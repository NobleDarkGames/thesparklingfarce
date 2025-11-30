## GridCursor - Visual cursor for grid-based movement selection
##
## Shows where the player is currently targeting on the grid.
## Features idle bob animation and pulse feedback on selection.
extends Node2D

## Current grid position
var grid_position: Vector2i = Vector2i.ZERO

## Cursor visual
@onready var cursor_sprite: Sprite2D = $CursorSprite

## Animation settings (exported for modders)
@export var bob_amplitude: float = 2.0   ## Pixels to bob up/down
@export var bob_duration: float = 0.8    ## Full cycle duration in seconds
@export var pulse_scale: float = 1.2     ## Scale multiplier on pulse

## Animation state
var _idle_tween: Tween = null
var _pulse_tween: Tween = null
var _base_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Store original offset for animation
	if cursor_sprite:
		_base_offset = cursor_sprite.offset
	_start_idle_animation()


## Start or restart the idle bob animation
func _start_idle_animation() -> void:
	if not GameJuice.animate_cursor:
		return

	if not cursor_sprite:
		return

	# Kill existing tween if running
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()

	# Reset to base offset
	cursor_sprite.offset = _base_offset

	# Create looping bob animation
	_idle_tween = create_tween()
	_idle_tween.set_loops()

	# Bob up
	_idle_tween.tween_property(
		cursor_sprite,
		"offset:y",
		_base_offset.y - bob_amplitude,
		bob_duration / 2.0
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Bob down
	_idle_tween.tween_property(
		cursor_sprite,
		"offset:y",
		_base_offset.y + bob_amplitude,
		bob_duration / 2.0
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


## Stop idle animation
func _stop_idle_animation() -> void:
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
		_idle_tween = null

	# Reset offset
	if cursor_sprite:
		cursor_sprite.offset = _base_offset


## Set cursor to specific grid position
func set_grid_position(cell: Vector2i) -> void:
	grid_position = cell
	position = GridManager.cell_to_world(cell)


## Move cursor by offset
func move_by(offset: Vector2i) -> void:
	set_grid_position(grid_position + offset)


## Show cursor with animation
func show_cursor() -> void:
	visible = true
	_start_idle_animation()


## Hide cursor
func hide_cursor() -> void:
	visible = false
	_stop_idle_animation()


## Pulse animation for visual feedback (e.g., on selection confirm)
func pulse() -> void:
	if not cursor_sprite:
		return

	# Kill existing pulse if running
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	# Scale up then back to normal
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(
		cursor_sprite,
		"scale",
		Vector2(pulse_scale, pulse_scale),
		0.08
	).set_ease(Tween.EASE_OUT)

	_pulse_tween.tween_property(
		cursor_sprite,
		"scale",
		Vector2.ONE,
		0.12
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
