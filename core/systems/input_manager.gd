## InputManager - Shining Force style player input handling
##
## Manages input for the active unit only, following Shining Force's turn flow:
## 1. Movement exploration (free to move/cancel/redo)
## 2. Action menu (Attack, Magic, Item, Stay)
## 3. Targeting (if applicable)
## 4. Execution and turn end
extends Node

## Input state machine
enum InputState {
	WAITING,            # Not player's turn
	INSPECTING,         # Free cursor mode - inspecting battlefield (B button)
	EXPLORING_MOVEMENT,  # LEGACY: Cursor-based movement (kept for compatibility)
	DIRECT_MOVEMENT,     # SF2-style: Player controls unit directly tile-by-tile
	SELECTING_ACTION,    # Action menu open (Attack/Magic/Item/Stay)
	SELECTING_ITEM,      # Item menu open (selecting which item to use)
	SELECTING_ITEM_TARGET,  # Selecting target for item use (e.g., healing ally)
	TARGETING,           # Selecting target for attack/spell
	EXECUTING,           # Action executing (animations, etc.)
}

## Signals
signal movement_confirmed(unit: Node2D, destination: Vector2i)
signal action_selected(unit: Node2D, action: String)
signal target_selected(unit: Node2D, target: Node2D)
signal item_use_requested(unit: Node2D, item_id: String, target: Node2D)  # Player used an item on a target
signal turn_cancelled()  # Player wants to redo movement

## Current state
var current_state: InputState = InputState.WAITING
var active_unit: Node2D = null

## Turn session ID to prevent stale signals from previous turns
var _turn_session_id: int = 0

## Movement tracking
var movement_start_position: Vector2i = Vector2i.ZERO
var current_cursor_position: Vector2i = Vector2i.ZERO
var walkable_cells: Array[Vector2i] = []

## Action menu state
var current_action: String = ""
var available_actions: Array[String] = []

## Item usage state
var selected_item_id: String = ""  # Item ID selected for use (for target selection)
var selected_item_data: ItemData = null  # Cached ItemData for the selected item
var _item_valid_targets: Array[Vector2i] = []  # Valid target cells for snap-to-target navigation

## References (set by battle scene or autoload setup)
var camera: Camera2D = null
var action_menu: Control = null  # Will be set by battle scene
var item_menu: Control = null  # Will be set by battle scene
var battle_scene: Node = null  # Reference to battle scene for UI access
var grid_cursor: Node2D = null  # Visual cursor for grid movement
var path_preview_parent: Node2D = null  # Parent node for path visuals
var stats_panel: Control = null  # ActiveUnitStatsPanel for both active unit and inspection
var terrain_panel: Control = null  # TerrainInfoPanel for cursor position
var combat_forecast_panel: Control = null  # CombatForecastPanel for attack preview

## Path preview
var current_path: Array[Vector2i] = []
var path_visuals: Array[Node2D] = []

## Continuous input handling
var _input_delay: float = 0.0
const INPUT_DELAY_INITIAL: float = 0.15  # Delay before repeat starts (SF2-responsive)
const INPUT_DELAY_REPEAT: float = 0.08   # Delay between repeats (SF2-responsive)

## Direct movement tracking (SF2-style tile-by-tile control)
var movement_path_taken: Array[Vector2i] = []  # Cells walked through in order
var movement_start_cell: Vector2i = Vector2i.ZERO  # Original position for cancel
var is_direct_moving: bool = false              # True during step animation (blocks input)


func _ready() -> void:
	# Disable per-frame processing on startup (we start in WAITING state)
	set_process(false)


## Set action menu reference and connect signals
func set_action_menu(menu: Control) -> void:
	action_menu = menu

	# Connect signals (we'll manage connection lifecycle per turn)
	if not action_menu.action_selected.is_connected(_on_action_menu_selected):
		action_menu.action_selected.connect(_on_action_menu_selected)
	if not action_menu.menu_cancelled.is_connected(_on_action_menu_cancelled):
		action_menu.menu_cancelled.connect(_on_action_menu_cancelled)


## Disconnect action menu signals (called when turn ends)
## Forces complete disconnection - removes ALL connections, not just the first one
func _disconnect_action_menu_signals() -> void:
	if action_menu:
		# Use while loop to ensure ALL connections are removed (fixes stale signal bug)
		while action_menu.action_selected.is_connected(_on_action_menu_selected):
			action_menu.action_selected.disconnect(_on_action_menu_selected)
		while action_menu.menu_cancelled.is_connected(_on_action_menu_cancelled):
			action_menu.menu_cancelled.disconnect(_on_action_menu_cancelled)


## Set item menu reference and connect signals
func set_item_menu(menu: Control) -> void:
	item_menu = menu

	# Connect signals (we'll manage connection lifecycle per turn)
	if not item_menu.item_selected.is_connected(_on_item_menu_selected):
		item_menu.item_selected.connect(_on_item_menu_selected)
	if not item_menu.menu_cancelled.is_connected(_on_item_menu_cancelled):
		item_menu.menu_cancelled.connect(_on_item_menu_cancelled)


## Disconnect item menu signals (called when turn ends)
func _disconnect_item_menu_signals() -> void:
	if item_menu:
		while item_menu.item_selected.is_connected(_on_item_menu_selected):
			item_menu.item_selected.disconnect(_on_item_menu_selected)
		while item_menu.menu_cancelled.is_connected(_on_item_menu_cancelled):
			item_menu.menu_cancelled.disconnect(_on_item_menu_cancelled)


## Reconnect item menu signals (called when player turn starts)
func _reconnect_item_menu_signals() -> void:
	if item_menu:
		if not item_menu.item_selected.is_connected(_on_item_menu_selected):
			item_menu.item_selected.connect(_on_item_menu_selected)
		if not item_menu.menu_cancelled.is_connected(_on_item_menu_cancelled):
			item_menu.menu_cancelled.connect(_on_item_menu_cancelled)


## Handle item menu selection signal
func _on_item_menu_selected(item_id: String, signal_session_id: int) -> void:
	# Guard: Reject stale signals from previous turns
	if signal_session_id != _turn_session_id:
		push_warning("InputManager: Ignoring STALE item selection from session %d (current: %d)" % [
			signal_session_id,
			_turn_session_id
		])
		return

	# Guard: Only process in correct state
	if current_state != InputState.SELECTING_ITEM or active_unit == null:
		push_warning("InputManager: Ignoring item selection in state %s" % InputState.keys()[current_state])
		return

	# Play selection sound
	AudioManager.play_sfx("menu_select", AudioManager.SFXCategory.UI)

	# Store selected item for target selection
	selected_item_id = item_id
	selected_item_data = ModLoader.registry.get_resource("item", item_id) as ItemData

	if not selected_item_data:
		push_warning("InputManager: Item '%s' not found in registry" % item_id)
		set_state(InputState.SELECTING_ACTION)
		return

	# Check if item needs target selection
	if _item_needs_target_selection(selected_item_data):
		set_state(InputState.SELECTING_ITEM_TARGET)
	else:
		# Self-target items (or items without effect) - use immediately on self
		_use_item_on_target(active_unit)


