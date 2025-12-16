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
			# Defensive role: protect high-value allies (bodyguard behavior)
			await _execute_defensive_role(unit, context, behavior)
			return  # Defensive role handles its own attack logic
		"tactical":
			# Tactical role: prioritize debuffs and status effects
			var debuffed: bool = await _execute_tactical_role(unit, context, behavior)
			if debuffed:
				return  # Successfully applied debuff, turn done
			# No debuff possible - fall through to mode-based attack
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
		if delay_before_attack > 0 and unit.get_tree():
			await unit.get_tree().create_timer(delay_before_attack).timeout
		await attack_target(unit, target)
		return

	# Move toward target
	var moved: bool = move_toward_target(unit, target.grid_position)

	if moved:
		await unit.await_movement_completion()
		if delay_after_movement > 0 and unit.get_tree():
			await unit.get_tree().create_timer(delay_after_movement).timeout

	# Attack if now in range (verify target still alive after movement)
	if target.is_alive() and is_in_attack_range(unit, target):
		if delay_before_attack > 0 and unit.get_tree():
			await unit.get_tree().create_timer(delay_before_attack).timeout
		await attack_target(unit, target)


## Cautious behavior: hold position, attack enemies that enter engagement zone, limited pursuit
## - alert_range: how far enemy can be before AI notices and may approach
## - engagement_range: how close enemy must be for AI to commit to attack
func _execute_cautious(unit: Node2D, context: Dictionary, behavior: AIBehaviorData) -> void:
	var player_units: Array[Node2D] = get_player_units(context)
	if player_units.is_empty():
		return

	var delays: Dictionary = context.get("ai_delays", {})
	var delay_before_attack: float = delays.get("before_attack", 0.3)
	var delay_after_movement: float = delays.get("after_movement", 0.5)

	# Check for targets in attack range first - attack immediately if found
	for target: Node2D in player_units:
		if not target.is_alive():
			continue
		if is_in_attack_range(unit, target):
			if delay_before_attack > 0 and unit.get_tree():
				await unit.get_tree().create_timer(delay_before_attack).timeout
			await attack_target(unit, target)
			return

	# Find nearest enemy
	var nearest: Node2D = find_nearest_target(unit, player_units)
	if not nearest:
		return

	var distance: int = GridManager.grid.get_manhattan_distance(unit.grid_position, nearest.grid_position)
	var alert_range: int = behavior.alert_range if behavior else 8
	var engagement_range: int = behavior.engagement_range if behavior else 5

	# Only react to enemies within alert range
	if distance > alert_range:
		return

	# Move toward the target
	var moved: bool = move_toward_target(unit, nearest.grid_position)
	if moved:
		await unit.await_movement_completion()
		if delay_after_movement > 0 and unit.get_tree():
			await unit.get_tree().create_timer(delay_after_movement).timeout

	# Recalculate distance after movement to decide whether to attack
	# - Only attack if enemy is now within engagement_range (committed engagement)
	# - If still outside engagement_range, we were just approaching cautiously
	var new_distance: int = GridManager.grid.get_manhattan_distance(unit.grid_position, nearest.grid_position)
	var should_attack: bool = new_distance <= engagement_range

	# Attack if we're in engagement range and now in attack range (verify target still alive)
	if should_attack and nearest.is_alive() and is_in_attack_range(unit, nearest):
		if delay_before_attack > 0 and unit.get_tree():
			await unit.get_tree().create_timer(delay_before_attack).timeout
		await attack_target(unit, nearest)


