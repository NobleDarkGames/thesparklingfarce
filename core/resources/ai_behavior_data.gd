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
# ROLE & MODE
# =============================================================================

## The unit's tactical role - determines primary combat behavior
## Built-in roles: "support", "aggressive", "defensive", "tactical"
@export var role: String = "aggressive"

## Behavior mode - how the AI executes its role
## Built-in modes: "aggressive", "cautious", "opportunistic"
@export var behavior_mode: String = "aggressive"

# =============================================================================
# THREAT ASSESSMENT WEIGHTS (Extensible Dictionary)
# =============================================================================

## Weights for target selection. Higher weights = higher priority.
## Default keys: "wounded_target", "damage_dealer", "healer", "proximity"
## Mods can add custom keys like "psionic_power", "hacking_vulnerability"
## Values typically range 0.0-2.0 where 1.0 is normal priority.
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
# ACCESSORS
# =============================================================================

## Get a threat weight value with fallback to default
func get_threat_weight(key: String, default: float = 1.0) -> float:
	var value: Variant = threat_weights.get(key, default)
	if value is float:
		return value
	if value is int:
		return float(value)
	return default


## Get the effective role, defaulting to "aggressive" if empty
func get_effective_role() -> String:
	if role.strip_edges().is_empty():
		return "aggressive"
	return role


## Get the effective behavior mode, defaulting to "aggressive" if empty
func get_effective_mode() -> String:
	if behavior_mode.strip_edges().is_empty():
		return "aggressive"
	return behavior_mode


## Check if retreat behavior is enabled
func is_retreat_enabled() -> bool:
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
				var phase_changes_dict: Dictionary = phase_changes
				for key: String in phase_changes_dict.keys():
					changes[key] = phase_changes_dict[key]

	return changes


## Check if a single phase trigger is active
func _is_phase_active(phase: Dictionary, context: Dictionary) -> bool:
	var trigger: String = DictUtils.get_string(phase, "trigger", "")
	var value: Variant = phase.get("value")
	# Pre-convert value to numeric types for type safety
	var value_float: float = 0.0
	if value is float:
		value_float = value
	elif value is int:
		value_float = float(value)
	elif value != null:
		value_float = 0.0
	var value_int: int = int(value_float)
	var value_str: String = str(value) if value != null else ""

	match trigger:
		"hp_below":
			var hp_percent: float = DictUtils.get_float(context, "unit_hp_percent", 100.0)
			return hp_percent < value_float

		"hp_above":
			var hp_percent: float = DictUtils.get_float(context, "unit_hp_percent", 100.0)
			return hp_percent > value_float

		"turn_count":
			var turn: int = DictUtils.get_int(context, "turn_number", 0)
			return turn >= value_int

		"ally_died":
			var dead_allies: Array = DictUtils.get_array(context, "dead_ally_ids", [])
			return value_str in dead_allies

		"ally_count_below":
			var ally_count: int = DictUtils.get_int(context, "ally_count", 0)
			return ally_count < value_int

		"enemy_count_below":
			var enemy_count: int = DictUtils.get_int(context, "enemy_count", 0)
			return enemy_count < value_int

		"flag_set":
			var flags: Dictionary = DictUtils.get_dict(context, "story_flags", {})
			return value_str in flags

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


# =============================================================================
# UTILITY
# =============================================================================

## Create a summary string for UI preview
func get_behavior_summary() -> String:
	var parts: Array[String] = []

	parts.append("%s (%s)" % [role.capitalize(), behavior_mode.capitalize()])

	if retreat_enabled:
		parts.append("Retreats at %d%% HP" % retreat_hp_threshold)
	else:
		parts.append("No retreat")

	if not behavior_phases.is_empty():
		parts.append("%d phase(s)" % behavior_phases.size())

	return ", ".join(parts)
