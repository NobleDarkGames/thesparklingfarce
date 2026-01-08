class_name CombatAnimationScene
extends CanvasLayer

## Displays combat animation when units attack each other.
## Full-screen overlay that completely replaces the tactical map view (Shining Force style).
##
## SF2 AUTHENTIC SESSION-BASED ARCHITECTURE:
## The battle screen now stays open for the ENTIRE combat exchange:
##   Fade In ONCE -> Initial Attack -> Double Attack (if any) -> Counter (if any) -> XP -> Fade Out ONCE
##
## This eliminates the jarring fade-in/fade-out between each phase that was present before.
##
## POSITIONING CONVENTION (SF2):
## - Attacker on RIGHT side of screen
## - Defender on LEFT side of screen
## - For counter attacks, the visual positions SWAP to show the new attacker

signal animation_complete
## Emitted when damage is applied at impact moment (for BattleManager to track)
signal damage_applied(defender: Unit, damage: int, defender_died: bool)
## Emitted when a single phase completes (used internally)
signal phase_complete
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

## Sprite containers - POSITION BASED (not role based)
## Right side = player, Left side = enemy (SF2 convention)
var _right_sprite: Control = null  ## Player's sprite (always on right)
var _left_sprite: Control = null   ## Enemy's sprite (always on left)

## Unit tracking - POSITION BASED
var _right_unit: Unit = null  ## Player unit (always on right)
var _left_unit: Unit = null   ## Enemy unit (always on left)

## Session state tracking
var _session_active: bool = false
var _initial_attacker: Unit = null  ## The unit who initiated the combat (for role tracking)
var _initial_defender: Unit = null  ## The unit who was attacked (for role tracking)

## Current phase tracking (who is currently attacking/defending in THIS phase)
var _current_attacker: Unit = null
var _current_defender: Unit = null

## Combat phase queue
var _combat_phases: Array[CombatPhase] = []
var _current_phase_index: int = 0

## Death tracking across phases
var _initial_attacker_died: bool = false
var _initial_defender_died: bool = false

## XP entries to display before fade-out (SF-authentic: XP shown in battle screen)
var _xp_entries: Array[Dictionary] = []

## Combat action entries to display before XP (e.g., "Max hit with CHAOS BREAKER for 12 damage!")
var _combat_actions: Array[Dictionary] = []

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
const BASE_XP_ENTRY_STAGGER: float = 0.6
const BASE_PHASE_TRANSITION_PAUSE: float = 0.4  ## Pause between phases (role swap, etc.)

## Speed multiplier (set by BattleManager based on GameJuice settings)
var _speed_multiplier: float = 1.0

## Tween pool for reuse (avoids creating 20+ tweens per combat)
var _tween_pool: Array[Tween] = []
const TWEEN_POOL_SIZE: int = 4


## Set animation speed multiplier (called by BattleManager)
func set_speed_multiplier(multiplier: float) -> void:
	_speed_multiplier = maxf(multiplier, 0.1)


## Get duration adjusted by speed multiplier
func _get_duration(base_duration: float) -> float:
	if _speed_multiplier <= 0.1:
		return 0.01
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

	# Pre-create tween pool
	for i: int in range(TWEEN_POOL_SIZE):
		_tween_pool.append(create_tween())
		_tween_pool[i].kill()  # Start killed so they're ready for reuse


## Get a pooled tween, killing any existing animation on it
func _get_pooled_tween() -> Tween:
	# Find a finished/killed tween in the pool
	for tween: Tween in _tween_pool:
		if not tween.is_valid() or not tween.is_running():
			# Recreate if invalid
			if not tween.is_valid():
				var idx: int = _tween_pool.find(tween)
				_tween_pool[idx] = create_tween()
				return _tween_pool[idx]
			# Kill and return if just finished
			tween.kill()
			return create_tween()  # Must create new after kill

	# All tweens busy - create a new one (fallback, shouldn't happen often)
	return create_tween()


# =============================================================================
# SESSION-BASED API (NEW - SF2 AUTHENTIC)
# =============================================================================

