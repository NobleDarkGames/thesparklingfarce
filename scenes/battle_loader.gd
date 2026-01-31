## BATTLE SCENE - Primary battle scene controller
##
## ARCHITECTURE:
## This is the single entry point for all tactical battles. Responsibilities are split:
##   - battle_loader.gd (this file): Scene structure, map loading, unit spawning, UI updates
##   - BattleManager (autoload): Combat execution, XP/level-ups, victory/defeat screens
##   - TurnManager (autoload): Turn flow, active unit tracking
##
## Called via: TriggerManager -> SceneManager.change_scene("res://scenes/battle_loader.tscn")
##
## This is an ENGINE component that loads CONTENT (maps, battles) from mods.
## Maps come from: mods/*/maps/
## Battles come from: mods/*/data/battles/
##
## For modders:
## - Define battles via BattleData resources (no code required)
## - Override unit/combat scenes via mod.json "scenes" section
## - Custom AI via AIBehaviorData resources
##
## Controls:
## - Arrow Keys: Move cursor during your turn
## - Enter/Space: Confirm movement (opens action menu)
## - Backspace/X: Cancel/go back/free cursor inspect
## - Action Menu: Arrow keys to select, Enter to confirm
extends Node2D

## Grid defaults for maps with empty/invalid used_rect
const DEFAULT_CELL_SIZE: int = 32
const DEFAULT_GRID_SIZE: Vector2i = Vector2i(20, 11)

## TileMapLayers to exclude from terrain detection (visual-only layers)
const EXCLUDED_TERRAIN_LAYERS: Array[String] = ["HighlightLayer"]

# Preload scenes
const ActionMenuScene: PackedScene = preload("res://scenes/ui/action_menu.tscn")
const UnitUtils = preload("res://core/utils/unit_utils.gd")
const ItemMenuScene: PackedScene = preload("res://scenes/ui/item_menu.tscn")
const SpellMenuScene: PackedScene = preload("res://scenes/ui/spell_menu.tscn")
const GridCursorScene: PackedScene = preload("res://core/components/grid_cursor.tscn")
const DialogBoxScene: PackedScene = preload("res://scenes/ui/dialog_box.tscn")
const ChoiceSelectorScene: PackedScene = preload("res://scenes/ui/choice_selector.tscn")
const BattleGameMenuScene: PackedScene = preload("res://scenes/ui/battle_game_menu.tscn")

## Battle data - set via TriggerManager or Inspector for testing
@export var battle_data: BattleData

var _ground_layer: TileMapLayer = null
var _highlight_layer: TileMapLayer = null
var _player_units: Array[Unit] = []  # All player units
var _enemy_units: Array[Unit] = []  # All enemy units
var _neutral_units: Array[Unit] = []  # All neutral units
var _action_menu: ActionMenu = null
var _item_menu: ItemMenu = null
var _spell_menu: SpellMenu = null
var _game_menu: BattleGameMenu = null
var _map_overlay: BattleMapOverlay = null
var _grid_cursor: Node2D = null  # Grid cursor visual
var _stats_panel: ActiveUnitStatsPanel = null  # Stats display panel
var _terrain_panel: TerrainInfoPanel = null  # Terrain info panel
var _combat_forecast_panel: CombatForecastPanel = null  # Combat forecast panel
var _turn_order_panel: TurnOrderPanel = null  # Turn order preview panel
var _camera: CameraController = null  # Camera controller
var _dialog_box: DialogBox = null
var _choice_selector: ChoiceSelector = null
var _debug_visible: bool = false  # Debug display toggle (F3)
var _map_instance: Node2D = null  # Instanced map scene
var _map_node: Node2D = null  # The active Map node (from loaded map scene)
var _debug_label: Label = null  # Cached debug label reference


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
	move_child(map_node, 0)  # First child (map renders behind units/UI)

	# Store reference for later use (instead of relying on $Map)
	_map_node = map_node

	# Clean up the rest of the instanced scene (Camera, UI, etc. - we have our own)
	_map_instance.queue_free()
	_map_instance = null

	return true


