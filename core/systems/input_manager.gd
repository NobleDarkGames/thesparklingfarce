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
	EXPLORING_MOVEMENT,  # Freely exploring movement options (can cancel)
	SELECTING_ACTION,    # Action menu open (Attack/Magic/Item/Stay)
	TARGETING,           # Selecting target for attack/spell
	EXECUTING,           # Action executing (animations, etc.)
}

## Signals
signal movement_confirmed(unit: Node2D, destination: Vector2i)
signal action_selected(unit: Node2D, action: String)
signal target_selected(unit: Node2D, target: Node2D)
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

## References (set by battle scene or autoload setup)
var camera: Camera2D = null
var action_menu: Control = null  # Will be set by battle scene
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
const INPUT_DELAY_INITIAL: float = 0.3  # Delay before repeat starts
const INPUT_DELAY_REPEAT: float = 0.1   # Delay between repeats


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
	print("InputManager: _on_action_menu_selected() received signal for action='%s', signal_session=%d, current_session=%d, state=%s" % [
		action,
		signal_session_id,
		_turn_session_id,
		InputState.keys()[current_state]
	])

	# Play menu selection sound
	AudioManager.play_sfx("menu_select", AudioManager.SFXCategory.UI)

	# Use the session ID that was passed WITH the signal (captured at emission time)
	_select_action(action, signal_session_id)


## Handle action menu cancellation signal
## signal_session_id: The session ID captured when menu was shown (not when signal arrives)
func _on_action_menu_cancelled(signal_session_id: int) -> void:
	print("InputManager: _on_action_menu_cancelled() signal_session=%d, current_session=%d" % [
		signal_session_id,
		_turn_session_id
	])

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
	print("InputManager: start_player_turn() called for %s" % (unit.get_display_name() if unit else "null"))

	if not unit:
		push_error("InputManager: Cannot start turn with null unit")
		return

	# Increment turn session ID to invalidate any queued signals from previous turns
	_turn_session_id += 1
	print("InputManager: New turn session ID: %d" % _turn_session_id)

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
	if unit.character_data and unit.character_data.character_class:
		movement_range = unit.character_data.character_class.movement_range
		movement_type = unit.character_data.character_class.movement_type
	else:
		push_warning("InputManager: Unit %s has no character_class, using default movement (range=%d)" % [unit.get_display_name(), movement_range])

	walkable_cells = GridManager.get_walkable_cells(
		movement_start_position,
		movement_range,
		movement_type,
		unit.faction
	)

	# AUTHENTIC SHINING FORCE: Start in movement mode immediately (cursor on unit)
	# Player can: Move with D-pad, Press A/C to act in place, Press B to inspect
	set_state(InputState.EXPLORING_MOVEMENT)

	# NOW reconnect signals after state is correct (eliminates timing window)
	_reconnect_action_menu_signals()

	print("InputManager: Player turn started for %s at %s" % [unit.get_display_name(), movement_start_position])
	print("InputManager: %d walkable cells available" % walkable_cells.size())
	print("InputManager: Arrow keys = Move, Enter/Space/Z = Action menu, Backspace/X = Free cursor inspect")


## Change input state
func set_state(new_state: InputState) -> void:
	var old_state: InputState = current_state
	current_state = new_state

	# Debug: Print stack trace when transitioning to WAITING unexpectedly
	if new_state == InputState.WAITING and old_state == InputState.EXPLORING_MOVEMENT:
		print("InputManager: WARNING - Unexpected transition from EXPLORING_MOVEMENT to WAITING!")
		print("Stack trace:")
		print_stack()

	match new_state:
		InputState.WAITING:
			_on_enter_waiting()
		InputState.INSPECTING:
			_on_enter_inspecting()
		InputState.EXPLORING_MOVEMENT:
			_on_enter_exploring_movement()
		InputState.SELECTING_ACTION:
			_on_enter_selecting_action()
		InputState.TARGETING:
			_on_enter_targeting()
		InputState.EXECUTING:
			_on_enter_executing()

	print("InputManager: State changed from %s to %s" % [
		InputState.keys()[old_state],
		InputState.keys()[new_state]
	])


## State enter handlers
func _on_enter_waiting() -> void:
	active_unit = null
	walkable_cells.clear()
	available_actions.clear()


