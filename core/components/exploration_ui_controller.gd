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
	INVENTORY,      ## PartyEquipmentMenu open (deprecated, use FIELD_ITEMS)
	MEMBERS,        ## MembersInterface open (new screen-based system)
	DEPOT,          ## CaravanDepotPanel open (from menu or Caravan interaction)
	FIELD_MENU,     ## ExplorationFieldMenu open (Item/Magic/Search/Member)
	FIELD_ITEMS,    ## FieldItemsInterface open (hero inventory, SF2 authentic)
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

## Party equipment menu (deprecated - replaced by field_items_interface)
## Kept for backwards compatibility but typically null
var party_equipment_menu: Node = null

## Caravan depot interface (must be set via setup())
## Type is Node because CaravanInterfaceController is a CanvasLayer in scenes/
var caravan_interface: Node = null

## Exploration field menu (must be set via setup() or setup_field_menu())
var exploration_field_menu: ExplorationFieldMenu = null

## Members interface (new screen-based party management)
## Type is Node because MembersInterfaceController is a CanvasLayer in scenes/
var members_interface: Node = null

## Field items interface (SF2-authentic hero inventory for field menu Item option)
## Type is Node because FieldItemInterfaceController is a CanvasLayer in scenes/
var field_items_interface: Node = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Process input for menu hotkeys
	set_process_input(true)


func _exit_tree() -> void:
	_disconnect_signals()


## Initialize the controller with UI panel references
## @param equipment_menu: Deprecated, typically null (replaced by field_items_interface)
## @param depot_interface: CaravanInterfaceController instance (CanvasLayer)
## @param field_menu: ExplorationFieldMenu instance (optional, can be set later)
## @param members_interface_node: MembersInterfaceController instance (optional)
## @param field_items_interface_node: FieldItemInterfaceController instance (optional)
func setup(equipment_menu: Node, depot_interface: Node, field_menu: ExplorationFieldMenu = null, members_interface_node: Node = null, field_items_interface_node: Node = null) -> void:
	party_equipment_menu = equipment_menu
	caravan_interface = depot_interface
	exploration_field_menu = field_menu
	members_interface = members_interface_node
	field_items_interface = field_items_interface_node

	_connect_signals()

	# Ensure menus start hidden
	if party_equipment_menu:
		party_equipment_menu.visible = false
	# CaravanInterfaceController manages its own visibility via show()/hide()
	if exploration_field_menu:
		exploration_field_menu.visible = false
	# MembersInterfaceController and FieldItemInterfaceController manage their own visibility


## Set up the exploration field menu (can be called after initial setup)
## @param field_menu: ExplorationFieldMenu instance
func setup_field_menu(field_menu: ExplorationFieldMenu) -> void:
	exploration_field_menu = field_menu
	_connect_field_menu_signals()
	if exploration_field_menu:
		exploration_field_menu.visible = false


func _connect_signals() -> void:
	# Party equipment menu (deprecated)
	_safe_connect(party_equipment_menu, "close_requested", _on_inventory_close_requested)
	_safe_connect(party_equipment_menu, "depot_requested", _on_depot_requested)

	# Interface controllers
	_safe_connect(caravan_interface, "depot_closed", _on_depot_close_requested)
	_safe_connect(members_interface, "members_closed", _on_members_close_requested)
	_safe_connect(field_items_interface, "field_items_closed", _on_field_items_close_requested)

	_connect_field_menu_signals()


func _connect_field_menu_signals() -> void:
	if not exploration_field_menu:
		return
	_safe_connect(exploration_field_menu, "close_requested", _on_field_menu_close_requested)
	_safe_connect(exploration_field_menu, "item_requested", _on_field_menu_item_requested)
	_safe_connect(exploration_field_menu, "member_requested", _on_field_menu_member_requested)
	_safe_connect(exploration_field_menu, "search_requested", _on_field_menu_search_requested)
	_safe_connect(exploration_field_menu, "magic_requested", _on_field_menu_magic_requested)


