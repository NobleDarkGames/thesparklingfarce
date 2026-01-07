class_name ExplorationUIController
extends Node

## ExplorationUIController - Menu state management for map exploration mode
##
## Centralizes UI state for exploration contexts (overworld, towns, dungeons).
## Manages menu visibility, input routing, and transitions between:
## - Normal exploration (hero can move)
## - Inventory menu (PartyEquipmentMenu)
## - Depot panel (CaravanDepotPanel)
## - Dialog (future: DialogManager integration)
##
## This is a local scene component, NOT an autoload. Each exploration scene
## owns its own ExplorationUIController instance.
##
## Usage:
##   # In exploration scene _ready():
##   exploration_ui = ExplorationUIController.new()
##   add_child(exploration_ui)
##   exploration_ui.setup(party_equipment_menu, caravan_depot_panel)
##   hero_controller.ui_controller = exploration_ui

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when UI state changes (for systems that need to react)
signal state_changed(old_state: UIState, new_state: UIState)

## Emitted when any menu opens (hero should stop movement)
signal menu_opened()

## Emitted when all menus close (hero can resume movement)
signal menu_closed()

# =============================================================================
# ENUMS
# =============================================================================

## UI states for exploration mode
enum UIState {
	EXPLORING,      ## Normal gameplay, hero can move and interact
	INVENTORY,      ## PartyEquipmentMenu open
	MEMBERS,        ## MembersInterface open (new screen-based system)
	DEPOT,          ## CaravanDepotPanel open (from menu or Caravan interaction)
	FIELD_MENU,     ## ExplorationFieldMenu open (Item/Magic/Search/Member)
	DIALOG,         ## Dialog box active (future)
	SHOP,           ## Shop interface (future)
	PAUSED          ## Pause menu (future)
}

# =============================================================================
# STATE
# =============================================================================

## Current UI state
var current_state: UIState = UIState.EXPLORING

## Previous state for nested navigation (e.g., INVENTORY -> DEPOT -> INVENTORY)
var _previous_state: UIState = UIState.EXPLORING

# =============================================================================
# UI REFERENCES
# =============================================================================

## Party equipment menu (must be set via setup())
var party_equipment_menu: PartyEquipmentMenu = null

## Caravan depot interface (must be set via setup())
## Type is Node because CaravanInterfaceController is a CanvasLayer in scenes/
var caravan_interface: Node = null

## Exploration field menu (must be set via setup() or setup_field_menu())
var exploration_field_menu: ExplorationFieldMenu = null

## Members interface (new screen-based party management)
## Type is Node because MembersInterfaceController is a CanvasLayer in scenes/
var members_interface: Node = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Process input for menu hotkeys
	set_process_input(true)


func _exit_tree() -> void:
	_disconnect_signals()


## Initialize the controller with UI panel references
## @param equipment_menu: PartyEquipmentMenu instance
## @param depot_interface: CaravanInterfaceController instance (CanvasLayer)
## @param field_menu: ExplorationFieldMenu instance (optional, can be set later)
## @param members_interface_node: MembersInterfaceController instance (optional)
func setup(equipment_menu: PartyEquipmentMenu, depot_interface: Node, field_menu: ExplorationFieldMenu = null, members_interface_node: Node = null) -> void:
	party_equipment_menu = equipment_menu
	caravan_interface = depot_interface
	exploration_field_menu = field_menu
	members_interface = members_interface_node

	_connect_signals()

	# Ensure menus start hidden
	if party_equipment_menu:
		party_equipment_menu.visible = false
	# CaravanInterfaceController manages its own visibility via show()/hide()
	if exploration_field_menu:
		exploration_field_menu.visible = false
	# MembersInterfaceController manages its own visibility


## Set up the exploration field menu (can be called after initial setup)
## @param field_menu: ExplorationFieldMenu instance
func setup_field_menu(field_menu: ExplorationFieldMenu) -> void:
	exploration_field_menu = field_menu
	_connect_field_menu_signals()
	if exploration_field_menu:
		exploration_field_menu.visible = false


func _connect_signals() -> void:
	if party_equipment_menu:
		if not party_equipment_menu.close_requested.is_connected(_on_inventory_close_requested):
			party_equipment_menu.close_requested.connect(_on_inventory_close_requested)
		if not party_equipment_menu.depot_requested.is_connected(_on_depot_requested):
			party_equipment_menu.depot_requested.connect(_on_depot_requested)

	if caravan_interface:
		# CaravanInterfaceController emits depot_closed signal
		if caravan_interface.has_signal("depot_closed"):
			if not caravan_interface.depot_closed.is_connected(_on_depot_close_requested):
				caravan_interface.depot_closed.connect(_on_depot_close_requested)

	if members_interface:
		# MembersInterfaceController emits members_closed signal
		if members_interface.has_signal("members_closed"):
			if not members_interface.members_closed.is_connected(_on_members_close_requested):
				members_interface.members_closed.connect(_on_members_close_requested)

	_connect_field_menu_signals()


