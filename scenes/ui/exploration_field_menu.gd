class_name ExplorationFieldMenu
extends Control

## ExplorationFieldMenu - SF2-style field menu for exploration mode
##
## Appears when player presses confirm with no interaction target,
## or presses cancel (B button) during exploration.
## Provides quick access to: Item, Magic, Search, Member
##
## SF2-authentic behavior:
## - Vertical list layout (not radial) for multi-input support
## - INSTANT cursor movement (no animation delays)
## - Cursor wrapping (down from bottom -> top)
## - "Member" terminology (not "Status" - that's Caravan menu)
## - Magic option HIDDEN if no party member has field magic (Egress/Detox)
##
## Mod-extensible via mod.json field_menu_options (Phase 4)

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when an option is selected
signal option_selected(option_id: String)

## Emitted when menu is cancelled/closed
signal close_requested()

## Emitted when item menu is requested
signal item_requested()

## Emitted when magic menu is requested (Phase 2)
signal magic_requested()

## Emitted when search action is requested
signal search_requested()

## Emitted when member/status view is requested
signal member_requested()

## Emitted when a custom mod option is selected (Phase 4)
signal custom_option_requested(option_id: String, scene_path: String)

# =============================================================================
# ENUMS
# =============================================================================

enum MenuOption {
	ITEM,
	MAGIC,
	SEARCH,
	MEMBER  ## SF2 terminology - "Status" is used in Caravan menu
}

# =============================================================================
# CONSTANTS - VISUAL SPECIFICATIONS (SF2-authentic with modern polish)
# =============================================================================

const PANEL_MIN_SIZE: Vector2 = Vector2(100, 80)
const PANEL_BG: Color = Color(0.1, 0.1, 0.15, 0.95)
const PANEL_BORDER: Color = Color(0.5, 0.5, 0.6, 1.0)
const PANEL_BORDER_WIDTH: int = 2
const PANEL_CORNER_RADIUS: int = 4  # Match CaravanMainMenu

# Padding/margins to match ItemActionMenu
const CONTENT_MARGIN_TOP: int = 8
const CONTENT_MARGIN_BOTTOM: int = 8
const CONTENT_MARGIN_LEFT: int = 8
const CONTENT_MARGIN_RIGHT: int = 8
const OPTION_SEPARATION: int = 2  # Vertical spacing between options

# Text colors (consistent with existing menus)
const TEXT_NORMAL: Color = Color(0.85, 0.85, 0.85)
const TEXT_SELECTED: Color = Color(1.0, 0.95, 0.4)  # Yellow highlight
const TEXT_DISABLED: Color = Color(0.4, 0.4, 0.4)
const TEXT_HOVER: Color = Color(0.95, 0.95, 0.85)

# Cursor
const CURSOR_CHAR: String = ">"
const CURSOR_SPACING: int = 8  # Space between cursor and text

# Font size
const FONT_SIZE: int = 16

# Menu animation timing (SF2-authentic: fast or instant)
const MENU_OPEN_DURATION: float = 0.08  # seconds
const MENU_CLOSE_DURATION: float = 0.05  # seconds

# Cursor Movement: INSTANT (no animation - SF2 purist requirement)
const CURSOR_MOVE_DURATION: float = 0.0

# Positioning
const MENU_OFFSET: Vector2 = Vector2(40, 20)  # Right and slightly down from hero
const EDGE_PADDING: float = 8.0

# Known field-usable ability IDs (SF2 authentic - only Egress and Detox)
const FIELD_USABLE_ABILITY_IDS: Array[String] = ["egress", "detox"]

# =============================================================================
# DEFAULT OPTIONS
# =============================================================================

