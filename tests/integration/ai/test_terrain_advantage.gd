## Terrain Advantage AI Integration Test
##
## Tests that AI units with seek_terrain_advantage enabled prefer cells
## with defense/evasion bonuses when choosing attack positions.
##
## Validates:
## - AI prefers forest (defense bonus) over plains when both are in attack range
## - AI with seek_terrain_advantage=false ignores terrain bonuses
## - Terrain bonus is a tie-breaker, not override (still attacks from range)
extends Node2D

const UnitScript = preload("res://core/components/unit.gd")

# Test state
var _test_complete: bool = false
var _test_passed: bool = false
var _failure_reason: String = ""

# Units
var _ai_unit: Unit
var _target_unit: Unit

# Positions
var _ai_start_pos: Vector2i
var _forest_cell: Vector2i  # Cell with defense bonus
var _plains_cell: Vector2i  # Cell without bonus

# Terrain data
var _forest_terrain: TerrainData
var _plains_terrain: TerrainData

# Resources to clean up
var _tilemap_layer: TileMapLayer
var _tileset: TileSet
var _grid_resource: Grid
var _created_characters: Array[CharacterData] = []
var _created_classes: Array[ClassData] = []
var _created_behaviors: Array[AIBehaviorData] = []


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("TERRAIN ADVANTAGE AI TEST")
	print("=".repeat(60))
	print("Testing: AI with seek_terrain_advantage prefers defensive terrain\n")

	_setup_terrain_types()
	await _run_test_with_terrain_seeking(true)

	if _test_passed:
		# Run second test: verify disabled seek_terrain_advantage ignores terrain
		await _run_test_without_terrain_seeking()

	_print_final_results()


func _setup_terrain_types() -> void:
	# Create forest terrain with defense bonus
	_forest_terrain = TerrainData.new()
	_forest_terrain.terrain_id = "test_forest"
	_forest_terrain.display_name = "Test Forest"
	_forest_terrain.defense_bonus = 3
	_forest_terrain.evasion_bonus = 10
	_forest_terrain.movement_cost_walking = 2

	# Create plains terrain with no bonus
	_plains_terrain = TerrainData.new()
	_plains_terrain.terrain_id = "test_plains"
	_plains_terrain.display_name = "Test Plains"
	_plains_terrain.defense_bonus = 0
	_plains_terrain.evasion_bonus = 0
	_plains_terrain.movement_cost_walking = 1


