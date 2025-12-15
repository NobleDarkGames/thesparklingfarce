class_name AIRoleBehavior
extends RefCounted

## Base class for pluggable AI role behaviors.
##
## Each tactical role (support, aggressive, defensive, etc.) can have
## a custom behavior script that implements role-specific logic for:
## - Target evaluation and prioritization
## - Action selection (attack, heal, move, use item)
## - Movement decisions
##
## Mods register role behaviors via mod.json:
## {
##   "ai_roles": {
##     "hacking": {
##       "display_name": "Hacking",
##       "description": "Disables enemy systems",
##       "script_path": "ai_roles/hacking_role.gd"
##     }
##   }
## }
##
## The ConfigurableAIBrain loads the appropriate role behavior script
## based on the AIBehaviorData.role value.

# =============================================================================
# TYPES
# =============================================================================

## Action types that can be returned from select_action()
enum ActionType {
	NONE,       # Do nothing (end turn)
	ATTACK,     # Physical attack a target
	SPELL,      # Cast a spell/ability
	ITEM,       # Use an item
	MOVE,       # Move to a position
	WAIT        # Stay in place but remain active
}

# =============================================================================
# ABSTRACT METHODS - Override in subclasses
# =============================================================================

## Evaluate potential targets and return them with priority scores.
## Higher scores = more attractive targets.
##
## @param unit: The AI unit evaluating targets
## @param context: Battle context dictionary containing:
##   - player_units: Array[Node2D] of enemy units (from AI's perspective)
##   - enemy_units: Array[Node2D] of allied units (from AI's perspective)
##   - neutral_units: Array[Node2D]
##   - grid: Reference to GridManager
##   - turn_number: int
## @param behavior: AIBehaviorData configuration
##
## @return: Array of {target: Node2D, score: float, reason: String}
func evaluate_targets(unit: Node2D, context: Dictionary, behavior: Resource) -> Array[Dictionary]:
	push_error("AIRoleBehavior.evaluate_targets() must be overridden in subclass: %s" % get_class())
	return []


## Select the best action for the unit to take this turn.
##
## @param unit: The AI unit selecting an action
## @param context: Battle context dictionary
## @param behavior: AIBehaviorData configuration
## @param target_evaluations: Array from evaluate_targets()
##
## @return: Dictionary with:
##   - action: ActionType
##   - target: Node2D (for attack/spell) or null
##   - ability: AbilityData (for spell) or null
##   - item: ItemData (for item) or null
##   - position: Vector2i (for move) or null
##   - reason: String (for debugging)
func select_action(unit: Node2D, context: Dictionary, behavior: Resource, target_evaluations: Array[Dictionary]) -> Dictionary:
	push_error("AIRoleBehavior.select_action() must be overridden in subclass: %s" % get_class())
	return _create_action(ActionType.NONE, null, "No action (base class)")


## Optionally override to provide custom movement logic.
## Default implementation returns the best position toward highest-priority target.
##
## @param unit: The AI unit deciding where to move
## @param context: Battle context dictionary
## @param behavior: AIBehaviorData configuration
## @param selected_action: The action dictionary from select_action()
##
## @return: Vector2i of target cell, or Vector2i(-1, -1) if no movement needed
func select_move_position(unit: Node2D, context: Dictionary, behavior: Resource, selected_action: Dictionary) -> Vector2i:
	# Default: move toward the action's target if we have one
	var target: Node2D = selected_action.get("target")
	if target and target.is_alive():
		return _get_best_position_toward(unit, target.grid_position, context, behavior)
	return Vector2i(-1, -1)


# =============================================================================
# HELPER METHODS - Available to subclasses
# =============================================================================

## Create a standardized action dictionary
func _create_action(action_type: ActionType, target: Node2D, reason: String) -> Dictionary:
	return {
		"action": action_type,
		"target": target,
		"ability": null,
		"item": null,
		"position": null,
		"reason": reason
	}


## Create an attack action
func _create_attack_action(target: Node2D, reason: String = "Attack target") -> Dictionary:
	var action: Dictionary = _create_action(ActionType.ATTACK, target, reason)
	return action


## Create a spell action
func _create_spell_action(target: Node2D, ability: Resource, reason: String = "Cast spell") -> Dictionary:
	var action: Dictionary = _create_action(ActionType.SPELL, target, reason)
	action.ability = ability
	return action


## Create an item action
func _create_item_action(target: Node2D, item: Resource, reason: String = "Use item") -> Dictionary:
	var action: Dictionary = _create_action(ActionType.ITEM, target, reason)
	action.item = item
	return action


## Create a move action
func _create_move_action(position: Vector2i, reason: String = "Move to position") -> Dictionary:
	var action: Dictionary = _create_action(ActionType.MOVE, null, reason)
	action.position = position
	return action


## Create a wait/end turn action
func _create_wait_action(reason: String = "Waiting") -> Dictionary:
	return _create_action(ActionType.WAIT, null, reason)