## Check if an item needs target selection (vs self-use)
func _item_needs_target_selection(item: ItemData) -> bool:
	if not item or not item.effect:
		# No effect = self-target by default
		return false

	var effect: AbilityData = item.effect as AbilityData
	if not effect:
		return false

	# Check the ability's target type
	match effect.target_type:
		AbilityData.TargetType.SELF:
			return false  # Always targets self
		AbilityData.TargetType.SINGLE_ALLY:
			return true  # Needs to pick an ally (including self)
		AbilityData.TargetType.SINGLE_ENEMY:
			return true  # Needs to pick an enemy
		AbilityData.TargetType.ALL_ALLIES, AbilityData.TargetType.ALL_ENEMIES:
			return false  # Affects all, no selection needed
		AbilityData.TargetType.AREA:
			return true  # Needs position selection
		_:
			return false


## Use the selected item on the given target
func _use_item_on_target(target: Node2D) -> void:
	# Emit item use signal for BattleManager to handle
	item_use_requested.emit(active_unit, selected_item_id, target)

	# Clear item selection state
	selected_item_id = ""
	selected_item_data = null
	_item_valid_targets.clear()

	# Transition to EXECUTING (BattleManager will handle the item use and end turn)
	set_state(InputState.EXECUTING)


## Handle item menu cancellation signal
func _on_item_menu_cancelled(signal_session_id: int) -> void:
	# Guard: Reject stale cancel signals from previous turns
	if signal_session_id != _turn_session_id:
		push_warning("InputManager: Ignoring STALE item cancel from session %d (current: %d)" % [
			signal_session_id,
			_turn_session_id
		])
		return

	# Return to action menu
	set_state(InputState.SELECTING_ACTION)


## Reconnect action menu signals (called when player turn starts)
func _reconnect_action_menu_signals() -> void:
	if action_menu:
		if not action_menu.action_selected.is_connected(_on_action_menu_selected):
			action_menu.action_selected.connect(_on_action_menu_selected)
		if not action_menu.menu_cancelled.is_connected(_on_action_menu_cancelled):
			action_menu.menu_cancelled.connect(_on_action_menu_cancelled)


## Handle action menu selection signal
## signal_session_id: The session ID captured when menu was shown (not when signal arrives)
func _on_action_menu_selected(action: String, signal_session_id: int) -> void:
	# Play menu selection sound
	AudioManager.play_sfx("menu_select", AudioManager.SFXCategory.UI)

	# Use the session ID that was passed WITH the signal (captured at emission time)
	_select_action(action, signal_session_id)


## Handle action menu cancellation signal
## signal_session_id: The session ID captured when menu was shown (not when signal arrives)
func _on_action_menu_cancelled(signal_session_id: int) -> void:

	# Guard: Reject stale cancel signals from previous turns
	if signal_session_id != _turn_session_id:
		push_warning("InputManager: Ignoring STALE cancel signal from session %d (current: %d)" % [
			signal_session_id,
			_turn_session_id
		])
		return

	# Play menu cancel sound
	AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)

	_cancel_action_menu()


## Initialize input manager for new player turn
func start_player_turn(unit: Node2D) -> void:
	if not unit:
		push_error("InputManager: Cannot start turn with null unit")
		return

	# Increment turn session ID to invalidate any queued signals from previous turns
	_turn_session_id += 1

	# NUCLEAR OPTION: Reset menu state FIRST to clear any stale state
	if action_menu:
		action_menu.reset_menu()

	# IMPORTANT: Disconnect first to clear any queued signals
	# Reconnection happens AFTER state change to eliminate timing window
	_disconnect_action_menu_signals()

	active_unit = unit
	movement_start_position = unit.grid_position
	current_cursor_position = unit.grid_position

	# Calculate walkable cells
	var movement_range: int = 4  # Default fallback
	var movement_type: int = 0   # Default: FOOT
	var current_class: ClassData = unit.get_current_class()
	if current_class:
		movement_range = current_class.movement_range
		movement_type = current_class.movement_type
	else:
		push_warning("InputManager: Unit %s has no character_class, using default movement (range=%d)" % [unit.get_display_name(), movement_range])

	walkable_cells = GridManager.get_walkable_cells(
		movement_start_position,
		movement_range,
		movement_type,
		unit.faction
	)

	# SF2-STYLE DIRECT MOVEMENT: Player controls unit tile-by-tile
	# Check if unit can move at all (not immobilized)
	if movement_range <= 0:
		# No movement possible - skip directly to action menu
		set_state(InputState.SELECTING_ACTION)
	else:
		# Normal case: Enter direct movement mode
		set_state(InputState.DIRECT_MOVEMENT)

	# NOW reconnect signals after state is correct (eliminates timing window)
	_reconnect_action_menu_signals()
	_reconnect_item_menu_signals()


## Change input state
func set_state(new_state: InputState) -> void:
	var old_state: InputState = current_state
	current_state = new_state

	# Warn on unexpected transition to WAITING
	if new_state == InputState.WAITING and old_state == InputState.EXPLORING_MOVEMENT:
		push_warning("InputManager: Unexpected transition from EXPLORING_MOVEMENT to WAITING!")

	match new_state:
		InputState.WAITING:
			_on_enter_waiting()
		InputState.INSPECTING:
			_on_enter_inspecting()
		InputState.EXPLORING_MOVEMENT:
			_on_enter_exploring_movement()
		InputState.DIRECT_MOVEMENT:
			_on_enter_direct_movement()
		InputState.SELECTING_ACTION:
			_on_enter_selecting_action()
		InputState.SELECTING_ITEM:
			_on_enter_selecting_item()
		InputState.SELECTING_ITEM_TARGET:
			_on_enter_selecting_item_target()
		InputState.TARGETING:
			_on_enter_targeting()
		InputState.EXECUTING:
			_on_enter_executing()


## State enter handlers
func _on_enter_waiting() -> void:
	# Disable per-frame processing in waiting state (optimization)
	set_process(false)
	active_unit = null
	walkable_cells.clear()
	available_actions.clear()


func _on_enter_inspecting() -> void:
	# Enable per-frame processing for continuous cursor movement
	set_process(true)
	# Free cursor mode - can inspect any unit on battlefield
	# Clear movement highlights (we're not moving anymore)
	GridManager.clear_highlights()

	# Clear path preview
	_clear_path_preview()

	# Cursor is free to roam anywhere - show at current position
	if grid_cursor:
		grid_cursor.set_grid_position(current_cursor_position)
		grid_cursor.show_cursor()

	# Update inspector for unit at current cursor position (if any)
	_update_unit_inspector()


func _on_enter_exploring_movement() -> void:
	# Enable per-frame processing for continuous cursor movement
	set_process(true)
	# Show active unit stats when exiting inspection mode
	if stats_panel and active_unit:
		stats_panel.show_unit_stats(active_unit)

	# Show movement range highlights
	if not walkable_cells.is_empty():
		_show_movement_range()

	# Position cursor on unit
	current_cursor_position = active_unit.grid_position

	# Show cursor at unit position
	if grid_cursor:
		grid_cursor.set_grid_position(current_cursor_position)
		grid_cursor.show_cursor()

	# Return camera to active unit (important when exiting inspection mode)
	if camera and camera is CameraController and active_unit:
		(camera as CameraController).follow_unit(active_unit)

	# Clear any existing path
	_clear_path_preview()


