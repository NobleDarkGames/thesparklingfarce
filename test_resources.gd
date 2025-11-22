extends SceneTree

## Test script for validating Resource creation and serialization
## Run with: godot --headless --script test_resources.gd

const ClassData: GDScript = preload("res://core/resources/class_data.gd")
const ItemData: GDScript = preload("res://core/resources/item_data.gd")
const AbilityData: GDScript = preload("res://core/resources/ability_data.gd")
const CharacterData: GDScript = preload("res://core/resources/character_data.gd")
const BattleData: GDScript = preload("res://core/resources/battle_data.gd")
const DialogueData: GDScript = preload("res://core/resources/dialogue_data.gd")

var test_passed: int = 0
var test_failed: int = 0


func _initialize() -> void:
	print("============================================================")
	print("The Sparkling Farce - Resource Test Suite")
	print("============================================================")

	_test_class_data()
	_test_item_data()
	_test_ability_data()
	_test_character_data()
	_test_battle_data()
	_test_dialogue_data()
	_test_resource_serialization()

	print("============================================================")
	print("Test Results:")
	print("  Passed: ", test_passed)
	print("  Failed: ", test_failed)
	print("============================================================")

	if test_failed > 0:
		print("FAIL: Some tests failed!")
		quit(1)
	else:
		print("SUCCESS: All tests passed!")
		quit(0)


func _test_class_data() -> void:
	print("\n[TEST] ClassData")

	# Create a valid ClassData
	var warrior: ClassData = ClassData.new()
	warrior.class_name = "Warrior"
	warrior.movement_type = ClassData.MovementType.WALKING
	warrior.movement_range = 4
	warrior.equippable_weapon_types = ["sword", "axe"]
	warrior.equippable_armor_types = ["heavy"]

	_assert(warrior.validate(), "ClassData validation should pass")
	_assert(warrior.can_equip_weapon("sword"), "Warrior should equip sword")
	_assert(not warrior.can_equip_weapon("bow"), "Warrior should not equip bow")
	_assert(warrior.class_name == "Warrior", "Class name should match")

	# Test invalid ClassData
	var invalid_class: ClassData = ClassData.new()
	_assert(not invalid_class.validate(), "Empty ClassData should fail validation")

	print("  ✓ ClassData tests complete")


func _test_item_data() -> void:
	print("\n[TEST] ItemData")

	# Create a weapon
	var sword: ItemData = ItemData.new()
	sword.item_name = "Iron Sword"
	sword.item_type = ItemData.ItemType.WEAPON
	sword.equipment_type = "sword"
	sword.attack_power = 15
	sword.attack_range = 1
	sword.strength_modifier = 2

	_assert(sword.validate(), "Weapon validation should pass")
	_assert(sword.is_equippable(), "Weapon should be equippable")
	_assert(not sword.is_usable(), "Weapon should not be usable as consumable")
	_assert(sword.get_stat_modifier("strength") == 2, "Strength modifier should be 2")

	# Create a consumable
	var potion: ItemData = ItemData.new()
	potion.item_name = "Health Potion"
	potion.item_type = ItemData.ItemType.CONSUMABLE
	potion.usable_in_battle = true

	_assert(potion.validate(), "Consumable validation should pass")
	_assert(potion.is_usable(), "Potion should be usable")

	print("  ✓ ItemData tests complete")


func _test_ability_data() -> void:
	print("\n[TEST] AbilityData")

	# Create an attack ability
	var fireball: AbilityData = AbilityData.new()
	fireball.ability_name = "Fireball"
	fireball.ability_type = AbilityData.AbilityType.ATTACK
	fireball.target_type = AbilityData.TargetType.SINGLE_ENEMY
	fireball.min_range = 1
	fireball.max_range = 3
	fireball.mp_cost = 5
	fireball.power = 25

	_assert(fireball.validate(), "Ability validation should pass")
	_assert(fireball.can_target_enemies(), "Fireball should target enemies")
	_assert(not fireball.can_target_allies(), "Fireball should not target allies")
	_assert(fireball.is_in_range(2), "Distance 2 should be in range")
	_assert(not fireball.is_in_range(5), "Distance 5 should be out of range")
	_assert(fireball.get_cost_string() == "5 MP", "Cost string should be '5 MP'")

	# Test invalid ability
	var invalid_ability: AbilityData = AbilityData.new()
	invalid_ability.min_range = 5
	invalid_ability.max_range = 2
	_assert(not invalid_ability.validate(), "Invalid range should fail validation")

	print("  ✓ AbilityData tests complete")


