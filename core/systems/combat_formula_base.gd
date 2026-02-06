## CombatFormulaBase - Base class for custom combat formulas
##
## Extend this class to create completely different combat systems.
## Total conversion mods can implement their own damage formulas, hit calculations,
## and other combat mechanics without modifying core engine code.
##
## Example: A sci-fi mod might want energy shields, armor penetration, or tech-based combat.
##
## Usage:
## 1. Create a script that extends CombatFormulaBase
## 2. Override the methods you want to customize
## 3. Create a CombatFormulaConfig resource pointing to your script
## 4. Assign the config to BattleData.combat_formula_config
##
## NOTE: Default implementations here match CombatCalculator's default formulas.
## Override only the methods you want to change.
class_name CombatFormulaBase
extends RefCounted

# Combat balance constants (same as CombatCalculator defaults)
const DAMAGE_VARIANCE_MIN: float = 0.9
const DAMAGE_VARIANCE_MAX: float = 1.1
const COUNTER_DAMAGE_MULTIPLIER: float = 0.75
const XP_LEVEL_BONUS_PERCENT: float = 0.2
const XP_LEVEL_PENALTY_PERCENT: float = 0.1
const XP_MINIMUM_MULTIPLIER: float = 0.5


## Calculate physical attack damage
## Override this to change the core damage formula
## Default: (STR + Weapon ATK - DEF) * weapon_bonus * variance, min 1
func calculate_physical_damage(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
	if not attacker_stats or not defender_stats:
		return 0

	var attack_power: int = attacker_stats.get_effective_strength()
	attack_power += attacker_stats.get_weapon_attack_power()
	var defense_power: int = defender_stats.get_effective_defense()
	var base_damage: int = attack_power - defense_power

	# Apply weapon type bonuses (movement type and unit tag multipliers)
	var weapon_multiplier: float = calculate_weapon_bonus_multiplier(attacker_stats, defender_stats)
	base_damage = int(base_damage * weapon_multiplier)

	var variance: float = RandomManager.combat_rng.randf_range(DAMAGE_VARIANCE_MIN, DAMAGE_VARIANCE_MAX)
	var damage: int = int(base_damage * variance)
	return maxi(damage, 1)


## Calculate physical damage with terrain defense bonus
## Override for terrain-aware custom damage formulas
func calculate_physical_damage_with_terrain(
	attacker_stats: UnitStats,
	defender_stats: UnitStats,
	terrain_defense_bonus: int
) -> int:
	if not attacker_stats or not defender_stats:
		return 0

	var attack_power: int = attacker_stats.get_effective_strength()
	attack_power += attacker_stats.get_weapon_attack_power()
	var effective_defense: int = defender_stats.get_effective_defense() + terrain_defense_bonus
	var base_damage: int = attack_power - effective_defense

	# Apply weapon type bonuses (movement type and unit tag multipliers)
	var weapon_multiplier: float = calculate_weapon_bonus_multiplier(attacker_stats, defender_stats)
	base_damage = int(base_damage * weapon_multiplier)

	var variance: float = RandomManager.combat_rng.randf_range(DAMAGE_VARIANCE_MIN, DAMAGE_VARIANCE_MAX)
	var damage: int = int(base_damage * variance)
	return maxi(damage, 1)


## Calculate magic attack damage
## Override to implement custom spell damage mechanics
## Default: (Ability Power + INT - DEF INT/2) * variance, min 1
func calculate_magic_damage(
	attacker_stats: UnitStats,
	defender_stats: UnitStats,
	ability: AbilityData
) -> int:
	if not attacker_stats or not defender_stats or not ability:
		return 0

	var ability_power: int = ability.potency

	@warning_ignore("integer_division")
	var base_damage: int = ability_power + attacker_stats.intelligence - (defender_stats.intelligence / 2)
	var variance: float = RandomManager.combat_rng.randf_range(DAMAGE_VARIANCE_MIN, DAMAGE_VARIANCE_MAX)
	var damage: int = int(base_damage * variance)
	return maxi(damage, 1)


## Calculate hit chance (percentage 0-100)
## Override to implement custom accuracy mechanics
## Default: Weapon Hit Rate + (AGI diff * 2), clamped 10-99
func calculate_hit_chance(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
	if not attacker_stats or not defender_stats:
		return 50

	var base_hit: int = attacker_stats.get_weapon_hit_rate()
	var hit_modifier: int = (attacker_stats.get_effective_agility() - defender_stats.get_effective_agility()) * 2
	return clampi(base_hit + hit_modifier, 10, 99)


## Calculate hit chance with terrain evasion bonus
## Override for terrain-aware custom hit calculations
func calculate_hit_chance_with_terrain(
	attacker_stats: UnitStats,
	defender_stats: UnitStats,
	terrain_evasion_bonus: int
) -> int:
	var base_hit: int = calculate_hit_chance(attacker_stats, defender_stats)
	return clampi(base_hit - terrain_evasion_bonus, 10, 99)


## Calculate critical hit chance (percentage 0-100)
## Override to implement custom crit mechanics
## Default: Weapon Crit Rate + (LUK diff), clamped 0-50
func calculate_crit_chance(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
	if not attacker_stats or not defender_stats:
		return 0

	var base_crit: int = attacker_stats.get_weapon_crit_rate()
	var crit_modifier: int = attacker_stats.get_effective_luck() - defender_stats.get_effective_luck()
	return clampi(base_crit + crit_modifier, 0, 50)


## Calculate healing amount
## Override to implement custom healing mechanics
## Default: (Ability Power + INT/2) * variance, min 1
func calculate_healing(caster_stats: UnitStats, ability: AbilityData) -> int:
	if not caster_stats or not ability:
		return 0

	var ability_power: int = ability.potency

	@warning_ignore("integer_division")
	var base_healing: int = ability_power + (caster_stats.intelligence / 2)
	var variance: float = RandomManager.combat_rng.randf_range(DAMAGE_VARIANCE_MIN, DAMAGE_VARIANCE_MAX)
	var healing: int = int(base_healing * variance)
	return maxi(healing, 1)


## Calculate counter chance (percentage 0-100)
## Override to implement custom counterattack chance mechanics
## Default: Class counter_rate, clamped 0-50
func calculate_counter_chance(defender_stats: UnitStats) -> int:
	if not defender_stats:
		return 0

	var counter_rate: int = 12
	if defender_stats.class_data and "counter_rate" in defender_stats.class_data:
		counter_rate = defender_stats.class_data.counter_rate
	return clampi(counter_rate, 0, 50)


## Calculate counterattack damage
## Override to implement custom counter damage (e.g., full damage instead of reduced)
## Default: 75% of normal physical damage
func calculate_counter_damage(
	defender_stats: UnitStats,
	attacker_stats: UnitStats,
	can_counter: bool = true
) -> int:
	if not can_counter:
		return 0

	var base_damage: int = calculate_physical_damage(defender_stats, attacker_stats)
	return int(base_damage * COUNTER_DAMAGE_MULTIPLIER)


## Calculate experience gain
## Override to implement custom XP formulas
## Default: Base XP * level difference multiplier
func calculate_experience_gain(
	player_level: int,
	enemy_level: int,
	base_xp: int = 10
) -> int:
	var level_diff: int = enemy_level - player_level
	var multiplier: float = 1.0

	if level_diff > 0:
		multiplier = 1.0 + (level_diff * XP_LEVEL_BONUS_PERCENT)
	elif level_diff < 0:
		multiplier = maxf(XP_MINIMUM_MULTIPLIER, 1.0 + (level_diff * XP_LEVEL_PENALTY_PERCENT))

	return maxi(1, int(base_xp * multiplier))


## Calculate weapon bonus multiplier for damage (movement types, unit tags, etc.)
## Override this to implement custom bonus systems (e.g., elemental weaknesses)
## Default: Delegates to CombatCalculator's static implementation
func calculate_weapon_bonus_multiplier(attacker_stats: UnitStats, defender_stats: UnitStats) -> float:
	return CombatCalculator._calculate_weapon_bonus_multiplier(attacker_stats, defender_stats)
