## SpellMenu - Shining Force style battle spell selection menu
##
## Displays character's available spells for battle casting.
## Features keyboard/mouse navigation, spell descriptions, MP costs, and smart defaults.
## Follows ItemMenu patterns for session IDs and signal handling.
class_name SpellMenu
extends Control

## Signals - session_id prevents stale signals from previous turns
signal spell_selected(ability: AbilityData, session_id: int)
signal menu_cancelled(session_id: int)

## UI element references (built dynamically)
var _spell_labels: Array[Label] = []
var _mp_labels: Array[Label] = []  ## MP cost display per spell
var _description_label: Label = null
var _header_label: Label = null
var _panel: ColorRect = null
var _container: VBoxContainer = null

## Spell data
var _abilities: Array[AbilityData] = []  ## Available abilities for this character
var _current_mp: int = 0  ## Character's current MP

## Current selection
var selected_index: int = 0

## Session ID - stored when menu opens, emitted with signals to prevent stale signals
var _menu_session_id: int = -1

## Hover tracking
var _hover_index: int = -1

## Colors - use centralized UIColors class (except unique border color)
const BORDER_COLOR: Color = Color(0.8, 0.8, 0.9, 1.0)  ## Unique light border for spell menu


func _ready() -> void:
	# Build the UI structure
	_build_ui()

	# Hide by default
	visible = false
	set_process_input(false)
	set_process(false)


## Build the menu UI dynamically
func _build_ui() -> void:
	# Main container with border
	var border: ColorRect = ColorRect.new()
	border.name = "Border"
	border.color = BORDER_COLOR
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(border)

	# Inner panel
	_panel = ColorRect.new()
	_panel.name = "InnerPanel"
	_panel.color = UIColors.PANEL_BG
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 2.0
	_panel.offset_top = 2.0
	_panel.offset_right = -2.0
	_panel.offset_bottom = -2.0
	border.add_child(_panel)

	# VBox for layout
	_container = VBoxContainer.new()
	_container.name = "VBoxContainer"
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.offset_left = 8.0
	_container.offset_top = 8.0
	_container.offset_right = -8.0
	_container.offset_bottom = -8.0
	_panel.add_child(_container)

	# Header label
	_header_label = Label.new()
	_header_label.name = "Header"
	_header_label.text = "Magic"
	_header_label.add_theme_font_size_override("font_size", 16)
	_header_label.modulate = UIColors.MENU_BRIGHT
	_container.add_child(_header_label)

	# Separator
	var separator: HSeparator = HSeparator.new()
	separator.add_theme_constant_override("separation", 4)
	_container.add_child(separator)

	# Spell labels will be created dynamically when showing menu

	# Description label at bottom (will be added after spell labels)
	_description_label = Label.new()
	_description_label.name = "Description"
	_description_label.text = ""
	_description_label.add_theme_font_size_override("font_size", 16)
	_description_label.modulate = Color(0.7, 0.7, 0.7, 1.0)
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD


## Create spell slot labels based on number of spells
func _create_spell_labels(slot_count: int) -> void:
	# Clear existing labels
	for label: Label in _spell_labels:
		if is_instance_valid(label):
			label.queue_free()
	_spell_labels.clear()

	for label: Label in _mp_labels:
		if is_instance_valid(label):
			label.queue_free()
	_mp_labels.clear()

	# Remove description label temporarily (we'll re-add at bottom)
	if _description_label.get_parent() == _container:
		_container.remove_child(_description_label)

	# Create new labels for each spell
	for i: int in range(slot_count):
		# HBox for spell name + MP cost
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.name = "SpellRow%d" % i
		_container.add_child(hbox)

		# Spell name label
		var name_label: Label = Label.new()
		name_label.name = "SpellSlot%d" % i
		name_label.text = "Spell"
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.modulate = UIColors.MENU_BRIGHT
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_label)
		_spell_labels.append(name_label)

		# MP cost label
		var mp_label: Label = Label.new()
		mp_label.name = "MPCost%d" % i
		mp_label.text = "0 MP"
		mp_label.add_theme_font_size_override("font_size", 16)
		mp_label.modulate = UIColors.MP_AVAILABLE
		mp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(mp_label)
		_mp_labels.append(mp_label)

	# Add separator before description
	var desc_sep: HSeparator = HSeparator.new()
	desc_sep.name = "DescSeparator"
	desc_sep.add_theme_constant_override("separation", 4)
	_container.add_child(desc_sep)

	# Re-add description at bottom
	_container.add_child(_description_label)


