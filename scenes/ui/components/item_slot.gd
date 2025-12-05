class_name ItemSlot
extends Control

## ItemSlot - A reusable UI component for displaying a single item
##
## Shows item icon (or placeholder if empty) with visual states for:
## - Empty, Filled, Selected, Cursed (red border/tint)
##
## Designed for SF2-authentic 48x48 slot size.
## Used in InventoryPanel for both equipment and inventory slots.

## Emitted when this slot is clicked
signal clicked(item_id: String)

## Emitted when mouse hovers over this slot
signal hovered(item_id: String)

## Emitted when mouse exits this slot
signal hover_exited()

# =============================================================================
# CONSTANTS
# =============================================================================

## Slot dimensions (SF-authentic small slots)
const SLOT_SIZE: Vector2 = Vector2(48, 48)

## Visual colors
const COLOR_BORDER_NORMAL: Color = Color(0.6, 0.6, 0.7, 1.0)
const COLOR_BORDER_SELECTED: Color = Color(1.0, 1.0, 0.3, 1.0)
const COLOR_BORDER_CURSED: Color = Color(0.9, 0.2, 0.2, 1.0)
const COLOR_BORDER_EMPTY: Color = Color(0.3, 0.3, 0.35, 1.0)
const COLOR_BACKGROUND: Color = Color(0.1, 0.1, 0.15, 0.95)
const COLOR_BACKGROUND_SELECTED: Color = Color(0.15, 0.15, 0.2, 0.95)
const COLOR_BACKGROUND_CURSED: Color = Color(0.2, 0.1, 0.1, 0.95)
const COLOR_ICON_EMPTY: Color = Color(0.3, 0.3, 0.35, 0.5)
const COLOR_ICON_NORMAL: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_ICON_CURSED: Color = Color(1.0, 0.7, 0.7, 1.0)

const BORDER_WIDTH: float = 2.0

# =============================================================================
# PROPERTIES
# =============================================================================

## Current item ID in this slot (empty string if no item)
var item_id: String = ""

## Cached ItemData for the current item
var _item_data: ItemData = null

## Visual state flags
var _is_selected: bool = false
var _is_cursed: bool = false
var _is_hovered: bool = false

## UI elements (built dynamically)
var _border_rect: ColorRect = null
var _background_rect: ColorRect = null
var _icon_texture: TextureRect = null
var _tooltip_label: Label = null
var _slot_label: Label = null

## Slot label text (shown when empty, e.g., "Weapon", "Ring 1")
var _slot_label_text: String = ""

## Placeholder texture for empty slots (drawn as simple shape)
var _empty_placeholder: Texture2D = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_build_ui()
	_update_visuals()

	# Enable mouse input
	mouse_filter = Control.MOUSE_FILTER_STOP


func _build_ui() -> void:
	# Set fixed size
	custom_minimum_size = SLOT_SIZE
	size = SLOT_SIZE

	# Border (outer colored rect)
	_border_rect = ColorRect.new()
	_border_rect.name = "Border"
	_border_rect.color = COLOR_BORDER_EMPTY
	_border_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_border_rect)

	# Background (inner panel)
	_background_rect = ColorRect.new()
	_background_rect.name = "Background"
	_background_rect.color = COLOR_BACKGROUND
	_background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background_rect.offset_left = BORDER_WIDTH
	_background_rect.offset_top = BORDER_WIDTH
	_background_rect.offset_right = -BORDER_WIDTH
	_background_rect.offset_bottom = -BORDER_WIDTH
	_background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border_rect.add_child(_background_rect)

	# Icon texture
	_icon_texture = TextureRect.new()
	_icon_texture.name = "Icon"
	_icon_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon_texture.offset_left = 4.0
	_icon_texture.offset_top = 4.0
	_icon_texture.offset_right = -4.0
	_icon_texture.offset_bottom = -4.0
	_icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background_rect.add_child(_icon_texture)

	# Slot label (shown when empty, e.g., "Weapon", "Ring 1")
	_slot_label = Label.new()
	_slot_label.name = "SlotLabel"
	_slot_label.set_anchors_preset(Control.PRESET_CENTER)
	_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_slot_label.add_theme_font_size_override("font_size", 16)
	_slot_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5, 0.8))
	_slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_label.visible = false
	_background_rect.add_child(_slot_label)


# =============================================================================
# PUBLIC API
# =============================================================================

## Set the item displayed in this slot
## @param new_item_id: Item ID to display (empty string for empty slot)
## @param is_cursed: Whether this item is currently cursed and unremovable
func set_item(new_item_id: String, is_cursed: bool = false) -> void:
	item_id = new_item_id
	_is_cursed = is_cursed
	_item_data = null

	if not item_id.is_empty():
		_item_data = ModLoader.registry.get_resource("item", item_id) as ItemData

	_update_visuals()


## Clear the slot (set to empty)
func clear_item() -> void:
	set_item("", false)


## Set selected state (visual highlight)
func set_selected(selected: bool) -> void:
	_is_selected = selected
	_update_visuals()


## Check if slot is empty
func is_empty() -> bool:
	return item_id.is_empty()


## Check if slot contains a cursed item
func is_cursed() -> bool:
	return _is_cursed


## Get the item name for display (returns empty string if no item)
func get_item_name() -> String:
	if _item_data:
		return _item_data.item_name
	return ""


## Get the item description for tooltips
func get_item_description() -> String:
	if _item_data:
		return _item_data.description
	return ""


## Get the ItemData resource (null if empty)
func get_item_data() -> ItemData:
	return _item_data


## Set the slot label text (shown when empty)
## @param label_text: Text to show, e.g., "Weapon", "Ring 1"
func set_slot_label(label_text: String) -> void:
	_slot_label_text = label_text
	if _slot_label:
		_slot_label.text = label_text
	_update_visuals()


# =============================================================================
# INPUT HANDLING
# =============================================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			clicked.emit(item_id)
			accept_event()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_is_hovered = true
			_update_visuals()
			hovered.emit(item_id)
		NOTIFICATION_MOUSE_EXIT:
			_is_hovered = false
			_update_visuals()
			hover_exited.emit()


# =============================================================================
# VISUAL UPDATES
# =============================================================================

func _update_visuals() -> void:
	if not is_node_ready():
		return

	# Update border color based on state
	if _is_cursed:
		_border_rect.color = COLOR_BORDER_CURSED
	elif _is_selected:
		_border_rect.color = COLOR_BORDER_SELECTED
	elif is_empty():
		_border_rect.color = COLOR_BORDER_EMPTY
	else:
		_border_rect.color = COLOR_BORDER_NORMAL

	# Subtle hover effect
	if _is_hovered and not is_empty():
		_border_rect.color = _border_rect.color.lightened(0.2)

	# Update background color
	if _is_cursed:
		_background_rect.color = COLOR_BACKGROUND_CURSED
	elif _is_selected:
		_background_rect.color = COLOR_BACKGROUND_SELECTED
	else:
		_background_rect.color = COLOR_BACKGROUND

	# Update icon
	if _item_data and _item_data.icon:
		_icon_texture.texture = _item_data.icon
		if _is_cursed:
			_icon_texture.modulate = COLOR_ICON_CURSED
		else:
			_icon_texture.modulate = COLOR_ICON_NORMAL
	else:
		# Empty slot or no icon - show placeholder
		_icon_texture.texture = null
		_icon_texture.modulate = COLOR_ICON_EMPTY

	# Show/hide slot label based on empty state
	if _slot_label:
		_slot_label.visible = is_empty() and not _slot_label_text.is_empty()
