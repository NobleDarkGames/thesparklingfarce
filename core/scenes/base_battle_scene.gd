## BaseBattleScene - Common functionality for all battle scenes
##
## Provides standard setup for tactical battles including:
## - GridManager initialization
## - UI setup (action menu, cursor, stats panels)
## - TurnManager and InputManager integration
## - Camera management
## - Common signal handlers
##
## Subclasses should:
## 1. Override _spawn_units() to create their specific units
## 2. Override _get_grid_size() if using non-standard grid
## 3. Optionally override _update_debug_label() for custom debug info
##
## Expected scene structure:
##   BattleScene (extends BaseBattleScene)
##     Map/
##       GroundLayer (TileMapLayer)
##       HighlightLayer (TileMapLayer)
##     Units/ (Node2D container)
##     UI/
##       HUD/
##         ActiveUnitStatsPanel
##         TerrainInfoPanel
##         DebugLabel (optional)
##     Camera (CameraController)
class_name BaseBattleScene
extends Node2D

## Preloaded scenes
const ActionMenuScene: PackedScene = preload("res://scenes/ui/action_menu.tscn")
const GridCursorScene: PackedScene = preload("res://scenes/ui/grid_cursor.tscn")

## Map layers
var _ground_layer: TileMapLayer = null
var _highlight_layer: TileMapLayer = null

## Unit tracking
var _player_units: Array[Node2D] = []
var _enemy_units: Array[Node2D] = []
var _neutral_units: Array[Node2D] = []

## UI elements
var _action_menu: Control = null
var _grid_cursor: Node2D = null
var _stats_panel: ActiveUnitStatsPanel = null
var _terrain_panel: TerrainInfoPanel = null

## Camera
var _camera: CameraController = null


func _ready() -> void:
	# Find required nodes
	if not _find_required_nodes():
		return

	# Generate visual map (subclasses can override)
	_generate_map()

	# Initialize grid system
	_setup_grid()

	# Setup UI
	_setup_ui()

	# Spawn units (subclass responsibility)
	_spawn_units()

	# Setup battle systems
	_setup_battle_systems()

	# Connect signals
	_connect_signals()

	# Print controls
	_print_controls()


## Find all required scene nodes
func _find_required_nodes() -> bool:
	_ground_layer = get_node_or_null("Map/GroundLayer")
	_highlight_layer = get_node_or_null("Map/HighlightLayer")

	if not _ground_layer or not _highlight_layer:
		push_error("BaseBattleScene: Missing Map/GroundLayer or Map/HighlightLayer")
		return false

	_stats_panel = get_node_or_null("UI/HUD/ActiveUnitStatsPanel")
	_terrain_panel = get_node_or_null("UI/HUD/TerrainInfoPanel")
	_camera = get_node_or_null("Camera")

	if not _camera:
		push_warning("BaseBattleScene: No Camera node found")

	return true


## Generate visual map - override in subclass if needed
func _generate_map() -> void:
	var grid_size: Vector2i = _get_grid_size()

	# Create visual grid using ColorRect nodes
	var grid_visual: Node2D = Node2D.new()
	grid_visual.name = "GridVisual"
	$Map.add_child(grid_visual)

	# Draw checkerboard pattern
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var cell_rect: ColorRect = ColorRect.new()
			cell_rect.size = Vector2(32, 32)
			cell_rect.position = Vector2(x * 32, y * 32)

			if (x + y) % 2 == 0:
				cell_rect.color = Color(0.3, 0.4, 0.3)
			else:
				cell_rect.color = Color(0.4, 0.5, 0.4)

			grid_visual.add_child(cell_rect)

	# Set cells in tilemap for GridManager
	if _ground_layer and _ground_layer.tile_set:
		for x in range(grid_size.x):
			for y in range(grid_size.y):
				_ground_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))


## Get grid size - override in subclass if needed
func _get_grid_size() -> Vector2i:
	return Vector2i(20, 11)


