class_name CombatAnimationScene
extends CanvasLayer

## Displays combat animation when units attack each other.
## Full-screen overlay that completely replaces the tactical map view (Shining Force style).
## Shows attacker on right, defender on left with animations and damage display.
##
## SF-AUTHENTIC BEHAVIOR:
## - Damage is applied at the IMPACT moment (not after screen closes)
## - HP bar updates in real-time to show actual damage
## - Death animation plays IN this screen if defender HP reaches 0
## - XP gain is displayed before returning to tactical map

signal animation_complete
## Emitted when damage is applied at impact moment (for BattleManager to track)
signal damage_applied(defender: Node2D, damage: int, defender_died: bool)
## Emitted when XP display is complete (used internally)
signal xp_display_complete

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
var attacker_sprite: Control = null
var defender_sprite: Control = null

## Unit references (for applying damage at impact - SF-authentic)
var _attacker_unit: Node2D = null
var _defender_unit: Node2D = null

## Combat result tracking (set before animation, applied at impact)
var _pending_damage: int = 0
var _was_miss: bool = false
var _defender_died: bool = false

## XP entries to display before fade-out (SF-authentic: XP shown in battle screen)
var _xp_entries: Array[Dictionary] = []

## Font reference for dynamically created labels
@onready var monogram_font: Font = preload("res://assets/fonts/monogram.ttf")

## Base animation constants (will be adjusted by GameJuice speed settings)
const ATTACK_MOVE_DISTANCE: float = 80.0
const BASE_ATTACK_MOVE_DURATION: float = 0.3
const DAMAGE_FLOAT_DISTANCE: float = 50.0
const BASE_DAMAGE_FLOAT_DURATION: float = 1.2
const BASE_FLASH_DURATION: float = 0.15
const SCREEN_SHAKE_AMOUNT: float = 10.0
const BASE_FADE_IN_DURATION: float = 0.4
const BASE_FADE_OUT_DURATION: float = 0.6
const BASE_RESULT_PAUSE_DURATION: float = 1.5
const BASE_IMPACT_PAUSE_DURATION: float = 0.2
const BASE_HP_BAR_NORMAL_DURATION: float = 0.6
const BASE_HP_BAR_CRIT_DURATION: float = 0.8
const BASE_CRIT_PAUSE_DURATION: float = 0.4
const BASE_DEATH_ANIMATION_DURATION: float = 0.8
const BASE_DEATH_PAUSE_DURATION: float = 0.6
const BASE_XP_DISPLAY_DURATION: float = 1.2
const BASE_XP_ENTRY_STAGGER: float = 0.6  # Time between XP entries (SF gives ~1-1.5s to read each)

## Speed multiplier (set by BattleManager based on GameJuice settings)
var _speed_multiplier: float = 1.0


## Set animation speed multiplier (called by BattleManager)
func set_speed_multiplier(multiplier: float) -> void:
	_speed_multiplier = maxf(multiplier, 0.1)  # Minimum 0.1 to avoid division issues


## Get duration adjusted by speed multiplier
func _get_duration(base_duration: float) -> float:
	if _speed_multiplier <= 0.1:
		return 0.01  # Near-instant
	return base_duration / _speed_multiplier


## Get pause duration adjusted by speed multiplier
func _get_pause(base_pause: float) -> float:
	if _speed_multiplier <= 0.1:
		return 0.01
	return base_pause / _speed_multiplier


func _ready() -> void:
	# Hide initially (fade in background)
	background.modulate.a = 0.0
	damage_label.visible = false
	combat_log.text = ""