func _connect_field_menu_signals() -> void:
	if exploration_field_menu:
		if not exploration_field_menu.close_requested.is_connected(_on_field_menu_close_requested):
			exploration_field_menu.close_requested.connect(_on_field_menu_close_requested)
		if not exploration_field_menu.item_requested.is_connected(_on_field_menu_item_requested):
			exploration_field_menu.item_requested.connect(_on_field_menu_item_requested)
		if not exploration_field_menu.member_requested.is_connected(_on_field_menu_member_requested):
			exploration_field_menu.member_requested.connect(_on_field_menu_member_requested)
		if not exploration_field_menu.search_requested.is_connected(_on_field_menu_search_requested):
			exploration_field_menu.search_requested.connect(_on_field_menu_search_requested)
		if not exploration_field_menu.magic_requested.is_connected(_on_field_menu_magic_requested):
			exploration_field_menu.magic_requested.connect(_on_field_menu_magic_requested)


func _disconnect_signals() -> void:
	if party_equipment_menu:
		if party_equipment_menu.close_requested.is_connected(_on_inventory_close_requested):
			party_equipment_menu.close_requested.disconnect(_on_inventory_close_requested)
		if party_equipment_menu.depot_requested.is_connected(_on_depot_requested):
			party_equipment_menu.depot_requested.disconnect(_on_depot_requested)

	if caravan_interface:
		if caravan_interface.has_signal("depot_closed"):
			if caravan_interface.depot_closed.is_connected(_on_depot_close_requested):
				caravan_interface.depot_closed.disconnect(_on_depot_close_requested)

	if members_interface:
		if members_interface.has_signal("members_closed"):
			if members_interface.members_closed.is_connected(_on_members_close_requested):
				members_interface.members_closed.disconnect(_on_members_close_requested)

	if exploration_field_menu:
		if exploration_field_menu.close_requested.is_connected(_on_field_menu_close_requested):
			exploration_field_menu.close_requested.disconnect(_on_field_menu_close_requested)
		if exploration_field_menu.item_requested.is_connected(_on_field_menu_item_requested):
			exploration_field_menu.item_requested.disconnect(_on_field_menu_item_requested)
		if exploration_field_menu.member_requested.is_connected(_on_field_menu_member_requested):
			exploration_field_menu.member_requested.disconnect(_on_field_menu_member_requested)
		if exploration_field_menu.search_requested.is_connected(_on_field_menu_search_requested):
			exploration_field_menu.search_requested.disconnect(_on_field_menu_search_requested)
		if exploration_field_menu.magic_requested.is_connected(_on_field_menu_magic_requested):
			exploration_field_menu.magic_requested.disconnect(_on_field_menu_magic_requested)

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	# Don't process game input while debug console is open
	if DebugConsole and DebugConsole.is_open:
		return

	# Handle inventory toggle (I key)
	# Note: Menus handle their own close via sf_cancel/ui_cancel and emit close_requested
	if event.is_action_pressed("sf_inventory"):
		if current_state == UIState.EXPLORING:
			# Open inventory from exploration mode
			open_inventory()
			get_viewport().set_input_as_handled()
		elif current_state == UIState.INVENTORY:
			# Close inventory with toggle (pressing I again closes it)
			close_all_menus()
			AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)
			get_viewport().set_input_as_handled()

# =============================================================================
# PUBLIC API
# =============================================================================

## Check if UI is blocking hero input (movement, interaction)
## @return: true if any menu/dialog is open, shop is active, cinematic is playing, or debug console is active
func is_blocking_input() -> bool:
	# Block input if debug console is open
	if DebugConsole and DebugConsole.is_open:
		return true
	# Block input if shop is open (ShopManager handles its own UI)
	if ShopManager and ShopManager.is_shop_open():
		return true
	# Block input if dialog is active
	if DialogManager and DialogManager.is_dialog_active():
		return true
	# Block input if cinematic is playing (even before dialog starts)
	if CinematicsManager and CinematicsManager.is_cinematic_active():
		return true
	return current_state != UIState.EXPLORING


## Open the party equipment/inventory menu
func open_inventory() -> void:
	if current_state != UIState.EXPLORING:
		return

	if not party_equipment_menu:
		push_warning("ExplorationUIController: No PartyEquipmentMenu assigned")
		return

	_set_state(UIState.INVENTORY)
	party_equipment_menu.refresh()
	party_equipment_menu.visible = true
	AudioManager.play_sfx("menu_open", AudioManager.SFXCategory.UI)