func _process(_delta: float) -> void:
	if not visible:
		return

	var new_hover: int = _get_label_index_at_position(get_global_mouse_position())
	if new_hover == _hover_index:
		return

	_hover_index = new_hover
	if new_hover != -1 and new_hover != selected_index:
		AudioManager.play_sfx("cursor_hover", AudioManager.SFXCategory.UI)
	_update_selection_visual()


## Get the index of the label at the given position, or -1 if none
func _get_label_index_at_position(pos: Vector2) -> int:
	for i: int in range(_spell_labels.size()):
		if _spell_labels[i].get_global_rect().has_point(pos):
			return i
	return -1


## Show menu with character's available spells
## @param abilities: Array of AbilityData for the character
## @param current_mp: Character's current MP
## @param session_id: Turn session ID from InputManager
func show_spells(abilities: Array[AbilityData], current_mp: int, session_id: int) -> void:
	_menu_session_id = session_id
	_hover_index = -1
	_abilities = abilities
	_current_mp = current_mp

	# Create labels if needed
	if _spell_labels.size() != abilities.size():
		_create_spell_labels(abilities.size())

	# Populate spell labels
	_populate_spell_labels()

	# Smart default selection
	_select_smart_default()

	# Update visuals
	_update_selection_visual()
	_update_description()

	# Size the menu appropriately
	_resize_menu()

	# Show menu
	visible = true
	set_process_input(true)
	set_process(true)


## Populate spell labels with ability data
func _populate_spell_labels() -> void:
	for i: int in range(_spell_labels.size()):
		var spell_label: Label = _spell_labels[i]
		var mp_label: Label = _mp_labels[i]
		if i < _abilities.size() and _abilities[i]:
			var ability: AbilityData = _abilities[i]
			spell_label.text = ability.ability_name
			mp_label.text = "%d MP" % ability.mp_cost

			# Color MP cost based on whether castable
			if ability.mp_cost <= _current_mp:
				mp_label.modulate = UIColors.MP_AVAILABLE
			else:
				mp_label.modulate = UIColors.RESULT_ERROR
		else:
			spell_label.text = "(None)"
			mp_label.text = ""


## Check if a spell at index is castable (has enough MP)
func _is_spell_castable(index: int) -> bool:
	if index < 0 or index >= _abilities.size():
		return false

	var ability: AbilityData = _abilities[index]
	if not ability:
		return false

	return ability.mp_cost <= _current_mp


## Check if any castable spells exist
func _has_any_castable_spells() -> bool:
	for i: int in range(_abilities.size()):
		if _is_spell_castable(i):
			return true
	return false


## Smart default selection based on spell availability
func _select_smart_default() -> void:
	# Select first castable spell
	for i: int in range(_abilities.size()):
		if _is_spell_castable(i):
			selected_index = i
			return

	# Fallback to first slot (even if not castable, for visual consistency)
	selected_index = 0


## Update visual highlighting
func _update_selection_visual() -> void:
	for i: int in range(_spell_labels.size()):
		var label: Label = _spell_labels[i]
		var color: Color = _get_spell_color(i)
		label.modulate = color

		if i == selected_index:
			label.add_theme_color_override("font_color", color)
		else:
			label.remove_theme_color_override("font_color")


## Get the display color for a spell slot
func _get_spell_color(index: int) -> Color:
	if index == selected_index:
		return UIColors.MENU_SELECTED
	if index == _hover_index:
		return UIColors.MENU_HOVER
	if _is_spell_castable(index):
		return UIColors.MENU_BRIGHT
	return UIColors.MENU_DISABLED


## Update description label based on selected spell
func _update_description() -> void:
	if selected_index < 0 or selected_index >= _abilities.size():
		_description_label.text = ""
		return

	var ability: AbilityData = _abilities[selected_index]
	if not ability:
		_description_label.text = ""
		return

	_description_label.text = _build_spell_description(ability)


