## Unit Tests for DialogManager
##
## Tests dialog state management, flow control, and signal emission.
## Tests the singleton autoload behavior.
class_name TestDialogManager
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

# Signal connection tracking for cleanup
var _connected_signals: Array[Dictionary] = []


## Create a valid DialogueData for testing
func _create_test_dialogue(id: String = "test_dialogue", line_count: int = 3) -> DialogueData:
	var dialogue: DialogueData = DialogueData.new()
	dialogue.dialogue_id = id
	dialogue.dialogue_title = "Test Dialogue"
	for i: int in range(line_count):
		dialogue.add_line("Speaker " + str(i), "This is line " + str(i + 1))
	return dialogue


## Create a dialogue with choices
func _create_dialogue_with_choices(id: String = "choice_dialogue") -> DialogueData:
	var dialogue: DialogueData = DialogueData.new()
	dialogue.dialogue_id = id
	dialogue.add_line("NPC", "What do you want to do?")

	var next_1: DialogueData = _create_test_dialogue("choice_result_1", 1)
	var next_2: DialogueData = _create_test_dialogue("choice_result_2", 1)

	dialogue.add_choice("Option A", next_1)
	dialogue.add_choice("Option B", next_2)
	return dialogue


## Reset DialogManager state before each test
func before_test() -> void:
	# Reset the singleton to idle state
	_reset_dialog_manager_state()


## Ensure DialogManager is reset after each test (even on failure)
func after_test() -> void:
	# Disconnect any signals that were connected during the test
	for connection: Dictionary in _connected_signals:
		var sig: Signal = connection.signal_ref
		var callable: Callable = connection.callable
		if sig.is_connected(callable):
			sig.disconnect(callable)
	_connected_signals.clear()

	_reset_dialog_manager_state()


## Helper to connect a signal and track it for cleanup
func _connect_signal(sig: Signal, callable: Callable) -> void:
	sig.connect(callable)
	_connected_signals.append({"signal_ref": sig, "callable": callable})


## Helper to reset DialogManager to a clean state
func _reset_dialog_manager_state() -> void:
	if DialogManager:
		# Force end any active dialog
		DialogManager.current_state = DialogManager.State.IDLE
		DialogManager.current_dialogue = null
		DialogManager.current_line_index = 0
		DialogManager._dialog_chain_stack.clear()


# =============================================================================
# STATE MANAGEMENT TESTS
# =============================================================================

func test_initial_state_is_idle() -> void:
	assert_int(DialogManager.current_state).is_equal(DialogManager.State.IDLE)


func test_start_dialog_sets_active_state() -> void:
	var dialogue: DialogueData = _create_test_dialogue()

	var result: bool = DialogManager.start_dialog_from_resource(dialogue)

	assert_bool(result).is_true()
	assert_bool(DialogManager.is_dialog_active()).is_true()


func test_start_dialog_sets_current_dialogue() -> void:
	var dialogue: DialogueData = _create_test_dialogue()

	DialogManager.start_dialog_from_resource(dialogue)

	assert_object(DialogManager.current_dialogue).is_same(dialogue)


func test_start_dialog_resets_line_index() -> void:
	var dialogue: DialogueData = _create_test_dialogue()

	DialogManager.start_dialog_from_resource(dialogue)

	assert_int(DialogManager.current_line_index).is_equal(0)


func test_start_dialog_null_returns_false() -> void:
	var result: bool = DialogManager.start_dialog_from_resource(null)

	assert_bool(result).is_false()
	assert_bool(DialogManager.is_dialog_active()).is_false()


func test_start_dialog_while_active_returns_false() -> void:
	var dialogue_1: DialogueData = _create_test_dialogue("dialogue_1")
	var dialogue_2: DialogueData = _create_test_dialogue("dialogue_2")

	DialogManager.start_dialog_from_resource(dialogue_1)
	var result: bool = DialogManager.start_dialog_from_resource(dialogue_2)

	assert_bool(result).is_false()
	# Original dialogue should still be active
	assert_object(DialogManager.current_dialogue).is_same(dialogue_1)


