## MapCamera - Camera controller for map exploration mode
##
## Smoothly follows the hero with optional lookahead in the movement direction.
class_name MapCamera
extends Camera2D

@export var follow_speed: float = 8.0  ## How quickly camera follows target
@export var lookahead_distance: float = 32.0  ## Pixels to look ahead in movement direction
@export var enable_lookahead: bool = false  ## Whether to use lookahead (disabled for authentic SF feel)

## Target to follow (usually the HeroController)
var follow_target: Node2D = null

## Previous target position for calculating movement direction
var _previous_target_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Setup camera properties for pixel-perfect rendering
	position_smoothing_enabled = false  # We handle smoothing manually

	# Initialize previous position
	if follow_target:
		_previous_target_pos = follow_target.global_position
		global_position = follow_target.global_position


func _process(delta: float) -> void:
	if not follow_target:
		return

	# Calculate target camera position
	var target_pos: Vector2 = follow_target.global_position

	# Add lookahead if enabled
	if enable_lookahead:
		var movement_dir: Vector2 = (target_pos - _previous_target_pos).normalized()

		# Only apply lookahead if target is moving
		if movement_dir.length() > 0.1:
			target_pos += movement_dir * lookahead_distance

	# Smooth camera movement
	global_position = global_position.lerp(target_pos, follow_speed * delta)

	# Pixel-perfect snapping for non-integer zoom levels
	# At 0.8x zoom, snap to 1.25 pixel intervals to prevent texture shimmer
	if zoom.x != 1.0:
		var snap_interval: float = 1.0 / zoom.x
		global_position = (global_position / snap_interval).round() * snap_interval

	# Update previous position
	_previous_target_pos = follow_target.global_position


## Set the target to follow.
func set_follow_target(target: Node2D) -> void:
	follow_target = target

	if follow_target:
		_previous_target_pos = follow_target.global_position
		global_position = follow_target.global_position


## Instantly move camera to target (for scene transitions).
func snap_to_target() -> void:
	if follow_target:
		global_position = follow_target.global_position
		_previous_target_pos = follow_target.global_position


## Move camera to a specific grid cell.
## Useful for inspection mode or cutscenes.
func move_to_cell(cell_pos: Vector2i, tile_size: int = 32) -> void:
	var world_pos: Vector2 = Vector2(cell_pos) * tile_size + Vector2(tile_size, tile_size) * 0.5
	global_position = global_position.lerp(world_pos, follow_speed * get_process_delta_time())