func _on_enter_direct_movement() -> void:
	## SF2-style direct movement: Player controls unit tile-by-tile
	# Enable per-frame processing for continuous input
	set_process(true)

	# Show active unit stats
	if stats_panel and active_unit:
		stats_panel.show_unit_stats(active_unit)

	# Initialize movement tracking
	movement_start_cell = active_unit.grid_position
	movement_path_taken = [movement_start_cell]
	is_direct_moving = false

	# Hide grid cursor during direct movement (unit IS the cursor)
	if grid_cursor:
		grid_cursor.hide_cursor()

	# Show movement range (walkable_cells already calculated at turn start)
	_show_movement_range()

	# Camera focuses on unit
	if camera and camera is CameraController:
		(camera as CameraController).follow_unit(active_unit)


func _on_enter_selecting_action() -> void:
	# Disable per-frame processing (menu handles its own input)
	set_process(false)
	# Clear movement highlights
	GridManager.clear_highlights()

	# Clear path preview but KEEP cursor visible (SF-style)
	_clear_path_preview()

	# Keep cursor on unit's current position
	if grid_cursor and active_unit:
		grid_cursor.set_grid_position(active_unit.grid_position)
		grid_cursor.show_cursor()

	# Ensure camera is centered on unit for action menu
	if camera and camera is CameraController and active_unit:
		(camera as CameraController).follow_unit(active_unit)

	# Calculate available actions based on context
	available_actions = _get_available_actions()

	# Show action menu
	_show_action_menu()


func _on_enter_selecting_item() -> void:
	# Disable per-frame processing (menu handles its own input)
	set_process(false)

	# Hide action menu if visible
	if action_menu and action_menu.visible:
		action_menu.hide_menu()

	# Show item menu
	_show_item_menu()


func _on_enter_selecting_item_target() -> void:
	# Disable per-frame processing (targeting uses _input for individual key presses)
	set_process(false)

	# Hide item menu if visible
	if item_menu and item_menu.visible:
		item_menu.hide_menu()

	# Clear movement highlights
	GridManager.clear_highlights()

	# Get valid targets for the item and store for snap-to-target navigation
	_item_valid_targets = _get_valid_item_target_cells()

	if _item_valid_targets.is_empty():
		# No valid targets - return to action menu (SF-authentic: don't end turn)
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		selected_item_id = ""
		selected_item_data = null
		set_state(InputState.SELECTING_ACTION)
		return

	# Show item target range (green for allies, different from attack red)
	_show_item_targeting_range(_item_valid_targets)

	# Position cursor on first valid target (prefer self if valid)
	if active_unit.grid_position in _item_valid_targets:
		current_cursor_position = active_unit.grid_position
	else:
		current_cursor_position = _item_valid_targets[0]

	# Show cursor at target position
	if grid_cursor:
		grid_cursor.set_grid_position(current_cursor_position)
		grid_cursor.show_cursor()

	# Update stats panel to show target info
	_update_item_target_info()


func _on_enter_targeting() -> void:
	# Disable per-frame processing (targeting uses _input for individual key presses)
	set_process(false)
	# Clear movement highlights
	GridManager.clear_highlights()

	# Show valid targets based on selected action
	_show_targeting_range()

	# Position cursor on nearest valid target
	var valid_targets: Array[Vector2i] = _get_valid_target_cells(1)  # TODO: Get actual weapon range
	if not valid_targets.is_empty():
		# Start cursor on first valid target
		current_cursor_position = valid_targets[0]
	else:
		# No valid targets, position on unit
		current_cursor_position = active_unit.grid_position

	# Show cursor at target position
	if grid_cursor:
		grid_cursor.set_grid_position(current_cursor_position)
		grid_cursor.show_cursor()

	# Show combat forecast for initial target
	_update_combat_forecast()


func _on_enter_executing() -> void:
	# Disable per-frame processing during action execution
	set_process(false)
	# Action is executing, clear all highlights and cursor
	GridManager.clear_highlights()

	# Hide cursor during execution
	if grid_cursor:
		grid_cursor.hide_cursor()

	# Hide combat forecast
	if combat_forecast_panel and combat_forecast_panel.has_method("hide_forecast"):
		combat_forecast_panel.hide_forecast()


## Handle continuous key presses (for cursor movement when held)
func _process(delta: float) -> void:
	# Only handle continuous input in movement and inspection modes
	if current_state != InputState.EXPLORING_MOVEMENT and current_state != InputState.INSPECTING and current_state != InputState.DIRECT_MOVEMENT:
		return

	# Block continuous input during step animation
	if current_state == InputState.DIRECT_MOVEMENT and is_direct_moving:
		return

	# Check if any directional key is held
	var direction: Vector2i = Vector2i.ZERO
	if Input.is_action_pressed("ui_up"):
		direction.y = -1
	elif Input.is_action_pressed("ui_down"):
		direction.y = 1
	elif Input.is_action_pressed("ui_left"):
		direction.x = -1
	elif Input.is_action_pressed("ui_right"):
		direction.x = 1

	# If a direction is held, handle with delay
	if direction != Vector2i.ZERO:
		# Only process if delay has expired
		if _input_delay > 0.0:
			_input_delay -= delta
		else:
			# Move based on current state
			if current_state == InputState.EXPLORING_MOVEMENT:
				_move_cursor(direction)
			elif current_state == InputState.INSPECTING:
				_move_free_cursor(direction)
			elif current_state == InputState.DIRECT_MOVEMENT:
				_try_direct_step(direction)

			# Set repeat delay (faster after initial delay)
			_input_delay = INPUT_DELAY_REPEAT
	else:
		# No direction held, reset delay to 0 (next press will be immediate via _input)
		_input_delay = 0.0


## Process input based on current state
func _input(event: InputEvent) -> void:
	match current_state:
		InputState.INSPECTING:
			_handle_inspecting_input(event)
		InputState.EXPLORING_MOVEMENT:
			_handle_movement_input(event)
		InputState.DIRECT_MOVEMENT:
			_handle_direct_movement_input(event)
		InputState.SELECTING_ACTION:
			_handle_action_menu_input(event)
		InputState.SELECTING_ITEM_TARGET:
			_handle_item_target_input(event)
		InputState.TARGETING:
			_handle_targeting_input(event)


## Handle inspecting mode input (free cursor)
func _handle_inspecting_input(event: InputEvent) -> void:
	var handled: bool = false

	# Arrow keys move cursor freely (no restrictions)
	if event.is_action_pressed("ui_up"):
		_move_free_cursor(Vector2i(0, -1))
		_input_delay = INPUT_DELAY_INITIAL  # Set delay for continuous movement
		handled = true
	elif event.is_action_pressed("ui_down"):
		_move_free_cursor(Vector2i(0, 1))
		_input_delay = INPUT_DELAY_INITIAL
		handled = true
	elif event.is_action_pressed("ui_left"):
		_move_free_cursor(Vector2i(-1, 0))
		_input_delay = INPUT_DELAY_INITIAL
		handled = true
	elif event.is_action_pressed("ui_right"):
		_move_free_cursor(Vector2i(1, 0))
		_input_delay = INPUT_DELAY_INITIAL
		handled = true

	# Accept key: Check what's under cursor
	if event.is_action_pressed("ui_accept"):
		var unit_at_cursor: Node2D = GridManager.get_unit_at_cell(current_cursor_position)

		if unit_at_cursor == active_unit:
			# Pressed A on our own unit - return to direct movement mode
			current_cursor_position = active_unit.grid_position
			set_state(InputState.DIRECT_MOVEMENT)
		elif unit_at_cursor:
			# Pressed A on another unit - show stats
			# TODO: Show unit stats panel
			pass
		else:
			# Pressed A on empty cell - could open game menu (Map, Speed, etc.)
			# TODO: Implement game menu (Map, Speed settings, etc.)
			pass
		handled = true

	# Cancel returns to direct movement mode
	if event.is_action_pressed("sf_cancel"):
		current_cursor_position = active_unit.grid_position
		set_state(InputState.DIRECT_MOVEMENT)
		handled = true

	# Consume input to prevent duplicate processing by other handlers
	if handled:
		get_viewport().set_input_as_handled()


