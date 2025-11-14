## Test scene for Unit + GridManager integration
##
## Creates test units and allows clicking to move them
extends Node2D

# Preload Unit class
const UnitScript: GDScript = preload("res://core/components/unit.gd")

var _ground_layer: TileMapLayer = null
var _highlight_layer: TileMapLayer = null
var _highlight_visuals: Dictionary = {}  # {Vector2i: ColorRect}
var _test_unit: Node2D = null  # Unit type
var _enemy_unit: Node2D = null  # Unit type


func _ready() -> void:
	# Find layers
	_ground_layer = $Map/GroundLayer
	_highlight_layer = $Map/HighlightLayer

	if not _ground_layer or not _highlight_layer:
		push_error("TestUnit: Missing layers")
		return

	# Generate test map
	_generate_test_map()

	# Initialize GridManager
	var grid_resource: Grid = Grid.new()
	grid_resource.grid_size = Vector2i(20, 11)
	grid_resource.cell_size = 32

	GridManager.setup_grid(grid_resource, _ground_layer)
	GridManager.set_highlight_layer(_highlight_layer)

	# Create test character data
	var player_character: CharacterData = _create_test_character("Hero", 15, 10, 8, 7, 6, 5, 4)
	var enemy_character: CharacterData = _create_test_character("Goblin", 12, 5, 6, 4, 5, 3, 3)

	# Spawn player unit
	_test_unit = _spawn_unit(player_character, Vector2i(3, 5), "player", "aggressive")
	_test_unit.show_selection()  # Show player unit as selected by default

	# Spawn enemy unit
	_enemy_unit = _spawn_unit(enemy_character, Vector2i(10, 5), "enemy", "aggressive")

	print("\n=== Unit Test Scene Ready ===")
	print("Player unit: %s" % _test_unit.get_stats_summary())
	print("Enemy unit: %s" % _enemy_unit.get_stats_summary())
	print("\nClick to move Hero")
	print("Press SPACE to attack enemy")
	print("Press ESC to quit")


func _generate_test_map() -> void:
	# Create visual grid using ColorRect nodes (since we don't have tileset graphics)
	var grid_visual: Node2D = Node2D.new()
	grid_visual.name = "GridVisual"
	$Map.add_child(grid_visual)

	# Draw checkerboard pattern
	for x in range(20):
		for y in range(11):
			var cell_rect: ColorRect = ColorRect.new()
			cell_rect.size = Vector2(32, 32)
			cell_rect.position = Vector2(x * 32, y * 32)

			# Checkerboard colors
			if (x + y) % 2 == 0:
				cell_rect.color = Color(0.3, 0.4, 0.3)  # Dark green
			else:
				cell_rect.color = Color(0.4, 0.5, 0.4)  # Light green

			grid_visual.add_child(cell_rect)

	# Also set cells in tilemap for GridManager to detect
	if _ground_layer and _ground_layer.tile_set:
		for x in range(20):
			for y in range(11):
				_ground_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))


func _create_test_character(p_name: String, hp: int, mp: int, str_val: int, def_val: int, agi: int, int_val: int, luk: int) -> CharacterData:
	var character: CharacterData = CharacterData.new()
	character.character_name = p_name
	character.base_hp = hp
	character.base_mp = mp
	character.base_strength = str_val
	character.base_defense = def_val
	character.base_agility = agi
	character.base_intelligence = int_val
	character.base_luck = luk
	character.starting_level = 1

	# Create a basic class
	var basic_class: ClassData = ClassData.new()
	basic_class.display_name = "Warrior"
	basic_class.movement_type = ClassData.MovementType.WALKING
	basic_class.movement_range = 4

	character.character_class = basic_class

	return character


func _spawn_unit(character: CharacterData, cell: Vector2i, p_faction: String, p_ai: String) -> Node2D:
	# Load unit scene
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")
	var unit: Node2D = unit_scene.instantiate()

	# Initialize with character data
	unit.initialize(character, p_faction, p_ai)

	# Set grid position
	unit.grid_position = cell
	unit.position = GridManager.cell_to_world(cell)

	# Register with GridManager
	GridManager.set_cell_occupied(cell, unit)

	# Add to scene
	$Units.add_child(unit)

	return unit


