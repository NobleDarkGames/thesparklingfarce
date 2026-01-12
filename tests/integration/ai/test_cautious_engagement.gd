## Cautious Engagement Range Integration Test
##
## Tests that cautious AI units respect alert_range and engagement_range
## thresholds, creating guard-like behavior that doesn't chase forever.
##
## Validates three scenarios:
## A) Outside alert range - unit should NOT move
## B) Inside alert, outside engagement - unit should move but NOT attack
## C) Inside engagement range - unit should attack
extends Node2D

const UnitScript = preload("res://core/components/unit.gd")

# Test configuration
const ALERT_RANGE: int = 6
const ENGAGEMENT_RANGE: int = 3

# Test state
var _current_scenario: String = ""
var _test_complete: bool = false
var _test_passed: bool = false
var _failure_reason: String = ""

# Scenario results
var _scenario_a_passed: bool = false
var _scenario_b_passed: bool = false
var _scenario_c_passed: bool = false

# Units (recreated for each scenario)
var _cautious_unit: Unit
var _player_unit: Unit

# Tracking
var _unit_start_pos: Vector2i
var _unit_moved: bool = false
var _combat_occurred: bool = false


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("CAUTIOUS ENGAGEMENT RANGE TEST")
	print("=".repeat(60))
	print("Testing alert_range: %d, engagement_range: %d\n" % [ALERT_RANGE, ENGAGEMENT_RANGE])

	# Run all three scenarios
	await _run_scenario_a()
	await _run_scenario_b()
	await _run_scenario_c()

	# Final results
	_validate_all_scenarios()


func _setup_grid() -> void:
	# Create minimal TileMapLayer for GridManager
	var tilemap_layer: TileMapLayer = TileMapLayer.new()
	var tileset: TileSet = TileSet.new()
	tilemap_layer.tile_set = tileset
	add_child(tilemap_layer)

	# Setup grid
	var grid_resource: Grid = Grid.new()
	grid_resource.grid_size = Vector2i(20, 10)
	grid_resource.cell_size = 32
	GridManager.setup_grid(grid_resource, tilemap_layer)


func _cleanup_scenario() -> void:
	# Remove units from grid and scene
	if _cautious_unit:
		GridManager.set_cell_occupied(_cautious_unit.grid_position, null)
		_cautious_unit.queue_free()
		_cautious_unit = null
	if _player_unit:
		GridManager.set_cell_occupied(_player_unit.grid_position, null)
		_player_unit.queue_free()
		_player_unit = null

	# Reset tracking
	_unit_moved = false
	_combat_occurred = false

	# Small delay for cleanup
	await get_tree().create_timer(0.1).timeout


# =============================================================================
# SCENARIO A: Outside Alert Range - Should NOT move
# =============================================================================
func _run_scenario_a() -> void:
	_current_scenario = "A"
	print("--- Scenario A: Outside Alert Range ---")

	_setup_grid()

	# Create characters
	var cautious_character: CharacterData = _create_character("CautiousGuard", 80, 10, 15, 12, 10)
	var player_character: CharacterData = _create_character("Player", 100, 10, 15, 15, 10)
	player_character.is_hero = true

	# Create cautious behavior
	var cautious_ai: AIBehaviorData = _create_cautious_behavior()

	# Spawn cautious unit at (2, 5)
	_unit_start_pos = Vector2i(2, 5)
	_cautious_unit = _spawn_unit(cautious_character, _unit_start_pos, "enemy", cautious_ai)

	# Spawn player at (10, 5) - distance 8 (OUTSIDE alert_range of 6)
	_player_unit = _spawn_unit(player_character, Vector2i(10, 5), "player", null)

	var distance: int = GridManager.grid.get_manhattan_distance(_unit_start_pos, _player_unit.grid_position)
	print("  Cautious unit at: %s" % _unit_start_pos)
	print("  Player at: %s (distance: %d, alert_range: %d)" % [_player_unit.grid_position, distance, ALERT_RANGE])
	print("  Expected: No movement (outside alert range)")

	# Setup BattleManager
	_setup_battle_manager()

	# Execute AI turn
	await _execute_cautious_turn()

	# Check results
	var unit_final_pos: Vector2i = _cautious_unit.grid_position
	var moved: bool = unit_final_pos != _unit_start_pos

	print("  Result: Moved=%s, Combat=%s" % [moved, _combat_occurred])

	if not moved and not _combat_occurred:
		print("  [OK] Unit stayed still (outside alert range)")
		_scenario_a_passed = true
	else:
		print("  [FAIL] Unit should not have moved or attacked")
		_scenario_a_passed = false

	await _cleanup_scenario()