## Handle movement exploration input
func _handle_movement_input(event: InputEvent) -> void:
	var handled: bool = false

	# Mouse click to select destination
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Get global mouse position (works with camera)
			var mouse_world: Vector2 = active_unit.get_global_mouse_position()
			var target_cell: Vector2i = GridManager.world_to_cell(mouse_world)
			_try_move_to_cell(target_cell)
			handled = true

	# Keyboard: Arrow keys to move cursor
	if event.is_action_pressed("ui_up"):
		_move_cursor(Vector2i(0, -1))
		_input_delay = INPUT_DELAY_INITIAL  # Set delay for continuous movement
		handled = true
	elif event.is_action_pressed("ui_down"):
		_move_cursor(Vector2i(0, 1))
		_input_delay = INPUT_DELAY_INITIAL
		handled = true
	elif event.is_action_pressed("ui_left"):
		_move_cursor(Vector2i(-1, 0))
		_input_delay = INPUT_DELAY_INITIAL
		handled = true
	elif event.is_action_pressed("ui_right"):
		_move_cursor(Vector2i(1, 0))
		_input_delay = INPUT_DELAY_INITIAL
		handled = true

	# Accept key - Opens action menu (moved or not)
	# AUTHENTIC SF: Can press A/C at starting position to act without moving
	if event.is_action_pressed("ui_accept"):
		# If cursor hasn't moved, open action menu at starting position
		if current_cursor_position == movement_start_position:
			set_state(InputState.SELECTING_ACTION)
		else:
			# Cursor has moved - move unit and open action menu
			_try_move_to_cell(current_cursor_position)
		handled = true

	# Cancel key - Enter free cursor inspection mode (B button in SF)
	if event.is_action_pressed("sf_cancel"):
		set_state(InputState.INSPECTING)
		handled = true

	# Consume input to prevent duplicate processing by other handlers
	if handled:
		get_viewport().set_input_as_handled()


## Try to move unit to target cell
func _try_move_to_cell(target_cell: Vector2i) -> void:
	if not GridManager.is_within_bounds(target_cell):
		return

	if target_cell not in walkable_cells:
		return

	if target_cell != active_unit.grid_position:
		# Calculate the full path from current position to target
		var unit_class: ClassData = active_unit.get_current_class()
		var movement_type: int = unit_class.movement_type if unit_class else 0
		var path: Array[Vector2i] = GridManager.find_path(
			active_unit.grid_position,
			target_cell,
			movement_type,
			active_unit.faction
		)

		# Move along the path (animates through each cell)
		if not path.is_empty():
			active_unit.move_along_path(path)
		else:
			push_warning("InputManager: No path found to %s, using direct movement" % target_cell)
			active_unit.move_to(target_cell)

	# Movement confirmed, open action menu
	movement_confirmed.emit(active_unit, target_cell)
	set_state(InputState.SELECTING_ACTION)


## Cancel movement and return to start position
func _cancel_movement() -> void:

	# Move unit back to start
	if active_unit.grid_position != movement_start_position:
		# Update GridManager
		GridManager.move_unit(active_unit, active_unit.grid_position, movement_start_position)
		active_unit.grid_position = movement_start_position
		active_unit.position = GridManager.cell_to_world(movement_start_position)

	# Reset cursor to unit position
	current_cursor_position = movement_start_position
	if grid_cursor:
		grid_cursor.set_grid_position(current_cursor_position)

	# Clear path preview
	_clear_path_preview()

	turn_cancelled.emit()


## Calculate which actions are available
func _get_available_actions() -> Array[String]:
	var actions: Array[String] = []

	# AUTHENTIC SHINING FORCE: No "Move" option - movement happens BEFORE menu
	# Menu only appears after positioning (or at starting position if not moved)

	# Attack - only if enemies in range
	var enemies_in_range: bool = _check_enemies_in_range()
	if enemies_in_range:
		actions.append("Attack")

	# Magic - only if unit has spells
	if active_unit.character_data and _has_spells():
		actions.append("Magic")

	# Item - always available
	actions.append("Item")

	# Stay - always available (ends turn at current position)
	actions.append("Stay")

	return actions


## Check if enemies are in attack range
func _check_enemies_in_range() -> bool:
	# For now, assume melee range (1 cell)
	# TODO: Check weapon range when equipment system exists
	var attack_range: int = 1

	var adjacent_cells: Array[Vector2i] = GridManager.get_cells_in_range(
		active_unit.grid_position,
		attack_range
	)

	for cell in adjacent_cells:
		var occupant: Node2D = GridManager.get_unit_at_cell(cell)
		if occupant and occupant.is_enemy_unit():
			return true

	return false


## Check if unit has spells
func _has_spells() -> bool:
	# TODO: Implement when spell system exists
	return false


## Show movement range highlights
## Shows blue movement range highlights.
func _show_movement_range() -> void:
	if not active_unit:
		return

	var unit_cell: Vector2i = active_unit.grid_position
	var unit_class: ClassData = active_unit.get_current_class()
	var movement_range: int = unit_class.movement_range if unit_class else 4
	var movement_type: int = unit_class.movement_type if unit_class else 0

	GridManager.show_movement_range(unit_cell, movement_range, movement_type, active_unit.faction)


## Move cursor by offset and update visuals (movement mode - clamped to walkable)
func _move_cursor(offset: Vector2i) -> void:
	var new_pos: Vector2i = current_cursor_position + offset

	# Check if position is valid for cursor (can pass through allies for planning)
	var is_walkable: bool = new_pos in walkable_cells
	var is_ally_cell: bool = false

	# Allow cursor to pass through allied units (same faction as active unit)
	if not is_walkable and active_unit:
		var unit_at_pos: Node = GridManager.get_unit_at_cell(new_pos)
		if unit_at_pos and unit_at_pos.faction == active_unit.faction:
			is_ally_cell = true

	if not is_walkable and not is_ally_cell:
		return

	# Update cursor position
	current_cursor_position = new_pos

	# Play cursor movement sound
	AudioManager.play_sfx("cursor_move", AudioManager.SFXCategory.UI)

	# Update cursor visual
	if grid_cursor:
		grid_cursor.set_grid_position(current_cursor_position)

	# Update terrain panel for cursor position
	_update_terrain_panel()

	# Update path preview
	_update_path_preview()


