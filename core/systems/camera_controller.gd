## Smooth scrolling camera controller for tactical RPG battles
##
## Provides smooth camera movement with grid-based boundaries.
## Designed for pixel-perfect rendering with configurable follow behavior.
## Can track cursor position, active units, or manual control.
class_name CameraController
extends Camera2D

## Reference to the Grid resource for this battle
@export var grid: Resource  # Grid resource

## Camera follow mode
enum FollowMode {
	NONE,           ## Camera doesn't move automatically
	CURSOR,         ## Camera follows cursor position
	ACTIVE_UNIT,    ## Camera follows the currently active unit
	TARGET_POSITION ## Camera moves to a specific target position
}

@export var follow_mode: FollowMode = FollowMode.NONE

## Speed of camera interpolation (higher = faster)
@export_range(1.0, 20.0, 0.5) var follow_speed: float = 8.0

## Enable smooth camera movement (lerp) or instant snap
@export var smooth_movement: bool = true

## Dead zone - cursor must be this far from screen center before camera moves
## Measured in pixels at base resolution (640x360)
@export var dead_zone_size: Vector2 = Vector2(160, 90)

## Margin from map edges in pixels (prevents camera from showing outside map)
@export var edge_margin: int = 16

## Current target position the camera is moving toward
var _target_position: Vector2 = Vector2.ZERO

## Reference to the tilemap for boundary calculations
var _tilemap: TileMapLayer = null

## Cache for map bounds
var _map_bounds: Rect2i = Rect2i()


func _ready() -> void:
	# Enable the camera
	enabled = true

	# Start at current position
	_target_position = position

	# Find tilemap in parent scene
	_find_tilemap()

	# Calculate and set camera limits
	_update_camera_limits()


## Find the TileMapLayer in the scene tree
func _find_tilemap() -> void:
	# Look for TileMapLayer in parent or siblings
	var parent: Node = get_parent()
	if parent:
		for child in parent.get_children():
			if child is TileMapLayer:
				_tilemap = child
				break

	if not _tilemap:
		push_warning("CameraController: No TileMapLayer found in scene. Camera limits may not work correctly.")


## Update camera limits based on tilemap bounds and grid
func _update_camera_limits() -> void:
	if not _tilemap:
		return

	# Get the used rect from tilemap (in grid coordinates)
	var used_rect: Rect2i = _tilemap.get_used_rect()

	# Convert to pixel coordinates
	var tile_size: Vector2i = _tilemap.tile_set.tile_size if _tilemap.tile_set else Vector2i(32, 32)

	# Calculate map bounds in pixels
	var map_pixel_size: Vector2i = used_rect.size * tile_size
	var map_origin: Vector2i = used_rect.position * tile_size

	# Get viewport size (base resolution: 640x360)
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_viewport: Vector2 = viewport_size / 2.0

	# Set limits with margins
	# Camera position is at center, so we need to account for half viewport
	limit_left = map_origin.x + edge_margin
	limit_top = map_origin.y + edge_margin
	limit_right = map_origin.x + map_pixel_size.x - edge_margin
	limit_bottom = map_origin.y + map_pixel_size.y - edge_margin

	# Store map bounds for reference
	_map_bounds = Rect2i(map_origin, map_pixel_size)


func _process(delta: float) -> void:
	# Update target based on follow mode
	match follow_mode:
		FollowMode.CURSOR:
			_follow_cursor()
		FollowMode.ACTIVE_UNIT:
			_follow_active_unit()
		FollowMode.TARGET_POSITION:
			pass  # Target is set externally via set_target_position()
		FollowMode.NONE:
			return

	# Move camera toward target
	_update_camera_position(delta)


## Follow cursor with dead zone
func _follow_cursor() -> void:
	var cursor_pos: Vector2 = get_global_mouse_position()
	var camera_to_cursor: Vector2 = cursor_pos - global_position

	# Check if cursor is outside dead zone
	if abs(camera_to_cursor.x) > dead_zone_size.x / 2.0:
		_target_position.x = cursor_pos.x

	if abs(camera_to_cursor.y) > dead_zone_size.y / 2.0:
		_target_position.y = cursor_pos.y


## Follow the currently active unit (placeholder for Phase 3)
func _follow_active_unit() -> void:
	# TODO: Get active unit position from BattleManager
	# For now, this is a placeholder
	pass


## Update camera position with smooth interpolation or instant snap
func _update_camera_position(delta: float) -> void:
	if smooth_movement:
		# Smooth interpolation
		position = position.lerp(_target_position, follow_speed * delta)
		# Snap to pixel to prevent sub-pixel rendering
		position = position.floor()
	else:
		# Instant snap
		position = _target_position.floor()


## Set target position for camera to move to
func set_target_position(target: Vector2) -> void:
	_target_position = target
	follow_mode = FollowMode.TARGET_POSITION


## Move camera to grid cell (centered)
func move_to_cell(cell: Vector2i) -> void:
	if grid and grid.has_method("map_to_local"):
		set_target_position(grid.map_to_local(cell))
	else:
		push_warning("CameraController: No Grid resource assigned")


## Instantly snap camera to target (no interpolation)
func snap_to_target() -> void:
	position = _target_position.floor()


## Get current cell the camera is centered on
func get_current_cell() -> Vector2i:
	if grid and grid.has_method("local_to_map"):
		return grid.local_to_map(position)
	return Vector2i.ZERO


## Recalculate camera limits (call when map changes)
func refresh_limits() -> void:
	_update_camera_limits()


## Enable/disable camera following
func set_follow_mode(mode: FollowMode) -> void:
	follow_mode = mode
	if mode == FollowMode.NONE:
		_target_position = position
