class_name PartyManagementPanel
extends Control

## PartyManagementPanel - SF2-style party roster management
##
## Allows swapping characters between active party (12 max) and reserves.
## Layout:
## - Left side: 4x3 grid of active party slots
## - Right side: Scrollable list of reserves + selected character info
## - Hero (slot 0) is locked and cannot be moved
##
## Keyboard/gamepad navigation with visual feedback.

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when panel should close
signal close_requested()

## Emitted when a swap is performed
signal party_changed()

# =============================================================================
# CONSTANTS
# =============================================================================

const COLOR_PANEL_BG: Color = Color(0.1, 0.1, 0.15, 0.95)
const COLOR_PANEL_BORDER: Color = Color(0.4, 0.35, 0.25, 1.0)
const COLOR_SLOT_EMPTY: Color = Color(0.2, 0.2, 0.25, 0.8)
const COLOR_SLOT_FILLED: Color = Color(0.25, 0.25, 0.3, 0.9)
const COLOR_SLOT_SELECTED: Color = Color(0.4, 0.35, 0.2, 1.0)
const COLOR_SLOT_HERO: Color = Color(0.3, 0.25, 0.15, 1.0)
const COLOR_TEXT_NORMAL: Color = Color(0.85, 0.85, 0.85, 1.0)
const COLOR_TEXT_SELECTED: Color = Color(1.0, 0.95, 0.4, 1.0)
const COLOR_TEXT_DISABLED: Color = Color(0.5, 0.5, 0.5, 1.0)

const SLOT_SIZE: Vector2 = Vector2(56, 56)
const SLOT_SPACING: int = 4
const ACTIVE_COLS: int = 4
const ACTIVE_ROWS: int = 3

const MONOGRAM_FONT: Font = preload("res://assets/fonts/monogram.ttf")

# =============================================================================
# STATE
# =============================================================================

## Currently selected slot: {section: "active"|"reserve", index: int}
var _selection: Dictionary = {"section": "active", "index": 0}

## First selected for swap (null if not in swap mode)
var _swap_source: Dictionary = {}

## Whether the panel is actively accepting input
var _active: bool = false

# =============================================================================
# UI REFERENCES
# =============================================================================

var _panel: PanelContainer = null
var _title_label: Label = null
var _active_grid: GridContainer = null
var _reserve_container: VBoxContainer = null
var _info_panel: PanelContainer = null
var _info_name: Label = null
var _info_class: Label = null
var _info_level: Label = null
var _hint_label: Label = null
var _active_slots: Array[PanelContainer] = []
var _reserve_slots: Array[PanelContainer] = []

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_build_ui()
	visible = false
	set_process_input(false)


func _input(event: InputEvent) -> void:
	if not _active:
		return

	var handled: bool = false

	if event.is_action_pressed("ui_up"):
		_move_selection(Vector2i(0, -1))
		handled = true
	elif event.is_action_pressed("ui_down"):
		_move_selection(Vector2i(0, 1))
		handled = true
	elif event.is_action_pressed("ui_left"):
		_move_selection(Vector2i(-1, 0))
		handled = true
	elif event.is_action_pressed("ui_right"):
		_move_selection(Vector2i(1, 0))
		handled = true
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("sf_confirm"):
		_confirm_selection()
		handled = true
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel"):
		_cancel()
		handled = true

	if handled:
		get_viewport().set_input_as_handled()


# =============================================================================
# UI BUILDING
# =============================================================================

