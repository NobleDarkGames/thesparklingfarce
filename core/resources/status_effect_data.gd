@tool
class_name StatusEffectData
extends Resource

## Data-driven status effect definition
##
## Status effects are defined entirely by properties - no custom scripts.
## Modders create new effects by combining predefined behaviors:
## - Skip turn effects (sleep, stun, paralysis with recovery chance)
## - Damage/healing over time (poison, regen)
## - Stat modifiers (attack_up, defense_down)
## - Action modifiers (confusion, berserk)
## - Removal conditions (removed on damage for sleep)

## Unique identifier (lowercase, underscores: "poison", "sleep", "attack_up")
@export var effect_id: String = ""

## Display name for UI ("Poisoned", "Asleep")
@export var display_name: String = ""

## Description for help text
@export_multiline var description: String = ""

## Popup text shown when effect triggers (empty = use display_name)
@export var popup_text: String = ""

## Popup text color
@export var popup_color: Color = Color.WHITE


# =============================================================================
# TIMING
# =============================================================================

## How many turns this effect lasts (0 = until removed by other means)
@export_range(0, 99) var duration: int = 3

## When this effect's behavior triggers
enum TriggerTiming {
	TURN_START,   ## Process at start of unit's turn (poison damage, paralysis check)
	TURN_END,     ## Process at end of unit's turn
	ON_DAMAGE,    ## Process when unit takes damage
	ON_ACTION,    ## Process when unit tries to act (confusion target redirect)
	PASSIVE       ## Always active, no per-turn processing (stat modifiers)
}
@export var trigger_timing: TriggerTiming = TriggerTiming.TURN_START


# =============================================================================
# SKIP TURN EFFECTS (sleep, stun, paralysis)
# =============================================================================

## If true, unit cannot act while effect is active
@export var skips_turn: bool = false

## Chance per turn to recover from effect (0 = no recovery, 25 = paralysis-style)
## Only checked if skips_turn is true
@export_range(0, 100) var recovery_chance_per_turn: int = 0


# =============================================================================
# DAMAGE/HEALING OVER TIME
# =============================================================================

## Damage dealt per turn (positive = damage, negative = healing)
## Applied when trigger_timing fires
@export var damage_per_turn: int = 0


# =============================================================================
# STAT MODIFIERS (active while effect present)
# =============================================================================

## Stat modifiers applied while effect is active
## Keys: "strength", "defense", "agility", "intelligence", "luck", "max_hp", "max_mp"
## Values: Integer bonus/penalty (positive = buff, negative = debuff)
## Example: {"strength": 5, "defense": -3}
@export var stat_modifiers: Dictionary[String, int] = {}


# =============================================================================
# REMOVAL CONDITIONS
# =============================================================================

## Remove this effect when unit takes damage (sleep wakes on hit)
@export var removed_on_damage: bool = false

## Chance to remove when damaged (100 = always remove, 50 = 50% chance)
## Only used if removed_on_damage is true
@export_range(0, 100) var removal_on_damage_chance: int = 100


# =============================================================================
# ACTION MODIFICATION (confusion, berserk)
# =============================================================================

## How this effect modifies unit's actions
enum ActionModifier {
	NONE,            ## No action modification
	RANDOM_TARGET,   ## Target is randomly selected from all units (confusion)
	ATTACK_ALLIES,   ## Must attack allies (berserk/charm)
	CANNOT_USE_MAGIC,## Cannot cast spells
	CANNOT_USE_ITEMS ## Cannot use items
}
@export var action_modifier: ActionModifier = ActionModifier.NONE

## Chance that action_modifier applies each turn (50 = confusion sometimes works normally)
@export_range(0, 100) var action_modifier_chance: int = 100


# =============================================================================
# VALIDATION
# =============================================================================

## Validate that required fields are set
func validate() -> bool:
	if effect_id.is_empty():
		push_error("StatusEffectData: effect_id is required")
		return false

	# Validate stat_modifiers keys
	var valid_stats: Array[String] = ["strength", "defense", "agility", "intelligence", "luck", "max_hp", "max_mp"]
	for key: Variant in stat_modifiers.keys():
		if not key is String:
			push_warning("StatusEffectData '%s': stat_modifier key is not a String" % effect_id)
			continue
		var key_str: String = key
		if key_str not in valid_stats:
			push_warning("StatusEffectData '%s': Unknown stat modifier '%s'" % [effect_id, key_str])

	return true


## Get the popup text to display (falls back to display_name)
func get_popup_text() -> String:
	if not popup_text.is_empty():
		return popup_text
	if not display_name.is_empty():
		return display_name
	return effect_id.capitalize()


## Check if this effect has any stat modifiers
func has_stat_modifiers() -> bool:
	return not stat_modifiers.is_empty()


## Get a specific stat modifier value (returns 0 if not present)
func get_stat_modifier(stat_name: String) -> int:
	if stat_name in stat_modifiers:
		var value: Variant = stat_modifiers[stat_name]
		if value is int:
			return value
		elif value is float:
			return int(value)
		else:
			push_warning("StatusEffectData '%s': stat_modifier '%s' has non-numeric value, returning 0" % [effect_id, stat_name])
			return 0
	return 0
