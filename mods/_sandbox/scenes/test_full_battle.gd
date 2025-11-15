## Test Full Battle Flow
##
## This scene tests the complete integration:
## 1. Create BattleData programmatically
## 2. Load map scene
## 3. BattleManager extracts Grid from map
## 4. Spawn units
## 5. Test turn-based combat
##
## This validates the proper separation of concerns.
extends Node2D

## References
var battle_manager: Node = null
var camera: Camera2D = null

## Battle setup
var test_battle_data: BattleData = null


func _ready() -> void:
	print("\n" + "=".repeat(50))
	print("TEST: Full Battle Flow with BattleManager")
	print("=".repeat(50) + "\n")

	# Get autoload references
	battle_manager = get_node("/root/BattleManager")

	if not battle_manager:
		push_error("TEST: BattleManager autoload not found!")
		return

	# Setup camera
	_setup_camera()

	# Setup BattleManager references
	battle_manager.setup(self, $Units)

	# Create test battle data
	_create_test_battle_data()

	# Small delay to let everything initialize
	await get_tree().create_timer(0.5).timeout

	# Start the battle!
	print("\nTEST: Starting battle...")
	battle_manager.start_battle(test_battle_data)

	# Wait for battle to initialize (GridManager setup)
	await get_tree().process_frame

	# TESTING WORKAROUND: Spawn player units AFTER grid is initialized
	# (Phase 4 will have proper party system that provides units to BattleManager)
	var test_player_units: Array[Node2D] = _spawn_test_player_units()

	# Add player units to battle
	_add_player_units_to_battle(test_player_units)


func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.enabled = true
	add_child(camera)

	# Position camera at center of expected grid
	camera.position = Vector2(320, 176)  # Center of 20x11 grid at 32px cells


func _create_test_battle_data() -> void:
	print("TEST: Creating test BattleData...")

	test_battle_data = BattleData.new()
	test_battle_data.battle_name = "Test Battle - BattleManager Integration"
	test_battle_data.battle_description = "Testing full combat flow with proper separation of concerns"

	# Load the test map scene (which contains Grid info)
	# For now, we'll create a minimal map scene programmatically
	test_battle_data.map_scene = _create_test_map_scene()

	# Setup enemy units
	test_battle_data.enemies = _create_enemy_units()

	# NOTE: Player units will come from party system (Phase 4)
	# For testing, we'll spawn a player unit manually in BattleManager setup

	# Victory/defeat conditions
	test_battle_data.victory_condition = BattleData.VictoryCondition.DEFEAT_ALL_ENEMIES
	test_battle_data.defeat_condition = BattleData.DefeatCondition.ALL_UNITS_DEFEATED

	print("TEST: BattleData created successfully")


func _create_test_map_scene() -> PackedScene:
	# Create a simple map scene with Grid
	var map_scene: PackedScene = PackedScene.new()

	var map_root: Node2D = Node2D.new()
	map_root.name = "TestMap"
	map_root.set_script(load("res://mods/_sandbox/scenes/test_map.gd"))

	# Add TileMapLayer
	var tilemap: TileMapLayer = TileMapLayer.new()
	tilemap.name = "GroundLayer"
	map_root.add_child(tilemap)
	tilemap.owner = map_root

	# Add visual grid (ColorRects for testing)
	var grid_visual: Node2D = Node2D.new()
	grid_visual.name = "GridVisual"
	map_root.add_child(grid_visual)
	grid_visual.owner = map_root

	# Create checkerboard pattern
	for x: int in range(20):
		for y: int in range(11):
			var cell_rect: ColorRect = ColorRect.new()
			cell_rect.size = Vector2(32, 32)
			cell_rect.position = Vector2(x * 32, y * 32)

			if (x + y) % 2 == 0:
				cell_rect.color = Color(0.3, 0.4, 0.3)  # Dark green
			else:
				cell_rect.color = Color(0.4, 0.5, 0.4)  # Light green

			cell_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid_visual.add_child(cell_rect)
			cell_rect.owner = map_root

	# Pack the scene
	map_scene.pack(map_root)

	return map_scene