const DEFAULT_OPTIONS: Array[Dictionary] = [
	{
		"id": "item",
		"label": "Item",
		"description": "View party inventory",
		"enabled": true,
		"is_custom": false,
		"action": MenuOption.ITEM
	},
	{
		"id": "magic",
		"label": "Magic",
		"description": "Cast field spells",
		"enabled": true,  # Dynamic: HIDE (not grey out) if no party member has field magic
		"is_custom": false,
		"action": MenuOption.MAGIC
	},
	{
		"id": "search",
		"label": "Search",
		"description": "Examine this area",
		"enabled": true,
		"is_custom": false,
		"action": MenuOption.SEARCH
	},
	{
		"id": "member",
		"label": "Member",  # SF2 terminology - NOT "Status"
		"description": "View party members",
		"enabled": true,
		"is_custom": false,
		"action": MenuOption.MEMBER
	}
]

# =============================================================================
# STATE
# =============================================================================

## Currently selected option index
var _selected_index: int = 0

## Whether the menu is actively accepting input
var _is_active: bool = false

## Dynamic menu options (populated based on party state)
var _menu_options: Array[Dictionary] = []

## Hover tracking for mouse support
var _hover_index: int = -1

## Position where menu was opened (for Search)
var _hero_grid_position: Vector2i = Vector2i.ZERO

## Hero screen position (for menu positioning)
var _hero_screen_position: Vector2 = Vector2.ZERO

# =============================================================================
# UI REFERENCES
# =============================================================================

var _panel: PanelContainer = null
var _options_container: VBoxContainer = null
var _option_labels: Array[Label] = []

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_build_ui()
	visible = false
	set_process_input(false)
	set_process(false)


func _build_ui() -> void:
	# This control is the root - position it relative to parent (CanvasLayer)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Panel container
	_panel = PanelContainer.new()
	_panel.name = "FieldMenuPanel"
	_panel.custom_minimum_size = PANEL_MIN_SIZE

	var panel_style: StyleBoxFlat = UIUtils.create_panel_style(PANEL_BG, PANEL_BORDER, PANEL_BORDER_WIDTH, PANEL_CORNER_RADIUS)
	panel_style.content_margin_top = CONTENT_MARGIN_TOP
	panel_style.content_margin_bottom = CONTENT_MARGIN_BOTTOM
	panel_style.content_margin_left = CONTENT_MARGIN_LEFT
	panel_style.content_margin_right = CONTENT_MARGIN_RIGHT
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# Options container
	_options_container = VBoxContainer.new()
	_options_container.name = "OptionsContainer"
	_options_container.add_theme_constant_override("separation", OPTION_SEPARATION)
	_panel.add_child(_options_container)


func _process(_delta: float) -> void:
	# Track mouse hover for visual feedback
	if not visible or not _is_active:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	var new_hover: int = -1

	for i: int in range(_option_labels.size()):
		var label: Label = _option_labels[i]
		var label_rect: Rect2 = label.get_global_rect()
		if label_rect.has_point(mouse_pos):
			new_hover = i
			break

	# Update hover state if changed
	if new_hover != _hover_index:
		_hover_index = new_hover
		if new_hover != -1 and new_hover != _selected_index:
			AudioManager.play_sfx("cursor_hover", AudioManager.SFXCategory.UI)
		_update_selection_visual()


# =============================================================================
# PUBLIC API
# =============================================================================

## Show the field menu at the hero's position
## @param hero_grid_pos: Grid position where menu was opened (for Search)
## @param hero_screen_pos: Screen position of the hero (for menu positioning)
func show_menu(hero_grid_pos: Vector2i, hero_screen_pos: Vector2 = Vector2.ZERO) -> void:
	_hero_grid_position = hero_grid_pos
	_hero_screen_position = hero_screen_pos
	_hover_index = -1

	# Build menu options (hides Magic if no field spells available)
	_build_menu_options()

	if _menu_options.is_empty():
		push_warning("ExplorationFieldMenu: No menu options available")
		return

	# Rebuild option labels
	_rebuild_option_labels()

	# Select first option (SF2-authentic: default to first)
	_selected_index = 0
	_update_selection_visual()

	# Position the menu near the hero
	_position_menu()

	# Show menu with fast animation
	_is_active = true
	visible = true
	set_process_input(true)
	set_process(true)

	# Animate open
	if MENU_OPEN_DURATION > 0:
		_panel.modulate.a = 0.0
		_panel.scale = Vector2(0.9, 0.9)
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(_panel, "modulate:a", 1.0, MENU_OPEN_DURATION).set_ease(Tween.EASE_OUT)
		tween.tween_property(_panel, "scale", Vector2.ONE, MENU_OPEN_DURATION).set_ease(Tween.EASE_OUT)
	else:
		_panel.modulate.a = 1.0
		_panel.scale = Vector2.ONE

	AudioManager.play_sfx("menu_open", AudioManager.SFXCategory.UI)


