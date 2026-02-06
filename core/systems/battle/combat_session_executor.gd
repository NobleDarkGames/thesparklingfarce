## CombatSessionExecutor - Handles execution of combat sessions (skip and animated modes).
##
## This class manages:
## - Skip mode combat execution (instant damage application, no animations)
## - Battlefield visibility toggling during combat animations
## - XP pooling for SF2-authentic experience awards (double attacks = one XP entry)
## - Combat results panel display for skip mode
##
## SF2-AUTHENTIC: All combat phases (initial, double, counter) are pre-calculated
## by BattleManager, then executed here either instantly (skip) or animated (Phase B).
##
## Extracted from BattleManager as part of Phase A refactoring to improve
## modularity and testability.
class_name CombatSessionExecutor
extends RefCounted


## Context holding all references needed for combat session execution.
## Passed to execution methods to avoid tight coupling with BattleManager.
class SessionContext:
	## The battle scene root node (for adding UI elements)
	var battle_scene_root: Node = null
	## The map instance (for visibility toggling)
	var map_instance: Node2D = null
	## The units parent container (for visibility toggling)
	var units_parent: Node2D = null
	## Callable to get cached scenes from BattleManager
	var get_cached_scene: Callable = Callable()
	## SceneTree reference (for timers and frame awaits)
	var scene_tree: SceneTree = null
	## Signal to emit when combat is resolved (attacker, defender, damage, hit, crit)
	var combat_resolved_signal: Signal
	## Cached PackedScene for CombatAnimationScene (animation mode)
	var combat_anim_scene: PackedScene = null


# =============================================================================
# CONSTANTS (mirrored from BattleManager for consistent behavior)
# =============================================================================

## Pause after combat to let player read results before returning to map
const BATTLEFIELD_SETTLE_DELAY: float = 1.2

## Music layer for combat intensity (adaptive music)
const COMBAT_AUDIO_LAYER: int = 1

## Fade duration for music layer transitions
const AUDIO_LAYER_FADE_DURATION: float = 0.4


# =============================================================================
# MEMBER VARIABLES (instance state for skip mode)
# =============================================================================

## XP entries queue for combat results panel
var _pending_xp_entries: Array[Dictionary] = []

## Combat actions queue for combat results panel (e.g., "Max hit for 12 damage!")
var _pending_combat_actions: Array[Dictionary] = []

## Combat animation scene instance (owned by executor during animation mode session)
var _combat_anim_instance: CombatAnimationScene = null


# =============================================================================
# STATIC HELPER METHODS
# =============================================================================

## Hide the battlefield for combat animation overlay.
## Makes map, units, and UI invisible so combat screen takes full focus.
## @param context: SessionContext with scene references
static func hide_battlefield(context: SessionContext) -> void:
	if context.map_instance:
		context.map_instance.visible = false
	if context.units_parent:
		context.units_parent.visible = false
	var ui_node: Node = context.battle_scene_root.get_node_or_null("UI") if context.battle_scene_root else null
	if ui_node:
		ui_node.visible = false


## Show the battlefield after combat animation completes.
## Restores visibility of map, units, and UI.
## @param context: SessionContext with scene references
static func show_battlefield(context: SessionContext) -> void:
	if context.map_instance:
		context.map_instance.visible = true
	if context.units_parent:
		context.units_parent.visible = true
	var ui_node: Node = context.battle_scene_root.get_node_or_null("UI") if context.battle_scene_root else null
	if ui_node:
		ui_node.visible = true


## Find the current phase for a given defender in the damage handler callback.
## Returns the most recent phase where this unit is the defender.
## @param phases: Array of CombatPhase objects for this session
## @param defender: The unit that took damage
## @return: The matching CombatPhase, or null if not found
static func find_current_phase_for_defender(phases: Array[CombatPhase], defender: Unit) -> CombatPhase:
	# Search backwards since we want the most recent phase
	for i: int in range(phases.size() - 1, -1, -1):
		var phase: CombatPhase = phases[i]
		if phase.defender == defender:
			return phase
	return null


