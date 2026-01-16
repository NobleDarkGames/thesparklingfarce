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


const TEST_MOD_ID: String = "_test_party_manager"

# Signal tracking
var _member_added_events: Array[CharacterData] = []
var _member_departed_events: Array[Dictionary] = []
var _member_rejoined_events: Array[String] = []
var _item_transferred_events: Array[Dictionary] = []
var _inventory_changed_events: Array[String] = []

# Resources to clean up
var _created_characters: Array[CharacterData] = []
var _created_classes: Array[ClassData] = []
var _created_items: Array[ItemData] = []

# Store original state
var _original_party_members: Array[CharacterData]
var _original_max_active_size: int


func before() -> void:
	# Store original state
	_original_party_members = PartyManager.party_members.duplicate()
	_original_max_active_size = PartyManager.MAX_ACTIVE_SIZE

	# Clear signal tracking
	_member_added_events.clear()
	_member_departed_events.clear()
	_member_rejoined_events.clear()
	_item_transferred_events.clear()
	_inventory_changed_events.clear()

	# Connect signals
	PartyManager.member_added.connect(_on_member_added)
	PartyManager.member_departed.connect(_on_member_departed)
	PartyManager.member_rejoined.connect(_on_member_rejoined)
	PartyManager.item_transferred.connect(_on_item_transferred)
	PartyManager.member_inventory_changed.connect(_on_inventory_changed)


func after() -> void:
	# Disconnect signals
	if PartyManager.member_added.is_connected(_on_member_added):
		PartyManager.member_added.disconnect(_on_member_added)
	if PartyManager.member_departed.is_connected(_on_member_departed):
		PartyManager.member_departed.disconnect(_on_member_departed)
	if PartyManager.member_rejoined.is_connected(_on_member_rejoined):
		PartyManager.member_rejoined.disconnect(_on_member_rejoined)
	if PartyManager.item_transferred.is_connected(_on_item_transferred):
		PartyManager.item_transferred.disconnect(_on_item_transferred)
	if PartyManager.member_inventory_changed.is_connected(_on_inventory_changed):
		PartyManager.member_inventory_changed.disconnect(_on_inventory_changed)

	# Restore original state
	PartyManager.party_members = _original_party_members
	PartyManager.MAX_ACTIVE_SIZE = _original_max_active_size

	# Clean up test items from registry
	if ModLoader and ModLoader.registry:
		ModLoader.registry.clear_mod_resources(TEST_MOD_ID)

	# Clean up resources
	_created_characters.clear()
	_created_classes.clear()
	_created_items.clear()


func before_test() -> void:
	# Clear signal events
	_member_added_events.clear()
	_member_departed_events.clear()
	_member_rejoined_events.clear()
	_item_transferred_events.clear()
	_inventory_changed_events.clear()

	# Clear party state for each test
	PartyManager.clear_party()
	PartyManager.clear_departed()
	PartyManager.MAX_ACTIVE_SIZE = PartyManager.DEFAULT_MAX_ACTIVE_SIZE


# =============================================================================
# TEST: Basic Party Management
# =============================================================================

func test_add_member_succeeds() -> void:
	var hero: CharacterData = _create_character("Hero", true)

	var result: bool = PartyManager.add_member(hero)

	assert_bool(result).is_true()
	assert_int(PartyManager.get_party_size()).is_equal(1)
	assert_int(_member_added_events.size()).is_equal(1)


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
	assert_int(_member_departed_events.size()).is_equal(1)
	assert_str(_member_departed_events[0].reason).is_equal("left")


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
	assert_int(_member_rejoined_events.size()).is_equal(1)


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
	assert_int(_inventory_changed_events.size()).is_equal(1)


func test_remove_item_from_member() -> void:
	var hero: CharacterData = _create_character("Hero", true)
	PartyManager.add_member(hero)

	var item: ItemData = _create_and_register_item("test_potion")
	var uid: String = hero.get_uid()

	PartyManager.add_item_to_member(uid, "test_potion")
	_inventory_changed_events.clear()

	var result: bool = PartyManager.remove_item_from_member(uid, "test_potion")

	assert_bool(result).is_true()
	assert_int(_inventory_changed_events.size()).is_equal(1)


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
	assert_int(_item_transferred_events.size()).is_equal(1)


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
# SIGNAL HANDLERS
# =============================================================================

func _on_member_added(character: CharacterData) -> void:
	_member_added_events.append(character)


func _on_member_departed(character_uid: String, reason: String) -> void:
	_member_departed_events.append({"uid": character_uid, "reason": reason})


func _on_member_rejoined(character_uid: String) -> void:
	_member_rejoined_events.append(character_uid)


func _on_item_transferred(from_uid: String, to_uid: String, item_id: String) -> void:
	_item_transferred_events.append({
		"from": from_uid,
		"to": to_uid,
		"item": item_id
	})


func _on_inventory_changed(character_uid: String) -> void:
	_inventory_changed_events.append(character_uid)


# =============================================================================
# TEST FIXTURES
# =============================================================================

func _create_character(p_name: String, is_hero: bool = false) -> CharacterData:
	var character: CharacterData = CharacterData.new()
	character.character_name = p_name
	character.base_hp = 50
	character.base_mp = 10
	character.base_strength = 10
	character.base_defense = 10
	character.base_agility = 10
	character.base_intelligence = 10
	character.base_luck = 5
	character.starting_level = 1
	character.is_hero = is_hero
	character.ensure_uid()

	var basic_class: ClassData = ClassData.new()
	basic_class.display_name = "Warrior"
	basic_class.movement_type = ClassData.MovementType.WALKING
	basic_class.movement_range = 4

	character.character_class = basic_class

	_created_characters.append(character)
	_created_classes.append(basic_class)

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