# =============================================================================
# SCENARIO B: Inside Alert, Outside Engagement - Should move but NOT attack
# =============================================================================
func _run_scenario_b() -> void:
	_current_scenario = "B"
	print("\n--- Scenario B: Inside Alert, Outside Engagement ---")

	_setup_grid()

	# Create characters
	var cautious_character: CharacterData = _create_character("CautiousGuard", 80, 10, 15, 12, 10)
	var player_character: CharacterData = _create_character("Player", 100, 10, 15, 15, 10)
	player_character.is_hero = true

	# Create cautious behavior
	var cautious_ai: AIBehaviorData = _create_cautious_behavior()

	# Spawn cautious unit at (2, 5)
	_unit_start_pos = Vector2i(2, 5)
	_cautious_unit = _spawn_unit(cautious_character, _unit_start_pos, "enemy", cautious_ai)

	# Spawn player at (8, 5) - distance 6 (INSIDE alert_range 6)
	# After moving 4 cells, unit will be at distance 2 - still can't attack (needs distance 1)
	# This tests the "approach but don't attack" behavior
	_player_unit = _spawn_unit(player_character, Vector2i(8, 5), "player", null)

	var distance: int = GridManager.grid.get_manhattan_distance(_unit_start_pos, _player_unit.grid_position)
	print("  Cautious unit at: %s (movement: 4)" % _unit_start_pos)
	print("  Player at: %s (distance: %d, alert: %d, engagement: %d)" % [
		_player_unit.grid_position, distance, ALERT_RANGE, ENGAGEMENT_RANGE
	])
	print("  Expected: Move toward player but NO attack (can't reach attack range)")

	# Setup BattleManager
	_setup_battle_manager()

	# Execute AI turn
	await _execute_cautious_turn()

	# Check results
	var unit_final_pos: Vector2i = _cautious_unit.grid_position
	var moved: bool = unit_final_pos != _unit_start_pos
	var new_distance: int = GridManager.grid.get_manhattan_distance(unit_final_pos, _player_unit.grid_position)

	print("  Result: Moved=%s (to %s, new distance: %d), Combat=%s" % [moved, unit_final_pos, new_distance, _combat_occurred])

	if moved and not _combat_occurred:
		print("  [OK] Unit moved but did not attack (cautious approach)")
		_scenario_b_passed = true
	elif not moved:
		print("  [FAIL] Unit should have moved toward player")
		_scenario_b_passed = false
	else:
		print("  [FAIL] Unit should not have attacked yet (can't reach attack range)")
		_scenario_b_passed = false

	await _cleanup_scenario()


