class_name ChapterTransitionUI
extends CanvasLayer

## ChapterTransitionUI - Displays chapter title cards and save prompts
##
## Connects to CampaignManager signals to show:
## - Chapter title cards when entering new chapters
## - Save prompt dialog at chapter boundaries

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when player responds to save prompt
signal save_prompt_responded(should_save: bool)

# =============================================================================
# CONSTANTS
# =============================================================================

const MONOGRAM_FONT: Font = preload("res://assets/fonts/monogram.ttf")

const COLOR_TITLE: Color = Color(1.0, 0.95, 0.7, 1.0)
const COLOR_SUBTITLE: Color = Color(0.7, 0.7, 0.7, 1.0)
const COLOR_PANEL_BG: Color = Color(0.05, 0.05, 0.1, 0.95)
const COLOR_PANEL_BORDER: Color = Color(0.4, 0.35, 0.25, 1.0)

const TITLE_CARD_DURATION: float = 3.0
const FADE_DURATION: float = 0.5

# =============================================================================
# STATE
# =============================================================================

var _title_card: Control = null
var _save_prompt: Control = null
var _is_showing_prompt: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	layer = 100  # Above most UI
	_build_title_card()
	_build_save_prompt()

	# Connect to CampaignManager signals
	if CampaignManager:
		CampaignManager.chapter_started.connect(_on_chapter_started)
		CampaignManager.chapter_boundary_reached.connect(_on_chapter_boundary_reached)


func _input(event: InputEvent) -> void:
	if not _is_showing_prompt:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("sf_confirm"):
		_respond_to_save_prompt(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel"):
		_respond_to_save_prompt(false)
		get_viewport().set_input_as_handled()

# =============================================================================
# UI BUILDING
# =============================================================================

func _build_title_card() -> void:
	_title_card = Control.new()
	_title_card.name = "TitleCard"
	_title_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_card.visible = false
	add_child(_title_card)

	# Dark overlay
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	_title_card.add_child(overlay)

	# Center container for text
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_card.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	# Chapter number label
	var chapter_num_label: Label = Label.new()
	chapter_num_label.name = "ChapterNumberLabel"
	chapter_num_label.add_theme_font_override("font", MONOGRAM_FONT)
	chapter_num_label.add_theme_font_size_override("font_size", 24)
	chapter_num_label.add_theme_color_override("font_color", COLOR_SUBTITLE)
	chapter_num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(chapter_num_label)

	# Chapter name label
	var chapter_name_label: Label = Label.new()
	chapter_name_label.name = "ChapterNameLabel"
	chapter_name_label.add_theme_font_override("font", MONOGRAM_FONT)
	chapter_name_label.add_theme_font_size_override("font_size", 48)
	chapter_name_label.add_theme_color_override("font_color", COLOR_TITLE)
	chapter_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(chapter_name_label)


func _build_save_prompt() -> void:
	_save_prompt = Control.new()
	_save_prompt.name = "SavePrompt"
	_save_prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_save_prompt.mouse_filter = Control.MOUSE_FILTER_STOP
	_save_prompt.visible = false
	add_child(_save_prompt)

	# Dark overlay
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	_save_prompt.add_child(overlay)

	# Center container
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_save_prompt.add_child(center)

	# Panel
	var panel: PanelContainer = PanelContainer.new()
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PANEL_BG
	panel_style.border_color = COLOR_PANEL_BORDER
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# Title
	var title: Label = Label.new()
	title.text = "Chapter Complete"
	title.add_theme_font_override("font", MONOGRAM_FONT)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Question
	var question: Label = Label.new()
	question.text = "Would you like to save your progress?"
	question.add_theme_font_override("font", MONOGRAM_FONT)
	question.add_theme_font_size_override("font_size", 16)
	question.add_theme_color_override("font_color", COLOR_SUBTITLE)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(question)

	# Separator
	var sep: HSeparator = HSeparator.new()
	sep.custom_minimum_size.y = 8
	vbox.add_child(sep)

	# Hints
	var hints: Label = Label.new()
	hints.text = "[Confirm] Save    [Cancel] Skip"
	hints.add_theme_font_override("font", MONOGRAM_FONT)
	hints.add_theme_font_size_override("font_size", 14)
	hints.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hints)

# =============================================================================
# TITLE CARD
# =============================================================================

func show_chapter_title(chapter: Dictionary) -> void:
	var chapter_num: int = chapter.get("number", 0)
	var chapter_name: String = chapter.get("name", "Unknown")

	# Update labels
	var num_label: Label = _title_card.get_node("CenterContainer/VBoxContainer/ChapterNumberLabel")
	var name_label: Label = _title_card.get_node("CenterContainer/VBoxContainer/ChapterNameLabel")

	if chapter_num > 0:
		num_label.text = "CHAPTER %d" % chapter_num
	else:
		num_label.text = ""
	name_label.text = chapter_name

	# Animate in
	_title_card.modulate.a = 0.0
	_title_card.visible = true

	var tween: Tween = create_tween()
	tween.tween_property(_title_card, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_interval(TITLE_CARD_DURATION)
	tween.tween_property(_title_card, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(func() -> void: _title_card.visible = false)

	# Play sound
	if AudioManager:
		AudioManager.play_sfx("chapter_start", AudioManager.SFXCategory.UI)

# =============================================================================
# SAVE PROMPT
# =============================================================================

func show_save_prompt(chapter: Dictionary) -> void:
	_is_showing_prompt = true
	_save_prompt.modulate.a = 0.0
	_save_prompt.visible = true

	var tween: Tween = create_tween()
	tween.tween_property(_save_prompt, "modulate:a", 1.0, FADE_DURATION * 0.5)

	# Play sound
	if AudioManager:
		AudioManager.play_sfx("menu_open", AudioManager.SFXCategory.UI)


func _respond_to_save_prompt(should_save: bool) -> void:
	_is_showing_prompt = false

	# Play sound
	if AudioManager:
		if should_save:
			AudioManager.play_sfx("menu_select", AudioManager.SFXCategory.UI)
		else:
			AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)

	# Hide prompt
	var tween: Tween = create_tween()
	tween.tween_property(_save_prompt, "modulate:a", 0.0, FADE_DURATION * 0.5)
	tween.tween_callback(func() -> void: _save_prompt.visible = false)

	# Emit signal
	save_prompt_responded.emit(should_save)

	# If saving, trigger the save process
	if should_save:
		_trigger_save()


func _trigger_save() -> void:
	# Get current save slot from GameState or use slot 1 as default
	var slot: int = GameState.get_campaign_data("active_save_slot", 1)

	# Create save data
	if SaveManager:
		var save_data: SaveData = SaveManager.create_save_data()
		if save_data:
			var success: bool = SaveManager.save_to_slot(slot, save_data)
			if success:
				print("ChapterTransitionUI: Game saved to slot %d" % slot)
			else:
				push_warning("ChapterTransitionUI: Failed to save game")

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_chapter_started(chapter: Dictionary) -> void:
	show_chapter_title(chapter)


func _on_chapter_boundary_reached(chapter: Dictionary) -> void:
	# Show title first, then save prompt after
	show_chapter_title(chapter)

	# Wait for title card to finish, then show save prompt
	await get_tree().create_timer(TITLE_CARD_DURATION + FADE_DURATION * 2 + 0.5).timeout
	show_save_prompt(chapter)
