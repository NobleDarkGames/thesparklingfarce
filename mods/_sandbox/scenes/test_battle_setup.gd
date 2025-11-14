## Test battle scene setup
##
## Generates a simple test map for camera and movement testing.
## This creates a procedural tilemap with a checkerboard pattern.
extends Node2D

## Size of the test map in tiles (will be calculated from viewport)
var map_size: Vector2i = Vector2i(40, 30)

## TileMapLayer reference
var _ground_layer: TileMapLayer = null


func _ready() -> void:
	# Find the ground layer
	_ground_layer = $Map/GroundLayer

	if not _ground_layer:
		push_error("TestBattle: Could not find GroundLayer")
		return

	# Calculate map size based on viewport to fill screen
	var viewport_size: Vector2 = get_viewport_rect().size
	map_size = Vector2i(
		int(viewport_size.x / 32) + 4,  # Add extra tiles for margin
		int(viewport_size.y / 32) + 4
	)

	print("Viewport size: ", viewport_size)
	print("Map size in tiles: ", map_size)

	# Generate test map
	_generate_test_map()

	# Update camera limits after map is generated
	var camera: Camera2D = $Camera
	if camera and camera.has_method("refresh_limits"):
		# Give the camera a frame to initialize
		await get_tree().process_frame
		camera.refresh_limits()
		# Start camera in center of map, but don't change the follow mode
		var center_pos: Vector2 = Vector2(map_size) * 16.0  # Half of 32px cells
		camera.position = center_pos


## Generate a simple checkerboard test map
func _generate_test_map() -> void:
	# Instead of using tiles (which we don't have textures for yet),
	# draw a visual grid using ColorRect nodes for testing
	var grid_visual: Node2D = Node2D.new()
	grid_visual.name = "GridVisual"
	$Map.add_child(grid_visual)

	# Draw a checkerboard pattern
	for x in range(map_size.x):
		for y in range(map_size.y):
			var cell_rect: ColorRect = ColorRect.new()
			cell_rect.size = Vector2(32, 32)
			cell_rect.position = Vector2(x * 32, y * 32)

			# Checkerboard colors
			if (x + y) % 2 == 0:
				cell_rect.color = Color(0.3, 0.4, 0.3)  # Dark green
			else:
				cell_rect.color = Color(0.4, 0.5, 0.4)  # Light green

			grid_visual.add_child(cell_rect)

	# Also set cells in tilemap for boundary detection
	if _ground_layer and _ground_layer.tile_set:
		for x in range(map_size.x):
			for y in range(map_size.y):
				var atlas_coords: Vector2i = Vector2i((x + y) % 2, 0)
				_ground_layer.set_cell(Vector2i(x, y), 0, atlas_coords)


func _process(_delta: float) -> void:
	# Debug info
	var camera: Camera2D = $Camera
	if camera and Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

	# Display camera info
	var debug_label: Label = $UI/HUD/DebugLabel
	if debug_label and camera:
		var current_cell: Vector2i = Vector2i.ZERO
		var mode: int = 0
		if camera.has_method("get_current_cell"):
			current_cell = camera.get_current_cell()
		var mode_value: Variant = camera.get("follow_mode")
		if mode_value != null:
			mode = mode_value as int

		var mouse_pos: Vector2 = get_global_mouse_position()
		debug_label.text = "Camera Test Scene\n"
		debug_label.text += "Camera Cell: %s\n" % current_cell
		debug_label.text += "Mouse World: %s\n" % mouse_pos
		debug_label.text += "Camera Mode: %s\n" % _get_mode_name(mode)
		debug_label.text += "Press ESC to quit"


func _get_mode_name(mode: int) -> String:
	match mode:
		0: return "NONE"
		1: return "CURSOR"
		2: return "ACTIVE_UNIT"
		3: return "TARGET_POSITION"
		_: return "UNKNOWN"
