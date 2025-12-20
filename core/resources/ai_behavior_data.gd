class_name AIBehaviorData
extends Resource

## Data-driven AI behavior configuration for configurable enemy AI.
##
## This resource defines HOW a unit behaves in combat without requiring
## custom GDScript. Modders can create diverse behaviors purely through
## the editor by adjusting these parameters.
##
## Key Design Decisions (per Modro's review):
## - Roles and modes are STRINGS validated against registries, NOT enums
## - Threat weights use extensible Dictionary, NOT fixed properties
## - Base behavior inheritance reduces duplication
## - Behavior phases enable boss phase changes without custom scripts
##
## See also: AIModeRegistry, ConfigurableAIBrain

# =============================================================================
# IDENTITY
# =============================================================================

## Unique identifier for this behavior (used in BattleData references)
@export var behavior_id: String = ""

## Human-readable name shown in editor
@export var display_name: String = ""

## Description of what this behavior does
@export_multiline var description: String = ""

# =============================================================================
# INHERITANCE
# =============================================================================

## Base behavior to inherit from. Properties with empty/default values
## will fall through to the base behavior's values. This reduces duplication
## when creating behavior variants (e.g., "aggressive_melee_cautious" inherits
## from "aggressive_melee" but overrides behavior_mode).
@export var base_behavior: AIBehaviorData = null

# =============================================================================
# ROLE & MODE (Registry-Based, NOT Hardcoded Enums)
# =============================================================================

## The unit's tactical role - determines primary combat behavior
## Built-in roles: "support", "aggressive", "defensive", "tactical"
## Empty string = inherit from base_behavior or use default "aggressive"
@export var role: String = ""

## Behavior mode - validated against AIModeRegistry
## Default modes: "aggressive", "cautious", "opportunistic"
## Mods can add: "berserk", "protective", "evasive", etc.
## Empty string = inherit from base_behavior or use default "aggressive"
@export var behavior_mode: String = ""

# =============================================================================
# THREAT ASSESSMENT WEIGHTS (Extensible Dictionary)
# =============================================================================

## Weights for target selection. Higher weights = higher priority.
## Default keys: "wounded_target", "damage_dealer", "healer", "proximity"
## Mods can add custom keys like "psionic_power", "hacking_vulnerability"
## Values typically range 0.0-2.0 where 1.0 is normal priority.
## Empty dictionary = inherit from base_behavior or use defaults.
@export var threat_weights: Dictionary = {}

## If true, avoids disproportionately targeting the hero/protagonist
## (Addresses the classic "AI obsessively attacks Max" problem)
@export var ignore_protagonist_priority: bool = true

# =============================================================================
# RETREAT & SELF-PRESERVATION
# =============================================================================

## HP percentage below which the unit will try to retreat/seek healing
@export_range(0, 100) var retreat_hp_threshold: int = 30

## If true, retreat when significantly outnumbered in local area
@export var retreat_when_outnumbered: bool = true

## If true, move toward allied healers when wounded
@export var seek_healer_when_wounded: bool = true

## Master switch to enable/disable retreat behavior entirely
@export var retreat_enabled: bool = true

# =============================================================================
# ABILITY USAGE RULES (Spells)
# =============================================================================

## Minimum number of targets required to use AoE abilities
@export_range(1, 5) var aoe_minimum_targets: int = 2

## If true, prefer lower-level heals when target isn't critically wounded
@export var conserve_mp_on_heals: bool = true

## If true, prioritize healing boss/leader units over regular allies
@export var prioritize_boss_heals: bool = true

## If true, use debuff/status effect abilities
@export var use_status_effects: bool = true

## Specific status effects this behavior prefers to use (empty = any)
@export var preferred_status_effects: Array[String] = []

# =============================================================================
# ITEM USAGE RULES
# =============================================================================

## If true, use healing items when wounded and no healer available
@export var use_healing_items: bool = true

## If true, use attack items (thrown weapons, bombs, etc.)
@export var use_attack_items: bool = true

## If true, use buff items on self or allies
@export var use_buff_items: bool = false

# =============================================================================
# ENGAGEMENT RULES
# =============================================================================

## Maximum distance at which unit becomes "alert" to enemies
## Alert units may move toward threats even before combat
@export_range(0, 20) var alert_range: int = 8

## Distance at which unit actively engages (moves to attack) enemies
@export_range(0, 20) var engagement_range: int = 5

## If true, prefer positions with terrain bonuses (defense, cover)
@export var seek_terrain_advantage: bool = true

## Maximum turns to wait without action before becoming aggressive
## 0 = always stay passive until triggered
@export_range(0, 99) var max_idle_turns: int = 0

# =============================================================================
# BEHAVIOR PHASES (Trigger-Based State Changes)
# =============================================================================

## Phase triggers that modify behavior during battle.
## Each phase is a Dictionary with:
##   "trigger": String - trigger type ("hp_below", "hp_above", "ally_died", "turn_count", etc.)
##   "value": Variant - trigger threshold (e.g., 50 for hp_below 50%)
##   "changes": Dictionary - properties to override when triggered
##
## Example phases:
## [
##   {"trigger": "hp_below", "value": 75, "changes": {"behavior_mode": "cautious"}},
##   {"trigger": "hp_below", "value": 25, "changes": {"role": "berserker", "retreat_enabled": false}},
##   {"trigger": "ally_died", "value": "boss_healer", "changes": {"prioritize_revenge": true}}
## ]
##
## Phases are evaluated in order; later phases override earlier ones.
@export var behavior_phases: Array[Dictionary] = []

# =============================================================================
# EFFECTIVE VALUE RESOLUTION (Inheritance Support)
# =============================================================================

