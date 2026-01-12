## Healer Prioritization Integration Test (Dark Priest Problem)
##
## Tests that support role units prioritize healing wounded allies
## over attacking enemies, even when enemies are in attack range.
##
## Validates:
## - Healer with wounded ally and enemy in range heals first
## - Healer does NOT attack when healing is needed
## - Support role behavior matches its intent
extends Node2D

const UnitScript = preload("res://core/components/unit.gd")

# Test state
var _test_complete: bool = false
var _test_passed: bool = false
var _failure_reason: String = ""

# Units
var _healer_unit: Unit
var _wounded_ally: Unit
var _enemy_unit: Unit

# Tracking
var _healer_attacked: bool = false
var _healing_occurred: bool = false
var _ally_initial_hp: int = 0
var _healer_initial_mp: int = 0


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("HEALER PRIORITIZATION TEST (Dark Priest Problem)")
	print("=".repeat(60))
	print("Testing: Healer should heal wounded ally instead of attacking enemy\n")

	# Create minimal TileMapLayer for GridManager
	var tilemap_layer: TileMapLayer = TileMapLayer.new()
	var tileset: TileSet = TileSet.new()
	tilemap_layer.tile_set = tileset
	add_child(tilemap_layer)

	# Setup grid
	var grid_resource: Grid = Grid.new()
	grid_resource.grid_size = Vector2i(15, 10)
	grid_resource.cell_size = 32
	GridManager.setup_grid(grid_resource, tilemap_layer)

	# Create healer character with healing ability
	var healer_character: CharacterData = _create_healer_character("TestHealer")

	# Create wounded ally character
	var ally_character: CharacterData = _create_character("WoundedAlly", 100, 10, 10, 10, 10)

	# Create enemy character
	var enemy_character: CharacterData = _create_character("TestEnemy", 50, 10, 10, 10, 5)
	enemy_character.is_hero = true  # Mark as hero for battle end detection

	# Load support role AI behavior (smart_healer)
	var healer_ai: AIBehaviorData = load("res://mods/_starter_kit/data/ai_behaviors/smart_healer.tres")
	if not healer_ai:
		healer_ai = _create_support_behavior()

	# Spawn healer at (5, 5)
	_healer_unit = _spawn_unit(healer_character, Vector2i(5, 5), "enemy", healer_ai)

	# Spawn wounded ally at (6, 5) - adjacent to healer, 30% HP
	_wounded_ally = _spawn_unit(ally_character, Vector2i(6, 5), "enemy", null)
	_wounded_ally.stats.current_hp = 30  # 30% of 100 HP
	_ally_initial_hp = _wounded_ally.stats.current_hp

	# Spawn enemy at (4, 5) - adjacent to healer on other side (in attack range)
	_enemy_unit = _spawn_unit(enemy_character, Vector2i(4, 5), "player", null)

	# Record initial state
	_healer_initial_mp = _healer_unit.stats.current_mp

	print("Setup:")
	print("  Healer at: %s (MP: %d)" % [_healer_unit.grid_position, _healer_initial_mp])
	print("  Wounded ally at: %s (HP: %d/%d = %d%%)" % [
		_wounded_ally.grid_position,
		_wounded_ally.stats.current_hp,
		_wounded_ally.stats.max_hp,
		int(100.0 * _wounded_ally.stats.current_hp / _wounded_ally.stats.max_hp)
	])
	print("  Enemy at: %s (in attack range)" % _enemy_unit.grid_position)

	# Setup BattleManager
	BattleManager.setup(self, self)
	BattleManager.player_units = [_enemy_unit]
	BattleManager.enemy_units = [_healer_unit, _wounded_ally]
	BattleManager.all_units = [_healer_unit, _wounded_ally, _enemy_unit]

	# Connect to combat signal to detect attacks
	BattleManager.combat_resolved.connect(_on_combat_resolved)

	# Run the AI turn
	print("\nExecuting healer AI turn...")
	await _execute_healer_turn()

	# Small delay to ensure all async operations complete
	await get_tree().create_timer(0.1).timeout

	# Validate results
	_validate_behavior()


func _create_character(p_name: String, hp: int, mp: int, str_val: int, def_val: int, agi: int) -> CharacterData:
	var character: CharacterData = CharacterData.new()
	character.character_name = p_name
	character.base_hp = hp
	character.base_mp = mp
	character.base_strength = str_val
	character.base_defense = def_val
	character.base_agility = agi
	character.base_intelligence = 10
	character.base_luck = 5
	character.starting_level = 1

	var basic_class: ClassData = ClassData.new()
	basic_class.display_name = "Fighter"
	basic_class.movement_type = ClassData.MovementType.WALKING
	basic_class.movement_range = 4

	character.character_class = basic_class
	return character