## Start a combat session - fades in and sets up the initial combatants
## Call this ONCE at the start of a combat exchange
func start_session(initial_attacker: Unit, initial_defender: Unit) -> void:
	_session_active = true
	_initial_attacker = initial_attacker
	_initial_defender = initial_defender
	_current_attacker = initial_attacker
	_current_defender = initial_defender
	_combat_phases.clear()
	_current_phase_index = 0
	_xp_entries.clear()
	_initial_attacker_died = false
	_initial_defender_died = false

	# SF2 POSITIONING: Player ALWAYS on RIGHT, Enemy ALWAYS on LEFT
	# (regardless of who initiated the attack)
	_right_unit = initial_attacker if initial_attacker.is_player_unit() else initial_defender
	_left_unit = initial_defender if initial_attacker.is_player_unit() else initial_attacker

	# Set up combatants visually (player on RIGHT with back view, enemy on LEFT with front view)
	_right_sprite = await _setup_combatant_and_return_sprite(_right_unit, attacker_container, attacker_name, attacker_hp_bar)
	_left_sprite = await _setup_combatant_and_return_sprite(_left_unit, defender_container, defender_name, defender_hp_bar)

	# Fade in background and contents
	var tween: Tween = _get_pooled_tween()
	tween.tween_property(background, "modulate:a", 1.0, _get_duration(BASE_FADE_IN_DURATION))
	await tween.finished


## Queue a combat phase to be executed
## Phases should be queued in order: Initial -> Double (if any) -> Counter (if any)
func queue_phase(phase: CombatPhase) -> void:
	_combat_phases.append(phase)


## Execute all queued phases WITHOUT fading between them
## This is the core of the SF2-authentic experience
func execute_all_phases() -> void:
	for i: int in range(_combat_phases.size()):
		_current_phase_index = i
		var phase: CombatPhase = _combat_phases[i]

		# Check if we should skip this phase due to death
		if _should_skip_phase(phase):
			continue

		# Handle role swap for counter attacks
		if phase.phase_type == CombatPhase.PhaseType.COUNTER_ATTACK:
			await _swap_combatant_roles()

		# Show appropriate banner
		if phase.is_double_attack:
			await show_custom_banner("DOUBLE ATTACK!", Color(0.2, 0.8, 1.0))
		elif phase.is_counter:
			await show_custom_banner("COUNTER!", Color(1.0, 0.6, 0.0))

		# Execute the phase animation
		await _execute_phase(phase)

		# Brief pause between phases (unless this is the last one)
		if i < _combat_phases.size() - 1 and not _should_skip_remaining_phases():
			await get_tree().create_timer(_get_pause(BASE_PHASE_TRANSITION_PAUSE)).timeout


## Finish the combat session - displays XP and fades out ONCE
func finish_session() -> void:
	# Display combat actions and XP gained before fade-out (SF-authentic)
	# Show the panel if EITHER combat actions OR XP entries exist
	if not _combat_actions.is_empty() or not _xp_entries.is_empty():
		await _display_xp_entries()

	# Pause to let player see final result
	await get_tree().create_timer(_get_pause(BASE_RESULT_PAUSE_DURATION)).timeout

	# Fade out everything
	var tween: Tween = _get_pooled_tween()
	tween.tween_property(background, "modulate:a", 0.0, _get_duration(BASE_FADE_OUT_DURATION))
	await tween.finished

	# Hide the entire CanvasLayer
	visible = false
	_session_active = false

	# Signal completion
	animation_complete.emit()


## Check if a phase should be skipped due to prior death
func _should_skip_phase(phase: CombatPhase) -> bool:
	# If the attacker for this phase is dead, skip it
	if phase.attacker == _initial_attacker and _initial_attacker_died:
		return true
	if phase.attacker == _initial_defender and _initial_defender_died:
		return true

	# If the defender for this phase is dead, skip it (can't attack a dead unit)
	if phase.defender == _initial_attacker and _initial_attacker_died:
		return true
	if phase.defender == _initial_defender and _initial_defender_died:
		return true

	return false


## Check if all remaining phases should be skipped
func _should_skip_remaining_phases() -> bool:
	# If both combatants are dead, skip everything
	return _initial_attacker_died and _initial_defender_died


## Handle role swap for counter attacks (SF2 style)
## SF2 RULE: Positions NEVER swap. Player stays on right, enemy stays on left.
## We just swap who is attacking/defending - the helper functions handle the rest.
func _swap_combatant_roles() -> void:
	# Swap the tracked units (who is attacking/defending this phase)
	var temp: Unit = _current_attacker
	_current_attacker = _current_defender
	_current_defender = temp
	# That's it! _get_attacker_sprite(), _get_defender_sprite(), and _get_attack_direction()
	# will now return the correct values based on _current_attacker/_current_defender