## Get the effective role, resolving inheritance chain
func get_effective_role() -> String:
	if not role.is_empty():
		return role
	if base_behavior:
		return base_behavior.get_effective_role()
	return "aggressive"


## Get the effective mode, resolving inheritance chain
func get_effective_mode() -> String:
	if not behavior_mode.is_empty():
		return behavior_mode
	if base_behavior:
		return base_behavior.get_effective_mode()
	return "aggressive"


## Get a threat weight value, resolving inheritance chain
func get_effective_threat_weight(key: String, default: float = 1.0) -> float:
	if key in threat_weights:
		return threat_weights[key]
	if base_behavior:
		return base_behavior.get_effective_threat_weight(key, default)
	return default


## Get all threat weights merged with inheritance chain
func get_all_effective_threat_weights() -> Dictionary:
	var result: Dictionary = {}

	# Start with base behavior's weights (if any)
	if base_behavior:
		result = base_behavior.get_all_effective_threat_weights()

	# Override with our weights
	for key: String in threat_weights.keys():
		result[key] = threat_weights[key]

	return result


## Get the effective retreat threshold, resolving inheritance chain
func get_effective_retreat_threshold() -> int:
	# Note: Since we can't distinguish "not set" from "set to 0",
	# we only inherit if this behavior has base_behavior AND retreat_hp_threshold == 30 (default)
	# In practice, most inheritance will be explicit via base_behavior reference
	if retreat_hp_threshold != 30:
		return retreat_hp_threshold
	if base_behavior:
		return base_behavior.get_effective_retreat_threshold()
	return retreat_hp_threshold


## Check if retreat is enabled, resolving inheritance chain
func is_retreat_enabled() -> bool:
	if not retreat_enabled:
		return false
	if base_behavior:
		return base_behavior.is_retreat_enabled()
	return retreat_enabled


# =============================================================================
# PHASE SYSTEM
# =============================================================================

## Evaluate which phases are active given current battle state
## Returns merged changes dictionary from all active phases
## @param context: Dictionary with battle state (unit_hp_percent, turn_number, etc.)
func evaluate_phase_changes(context: Dictionary) -> Dictionary:
	var changes: Dictionary = {}

	for phase: Dictionary in behavior_phases:
		if _is_phase_active(phase, context):
			# Merge changes from this phase
			var phase_changes: Variant = phase.get("changes", {})
			if phase_changes is Dictionary:
				for key: String in phase_changes.keys():
					changes[key] = phase_changes[key]

	return changes


## Check if a single phase trigger is active
func _is_phase_active(phase: Dictionary, context: Dictionary) -> bool:
	var trigger: String = str(phase.get("trigger", ""))
	var value: Variant = phase.get("value")

	match trigger:
		"hp_below":
			var hp_percent: float = context.get("unit_hp_percent", 100.0)
			return hp_percent < float(value)

		"hp_above":
			var hp_percent: float = context.get("unit_hp_percent", 100.0)
			return hp_percent > float(value)

		"turn_count":
			var turn: int = context.get("turn_number", 0)
			return turn >= int(value)

		"ally_died":
			var dead_allies: Array = context.get("dead_ally_ids", [])
			return str(value) in dead_allies

		"ally_count_below":
			var ally_count: int = context.get("ally_count", 0)
			return ally_count < int(value)

		"enemy_count_below":
			var enemy_count: int = context.get("enemy_count", 0)
			return enemy_count < int(value)

		"flag_set":
			var flags: Dictionary = context.get("story_flags", {})
			return str(value) in flags

		_:
			# Unknown trigger - log warning and skip
			if not trigger.is_empty():
				push_warning("AIBehaviorData: Unknown phase trigger '%s'" % trigger)
			return false


# =============================================================================
# VALIDATION
# =============================================================================

## Validate the behavior data
## Returns Dictionary with {valid: bool, errors: Array[String]}
func validate() -> Dictionary:
	var errors: Array[String] = []

	# Check ID
	if behavior_id.strip_edges().is_empty():
		errors.append("Behavior ID cannot be empty")

	# Check for circular inheritance
	if _has_circular_inheritance():
		errors.append("Circular inheritance detected in base_behavior chain")

	# Validate role if set (can't validate against registry here without autoload access)
	# Runtime validation will catch invalid roles

	# Validate phase triggers
	for i: int in range(behavior_phases.size()):
		var phase: Dictionary = behavior_phases[i]
		if "trigger" not in phase:
			errors.append("Phase %d missing 'trigger' key" % i)
		if "changes" not in phase:
			errors.append("Phase %d missing 'changes' key" % i)

	return {
		"valid": errors.is_empty(),
		"errors": errors
	}


## Check for circular inheritance
func _has_circular_inheritance() -> bool:
	var visited: Array[AIBehaviorData] = []
	var current: AIBehaviorData = self

	while current != null:
		if current in visited:
			return true
		visited.append(current)
		current = current.base_behavior

	return false


# =============================================================================
# UTILITY
# =============================================================================

## Create a summary string for UI preview
func get_behavior_summary() -> String:
	var parts: Array[String] = []

	var eff_role: String = get_effective_role()
	var eff_mode: String = get_effective_mode()
	parts.append("%s (%s)" % [eff_role.capitalize(), eff_mode.capitalize()])

	if is_retreat_enabled():
		parts.append("Retreats at %d%% HP" % get_effective_retreat_threshold())
	else:
		parts.append("No retreat")

	if not behavior_phases.is_empty():
		parts.append("%d phase(s)" % behavior_phases.size())

	return ", ".join(parts)
