## Terrain Layering Integration Test
##
## Tests that the multi-layer terrain system correctly resolves terrain
## using "top layer wins" priority.
##
## Validates:
## - Single layer still works (backwards compatibility)
## - Two layers: top layer terrain wins when tile exists
## - Two layers: falls through to ground layer when top layer empty
## - Decoration tiles (not in registry) pass through to layer below
class_name TestTerrainLayering
extends GdUnitTestSuite


# Test terrain data
var _grass_terrain: TerrainData
var _road_terrain: TerrainData

# Layers
var _ground_layer: TileMapLayer
var _path_layer: TileMapLayer
var _tileset: TileSet

# Grid
var _grid_resource: Grid

# Container node
var _container: Node2D


func before() -> void:
	_container = Node2D.new()
	add_child(_container)
	_setup_terrain_registry()


func after() -> void:
	_cleanup()
	GridManager.clear_grid()


func before_test() -> void:
	# Clean slate for each test
	_cleanup_layers()


func _setup_terrain_registry() -> void:
	# Create grass terrain
	_grass_terrain = TerrainData.new()
	_grass_terrain.terrain_id = "test_grass"
	_grass_terrain.display_name = "Test Grass"
	_grass_terrain.defense_bonus = 0
	_grass_terrain.movement_cost_walking = 1

	# Create road terrain
	_road_terrain = TerrainData.new()
	_road_terrain.terrain_id = "test_road"
	_road_terrain.display_name = "Test Road"
	_road_terrain.defense_bonus = 0
	_road_terrain.movement_cost_walking = 1

	# Register terrains (use "test_mod" as source for cleanup)
	ModLoader.terrain_registry.register_terrain(_grass_terrain, "test_terrain_layering")
	ModLoader.terrain_registry.register_terrain(_road_terrain, "test_terrain_layering")


func _create_tileset_with_sources() -> TileSet:
	# Create a tileset with two atlas sources
	# Source 0: "test_grass" texture
	# Source 1: "test_road" texture
	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(32, 32)

	# Add custom data layer for terrain type (used by GridManager)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "terrain_type")
	ts.set_custom_data_layer_type(0, TYPE_STRING)

	# Create grass atlas source
	var grass_atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	var grass_texture: ImageTexture = _create_mock_texture(Color.GREEN)
	grass_atlas.texture = grass_texture
	grass_atlas.texture_region_size = Vector2i(32, 32)
	grass_atlas.create_tile(Vector2i(0, 0))
	ts.add_source(grass_atlas, 0)
	# Set terrain type via custom data (must be AFTER adding to TileSet)
	var grass_tile_data: TileData = grass_atlas.get_tile_data(Vector2i(0, 0), 0)
	grass_tile_data.set_custom_data("terrain_type", "test_grass")

	# Create road atlas source
	var road_atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	var road_texture: ImageTexture = _create_mock_texture(Color.BROWN)
	road_atlas.texture = road_texture
	road_atlas.texture_region_size = Vector2i(32, 32)
	road_atlas.create_tile(Vector2i(0, 0))
	ts.add_source(road_atlas, 1)
	# Set terrain type via custom data (must be AFTER adding to TileSet)
	var road_tile_data: TileData = road_atlas.get_tile_data(Vector2i(0, 0), 0)
	road_tile_data.set_custom_data("terrain_type", "test_road")

	# Create decoration atlas (not registered in terrain registry)
	var decor_atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	var decor_texture: ImageTexture = _create_mock_texture(Color.YELLOW)
	decor_atlas.texture = decor_texture
	decor_atlas.texture_region_size = Vector2i(32, 32)
	decor_atlas.create_tile(Vector2i(0, 0))
	ts.add_source(decor_atlas, 2)
	# Set terrain type to something NOT in registry (decoration)
	var decor_tile_data: TileData = decor_atlas.get_tile_data(Vector2i(0, 0), 0)
	decor_tile_data.set_custom_data("terrain_type", "test_decoration")

	return ts


func _create_mock_texture(color: Color) -> ImageTexture:
	# Create a minimal 32x32 texture with no resource_path
	# Terrain ID is now handled via TileSet custom data layer, not filename
	var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	# DO NOT set resource_path - it causes conflicts in Godot's resource cache
	# when multiple tests create textures with the same path
	return texture


func _setup_single_layer(grid_size: Vector2i = Vector2i(10, 10)) -> void:
	_tileset = _create_tileset_with_sources()

	_ground_layer = TileMapLayer.new()
	_ground_layer.name = "GroundLayer"
	_ground_layer.tile_set = _tileset
	_ground_layer.z_index = 0
	_container.add_child(_ground_layer)

	_grid_resource = Grid.new()
	_grid_resource.grid_size = grid_size
	_grid_resource.cell_size = 32

	GridManager.setup_grid(_grid_resource, [_ground_layer])