# =============================================================================
# INSTANCE METHODS (require state)
# =============================================================================

## Pool damage for XP calculation - SF2-authentic behavior.
## Double attacks should show as a single XP entry, so we pool damage by
## attacker/defender pair and award XP once at the end.
## @param xp_pools: Dictionary to accumulate damage (modified in place)
## @param attacker: The attacking unit
## @param defender: The defending unit that took damage
## @param damage: Amount of damage dealt
## @param died: Whether the defender died from this damage
func pool_damage_for_xp(xp_pools: Dictionary, attacker: Unit, defender: Unit, damage: int, died: bool) -> void:
	var pool_key: String = "%d:%d" % [attacker.get_instance_id(), defender.get_instance_id()]
	if pool_key not in xp_pools:
		xp_pools[pool_key] = {
			"attacker": attacker,
			"defender": defender,
			"total_damage": 0,
			"got_kill": false
		}
	xp_pools[pool_key]["total_damage"] += damage
	if died:
		xp_pools[pool_key]["got_kill"] = true


## Show combat results panel with queued combat actions and XP entries.
## Used in skip mode to display results on the map instead of battle screen.
## @param context: SessionContext with scene references
func show_combat_results(context: SessionContext) -> void:
	# Skip in headless mode
	if TurnManager.is_headless:
		_pending_combat_actions.clear()
		_pending_xp_entries.clear()
		return

	# Skip if no entries
	if _pending_combat_actions.is_empty() and _pending_xp_entries.is_empty():
		return

	# Get the cached scene via the callable
	if not context.get_cached_scene.is_valid():
		push_warning("CombatSessionExecutor: Cannot show results - get_cached_scene not set")
		_pending_combat_actions.clear()
		_pending_xp_entries.clear()
		return

	var results_scene: PackedScene = context.get_cached_scene.call("combat_results_scene")
	if not results_scene:
		push_warning("CombatSessionExecutor: Cannot show results - scene not found")
		_pending_combat_actions.clear()
		_pending_xp_entries.clear()
		return

	# Create and populate the results panel
	var results_panel: CanvasLayer = results_scene.instantiate()
	context.battle_scene_root.add_child(results_panel)

	# Add all queued combat actions first
	for action: Dictionary in _pending_combat_actions:
		results_panel.add_combat_action(action.text, action.is_critical, action.is_miss)

	# Clear the combat actions queue
	_pending_combat_actions.clear()

	# Add all queued XP entries
	for entry: Dictionary in _pending_xp_entries:
		results_panel.add_xp_entry(entry.unit_name, entry.amount, entry.source)

	# Clear the XP queue
	_pending_xp_entries.clear()

	# Show and wait for dismissal
	results_panel.show_results()
	await results_panel.results_dismissed

	# HIGH-003: Validate state after await on UI signal
	if is_instance_valid(results_panel):
		results_panel.queue_free()


