## CombatCalculator - Combat damage and resolution formulas
##
## Static utility class for calculating combat outcomes using Shining Force-inspired
## formulas. All methods are pure calculations with no side effects.
##
## IMPORTANT: This is ENGINE CODE (mechanics).
## Character stats come from CharacterData/UnitStats (content in mods/).
class_name CombatCalculator
extends RefCounted

# Combat balance constants
const DAMAGE_VARIANCE_MIN: float = 0.9
const DAMAGE_VARIANCE_MAX: float = 1.1
const BASE_HIT_CHANCE: int = 80
const BASE_CRIT_CHANCE: int = 5
const COUNTER_DAMAGE_MULTIPLIER: float = 0.75
const XP_LEVEL_BONUS_PERCENT: float = 0.2
const XP_LEVEL_PENALTY_PERCENT: float = 0.1
const XP_MINIMUM_MULTIPLIER: float = 0.5


## Calculate physical attack damage
## Formula: (Attacker STR - Defender DEF) * variance(0.9 to 1.1)
## Returns: Minimum of 1 damage
static func calculate_physical_damage(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
	if not attacker_stats or not defender_stats:
		push_error("CombatCalculator: Cannot calculate damage with null stats")
		return 0

	var base_damage: int = attacker_stats.strength - defender_stats.defense

	# Apply variance (±10%)
	var variance: float = randf_range(DAMAGE_VARIANCE_MIN, DAMAGE_VARIANCE_MAX)
	var damage: int = int(base_damage * variance)

	# Minimum damage is always 1
	return maxi(damage, 1)


## Calculate magic attack damage
## Formula: (Ability Power + Attacker INT - Defender INT/2) * variance
## Returns: Minimum of 1 damage
static func calculate_magic_damage(
	attacker_stats: UnitStats,
	defender_stats: UnitStats,
	ability: Resource
) -> int:
	if not attacker_stats or not defender_stats or not ability:
		push_error("CombatCalculator: Cannot calculate magic damage with null parameters")
		return 0

	# Get ability power (AbilityData should have base_power property)
	var ability_power: int = 0
	if "base_power" in ability:
		ability_power = ability.base_power
	else:
		push_warning("CombatCalculator: Ability missing base_power property")

	var base_damage: int = ability_power + attacker_stats.intelligence - (defender_stats.intelligence / 2)

	# Apply variance (±10%)
	var variance: float = randf_range(DAMAGE_VARIANCE_MIN, DAMAGE_VARIANCE_MAX)
	var damage: int = int(base_damage * variance)

	# Minimum damage is always 1
	return maxi(damage, 1)


## Calculate hit chance (percentage)
## Formula: Base 80% + (Attacker AGI - Defender AGI) * 2
## Returns: Clamped between 10% and 99%
static func calculate_hit_chance(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
	if not attacker_stats or not defender_stats:
		push_error("CombatCalculator: Cannot calculate hit chance with null stats")
		return 50  # Default to 50% if error

	var base_hit: int = BASE_HIT_CHANCE
	var hit_modifier: int = (attacker_stats.agility - defender_stats.agility) * 2

	return clampi(base_hit + hit_modifier, 10, 99)


## Calculate critical hit chance (percentage)
## Formula: Base 5% + (Attacker LUK - Defender LUK)
## Returns: Clamped between 0% and 50%
static func calculate_crit_chance(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
	if not attacker_stats or not defender_stats:
		push_error("CombatCalculator: Cannot calculate crit chance with null stats")
		return 0

	var base_crit: int = BASE_CRIT_CHANCE
	var crit_modifier: int = attacker_stats.luck - defender_stats.luck

	return clampi(base_crit + crit_modifier, 0, 50)


## Check if attack hits (random roll)
## Returns: true if attack connects, false if miss
static func roll_hit(hit_chance: int) -> bool:
	var roll: int = randi_range(1, 100)
	return roll <= hit_chance


## Check if attack crits (random roll)
## Returns: true if critical hit, false otherwise
static func roll_crit(crit_chance: int) -> bool:
	var roll: int = randi_range(1, 100)
	return roll <= crit_chance


## Calculate healing amount
## Formula: (Ability Power + Caster INT/2) * variance
## Returns: Minimum of 1 healing
static func calculate_healing(caster_stats: UnitStats, ability: Resource) -> int:
	if not caster_stats or not ability:
		push_error("CombatCalculator: Cannot calculate healing with null parameters")
		return 0

	# Get ability power
	var ability_power: int = 0
	if "base_power" in ability:
		ability_power = ability.base_power
	else:
		push_warning("CombatCalculator: Healing ability missing base_power property")

	var base_healing: int = ability_power + (caster_stats.intelligence / 2)

	# Apply variance (±10%)
	var variance: float = randf_range(DAMAGE_VARIANCE_MIN, DAMAGE_VARIANCE_MAX)
	var healing: int = int(base_healing * variance)

	# Minimum healing is always 1
	return maxi(healing, 1)


## Calculate experience gain for defeating an enemy
## Formula: Base XP * Level difference multiplier
## Returns: XP amount to award
static func calculate_experience_gain(
	player_level: int,
	enemy_level: int,
	base_xp: int = 10
) -> int:
	var level_diff: int = enemy_level - player_level
	var multiplier: float = 1.0

	# Higher level enemies give more XP
	if level_diff > 0:
		multiplier = 1.0 + (level_diff * XP_LEVEL_BONUS_PERCENT)  # +20% per level above
	# Lower level enemies give less XP
	elif level_diff < 0:
		multiplier = maxf(XP_MINIMUM_MULTIPLIER, 1.0 + (level_diff * XP_LEVEL_PENALTY_PERCENT))  # -10% per level below, min 50%

	return maxi(1, int(base_xp * multiplier))


## Calculate counterattack damage (if unit can counter)
## In Shining Force, counterattacks happen at reduced damage
## Returns: Damage amount, or 0 if cannot counter
static func calculate_counter_damage(
	defender_stats: UnitStats,
	attacker_stats: UnitStats,
	can_counter: bool = true
) -> int:
	if not can_counter:
		return 0

	# Counterattacks deal 75% of normal damage
	var base_damage: int = calculate_physical_damage(defender_stats, attacker_stats)
	return int(base_damage * COUNTER_DAMAGE_MULTIPLIER)


## Check if unit can counterattack based on weapon range
## In Shining Force, you can only counter if your weapon range matches
## Returns: true if counter is possible
static func can_counterattack(
	defender_weapon_range: int,
	attack_distance: int
) -> bool:
	# Can only counter if weapon reaches the attacker
	return defender_weapon_range >= attack_distance
