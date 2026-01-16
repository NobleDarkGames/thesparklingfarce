## Unit Tests for TriggerManager Key Item Checks
##
## Tests the _party_has_item function used for locked door verification.
class_name TestTriggerKeyItems
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

var _original_party_members: Array[CharacterData] = []
var _original_save_data: Dictionary = {}


func before_test() -> void:
	# Store original state
	if PartyManager:
		_original_party_members = PartyManager.party_members.duplicate()
		for character: CharacterData in PartyManager.party_members:
			var save_data: CharacterSaveData = PartyManager.get_member_save_data(character.character_uid)
			if save_data:
				_original_save_data[character.character_uid] = save_data.inventory.duplicate()


func after_test() -> void:
	# Restore original state
	if PartyManager:
		PartyManager.party_members = _original_party_members
		for uid: String in _original_save_data:
			var save_data: CharacterSaveData = PartyManager.get_member_save_data(uid)
			if save_data:
				save_data.inventory = _original_save_data[uid]
	_original_party_members.clear()
	_original_save_data.clear()


func _create_test_character(uid: String, name: String) -> CharacterData:
	var character: CharacterData = CharacterData.new()
	character.character_uid = uid
	character.character_name = name
	return character


func _create_test_save_data(uid: String) -> CharacterSaveData:
	var save_data: CharacterSaveData = CharacterSaveData.new()
	save_data.character_mod_id = "_test"
	save_data.character_resource_id = uid
	save_data.fallback_character_name = "Test"
	save_data.fallback_class_name = "Warrior"
	save_data.level = 1
	save_data.current_hp = 20
	save_data.max_hp = 20
	save_data.inventory = []
	return save_data


# =============================================================================
# PARTY HAS ITEM TESTS
# =============================================================================

func test_party_has_item_returns_false_when_no_party() -> void:
	# Clear party
	PartyManager.party_members.clear()

	var result: bool = TriggerManager._party_has_item("test_key")
	assert_bool(result).is_false()


func test_party_has_item_returns_false_when_item_not_present() -> void:
	# Set up party with character who doesn't have the item
	var character: CharacterData = _create_test_character("test_hero", "Test Hero")
	var save_data: CharacterSaveData = _create_test_save_data("test_hero")
	save_data.inventory = ["potion", "herb"]  # No key item

	PartyManager.party_members.clear()
	PartyManager.party_members.append(character)
	PartyManager._member_save_data["test_hero"] = save_data

	var result: bool = TriggerManager._party_has_item("brass_key")
	assert_bool(result).is_false()


func test_party_has_item_returns_true_when_hero_has_item() -> void:
	# Set up party with character who has the key item
	var character: CharacterData = _create_test_character("test_hero", "Test Hero")
	var save_data: CharacterSaveData = _create_test_save_data("test_hero")
	save_data.inventory = ["potion", "brass_key", "herb"]

	PartyManager.party_members.clear()
	PartyManager.party_members.append(character)
	PartyManager._member_save_data["test_hero"] = save_data

	var result: bool = TriggerManager._party_has_item("brass_key")
	assert_bool(result).is_true()


func test_party_has_item_checks_all_party_members() -> void:
	# Set up party with multiple characters - only second has key
	var hero: CharacterData = _create_test_character("test_hero", "Test Hero")
	var hero_save: CharacterSaveData = _create_test_save_data("test_hero")
	hero_save.inventory = ["potion"]  # No key

	var ally: CharacterData = _create_test_character("test_ally", "Test Ally")
	var ally_save: CharacterSaveData = _create_test_save_data("test_ally")
	ally_save.inventory = ["tower_key"]  # Has key

	PartyManager.party_members.clear()
	PartyManager.party_members.append(hero)
	PartyManager.party_members.append(ally)
	PartyManager._member_save_data["test_hero"] = hero_save
	PartyManager._member_save_data["test_ally"] = ally_save

	var result: bool = TriggerManager._party_has_item("tower_key")
	assert_bool(result).is_true()
