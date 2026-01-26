## Unit Tests for Character Editor Validation
##
## Tests the validation logic in the character editor using a mock.
## This avoids instantiating the full @tool editor UI which creates
## 500+ orphan nodes from EditorFileDialog and other internal components.
##
## The mock replicates the validation rules from CharacterEditor._validate_resource()
## (lines 293-320 in character_editor.gd). Keep both in sync when modifying rules.
##
## Original bug fixed in commit 95987a0: validation was reading from resource
## state instead of UI state.
class_name TestCharacterEditorValidation
extends GdUnitTestSuite


# =============================================================================
# MOCK CLASS
# =============================================================================

## Mock that provides UI state for validation testing without instantiating
## the full @tool editor UI. Extends RefCounted (not Node) = zero orphans.
class MockCharacterEditorState extends RefCounted:
	var current_resource: Resource = null
	var name_text: String = ""
	var level_value: int = 1
	var selected_class: ClassData = null
	var category_selected: String = "player"

	## Replicates CharacterEditor._validate_resource() logic exactly.
	## See addons/sparkling_editor/ui/character_editor.gd lines 293-320.
	func validate_resource() -> Dictionary:
		var character: CharacterData = current_resource as CharacterData
		if not character:
			return {valid = false, errors = ["Invalid resource type"]}

		var errors: Array[String] = []
		var warnings: Array[String] = []

		# Validate UI state (not resource state)
		var char_name: String = name_text.strip_edges()
		var level: int = level_value
		var unit_cat: String = category_selected

		if char_name.is_empty():
			errors.append("Character name cannot be empty")

		if level < 1 or level > 99:
			errors.append("Starting level must be between 1 and 99")

		# Validate class selection - required for playable characters
		if selected_class == null:
			if unit_cat == "player":
				errors.append("Player characters must have a class assigned")
			else:
				warnings.append("No class assigned - character will have no abilities or stat growth")

		return {valid = errors.is_empty(), errors = errors, warnings = warnings}


# =============================================================================
# TEST FIXTURES
# =============================================================================

var _mock: MockCharacterEditorState


func before_test() -> void:
	_mock = MockCharacterEditorState.new()


func after_test() -> void:
	_mock = null


# =============================================================================
# HELPER METHODS
# =============================================================================

func _setup_valid_enemy() -> void:
	_mock.current_resource = CharacterData.new()
	_mock.name_text = "Goblin"
	_mock.level_value = 1
	_mock.category_selected = "enemy"
	_mock.selected_class = null


func _setup_valid_player_with_class() -> void:
	_mock.current_resource = CharacterData.new()
	_mock.name_text = "Hero"
	_mock.level_value = 1
	_mock.category_selected = "player"
	_mock.selected_class = ClassData.new()


# =============================================================================
# VALIDATION - EMPTY NAME TESTS
# =============================================================================

func test_validate_empty_name_fails() -> void:
	_mock.current_resource = CharacterData.new()
	_mock.name_text = ""
	_mock.level_value = 1
	_mock.category_selected = "enemy"

	var result: Dictionary = _mock.validate_resource()

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
	_mock.current_resource = CharacterData.new()
	_mock.name_text = "   "  # Only whitespace
	_mock.level_value = 1
	_mock.category_selected = "enemy"

	var result: Dictionary = _mock.validate_resource()

	assert_bool(result.valid).is_false()


func test_validate_valid_name_passes() -> void:
	_setup_valid_enemy()
	_mock.name_text = "Hero"

	var result: Dictionary = _mock.validate_resource()

	assert_bool(result.valid).is_true()


# =============================================================================
# VALIDATION - LEVEL TESTS
# =============================================================================

func test_validate_level_zero_fails() -> void:
	_setup_valid_enemy()
	_mock.level_value = 0

	var result: Dictionary = _mock.validate_resource()

	assert_bool(result.valid).is_false()
	var has_level_error: bool = false
	for error: String in result.errors:
		if "level" in error.to_lower():
			has_level_error = true
			break
	assert_bool(has_level_error).is_true()


func test_validate_level_100_fails() -> void:
	_setup_valid_enemy()
	_mock.level_value = 100

	var result: Dictionary = _mock.validate_resource()

	assert_bool(result.valid).is_false()


func test_validate_level_1_passes() -> void:
	_setup_valid_enemy()
	_mock.level_value = 1

	var result: Dictionary = _mock.validate_resource()

	assert_bool(result.valid).is_true()


func test_validate_level_99_passes() -> void:
	_setup_valid_enemy()
	_mock.level_value = 99

	var result: Dictionary = _mock.validate_resource()

	assert_bool(result.valid).is_true()


# =============================================================================
# VALIDATION - CLASS REQUIREMENT TESTS
# =============================================================================

