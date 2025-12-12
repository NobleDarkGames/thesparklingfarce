extends "res://core/resources/ai_brain.gd"

class_name ConfigurableAIBrain

## ConfigurableAIBrain - Interprets AIBehaviorData at runtime
##
## This brain reads configuration from AIBehaviorData and executes
## behavior using the existing AIBrain helper methods (pathfinding, attacking).
##
## Unlike script-based AIBrains, this allows modders to create AI behaviors
## through data files without writing GDScript.

## Singleton instance for use by AIController
static var _instance: AIBrain = null  # Use base class type to avoid self-reference issue


static func get_instance() -> AIBrain:
	if _instance == null:
		# Use load() to get a reference to this script and create instance
		var script: GDScript = load("res://core/systems/ai/configurable_ai_brain.gd")
		_instance = script.new()
	return _instance


## Execute AI behavior based on AIBehaviorData configuration
func execute_with_behavior(unit: Node2D, context: Dictionary, behavior: AIBehaviorData) -> void:
	if not behavior:
		push_warning("ConfigurableAIBrain: No behavior data, using default aggressive")
		await execute_async(unit, context)
		return

	var role: String = behavior.get_effective_role()
	var mode: String = behavior.get_effective_mode()

	# Add HP percent to context for phase evaluation
	if unit.stats:
		var hp_percent: float = (float(unit.stats.current_hp) / float(unit.stats.max_hp)) * 100.0
		context["unit_hp_percent"] = hp_percent

	# Check for behavior phase changes
	var phase_changes: Dictionary = behavior.evaluate_phase_changes(context)
	if not phase_changes.is_empty():
		if "role" in phase_changes:
			role = phase_changes["role"]
		if "behavior_mode" in phase_changes:
			mode = phase_changes["behavior_mode"]

	# Execute based on ROLE first (what the AI prioritizes)
	# Then fall back to MODE (how it executes attacks)
	match role:
		"support":
			# Support role: prioritize healing allies before attacking
			var healed: bool = await _execute_support_role(unit, context, behavior)
			if healed:
				return  # Successfully healed, turn done
			# No healing needed/possible - fall through to mode-based attack
		"defensive":
			# Defensive role: protect high-value targets
			# TODO: Implement defensive positioning and bodyguard behavior
			pass
		"tactical":
			# Tactical role: complex spell usage, debuffs
			# TODO: Implement tactical spell prioritization
			pass
		# "aggressive" is the default - no special pre-processing

	# Execute based on behavior MODE (how it attacks)
	match mode:
		"cautious":
			await _execute_cautious(unit, context, behavior)
		"opportunistic":
			await _execute_opportunistic(unit, context, behavior)
		_:  # "aggressive" or default
			await _execute_aggressive(unit, context, behavior)


## Default execute_async - aggressive behavior (for fallback)
func execute_async(unit: Node2D, context: Dictionary) -> void:
	await _execute_aggressive(unit, context, null)


## Aggressive behavior: move toward nearest enemy and attack
func _execute_aggressive(unit: Node2D, context: Dictionary, behavior: AIBehaviorData) -> void:
	var player_units: Array[Node2D] = get_player_units(context)
	if player_units.is_empty():
		return

	# Find target based on threat weights if behavior provided, else nearest
	var target: Node2D
	if behavior:
		target = _find_best_target(unit, player_units, behavior)
	else:
		target = find_nearest_target(unit, player_units)

	if not target:
		return

	var delays: Dictionary = context.get("ai_delays", {})
	var delay_after_movement: float = delays.get("after_movement", 0.5)
	var delay_before_attack: float = delays.get("before_attack", 0.3)

	# If already in attack range, attack immediately
	if is_in_attack_range(unit, target):
		if delay_before_attack > 0:
			await unit.get_tree().create_timer(delay_before_attack).timeout
		await attack_target(unit, target)
		return

	# Move toward target
	var moved: bool = move_toward_target(unit, target.grid_position)

	if moved:
		await unit.await_movement_completion()
		if delay_after_movement > 0:
			await unit.get_tree().create_timer(delay_after_movement).timeout

	# Attack if now in range
	if is_in_attack_range(unit, target):
		if delay_before_attack > 0:
			await unit.get_tree().create_timer(delay_before_attack).timeout
		await attack_target(unit, target)


