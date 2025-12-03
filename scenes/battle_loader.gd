## BATTLE LOADER - ENGINE COMPONENT
##
## Loads battles created in the Sparkling Editor and executes them.
## Fully dynamic - uses PartyManager for player units and BattleData for enemies/neutrals.
##
## This is an ENGINE component that loads CONTENT (maps, battles) from mods.
## Maps come from: mods/*/maps/
## Battles come from: mods/*/data/battles/
##
## Features:
## - Loads BattleData resources from editor
## - Spawns player party from PartyManager
## - Spawns enemies and neutral units from BattleData
## - Complete turn-based battle flow (TurnManager + InputManager + BattleManager)
## - Full XP system integration (damage, kill, participation, level-ups)
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
extends Node2D

# Preload scenes
const ActionMenuScene: PackedScene = preload("res://scenes/ui/action_menu.tscn")
const ItemMenuScene: PackedScene = preload("res://scenes/ui/item_menu.tscn")
const GridCursorScene: PackedScene = preload("res://scenes/ui/grid_cursor.tscn")

## Battle data - set via TriggerManager or Inspector for testing
@export var battle_data: BattleData

var _ground_layer: TileMapLayer = null
var _highlight_layer: TileMapLayer = null
var _player_units: Array[Node2D] = []  # All player units
var _enemy_units: Array[Node2D] = []  # All enemy units
var _neutral_units: Array[Node2D] = []  # All neutral units
var _action_menu: Control = null  # Action menu UI
var _item_menu: Control = null  # Item menu UI
var _grid_cursor: Node2D = null  # Grid cursor visual
var _stats_panel: ActiveUnitStatsPanel = null  # Stats display panel
var _terrain_panel: TerrainInfoPanel = null  # Terrain info panel
var _combat_forecast_panel: CombatForecastPanel = null  # Combat forecast panel
var _turn_order_panel: TurnOrderPanel = null  # Turn order preview panel
var _camera: CameraController = null  # Camera controller
var _debug_visible: bool = false  # Debug display toggle (F3)
var _map_instance: Node2D = null  # Instanced map scene
var _map_node: Node2D = null  # The active Map node (from loaded map scene)


## Load and integrate the map scene from battle_data
func _load_map_scene() -> bool:
	# Validate map_scene exists
	if not battle_data.map_scene:
		push_error("BattleLoader: battle_data.map_scene is not set!")
		return false

	# Instance the map scene
	_map_instance = battle_data.map_scene.instantiate()
	if not _map_instance:
		push_error("BattleLoader: Failed to instantiate map_scene")
		return false


	# Find the Map node in the instanced scene
	var map_node: Node2D = _map_instance.get_node_or_null("Map")
	if not map_node:
		# Maybe the root IS the map node
		if _map_instance.get_node_or_null("GroundLayer"):
			map_node = _map_instance
		else:
			push_error("BattleLoader: map_scene has no 'Map' node or 'GroundLayer'")
			_map_instance.queue_free()
			return false

	# Find required layers
	_ground_layer = map_node.get_node_or_null("GroundLayer") as TileMapLayer
	_highlight_layer = map_node.get_node_or_null("HighlightLayer") as TileMapLayer

	if not _ground_layer:
		push_error("BattleLoader: Map missing 'GroundLayer' TileMapLayer")
		_map_instance.queue_free()
		return false

	if not _highlight_layer:
		push_error("BattleLoader: Map missing 'HighlightLayer' TileMapLayer")
		_map_instance.queue_free()
		return false

	# Remove our placeholder Map node and replace with the loaded one
	# Use free() instead of queue_free() to ensure immediate removal
	# This prevents $Map from finding the old dying node instead of the new one
	var old_map: Node = get_node_or_null("Map")
	if old_map:
		remove_child(old_map)
		old_map.free()

	# Reparent the Map node from the instanced scene to battle_loader
	map_node.get_parent().remove_child(map_node)
	add_child(map_node)
	move_child(map_node, 1)  # After Background

	# Store reference for later use (instead of relying on $Map)
	_map_node = map_node

	# Clean up the rest of the instanced scene (Camera, UI, etc. - we have our own)
	_map_instance.queue_free()
	_map_instance = null

	return true


