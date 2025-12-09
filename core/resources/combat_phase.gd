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
	SPELL_ATTACK      ## Magic attack (no counter possible)
}

## The type of this combat phase
var phase_type: PhaseType = PhaseType.INITIAL_ATTACK

## The unit dealing damage in this phase
## For COUNTER_ATTACK, this is the original defender
var attacker: Node2D = null

## The unit receiving damage in this phase
## For COUNTER_ATTACK, this is the original attacker
var defender: Node2D = null

## Pre-calculated damage for this phase (0 if miss)
var damage: int = 0

## Whether this attack was a critical hit
var was_critical: bool = false

## Whether this attack missed
var was_miss: bool = false

## Whether this is a counter attack (affects damage display and banner)
var is_counter: bool = false

## Whether this is a double attack (shows "DOUBLE ATTACK!" banner)
var is_double_attack: bool = false


## Factory method to create an initial attack phase
static func create_initial_attack(
	p_attacker: Node2D,
	p_defender: Node2D,
	p_damage: int,
	p_was_critical: bool,
	p_was_miss: bool
) -> CombatPhase:
	var phase: CombatPhase = CombatPhase.new()
	phase.phase_type = PhaseType.INITIAL_ATTACK
	phase.attacker = p_attacker
	phase.defender = p_defender
	phase.damage = p_damage
	phase.was_critical = p_was_critical
	phase.was_miss = p_was_miss
	phase.is_counter = false
	phase.is_double_attack = false
	return phase


## Factory method to create a double attack phase
static func create_double_attack(
	p_attacker: Node2D,
	p_defender: Node2D,
	p_damage: int,
	p_was_critical: bool,
	p_was_miss: bool
) -> CombatPhase:
	var phase: CombatPhase = CombatPhase.new()
	phase.phase_type = PhaseType.DOUBLE_ATTACK
	phase.attacker = p_attacker
	phase.defender = p_defender
	phase.damage = p_damage
	phase.was_critical = p_was_critical
	phase.was_miss = p_was_miss
	phase.is_counter = false
	phase.is_double_attack = true
	return phase


## Factory method to create a counter attack phase
## Note: attacker/defender are SWAPPED from the original attack
static func create_counter_attack(
	p_counter_attacker: Node2D,
	p_counter_target: Node2D,
	p_damage: int,
	p_was_critical: bool,
	p_was_miss: bool
) -> CombatPhase:
	var phase: CombatPhase = CombatPhase.new()
	phase.phase_type = PhaseType.COUNTER_ATTACK
	phase.attacker = p_counter_attacker
	phase.defender = p_counter_target
	phase.damage = p_damage
	phase.was_critical = p_was_critical
	phase.was_miss = p_was_miss
	phase.is_counter = true
	phase.is_double_attack = false
	return phase


## Factory method to create a spell attack phase
## Spells cannot be countered or trigger double attacks
static func create_spell_attack(
	p_caster: Node2D,
	p_target: Node2D,
	p_damage: int
) -> CombatPhase:
	var phase: CombatPhase = CombatPhase.new()
	phase.phase_type = PhaseType.SPELL_ATTACK
	phase.attacker = p_caster
	phase.defender = p_target
	phase.damage = p_damage
	phase.was_critical = false  # Spells don't crit in SF2
	phase.was_miss = false      # Spells don't miss in SF2
	phase.is_counter = false
	phase.is_double_attack = false
	return phase


## Get a human-readable description for debugging
func get_description() -> String:
	var type_str: String = ""
	match phase_type:
		PhaseType.INITIAL_ATTACK:
			type_str = "Initial"
		PhaseType.DOUBLE_ATTACK:
			type_str = "Double"
		PhaseType.COUNTER_ATTACK:
			type_str = "Counter"
		PhaseType.SPELL_ATTACK:
			type_str = "Spell"

	var attacker_name: String = attacker.get_display_name() if attacker and attacker.has_method("get_display_name") else "Unknown"
	var defender_name: String = defender.get_display_name() if defender and defender.has_method("get_display_name") else "Unknown"

	if was_miss:
		return "%s: %s attacks %s - MISS" % [type_str, attacker_name, defender_name]
	elif was_critical:
		return "%s: %s attacks %s - CRITICAL %d damage" % [type_str, attacker_name, defender_name, damage]
	else:
		return "%s: %s attacks %s - %d damage" % [type_str, attacker_name, defender_name, damage]
