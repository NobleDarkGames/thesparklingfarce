extends Control

## SettingsScreen - Tab-based settings UI for the pause menu.
##
## Provides three settings categories (Audio, Display, Gameplay)
## navigable via shoulder buttons (Q/E or L1/R1). Widget rows within each tab
## are navigated with Up/Down; Left/Right adjusts values.
##
## All changes are applied immediately via SettingsManager setters.
## Settings are persisted on exit (back/cancel).
##
## Built entirely in code -- the .tscn only provides a root Control node.

# =============================================================================
# CONSTANTS - Match BattleGameMenu visual specs exactly
# =============================================================================

const PANEL_BG: Color = Color(0.1, 0.1, 0.15, 0.95)
const PANEL_BORDER: Color = Color(0.5, 0.5, 0.6, 1.0)
const PANEL_BORDER_WIDTH: int = 2
const PANEL_CORNER_RADIUS: int = 4

const CONTENT_MARGIN_TOP: int = 8
const CONTENT_MARGIN_BOTTOM: int = 8
const CONTENT_MARGIN_LEFT: int = 12
const CONTENT_MARGIN_RIGHT: int = 12

const TEXT_NORMAL: Color = Color(0.85, 0.85, 0.85)
const TEXT_SELECTED: Color = Color(1.0, 0.95, 0.4)
const TEXT_INACTIVE: Color = Color(0.5, 0.5, 0.5)

const FONT_SIZE: int = 16
const TAB_SEPARATION: int = 16
const WIDGET_SEPARATION: int = 4

const TAB_NAMES: Array[String] = ["Audio", "Display", "Gameplay"]

# =============================================================================
# STATE
# =============================================================================

## Controller reference (has pop_screen method)
var _controller: Node = null

## Current tab index (0..2)
var _current_tab: int = 0

## Selected widget row index within current tab
var _selected_row: int = 0

## Whether this screen is actively accepting input
var _is_active: bool = false

# =============================================================================
# UI REFERENCES
# =============================================================================

var _panel: PanelContainer = null
var _tab_labels: Array[Label] = []
var _tab_containers: Array[VBoxContainer] = []
var _tab_widgets: Array[Array] = []  # Array of Array -- one per tab

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_build_ui()
	visible = true
	set_process_input(false)


func initialize(controller: Node) -> void:
	_controller = controller
	_populate_tabs()
	_switch_tab(0)
	_is_active = true
	set_process_input(true)

# =============================================================================
# UI CONSTRUCTION
# =============================================================================

func _build_ui() -> void:
	# Root fills parent
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Center wrapper -- centers the panel in the screen
	var center: CenterContainer = CenterContainer.new()
	center.name = "CenterWrapper"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Panel
	_panel = PanelContainer.new()
	_panel.name = "SettingsPanel"
	_panel.custom_minimum_size = Vector2(340, 200)

	var panel_style: StyleBoxFlat = UIUtils.create_panel_style(PANEL_BG, PANEL_BORDER, PANEL_BORDER_WIDTH, PANEL_CORNER_RADIUS)
	panel_style.content_margin_top = CONTENT_MARGIN_TOP
	panel_style.content_margin_bottom = CONTENT_MARGIN_BOTTOM
	panel_style.content_margin_left = CONTENT_MARGIN_LEFT
	panel_style.content_margin_right = CONTENT_MARGIN_RIGHT
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)

	# Main vertical layout
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	# -- Tab bar --
	var tab_bar: HBoxContainer = HBoxContainer.new()
	tab_bar.name = "TabBar"
	tab_bar.add_theme_constant_override("separation", TAB_SEPARATION)
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(tab_bar)

	# Left arrow hint
	var left_hint: Label = Label.new()
	left_hint.text = "<<"
	UIUtils.apply_monogram_style(left_hint, FONT_SIZE)
	left_hint.add_theme_color_override("font_color", TEXT_INACTIVE)
	tab_bar.add_child(left_hint)

	for i: int in range(TAB_NAMES.size()):
		var label: Label = Label.new()
		label.text = TAB_NAMES[i]
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		UIUtils.apply_monogram_style(label, FONT_SIZE)
		label.add_theme_color_override("font_color", TEXT_INACTIVE)
		label.gui_input.connect(_on_tab_label_input.bind(i))
		tab_bar.add_child(label)
		_tab_labels.append(label)

	# Right arrow hint
	var right_hint: Label = Label.new()
	right_hint.text = ">>"
	UIUtils.apply_monogram_style(right_hint, FONT_SIZE)
	right_hint.add_theme_color_override("font_color", TEXT_INACTIVE)
	tab_bar.add_child(right_hint)

	# -- Separator --
	var separator: HSeparator = HSeparator.new()
	separator.name = "TabSeparator"
	var sep_style: StyleBoxFlat = StyleBoxFlat.new()
	sep_style.bg_color = Color(0.3, 0.3, 0.35, 1.0)
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1
	separator.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(separator)

	# -- Tab content area --
	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.name = "TabContentMargin"
	content_margin.add_theme_constant_override("margin_top", 4)
	content_margin.add_theme_constant_override("margin_bottom", 4)
	content_margin.add_theme_constant_override("margin_left", 0)
	content_margin.add_theme_constant_override("margin_right", 0)
	vbox.add_child(content_margin)

	# One VBoxContainer per tab (only active one is visible)
	var content_stack: Control = Control.new()
	content_stack.name = "ContentStack"
	content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(content_stack)

	for i: int in range(TAB_NAMES.size()):
		var container: VBoxContainer = VBoxContainer.new()
		container.name = "Tab_%s" % TAB_NAMES[i]
		container.add_theme_constant_override("separation", WIDGET_SEPARATION)
		container.visible = false
		content_stack.add_child(container)
		_tab_containers.append(container)
		_tab_widgets.append([])

