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
signal unit_learned_ability(unit: Node2D, ability: Resource)

## Emitted when a unit is promoted to a new class.
## @param unit: The Unit that was promoted
## @param old_class: Previous ClassData
## @param new_class: New ClassData
signal unit_promoted(unit: Node2D, old_class: Resource, new_class: Resource)


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
		var loaded_config: Resource = ModLoader.registry.get_resource("experience_config", "default")
		if loaded_config is ExperienceConfig:
			config = loaded_config
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
func award_combat_xp(attacker: Node2D, defender: Node2D, damage_dealt: int, got_kill: bool) -> void:
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
	if config.enable_formation_xp and damage_dealt > 0:
		var nearby_allies: Array[Node2D] = _get_units_in_formation_radius(attacker)
		var ally_count: int = nearby_allies.size()

		if ally_count > 0:
			# Calculate TOTAL formation XP pool, capped at % of attacker's actual XP
			var base_total_formation: int = int(base_xp * config.formation_multiplier)
			var capped_total_formation: int = int(attacker_xp * config.formation_cap_ratio)
			var total_formation_xp: int = mini(base_total_formation, capped_total_formation)

			# Divide pool among allies (minimum 1 XP each if any pool exists)
			var per_ally_xp: int = maxi(1, total_formation_xp / ally_count)

			for ally in nearby_allies:
				_give_xp_to_unit(ally, per_ally_xp, "formation")


## Get all allied units within formation radius of a unit.
##
## @param center_unit: Unit to check from
## @return: Array of Units within formation range
func _get_units_in_formation_radius(center_unit: Node2D) -> Array[Node2D]:
	var nearby_allies: Array[Node2D] = []

	if not is_instance_valid(center_unit):
		return nearby_allies

	var center_pos: Vector2i = center_unit.grid_position
	var all_units: Array = TurnManager.all_units

	for unit: Node2D in all_units:
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
func award_support_xp(supporter: Node2D, action_type: String, target: Node2D, amount: int) -> void:
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
		var usage_count: int = supporter.stats.support_actions_this_battle.get(action_type, 0)
		var multiplier: float = config.get_anti_spam_multiplier(usage_count)
		base_xp = int(base_xp * multiplier)

		# Increment usage count
		supporter.stats.support_actions_this_battle[action_type] = usage_count + 1

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
func _give_xp_to_unit(unit: Node2D, amount: int, source: String) -> void:
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
func _trigger_level_up(unit: Node2D) -> void:
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
func apply_level_up(unit: Node2D) -> Dictionary:
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

	# Check for ability learning
	var learned_abilities: Array[Resource] = _check_learned_abilities(unit, new_level, class_data)
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
## @param new_level: New level reached
## @param class_data: ClassData with learnable abilities
## @return: Array of learned AbilityData
func _check_learned_abilities(unit: Node2D, new_level: int, class_data: ClassData) -> Array[Resource]:
	var learned: Array[Resource] = []

	# Check if class has learnable_abilities dictionary
	if "learnable_abilities" not in class_data:
		return learned

	var learnable_abilities_raw: Variant = class_data.learnable_abilities
	if learnable_abilities_raw == null or not learnable_abilities_raw is Dictionary:
		return learned

	var learnable_abilities: Dictionary = learnable_abilities_raw as Dictionary

	# Check if this level has abilities
	if new_level in learnable_abilities:
		var abilities: Variant = learnable_abilities[new_level]

		# Handle both single ability and array of abilities
		if abilities is Array:
			for ability: Resource in abilities:
				if unit.has_method("add_ability"):
					unit.add_ability(ability)
				learned.append(ability)
				unit_learned_ability.emit(unit, ability)
		else:
			# Single ability
			if unit.has_method("add_ability"):
				unit.add_ability(abilities)
			learned.append(abilities)
			unit_learned_ability.emit(unit, abilities)

	return learned


# ============================================================================
# HELPER METHODS
# ============================================================================

## Get the base XP value for a level difference.
## Wrapper for config method for convenience.
##
## @param level_diff: Defender level - Attacker level
## @return: Base XP value
func get_base_xp_from_level_diff(level_diff: int) -> int:
	return config.get_base_xp_from_level_diff(level_diff)