## Move free cursor (inspection mode - no restrictions)
func _move_free_cursor(offset: Vector2i) -> void:
	var new_pos: Vector2i = current_cursor_position + offset

	# Only check bounds, not walkability
	if not GridManager.is_within_bounds(new_pos):
		return

	# Update cursor position
	current_cursor_position = new_pos

	# Update cursor visual
	if grid_cursor:
		grid_cursor.set_grid_position(current_cursor_position)

	# Move camera to follow cursor in inspection mode
	if camera:
		camera.move_to_cell(current_cursor_position)

	# Update terrain panel for cursor position
	_update_terrain_panel()

	# Update unit inspector panel based on what's under cursor
	_update_unit_inspector()


## Move targeting cursor by offset (for attack/spell targeting)
func _move_targeting_cursor(offset: Vector2i) -> void:
	var new_pos: Vector2i = current_cursor_position + offset

	# Check if new position is within bounds
	if not GridManager.is_within_bounds(new_pos):
		return

	# Update cursor position (allow moving to any valid grid cell during targeting)
	current_cursor_position = new_pos

	# Update cursor visual
	if grid_cursor:
		grid_cursor.set_grid_position(current_cursor_position)

	# Update terrain panel for cursor position
	_update_terrain_panel()

	# Update combat forecast if there's a target under cursor
	_update_combat_forecast()


## Update path preview from unit to cursor
func _update_path_preview() -> void:
	# Clear old path
	_clear_path_preview()

	# Calculate new path
	if active_unit and current_cursor_position != active_unit.grid_position:
		var unit_class: ClassData = active_unit.get_current_class()
		var movement_type: int = unit_class.movement_type if unit_class else 0
		current_path = GridManager.find_path(
			active_unit.grid_position,
			current_cursor_position,
			movement_type,
			active_unit.faction
		)

		# Draw path
		if not current_path.is_empty():
			_draw_path_preview()


## Draw path preview visuals
func _draw_path_preview() -> void:
	if not path_preview_parent:
		push_warning("InputManager: No path_preview_parent set!")
		return

	for cell in current_path:
		# Create Node2D with ColorRect child for proper world positioning
		var path_node: Node2D = Node2D.new()
		path_node.position = GridManager.cell_to_world(cell)
		path_node.z_index = 5  # Above ground, below cursor

		var path_visual: ColorRect = ColorRect.new()
		path_visual.offset_left = -16.0
		path_visual.offset_top = -16.0
		path_visual.offset_right = 16.0
		path_visual.offset_bottom = 16.0
		path_visual.color = Color(0.3, 0.8, 1.0, 0.4)  # Light cyan, semi-transparent
		path_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE

		path_node.add_child(path_visual)
		path_preview_parent.add_child(path_node)
		path_visuals.append(path_node)


## Clear path preview visuals
func _clear_path_preview() -> void:
	for visual in path_visuals:
		if visual:
			var parent: Node = visual.get_parent()
			if parent:
				parent.remove_child(visual)
			visual.queue_free()
	path_visuals.clear()
	current_path.clear()


## Show action menu
func _show_action_menu() -> void:
	if not action_menu:
		push_warning("InputManager: No action menu reference set")
		return

	# Determine default action (context-aware highlighting)
	var default_action: String = ""
	if "Attack" in available_actions:
		default_action = "Attack"
	else:
		default_action = "Stay"

	# Position menu near active unit BEFORE showing (action_menu captures position at show time)
	if active_unit:
		# Convert unit's world position to screen position
		# The action menu is in a CanvasLayer (viewport coordinates)
		# but active_unit.position is in world coordinates
		var viewport: Viewport = active_unit.get_viewport()
		var unit_screen_pos: Vector2 = viewport.get_canvas_transform() * active_unit.position
		# Offset to right of unit
		action_menu.position = unit_screen_pos + Vector2(40, -20)

	# Show menu with available actions AND current session ID
	# The session ID will be returned with any signals to prevent stale signals
	action_menu.show_menu(available_actions, default_action, _turn_session_id)


## Handle action menu input
func _handle_action_menu_input(event: InputEvent) -> void:
	# Action menu handles its own input
	# We just wait for signals from the menu
	pass


## Show item menu
func _show_item_menu() -> void:
	if not item_menu:
		push_warning("InputManager: No item menu reference set - falling back to Stay action")
		# Fall back: emit stay action via signal (prevents freeze)
		action_selected.emit(active_unit, "stay")
		return

	if not active_unit:
		push_warning("InputManager: No active unit for item menu")
		set_state(InputState.SELECTING_ACTION)
		return

	# Show item menu with unit's inventory
	item_menu.show_menu(active_unit, _turn_session_id)

	# Position menu near active unit (similar to action menu)
	var viewport: Viewport = active_unit.get_viewport()
	var unit_screen_pos: Vector2 = viewport.get_canvas_transform() * active_unit.position
	# Offset to right of unit
	item_menu.position = unit_screen_pos + Vector2(40, -20)


## Select action from menu
func _select_action(action: String, signal_session_id: int) -> void:
	# Guard: Check if this signal is from a previous turn (stale)
	if signal_session_id != _turn_session_id:
		push_warning("InputManager: Ignoring STALE action selection '%s' from session %d (current session: %d)" % [
			action,
			signal_session_id,
			_turn_session_id
		])
		return

	# Guard: Only process actions when in correct state AND we have an active unit
	if current_state != InputState.SELECTING_ACTION or active_unit == null:
		push_warning("InputManager: Ignoring action selection '%s' in state %s (active_unit: %s)" % [
			action,
			InputState.keys()[current_state],
			"null" if active_unit == null else active_unit.get_display_name()
		])
		return

	# Additional safety: Only process if active unit is a player unit
	if not active_unit.is_player_unit():
		push_warning("InputManager: Ignoring action selection '%s' for non-player unit %s" % [action, active_unit.get_display_name()])
		return

	current_action = action

	# Convert to lowercase for BattleManager (internal representation)
	var action_lower: String = action.to_lower()

	# CRITICAL: Capture session ID BEFORE emitting signal
	# The signal handler may synchronously start the next turn, changing our session!
	var pre_emit_session: int = _turn_session_id

	action_selected.emit(active_unit, action_lower)

	# CRITICAL FIX: The signal handler runs synchronously and may have already:
	# 1. Started the next turn (session ID changed), OR
	# 2. Reset state to WAITING (e.g., for Stay action via BattleManager._execute_stay)
	#
	# If either happened, we must NOT continue - the action is already handled!
	if _turn_session_id != pre_emit_session:
		return

	# Check if state was reset by the signal handler (e.g., Stay action resets to WAITING)
	if current_state == InputState.WAITING:
		return

	match action:
		"Attack":
			set_state(InputState.TARGETING)
		"Magic":
			set_state(InputState.TARGETING)
		"Item":
			# Open item menu - transition to SELECTING_ITEM state
			set_state(InputState.SELECTING_ITEM)
		"Stay":
			# BattleManager._execute_stay() handles this synchronously and resets state
			# We should never reach here for Stay (caught by WAITING check above)
			push_warning("InputManager: Stay action reached match statement unexpectedly")
			_execute_action()


