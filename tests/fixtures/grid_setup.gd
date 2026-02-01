## Shared test fixture for setting up Grid and TileMapLayer
##
## Dependencies (autoloads that must be initialized):
## - GridManager: Called via GridManager.setup_grid()
##
## This fixture is for INTEGRATION TESTS ONLY.
## Do not use in unit tests that should be autoload-free.
##
## Usage:
##   var setup: GridSetup = GridSetup.new()
##   setup.create_grid(parent_node, Vector2i(20, 15))
##   # ... run tests ...
##   setup.cleanup()
class_name GridSetup
extends RefCounted


var tilemap_layer: TileMapLayer
var tileset: TileSet
var grid_resource: Grid


## Create a minimal grid setup for testing
func create_grid(
	parent: Node,
	grid_size: Vector2i = Vector2i(20, 15),
	cell_size: int = 32
) -> void:
	tileset = TileSet.new()
	tilemap_layer = TileMapLayer.new()
	tilemap_layer.tile_set = tileset
	parent.add_child(tilemap_layer)

	grid_resource = Grid.new()
	grid_resource.grid_size = grid_size
	grid_resource.cell_size = cell_size
	GridManager.setup_grid(grid_resource, [tilemap_layer])


## Clean up the grid setup
func cleanup() -> void:
	if tilemap_layer and is_instance_valid(tilemap_layer):
		tilemap_layer.queue_free()
		tilemap_layer = null
	tileset = null
	grid_resource = null