func _create_healer_character(p_name: String) -> CharacterData:
	var character: CharacterData = CharacterData.new()
	character.character_name = p_name
	character.base_hp = 40
	character.base_mp = 30
	character.base_strength = 5
	character.base_defense = 8
	character.base_agility = 10
	character.base_intelligence = 15
	character.base_luck = 5
	character.starting_level = 1

	# Create healer class with healing ability
	var healer_class: ClassData = ClassData.new()
	healer_class.display_name = "Priest"
	healer_class.movement_type = ClassData.MovementType.WALKING
	healer_class.movement_range = 4

	# Create healing ability
	var heal_ability: AbilityData = AbilityData.new()
	heal_ability.ability_name = "Heal"
	heal_ability.ability_id = "test_heal"
	heal_ability.ability_type = AbilityData.AbilityType.HEAL
	heal_ability.target_type = AbilityData.TargetType.SINGLE_ALLY
	heal_ability.min_range = 1
	heal_ability.max_range = 2
	heal_ability.mp_cost = 5
	heal_ability.potency = 20  # Heals 20 HP

	# Add ability to class (this is what get_unlocked_class_abilities iterates)
	healer_class.class_abilities = [heal_ability]
	healer_class.ability_unlock_levels = {"test_heal": 1}

	# Also register in ModLoader so execute_ai_spell can look it up by ID
	if ModLoader and ModLoader.registry:
		ModLoader.registry.register_resource(heal_ability, "ability", "test_heal", "_test")

	character.character_class = healer_class
	return character


func _create_support_behavior() -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = "test_support"
	behavior.display_name = "Test Support"
	behavior.role = "support"
	behavior.behavior_mode = "cautious"
	behavior.conserve_mp_on_heals = false  # Heal freely
	behavior.prioritize_boss_heals = false
	return behavior


func _spawn_unit(character: CharacterData, cell: Vector2i, p_faction: String, p_ai_behavior: AIBehaviorData) -> Unit:
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")
	var unit: Unit = unit_scene.instantiate() as Unit
	unit.initialize(character, p_faction, p_ai_behavior)
	unit.grid_position = cell
	unit.position = Vector2(cell.x * 32, cell.y * 32)
	add_child(unit)
	GridManager.set_cell_occupied(cell, unit)
	return unit


func _execute_healer_turn() -> void:
	var context: Dictionary = {
		"player_units": BattleManager.player_units,
		"enemy_units": BattleManager.enemy_units,
		"neutral_units": [],
		"turn_number": 1,
		"ai_delays": {"after_movement": 0.0, "before_attack": 0.0}
	}

	var ConfigurableAIBrainScript: GDScript = load("res://core/systems/ai/configurable_ai_brain.gd")
	var brain: AIBrain = ConfigurableAIBrainScript.get_instance()
	await brain.execute_with_behavior(_healer_unit, context, _healer_unit.ai_behavior)

	# Wait for any async operations
	await _healer_unit.await_movement_completion()


func _on_combat_resolved(attacker: Unit, defender: Unit, _damage: int, _hit: bool, _crit: bool) -> void:
	if attacker == _healer_unit:
		_healer_attacked = true
		print("  [COMBAT] Healer ATTACKED %s (this should NOT happen!)" % defender.get_display_name())


func _validate_behavior() -> void:
	if _test_complete:
		return

	print("\nResults:")

	# Check if ally was healed
	var ally_hp_change: int = _wounded_ally.stats.current_hp - _ally_initial_hp
	var healer_mp_change: int = _healer_initial_mp - _healer_unit.stats.current_mp

	print("  Ally HP: %d -> %d (change: %+d)" % [_ally_initial_hp, _wounded_ally.stats.current_hp, ally_hp_change])
	print("  Healer MP: %d -> %d (spent: %d)" % [_healer_initial_mp, _healer_unit.stats.current_mp, healer_mp_change])
	print("  Healer attacked: %s" % _healer_attacked)

	_healing_occurred = ally_hp_change > 0 or healer_mp_change > 0

	print("\nValidation:")

	if _healer_attacked:
		_test_passed = false
		_failure_reason = "Healer attacked enemy instead of healing wounded ally (Dark Priest Problem!)"
		print("  [FAIL] %s" % _failure_reason)
	elif not _healing_occurred:
		_test_passed = false
		_failure_reason = "Healer did not heal (no HP change, no MP spent)"
		print("  [FAIL] %s" % _failure_reason)
	else:
		print("  [OK] Healer did not attack")
		if ally_hp_change > 0:
			print("  [OK] Wounded ally was healed (+%d HP)" % ally_hp_change)
		if healer_mp_change > 0:
			print("  [OK] Healer spent MP on healing (%d MP)" % healer_mp_change)
		_test_passed = true

	_test_complete = true
	_print_results()


func _print_results() -> void:
	print("\n" + "=".repeat(60))
	if _test_passed:
		print("HEALER PRIORITIZATION TEST PASSED!")
		print("Healer correctly prioritized healing over attacking.")
	else:
		print("HEALER PRIORITIZATION TEST FAILED!")
		print("Reason: %s" % _failure_reason)
	print("=".repeat(60) + "\n")

	get_tree().quit(0 if _test_passed else 1)


func _process(_delta: float) -> void:
	# Safety timeout - but give more time for healing to complete
	pass