func test_start_dialog_invalid_dialogue_returns_false() -> void:
	var invalid_dialogue: DialogueData = DialogueData.new()
	invalid_dialogue.dialogue_id = ""  # Invalid: no ID

	var result: bool = DialogManager.start_dialog_from_resource(invalid_dialogue)

	assert_bool(result).is_false()


func test_is_dialog_active_false_when_idle() -> void:
	assert_bool(DialogManager.is_dialog_active()).is_false()


func test_get_current_state_returns_state() -> void:
	assert_int(DialogManager.get_current_state()).is_equal(DialogManager.State.IDLE)


# =============================================================================
# DIALOG ADVANCEMENT TESTS
# =============================================================================

func test_advance_dialog_increments_line() -> void:
	var dialogue: DialogueData = _create_test_dialogue("test", 3)
	DialogManager.start_dialog_from_resource(dialogue)

	# Complete text reveal to allow advancement
	DialogManager.on_text_reveal_finished()
	DialogManager.advance_dialog()

	assert_int(DialogManager.current_line_index).is_equal(1)


func test_dialog_ends_at_last_line() -> void:
	var dialogue: DialogueData = _create_test_dialogue("test", 2)
	DialogManager.start_dialog_from_resource(dialogue)

	# Advance through all lines
	DialogManager.on_text_reveal_finished()
	DialogManager.advance_dialog()  # Move to line 1
	DialogManager.on_text_reveal_finished()
	DialogManager.advance_dialog()  # Should end dialog

	assert_bool(DialogManager.is_dialog_active()).is_false()


func test_advance_dialog_only_when_waiting_for_input() -> void:
	var dialogue: DialogueData = _create_test_dialogue("test", 3)
	DialogManager.start_dialog_from_resource(dialogue)

	# Try to advance without text reveal finishing
	# State should be SHOWING_LINE, not WAITING_FOR_INPUT
	DialogManager.advance_dialog()

	# Line should not have advanced
	assert_int(DialogManager.current_line_index).is_equal(0)


func test_text_reveal_finished_changes_state() -> void:
	var dialogue: DialogueData = _create_test_dialogue()
	DialogManager.start_dialog_from_resource(dialogue)

	# Initially should be SHOWING_LINE
	DialogManager.on_text_reveal_finished()

	assert_int(DialogManager.current_state).is_equal(DialogManager.State.WAITING_FOR_INPUT)


# =============================================================================
# CIRCULAR REFERENCE DETECTION TESTS
# =============================================================================

func test_circular_reference_detected() -> void:
	var dialogue: DialogueData = _create_test_dialogue("circular_test", 1)
	# Create a circular reference: dialogue chains back to itself
	dialogue.next_dialogue = dialogue

	DialogManager.start_dialog_from_resource(dialogue)

	# Advance to end of first dialogue
	DialogManager.on_text_reveal_finished()
	DialogManager.advance_dialog()

	# The chain should have ended due to circular reference detection
	# The original dialog ended, but trying to chain to itself should fail
	assert_bool(DialogManager.is_dialog_active()).is_false()


func test_max_depth_enforced() -> void:
	# Create a chain of dialogues that exceeds MAX_DIALOG_CHAIN_DEPTH
	var dialogues: Array[DialogueData] = []
	for i: int in range(DialogManager.MAX_DIALOG_CHAIN_DEPTH + 2):
		var d: DialogueData = _create_test_dialogue("chain_" + str(i), 1)
		dialogues.append(d)

	# Link them together
	for i: int in range(dialogues.size() - 1):
		dialogues[i].next_dialogue = dialogues[i + 1]

	DialogManager.start_dialog_from_resource(dialogues[0])

	# Advance through dialogs - should eventually stop due to depth limit or chain end
	for i: int in range(DialogManager.MAX_DIALOG_CHAIN_DEPTH + 5):
		if not DialogManager.is_dialog_active():
			break
		DialogManager.on_text_reveal_finished()
		DialogManager.advance_dialog()

	# Verify dialog eventually ended (no infinite loop) and no crash occurred
	assert_bool(DialogManager.is_dialog_active()).is_false()


