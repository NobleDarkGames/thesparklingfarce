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
	WAITING,           # Not player's turn
	EXPLORING_MOVEMENT, # Freely exploring movement options (can cancel)
	SELECTING_ACTION,  # Action menu open (Attack/Magic/Item/Stay)
	TARGETING,         # Selecting target for attack/spell
	EXECUTING,         # Action executing (animations, etc.)
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

## Path preview
var current_path: Array[Vector2i] = []
var path_visuals: Array[Node2D] = []


## Set action menu reference and connect signals
func set_action_menu(menu: Control) -> void:
	action_menu = menu

	# Connect signals (we'll manage connection lifecycle per turn)
	if not action_menu.action_selected.is_connected(_on_action_menu_selected):
		action_menu.action_selected.connect(_on_action_menu_selected)
	if not action_menu.menu_cancelled.is_connected(_on_action_menu_cancelled):
		action_menu.menu_cancelled.connect(_on_action_menu_cancelled)


## Disconnect action menu signals (called when turn ends)
func _disconnect_action_menu_signals() -> void:
	if action_menu:
		if action_menu.action_selected.is_connected(_on_action_menu_selected):
			action_menu.action_selected.disconnect(_on_action_menu_selected)
		if action_menu.menu_cancelled.is_connected(_on_action_menu_cancelled):
			action_menu.menu_cancelled.disconnect(_on_action_menu_cancelled)


## Reconnect action menu signals (called when player turn starts)
func _reconnect_action_menu_signals() -> void:
	if action_menu:
		if not action_menu.action_selected.is_connected(_on_action_menu_selected):
			action_menu.action_selected.connect(_on_action_menu_selected)
		if not action_menu.menu_cancelled.is_connected(_on_action_menu_cancelled):
			action_menu.menu_cancelled.connect(_on_action_menu_cancelled)


## Handle action menu selection signal
func _on_action_menu_selected(action: String) -> void:
	# Capture current session ID at the time of signal emission
	var signal_session_id: int = _turn_session_id
	_select_action(action, signal_session_id)


## Handle action menu cancellation signal
func _on_action_menu_cancelled() -> void:
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

	# IMPORTANT: Disconnect first to clear any queued signals, THEN reconnect fresh
	# No await needed - disconnecting immediately clears the signal queue
	_disconnect_action_menu_signals()
	_reconnect_action_menu_signals()

	active_unit = unit
	movement_start_position = unit.grid_position
	current_cursor_position = unit.grid_position

	# Calculate walkable cells
	if unit.character_data and unit.character_data.character_class:
		var movement_range: int = unit.character_data.character_class.movement_range
		var movement_type: int = unit.character_data.character_class.movement_type
		walkable_cells = GridManager.get_walkable_cells(
			movement_start_position,
			movement_range,
			movement_type
		)
	else:
		walkable_cells = []

	# Start in movement exploration mode
	set_state(InputState.EXPLORING_MOVEMENT)

	print("InputManager: Player turn started for %s at %s" % [unit.get_display_name(), movement_start_position])
	print("InputManager: %d walkable cells" % walkable_cells.size())
	print("InputManager: Ready to receive input - click or use arrow keys to move")


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


func _on_enter_exploring_movement() -> void:
	# Show movement range highlights
	if not walkable_cells.is_empty():
		_show_movement_range()

	# Position cursor on unit
	current_cursor_position = active_unit.grid_position

	# Show cursor at unit position
	if grid_cursor:
		grid_cursor.set_grid_position(current_cursor_position)
		grid_cursor.show_cursor()

	# Clear any existing path
	_clear_path_preview()


func _on_enter_selecting_action() -> void:
	# Hide cursor and path (movement is locked in)
	if grid_cursor:
		grid_cursor.hide_cursor()
	_clear_path_preview()

	# Calculate available actions based on context
	_calculate_available_actions()

	# Show action menu
	_show_action_menu()


func _on_enter_targeting() -> void:
	# Show valid targets based on selected action
	_show_targeting_range()


func _on_enter_executing() -> void:
	# Action is executing, wait for completion
	pass


## Process input based on current state
func _input(event: InputEvent) -> void:
	# Debug: Show that we're receiving input
	if event is InputEventMouseButton or event is InputEventKey:
		if event.pressed:
			print("InputManager: Received input in state %s" % InputState.keys()[current_state])

	match current_state:
		InputState.EXPLORING_MOVEMENT:
			_handle_movement_input(event)
		InputState.SELECTING_ACTION:
			_handle_action_menu_input(event)
		InputState.TARGETING:
			_handle_targeting_input(event)


