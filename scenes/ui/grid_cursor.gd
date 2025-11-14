## GridCursor - Visual cursor for grid-based movement selection
##
## Shows where the player is currently targeting on the grid
extends Node2D

## Current grid position
var grid_position: Vector2i = Vector2i.ZERO

## Cursor visual
@onready var cursor_sprite: ColorRect = $CursorSprite


## Set cursor to specific grid position
func set_grid_position(cell: Vector2i) -> void:
	grid_position = cell
	position = GridManager.cell_to_world(cell)


## Move cursor by offset
func move_by(offset: Vector2i) -> void:
	set_grid_position(grid_position + offset)


## Show cursor
func show_cursor() -> void:
	visible = true


## Hide cursor
func hide_cursor() -> void:
	visible = false


## Pulse animation (optional visual feedback)
func pulse() -> void:
	# TODO: Add tween animation for visual feedback
	pass
