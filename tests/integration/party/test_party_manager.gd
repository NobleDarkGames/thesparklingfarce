## PartyManager Integration Test
##
## Tests the PartyManager autoload functionality:
## - Party member management (add, remove, clear)
## - Active/reserve roster (Caravan system)
## - Hero position protection
## - Departed member handling
## - Inventory operations
## - Save data management
class_name TestPartyManager
extends GdUnitTestSuite


const CharacterFactoryScript = preload("res://tests/fixtures/character_factory.gd")
const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")
const TEST_MOD_ID: String = "_test_party_manager"

# Signal tracking
var _tracker: RefCounted

# Resources to clean up
var _created_characters: Array[CharacterData] = []
var _created_items: Array[ItemData] = []

# Store original state
var _original_party_members: Array[CharacterData]
var _original_max_active_size: int


func before() -> void:
	# Store original state
	_original_party_members = PartyManager.party_members.duplicate()
	_original_max_active_size = PartyManager.MAX_ACTIVE_SIZE


func after() -> void:
	# Restore original state
	PartyManager.party_members = _original_party_members
	PartyManager.MAX_ACTIVE_SIZE = _original_max_active_size

	# Clean up test items from registry
	if ModLoader and ModLoader.registry:
		ModLoader.registry.clear_mod_resources(TEST_MOD_ID)

	# Clean up resources
	_created_characters.clear()
	_created_items.clear()


func before_test() -> void:
	# Initialize signal tracker
	_tracker = SignalTrackerScript.new()

	# Track PartyManager signals
	_tracker.track(PartyManager.member_added)
	_tracker.track(PartyManager.member_departed)
	_tracker.track(PartyManager.member_rejoined)
	_tracker.track(PartyManager.item_transferred)
	_tracker.track(PartyManager.member_inventory_changed)

	# Clear party state for each test
	PartyManager.clear_party()
	PartyManager.clear_departed()
	PartyManager.MAX_ACTIVE_SIZE = PartyManager.DEFAULT_MAX_ACTIVE_SIZE


func after_test() -> void:
	# Disconnect signal tracker
	if _tracker:
		_tracker.disconnect_all()
		_tracker = null


# =============================================================================
# TEST: Basic Party Management
# =============================================================================

func test_add_member_succeeds() -> void:
	var hero: CharacterData = _create_character("Hero", true)

	var result: bool = PartyManager.add_member(hero)

	assert_bool(result).is_true()
	assert_int(PartyManager.get_party_size()).is_equal(1)
	assert_int(_tracker.emission_count("member_added")).is_equal(1)


