## TurnManager - AGI-based turn queue system (Shining Force style)
##
## Manages individual turn order where player and enemy units are intermixed
## based on their agility stats. No separate phases - one unit acts at a time.
extends Node

## Headless mode detection - skips visual delays for automated testing
## Cached at startup for performance
var is_headless: bool = false

# Turn priority calculation constants (Shining Force II formula)
const AGI_VARIANCE_MIN: float = 0.875
const AGI_VARIANCE_MAX: float = 1.125
const AGI_OFFSET_MIN: int = -1
const AGI_OFFSET_MAX: int = 1

## Signals for turn events
signal turn_cycle_started(turn_number: int)
signal player_turn_started(unit: Unit)
signal enemy_turn_started(unit: Unit)
signal unit_turn_ended(unit: Unit)
signal battle_ended(victory: bool)
signal hero_died_in_battle()  ## SF2: Hero death triggers immediate battle exit

## Signals for mod hooks - allow mods to override victory/defeat conditions
## Mods can set context.result = "victory" or "defeat" to force outcome
signal victory_condition_check(battle_data: BattleData, context: Dictionary)
signal defeat_condition_check(battle_data: BattleData, context: Dictionary)

## All units participating in battle (player + enemy + neutral)
var all_units: Array[Unit] = []

## Current turn queue (sorted by AGI priority)
var turn_queue: Array[Unit] = []

## Currently active unit
var active_unit: Unit = null

## Overall turn counter
var turn_number: int = 0

## Battle state
var battle_active: bool = false

## Guard flag to prevent re-entry during async turn advancement
var _advancing_turn: bool = false

## Turn transition delay (allows camera pan, animations, stats panels to settle)
## This delay occurs AFTER unit_turn_ended and BEFORE next unit's turn starts
@export var turn_transition_delay: float = 0.6  # Slightly longer than camera movement_duration

## Reference to camera for awaiting visual transitions
var battle_camera: Camera2D = null

## Timing tracking for debug
var _timing_start_ms: int = 0

## Active popup labels (for cleanup on battle exit)
var _active_popup_labels: Array[Label] = []


func _ready() -> void:
	# Detect headless mode for automated testing (skips visual delays)
	is_headless = DisplayServer.get_name() == "headless"


## Get elapsed time since battle start (for debug timing)
func _get_elapsed_time() -> String:
	var elapsed_ms: int = Time.get_ticks_msec() - _timing_start_ms
	return "[T+%.3fs]" % (elapsed_ms / 1000.0)


## Initialize battle with all units
func start_battle(units: Array[Unit]) -> void:
	if units.is_empty():
		push_error("TurnManager: Cannot start battle with no units")
		return

	all_units = units
	turn_number = 0
	battle_active = true
	_timing_start_ms = Time.get_ticks_msec()

	# Start first turn cycle
	start_new_turn_cycle()


## Calculate turn priority for a unit (Shining Force II formula)
## Returns: AGI * Random(0.875 to 1.125) + Random(-1, 0, 1)
func calculate_turn_priority(unit: Unit) -> float:
	if not unit.has_method("get_stats_summary"):
		push_warning("TurnManager: Unit missing stats")
		return 0.0

	var base_agi: float = unit.stats.agility if unit.stats else 5.0

	# Randomize AGI: 87.5% to 112.5% of base value
	var random_mult: float = randf_range(AGI_VARIANCE_MIN, AGI_VARIANCE_MAX)

	# Add small random offset: -1, 0, or +1
	var random_offset: float = float(randi_range(AGI_OFFSET_MIN, AGI_OFFSET_MAX))

	var priority: float = (base_agi * random_mult) + random_offset

	return priority


## Calculate turn order for all living units
func calculate_turn_order() -> void:
	turn_queue.clear()

	# Calculate priority for each living unit
	for unit: Unit in all_units:
		if not unit.is_alive():
			continue

		var priority: float = calculate_turn_priority(unit)
		unit.turn_priority = priority
		turn_queue.append(unit)

	# Sort by priority (highest first)
	turn_queue.sort_custom(func(a: Unit, b: Unit) -> bool: return a.turn_priority > b.turn_priority)


## Start a new turn cycle
func start_new_turn_cycle() -> void:
	turn_number += 1
	turn_cycle_started.emit(turn_number)

	# Reset all unit visuals (remove dimming from previous round)
	for unit: Unit in all_units:
		if unit.is_alive() and unit.has_method("reset_acted_visual"):
			unit.reset_acted_visual()

	# Recalculate turn order with new AGI randomization
	calculate_turn_order()

	# Check if battle is over before starting turns
	if _check_battle_end():
		return

	# Start first unit's turn
	if not turn_queue.is_empty():
		var first_unit: Unit = turn_queue.pop_front()
		start_unit_turn(first_unit)
	else:
		push_error("TurnManager: Turn queue is empty after calculation")
		battle_active = false


