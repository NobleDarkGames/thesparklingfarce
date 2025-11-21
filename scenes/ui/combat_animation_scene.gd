class_name CombatAnimationScene
extends CanvasLayer

## Displays combat animation when units attack each other.
## Full-screen overlay that completely replaces the tactical map view (Shining Force style).
## Shows attacker on right, defender on left with animations and damage display.

signal animation_complete

## Visual components
@onready var background: ColorRect = $Background
@onready var attacker_container: Control = $CenterContainer/HBoxContainer/AttackerContainer
@onready var defender_container: Control = $CenterContainer/HBoxContainer/DefenderContainer
@onready var damage_label: Label = $DamageLabel
@onready var combat_log: Label = $CombatLog
@onready var attacker_name: Label = $CenterContainer/HBoxContainer/AttackerContainer/NameLabel
@onready var defender_name: Label = $CenterContainer/HBoxContainer/DefenderContainer/NameLabel
@onready var attacker_hp_bar: ProgressBar = $CenterContainer/HBoxContainer/AttackerContainer/HPBar
@onready var defender_hp_bar: ProgressBar = $CenterContainer/HBoxContainer/DefenderContainer/HPBar

## Sprite containers (will be populated dynamically)
var attacker_sprite: Control
var defender_sprite: Control

## Font reference for dynamically created labels
@onready var monogram_font: Font = preload("res://assets/fonts/monogram.ttf")

## Animation constants (slowed down for better visibility)
const ATTACK_MOVE_DISTANCE: float = 80.0
const ATTACK_MOVE_DURATION: float = 0.3  # Increased from 0.15
const DAMAGE_FLOAT_DISTANCE: float = 50.0
const DAMAGE_FLOAT_DURATION: float = 1.2  # Increased from 0.8
const FLASH_DURATION: float = 0.15  # Increased from 0.1
const SCREEN_SHAKE_AMOUNT: float = 10.0
const FADE_IN_DURATION: float = 0.4  # New: fade in duration
const FADE_OUT_DURATION: float = 0.4  # New: fade out duration
const RESULT_PAUSE_DURATION: float = 1.5  # New: pause to see result (increased from 0.5)


func _ready() -> void:
	# Hide initially (fade in background)
	background.modulate.a = 0.0
	damage_label.visible = false
	combat_log.text = ""


## Main entry point: play combat animation sequence
func play_combat_animation(
	attacker: Node2D,
	defender: Node2D,
	damage: int,
	was_critical: bool,
	was_miss: bool
) -> void:
	# Set up combatants
	await _setup_combatant(attacker, attacker_container, attacker_name, attacker_hp_bar, true)
	await _setup_combatant(defender, defender_container, defender_name, defender_hp_bar, false)

	# Fade in background and contents
	var tween := create_tween()
	tween.tween_property(background, "modulate:a", 1.0, FADE_IN_DURATION)
	await tween.finished

	# Play appropriate animation sequence
	if was_miss:
		await _play_miss_animation()
	elif was_critical:
		await _play_critical_animation(damage, defender)
	else:
		await _play_hit_animation(damage, defender)

	# Pause to let player see result
	await get_tree().create_timer(RESULT_PAUSE_DURATION).timeout

	# Fade out everything by hiding the entire layer
	tween = create_tween()
	tween.tween_property(background, "modulate:a", 0.0, FADE_OUT_DURATION)
	await tween.finished

	# Hide the entire CanvasLayer to ensure nothing remains visible
	visible = false

	# Signal completion
	animation_complete.emit()


## Set up a combatant's visual representation
func _setup_combatant(
	unit: Node2D,
	container: Control,
	name_label: Label,
	hp_bar: ProgressBar,
	is_attacker: bool
) -> void:
	# Set name
	name_label.text = unit.character_data.character_name

	# Set HP bar
	hp_bar.max_value = unit.stats.max_hp
	hp_bar.value = unit.stats.current_hp

	# Create sprite (real or placeholder)
	var sprite: Control
	if unit.character_data.combat_animation_data and unit.character_data.combat_animation_data.battle_sprite:
		sprite = _create_real_sprite(unit, is_attacker)
	else:
		sprite = _create_placeholder_sprite(unit, is_attacker)

	# Store reference
	if is_attacker:
		attacker_sprite = sprite
	else:
		defender_sprite = sprite

	# Add to container (insert before name label)
	container.add_child(sprite)
	container.move_child(sprite, 0)