func _ready() -> void:
	# Check if TriggerManager has battle data (from map trigger)
	var trigger_battle_data: Resource = TriggerManager.get_current_battle_data()
	if trigger_battle_data:
		battle_data = trigger_battle_data

	# Validate battle data
	if not battle_data:
		push_error("BattleLoader: No battle_data assigned! Set the 'battle_data' export variable in the Inspector.")
		return

	print("[FLOW] BattleLoader: %s" % battle_data.battle_name)

	# Load map from battle_data.map_scene
	if not _load_map_scene():
		push_error("BattleLoader: Failed to load map scene")
		return

	# Calculate grid size from tilemap used rect
	var grid_resource: Grid = Grid.new()
	grid_resource.cell_size = 32

	var used_rect: Rect2i = _ground_layer.get_used_rect()
	if used_rect.size.x > 0 and used_rect.size.y > 0:
		grid_resource.grid_size = used_rect.size
	else:
		# Fallback for empty maps - use a default size
		grid_resource.grid_size = Vector2i(20, 11)

	GridManager.setup_grid(grid_resource, _ground_layer)
	GridManager.set_highlight_layer(_highlight_layer)

	# Spawn player units from BattleData or PartyManager

	# If battle has specific party, load it temporarily
	if battle_data.player_party:
		PartyManager.load_from_party_data(battle_data.player_party)

	# Get spawn data from PartyManager (uses current party and battle's spawn point)
	var party_spawn_data: Array[Dictionary] = PartyManager.get_battle_spawn_data(battle_data.player_spawn_point)

	if party_spawn_data.is_empty():
		push_warning("BattleLoader: PartyManager has no party members!")
	else:
		for spawn_entry: Dictionary in party_spawn_data:
			var character: CharacterData = spawn_entry.character
			var spawn_position: Vector2i = spawn_entry.position

			var player_unit: Node2D = _spawn_unit(character, spawn_position, "player", null)
			_player_units.append(player_unit)

	# Spawn enemy units from BattleData
	for enemy_dict in battle_data.enemies:
		if not 'character' in enemy_dict or not enemy_dict.character:
			push_error("BattleLoader: Enemy missing character data")
			continue

		var character: CharacterData = enemy_dict.character
		var enemy_pos: Vector2i = enemy_dict.position if 'position' in enemy_dict else Vector2i(10, 5)
		var ai_brain: AIBrain = enemy_dict.ai_brain if 'ai_brain' in enemy_dict else null

		var enemy_unit: Node2D = _spawn_unit(character, enemy_pos, "enemy", ai_brain)
		_enemy_units.append(enemy_unit)

	# Spawn neutral units from BattleData
	if not battle_data.neutrals.is_empty():
		for neutral_dict in battle_data.neutrals:
			if not 'character' in neutral_dict or not neutral_dict.character:
				push_error("BattleLoader: Neutral missing character data")
				continue

			var character: CharacterData = neutral_dict.character
			var neutral_pos: Vector2i = neutral_dict.position if 'position' in neutral_dict else Vector2i(8, 5)
			var ai_brain: AIBrain = neutral_dict.ai_brain if 'ai_brain' in neutral_dict else null

			var neutral_unit: Node2D = _spawn_unit(character, neutral_pos, "neutral", ai_brain)
			_neutral_units.append(neutral_unit)

	print("[FLOW] Units: %d player, %d enemy, %d neutral" % [
		_player_units.size(), _enemy_units.size(), _neutral_units.size()])

	# Setup action menu UI BEFORE starting battle
	_action_menu = ActionMenuScene.instantiate()
	$UI.add_child(_action_menu)
	InputManager.set_action_menu(_action_menu)

	# Setup item menu UI
	_item_menu = ItemMenuScene.instantiate()
	$UI.add_child(_item_menu)
	InputManager.set_item_menu(_item_menu)

	# Setup grid cursor
	_grid_cursor = GridCursorScene.instantiate()
	_map_node.add_child(_grid_cursor)
	_grid_cursor.hide_cursor()  # Hidden until player turn
	InputManager.grid_cursor = _grid_cursor

	# Set path preview parent (use Map node for path visuals)
	InputManager.path_preview_parent = _map_node

	# Get reference to UI panels
	_stats_panel = $UI/HUD/ActiveUnitStatsPanel
	_terrain_panel = $UI/HUD/TerrainInfoPanel
	_combat_forecast_panel = $UI/HUD/CombatForecastPanel
	_turn_order_panel = $UI/HUD/TurnOrderPanel

	# Get reference to camera
	_camera = $Camera

	# Set camera reference in InputManager for inspection mode
	InputManager.camera = _camera

	# Set stats panel reference in InputManager (used for both active unit and inspection)
	InputManager.stats_panel = _stats_panel
	InputManager.terrain_panel = _terrain_panel
	InputManager.combat_forecast_panel = _combat_forecast_panel

	# Setup BattleManager with scene references
	BattleManager.setup(self, $Units)

	# CRITICAL: Connect BattleManager signals for XP, level-ups, and victory/defeat screens
	# This must be called because we're NOT calling BattleManager.start_battle()
	# (we call TurnManager.start_battle() directly for more control)
	BattleManager._connect_signals()

	# Populate BattleManager unit arrays (needed for AI to find targets)
	BattleManager.player_units = _player_units
	BattleManager.enemy_units = _enemy_units
	BattleManager.neutral_units = _neutral_units
	BattleManager.all_units = _player_units + _enemy_units + _neutral_units

	# Connect to BattleManager signals for visual feedback
	BattleManager.combat_resolved.connect(_on_combat_resolved)

	# Connect to TurnManager signals BEFORE starting battle (with guards to prevent duplicates)
	if not TurnManager.turn_cycle_started.is_connected(_on_turn_cycle_started):
		TurnManager.turn_cycle_started.connect(_on_turn_cycle_started)
	if not TurnManager.player_turn_started.is_connected(_on_player_turn_started):
		TurnManager.player_turn_started.connect(_on_player_turn_started)
	if not TurnManager.enemy_turn_started.is_connected(_on_enemy_turn_started):
		TurnManager.enemy_turn_started.connect(_on_enemy_turn_started)
	if not TurnManager.unit_turn_ended.is_connected(_on_unit_turn_ended):
		TurnManager.unit_turn_ended.connect(_on_unit_turn_ended)
	if not TurnManager.battle_ended.is_connected(_on_battle_ended):
		TurnManager.battle_ended.connect(_on_battle_ended)

	# Register camera with all game systems (TurnManager, CinematicsManager)
	_camera.register_with_systems()

	# Start turn-based battle (this will emit signals immediately)
	var all_units: Array[Node2D] = _player_units + _enemy_units + _neutral_units
	TurnManager.start_battle(all_units)

	# Connect InputManager signals to BattleManager (for combat execution)
	if not InputManager.action_selected.is_connected(BattleManager._on_action_selected):
		InputManager.action_selected.connect(BattleManager._on_action_selected)
	if not InputManager.target_selected.is_connected(BattleManager._on_target_selected):
		InputManager.target_selected.connect(BattleManager._on_target_selected)