## Execute a single combat phase
func _execute_phase(phase: CombatPhase) -> void:
	# Handle healing phases differently
	if phase.phase_type == CombatPhase.PhaseType.ITEM_HEAL or phase.phase_type == CombatPhase.PhaseType.SPELL_HEAL:
		await _play_heal_animation(phase.heal_amount, phase.defender)
		# Healing phases don't cause death, so skip death check
		return

	# Handle status effect phases (no damage, just effect application)
	if phase.phase_type == CombatPhase.PhaseType.SPELL_STATUS:
		await _play_status_animation(phase.was_resisted, phase.status_effect_name, phase.defender)
		# Status phases don't cause death
		return

	# Play appropriate animation based on hit/miss/critical
	if phase.was_miss:
		await _play_miss_animation()
	elif phase.was_critical:
		await _play_critical_animation(phase.damage, phase.defender)
	else:
		await _play_hit_animation(phase.damage, phase.defender)

	# Check for death after this phase
	if phase.defender == _initial_attacker and _initial_attacker:
		_initial_attacker_died = _initial_attacker.is_dead() if _initial_attacker.has_method("is_dead") else _initial_attacker.stats.current_hp <= 0
		if _initial_attacker_died:
			await _play_death_animation()
	elif phase.defender == _initial_defender and _initial_defender:
		_initial_defender_died = _initial_defender.is_dead() if _initial_defender.has_method("is_dead") else _initial_defender.stats.current_hp <= 0
		if _initial_defender_died:
			await _play_death_animation()


# =============================================================================
# LEGACY API (For backwards compatibility during transition)
# =============================================================================

## Legacy entry point: play combat animation sequence
## This wraps the new session-based API for backwards compatibility
func play_combat_animation(
	attacker: Unit,
	defender: Unit,
	damage: int,
	was_critical: bool,
	was_miss: bool,
	is_counter: bool = false
) -> void:
	# Create a single-phase session for backwards compatibility
	await start_session(attacker, defender)

	# Create and queue the single phase
	var phase: CombatPhase
	if is_counter:
		phase = CombatPhase.create_counter_attack(attacker, defender, damage, was_critical, was_miss)
	else:
		phase = CombatPhase.create_initial_attack(attacker, defender, damage, was_critical, was_miss)

	queue_phase(phase)
	await execute_all_phases()
	await finish_session()


# =============================================================================
# COMBATANT SETUP
# =============================================================================

## Set up a combatant's visual representation
func _setup_combatant(
	unit: Unit,
	container: Control,
	name_label: Label,
	hp_bar: ProgressBar
) -> Control:
	# Set name
	name_label.text = unit.character_data.character_name

	# Set HP bar
	hp_bar.max_value = unit.stats.max_hp
	hp_bar.value = unit.stats.current_hp

	# Reset modulate in case it was faded
	name_label.modulate.a = 1.0
	hp_bar.modulate.a = 1.0

	# Create sprite (real or placeholder)
	var sprite: Control = null
	if unit.character_data.combat_animation_data and unit.character_data.combat_animation_data.battle_sprite:
		sprite = _create_real_sprite(unit)
	else:
		sprite = _create_placeholder_sprite(unit)

	# Add to container (insert before name label)
	container.add_child(sprite)
	container.move_child(sprite, 0)

	return sprite


## Alias for backward compatibility
func _setup_combatant_and_return_sprite(
	unit: Unit,
	container: Control,
	name_label: Label,
	hp_bar: ProgressBar
) -> Control:
	return await _setup_combatant(unit, container, name_label, hp_bar)


## Get the sprite for the current attacker (whoever is attacking this phase)
func _get_attacker_sprite() -> Control:
	if _current_attacker == _right_unit:
		return _right_sprite
	else:
		return _left_sprite


## Get the sprite for the current defender (whoever is being attacked this phase)
func _get_defender_sprite() -> Control:
	if _current_defender == _right_unit:
		return _right_sprite
	else:
		return _left_sprite


## Get the HP bar for the current defender
func _get_defender_hp_bar() -> ProgressBar:
	if _current_defender == _right_unit:
		return attacker_hp_bar  # Right side uses attacker_container's HP bar
	else:
		return defender_hp_bar  # Left side uses defender_container's HP bar


## Get the name label for the current defender
func _get_defender_name() -> Label:
	if _current_defender == _right_unit:
		return attacker_name  # Right side uses attacker_container's name
	else:
		return defender_name  # Left side uses defender_container's name


