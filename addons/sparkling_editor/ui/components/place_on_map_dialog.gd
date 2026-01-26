@tool
class_name PlaceOnMapDialog
extends RefCounted

## Reusable dialog component for selecting maps to place entities (NPCs, Interactables, etc.)
##
## This component handles:
## - Map selection popup creation and management
## - Populating map list from active mod
## - Selection and confirmation UI
## - Emitting signals when a map is confirmed
##
## The position spinboxes remain in the parent editor's form. This component only handles
## map selection. The parent editor provides the grid position when handling the signal.
##
## Usage:
##   var dialog: PlaceOnMapDialog = PlaceOnMapDialog.new()
##   dialog.setup(parent_control, "NPC")
##   dialog.map_confirmed.connect(_on_map_selected)
##   dialog.show_dialog()

## Emitted when user confirms a map selection
## Parameters: map_path (String)
signal map_confirmed(map_path: String)

## Emitted when dialog is cancelled or an error occurs
signal cancelled()

## Emitted when an error occurs (e.g., invalid map selection)
signal error_occurred(message: String)

# UI References
var _popup: PopupPanel
var _map_list: ItemList
var _confirm_btn: Button

# Configuration
var _entity_type_name: String = "Entity"
var _parent_control: Control


## Initialize the dialog with a parent control and entity type name
## @param parent: The Control that will own this dialog
## @param entity_type_name: Name for display (e.g., "NPC", "Interactable")
func setup(parent: Control, entity_type_name: String) -> void:
	_parent_control = parent
	_entity_type_name = entity_type_name
	_create_popup()


## Show the dialog (populates map list and displays popup)
func show_dialog() -> void:
	if not _popup:
		push_error("PlaceOnMapDialog: setup() must be called before show_dialog()")
		return

	_populate_map_list()
	_popup.popup_centered()


## Hide the dialog
func hide_dialog() -> void:
	if _popup:
		_popup.hide()


## Create the popup UI
func _create_popup() -> void:
	if not _parent_control:
		push_error("PlaceOnMapDialog: No parent control set")
		return

	_popup = PopupPanel.new()
	_popup.title = "Select Map"

	var popup_content: VBoxContainer = VBoxContainer.new()
	popup_content.custom_minimum_size = Vector2(400, 300)

	# Instruction label
	var popup_label: Label = Label.new()
	popup_label.text = "Select a map to place the %s on:" % _entity_type_name.to_lower()
	popup_content.add_child(popup_label)

	# Map list
	_map_list = ItemList.new()
	_map_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_list.custom_minimum_size.y = 200
	_map_list.item_activated.connect(_on_map_double_clicked)
	popup_content.add_child(_map_list)

	# Button row
	var btn_container: HBoxContainer = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_END

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_cancel_pressed)
	btn_container.add_child(cancel_btn)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Place %s" % _entity_type_name
	_confirm_btn.pressed.connect(_on_place_confirmed)
	btn_container.add_child(_confirm_btn)

	popup_content.add_child(btn_container)
	_popup.add_child(popup_content)
	_parent_control.add_child(_popup)


## Populate the map list from the active mod
func _populate_map_list() -> void:
	if not _map_list:
		return

	_map_list.clear()

	var mod_path: String = SparklingEditorUtils.get_active_mod_path()
	if mod_path.is_empty():
		_map_list.add_item("(No active mod selected)")
		return

	var maps: Array[Dictionary] = MapPlacementHelper.get_available_maps(mod_path)
	if maps.is_empty():
		_map_list.add_item("(No maps found)")
		return

	for map_info: Dictionary in maps:
		var display_name: String = DictUtils.get_string(map_info, "display_name", "Unknown")
		var map_path: String = DictUtils.get_string(map_info, "path", "")
		_map_list.add_item(display_name)
		_map_list.set_item_metadata(_map_list.item_count - 1, map_path)


## Handle double-click on map item
func _on_map_double_clicked(index: int) -> void:
	_map_list.select(index)
	_on_place_confirmed()


## Handle cancel button
func _on_cancel_pressed() -> void:
	_popup.hide()
	cancelled.emit()


## Handle place confirmation
func _on_place_confirmed() -> void:
	if not _map_list:
		return

	var selected_items: PackedInt32Array = _map_list.get_selected_items()
	if selected_items.is_empty():
		error_occurred.emit("Please select a map first.")
		return

	var selected_index: int = selected_items[0]
	var map_path: String = _map_list.get_item_metadata(selected_index)

	if map_path.is_empty() or not FileAccess.file_exists(map_path):
		error_occurred.emit("Invalid map selection.")
		return

	_popup.hide()
	map_confirmed.emit(map_path)


## Clean up resources
func cleanup() -> void:
	if _popup and is_instance_valid(_popup):
		_popup.queue_free()
		_popup = null
	_map_list = null
	_confirm_btn = null