func _spawn_unit(character: CharacterData, cell: Vector2i, p_faction: String, p_ai_brain: Resource) -> Node2D:
	# Use BattleManager's preloaded unit scene constant
	var unit: Node2D = BattleManager.UNIT_SCENE.instantiate()

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


## Handle debug toggle input (F3 key)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			_debug_visible = not _debug_visible
			var debug_label: Label = $UI/HUD/DebugLabel
			if debug_label:
				debug_label.visible = _debug_visible


func _process(_delta: float) -> void:
	# Note: Q-key quit is now handled globally by GameState autoload

	# Camera behavior:
	# - On turn start: CameraController.follow_unit() smoothly pans to new unit
	# - During unit movement: Follow the moving unit's position (while they're animating)
	# - In inspection mode: InputManager controls the camera to follow cursor
	var active_unit: Node2D = TurnManager.get_active_unit()
	if InputManager.current_state != InputManager.InputState.INSPECTING:
		if active_unit and active_unit.is_alive():
			# If unit is currently moving (has active tween), follow them smoothly
			if active_unit.is_moving():
				_camera.set_target_position(active_unit.position)

	# Early return if debug label is hidden (optimization)
	if not _debug_visible:
		return

	# Update debug label (visible since we passed the early return check)
	var debug_label: Label = $UI/HUD/DebugLabel
	if not debug_label:
		return

	debug_label.visible = true
	var mouse_world: Vector2 = get_global_mouse_position()
	var mouse_cell: Vector2i = GridManager.world_to_cell(mouse_world)

	debug_label.text = "=== DEBUG (F3) ===\n"
	debug_label.text += "Battle: %s\n" % battle_data.battle_name
	debug_label.text += "Cell: %s\n" % mouse_cell
	debug_label.text += "FPS: %d\n" % Engine.get_frames_per_second()

	if active_unit:
		debug_label.text += "Active: %s\n" % active_unit.get_display_name()

	debug_label.text += "\n--- Units ---\n"
	for unit in _player_units:
		if unit.is_alive():
			debug_label.text += "P: %s HP:%d/%d\n" % [
				unit.get_display_name().left(8),
				unit.stats.current_hp,
				unit.stats.max_hp
			]

	for unit in _enemy_units:
		if unit.is_alive():
			debug_label.text += "E: %s HP:%d/%d\n" % [
				unit.get_display_name().left(8),
				unit.stats.current_hp,
				unit.stats.max_hp
			]