# =============================================================================
# TAB POPULATION
# =============================================================================

func _populate_tabs() -> void:
	_populate_audio_tab()
	_populate_display_tab()
	_populate_gameplay_tab()


func _populate_audio_tab() -> void:
	var tab_index: int = 0
	var container: VBoxContainer = _tab_containers[tab_index]

	# Master Volume
	var master: SettingSliderWidget = SettingSliderWidget.new()
	container.add_child(master)
	master.setup("Master", 0.0, 1.0, 0.05, SettingsManager.get_master_volume())
	master.value_changed.connect(func(v: float) -> void: SettingsManager.set_master_volume(v))
	_tab_widgets[tab_index].append(master)

	# Music Volume
	var music: SettingSliderWidget = SettingSliderWidget.new()
	container.add_child(music)
	music.setup("Music", 0.0, 1.0, 0.05, SettingsManager.get_music_volume())
	music.value_changed.connect(func(v: float) -> void: SettingsManager.set_music_volume(v))
	_tab_widgets[tab_index].append(music)

	# SFX Volume
	var sfx: SettingSliderWidget = SettingSliderWidget.new()
	container.add_child(sfx)
	sfx.setup("SFX", 0.0, 1.0, 0.05, SettingsManager.get_sfx_volume())
	sfx.value_changed.connect(func(v: float) -> void: SettingsManager.set_sfx_volume(v))
	_tab_widgets[tab_index].append(sfx)


func _populate_display_tab() -> void:
	var tab_index: int = 1
	var container: VBoxContainer = _tab_containers[tab_index]

	# Fullscreen
	var fullscreen: SettingToggleWidget = SettingToggleWidget.new()
	container.add_child(fullscreen)
	fullscreen.setup("Fullscreen", SettingsManager.is_fullscreen())
	fullscreen.value_changed.connect(func(v: bool) -> void: SettingsManager.set_fullscreen(v))
	_tab_widgets[tab_index].append(fullscreen)

	# VSync
	var vsync: SettingToggleWidget = SettingToggleWidget.new()
	container.add_child(vsync)
	vsync.setup("VSync", SettingsManager.is_vsync_enabled())
	vsync.value_changed.connect(func(v: bool) -> void: SettingsManager.set_vsync(v))
	_tab_widgets[tab_index].append(vsync)



func _populate_gameplay_tab() -> void:
	var tab_index: int = 2
	var container: VBoxContainer = _tab_containers[tab_index]

	# Text Speed
	var speed_options: Array[Dictionary] = [
		{"label": "Slow", "value": 0.5},
		{"label": "Normal", "value": 1.0},
		{"label": "Fast", "value": 2.0},
	]
	var current_speed: float = SettingsManager.get_text_speed()
	var speed_index: int = _find_option_index(speed_options, current_speed)
	var text_speed: SettingOptionsWidget = SettingOptionsWidget.new()
	container.add_child(text_speed)
	text_speed.setup("Text Speed", speed_options, speed_index)
	text_speed.value_changed.connect(func(v: Variant) -> void: SettingsManager.set_text_speed(v as float))
	_tab_widgets[tab_index].append(text_speed)

	# Combat Anims
	var combat_options: Array[Dictionary] = [
		{"label": "Full", "value": 0},
		{"label": "Fast", "value": 1},
		{"label": "Map Only", "value": 2},
	]
	var current_combat: int = SettingsManager.get_combat_animation_mode()
	var combat_index: int = _find_option_index(combat_options, current_combat)
	var combat_anims: SettingOptionsWidget = SettingOptionsWidget.new()
	container.add_child(combat_anims)
	combat_anims.setup("Combat Anims", combat_options, combat_index)
	combat_anims.value_changed.connect(func(v: Variant) -> void: SettingsManager.set_combat_animation_mode(v as int))
	_tab_widgets[tab_index].append(combat_anims)

	# Church Revival HP
	var revival: SettingSliderWidget = SettingSliderWidget.new()
	container.add_child(revival)
	revival.format_callback = func(value: float) -> String:
		if roundi(value) == 0:
			return "1 HP"
		return "%d%%" % roundi(value)
	revival.setup("Church Revival", 0.0, 100.0, 5.0, float(SettingsManager.get_church_revival_hp_percent()))
	revival.value_changed.connect(func(v: float) -> void: SettingsManager.set_church_revival_hp_percent(roundi(v)))
	_tab_widgets[tab_index].append(revival)

	# Cursor Animation
	var cursor_anim: SettingToggleWidget = SettingToggleWidget.new()
	container.add_child(cursor_anim)
	cursor_anim.setup("Cursor Anim", SettingsManager.is_cursor_animation_enabled())
	cursor_anim.value_changed.connect(func(v: bool) -> void: SettingsManager.set_cursor_animation(v))
	_tab_widgets[tab_index].append(cursor_anim)

	# Stat Bar Animation
	var stat_bars: SettingToggleWidget = SettingToggleWidget.new()
	container.add_child(stat_bars)
	stat_bars.setup("Stat Bar Anim", SettingsManager.is_stat_bar_animation_enabled())
	stat_bars.value_changed.connect(func(v: bool) -> void: SettingsManager.set_stat_bar_animation(v))
	_tab_widgets[tab_index].append(stat_bars)

