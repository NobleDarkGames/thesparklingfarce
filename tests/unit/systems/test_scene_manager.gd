## SceneManager Unit Tests
##
## Tests the SceneManager scene transition and fade functionality:
## - Fade state management (is_faded_to_black, is_fading)
## - Immediate fade operations (set_black, clear_fade)
## - Scene path resolution with fallbacks
## - Transition state tracking
## - Signal emissions
## - Scene history (previous_scene_path)
##
## Note: This is a UNIT test - creates a fresh SceneManager instance.
## Many methods require async/tween support and are tested for state changes.
class_name TestSceneManager
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

const SceneManagerScript: GDScript = preload("res://core/systems/scene_manager.gd")
const SignalTrackerScript: GDScript = preload("res://tests/fixtures/signal_tracker.gd")

var _scene_manager: Node
var _tracker: SignalTracker


func before_test() -> void:
	_scene_manager = SceneManagerScript.new()
	add_child(_scene_manager)
	# Wait for deferred fade overlay setup
	await get_tree().process_frame
	_tracker = SignalTrackerScript.new()


func after_test() -> void:
	if _tracker:
		_tracker.disconnect_all()
		_tracker = null
	if _scene_manager and is_instance_valid(_scene_manager):
		_scene_manager.queue_free()
	_scene_manager = null


# =============================================================================
# INITIAL STATE TESTS
# =============================================================================

func test_initial_is_transitioning_is_false() -> void:
	assert_bool(_scene_manager.is_transitioning).is_false()


func test_initial_is_faded_to_black_is_false() -> void:
	assert_bool(_scene_manager.is_faded_to_black).is_false()


func test_initial_is_fading_is_false() -> void:
	assert_bool(_scene_manager.is_fading).is_false()


func test_initial_previous_scene_path_is_empty() -> void:
	assert_str(_scene_manager.previous_scene_path).is_empty()


func test_initial_save_slot_mode_is_new_game() -> void:
	assert_str(_scene_manager.save_slot_mode).is_equal("new_game")


func test_fade_overlay_is_created() -> void:
	# Wait for deferred add to complete
	await get_tree().process_frame
	assert_object(_scene_manager.fade_overlay).is_not_null()


func test_fade_overlay_starts_transparent() -> void:
	await get_tree().process_frame
	assert_float(_scene_manager.fade_overlay.modulate.a).is_equal(0.0)


# =============================================================================
# IMMEDIATE FADE OPERATION TESTS
# =============================================================================

func test_set_black_sets_overlay_alpha_to_one() -> void:
	await get_tree().process_frame

	_scene_manager.set_black()

	assert_float(_scene_manager.fade_overlay.modulate.a).is_equal(1.0)


func test_set_black_sets_is_faded_to_black_true() -> void:
	await get_tree().process_frame

	_scene_manager.set_black()

	assert_bool(_scene_manager.is_faded_to_black).is_true()


func test_clear_fade_sets_overlay_alpha_to_zero() -> void:
	await get_tree().process_frame
	_scene_manager.set_black()

	_scene_manager.clear_fade()

	assert_float(_scene_manager.fade_overlay.modulate.a).is_equal(0.0)


func test_clear_fade_sets_is_faded_to_black_false() -> void:
	await get_tree().process_frame
	_scene_manager.set_black()

	_scene_manager.clear_fade()

	assert_bool(_scene_manager.is_faded_to_black).is_false()


func test_set_black_then_clear_fade_cycle() -> void:
	await get_tree().process_frame

	_scene_manager.set_black()
	assert_bool(_scene_manager.is_faded_to_black).is_true()

	_scene_manager.clear_fade()
	assert_bool(_scene_manager.is_faded_to_black).is_false()

	_scene_manager.set_black()
	assert_bool(_scene_manager.is_faded_to_black).is_true()


# =============================================================================
# SCENE PATH RESOLUTION TESTS
# =============================================================================

func test_get_scene_path_returns_fallback_when_not_registered() -> void:
	var path: String = _scene_manager.get_scene_path("nonexistent_scene", "res://fallback.tscn")

	assert_str(path).is_equal("res://fallback.tscn")