## Opportunistic behavior: prioritize wounded, retreat if low HP
## Integrates item usage and outnumbered detection
func _execute_opportunistic(unit: Node2D, context: Dictionary, behavior: AIBehaviorData) -> void:
	var player_units: Array[Node2D] = get_player_units(context)
	if player_units.is_empty():
		return

	# Check retreat conditions
	if behavior and behavior.retreat_enabled:
		var hp_percent: float = context.get("unit_hp_percent", 100.0)
		var should_retreat: bool = hp_percent < behavior.retreat_hp_threshold

		# Also retreat if outnumbered
		if not should_retreat and behavior.retreat_when_outnumbered:
			should_retreat = _is_outnumbered(unit, context)

		if should_retreat:
			# Try healing item first before retreating
			var healed: bool = await _try_use_healing_item(unit, context, behavior)
			if healed:
				return  # Turn consumed by item use

			await _execute_retreat(unit, player_units, context)
			return

	# Find best target (wounded priority)
	var target: Node2D = _find_best_target(unit, player_units, behavior)
	if not target:
		return

	# Consider attack items for ranged damage
	if behavior and behavior.use_attack_items:
		var used_item: bool = await _try_use_attack_item(unit, target, context, behavior)
		if used_item:
			return

	# Standard attack pattern
	await _execute_aggressive(unit, context, behavior)


## Retreat behavior: move away from enemies, optionally toward healers
func _execute_retreat(unit: Node2D, enemies: Array[Node2D], context: Dictionary) -> void:
	var unit_class: ClassData = unit.get_current_class()
	if not unit_class:
		return

	var behavior: AIBehaviorData = unit.ai_behavior if "ai_behavior" in unit else null
	var movement_range: int = unit_class.movement_range
	var reachable: Array[Vector2i] = GridManager.get_walkable_cells(unit.grid_position, movement_range, unit_class.movement_type, unit.faction)

	if reachable.is_empty():
		return

	# Check if we should seek a healer
	var healer_target: Node2D = null
	if behavior and behavior.seek_healer_when_wounded:
		healer_target = _find_nearest_allied_healer(unit, context)

	# Find best retreat cell
	var best_cell: Vector2i = unit.grid_position
	var best_score: float = -999.0

	for cell: Vector2i in reachable:
		if cell != unit.grid_position and GridManager.is_cell_occupied(cell):
			continue

		var score: float = 0.0

		# Distance from enemies (want to maximize)
		var min_enemy_dist: int = 999
		for enemy: Node2D in enemies:
			if enemy.is_alive():
				var dist: int = GridManager.grid.get_manhattan_distance(cell, enemy.grid_position)
				min_enemy_dist = mini(min_enemy_dist, dist)
		score += min_enemy_dist * 10.0

		# Distance to healer (want to minimize)
		if healer_target:
			var healer_dist: int = GridManager.grid.get_manhattan_distance(cell, healer_target.grid_position)
			score -= healer_dist * 5.0  # Less weight than enemy avoidance

		if score > best_score:
			best_score = score
			best_cell = cell

	if best_cell != unit.grid_position:
		unit.move_along_path([unit.grid_position, best_cell])
		await unit.await_movement_completion()


## Find best target based on threat weights and calculated unit threat
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

		# Calculate unit threat (ability-based targeting)
		if behavior:
			score += _calculate_unit_threat(target, behavior)

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


