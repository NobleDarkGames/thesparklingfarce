## Unit Tests for InteractableData Resource
##
## Tests InteractableData validation, state tracking, and message utilities.
class_name TestInteractableData
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

var _interactable: InteractableData


func before_test() -> void:
	_interactable = InteractableData.new()
	_interactable.interactable_id = "test_chest"
	_interactable.display_name = "Test Chest"
	_interactable.interactable_type = InteractableData.InteractableType.CHEST
	_interactable.gold_reward = 50


func after_test() -> void:
	if _interactable:
		_interactable = null
	# Clean up any flags we set
	if GameState:
		GameState.story_flags.erase("test_chest_opened")
		GameState.story_flags.erase("custom_flag")
		GameState.story_flags.erase("required_flag")
		GameState.story_flags.erase("forbidden_flag")


# =============================================================================
# VALIDATION TESTS
# =============================================================================

func test_validation_requires_interactable_id() -> void:
	_interactable.interactable_id = ""

	var result: bool = _interactable.validate()

	assert_bool(result).is_false()


func test_validation_requires_interaction_content() -> void:
	_interactable.gold_reward = 0
	_interactable.item_rewards = []
	_interactable.interaction_cinematic_id = ""
	_interactable.fallback_cinematic_id = ""
	_interactable.conditional_cinematics = []

	var result: bool = _interactable.validate()

	assert_bool(result).is_false()


func test_validation_passes_with_gold_reward() -> void:
	_interactable.gold_reward = 100

	var result: bool = _interactable.validate()

	assert_bool(result).is_true()


func test_validation_passes_with_item_rewards() -> void:
	_interactable.gold_reward = 0
	_interactable.item_rewards = [{"item_id": "healing_herb", "quantity": 1}]

	var result: bool = _interactable.validate()

	assert_bool(result).is_true()


func test_validation_passes_with_fallback_cinematic() -> void:
	_interactable.gold_reward = 0
	_interactable.fallback_cinematic_id = "sign_cinematic"

	var result: bool = _interactable.validate()

	assert_bool(result).is_true()


func test_validation_passes_with_cinematic_id() -> void:
	_interactable.gold_reward = 0
	_interactable.interaction_cinematic_id = "chest_open_cinematic"

	var result: bool = _interactable.validate()

	assert_bool(result).is_true()


# =============================================================================
# STATE TRACKING TESTS
# =============================================================================

func test_completion_flag_auto_generates() -> void:
	_interactable.completion_flag = ""

	var flag: String = _interactable.get_completion_flag()

	assert_str(flag).is_equal("test_chest_opened")


func test_completion_flag_uses_custom_when_set() -> void:
	_interactable.completion_flag = "custom_flag"

	var flag: String = _interactable.get_completion_flag()

	assert_str(flag).is_equal("custom_flag")


func test_is_opened_returns_false_when_flag_not_set() -> void:
	_interactable.one_shot = true

	var result: bool = _interactable.is_opened()

	assert_bool(result).is_false()


func test_is_opened_returns_true_when_flag_set() -> void:
	_interactable.one_shot = true
	GameState.set_flag("test_chest_opened")

	var result: bool = _interactable.is_opened()

	assert_bool(result).is_true()


func test_is_opened_always_false_for_repeatable() -> void:
	_interactable.one_shot = false
	GameState.set_flag("test_chest_opened")

	var result: bool = _interactable.is_opened()

	assert_bool(result).is_false()


func test_mark_opened_sets_flag_for_one_shot() -> void:
	_interactable.one_shot = true

	_interactable.mark_opened()

	assert_bool(GameState.has_flag("test_chest_opened")).is_true()


func test_mark_opened_does_nothing_for_repeatable() -> void:
	_interactable.one_shot = false

	_interactable.mark_opened()

	assert_bool(GameState.has_flag("test_chest_opened")).is_false()


# =============================================================================
# CAN_INTERACT TESTS
# =============================================================================

func test_can_interact_returns_true_by_default() -> void:
	var result: Dictionary = _interactable.can_interact()

	assert_bool(result.get("can_interact", false)).is_true()


func test_can_interact_fails_when_already_opened() -> void:
	_interactable.one_shot = true
	GameState.set_flag("test_chest_opened")

	var result: Dictionary = _interactable.can_interact()

	assert_bool(result.get("can_interact", true)).is_false()
	assert_str(result.get("reason", "")).is_equal("already_opened")


func test_can_interact_fails_when_missing_required_flag() -> void:
	_interactable.required_flags = ["required_flag"]

	var result: Dictionary = _interactable.can_interact()

	assert_bool(result.get("can_interact", true)).is_false()
	assert_str(result.get("reason", "")).is_equal("missing_flag")


func test_can_interact_passes_when_required_flag_set() -> void:
	_interactable.required_flags = ["required_flag"]
	GameState.set_flag("required_flag")

	var result: Dictionary = _interactable.can_interact()

	assert_bool(result.get("can_interact", false)).is_true()


func test_can_interact_fails_when_forbidden_flag_set() -> void:
	_interactable.forbidden_flags = ["forbidden_flag"]
	GameState.set_flag("forbidden_flag")

	var result: Dictionary = _interactable.can_interact()

	assert_bool(result.get("can_interact", true)).is_false()
	assert_str(result.get("reason", "")).is_equal("forbidden_flag")


