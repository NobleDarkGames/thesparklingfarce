## Smooth scrolling camera controller for tactical RPG battles
##
## Provides smooth camera movement with grid-based boundaries.
## Designed for pixel-perfect rendering with configurable follow behavior.
## Can track cursor position, active units, or manual control.
##
## LIFECYCLE:
## 1. Create CameraController in your scene (battle or exploration)
## 2. Call register_with_systems() to register with TurnManager and CinematicsManager
## 3. Systems will automatically use this camera for turn transitions and cinematics
## 4. Camera is automatically unregistered when the scene is freed
##
## Example:
##   var camera = $BattleCamera as CameraController
##   camera.register_with_systems()
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

## Camera mode - determines movement speed and style
## TACTICAL: Fast linear pans for responsive gameplay (SF-style)
## CINEMATIC: Slower eased movements for story moments
enum CameraMode {
	TACTICAL,   ## Fast linear panning for battle/cursor movement
	CINEMATIC   ## Smooth eased panning for cutscenes/story
}

@export var camera_mode: CameraMode = CameraMode.TACTICAL

## Interpolation type for camera movement
enum InterpolationType {
	LINEAR,        ## Simple linear interpolation (lerp)
	EASE_IN,       ## Slow start, fast end
	EASE_OUT,      ## Fast start, slow end
	EASE_IN_OUT,   ## Slow start and end, fast middle
	CUBIC          ## Smooth cubic curve
}

## Tactical mode settings (fast, responsive, SF-style)
@export_group("Tactical Mode")
@export_range(0.1, 1.0, 0.05) var tactical_duration: float = 0.2
@export var tactical_interpolation: InterpolationType = InterpolationType.LINEAR

## Cinematic mode settings (smooth, dramatic)
@export_group("Cinematic Mode")
@export_range(0.2, 2.0, 0.1) var cinematic_duration: float = 0.6
@export var cinematic_interpolation: InterpolationType = InterpolationType.EASE_IN_OUT

## Legacy exports (use camera_mode instead)
@export_group("Legacy")
@export var smooth_movement: bool = true  ## Always true now, use camera_mode for speed

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

## Current movement tween
var _movement_tween: Tween = null

## Camera shake state
var _is_shaking: bool = false
var _shake_intensity: float = 0.0
var _shake_time_remaining: float = 0.0
var _shake_frequency: float = 30.0
var _shake_elapsed: float = 0.0

## Continuous follow state
var _follow_target: Node2D = null
var _follow_speed: float = 8.0

## Signals for async operations (Phase 3: cinematics integration)
signal movement_completed()
signal shake_completed()
signal operation_completed()  ## Generic signal for any async operation


func _ready() -> void:
	# Enable the camera
	enabled = true

	# Start at current position
	_target_position = position

	# Find tilemap in parent scene
	_find_tilemap()

	# Calculate and set camera limits
	_update_camera_limits()

	# Clean up when scene is freed
	tree_exiting.connect(_on_tree_exiting)


## Register this camera with game systems (TurnManager, CinematicsManager)
## Call this after adding the camera to the scene tree
func register_with_systems() -> void:
	# Register with TurnManager for battle transitions
	if TurnManager:
		TurnManager.battle_camera = self

	# Register with CinematicsManager for cinematic sequences
	if CinematicsManager:
		CinematicsManager.register_camera(self)

	print("CameraController: Registered with TurnManager and CinematicsManager")


## Unregister from systems when being freed
func _on_tree_exiting() -> void:
	# Clear references to prevent stale pointers
	if TurnManager and TurnManager.battle_camera == self:
		TurnManager.battle_camera = null

	if CinematicsManager and CinematicsManager._active_camera == self:
		CinematicsManager._active_camera = null


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
	# Handle continuous follow
	if _follow_target and is_instance_valid(_follow_target):
		var target_pos: Vector2 = _follow_target.global_position
		position = position.lerp(target_pos, _follow_speed * delta)

	# Handle camera shake
	if _is_shaking:
		_shake_elapsed += delta
		_shake_time_remaining -= delta

		if _shake_time_remaining <= 0.0:
			_on_shake_completed()
			return

		# Calculate shake offset using sine wave for smooth oscillation
		var shake_amount: float = _shake_intensity * (_shake_time_remaining / (_shake_time_remaining + _shake_elapsed))
		var angle: float = _shake_elapsed * _shake_frequency

		offset = Vector2(
			cos(angle) * shake_amount * randf_range(0.8, 1.2),
			sin(angle * 1.3) * shake_amount * randf_range(0.8, 1.2)
		)


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


## Set target position for camera to move to
func set_target_position(target: Vector2) -> void:
	_target_position = target
	follow_mode = FollowMode.TARGET_POSITION

	# Kill any existing tween
	if _movement_tween and _movement_tween.is_valid():
		_movement_tween.kill()
		_movement_tween = null

	# Get mode-based settings
	var duration: float = _get_current_duration()
	var interp_type: InterpolationType = _get_current_interpolation()

	# Create new tween for smooth movement
	_movement_tween = create_tween()

	# Apply interpolation based on current camera mode
	_apply_interpolation(_movement_tween, interp_type)

	# Tween to target position
	_movement_tween.tween_property(self, "position", _target_position, duration)

	# Snap to pixel after tween completes and emit completion signal
	_movement_tween.tween_callback(func() -> void:
		position = position.floor()
		movement_completed.emit()
	)


