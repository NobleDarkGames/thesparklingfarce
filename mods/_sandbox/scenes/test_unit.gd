## PRIMARY MANUAL TEST SCENE
##
## This is the most complete working battle scene for manual testing.
## Use this as the basis for future test scenes when appropriate.
##
## Features:
## - Full player-controlled unit with movement and combat
## - AI-controlled enemy with aggressive behavior
## - Complete turn-based battle flow (TurnManager + InputManager + BattleManager)
## - Visual grid with cursor and path preview
## - Action menu UI with Attack/Stay options
## - Combat resolution with damage calculation
##
## Controls:
## - Arrow Keys: Move cursor during your turn
## - Enter/Space: Confirm movement (opens action menu)
## - Escape: Cancel/go back
## - Action Menu: Arrow keys to select, Enter to confirm
##
## Tests Shining Force-style turn-based battle system
extends Node2D

# Preload scenes
const UnitScript: GDScript = preload("res://core/components/unit.gd")
const ActionMenuScene: PackedScene = preload("res://scenes/ui/action_menu.tscn")
const GridCursorScene: PackedScene = preload("res://scenes/ui/grid_cursor.tscn")

var _ground_layer: TileMapLayer = null
var _highlight_layer: TileMapLayer = null
var _highlight_visuals: Dictionary = {}  # {Vector2i: ColorRect}
var _test_unit: Node2D = null  # Unit type
var _enemy_unit: Node2D = null  # Unit type
var _action_menu: Control = null  # Action menu UI
var _grid_cursor: Node2D = null  # Grid cursor visual
var _stats_panel: ActiveUnitStatsPanel = null  # Stats display panel
var _terrain_panel: TerrainInfoPanel = null  # Terrain info panel


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

	# Create AI brains (load at runtime)
	var AIAggressiveClass: GDScript = load("res://mods/base_game/ai_brains/ai_aggressive.gd")
	var aggressive_ai: Resource = AIAggressiveClass.new()

	# Spawn player unit (no AI brain for player)
	_test_unit = _spawn_unit(player_character, Vector2i(3, 5), "player", null)

	# Spawn enemy unit with aggressive AI
	_enemy_unit = _spawn_unit(enemy_character, Vector2i(10, 5), "enemy", aggressive_ai)

	print("\n=== Unit Test Scene Ready ===")
	print("Player unit: %s" % _test_unit.get_stats_summary())
	print("Enemy unit: %s" % _enemy_unit.get_stats_summary())

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

	# Setup BattleManager with scene references
	BattleManager.setup(self, $Units)

	# Populate BattleManager unit arrays (needed for AI to find targets)
	BattleManager.player_units = [_test_unit]
	BattleManager.enemy_units = [_enemy_unit]
	BattleManager.all_units = [_test_unit, _enemy_unit]

	# Connect to BattleManager signals for visual feedback
	BattleManager.combat_resolved.connect(_on_combat_resolved)

	# Connect to TurnManager signals BEFORE starting battle
	TurnManager.player_turn_started.connect(_on_player_turn_started)
	TurnManager.enemy_turn_started.connect(_on_enemy_turn_started)
	TurnManager.unit_turn_ended.connect(_on_unit_turn_ended)
	TurnManager.battle_ended.connect(_on_battle_ended)

	# Start turn-based battle (this will emit signals immediately)
	var all_units: Array[Node2D] = [_test_unit, _enemy_unit]
	TurnManager.start_battle(all_units)

	# Connect InputManager signals to BattleManager (for combat execution)
	if not InputManager.action_selected.is_connected(BattleManager._on_action_selected):
		InputManager.action_selected.connect(BattleManager._on_action_selected)
	if not InputManager.target_selected.is_connected(BattleManager._on_target_selected):
		InputManager.target_selected.connect(BattleManager._on_target_selected)

	print("\n=== Controls ===")
	print("Arrow keys = Move cursor")
	print("Click/Enter = Confirm movement")
	print("ESC/B = Cancel movement")
	print("Arrow keys = Navigate action menu")
	print("Enter = Confirm action")
	print("1-4 = Quick select action")
	print("ESC = Quit")


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
	# Quit on ESC (when not in a menu)
	if Input.is_action_just_pressed("ui_cancel") and not _action_menu.visible:
		get_tree().quit()

	# Keep camera centered on active unit
	var camera: Camera2D = $Camera
	var active_unit: Node2D = TurnManager.get_active_unit()
	if camera and active_unit and active_unit.is_alive():
		camera.position = active_unit.position

	# Update debug label
	var mouse_world: Vector2 = get_global_mouse_position()
	var mouse_cell: Vector2i = GridManager.world_to_cell(mouse_world)

	var debug_label: Label = $UI/HUD/DebugLabel
	if debug_label:
		debug_label.text = "Shining Force Battle Test\n"
		debug_label.text += "Mouse: %s\n" % mouse_cell
		if _test_unit and _test_unit.is_alive():
			debug_label.text += "Hero: %s\n" % _test_unit.get_stats_summary()
		else:
			debug_label.text += "Hero: DEAD\n"
		if _enemy_unit and _enemy_unit.is_alive():
			debug_label.text += "Goblin: %s\n" % _enemy_unit.get_stats_summary()
		else:
			debug_label.text += "Goblin: DEAD\n"

		# Show current turn state
		if active_unit:
			debug_label.text += "\nActive: %s" % active_unit.get_display_name()
		else:
			debug_label.text += "\nActive: None"


# Input is now handled by InputManager, no longer needed here


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


# Movement and combat now handled by InputManager


## TurnManager signal handlers
func _on_player_turn_started(unit: Node2D) -> void:
	print("\n>>> PLAYER'S TURN: %s <<<" % unit.get_display_name())
	unit.show_selection()

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
	else:
		print("YOU LOSE!")
	print("Press ESC to quit")


func _on_combat_resolved(attacker: Node2D, defender: Node2D, damage: int, hit: bool, crit: bool) -> void:
	print("Test scene: Combat resolved - %s -> %s: %d damage (hit: %s, crit: %s)" % [
		attacker.get_display_name(),
		defender.get_display_name(),
		damage,
		hit,
		crit
	])
	# TODO: Show damage numbers (Phase 3)