## Cautious behavior: only attack adjacent enemies, limited pursuit
func _execute_cautious(unit: Node2D, context: Dictionary, behavior: AIBehaviorData) -> void:
	var player_units: Array[Node2D] = get_player_units(context)
	if player_units.is_empty():
		return

	var delays: Dictionary = context.get("ai_delays", {})
	var delay_before_attack: float = delays.get("before_attack", 0.3)

	# Check for adjacent targets first
	for target: Node2D in player_units:
		if not target.is_alive():
			continue
		if is_in_attack_range(unit, target):
			if delay_before_attack > 0:
				await unit.get_tree().create_timer(delay_before_attack).timeout
			await attack_target(unit, target)
			return

	# Only pursue if enemy within alert range
	var alert_range: int = behavior.alert_range if behavior else 8
	var nearest: Node2D = find_nearest_target(unit, player_units)
	if nearest:
		var distance: int = GridManager.grid.get_manhattan_distance(unit.grid_position, nearest.grid_position)
		if distance <= alert_range:
			var engagement_range: int = behavior.engagement_range if behavior else 5
			if distance > engagement_range:
				var moved: bool = move_toward_target(unit, nearest.grid_position)
				if moved:
					await unit.await_movement_completion()


## Opportunistic behavior: prioritize wounded, retreat if low HP
func _execute_opportunistic(unit: Node2D, context: Dictionary, behavior: AIBehaviorData) -> void:
	var player_units: Array[Node2D] = get_player_units(context)
	if player_units.is_empty():
		return

	# Check retreat condition
	if behavior and behavior.retreat_enabled:
		var hp_percent: float = context.get("unit_hp_percent", 100.0)
		if hp_percent < behavior.retreat_hp_threshold:
			await _execute_retreat(unit, player_units, context)
			return

	# Find best target (wounded priority)
	var target: Node2D = _find_best_target(unit, player_units, behavior)
	if not target:
		return

	# Standard attack pattern
	await _execute_aggressive(unit, context, behavior)


## Retreat behavior: move away from enemies
func _execute_retreat(unit: Node2D, enemies: Array[Node2D], _context: Dictionary) -> void:
	var unit_class: ClassData = unit.get_current_class()
	if not unit_class:
		return

	var movement_range: int = unit_class.movement_range
	var reachable: Array[Vector2i] = GridManager.get_walkable_cells(unit.grid_position, movement_range, unit_class.movement_type, unit.faction)

	if reachable.is_empty():
		return

	# Find cell furthest from all enemies
	var best_cell: Vector2i = unit.grid_position
	var best_min_dist: int = 0

	for cell: Vector2i in reachable:
		if cell != unit.grid_position and GridManager.is_cell_occupied(cell):
			continue

		var min_dist: int = 999
		for enemy: Node2D in enemies:
			if enemy.is_alive():
				var dist: int = GridManager.grid.get_manhattan_distance(cell, enemy.grid_position)
				min_dist = mini(min_dist, dist)

		if min_dist > best_min_dist:
			best_min_dist = min_dist
			best_cell = cell

	if best_cell != unit.grid_position:
		# Use simple movement to retreat cell
		unit.move_along_path([unit.grid_position, best_cell])
		await unit.await_movement_completion()


## Find best target based on threat weights
func _find_best_target(unit: Node2D, targets: Array[Node2D], behavior: AIBehaviorData) -> Node2D:
	if targets.is_empty():
		return null

	var best_target: Node2D = null
	var best_score: float = -999.0

	var wounded_weight: float = behavior.get_effective_threat_weight("wounded_target", 1.0) if behavior else 1.0
	var proximity_weight: float = behavior.get_effective_threat_weight("proximity", 1.0) if behavior else 1.0

	for target: Node2D in targets:
		if not target.is_alive():
			continue

		var score: float = 0.0

		# Wounded target priority
		if target.stats:
			var hp_percent: float = float(target.stats.current_hp) / float(target.stats.max_hp)
			score += (1.0 - hp_percent) * wounded_weight * 100.0

		# Proximity bonus
		var dist: int = GridManager.grid.get_manhattan_distance(unit.grid_position, target.grid_position)
		score += (20 - dist) * proximity_weight * 5.0

		if score > best_score:
			best_score = score
			best_target = target

	return best_target