## Cancel action menu and return to previous state
func _cancel_action_menu() -> void:

	# SF2-STYLE: B button in menu returns to direct movement mode
	# If unit has moved from their starting position, return them to start
	if active_unit.grid_position != movement_start_cell:
		_cancel_direct_movement()

	# Return to DIRECT_MOVEMENT (SF2-style)
	set_state(InputState.DIRECT_MOVEMENT)


## Cancel all direct movement and return unit to start position (SF2-style)
func _cancel_direct_movement() -> void:
	if movement_path_taken.size() <= 1:
		return  # Already at start

	# Update grid occupation back to start
	var current_occupant: Node2D = GridManager.get_unit_at_cell(active_unit.grid_position)
	if current_occupant == active_unit:
		GridManager.clear_cell_occupied(active_unit.grid_position)

	# Set start cell as occupied (we're returning there)
	GridManager.set_cell_occupied(movement_start_cell, active_unit)
	active_unit.grid_position = movement_start_cell

	# Instant teleport back (SF2-authentic)
	active_unit.position = GridManager.cell_to_world(movement_start_cell)

	# Reset path tracking
	movement_path_taken = [movement_start_cell]


## Get valid target cells based on action and range
func _get_valid_target_cells(weapon_range: int) -> Array[Vector2i]:
	var valid_cells: Array[Vector2i] = []

	if current_action == "Attack":
		# Get all cells in weapon range
		var cells_in_range: Array[Vector2i] = GridManager.get_cells_in_range(
			active_unit.grid_position,
			weapon_range
		)

		# Filter to only cells with enemy units
		for cell in cells_in_range:
			var occupant: Node2D = GridManager.get_unit_at_cell(cell)
			if occupant and occupant.is_enemy_unit():
				valid_cells.append(cell)

	elif current_action == "Magic":
		# TODO: Implement spell targeting when spell system exists
		pass

	return valid_cells


## Show targeting range and valid targets
func _show_targeting_range() -> void:
	if not active_unit:
		return

	# Get weapon range (default to 1 for melee)
	# TODO: Get from equipped weapon when equipment system exists
	var weapon_range: int = 1

	# Show red attack range tiles
	GridManager.show_attack_range(active_unit.grid_position, weapon_range)

	# Find and highlight valid targets in yellow
	var valid_targets: Array[Vector2i] = _get_valid_target_cells(weapon_range)
	if not valid_targets.is_empty():
		GridManager.highlight_targets(valid_targets)


## Handle targeting input
func _handle_targeting_input(event: InputEvent) -> void:
	var handled: bool = false

	# Mouse click to select target
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse_world: Vector2 = active_unit.get_global_mouse_position()
			var target_cell: Vector2i = GridManager.world_to_cell(mouse_world)

			var target: Node2D = GridManager.get_unit_at_cell(target_cell)
			if target:
				_select_target(target)
			handled = true

	# Keyboard: Arrow keys to move targeting cursor
	if event.is_action_pressed("ui_up"):
		_move_targeting_cursor(Vector2i(0, -1))
		handled = true
	elif event.is_action_pressed("ui_down"):
		_move_targeting_cursor(Vector2i(0, 1))
		handled = true
	elif event.is_action_pressed("ui_left"):
		_move_targeting_cursor(Vector2i(-1, 0))
		handled = true
	elif event.is_action_pressed("ui_right"):
		_move_targeting_cursor(Vector2i(1, 0))
		handled = true

	# Accept key to confirm target selection
	if event.is_action_pressed("ui_accept"):
		var target: Node2D = GridManager.get_unit_at_cell(current_cursor_position)
		if target:
			_select_target(target)
		handled = true

	# Cancel targeting
	if event.is_action_pressed("sf_cancel"):
		set_state(InputState.SELECTING_ACTION)
		handled = true

	# Consume input to prevent duplicate processing by other handlers
	if handled:
		get_viewport().set_input_as_handled()


## Select target for action
func _select_target(target: Node2D) -> void:
	target_selected.emit(active_unit, target)
	_execute_action_on_target(target)


## Execute action on target
func _execute_action_on_target(target: Node2D) -> void:
	# NOTE: We do NOT execute actions here - just signal what was selected
	# BattleManager handles all action execution
	# The signal was already emitted in _select_target()

	# State transition is now handled by BattleManager
	# (it will call end_turn when action completes)
	set_state(InputState.EXECUTING)


## Execute action without target
func _execute_action() -> void:
	# NOTE: We do NOT execute actions here - just signal what was selected
	# BattleManager handles all action execution
	# The signal was already emitted in _select_action()

	# For Stay action, BattleManager will end turn immediately
	set_state(InputState.EXECUTING)


## Complete turn and notify TurnManager
func _complete_turn() -> void:
	# Mark unit as acted
	active_unit.mark_acted()

	# Save reference before clearing
	var unit: Node2D = active_unit

	# Clear state (this will set active_unit to null)
	set_state(InputState.WAITING)

	# End turn through TurnManager
	TurnManager.end_unit_turn(unit)


## Cleanup - called by BattleManager when action execution is complete
func end_player_turn() -> void:
	set_state(InputState.WAITING)


## Reset to waiting state (called by TurnManager/BattleManager)
func reset_to_waiting() -> void:
	# NUCLEAR OPTION: Reset menu state to clear any stale state
	if action_menu:
		action_menu.reset_menu()
	if item_menu:
		item_menu.reset_menu()

	# Disconnect menus to prevent stale signals
	_disconnect_action_menu_signals()
	_disconnect_item_menu_signals()

	# Hide stats panel
	if stats_panel:
		stats_panel.hide_stats()

	active_unit = null
	walkable_cells.clear()
	available_actions.clear()
	current_action = ""
	set_state(InputState.WAITING)


## Update stats panel based on cursor position during inspection
func _update_unit_inspector() -> void:
	if not stats_panel:
		return

	# Check what's under the cursor
	var unit_at_cursor: Node2D = GridManager.get_unit_at_cell(current_cursor_position)

	if unit_at_cursor:
		# Show stats for this unit (player or enemy)
		stats_panel.show_unit_stats(unit_at_cursor)
	else:
		# No unit under cursor, hide stats
		stats_panel.hide_stats()


## Update terrain panel based on cursor position
func _update_terrain_panel() -> void:
	if not terrain_panel:
		return

	if terrain_panel.has_method("show_terrain_info"):
		terrain_panel.show_terrain_info(current_cursor_position)


## Update combat forecast based on cursor position (during targeting)
func _update_combat_forecast() -> void:
	if not combat_forecast_panel:
		return

	# Only show forecast in targeting mode
	if current_state != InputState.TARGETING:
		if combat_forecast_panel.has_method("hide_forecast"):
			combat_forecast_panel.hide_forecast()
		return

	# Check for enemy under cursor
	var target: Node2D = GridManager.get_unit_at_cell(current_cursor_position)

	if target and target.is_alive() and active_unit:
		# Show forecast for this target
		if combat_forecast_panel.has_method("show_forecast"):
			combat_forecast_panel.show_forecast(active_unit, target)
	else:
		# No valid target, hide forecast
		if combat_forecast_panel.has_method("hide_forecast"):
			combat_forecast_panel.hide_forecast()


# =============================================================================
# SF2-STYLE DIRECT MOVEMENT SYSTEM
# =============================================================================

