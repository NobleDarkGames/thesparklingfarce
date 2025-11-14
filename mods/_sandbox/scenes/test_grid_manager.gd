## Test scene for GridManager pathfinding and movement range
##
## Click cells to see pathfinding in action
## Press SPACE to toggle movement range display
extends Node2D

@export var test_movement_range: int = 5
@export var test_movement_type: int = 0  # WALKING

var _ground_layer: TileMapLayer = null
var _highlight_layer: TileMapLayer = null
var _start_cell: Vector2i = Vector2i(5, 5)
var _show_movement_range: bool = false

# Visual markers
var _start_marker: ColorRect = null
var _end_marker: ColorRect = null


func _ready() -> void:
	# Find layers
	_ground_layer = $Map/GroundLayer
	_highlight_layer = $Map/HighlightLayer

	if not _ground_layer:
		push_error("TestGridManager: Could not find GroundLayer")
		return

	if not _highlight_layer:
		push_error("TestGridManager: Could not find HighlightLayer")
		return

	# Generate test map
	_generate_test_map()

	# Initialize GridManager
	var grid_resource: Grid = Grid.new()
	grid_resource.grid_size = Vector2i(20, 11)
	grid_resource.cell_size = 32

	GridManager.setup_grid(grid_resource, _ground_layer)
	GridManager.set_highlight_layer(_highlight_layer)

	# Create visual markers
	_create_markers()

	# Set start marker position
	_update_marker_position(_start_marker, _start_cell)

	print("GridManager Test Scene Ready!")
	print("- Click to see pathfinding")
	print("- Press SPACE to toggle movement range")
	print("- Press ESC to quit")


func _generate_test_map() -> void:
	# Create a simple checkerboard pattern
	if not _ground_layer or not _ground_layer.tile_set:
		push_error("TestGridManager: Cannot generate map without tileset")
		return

	for x in range(20):
		for y in range(11):
			var atlas_coords: Vector2i = Vector2i((x + y) % 2, 0)
			_ground_layer.set_cell(Vector2i(x, y), 0, atlas_coords)

	# Add some "obstacles" (set as solid in GridManager later if needed)
	# For now, just visual variety
	_ground_layer.set_cell(Vector2i(10, 5), 0, Vector2i(2, 0))
	_ground_layer.set_cell(Vector2i(11, 5), 0, Vector2i(2, 0))
	_ground_layer.set_cell(Vector2i(10, 6), 0, Vector2i(2, 0))


func _create_markers() -> void:
	# Start marker (green)
	_start_marker = ColorRect.new()
	_start_marker.size = Vector2(28, 28)
	_start_marker.color = Color.GREEN
	_start_marker.position = Vector2(2, 2)  # Offset within cell
	$Map.add_child(_start_marker)

	# End marker (red)
	_end_marker = ColorRect.new()
	_end_marker.size = Vector2(28, 28)
	_end_marker.color = Color.RED
	_end_marker.position = Vector2(2, 2)
	_end_marker.visible = false
	$Map.add_child(_end_marker)


func _update_marker_position(marker: ColorRect, cell: Vector2i) -> void:
	var world_pos: Vector2 = GridManager.cell_to_world(cell)
	marker.position = world_pos - Vector2(14, 14)  # Center the marker


func _process(_delta: float) -> void:
	# Quit on ESC
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

	# Toggle movement range on SPACE
	if Input.is_action_just_pressed("ui_select"):
		_show_movement_range = not _show_movement_range
		_update_display()

	# Update debug label
	var mouse_world: Vector2 = get_global_mouse_position()
	var mouse_cell: Vector2i = GridManager.world_to_cell(mouse_world)

	var debug_label: Label = $UI/HUD/DebugLabel
	if debug_label:
		debug_label.text = "GridManager Test\n"
		debug_label.text += "Mouse Cell: %s\n" % mouse_cell
		debug_label.text += "Start Cell: %s\n" % _start_cell
		debug_label.text += "Movement Range: %d\n" % test_movement_range
		debug_label.text += "Show Range: %s\n" % _show_movement_range
		debug_label.text += "\nClick to pathfind"
		debug_label.text += "\nSPACE = toggle range"
		debug_label.text += "\nESC = quit"


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse_world: Vector2 = get_global_mouse_position()
			var target_cell: Vector2i = GridManager.world_to_cell(mouse_world)

			if GridManager.is_within_bounds(target_cell):
				_test_pathfinding(target_cell)


func _test_pathfinding(target_cell: Vector2i) -> void:
	print("\n=== Testing Pathfinding ===")
	print("From: %s" % _start_cell)
	print("To: %s" % target_cell)

	# Find path
	var path: Array[Vector2i] = GridManager.find_path(_start_cell, target_cell, test_movement_type)

	if path.is_empty():
		print("No path found!")
		GridManager.clear_highlights()
		_end_marker.visible = false
		return

	print("Path found with %d cells:" % path.size())
	for i in range(path.size()):
		print("  [%d] %s" % [i, path[i]])

	# Check if within movement range
	var walkable_cells: Array[Vector2i] = GridManager.get_walkable_cells(_start_cell, test_movement_range, test_movement_type)
	var is_reachable: bool = target_cell in walkable_cells

	print("Reachable: %s" % is_reachable)

	# Highlight path
	GridManager.clear_highlights()
	GridManager.highlight_cells(path, 1)  # Red for path

	# Show end marker
	_end_marker.visible = true
	_update_marker_position(_end_marker, target_cell)

	# If showing movement range, also display that
	if _show_movement_range:
		# Highlight walkable cells in blue (0), but path overrides in red (1)
		GridManager.highlight_cells(walkable_cells, 0)
		GridManager.highlight_cells(path, 1)


func _update_display() -> void:
	if _show_movement_range:
		# Show all walkable cells
		var walkable_cells: Array[Vector2i] = GridManager.get_walkable_cells(_start_cell, test_movement_range, test_movement_type)
		GridManager.clear_highlights()
		GridManager.highlight_cells(walkable_cells, 0)
		print("Movement range displayed: %d cells" % walkable_cells.size())
	else:
		# Clear highlights
		GridManager.clear_highlights()
		_end_marker.visible = false
		print("Movement range hidden")