## Main entry point: play combat animation sequence
## is_counter: if true, displays "COUNTER!" banner before the attack
##
## SF-AUTHENTIC: Damage is now applied at the IMPACT moment within this function,
## not after the animation completes. The defender's HP bar updates in real-time,
## and death animations play within this screen if the defender dies.
func play_combat_animation(
	attacker: Node2D,
	defender: Node2D,
	damage: int,
	was_critical: bool,
	was_miss: bool,
	is_counter: bool = false
) -> void:
	# Store unit references for damage application at impact
	_attacker_unit = attacker
	_defender_unit = defender
	_pending_damage = damage
	_was_miss = was_miss
	_defender_died = false
	_xp_entries.clear()

	# Set up combatants
	await _setup_combatant(attacker, attacker_container, attacker_name, attacker_hp_bar, true)
	await _setup_combatant(defender, defender_container, defender_name, defender_hp_bar, false)

	# Fade in background and contents
	var tween: Tween = create_tween()
	tween.tween_property(background, "modulate:a", 1.0, _get_duration(BASE_FADE_IN_DURATION))
	await tween.finished

	# Show "COUNTER!" banner if this is a counterattack
	if is_counter:
		await _show_counter_banner()

	# Play appropriate animation sequence
	# NOTE: Damage is applied at IMPACT within these functions (SF-authentic)
	if was_miss:
		await _play_miss_animation()
	elif was_critical:
		await _play_critical_animation(damage)
	else:
		await _play_hit_animation(damage)

	# If defender died, play death animation IN the battle screen (GAP 2)
	if _defender_died:
		await _play_death_animation()

	# Display XP gained before fade-out (GAP 3 - SF-authentic)
	if not _xp_entries.is_empty():
		await _display_xp_entries()

	# Pause to let player see final result
	await get_tree().create_timer(_get_pause(BASE_RESULT_PAUSE_DURATION)).timeout

	# Fade out everything by hiding the entire layer
	tween = create_tween()
	tween.tween_property(background, "modulate:a", 0.0, _get_duration(BASE_FADE_OUT_DURATION))
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
	var sprite: Control = null
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
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 180)  # Larger for full-screen view

	# Create styled panel based on character class
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
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
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Character initial (large letter)
	var initial: Label = Label.new()
	initial.text = unit.character_data.character_name.substr(0, 1).to_upper()
	initial.add_theme_font_override("font", monogram_font)
	initial.add_theme_font_size_override("font_size", 96)  # Even larger for prominence
	initial.add_theme_color_override("font_color", Color.WHITE)
	initial.add_theme_color_override("font_outline_color", Color.BLACK)
	initial.add_theme_constant_override("outline_size", 4)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(initial)

	# Simple ASCII face
	var face: Label = Label.new()
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
	var sprite_node: Node = null
	if anim_data.battle_sprite_frames:
		var animated: AnimatedSprite2D = AnimatedSprite2D.new()
		animated.sprite_frames = anim_data.battle_sprite_frames
		animated.animation = anim_data.idle_animation
		animated.play()
		sprite_node = animated
	else:
		var static_sprite: Sprite2D = Sprite2D.new()
		static_sprite.texture = anim_data.battle_sprite
		sprite_node = static_sprite

	# Apply scale and offset
	sprite_node.scale = Vector2.ONE * anim_data.sprite_scale
	sprite_node.position = anim_data.sprite_offset

	# Flip attacker to face left
	if is_attacker:
		sprite_node.flip_h = true

	# Wrap in control for consistent API
	var container: Control = Control.new()
	container.custom_minimum_size = Vector2(120, 120)
	container.add_child(sprite_node)

	return container


## Get color based on character class
func _get_class_color(unit: Node2D) -> Color:
	var char_class_name: String = unit.character_data.character_class.display_name.to_lower() if unit.character_data.character_class else "unknown"

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
## SF-AUTHENTIC: Damage is applied at the IMPACT moment, HP bar shows real result
func _play_hit_animation(damage: int) -> void:
	combat_log.text = "Hit!"

	var attacker_start_pos: Vector2 = attacker_sprite.position
	var move_duration: float = _get_duration(BASE_ATTACK_MOVE_DURATION)

	# Attacker slides forward
	var tween: Tween = create_tween()
	tween.tween_property(attacker_sprite, "position:x", attacker_start_pos.x - ATTACK_MOVE_DISTANCE, move_duration)
	await tween.finished

	# Pause at impact moment
	await get_tree().create_timer(_get_pause(BASE_IMPACT_PAUSE_DURATION)).timeout

	# === IMPACT MOMENT: Apply damage NOW (SF-authentic) ===
	_apply_damage_at_impact(damage)

	# Flash defender red and show damage
	_flash_sprite(defender_sprite, Color.RED, _get_duration(BASE_FLASH_DURATION))
	_show_damage_number(damage, false)

	# Update defender HP bar to show ACTUAL new HP (after damage applied)
	var new_hp: int = _defender_unit.stats.current_hp
	var hp_tween: Tween = create_tween()
	hp_tween.tween_property(defender_hp_bar, "value", new_hp, _get_duration(BASE_HP_BAR_NORMAL_DURATION))

	# Attacker returns to position
	tween = create_tween()
	tween.tween_property(attacker_sprite, "position", attacker_start_pos, move_duration)
	await tween.finished


