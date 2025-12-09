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


## Calculate physical attack damage with weapon
## Formula: (Attacker STR + Weapon ATK - Defender DEF) * variance(0.9 to 1.1)
## Returns: Minimum of 1 damage
static func calculate_physical_damage(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
	if not attacker_stats or not defender_stats:
		push_error("CombatCalculator: Cannot calculate damage with null stats")
		return 0

	# Get effective strength (includes equipment bonuses)
	var attack_power: int = attacker_stats.get_effective_strength()

	# Add weapon attack power
	attack_power += attacker_stats.get_weapon_attack_power()

	# Get effective defense (includes equipment bonuses)
	var defense_power: int = defender_stats.get_effective_defense()

	var base_damage: int = attack_power - defense_power

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

	# Get ability power (AbilityData uses 'power' field)
	var ability_power: int = 0
	if "power" in ability:
		ability_power = ability.power
	else:
		push_warning("CombatCalculator: Ability missing power property")

	var base_damage: int = ability_power + attacker_stats.intelligence - (defender_stats.intelligence / 2)

	# Apply variance (±10%)
	var variance: float = randf_range(DAMAGE_VARIANCE_MIN, DAMAGE_VARIANCE_MAX)
	var damage: int = int(base_damage * variance)

	# Minimum damage is always 1
	return maxi(damage, 1)


## Calculate hit chance (percentage) with weapon hit rate
## Formula: Weapon Hit Rate + (Attacker AGI - Defender AGI) * 2
## Returns: Clamped between 10% and 99%
static func calculate_hit_chance(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
	if not attacker_stats or not defender_stats:
		push_error("CombatCalculator: Cannot calculate hit chance with null stats")
		return 50  # Default to 50% if error

	# Get weapon hit rate (or default base hit rate)
	var base_hit: int = attacker_stats.get_weapon_hit_rate()

	# Calculate agility modifier
	var hit_modifier: int = (attacker_stats.get_effective_agility() - defender_stats.get_effective_agility()) * 2

	return clampi(base_hit + hit_modifier, 10, 99)


## Calculate critical hit chance (percentage) with weapon crit rate
## Formula: Weapon Crit Rate + (Attacker LUK - Defender LUK)
## Returns: Clamped between 0% and 50%
static func calculate_crit_chance(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
	if not attacker_stats or not defender_stats:
		push_error("CombatCalculator: Cannot calculate crit chance with null stats")
		return 0

	# Get weapon crit rate (or default base crit rate)
	var base_crit: int = attacker_stats.get_weapon_crit_rate()

	# Calculate luck modifier
	var crit_modifier: int = attacker_stats.get_effective_luck() - defender_stats.get_effective_luck()

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

	# Get ability power (AbilityData uses 'power' field)
	var ability_power: int = 0
	if "power" in ability:
		ability_power = ability.power
	else:
		push_warning("CombatCalculator: Healing ability missing power property")

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
## DEPRECATED: Use can_counterattack_with_range_band() for weapons with dead zones
## Returns: true if counter is possible
static func can_counterattack(
	defender_weapon_range: int,
	attack_distance: int
) -> bool:
	# Can only counter if weapon reaches the attacker
	return defender_weapon_range >= attack_distance


## Check if unit can counterattack based on weapon min/max range
## Supports dead zones: a bow (min=2, max=3) CANNOT counter at distance 1
## Returns: true if counter is possible within the weapon's range band
static func can_counterattack_with_range_band(
	defender_min_range: int,
	defender_max_range: int,
	attack_distance: int
) -> bool:
	# Can only counter if attacker is within defender's weapon range band
	# This properly handles dead zones - a bow cannot counter adjacent attackers
	return attack_distance >= defender_min_range and attack_distance <= defender_max_range


## Check if attacker can reach target with their weapon
## Uses the cached weapon range from UnitStats
## DEPRECATED: Use can_attack_at_range_band() for weapons with dead zones
static func can_attack_at_range(attacker_stats: UnitStats, distance: int) -> bool:
	if not attacker_stats:
		return false
	return attacker_stats.get_weapon_range() >= distance


## Check if attacker can reach target within their weapon's range band
## Supports dead zones: a bow (min=2, max=3) returns false for distance=1
static func can_attack_at_range_band(attacker_stats: UnitStats, distance: int) -> bool:
	if not attacker_stats:
		return false
	return attacker_stats.can_attack_at_distance(distance)


## Calculate counter chance based on defender's class
## SF2 uses class-based rates (1/4, 1/8, 1/16, 1/32) not agility
## Returns: Counter chance percentage (0-50)
static func calculate_counter_chance(defender_stats: UnitStats) -> int:
	if not defender_stats:
		return 0

	# Get counter rate from class data (default 12% if no class)
	var counter_rate: int = 12
	if defender_stats.class_data and "counter_rate" in defender_stats.class_data:
		counter_rate = defender_stats.class_data.counter_rate

	return clampi(counter_rate, 0, 50)


## Roll for counterattack
## Returns: true if counter occurs
static func roll_counter(counter_chance: int) -> bool:
	if counter_chance <= 0:
		return false
	var roll: int = randi_range(1, 100)
	return roll <= counter_chance


## Full counterattack check - combines range check and roll
## DEPRECATED: Use check_counterattack_with_range_band() for weapons with dead zones
## Returns: Dictionary with {can_counter: bool, will_counter: bool, chance: int}
static func check_counterattack(
	defender_stats: UnitStats,
	defender_weapon_range: int,
	attack_distance: int,
	defender_is_alive: bool
) -> Dictionary:
	# Delegate to range band version with min_range=1 for backwards compatibility
	return check_counterattack_with_range_band(
		defender_stats,
		1,  # min_range defaults to 1 (melee)
		defender_weapon_range,
		attack_distance,
		defender_is_alive
	)


## Full counterattack check with range band support - combines range check and roll
## Properly handles dead zones: a bow (min=2, max=3) CANNOT counter at distance 1
## Returns: Dictionary with {can_counter: bool, will_counter: bool, chance: int}
static func check_counterattack_with_range_band(
	defender_stats: UnitStats,
	defender_min_range: int,
	defender_max_range: int,
	attack_distance: int,
	defender_is_alive: bool
) -> Dictionary:
	var result: Dictionary = {
		"can_counter": false,
		"will_counter": false,
		"chance": 0
	}

	# Dead units can't counter
	if not defender_is_alive:
		return result

	# Check range requirement using range band (supports dead zones)
	if not can_counterattack_with_range_band(defender_min_range, defender_max_range, attack_distance):
		return result

	# Calculate and store chance
	result.chance = calculate_counter_chance(defender_stats)
	result.can_counter = result.chance > 0

	# Roll for counter
	if result.can_counter:
		result.will_counter = roll_counter(result.chance)

	return result


## Calculate hit chance with terrain evasion bonus
## Formula: Base hit chance - terrain_evasion_bonus
## Returns: Clamped between 10% and 99%
static func calculate_hit_chance_with_terrain(
	attacker_stats: UnitStats,
	defender_stats: UnitStats,
	terrain_evasion_bonus: int
) -> int:
	var base_hit: int = calculate_hit_chance(attacker_stats, defender_stats)
	return clampi(base_hit - terrain_evasion_bonus, 10, 99)


## Calculate effective defense with terrain bonus
## Returns: Defender's effective defense (including equipment) + terrain_defense_bonus
static func get_effective_defense_with_terrain(
	defender_stats: UnitStats,
	terrain_defense_bonus: int
) -> int:
	return defender_stats.get_effective_defense() + terrain_defense_bonus


## Calculate physical damage with terrain defense bonus
## Formula: (Attacker STR + Weapon ATK - (Defender DEF + terrain_def)) * variance
## Returns: Minimum of 1 damage
static func calculate_physical_damage_with_terrain(
	attacker_stats: UnitStats,
	defender_stats: UnitStats,
	terrain_defense_bonus: int
) -> int:
	if not attacker_stats or not defender_stats:
		push_error("CombatCalculator: Cannot calculate damage with null stats")
		return 0

	# Get effective strength (includes equipment bonuses)
	var attack_power: int = attacker_stats.get_effective_strength()

	# Add weapon attack power
	attack_power += attacker_stats.get_weapon_attack_power()

	# Get effective defense (includes equipment bonuses) + terrain bonus
	var effective_defense: int = defender_stats.get_effective_defense() + terrain_defense_bonus

	var base_damage: int = attack_power - effective_defense

	# Apply variance (+/- 10%)
	var variance: float = randf_range(DAMAGE_VARIANCE_MIN, DAMAGE_VARIANCE_MAX)
	var damage: int = int(base_damage * variance)

	# Minimum damage is always 1
	return maxi(damage, 1)
