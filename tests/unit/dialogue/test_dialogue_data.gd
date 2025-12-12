## Unit Tests for DialogueData
##
## Tests line management, choice management, and validation.
## Pure resource tests - no scene dependencies.
class_name TestDialogueData
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

## Create a valid DialogueData with defaults
func _create_test_dialogue(id: String = "test_dialogue") -> DialogueData:
	var dialogue: DialogueData = DialogueData.new()
	dialogue.dialogue_id = id
	dialogue.dialogue_title = "Test Dialogue"
	return dialogue


## Create a dialogue with lines already added
func _create_dialogue_with_lines(line_count: int = 3) -> DialogueData:
	var dialogue: DialogueData = _create_test_dialogue()
	for i: int in range(line_count):
		dialogue.add_line("Speaker " + str(i), "This is line " + str(i + 1))
	return dialogue


## Create a dialogue with choices
func _create_dialogue_with_choices() -> DialogueData:
	var dialogue: DialogueData = _create_dialogue_with_lines(1)
	var next_dialogue: DialogueData = _create_test_dialogue("next_dialogue")
	next_dialogue.add_line("NPC", "You chose option 1!")
	dialogue.add_choice("Option 1", next_dialogue)
	dialogue.add_choice("Option 2", null)
	return dialogue


# =============================================================================
# LINE MANAGEMENT TESTS
# =============================================================================

func test_add_line_stores_correctly() -> void:
	var dialogue: DialogueData = _create_test_dialogue()

	dialogue.add_line("Max", "Hello there!", null, "happy")

	assert_int(dialogue.get_line_count()).is_equal(1)
	var line: Dictionary = dialogue.get_line(0)
	assert_str(line["speaker_name"]).is_equal("Max")
	assert_str(line["text"]).is_equal("Hello there!")
	assert_str(line["emotion"]).is_equal("happy")


func test_add_line_default_emotion_is_neutral() -> void:
	var dialogue: DialogueData = _create_test_dialogue()

	dialogue.add_line("Max", "Test line")

	var line: Dictionary = dialogue.get_line(0)
	assert_str(line["emotion"]).is_equal("neutral")


func test_add_multiple_lines() -> void:
	var dialogue: DialogueData = _create_test_dialogue()

	dialogue.add_line("Max", "Line 1")
	dialogue.add_line("Tao", "Line 2")
	dialogue.add_line("Lowe", "Line 3")

	assert_int(dialogue.get_line_count()).is_equal(3)


func test_get_line_returns_correct_data() -> void:
	var dialogue: DialogueData = _create_dialogue_with_lines(3)

	var line_1: Dictionary = dialogue.get_line(1)

	assert_str(line_1["speaker_name"]).is_equal("Speaker 1")
	assert_str(line_1["text"]).is_equal("This is line 2")


func test_get_line_invalid_negative_index_returns_empty() -> void:
	var dialogue: DialogueData = _create_dialogue_with_lines(3)

	var line: Dictionary = dialogue.get_line(-1)

	assert_bool(line.is_empty()).is_true()


func test_get_line_invalid_high_index_returns_empty() -> void:
	var dialogue: DialogueData = _create_dialogue_with_lines(3)

	var line: Dictionary = dialogue.get_line(10)

	assert_bool(line.is_empty()).is_true()


func test_get_line_count_empty_dialogue() -> void:
	var dialogue: DialogueData = _create_test_dialogue()

	assert_int(dialogue.get_line_count()).is_equal(0)


func test_get_line_count_with_lines() -> void:
	var dialogue: DialogueData = _create_dialogue_with_lines(5)

	assert_int(dialogue.get_line_count()).is_equal(5)


# =============================================================================
# CHOICE MANAGEMENT TESTS
# =============================================================================

func test_add_choice_stores_correctly() -> void:
	var dialogue: DialogueData = _create_dialogue_with_lines(1)

	dialogue.add_choice("Accept quest", null)

	assert_int(dialogue.get_choice_count()).is_equal(1)
	var choice: Dictionary = dialogue.get_choice(0)
	assert_str(choice["choice_text"]).is_equal("Accept quest")


func test_add_choice_with_next_dialogue() -> void:
	var dialogue: DialogueData = _create_dialogue_with_lines(1)
	var next: DialogueData = _create_test_dialogue("next")
	next.add_line("NPC", "Great choice!")

	dialogue.add_choice("Say yes", next)

	var choice: Dictionary = dialogue.get_choice(0)
	assert_str(choice["choice_text"]).is_equal("Say yes")
	assert_object(choice["next_dialogue"]).is_same(next)


func test_add_multiple_choices() -> void:
	var dialogue: DialogueData = _create_dialogue_with_lines(1)

	dialogue.add_choice("Option A", null)
	dialogue.add_choice("Option B", null)
	dialogue.add_choice("Option C", null)

	assert_int(dialogue.get_choice_count()).is_equal(3)