## Update movement range display (shows walkable_cells calculated at turn start)
func _update_direct_movement_range() -> void:
	GridManager.clear_highlights()

	# Highlight all walkable cells in blue
	GridManager.highlight_cells(walkable_cells, GridManager.HIGHLIGHT_BLUE)

	# Highlight current position in green (unit's position is distinct)
	GridManager.highlight_cells([active_unit.grid_position], GridManager.HIGHLIGHT_GREEN)


## Try to step the unit one tile in a direction (SF2-style direct control)
## Returns true if step was executed, false if blocked
func _try_direct_step(direction: Vector2i) -> bool:
	if is_direct_moving:
		return false  # Block input during animation

	if not active_unit:
		return false

	var target_cell: Vector2i = active_unit.grid_position + direction

	# Bounds check
	if not GridManager.is_within_bounds(target_cell):
		return false

	# Check if walking back on our path (always allowed)
	if movement_path_taken.size() > 1:
		var previous_cell: Vector2i = movement_path_taken[-2]
		if target_cell == previous_cell:
			_undo_last_step()
			return true

	# Check what's at the target cell
	var occupant: Node2D = GridManager.get_unit_at_cell(target_cell)

	# Block if enemy occupies the cell
	if occupant and occupant.faction != active_unit.faction:
		return false

	# Allow if: in walkable_cells, OR on our path, OR ally is there (pass-through)
	var is_walkable: bool = target_cell in walkable_cells
	var is_on_path: bool = target_cell in movement_path_taken
	var is_ally_cell: bool = occupant != null and occupant.faction == active_unit.faction

	if not is_walkable and not is_on_path and not is_ally_cell:
		return false

	# Execute the step
	_execute_direct_step(target_cell)
	return true


## Execute a single step to target cell with animation
func _execute_direct_step(target_cell: Vector2i) -> void:
	is_direct_moving = true

	# Update path taken
	movement_path_taken.append(target_cell)

	# Update grid occupation (handle ally pass-through)
	var old_pos: Vector2i = active_unit.grid_position
	var target_occupant: Node2D = GridManager.get_unit_at_cell(target_cell)

	# Clear old position unless an ally is there (we were passing through)
	var old_occupant: Node2D = GridManager.get_unit_at_cell(old_pos)
	if old_occupant == active_unit:
		GridManager.clear_cell_occupied(old_pos)

	# Set new position as occupied unless an ally is there (passing through)
	if not target_occupant:
		GridManager.set_cell_occupied(target_cell, active_unit)

	active_unit.grid_position = target_cell

	# Quick tween to new position (SF2-style: nearly instant)
	var target_world: Vector2 = GridManager.cell_to_world(target_cell)
	var step_tween: Tween = create_tween()
	step_tween.tween_property(active_unit, "position", target_world, 0.1)
	step_tween.set_trans(Tween.TRANS_LINEAR)

	# Play step sound (walk sound, no overlap to prevent stacking)
	AudioManager.play_sfx_no_overlap("walk", AudioManager.SFXCategory.MOVEMENT)

	await step_tween.finished

	# Guard: Validate state after async operation
	if not is_instance_valid(active_unit) or current_state != InputState.DIRECT_MOVEMENT:
		is_direct_moving = false
		return

	is_direct_moving = false

	# Update visual feedback (remaining movement display)
	_update_direct_movement_range()

	# Update camera to follow unit
	if camera and camera is CameraController:
		(camera as CameraController).move_to_cell(target_cell)


## Undo the last step (walking backward)
func _undo_last_step() -> void:
	if movement_path_taken.size() <= 1:
		return  # Can't undo - at start

	is_direct_moving = true

	# Remove current cell from path
	movement_path_taken.pop_back()
	var previous_cell: Vector2i = movement_path_taken[-1]

	# Update grid occupation
	var current_occupant: Node2D = GridManager.get_unit_at_cell(active_unit.grid_position)
	if current_occupant == active_unit:
		GridManager.clear_cell_occupied(active_unit.grid_position)

	var prev_occupant: Node2D = GridManager.get_unit_at_cell(previous_cell)
	if not prev_occupant:
		GridManager.set_cell_occupied(previous_cell, active_unit)

	active_unit.grid_position = previous_cell

	# Animate back
	var target_world: Vector2 = GridManager.cell_to_world(previous_cell)
	var step_tween: Tween = create_tween()
	step_tween.tween_property(active_unit, "position", target_world, 0.1)
	step_tween.set_trans(Tween.TRANS_LINEAR)

	# Play step sound (walk sound, same as forward movement)
	AudioManager.play_sfx_no_overlap("walk", AudioManager.SFXCategory.MOVEMENT)

	await step_tween.finished

	# Guard: Validate state after async operation
	if not is_instance_valid(active_unit) or current_state != InputState.DIRECT_MOVEMENT:
		is_direct_moving = false
		return

	is_direct_moving = false

	# Update visual feedback
	_update_direct_movement_range()

	# Update camera to follow unit
	if camera and camera is CameraController:
		(camera as CameraController).move_to_cell(previous_cell)


## Handle direct movement input (SF2-style)
func _handle_direct_movement_input(event: InputEvent) -> void:
	var handled: bool = false

	# Block all input during step animation
	if is_direct_moving:
		if event is InputEventKey or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return

	# Arrow keys directly move the unit
	if event.is_action_pressed("ui_up"):
		_try_direct_step(Vector2i(0, -1))
		_input_delay = INPUT_DELAY_INITIAL
		handled = true
	elif event.is_action_pressed("ui_down"):
		_try_direct_step(Vector2i(0, 1))
		_input_delay = INPUT_DELAY_INITIAL
		handled = true
	elif event.is_action_pressed("ui_left"):
		_try_direct_step(Vector2i(-1, 0))
		_input_delay = INPUT_DELAY_INITIAL
		handled = true
	elif event.is_action_pressed("ui_right"):
		_try_direct_step(Vector2i(1, 0))
		_input_delay = INPUT_DELAY_INITIAL
		handled = true

	# Accept key - Confirm position and open action menu
	if event.is_action_pressed("ui_accept"):
		# Check if we can confirm at this position (not on ally)
		if _can_confirm_direct_position():
			set_state(InputState.SELECTING_ACTION)
		handled = true

	# Cancel key - SF2-style B button behavior
	if event.is_action_pressed("sf_cancel"):
		if active_unit.grid_position != movement_start_cell:
			# Unit has moved - cancel all movement and return to start
			_cancel_direct_movement()
			_update_direct_movement_range()
			# Stay in DIRECT_MOVEMENT to try again
		else:
			# Already at start - enter inspection mode
			current_cursor_position = active_unit.grid_position
			set_state(InputState.INSPECTING)
		handled = true

	if handled:
		get_viewport().set_input_as_handled()


## Check if unit can confirm its current position (not standing on an ally)
func _can_confirm_direct_position() -> bool:
	var occupant: Node2D = GridManager.get_unit_at_cell(active_unit.grid_position)
	if occupant and occupant != active_unit:
		# Standing on another unit (ally pass-through) - can't confirm here
		AudioManager.play_sfx("movement_blocked", AudioManager.SFXCategory.UI)
		return false
	return true


# =============================================================================
# ITEM TARGET SELECTION SYSTEM
# =============================================================================