## Collect TileMapLayer children from a map node for terrain detection
## Excludes visual-only layers (HighlightLayer, etc.) and sorts by z_index descending
## so the topmost layer is checked first for terrain
func _collect_terrain_layers(map_node: Node2D) -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []

	for child: Node in map_node.get_children():
		if child is TileMapLayer:
			var layer_name: String = child.name
			if layer_name not in EXCLUDED_TERRAIN_LAYERS:
				layers.append(child as TileMapLayer)

	# Sort by z_index descending (higher z = checked first, top layer wins)
	layers.sort_custom(func(a: TileMapLayer, b: TileMapLayer) -> bool:
		return a.z_index > b.z_index
	)

	return layers


func _ready() -> void:
	# Check if TriggerManager has battle data (from map trigger)
	var trigger_battle_data: BattleData = TriggerManager.get_current_battle_data()
	if trigger_battle_data:
		battle_data = trigger_battle_data

	# Validate battle data
	if not battle_data:
		push_error("BattleLoader: No battle_data assigned! Set the 'battle_data' export variable in the Inspector.")
		return

	# Load map from battle_data.map_scene
	if not _load_map_scene():
		push_error("BattleLoader: Failed to load map scene")
		return

	# Calculate grid size from tilemap used rect
	var grid_resource: Grid = Grid.new()
	grid_resource.cell_size = DEFAULT_CELL_SIZE

	var used_rect: Rect2i = _ground_layer.get_used_rect()
	if used_rect.size.x > 0 and used_rect.size.y > 0:
		grid_resource.grid_size = used_rect.size
	else:
		# Fallback for empty maps - use a default size
		grid_resource.grid_size = DEFAULT_GRID_SIZE

	# Collect terrain layers from map (excludes visual-only layers like HighlightLayer)
	var terrain_layers: Array[TileMapLayer] = _collect_terrain_layers(_map_node)
	GridManager.setup_grid(grid_resource, terrain_layers)
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
			var spawn_character_val: Variant = spawn_entry.get("character")
			var spawn_position_val: Variant = spawn_entry.get("position")
			var character: CharacterData = spawn_character_val as CharacterData
			var spawn_position: Vector2i = spawn_position_val as Vector2i

			# Get save data from PartyManager to preserve equipped items
			var save_data: CharacterSaveData = PartyManager.get_member_save_data(character.character_uid)
			var player_unit: Unit = _spawn_unit(character, spawn_position, "player", null, save_data)
			_player_units.append(player_unit)

	# Spawn enemy units from BattleData
	for enemy_dict: Dictionary in battle_data.enemies:
		var enemy_character_val: Variant = enemy_dict.get("character")
		if enemy_character_val == null:
			push_error("BattleLoader: Enemy missing character data")
			continue

		var character: CharacterData = enemy_character_val as CharacterData
		var enemy_pos_val: Variant = enemy_dict.get("position", Vector2i(10, 5))
		var enemy_pos: Vector2i = enemy_pos_val as Vector2i
		var ai_behavior_val: Variant = enemy_dict.get("ai_behavior")
		var ai_behavior: AIBehaviorData = ai_behavior_val as AIBehaviorData if ai_behavior_val != null else null

		var enemy_unit: Unit = _spawn_unit(character, enemy_pos, "enemy", ai_behavior)
		_enemy_units.append(enemy_unit)

	# Spawn neutral units from BattleData
	if not battle_data.neutrals.is_empty():
		for neutral_dict: Dictionary in battle_data.neutrals:
			var neutral_character_val: Variant = neutral_dict.get("character")
			if neutral_character_val == null:
				push_error("BattleLoader: Neutral missing character data")
				continue

			var character: CharacterData = neutral_character_val as CharacterData
			var neutral_pos_val: Variant = neutral_dict.get("position", Vector2i(8, 5))
			var neutral_pos: Vector2i = neutral_pos_val as Vector2i
			var ai_behavior_val: Variant = neutral_dict.get("ai_behavior")
			var ai_behavior: AIBehaviorData = ai_behavior_val as AIBehaviorData if ai_behavior_val != null else null

			var neutral_unit: Unit = _spawn_unit(character, neutral_pos, "neutral", ai_behavior)
			_neutral_units.append(neutral_unit)

	# Setup action menu UI BEFORE starting battle
	_action_menu = ActionMenuScene.instantiate()
	if not _action_menu:
		push_error("BattleLoader: Failed to instantiate ActionMenu")
		return
	$UI.add_child(_action_menu)
	InputManager.set_action_menu(_action_menu)

	# Setup item menu UI
	_item_menu = ItemMenuScene.instantiate()
	if not _item_menu:
		push_error("BattleLoader: Failed to instantiate ItemMenu")
		return
	$UI.add_child(_item_menu)
	InputManager.set_item_menu(_item_menu)

	# Setup spell menu UI
	_spell_menu = SpellMenuScene.instantiate()
	if not _spell_menu:
		push_error("BattleLoader: Failed to instantiate SpellMenu")
		return
	$UI.add_child(_spell_menu)
	InputManager.set_spell_menu(_spell_menu)

	# Setup battle game menu UI (Map, Speed, Status, Quit)
	_game_menu = BattleGameMenuScene.instantiate()
	if not _game_menu:
		push_error("BattleLoader: Failed to instantiate BattleGameMenu")
		return
	$UI.add_child(_game_menu)

	# Setup map overlay (created programmatically since it's simple)
	_map_overlay = BattleMapOverlay.new()
	_map_overlay.name = "BattleMapOverlay"
	$UI.add_child(_map_overlay)

	# Wire up game menu with map overlay and InputManager
	_game_menu.set_map_overlay(_map_overlay)
	InputManager.set_game_menu(_game_menu)

	# Setup dialog box for pre/post battle dialogue
	_dialog_box = DialogBoxScene.instantiate()
	_dialog_box.hide()
	$UI.add_child(_dialog_box)
	DialogManager.dialog_box = _dialog_box

	# Setup choice selector for dialogue choices
	_choice_selector = ChoiceSelectorScene.instantiate()
	_choice_selector.hide()
	$UI.add_child(_choice_selector)

	# Setup grid cursor
	_grid_cursor = GridCursorScene.instantiate()
	if not _grid_cursor:
		push_error("BattleLoader: Failed to instantiate GridCursor")
		return
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
	_debug_label = $UI/HUD/DebugLabel

	# Validate required UI panels exist
	if not _stats_panel or not _terrain_panel or not _combat_forecast_panel or not _turn_order_panel:
		push_error("BattleLoader: Missing required UI panels in HUD")
		return

	# Get reference to camera
	_camera = $Camera
	if not _camera:
		push_error("BattleLoader: Missing Camera node")
		return

	# Set camera reference in InputManager for inspection mode
	InputManager.camera = _camera

	# Set stats panel reference in InputManager (used for both active unit and inspection)
	InputManager.stats_panel = _stats_panel
	InputManager.terrain_panel = _terrain_panel
	InputManager.combat_forecast_panel = _combat_forecast_panel

	# Setup BattleManager with scene references
	BattleManager.setup(self, $Units)
	BattleManager.current_battle_data = battle_data

	# Connect BattleManager signals for XP, level-ups, and victory/defeat screens
	# We call setup() + _connect_signals() directly rather than start_battle() because
	# this scene handles map loading and unit spawning with specific scene integration
	BattleManager._connect_signals()

	# Populate BattleManager unit arrays (needed for AI to find targets)
	BattleManager.player_units = _player_units
	BattleManager.enemy_units = _enemy_units
	BattleManager.neutral_units = _neutral_units
	BattleManager.all_units = _player_units + _enemy_units + _neutral_units

	# Connect to BattleManager signals for visual feedback
	BattleManager.combat_resolved.connect(_on_combat_resolved)

	# Connect to TurnManager signals BEFORE starting battle
	UIUtils.safe_connect(TurnManager.turn_cycle_started, _on_turn_cycle_started)
	UIUtils.safe_connect(TurnManager.player_turn_started, _on_player_turn_started)
	UIUtils.safe_connect(TurnManager.enemy_turn_started, _on_enemy_turn_started)
	UIUtils.safe_connect(TurnManager.unit_turn_ended, _on_unit_turn_ended)
	UIUtils.safe_connect(TurnManager.battle_ended, _on_battle_ended)

	# Register camera with all game systems (TurnManager, CinematicsManager)
	_camera.register_with_systems()

	# Play pre-battle dialogue if configured
	if battle_data.pre_battle_dialogue:
		if DialogManager.start_dialog_from_resource(battle_data.pre_battle_dialogue):
			await DialogManager.dialog_ended
			# Scene may have been freed during dialogue
			if not is_instance_valid(self):
				return
			# battle_data Resource may have been freed during async operation
			if not is_instance_valid(battle_data):
				push_warning("BattleLoader: battle_data freed during pre-battle dialogue")
				return

	# Emit pre-battle event (mods can cancel)
	if not GameEventBus.emit_pre_battle_start(battle_data):
		push_warning("BattleLoader: Battle cancelled by mod")
		TriggerManager.return_to_map()
		return

	# Start turn-based battle (this will emit signals immediately)
	var all_units: Array[Unit] = _player_units + _enemy_units + _neutral_units
	TurnManager.start_battle(all_units)

	# Emit battle started signals for mod hooks
	BattleManager.battle_started.emit(battle_data)
	GameEventBus.post_battle_start.emit(battle_data)

	# Connect InputManager signals to BattleManager (for combat execution)
	UIUtils.safe_connect(InputManager.action_selected, BattleManager._on_action_selected)
	UIUtils.safe_connect(InputManager.target_selected, BattleManager._on_target_selected)



