class_name PromotionCeremony
extends CanvasLayer

## Promotion Ceremony - Full-screen transformation celebration
##
## The most emotionally significant moment in a Shining Force game.
## Shows the dramatic class transformation with fanfare and visual effects.
## Designed to honor the SF2 promotion experience.

signal ceremony_dismissed

## Animation timing constants
const ENTRANCE_DURATION: float = 0.4
const ANTICIPATION_DURATION: float = 0.5
const FLASH_IN_DURATION: float = 0.1
const FLASH_OUT_DURATION: float = 0.2
const REVEAL_DURATION: float = 0.8
const STAT_REVEAL_DELAY: float = 0.12

## Visual constants
const TITLE_FONT_SIZE: int = 48
const NAME_FONT_SIZE: int = 32
const CLASS_FONT_SIZE: int = 32
const BONUS_FONT_SIZE: int = 24
const CONTINUE_FONT_SIZE: int = 24

## Colors (royal gold theme)
const COLOR_GOLD: Color = Color(1.0, 0.843, 0.0, 1.0)  # #FFD700
const COLOR_LIGHT_GOLD: Color = Color(0.94, 0.90, 0.55, 1.0)  # #F0E68C
const COLOR_CYAN: Color = Color(0.0, 0.808, 0.82, 1.0)  # #00CED1
const COLOR_LIGHT_GRAY: Color = Color(0.7, 0.7, 0.7, 1.0)

## UI References
@onready var background: ColorRect = $Background
@onready var screen_flash: ColorRect = $ScreenFlash
@onready var center_container: CenterContainer = $CenterContainer
@onready var ceremony_vbox: VBoxContainer = $CenterContainer/CeremonyVBox
@onready var title_label: Label = $CenterContainer/CeremonyVBox/TitleLabel
@onready var character_name_label: Label = $CenterContainer/CeremonyVBox/CharacterNameLabel
@onready var character_sprite: TextureRect = $CenterContainer/CeremonyVBox/SpriteContainer/CharacterSprite
@onready var class_transition_box: HBoxContainer = $CenterContainer/CeremonyVBox/ClassTransitionBox
@onready var old_class_label: Label = $CenterContainer/CeremonyVBox/ClassTransitionBox/OldClassLabel
@onready var arrow_label: Label = $CenterContainer/CeremonyVBox/ClassTransitionBox/ArrowLabel
@onready var new_class_label: Label = $CenterContainer/CeremonyVBox/ClassTransitionBox/NewClassLabel
@onready var bonuses_container: VBoxContainer = $CenterContainer/CeremonyVBox/BonusesContainer
@onready var continue_label: Label = $CenterContainer/CeremonyVBox/ContinueLabel

## State
var _can_dismiss: bool = false
var _blink_tween: Tween = null
var _current_unit: Unit = null
var _old_class: ClassData = null
var _new_class: ClassData = null
var _stat_changes: Dictionary = {}


func _ready() -> void:
	# Start fully hidden
	background.modulate.a = 0.0
	ceremony_vbox.modulate.a = 0.0
	screen_flash.modulate.a = 0.0
	continue_label.visible = false
	bonuses_container.visible = false

	# Set layer above level-up celebration
	layer = 102


## Show the promotion ceremony
## @param unit: Unit being promoted
## @param old_class: Previous ClassData
## @param new_class: New ClassData (after promotion)
func show_promotion(unit: Unit, old_class: ClassData, new_class: ClassData) -> void:
	_can_dismiss = false
	_current_unit = unit
	_old_class = old_class
	_new_class = new_class

	# Reset visibility states
	continue_label.visible = false
	bonuses_container.visible = false
	arrow_label.modulate.a = 0.0
	new_class_label.modulate.a = 0.0

	# Clear previous bonus labels
	for child: Node in bonuses_container.get_children():
		child.queue_free()

	# Set character info
	_setup_character_display(unit, old_class, new_class)

	# Phase 1: Entrance with fanfare
	await _phase_entrance()
	if not is_instance_valid(self):
		return

	# Phase 2: Anticipation (build tension)
	await _phase_anticipation()
	if not is_instance_valid(self):
		return

	# Phase 3: TRANSFORMATION (the moment!)
	await _phase_transformation()
	if not is_instance_valid(self):
		return

	# Phase 4: Revelation
	await _phase_revelation()
	if not is_instance_valid(self):
		return

	# Phase 5: Continue prompt
	_phase_continue_prompt()

	# Wait for player to dismiss the ceremony
	await ceremony_dismissed
	if not is_instance_valid(self):
		return


func _setup_character_display(unit: Unit, old_class: ClassData, new_class: ClassData) -> void:
	# Character name
	var char_name: String = "Unknown"
	if unit.character_data:
		char_name = unit.character_data.character_name
	character_name_label.text = char_name

	# OLD class sprite (will swap to new during transformation)
	if unit.character_data:
		character_sprite.texture = unit.character_data.get_display_texture()
	else:
		# Placeholder if no sprite
		character_sprite.texture = null

	# Class names
	old_class_label.text = old_class.display_name if old_class else "???"
	new_class_label.text = new_class.display_name if new_class else "???"


## Phase 1: Entrance (0.0 - 0.5s)
func _phase_entrance() -> void:
	# Play fanfare immediately - this is THE moment
	AudioManager.play_sfx("promotion_fanfare", AudioManager.SFXCategory.CEREMONY)

	# Fade in background and content
	var tween: Tween = create_tween()
	tween.set_parallel(true)

	var duration: float = GameJuice.get_adjusted_duration(ENTRANCE_DURATION) if GameJuice else ENTRANCE_DURATION

	tween.tween_property(background, "modulate:a", 0.85, duration)
	tween.tween_property(ceremony_vbox, "modulate:a", 1.0, duration)

	await tween.finished
	if not is_instance_valid(self):
		return


