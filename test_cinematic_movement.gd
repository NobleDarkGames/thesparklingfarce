extends Node2D

## Headless test to debug cinematic movement pathfinding

func _ready() -> void:
	print("\n=== Cinematic Movement Pathfinding Debug ===\n")

	# Wait for autoloads
	await get_tree().process_frame
	await get_tree().process_frame

	# Test GridManager state
	print("GridManager.grid: ", GridManager.grid)
	print("GridManager.get_tile_size(): ", GridManager.get_tile_size())

	# Test coordinate conversion
	var test_cell: Vector2i = Vector2i(10, 10)
	var world_pos: Vector2 = GridManager.cell_to_world(test_cell)
	print("Cell (10, 10) converts to world: ", world_pos)

	var back_to_cell: Vector2i = GridManager.world_to_cell(world_pos)
	print("World ", world_pos, " converts back to cell: ", back_to_cell)

	# Test pathfinding
	print("\n--- Testing Pathfinding ---")
	var start: Vector2i = Vector2i(10, 10)
	var end: Vector2i = Vector2i(10, 7)

	print("Finding path from ", start, " to ", end)
	var path: Array[Vector2i] = GridManager.find_path(start, end, 0)

	print("Path result: ", path)
	print("Path length: ", path.size())

	if path.is_empty():
		print("WARNING: Pathfinding returned empty path!")
		print("This explains the diagonal movement - no pathfinding available")
	else:
		print("Path cells:")
		for i in range(path.size()):
			print("  [%d] %s" % [i, path[i]])

	# Test the waypoint expansion logic
	print("\n--- Testing Waypoint Expansion ---")
	var waypoints: Array = [[10, 10], [10, 7], [13, 7], [13, 10]]
	print("Input waypoints: ", waypoints)

	var complete_path: Array[Vector2i] = []
	var current_pos: Vector2i = Vector2i(10, 10)
	complete_path.append(current_pos)

	for waypoint_data: Variant in waypoints:
		var waypoint: Vector2i = Vector2i(waypoint_data[0], waypoint_data[1])
		if waypoint == current_pos:
			continue

		print("\nFinding segment from ", current_pos, " to ", waypoint)
		var segment_path: Array[Vector2i] = GridManager.find_path(current_pos, waypoint, 0)
		print("  Segment path: ", segment_path)

		if segment_path.is_empty():
			print("  WARNING: Empty segment!")
			current_pos = waypoint
			complete_path.append(waypoint)
			continue

		for i in range(1, segment_path.size()):
			complete_path.append(segment_path[i])

		current_pos = waypoint

	print("\nComplete expanded path:")
	print("  Total cells: ", complete_path.size())
	for i in range(complete_path.size()):
		print("  [%d] %s" % [i, complete_path[i]])

	print("\n=== Test Complete ===")

	# Quit after 1 second
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()
