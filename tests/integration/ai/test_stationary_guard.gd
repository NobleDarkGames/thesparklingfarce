## Stationary Guard Behavior Integration Test
##
## Tests that guard units with very small alert/engagement ranges
## hold position and only attack adjacent enemies.
##
## Validates:
## - Guard does NOT move when player is far away
## - Guard does NOT move when player is nearby but not adjacent
## - Guard ONLY attacks when player is adjacent (distance 1)
extends Node2D

const UnitScript = preload("res://core/components/unit.gd")

# Test state
var _test_complete: bool = false
var _test_passed: bool = false
var _failure_reason: String = ""

# Scenario results
var _scenario_a_passed: bool = false
var _scenario_b_passed: bool = false

# Units (recreated for each scenario)
var _guard_unit: Unit
var _player_unit: Unit

# Tracking
var _guard_start_pos: Vector2i
var _combat_occurred: bool = false

# Resources to clean up
var _tilemap_layer: TileMapLayer
var _tileset: TileSet
var _grid_resource: Grid
var _created_characters: Array[CharacterData] = []
var _created_classes: Array[ClassData] = []
var _created_behaviors: Array[AIBehaviorData] = []


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("STATIONARY GUARD BEHAVIOR TEST")
	print("=".repeat(60))
	print("Testing: Guard holds position and only attacks adjacent enemies\n")

	# Run both scenarios
	await _run_scenario_a()
	await _run_scenario_b()

	# Final results
	_validate_all_scenarios()


func _setup_grid() -> void:
	# Clean up previous tilemap if any
	_cleanup_tilemap()

	# Create minimal TileMapLayer for GridManager
	_tilemap_layer = TileMapLayer.new()
	_tileset = TileSet.new()
	_tilemap_layer.tile_set = _tileset
	add_child(_tilemap_layer)

	# Setup grid
	_grid_resource = Grid.new()
	_grid_resource.grid_size = Vector2i(15, 10)
	_grid_resource.cell_size = 32
	GridManager.setup_grid(_grid_resource, _tilemap_layer)


func _cleanup_scenario() -> void:
	# Remove units from grid and scene
	if _guard_unit:
		GridManager.set_cell_occupied(_guard_unit.grid_position, null)
		_guard_unit.queue_free()
		_guard_unit = null
	if _player_unit:
		GridManager.set_cell_occupied(_player_unit.grid_position, null)
		_player_unit.queue_free()
		_player_unit = null

	# Clean up tilemap for next scenario
	_cleanup_tilemap()

	# Reset tracking
	_combat_occurred = false

	# Small delay for cleanup
	await get_tree().create_timer(0.1).timeout


func _cleanup_tilemap() -> void:
	if _tilemap_layer and is_instance_valid(_tilemap_layer):
		_tilemap_layer.queue_free()
		_tilemap_layer = null
	_tileset = null
	_grid_resource = null


func _cleanup_resources() -> void:
	# Clear tracked resources (RefCounted will handle cleanup)
	_created_characters.clear()
	_created_classes.clear()
	_created_behaviors.clear()


# =============================================================================
# SCENARIO A: Player NOT adjacent - Guard should NOT move or attack
# =============================================================================
func _run_scenario_a() -> void:
	print("--- Scenario A: Player at distance 3 (not adjacent) ---")

	_setup_grid()

	# Create characters
	var guard_character: CharacterData = _create_character("StationaryGuard", 100, 10, 18, 15, 8)
	var player_character: CharacterData = _create_character("Player", 80, 10, 15, 12, 12)
	player_character.is_hero = true

	# Create truly stationary behavior (alert_range=1, engagement_range=1)
	var guard_ai: AIBehaviorData = _create_stationary_behavior()

	# Spawn guard at (5, 5)
	_guard_start_pos = Vector2i(5, 5)
	_guard_unit = _spawn_unit(guard_character, _guard_start_pos, "enemy", guard_ai)

	# Spawn player at (8, 5) - distance 3 (outside alert_range of 1)
	_player_unit = _spawn_unit(player_character, Vector2i(8, 5), "player", null)

	var distance: int = GridManager.grid.get_manhattan_distance(_guard_start_pos, _player_unit.grid_position)
	print("  Guard at: %s" % _guard_start_pos)
	print("  Player at: %s (distance: %d)" % [_player_unit.grid_position, distance])
	print("  Alert range: 1, Engagement range: 1")
	print("  Expected: NO movement, NO attack")

	# Setup BattleManager
	_setup_battle_manager()

	# Execute AI turn
	await _execute_guard_turn()

	# Check results
	var guard_final_pos: Vector2i = _guard_unit.grid_position
	var moved: bool = guard_final_pos != _guard_start_pos

	print("  Result: Moved=%s, Combat=%s" % [moved, _combat_occurred])

	if not moved and not _combat_occurred:
		print("  [OK] Guard held position (player too far)")
		_scenario_a_passed = true
	elif moved:
		print("  [FAIL] Guard moved from %s to %s (should stay stationary)" % [_guard_start_pos, guard_final_pos])
		_scenario_a_passed = false
	else:
		print("  [FAIL] Guard attacked despite player being out of range")
		_scenario_a_passed = false

	await _cleanup_scenario()