func _spawn_unit(character: CharacterData, cell: Vector2i, p_faction: String, p_ai_behavior: AIBehaviorData, p_save_data: CharacterSaveData = null) -> Unit:
	# Use BattleManager's unit scene (supports mod overrides)
	var unit: Unit = BattleManager._get_cached_scene("unit_scene").instantiate()

	# Initialize with character data (and save data if available for player units)
	if p_save_data:
		unit.initialize_from_save_data(character, p_save_data, p_faction, p_ai_behavior)
	else:
		unit.initialize(character, p_faction, p_ai_behavior)

	# Set grid position
	unit.grid_position = cell
	unit.position = GridManager.cell_to_world(cell)

	# Register with GridManager
	GridManager.set_cell_occupied(cell, unit)

	# Add to scene
	$Units.add_child(unit)

	# Connect death signal for fade-out effect
	if unit.has_signal("died"):
		var callback: Callable = BattleManager._on_unit_died.bind(unit)
		if not unit.died.is_connected(callback):
			unit.died.connect(callback)

	return unit


## Handle debug toggle input (F3 key)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F3:
			_debug_visible = not _debug_visible
			if _debug_label:
				_debug_label.visible = _debug_visible


func _process(_delta: float) -> void:
	# Note: Q-key quit is now handled globally by GameState autoload

	# Camera behavior:
	# - On turn start: CameraController.follow_unit() smoothly pans to new unit
	# - During unit movement: Follow the moving unit's position (while they're animating)
	# - In inspection mode: InputManager controls the camera to follow cursor
	var active_unit: Unit = TurnManager.get_active_unit()
	if InputManager.current_state != InputManager.InputState.INSPECTING:
		if active_unit and active_unit.is_alive():
			# If unit is currently moving (has active tween), follow them smoothly
			if active_unit.is_moving():
				_camera.set_target_position(active_unit.position)

	# Early return if debug label is hidden (optimization)
	if not _debug_visible or not _debug_label:
		return

	# Update debug label (visible since we passed the early return check)
	_debug_label.visible = true
	var mouse_world: Vector2 = get_global_mouse_position()
	var mouse_cell: Vector2i = GridManager.world_to_cell(mouse_world)

	# Build debug text using PackedStringArray to reduce GC pressure
	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== DEBUG (F3) ===")
	lines.append("Battle: %s" % battle_data.battle_name)
	lines.append("Cell: %s" % mouse_cell)
	lines.append("FPS: %d" % Engine.get_frames_per_second())

	if active_unit:
		lines.append("Active: %s" % UnitUtils.get_display_name(active_unit))

	lines.append("")
	lines.append("--- Units ---")
	for unit: Unit in _player_units:
		if unit.is_alive():
			lines.append("P: %s HP:%d/%d" % [
				UnitUtils.get_display_name(unit).left(8),
				unit.stats.current_hp,
				unit.stats.max_hp
			])

	for unit: Unit in _enemy_units:
		if unit.is_alive():
			lines.append("E: %s HP:%d/%d" % [
				UnitUtils.get_display_name(unit).left(8),
				unit.stats.current_hp,
				unit.stats.max_hp
			])

	_debug_label.text = "\n".join(lines)


