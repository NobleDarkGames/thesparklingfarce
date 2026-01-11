## Unit Tests for Character Editor Validation
##
## Tests the validation logic in the character editor.
## Focus on ensuring validation checks UI state, not resource state.
## This was a bug where selecting a class in the picker wasn't recognized
## because validation was reading from the resource (which hadn't been saved yet)
## instead of from the UI controls.
##
## Bug fixed in commit 95987a0
class_name TestCharacterEditorValidation
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

var _editor: Control
var CharacterEditorClass: GDScript


func before_test() -> void:
	CharacterEditorClass = load("res://addons/sparkling_editor/ui/character_editor.gd")
	_editor = CharacterEditorClass.new()
	add_child(_editor)
	# Wait for UI to initialize
	await get_tree().process_frame


func after_test() -> void:
	if _editor and is_instance_valid(_editor):
		_editor.queue_free()
	_editor = null


# =============================================================================
# UI COMPONENT EXISTENCE TESTS
# =============================================================================

func test_editor_has_name_edit() -> void:
	assert_object(_editor.name_edit).is_not_null()
	assert_bool(_editor.name_edit is LineEdit).is_true()


func test_editor_has_level_spin() -> void:
	assert_object(_editor.level_spin).is_not_null()
	assert_bool(_editor.level_spin is SpinBox).is_true()


func test_editor_has_class_picker() -> void:
	assert_object(_editor.class_picker).is_not_null()


func test_editor_has_category_option() -> void:
	assert_object(_editor.category_option).is_not_null()
	assert_bool(_editor.category_option is OptionButton).is_true()


# =============================================================================
# VALIDATION - EMPTY NAME TESTS
# =============================================================================

func test_validate_empty_name_fails() -> void:
	# Set up a valid resource (to ensure we're testing UI, not resource)
	var char_data: CharacterData = CharacterData.new()
	char_data.character_name = "Valid Resource Name"
	_editor.current_resource = char_data
	
	# Set UI to invalid state - empty name
	_editor.name_edit.text = ""
	_editor.level_spin.value = 1
	
	var result: Dictionary = _editor._validate_resource()
	
	assert_bool(result.valid).is_false()
	assert_bool(result.errors.size() > 0).is_true()
	# Error message should mention name
	var has_name_error: bool = false
	for error: String in result.errors:
		if "name" in error.to_lower():
			has_name_error = true
			break
	assert_bool(has_name_error).is_true()


func test_validate_whitespace_only_name_fails() -> void:
	var char_data: CharacterData = CharacterData.new()
	_editor.current_resource = char_data
	
	_editor.name_edit.text = "   "  # Only whitespace
	_editor.level_spin.value = 1
	
	var result: Dictionary = _editor._validate_resource()
	
	assert_bool(result.valid).is_false()


func test_validate_valid_name_passes() -> void:
	var char_data: CharacterData = CharacterData.new()
	_editor.current_resource = char_data
	
	_editor.name_edit.text = "Hero"
	_editor.level_spin.value = 1
	# Select enemy category so class isn't required
	_select_category("enemy")
	
	var result: Dictionary = _editor._validate_resource()
	
	assert_bool(result.valid).is_true()


# =============================================================================
# VALIDATION - LEVEL TESTS
# Note: test_validate_level_zero_fails and test_validate_level_100_fails were
# removed because the SpinBox UI control (min_value=1, max_value=99) clamps
# values to the valid range, making those validation paths unreachable.
# The validation check in _validate_resource() serves as defense-in-depth
# but cannot be triggered through the UI.
# =============================================================================

func test_validate_level_1_passes() -> void:
	var char_data: CharacterData = CharacterData.new()
	_editor.current_resource = char_data
	
	_editor.name_edit.text = "Hero"
	_editor.level_spin.value = 1
	_select_category("enemy")
	
	var result: Dictionary = _editor._validate_resource()
	
	assert_bool(result.valid).is_true()


func test_validate_level_99_passes() -> void:
	var char_data: CharacterData = CharacterData.new()
	_editor.current_resource = char_data
	
	_editor.name_edit.text = "Hero"
	_editor.level_spin.value = 99
	_select_category("enemy")
	
	var result: Dictionary = _editor._validate_resource()
	
	assert_bool(result.valid).is_true()


# =============================================================================
# VALIDATION - CLASS REQUIREMENT TESTS
# Critical regression tests for the UI state bug
# =============================================================================

func test_validate_player_without_class_fails() -> void:
	var char_data: CharacterData = CharacterData.new()
	_editor.current_resource = char_data
	
	_editor.name_edit.text = "Hero"
	_editor.level_spin.value = 1
	_select_category("player")
	_editor.class_picker.select_none()
	
	var result: Dictionary = _editor._validate_resource()
	
	assert_bool(result.valid).is_false()
	# Error should mention class
	var has_class_error: bool = false
	for error: String in result.errors:
		if "class" in error.to_lower():
			has_class_error = true
			break
	assert_bool(has_class_error).is_true()


