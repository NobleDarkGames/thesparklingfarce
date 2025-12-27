extends Node

## ExperienceManager - Central system for XP awards and level-up mechanics.
##
## Autoload singleton responsible for:
## - Calculating and awarding combat XP (damage, kills, formation bonus)
## - Calculating and awarding support XP (healing, buffs, debuffs)
## - Processing level-ups and stat increases
## - Learning new abilities at milestone levels
## - Handling promotions (future)
##
## Emits signals for UI to respond to XP gains and level-ups.

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when a unit gains XP.
## @param unit: The Unit that gained XP
## @param amount: Amount of XP gained
## @param source: Source of XP ("damage", "kill", "formation", "heal", etc.)
signal unit_gained_xp(unit: Node2D, amount: int, source: String)

## Emitted when a unit levels up.
## @param unit: The Unit that leveled up
## @param old_level: Previous level
## @param new_level: New level
## @param stat_increases: Dictionary of stat increases {stat_name: increase_amount}
signal unit_leveled_up(unit: Node2D, old_level: int, new_level: int, stat_increases: Dictionary)

## Emitted when a unit learns a new ability.
## @param unit: The Unit that learned the ability
## @param ability: The AbilityData learned
signal unit_learned_ability(unit: Node2D, ability: AbilityData)

## Emitted when a unit is promoted to a new class.
## @param unit: The Unit that was promoted
## @param old_class: Previous ClassData
## @param new_class: New ClassData
signal unit_promoted(unit: Node2D, old_class: ClassData, new_class: ClassData)


# ============================================================================
# CONFIGURATION
# ============================================================================

## Configuration resource with all XP settings.
## Set by BattleData or use default values.
var config: ExperienceConfig = null


# ============================================================================
# XP SOURCE TYPES
# ============================================================================

enum XPSource {
	DAMAGE,          ## XP from dealing damage
	KILL,            ## Bonus XP from killing an enemy
	FORMATION,       ## XP from being positioned near an ally's combat
	HEAL,            ## XP from healing
	BUFF,            ## XP from buffing allies
	DEBUFF,          ## XP from debuffing enemies
	MISSION_COMPLETE ## XP from completing battle objectives
}


# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Load config from mod registry, falling back to default if not found
	_load_config_from_registry()


## Load experience configuration from the mod registry.
## Falls back to a default ExperienceConfig if no mod provides one.
## This allows mods to customize XP curves, anti-spam settings, promotion levels, etc.
func _load_config_from_registry() -> void:
	if config != null:
		return  # Config already set (e.g., by BattleData)

	# Try to load from mod registry
	if ModLoader and ModLoader.registry:
		var resource: Resource = ModLoader.registry.get_resource("experience_config", "default")
		if resource is ExperienceConfig:
			config = resource
			return

	# Fallback: create default config if no mod provides one
	config = ExperienceConfig.new()


## Set the configuration for this battle.
## Called by BattleManager when battle starts.
## If null is passed, reloads from registry (or uses default).
func set_config(new_config: ExperienceConfig) -> void:
	if new_config != null:
		config = new_config
	else:
		# Reset to registry config (or default)
		config = null
		_load_config_from_registry()


# ============================================================================
# COMBAT XP METHODS
# ============================================================================