func test_dialog_chain_stack_tracks_ids() -> void:
	var dialogue: DialogueData = _create_test_dialogue("tracked_dialogue", 1)

	DialogManager.start_dialog_from_resource(dialogue)

	assert_bool("tracked_dialogue" in DialogManager._dialog_chain_stack).is_true()


func test_dialog_chain_stack_cleared_on_end() -> void:
	var dialogue: DialogueData = _create_test_dialogue("temp_dialogue", 1)
	DialogManager.start_dialog_from_resource(dialogue)

	# End the dialog
	DialogManager.end_dialog()

	assert_bool("temp_dialogue" in DialogManager._dialog_chain_stack).is_false()


# =============================================================================
# SIGNAL EMISSION TESTS
# =============================================================================

var _dialog_started_emitted: bool = false
var _dialog_ended_emitted: bool = false
var _line_changed_emitted: bool = false
var _choices_ready_emitted: bool = false
var _last_line_index: int = -1
var _last_choices: Array = []


func _reset_signal_flags() -> void:
	_dialog_started_emitted = false
	_dialog_ended_emitted = false
	_line_changed_emitted = false
	_choices_ready_emitted = false
	_last_line_index = -1
	_last_choices = []


func _on_dialog_started(_dialogue: DialogueData) -> void:
	_dialog_started_emitted = true


func _on_dialog_ended(_dialogue: DialogueData) -> void:
	_dialog_ended_emitted = true


func _on_line_changed(index: int, _data: Dictionary) -> void:
	_line_changed_emitted = true
	_last_line_index = index


func _on_choices_ready(choices: Array) -> void:
	_choices_ready_emitted = true
	_last_choices = choices


func test_dialog_started_signal() -> void:
	_reset_signal_flags()
	_connect_signal(DialogManager.dialog_started, _on_dialog_started)

	var dialogue: DialogueData = _create_test_dialogue()
	DialogManager.start_dialog_from_resource(dialogue)

	assert_bool(_dialog_started_emitted).is_true()
	# Signal cleanup handled by after_test()


func test_dialog_ended_signal() -> void:
	_reset_signal_flags()
	_connect_signal(DialogManager.dialog_ended, _on_dialog_ended)

	var dialogue: DialogueData = _create_test_dialogue("test", 1)
	DialogManager.start_dialog_from_resource(dialogue)
	DialogManager.on_text_reveal_finished()
	DialogManager.advance_dialog()

	assert_bool(_dialog_ended_emitted).is_true()
	# Signal cleanup handled by after_test()


func test_line_changed_signal() -> void:
	_reset_signal_flags()
	_connect_signal(DialogManager.line_changed, _on_line_changed)

	var dialogue: DialogueData = _create_test_dialogue("test", 2)
	DialogManager.start_dialog_from_resource(dialogue)

	assert_bool(_line_changed_emitted).is_true()
	assert_int(_last_line_index).is_equal(0)
	# Signal cleanup handled by after_test()


func test_line_changed_signal_on_advance() -> void:
	_reset_signal_flags()
	_connect_signal(DialogManager.line_changed, _on_line_changed)

	var dialogue: DialogueData = _create_test_dialogue("test", 3)
	DialogManager.start_dialog_from_resource(dialogue)
	_reset_signal_flags()  # Clear the initial signal

	DialogManager.on_text_reveal_finished()
	DialogManager.advance_dialog()

	assert_bool(_line_changed_emitted).is_true()
	assert_int(_last_line_index).is_equal(1)
	# Signal cleanup handled by after_test()


func test_choices_ready_signal() -> void:
	_reset_signal_flags()
	_connect_signal(DialogManager.choices_ready, _on_choices_ready)

	var dialogue: DialogueData = _create_dialogue_with_choices()
	DialogManager.start_dialog_from_resource(dialogue)
	DialogManager.on_text_reveal_finished()
	DialogManager.advance_dialog()  # Should trigger choices

	assert_bool(_choices_ready_emitted).is_true()
	assert_int(_last_choices.size()).is_equal(2)
	# Signal cleanup handled by after_test()


# =============================================================================
# CHOICE HANDLING TESTS
# =============================================================================