## Create placeholder portrait using colored panel and character initial
func _create_placeholder_sprite(unit: Node2D, is_attacker: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 180)  # Larger for full-screen view

	# Create styled panel based on character class
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = _get_class_color(unit)
	style_box.border_width_left = 4
	style_box.border_width_right = 4
	style_box.border_width_top = 4
	style_box.border_width_bottom = 4
	style_box.border_color = Color.WHITE if is_attacker else Color(0.8, 0.8, 0.8)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.shadow_color = Color(0, 0, 0, 0.5)
	style_box.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style_box)

	# Container for content
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Character initial (large letter)
	var initial := Label.new()
	initial.text = unit.character_data.character_name.substr(0, 1).to_upper()
	initial.add_theme_font_override("font", monogram_font)
	initial.add_theme_font_size_override("font_size", 96)  # Even larger for prominence
	initial.add_theme_color_override("font_color", Color.WHITE)
	initial.add_theme_color_override("font_outline_color", Color.BLACK)
	initial.add_theme_constant_override("outline_size", 4)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(initial)

	# Simple ASCII face
	var face := Label.new()
	face.text = "• — •\n  ◡"
	face.add_theme_font_override("font", monogram_font)
	face.add_theme_font_size_override("font_size", 24)  # Larger face too
	face.add_theme_color_override("font_color", Color.WHITE)
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(face)

	return panel


## Create sprite from real combat animation data
func _create_real_sprite(unit: Node2D, is_attacker: bool) -> Control:
	var anim_data: CombatAnimationData = unit.character_data.combat_animation_data

	# Use AnimatedSprite2D if sprite frames provided, otherwise static Sprite2D
	var sprite_node: Node
	if anim_data.battle_sprite_frames:
		var animated := AnimatedSprite2D.new()
		animated.sprite_frames = anim_data.battle_sprite_frames
		animated.animation = anim_data.idle_animation
		animated.play()
		sprite_node = animated
	else:
		var static_sprite := Sprite2D.new()
		static_sprite.texture = anim_data.battle_sprite
		sprite_node = static_sprite

	# Apply scale and offset
	sprite_node.scale = Vector2.ONE * anim_data.sprite_scale
	sprite_node.position = anim_data.sprite_offset

	# Flip attacker to face left
	if is_attacker:
		sprite_node.flip_h = true

	# Wrap in control for consistent API
	var container := Control.new()
	container.custom_minimum_size = Vector2(120, 120)
	container.add_child(sprite_node)

	return container


## Get color based on character class
func _get_class_color(unit: Node2D) -> Color:
	var char_class_name: String = unit.character_data.character_class.display_name.to_lower()

	# Color coding by class archetype
	if "warrior" in char_class_name or "knight" in char_class_name or "fighter" in char_class_name:
		return Color(0.8, 0.2, 0.2)  # Red - Warriors
	elif "mage" in char_class_name or "wizard" in char_class_name or "sorcerer" in char_class_name:
		return Color(0.2, 0.2, 0.8)  # Blue - Mages
	elif "healer" in char_class_name or "priest" in char_class_name or "cleric" in char_class_name:
		return Color(0.2, 0.8, 0.2)  # Green - Healers
	elif "archer" in char_class_name or "ranger" in char_class_name or "bow" in char_class_name:
		return Color(0.6, 0.4, 0.2)  # Brown - Archers
	elif "thief" in char_class_name or "rogue" in char_class_name or "ninja" in char_class_name:
		return Color(0.5, 0.3, 0.7)  # Purple - Thieves
	else:
		return Color(0.5, 0.5, 0.5)  # Gray - Default/Unknown


## Play standard hit animation
func _play_hit_animation(damage: int, defender: Node2D) -> void:
	combat_log.text = "Hit!"

	var attacker_start_pos: Vector2 = attacker_sprite.position

	# Attacker slides forward
	var tween := create_tween()
	tween.tween_property(attacker_sprite, "position:x", attacker_start_pos.x - ATTACK_MOVE_DISTANCE, ATTACK_MOVE_DURATION)
	await tween.finished

	# Pause at impact moment
	await get_tree().create_timer(0.2).timeout

	# Flash defender red and show damage
	_flash_sprite(defender_sprite, Color.RED, FLASH_DURATION)
	_show_damage_number(damage, false)

	# Update defender HP bar (slower animation)
	var hp_tween := create_tween()
	hp_tween.tween_property(defender_hp_bar, "value", defender.stats.current_hp - damage, 0.6)

	# Attacker returns to position
	tween = create_tween()
	tween.tween_property(attacker_sprite, "position", attacker_start_pos, ATTACK_MOVE_DURATION)
	await tween.finished


