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

## Cinematic override target - when set, camera follows this instead of follow_target
## Used during exploration cinematics to pan to speaking actors
var _cinematic_target: Node2D = null

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
	# Cinematic target takes priority over normal follow target
	var active_target: Node2D = _cinematic_target if _cinematic_target else follow_target
	if not active_target:
		return

	# Calculate target camera position
	var target_pos: Vector2 = active_target.global_position

	# Add lookahead if enabled
	if enable_lookahead:
		var movement_dir: Vector2 = (target_pos - _previous_target_pos).normalized()

		# Only apply lookahead if target is moving
		if movement_dir.length() > 0.1:
			target_pos += movement_dir * lookahead_distance

	# Smooth camera movement
	global_position = global_position.lerp(target_pos, follow_speed * delta)

	# Snap to pixel for clean rendering (works with 1.0 zoom)
	global_position = global_position.round()

	# Update previous position
	_previous_target_pos = active_target.global_position


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


# =============================================================================
# CINEMATIC CONTROL
# =============================================================================

## Set a temporary target to follow during cinematics.
## Camera will smoothly pan to and follow this target instead of the hero.
## Call clear_cinematic_target() to resume hero following.
func set_cinematic_target(target: Node2D) -> void:
	_cinematic_target = target


## Clear the cinematic target, resuming normal hero following.
func clear_cinematic_target() -> void:
	_cinematic_target = null


## Check if camera is currently following a cinematic target.
func has_cinematic_target() -> bool:
	return _cinematic_target != null