## Start a unit's turn
func start_unit_turn(unit: Unit) -> void:
	if not unit or not unit.is_alive():
		# Skip dead units, get next
		advance_to_next_unit()
		return

	active_unit = unit

	# Process terrain effects BEFORE unit.start_turn() (damage happens at turn start)
	var terrain_died: bool = await _process_terrain_effects(unit)
	if terrain_died:
		# Unit died from terrain damage - skip their turn
		unit_turn_ended.emit(unit)
		advance_to_next_unit()
		return

	# Process status effects (sleep, paralysis, poison damage, etc.)
	var status_result: Dictionary = await _process_status_effects(unit)
	if status_result.died:
		# Unit died from status effect damage (e.g., poison)
		unit_turn_ended.emit(unit)
		advance_to_next_unit()
		return
	if status_result.skip_turn:
		# Unit is incapacitated (sleep, paralysis) - skip their turn
		unit.end_turn()
		unit_turn_ended.emit(unit)
		advance_to_next_unit()
		return

	unit.start_turn()

	if unit.is_player_unit():
		# Player unit - wait for player input
		player_turn_started.emit(unit)
		# InputManager will handle from here
	else:
		# Enemy/AI unit - emit signal and await visual setup completion
		enemy_turn_started.emit(unit)

		# Wait for camera pan to complete (signal handlers start the camera movement)
		if battle_camera:
			await battle_camera.movement_completed
			# HIGH-002: Validate unit still valid after await on camera
			if not is_instance_valid(unit):
				return

		# Now delegate to AIController
		await AIController.process_enemy_turn(unit)


## End the current unit's turn
func end_unit_turn(unit: Unit) -> void:
	if unit != active_unit:
		push_warning("TurnManager: Trying to end turn for non-active unit")
		return

	unit.end_turn()
	unit_turn_ended.emit(unit)

	active_unit = null

	# Check battle end conditions
	if _check_battle_end():
		return

	# Advance to next unit
	advance_to_next_unit()


## Advance to the next unit in queue
## Now async to allow for turn transition delay
func advance_to_next_unit() -> void:
	# Guard against re-entry during async operations
	# This prevents double-popping from turn_queue if called concurrently
	if _advancing_turn:
		push_warning("TurnManager: advance_to_next_unit called while already advancing")
		return
	_advancing_turn = true

	# Add delay before starting next unit's turn
	# This allows camera pans, animations, and UI updates to complete
	# Skip in headless mode for faster automated testing
	if turn_transition_delay > 0 and not is_headless:
		await get_tree().create_timer(turn_transition_delay).timeout

	# Clear flag before start_unit_turn - it may recursively call advance_to_next_unit
	# if the unit is invalid/dead/incapacitated
	_advancing_turn = false

	if turn_queue.is_empty():
		# Turn cycle complete, start new cycle
		start_new_turn_cycle()
	else:
		# Get next unit
		var next_unit: Unit = turn_queue.pop_front()
		start_unit_turn(next_unit)


## Check if battle has ended (victory or defeat)
func _check_battle_end() -> bool:
	if not battle_active:
		return true

	# Get battle data from BattleManager for condition checks
	var battle_data: BattleData = BattleManager.current_battle_data

	# Count living units by faction and track hero/boss status
	var player_count: int = 0
	var enemy_count: int = 0
	var hero_alive: bool = false
	var boss_alive: bool = true

	for unit: Unit in all_units:
		if not unit.is_alive():
			continue

		if unit.is_player_unit():
			player_count += 1
			if unit.character_data and unit.character_data.is_hero:
				hero_alive = true
		elif unit.is_enemy_unit():
			enemy_count += 1

	# Check if boss is dead (for DEFEAT_BOSS condition)
	if battle_data and battle_data.victory_condition == BattleData.VictoryCondition.DEFEAT_BOSS:
		boss_alive = _is_boss_alive(battle_data)

	# Check defeat conditions first (defeat takes priority)
	var defeat_result: String = _check_defeat_condition(battle_data, player_count, hero_alive)
	if defeat_result == "defeat":
		active_unit = null
		turn_queue.clear()
		hero_died_in_battle.emit()
		return true

	# Check victory conditions
	var victory_result: String = _check_victory_condition(battle_data, enemy_count, boss_alive)
	if victory_result == "victory":
		_end_battle(true)
		return true

	return false


