## BATTLE DATA LOADER SCENE
##
## Loads battles created in the Sparkling Editor and executes them.
## Based on test_unit.gd template with all working mechanisms preserved.
##
## Features:
## - Loads BattleData resources from editor
## - Spawns player, enemy, and neutral units from battle configuration
## - Complete turn-based battle flow (TurnManager + InputManager + BattleManager)
## - Visual grid with cursor and path preview
## - Action menu UI with Attack/Stay options
## - Combat resolution with damage calculation
##
## Controls:
## - Arrow Keys: Move cursor during your turn
## - Enter/Space: Confirm movement (opens action menu)
## - Backspace/X: Cancel/go back/free cursor inspect (B button)
## - Q: Quit test scene
## - Action Menu: Arrow keys to select, Enter to confirm
##
## Tests Shining Force-style turn-based battle system with editor-created data
extends Node2D

# Preload scenes
const UnitScript: GDScript = preload("res://core/components/unit.gd")
const ActionMenuScene: PackedScene = preload("res://scenes/ui/action_menu.tscn")
const GridCursorScene: PackedScene = preload("res://scenes/ui/grid_cursor.tscn")

## SET THIS to the battle you want to test!
@export var battle_data: BattleData

var _ground_layer: TileMapLayer = null
var _highlight_layer: TileMapLayer = null
var _highlight_visuals: Dictionary = {}  # {Vector2i: ColorRect}
var _player_units: Array[Node2D] = []  # All player units
var _enemy_units: Array[Node2D] = []  # All enemy units
var _neutral_units: Array[Node2D] = []  # All neutral units
var _action_menu: Control = null  # Action menu UI
var _grid_cursor: Node2D = null  # Grid cursor visual
var _stats_panel: ActiveUnitStatsPanel = null  # Stats display panel
var _terrain_panel: TerrainInfoPanel = null  # Terrain info panel
var _camera: CameraController = null  # Camera controller