func _process(_delta: float) -> void:
	# Quit on ESC
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

	# Attack test on SPACE
	if Input.is_action_just_pressed("ui_select"):
		if _test_unit and _enemy_unit and _test_unit.is_alive() and _enemy_unit.is_alive():
			_test_attack()

	# Keep camera centered on active unit (Hero for now)
	var camera: Camera2D = $Camera
	if camera and _test_unit and _test_unit.is_alive():
		camera.position = _test_unit.position

	# Update debug label
	var mouse_world: Vector2 = get_global_mouse_position()
	var mouse_cell: Vector2i = GridManager.world_to_cell(mouse_world)

	var debug_label: Label = $UI/HUD/DebugLabel
	if debug_label:
		debug_label.text = "Unit Test Scene\n"
		debug_label.text += "Mouse Cell: %s\n" % mouse_cell
		if _test_unit and _test_unit.is_alive():
			debug_label.text += "Hero: %s\n" % _test_unit.get_stats_summary()
		else:
			debug_label.text += "Hero: DEAD\n"
		if _enemy_unit and _enemy_unit.is_alive():
			debug_label.text += "Goblin: %s\n" % _enemy_unit.get_stats_summary()
		else:
			debug_label.text += "Goblin: DEAD\n"
		debug_label.text += "\nClick = Move Hero"
		debug_label.text += "\nSPACE = Attack"
		debug_label.text += "\nESC = Quit"


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _test_unit and _test_unit.is_alive():
				var mouse_world: Vector2 = get_global_mouse_position()
				var target_cell: Vector2i = GridManager.world_to_cell(mouse_world)
				_try_move_unit(target_cell)


func _show_highlights(cells: Array[Vector2i], color: Color) -> void:
	# Clear old highlights
	_clear_highlights()

	# Create new highlight overlays
	for cell in cells:
		if not GridManager.is_within_bounds(cell):
			continue

		var highlight: ColorRect = ColorRect.new()
		highlight.size = Vector2(32, 32)
		highlight.position = GridManager.cell_to_world(cell) - Vector2(16, 16)
		highlight.color = color
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Map.add_child(highlight)

		_highlight_visuals[cell] = highlight


func _clear_highlights() -> void:
	for cell: Vector2i in _highlight_visuals.keys():
		var highlight: ColorRect = _highlight_visuals[cell]
		highlight.queue_free()
	_highlight_visuals.clear()


func _try_move_unit(target_cell: Vector2i) -> void:
	if not GridManager.is_within_bounds(target_cell):
		print("Target out of bounds")
		return

	print("\n=== Moving Unit ===")

	# Get movement range
	var movement_range: int = _test_unit.character_data.character_class.movement_range
	var walkable_cells: Array[Vector2i] = GridManager.get_walkable_cells(
		_test_unit.grid_position,
		movement_range,
		_test_unit.character_data.character_class.movement_type
	)

	# Check if target is walkable
	if target_cell not in walkable_cells:
		print("Target not reachable (movement range: %d)" % movement_range)
		# Show walkable cells for feedback (blue, semi-transparent)
		_show_highlights(walkable_cells, Color(0.3, 0.5, 1.0, 0.4))
		return

	# Find path
	var path: Array[Vector2i] = GridManager.find_path(
		_test_unit.grid_position,
		target_cell,
		_test_unit.character_data.character_class.movement_type
	)

	if path.is_empty():
		print("No path found")
		return

	print("Path: %s" % path)

	# Move unit (in real game, this would be animated)
	_test_unit.move_to(target_cell)

	# Show path briefly (yellow, semi-transparent)
	_show_highlights(path, Color(1.0, 1.0, 0.3, 0.5))


func _test_attack() -> void:
	print("\n=== Testing Combat ===")

	# Check distance
	var distance: int = GridManager.get_distance(_test_unit.grid_position, _enemy_unit.grid_position)
	print("Distance: %d" % distance)

	if distance > 1:
		print("Enemy too far to attack (melee range only)")
		return

	# Calculate damage (simple formula for now)
	var damage: int = maxi(1, _test_unit.stats.strength - _enemy_unit.stats.defense)
	print("%s attacks %s for %d damage!" % [_test_unit.get_display_name(), _enemy_unit.get_display_name(), damage])

	# Apply damage
	_enemy_unit.take_damage(damage)

	# If enemy died, clear highlights
	if _enemy_unit.is_dead():
		print("Enemy defeated!")
		_clear_highlights()