# =============================================================================
# SCENARIO C: Inside Engagement Range - Should attack
# =============================================================================
func _run_scenario_c() -> void:
	_current_scenario = "C"
	print("\n--- Scenario C: Inside Engagement Range ---")

	_setup_grid()

	# Create characters
	var cautious_character: CharacterData = _create_character("CautiousGuard", 80, 10, 15, 12, 10)
	var player_character: CharacterData = _create_character("Player", 100, 10, 15, 15, 10)
	player_character.is_hero = true

	# Create cautious behavior
	var cautious_ai: AIBehaviorData = _create_cautious_behavior()

	# Spawn cautious unit at (2, 5)
	_unit_start_pos = Vector2i(2, 5)
	_cautious_unit = _spawn_unit(cautious_character, _unit_start_pos, "enemy", cautious_ai)

	# Spawn player at (4, 5) - distance 2 (INSIDE engagement_range of 3)
	_player_unit = _spawn_unit(player_character, Vector2i(4, 5), "player", null)

	var distance: int = GridManager.grid.get_manhattan_distance(_unit_start_pos, _player_unit.grid_position)
	print("  Cautious unit at: %s" % _unit_start_pos)
	print("  Player at: %s (distance: %d, engagement_range: %d)" % [
		_player_unit.grid_position, distance, ENGAGEMENT_RANGE
	])
	print("  Expected: Attack (inside engagement range)")

	# Setup BattleManager
	_setup_battle_manager()

	# Execute AI turn
	await _execute_cautious_turn()

	# Check results
	print("  Result: Combat=%s" % _combat_occurred)

	if _combat_occurred:
		print("  [OK] Unit attacked (inside engagement range)")
		_scenario_c_passed = true
	else:
		print("  [FAIL] Unit should have attacked")
		_scenario_c_passed = false

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
	basic_class.movement_range = 4

	character.character_class = basic_class
	return character


func _create_cautious_behavior() -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = "test_cautious"
	behavior.display_name = "Test Cautious"
	behavior.role = "aggressive"
	behavior.behavior_mode = "cautious"
	behavior.alert_range = ALERT_RANGE
	behavior.engagement_range = ENGAGEMENT_RANGE
	behavior.retreat_enabled = false
	behavior.use_healing_items = false
	behavior.use_attack_items = false
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
	BattleManager.enemy_units = [_cautious_unit]
	BattleManager.all_units = [_cautious_unit, _player_unit]

	# Reconnect combat signal
	if BattleManager.combat_resolved.is_connected(_on_combat_resolved):
		BattleManager.combat_resolved.disconnect(_on_combat_resolved)
	BattleManager.combat_resolved.connect(_on_combat_resolved)


func _execute_cautious_turn() -> void:
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
	await brain.execute_with_behavior(_cautious_unit, context, _cautious_unit.ai_behavior)

	# Wait for movement to complete (with timeout)
	var wait_start: float = Time.get_ticks_msec()
	while _cautious_unit.is_moving() and (Time.get_ticks_msec() - wait_start) < 3000:
		await get_tree().process_frame


func _on_combat_resolved(attacker: Unit, _defender: Unit, _damage: int, _hit: bool, _crit: bool) -> void:
	if attacker == _cautious_unit:
		_combat_occurred = true
		print("  [COMBAT] Cautious unit attacked")


func _validate_all_scenarios() -> void:
	print("\n" + "=".repeat(60))
	print("SCENARIO RESULTS:")
	print("  A (Outside Alert): %s" % ("PASSED" if _scenario_a_passed else "FAILED"))
	print("  B (Alert, not Engagement): %s" % ("PASSED" if _scenario_b_passed else "FAILED"))
	print("  C (Inside Engagement): %s" % ("PASSED" if _scenario_c_passed else "FAILED"))

	_test_passed = _scenario_a_passed and _scenario_b_passed and _scenario_c_passed

	print("")
	if _test_passed:
		print("CAUTIOUS ENGAGEMENT TEST PASSED!")
		print("All three engagement range scenarios behaved correctly.")
	else:
		print("CAUTIOUS ENGAGEMENT TEST FAILED!")
		if not _scenario_a_passed:
			print("- Scenario A: Unit moved when outside alert range")
		if not _scenario_b_passed:
			print("- Scenario B: Unit didn't move or attacked prematurely")
		if not _scenario_c_passed:
			print("- Scenario C: Unit didn't attack when in engagement range")
	print("=".repeat(60) + "\n")

	_test_complete = true
	get_tree().quit(0 if _test_passed else 1)


func _process(_delta: float) -> void:
	# Safety timeout
	pass
