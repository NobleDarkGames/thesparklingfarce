## Shared test fixture for spawning Unit nodes
##
## Usage:
##   var unit: Unit = UnitFactory.spawn_unit(character, Vector2i(5, 5), "player", container)
class_name UnitFactory
extends RefCounted


const UNIT_SCENE_PATH: String = "res://scenes/unit.tscn"


## Spawn a unit at the specified grid cell
## Returns the spawned Unit node (caller is responsible for cleanup)
static func spawn_unit(
	character: CharacterData,
	cell: Vector2i,
	faction: String,
	parent: Node,
	ai_behavior: AIBehaviorData = null,
	register_with_grid: bool = true
) -> Unit:
	var unit_scene: PackedScene = load(UNIT_SCENE_PATH)
	var unit: Unit = unit_scene.instantiate() as Unit
	unit.initialize(character, faction, ai_behavior)
	unit.grid_position = cell
	unit.position = Vector2(cell.x * 32, cell.y * 32)
	parent.add_child(unit)

	if register_with_grid:
		GridManager.set_cell_occupied(cell, unit)

	return unit


## Clean up a unit and unregister from grid
static func cleanup_unit(unit: Unit) -> void:
	if unit and is_instance_valid(unit):
		GridManager.set_cell_occupied(unit.grid_position, null)
		unit.queue_free()


## Clean up multiple units
static func cleanup_units(units: Array) -> void:
	for unit in units:
		cleanup_unit(unit)
