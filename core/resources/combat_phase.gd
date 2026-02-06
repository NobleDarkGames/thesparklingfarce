class_name CombatPhase
extends RefCounted

## Represents a single phase of combat within a combat session.
##
## SF2 Authentic Flow: A full combat exchange stays on one screen:
##   - Initial Attack (attacker strikes defender)
##   - Double Attack (if attacker's class has double_attack_rate and roll succeeds)
##   - Counter Attack (if defender survives and counter conditions met)
##
## This resource is created by BattleManager before the combat animation starts,
## allowing the entire combat sequence to be pre-calculated and displayed
## without jarring fade transitions between phases.

## Phase types in combat order
enum PhaseType {
	INITIAL_ATTACK,   ## First strike from the initiating unit
	DOUBLE_ATTACK,    ## Second strike if AGI/class allows
	COUNTER_ATTACK,   ## Defender's retaliation (75% damage)
	SPELL_ATTACK,     ## Magic attack (no counter possible)
	SPELL_STATUS,     ## Status effect spell (confusion, sleep, etc.)
	ITEM_HEAL,        ## Item used to heal (shows HP going UP)
	SPELL_HEAL        ## Healing spell (shows HP going UP)
}

## The type of this combat phase
var phase_type: PhaseType = PhaseType.INITIAL_ATTACK

## The unit dealing damage in this phase
## For COUNTER_ATTACK, this is the original defender
var attacker: Unit = null

## The unit receiving damage in this phase
## For COUNTER_ATTACK, this is the original attacker
var defender: Unit = null

## Pre-calculated damage for this phase (0 if miss)
var damage: int = 0

## Healing amount for heal phases (ITEM_HEAL, SPELL_HEAL)
var heal_amount: int = 0

## Whether this attack was a critical hit
var was_critical: bool = false

## Whether this attack missed
var was_miss: bool = false

## Whether this is a counter attack (affects damage display and banner)
var is_counter: bool = false

## Whether this is a double attack (shows "DOUBLE ATTACK!" banner)
var is_double_attack: bool = false

## Name of the action (weapon name, spell name) for display in results
var action_name: String = ""

## Name of status effect applied (for SPELL_STATUS phases)
var status_effect_name: String = ""

## Whether the status effect was resisted
var was_resisted: bool = false


## Internal helper to create a base phase with common fields
static func _create_base(p_type: PhaseType, p_attacker: Unit, p_defender: Unit, p_action_name: String = "") -> CombatPhase:
	var phase: CombatPhase = CombatPhase.new()
	phase.phase_type = p_type
	phase.attacker = p_attacker
	phase.defender = p_defender
	phase.action_name = p_action_name
	return phase


## Factory method to create an initial attack phase
static func create_initial_attack(
	p_attacker: Unit,
	p_defender: Unit,
	p_damage: int,
	p_was_critical: bool,
	p_was_miss: bool,
	p_weapon_name: String = ""
) -> CombatPhase:
	var phase: CombatPhase = _create_base(PhaseType.INITIAL_ATTACK, p_attacker, p_defender, p_weapon_name)
	phase.damage = p_damage
	phase.was_critical = p_was_critical
	phase.was_miss = p_was_miss
	return phase


## Factory method to create a double attack phase
static func create_double_attack(
	p_attacker: Unit,
	p_defender: Unit,
	p_damage: int,
	p_was_critical: bool,
	p_was_miss: bool,
	p_weapon_name: String = ""
) -> CombatPhase:
	var phase: CombatPhase = _create_base(PhaseType.DOUBLE_ATTACK, p_attacker, p_defender, p_weapon_name)
	phase.damage = p_damage
	phase.was_critical = p_was_critical
	phase.was_miss = p_was_miss
	phase.is_double_attack = true
	return phase