## Handle input during item target selection
func _handle_item_target_input(event: InputEvent) -> void:
	var handled: bool = false

	# Mouse click to select target
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse_world: Vector2 = active_unit.get_global_mouse_position()
			var target_cell: Vector2i = GridManager.world_to_cell(mouse_world)

			var target: Node2D = GridManager.get_unit_at_cell(target_cell)
			if target and _is_valid_item_target(target):
				_confirm_item_target(target)
			handled = true

	# Keyboard: Arrow keys to move targeting cursor
	if event.is_action_pressed("ui_up"):
		_move_item_target_cursor(Vector2i(0, -1))
		handled = true
	elif event.is_action_pressed("ui_down"):
		_move_item_target_cursor(Vector2i(0, 1))
		handled = true
	elif event.is_action_pressed("ui_left"):
		_move_item_target_cursor(Vector2i(-1, 0))
		handled = true
	elif event.is_action_pressed("ui_right"):
		_move_item_target_cursor(Vector2i(1, 0))
		handled = true

	# Accept key to confirm target selection
	if event.is_action_pressed("ui_accept"):
		var target: Node2D = GridManager.get_unit_at_cell(current_cursor_position)
		if target and _is_valid_item_target(target):
			_confirm_item_target(target)
		else:
			# Invalid target - play error sound but stay in targeting
			AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		handled = true

	# Cancel returns to action menu (SF-authentic: don't end turn)
	if event.is_action_pressed("sf_cancel"):
		AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)
		selected_item_id = ""
		selected_item_data = null
		_item_valid_targets.clear()
		set_state(InputState.SELECTING_ACTION)
		handled = true

	# Consume input to prevent duplicate processing by other handlers
	if handled:
		get_viewport().set_input_as_handled()


## Get valid target cells for the selected item
func _get_valid_item_target_cells() -> Array[Vector2i]:
	var valid_cells: Array[Vector2i] = []

	if not selected_item_data or not selected_item_data.effect:
		# No effect - only self is valid
		valid_cells.append(active_unit.grid_position)
		return valid_cells

	var effect: AbilityData = selected_item_data.effect as AbilityData
	if not effect:
		valid_cells.append(active_unit.grid_position)
		return valid_cells

	# Get cells in range based on ability
	var cells_in_range: Array[Vector2i] = GridManager.get_cells_in_range(
		active_unit.grid_position,
		effect.max_range
	)

	# Also include self if min_range is 0
	if effect.min_range == 0:
		if active_unit.grid_position not in cells_in_range:
			cells_in_range.append(active_unit.grid_position)

	# Filter based on target type
	match effect.target_type:
		AbilityData.TargetType.SELF:
			valid_cells.append(active_unit.grid_position)

		AbilityData.TargetType.SINGLE_ALLY:
			# Include self and all allies (same faction) in range
			for cell in cells_in_range:
				var unit: Node2D = GridManager.get_unit_at_cell(cell)
				if unit and unit.faction == active_unit.faction and unit.is_alive():
					valid_cells.append(cell)
			# Always include self for healing items
			if active_unit.grid_position not in valid_cells:
				valid_cells.append(active_unit.grid_position)

		AbilityData.TargetType.SINGLE_ENEMY:
			# Only enemies in range
			for cell in cells_in_range:
				var unit: Node2D = GridManager.get_unit_at_cell(cell)
				if unit and unit.faction != active_unit.faction and unit.is_alive():
					valid_cells.append(cell)

		AbilityData.TargetType.ALL_ALLIES, AbilityData.TargetType.ALL_ENEMIES:
			# No target selection needed - handled elsewhere
			valid_cells.append(active_unit.grid_position)

		AbilityData.TargetType.AREA:
			# All cells in range
			valid_cells = cells_in_range

	return valid_cells


## Check if a unit is a valid target for the selected item
func _is_valid_item_target(unit: Node2D) -> bool:
	if not unit or not unit.is_alive():
		return false

	if not selected_item_data or not selected_item_data.effect:
		# No effect - only self is valid
		return unit == active_unit

	var effect: AbilityData = selected_item_data.effect as AbilityData
	if not effect:
		return unit == active_unit

	# Check range
	var distance: int = GridManager.get_distance(active_unit.grid_position, unit.grid_position)
	if distance < effect.min_range or distance > effect.max_range:
		return false

	# Check target type
	match effect.target_type:
		AbilityData.TargetType.SELF:
			return unit == active_unit
		AbilityData.TargetType.SINGLE_ALLY:
			return unit.faction == active_unit.faction
		AbilityData.TargetType.SINGLE_ENEMY:
			return unit.faction != active_unit.faction
		_:
			return true


## Show item targeting range highlights
func _show_item_targeting_range(valid_targets: Array[Vector2i]) -> void:
	# Use green for ally-targeting items (like healing)
	# Use red for enemy-targeting items
	# Use yellow for area/special items
	var effect: AbilityData = selected_item_data.effect as AbilityData if selected_item_data else null

	var color_type: int = GridManager.HIGHLIGHT_GREEN  # Default green for allies

	if effect:
		match effect.target_type:
			AbilityData.TargetType.SINGLE_ENEMY:
				color_type = GridManager.HIGHLIGHT_RED
			AbilityData.TargetType.SELF:
				color_type = GridManager.HIGHLIGHT_GREEN
			AbilityData.TargetType.AREA:
				color_type = GridManager.HIGHLIGHT_YELLOW

	GridManager.highlight_cells(valid_targets, color_type)


## Move item target cursor (snap-to-target navigation for better UX)
func _move_item_target_cursor(offset: Vector2i) -> void:
	# SF-authentic: Snap between valid targets instead of cell-by-cell movement
	if _item_valid_targets.is_empty():
		return

	# Find current target index
	var current_idx: int = _item_valid_targets.find(current_cursor_position)

	if current_idx == -1:
		# Not on a valid target - snap to first one
		current_cursor_position = _item_valid_targets[0]
	else:
		# Snap to next/previous valid target based on direction
		# Up or Left = previous, Down or Right = next
		if offset.y < 0 or offset.x < 0:
			current_idx = wrapi(current_idx - 1, 0, _item_valid_targets.size())
		else:
			current_idx = wrapi(current_idx + 1, 0, _item_valid_targets.size())

		current_cursor_position = _item_valid_targets[current_idx]

	# Play cursor movement sound
	AudioManager.play_sfx("cursor_move", AudioManager.SFXCategory.UI)

	# Update cursor visual
	if grid_cursor:
		grid_cursor.set_grid_position(current_cursor_position)

	# Update target info panel
	_update_item_target_info()


## Update stats panel to show target info during item targeting
func _update_item_target_info() -> void:
	if not stats_panel:
		return

	# Check what's under the cursor
	var unit_at_cursor: Node2D = GridManager.get_unit_at_cell(current_cursor_position)

	if unit_at_cursor and unit_at_cursor.is_alive():
		# Show stats for potential target
		stats_panel.show_unit_stats(unit_at_cursor)
	else:
		# No valid target, show active unit stats
		if active_unit:
			stats_panel.show_unit_stats(active_unit)


## Confirm item target and use item
func _confirm_item_target(target: Node2D) -> void:
	# Play confirm sound
	AudioManager.play_sfx("menu_select", AudioManager.SFXCategory.UI)

	# Use the item on the target
	_use_item_on_target(target)