## Play critical hit animation (more dramatic)
## SF-AUTHENTIC: Damage is applied at the IMPACT moment, HP bar shows real result
func _play_critical_animation(damage: int) -> void:
	combat_log.text = "Critical Hit!"
	combat_log.add_theme_font_override("font", monogram_font)
	combat_log.add_theme_color_override("font_color", Color.YELLOW)

	var attacker_start_pos: Vector2 = attacker_sprite.position
	var move_duration: float = _get_duration(BASE_ATTACK_MOVE_DURATION)

	# Attacker slides forward (still dramatic but not too fast)
	var tween: Tween = create_tween()
	tween.tween_property(attacker_sprite, "position:x", attacker_start_pos.x - ATTACK_MOVE_DISTANCE * 1.5, move_duration)
	await tween.finished

	# Screen shake effect (respects GameJuice intensity setting)
	_screen_shake()

	# === IMPACT MOMENT: Apply damage NOW (SF-authentic) ===
	_apply_damage_at_impact(damage)

	# Flash defender yellow and show critical damage
	_flash_sprite(defender_sprite, Color.YELLOW, _get_duration(BASE_FLASH_DURATION))
	_show_damage_number(damage, true)

	# Update defender HP bar to show ACTUAL new HP (after damage applied)
	var new_hp: int = _defender_unit.stats.current_hp
	var hp_tween: Tween = create_tween()
	hp_tween.tween_property(defender_hp_bar, "value", new_hp, _get_duration(BASE_HP_BAR_CRIT_DURATION))

	await get_tree().create_timer(_get_pause(BASE_CRIT_PAUSE_DURATION)).timeout

	# Attacker returns to position
	tween = create_tween()
	tween.tween_property(attacker_sprite, "position", attacker_start_pos, move_duration)
	await tween.finished


## Play miss animation
func _play_miss_animation() -> void:
	combat_log.text = "Miss!"
	combat_log.add_theme_font_override("font", monogram_font)
	combat_log.add_theme_color_override("font_color", Color.GRAY)

	var attacker_start_pos: Vector2 = attacker_sprite.position
	var defender_start_pos: Vector2 = defender_sprite.position
	var move_duration: float = _get_duration(BASE_ATTACK_MOVE_DURATION)
	var float_duration: float = _get_duration(BASE_DAMAGE_FLOAT_DURATION)

	# Attacker slides forward
	var attack_tween: Tween = create_tween()
	attack_tween.tween_property(attacker_sprite, "position:x", attacker_start_pos.x - ATTACK_MOVE_DISTANCE, move_duration)

	# Defender dodges (slight movement)
	var dodge_tween: Tween = create_tween()
	dodge_tween.tween_property(defender_sprite, "position:x", defender_start_pos.x + 30, move_duration)

	await attack_tween.finished

	# Show "MISS" text
	damage_label.text = "MISS"
	damage_label.add_theme_font_override("font", monogram_font)
	damage_label.add_theme_color_override("font_color", Color.GRAY)
	damage_label.visible = true
	damage_label.modulate.a = 1.0

	var fade_tween: Tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(damage_label, "position:y", damage_label.position.y - DAMAGE_FLOAT_DISTANCE, float_duration)
	fade_tween.tween_property(damage_label, "modulate:a", 0.0, float_duration)

	# Both return to start positions
	var return_tween: Tween = create_tween()
	return_tween.set_parallel(true)
	return_tween.tween_property(attacker_sprite, "position", attacker_start_pos, move_duration)
	return_tween.tween_property(defender_sprite, "position", defender_start_pos, move_duration)

	await return_tween.finished


## Show damage number with float animation
func _show_damage_number(damage: int, is_critical: bool) -> void:
	damage_label.text = str(damage)
	damage_label.add_theme_font_override("font", monogram_font)
	damage_label.add_theme_font_size_override("font_size", 48 if is_critical else 32)
	damage_label.add_theme_color_override("font_color", Color.YELLOW if is_critical else Color.WHITE)
	damage_label.add_theme_color_override("font_outline_color", Color.BLACK)
	damage_label.add_theme_constant_override("outline_size", 3)

	# Reset position and visibility
	var start_y: float = damage_label.position.y
	damage_label.visible = true
	damage_label.modulate.a = 1.0

	# Animate upward and fade out
	var float_duration: float = _get_duration(BASE_DAMAGE_FLOAT_DURATION)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", start_y - DAMAGE_FLOAT_DISTANCE, float_duration)
	tween.tween_property(damage_label, "modulate:a", 0.0, float_duration)


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
		var shake_amount: Vector2 = Vector2(
			randf_range(-SCREEN_SHAKE_AMOUNT, SCREEN_SHAKE_AMOUNT),
			randf_range(-SCREEN_SHAKE_AMOUNT, SCREEN_SHAKE_AMOUNT)
		)
		offset = original_offset + shake_amount
		await get_tree().create_timer(shake_delay).timeout

	# Return to original offset
	offset = original_offset