## Calculate threat weight for a target using behavior configuration
func _calculate_threat_weight(target: Node2D, behavior: Resource, context: Dictionary) -> float:
	var weight: float = 1.0
	var behavior_data: AIBehaviorData = behavior as AIBehaviorData
	if not behavior_data:
		return weight

	# Wounded target priority
	if "stats" in target and target.stats:
		var hp_ratio: float = float(target.stats.current_hp) / float(target.stats.max_hp)
		if hp_ratio < 0.5:
			weight *= behavior_data.get_effective_threat_weight("wounded_target", 1.0)

	# Healer priority (if target has healing abilities)
	if _is_healer(target):
		weight *= behavior_data.get_effective_threat_weight("healer", 1.0)

	# Damage dealer priority (high attack power)
	if _is_damage_dealer(target):
		weight *= behavior_data.get_effective_threat_weight("damage_dealer", 1.0)

	# Proximity priority
	var unit: Node2D = context.get("current_unit")
	if unit and "grid_position" in unit and "grid_position" in target:
		var distance: int = _get_manhattan_distance(unit.grid_position, target.grid_position)
		var proximity_weight: float = behavior_data.get_effective_threat_weight("proximity", 1.0)
		# Closer targets get higher weight (inverse distance)
		weight *= proximity_weight / maxf(1.0, float(distance) * 0.5)

	return weight


## Check if a unit appears to be a healer
func _is_healer(unit: Node2D) -> bool:
	# Check if unit has healing abilities
	if "character_data" in unit:
		var char_data: Resource = unit.character_data
		if char_data and "unique_abilities" in char_data:
			for ability: Resource in char_data.unique_abilities:
				if ability and "ability_type" in ability:
					# AbilityType.HEAL = 1 (check AbilityData enum)
					if ability.ability_type == 1:
						return true
	return false


## Check if a unit appears to be a damage dealer
func _is_damage_dealer(unit: Node2D) -> bool:
	# Check for high attack stat
	if "stats" in unit:
		var stats: Resource = unit.stats
		if stats and "attack" in stats:
			return stats.attack > 15  # Threshold for "high" damage
	return false


## Get Manhattan distance between two grid positions
func _get_manhattan_distance(from: Vector2i, to: Vector2i) -> int:
	return abs(to.x - from.x) + abs(to.y - from.y)


## Find the best position to move toward a target
func _get_best_position_toward(unit: Node2D, target_pos: Vector2i, context: Dictionary, behavior: Resource) -> Vector2i:
	# This would use GridManager for pathfinding
	# For now, return the target position and let the caller handle pathfinding
	return target_pos


## Check if unit is in attack range of target
## Uses unit's equipped weapon range (min/max) to support ranged weapons and dead zones
func _is_in_attack_range(unit: Node2D, target: Node2D) -> bool:
	if not unit or not target:
		return false

	if "grid_position" not in unit or "grid_position" not in target:
		return false

	var distance: int = _get_manhattan_distance(unit.grid_position, target.grid_position)

	# Use unit's weapon range from stats (handles min/max range bands)
	if "stats" in unit and unit.stats:
		return unit.stats.can_attack_at_distance(distance)

	# Fallback: unarmed melee (range 1 only)
	return distance == 1


## Get unit's maximum attack range
func _get_attack_range(unit: Node2D) -> int:
	if "stats" in unit and unit.stats:
		return unit.stats.get_weapon_max_range()
	return 1  # Fallback melee


## Check if unit should retreat based on behavior configuration
func _should_retreat(unit: Node2D, behavior: Resource, context: Dictionary) -> bool:
	var behavior_data: AIBehaviorData = behavior as AIBehaviorData
	if not behavior_data or not behavior_data.is_retreat_enabled():
		return false

	# Check HP threshold
	if "stats" in unit and unit.stats:
		var hp_percent: float = 100.0 * float(unit.stats.current_hp) / float(unit.stats.max_hp)
		if hp_percent < behavior_data.get_effective_retreat_threshold():
			return true

	# Check outnumbered
	if behavior_data.retreat_when_outnumbered:
		var nearby_enemies: int = _count_nearby_enemies(unit, context, 3)
		var nearby_allies: int = _count_nearby_allies(unit, context, 3)
		if nearby_enemies > nearby_allies * 2:
			return true

	return false


## Count enemies within range of unit
func _count_nearby_enemies(unit: Node2D, context: Dictionary, range_tiles: int) -> int:
	var count: int = 0
	var enemies: Array = context.get("player_units", [])

	if "grid_position" not in unit:
		return count

	for enemy: Node2D in enemies:
		if enemy and enemy.is_alive() and "grid_position" in enemy:
			var distance: int = _get_manhattan_distance(unit.grid_position, enemy.grid_position)
			if distance <= range_tiles:
				count += 1

	return count


## Count allies within range of unit
func _count_nearby_allies(unit: Node2D, context: Dictionary, range_tiles: int) -> int:
	var count: int = 0
	var allies: Array = context.get("enemy_units", [])

	if "grid_position" not in unit:
		return count

	for ally: Node2D in allies:
		if ally and ally != unit and ally.is_alive() and "grid_position" in ally:
			var distance: int = _get_manhattan_distance(unit.grid_position, ally.grid_position)
			if distance <= range_tiles:
				count += 1

	return count


## Get the highest priority target from evaluations
func _get_best_target(target_evaluations: Array[Dictionary]) -> Node2D:
	if target_evaluations.is_empty():
		return null

	var best: Dictionary = target_evaluations[0]
	for eval: Dictionary in target_evaluations:
		if eval.get("score", 0.0) > best.get("score", 0.0):
			best = eval

	return best.get("target")