## Create placeholder portrait using colored panel and character initial
func _create_placeholder_sprite(unit: Unit) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 180)

	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	# Simple faction-based color for placeholder sprites
	style_box.bg_color = Color(0.2, 0.3, 0.5) if unit.is_player_unit() else Color(0.5, 0.2, 0.2)
	style_box.border_width_left = 4
	style_box.border_width_right = 4
	style_box.border_width_top = 4
	style_box.border_width_bottom = 4
	style_box.border_color = Color.WHITE if unit.is_player_unit() else Color(0.8, 0.8, 0.8)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.shadow_color = Color(0, 0, 0, 0.5)
	style_box.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style_box)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var initial: Label = Label.new()
	initial.text = unit.character_data.character_name.substr(0, 1).to_upper()
	initial.add_theme_font_override("font", monogram_font)
	initial.add_theme_font_size_override("font_size", 64)
	initial.add_theme_color_override("font_color", Color.WHITE)
	initial.add_theme_color_override("font_outline_color", Color.BLACK)
	initial.add_theme_constant_override("outline_size", 4)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(initial)

	var face: Label = Label.new()
	face.text = ".-."
	face.add_theme_font_override("font", monogram_font)
	face.add_theme_font_size_override("font_size", 24)
	face.add_theme_color_override("font_color", Color.WHITE)
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(face)

	return panel


## Create sprite from real combat animation data
func _create_real_sprite(unit: Unit) -> Control:
	var anim_data: CombatAnimationData = unit.character_data.combat_animation_data

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

	sprite_node.scale = Vector2.ONE * anim_data.sprite_scale

	# NOTE: No flip needed - sprites are pre-oriented:
	# - Player sprites are BACK views (facing left toward enemy)
	# - Enemy sprites are FRONT views (facing right toward player)

	# Use CenterContainer to properly center the sprite
	var container: CenterContainer = CenterContainer.new()
	container.custom_minimum_size = Vector2(180, 180)

	# Wrap sprite in a Control for proper sizing
	var sprite_wrapper: Control = Control.new()
	sprite_wrapper.custom_minimum_size = Vector2(180, 180)
	sprite_wrapper.add_child(sprite_node)

	# Center the sprite within the wrapper
	sprite_node.position = Vector2(90, 90) + anim_data.sprite_offset

	container.add_child(sprite_wrapper)

	return container


# =============================================================================
# ATTACK ANIMATIONS
# =============================================================================

## Get attack direction multiplier based on who is attacking
## Player (right side) attacks LEFT (-1), Enemy (left side) attacks RIGHT (+1)
func _get_attack_direction() -> float:
	# If current attacker is on the right, they lunge LEFT (-1)
	# If current attacker is on the left, they lunge RIGHT (+1)
	if _current_attacker == _right_unit:
		return -1.0  # Right side attacks left
	else:
		return 1.0   # Left side attacks right


## Play standard hit animation
func _play_hit_animation(damage: int, target: Unit) -> void:
	combat_log.text = "Hit!"
	combat_log.add_theme_color_override("font_color", Color.WHITE)

	var atk_sprite: Control = _get_attacker_sprite()
	var def_sprite: Control = _get_defender_sprite()
	var attacker_start_pos: Vector2 = atk_sprite.position
	var move_duration: float = _get_duration(BASE_ATTACK_MOVE_DURATION)
	var direction: float = _get_attack_direction()

	var tween: Tween = _get_pooled_tween()
	tween.tween_property(atk_sprite, "position:x", attacker_start_pos.x + (ATTACK_MOVE_DISTANCE * direction), move_duration)
	await tween.finished

	await get_tree().create_timer(_get_pause(BASE_IMPACT_PAUSE_DURATION)).timeout

	# Apply damage at impact
	_apply_damage_at_impact(damage, target)

	_flash_sprite(def_sprite, Color.RED, _get_duration(BASE_FLASH_DURATION))
	_show_damage_number(damage, false)

	# Update defender HP bar
	var hp_tween: Tween = _get_pooled_tween()
	hp_tween.tween_property(_get_defender_hp_bar(), "value", target.stats.current_hp, _get_duration(BASE_HP_BAR_NORMAL_DURATION))

	tween = _get_pooled_tween()
	tween.tween_property(atk_sprite, "position", attacker_start_pos, move_duration)
	await tween.finished