func _setup_two_layers(grid_size: Vector2i = Vector2i(10, 10)) -> void:
	_tileset = _create_tileset_with_sources()

	# Ground layer (base terrain)
	_ground_layer = TileMapLayer.new()
	_ground_layer.name = "GroundLayer"
	_ground_layer.tile_set = _tileset
	_ground_layer.z_index = 0
	_container.add_child(_ground_layer)

	# Path layer (overlay terrain)
	_path_layer = TileMapLayer.new()
	_path_layer.name = "PathLayer"
	_path_layer.tile_set = _tileset
	_path_layer.z_index = 1
	_container.add_child(_path_layer)

	_grid_resource = Grid.new()
	_grid_resource.grid_size = grid_size
	_grid_resource.cell_size = 32

	# Pass layers sorted by z_index descending (top layer first)
	GridManager.setup_grid(_grid_resource, [_path_layer, _ground_layer])


func _cleanup_layers() -> void:
	if _ground_layer and is_instance_valid(_ground_layer):
		_ground_layer.queue_free()
		_ground_layer = null
	if _path_layer and is_instance_valid(_path_layer):
		_path_layer.queue_free()
		_path_layer = null
	_tileset = null
	_grid_resource = null


func _cleanup() -> void:
	_cleanup_layers()
	if _container and is_instance_valid(_container):
		_container.queue_free()
		_container = null

	# Unregister all test terrains
	ModLoader.terrain_registry.unregister_mod("test_terrain_layering")


# =============================================================================
# TEST CASES
# =============================================================================

func test_single_layer_returns_ground_terrain() -> void:
	# Arrange
	_setup_single_layer()

	# Paint grass on ground layer at cell (5, 5)
	_ground_layer.set_cell(Vector2i(5, 5), 0, Vector2i(0, 0))  # source 0 = grass

	# Reload terrain data after painting
	GridManager.load_terrain_data()

	# Act
	var terrain: TerrainData = GridManager.get_terrain_at_cell(Vector2i(5, 5))

	# Assert
	assert_str(terrain.terrain_id).is_equal("test_grass")


func test_two_layers_top_layer_wins_when_tile_exists() -> void:
	# Arrange
	_setup_two_layers()

	# Paint grass on ground layer
	_ground_layer.set_cell(Vector2i(5, 5), 0, Vector2i(0, 0))  # source 0 = grass

	# Paint road on path layer (same cell)
	_path_layer.set_cell(Vector2i(5, 5), 1, Vector2i(0, 0))  # source 1 = road

	# Reload terrain data
	GridManager.load_terrain_data()

	# Act
	var terrain: TerrainData = GridManager.get_terrain_at_cell(Vector2i(5, 5))

	# Assert - road should win (top layer)
	assert_str(terrain.terrain_id).is_equal("test_road")


func test_two_layers_falls_through_when_top_layer_empty() -> void:
	# Arrange
	_setup_two_layers()

	# Paint grass on ground layer
	_ground_layer.set_cell(Vector2i(5, 5), 0, Vector2i(0, 0))  # source 0 = grass

	# Path layer is empty at this cell

	# Reload terrain data
	GridManager.load_terrain_data()

	# Act
	var terrain: TerrainData = GridManager.get_terrain_at_cell(Vector2i(5, 5))

	# Assert - grass should be used (fell through from ground layer)
	assert_str(terrain.terrain_id).is_equal("test_grass")


func test_decoration_tiles_pass_through_to_ground() -> void:
	# Arrange
	_setup_two_layers()

	# Paint grass on ground layer
	_ground_layer.set_cell(Vector2i(5, 5), 0, Vector2i(0, 0))  # source 0 = grass

	# Paint decoration on path layer (source 2 = decoration, not in registry)
	_path_layer.set_cell(Vector2i(5, 5), 2, Vector2i(0, 0))  # source 2 = decoration

	# Reload terrain data
	GridManager.load_terrain_data()

	# Act
	var terrain: TerrainData = GridManager.get_terrain_at_cell(Vector2i(5, 5))

	# Assert - grass should be used (decoration passed through)
	assert_str(terrain.terrain_id).is_equal("test_grass")


func test_movement_cost_uses_top_layer_terrain() -> void:
	# Arrange
	_setup_two_layers()

	# Make road have different movement cost for this test
	_road_terrain.movement_cost_walking = 1
	_grass_terrain.movement_cost_walking = 2  # Grass is slower

	# Paint grass everywhere on ground
	for x: int in range(10):
		for y: int in range(10):
			_ground_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))

	# Paint road on path layer at specific cell
	_path_layer.set_cell(Vector2i(5, 5), 1, Vector2i(0, 0))

	# Reload terrain data
	GridManager.load_terrain_data()

	# Act
	var grass_cost: float = GridManager.get_terrain_cost(Vector2i(3, 3), 0)  # No road
	var road_cost: float = GridManager.get_terrain_cost(Vector2i(5, 5), 0)   # Has road

	# Assert
	assert_float(grass_cost).is_equal(2.0)  # Grass cost
	assert_float(road_cost).is_equal(1.0)   # Road cost (top layer wins)


func test_empty_cell_returns_fallback_terrain() -> void:
	# Arrange
	_setup_two_layers()

	# Don't paint anything - both layers empty

	# Reload terrain data
	GridManager.load_terrain_data()

	# Act
	var terrain: TerrainData = GridManager.get_terrain_at_cell(Vector2i(5, 5))

	# Assert - should return plains fallback
	assert_str(terrain.terrain_id).is_equal("plains")