## Show "COUNTER!" banner before counterattack animation
func _show_counter_banner() -> void:
	await show_custom_banner("COUNTER!", Color(1.0, 0.6, 0.0))  # Orange


## Show a custom banner (used for COUNTER!, DOUBLE ATTACK!, etc.)
## This is a public method that can be called by BattleManager
func show_custom_banner(text: String, color: Color) -> void:
	# Create banner label
	var banner_label: Label = Label.new()
	banner_label.text = text
	banner_label.add_theme_font_override("font", monogram_font)
	banner_label.add_theme_font_size_override("font_size", 64)
	banner_label.add_theme_color_override("font_color", color)
	banner_label.add_theme_color_override("font_outline_color", Color.BLACK)
	banner_label.add_theme_constant_override("outline_size", 4)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Position at center of screen
	banner_label.set_anchors_preset(Control.PRESET_CENTER)
	banner_label.pivot_offset = banner_label.size / 2

	add_child(banner_label)

	# Animate: scale up from small, hold, then fade out
	banner_label.scale = Vector2(0.3, 0.3)
	banner_label.modulate.a = 0.0

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(banner_label, "scale", Vector2.ONE, _get_duration(0.2)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(banner_label, "modulate:a", 1.0, _get_duration(0.15))
	await tween.finished

	# Hold for a moment
	await get_tree().create_timer(_get_pause(0.4)).timeout

	# Fade out
	tween = create_tween()
	tween.tween_property(banner_label, "modulate:a", 0.0, _get_duration(0.2))
	await tween.finished

	banner_label.queue_free()


# =============================================================================
# SF-AUTHENTIC: DAMAGE APPLICATION AT IMPACT (GAP 1)
# =============================================================================

## Apply damage to defender at the impact moment (SF-authentic behavior)
## This is called during the hit/critical animation, NOT after the screen closes.
## The Unit.take_damage() call will emit the died signal if HP reaches 0.
func _apply_damage_at_impact(damage: int) -> void:
	if _defender_unit == null or not is_instance_valid(_defender_unit):
		push_warning("CombatAnimationScene: Cannot apply damage - defender is null or invalid")
		return

	if damage <= 0:
		return

	# Apply damage through the Unit's method (handles death signal internally)
	# IMPORTANT: We suppress the died signal emission here because we handle
	# death visually within this screen, then let BattleManager know via our signal
	if _defender_unit.has_method("take_damage"):
		_defender_unit.take_damage(damage)
	else:
		# Fallback: apply damage directly to stats
		_defender_unit.stats.current_hp -= damage
		_defender_unit.stats.current_hp = maxi(0, _defender_unit.stats.current_hp)

	# Check if defender died
	_defender_died = _defender_unit.is_dead() if _defender_unit.has_method("is_dead") else _defender_unit.stats.current_hp <= 0

	# Emit signal so BattleManager knows damage was applied (for tracking/skip mode)
	damage_applied.emit(_defender_unit, damage, _defender_died)


# =============================================================================
# SF-AUTHENTIC: DEATH ANIMATION IN BATTLE SCREEN (GAP 2)
# =============================================================================

## Play death animation for defender within the battle screen (SF-authentic)
## In Shining Force, you see the unit collapse/fade IN the battle screen,
## not after returning to the tactical map.
func _play_death_animation() -> void:
	if defender_sprite == null:
		return

	combat_log.text = "Defeated!"
	combat_log.add_theme_font_override("font", monogram_font)
	combat_log.add_theme_color_override("font_color", Color.RED)

	# Brief pause before death animation starts
	await get_tree().create_timer(_get_pause(0.2)).timeout

	# Death animation: fade out and sink down (SF-style collapse)
	var death_tween: Tween = create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(defender_sprite, "modulate:a", 0.0, _get_duration(BASE_DEATH_ANIMATION_DURATION))
	death_tween.tween_property(defender_sprite, "position:y", defender_sprite.position.y + 30, _get_duration(BASE_DEATH_ANIMATION_DURATION))

	# Also fade the HP bar and name to 0
	death_tween.tween_property(defender_hp_bar, "modulate:a", 0.0, _get_duration(BASE_DEATH_ANIMATION_DURATION))
	death_tween.tween_property(defender_name, "modulate:a", 0.0, _get_duration(BASE_DEATH_ANIMATION_DURATION))

	await death_tween.finished

	# Dramatic pause to let death sink in
	await get_tree().create_timer(_get_pause(BASE_DEATH_PAUSE_DURATION)).timeout


# =============================================================================
# SF-AUTHENTIC: XP DISPLAY IN BATTLE SCREEN (GAP 3)
# =============================================================================

## Queue an XP entry to be displayed before fade-out
## Called by BattleManager when it receives unit_gained_xp signals
func queue_xp_entry(unit_name: String, amount: int, source: String) -> void:
	_xp_entries.append({
		"name": unit_name,
		"amount": amount,
		"source": source
	})


## Display all queued XP entries before the battle screen fades out
## SF-authentic: XP is shown IN the battle screen in a blue panel at the bottom
func _display_xp_entries() -> void:
	if _xp_entries.is_empty():
		return

	# Create SF-authentic XP panel at bottom of screen
	var xp_panel: PanelContainer = _create_xp_panel()
	add_child(xp_panel)

	# Get the RichTextLabel inside the panel for text display
	var xp_label: RichTextLabel = xp_panel.get_node("MarginContainer/XPLabel")

	# SF-authentic: Display each entry one line at a time, scrolling if needed
	var displayed_entries: Array[Dictionary] = []  # Track entries with their source for coloring
	var max_visible_lines: int = 3  # SF typically shows 2-3 lines at once

	for entry: Dictionary in _xp_entries:
		displayed_entries.append(entry)

		# Keep only the most recent entries visible (scroll effect)
		if displayed_entries.size() > max_visible_lines:
			displayed_entries.pop_front()

		# Build BBCode text with color-coded lines
		var bbcode_lines: Array[String] = []
		for e: Dictionary in displayed_entries:
			var line: String = "%s gained %d XP" % [e.name, e.amount]
			if e.source == "kill":
				# Bright yellow for kills - more exciting!
				line = "[color=#FFFF66]%s![/color]" % line
			else:
				# Warm gold for regular XP
				line = "[color=#FFF2B3]%s[/color]" % line
			bbcode_lines.append(line)

		# Update label text with visible lines
		xp_label.text = "\n".join(bbcode_lines)

		# Play XP gain sound (dedicated sound for feedback)
		AudioManager.play_sfx("xp_gain", AudioManager.SFXCategory.UI)

		# Wait between entries (SF-authentic pacing)
		await get_tree().create_timer(_get_pause(BASE_XP_ENTRY_STAGGER * 2.0)).timeout

	# Hold XP display for a moment before continuing
	await get_tree().create_timer(_get_pause(BASE_XP_DISPLAY_DURATION)).timeout

	# Fade out XP panel
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(xp_panel, "modulate:a", 0.0, _get_duration(0.3))
	await fade_tween.finished

	xp_panel.queue_free()
	_xp_entries.clear()


## Create SF-authentic XP panel (blue panel at bottom of screen)
func _create_xp_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()

	# Calculate dynamic height based on number of entries (max 3 visible)
	var visible_entries: int = mini(_xp_entries.size(), 3)
	var line_height: int = 24  # Approximate height per line with font size 20
	var padding: int = 24  # Top + bottom padding
	var panel_height: int = (visible_entries * line_height) + padding + 16  # Extra for margins

	# Position at bottom center of screen with dynamic height
	panel.anchor_left = 0.1
	panel.anchor_right = 0.9
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -panel_height - 10  # Dynamic height + margin
	panel.offset_bottom = -10  # Small margin from bottom

	# SF-authentic blue panel style
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.1, 0.25, 0.95)  # Dark blue background
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.4, 0.5, 0.8, 1.0)  # Light blue border
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	# Add margin container for padding
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	# Add RichTextLabel for XP text (supports BBCode for colored lines)
	var label: RichTextLabel = RichTextLabel.new()
	label.name = "XPLabel"
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_font_override("normal_font", monogram_font)
	label.add_theme_font_size_override("normal_font_size", 20)
	label.add_theme_color_override("default_color", Color(1.0, 0.95, 0.7, 1.0))  # Warm gold default
	margin.add_child(label)

	# Fade in with subtle slide-up animation (Clauderina's suggestion)
	panel.modulate.a = 0.0
	var start_offset: float = panel.offset_top
	panel.offset_top = start_offset + 10  # Start 10px lower

	var fade_tween: Tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(panel, "modulate:a", 1.0, _get_duration(0.2))
	fade_tween.tween_property(panel, "offset_top", start_offset, _get_duration(0.25)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	return panel