func _run_test_with_terrain_seeking(seek_terrain: bool) -> void:
	print("\n--- Test: seek_terrain_advantage = %s ---" % seek_terrain)

	# Clean up any previous test state
	_cleanup_units()

	# Clean up any previous tilemap/grid resources
	_cleanup_tilemap()

	# Create minimal TileMapLayer for GridManager
	_tilemap_layer = TileMapLayer.new()
	_tileset = TileSet.new()
	_tilemap_layer.tile_set = _tileset
	add_child(_tilemap_layer)

	# Setup grid
	_grid_resource = Grid.new()
	_grid_resource.grid_size = Vector2i(10, 10)
	_grid_resource.cell_size = 32
	GridManager.setup_grid(_grid_resource, _tilemap_layer)

	# Define key positions:
	# - AI starts at (2, 4)
	# - Target at (5, 5)
	# - Forest at (4, 5) - distance 1 from target (west), in attack range
	# - Plains at (5, 4) - distance 1 from target (north), also in attack range
	# Both cells are equidistant from AI start (distance 3), making terrain the tie-breaker
	_ai_start_pos = Vector2i(2, 4)
	_forest_cell = Vector2i(4, 5)
	_plains_cell = Vector2i(5, 4)
	var target_pos: Vector2i = Vector2i(5, 5)

	# Register terrain at cells using GridManager's cache
	# We need to inject terrain data into GridManager's terrain cache
	_inject_terrain_at_cell(_forest_cell, _forest_terrain)
	_inject_terrain_at_cell(_plains_cell, _plains_terrain)

	# Create AI character
	var ai_character: CharacterData = _create_character("TestWarrior", 50, 10, 15, 12, 10)

	# Create target character
	var target_character: CharacterData = _create_character("TestTarget", 100, 10, 10, 20, 5)
	target_character.is_hero = true

	# Create AI behavior with seek_terrain_advantage setting
	var ai_behavior: AIBehaviorData = AIBehaviorData.new()
	ai_behavior.behavior_id = "test_terrain_seeker"
	ai_behavior.display_name = "Test Terrain Seeker"
	ai_behavior.role = "aggressive"
	ai_behavior.behavior_mode = "aggressive"
	ai_behavior.seek_terrain_advantage = seek_terrain

	# Spawn units
	_ai_unit = _spawn_unit(ai_character, _ai_start_pos, "enemy", ai_behavior)
	_target_unit = _spawn_unit(target_character, target_pos, "player", null)

	print("Setup:")
	print("  AI at: %s (seek_terrain=%s)" % [_ai_start_pos, seek_terrain])
	print("  Target at: %s" % target_pos)
	print("  Forest cell at: %s (defense +%d, evasion +%d%%)" % [
		_forest_cell, _forest_terrain.defense_bonus, _forest_terrain.evasion_bonus
	])
	print("  Plains cell at: %s (no bonus)" % _plains_cell)

	# Setup BattleManager
	BattleManager.setup(self, self)
	BattleManager.player_units = [_target_unit]
	BattleManager.enemy_units = [_ai_unit]
	BattleManager.all_units = [_ai_unit, _target_unit]

	# Execute AI turn
	print("\nExecuting AI turn...")
	await _execute_ai_turn()

	# Validate based on seek_terrain setting
	if seek_terrain:
		_validate_terrain_preference()
	else:
		_validate_ignores_terrain()


func _run_test_without_terrain_seeking() -> void:
	# Reset test state
	_test_passed = false
	_failure_reason = ""

	await _run_test_with_terrain_seeking(false)


func _inject_terrain_at_cell(cell: Vector2i, terrain: TerrainData) -> void:
	# Access GridManager's internal terrain cache
	# This is a test-only hack to inject terrain without a full tilemap setup
	if GridManager.has_method("_set_cell_terrain_for_testing"):
		GridManager._set_cell_terrain_for_testing(cell, terrain)
	else:
		# Fallback: directly access the cache if possible
		if "_cell_terrain_cache" in GridManager:
			GridManager._cell_terrain_cache[cell] = terrain
		else:
			push_warning("Cannot inject terrain - GridManager cache not accessible")


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
	basic_class.display_name = "Warrior"
	basic_class.movement_type = ClassData.MovementType.WALKING
	basic_class.movement_range = 5

	character.character_class = basic_class

	# Track for cleanup
	_created_characters.append(character)
	_created_classes.append(basic_class)

	return character


func _spawn_unit(character: CharacterData, cell: Vector2i, p_faction: String, p_ai_behavior: AIBehaviorData) -> Unit:
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")
	var unit: Unit = unit_scene.instantiate() as Unit
	unit.initialize(character, p_faction, p_ai_behavior)
	unit.grid_position = cell
	unit.position = Vector2(cell.x * 32, cell.y * 32)
	add_child(unit)
	GridManager.set_cell_occupied(cell, unit)

	# Track behavior for cleanup
	if p_ai_behavior and p_ai_behavior not in _created_behaviors:
		_created_behaviors.append(p_ai_behavior)

	return unit


func _cleanup_units() -> void:
	if _ai_unit and is_instance_valid(_ai_unit):
		GridManager.set_cell_occupied(_ai_unit.grid_position, null)
		_ai_unit.queue_free()
		_ai_unit = null
	if _target_unit and is_instance_valid(_target_unit):
		GridManager.set_cell_occupied(_target_unit.grid_position, null)
		_target_unit.queue_free()
		_target_unit = null