# =============================================================================
# TAB SWITCHING
# =============================================================================

func _switch_tab(new_tab: int) -> void:
	# Hide old tab
	if _current_tab < _tab_containers.size():
		_tab_containers[_current_tab].visible = false
	if _current_tab < _tab_labels.size():
		_tab_labels[_current_tab].add_theme_color_override("font_color", TEXT_INACTIVE)

	_current_tab = new_tab
	_selected_row = 0

	# Show new tab
	if _current_tab < _tab_containers.size():
		_tab_containers[_current_tab].visible = true
	if _current_tab < _tab_labels.size():
		_tab_labels[_current_tab].add_theme_color_override("font_color", TEXT_SELECTED)

	_update_widget_selection()

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not _is_active:
		return

	# Tab switching (shoulder buttons)
	if event.is_action_pressed("sf_tab_left"):
		_change_tab(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("sf_tab_right"):
		_change_tab(1)
		get_viewport().set_input_as_handled()
		return

	# Row navigation
	if event.is_action_pressed("ui_up"):
		_move_row(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down"):
		_move_row(1)
		get_viewport().set_input_as_handled()
		return

	# Value adjustment
	if event.is_action_pressed("ui_left"):
		_adjust_current(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right"):
		_adjust_current(1)
		get_viewport().set_input_as_handled()
		return

	# Confirm also adjusts (toggle / cycle forward)
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("sf_confirm"):
		_adjust_current(1)
		get_viewport().set_input_as_handled()
		return

	# Back
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
		return


## Capture unhandled input to prevent leaking to game controls
func _unhandled_input(_event: InputEvent) -> void:
	if _is_active:
		get_viewport().set_input_as_handled()


func _change_tab(direction: int) -> void:
	var new_tab: int = wrapi(_current_tab + direction, 0, TAB_NAMES.size())
	if new_tab != _current_tab:
		_switch_tab(new_tab)
		AudioManager.play_sfx("cursor_move", AudioManager.SFXCategory.UI)


func _on_tab_label_input(event: InputEvent, tab_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if tab_index != _current_tab:
			_switch_tab(tab_index)
			AudioManager.play_sfx("cursor_move", AudioManager.SFXCategory.UI)


func _move_row(direction: int) -> void:
	var widgets: Array = _tab_widgets[_current_tab]
	if widgets.is_empty():
		return

	var new_row: int = wrapi(_selected_row + direction, 0, widgets.size())
	if new_row != _selected_row:
		_selected_row = new_row
		_update_widget_selection()
		AudioManager.play_sfx("cursor_move", AudioManager.SFXCategory.UI)


func _adjust_current(direction: int) -> void:
	var widgets: Array = _tab_widgets[_current_tab]
	if _selected_row < widgets.size():
		var widget: Node = widgets[_selected_row]
		if widget.has_method("adjust"):
			widget.adjust(direction)


func _on_back() -> void:
	AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)
	_is_active = false
	set_process_input(false)

	if SettingsManager.has_unsaved_changes():
		SettingsManager.save_settings()

	if _controller and _controller.has_method("pop_screen"):
		_controller.pop_screen()

# =============================================================================
# SELECTION VISUAL
# =============================================================================

func _update_widget_selection() -> void:
	var widgets: Array = _tab_widgets[_current_tab]
	for i: int in range(widgets.size()):
		var widget: Node = widgets[i]
		if widget.has_method("set_selected"):
			widget.set_selected(i == _selected_row)

# =============================================================================
# HELPERS
# =============================================================================

## Find the index of an option whose value matches the target.
## Returns 0 if no match found.
func _find_option_index(options: Array[Dictionary], target: Variant) -> int:
	for i: int in range(options.size()):
		var option: Dictionary = options[i]
		if "value" in option and _values_match(option["value"], target):
			return i
	return 0


## Compare two values with tolerance for floats.
func _values_match(a: Variant, b: Variant) -> bool:
	if a is float and b is float:
		return absf(a - b) < 0.001
	return a == b


## Called when this screen is being removed from the stack (e.g., menu closed directly)
func _on_screen_exit() -> void:
	_is_active = false
	set_process_input(false)
	if SettingsManager.has_unsaved_changes():
		SettingsManager.save_settings()