# =============================================================================
# SUPPORT ROLE IMPLEMENTATION
# =============================================================================

## Execute support role: heal wounded allies, fall back to attack if none need healing
## Returns true if a healing action was performed
func _execute_support_role(unit: Node2D, context: Dictionary, behavior: AIBehaviorData) -> bool:
	# Get allied units (same faction)
	var allies: Array[Node2D] = _get_allied_units(unit, context)

	# Find wounded allies
	var wounded_allies: Array[Node2D] = _find_wounded_allies(allies, behavior)

	if wounded_allies.is_empty():
		return false  # No one to heal

	# Get unit's healing abilities
	var healing_abilities: Array[Dictionary] = _get_unit_healing_abilities(unit)

	if healing_abilities.is_empty():
		return false  # No healing abilities available

	# Find best target to heal
	var heal_target: Node2D = _find_best_heal_target(unit, wounded_allies, behavior)

	if not heal_target:
		return false

	# Find best healing ability for this target
	var best_ability: Dictionary = _select_best_healing_ability(unit, heal_target, healing_abilities, behavior)

	if best_ability.is_empty():
		return false  # No suitable ability (MP too low, etc.)

	var ability_id: String = best_ability.get("id", "")
	var ability_range: int = best_ability.get("range", 1)

	# Check if target is in range
	var distance: int = GridManager.grid.get_manhattan_distance(unit.grid_position, heal_target.grid_position)

	if distance > ability_range:
		# Move toward target to get in range
		var moved: bool = _move_into_spell_range(unit, heal_target.grid_position, ability_range)
		if moved:
			await unit.await_movement_completion()
			var delays: Dictionary = context.get("ai_delays", {})
			var delay_after_movement: float = delays.get("after_movement", 0.5)
			if delay_after_movement > 0:
				await unit.get_tree().create_timer(delay_after_movement).timeout

		# Recalculate distance after moving
		distance = GridManager.grid.get_manhattan_distance(unit.grid_position, heal_target.grid_position)
		if distance > ability_range:
			return false  # Still out of range

	# Cast the healing spell
	var delays: Dictionary = context.get("ai_delays", {})
	var delay_before_spell: float = delays.get("before_attack", 0.3)
	if delay_before_spell > 0:
		await unit.get_tree().create_timer(delay_before_spell).timeout

	var success: bool = await BattleManager.execute_ai_spell(unit, ability_id, heal_target)
	return success


## Get all units allied to this unit (same faction)
func _get_allied_units(unit: Node2D, context: Dictionary) -> Array[Node2D]:
	var allies: Array[Node2D] = []

	match unit.faction:
		"enemy":
			allies = get_enemy_units(context)
		"player":
			allies = get_player_units(context)
		"neutral":
			allies = get_neutral_units(context)

	return allies


## Find wounded allies that could benefit from healing
func _find_wounded_allies(allies: Array[Node2D], behavior: AIBehaviorData) -> Array[Node2D]:
	var wounded: Array[Node2D] = []

	# Determine minimum damage threshold for healing (default: 20% missing HP)
	var heal_threshold: float = 0.8  # Heal if below 80% HP

	for ally: Node2D in allies:
		if not ally.is_alive() or not ally.stats:
			continue

		var hp_percent: float = float(ally.stats.current_hp) / float(ally.stats.max_hp)
		if hp_percent < heal_threshold:
			wounded.append(ally)

	return wounded


## Find best target to heal based on priority rules
func _find_best_heal_target(unit: Node2D, wounded: Array[Node2D], behavior: AIBehaviorData) -> Node2D:
	if wounded.is_empty():
		return null

	var best_target: Node2D = null
	var best_score: float = -999.0
	var prioritize_boss: bool = behavior.prioritize_boss_heals if behavior else false

	for ally: Node2D in wounded:
		var score: float = 0.0

		# Most wounded gets highest priority
		var hp_percent: float = float(ally.stats.current_hp) / float(ally.stats.max_hp)
		score += (1.0 - hp_percent) * 100.0

		# Boss/leader priority
		if prioritize_boss:
			# Check if this is a "boss" unit (could check a flag or position in enemy list)
			# For now, units with higher max HP are considered more important
			score += float(ally.stats.max_hp) * 0.1

		# Proximity bonus (prefer closer allies)
		var dist: int = GridManager.grid.get_manhattan_distance(unit.grid_position, ally.grid_position)
		score += (20 - dist) * 2.0

		# Self-healing bonus (slight preference to heal self if equally wounded)
		if ally == unit:
			score += 5.0

		if score > best_score:
			best_score = score
			best_target = ally

	return best_target