## Calculate unit's threat score based on their abilities and character data
## Uses AbilityType enum for categorization (NO custom taxonomies)
## @param unit: Target unit to evaluate
## @param behavior: AI behavior providing threat weights
## @return: Calculated threat score (higher = more threatening)
func _calculate_unit_threat(unit: Node2D, behavior: AIBehaviorData) -> float:
	var threat: float = 0.0

	if not unit or not unit.stats:
		return threat

	# Check for character_data - may not exist on all units
	if not "character_data" in unit or unit.character_data == null:
		return threat

	# Get unit's class for ability lookup
	var unit_class: ClassData = unit.get_current_class()
	if not unit_class:
		return threat

	# Get unlocked abilities at current level
	var abilities: Array[AbilityData] = unit_class.get_unlocked_class_abilities(unit.stats.level)

	# Also include character's unique abilities
	if unit.character_data.unique_abilities:
		abilities.append_array(unit.character_data.unique_abilities)

	# Scan abilities and accumulate threat by AbilityType
	for ability: AbilityData in abilities:
		if ability == null:
			continue

		var contribution: float = ability.ai_threat_contribution
		if contribution <= 0.0:
			continue

		match ability.ability_type:
			AbilityData.AbilityType.HEAL:
				# Healers are high-value targets
				var base_threat: float = 30.0 + ability.power * 0.5
				var weight: float = behavior.get_effective_threat_weight("healer", 1.0)
				threat += base_threat * contribution * weight

			AbilityData.AbilityType.ATTACK:
				# Damage dealers based on spell power
				var base_threat: float = ability.power * 0.5
				var weight: float = behavior.get_effective_threat_weight("damage_dealer", 1.0)
				threat += base_threat * contribution * weight

			AbilityData.AbilityType.DEBUFF, AbilityData.AbilityType.STATUS:
				# Debuffers can swing battles
				var base_threat: float = 20.0
				var weight: float = behavior.get_effective_threat_weight("debuffer", 1.0)
				threat += base_threat * contribution * weight

			AbilityData.AbilityType.SUPPORT:
				# Buffers help their team
				var base_threat: float = 15.0
				var weight: float = behavior.get_effective_threat_weight("support", 1.0)
				threat += base_threat * contribution * weight

			_:
				# Other types: small contribution
				threat += 5.0 * contribution

	# Add stat-based threat (high attack = dangerous)
	var attack_stat: int = unit.stats.strength if unit.stats else 0
	var attack_weight: float = behavior.get_effective_threat_weight("high_attack", 1.0)
	threat += attack_stat * 0.3 * attack_weight

	# Low defense = vulnerable = good target
	var defense_stat: int = unit.stats.defense if unit.stats else 0
	var defense_weight: float = behavior.get_effective_threat_weight("low_defense", 1.0)
	if defense_stat < 10:
		threat += (10 - defense_stat) * 2.0 * defense_weight

	# Apply character's threat modifier (bosses = 2.0, fodder = 0.5)
	var char_modifier: float = unit.character_data.ai_threat_modifier
	threat *= char_modifier

	# Handle threat tags
	var tags: Array[String] = unit.character_data.ai_threat_tags
	if "priority_target" in tags:
		threat *= 2.0
	if "avoid" in tags:
		threat *= 0.1

	return threat


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
			if delay_after_movement > 0 and unit.get_tree():
				await unit.get_tree().create_timer(delay_after_movement).timeout

		# Recalculate distance after moving
		distance = GridManager.grid.get_manhattan_distance(unit.grid_position, heal_target.grid_position)
		if distance > ability_range:
			return false  # Still out of range

	# Cast the healing spell
	var delays: Dictionary = context.get("ai_delays", {})
	var delay_before_spell: float = delays.get("before_attack", 0.3)
	if delay_before_spell > 0 and unit.get_tree():
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
		if prioritize_boss and "character_data" in ally and ally.character_data:
			if ally.character_data.is_boss:
				score += 50.0  # Strong preference for bosses

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
## Integrates AoE optimization to skip AoE heals when not enough targets
func _select_best_healing_ability(unit: Node2D, target: Node2D, abilities: Array[Dictionary], behavior: AIBehaviorData) -> Dictionary:
	if abilities.is_empty():
		return {}

	var best_ability: Dictionary = {}
	var best_score: float = -999.0
	var conserve_mp: bool = behavior.conserve_mp_on_heals if behavior else false
	var min_aoe_targets: int = behavior.aoe_minimum_targets if behavior else 2

	var missing_hp: int = target.stats.max_hp - target.stats.current_hp

	for ability_info: Dictionary in abilities:
		var mp_cost: int = ability_info.get("mp_cost", 0)
		var power: int = ability_info.get("power", 0)
		var aoe_radius: int = ability_info.get("aoe", 0)

		# Can't afford this spell
		if mp_cost > unit.stats.current_mp:
			continue

		# AoE check: skip if not enough targets
		if aoe_radius > 0:
			var ability: AbilityData = ability_info.get("ability") as AbilityData
			if ability:
				var target_count: int = _count_aoe_targets(target.grid_position, aoe_radius, unit, ability)
				if target_count < min_aoe_targets:
					continue  # Skip this AoE spell - not enough targets

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

		# Bonus for AoE that meets threshold
		if aoe_radius > 0:
			score += 20.0  # AoE heals are efficient

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


# =============================================================================
# AOE OPTIMIZATION (Phase 6)
# =============================================================================