func _build_ui() -> void:
	# Fill screen for centering
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Main panel
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(400, 300)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PANEL_BG
	panel_style.border_color = COLOR_PANEL_BORDER
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# Main content
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_panel.add_child(content)

	# Title
	_title_label = Label.new()
	_title_label.text = "Party Management"
	_title_label.add_theme_font_override("font", MONOGRAM_FONT)
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", COLOR_PANEL_BORDER)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title_label)

	# Separator
	var sep: HSeparator = HSeparator.new()
	content.add_child(sep)

	# Main split: Active grid | Reserves + Info
	var split: HBoxContainer = HBoxContainer.new()
	split.add_theme_constant_override("separation", 16)
	content.add_child(split)

	# Left: Active party section
	var active_section: VBoxContainer = VBoxContainer.new()
	active_section.add_theme_constant_override("separation", 4)
	split.add_child(active_section)

	var active_label: Label = Label.new()
	active_label.text = "Active Party"
	active_label.add_theme_font_override("font", MONOGRAM_FONT)
	active_label.add_theme_font_size_override("font_size", 16)
	active_label.add_theme_color_override("font_color", COLOR_TEXT_NORMAL)
	active_section.add_child(active_label)

	_active_grid = GridContainer.new()
	_active_grid.columns = ACTIVE_COLS
	_active_grid.add_theme_constant_override("h_separation", SLOT_SPACING)
	_active_grid.add_theme_constant_override("v_separation", SLOT_SPACING)
	active_section.add_child(_active_grid)

	# Create active slots
	for i: int in range(ACTIVE_COLS * ACTIVE_ROWS):
		var slot: PanelContainer = _create_slot(i, true)
		_active_grid.add_child(slot)
		_active_slots.append(slot)

	# Right side: Reserves + Info
	var right_section: VBoxContainer = VBoxContainer.new()
	right_section.add_theme_constant_override("separation", 8)
	right_section.custom_minimum_size.x = 140
	split.add_child(right_section)

	var reserve_label: Label = Label.new()
	reserve_label.text = "Reserves"
	reserve_label.add_theme_font_override("font", MONOGRAM_FONT)
	reserve_label.add_theme_font_size_override("font_size", 16)
	reserve_label.add_theme_color_override("font_color", COLOR_TEXT_NORMAL)
	right_section.add_child(reserve_label)

	# Reserve slots container (scrollable if needed later)
	_reserve_container = VBoxContainer.new()
	_reserve_container.add_theme_constant_override("separation", SLOT_SPACING)
	right_section.add_child(_reserve_container)

	# Info panel
	_info_panel = PanelContainer.new()
	_info_panel.custom_minimum_size = Vector2(130, 70)
	var info_style: StyleBoxFlat = StyleBoxFlat.new()
	info_style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	info_style.set_border_width_all(1)
	info_style.border_color = COLOR_PANEL_BORDER
	info_style.content_margin_left = 8
	info_style.content_margin_right = 8
	info_style.content_margin_top = 6
	info_style.content_margin_bottom = 6
	_info_panel.add_theme_stylebox_override("panel", info_style)
	right_section.add_child(_info_panel)

	var info_content: VBoxContainer = VBoxContainer.new()
	info_content.add_theme_constant_override("separation", 2)
	_info_panel.add_child(info_content)

	_info_name = Label.new()
	_info_name.text = "---"
	_info_name.add_theme_font_override("font", MONOGRAM_FONT)
	_info_name.add_theme_font_size_override("font_size", 16)
	_info_name.add_theme_color_override("font_color", COLOR_TEXT_SELECTED)
	info_content.add_child(_info_name)

	_info_class = Label.new()
	_info_class.text = ""
	_info_class.add_theme_font_override("font", MONOGRAM_FONT)
	_info_class.add_theme_font_size_override("font_size", 16)
	_info_class.add_theme_color_override("font_color", COLOR_TEXT_NORMAL)
	info_content.add_child(_info_class)

	_info_level = Label.new()
	_info_level.text = ""
	_info_level.add_theme_font_override("font", MONOGRAM_FONT)
	_info_level.add_theme_font_size_override("font_size", 16)
	_info_level.add_theme_color_override("font_color", COLOR_TEXT_NORMAL)
	info_content.add_child(_info_level)

	# Hint text at bottom
	var sep2: HSeparator = HSeparator.new()
	content.add_child(sep2)

	_hint_label = Label.new()
	_hint_label.text = "Select character to swap"
	_hint_label.add_theme_font_override("font", MONOGRAM_FONT)
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", COLOR_TEXT_DISABLED)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_hint_label)