## Build description text for a spell
func _build_spell_description(ability: AbilityData) -> String:
	var parts: Array[String] = []

	# Effect description based on type
	parts.append(_get_ability_type_text(ability))

	# Range info if not self-only
	var range_text: String = _get_range_text(ability)
	if not range_text.is_empty():
		parts[0] += " " + range_text

	# Custom description
	if not ability.description.is_empty():
		parts.append(ability.description)

	# MP warning
	if not _is_spell_castable(selected_index):
		parts.append("[Not enough MP]")

	return "\n".join(parts)


## Get the effect text for an ability type
func _get_ability_type_text(ability: AbilityData) -> String:
	match ability.ability_type:
		AbilityData.AbilityType.HEAL:
			return "Heals: %d HP" % ability.potency
		AbilityData.AbilityType.ATTACK:
			return "Damage: %d" % ability.potency
		AbilityData.AbilityType.SUPPORT:
			return "Buff effect"
		AbilityData.AbilityType.DEBUFF:
			return "Debuff effect"
		AbilityData.AbilityType.STATUS:
			return "Status effect"
	return "Special effect"


## Get range text for an ability
func _get_range_text(ability: AbilityData) -> String:
	if ability.target_type == AbilityData.TargetType.SELF:
		return ""
	if ability.min_range == ability.max_range:
		return "(Range: %d)" % ability.max_range
	return "(Range: %d-%d)" % [ability.min_range, ability.max_range]


## Resize menu to fit contents
func _resize_menu() -> void:
	# Base size
	var width: float = 220.0
	var height: float = 60.0  # Header + separator

	# Add height for each spell slot
	height += _spell_labels.size() * 24.0

	# Add height for description
	height += 50.0

	custom_minimum_size = Vector2(width, height)
	size = custom_minimum_size


## Hide menu
func hide_menu() -> void:
	set_process_input(false)
	set_process(false)
	visible = false
	_hover_index = -1


## Reset menu to clean state
func reset_menu() -> void:
	set_process_input(false)
	set_process(false)

	_abilities.clear()
	_current_mp = 0
	selected_index = 0
	_menu_session_id = -1
	_hover_index = -1

	visible = false


## Handle input
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if _handle_mouse_click(event):
		return

	_handle_keyboard_input(event)


## Handle mouse click input, returns true if handled
func _handle_mouse_click(event: InputEvent) -> bool:
	if not event is InputEventMouseButton:
		return false

	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return false

	var clicked_index: int = _get_label_index_at_position(get_global_mouse_position())
	if clicked_index >= 0:
		selected_index = clicked_index
		_update_selection_visual()
		_update_description()
		_try_confirm_selection()
		get_viewport().set_input_as_handled()
		return true

	return false


## Handle keyboard navigation input
func _handle_keyboard_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_try_confirm_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel"):
		_cancel_menu()
		get_viewport().set_input_as_handled()


## Move selection up or down
func _move_selection(direction: int) -> void:
	var start_index: int = selected_index

	# Loop through spells to find next one
	for _i: int in range(_spell_labels.size()):
		selected_index = wrapi(selected_index + direction, 0, _spell_labels.size())

		# Allow selecting any slot (for visual feedback), even uncastable ones
		if selected_index != start_index:
			AudioManager.play_sfx("cursor_move", AudioManager.SFXCategory.UI)
			_update_selection_visual()
			_update_description()
			return


## Try to confirm current selection
func _try_confirm_selection() -> void:
	# Safety checks
	if not is_processing_input():
		return
	if not visible:
		return

	# Check if selected spell is castable
	if not _is_spell_castable(selected_index):
		# Play error sound - not enough MP
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		return

	# Get the ability ID
	var ability: AbilityData = _abilities[selected_index]
	if not ability or ability.ability_id.is_empty():
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		return

	# Play confirm sound
	AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)

	# Emit selection signal before hiding
	var emit_session_id: int = _menu_session_id
	spell_selected.emit(ability, emit_session_id)
	hide_menu()


## Cancel menu and return to action menu
func _cancel_menu() -> void:
	# Play cancel sound
	AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)

	# Emit cancel signal before hiding
	var emit_session_id: int = _menu_session_id
	menu_cancelled.emit(emit_session_id)
	hide_menu()