## Check victory condition based on BattleData configuration
## Returns "victory" if condition met, "" otherwise
func _check_victory_condition(battle_data: BattleData, enemy_count: int, boss_alive: bool) -> String:
	# Allow mods to override victory condition
	var context: Dictionary = {"result": "", "enemy_count": enemy_count, "turn_number": turn_number}
	victory_condition_check.emit(battle_data, context)
	if context.result == "victory":
		return "victory"

	# No battle data = use default (defeat all enemies)
	if not battle_data:
		return "victory" if enemy_count == 0 else ""

	match battle_data.victory_condition:
		BattleData.VictoryCondition.DEFEAT_ALL_ENEMIES:
			if enemy_count == 0:
				return "victory"
		BattleData.VictoryCondition.DEFEAT_BOSS:
			if not boss_alive:
				return "victory"
		BattleData.VictoryCondition.SURVIVE_TURNS:
			if turn_number >= battle_data.victory_turn_count:
				return "victory"
		# REACH_LOCATION, PROTECT_UNIT, CUSTOM - not yet implemented
		_:
			# Default fallback: all enemies dead
			if enemy_count == 0:
				return "victory"

	return ""


## Check defeat condition based on BattleData configuration
## Returns "defeat" if condition met, "" otherwise
func _check_defeat_condition(battle_data: BattleData, player_count: int, hero_alive: bool) -> String:
	# Allow mods to override defeat condition
	var context: Dictionary = {"result": "", "player_count": player_count, "turn_number": turn_number}
	defeat_condition_check.emit(battle_data, context)
	if context.result == "defeat":
		return "defeat"

	# SF2-authentic: Hero death = immediate defeat (always checked, regardless of condition)
	if not hero_alive:
		return "defeat"

	# No battle data = use defaults only
	if not battle_data:
		return ""

	match battle_data.defeat_condition:
		BattleData.DefeatCondition.ALL_UNITS_DEFEATED:
			if player_count == 0:
				return "defeat"
		BattleData.DefeatCondition.LEADER_DEFEATED:
			# Already handled above (hero_alive check)
			pass
		BattleData.DefeatCondition.TURN_LIMIT:
			if battle_data.defeat_turn_limit > 0 and turn_number > battle_data.defeat_turn_limit:
				return "defeat"
		# UNIT_DIES, CUSTOM - not yet implemented
		_:
			pass

	return ""


## Check if the boss enemy is still alive
func _is_boss_alive(battle_data: BattleData) -> bool:
	if not battle_data or battle_data.victory_boss_index < 0:
		# Fallback: check any enemy with is_boss flag
		for unit: Unit in all_units:
			if unit.is_enemy_unit() and unit.is_alive():
				if unit.character_data and unit.character_data.is_boss:
					return true
		return false

	# Check specific boss by index
	var boss_index: int = battle_data.victory_boss_index
	var enemy_index: int = 0
	for unit: Unit in all_units:
		if unit.is_enemy_unit():
			if enemy_index == boss_index:
				return unit.is_alive()
			enemy_index += 1

	return false


## End the battle
func _end_battle(victory: bool) -> void:
	battle_active = false
	active_unit = null
	turn_queue.clear()

	battle_ended.emit(victory)


## Get the currently active unit
func get_active_unit() -> Unit:
	return active_unit


## Check if it's a player unit's turn
func is_player_turn() -> bool:
	return active_unit != null and active_unit.is_player_unit()


## Check if battle is active
func is_battle_active() -> bool:
	return battle_active


## Get remaining units in turn queue
func get_remaining_turn_queue() -> Array[Unit]:
	return turn_queue.duplicate()


## Get turn number
func get_turn_number() -> int:
	return turn_number