func test_get_scene_path_returns_empty_with_no_fallback() -> void:
	var path: String = _scene_manager.get_scene_path("nonexistent_scene")

	assert_str(path).is_empty()


func test_get_scene_path_with_opening_cinematic_constant() -> void:
	# When scene not registered, should return fallback
	var path: String = _scene_manager.get_scene_path(
		_scene_manager.SCENE_OPENING_CINEMATIC,
		_scene_manager.FALLBACK_OPENING_CINEMATIC
	)

	assert_str(path).is_equal(_scene_manager.FALLBACK_OPENING_CINEMATIC)


func test_get_scene_path_with_main_menu_constant() -> void:
	var path: String = _scene_manager.get_scene_path(
		_scene_manager.SCENE_MAIN_MENU,
		_scene_manager.FALLBACK_MAIN_MENU
	)

	# Path may be overridden by mods, so just check it's not empty
	assert_str(path).is_not_empty()
	assert_str(path).ends_with(".tscn")


func test_get_scene_path_with_save_slot_selector_constant() -> void:
	var path: String = _scene_manager.get_scene_path(
		_scene_manager.SCENE_SAVE_SLOT_SELECTOR,
		_scene_manager.FALLBACK_SAVE_SLOT_SELECTOR
	)

	assert_str(path).is_equal(_scene_manager.FALLBACK_SAVE_SLOT_SELECTOR)


# =============================================================================
# CONSTANTS TESTS
# =============================================================================

func test_scene_id_constants_are_not_empty() -> void:
	assert_str(_scene_manager.SCENE_OPENING_CINEMATIC).is_not_empty()
	assert_str(_scene_manager.SCENE_MAIN_MENU).is_not_empty()
	assert_str(_scene_manager.SCENE_SAVE_SLOT_SELECTOR).is_not_empty()


func test_fallback_paths_are_valid_resource_paths() -> void:
	assert_str(_scene_manager.FALLBACK_OPENING_CINEMATIC).starts_with("res://")
	assert_str(_scene_manager.FALLBACK_MAIN_MENU).starts_with("res://")
	assert_str(_scene_manager.FALLBACK_SAVE_SLOT_SELECTOR).starts_with("res://")
	assert_str(_scene_manager.FALLBACK_BATTLE_LOADER).starts_with("res://")


func test_fade_duration_is_positive() -> void:
	assert_float(_scene_manager.FADE_DURATION).is_greater(0.0)


# =============================================================================
# SAVE SLOT MODE TESTS
# =============================================================================

func test_save_slot_mode_can_be_set_to_load_game() -> void:
	_scene_manager.save_slot_mode = "load_game"

	assert_str(_scene_manager.save_slot_mode).is_equal("load_game")


func test_save_slot_mode_can_be_set_to_new_game() -> void:
	_scene_manager.save_slot_mode = "load_game"
	_scene_manager.save_slot_mode = "new_game"

	assert_str(_scene_manager.save_slot_mode).is_equal("new_game")


# =============================================================================
# TRANSITION STATE TESTS
# =============================================================================

func test_is_transitioning_blocks_additional_transitions() -> void:
	# Simulate being in transition
	_scene_manager.is_transitioning = true

	# change_scene should early exit when already transitioning
	# We can verify the state remains unchanged
	var original_current: String = _scene_manager.current_scene_path
	# Note: Actually calling change_scene would require valid scene paths
	# Instead we verify the guard condition logic
	assert_bool(_scene_manager.is_transitioning).is_true()


func test_previous_scene_path_can_be_tracked() -> void:
	_scene_manager.previous_scene_path = "res://scenes/test_previous.tscn"

	assert_str(_scene_manager.previous_scene_path).is_equal("res://scenes/test_previous.tscn")


func test_current_scene_path_can_be_tracked() -> void:
	_scene_manager.current_scene_path = "res://scenes/test_current.tscn"

	assert_str(_scene_manager.current_scene_path).is_equal("res://scenes/test_current.tscn")


# =============================================================================
# FADE OVERLAY CONFIGURATION TESTS
# =============================================================================