## Get list of healing abilities the unit can use
func _get_unit_healing_abilities(unit: Node2D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if not unit.stats:
		return result

	# Get unit's class abilities
	var unit_class: ClassData = unit.get_current_class()
	if not unit_class:
		return result

	# Get all abilities unlocked at current level using ClassData's helper method
	var unlocked_abilities: Array[AbilityData] = unit_class.get_unlocked_class_abilities(unit.stats.level)

	for ability: AbilityData in unlocked_abilities:
		if not ability:
			continue

		# Check if it's a healing ability
		if ability.ability_type == AbilityData.AbilityType.HEAL:
			result.append({
				"id": ability.ability_id,
				"ability": ability,
				"range": ability.max_range,
				"mp_cost": ability.mp_cost,
				"power": ability.power,
				"aoe": ability.area_of_effect
			})

	return result


## Select the best healing ability for this situation
func _select_best_healing_ability(unit: Node2D, target: Node2D, abilities: Array[Dictionary], behavior: AIBehaviorData) -> Dictionary:
	if abilities.is_empty():
		return {}

	var best_ability: Dictionary = {}
	var best_score: float = -999.0
	var conserve_mp: bool = behavior.conserve_mp_on_heals if behavior else false

	var missing_hp: int = target.stats.max_hp - target.stats.current_hp

	for ability_info: Dictionary in abilities:
		var mp_cost: int = ability_info.get("mp_cost", 0)
		var power: int = ability_info.get("power", 0)

		# Can't afford this spell
		if mp_cost > unit.stats.current_mp:
			continue

		var score: float = 0.0

		# Prefer abilities that won't overheal too much
		var overheal: int = maxi(0, power - missing_hp)
		var efficiency: float = 1.0 - (float(overheal) / float(power + 1))
		score += efficiency * 50.0

		# If conserving MP, prefer cheaper spells
		if conserve_mp:
			score -= mp_cost * 2.0
		else:
			# Otherwise prefer stronger heals
			score += power * 0.5

		if score > best_score:
			best_score = score
			best_ability = ability_info

	return best_ability


## Move unit into spell casting range of target
func _move_into_spell_range(unit: Node2D, target_pos: Vector2i, spell_range: int) -> bool:
	if not unit:
		return false

	var unit_class: ClassData = unit.get_current_class()
	if not unit_class:
		return false

	var movement_range: int = unit_class.movement_range
	var reachable: Array[Vector2i] = GridManager.get_walkable_cells(unit.grid_position, movement_range, unit_class.movement_type, unit.faction)

	# Find best cell that puts us in range of target
	var best_cell: Vector2i = unit.grid_position
	var best_distance_to_range: int = 999
	var current_dist: int = GridManager.grid.get_manhattan_distance(unit.grid_position, target_pos)

	for cell: Vector2i in reachable:
		if cell != unit.grid_position and GridManager.is_cell_occupied(cell):
			continue

		var dist: int = GridManager.grid.get_manhattan_distance(cell, target_pos)

		# Check if this cell is in range
		if dist <= spell_range:
			# Prefer staying closer to current position (less movement)
			var movement_cost: int = GridManager.grid.get_manhattan_distance(unit.grid_position, cell)
			if best_distance_to_range > 0 or movement_cost < GridManager.grid.get_manhattan_distance(unit.grid_position, best_cell):
				best_distance_to_range = 0
				best_cell = cell
		elif dist < current_dist and best_distance_to_range > 0:
			# Not in range, but closer than we are now
			if dist - spell_range < best_distance_to_range:
				best_distance_to_range = dist - spell_range
				best_cell = cell

	if best_cell == unit.grid_position:
		return false  # No better position found

	# Find path to best cell
	var movement_type: int = unit_class.movement_type
	var path: Array[Vector2i] = GridManager.find_path(unit.grid_position, best_cell, movement_type, unit.faction)

	if path.is_empty():
		return false

	unit.move_along_path(path)
	return true