func test_validate_player_without_class_fails() -> void:
	_mock.current_resource = CharacterData.new()
	_mock.name_text = "Hero"
	_mock.level_value = 1
	_mock.category_selected = "player"
	_mock.selected_class = null

	var result: Dictionary = _mock.validate_resource()

	assert_bool(result.valid).is_false()
	# Error should mention class
	var has_class_error: bool = false
	for error: String in result.errors:
		if "class" in error.to_lower():
			has_class_error = true
			break
	assert_bool(has_class_error).is_true()


func test_validate_player_with_class_passes() -> void:
	_setup_valid_player_with_class()

	var result: Dictionary = _mock.validate_resource()

	assert_bool(result.valid).is_true()


func test_validate_enemy_without_class_passes_with_warning() -> void:
	_mock.current_resource = CharacterData.new()
	_mock.name_text = "Goblin"
	_mock.level_value = 1
	_mock.category_selected = "enemy"
	_mock.selected_class = null

	var result: Dictionary = _mock.validate_resource()

	# Should be valid (enemies don't require class)
	assert_bool(result.valid).is_true()
	# But should have warning
	var warnings: Array = result.get("warnings", [])
	assert_bool(warnings.size() > 0).is_true()


func test_validate_neutral_without_class_passes_with_warning() -> void:
	_mock.current_resource = CharacterData.new()
	_mock.name_text = "Villager"
	_mock.level_value = 1
	_mock.category_selected = "neutral"
	_mock.selected_class = null

	var result: Dictionary = _mock.validate_resource()

	assert_bool(result.valid).is_true()
	var warnings: Array = result.get("warnings", [])
	assert_bool(warnings.size() > 0).is_true()


# =============================================================================
# REGRESSION TEST - UI STATE VS RESOURCE STATE
# This is the core bug that was fixed in commit 95987a0
# =============================================================================

func test_validation_uses_ui_state_not_resource_state() -> void:
	# Create a resource with VALID data
	var char_data: CharacterData = CharacterData.new()
	char_data.character_name = "Valid Name From Resource"
	char_data.starting_level = 5
	_mock.current_resource = char_data

	# But set UI state to INVALID (empty name)
	_mock.name_text = ""
	_mock.level_value = 1
	_mock.category_selected = "enemy"

	# Validation should FAIL because it checks UI state
	var result: Dictionary = _mock.validate_resource()

	# If this fails, validation is checking resource state (the old bug)
	assert_bool(result.valid).is_false()


func test_validation_reads_name_from_ui_not_resource() -> void:
	# Resource has one name
	var char_data: CharacterData = CharacterData.new()
	char_data.character_name = "Resource Name"
	_mock.current_resource = char_data

	# UI has different name
	_mock.name_text = "UI Name"
	_mock.level_value = 1
	_mock.category_selected = "enemy"

	# Should validate successfully using UI name
	var result: Dictionary = _mock.validate_resource()
	assert_bool(result.valid).is_true()

	# Now clear UI name (resource still has valid name)
	_mock.name_text = ""

	# Should fail because UI name is empty
	result = _mock.validate_resource()
	assert_bool(result.valid).is_false()


func test_validation_reads_level_from_ui_not_resource() -> void:
	# Resource has valid level
	var char_data: CharacterData = CharacterData.new()
	char_data.starting_level = 50
	_mock.current_resource = char_data

	_mock.name_text = "Hero"
	_mock.category_selected = "enemy"

	# UI has level 1 (valid)
	_mock.level_value = 1

	var result: Dictionary = _mock.validate_resource()
	assert_bool(result.valid).is_true()

	# UI has level 0 (invalid) - resource still has 50
	_mock.level_value = 0

	result = _mock.validate_resource()
	assert_bool(result.valid).is_false()


func test_validation_reads_category_from_ui_not_resource() -> void:
	# Resource is player
	var char_data: CharacterData = CharacterData.new()
	char_data.unit_category = "player"
	_mock.current_resource = char_data

	_mock.name_text = "Goblin"
	_mock.level_value = 1
	_mock.selected_class = null

	# UI says enemy (so class not required)
	_mock.category_selected = "enemy"

	# Should pass because UI category is "enemy"
	var result: Dictionary = _mock.validate_resource()
	assert_bool(result.valid).is_true()

	# Now change UI to player (class required)
	_mock.category_selected = "player"

	# Should fail because UI category is "player" and no class selected
	result = _mock.validate_resource()
	assert_bool(result.valid).is_false()


# =============================================================================
# NULL RESOURCE TESTS
# =============================================================================

func test_validate_null_resource_fails() -> void:
	_mock.current_resource = null

	var result: Dictionary = _mock.validate_resource()

	assert_bool(result.valid).is_false()


func test_validate_wrong_resource_type_fails() -> void:
	# Set a non-CharacterData resource
	_mock.current_resource = Resource.new()

	var result: Dictionary = _mock.validate_resource()

	assert_bool(result.valid).is_false()