## Count targets that would be hit by AoE at a given position
## @param center: Center cell of the AoE
## @param radius: AoE radius
## @param caster: The casting unit (to determine valid targets)
## @param ability: The ability being cast
## @return: Number of valid targets in AoE
func _count_aoe_targets(center: Vector2i, radius: int, caster: Node2D, ability: AbilityData) -> int:
	var count: int = 0

	for dx: int in range(-radius, radius + 1):
		for dy: int in range(-radius, radius + 1):
			var manhattan_dist: int = absi(dx) + absi(dy)
			if manhattan_dist > radius:
				continue

			var cell: Vector2i = center + Vector2i(dx, dy)
			if not GridManager.is_within_bounds(cell):
				continue

			var unit: Node2D = GridManager.get_unit_at_cell(cell)
			if unit and unit.is_alive() and _is_valid_aoe_target(caster, unit, ability):
				count += 1

	return count


## Check if unit is a valid target for this AoE ability
func _is_valid_aoe_target(caster: Node2D, target: Node2D, ability: AbilityData) -> bool:
	match ability.ability_type:
		AbilityData.AbilityType.HEAL, AbilityData.AbilityType.SUPPORT:
			return target.faction == caster.faction
		AbilityData.AbilityType.ATTACK, AbilityData.AbilityType.DEBUFF, AbilityData.AbilityType.STATUS:
			return target.faction != caster.faction
		_:
			return true


## Find best position to cast AoE for maximum targets
## @param caster: The casting unit
## @param ability: The AoE ability
## @param behavior: AI behavior settings
## @return: Dictionary with "target_cell" and "hit_count", or empty if not enough targets
func _find_best_aoe_target(caster: Node2D, ability: AbilityData, behavior: AIBehaviorData) -> Dictionary:
	var min_targets: int = behavior.aoe_minimum_targets if behavior else 2
	var aoe_radius: int = ability.area_of_effect
	var spell_range: int = ability.max_range

	var opponents: Array[Node2D]
	if caster.faction == "enemy":
		opponents = BattleManager.player_units
	else:
		opponents = BattleManager.enemy_units

	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_count: int = 0

	# Check each potential target position
	for opponent: Node2D in opponents:
		if not opponent.is_alive():
			continue

		var target_cell: Vector2i = opponent.grid_position

		# Check if in range
		var dist: int = GridManager.grid.get_manhattan_distance(caster.grid_position, target_cell)
		if dist > spell_range:
			continue

		var count: int = _count_aoe_targets(target_cell, aoe_radius, caster, ability)
		if count > best_count:
			best_count = count
			best_cell = target_cell

	if best_count >= min_targets:
		return {"target_cell": best_cell, "hit_count": best_count}

	return {}


# =============================================================================
# ITEM USAGE (Phase 2)
# =============================================================================

## Attempt to use a healing item from inventory
## @param unit: The AI unit
## @param context: Battle context
## @param behavior: AI behavior settings
## @return: true if item was used, false otherwise
func _try_use_healing_item(unit: Node2D, context: Dictionary, behavior: AIBehaviorData) -> bool:
	if not behavior or not behavior.use_healing_items:
		return false

	if not "character_data" in unit or unit.character_data == null:
		return false

	# Get unit's inventory from save data
	var char_uid: String = unit.character_data.character_uid
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(char_uid)
	if not save_data:
		return false

	# Find a healing consumable
	for item_id: String in save_data.inventory:
		var item: ItemData = ModLoader.registry.get_resource("item", item_id) as ItemData
		if not item:
			continue

		# Check if it's a usable healing item
		if item.item_type != ItemData.ItemType.CONSUMABLE:
			continue
		if not item.usable_in_battle:
			continue
		if not item.effect or not item.effect is AbilityData:
			continue

		var ability: AbilityData = item.effect as AbilityData
		if ability.ability_type != AbilityData.AbilityType.HEAL:
			continue

		# Found a healing item - use it on self
		var delays: Dictionary = context.get("ai_delays", {})
		var delay_before: float = delays.get("before_attack", 0.3)
		if delay_before > 0 and unit.get_tree():
			await unit.get_tree().create_timer(delay_before).timeout

		# Use BattleManager's item use system
		await BattleManager._on_item_use_requested(unit, item_id, unit)
		return true

	return false