## Award combat XP for an attack action.
##
## Distributes XP to:
## - Attacker (based on damage dealt)
## - Attacker (bonus if got kill)
## - Nearby allies (formation XP for tactical positioning)
##
## @param attacker: Unit that performed the attack
## @param defender: Unit that was attacked
## @param damage_dealt: Amount of damage dealt
## @param got_kill: Whether this attack killed the defender
func award_combat_xp(attacker: Unit, defender: Unit, damage_dealt: int, got_kill: bool) -> void:
	if attacker == null or defender == null:
		push_warning("ExperienceManager: Cannot award combat XP with null units")
		return

	if attacker.stats == null or defender.stats == null:
		push_warning("ExperienceManager: Units missing stats")
		return

	# Calculate base XP from level difference
	var level_diff: int = defender.stats.level - attacker.stats.level
	var base_xp: int = config.get_base_xp_from_level_diff(level_diff)

	# Calculate attacker's XP
	var attacker_xp: int = 0

	# Damage XP: proportional to damage dealt, with minimum floor
	if damage_dealt > 0:
		var damage_ratio: float = float(damage_dealt) / float(defender.stats.max_hp)
		var damage_xp: int = int(base_xp * damage_ratio)

		# Ensure minimum XP for any successful hit (prevents chip damage being worthless)
		var min_damage_xp: int = maxi(1, int(base_xp * config.min_damage_xp_ratio))
		damage_xp = maxi(damage_xp, min_damage_xp)

		attacker_xp += damage_xp

	# Kill bonus XP
	if got_kill:
		var kill_bonus: int = int(base_xp * config.kill_bonus_multiplier)
		attacker_xp += kill_bonus

	# Cap at max XP per action
	attacker_xp = mini(attacker_xp, config.max_xp_per_action)

	# Only award XP to player faction - enemies don't use our progression system
	if attacker.faction != "player":
		return

	# Award to attacker
	if attacker_xp > 0:
		var source: String = "kill" if got_kill else "damage"
		_give_xp_to_unit(attacker, attacker_xp, source)

	# Award formation XP to nearby allies (rewards tactical positioning)
	# Each ally receives a percentage of base XP individually (not divided from a pool)
	# Allies who are behind the party average level receive bonus XP (catch-up mechanic)
	if config.enable_formation_xp and damage_dealt > 0:
		var nearby_allies: Array[Unit] = _get_units_in_formation_radius(attacker)

		if nearby_allies.size() > 0:
			# Base formation XP per ally (before catch-up adjustment)
			var per_ally_base: int = int(base_xp * config.formation_multiplier)
			# Cap at percentage of attacker's actual XP to prevent bystanders outearning fighters
			var max_formation_xp: int = int(attacker_xp * config.formation_cap_ratio)
			per_ally_base = mini(per_ally_base, max_formation_xp)

			# Get party average level for catch-up calculation
			var avg_level: float = _get_party_average_level()

			for ally: Unit in nearby_allies:
				var ally_xp: int = per_ally_base

				# Apply catch-up multiplier: underleveled allies earn more, overleveled earn less
				if config.formation_catch_up_rate > 0.0:
					var level_gap: int = int(avg_level) - ally.stats.level
					# Clamp multiplier: -50% (5 levels ahead) to +150% (10 levels behind)
					var catch_up_mult: float = 1.0 + clampf(
						level_gap * config.formation_catch_up_rate,
						-0.5,
						1.5
					)
					ally_xp = int(ally_xp * catch_up_mult)

				# Ensure minimum 1 XP for being in formation
				ally_xp = maxi(1, ally_xp)
				_give_xp_to_unit(ally, ally_xp, "formation")


## Get all allied units within formation radius of a unit.
##
## @param center_unit: Unit to check from
## @return: Array of Units within formation range
func _get_units_in_formation_radius(center_unit: Unit) -> Array[Unit]:
	var nearby_allies: Array[Unit] = []

	if not is_instance_valid(center_unit):
		return nearby_allies

	var center_pos: Vector2i = center_unit.grid_position
	var all_units: Array = TurnManager.all_units

	for unit: Unit in all_units:
		# Skip self
		if unit == center_unit:
			continue

		# Only same faction
		if unit.faction != center_unit.faction:
			continue

		# Must be alive
		if not unit.stats.is_alive():
			continue

		# Check distance
		var distance: int = GridManager.get_distance(center_pos, unit.grid_position)
		if distance <= config.formation_radius:
			nearby_allies.append(unit)

	return nearby_allies


# ============================================================================
# SUPPORT XP METHODS
# ============================================================================