## Hide the menu
func hide_menu() -> void:
	_is_active = false
	set_process_input(false)
	set_process(false)
	_hover_index = -1

	# Animate close
	if MENU_CLOSE_DURATION > 0 and visible:
		var tween: Tween = create_tween()
		tween.tween_property(_panel, "modulate:a", 0.0, MENU_CLOSE_DURATION).set_ease(Tween.EASE_IN)
		await tween.finished
		if not is_instance_valid(self):
			return

	visible = false


## Check if menu is currently active
func is_menu_active() -> bool:
	return _is_active


## Get the grid position where menu was opened (for Search)
func get_hero_grid_position() -> Vector2i:
	return _hero_grid_position


# =============================================================================
# MENU OPTIONS BUILDING
# =============================================================================

## Build the menu options list, hiding unavailable options
func _build_menu_options() -> void:
	_menu_options.clear()

	# Check if party has field magic
	var has_field_magic: bool = _party_has_field_magic()

	for option: Dictionary in DEFAULT_OPTIONS:
		var opt_copy: Dictionary = option.duplicate()

		# SF2-authentic: HIDE Magic option if no party member has field spells
		# Don't grey it out - completely hide it
		var opt_id: String = DictUtils.get_string(opt_copy, "id", "")
		if opt_id == "magic" and not has_field_magic:
			continue  # Skip adding this option

		_menu_options.append(opt_copy)

	# TODO Phase 4: Add mod-registered custom options here
	# _add_mod_options()


## Check if any party member has field-usable magic (Egress, Detox)
func _party_has_field_magic() -> bool:
	if not PartyManager:
		return false

	for character: CharacterData in PartyManager.party_members:
		if _character_has_field_ability(character):
			return true
	return false


## Check if a specific character has any field-usable ability
func _character_has_field_ability(character: CharacterData) -> bool:
	if not character:
		return false

	var save_data: CharacterSaveData = PartyManager.get_member_save_data(character.character_uid)
	if not save_data:
		return false

	for ability_dict: Dictionary in save_data.learned_abilities:
		var ability_id: String = DictUtils.get_string(ability_dict, "ability_id", "")
		if _is_field_usable_ability(ability_id):
			return true
	return false


## Check if an ability ID is usable on the field
func _is_field_usable_ability(ability_id: String) -> bool:
	if ability_id in FIELD_USABLE_ABILITY_IDS:
		return true

	var ability_data: AbilityData = ModLoader.registry.get_ability(ability_id)
	return ability_data and "usable_on_field" in ability_data and ability_data.usable_on_field


## Rebuild the option labels from current _menu_options
func _rebuild_option_labels() -> void:
	# Clear existing labels
	for label: Label in _option_labels:
		if is_instance_valid(label):
			label.queue_free()
	_option_labels.clear()

	# Create label for each option
	for option: Dictionary in _menu_options:
		var label: Label = Label.new()
		var option_label_text: String = DictUtils.get_string(option, "label", "")
		label.text = "  " + option_label_text  # Indent for cursor space
		UIUtils.apply_monogram_style(label, FONT_SIZE)
		label.add_theme_color_override("font_color", TEXT_NORMAL)
		_options_container.add_child(label)
		_option_labels.append(label)