## Setup GridManager
func _setup_grid() -> void:
	var grid_size: Vector2i = _get_grid_size()
	var grid_resource: Grid = Grid.new()
	grid_resource.grid_size = grid_size
	grid_resource.cell_size = 32

	GridManager.setup_grid(grid_resource, _ground_layer)
	GridManager.set_highlight_layer(_highlight_layer)


## Setup UI elements
func _setup_ui() -> void:
	# Action menu
	_action_menu = ActionMenuScene.instantiate()
	$UI.add_child(_action_menu)
	InputManager.set_action_menu(_action_menu)

	# Grid cursor
	_grid_cursor = GridCursorScene.instantiate()
	$Map.add_child(_grid_cursor)
	_grid_cursor.hide_cursor()
	InputManager.grid_cursor = _grid_cursor

	# Path preview parent
	InputManager.path_preview_parent = $Map

	# Set InputManager references
	if _camera:
		InputManager.camera = _camera
	if _stats_panel:
		InputManager.stats_panel = _stats_panel


## Spawn units - MUST be overridden by subclass
func _spawn_units() -> void:
	push_error("BaseBattleScene: _spawn_units() must be overridden by subclass")


## Setup BattleManager and connect systems
func _setup_battle_systems() -> void:
	# Setup BattleManager
	BattleManager.setup(self, $Units)
	BattleManager.player_units = _player_units
	BattleManager.enemy_units = _enemy_units
	BattleManager.neutral_units = _neutral_units
	BattleManager.all_units = _player_units + _enemy_units + _neutral_units

	# Register camera with systems
	if _camera:
		_camera.register_with_systems()


## Connect all battle signals
func _connect_signals() -> void:
	# BattleManager signals
	BattleManager.combat_resolved.connect(_on_combat_resolved)

	# TurnManager signals
	TurnManager.player_turn_started.connect(_on_player_turn_started)
	TurnManager.enemy_turn_started.connect(_on_enemy_turn_started)
	TurnManager.unit_turn_ended.connect(_on_unit_turn_ended)
	TurnManager.battle_ended.connect(_on_battle_ended)

	# InputManager to BattleManager
	if not InputManager.action_selected.is_connected(BattleManager._on_action_selected):
		InputManager.action_selected.connect(BattleManager._on_action_selected)
	if not InputManager.target_selected.is_connected(BattleManager._on_target_selected):
		InputManager.target_selected.connect(BattleManager._on_target_selected)


## Print control instructions
func _print_controls() -> void:
	print("\n=== Controls ===")
	print("Arrow keys = Move cursor")
	print("Enter/Space/Z = Confirm position / Open action menu")
	print("Backspace/X = Free cursor inspect mode (B button)")
	print("Arrow keys = Navigate action menu")
	print("Enter/Space/Z = Confirm action")
	print("Backspace/X in menu = Cancel and return to movement")
	print("Q = Quit")


## Start the battle with all spawned units
func _start_battle() -> void:
	var all_units: Array[Node2D] = _player_units + _enemy_units + _neutral_units
	TurnManager.start_battle(all_units)


## Spawn a unit at a grid position
func _spawn_unit(character: CharacterData, cell: Vector2i, faction: String, ai_brain: Resource) -> Node2D:
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")
	var unit: Node2D = unit_scene.instantiate()

	unit.initialize(character, faction, ai_brain)
	unit.grid_position = cell
	unit.position = GridManager.cell_to_world(cell)

	GridManager.set_cell_occupied(cell, unit)
	$Units.add_child(unit)

	return unit


func _process(_delta: float) -> void:
	# Quit on Q key
	if Input.is_key_pressed(KEY_Q):
		get_tree().quit()

	# Camera follows active unit during movement
	var active_unit: Node2D = TurnManager.get_active_unit()
	if InputManager.current_state != InputManager.InputState.INSPECTING:
		if active_unit and active_unit.is_alive():
			if active_unit.has_method("is_moving") and active_unit.is_moving():
				_camera.set_target_position(active_unit.position)

	# Update debug label (subclass can override)
	_update_debug_label()