## Execute skip mode combat - instant damage application, no animations.
## This handles the "skip combat animations" setting and headless mode.
## @param context: SessionContext with all required references
## @param initial_attacker: The unit that initiated the attack
## @param initial_defender: The target of the attack
## @param phases: Pre-calculated combat phases to execute
## @return: Dictionary with {attacker_died: bool, defender_died: bool}
func execute_skip_mode(
	context: SessionContext,
	initial_attacker: Unit,
	initial_defender: Unit,
	phases: Array[CombatPhase]
) -> Dictionary:
	var attacker_died: bool = false
	var defender_died: bool = false

	# SF2-AUTHENTIC: Pool XP by attacker/defender pair, award ONCE per pair
	var xp_pools: Dictionary = {}

	for phase: CombatPhase in phases:
		# Check if we should skip this phase due to death
		if phase.attacker == initial_attacker and attacker_died:
			continue
		if phase.attacker == initial_defender and defender_died:
			continue
		if phase.defender == initial_attacker and attacker_died:
			continue
		if phase.defender == initial_defender and defender_died:
			continue

		# Queue combat action for results panel
		_pending_combat_actions.append({
			"text": phase.get_result_text(),
			"is_critical": phase.was_critical,
			"is_miss": phase.was_miss
		})

		# Handle healing phases (ITEM_HEAL, SPELL_HEAL)
		if phase.phase_type == CombatPhase.PhaseType.ITEM_HEAL or phase.phase_type == CombatPhase.PhaseType.SPELL_HEAL:
			# Play healing sound
			AudioManager.play_sfx("heal", AudioManager.SFXCategory.COMBAT)

			# Apply healing directly
			if phase.heal_amount > 0 and is_instance_valid(phase.defender) and phase.defender.stats:
				var stats: UnitStats = phase.defender.stats
				stats.current_hp = mini(stats.current_hp + phase.heal_amount, stats.max_hp)

			# Healing doesn't have damage XP pooling - XP is handled separately
			continue

		# Handle status effect phases (SPELL_STATUS)
		# Status application happens in BattleManager._apply_spell_status() after
		# the combat session returns — executor only plays the sound effect.
		if phase.phase_type == CombatPhase.PhaseType.SPELL_STATUS:
			AudioManager.play_sfx("spell_status", AudioManager.SFXCategory.COMBAT)
			# Emit combat resolved signal for status phases
			if context.combat_resolved_signal:
				context.combat_resolved_signal.emit(phase.attacker, phase.defender, 0, not phase.was_resisted, false)
			continue

		# Play sound effect (for attack phases)
		if not phase.was_miss:
			if phase.was_critical:
				AudioManager.play_sfx("attack_critical", AudioManager.SFXCategory.COMBAT)
			else:
				AudioManager.play_sfx("attack_hit", AudioManager.SFXCategory.COMBAT)
		else:
			AudioManager.play_sfx("attack_miss", AudioManager.SFXCategory.COMBAT)

		# Apply damage directly
		if not phase.was_miss and phase.damage > 0 and is_instance_valid(phase.defender):
			if phase.defender.has_method("take_damage"):
				phase.defender.take_damage(phase.damage)
			else:
				phase.defender.stats.current_hp -= phase.damage
				phase.defender.stats.current_hp = maxi(0, phase.defender.stats.current_hp)

			# Check for death
			var died: bool = phase.defender.is_dead() if phase.defender.has_method("is_dead") else phase.defender.stats.current_hp <= 0

			# Update death tracking
			if phase.defender == initial_attacker:
				attacker_died = died
			elif phase.defender == initial_defender:
				defender_died = died

			# SF2-AUTHENTIC: Pool damage instead of awarding XP immediately
			pool_damage_for_xp(xp_pools, phase.attacker, phase.defender, phase.damage, died)

		# Emit combat resolved signal
		if context.combat_resolved_signal:
			context.combat_resolved_signal.emit(phase.attacker, phase.defender, phase.damage, not phase.was_miss, phase.was_critical)

	# SF2-AUTHENTIC: Award pooled XP ONCE per attacker/defender pair
	for pool: Dictionary in xp_pools.values():
		ExperienceManager.award_combat_xp(
			pool["attacker"],
			pool["defender"],
			pool["total_damage"],
			pool["got_kill"]
		)

	# Show combat results panel (skip mode shows XP on map)
	await show_combat_results(context)

	return {
		"attacker_died": attacker_died,
		"defender_died": defender_died
	}


## Queue an XP entry for display in the results panel.
## Called by ExperienceManager signal handler.
## @param unit_name: Display name of the unit gaining XP
## @param amount: Amount of XP gained
## @param source: Source of XP (e.g., "combat", "heal_spell")
func queue_xp_entry(unit_name: String, amount: int, source: String) -> void:
	_pending_xp_entries.append({
		"unit_name": unit_name,
		"amount": amount,
		"source": source
	})