func _ready() -> void:
	# Validate battle data
	if not battle_data:
		push_error("BattleLoader: No battle_data assigned! Set the 'battle_data' export variable in the Inspector.")
		return

	print("\n=== Battle Loader Starting ===")
	print("Battle: %s" % battle_data.battle_name)
	print("Description: %s" % battle_data.battle_description)

	# Find layers
	_ground_layer = $Map/GroundLayer
	_highlight_layer = $Map/HighlightLayer

	if not _ground_layer or not _highlight_layer:
		push_error("BattleLoader: Missing layers")
		return

	# Generate test map (Phase 3: load from battle_data.map_scene)
	_generate_test_map()

	# Initialize GridManager
	var grid_resource: Grid = Grid.new()
	grid_resource.grid_size = Vector2i(20, 11)
	grid_resource.cell_size = 32

	GridManager.setup_grid(grid_resource, _ground_layer)
	GridManager.set_highlight_layer(_highlight_layer)

	# Spawn player units
	# TODO Phase 3: BattleData should have player_units array with positions
	# For now, create a test player at a fixed position
	var test_player_character: CharacterData = _create_test_player()
	var player_unit: Node2D = _spawn_unit(test_player_character, Vector2i(3, 5), "player", null)
	_player_units.append(player_unit)

	# Spawn enemy units from BattleData
	print("\n=== Spawning Enemies ===")
	for enemy_dict in battle_data.enemies:
		if not 'character' in enemy_dict or not enemy_dict.character:
			push_error("BattleLoader: Enemy missing character data")
			continue

		var character: CharacterData = enemy_dict.character
		var position: Vector2i = enemy_dict.position if 'position' in enemy_dict else Vector2i(10, 5)
		var ai_brain: AIBrain = enemy_dict.ai_brain if 'ai_brain' in enemy_dict else null

		var enemy_unit: Node2D = _spawn_unit(character, position, "enemy", ai_brain)
		_enemy_units.append(enemy_unit)
		print("  - %s at %s (AI: %s)" % [character.character_name, position, ai_brain.get_script().get_path().get_file() if ai_brain else "none"])

	# Spawn neutral units from BattleData
	if not battle_data.neutrals.is_empty():
		print("\n=== Spawning Neutrals ===")
		for neutral_dict in battle_data.neutrals:
			if not 'character' in neutral_dict or not neutral_dict.character:
				push_error("BattleLoader: Neutral missing character data")
				continue

			var character: CharacterData = neutral_dict.character
			var position: Vector2i = neutral_dict.position if 'position' in neutral_dict else Vector2i(8, 5)
			var ai_brain: AIBrain = neutral_dict.ai_brain if 'ai_brain' in neutral_dict else null

			var neutral_unit: Node2D = _spawn_unit(character, position, "neutral", ai_brain)
			_neutral_units.append(neutral_unit)
			print("  - %s at %s (AI: %s)" % [character.character_name, position, ai_brain.get_script().get_path().get_file() if ai_brain else "none"])

	print("\n=== Units Summary ===")
	print("Player units: %d" % _player_units.size())
	print("Enemy units: %d" % _enemy_units.size())
	print("Neutral units: %d" % _neutral_units.size())

	# Setup action menu UI BEFORE starting battle
	_action_menu = ActionMenuScene.instantiate()
	$UI.add_child(_action_menu)
	InputManager.set_action_menu(_action_menu)

	# Setup grid cursor
	_grid_cursor = GridCursorScene.instantiate()
	$Map.add_child(_grid_cursor)
	_grid_cursor.hide_cursor()  # Hidden until player turn
	InputManager.grid_cursor = _grid_cursor

	# Set path preview parent (use Map node for path visuals)
	InputManager.path_preview_parent = $Map

	# Get reference to stats panels
	_stats_panel = $UI/HUD/ActiveUnitStatsPanel
	_terrain_panel = $UI/HUD/TerrainInfoPanel

	# Get reference to camera
	_camera = $Camera

	# Set camera reference in InputManager for inspection mode
	InputManager.camera = _camera

	# Set stats panel reference in InputManager (used for both active unit and inspection)
	InputManager.stats_panel = _stats_panel

	# Setup BattleManager with scene references
	BattleManager.setup(self, $Units)

	# Populate BattleManager unit arrays (needed for AI to find targets)
	BattleManager.player_units = _player_units
	BattleManager.enemy_units = _enemy_units
	BattleManager.neutral_units = _neutral_units
	BattleManager.all_units = _player_units + _enemy_units + _neutral_units

	# Connect to BattleManager signals for visual feedback
	BattleManager.combat_resolved.connect(_on_combat_resolved)

	# Connect to TurnManager signals BEFORE starting battle
	TurnManager.player_turn_started.connect(_on_player_turn_started)
	TurnManager.enemy_turn_started.connect(_on_enemy_turn_started)
	TurnManager.unit_turn_ended.connect(_on_unit_turn_ended)
	TurnManager.battle_ended.connect(_on_battle_ended)

	# Start turn-based battle (this will emit signals immediately)
	var all_units: Array[Node2D] = _player_units + _enemy_units + _neutral_units
	TurnManager.start_battle(all_units)

	# Connect InputManager signals to BattleManager (for combat execution)
	if not InputManager.action_selected.is_connected(BattleManager._on_action_selected):
		InputManager.action_selected.connect(BattleManager._on_action_selected)
	if not InputManager.target_selected.is_connected(BattleManager._on_target_selected):
		InputManager.target_selected.connect(BattleManager._on_target_selected)

	print("\n=== Controls ===")
	print("Arrow keys = Move cursor")
	print("Enter/Space/Z = Confirm position / Open action menu")
	print("Backspace/X = Free cursor inspect mode (B button)")
	print("Arrow keys = Navigate action menu")
	print("Enter/Space/Z = Confirm action")
	print("Backspace/X in menu = Cancel and return to movement")
	print("Q = Quit")


func _generate_test_map() -> void:
	# Create visual grid using ColorRect nodes (since we don't have tileset graphics)
	# Phase 3: Load actual map from battle_data.map_scene
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


func _create_test_player() -> CharacterData:
	# Temporary: Create a basic player character
	# Phase 3: BattleData will have player_units array
	var character: CharacterData = CharacterData.new()
	character.character_name = "Hero"
	character.base_hp = 15
	character.base_mp = 10
	character.base_strength = 8
	character.base_defense = 7
	character.base_agility = 6
	character.base_intelligence = 5
	character.base_luck = 4
	character.starting_level = 1

	# Create a basic class
	var basic_class: ClassData = ClassData.new()
	basic_class.display_name = "Warrior"
	basic_class.movement_type = ClassData.MovementType.WALKING
	basic_class.movement_range = 4

	character.character_class = basic_class

	return character