func test_get_choice_returns_data() -> void:
	var dialogue: DialogueData = _create_dialogue_with_choices()

	var choice: Dictionary = dialogue.get_choice(0)

	assert_str(choice["choice_text"]).is_equal("Option 1")


func test_get_choice_invalid_index_returns_empty() -> void:
	var dialogue: DialogueData = _create_dialogue_with_choices()

	var choice: Dictionary = dialogue.get_choice(99)

	assert_bool(choice.is_empty()).is_true()


func test_get_choice_negative_index_returns_empty() -> void:
	var dialogue: DialogueData = _create_dialogue_with_choices()

	var choice: Dictionary = dialogue.get_choice(-1)

	assert_bool(choice.is_empty()).is_true()


func test_has_choices_true_when_choices_exist() -> void:
	var dialogue: DialogueData = _create_dialogue_with_choices()

	assert_bool(dialogue.has_choices()).is_true()


func test_has_choices_false_when_empty() -> void:
	var dialogue: DialogueData = _create_dialogue_with_lines(3)

	assert_bool(dialogue.has_choices()).is_false()


func test_get_choice_count_empty() -> void:
	var dialogue: DialogueData = _create_test_dialogue()

	assert_int(dialogue.get_choice_count()).is_equal(0)


# =============================================================================
# FLOW CONTROL TESTS
# =============================================================================

func test_has_next_true_when_next_dialogue_set() -> void:
	var dialogue: DialogueData = _create_dialogue_with_lines(1)
	var next: DialogueData = _create_dialogue_with_lines(1)
	dialogue.next_dialogue = next

	assert_bool(dialogue.has_next()).is_true()


func test_has_next_false_when_no_next_dialogue() -> void:
	var dialogue: DialogueData = _create_dialogue_with_lines(1)

	assert_bool(dialogue.has_next()).is_false()


func test_box_position_default_is_bottom() -> void:
	var dialogue: DialogueData = DialogueData.new()

	assert_int(dialogue.box_position).is_equal(DialogueData.BoxPosition.BOTTOM)


func test_auto_advance_default_is_false() -> void:
	var dialogue: DialogueData = DialogueData.new()

	assert_bool(dialogue.auto_advance).is_false()


func test_advance_delay_default_is_two_seconds() -> void:
	var dialogue: DialogueData = DialogueData.new()

	assert_float(dialogue.advance_delay).is_equal(2.0)


# =============================================================================
# VALIDATION TESTS
# =============================================================================

func test_validate_requires_id() -> void:
	var dialogue: DialogueData = DialogueData.new()
	dialogue.dialogue_id = ""
	dialogue.add_line("Speaker", "Test text")

	var result: bool = dialogue.validate()

	assert_bool(result).is_false()


func test_validate_requires_lines() -> void:
	var dialogue: DialogueData = DialogueData.new()
	dialogue.dialogue_id = "test"
	# No lines added

	var result: bool = dialogue.validate()

	assert_bool(result).is_false()


func test_validate_lines_have_text() -> void:
	var dialogue: DialogueData = DialogueData.new()
	dialogue.dialogue_id = "test"
	# Add line with empty text directly
	dialogue.lines.append({"speaker_name": "Max", "text": "", "emotion": "neutral"})

	var result: bool = dialogue.validate()

	assert_bool(result).is_false()


func test_validate_passes_with_valid_data() -> void:
	var dialogue: DialogueData = _create_dialogue_with_lines(2)

	var result: bool = dialogue.validate()

	assert_bool(result).is_true()


func test_validate_single_line_valid() -> void:
	var dialogue: DialogueData = _create_test_dialogue()
	dialogue.add_line("Speaker", "Just one line.")

	var result: bool = dialogue.validate()

	assert_bool(result).is_true()


# =============================================================================
# EMOTION ENUM TESTS
# =============================================================================

func test_emotion_enum_values() -> void:
	assert_int(DialogueData.Emotion.NEUTRAL).is_equal(0)
	assert_int(DialogueData.Emotion.HAPPY).is_equal(1)
	assert_int(DialogueData.Emotion.SAD).is_equal(2)
	assert_int(DialogueData.Emotion.ANGRY).is_equal(3)
	assert_int(DialogueData.Emotion.WORRIED).is_equal(4)
	assert_int(DialogueData.Emotion.SURPRISED).is_equal(5)
	assert_int(DialogueData.Emotion.DETERMINED).is_equal(6)
	assert_int(DialogueData.Emotion.THINKING).is_equal(7)


func test_box_position_enum_values() -> void:
	assert_int(DialogueData.BoxPosition.BOTTOM).is_equal(0)
	assert_int(DialogueData.BoxPosition.TOP).is_equal(1)
	assert_int(DialogueData.BoxPosition.CENTER).is_equal(2)
	assert_int(DialogueData.BoxPosition.AUTO).is_equal(3)