## Open the Caravan depot interface
## Can be called from inventory menu or direct Caravan interaction
## @param from_caravan_interaction: true if opened by interacting with Caravan sprite
func open_depot(from_caravan_interaction: bool = false) -> void:
	if not caravan_interface:
		push_warning("ExplorationUIController: No CaravanInterfaceController assigned")
		return

	# Track where we came from for proper back navigation
	_previous_state = current_state

	# Hide inventory menu if it was open
	if party_equipment_menu and party_equipment_menu.visible:
		party_equipment_menu.visible = false

	_set_state(UIState.DEPOT)

	# CaravanInterfaceController manages its own visibility and initialization
	if caravan_interface.has_method("open_depot"):
		caravan_interface.open_depot(from_caravan_interaction)

	# Sound is handled by the CaravanInterfaceController screens


## Close all menus and return to exploration
func close_all_menus() -> void:
	if party_equipment_menu:
		party_equipment_menu.visible = false
	if caravan_interface and caravan_interface.has_method("is_open"):
		if caravan_interface.is_open():
			caravan_interface.close_interface()
	if members_interface and members_interface.has_method("is_open"):
		if members_interface.is_open():
			members_interface.close_interface()
	if exploration_field_menu:
		exploration_field_menu.hide_menu()

	_set_state(UIState.EXPLORING)


## Open the exploration field menu
## @param hero_grid_pos: Grid position where menu was opened (for Search action)
## @param hero_screen_pos: Screen position of hero (for menu positioning)
func open_field_menu(hero_grid_pos: Vector2i, hero_screen_pos: Vector2 = Vector2.ZERO) -> void:
	if current_state != UIState.EXPLORING:
		return

	if not exploration_field_menu:
		push_warning("ExplorationUIController: No ExplorationFieldMenu assigned")
		return

	_set_state(UIState.FIELD_MENU)
	exploration_field_menu.show_menu(hero_grid_pos, hero_screen_pos)


## Get current UI state
func get_state() -> UIState:
	return current_state


## Get state name for debugging
func get_state_name() -> String:
	return UIState.keys()[current_state]

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_inventory_close_requested() -> void:
	close_all_menus()


func _on_depot_requested() -> void:
	open_depot(false)  # From menu button, not caravan interaction


func _on_depot_close_requested() -> void:
	# If we came from inventory, go back to inventory
	if _previous_state == UIState.INVENTORY and party_equipment_menu:
		# CaravanInterfaceController already closed itself when it emitted depot_closed
		_set_state(UIState.INVENTORY)
		party_equipment_menu.visible = true
		AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)
	else:
		# Otherwise close everything and return to exploration
		_set_state(UIState.EXPLORING)


## Field menu closed - return to exploration
func _on_field_menu_close_requested() -> void:
	_set_state(UIState.EXPLORING)


## Field menu Item option - open inventory
func _on_field_menu_item_requested() -> void:
	# Close field menu first
	if exploration_field_menu:
		exploration_field_menu.hide_menu()

	# Open inventory (transitions from FIELD_MENU to INVENTORY)
	_set_state(UIState.INVENTORY)
	if party_equipment_menu:
		party_equipment_menu.refresh()
		party_equipment_menu.visible = true


## Field menu Member option - open the new Members interface
func _on_field_menu_member_requested() -> void:
	# Close field menu first
	if exploration_field_menu:
		exploration_field_menu.hide_menu()

	# Open the new MembersInterface (screen-based, keyboard/gamepad friendly)
	if members_interface and members_interface.has_method("open_members"):
		_set_state(UIState.MEMBERS)
		members_interface.open_members()
	else:
		# Fallback to old PartyEquipmentMenu if MembersInterface not available
		_set_state(UIState.INVENTORY)
		if party_equipment_menu:
			party_equipment_menu.refresh()
			party_equipment_menu.visible = true


## Members interface closed - return to exploration
func _on_members_close_requested() -> void:
	_set_state(UIState.EXPLORING)


## Field menu Search option - examine current tile
func _on_field_menu_search_requested() -> void:
	# Close field menu first
	if exploration_field_menu:
		exploration_field_menu.hide_menu()

	_set_state(UIState.EXPLORING)

	# Phase 1: Show placeholder message via DialogManager
	# Phase 3 will implement hidden item detection and tile descriptions
	if DialogManager:
		DialogManager.show_message("Nothing unusual here.")
	else:
		push_warning("ExplorationUIController: DialogManager not available for Search message")


## Field menu Magic option - open magic selection (Phase 2)
func _on_field_menu_magic_requested() -> void:
	# Close field menu first
	if exploration_field_menu:
		exploration_field_menu.hide_menu()

	_set_state(UIState.EXPLORING)

	# Phase 1: Show placeholder message
	# Phase 2 will implement FieldMagicMenu for Egress/Detox
	if DialogManager:
		DialogManager.show_message("No field magic available.")
	else:
		push_warning("ExplorationUIController: DialogManager not available for Magic message")


# =============================================================================
# STATE MANAGEMENT
# =============================================================================

func _set_state(new_state: UIState) -> void:
	var old_state: UIState = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)

	# Emit convenience signals for hero controller
	if new_state == UIState.EXPLORING:
		menu_closed.emit()
	elif old_state == UIState.EXPLORING:
		menu_opened.emit()