## Award XP for support actions (healing, buffs, debuffs).
##
## Applies anti-spam scaling based on usage count this battle.
##
## @param supporter: Unit performing the support action
## @param action_type: Type of action ("heal", "buff", "debuff")
## @param target: Unit being targeted (for heal ratio calculation)
## @param amount: Amount healed (for healing XP) or 0 for buffs/debuffs
func award_support_xp(supporter: Unit, action_type: String, target: Unit, amount: int) -> void:
	if not config.enable_enhanced_support_xp:
		return

	if supporter == null or supporter.stats == null:
		push_warning("ExperienceManager: Cannot award support XP with null supporter")
		return

	var base_xp: int = 0

	match action_type:
		"heal":
			if target == null or target.stats == null:
				return
			# Base XP + ratio bonus
			var heal_ratio: float = float(amount) / float(target.stats.max_hp)
			base_xp = config.heal_base_xp + int(config.heal_ratio_multiplier * heal_ratio)

		"buff":
			base_xp = config.buff_base_xp

		"debuff":
			base_xp = config.debuff_base_xp

		_:
			push_warning("ExperienceManager: Unknown support action type: %s" % action_type)
			return

	# Apply anti-spam scaling
	if config.anti_spam_enabled:
		var usage_count_value: Variant = supporter.stats.support_actions_this_battle.get(action_type, 0)
		var usage_count: int = usage_count_value if usage_count_value is int else 0
		var multiplier: float = config.get_anti_spam_multiplier(usage_count)
		base_xp = int(base_xp * multiplier)

		# Increment usage count
		supporter.stats.support_actions_this_battle[action_type] = usage_count + 1

	# Apply catch-up multiplier for underleveled supporters
	# Healers who fall behind earn bonus XP when supporting higher-level allies
	if config.support_catch_up_rate > 0.0:
		var reference_level: int = supporter.stats.level
		if target != null and target.stats != null:
			# Use target's level as reference (healer supporting higher-level ally)
			reference_level = target.stats.level
		else:
			# Use party average for buffs/debuffs without specific target
			reference_level = int(_get_party_average_level())

		var level_gap: int = reference_level - supporter.stats.level
		if level_gap > 0:
			# Supporter is behind: bonus XP (+15% per level, capped at +100%)
			var catch_up_mult: float = 1.0 + clampf(level_gap * config.support_catch_up_rate, 0.0, 1.0)
			base_xp = int(base_xp * catch_up_mult)

	# Award XP
	if base_xp > 0:
		_give_xp_to_unit(supporter, base_xp, action_type)


# ============================================================================
# XP DISTRIBUTION
# ============================================================================

## Give XP to a unit and trigger level-up if threshold reached.
##
## @param unit: Unit to receive XP
## @param amount: Amount of XP to award
## @param source: Source of XP (for signal)
func _give_xp_to_unit(unit: Unit, amount: int, source: String) -> void:
	if unit == null or unit.stats == null:
		return

	if amount <= 0:
		return

	# Check if already max level
	if unit.stats.level >= config.max_level:
		return

	# Award XP
	unit.stats.gain_xp(amount)

	# Emit signal
	unit_gained_xp.emit(unit, amount, source)

	# Check for level-up (handled by UnitStats.gain_xp calling back to us)


## Trigger a level-up for a unit.
## Called by UnitStats when XP threshold is reached.
##
## @param unit: Unit to level up
func _trigger_level_up(unit: Unit) -> void:
	if unit == null or unit.stats == null:
		return

	apply_level_up(unit)


# ============================================================================
# LEVEL-UP SYSTEM
# ============================================================================