## Play critical hit animation
func _play_critical_animation(damage: int, target: Unit) -> void:
	combat_log.text = "Critical Hit!"
	combat_log.add_theme_font_override("font", monogram_font)
	combat_log.add_theme_color_override("font_color", Color.YELLOW)

	var atk_sprite: Control = _get_attacker_sprite()
	var def_sprite: Control = _get_defender_sprite()
	var attacker_start_pos: Vector2 = atk_sprite.position
	var move_duration: float = _get_duration(BASE_ATTACK_MOVE_DURATION)
	var direction: float = _get_attack_direction()

	var tween: Tween = _get_pooled_tween()
	tween.tween_property(atk_sprite, "position:x", attacker_start_pos.x + (ATTACK_MOVE_DISTANCE * 1.5 * direction), move_duration)
	await tween.finished

	_screen_shake()

	# Apply damage at impact
	_apply_damage_at_impact(damage, target)

	_flash_sprite(def_sprite, Color.YELLOW, _get_duration(BASE_FLASH_DURATION))
	_show_damage_number(damage, true)

	var hp_tween: Tween = _get_pooled_tween()
	hp_tween.tween_property(_get_defender_hp_bar(), "value", target.stats.current_hp, _get_duration(BASE_HP_BAR_CRIT_DURATION))

	await get_tree().create_timer(_get_pause(BASE_CRIT_PAUSE_DURATION)).timeout

	tween = _get_pooled_tween()
	tween.tween_property(atk_sprite, "position", attacker_start_pos, move_duration)
	await tween.finished


## Play miss animation
func _play_miss_animation() -> void:
	combat_log.text = "Miss!"
	combat_log.add_theme_font_override("font", monogram_font)
	combat_log.add_theme_color_override("font_color", Color.GRAY)

	var atk_sprite: Control = _get_attacker_sprite()
	var def_sprite: Control = _get_defender_sprite()
	var attacker_start_pos: Vector2 = atk_sprite.position
	var defender_start_pos: Vector2 = def_sprite.position
	var move_duration: float = _get_duration(BASE_ATTACK_MOVE_DURATION)
	var float_duration: float = _get_duration(BASE_DAMAGE_FLOAT_DURATION)
	var direction: float = _get_attack_direction()

	var attack_tween: Tween = _get_pooled_tween()
	attack_tween.tween_property(atk_sprite, "position:x", attacker_start_pos.x + (ATTACK_MOVE_DISTANCE * direction), move_duration)

	# Defender dodges away from attacker (opposite direction)
	var dodge_tween: Tween = _get_pooled_tween()
	dodge_tween.tween_property(def_sprite, "position:x", defender_start_pos.x - (30 * direction), move_duration)

	await attack_tween.finished

	damage_label.text = "MISS"
	damage_label.add_theme_font_override("font", monogram_font)
	damage_label.add_theme_color_override("font_color", Color.GRAY)
	damage_label.visible = true
	damage_label.modulate.a = 1.0

	var fade_tween: Tween = _get_pooled_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(damage_label, "position:y", damage_label.position.y - DAMAGE_FLOAT_DISTANCE, float_duration)
	fade_tween.tween_property(damage_label, "modulate:a", 0.0, float_duration)

	var return_tween: Tween = _get_pooled_tween()
	return_tween.set_parallel(true)
	return_tween.tween_property(atk_sprite, "position", attacker_start_pos, move_duration)
	return_tween.tween_property(def_sprite, "position", defender_start_pos, move_duration)

	await return_tween.finished


## Play healing animation (for item heal and spell heal phases)
func _play_heal_animation(heal_amount: int, target: Unit) -> void:
	combat_log.text = "Heal!"
	combat_log.add_theme_font_override("font", monogram_font)
	combat_log.add_theme_color_override("font_color", Color.GREEN)

	# Flash the target green
	_flash_sprite(_get_defender_sprite(), Color.GREEN, _get_duration(BASE_FLASH_DURATION))

	# Play healing sound
	AudioManager.play_sfx("heal", AudioManager.SFXCategory.COMBAT)

	# Apply healing at this moment (like damage is applied at impact)
	var actual_heal: int = _apply_healing_at_impact(heal_amount, target)

	# Show healing number (green, floating up)
	_show_heal_number(actual_heal)

	# Update defender HP bar (HP goes UP - target.stats.current_hp now has new value)
	var hp_tween: Tween = _get_pooled_tween()
	hp_tween.tween_property(_get_defender_hp_bar(), "value", target.stats.current_hp, _get_duration(BASE_HP_BAR_NORMAL_DURATION))

	# Brief pause
	await get_tree().create_timer(_get_pause(BASE_RESULT_PAUSE_DURATION)).timeout