# =============================================================================
# REWARDS TESTS
# =============================================================================

func test_has_rewards_true_with_gold() -> void:
	_interactable.gold_reward = 100
	_interactable.item_rewards = []

	var result: bool = _interactable.has_rewards()

	assert_bool(result).is_true()


func test_has_rewards_true_with_items() -> void:
	_interactable.gold_reward = 0
	_interactable.item_rewards = [{"item_id": "sword"}]

	var result: bool = _interactable.has_rewards()

	assert_bool(result).is_true()


func test_has_rewards_false_when_empty() -> void:
	_interactable.gold_reward = 0
	_interactable.item_rewards = []

	var result: bool = _interactable.has_rewards()

	assert_bool(result).is_false()


# =============================================================================
# DEFAULT MESSAGE TESTS
# =============================================================================

func test_default_empty_message_for_chest() -> void:
	var msg: String = InteractableData.get_default_empty_message(InteractableData.InteractableType.CHEST)

	assert_str(msg).is_equal("The chest is empty.")


func test_default_empty_message_for_bookshelf() -> void:
	var msg: String = InteractableData.get_default_empty_message(InteractableData.InteractableType.BOOKSHELF)

	assert_str(msg).is_equal("Dusty tomes line the shelves...")


func test_default_empty_message_for_barrel() -> void:
	var msg: String = InteractableData.get_default_empty_message(InteractableData.InteractableType.BARREL)

	assert_str(msg).is_equal("There's nothing inside.")


func test_default_empty_message_for_sign() -> void:
	var msg: String = InteractableData.get_default_empty_message(InteractableData.InteractableType.SIGN)

	assert_str(msg).is_equal("The sign is blank.")


func test_default_empty_message_for_lever() -> void:
	var msg: String = InteractableData.get_default_empty_message(InteractableData.InteractableType.LEVER)

	assert_str(msg).is_equal("A rusty lever.")


func test_default_empty_message_fallback_for_custom() -> void:
	var msg: String = InteractableData.get_default_empty_message(InteractableData.InteractableType.CUSTOM)

	assert_str(msg).is_equal("There's nothing here.")


func test_already_opened_message_for_chest() -> void:
	var msg: String = InteractableData.get_already_opened_message(InteractableData.InteractableType.CHEST)

	assert_str(msg).is_equal("The chest has already been opened.")


func test_already_opened_message_for_barrel() -> void:
	var msg: String = InteractableData.get_already_opened_message(InteractableData.InteractableType.BARREL)

	assert_str(msg).is_equal("You've already searched this.")


func test_already_opened_message_fallback() -> void:
	var msg: String = InteractableData.get_already_opened_message(InteractableData.InteractableType.BOOKSHELF)

	assert_str(msg).is_equal("There's nothing more here.")


# =============================================================================
# CINEMATIC ID TESTS
# =============================================================================

func test_get_cinematic_id_returns_explicit_when_set() -> void:
	_interactable.interaction_cinematic_id = "custom_cinematic"

	var result: String = _interactable.get_cinematic_id_for_state()

	assert_str(result).is_equal("custom_cinematic")


func test_get_cinematic_id_returns_fallback_when_no_explicit() -> void:
	_interactable.interaction_cinematic_id = ""
	_interactable.fallback_cinematic_id = "fallback_cinematic"

	var result: String = _interactable.get_cinematic_id_for_state()

	assert_str(result).is_equal("fallback_cinematic")


func test_get_cinematic_id_returns_auto_when_no_cinematics() -> void:
	_interactable.interaction_cinematic_id = ""
	_interactable.fallback_cinematic_id = ""

	var result: String = _interactable.get_cinematic_id_for_state()

	assert_str(result).is_equal("__auto_interactable__test_chest")


# =============================================================================
# SPRITE TESTS
# =============================================================================

func test_get_current_sprite_returns_closed_when_not_opened() -> void:
	var closed_texture: Texture2D = PlaceholderTexture2D.new()
	var opened_texture: Texture2D = PlaceholderTexture2D.new()
	_interactable.sprite_closed = closed_texture
	_interactable.sprite_opened = opened_texture
	_interactable.one_shot = true

	var result: Texture2D = _interactable.get_current_sprite()

	assert_object(result).is_equal(closed_texture)


func test_get_current_sprite_returns_opened_when_opened() -> void:
	var closed_texture: Texture2D = PlaceholderTexture2D.new()
	var opened_texture: Texture2D = PlaceholderTexture2D.new()
	_interactable.sprite_closed = closed_texture
	_interactable.sprite_opened = opened_texture
	_interactable.one_shot = true
	GameState.set_flag("test_chest_opened")

	var result: Texture2D = _interactable.get_current_sprite()

	assert_object(result).is_equal(opened_texture)


func test_get_current_sprite_returns_closed_when_no_opened_sprite() -> void:
	var closed_texture: Texture2D = PlaceholderTexture2D.new()
	_interactable.sprite_closed = closed_texture
	_interactable.sprite_opened = null
	_interactable.one_shot = true
	GameState.set_flag("test_chest_opened")

	var result: Texture2D = _interactable.get_current_sprite()

	assert_object(result).is_equal(closed_texture)
