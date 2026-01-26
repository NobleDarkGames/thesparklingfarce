class_name LevelUpCelebration
extends CanvasLayer

## Level-Up Celebration - Displays stat increases when a unit levels up
##
## Shows immediately during battle (Shining Force authentic behavior).
## Pauses battle flow until player acknowledges.

signal celebration_dismissed

## Font reference
const MONOGRAM_FONT: Font = preload("res://assets/fonts/monogram.ttf")

## Animation constants
const FADE_IN_DURATION: float = 0.3
const STAT_REVEAL_DELAY: float = 0.12
const LEVEL_FLASH_COLOR: Color = Color(1.6, 1.6, 0.8, 1.0)  # Golden brightness flash

## UI References
@onready var background: ColorRect = $Background
@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var portrait: TextureRect = $CenterContainer/Panel/MarginContainer/HBox/PortraitPanel/Portrait
@onready var name_label: Label = $CenterContainer/Panel/MarginContainer/HBox/StatsVBox/NameLabel
@onready var level_label: Label = $CenterContainer/Panel/MarginContainer/HBox/StatsVBox/LevelLabel
@onready var stats_container: VBoxContainer = $CenterContainer/Panel/MarginContainer/HBox/StatsVBox/StatsContainer
@onready var abilities_container: VBoxContainer = $CenterContainer/Panel/MarginContainer/HBox/StatsVBox/AbilitiesContainer
@onready var continue_label: Label = $CenterContainer/Panel/MarginContainer/HBox/StatsVBox/ContinueLabel

## State
var _can_dismiss: bool = false
var _blink_tween: Tween = null


func _ready() -> void:
	# Start hidden
	background.modulate.a = 0.0
	panel.modulate.a = 0.0
	continue_label.visible = false

	# Set layer above combat animation
	layer = 101


## Show the level-up celebration
func show_level_up(unit: Unit, old_level: int, new_level: int, stat_increases: Dictionary) -> void:
	_can_dismiss = false

	# Play level-up sound
	AudioManager.play_sfx("level_up", AudioManager.SFXCategory.UI)

	# Set portrait
	if unit.character_data and unit.character_data.portrait:
		portrait.texture = unit.character_data.portrait
		portrait.visible = true
	else:
		portrait.visible = false

	# Set name
	var char_name: String = "Unknown"
	if unit.character_data:
		char_name = unit.character_data.character_name
	name_label.text = char_name

	# Set initial level text
	level_label.text = "LEVEL UP!"
	level_label.add_theme_color_override("font_color", Color.GOLD)

	# Fade in
	await _fade_in()

	# Animate level change
	await _animate_level_change(old_level, new_level)

	# Reveal stat increases one by one
	await _reveal_stats(stat_increases)

	# Show learned abilities if any
	if "abilities" in stat_increases:
		var abilities_val: Variant = stat_increases.get("abilities", [])
		var abilities_array: Array = abilities_val if abilities_val is Array else []
		if not abilities_array.is_empty():
			var typed_abilities: Array[AbilityData] = []
			for ability: Variant in abilities_array:
				if ability is AbilityData:
					typed_abilities.append(ability)
			await _reveal_abilities(typed_abilities)

	# Show continue prompt
	continue_label.visible = true
	_animate_continue_blink()
	_can_dismiss = true


func _fade_in() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(background, "modulate:a", 0.7, FADE_IN_DURATION)
	tween.tween_property(panel, "modulate:a", 1.0, FADE_IN_DURATION)
	await tween.finished


func _animate_level_change(old_level: int, new_level: int) -> void:
	await get_tree().create_timer(0.3).timeout

	# Brightness flash animation on level text (pixel-perfect, no scaling)
	var tween: Tween = create_tween()
	tween.tween_property(level_label, "modulate", LEVEL_FLASH_COLOR, 0.1)
	tween.tween_callback(func() -> void:
		level_label.text = "Lv %d -> %d" % [old_level, new_level]
	)
	tween.tween_property(level_label, "modulate", Color.WHITE, 0.15)
	await tween.finished


func _reveal_stats(stat_increases: Dictionary) -> void:
	# Clear any existing stat rows
	for child: Node in stats_container.get_children():
		child.queue_free()

	# Stat display order (Shining Force style)
	var stat_order: Array[String] = ["hp", "mp", "strength", "defense", "agility", "intelligence", "luck"]

	for stat_name: String in stat_order:
		if stat_name not in stat_increases:
			continue

		var increase_val: Variant = stat_increases.get(stat_name, 0)
		var increase: int = increase_val if increase_val is int else 0
		if increase <= 0:
			continue

		# Create stat row
		var row: HBoxContainer = _create_stat_row(stat_name, increase)
		row.modulate.a = 0.0
		stats_container.add_child(row)

		# Play tick sound and fade in
		AudioManager.play_sfx("ui_select", AudioManager.SFXCategory.UI)

		var tween: Tween = create_tween()
		tween.tween_property(row, "modulate:a", 1.0, 0.15)

		await get_tree().create_timer(STAT_REVEAL_DELAY).timeout


func _create_stat_row(stat_name: String, increase: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Stat name label
	var name_lbl: Label = Label.new()
	name_lbl.text = SparklingEditorUtils.format_stat_abbreviation(stat_name)
	UIUtils.apply_monogram_style(name_lbl, 24)
	name_lbl.custom_minimum_size.x = 80
	row.add_child(name_lbl)

	# Increase label
	var value_lbl: Label = Label.new()
	value_lbl.text = "+%d" % increase
	UIUtils.apply_monogram_style(value_lbl, 24)
	value_lbl.add_theme_color_override("font_color", Color.LIME_GREEN)
	row.add_child(value_lbl)

	return row


func _reveal_abilities(abilities: Array[AbilityData]) -> void:
	# Clear existing
	for child: Node in abilities_container.get_children():
		child.queue_free()

	for ability: AbilityData in abilities:
		var ability_name: String = "Unknown Ability"
		if ability:
			ability_name = ability.ability_name

		var lbl: Label = Label.new()
		lbl.text = "Learned: %s" % ability_name
		UIUtils.apply_monogram_style(lbl, 24)
		lbl.add_theme_color_override("font_color", Color.CYAN)
		lbl.modulate.a = 0.0
		abilities_container.add_child(lbl)

		# Play special sound for ability
		AudioManager.play_sfx("ability_learned", AudioManager.SFXCategory.UI)

		var tween: Tween = create_tween()
		tween.tween_property(lbl, "modulate:a", 1.0, 0.2)

		await get_tree().create_timer(0.3).timeout


func _animate_continue_blink() -> void:
	_blink_tween = UIUtils.start_blink_tween(continue_label, _blink_tween)


func _input(event: InputEvent) -> void:
	# Block ALL inputs while this modal popup is visible
	# This prevents clicks/keys from passing through to the battle map
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
	tween.tween_property(background, "modulate:a", 0.0, 0.2)
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	await tween.finished

	celebration_dismissed.emit()