func _spawn_test_player_units() -> Array[Node2D]:
	var units: Array[Node2D] = []

	# Create player character data
	var hero_data: CharacterData = _get_or_create_test_character("Hero", 15, 10, 8, 7, 6, 5, 4)

	# Load unit scene
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")
	var hero_unit: Node2D = unit_scene.instantiate()

	# Initialize with character data and faction
	hero_unit.initialize(hero_data, "player", "")
	hero_unit.grid_position = Vector2i(3, 5)
	hero_unit.position = GridManager.cell_to_world(Vector2i(3, 5))

	# Add to scene immediately (so it's visible)
	$Units.add_child(hero_unit)

	units.append(hero_unit)
	print("TEST: Created player unit: %s" % hero_data.character_name)

	return units


func _add_player_units_to_battle(player_units: Array[Node2D]) -> void:
	# Add to BattleManager tracking
	battle_manager.player_units = player_units
	battle_manager.all_units = player_units + battle_manager.enemy_units + battle_manager.neutral_units

	# Add to TurnManager
	TurnManager.all_units = battle_manager.all_units.duplicate()

	# Recalculate turn order with all units
	TurnManager.calculate_turn_order()

	# Start first unit's turn
	if not TurnManager.turn_queue.is_empty():
		var first_unit: Node2D = TurnManager.turn_queue.pop_front()
		TurnManager.start_unit_turn(first_unit)

	print("TEST: Player units added to battle (%d units total)" % battle_manager.all_units.size())


func _create_enemy_units() -> Array[Dictionary]:
	var units: Array[Dictionary] = []

	# Create enemy characters
	var goblin_data: CharacterData = _get_or_create_test_character("Goblin", 12, 5, 6, 4, 5, 3, 3)
	var orc_data: CharacterData = _get_or_create_test_character("Orc", 18, 8, 8, 5, 4, 3, 2)

	units.append({
		"character": goblin_data,
		"position": Vector2i(16, 5),
		"ai_behavior": "aggressive"
	})

	units.append({
		"character": orc_data,
		"position": Vector2i(16, 6),
		"ai_behavior": "stationary"
	})

	print("TEST: Created %d enemy units" % units.size())
	return units


func _get_or_create_test_character(char_name: String, hp: int, mp: int, str_val: int, def_val: int, agi: int, int_val: int, luk: int) -> CharacterData:
	# Try to load from mods first
	var char_path: String = "res://mods/_base_game/data/characters/"
	var dir: DirAccess = DirAccess.open(char_path)

	if dir:
		# Look for any character file
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		if file_name != "" and file_name.ends_with(".tres"):
			var char: CharacterData = load(char_path + file_name)
			if char:
				print("TEST: Loaded existing character: %s" % char.character_name)
				return char

	# Create new test character
	var character: CharacterData = CharacterData.new()
	character.character_name = char_name

	# Create a basic class
	var basic_class: ClassData = ClassData.new()
	basic_class.display_name = "Warrior"
	basic_class.movement_range = 4
	basic_class.movement_type = 0  # WALKING

	character.character_class = basic_class
	character.base_stats = {
		"hp": hp,
		"mp": mp,
		"strength": str_val,
		"defense": def_val,
		"agility": agi,
		"intelligence": int_val,
		"luck": luk
	}
	character.starting_level = 1

	print("TEST: Created test character: %s" % char_name)
	return character


func _input(event: InputEvent) -> void:
	# ESC to quit
	if event.is_action_pressed("ui_cancel"):
		print("\nTEST: Exiting...")
		get_tree().quit()

	# R to restart battle
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		print("\nTEST: Restarting battle...")
		get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	# Display test instructions
	if not has_node("UI"):
		var ui: CanvasLayer = CanvasLayer.new()
		ui.name = "UI"
		add_child(ui)

		var label: Label = Label.new()
		label.position = Vector2(10, 10)
		label.text = """TEST: Full Battle Flow

Controls:
- Click to move unit
- Select action from menu
- Click to target enemy
- ESC: Quit
- R: Restart battle

Watch console for detailed logs!"""

		ui.add_child(label)