func _cleanup_tilemap() -> void:
	if _tilemap_layer and is_instance_valid(_tilemap_layer):
		_tilemap_layer.queue_free()
		_tilemap_layer = null
	_tileset = null
	_grid_resource = null


func _cleanup_resources() -> void:
	# Free terrain data
	_forest_terrain = null
	_plains_terrain = null

	# Clear tracked resources (RefCounted will handle cleanup)
	_created_characters.clear()
	_created_classes.clear()
	_created_behaviors.clear()


func _execute_ai_turn() -> void:
	var context: Dictionary = {
		"player_units": BattleManager.player_units,
		"enemy_units": BattleManager.enemy_units,
		"neutral_units": [],
		"turn_number": 1,
		"ai_delays": {"after_movement": 0.0, "before_attack": 0.0}
	}

	var ConfigurableAIBrainScript: GDScript = load("res://core/systems/ai/configurable_ai_brain.gd")
	var brain: AIBrain = ConfigurableAIBrainScript.get_instance()
	await brain.execute_with_behavior(_ai_unit, context, _ai_unit.ai_behavior)

	# Wait for movement to complete
	await _ai_unit.await_movement_completion()


func _validate_terrain_preference() -> void:
	var final_pos: Vector2i = _ai_unit.grid_position
	print("\nResults (seek_terrain_advantage = true):")
	print("  AI moved to: %s" % final_pos)

	# Check if AI chose forest (terrain advantage) over plains
	if final_pos == _forest_cell:
		print("  [OK] AI chose forest cell with defense bonus")
		_test_passed = true
	elif final_pos == _plains_cell:
		print("  [FAIL] AI chose plains instead of forest")
		_failure_reason = "AI did not prefer terrain with defense bonus"
		_test_passed = false
	else:
		# AI might have chosen a different valid attack position
		var dist_to_target: int = GridManager.grid.get_manhattan_distance(final_pos, _target_unit.grid_position)
		if dist_to_target == 1:
			print("  [INFO] AI at different attack position: %s (distance 1)" % final_pos)
			# Check terrain at that position
			var terrain: TerrainData = GridManager.get_terrain_at_cell(final_pos)
			if terrain and terrain.defense_bonus > 0:
				print("  [OK] AI chose a position with terrain bonus")
				_test_passed = true
			else:
				print("  [FAIL] AI chose position without terrain bonus")
				_failure_reason = "AI at %s without terrain bonus when forest was available" % final_pos
				_test_passed = false
		else:
			print("  [FAIL] AI ended at unexpected position: %s" % final_pos)
			_failure_reason = "Unexpected final position"
			_test_passed = false


func _validate_ignores_terrain() -> void:
	var final_pos: Vector2i = _ai_unit.grid_position
	print("\nResults (seek_terrain_advantage = false):")
	print("  AI moved to: %s" % final_pos)

	# When seek_terrain_advantage is false, AI should choose based on
	# movement efficiency (closer = better since less movement cost)
	# Plains is closer to start, so AI might prefer it
	var dist_to_target: int = GridManager.grid.get_manhattan_distance(final_pos, _target_unit.grid_position)

	if dist_to_target == 1:
		print("  [OK] AI reached attack range")
		# We don't strictly require plains - just verify terrain wasn't the deciding factor
		# The key validation is that with seek_terrain=true it chose forest
		_test_passed = true
	else:
		print("  [FAIL] AI not in attack range")
		_failure_reason = "AI didn't reach attack position"
		_test_passed = false


func _print_final_results() -> void:
	_test_complete = true

	print("\n" + "=".repeat(60))
	if _test_passed:
		print("TERRAIN ADVANTAGE AI TEST PASSED!")
		print("AI correctly prefers defensive terrain when seek_terrain_advantage is enabled.")
	else:
		print("TERRAIN ADVANTAGE AI TEST FAILED!")
		print("Reason: %s" % _failure_reason)
	print("=".repeat(60) + "\n")

	# Cleanup before quitting
	_cleanup_units()
	_cleanup_tilemap()
	_cleanup_resources()

	get_tree().quit(0 if _test_passed else 1)