## Process terrain effects for a unit at the start of their turn
## Returns true if the unit died from terrain damage
func _process_terrain_effects(unit: Unit) -> bool:
	if not unit or not unit.is_alive():
		return false

	# Get terrain at unit's position
	var terrain: TerrainData = GridManager.get_terrain_at_cell(unit.grid_position)
	if terrain == null:
		return false

	# Flying units are immune to ground-based terrain damage
	var unit_class: ClassData = unit.get_current_class()
	if unit_class:
		var movement_type: int = unit_class.movement_type
		if movement_type == ClassData.MovementType.FLYING:
			return false  # Flying units ignore terrain DoT

	# Apply terrain damage
	if terrain.damage_per_turn > 0:
		if not is_headless:
			_show_terrain_popup(unit, "-%d (%s)" % [terrain.damage_per_turn, terrain.display_name], Color.RED)

		if unit.has_method("take_damage"):
			unit.take_damage(terrain.damage_per_turn)
		elif unit.stats:
			unit.stats.current_hp -= terrain.damage_per_turn
			unit.stats.current_hp = maxi(0, unit.stats.current_hp)

		# Check if unit died
		if unit.has_method("is_dead"):
			if unit.is_dead():
				return true
		elif unit.stats and unit.stats.current_hp <= 0:
			return true

	# Apply terrain healing
	if terrain.healing_per_turn > 0 and unit.stats:
		var max_hp: int = unit.stats.get_effective_max_hp() if unit.stats.has_method("get_effective_max_hp") else unit.stats.max_hp
		var old_hp: int = unit.stats.current_hp
		unit.stats.current_hp = mini(unit.stats.current_hp + terrain.healing_per_turn, max_hp)
		var healed: int = unit.stats.current_hp - old_hp
		if healed > 0 and not is_headless:
			_show_terrain_popup(unit, "+%d (%s)" % [healed, terrain.display_name], Color.GREEN)

	return false


## Show a popup for terrain effects (damage or healing)
func _show_terrain_popup(unit: Unit, message: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = message
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 16)
	label.position = unit.position + Vector2(0, -20)
	label.z_index = 100

	if unit.get_parent():
		unit.get_parent().add_child(label)
		_active_popup_labels.append(label)
		var tween: Tween = label.create_tween()
		tween.tween_property(label, "position:y", label.position.y - 30, 0.8)
		tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
		tween.tween_callback(_remove_popup_label.bind(label))


## Process status effects for a unit at the start of their turn
## Returns Dictionary: {skip_turn: bool, died: bool}
## - skip_turn: true if unit should skip their turn (sleep, paralysis)
## - died: true if unit died from status damage (poison)
##
## Uses data-driven StatusEffectData from ModLoader.status_effect_registry
func _process_status_effects(unit: Unit) -> Dictionary:
	var result: Dictionary = {"skip_turn": false, "died": false}

	if not unit or not unit.is_alive() or not unit.stats:
		return result

	var stats: UnitStats = unit.stats
	var effects_to_remove: Array[String] = []
	var showed_popup: bool = false

	# Process each status effect on the unit
	for i: int in range(stats.status_effects.size() - 1, -1, -1):
		var effect_state: Dictionary = stats.status_effects[i]
		var effect_type: String = effect_state.get("type", "")

		# Look up effect data from registry
		var effect_data: StatusEffectData = ModLoader.status_effect_registry.get_effect(effect_type)

		if not effect_data:
			# Effect not in registry - use legacy hardcoded fallback for backwards compatibility
			var legacy_result: Dictionary = _process_legacy_status_effect(unit, effect_state, effects_to_remove)
			if legacy_result.skip_turn:
				result.skip_turn = true
			if legacy_result.showed_popup:
				showed_popup = true
			continue

		# Only process TURN_START effects here (other timings handled elsewhere)
		if effect_data.trigger_timing != StatusEffectData.TriggerTiming.TURN_START:
			# Still show visual feedback for non-TURN_START effects
			if effect_data.trigger_timing == StatusEffectData.TriggerTiming.ON_ACTION:
				if not is_headless:
					_show_status_popup(unit, effect_data.get_popup_text(), effect_data.popup_color)
					showed_popup = true
			continue

		# Handle skip_turn effects with recovery chance
		if effect_data.skips_turn:
			if effect_data.recovery_chance_per_turn > 0:
				var recovery_roll: int = randi_range(1, 100)
				if recovery_roll <= effect_data.recovery_chance_per_turn:
					# Recovered!
					effects_to_remove.append(effect_type)
					if not is_headless:
						_show_status_popup(unit, "Recovered!", Color(0.2, 1.0, 0.2))
						showed_popup = true
					continue

			# Still affected - skip turn
			result.skip_turn = true
			if not is_headless:
				_show_status_popup(unit, effect_data.get_popup_text(), effect_data.popup_color)
				showed_popup = true

		# Handle damage over time
		if effect_data.damage_per_turn != 0:
			if effect_data.damage_per_turn > 0:
				# Damage
				if not is_headless:
					_show_status_popup(unit, effect_data.get_popup_text(), effect_data.popup_color)
					showed_popup = true

				if unit.has_method("take_damage"):
					unit.take_damage(effect_data.damage_per_turn)
				else:
					stats.current_hp -= effect_data.damage_per_turn
					stats.current_hp = maxi(0, stats.current_hp)

				# Check for death
				if not unit.is_alive():
					result.died = true
					return result
			else:
				# Healing (negative damage)
				var heal_amount: int = -effect_data.damage_per_turn
				if unit.has_method("heal"):
					unit.heal(heal_amount)
				else:
					stats.current_hp = mini(stats.current_hp + heal_amount, stats.max_hp)

				if not is_headless:
					_show_status_popup(unit, effect_data.get_popup_text(), effect_data.popup_color)
					showed_popup = true

		# Decrement duration
		effect_state.duration -= 1
		if effect_state.duration <= 0:
			effects_to_remove.append(effect_type)

	# Remove expired effects and recovered effects
	for effect_type: String in effects_to_remove:
		unit.remove_status_effect(effect_type)

	# Brief visual pause if any status was shown
	if not is_headless and showed_popup:
		await get_tree().create_timer(0.6).timeout

	return result