func _create_slot(index: int, is_active: bool) -> PanelContainer:
	var slot: PanelContainer = PanelContainer.new()
	slot.custom_minimum_size = SLOT_SIZE

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_SLOT_EMPTY
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.3, 0.35, 0.8)
	style.set_corner_radius_all(2)
	slot.add_theme_stylebox_override("panel", style)

	# Character name label (centered)
	var label: Label = Label.new()
	label.name = "NameLabel"
	label.text = ""
	label.add_theme_font_override("font", MONOGRAM_FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", COLOR_TEXT_NORMAL)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(label)

	# Store metadata
	slot.set_meta("slot_index", index)
	slot.set_meta("is_active", is_active)

	return slot


# =============================================================================
# PANEL CONTROL
# =============================================================================

## Show the panel and populate with current party data
func show_panel() -> void:
	_selection = {"section": "active", "index": 0}
	_swap_source = {}
	_refresh_slots()
	_update_selection_visual()
	_update_info_panel()
	visible = true
	_active = true
	set_process_input(true)

	if AudioManager:
		AudioManager.play_sfx("menu_open", AudioManager.SFXCategory.UI)


## Hide the panel
func hide_panel() -> void:
	visible = false
	_active = false
	set_process_input(false)


func _refresh_slots() -> void:
	if not PartyManager:
		return

	var active_party: Array[CharacterData] = PartyManager.get_active_party()
	var reserve_party: Array[CharacterData] = PartyManager.get_reserve_party()

	# Update active slots
	for i: int in range(_active_slots.size()):
		var slot: PanelContainer = _active_slots[i]
		var label_node: Node = slot.get_node("NameLabel")
		var label: Label = label_node as Label if label_node is Label else null
		if label == null:
			continue

		if i < active_party.size():
			var character: CharacterData = active_party[i]
			label.text = _truncate_name(character.character_name, 6)
			slot.set_meta("character", character)
			_set_slot_style(slot, false, i == 0)  # Hero check for slot 0
		else:
			label.text = ""
			slot.set_meta("character", null)
			_set_slot_style(slot, true, false)

	# Clear and rebuild reserve slots
	for child: Node in _reserve_container.get_children():
		child.queue_free()
	_reserve_slots.clear()

	for i: int in range(reserve_party.size()):
		var character: CharacterData = reserve_party[i]
		var slot: PanelContainer = _create_reserve_slot(i, character)
		_reserve_container.add_child(slot)
		_reserve_slots.append(slot)

	# If no reserves, show placeholder
	if reserve_party.is_empty():
		var placeholder: Label = Label.new()
		placeholder.text = "(none)"
		placeholder.add_theme_font_override("font", MONOGRAM_FONT)
		placeholder.add_theme_font_size_override("font_size", 16)
		placeholder.add_theme_color_override("font_color", COLOR_TEXT_DISABLED)
		_reserve_container.add_child(placeholder)


func _create_reserve_slot(index: int, character: CharacterData) -> PanelContainer:
	var slot: PanelContainer = PanelContainer.new()
	slot.custom_minimum_size = Vector2(120, 28)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_SLOT_FILLED
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.3, 0.35, 0.8)
	style.set_corner_radius_all(2)
	slot.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.name = "NameLabel"
	label.text = _truncate_name(character.character_name, 12)
	label.add_theme_font_override("font", MONOGRAM_FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", COLOR_TEXT_NORMAL)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(label)

	slot.set_meta("slot_index", index)
	slot.set_meta("is_active", false)
	slot.set_meta("character", character)

	return slot


func _set_slot_style(slot: PanelContainer, is_empty: bool, is_hero: bool) -> void:
	var style: StyleBoxFlat = slot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if is_hero:
		style.bg_color = COLOR_SLOT_HERO
	elif is_empty:
		style.bg_color = COLOR_SLOT_EMPTY
	else:
		style.bg_color = COLOR_SLOT_FILLED
	slot.add_theme_stylebox_override("panel", style)


func _truncate_name(name: String, max_len: int) -> String:
	if name.length() <= max_len:
		return name
	return name.substr(0, max_len - 1) + "."


# =============================================================================
# SELECTION & NAVIGATION
# =============================================================================

func _move_selection(direction: Vector2i) -> void:
	var active_count: int = PartyManager.get_active_count() if PartyManager else 0
	var reserve_count: int = PartyManager.get_reserve_count() if PartyManager else 0

	var current_section: String = DictUtils.get_string(_selection, "section", "active")
	var current_idx: int = DictUtils.get_int(_selection, "index", 0)
	if current_section == "active":
		var col: int = current_idx % ACTIVE_COLS
		var row: int = current_idx / ACTIVE_COLS

		# Handle movement
		if direction.x > 0:
			# Move right
			if col == ACTIVE_COLS - 1 and reserve_count > 0:
				# Jump to reserves
				_selection = {"section": "reserve", "index": 0}
			else:
				var new_idx: int = mini(current_idx + 1, active_count - 1)
				_selection["index"] = new_idx
		elif direction.x < 0:
			_selection["index"] = maxi(0, current_idx - 1)
		elif direction.y > 0:
			var new_idx: int = current_idx + ACTIVE_COLS
			if new_idx < active_count:
				_selection["index"] = new_idx
		elif direction.y < 0:
			var new_idx: int = current_idx - ACTIVE_COLS
			if new_idx >= 0:
				_selection["index"] = new_idx

	else:  # reserve section
		if direction.x < 0:
			# Jump to active section (rightmost column)
			var active_count_clamped: int = maxi(1, active_count)
			var target_row: int = mini(current_idx, ACTIVE_ROWS - 1)
			var target_idx: int = (target_row * ACTIVE_COLS) + (ACTIVE_COLS - 1)
			_selection = {"section": "active", "index": mini(target_idx, active_count_clamped - 1)}
		elif direction.y > 0:
			_selection["index"] = mini(current_idx + 1, reserve_count - 1)
		elif direction.y < 0:
			_selection["index"] = maxi(0, current_idx - 1)

	_update_selection_visual()
	_update_info_panel()

	if AudioManager:
		AudioManager.play_sfx("cursor_move", AudioManager.SFXCategory.UI)


func _update_selection_visual() -> void:
	# Reset all slot borders
	for slot: PanelContainer in _active_slots:
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		style.border_color = Color(0.3, 0.3, 0.35, 0.8)
		slot.add_theme_stylebox_override("panel", style)

	for slot: PanelContainer in _reserve_slots:
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		style.border_color = Color(0.3, 0.3, 0.35, 0.8)
		slot.add_theme_stylebox_override("panel", style)

	# Highlight swap source if set
	if not _swap_source.is_empty():
		var source_slot: PanelContainer = _get_slot(_swap_source)
		if source_slot:
			var style: StyleBoxFlat = source_slot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
			style.border_color = COLOR_TEXT_SELECTED
			source_slot.add_theme_stylebox_override("panel", style)

	# Highlight current selection
	var selected_slot: PanelContainer = _get_slot(_selection)
	if selected_slot:
		var style: StyleBoxFlat = selected_slot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		style.border_color = COLOR_SLOT_SELECTED
		style.set_border_width_all(3)
		selected_slot.add_theme_stylebox_override("panel", style)


func _get_slot(sel: Dictionary) -> PanelContainer:
	var section: String = DictUtils.get_string(sel, "section", "")
	var index: int = DictUtils.get_int(sel, "index", 0)
	if section == "active" and index < _active_slots.size():
		return _active_slots[index]
	elif section == "reserve" and index < _reserve_slots.size():
		return _reserve_slots[index]
	return null


func _update_info_panel() -> void:
	var slot: PanelContainer = _get_slot(_selection)
	if not slot:
		_info_name.text = "---"
		_info_class.text = ""
		_info_level.text = ""
		return

	var character: CharacterData = slot.get_meta("character") if slot.has_meta("character") else null
	if not character:
		_info_name.text = "(empty)"
		_info_class.text = ""
		_info_level.text = ""
		return

	_info_name.text = character.character_name
	_info_class.text = character.character_class.display_name if character.character_class else "Unknown"
	_info_level.text = "Level %d" % character.starting_level

	# Update hint based on state
	var sel_section: String = DictUtils.get_string(_selection, "section", "")
	var sel_index: int = DictUtils.get_int(_selection, "index", 0)
	if _swap_source.is_empty():
		if sel_section == "active" and sel_index == 0:
			_hint_label.text = "Hero cannot be moved"
		else:
			_hint_label.text = "Press Z to select for swap"
	else:
		_hint_label.text = "Select target to swap with"


# =============================================================================
# ACTIONS
# =============================================================================

func _confirm_selection() -> void:
	var slot: PanelContainer = _get_slot(_selection)
	if not slot:
		return

	var character: CharacterData = slot.get_meta("character") if slot.has_meta("character") else null

	# If selecting empty slot, ignore
	if not character:
		if AudioManager:
			AudioManager.play_sfx("error", AudioManager.SFXCategory.UI)
		return

	# Cannot select hero for swap
	var sel_section: String = DictUtils.get_string(_selection, "section", "")
	var sel_index: int = DictUtils.get_int(_selection, "index", 0)
	if sel_section == "active" and sel_index == 0:
		if AudioManager:
			AudioManager.play_sfx("error", AudioManager.SFXCategory.UI)
		return

	# First selection - set swap source
	if _swap_source.is_empty():
		_swap_source = _selection.duplicate()
		_update_selection_visual()
		_update_info_panel()
		if AudioManager:
			AudioManager.play_sfx("menu_select", AudioManager.SFXCategory.UI)
		return

	# Second selection - perform swap
	var swap_section: String = DictUtils.get_string(_swap_source, "section", "")
	var swap_index: int = DictUtils.get_int(_swap_source, "index", 0)
	if sel_section == swap_section and sel_index == swap_index:
		# Selected same slot, cancel swap mode
		_swap_source = {}
		_update_selection_visual()
		_update_info_panel()
		return

	_perform_swap()


func _perform_swap() -> void:
	if not PartyManager:
		return

	var result: Dictionary = {"success": false, "error": "Unknown error"}

	# Get typed values from dictionaries
	var swap_section: String = DictUtils.get_string(_swap_source, "section", "")
	var swap_index: int = DictUtils.get_int(_swap_source, "index", 0)
	var sel_section: String = DictUtils.get_string(_selection, "section", "")
	var sel_index: int = DictUtils.get_int(_selection, "index", 0)

	# Determine swap type
	if swap_section == "active" and sel_section == "reserve":
		# Active -> Reserve swap
		result = PartyManager.swap_active_reserve(swap_index, sel_index)
	elif swap_section == "reserve" and sel_section == "active":
		# Reserve -> Active swap
		result = PartyManager.swap_active_reserve(sel_index, swap_index)
	elif swap_section == "active" and sel_section == "active":
		# Swap within active (just reorder)
		result = _swap_within_active(swap_index, sel_index)
	elif swap_section == "reserve" and sel_section == "reserve":
		# Swap within reserve (just reorder)
		result = _swap_within_reserve(swap_index, sel_index)

	var success: bool = DictUtils.get_bool(result, "success", false)
	if success:
		if AudioManager:
			AudioManager.play_sfx("menu_select", AudioManager.SFXCategory.UI)
		party_changed.emit()
	else:
		if AudioManager:
			AudioManager.play_sfx("error", AudioManager.SFXCategory.UI)
		var error_msg: String = DictUtils.get_string(result, "error", "Unknown error")
		push_warning("PartyManagementPanel: Swap failed - %s" % error_msg)

	# Clear swap mode and refresh
	_swap_source = {}
	_refresh_slots()
	_update_selection_visual()
	_update_info_panel()


func _swap_within_active(idx1: int, idx2: int) -> Dictionary:
	if not PartyManager:
		return {"success": false, "error": "No PartyManager"}

	return PartyManager.swap_within_active(idx1, idx2)


func _swap_within_reserve(idx1: int, idx2: int) -> Dictionary:
	if not PartyManager:
		return {"success": false, "error": "No PartyManager"}

	return PartyManager.swap_within_reserve(idx1, idx2)


func _cancel() -> void:
	if not _swap_source.is_empty():
		# Cancel swap mode
		_swap_source = {}
		_update_selection_visual()
		_update_info_panel()
		if AudioManager:
			AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)
	else:
		# Close panel
		if AudioManager:
			AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)
		close_requested.emit()