## Clear all pending entries (used when cancelling or on error)
func clear_pending_entries() -> void:
	_pending_xp_entries.clear()
	_pending_combat_actions.clear()


## Execute animation mode combat - full battle screen with sprites and effects.
## SF2-AUTHENTIC: Single fade-in, all phases animate, single fade-out.
## @param context: SessionContext with all required references
## @param initial_attacker: The unit that initiated the attack
## @param initial_defender: The target of the attack
## @param phases: Pre-calculated combat phases to execute
## @return: Dictionary with {attacker_died: bool, defender_died: bool}
func execute_animation_mode(
	context: SessionContext,
	initial_attacker: Unit,
	initial_defender: Unit,
	phases: Array[CombatPhase]
) -> Dictionary:
	var attacker_died: bool = false
	var defender_died: bool = false

	# SF2-AUTHENTIC: Pool XP by attacker/defender pair, award ONCE per pair
	var xp_pools: Dictionary = {}

	# Instantiate combat animation scene from cached scene
	if not context.combat_anim_scene:
		push_error("CombatSessionExecutor: combat_anim_scene not set in context")
		return {"attacker_died": false, "defender_died": false}

	_combat_anim_instance = context.combat_anim_scene.instantiate() as CombatAnimationScene
	if not _combat_anim_instance:
		push_error("CombatSessionExecutor: Failed to instantiate CombatAnimationScene")
		return {"attacker_died": false, "defender_died": false}

	context.battle_scene_root.add_child(_combat_anim_instance)
	_combat_anim_instance.set_speed_multiplier(GameJuice.get_combat_speed_multiplier())

	# Create lambda signal handler for XP display
	var xp_handler: Callable = func(unit: Unit, amount: int, source: String) -> void:
		if _combat_anim_instance and is_instance_valid(_combat_anim_instance):
			var display_name: String = unit.character_data.character_name if unit and unit.character_data else "Unknown"
			_combat_anim_instance.queue_xp_entry(display_name, amount, source)
	ExperienceManager.unit_gained_xp.connect(xp_handler)

	# Track which phases have had their signal emitted (for miss handling later)
	var emitted_phases: Dictionary = {}

	# Create lambda signal handler for damage pooling
	var damage_handler: Callable = func(def_unit: Unit, dmg: int, died: bool) -> void:
		# Find which phase this corresponds to
		var current_phase: CombatPhase = find_current_phase_for_defender(phases, def_unit)
		if current_phase and dmg > 0:
			# Pool damage by attacker/defender pair instead of awarding immediately
			pool_damage_for_xp(xp_pools, current_phase.attacker, def_unit, dmg, died)
			# Track death state
			if def_unit == initial_attacker:
				attacker_died = died
			elif def_unit == initial_defender:
				defender_died = died
			# Emit combat resolved signal (parity with skip_mode)
			if context.combat_resolved_signal:
				context.combat_resolved_signal.emit(
					current_phase.attacker,
					current_phase.defender,
					current_phase.damage,
					not current_phase.was_miss,
					current_phase.was_critical
				)
				emitted_phases[current_phase] = true
	_combat_anim_instance.damage_applied.connect(damage_handler)

	# Hide the battlefield for combat animation overlay
	hide_battlefield(context)

	# ADAPTIVE MUSIC: Enable attack layer during combat animation
	AudioManager.enable_layer(COMBAT_AUDIO_LAYER, AUDIO_LAYER_FADE_DURATION)

	# Start the session (fade in ONCE)
	await _combat_anim_instance.start_session(initial_attacker, initial_defender)

	# HIGH-003: Validate combat_anim_instance after await - may be freed during session start
	if not is_instance_valid(_combat_anim_instance):
		ExperienceManager.unit_gained_xp.disconnect(xp_handler)
		AudioManager.disable_layer(COMBAT_AUDIO_LAYER, AUDIO_LAYER_FADE_DURATION)
		show_battlefield(context)
		return {"attacker_died": attacker_died, "defender_died": defender_died}

	# Queue all phases and their combat action text
	for phase: CombatPhase in phases:
		_combat_anim_instance.queue_phase(phase)
		# Queue combat action for results display
		_combat_anim_instance.queue_combat_action(
			phase.get_result_text(),
			phase.was_critical,
			phase.was_miss
		)

	# Execute all phases (no fading between them!)
	await _combat_anim_instance.execute_all_phases()

	# HIGH-003: Validate combat_anim_instance after await - may be freed during phase execution
	if not is_instance_valid(_combat_anim_instance):
		ExperienceManager.unit_gained_xp.disconnect(xp_handler)
		AudioManager.disable_layer(COMBAT_AUDIO_LAYER, AUDIO_LAYER_FADE_DURATION)
		show_battlefield(context)
		return {"attacker_died": attacker_died, "defender_died": defender_died}

	# Emit combat_resolved for miss phases (hits already emitted via damage_handler)
	# This maintains parity with skip_mode which emits for all phases
	if context.combat_resolved_signal:
		for phase: CombatPhase in phases:
			if phase not in emitted_phases:
				# Skip healing phases - they don't represent combat (parity with skip_mode)
				if phase.phase_type == CombatPhase.PhaseType.ITEM_HEAL or phase.phase_type == CombatPhase.PhaseType.SPELL_HEAL:
					continue
				context.combat_resolved_signal.emit(
					phase.attacker,
					phase.defender,
					phase.damage,
					not phase.was_miss,
					phase.was_critical
				)

	# SF2-AUTHENTIC: Award pooled XP ONCE per attacker/defender pair
	# (This happens after all phases complete, so double attacks show as one XP entry)
	for pool: Dictionary in xp_pools.values():
		ExperienceManager.award_combat_xp(
			pool["attacker"],
			pool["defender"],
			pool["total_damage"],
			pool["got_kill"]
		)

	# Finish session (display XP, fade out ONCE)
	await _combat_anim_instance.finish_session()

	# Disconnect XP handler
	if ExperienceManager.unit_gained_xp.is_connected(xp_handler):
		ExperienceManager.unit_gained_xp.disconnect(xp_handler)

	# HIGH-003: Validate combat_anim_instance after await before cleanup
	if _combat_anim_instance and is_instance_valid(_combat_anim_instance):
		if _combat_anim_instance.damage_applied.is_connected(damage_handler):
			_combat_anim_instance.damage_applied.disconnect(damage_handler)
		_combat_anim_instance.queue_free()
	_combat_anim_instance = null

	# ADAPTIVE MUSIC: Disable attack layer after combat animation
	AudioManager.disable_layer(COMBAT_AUDIO_LAYER, AUDIO_LAYER_FADE_DURATION)

	# Restore battlefield
	show_battlefield(context)

	# Battlefield settle delay
	if context.scene_tree:
		await context.scene_tree.create_timer(BATTLEFIELD_SETTLE_DELAY).timeout

		# HIGH-003: Validate scene_tree after await - may have changed during delay
		if not context.scene_tree:
			return {"attacker_died": attacker_died, "defender_died": defender_died}

	return {
		"attacker_died": attacker_died,
		"defender_died": defender_died
	}


## Main entry point for executing a combat session.
## Routes to skip mode or animation mode based on settings.
## @param context: SessionContext with all required references
## @param initial_attacker: The unit that initiated the attack
## @param initial_defender: The target of the attack
## @param phases: Pre-calculated combat phases to execute
## @return: Dictionary with {attacker_died: bool, defender_died: bool}
func execute(
	context: SessionContext,
	initial_attacker: Unit,
	initial_defender: Unit,
	phases: Array[CombatPhase]
) -> Dictionary:
	# Check if we should skip combat animations
	if TurnManager.is_headless or GameJuice.should_skip_combat_animation():
		return await execute_skip_mode(context, initial_attacker, initial_defender, phases)
	else:
		return await execute_animation_mode(context, initial_attacker, initial_defender, phases)