## Legacy fallback for status effects not in registry (backwards compatibility)
## Returns: {skip_turn: bool, showed_popup: bool}
func _process_legacy_status_effect(
	unit: Unit,
	effect_state: Dictionary,
	effects_to_remove: Array[String]
) -> Dictionary:
	var result: Dictionary = {"skip_turn": false, "showed_popup": false}
	var effect_type: String = effect_state.get("type", "")

	match effect_type:
		"poison":
			# Poison damage is handled at END of turn via UnitStats.process_status_effects()
			# Just show visual feedback here at turn start
			if not is_headless:
				_show_status_popup(unit, "Poisoned!", Color(0.6, 0.2, 0.8))
				result.showed_popup = true

		"sleep":
			# Sleep: skip turn, show message
			result.skip_turn = true
			if not is_headless:
				_show_status_popup(unit, "Asleep!", Color(0.4, 0.4, 1.0))
				result.showed_popup = true

		"paralysis":
			# Paralysis: 25% chance to recover each turn, otherwise skip
			var recovery_roll: int = randi_range(1, 100)
			if recovery_roll <= 25:
				# Recovered from paralysis!
				effects_to_remove.append("paralysis")
				if not is_headless:
					_show_status_popup(unit, "Recovered!", Color(0.2, 1.0, 0.2))
					result.showed_popup = true
			else:
				# Still paralyzed
				result.skip_turn = true
				if not is_headless:
					_show_status_popup(unit, "Paralyzed!", Color(1.0, 1.0, 0.2))
					result.showed_popup = true

		"confusion":
			# Confusion is handled during action selection, not here
			# Just show visual feedback
			if not is_headless:
				_show_status_popup(unit, "Confused!", Color(1.0, 0.5, 0.7))
				result.showed_popup = true

		"attack_up", "attack_down", "defense_up", "defense_down", "speed_up", "speed_down":
			# Stat modifiers are handled in UnitStats.get_effective_*() methods
			# No visual feedback at turn start (they're passive)
			pass

		"regen":
			# Regen healing is handled at END of turn via UnitStats.process_status_effects()
			if not is_headless:
				_show_status_popup(unit, "Regenerating", Color(0.2, 1.0, 0.5))
				result.showed_popup = true

		_:
			# Unknown effect - log but don't crash
			push_warning("[TurnManager] Unknown legacy status effect: '%s'" % effect_type)

	# Decrement duration for legacy effects
	effect_state.duration -= 1
	if effect_state.duration <= 0:
		effects_to_remove.append(effect_type)

	return result


## Show a status effect popup above unit
func _show_status_popup(unit: Unit, message: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = message
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 16)
	label.position = unit.position + Vector2(0, -30)
	label.z_index = 100

	if unit.get_parent():
		unit.get_parent().add_child(label)
		_active_popup_labels.append(label)

		# Animate and remove
		var tween: Tween = label.create_tween()
		tween.tween_property(label, "position:y", label.position.y - 20, 0.6)
		tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
		tween.tween_callback(_remove_popup_label.bind(label))


## Helper to get unit display name safely
func _get_unit_name(unit: Unit) -> String:
	if unit.has_method("get_display_name"):
		return unit.get_display_name()
	return "Unknown"


## Remove a popup label from tracking and free it
func _remove_popup_label(label: Label) -> void:
	_active_popup_labels.erase(label)
	if is_instance_valid(label):
		label.queue_free()


## Clear battle state (call when exiting battle)
func clear_battle() -> void:
	all_units.clear()
	turn_queue.clear()
	active_unit = null
	turn_number = 0
	battle_active = false
	_advancing_turn = false

	# Clean up any active popup labels (freeing label also kills its bound tweens)
	# Tweens created via label.create_tween() are bound to the label's lifetime
	for label: Label in _active_popup_labels:
		if is_instance_valid(label):
			label.queue_free()
	_active_popup_labels.clear()
