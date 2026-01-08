## GridCursor - Visual cursor for grid-based movement selection
##
## Shows where the player is currently targeting on the grid.
## Features idle bob animation and pulse feedback on selection.
## Supports multiple cursor modes for different battle states (SF2-authentic).
class_name GridCursor
extends Node2D

const UIColors = preload("res://core/utils/ui_colors.gd")

## Cursor mode determines visual style and animation
enum CursorMode {
	ACTIVE_UNIT,     ## Yellow pulsing - "this unit's turn is starting"
	READY_TO_ACT,    ## White bouncing - "waiting for action selection"
	TARGETING,       ## Red (enemy) / Green (ally) bouncing - "select a target"
}

## Current grid position
var grid_position: Vector2i = Vector2i.ZERO

## Current cursor mode
var current_mode: CursorMode = CursorMode.READY_TO_ACT

## Cursor visual
@onready var cursor_sprite: Sprite2D = $CursorSprite

## Animation settings (exported for modders)
@export var bob_amplitude: float = 3.0   ## Pixels to bob up/down (SF2-authentic: 3-4px)
@export var bob_duration: float = 0.6    ## Full cycle duration in seconds (SF2-authentic: ~0.6s)
@export var pulse_scale: float = 1.2     ## Scale multiplier on pulse

## Mode-specific colors (exported for modders, defaults from UIColors)
@export var color_active_unit: Color = UIColors.CURSOR_ACTIVE_UNIT
@export var color_ready_to_act: Color = UIColors.CURSOR_READY_TO_ACT
@export var color_target_enemy: Color = UIColors.CURSOR_TARGET_ENEMY
@export var color_target_ally: Color = UIColors.CURSOR_TARGET_ALLY

## Animation state
var _idle_tween: Tween = null
var _pulse_tween: Tween = null
var _scale_tween: Tween = null
var _base_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Store original offset for animation
	if cursor_sprite:
		_base_offset = cursor_sprite.offset
	_start_idle_animation()


func _exit_tree() -> void:
	# Kill all tweens to prevent callbacks on freed node
	_stop_all_animations()


## Set cursor mode with appropriate visual style
## mode: The cursor mode (ACTIVE_UNIT, READY_TO_ACT, TARGETING)
## is_ally: For TARGETING mode, whether target is ally (green) or enemy (red)
func set_cursor_mode(mode: CursorMode, is_ally: bool = false) -> void:
	current_mode = mode

	if not cursor_sprite:
		return

	# Stop existing animations
	_stop_all_animations()

	# Apply mode-specific color and animation
	match mode:
		CursorMode.ACTIVE_UNIT:
			cursor_sprite.modulate = color_active_unit
			_start_scale_pulse_animation()  # Slow pulse for "your turn"
		CursorMode.READY_TO_ACT:
			cursor_sprite.modulate = color_ready_to_act
			_start_idle_animation()  # Standard SF2-style bounce
		CursorMode.TARGETING:
			cursor_sprite.modulate = color_target_ally if is_ally else color_target_enemy
			_start_idle_animation()  # Bounce for targeting


## Stop all cursor animations
func _stop_all_animations() -> void:
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
		_idle_tween = null
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
		_scale_tween = null
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null

	# Reset to base state
	if cursor_sprite:
		cursor_sprite.offset = _base_offset
		cursor_sprite.scale = Vector2.ONE


## Start scale pulse animation (for ACTIVE_UNIT mode - slow gentle pulse)
func _start_scale_pulse_animation() -> void:
	if not GameJuice or not GameJuice.animate_cursor:
		return

	if not cursor_sprite:
		return

	# Create looping scale pulse
	_scale_tween = create_tween()
	_scale_tween.set_loops()

	# Pulse up (scale to 1.08)
	_scale_tween.tween_property(
		cursor_sprite,
		"scale",
		Vector2(1.08, 1.08),
		0.4
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Pulse down (scale back to 1.0)
	_scale_tween.tween_property(
		cursor_sprite,
		"scale",
		Vector2.ONE,
		0.4
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


## Start or restart the idle bob animation (SF2-authentic "hop" pattern)
func _start_idle_animation() -> void:
	if not GameJuice or not GameJuice.animate_cursor:
		return

	if not cursor_sprite:
		return

	# Kill existing tween if running
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()

	# Reset to base offset
	cursor_sprite.offset = _base_offset

	# Create looping bob animation (SF2-style "hop" - quick up, pause, quick down)
	_idle_tween = create_tween()
	_idle_tween.set_loops()

	# Quick rise (30% of cycle)
	_idle_tween.tween_property(
		cursor_sprite,
		"offset:y",
		_base_offset.y - bob_amplitude,
		bob_duration * 0.3
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Pause at top (40% of cycle)
	_idle_tween.tween_interval(bob_duration * 0.4)

	# Quick drop (30% of cycle)
	_idle_tween.tween_property(
		cursor_sprite,
		"offset:y",
		_base_offset.y,
		bob_duration * 0.3
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


## Stop idle animation (legacy - use _stop_all_animations() for full cleanup)
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


## Show cursor with animation (uses current mode)
func show_cursor() -> void:
	visible = true
	# Restart animation based on current mode
	match current_mode:
		CursorMode.ACTIVE_UNIT:
			_start_scale_pulse_animation()
		CursorMode.READY_TO_ACT, CursorMode.TARGETING:
			_start_idle_animation()


## Hide cursor and stop all animations
func hide_cursor() -> void:
	visible = false
	_stop_all_animations()


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