func _on_enter_inspecting() -> void:
	# Free cursor mode - can inspect any unit on battlefield
	# Clear movement highlights (we're not moving anymore)
	GridManager.clear_highlights()

	# Clear path preview
	_clear_path_preview()

	# Cursor is free to roam anywhere
	if grid_cursor:
		grid_cursor.show_cursor()

	# Update inspector for unit at current cursor position (if any)
	_update_unit_inspector()

	print("InputManager: Entering INSPECTING mode - cursor free to roam")


func _on_enter_exploring_movement() -> void:
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


func _on_enter_selecting_action() -> void:
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


func _on_enter_targeting() -> void:
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
	if current_state != InputState.EXPLORING_MOVEMENT and current_state != InputState.INSPECTING:
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
			# Move cursor
			if current_state == InputState.EXPLORING_MOVEMENT:
				_move_cursor(direction)
			elif current_state == InputState.INSPECTING:
				_move_free_cursor(direction)

			# Set repeat delay (faster after initial delay)
			_input_delay = INPUT_DELAY_REPEAT
	else:
		# No direction held, reset delay to 0 (next press will be immediate via _input)
		_input_delay = 0.0


## Process input based on current state
func _input(event: InputEvent) -> void:
	# Debug: Show that we're receiving input
	if event is InputEventMouseButton or event is InputEventKey:
		if event.pressed:
			print("InputManager: Received input in state %s" % InputState.keys()[current_state])

	match current_state:
		InputState.INSPECTING:
			_handle_inspecting_input(event)
		InputState.EXPLORING_MOVEMENT:
			_handle_movement_input(event)
		InputState.SELECTING_ACTION:
			_handle_action_menu_input(event)
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
			# Pressed A on our own unit - return to movement mode
			print("InputManager: Returning to movement mode")
			current_cursor_position = active_unit.grid_position
			set_state(InputState.EXPLORING_MOVEMENT)
		elif unit_at_cursor:
			# Pressed A on another unit - show stats (TODO: implement stats panel)
			print("InputManager: Inspecting unit: %s" % unit_at_cursor.get_display_name())
			# TODO: Show unit stats panel
		else:
			# Pressed A on empty cell - could open game menu (Map, Speed, etc.)
			print("InputManager: Empty cell - could open game menu here")
			# TODO: Implement game menu (Map, Speed settings, etc.)
		handled = true

	# Cancel returns to movement mode
	if event.is_action_pressed("sf_cancel"):
		print("InputManager: Exiting inspect mode, returning to movement")
		current_cursor_position = active_unit.grid_position
		set_state(InputState.EXPLORING_MOVEMENT)
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

			print("InputManager: Mouse click at world %s" % mouse_world)

			var target_cell: Vector2i = GridManager.world_to_cell(mouse_world)
			print("InputManager: Target cell: %s" % target_cell)
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
			print("InputManager: Opening action menu without moving")
			set_state(InputState.SELECTING_ACTION)
		else:
			# Cursor has moved - move unit and open action menu
			_try_move_to_cell(current_cursor_position)
		handled = true

	# Cancel key - Enter free cursor inspection mode (B button in SF)
	if event.is_action_pressed("sf_cancel"):
		print("InputManager: [BACKSPACE/X PRESSED] Entering inspection mode (free cursor)")
		set_state(InputState.INSPECTING)
		handled = true

	# Consume input to prevent duplicate processing by other handlers
	if handled:
		get_viewport().set_input_as_handled()


## Try to move unit to target cell
func _try_move_to_cell(target_cell: Vector2i) -> void:
	if not GridManager.is_within_bounds(target_cell):
		print("InputManager: Cell %s out of bounds" % target_cell)
		return

	if target_cell not in walkable_cells:
		print("InputManager: Cell %s not walkable" % target_cell)
		return

	# Move unit to target cell
	print("InputManager: Moving unit to %s" % target_cell)

	if target_cell != active_unit.grid_position:
		# Calculate the full path from current position to target
		var movement_type: int = active_unit.character_data.character_class.movement_type
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
	print("InputManager: Canceling movement, returning to %s" % movement_start_position)

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

	print("InputManager: Available actions: ", actions)
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
	var movement_range: int = active_unit.character_data.character_class.movement_range
	var movement_type: int = active_unit.character_data.character_class.movement_type

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
		print("InputManager: Cursor cannot move to %s (not walkable)" % new_pos)
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

	print("InputManager: Cursor moved to %s" % current_cursor_position)