## Follow a specific unit smoothly
## Moves camera to center on the given unit's position.
func follow_unit(unit: Node2D) -> void:
	if not unit:
		push_warning("CameraController: Cannot follow null unit")
		return

	# Get unit's world position
	var unit_position: Vector2 = unit.global_position

	# Set as target and enable target position mode
	set_target_position(unit_position)


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


## Set camera to tactical mode (fast linear panning for gameplay)
func set_tactical_mode() -> void:
	camera_mode = CameraMode.TACTICAL


## Set camera to cinematic mode (smooth eased panning for story moments)
func set_cinematic_mode() -> void:
	camera_mode = CameraMode.CINEMATIC


## Get current movement duration based on camera mode
func _get_current_duration() -> float:
	match camera_mode:
		CameraMode.TACTICAL:
			return tactical_duration
		CameraMode.CINEMATIC:
			return cinematic_duration
	return tactical_duration


## Get current interpolation type based on camera mode
func _get_current_interpolation() -> InterpolationType:
	match camera_mode:
		CameraMode.TACTICAL:
			return tactical_interpolation
		CameraMode.CINEMATIC:
			return cinematic_interpolation
	return tactical_interpolation


## Apply interpolation settings to a tween based on type
func _apply_interpolation(tween: Tween, interp_type: InterpolationType) -> void:
	match interp_type:
		InterpolationType.LINEAR:
			tween.set_trans(Tween.TRANS_LINEAR)
		InterpolationType.EASE_IN:
			tween.set_trans(Tween.TRANS_QUAD)
			tween.set_ease(Tween.EASE_IN)
		InterpolationType.EASE_OUT:
			tween.set_trans(Tween.TRANS_QUAD)
			tween.set_ease(Tween.EASE_OUT)
		InterpolationType.EASE_IN_OUT:
			tween.set_trans(Tween.TRANS_QUAD)
			tween.set_ease(Tween.EASE_IN_OUT)
		InterpolationType.CUBIC:
			tween.set_trans(Tween.TRANS_CUBIC)
			tween.set_ease(Tween.EASE_IN_OUT)


## Apply screen shake effect (Phase 3: cinematics & battle integration)
## intensity: Maximum pixel offset for shake
## duration: How long the shake lasts in seconds
## frequency: Oscillation frequency (higher = faster shaking)
func shake(intensity: float, duration: float, frequency: float = 30.0) -> void:
	_shake_intensity = intensity
	_shake_frequency = frequency
	_shake_time_remaining = duration
	_shake_elapsed = 0.0
	_is_shaking = true


## Move camera to a world position (not grid-based)
## target: World position in pixels
## custom_duration: Optional override for mode-based duration (-1 uses mode default)
## wait: If true, emits movement_completed signal when done
func move_to_position(target: Vector2, custom_duration: float = -1.0, wait: bool = false) -> void:
	_target_position = target
	follow_mode = FollowMode.TARGET_POSITION

	# Kill any existing tween
	if _movement_tween and _movement_tween.is_valid():
		_movement_tween.kill()
		_movement_tween = null

	# Get mode-based settings, with optional duration override
	var duration: float = custom_duration if custom_duration > 0.0 else _get_current_duration()
	var interp_type: InterpolationType = _get_current_interpolation()

	# Create new tween for smooth movement
	_movement_tween = create_tween()

	# Apply interpolation based on current camera mode
	_apply_interpolation(_movement_tween, interp_type)

	# Tween to target position
	_movement_tween.tween_property(self, "position", _target_position, duration)

	# Snap to pixel and emit signal if waiting
	if wait:
		_movement_tween.tween_callback(func() -> void:
			position = position.floor()
			movement_completed.emit()
			operation_completed.emit()
		)
	else:
		_movement_tween.tween_callback(func() -> void: position = position.floor())


## Follow an actor continuously (Phase 3: cinematics integration)
## actor: Node2D to follow (CinematicActor parent, Unit, etc.)
## speed: Lerp speed for smooth following (higher = faster)
## initial_duration: Duration for initial movement to actor position
func follow_actor(actor: Node2D, speed: float = 8.0, initial_duration: float = 0.5) -> void:
	if not actor or not is_instance_valid(actor):
		push_warning("CameraController: Cannot follow null or invalid actor")
		return

	_follow_target = actor
	_follow_speed = speed
	follow_mode = FollowMode.ACTIVE_UNIT

	# Do initial smooth move to actor position
	var actor_pos: Vector2 = actor.global_position
	move_to_position(actor_pos, initial_duration, false)


## Stop continuous following
func stop_follow() -> void:
	_follow_target = null
	follow_mode = FollowMode.NONE


## Internal: Called when shake completes
func _on_shake_completed() -> void:
	_is_shaking = false
	offset = Vector2.ZERO
	shake_completed.emit()
	operation_completed.emit()