## Factory method to create a counter attack phase
## Note: attacker/defender are SWAPPED from the original attack
static func create_counter_attack(
	p_counter_attacker: Unit,
	p_counter_target: Unit,
	p_damage: int,
	p_was_critical: bool,
	p_was_miss: bool,
	p_weapon_name: String = ""
) -> CombatPhase:
	var phase: CombatPhase = _create_base(PhaseType.COUNTER_ATTACK, p_counter_attacker, p_counter_target, p_weapon_name)
	phase.damage = p_damage
	phase.was_critical = p_was_critical
	phase.was_miss = p_was_miss
	phase.is_counter = true
	return phase


## Factory method to create a spell attack phase
## Spells cannot be countered or trigger double attacks
static func create_spell_attack(
	p_caster: Unit,
	p_target: Unit,
	p_damage: int,
	p_spell_name: String = ""
) -> CombatPhase:
	var phase: CombatPhase = _create_base(PhaseType.SPELL_ATTACK, p_caster, p_target, p_spell_name)
	phase.damage = p_damage
	return phase


## Factory method to create an item heal phase
## Shows HP going UP on the target
static func create_item_heal(
	p_user: Unit,
	p_target: Unit,
	p_heal_amount: int,
	p_item_name: String = ""
) -> CombatPhase:
	var phase: CombatPhase = _create_base(PhaseType.ITEM_HEAL, p_user, p_target, p_item_name)
	phase.heal_amount = p_heal_amount
	return phase


## Factory method to create a spell heal phase
## Shows HP going UP on the target
static func create_spell_heal(
	p_caster: Unit,
	p_target: Unit,
	p_heal_amount: int,
	p_spell_name: String = ""
) -> CombatPhase:
	var phase: CombatPhase = _create_base(PhaseType.SPELL_HEAL, p_caster, p_target, p_spell_name)
	phase.heal_amount = p_heal_amount
	return phase


## Factory method to create a status spell phase
## Shows status effect being applied (or resisted)
static func create_spell_status(
	p_caster: Unit,
	p_target: Unit,
	p_spell_name: String,
	p_status_effect: String,
	p_was_resisted: bool = false
) -> CombatPhase:
	var phase: CombatPhase = _create_base(PhaseType.SPELL_STATUS, p_caster, p_target, p_spell_name)
	phase.was_resisted = p_was_resisted
	phase.status_effect_name = p_status_effect
	return phase


## Phase type display names for debugging
const PHASE_TYPE_NAMES: Dictionary = {
	PhaseType.INITIAL_ATTACK: "Initial",
	PhaseType.DOUBLE_ATTACK: "Double",
	PhaseType.COUNTER_ATTACK: "Counter",
	PhaseType.SPELL_ATTACK: "Spell",
	PhaseType.SPELL_STATUS: "Status",
	PhaseType.ITEM_HEAL: "Item Heal",
	PhaseType.SPELL_HEAL: "Spell Heal"
}


## Get a human-readable description for debugging
func get_description() -> String:
	var type_str: String = PHASE_TYPE_NAMES.get(phase_type, "Unknown")
	var attacker_name: String = _get_unit_display_name(attacker)
	var defender_name: String = _get_unit_display_name(defender)
	var action_str: String = " with %s" % action_name if not action_name.is_empty() else ""

	# Handle status phases
	if phase_type == PhaseType.SPELL_STATUS:
		var outcome: String = "RESISTED" if was_resisted else "%s applied" % status_effect_name
		return "%s: %s casts %s on %s - %s" % [type_str, attacker_name, action_name, defender_name, outcome]

	# Handle healing phases
	if phase_type == PhaseType.ITEM_HEAL or phase_type == PhaseType.SPELL_HEAL:
		return "%s: %s heals %s%s - %d HP" % [type_str, attacker_name, defender_name, action_str, heal_amount]

	# Handle attack phases
	var outcome: String = "MISS" if was_miss else ("CRITICAL %d damage" % damage if was_critical else "%d damage" % damage)
	return "%s: %s attacks %s%s - %s" % [type_str, attacker_name, defender_name, action_str, outcome]