## Update visual selection (cursor and colors)
func _update_selection_visual() -> void:
	for i: int in range(_option_labels.size()):
		var label: Label = _option_labels[i]
		var option_label: String = DictUtils.get_string(_menu_options[i], "label", "")
		var is_selected: bool = i == _selected_index
		var is_hovered: bool = i == _hover_index

		# Set color based on state
		var color: Color = TEXT_SELECTED if is_selected else (TEXT_HOVER if is_hovered else TEXT_NORMAL)
		label.add_theme_color_override("font_color", color)

		# Show cursor for selected, indent otherwise
		label.text = (CURSOR_CHAR + " " if is_selected else "  ") + option_label


## Position the menu near the hero, clamped to viewport bounds
func _position_menu() -> void:
	# Wait a frame for panel size to be calculated
	await get_tree().process_frame
	if not is_instance_valid(self) or not visible or not _is_active:
		return

	var desired_pos: Vector2 = _hero_screen_position + MENU_OFFSET

	var viewport_rect: Rect2 = get_viewport_rect()
	var menu_size: Vector2 = _panel.get_combined_minimum_size()

	# Clamp to viewport bounds
	desired_pos.x = clampf(desired_pos.x, EDGE_PADDING, viewport_rect.size.x - menu_size.x - EDGE_PADDING)
	desired_pos.y = clampf(desired_pos.y, EDGE_PADDING, viewport_rect.size.y - menu_size.y - EDGE_PADDING)

	position = desired_pos


# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not _is_active:
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

	var mouse_pos: Vector2 = get_global_mouse_position()

	# Check if clicked on an option label
	var clicked_index: int = _get_label_index_at_position(mouse_pos)
	if clicked_index >= 0:
		_selected_index = clicked_index
		_confirm_selection()
		get_viewport().set_input_as_handled()
		return true

	# Click outside panel - cancel
	if not _panel.get_global_rect().has_point(mouse_pos):
		_cancel_menu()
		get_viewport().set_input_as_handled()
		return true

	return false


## Get the index of the label at the given position, or -1 if none
func _get_label_index_at_position(pos: Vector2) -> int:
	for i: int in range(_option_labels.size()):
		if _option_labels[i].get_global_rect().has_point(pos):
			return i
	return -1


## Handle keyboard navigation input
func _handle_keyboard_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("sf_confirm"):
		_confirm_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel"):
		_cancel_menu()
		get_viewport().set_input_as_handled()


## Move selection with wrapping (SF2-authentic)
func _move_selection(direction: int) -> void:
	if _menu_options.is_empty():
		return

	# INSTANT cursor movement (SF2 purist requirement - no animation)
	var new_index: int = wrapi(_selected_index + direction, 0, _menu_options.size())

	if new_index != _selected_index:
		_selected_index = new_index
		_update_selection_visual()
		AudioManager.play_sfx("cursor_move", AudioManager.SFXCategory.UI)


## Confirm the currently selected option
func _confirm_selection() -> void:
	if not _is_active or _menu_options.is_empty():
		return

	var selected_option: Dictionary = _menu_options[_selected_index]
	var option_id: String = DictUtils.get_string(selected_option, "id", "")
	var is_custom: bool = DictUtils.get_bool(selected_option, "is_custom", false)

	AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)

	# Emit appropriate signal based on option
	if is_custom:
		# Phase 4: Custom mod options
		var scene_path: String = DictUtils.get_string(selected_option, "scene_path", "")
		custom_option_requested.emit(option_id, scene_path)
	else:
		# Built-in options
		match option_id:
			"item":
				item_requested.emit()
			"magic":
				magic_requested.emit()
			"search":
				search_requested.emit()
			"member":
				member_requested.emit()

	option_selected.emit(option_id)


## Cancel and close the menu
func _cancel_menu() -> void:
	AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)
	hide_menu()
	close_requested.emit()