## TurnManager signal handlers

## Called when a new turn cycle begins (all units get new turn priorities)
func _on_turn_cycle_started(turn_number: int) -> void:
	print("[FLOW] Turn cycle: %d" % turn_number)

	# Show turn order panel on first turn cycle
	if turn_number == 1:
		_turn_order_panel.show_panel()


func _on_player_turn_started(unit: Node2D) -> void:
	unit.show_selection()

	# Move camera to active unit
	_camera.follow_unit(unit)

	# Show stats and terrain panels
	_stats_panel.show_unit_stats(unit)
	var unit_cell: Vector2i = unit.grid_position
	_terrain_panel.show_terrain_info(unit_cell)

	# Update turn order panel
	_update_turn_order_display(unit)

	# GridManager now handles highlights via TileMapLayer (called by InputManager)
	# Start InputManager for player turn
	InputManager.start_player_turn(unit)


func _on_enemy_turn_started(unit: Node2D) -> void:
	unit.show_selection()

	# Move camera to active unit
	_camera.follow_unit(unit)

	# Show stats and terrain panels for enemy turn (optional)
	_stats_panel.show_unit_stats(unit)
	var unit_cell: Vector2i = unit.grid_position
	_terrain_panel.show_terrain_info(unit_cell)

	# Update turn order panel
	_update_turn_order_display(unit)


func _on_unit_turn_ended(unit: Node2D) -> void:
	unit.hide_selection()

	# Hide stats and terrain panels
	_stats_panel.hide_stats()
	_terrain_panel.hide_terrain_info()

	# GridManager now handles clearing highlights


func _on_battle_ended(_victory: bool) -> void:
	# Hide turn order panel
	_turn_order_panel.hide_panel()


## Helper to update the turn order panel with current battle state
func _update_turn_order_display(active_unit: Node2D) -> void:
	var upcoming: Array[Node2D] = TurnManager.get_remaining_turn_queue()
	_turn_order_panel.update_turn_order(active_unit, upcoming)
	_turn_order_panel.animate_transition()


func _on_combat_resolved(_attacker: Node2D, _defender: Node2D, _damage: int, _hit: bool, _crit: bool) -> void:
	# TODO: Show damage numbers (Phase 3)
	pass
