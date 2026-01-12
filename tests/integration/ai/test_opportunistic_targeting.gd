## Opportunistic Target Selection Integration Test
##
## Tests that opportunistic AI units prioritize wounded targets over
## closer full-HP targets, enabling "finishing blow" behavior.
##
## Validates:
## - Attacker ignores closer full-HP target
## - Attacker moves toward and attacks wounded target
## - Wounded priority weight functions correctly
extends Node2D

const UnitScript = preload("res://core/components/unit.gd")

# Test state
var _test_complete: bool = false
var _test_passed: bool = false
var _failure_reason: String = ""

# Units
var _attacker_unit: Unit
var _full_hp_target: Unit
var _wounded_target: Unit

# Tracking
var _attacker_start_pos: Vector2i
var _attacked_target: Unit = null
var _combat_occurred: bool = false


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("OPPORTUNISTIC TARGET SELECTION TEST")
	print("=".repeat(60))
	print("Testing: Attacker should prioritize wounded target over closer full-HP target\n")

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

	# Create attacker character
	var attacker_character: CharacterData = _create_character("Opportunist", 80, 10, 20, 12, 14)

	# Create full HP target character
	var full_hp_character: CharacterData = _create_character("FullHPTarget", 100, 10, 15, 15, 10)
	full_hp_character.is_hero = true

	# Create wounded target character
	var wounded_character: CharacterData = _create_character("WoundedTarget", 100, 10, 15, 15, 10)
	wounded_character.is_hero = true

	# Create opportunistic behavior
	var attacker_ai: AIBehaviorData = _create_opportunistic_behavior()

	# Spawn attacker at (2, 5)
	_attacker_start_pos = Vector2i(2, 5)
	_attacker_unit = _spawn_unit(attacker_character, _attacker_start_pos, "enemy", attacker_ai)

	# Spawn full HP target at (4, 5) - distance 2 (closer)
	_full_hp_target = _spawn_unit(full_hp_character, Vector2i(4, 5), "player", null)

	# Spawn wounded target at (6, 5) - distance 4 (farther but wounded)
	_wounded_target = _spawn_unit(wounded_character, Vector2i(6, 5), "player", null)
	_wounded_target.stats.current_hp = 20  # 20% HP

	print("Setup:")
	print("  Attacker at: %s" % _attacker_start_pos)
	print("  Full HP target at: %s (HP: %d/%d = 100%%)" % [
		_full_hp_target.grid_position,
		_full_hp_target.stats.current_hp,
		_full_hp_target.stats.max_hp
	])
	print("  Wounded target at: %s (HP: %d/%d = %d%%)" % [
		_wounded_target.grid_position,
		_wounded_target.stats.current_hp,
		_wounded_target.stats.max_hp,
		int(100.0 * _wounded_target.stats.current_hp / _wounded_target.stats.max_hp)
	])
	print("  Distance to full HP: %d" % GridManager.grid.get_manhattan_distance(_attacker_start_pos, _full_hp_target.grid_position))
	print("  Distance to wounded: %d" % GridManager.grid.get_manhattan_distance(_attacker_start_pos, _wounded_target.grid_position))

	# Setup BattleManager
	BattleManager.setup(self, self)
	BattleManager.player_units = [_full_hp_target, _wounded_target]
	BattleManager.enemy_units = [_attacker_unit]
	BattleManager.all_units = [_attacker_unit, _full_hp_target, _wounded_target]

	# Connect to combat signal to track who gets attacked
	BattleManager.combat_resolved.connect(_on_combat_resolved)

	# Run the AI turn
	print("\nExecuting attacker AI turn...")
	await _execute_attacker_turn()

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
	character.base_intelligence = 5
	character.base_luck = 5
	character.starting_level = 1

	var basic_class: ClassData = ClassData.new()
	basic_class.display_name = "Fighter"
	basic_class.movement_type = ClassData.MovementType.WALKING
	basic_class.movement_range = 5

	character.character_class = basic_class
	return character


func _create_opportunistic_behavior() -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = "test_opportunistic"
	behavior.display_name = "Test Opportunistic"
	behavior.role = "aggressive"
	behavior.behavior_mode = "opportunistic"
	behavior.retreat_enabled = false  # Don't retreat, focus on attacking
	behavior.use_healing_items = false
	behavior.use_attack_items = false
	# High wounded priority, low proximity priority
	behavior.threat_weights = {
		"wounded_target": 2.0,
		"proximity": 0.3
	}
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


func _execute_attacker_turn() -> void:
	var context: Dictionary = {
		"player_units": BattleManager.player_units,
		"enemy_units": BattleManager.enemy_units,
		"neutral_units": [],
		"turn_number": 1,
		"unit_hp_percent": 100.0,  # Attacker at full HP
		"ai_delays": {"after_movement": 0.0, "before_attack": 0.0}
	}

	var ConfigurableAIBrainScript: GDScript = load("res://core/systems/ai/configurable_ai_brain.gd")
	var brain: AIBrain = ConfigurableAIBrainScript.get_instance()
	await brain.execute_with_behavior(_attacker_unit, context, _attacker_unit.ai_behavior)

	# Wait for movement to complete (with timeout)
	var wait_start: float = Time.get_ticks_msec()
	while _attacker_unit.is_moving() and (Time.get_ticks_msec() - wait_start) < 3000:
		await get_tree().process_frame


func _on_combat_resolved(attacker: Unit, defender: Unit, _damage: int, _hit: bool, _crit: bool) -> void:
	if attacker == _attacker_unit:
		_combat_occurred = true
		_attacked_target = defender
		print("  [COMBAT] Attacker attacked %s" % defender.character_data.character_name)


func _validate_behavior() -> void:
	if _test_complete:
		return

	print("\nResults:")
	print("  Combat occurred: %s" % _combat_occurred)
	if _attacked_target:
		print("  Target attacked: %s" % _attacked_target.character_data.character_name)
	else:
		print("  Target attacked: None")

	print("\nValidation:")

	if not _combat_occurred:
		_test_passed = false
		_failure_reason = "No combat occurred - attacker did not attack anyone"
		print("  [FAIL] %s" % _failure_reason)
	elif _attacked_target == _full_hp_target:
		_test_passed = false
		_failure_reason = "Attacker attacked the closer full-HP target instead of wounded target"
		print("  [FAIL] %s" % _failure_reason)
	elif _attacked_target == _wounded_target:
		print("  [OK] Attacker prioritized the wounded target")
		print("  [OK] Ignored closer full-HP target")
		_test_passed = true
	else:
		_test_passed = false
		_failure_reason = "Unknown target attacked"
		print("  [FAIL] %s" % _failure_reason)

	_test_complete = true
	_print_results()


func _print_results() -> void:
	print("\n" + "=".repeat(60))
	if _test_passed:
		print("OPPORTUNISTIC TARGETING TEST PASSED!")
		print("Attacker correctly prioritized wounded target over closer target.")
	else:
		print("OPPORTUNISTIC TARGETING TEST FAILED!")
		print("Reason: %s" % _failure_reason)
	print("=".repeat(60) + "\n")

	get_tree().quit(0 if _test_passed else 1)


func _process(_delta: float) -> void:
	# Safety timeout
	pass