func _disconnect_signals() -> void:
	# Party equipment menu (deprecated)
	_safe_disconnect(party_equipment_menu, "close_requested", _on_inventory_close_requested)
	_safe_disconnect(party_equipment_menu, "depot_requested", _on_depot_requested)

	# Interface controllers
	_safe_disconnect(caravan_interface, "depot_closed", _on_depot_close_requested)
	_safe_disconnect(members_interface, "members_closed", _on_members_close_requested)
	_safe_disconnect(field_items_interface, "field_items_closed", _on_field_items_close_requested)

	# Field menu
	_safe_disconnect(exploration_field_menu, "close_requested", _on_field_menu_close_requested)
	_safe_disconnect(exploration_field_menu, "item_requested", _on_field_menu_item_requested)
	_safe_disconnect(exploration_field_menu, "member_requested", _on_field_menu_member_requested)
	_safe_disconnect(exploration_field_menu, "search_requested", _on_field_menu_search_requested)
	_safe_disconnect(exploration_field_menu, "magic_requested", _on_field_menu_magic_requested)


## Safely connect a signal if object exists and signal isn't already connected
func _safe_connect(obj: Object, signal_name: String, callable: Callable) -> void:
	if not obj or not obj.has_signal(signal_name):
		return
	var sig: Signal = Signal(obj, signal_name)
	if not sig.is_connected(callable):
		sig.connect(callable)


## Safely disconnect a signal if object exists and signal is connected
func _safe_disconnect(obj: Object, signal_name: String, callable: Callable) -> void:
	if not obj or not obj.has_signal(signal_name):
		return
	var sig: Signal = Signal(obj, signal_name)
	if sig.is_connected(callable):
		sig.disconnect(callable)

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
		elif current_state == UIState.FIELD_ITEMS:
			# Close field items with toggle (pressing I again closes it)
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
	# Block input if pause menu is open
	if PauseMenuManager and PauseMenuManager.is_open():
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


## Open the hero's inventory (field items interface)
## This is the SF2-authentic hero-only inventory view
func open_inventory() -> void:
	if current_state != UIState.EXPLORING:
		return

	# Use new FieldItemsInterface (SF2 authentic: hero only, no GIVE)
	if field_items_interface and field_items_interface.has_method("open_field_items"):
		_set_state(UIState.FIELD_ITEMS)
		field_items_interface.open_field_items()
		AudioManager.play_sfx("menu_open", AudioManager.SFXCategory.UI)
	else:
		push_warning("ExplorationUIController: No FieldItemsInterface assigned")


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
	if field_items_interface and field_items_interface.has_method("is_open"):
		if field_items_interface.is_open():
			field_items_interface.close_interface()
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


## Field menu Item option - open hero's inventory (SF2 authentic)
func _on_field_menu_item_requested() -> void:
	_close_field_menu()

	# Open FieldItemsInterface (SF2 authentic: hero only, no GIVE)
	if field_items_interface and field_items_interface.has_method("open_field_items"):
		_set_state(UIState.FIELD_ITEMS)
		field_items_interface.open_field_items()
	else:
		_open_fallback_inventory()


## Field menu Member option - open the new Members interface
func _on_field_menu_member_requested() -> void:
	_close_field_menu()

	# Open MembersInterface (screen-based, keyboard/gamepad friendly)
	if members_interface and members_interface.has_method("open_members"):
		_set_state(UIState.MEMBERS)
		members_interface.open_members()
	else:
		_open_fallback_inventory()


## Pause menu opened - set PAUSED state
func _on_pause_menu_opened() -> void:
	_set_state(UIState.PAUSED)


## Pause menu closed - return to exploration
func _on_pause_menu_closed() -> void:
	_set_state(UIState.EXPLORING)


## Members/FieldItems interface closed - return to exploration
func _on_members_close_requested() -> void:
	_set_state(UIState.EXPLORING)


func _on_field_items_close_requested() -> void:
	_set_state(UIState.EXPLORING)


## Field menu Search option - examine current tile (placeholder)
func _on_field_menu_search_requested() -> void:
	_close_field_menu_and_show_message("Nothing unusual here.")


## Field menu Magic option - open magic selection (placeholder)
func _on_field_menu_magic_requested() -> void:
	_close_field_menu_and_show_message("No field magic available.")


## Helper: close field menu
func _close_field_menu() -> void:
	if exploration_field_menu:
		exploration_field_menu.hide_menu()


## Helper: close field menu and show a message via DialogManager
func _close_field_menu_and_show_message(message: String) -> void:
	_close_field_menu()
	_set_state(UIState.EXPLORING)
	if DialogManager:
		DialogManager.show_message(message)
	else:
		push_warning("ExplorationUIController: DialogManager not available")


## Helper: fallback to deprecated PartyEquipmentMenu
func _open_fallback_inventory() -> void:
	_set_state(UIState.INVENTORY)
	if party_equipment_menu:
		party_equipment_menu.refresh()
		party_equipment_menu.visible = true


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