func test_remove_member_succeeds() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	var warrior: CharacterData = _create_character("Warrior", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(warrior)

	var result: bool = PartyManager.remove_member(warrior)

	assert_bool(result).is_true()
	assert_int(PartyManager.get_party_size()).is_equal(1)


func test_cannot_remove_hero() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	PartyManager.add_member(hero)

	var result: bool = PartyManager.remove_member(hero)

	assert_bool(result).is_false()
	assert_int(PartyManager.get_party_size()).is_equal(1)


func test_remove_nonexistent_member_fails() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	var other: CharacterData = _create_character("Other", false)

	PartyManager.add_member(hero)

	var result: bool = PartyManager.remove_member(other)

	assert_bool(result).is_false()


func test_clear_party() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	var warrior: CharacterData = _create_character("Warrior", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(warrior)

	PartyManager.clear_party()

	assert_int(PartyManager.get_party_size()).is_equal(0)
	assert_bool(PartyManager.is_empty()).is_true()


func test_get_party_size() -> void:
	assert_int(PartyManager.get_party_size()).is_equal(0)

	var hero: CharacterData = _create_character("Hero", true)
	PartyManager.add_member(hero)

	assert_int(PartyManager.get_party_size()).is_equal(1)


func test_is_empty() -> void:
	assert_bool(PartyManager.is_empty()).is_true()

	var hero: CharacterData = _create_character("Hero", true)
	PartyManager.add_member(hero)

	assert_bool(PartyManager.is_empty()).is_false()


func test_get_leader_returns_first_member() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	var warrior: CharacterData = _create_character("Warrior", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(warrior)

	var leader: CharacterData = PartyManager.get_leader()

	assert_object(leader).is_same(hero)


func test_get_leader_returns_null_when_empty() -> void:
	var leader: CharacterData = PartyManager.get_leader()

	assert_object(leader).is_null()


# =============================================================================
# TEST: Hero Management
# =============================================================================

func test_hero_is_always_at_position_zero() -> void:
	var warrior: CharacterData = _create_character("Warrior", false)
	var hero: CharacterData = _create_character("Hero", true)

	# Add warrior first, then hero
	PartyManager.add_member(warrior)
	PartyManager.add_member(hero)

	# Hero should be moved to front
	PartyManager._ensure_hero_is_leader()

	assert_object(PartyManager.party_members[0]).is_same(hero)


func test_has_hero() -> void:
	assert_bool(PartyManager.has_hero()).is_false()

	var hero: CharacterData = _create_character("Hero", true)
	PartyManager.add_member(hero)

	assert_bool(PartyManager.has_hero()).is_true()


func test_get_hero() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	var warrior: CharacterData = _create_character("Warrior", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(warrior)

	var found_hero: CharacterData = PartyManager.get_hero()

	assert_object(found_hero).is_same(hero)


func test_get_hero_returns_null_when_no_hero() -> void:
	var warrior: CharacterData = _create_character("Warrior", false)
	PartyManager.add_member(warrior)

	var found_hero: CharacterData = PartyManager.get_hero()

	assert_object(found_hero).is_null()


# =============================================================================
# TEST: Active/Reserve Roster
# =============================================================================

func test_get_active_party() -> void:
	PartyManager.MAX_ACTIVE_SIZE = 3

	var hero: CharacterData = _create_character("Hero", true)
	var member2: CharacterData = _create_character("Member2", false)
	var member3: CharacterData = _create_character("Member3", false)
	var member4: CharacterData = _create_character("Member4", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(member2)
	PartyManager.add_member(member3)
	PartyManager.add_member(member4)

	var active: Array[CharacterData] = PartyManager.get_active_party()

	assert_int(active.size()).is_equal(3)


func test_get_reserve_party() -> void:
	PartyManager.MAX_ACTIVE_SIZE = 2

	var hero: CharacterData = _create_character("Hero", true)
	var member2: CharacterData = _create_character("Member2", false)
	var member3: CharacterData = _create_character("Member3", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(member2)
	PartyManager.add_member(member3)

	var reserve: Array[CharacterData] = PartyManager.get_reserve_party()

	assert_int(reserve.size()).is_equal(1)


func test_is_active_party_full() -> void:
	PartyManager.MAX_ACTIVE_SIZE = 2

	var hero: CharacterData = _create_character("Hero", true)
	PartyManager.add_member(hero)

	assert_bool(PartyManager.is_active_party_full()).is_false()

	var member2: CharacterData = _create_character("Member2", false)
	PartyManager.add_member(member2)

	assert_bool(PartyManager.is_active_party_full()).is_true()


func test_demote_to_reserve() -> void:
	PartyManager.MAX_ACTIVE_SIZE = 2

	var hero: CharacterData = _create_character("Hero", true)
	var member2: CharacterData = _create_character("Member2", false)
	var member3: CharacterData = _create_character("Member3", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(member2)
	PartyManager.add_member(member3)  # Goes to reserve (3rd member, MAX=2)

	# Initial state: 2 active (hero, member2), 1 reserve (member3)
	assert_int(PartyManager.get_active_count()).is_equal(2)
	assert_int(PartyManager.get_reserve_count()).is_equal(1)

	# Demote member2 (index 1) to reserves
	var result: Dictionary = PartyManager.demote_to_reserve(1)

	assert_bool(result.success).is_true()
	# After demote: [hero, member3, member2] - hero active, member3 active, member2 reserve
	# Wait no - demote moves to END, so:
	# Before: [hero, member2, member3]
	# remove_at(1): [hero, member3]
	# append(member2): [hero, member3, member2]
	# Now with MAX=2: 2 active (hero, member3), 1 reserve (member2)
	assert_int(PartyManager.get_active_count()).is_equal(2)
	assert_int(PartyManager.get_reserve_count()).is_equal(1)
	# member2 should now be in reserve (at end)
	var reserve: Array[CharacterData] = PartyManager.get_reserve_party()
	assert_object(reserve[0]).is_same(member2)


func test_cannot_demote_hero() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	var member2: CharacterData = _create_character("Member2", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(member2)

	var result: Dictionary = PartyManager.demote_to_reserve(0)

	assert_bool(result.success).is_false()
	assert_str(result.error).contains("hero")


func test_swap_within_active() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	var member2: CharacterData = _create_character("Member2", false)
	var member3: CharacterData = _create_character("Member3", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(member2)
	PartyManager.add_member(member3)

	# Swap positions 1 and 2
	var result: Dictionary = PartyManager.swap_within_active(1, 2)

	assert_bool(result.success).is_true()
	assert_object(PartyManager.party_members[1]).is_same(member3)
	assert_object(PartyManager.party_members[2]).is_same(member2)


func test_cannot_swap_hero_position() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	var member2: CharacterData = _create_character("Member2", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(member2)

	var result: Dictionary = PartyManager.swap_within_active(0, 1)

	assert_bool(result.success).is_false()
	assert_str(result.error).contains("hero")


# =============================================================================
# TEST: Departed Members
# =============================================================================

func test_remove_member_preserve_data() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	var warrior: CharacterData = _create_character("Warrior", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(warrior)

	var preserved: CharacterSaveData = PartyManager.remove_member_preserve_data(warrior, "left")

	assert_object(preserved).is_not_null()
	assert_int(PartyManager.get_party_size()).is_equal(1)
	assert_int(_tracker.emission_count("member_departed")).is_equal(1)
	# Verify signal was emitted with correct reason
	var emissions: Array = _tracker.get_emissions("member_departed")
	assert_str(emissions[0].arguments[1]).is_equal("left")


func test_is_departed() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	var warrior: CharacterData = _create_character("Warrior", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(warrior)

	var uid: String = warrior.get_uid()
	assert_bool(PartyManager.is_departed(uid)).is_false()

	PartyManager.remove_member_preserve_data(warrior, "died")

	assert_bool(PartyManager.is_departed(uid)).is_true()


func test_rejoin_departed_member() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	var warrior: CharacterData = _create_character("Warrior", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(warrior)

	PartyManager.remove_member_preserve_data(warrior, "left")
	assert_int(PartyManager.get_party_size()).is_equal(1)

	var result: bool = PartyManager.rejoin_departed_member(warrior)

	assert_bool(result).is_true()
	assert_int(PartyManager.get_party_size()).is_equal(2)
	assert_int(_tracker.emission_count("member_rejoined")).is_equal(1)


func test_rejoin_nonexistent_departed_fails() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	var warrior: CharacterData = _create_character("Warrior", false)

	PartyManager.add_member(hero)

	var result: bool = PartyManager.rejoin_departed_member(warrior)

	assert_bool(result).is_false()


func test_get_departed_save_data() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	var warrior: CharacterData = _create_character("Warrior", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(warrior)

	var uid: String = warrior.get_uid()
	PartyManager.remove_member_preserve_data(warrior, "captured")

	var departed_data: CharacterSaveData = PartyManager.get_departed_save_data(uid)

	assert_object(departed_data).is_not_null()


# =============================================================================
# TEST: Max Active Size
# =============================================================================

func test_set_max_active_size() -> void:
	var new_size: int = PartyManager.set_max_active_size(8)

	assert_int(new_size).is_equal(8)
	assert_int(PartyManager.get_max_active_size()).is_equal(8)


func test_set_max_active_size_clamped() -> void:
	# Below minimum
	var too_small: int = PartyManager.set_max_active_size(0)
	assert_int(too_small).is_equal(PartyManager.MIN_ACTIVE_SIZE)

	# Above maximum
	var too_large: int = PartyManager.set_max_active_size(100)
	assert_int(too_large).is_equal(PartyManager.ABSOLUTE_MAX_ACTIVE_SIZE)


func test_reset_max_active_size() -> void:
	PartyManager.set_max_active_size(5)
	PartyManager.reset_max_active_size()

	assert_int(PartyManager.get_max_active_size()).is_equal(PartyManager.DEFAULT_MAX_ACTIVE_SIZE)


func test_get_available_active_slots() -> void:
	PartyManager.MAX_ACTIVE_SIZE = 5

	var hero: CharacterData = _create_character("Hero", true)
	var member2: CharacterData = _create_character("Member2", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(member2)

	assert_int(PartyManager.get_available_active_slots()).is_equal(3)


# =============================================================================
# TEST: Inventory Operations
# =============================================================================

func test_add_item_to_member() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	PartyManager.add_member(hero)

	var item: ItemData = _create_and_register_item("test_sword")
	var uid: String = hero.get_uid()

	var result: bool = PartyManager.add_item_to_member(uid, "test_sword")

	assert_bool(result).is_true()
	assert_int(_tracker.emission_count("member_inventory_changed")).is_equal(1)


func test_remove_item_from_member() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	PartyManager.add_member(hero)

	var item: ItemData = _create_and_register_item("test_potion")
	var uid: String = hero.get_uid()

	PartyManager.add_item_to_member(uid, "test_potion")
	_tracker.clear_emissions()

	var result: bool = PartyManager.remove_item_from_member(uid, "test_potion")

	assert_bool(result).is_true()
	assert_int(_tracker.emission_count("member_inventory_changed")).is_equal(1)


func test_transfer_item_between_members() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	var warrior: CharacterData = _create_character("Warrior", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(warrior)

	var item: ItemData = _create_and_register_item("transfer_item")
	var hero_uid: String = hero.get_uid()
	var warrior_uid: String = warrior.get_uid()

	PartyManager.add_item_to_member(hero_uid, "transfer_item")

	var result: Dictionary = PartyManager.transfer_item_between_members(hero_uid, warrior_uid, "transfer_item")

	assert_bool(result.success).is_true()
	assert_int(_tracker.emission_count("item_transferred")).is_equal(1)


func test_transfer_item_fails_for_nonexistent_item() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	var warrior: CharacterData = _create_character("Warrior", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(warrior)

	var hero_uid: String = hero.get_uid()
	var warrior_uid: String = warrior.get_uid()

	var result: Dictionary = PartyManager.transfer_item_between_members(hero_uid, warrior_uid, "nonexistent")

	assert_bool(result.success).is_false()


# =============================================================================
# TEST: Battle Spawn Data
# =============================================================================

func test_get_battle_spawn_data() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	var warrior: CharacterData = _create_character("Warrior", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(warrior)

	var spawn_data: Array[Dictionary] = PartyManager.get_battle_spawn_data(Vector2i(2, 2))

	assert_int(spawn_data.size()).is_equal(2)
	assert_object(spawn_data[0].character).is_same(hero)
	assert_object(spawn_data[1].character).is_same(warrior)


# =============================================================================
# TEST: Save Data Management
# =============================================================================

func test_get_member_save_data() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	PartyManager.add_member(hero)

	var uid: String = hero.get_uid()
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(uid)

	assert_object(save_data).is_not_null()


func test_get_member_save_data_for_invalid_uid_returns_null() -> void:
	var save_data: CharacterSaveData = PartyManager.get_member_save_data("nonexistent_uid")

	assert_object(save_data).is_null()


func test_export_to_save() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	var warrior: CharacterData = _create_character("Warrior", false)

	PartyManager.add_member(hero)
	PartyManager.add_member(warrior)

	var exported: Array[CharacterSaveData] = PartyManager.export_to_save()

	assert_int(exported.size()).is_equal(2)


# =============================================================================
# TEST FIXTURES
# =============================================================================

func _create_character(p_name: String, is_hero: bool = false) -> CharacterData:
	var character: CharacterData = CharacterFactoryScript.create_character(p_name, {
		"is_hero": is_hero,
		"ensure_uid": true
	})
	_created_characters.append(character)
	return character


func _create_and_register_item(item_id: String) -> ItemData:
	var item: ItemData = ItemData.new()
	item.item_name = item_id.capitalize()
	item.item_type = ItemData.ItemType.CONSUMABLE
	item.equipment_type = ""
	item.equipment_slot = ""

	ModLoader.registry.register_resource(item, "item", item_id, TEST_MOD_ID)
	_created_items.append(item)

	return item
