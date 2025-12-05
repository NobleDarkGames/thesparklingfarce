class_name PartyEquipmentMenu
extends Control

## PartyEquipmentMenu - Multi-character equipment and inventory management
##
## Provides SF2-style party inventory management:
## - Character tabs to switch between party members
## - Embedded InventoryPanel for selected character
## - Item transfer between characters ("Give to...")
## - Quick access to Caravan Depot
##
## Access via menu button or "I" key during exploration.

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when menu should close
signal close_requested()

## Emitted when depot panel should open
signal depot_requested()

## Emitted when item transfer completes
signal item_transferred(from_uid: String, to_uid: String, item_id: String)

# =============================================================================
# CONSTANTS
# =============================================================================

const COLOR_TAB_NORMAL: Color = Color(0.2, 0.2, 0.25, 0.9)
const COLOR_TAB_SELECTED: Color = Color(0.3, 0.3, 0.4, 0.95)
const COLOR_TAB_HOVER: Color = Color(0.25, 0.25, 0.3, 0.9)
const COLOR_PANEL_BG: Color = Color(0.12, 0.12, 0.16, 0.98)

# =============================================================================
# PRELOADS
# =============================================================================

const InventoryPanelScene: PackedScene = preload("res://scenes/ui/inventory_panel.tscn")
const MONOGRAM_FONT: Font = preload("res://assets/fonts/monogram.ttf")
const UI_THEME: Theme = preload("res://assets/themes/ui_theme.tres")

# =============================================================================
# STATE
# =============================================================================

## Currently selected character index in party
var _current_index: int = 0

## Party member save data references
var _party_save_data: Array[CharacterSaveData] = []

## Party member character data references
var _party_character_data: Array[CharacterData] = []

## Character tab buttons
var _character_tabs: Array[Button] = []

## Transfer mode state
var _transfer_mode_active: bool = false
var _transfer_item_id: String = ""

# =============================================================================
# UI REFERENCES
# =============================================================================

var _main_container: VBoxContainer = null
var _header_bar: HBoxContainer = null
var _title_label: Label = null
var _depot_button: Button = null
var _close_button: Button = null
var _tabs_container: HBoxContainer = null
var _content_container: HBoxContainer = null
var _inventory_panel: Control = null  # InventoryPanel instance
var _actions_panel: VBoxContainer = null
var _give_button: Button = null
var _depot_store_button: Button = null
var _footer_label: Label = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_build_ui()
	_refresh_party_data()
	_create_character_tabs()
	if not _party_save_data.is_empty():
		_select_character(0)


func _build_ui() -> void:
	# Full screen semi-transparent background
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Main panel (centered) - sized for 640x360 viewport
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "MainPanel"
	panel.custom_minimum_size = Vector2(280, 200)
	panel.size = panel.custom_minimum_size
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PANEL_BG
	panel_style.border_width_bottom = 1
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_color = Color(0.5, 0.5, 0.6, 1.0)
	panel_style.content_margin_bottom = 4
	panel_style.content_margin_left = 4
	panel_style.content_margin_right = 4
	panel_style.content_margin_top = 4
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	# Main VBox layout
	_main_container = VBoxContainer.new()
	_main_container.name = "MainVBox"
	_main_container.add_theme_constant_override("separation", 2)
	panel.add_child(_main_container)

	# Header bar
	_header_bar = HBoxContainer.new()
	_header_bar.name = "HeaderBar"
	_header_bar.add_theme_constant_override("separation", 4)
	_main_container.add_child(_header_bar)

	_title_label = Label.new()
	_title_label.text = "PARTY EQUIPMENT"
	_title_label.add_theme_font_override("font", MONOGRAM_FONT)
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_bar.add_child(_title_label)

	_depot_button = _create_button("Depot", _on_depot_pressed)
	_header_bar.add_child(_depot_button)

	_close_button = _create_button("X", _on_close_pressed)
	_close_button.custom_minimum_size = Vector2(16, 16)
	_header_bar.add_child(_close_button)

	# Character tabs
	_tabs_container = HBoxContainer.new()
	_tabs_container.name = "TabsContainer"
	_tabs_container.add_theme_constant_override("separation", 2)
	_main_container.add_child(_tabs_container)

	# Content area (inventory panel + actions)
	_content_container = HBoxContainer.new()
	_content_container.name = "ContentContainer"
	_content_container.add_theme_constant_override("separation", 4)
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_container.add_child(_content_container)

	# Inventory panel (will be instantiated)
	_inventory_panel = InventoryPanelScene.instantiate()
	_inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_container.add_child(_inventory_panel)

	# Connect inventory panel signals
	_inventory_panel.slot_clicked.connect(_on_inventory_slot_clicked)
	_inventory_panel.equipment_changed.connect(_on_equipment_changed)

	# Actions panel
	_actions_panel = VBoxContainer.new()
	_actions_panel.name = "ActionsPanel"
	_actions_panel.add_theme_constant_override("separation", 2)
	_actions_panel.custom_minimum_size = Vector2(60, 0)
	_content_container.add_child(_actions_panel)

	var actions_label: Label = Label.new()
	actions_label.text = "Actions"
	actions_label.add_theme_font_override("font", MONOGRAM_FONT)
	actions_label.add_theme_font_size_override("font_size", 16)
	actions_label.modulate = Color(0.7, 0.7, 0.8, 1.0)
	_actions_panel.add_child(actions_label)

	_give_button = _create_button("Give to...", _on_give_pressed)
	_give_button.disabled = true
	_actions_panel.add_child(_give_button)

	_depot_store_button = _create_button("Store in Depot", _on_depot_store_pressed)
	_depot_store_button.disabled = true
	_actions_panel.add_child(_depot_store_button)

	# Footer
	_footer_label = Label.new()
	_footer_label.text = "Tab: Switch character | I: Close"
	_footer_label.add_theme_font_override("font", MONOGRAM_FONT)
	_footer_label.add_theme_font_size_override("font_size", 16)
	_footer_label.modulate = Color(0.5, 0.5, 0.6, 1.0)
	_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_container.add_child(_footer_label)