## Phase 2: Anticipation (0.5 - 1.0s)
func _phase_anticipation() -> void:
	# Reveal arrow
	var tween: Tween = create_tween()
	var duration: float = GameJuice.get_adjusted_duration(0.2) if GameJuice else 0.2

	tween.tween_property(arrow_label, "modulate:a", 1.0, duration)

	# Brightness pulse the sprite (anticipation) - pixel-perfect, no scaling
	tween.tween_property(character_sprite, "modulate", Color(1.4, 1.4, 1.4, 1.0), 0.25)
	tween.tween_property(character_sprite, "modulate", Color.WHITE, 0.2)

	await tween.finished
	if not is_instance_valid(self):
		return


## Phase 3: TRANSFORMATION (1.0 - 1.5s) - THE MOMENT
func _phase_transformation() -> void:
	# Screen shake for impact
	if GameJuice:
		GameJuice.request_screen_shake(3.0, 0.3)

	# Flash IN (white out)
	var flash_in_tween: Tween = create_tween()
	var flash_duration: float = GameJuice.get_adjusted_duration(FLASH_IN_DURATION) if GameJuice else FLASH_IN_DURATION
	flash_in_tween.tween_property(screen_flash, "modulate:a", 1.0, flash_duration)
	await flash_in_tween.finished
	if not is_instance_valid(self):
		return

	# DURING FLASH PEAK: Swap sprite and reveal new class
	if _new_class and _current_unit and _current_unit.character_data:
		# Try to get the new class sprite (might be stored differently)
		# For now, we'll update sprite after the full promotion completes
		pass

	# Update new class label
	new_class_label.modulate.a = 1.0

	# Flash OUT (fade from white)
	var flash_out_tween: Tween = create_tween()
	var flash_out_duration: float = GameJuice.get_adjusted_duration(FLASH_OUT_DURATION) if GameJuice else FLASH_OUT_DURATION
	flash_out_tween.tween_property(screen_flash, "modulate:a", 0.0, flash_out_duration)
	await flash_out_tween.finished
	if not is_instance_valid(self):
		return


## Phase 4: Revelation (1.5 - 2.5s)
func _phase_revelation() -> void:
	# Brightness flash emphasis on new class name (pixel-perfect, no scaling)
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(new_class_label, "modulate", Color(1.6, 1.6, 1.0, 1.0), 0.1)  # Golden flash
	flash_tween.tween_property(new_class_label, "modulate", Color.WHITE, 0.15)
	await flash_tween.finished
	if not is_instance_valid(self):
		return

	# Reveal stat bonuses if any
	if not _stat_changes.is_empty():
		await _reveal_stat_bonuses()
		if not is_instance_valid(self):
			return


func _reveal_stat_bonuses() -> void:
	# Filter out non-stat changes
	var bonus_stats: Array[String] = ["hp", "mp", "strength", "defense", "agility", "intelligence", "luck"]
	var has_bonuses: bool = false

	for stat_name: String in bonus_stats:
		if stat_name in _stat_changes and _stat_changes[stat_name] > 0:
			has_bonuses = true
			break

	if not has_bonuses:
		return

	bonuses_container.visible = true

	for stat_name: String in bonus_stats:
		if stat_name not in _stat_changes:
			continue

		var bonus: int = _stat_changes[stat_name]
		if bonus <= 0:
			continue

		# Create bonus label
		var lbl: Label = Label.new()
		lbl.text = "%s +%d" % [SparklingEditorUtils.format_stat_abbreviation(stat_name), bonus]
		UIUtils.apply_monogram_style(lbl, BONUS_FONT_SIZE)
		lbl.add_theme_color_override("font_color", COLOR_LIGHT_GOLD)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate.a = 0.0
		bonuses_container.add_child(lbl)

		# Play tick sound and fade in
		AudioManager.play_sfx("ui_select", AudioManager.SFXCategory.UI)

		var reveal_tween: Tween = create_tween()
		reveal_tween.tween_property(lbl, "modulate:a", 1.0, 0.15)

		await get_tree().create_timer(STAT_REVEAL_DELAY).timeout
		if not is_instance_valid(self):
			return


## Phase 5: Continue Prompt
func _phase_continue_prompt() -> void:
	continue_label.visible = true
	_animate_continue_blink()
	_can_dismiss = true


func _animate_continue_blink() -> void:
	_blink_tween = UIUtils.start_blink_tween(continue_label, _blink_tween)


func _input(event: InputEvent) -> void:
	# Block ALL inputs while this modal popup is visible
	get_viewport().set_input_as_handled()

	if not _can_dismiss:
		return

	if event.is_action_pressed("sf_confirm") or event.is_action_pressed("sf_cancel"):
		AudioManager.play_sfx("ui_confirm", AudioManager.SFXCategory.UI)
		_dismiss()


func _dismiss() -> void:
	_can_dismiss = false

	UIUtils.kill_tween(_blink_tween)
	_blink_tween = null

	# Fade out
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	var duration: float = GameJuice.get_adjusted_duration(0.2) if GameJuice else 0.2
	tween.tween_property(background, "modulate:a", 0.0, duration)
	tween.tween_property(ceremony_vbox, "modulate:a", 0.0, duration)
	await tween.finished
	if not is_instance_valid(self):
		return

	ceremony_dismissed.emit()


## Entry point for triggering ceremony with stat changes
func show_promotion_with_stats(unit: Unit, old_class: ClassData, new_class: ClassData, stat_changes: Dictionary) -> void:
	_stat_changes = stat_changes
	await show_promotion(unit, old_class, new_class)