func _spawn_unit(character: CharacterData, cell: Vector2i, p_faction: String, p_ai_brain: Resource) -> Node2D:
	# Load unit scene
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")
	var unit: Node2D = unit_scene.instantiate()

	# Initialize with character data and AI brain
	unit.initialize(character, p_faction, p_ai_brain)

	# Set grid position
	unit.grid_position = cell
	unit.position = GridManager.cell_to_world(cell)

	# Register with GridManager
	GridManager.set_cell_occupied(cell, unit)

	# Add to scene
	$Units.add_child(unit)

	return unit


func _process(_delta: float) -> void:
	# Quit on Q key (changed from ESC/Backspace to avoid conflict with B button functionality)
	if Input.is_key_pressed(KEY_Q):
		get_tree().quit()

	# Keep camera centered on active unit (except in inspection mode)
	# In inspection mode, InputManager controls the camera to follow cursor
	var camera: Camera2D = $Camera
	var active_unit: Node2D = TurnManager.get_active_unit()
	if InputManager.current_state != InputManager.InputState.INSPECTING:
		if camera and active_unit and active_unit.is_alive():
			camera.position = active_unit.position

	# Update debug label
	var mouse_world: Vector2 = get_global_mouse_position()
	var mouse_cell: Vector2i = GridManager.world_to_cell(mouse_world)

	var debug_label: Label = $UI/HUD/DebugLabel
	if debug_label:
		debug_label.text = "Battle: %s\n" % battle_data.battle_name
		debug_label.text += "Mouse: %s\n" % mouse_cell

		# Show all units
		for unit in _player_units:
			if unit.is_alive():
				debug_label.text += "Player: %s\n" % unit.get_stats_summary()
			else:
				debug_label.text += "Player: DEAD\n"

		for unit in _enemy_units:
			if unit.is_alive():
				debug_label.text += "Enemy: %s\n" % unit.get_stats_summary()
			else:
				debug_label.text += "Enemy: DEAD\n"

		# Show current turn state
		if active_unit:
			debug_label.text += "\nActive: %s" % active_unit.get_display_name()
		else:
			debug_label.text += "\nActive: None"


## TurnManager signal handlers
func _on_player_turn_started(unit: Node2D) -> void:
	print("\n>>> PLAYER'S TURN: %s <<<" % unit.get_display_name())
	unit.show_selection()

	# Move camera to active unit
	_camera.follow_unit(unit)

	# Show stats and terrain panels
	_stats_panel.show_unit_stats(unit)
	var unit_cell: Vector2i = unit.grid_position
	_terrain_panel.show_terrain_info(unit_cell)

	# GridManager now handles highlights via TileMapLayer (called by InputManager)
	# Start InputManager for player turn
	InputManager.start_player_turn(unit)


func _on_enemy_turn_started(unit: Node2D) -> void:
	print("\n>>> ENEMY'S TURN: %s <<<" % unit.get_display_name())
	unit.show_selection()

	# Move camera to active unit
	_camera.follow_unit(unit)

	# Show stats and terrain panels for enemy turn (optional)
	_stats_panel.show_unit_stats(unit)
	var unit_cell: Vector2i = unit.grid_position
	_terrain_panel.show_terrain_info(unit_cell)


func _on_unit_turn_ended(unit: Node2D) -> void:
	print(">>> Turn ended for: %s <<<" % unit.get_display_name())
	unit.hide_selection()

	# Hide stats and terrain panels
	_stats_panel.hide_stats()
	_terrain_panel.hide_terrain_info()

	# GridManager now handles clearing highlights


func _on_battle_ended(victory: bool) -> void:
	print("\n========== BATTLE OVER ==========")
	if victory:
		print("YOU WIN!")
		# Phase 3: Show victory_dialogue from battle_data
	else:
		print("YOU LOSE!")
		# Phase 3: Show defeat_dialogue from battle_data
	print("Press Q to quit")


func _on_combat_resolved(attacker: Node2D, defender: Node2D, damage: int, hit: bool, crit: bool) -> void:
	print("Battle: Combat resolved - %s -> %s: %d damage (hit: %s, crit: %s)" % [
		attacker.get_display_name(),
		defender.get_display_name(),
		damage,
		hit,
		crit
	])
	# TODO: Show damage numbers (Phase 3)