func _create_button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_override("font", MONOGRAM_FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.custom_minimum_size = Vector2(48, 16)

	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = COLOR_TAB_NORMAL
	normal_style.border_width_bottom = 1
	normal_style.border_width_left = 1
	normal_style.border_width_right = 1
	normal_style.border_width_top = 1
	normal_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	button.add_theme_stylebox_override("normal", normal_style)

	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.bg_color = COLOR_TAB_HOVER
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style: StyleBoxFlat = normal_style.duplicate()
	pressed_style.bg_color = COLOR_TAB_SELECTED
	button.add_theme_stylebox_override("pressed", pressed_style)

	button.pressed.connect(callback)
	return button


# =============================================================================
# PARTY DATA
# =============================================================================

func _refresh_party_data() -> void:
	_party_save_data.clear()
	_party_character_data.clear()

	for character: CharacterData in PartyManager.party_members:
		var uid: String = character.character_uid
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(uid)
		if save_data:
			_party_save_data.append(save_data)
			_party_character_data.append(character)


func _create_character_tabs() -> void:
	# Clear existing tabs
	for tab: Button in _character_tabs:
		tab.queue_free()
	_character_tabs.clear()

	# Create tab for each party member
	for i in range(_party_character_data.size()):
		var character: CharacterData = _party_character_data[i]
		var tab: Button = Button.new()
		tab.text = character.character_name
		tab.add_theme_font_override("font", MONOGRAM_FONT)
		tab.add_theme_font_size_override("font_size", 16)
		tab.custom_minimum_size = Vector2(48, 16)
		tab.toggle_mode = true

		var normal_style: StyleBoxFlat = StyleBoxFlat.new()
		normal_style.bg_color = COLOR_TAB_NORMAL
		normal_style.border_width_bottom = 1
		normal_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
		tab.add_theme_stylebox_override("normal", normal_style)

		var pressed_style: StyleBoxFlat = normal_style.duplicate()
		pressed_style.bg_color = COLOR_TAB_SELECTED
		pressed_style.border_color = Color(0.6, 0.6, 0.7, 1.0)
		tab.add_theme_stylebox_override("pressed", pressed_style)

		var hover_style: StyleBoxFlat = normal_style.duplicate()
		hover_style.bg_color = COLOR_TAB_HOVER
		tab.add_theme_stylebox_override("hover", hover_style)

		var index: int = i
		tab.pressed.connect(_on_tab_pressed.bind(index))

		_tabs_container.add_child(tab)
		_character_tabs.append(tab)


func _select_character(index: int) -> void:
	if index < 0 or index >= _party_save_data.size():
		return

	_current_index = index

	# Update tab visual state
	for i in range(_character_tabs.size()):
		_character_tabs[i].button_pressed = (i == index)

	# Update inventory panel
	var save_data: CharacterSaveData = _party_save_data[index]
	_inventory_panel.set_character(save_data)

	# Reset action buttons
	_give_button.disabled = true
	_depot_store_button.disabled = true
	_cancel_transfer_mode()


# =============================================================================
# TRANSFER MODE
# =============================================================================

func _enter_transfer_mode(item_id: String) -> void:
	_transfer_mode_active = true
	_transfer_item_id = item_id
	_footer_label.text = "Select recipient or press Esc to cancel"
	_footer_label.modulate = Color(1.0, 1.0, 0.5, 1.0)

	# Highlight other character tabs as valid targets
	for i in range(_character_tabs.size()):
		if i != _current_index:
			_character_tabs[i].modulate = Color(0.5, 1.0, 0.5, 1.0)


func _cancel_transfer_mode() -> void:
	_transfer_mode_active = false
	_transfer_item_id = ""
	_footer_label.text = "Tab: Switch character | I: Close"
	_footer_label.modulate = Color(0.5, 0.5, 0.6, 1.0)

	# Reset tab colors
	for tab: Button in _character_tabs:
		tab.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _execute_transfer(target_index: int) -> void:
	if target_index == _current_index:
		return

	var from_uid: String = _party_character_data[_current_index].character_uid
	var to_uid: String = _party_character_data[target_index].character_uid

	var result: Dictionary = PartyManager.transfer_item_between_members(
		from_uid, to_uid, _transfer_item_id
	)

	if result.success:
		AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)
		item_transferred.emit(from_uid, to_uid, _transfer_item_id)
		_footer_label.text = "Item transferred!"
	else:
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		_footer_label.text = result.error

	_cancel_transfer_mode()
	_inventory_panel.refresh()