func test_select_choice_ends_current_dialog() -> void:
	var dialogue: DialogueData = _create_dialogue_with_choices()
	DialogManager.start_dialog_from_resource(dialogue)
	DialogManager.on_text_reveal_finished()
	DialogManager.advance_dialog()  # Show choices

	DialogManager.select_choice(0)

	# A new dialog should have started from the choice
	assert_bool(DialogManager.is_dialog_active()).is_true()
	assert_str(DialogManager.current_dialogue.dialogue_id).is_equal("choice_result_1")


func test_select_choice_advances_to_next_dialogue() -> void:
	var dialogue: DialogueData = _create_dialogue_with_choices()
	DialogManager.start_dialog_from_resource(dialogue)
	DialogManager.on_text_reveal_finished()
	DialogManager.advance_dialog()  # Show choices

	DialogManager.select_choice(1)  # Select Option B

	assert_str(DialogManager.current_dialogue.dialogue_id).is_equal("choice_result_2")


func test_select_invalid_choice_ignored() -> void:
	var dialogue: DialogueData = _create_dialogue_with_choices()
	DialogManager.start_dialog_from_resource(dialogue)
	DialogManager.on_text_reveal_finished()
	DialogManager.advance_dialog()  # Show choices

	# Try to select an invalid choice index
	DialogManager.select_choice(99)

	# State should remain waiting for choice
	assert_int(DialogManager.current_state).is_equal(DialogManager.State.WAITING_FOR_CHOICE)


func test_select_choice_not_waiting_ignored() -> void:
	var dialogue: DialogueData = _create_test_dialogue("no_choices", 2)
	DialogManager.start_dialog_from_resource(dialogue)

	# Try to select a choice when not in WAITING_FOR_CHOICE state
	DialogManager.select_choice(0)

	# Should be ignored, state unchanged
	assert_bool(DialogManager.is_dialog_active()).is_true()


# =============================================================================
# CANCEL DIALOG TESTS
# =============================================================================

func test_cancel_dialog_ends_dialog() -> void:
	var dialogue: DialogueData = _create_test_dialogue()
	DialogManager.start_dialog_from_resource(dialogue)

	DialogManager.cancel_dialog()

	assert_bool(DialogManager.is_dialog_active()).is_false()


func test_cancel_dialog_when_idle_is_safe() -> void:
	# Should not crash or error
	DialogManager.cancel_dialog()

	assert_bool(DialogManager.is_dialog_active()).is_false()


func test_end_dialog_public_method() -> void:
	var dialogue: DialogueData = _create_test_dialogue()
	DialogManager.start_dialog_from_resource(dialogue)

	DialogManager.end_dialog()

	assert_bool(DialogManager.is_dialog_active()).is_false()


# =============================================================================
# TEXT SPEED TESTS
# =============================================================================

func test_set_text_speed_slow() -> void:
	DialogManager.set_text_speed(DialogManager.TextSpeed.SLOW)

	assert_float(DialogManager.text_speed_multiplier).is_equal(0.5)


func test_set_text_speed_normal() -> void:
	DialogManager.set_text_speed(DialogManager.TextSpeed.NORMAL)

	assert_float(DialogManager.text_speed_multiplier).is_equal(1.0)


func test_set_text_speed_fast() -> void:
	DialogManager.set_text_speed(DialogManager.TextSpeed.FAST)

	assert_float(DialogManager.text_speed_multiplier).is_equal(2.0)


func test_set_text_speed_instant() -> void:
	DialogManager.set_text_speed(DialogManager.TextSpeed.INSTANT)

	assert_float(DialogManager.text_speed_multiplier).is_equal(999.0)


# =============================================================================
# STATE ENUM TESTS
# =============================================================================

func test_state_enum_values() -> void:
	assert_int(DialogManager.State.IDLE).is_equal(0)
	assert_int(DialogManager.State.DIALOG_STARTING).is_equal(1)
	assert_int(DialogManager.State.SHOWING_LINE).is_equal(2)
	assert_int(DialogManager.State.WAITING_FOR_INPUT).is_equal(3)
	assert_int(DialogManager.State.WAITING_FOR_CHOICE).is_equal(4)
	assert_int(DialogManager.State.DIALOG_ENDING).is_equal(5)