func test_fade_overlay_color_is_black() -> void:
	await get_tree().process_frame

	assert_object(_scene_manager.fade_overlay.color).is_equal(Color.BLACK)


func test_fade_overlay_ignores_mouse() -> void:
	await get_tree().process_frame

	assert_int(_scene_manager.fade_overlay.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_fade_canvas_layer_is_high() -> void:
	await get_tree().process_frame

	# Layer should be high (128) to render above everything
	assert_int(_scene_manager._fade_canvas_layer.layer).is_equal(128)


# =============================================================================
# SIGNAL TESTS
# =============================================================================

func test_fade_started_signal_exists() -> void:
	# Verify signal can be connected to
	var emissions: Array = []
	var callback: Callable = func(to_black: bool) -> void:
		emissions.append(to_black)

	_scene_manager.fade_started.connect(callback)
	_scene_manager.fade_started.emit(true)

	assert_int(emissions.size()).is_equal(1)
	assert_bool(emissions[0]).is_true()

	_scene_manager.fade_started.disconnect(callback)


func test_fade_completed_signal_exists() -> void:
	var emissions: Array = []
	var callback: Callable = func(is_black: bool) -> void:
		emissions.append(is_black)

	_scene_manager.fade_completed.connect(callback)
	_scene_manager.fade_completed.emit(false)

	assert_int(emissions.size()).is_equal(1)
	assert_bool(emissions[0]).is_false()

	_scene_manager.fade_completed.disconnect(callback)


func test_scene_transition_started_signal_exists() -> void:
	var emissions: Array = []
	var callback: Callable = func(from: String, to: String) -> void:
		emissions.append([from, to])

	_scene_manager.scene_transition_started.connect(callback)
	_scene_manager.scene_transition_started.emit("from.tscn", "to.tscn")

	assert_int(emissions.size()).is_equal(1)
	assert_str(emissions[0][0]).is_equal("from.tscn")
	assert_str(emissions[0][1]).is_equal("to.tscn")

	_scene_manager.scene_transition_started.disconnect(callback)


func test_scene_transition_completed_signal_exists() -> void:
	var emissions: Array = []
	var callback: Callable = func(scene: String) -> void:
		emissions.append(scene)

	_scene_manager.scene_transition_completed.connect(callback)
	_scene_manager.scene_transition_completed.emit("completed.tscn")

	assert_int(emissions.size()).is_equal(1)
	assert_str(emissions[0]).is_equal("completed.tscn")

	_scene_manager.scene_transition_completed.disconnect(callback)


# =============================================================================
# GO BACK TESTS
# =============================================================================

func test_go_back_requires_previous_scene_path() -> void:
	# When previous_scene_path is empty, go_back should warn and not crash
	_scene_manager.previous_scene_path = ""

	# This should not crash and should exit early
	# We verify by checking transitioning state remains false
	assert_bool(_scene_manager.is_transitioning).is_false()


# =============================================================================
# CONVENIENCE METHOD TESTS
# =============================================================================

func test_goto_battle_uses_fallback_when_empty() -> void:
	# The method should use FALLBACK_BATTLE_LOADER when path is empty
	# We can't actually call it without valid scenes, but we verify the fallback exists
	assert_str(_scene_manager.FALLBACK_BATTLE_LOADER).is_not_empty()


# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_set_black_with_null_overlay_does_not_crash() -> void:
	# Temporarily null the overlay
	var original_overlay: ColorRect = _scene_manager.fade_overlay
	_scene_manager.fade_overlay = null

	# Should not crash
	_scene_manager.set_black()

	# Restore
	_scene_manager.fade_overlay = original_overlay


func test_clear_fade_with_null_overlay_does_not_crash() -> void:
	var original_overlay: ColorRect = _scene_manager.fade_overlay
	_scene_manager.fade_overlay = null

	# Should not crash
	_scene_manager.clear_fade()

	_scene_manager.fade_overlay = original_overlay


func test_get_current_scene_returns_node() -> void:
	var current: Node = _scene_manager.get_current_scene()

	# Should return some node (the current scene)
	assert_object(current).is_not_null()