# =============================================================================
# EVENT HANDLERS
# =============================================================================

func _on_tab_pressed(index: int) -> void:
	if _transfer_mode_active:
		if index != _current_index:
			_execute_transfer(index)
		return

	_select_character(index)
	AudioManager.play_sfx("menu_hover", AudioManager.SFXCategory.UI)


func _on_inventory_slot_clicked(slot_type: String, slot_index: int, item_id: String) -> void:
	# Enable/disable action buttons based on selection
	var has_item: bool = not item_id.is_empty()
	_give_button.disabled = not has_item or _party_save_data.size() < 2
	_depot_store_button.disabled = not has_item

	# Store selected item for actions
	if has_item:
		_transfer_item_id = item_id


func _on_equipment_changed(_slot_id: String, _old_item: String, _new_item: String) -> void:
	# Refresh after equipment change
	_inventory_panel.refresh()


func _on_give_pressed() -> void:
	if _transfer_item_id.is_empty():
		return

	if _party_save_data.size() < 2:
		_footer_label.text = "No other party members!"
		return

	_enter_transfer_mode(_transfer_item_id)
	AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)


func _on_depot_store_pressed() -> void:
	if _transfer_item_id.is_empty():
		return

	var save_data: CharacterSaveData = _party_save_data[_current_index]

	# Remove from character inventory
	if save_data.remove_item_from_inventory(_transfer_item_id):
		# Add to depot
		StorageManager.add_to_depot(_transfer_item_id)
		AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)
		_footer_label.text = "Stored in depot!"
		_inventory_panel.refresh()
		_give_button.disabled = true
		_depot_store_button.disabled = true
	else:
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		_footer_label.text = "Failed to store item"


func _on_depot_pressed() -> void:
	depot_requested.emit()
	AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)


func _on_close_pressed() -> void:
	close_requested.emit()
	AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)


# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel"):
		if _transfer_mode_active:
			_cancel_transfer_mode()
			AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)
		else:
			close_requested.emit()
			AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_focus_next"):  # Tab key
		var next_index: int = (_current_index + 1) % _party_save_data.size()
		if _transfer_mode_active:
			_execute_transfer(next_index)
		else:
			_select_character(next_index)
			AudioManager.play_sfx("menu_hover", AudioManager.SFXCategory.UI)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_focus_prev"):  # Shift+Tab
		var prev_index: int = (_current_index - 1 + _party_save_data.size()) % _party_save_data.size()
		if _transfer_mode_active:
			_execute_transfer(prev_index)
		else:
			_select_character(prev_index)
			AudioManager.play_sfx("menu_hover", AudioManager.SFXCategory.UI)
		get_viewport().set_input_as_handled()


# =============================================================================
# PUBLIC API
# =============================================================================

## Refresh party data and rebuild UI
func refresh() -> void:
	_refresh_party_data()
	_create_character_tabs()
	if _current_index >= _party_save_data.size():
		_current_index = 0
	if not _party_save_data.is_empty():
		_select_character(_current_index)


## Open menu and select specific character
func open_for_character(character_uid: String) -> void:
	for i in range(_party_character_data.size()):
		if _party_character_data[i].character_uid == character_uid:
			_select_character(i)
			break
	visible = true
