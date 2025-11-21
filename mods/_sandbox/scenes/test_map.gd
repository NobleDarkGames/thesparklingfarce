## Test map scene script
##
## Purpose: Provides map data for test_full_battle.tscn
## This map provides Grid configuration for BattleManager to extract.
## This demonstrates the proper separation: map scenes contain Grid info,
## not BattleData.
##
## Used by: test_full_battle.tscn
extends Node2D

## Grid configuration for this map
@export var grid: Grid

func _ready() -> void:
	# If no grid was set in the editor, create a default one
	if not grid:
		grid = Grid.new()
		grid.grid_size = Vector2i(20, 11)
		grid.cell_size = 32
		print("TestMap: Created default Grid (%s)" % grid.grid_size)
	else:
		print("TestMap: Using exported Grid (%s)" % grid.grid_size)