## TurnManager signal handlers

## Called when a new turn cycle begins (all units get new turn priorities)
func _on_turn_cycle_started(turn_number: int) -> void:

	# Show turn order panel on first turn cycle
	if turn_number == 1:
		_turn_order_panel.show_panel()


func _on_player_turn_started(unit: Unit) -> void:
	if not is_instance_valid(unit):
		return
	unit.show_selection()

	# Move camera to active unit
	_camera.follow_unit(unit)

	# Show stats and terrain panels
	_stats_panel.show_unit_stats(unit)
	var unit_cell: Vector2i = unit.grid_position
	_terrain_panel.show_terrain_info(unit_cell)

	# Connect to cell_entered to update terrain panel during movement
	if unit.has_signal("cell_entered"):
		UIUtils.safe_connect(unit.cell_entered, _on_active_unit_cell_entered)

	# Update turn order panel
	_update_turn_order_display(unit)

	# GridManager now handles highlights via TileMapLayer (called by InputManager)
	# Start InputManager for player turn
	InputManager.start_player_turn(unit)


func _on_enemy_turn_started(unit: Unit) -> void:
	if not is_instance_valid(unit):
		return
	unit.show_selection()

	# Move camera to active unit
	_camera.follow_unit(unit)

	# Show stats and terrain panels for enemy turn (optional)
	_stats_panel.show_unit_stats(unit)
	var unit_cell: Vector2i = unit.grid_position
	_terrain_panel.show_terrain_info(unit_cell)

	# Connect to cell_entered to update terrain panel during movement
	if unit.has_signal("cell_entered"):
		UIUtils.safe_connect(unit.cell_entered, _on_active_unit_cell_entered)

	# Update turn order panel
	_update_turn_order_display(unit)


