@tool
## SpawnPoint - Marker for player spawn locations in maps
##
## Place SpawnPoint nodes in map scenes to define where players can
## appear when entering the map. Each spawn point has a unique ID
## that map transitions reference to determine player placement.
##
## Usage in editor:
##   1. Add SpawnPoint node to map scene
##   2. Position it on the tile where player should spawn
##   3. Set spawn_id (e.g., "entrance", "from_castle")
##   4. Set facing direction
##   5. Mark one as is_default for fallback spawning
##
## Usage in code:
##   # Find spawn point in scene
##   var spawn = spawn_points_container.find_spawn_point("entrance")
##   hero.teleport_to_grid(spawn.grid_position)
##   hero.set_facing(spawn.facing)
class_name SpawnPoint
extends Marker2D

## Unique identifier within this map (e.g., "entrance", "from_castle")
## Referenced by MapTrigger door triggers and TransitionContext
@export var spawn_id: String = ""

## Direction player should face when spawning here
@export_enum("up", "down", "left", "right") var facing: String = "down"

## Is this the default spawn point for the map?
## Used when no specific spawn_id is provided in transition
@export var is_default: bool = false

## Is this a Caravan spawn point?
## The Caravan will spawn here on overworld maps
@export var is_caravan_spawn: bool = false

## Optional description for editor tooltips
@export_multiline var description: String = ""

## Tile size for grid calculations (should match your tilemap)
## SF-authentic: unified 32px tiles for all modes (matching HeroController default)
@export var tile_size: int = 32

## Colors for editor visualization
const COLOR_DEFAULT: Color = Color(0.2, 0.8, 0.2, 0.8)  # Green for default
const COLOR_CARAVAN: Color = Color(0.8, 0.6, 0.2, 0.8)  # Orange for caravan
const COLOR_NORMAL: Color = Color(0.2, 0.4, 0.8, 0.8)   # Blue for normal
const GIZMO_SIZE: float = 12.0
const ARROW_LENGTH: float = 8.0


## Get the grid position (tile coordinates) of this spawn point
var grid_position: Vector2i:
	get:
		return Vector2i(
			int(floor(global_position.x / tile_size)),
			int(floor(global_position.y / tile_size))
		)


## Get the world position snapped to tile center
var snapped_position: Vector2:
	get:
		var grid_pos: Vector2i = grid_position
		return Vector2(
			grid_pos.x * tile_size + tile_size / 2.0,
			grid_pos.y * tile_size + tile_size / 2.0
		)


## Get facing direction as Vector2i (for movement calculations)
var facing_vector: Vector2i:
	get:
		match facing:
			"up": return Vector2i.UP
			"down": return Vector2i.DOWN
			"left": return Vector2i.LEFT
			"right": return Vector2i.RIGHT
			_: return Vector2i.DOWN


func _ready() -> void:
	# Validate spawn_id in game mode
	if not Engine.is_editor_hint() and spawn_id.is_empty():
		push_warning("SpawnPoint at %s has no spawn_id set" % global_position)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	# Choose color based on spawn point type
	var color: Color = COLOR_NORMAL
	if is_default:
		color = COLOR_DEFAULT
	elif is_caravan_spawn:
		color = COLOR_CARAVAN

	# Draw circle at spawn position
	draw_circle(Vector2.ZERO, GIZMO_SIZE, color)

	# Draw border
	draw_arc(Vector2.ZERO, GIZMO_SIZE, 0, TAU, 32, color.darkened(0.3), 2.0)

	# Draw facing direction arrow
	var arrow_dir: Vector2 = Vector2.ZERO
	match facing:
		"up": arrow_dir = Vector2.UP
		"down": arrow_dir = Vector2.DOWN
		"left": arrow_dir = Vector2.LEFT
		"right": arrow_dir = Vector2.RIGHT

	var arrow_start: Vector2 = Vector2.ZERO
	var arrow_end: Vector2 = arrow_dir * (GIZMO_SIZE + ARROW_LENGTH)

	# Arrow shaft
	draw_line(arrow_start, arrow_end, Color.WHITE, 2.0)

	# Arrow head
	var perp: Vector2 = arrow_dir.rotated(PI / 2) * 4.0
	var head_base: Vector2 = arrow_end - arrow_dir * 6.0
	draw_line(arrow_end, head_base + perp, Color.WHITE, 2.0)
	draw_line(arrow_end, head_base - perp, Color.WHITE, 2.0)

	# Draw spawn_id label
	if not spawn_id.is_empty():
		# Note: draw_string requires a font, using simpler approach
		pass


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	if spawn_id.is_empty():
		warnings.append("spawn_id is not set - this spawn point cannot be referenced")

	return warnings


## Export spawn point data to dictionary (for MapMetadata)
func to_dict() -> Dictionary:
	return {
		"grid_position": grid_position,
		"facing": facing,
		"is_default": is_default,
		"is_caravan_spawn": is_caravan_spawn
	}


## Snap position to tile grid (editor helper)
func snap_to_grid() -> void:
	global_position = snapped_position
	queue_redraw()


# =============================================================================
# Static Helpers
# =============================================================================

## Find all SpawnPoint nodes in a scene tree
static func find_all_in_tree(root: Node) -> Array[SpawnPoint]:
	var spawn_points: Array[SpawnPoint] = []
	_find_spawn_points_recursive(root, spawn_points)
	return spawn_points


static func _find_spawn_points_recursive(node: Node, results: Array[SpawnPoint]) -> void:
	if node is SpawnPoint:
		results.append(node as SpawnPoint)

	for child: Node in node.get_children():
		_find_spawn_points_recursive(child, results)


## Find a spawn point by ID in a scene tree
static func find_by_id(root: Node, spawn_id: String) -> SpawnPoint:
	var all_spawns: Array[SpawnPoint] = find_all_in_tree(root)
	for spawn: SpawnPoint in all_spawns:
		if spawn.spawn_id == spawn_id:
			return spawn
	return null


## Find the default spawn point in a scene tree
static func find_default(root: Node) -> SpawnPoint:
	var all_spawns: Array[SpawnPoint] = find_all_in_tree(root)

	# First look for explicitly marked default
	for spawn: SpawnPoint in all_spawns:
		if spawn.is_default:
			return spawn

	# Fallback to first spawn point
	if not all_spawns.is_empty():
		return all_spawns[0]

	return null


## Find the caravan spawn point in a scene tree
static func find_caravan_spawn(root: Node) -> SpawnPoint:
	var all_spawns: Array[SpawnPoint] = find_all_in_tree(root)
	for spawn: SpawnPoint in all_spawns:
		if spawn.is_caravan_spawn:
			return spawn
	return null


## Find the nearest spawn point to a given grid position
static func find_nearest(root: Node, grid_pos: Vector2i) -> SpawnPoint:
	var all_spawns: Array[SpawnPoint] = find_all_in_tree(root)
	if all_spawns.is_empty():
		return null

	var nearest: SpawnPoint = null
	var nearest_distance: float = INF

	for spawn: SpawnPoint in all_spawns:
		var distance: float = Vector2(spawn.grid_position - grid_pos).length()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = spawn

	return nearest