## Update debug label - override in subclass for custom info
func _update_debug_label() -> void:
	var debug_label: Label = get_node_or_null("UI/HUD/DebugLabel")
	if not debug_label:
		return

	var mouse_world: Vector2 = get_global_mouse_position()
	var mouse_cell: Vector2i = GridManager.world_to_cell(mouse_world)
	var active_unit: Node2D = TurnManager.get_active_unit()

	debug_label.text = "Battle Scene\n"
	debug_label.text += "Mouse: %s\n" % mouse_cell

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

	if active_unit:
		debug_label.text += "\nActive: %s" % active_unit.get_display_name()
	else:
		debug_label.text += "\nActive: None"


## TurnManager signal handlers

func _on_player_turn_started(unit: Node2D) -> void:
	print("\n>>> PLAYER'S TURN: %s <<<" % unit.get_display_name())
	unit.show_selection()

	if _camera:
		_camera.follow_unit(unit)

	if _stats_panel:
		_stats_panel.show_unit_stats(unit)
	if _terrain_panel:
		_terrain_panel.show_terrain_info(unit.grid_position)

	InputManager.start_player_turn(unit)


func _on_enemy_turn_started(unit: Node2D) -> void:
	print("\n>>> ENEMY'S TURN: %s <<<" % unit.get_display_name())
	unit.show_selection()

	if _camera:
		_camera.follow_unit(unit)

	if _stats_panel:
		_stats_panel.show_unit_stats(unit)
	if _terrain_panel:
		_terrain_panel.show_terrain_info(unit.grid_position)


func _on_unit_turn_ended(unit: Node2D) -> void:
	print(">>> Turn ended for: %s <<<" % unit.get_display_name())
	unit.hide_selection()

	if _stats_panel:
		_stats_panel.hide_stats()
	if _terrain_panel:
		_terrain_panel.hide_terrain_info()


func _on_battle_ended(victory: bool) -> void:
	print("\n========== BATTLE OVER ==========")
	if victory:
		print("YOU WIN!")
	else:
		print("YOU LOSE!")
	print("Press Q to quit")


func _on_combat_resolved(attacker: Node2D, defender: Node2D, damage: int, hit: bool, crit: bool) -> void:
	print("Combat: %s -> %s: %d damage (hit: %s, crit: %s)" % [
		attacker.get_display_name(),
		defender.get_display_name(),
		damage,
		hit,
		crit
	])


## Cleanup when scene is freed - disconnect from singletons to prevent stale references
func _exit_tree() -> void:
	# Disconnect from BattleManager signals
	if BattleManager.combat_resolved.is_connected(_on_combat_resolved):
		BattleManager.combat_resolved.disconnect(_on_combat_resolved)

	# Disconnect from TurnManager signals
	if TurnManager.player_turn_started.is_connected(_on_player_turn_started):
		TurnManager.player_turn_started.disconnect(_on_player_turn_started)
	if TurnManager.enemy_turn_started.is_connected(_on_enemy_turn_started):
		TurnManager.enemy_turn_started.disconnect(_on_enemy_turn_started)
	if TurnManager.unit_turn_ended.is_connected(_on_unit_turn_ended):
		TurnManager.unit_turn_ended.disconnect(_on_unit_turn_ended)
	if TurnManager.battle_ended.is_connected(_on_battle_ended):
		TurnManager.battle_ended.disconnect(_on_battle_ended)

	# Disconnect InputManager signals
	if InputManager.action_selected.is_connected(BattleManager._on_action_selected):
		InputManager.action_selected.disconnect(BattleManager._on_action_selected)
	if InputManager.target_selected.is_connected(BattleManager._on_target_selected):
		InputManager.target_selected.disconnect(BattleManager._on_target_selected)