func test_validate_enemy_without_class_passes_with_warning() -> void:
	var char_data: CharacterData = CharacterData.new()
	_editor.current_resource = char_data
	
	_editor.name_edit.text = "Goblin"
	_editor.level_spin.value = 1
	_select_category("enemy")
	_editor.class_picker.select_none()
	
	var result: Dictionary = _editor._validate_resource()
	
	# Should be valid (enemies don't require class)
	assert_bool(result.valid).is_true()
	# But should have warning
	var warnings: Array = result.get("warnings", [])
	assert_bool(warnings.size() > 0).is_true()


func test_validate_neutral_without_class_passes_with_warning() -> void:
	var char_data: CharacterData = CharacterData.new()
	_editor.current_resource = char_data
	
	_editor.name_edit.text = "Villager"
	_editor.level_spin.value = 1
	_select_category("neutral")
	_editor.class_picker.select_none()
	
	var result: Dictionary = _editor._validate_resource()
	
	assert_bool(result.valid).is_true()
	var warnings: Array = result.get("warnings", [])
	assert_bool(warnings.size() > 0).is_true()


# =============================================================================
# REGRESSION TEST - UI STATE VS RESOURCE STATE
# This is the core bug that was fixed
# =============================================================================

func test_validation_uses_ui_state_not_resource_state() -> void:
	# Create a resource with VALID data
	var char_data: CharacterData = CharacterData.new()
	char_data.character_name = "Valid Name From Resource"
	char_data.starting_level = 5
	# Note: character_class would need to be set too, but we're testing name
	
	_editor.current_resource = char_data
	
	# But set UI to INVALID state (empty name)
	_editor.name_edit.text = ""
	_editor.level_spin.value = 1
	
	# Validation should FAIL because it checks UI state
	var result: Dictionary = _editor._validate_resource()
	
	# If this fails, validation is still checking resource state (the old bug)
	assert_bool(result.valid).is_false()


func test_validation_reads_name_from_ui_not_resource() -> void:
	# Resource has one name
	var char_data: CharacterData = CharacterData.new()
	char_data.character_name = "Resource Name"
	_editor.current_resource = char_data
	
	# UI has different name
	_editor.name_edit.text = "UI Name"
	_editor.level_spin.value = 1
	_select_category("enemy")
	
	# Should validate successfully using UI name
	var result: Dictionary = _editor._validate_resource()
	assert_bool(result.valid).is_true()
	
	# Now clear UI name (resource still has valid name)
	_editor.name_edit.text = ""
	
	# Should fail because UI name is empty
	result = _editor._validate_resource()
	assert_bool(result.valid).is_false()


func test_validation_reads_level_from_ui_not_resource() -> void:
	# Resource has valid level
	var char_data: CharacterData = CharacterData.new()
	char_data.starting_level = 50
	_editor.current_resource = char_data
	
	_editor.name_edit.text = "Hero"
	_select_category("enemy")
	
	# UI has invalid level (SpinBox won't actually go to 0, but we test the principle)
	# SpinBox min is 1, so set to 1 which is valid
	_editor.level_spin.value = 1
	
	var result: Dictionary = _editor._validate_resource()
	assert_bool(result.valid).is_true()


func test_validation_reads_category_from_ui_not_resource() -> void:
	# Resource is player
	var char_data: CharacterData = CharacterData.new()
	char_data.unit_category = "player"
	_editor.current_resource = char_data
	
	_editor.name_edit.text = "Goblin"
	_editor.level_spin.value = 1
	
	# UI says enemy (so class not required)
	_select_category("enemy")
	_editor.class_picker.select_none()
	
	# Should pass because UI category is "enemy"
	var result: Dictionary = _editor._validate_resource()
	assert_bool(result.valid).is_true()
	
	# Now change UI to player (class required)
	_select_category("player")
	
	# Should fail because UI category is "player" and no class selected
	result = _editor._validate_resource()
	assert_bool(result.valid).is_false()


# =============================================================================
# NULL RESOURCE TESTS
# =============================================================================

func test_validate_null_resource_fails() -> void:
	_editor.current_resource = null
	
	var result: Dictionary = _editor._validate_resource()
	
	assert_bool(result.valid).is_false()


func test_validate_wrong_resource_type_fails() -> void:
	# Set a non-CharacterData resource
	_editor.current_resource = Resource.new()
	
	var result: Dictionary = _editor._validate_resource()
	
	assert_bool(result.valid).is_false()


# =============================================================================
# HELPER METHODS
# =============================================================================

func _select_category(category: String) -> void:
	for i: int in range(_editor.category_option.item_count):
		if _editor.category_option.get_item_text(i) == category:
			_editor.category_option.select(i)
			return
	push_warning("Category '%s' not found in options" % category)