## Move free cursor (inspection mode - no restrictions)
func _move_free_cursor(offset: Vector2i) -> void:
	var new_pos: Vector2i = current_cursor_position + offset

	# Only check bounds, not walkability
	if not GridManager.is_within_bounds(new_pos):
		print("InputManager: Free cursor cannot move to %s (out of bounds)" % new_pos)
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

	print("InputManager: Free cursor moved to %s" % current_cursor_position)


## Move targeting cursor by offset (for attack/spell targeting)
func _move_targeting_cursor(offset: Vector2i) -> void:
	var new_pos: Vector2i = current_cursor_position + offset

	# Check if new position is within bounds
	if not GridManager.is_within_bounds(new_pos):
		print("InputManager: Targeting cursor cannot move to %s (out of bounds)" % new_pos)
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

	print("InputManager: Targeting cursor moved to %s" % current_cursor_position)


## Update path preview from unit to cursor
func _update_path_preview() -> void:
	# Clear old path
	_clear_path_preview()

	# Calculate new path
	if active_unit and current_cursor_position != active_unit.grid_position:
		current_path = GridManager.find_path(
			active_unit.grid_position,
			current_cursor_position,
			active_unit.character_data.character_class.movement_type,
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

	# Show menu with available actions AND current session ID
	# The session ID will be returned with any signals to prevent stale signals
	action_menu.show_menu(available_actions, default_action, _turn_session_id)

	# Position menu near active unit
	if active_unit:
		# Convert unit's world position to screen position
		# The action menu is in a CanvasLayer (viewport coordinates)
		# but active_unit.position is in world coordinates
		var viewport: Viewport = active_unit.get_viewport()
		var unit_screen_pos: Vector2 = viewport.get_canvas_transform() * active_unit.position
		# Offset to right of unit
		action_menu.position = unit_screen_pos + Vector2(40, -20)


## Handle action menu input
func _handle_action_menu_input(event: InputEvent) -> void:
	# Action menu handles its own input
	# We just wait for signals from the menu
	pass


## Select action from menu
func _select_action(action: String, signal_session_id: int) -> void:
	print("InputManager: _select_action called with action='%s', state=%s, active_unit=%s, signal_session=%d, current_session=%d" % [
		action,
		InputState.keys()[current_state],
		"null" if active_unit == null else active_unit.get_display_name(),
		signal_session_id,
		_turn_session_id
	])

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
		print("InputManager: Session changed during signal handling (%d -> %d), aborting _select_action continuation" % [
			pre_emit_session, _turn_session_id
		])
		return

	# Check if state was reset by the signal handler (e.g., Stay action resets to WAITING)
	if current_state == InputState.WAITING:
		print("InputManager: State reset to WAITING by signal handler, action '%s' already handled" % action)
		return

	print("InputManager: Action selected: %s" % action)

	match action:
		"Attack":
			set_state(InputState.TARGETING)
		"Magic":
			set_state(InputState.TARGETING)
		"Item":
			# TODO: Open item menu
			_execute_action()
		"Stay":
			# BattleManager._execute_stay() handles this synchronously and resets state
			# We should never reach here for Stay (caught by WAITING check above)
			push_warning("InputManager: Stay action reached match statement unexpectedly")
			_execute_action()


## Cancel action menu and return to previous state
func _cancel_action_menu() -> void:
	print("InputManager: Canceling action menu")

	# AUTHENTIC SHINING FORCE: B button in menu returns to movement mode
	# If unit has moved, cancel movement and return to start
	if active_unit.grid_position != movement_start_position:
		_cancel_movement()

	# Always return to EXPLORING_MOVEMENT (not WAITING_FOR_COMMAND)
	set_state(InputState.EXPLORING_MOVEMENT)


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

	print("InputManager: Showing targeting range for %s" % current_action)

	# Get weapon range (default to 1 for melee)
	# TODO: Get from equipped weapon when equipment system exists
	var weapon_range: int = 1

	print("InputManager: Unit position: %s, weapon range: %d" % [active_unit.grid_position, weapon_range])

	# Show red attack range tiles
	GridManager.show_attack_range(active_unit.grid_position, weapon_range)

	# Find and highlight valid targets in yellow
	var valid_targets: Array[Vector2i] = _get_valid_target_cells(weapon_range)
	print("InputManager: Valid targets found: %d at cells: %s" % [valid_targets.size(), valid_targets])
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
	print("InputManager: Target selected: %s" % target.get_display_name())
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
	print("InputManager: Turn complete for %s" % active_unit.get_display_name())

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

	# Disconnect action menu to prevent stale signals
	_disconnect_action_menu_signals()

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