## Get display text for combat results panel
## Format varies by phase type:
##   Initial: "Name hit with WEAPON for X damage!"
##   Double:  "Name struck again for X damage!"
##   Counter: "Name countered for X damage!"
##   Spell:   "Name cast SPELL for X damage!"
##   Item Heal: "Name used ITEM - Recovered X HP!"
##   Spell Heal: "Name cast SPELL - Recovered X HP!"
##   Miss:    "Name missed!" or "Name's counter missed!"
func get_result_text() -> String:
	var attacker_name: String = _get_unit_display_name(attacker)
	var defender_name: String = _get_unit_display_name(defender)
	var is_self_target: bool = attacker == defender
	var has_action: bool = not action_name.is_empty()
	var upper_action: String = action_name.to_upper()

	# Handle healing phases first (heals don't miss)
	if phase_type == PhaseType.ITEM_HEAL:
		return _format_heal_text(attacker_name, defender_name, is_self_target, has_action, upper_action, "used", "used an item")

	if phase_type == PhaseType.SPELL_HEAL:
		return _format_heal_text(attacker_name, defender_name, is_self_target, has_action, upper_action, "cast", "cast a healing spell")

	# Handle status effect phases
	if phase_type == PhaseType.SPELL_STATUS:
		if was_resisted:
			if has_action:
				return "%s cast %s on %s - Resisted!" % [attacker_name, upper_action, defender_name]
			return "%s's spell was resisted by %s!" % [attacker_name, defender_name]
		if has_action:
			return "%s cast %s on %s - %s!" % [attacker_name, upper_action, defender_name, status_effect_name.capitalize()]
		return "%s inflicted %s on %s!" % [attacker_name, status_effect_name.capitalize(), defender_name]

	# Handle misses based on phase type
	if was_miss:
		if phase_type == PhaseType.COUNTER_ATTACK:
			return "%s's counter missed!" % attacker_name
		if phase_type == PhaseType.DOUBLE_ATTACK:
			return "%s's second attack missed!" % attacker_name
		return "%s missed!" % attacker_name

	# Build damage string for attack phases
	var damage_str: String = "%d CRITICAL damage" % damage if was_critical else "%d damage" % damage

	# Format based on phase type
	if phase_type == PhaseType.SPELL_ATTACK:
		if has_action:
			return "%s cast %s for %s!" % [attacker_name, upper_action, damage_str]
		return "%s cast a spell for %s!" % [attacker_name, damage_str]

	if phase_type == PhaseType.DOUBLE_ATTACK:
		if has_action:
			return "%s struck again with %s for %s!" % [attacker_name, upper_action, damage_str]
		return "%s struck again for %s!" % [attacker_name, damage_str]

	if phase_type == PhaseType.COUNTER_ATTACK:
		if has_action:
			return "%s countered with %s for %s!" % [attacker_name, upper_action, damage_str]
		return "%s countered for %s!" % [attacker_name, damage_str]

	# INITIAL_ATTACK or unknown
	if has_action:
		return "%s hit with %s for %s!" % [attacker_name, upper_action, damage_str]
	return "%s hit for %s!" % [attacker_name, damage_str]


## Helper for formatting heal result text
func _format_heal_text(attacker_name: String, defender_name: String, is_self: bool, has_action: bool, upper_action: String, verb: String, default_verb: String) -> String:
	if is_self:
		if has_action:
			return "%s %s %s - Recovered %d HP!" % [attacker_name, verb, upper_action, heal_amount]
		return "%s %s - Recovered %d HP!" % [attacker_name, default_verb, heal_amount]
	if has_action:
		return "%s %s %s on %s - Recovered %d HP!" % [attacker_name, verb, upper_action, defender_name, heal_amount]
	return "%s healed %s - Recovered %d HP!" % [attacker_name, defender_name, heal_amount]


## Helper to safely get a unit's display name
## Returns "Unknown" if unit is null, freed, or method returns non-String
func _get_unit_display_name(unit: Unit) -> String:
	if not is_instance_valid(unit) or not unit.has_method("get_display_name"):
		return "Unknown"
	var result: Variant = unit.call("get_display_name")
	if result is String:
		return result
	return "Unknown"