## Handle movement exploration input
func _handle_movement_input(event: InputEvent) -> void:
	# Mouse click to select destination
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Get global mouse position (works with camera)
			var mouse_world: Vector2 = active_unit.get_global_mouse_position()

			print("InputManager: Mouse click at world %s" % mouse_world)

			var target_cell: Vector2i = GridManager.world_to_cell(mouse_world)
			print("InputManager: Target cell: %s" % target_cell)
			_try_move_to_cell(target_cell)

	# Keyboard: Arrow keys to move cursor
	if event.is_action_pressed("ui_up"):
		_move_cursor(Vector2i(0, -1))
	elif event.is_action_pressed("ui_down"):
		_move_cursor(Vector2i(0, 1))
	elif event.is_action_pressed("ui_left"):
		_move_cursor(Vector2i(-1, 0))
	elif event.is_action_pressed("ui_right"):
		_move_cursor(Vector2i(1, 0))

	# Accept key to confirm movement
	if event.is_action_pressed("ui_accept"):
		_try_move_to_cell(current_cursor_position)

	# Cancel key to return to starting position
	if event.is_action_pressed("ui_cancel"):
		_cancel_movement()


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
func _calculate_available_actions() -> void:
	available_actions.clear()

	# Attack - only if enemies in range
	var enemies_in_range: bool = _check_enemies_in_range()
	if enemies_in_range:
		available_actions.append("Attack")

	# Magic - only if unit has spells
	if active_unit.character_data and _has_spells():
		available_actions.append("Magic")

	# Item - always available
	available_actions.append("Item")

	# Stay - always available
	available_actions.append("Stay")

	print("InputManager: Available actions: ", available_actions)


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


## Show movement range highlights (placeholder)
func _show_movement_range() -> void:
	# TODO: Implement visual highlight system
	# For now, this is handled by test scene
	pass


## Move cursor by offset and update visuals
func _move_cursor(offset: Vector2i) -> void:
	var new_pos: Vector2i = current_cursor_position + offset

	# Clamp to walkable cells only
	if new_pos not in walkable_cells:
		print("InputManager: Cursor cannot move to %s (not walkable)" % new_pos)
		return

	# Update cursor position
	current_cursor_position = new_pos

	# Update cursor visual
	if grid_cursor:
		grid_cursor.set_grid_position(current_cursor_position)

	# Update path preview
	_update_path_preview()

	print("InputManager: Cursor moved to %s" % current_cursor_position)


## Update path preview from unit to cursor
func _update_path_preview() -> void:
	# Clear old path
	_clear_path_preview()

	# Calculate new path
	if active_unit and current_cursor_position != active_unit.grid_position:
		current_path = GridManager.find_path(
			active_unit.grid_position,
			current_cursor_position,
			active_unit.character_data.character_class.movement_type
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
		path_visual.color = Color(1.0, 1.0, 0.3, 0.5)  # Yellow, semi-transparent
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

	# Show menu with available actions
	action_menu.show_menu(available_actions, default_action)

	# Position menu near active unit
	if active_unit:
		var unit_screen_pos: Vector2 = active_unit.position
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
	action_selected.emit(active_unit, action_lower)

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
			_execute_action()


## Cancel action menu and return to movement
func _cancel_action_menu() -> void:
	print("InputManager: Canceling action menu, returning to movement")
	_cancel_movement()
	set_state(InputState.EXPLORING_MOVEMENT)


## Show targeting range (placeholder)
func _show_targeting_range() -> void:
	# TODO: Implement targeting visual
	print("InputManager: Showing targeting range for %s" % current_action)


## Handle targeting input (placeholder)
func _handle_targeting_input(event: InputEvent) -> void:
	# Mouse click to select target
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse_world: Vector2 = active_unit.get_global_mouse_position()
			var target_cell: Vector2i = GridManager.world_to_cell(mouse_world)

			var target: Node2D = GridManager.get_unit_at_cell(target_cell)
			if target:
				_select_target(target)

	# Cancel targeting
	if event.is_action_pressed("ui_cancel"):
		set_state(InputState.SELECTING_ACTION)


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
	# Disconnect action menu to prevent stale signals
	_disconnect_action_menu_signals()

	active_unit = null
	walkable_cells.clear()
	available_actions.clear()
	current_action = ""
	set_state(InputState.WAITING)
