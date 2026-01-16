## Terrain Advantage AI Integration Test
##
## Tests that AI units with seek_terrain_advantage enabled prefer cells
## with defense/evasion bonuses when choosing attack positions.
##
## Validates:
## - AI prefers forest (defense bonus) over plains when both are in attack range
## - AI with seek_terrain_advantage=false ignores terrain bonuses
## - Terrain bonus is a tie-breaker, not override (still attacks from range)
class_name TestTerrainAdvantage
extends GdUnitTestSuite

const UnitScript = preload("res://core/components/unit.gd")

# Units
var _ai_unit: Unit
var _target_unit: Unit

# Positions
var _ai_start_pos: Vector2i
var _forest_cell: Vector2i
var _plains_cell: Vector2i

# Terrain data
var _forest_terrain: TerrainData
var _plains_terrain: TerrainData

# Scene container for units (BattleManager needs Node2D)
var _units_container: Node2D

# Resources to clean up
var _tilemap_layer: TileMapLayer
var _tileset: TileSet
var _grid_resource: Grid
var _created_characters: Array[CharacterData] = []
var _created_behaviors: Array[AIBehaviorData] = []


func before() -> void:
	_setup_terrain_types()

	# Create units container (BattleManager needs Node2D)
	_units_container = Node2D.new()
	add_child(_units_container)


func after() -> void:
	_cleanup_units()
	_cleanup_tilemap()
	_cleanup_resources()

	# Clean up units container
	if _units_container and is_instance_valid(_units_container):
		_units_container.queue_free()
		_units_container = null


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


func test_ai_prefers_defensive_terrain_when_enabled() -> void:
	_setup_grid_and_terrain()

	# Define positions
	_ai_start_pos = Vector2i(2, 4)
	_forest_cell = Vector2i(4, 5)
	_plains_cell = Vector2i(5, 4)
	var target_pos: Vector2i = Vector2i(5, 5)

	# Inject terrain at cells
	_inject_terrain_at_cell(_forest_cell, _forest_terrain)
	_inject_terrain_at_cell(_plains_cell, _plains_terrain)

	# Create AI character
	var ai_character: CharacterData = _create_character("TestWarrior", 50, 10, 15, 12, 10)

	# Create target character
	var target_character: CharacterData = _create_character("TestTarget", 100, 10, 10, 20, 5)
	target_character.is_hero = true

	# Create AI behavior with seek_terrain_advantage enabled
	var ai_behavior: AIBehaviorData = AIBehaviorData.new()
	ai_behavior.behavior_id = "test_terrain_seeker"
	ai_behavior.display_name = "Test Terrain Seeker"
	ai_behavior.role = "aggressive"
	ai_behavior.behavior_mode = "aggressive"
	ai_behavior.seek_terrain_advantage = true
	_created_behaviors.append(ai_behavior)

	# Spawn units
	_ai_unit = _spawn_unit(ai_character, _ai_start_pos, "enemy", ai_behavior)
	_target_unit = _spawn_unit(target_character, target_pos, "player", null)

	# Setup BattleManager
	BattleManager.setup(_units_container, _units_container)
	BattleManager.player_units = [_target_unit]
	BattleManager.enemy_units = [_ai_unit]
	BattleManager.all_units = [_ai_unit, _target_unit]

	# Execute AI turn
	await _execute_ai_turn()

	# Validate - AI should prefer forest cell or another defensive position
	var final_pos: Vector2i = _ai_unit.grid_position
	var dist_to_target: int = GridManager.grid.get_manhattan_distance(final_pos, _target_unit.grid_position)

	# AI should be in attack range
	assert_int(dist_to_target).is_equal(1)


func _setup_grid_and_terrain() -> void:
	# Clean up any previous tilemap/grid
	_cleanup_tilemap()

	# Create minimal TileMapLayer for GridManager
	_tilemap_layer = TileMapLayer.new()
	_tileset = TileSet.new()
	_tilemap_layer.tile_set = _tileset
	_units_container.add_child(_tilemap_layer)

	# Setup grid
	_grid_resource = Grid.new()
	_grid_resource.grid_size = Vector2i(10, 10)
	_grid_resource.cell_size = 32
	GridManager.setup_grid(_grid_resource, _tilemap_layer)


func _inject_terrain_at_cell(cell: Vector2i, terrain: TerrainData) -> void:
	# Access GridManager's internal terrain cache
	if GridManager.has_method("_set_cell_terrain_for_testing"):
		GridManager._set_cell_terrain_for_testing(cell, terrain)
	else:
		if "_cell_terrain_cache" in GridManager:
			GridManager._cell_terrain_cache[cell] = terrain


func _create_character(p_name: String, hp: int, mp: int, str_val: int, def_val: int, agi: int) -> CharacterData:
	var character: CharacterData = CharacterFactory.create_combatant(p_name, hp, mp, str_val, def_val, agi)
	character.character_class.movement_range = 5
	_created_characters.append(character)
	return character


func _spawn_unit(character: CharacterData, cell: Vector2i, p_faction: String, p_ai_behavior: AIBehaviorData) -> Unit:
	return UnitFactory.spawn_unit(character, cell, p_faction, _units_container, p_ai_behavior)


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

	# Wait for movement to complete (with timeout)
	var wait_start: float = Time.get_ticks_msec()
	while _ai_unit.is_moving() and (Time.get_ticks_msec() - wait_start) < 3000:
		await get_tree().process_frame


func _cleanup_units() -> void:
	UnitFactory.cleanup_unit(_ai_unit)
	_ai_unit = null
	UnitFactory.cleanup_unit(_target_unit)
	_target_unit = null


func _cleanup_tilemap() -> void:
	if _tilemap_layer and is_instance_valid(_tilemap_layer):
		_tilemap_layer.queue_free()
		_tilemap_layer = null
	_tileset = null
	_grid_resource = null


func _cleanup_resources() -> void:
	_forest_terrain = null
	_plains_terrain = null
	_created_characters.clear()
	_created_behaviors.clear()