## Apply a level-up to a unit.
##
## Increases level, rolls for stat increases based on growth rates,
## checks for learned abilities, and emits signals.
##
## @param unit: Unit to level up
## @return: Dictionary of stat increases {stat_name: increase}
func apply_level_up(unit: Unit) -> Dictionary:
	if unit == null or unit.stats == null or unit.character_data == null:
		push_error("ExperienceManager: Invalid unit for level-up")
		return {}

	var old_level: int = unit.stats.level
	unit.stats.level += 1
	var new_level: int = unit.stats.level

	var stat_increases: Dictionary = {}
	var class_data: ClassData = unit.get_current_class()

	if class_data == null:
		push_error("ExperienceManager: Unit has no class data")
		return {}

	# Roll for each stat increase (Shining Force style)
	var stats_to_grow: Array[String] = ["hp", "mp", "strength", "defense", "agility", "intelligence", "luck"]

	for stat_name: String in stats_to_grow:
		var growth_rate: int = class_data.get_growth_rate(stat_name)
		var increase: int = _calculate_stat_increase(growth_rate)

		if increase > 0:
			stat_increases[stat_name] = increase

			# Apply the increase
			match stat_name:
				"hp":
					unit.stats.max_hp += increase
					unit.stats.current_hp += increase  # Heal on level-up
				"mp":
					unit.stats.max_mp += increase
					unit.stats.current_mp += increase  # Restore on level-up
				"strength":
					unit.stats.strength += increase
				"defense":
					unit.stats.defense += increase
				"agility":
					unit.stats.agility += increase
				"intelligence":
					unit.stats.intelligence += increase
				"luck":
					unit.stats.luck += increase

	# Check for ability learning (pass old_level to detect newly unlocked abilities)
	var learned_abilities: Array[AbilityData] = _check_learned_abilities(unit, old_level, new_level, class_data)
	if not learned_abilities.is_empty():
		stat_increases["abilities"] = learned_abilities

	# Emit signal
	unit_leveled_up.emit(unit, old_level, new_level, stat_increases)

	# Check if promotion is now available
	if PromotionManager:
		PromotionManager.check_promotion_eligibility(unit)

	return stat_increases


## Calculate stat increase based on growth rate.
##
## Shining Force style: growth_rate is percentage (0-100).
## Roll 0-99, if less than growth_rate, stat increases by 1.
##
## @param growth_rate: Percentage chance (0-100)
## @return: 1 if stat increases, 0 otherwise
func _calculate_stat_increase(growth_rate: int) -> int:
	var roll: int = randi() % 100
	return 1 if roll < growth_rate else 0


## Check if unit learns abilities at this level.
##
## @param unit: Unit that leveled up
## @param old_level: Previous level before level-up
## @param new_level: New level reached
## @param class_data: ClassData with learnable abilities
## @return: Array of learned AbilityData
func _check_learned_abilities(unit: Unit, old_level: int, new_level: int, class_data: ClassData) -> Array[AbilityData]:
	var learned: Array[AbilityData] = []

	# ==========================================================================
	# NEW SYSTEM: Check ability_unlock_levels (preferred)
	# Compare abilities unlocked at old_level vs new_level
	# ==========================================================================
	if class_data.class_abilities.size() > 0:
		var old_abilities: Array[AbilityData] = class_data.get_unlocked_class_abilities(old_level)
		var new_abilities: Array[AbilityData] = class_data.get_unlocked_class_abilities(new_level)

		# Find abilities that are in new but not in old
		for ability: AbilityData in new_abilities:
			if ability == null:
				continue

			var was_unlocked: bool = false
			for old_ability: AbilityData in old_abilities:
				if old_ability and old_ability.ability_id == ability.ability_id:
					was_unlocked = true
					break

			if not was_unlocked:
				# This is a newly unlocked ability!
				learned.append(ability)
				unit_learned_ability.emit(unit, ability)

	return learned


# ============================================================================
# HELPER METHODS
# ============================================================================

## Cached party average level for the current battle (invalidated on battle start).
var _cached_party_avg_level: float = -1.0


## Get the average level of all player faction units.
## Cached per battle for performance.
##
## @return: Average level of player units (minimum 1.0)
func _get_party_average_level() -> float:
	# Return cached value if available
	if _cached_party_avg_level > 0:
		return _cached_party_avg_level

	var total_level: int = 0
	var count: int = 0

	var all_units: Array = TurnManager.all_units
	for unit: Unit in all_units:
		if unit.faction == "player" and unit.stats != null and unit.stats.is_alive():
			total_level += unit.stats.level
			count += 1

	if count == 0:
		_cached_party_avg_level = 1.0
	else:
		_cached_party_avg_level = float(total_level) / float(count)

	return _cached_party_avg_level


## Invalidate the cached party average level.
## Call this at battle start or when party composition changes.
func invalidate_party_level_cache() -> void:
	_cached_party_avg_level = -1.0


## Get the base XP value for a level difference.
## Wrapper for config method for convenience.
##
## @param level_diff: Defender level - Attacker level
## @return: Base XP value
func get_base_xp_from_level_diff(level_diff: int) -> int:
	return config.get_base_xp_from_level_diff(level_diff)