func _test_character_data() -> void:
	print("\n[TEST] CharacterData")

	# Create a class first
	var warrior_class: ClassData = ClassData.new()
	warrior_class.display_name = "Warrior"
	warrior_class.movement_range = 4
	warrior_class.hp_growth = 80
	warrior_class.strength_growth = 60

	# Create a character
	var hero: CharacterData = CharacterData.new()
	hero.character_name = "Hero"
	hero.character_class = warrior_class
	hero.base_hp = 20
	hero.base_strength = 8
	hero.starting_level = 1

	_assert(hero.validate(), "Character validation should pass")
	_assert(hero.get_base_stat("base_hp") == 20, "Base HP should be 20")
	_assert(hero.character_class.get_growth_rate("hp") == 80, "HP growth should be 80 (from class)")

	# Test invalid character
	var invalid_char: CharacterData = CharacterData.new()
	_assert(not invalid_char.validate(), "Empty character should fail validation")

	print("  ✓ CharacterData tests complete")


func _test_battle_data() -> void:
	print("\n[TEST] BattleData")

	var battle: BattleData = BattleData.new()
	battle.battle_name = "Test Battle"
	battle.grid_width = 10
	battle.grid_height = 10

	_assert(battle.validate(), "Empty battle should validate")
	_assert(battle.is_valid_position(Vector2i(5, 5)), "Position (5,5) should be valid")
	_assert(not battle.is_valid_position(Vector2i(15, 5)), "Position (15,5) should be invalid")

	# Test with units
	var warrior_class: ClassData = ClassData.new()
	warrior_class.class_name = "Warrior"
	warrior_class.movement_range = 4

	var player_unit: CharacterData = CharacterData.new()
	player_unit.character_name = "Player"
	player_unit.character_class = warrior_class
	player_unit.starting_level = 1

	battle.player_units = [player_unit]
	battle.player_positions = [Vector2i(2, 2)]

	_assert(battle.validate_unit_placement(), "Unit placement should be valid")
	_assert(battle.validate_positions(), "Positions should be valid")

	print("  ✓ BattleData tests complete")


func _test_dialogue_data() -> void:
	print("\n[TEST] DialogueData")

	var dialogue: DialogueData = DialogueData.new()
	dialogue.dialogue_id = "test_dialogue"
	dialogue.add_line("Hero", "Hello, world!")
	dialogue.add_line("Villain", "Not for long!")

	_assert(dialogue.validate(), "Dialogue validation should pass")
	_assert(dialogue.get_line_count() == 2, "Should have 2 lines")
	_assert(dialogue.get_line(0)["speaker_name"] == "Hero", "First speaker should be Hero")

	# Test choices
	dialogue.add_choice("Fight")
	dialogue.add_choice("Run away")
	_assert(dialogue.has_choices(), "Dialogue should have choices")
	_assert(dialogue.get_choice_count() == 2, "Should have 2 choices")

	# Test invalid dialogue
	var invalid_dialogue: DialogueData = DialogueData.new()
	_assert(not invalid_dialogue.validate(), "Empty dialogue should fail validation")

	print("  ✓ DialogueData tests complete")


func _test_resource_serialization() -> void:
	print("\n[TEST] Resource Serialization")

	# Create a complete character with all dependencies
	var warrior_class: ClassData = ClassData.new()
	warrior_class.class_name = "Test Warrior"
	warrior_class.movement_range = 4

	var character: CharacterData = CharacterData.new()
	character.character_name = "Test Hero"
	character.character_class = warrior_class
	character.base_hp = 20
	character.starting_level = 1

	# Save to temporary file
	var temp_path: String = "user://test_character.tres"
	var err: Error = ResourceSaver.save(character, temp_path)
	_assert(err == OK, "Character should save successfully")

	# Load it back
	var loaded_character: CharacterData = load(temp_path)
	_assert(loaded_character != null, "Character should load successfully")
	_assert(loaded_character.character_name == "Test Hero", "Loaded name should match")
	_assert(loaded_character.base_hp == 20, "Loaded HP should match")

	# Clean up
	DirAccess.remove_absolute(temp_path)

	print("  ✓ Resource serialization tests complete")


func _assert(condition: bool, message: String) -> void:
	if condition:
		test_passed += 1
	else:
		test_failed += 1
		print("  ✗ FAIL: ", message)