## Play critical hit animation (more dramatic)
func _play_critical_animation(damage: int, defender: Node2D) -> void:
	combat_log.text = "Critical Hit!"
	combat_log.add_theme_color_override("font_color", Color.YELLOW)

	var attacker_start_pos: Vector2 = attacker_sprite.position

	# Attacker slides forward (still dramatic but not too fast)
	var tween := create_tween()
	tween.tween_property(attacker_sprite, "position:x", attacker_start_pos.x - ATTACK_MOVE_DISTANCE * 1.5, ATTACK_MOVE_DURATION)
	await tween.finished

	# Screen shake effect
	_screen_shake()

	# Flash defender yellow and show critical damage
	_flash_sprite(defender_sprite, Color.YELLOW, FLASH_DURATION)
	_show_damage_number(damage, true)

	# Update defender HP bar (slower for dramatic effect)
	var hp_tween := create_tween()
	hp_tween.tween_property(defender_hp_bar, "value", defender.stats.current_hp - damage, 0.8)

	await get_tree().create_timer(0.4).timeout

	# Attacker returns to position
	tween = create_tween()
	tween.tween_property(attacker_sprite, "position", attacker_start_pos, ATTACK_MOVE_DURATION)
	await tween.finished


## Play miss animation
func _play_miss_animation() -> void:
	combat_log.text = "Miss!"
	combat_log.add_theme_color_override("font_color", Color.GRAY)

	var attacker_start_pos: Vector2 = attacker_sprite.position
	var defender_start_pos: Vector2 = defender_sprite.position

	# Attacker slides forward
	var attack_tween := create_tween()
	attack_tween.tween_property(attacker_sprite, "position:x", attacker_start_pos.x - ATTACK_MOVE_DISTANCE, ATTACK_MOVE_DURATION)

	# Defender dodges (slight movement)
	var dodge_tween := create_tween()
	dodge_tween.tween_property(defender_sprite, "position:x", defender_start_pos.x + 30, ATTACK_MOVE_DURATION)

	await attack_tween.finished

	# Show "MISS" text
	damage_label.text = "MISS"
	damage_label.add_theme_color_override("font_color", Color.GRAY)
	damage_label.visible = true
	damage_label.modulate.a = 1.0

	var fade_tween := create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(damage_label, "position:y", damage_label.position.y - DAMAGE_FLOAT_DISTANCE, DAMAGE_FLOAT_DURATION)
	fade_tween.tween_property(damage_label, "modulate:a", 0.0, DAMAGE_FLOAT_DURATION)

	# Both return to start positions
	var return_tween := create_tween()
	return_tween.set_parallel(true)
	return_tween.tween_property(attacker_sprite, "position", attacker_start_pos, ATTACK_MOVE_DURATION)
	return_tween.tween_property(defender_sprite, "position", defender_start_pos, ATTACK_MOVE_DURATION)

	await return_tween.finished


## Show damage number with float animation
func _show_damage_number(damage: int, is_critical: bool) -> void:
	damage_label.text = str(damage)
	damage_label.add_theme_font_size_override("font_size", 48 if is_critical else 36)
	damage_label.add_theme_color_override("font_color", Color.YELLOW if is_critical else Color.WHITE)
	damage_label.add_theme_color_override("font_outline_color", Color.BLACK)
	damage_label.add_theme_constant_override("outline_size", 3)

	# Reset position and visibility
	var start_y: float = damage_label.position.y
	damage_label.visible = true
	damage_label.modulate.a = 1.0

	# Animate upward and fade out
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", start_y - DAMAGE_FLOAT_DISTANCE, DAMAGE_FLOAT_DURATION)
	tween.tween_property(damage_label, "modulate:a", 0.0, DAMAGE_FLOAT_DURATION)


## Flash a sprite with a color
func _flash_sprite(sprite: Control, flash_color: Color, duration: float) -> void:
	var original_modulate: Color = sprite.modulate

	# Flash to color
	sprite.modulate = flash_color

	# Return to original
	await get_tree().create_timer(duration).timeout
	sprite.modulate = original_modulate


## Screen shake effect (using CanvasLayer offset)
func _screen_shake() -> void:
	var original_offset: Vector2 = offset
	var shake_count: int = 6
	var shake_delay: float = 0.05

	for i in shake_count:
		# Random offset
		var shake_amount := Vector2(
			randf_range(-SCREEN_SHAKE_AMOUNT, SCREEN_SHAKE_AMOUNT),
			randf_range(-SCREEN_SHAKE_AMOUNT, SCREEN_SHAKE_AMOUNT)
		)
		offset = original_offset + shake_amount
		await get_tree().create_timer(shake_delay).timeout

	# Return to original offset
	offset = original_offset