## Attempt to use an attack item on a target
## @param unit: The AI unit
## @param target: The target unit
## @param context: Battle context
## @param behavior: AI behavior settings
## @return: true if item was used, false otherwise
func _try_use_attack_item(unit: Node2D, target: Node2D, context: Dictionary, behavior: AIBehaviorData) -> bool:
	if not behavior or not behavior.use_attack_items:
		return false

	if not "character_data" in unit or unit.character_data == null or not target:
		return false

	# Get unit's inventory from save data
	var char_uid: String = unit.character_data.character_uid
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(char_uid)
	if not save_data:
		return false

	# Find an attack consumable
	for item_id: String in save_data.inventory:
		var item: ItemData = ModLoader.registry.get_resource("item", item_id) as ItemData
		if not item:
			continue

		# Check if it's a usable attack item
		if item.item_type != ItemData.ItemType.CONSUMABLE:
			continue
		if not item.usable_in_battle:
			continue
		if not item.effect or not item.effect is AbilityData:
			continue

		var ability: AbilityData = item.effect as AbilityData
		if ability.ability_type != AbilityData.AbilityType.ATTACK:
			continue

		# Found an attack item - use it
		var delays: Dictionary = context.get("ai_delays", {})
		var delay_before: float = delays.get("before_attack", 0.3)
		if delay_before > 0 and unit.get_tree():
			await unit.get_tree().create_timer(delay_before).timeout

		await BattleManager._on_item_use_requested(unit, item_id, target)
		return true

	return false


# =============================================================================
# RETREAT ENHANCEMENTS (Phase 5)
# =============================================================================