## Play status effect animation (for SPELL_STATUS phases)
@warning_ignore("unused_parameter")
func _play_status_animation(was_resisted: bool, status_name: String, _target: Unit) -> void:
	var def_sprite: Control = _get_defender_sprite()
	if was_resisted:
		# Similar to miss - white flash, "Resisted!" text
		combat_log.text = "Resisted!"
		combat_log.add_theme_font_override("font", monogram_font)
		combat_log.add_theme_color_override("font_color", Color.WHITE)
		_flash_sprite(def_sprite, Color.WHITE, _get_duration(BASE_FLASH_DURATION))
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
	else:
		# Status applied - purple flash, show status name
		combat_log.text = status_name.capitalize() + "!"
		combat_log.add_theme_font_override("font", monogram_font)
		combat_log.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0))  # Purple
		_flash_sprite(def_sprite, Color(0.8, 0.4, 1.0), _get_duration(BASE_FLASH_DURATION))
		AudioManager.play_sfx("spell_cast", AudioManager.SFXCategory.COMBAT)

	# Brief pause
	await get_tree().create_timer(_get_pause(BASE_RESULT_PAUSE_DURATION)).timeout


## Show healing number with float animation (green color)
func _show_heal_number(heal_amount: int) -> void:
	damage_label.text = "+%d" % heal_amount
	damage_label.add_theme_font_override("font", monogram_font)
	damage_label.add_theme_font_size_override("font_size", 32)
	damage_label.add_theme_color_override("font_color", Color.GREEN)
	damage_label.add_theme_color_override("font_outline_color", Color.BLACK)
	damage_label.add_theme_constant_override("outline_size", 3)

	var start_y: float = damage_label.position.y
	damage_label.visible = true
	damage_label.modulate.a = 1.0

	var float_duration: float = _get_duration(BASE_DAMAGE_FLOAT_DURATION)
	var tween: Tween = _get_pooled_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", start_y - DAMAGE_FLOAT_DISTANCE, float_duration)
	tween.tween_property(damage_label, "modulate:a", 0.0, float_duration)


## Show damage number with float animation
func _show_damage_number(damage: int, is_critical: bool) -> void:
	damage_label.text = str(damage)
	damage_label.add_theme_font_override("font", monogram_font)
	damage_label.add_theme_font_size_override("font_size", 48 if is_critical else 32)
	damage_label.add_theme_color_override("font_color", Color.YELLOW if is_critical else Color.WHITE)
	damage_label.add_theme_color_override("font_outline_color", Color.BLACK)
	damage_label.add_theme_constant_override("outline_size", 3)

	var start_y: float = damage_label.position.y
	damage_label.visible = true
	damage_label.modulate.a = 1.0

	var float_duration: float = _get_duration(BASE_DAMAGE_FLOAT_DURATION)
	var tween: Tween = _get_pooled_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", start_y - DAMAGE_FLOAT_DISTANCE, float_duration)
	tween.tween_property(damage_label, "modulate:a", 0.0, float_duration)


## Flash a sprite with a color
func _flash_sprite(sprite: Control, flash_color: Color, duration: float) -> void:
	var original_modulate: Color = sprite.modulate
	sprite.modulate = flash_color
	await get_tree().create_timer(duration).timeout
	sprite.modulate = original_modulate


## Screen shake effect
func _screen_shake() -> void:
	var original_offset: Vector2 = offset
	var shake_count: int = 6
	var shake_delay: float = 0.05

	for i: int in shake_count:
		var shake_amount: Vector2 = Vector2(
			randf_range(-SCREEN_SHAKE_AMOUNT, SCREEN_SHAKE_AMOUNT),
			randf_range(-SCREEN_SHAKE_AMOUNT, SCREEN_SHAKE_AMOUNT)
		)
		offset = original_offset + shake_amount
		await get_tree().create_timer(shake_delay).timeout

	offset = original_offset