# =============================================================================
# SCENARIO B: Player adjacent - Guard should attack (but NOT move first)
# =============================================================================
func _run_scenario_b() -> void:
	print("\n--- Scenario B: Player adjacent (distance 1) ---")

	_setup_grid()

	# Create characters
	var guard_character: CharacterData = _create_character("StationaryGuard", 100, 10, 18, 15, 8)
	var player_character: CharacterData = _create_character("Player", 80, 10, 15, 12, 12)
	player_character.is_hero = true

	# Create truly stationary behavior
	var guard_ai: AIBehaviorData = _create_stationary_behavior()

	# Spawn guard at (5, 5)
	_guard_start_pos = Vector2i(5, 5)
	_guard_unit = _spawn_unit(guard_character, _guard_start_pos, "enemy", guard_ai)

	# Spawn player at (6, 5) - distance 1 (adjacent, inside alert and engagement range)
	_player_unit = _spawn_unit(player_character, Vector2i(6, 5), "player", null)

	var distance: int = GridManager.grid.get_manhattan_distance(_guard_start_pos, _player_unit.grid_position)
	print("  Guard at: %s" % _guard_start_pos)
	print("  Player at: %s (distance: %d)" % [_player_unit.grid_position, distance])
	print("  Expected: NO movement, YES attack")

	# Setup BattleManager
	_setup_battle_manager()

	# Execute AI turn
	await _execute_guard_turn()

	# Check results
	var guard_final_pos: Vector2i = _guard_unit.grid_position
	var moved: bool = guard_final_pos != _guard_start_pos

	print("  Result: Moved=%s, Combat=%s" % [moved, _combat_occurred])

	if not moved and _combat_occurred:
		print("  [OK] Guard attacked without moving")
		_scenario_b_passed = true
	elif moved:
		print("  [FAIL] Guard moved (should stay stationary even when attacking)")
		_scenario_b_passed = false
	else:
		print("  [FAIL] Guard did not attack adjacent player")
		_scenario_b_passed = false

	await _cleanup_scenario()


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

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
	basic_class.display_name = "Guard"
	basic_class.movement_type = ClassData.MovementType.WALKING
	basic_class.movement_range = 4  # Has movement but shouldn't use it

	character.character_class = basic_class

	# Track for cleanup
	_created_characters.append(character)
	_created_classes.append(basic_class)

	return character


func _create_stationary_behavior() -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = "test_stationary_guard"
	behavior.display_name = "Test Stationary Guard"
	behavior.role = "defensive"
	behavior.behavior_mode = "cautious"
	# Key settings for truly stationary behavior:
	# - alert_range=1 means only react to adjacent enemies
	# - engagement_range=1 means only engage adjacent enemies
	behavior.alert_range = 1
	behavior.engagement_range = 1
	behavior.retreat_enabled = false
	behavior.use_healing_items = false
	behavior.use_attack_items = false

	# Track for cleanup
	_created_behaviors.append(behavior)

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


func _setup_battle_manager() -> void:
	BattleManager.setup(self, self)
	BattleManager.player_units = [_player_unit]
	BattleManager.enemy_units = [_guard_unit]
	BattleManager.all_units = [_guard_unit, _player_unit]

	# Reconnect combat signal
	if BattleManager.combat_resolved.is_connected(_on_combat_resolved):
		BattleManager.combat_resolved.disconnect(_on_combat_resolved)
	BattleManager.combat_resolved.connect(_on_combat_resolved)


func _execute_guard_turn() -> void:
	var context: Dictionary = {
		"player_units": BattleManager.player_units,
		"enemy_units": BattleManager.enemy_units,
		"neutral_units": [],
		"turn_number": 1,
		"unit_hp_percent": 100.0,
		"ai_delays": {"after_movement": 0.0, "before_attack": 0.0}
	}

	var ConfigurableAIBrainScript: GDScript = load("res://core/systems/ai/configurable_ai_brain.gd")
	var brain: AIBrain = ConfigurableAIBrainScript.get_instance()
	await brain.execute_with_behavior(_guard_unit, context, _guard_unit.ai_behavior)

	# Wait for any movement to complete (with timeout)
	var wait_start: float = Time.get_ticks_msec()
	while _guard_unit.is_moving() and (Time.get_ticks_msec() - wait_start) < 3000:
		await get_tree().process_frame


func _on_combat_resolved(attacker: Unit, _defender: Unit, _damage: int, _hit: bool, _crit: bool) -> void:
	if attacker == _guard_unit:
		_combat_occurred = true
		print("  [COMBAT] Guard attacked")


func _validate_all_scenarios() -> void:
	print("\n" + "=".repeat(60))
	print("SCENARIO RESULTS:")
	print("  A (Player far away): %s" % ("PASSED" if _scenario_a_passed else "FAILED"))
	print("  B (Player adjacent): %s" % ("PASSED" if _scenario_b_passed else "FAILED"))

	_test_passed = _scenario_a_passed and _scenario_b_passed

	print("")
	if _test_passed:
		print("STATIONARY GUARD TEST PASSED!")
		print("Guard correctly holds position and only attacks adjacent enemies.")
	else:
		print("STATIONARY GUARD TEST FAILED!")
		if not _scenario_a_passed:
			print("- Scenario A: Guard moved or attacked when player was far")
		if not _scenario_b_passed:
			print("- Scenario B: Guard moved or didn't attack adjacent player")
	print("=".repeat(60) + "\n")

	_test_complete = true

	# Cleanup before quitting
	_cleanup_tilemap()
	_cleanup_resources()

	get_tree().quit(0 if _test_passed else 1)


func _process(_delta: float) -> void:
	# Safety timeout
	pass