## Find nearest ally with healing abilities
func _find_nearest_allied_healer(unit: Node2D, context: Dictionary) -> Node2D:
	var allies: Array[Node2D] = _get_allied_units(unit, context)

	var nearest_healer: Node2D = null
	var nearest_dist: int = 999

	for ally: Node2D in allies:
		if ally == unit or not ally.is_alive():
			continue

		# Check if ally has healing abilities
		var ally_class: ClassData = ally.get_current_class()
		if not ally_class:
			continue

		var has_heal: bool = false
		var level: int = ally.stats.level if ally.stats else 1
		var abilities: Array[AbilityData] = ally_class.get_unlocked_class_abilities(level)
		for ability: AbilityData in abilities:
			if ability and ability.ability_type == AbilityData.AbilityType.HEAL:
				has_heal = true
				break

		if not has_heal:
			continue

		var dist: int = GridManager.grid.get_manhattan_distance(unit.grid_position, ally.grid_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_healer = ally

	return nearest_healer


## Check if unit is outnumbered in local area
## @param unit: The unit to check
## @param context: Battle context
## @param radius: Tile radius to check (default 3)
## @return: true if enemies outnumber allies 2:1 or more
func _is_outnumbered(unit: Node2D, context: Dictionary, radius: int = 3) -> bool:
	var allies: Array[Node2D] = _get_allied_units(unit, context)
	var opponents: Array[Node2D]
	if unit.faction == "enemy":
		opponents = get_player_units(context)
	else:
		opponents = get_enemy_units(context)

	var nearby_allies: int = 1  # Count self
	var nearby_enemies: int = 0

	for ally: Node2D in allies:
		if ally == unit or not ally.is_alive():
			continue
		var dist: int = GridManager.grid.get_manhattan_distance(unit.grid_position, ally.grid_position)
		if dist <= radius:
			nearby_allies += 1

	for enemy: Node2D in opponents:
		if not enemy.is_alive():
			continue
		var dist: int = GridManager.grid.get_manhattan_distance(unit.grid_position, enemy.grid_position)
		if dist <= radius:
			nearby_enemies += 1

	# Outnumbered if enemies are 2x or more allies
	return nearby_enemies >= nearby_allies * 2


# =============================================================================
# TACTICAL ROLE IMPLEMENTATION (Phase 3)
# =============================================================================

## Execute tactical role: apply debuffs/status effects to high-threat targets
## @return: true if a debuff was applied, false otherwise
func _execute_tactical_role(unit: Node2D, context: Dictionary, behavior: AIBehaviorData) -> bool:
	if not behavior.use_status_effects:
		return false

	# Get opponent units
	var opponents: Array[Node2D]
	if unit.faction == "enemy":
		opponents = get_player_units(context)
	else:
		opponents = get_enemy_units(context)

	if opponents.is_empty():
		return false

	# Get unit's debuff abilities
	var debuff_abilities: Array[Dictionary] = _get_unit_debuff_abilities(unit, behavior)
	if debuff_abilities.is_empty():
		return false

	# Find best target (highest threat that doesn't already have debuffs)
	var best_target: Node2D = null
	var best_threat: float = -999.0

	for target: Node2D in opponents:
		if not target.is_alive():
			continue

		# Skip targets that already have status effects (to spread debuffs)
		if target.stats and not target.stats.status_effects.is_empty():
			continue

		var threat: float = _calculate_unit_threat(target, behavior)
		if threat > best_threat:
			best_threat = threat
			best_target = target

	if not best_target:
		# All targets have debuffs, fall back to highest threat regardless
		best_target = _find_best_target(unit, opponents, behavior)

	if not best_target:
		return false

	# Find best debuff ability for this target
	var best_ability: Dictionary = _select_best_debuff_ability(unit, best_target, debuff_abilities, behavior)
	if best_ability.is_empty():
		return false

	var ability_id: String = best_ability.get("id", "")
	var ability_range: int = best_ability.get("range", 1)

	# Check if target is in range
	var distance: int = GridManager.grid.get_manhattan_distance(unit.grid_position, best_target.grid_position)

	if distance > ability_range:
		# Move toward target
		var moved: bool = _move_into_spell_range(unit, best_target.grid_position, ability_range)
		if moved:
			await unit.await_movement_completion()
			var delays: Dictionary = context.get("ai_delays", {})
			var delay_after: float = delays.get("after_movement", 0.5)
			if delay_after > 0 and unit.get_tree():
				await unit.get_tree().create_timer(delay_after).timeout

		distance = GridManager.grid.get_manhattan_distance(unit.grid_position, best_target.grid_position)
		if distance > ability_range:
			return false  # Still out of range

	# Cast the debuff
	var delays: Dictionary = context.get("ai_delays", {})
	var delay_before: float = delays.get("before_attack", 0.3)
	if delay_before > 0 and unit.get_tree():
		await unit.get_tree().create_timer(delay_before).timeout

	var success: bool = await BattleManager.execute_ai_spell(unit, ability_id, best_target)
	return success


## Get list of debuff abilities the unit can use
func _get_unit_debuff_abilities(unit: Node2D, behavior: AIBehaviorData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if not unit.stats:
		return result

	var unit_class: ClassData = unit.get_current_class()
	if not unit_class:
		return result

	var unlocked_abilities: Array[AbilityData] = unit_class.get_unlocked_class_abilities(unit.stats.level)

	for ability: AbilityData in unlocked_abilities:
		if not ability:
			continue

		# Check if it's a debuff/status ability
		if ability.ability_type != AbilityData.AbilityType.DEBUFF and ability.ability_type != AbilityData.AbilityType.STATUS:
			continue

		# Check if it matches preferred status effects (if any specified)
		if not behavior.preferred_status_effects.is_empty():
			var matches_preferred: bool = false
			for effect: String in ability.status_effects:
				if effect in behavior.preferred_status_effects:
					matches_preferred = true
					break
			if not matches_preferred:
				continue

		# Check if unit can afford it
		if ability.mp_cost > unit.stats.current_mp:
			continue

		result.append({
			"id": ability.ability_id,
			"ability": ability,
			"range": ability.max_range,
			"mp_cost": ability.mp_cost,
			"effects": ability.status_effects
		})

	return result


## Select the best debuff ability for the situation
func _select_best_debuff_ability(unit: Node2D, target: Node2D, abilities: Array[Dictionary], behavior: AIBehaviorData) -> Dictionary:
	if abilities.is_empty():
		return {}

	var best_ability: Dictionary = {}
	var best_score: float = -999.0

	for ability_info: Dictionary in abilities:
		var score: float = 0.0

		# Prefer abilities that match preferred_status_effects (if specified)
		var effects: Array = ability_info.get("effects", [])
		for effect: Variant in effects:
			if effect in behavior.preferred_status_effects:
				score += 50.0

		# Prefer lower MP cost (conserve resources)
		var mp_cost: int = ability_info.get("mp_cost", 0)
		score -= mp_cost * 2.0

		# Prefer higher effect chance (from ability data)
		var ability: AbilityData = ability_info.get("ability") as AbilityData
		if ability:
			score += ability.effect_chance * 0.5

		if score > best_score:
			best_score = score
			best_ability = ability_info

	return best_ability


# =============================================================================
# DEFENSIVE ROLE IMPLEMENTATION (Phase 4)
# =============================================================================

## Execute defensive role: position between VIP and threats
func _execute_defensive_role(unit: Node2D, context: Dictionary, behavior: AIBehaviorData) -> void:
	# Get allies and opponents
	var allies: Array[Node2D] = _get_allied_units(unit, context)
	var opponents: Array[Node2D]
	if unit.faction == "enemy":
		opponents = get_player_units(context)
	else:
		opponents = get_enemy_units(context)

	# Find VIP to protect (highest ai_threat_modifier or boss tag)
	var vip: Node2D = _find_vip_to_protect(unit, allies)

	if not vip or opponents.is_empty():
		# No VIP or no threats - fall back to cautious behavior
		await _execute_cautious(unit, context, behavior)
		return

	# Find nearest threat to VIP
	var nearest_threat: Node2D = find_nearest_target(vip, opponents)
	if not nearest_threat:
		await _execute_cautious(unit, context, behavior)
		return

	var delays: Dictionary = context.get("ai_delays", {})

	# Check if we should attack first (enemy adjacent to us)
	for opponent: Node2D in opponents:
		if not opponent.is_alive():
			continue
		if is_in_attack_range(unit, opponent):
			var delay_before: float = delays.get("before_attack", 0.3)
			if delay_before > 0 and unit.get_tree():
				await unit.get_tree().create_timer(delay_before).timeout
			await attack_target(unit, opponent)
			return

	# Calculate ideal interception position (between VIP and threat)
	var intercept_pos: Vector2i = _calculate_intercept_position(unit, vip, nearest_threat)

	# Find the best move target that balances protection and attack opportunity
	var best_target: Vector2i = _find_best_defensive_position(unit, intercept_pos, opponents)

	if best_target == unit.grid_position:
		# Already in best position - check for attack opportunity
		for opponent: Node2D in opponents:
			if not opponent.is_alive():
				continue
			if is_in_attack_range(unit, opponent):
				var delay_before: float = delays.get("before_attack", 0.3)
				if delay_before > 0 and unit.get_tree():
					await unit.get_tree().create_timer(delay_before).timeout
				await attack_target(unit, opponent)
				return
		return  # No attack possible, stay in position

	# Move toward the best defensive position
	var moved: bool = move_toward_target(unit, best_target)
	if moved:
		await unit.await_movement_completion()
		var delay_after: float = delays.get("after_movement", 0.5)
		if delay_after > 0 and unit.get_tree():
			await unit.get_tree().create_timer(delay_after).timeout

	# Attack if now in range of any opponent
	for opponent: Node2D in opponents:
		if not opponent.is_alive():
			continue
		if is_in_attack_range(unit, opponent):
			var delay_before: float = delays.get("before_attack", 0.3)
			if delay_before > 0 and unit.get_tree():
				await unit.get_tree().create_timer(delay_before).timeout
			await attack_target(unit, opponent)
			return


## Find the VIP (most valuable ally to protect)
func _find_vip_to_protect(protector: Node2D, allies: Array[Node2D]) -> Node2D:
	var best_vip: Node2D = null
	var best_priority: float = -999.0

	for ally: Node2D in allies:
		if ally == protector or not ally.is_alive():
			continue

		if not "character_data" in ally or ally.character_data == null:
			continue

		var priority: float = 0.0

		# Check is_boss flag (primary boss indicator)
		if ally.character_data.is_boss:
			priority += 200.0

		# Check ai_threat_modifier (fine-tuning)
		priority += ally.character_data.ai_threat_modifier * 100.0

		# Check for vip tag (secondary protection target)
		var tags: Array[String] = ally.character_data.ai_threat_tags
		if "vip" in tags:
			priority += 150.0

		# Healers are valuable
		var ally_class: ClassData = ally.get_current_class()
		if ally_class:
			var level: int = ally.stats.level if ally.stats else 1
			var abilities: Array[AbilityData] = ally_class.get_unlocked_class_abilities(level)
			for ability: AbilityData in abilities:
				if ability and ability.ability_type == AbilityData.AbilityType.HEAL:
					priority += 50.0
					break

		if priority > best_priority:
			best_priority = priority
			best_vip = ally

	return best_vip


## Calculate position to intercept threats to VIP
func _calculate_intercept_position(protector: Node2D, vip: Node2D, threat: Node2D) -> Vector2i:
	# Calculate midpoint between VIP and threat
	var vip_pos: Vector2i = vip.grid_position
	var threat_pos: Vector2i = threat.grid_position

	# Target position is one step from VIP toward threat
	var direction: Vector2i = Vector2i(
		signi(threat_pos.x - vip_pos.x),
		signi(threat_pos.y - vip_pos.y)
	)

	var intercept: Vector2i = vip_pos + direction

	# If intercept is occupied or invalid, try adjacent cells
	if not GridManager.is_within_bounds(intercept) or GridManager.is_cell_occupied(intercept):
		# Try orthogonal directions
		var alternatives: Array[Vector2i] = [
			vip_pos + Vector2i(direction.x, 0),
			vip_pos + Vector2i(0, direction.y),
			vip_pos + Vector2i(-direction.y, direction.x),  # Perpendicular
			vip_pos + Vector2i(direction.y, -direction.x)   # Other perpendicular
		]

		for alt: Vector2i in alternatives:
			if GridManager.is_within_bounds(alt) and not GridManager.is_cell_occupied(alt):
				return alt

		# No good position - stay put
		return protector.grid_position

	return intercept


## Find best defensive position balancing protection and attack opportunity
func _find_best_defensive_position(unit: Node2D, intercept_pos: Vector2i, opponents: Array[Node2D]) -> Vector2i:
	var unit_class: ClassData = unit.get_current_class()
	if not unit_class:
		return intercept_pos

	var movement_range: int = unit_class.movement_range
	var reachable: Array[Vector2i] = GridManager.get_walkable_cells(
		unit.grid_position, movement_range, unit_class.movement_type, unit.faction
	)

	if reachable.is_empty():
		return unit.grid_position

	var best_cell: Vector2i = unit.grid_position
	var best_score: float = -999.0

	# Get weapon range for attack opportunity checks
	var min_attack_range: int = 1
	var max_attack_range: int = 1
	if unit.stats:
		min_attack_range = unit.stats.get_weapon_min_range()
		max_attack_range = unit.stats.get_weapon_max_range()

	for cell: Vector2i in reachable:
		var score: float = 0.0

		# Score: closer to intercept position is better (protection duty)
		var dist_to_intercept: int = GridManager.grid.get_manhattan_distance(cell, intercept_pos)
		score -= dist_to_intercept * 2.0  # Penalty for distance from intercept

		# Bonus: can attack an opponent from this cell
		for opponent: Node2D in opponents:
			if not opponent.is_alive():
				continue
			var dist_to_enemy: int = GridManager.grid.get_manhattan_distance(cell, opponent.grid_position)
			if dist_to_enemy >= min_attack_range and dist_to_enemy <= max_attack_range:
				score += 10.0  # Big bonus for attack opportunity
				break  # Only need one attackable target

		if score > best_score:
			best_score = score
			best_cell = cell

	return best_cell