## Show a custom banner (COUNTER!, DOUBLE ATTACK!, etc.)
## Uses slide-in + brightness flash (pixel-perfect, no scaling)
func show_custom_banner(text: String, color: Color) -> void:
	var banner_label: Label = Label.new()
	banner_label.text = text
	banner_label.add_theme_font_override("font", monogram_font)
	banner_label.add_theme_font_size_override("font_size", 64)
	banner_label.add_theme_color_override("font_color", color)
	banner_label.add_theme_color_override("font_outline_color", Color.BLACK)
	banner_label.add_theme_constant_override("outline_size", 4)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.set_anchors_preset(Control.PRESET_CENTER)

	add_child(banner_label)

	# Start above screen, invisible, with bright flash color
	var target_pos: Vector2 = banner_label.position
	banner_label.position.y -= 40
	banner_label.modulate = Color(1.5, 1.5, 1.5, 0.0)  # Bright but invisible

	var tween: Tween = _get_pooled_tween()
	tween.set_parallel(true)
	# Slide down into position
	tween.tween_property(banner_label, "position:y", target_pos.y, _get_duration(0.2)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Fade in
	tween.tween_property(banner_label, "modulate:a", 1.0, _get_duration(0.15))
	# Settle brightness to normal
	tween.tween_property(banner_label, "modulate", Color(color.r, color.g, color.b, 1.0), _get_duration(0.25))
	await tween.finished

	await get_tree().create_timer(_get_pause(0.4)).timeout

	tween = _get_pooled_tween()
	tween.tween_property(banner_label, "modulate:a", 0.0, _get_duration(0.2))
	await tween.finished

	banner_label.queue_free()


# =============================================================================
# DAMAGE APPLICATION
# =============================================================================

## Apply damage to target at the impact moment
func _apply_damage_at_impact(damage: int, target: Unit) -> void:
	if target == null or not is_instance_valid(target):
		push_warning("CombatAnimationScene: Cannot apply damage - target is null or invalid")
		return

	if damage <= 0:
		return

	if target.has_method("take_damage"):
		target.take_damage(damage)
	else:
		target.stats.current_hp -= damage
		target.stats.current_hp = maxi(0, target.stats.current_hp)

	var target_died: bool = target.is_dead() if target.has_method("is_dead") else target.stats.current_hp <= 0

	damage_applied.emit(target, damage, target_died)


## Apply healing to target at the animation moment
## Returns the actual heal amount (may be less if near max HP)
func _apply_healing_at_impact(heal_amount: int, target: Unit) -> int:
	if target == null or not is_instance_valid(target):
		push_warning("CombatAnimationScene: Cannot apply healing - target is null or invalid")
		return 0

	if heal_amount <= 0:
		return 0

	if not target.stats:
		push_warning("CombatAnimationScene: Cannot apply healing - target has no stats")
		return 0

	var stats: UnitStats = target.stats
	var old_hp: int = stats.current_hp
	stats.current_hp = mini(stats.current_hp + heal_amount, stats.max_hp)
	var actual_heal: int = stats.current_hp - old_hp

	return actual_heal


# =============================================================================
# DEATH ANIMATION
# =============================================================================

## Play death animation for defender
func _play_death_animation() -> void:
	var def_sprite: Control = _get_defender_sprite()
	if def_sprite == null:
		return

	combat_log.text = "Defeated!"
	combat_log.add_theme_font_override("font", monogram_font)
	combat_log.add_theme_color_override("font_color", Color.RED)

	await get_tree().create_timer(_get_pause(0.2)).timeout

	var death_tween: Tween = _get_pooled_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(def_sprite, "modulate:a", 0.0, _get_duration(BASE_DEATH_ANIMATION_DURATION))
	death_tween.tween_property(def_sprite, "position:y", def_sprite.position.y + 30, _get_duration(BASE_DEATH_ANIMATION_DURATION))
	death_tween.tween_property(_get_defender_hp_bar(), "modulate:a", 0.0, _get_duration(BASE_DEATH_ANIMATION_DURATION))
	death_tween.tween_property(_get_defender_name(), "modulate:a", 0.0, _get_duration(BASE_DEATH_ANIMATION_DURATION))

	await death_tween.finished
	await get_tree().create_timer(_get_pause(BASE_DEATH_PAUSE_DURATION)).timeout


# =============================================================================
# XP DISPLAY
# =============================================================================

## Queue a combat action to be displayed before XP entries
## Called by BattleManager for each combat phase
func queue_combat_action(text: String, is_critical: bool = false, is_miss: bool = false) -> void:
	_combat_actions.append({
		"text": text,
		"is_critical": is_critical,
		"is_miss": is_miss
	})


## Queue an XP entry to be displayed before fade-out
func queue_xp_entry(unit_name: String, amount: int, source: String) -> void:
	_xp_entries.append({
		"name": unit_name,
		"amount": amount,
		"source": source
	})


## Display all queued combat actions and XP entries (SF-authentic blue panel)
func _display_xp_entries() -> void:
	if _combat_actions.is_empty() and _xp_entries.is_empty():
		return

	var xp_panel: PanelContainer = _create_xp_panel()
	add_child(xp_panel)

	var xp_label: RichTextLabel = xp_panel.get_node("MarginContainer/XPLabel")

	var displayed_lines: Array[String] = []
	var max_visible_lines: int = 5  # Increased to accommodate combat actions

	# First: Display combat actions (attack/spell info)
	for action: Dictionary in _combat_actions:
		var line: String = action.text
		if action.is_miss:
			line = "[color=#999999]%s[/color]" % line  # Gray for misses
		elif action.is_critical:
			line = "[color=#FF9933]%s[/color]" % line  # Orange for crits
		else:
			line = "[color=#FFFFFF]%s[/color]" % line  # White for normal hits

		displayed_lines.append(line)

		if displayed_lines.size() > max_visible_lines:
			displayed_lines.pop_front()

		xp_label.text = "\n".join(displayed_lines)

		AudioManager.play_sfx("ui_select", AudioManager.SFXCategory.UI)

		await get_tree().create_timer(_get_pause(BASE_XP_ENTRY_STAGGER * 2.0)).timeout

	# Clear combat actions queue
	_combat_actions.clear()

	# Second: Display XP entries
	for entry: Dictionary in _xp_entries:
		var entry_name: String = DictUtils.get_string(entry, "name", "")
		var entry_amount: int = DictUtils.get_int(entry, "amount", 0)
		var entry_source: String = DictUtils.get_string(entry, "source", "")
		# Format source for display (damage/kill -> combat, others as-is)
		var source_display: String = entry_source
		if entry_source == "damage" or entry_source == "kill":
			source_display = "combat"
		var line: String = "%s gained %d %s XP" % [entry_name, entry_amount, source_display]
		if entry_source == "kill":
			line = "[color=#FFFF66]%s![/color]" % line
		elif entry_source == "formation":
			line = "[color=#B3D9FF]%s[/color]" % line  # Light blue for formation
		elif entry_source in ["heal", "buff", "debuff"]:
			line = "[color=#B3FFB3]%s[/color]" % line  # Light green for support
		else:
			line = "[color=#FFF2B3]%s[/color]" % line

		displayed_lines.append(line)

		if displayed_lines.size() > max_visible_lines:
			displayed_lines.pop_front()

		xp_label.text = "\n".join(displayed_lines)

		AudioManager.play_sfx("xp_gain", AudioManager.SFXCategory.UI)

		await get_tree().create_timer(_get_pause(BASE_XP_ENTRY_STAGGER * 2.0)).timeout

	await get_tree().create_timer(_get_pause(BASE_XP_DISPLAY_DURATION)).timeout

	var fade_tween: Tween = _get_pooled_tween()
	fade_tween.tween_property(xp_panel, "modulate:a", 0.0, _get_duration(0.3))
	await fade_tween.finished

	xp_panel.queue_free()
	_xp_entries.clear()


## Create SF-authentic XP panel
func _create_xp_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()

	var visible_entries: int = mini(_xp_entries.size(), 4)
	var line_height: int = 16
	var padding: int = 20
	var panel_height: int = (visible_entries * line_height) + padding + 16

	panel.anchor_left = 0.1
	panel.anchor_right = 0.9
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -panel_height - 10
	panel.offset_bottom = -10

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.1, 0.25, 0.95)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.4, 0.5, 0.8, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var label: RichTextLabel = RichTextLabel.new()
	label.name = "XPLabel"
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	# Set ALL font variants to the same monogram font to prevent any bold rendering
	label.add_theme_font_override("normal_font", monogram_font)
	label.add_theme_font_override("bold_font", monogram_font)
	label.add_theme_font_override("italics_font", monogram_font)
	label.add_theme_font_override("bold_italics_font", monogram_font)
	label.add_theme_font_override("mono_font", monogram_font)
	label.add_theme_font_size_override("normal_font_size", 16)
	label.add_theme_font_size_override("bold_font_size", 16)
	label.add_theme_font_size_override("italics_font_size", 16)
	label.add_theme_font_size_override("bold_italics_font_size", 16)
	label.add_theme_font_size_override("mono_font_size", 16)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("default_color", Color(1.0, 0.95, 0.7, 1.0))
	margin.add_child(label)

	panel.modulate.a = 0.0
	var start_offset: float = panel.offset_top
	panel.offset_top = start_offset + 10

	var fade_tween: Tween = _get_pooled_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(panel, "modulate:a", 1.0, _get_duration(0.2))
	fade_tween.tween_property(panel, "offset_top", start_offset, _get_duration(0.25)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	return panel