func _on_unit_turn_ended(unit: Unit) -> void:
	if not is_instance_valid(unit):
		return
	unit.hide_selection()

	# Disconnect from cell_entered signal
	if unit.has_signal("cell_entered"):
		UIUtils.safe_disconnect(unit.cell_entered, _on_active_unit_cell_entered)

	# Hide stats and terrain panels
	_stats_panel.hide_stats()
	_terrain_panel.hide_terrain_info()

	# GridManager now handles clearing highlights


## Update terrain panel when active unit enters a new cell during movement
func _on_active_unit_cell_entered(cell: Vector2i) -> void:
	# Use non-animating update for rapid movement updates
	if _terrain_panel.has_method("update_terrain_info"):
		_terrain_panel.update_terrain_info(cell)
	else:
		_terrain_panel.show_terrain_info(cell)


func _on_battle_ended(_victory: bool) -> void:
	# Hide turn order panel
	_turn_order_panel.hide_panel()


## Helper to update the turn order panel with current battle state
func _update_turn_order_display(active_unit: Unit) -> void:
	var upcoming: Array[Unit] = TurnManager.get_remaining_turn_queue()
	_turn_order_panel.update_turn_order(active_unit, upcoming)
	_turn_order_panel.animate_transition()


func _on_combat_resolved(_attacker: Unit, _defender: Unit, _damage: int, _hit: bool, _crit: bool) -> void:
	# Damage display handled by combat_animation_scene.gd via _show_damage_number()
	pass


func _exit_tree() -> void:
	# Clear DialogManager reference to avoid dangling pointer
	if DialogManager.dialog_box == _dialog_box:
		DialogManager.dialog_box = null

	# Disconnect TurnManager signals
	UIUtils.safe_disconnect(TurnManager.turn_cycle_started, _on_turn_cycle_started)
	UIUtils.safe_disconnect(TurnManager.player_turn_started, _on_player_turn_started)
	UIUtils.safe_disconnect(TurnManager.enemy_turn_started, _on_enemy_turn_started)
	UIUtils.safe_disconnect(TurnManager.unit_turn_ended, _on_unit_turn_ended)
	UIUtils.safe_disconnect(TurnManager.battle_ended, _on_battle_ended)

	# Disconnect BattleManager signals
	UIUtils.safe_disconnect(BattleManager.combat_resolved, _on_combat_resolved)

	# Disconnect InputManager signals from BattleManager
	UIUtils.safe_disconnect(InputManager.action_selected, BattleManager._on_action_selected)
	UIUtils.safe_disconnect(InputManager.target_selected, BattleManager._on_target_selected)
