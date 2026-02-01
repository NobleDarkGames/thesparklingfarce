## UnitStats - Runtime stat tracking for battle units
##
## Calculates and tracks current stats based on CharacterData, equipment,
## buffs, and debuffs. Handles stat modifications and status effects.
class_name UnitStats
extends RefCounted

## Current and maximum hit points
var current_hp: int = 10
var max_hp: int = 10

## Current and maximum magic points
var current_mp: int = 5
var max_mp: int = 5

## Combat stats
var strength: int = 5
var defense: int = 5
var agility: int = 5
var intelligence: int = 5
var luck: int = 5

## Current level
var level: int = 1

## Experience tracking
var current_xp: int = 0
var xp_to_next_level: int = 100

## Support action tracking (for anti-spam system)
## Dictionary: {action_type: usage_count}
## Example: {"heal": 3, "buff": 2}
## Reset at end of each battle
var support_actions_this_battle: Dictionary = {}

## Unit tags for combat bonuses - copied from CharacterData, modifiable by effects
var unit_tags: Array[String] = []

## Status effects: Array[Dictionary]
## Each effect: {type: String, duration: int, power: int}
## Types: "poison", "sleep", "stun", "attack_up", "defense_up", etc.
var status_effects: Array[Dictionary] = []

## Reference to source CharacterData
var character_data: CharacterData = null

## Reference to source ClassData
var class_data: ClassData = null

## Reference to owner Unit (needed for level-up callbacks)
var owner_unit: Node2D = null

# =============================================================================
# EQUIPMENT CACHE
# =============================================================================

## Cached equipped weapon (for combat calculations)
var cached_weapon: ItemData = null

## Cached equipment by slot (for stat bonuses)
## Format: {slot_id: ItemData}
var cached_equipment: Dictionary = {}

## Equipment stat bonuses (cached for performance)
var equipment_hp_bonus: int = 0
var equipment_mp_bonus: int = 0
var equipment_strength_bonus: int = 0
var equipment_defense_bonus: int = 0
var equipment_agility_bonus: int = 0
var equipment_intelligence_bonus: int = 0
var equipment_luck_bonus: int = 0


## Calculate stats from CharacterData and equipment
func calculate_from_character(character: CharacterData) -> void:
	if character == null:
		push_error("UnitStats: Cannot calculate from null CharacterData")
		return

	character_data = character
	class_data = character.character_class

	if class_data == null:
		push_error("UnitStats: CharacterData has null class")
		return

	# Copy unit tags from character template (can be modified by status effects mid-battle)
	unit_tags = character.unit_tags.duplicate()

	# Set level
	level = character.starting_level

	# Calculate base stats
	max_hp = character.base_hp
	max_mp = character.base_mp
	strength = character.base_strength
	defense = character.base_defense
	agility = character.base_agility
	intelligence = character.base_intelligence
	luck = character.base_luck

	# Apply stat growth for starting levels above 1
	# Simulates leveling up from 1 to starting_level with random growth rolls
	if level > 1 and class_data != null:
		_apply_starting_level_growth(class_data, level)

	# Apply equipment bonuses and cache weapon
	for item: ItemData in character.starting_equipment:
		if item != null:
			apply_equipment_bonus(item)
			# Cache weapon for combat calculations (attack power, range, hit rate, crit rate)
			if item.item_type == ItemData.ItemType.WEAPON:
				cached_weapon = item

	# Set current HP/MP to max
	current_hp = max_hp
	current_mp = max_mp

	# Initialize XP threshold from config (allows mods to customize progression)
	if ExperienceManager.config:
		xp_to_next_level = ExperienceManager.config.xp_per_level


## Apply or remove equipment stat modifiers
## multiplier: 1 to apply, -1 to remove
func _modify_stats_from_item(item: ItemData, multiplier: int) -> void:
	if item == null:
		return
	max_hp += item.hp_modifier * multiplier
	max_mp += item.mp_modifier * multiplier
	strength += item.strength_modifier * multiplier
	defense += item.defense_modifier * multiplier
	agility += item.agility_modifier * multiplier
	intelligence += item.intelligence_modifier * multiplier
	luck += item.luck_modifier * multiplier


## Apply bonuses from equipped item
func apply_equipment_bonus(item: ItemData) -> void:
	_modify_stats_from_item(item, 1)


## Remove bonuses from equipped item (when unequipping)
func remove_equipment_bonus(item: ItemData) -> void:
	_modify_stats_from_item(item, -1)
	# Clamp current HP/MP after removal
	current_hp = mini(current_hp, max_hp)
	current_mp = mini(current_mp, max_mp)


## Load and cache equipment from CharacterSaveData
## Called when initializing a Unit from saved state or when equipment changes
func load_equipment_from_save(save_data: CharacterSaveData) -> void:
	# Clear existing cache
	cached_weapon = null
	cached_equipment.clear()
	equipment_hp_bonus = 0
	equipment_mp_bonus = 0
	equipment_strength_bonus = 0
	equipment_defense_bonus = 0
	equipment_agility_bonus = 0
	equipment_intelligence_bonus = 0
	equipment_luck_bonus = 0

	# Load each equipped item
	for entry: Dictionary in save_data.equipped_items:
		var slot_id: String = entry.get("slot", "")
		var item_id: String = entry.get("item_id", "")

		if slot_id.is_empty() or item_id.is_empty():
			continue

		# Get item from registry
		var item: ItemData = ModLoader.registry.get_item(item_id)
		if not item:
			push_warning("UnitStats: Failed to load item '%s' for slot '%s'" % [item_id, slot_id])
			continue

		# Cache by slot
		cached_equipment[slot_id] = item

		# Special handling for weapon (slot_id "weapon" or ItemType.WEAPON)
		if slot_id == "weapon" or item.item_type == ItemData.ItemType.WEAPON:
			cached_weapon = item

		# Accumulate stat bonuses
		equipment_hp_bonus += item.hp_modifier
		equipment_mp_bonus += item.mp_modifier
		equipment_strength_bonus += item.strength_modifier
		equipment_defense_bonus += item.defense_modifier
		equipment_agility_bonus += item.agility_modifier
		equipment_intelligence_bonus += item.intelligence_modifier
		equipment_luck_bonus += item.luck_modifier


## Load stats from CharacterSaveData (preserves persistent state)
func load_from_save_data(save_data: CharacterSaveData, p_character_data: CharacterData) -> void:
	# Load base stats from save data
	level = save_data.level
	current_xp = save_data.current_xp
	max_hp = save_data.max_hp
	current_hp = save_data.current_hp
	max_mp = save_data.max_mp
	current_mp = save_data.current_mp
	strength = save_data.strength
	defense = save_data.defense
	agility = save_data.agility
	intelligence = save_data.intelligence
	luck = save_data.luck

	# Store character and class references
	character_data = p_character_data
	class_data = save_data.get_current_class(p_character_data)

	# Copy unit tags from character template (can be modified by status effects mid-battle)
	if p_character_data:
		unit_tags = p_character_data.unit_tags.duplicate()

	# Load equipment from save data
	load_equipment_from_save(save_data)


## Get weapon attack power (0 if no weapon equipped)
func get_weapon_attack_power() -> int:
	if cached_weapon:
		return cached_weapon.attack_power
	return 0


## Get weapon attack range (1 = melee if no weapon)
## DEPRECATED: Use get_weapon_max_range() for new code
## Kept for backwards compatibility - returns max_attack_range
func get_weapon_range() -> int:
	if cached_weapon:
		return cached_weapon.max_attack_range
	return 1


## Get weapon minimum attack range (1 = melee, 2+ = ranged with dead zone)
func get_weapon_min_range() -> int:
	if cached_weapon:
		return cached_weapon.min_attack_range
	return 1


## Get weapon maximum attack range
func get_weapon_max_range() -> int:
	if cached_weapon:
		return cached_weapon.max_attack_range
	return 1


## Check if unit can attack at the given distance
## Takes into account both minimum and maximum attack range
## Example: Bow (min=2, max=3) returns false for distance=1 (dead zone)
func can_attack_at_distance(distance: int) -> bool:
	if cached_weapon:
		return cached_weapon.is_distance_in_range(distance)
	# No weapon = unarmed melee, can only attack at distance 1
	return distance == 1


## Get weapon hit rate bonus (90 default if no weapon)
func get_weapon_hit_rate() -> int:
	if cached_weapon:
		return cached_weapon.hit_rate
	return 90


## Get weapon critical rate bonus (5 default if no weapon)
func get_weapon_crit_rate() -> int:
	if cached_weapon:
		return cached_weapon.critical_rate
	return 5


## Helper to sum stat modifiers from all active status effects (data-driven)
func _get_status_stat_modifier(stat_name: String) -> int:
	var total: int = 0
	for effect_variant: Variant in status_effects:
		if not effect_variant is Dictionary:
			continue
		var effect: Dictionary = effect_variant
		var effect_type: String = effect.get("type", "")
		var effect_data: StatusEffectData = ModLoader.status_effect_registry.get_effect(effect_type)
		if effect_data:
			total += effect_data.get_stat_modifier(stat_name)
	return total


## Calculate effective stat value (base + equipment + status effects)
func _get_effective_stat(base: int, equipment_bonus: int, stat_name: String, min_value: int = 0) -> int:
	var total: int = base + equipment_bonus + _get_status_stat_modifier(stat_name)
	return maxi(min_value, total)


## Get effective strength (base + equipment + buffs)
func get_effective_strength() -> int:
	return _get_effective_stat(strength, equipment_strength_bonus, "strength")


## Get effective defense (base + equipment + buffs)
func get_effective_defense() -> int:
	return _get_effective_stat(defense, equipment_defense_bonus, "defense")


## Get effective agility (base + equipment + buffs)
func get_effective_agility() -> int:
	return _get_effective_stat(agility, equipment_agility_bonus, "agility")


## Get effective intelligence (base + equipment + buffs)
func get_effective_intelligence() -> int:
	return _get_effective_stat(intelligence, equipment_intelligence_bonus, "intelligence")


## Get effective luck (base + equipment + buffs)
func get_effective_luck() -> int:
	return _get_effective_stat(luck, equipment_luck_bonus, "luck")


## Get effective max HP (base + equipment + buffs)
func get_effective_max_hp() -> int:
	return _get_effective_stat(max_hp, equipment_hp_bonus, "max_hp", 1)


## Get effective max MP (base + equipment + buffs)
func get_effective_max_mp() -> int:
	return _get_effective_stat(max_mp, equipment_mp_bonus, "max_mp")


## Find status effect by type, returns null if not found
func _find_status_effect(effect_type: String) -> Dictionary:
	for effect_variant: Variant in status_effects:
		if not effect_variant is Dictionary:
			continue
		var effect: Dictionary = effect_variant
		if effect.get("type", "") == effect_type:
			return effect
	return {}


## Add a status effect
func add_status_effect(effect_type: String, duration: int, potency: int = 0) -> void:
	var existing: Dictionary = _find_status_effect(effect_type)
	if not existing.is_empty():
		# Refresh duration and potency to higher values
		existing["duration"] = maxi(existing.get("duration", 0), duration)
		existing["potency"] = maxi(existing.get("potency", 0), potency)
		return

	status_effects.append({
		"type": effect_type,
		"duration": duration,
		"potency": potency
	})


## Remove a status effect by type
func remove_status_effect(effect_type: String) -> void:
	for i: int in range(status_effects.size() - 1, -1, -1):
		if status_effects[i].get("type", "") == effect_type:
			status_effects.remove_at(i)


## Check if unit has a specific status effect
func has_status_effect(effect_type: String) -> bool:
	return not _find_status_effect(effect_type).is_empty()


## Process status effects at end of turn
## Returns true if unit is still alive
func process_status_effects() -> bool:
	for i: int in range(status_effects.size() - 1, -1, -1):
		var effect: Dictionary = status_effects[i]
		var effect_type: String = effect.get("type", "")
		var effect_potency: int = effect.get("potency", 0)
		var effect_duration: int = effect.get("duration", 0)

		# Process effect
		match effect_type:
			"poison":
				# Take damage based on power
				var damage: int = maxi(1, effect_potency)
				current_hp -= damage

			"regen":
				# Heal based on power
				var heal: int = maxi(1, effect_potency)
				current_hp = mini(current_hp + heal, get_effective_max_hp())

		# Decrement duration
		effect_duration -= 1
		effect["duration"] = effect_duration

		# Remove if expired
		if effect_duration <= 0:
			status_effects.remove_at(i)

	# Check if still alive
	return current_hp > 0


## Take damage
## Returns true if unit died from damage
func take_damage(damage: int) -> bool:
	current_hp -= damage
	current_hp = maxi(current_hp, 0)
	return current_hp == 0


## Heal HP
func heal(amount: int) -> void:
	current_hp = mini(current_hp + amount, get_effective_max_hp())


## Spend MP for ability
## Returns true if sufficient MP
func spend_mp(cost: int) -> bool:
	if current_mp >= cost:
		current_mp -= cost
		return true
	return false


## Restore MP
func restore_mp(amount: int) -> void:
	current_mp = mini(current_mp + amount, get_effective_max_mp())


## Check if unit is alive
func is_alive() -> bool:
	return current_hp > 0


## Check if unit is at full HP
func is_at_full_hp() -> bool:
	return current_hp >= get_effective_max_hp()


## Check if unit is at full MP
func is_at_full_mp() -> bool:
	return current_mp >= get_effective_max_mp()


## Get HP percentage (0.0 to 1.0)
func get_hp_percent() -> float:
	var effective_max: int = get_effective_max_hp()
	if effective_max == 0:
		return 0.0
	return float(current_hp) / float(effective_max)


## Get MP percentage (0.0 to 1.0)
func get_mp_percent() -> float:
	var effective_max: int = get_effective_max_mp()
	if effective_max == 0:
		return 0.0
	return float(current_mp) / float(effective_max)

## Get summary string for debugging
func get_stats_string() -> String:
	return "Lv%d HP:%d/%d MP:%d/%d STR:%d DEF:%d AGI:%d INT:%d LUK:%d" % [
		level, current_hp, max_hp, current_mp, max_mp,
		strength, defense, agility, intelligence, luck
	]


# ============================================================================
# STARTING LEVEL STAT GROWTH
# ============================================================================

## Apply stat growth for characters starting above level 1.
## Simulates leveling up from level 1 to target_level with random growth rolls.
## Uses the same enhanced growth system as in-game level-ups.
##
## @param p_class_data: ClassData containing growth rates
## @param target_level: The starting level to grow stats to
func _apply_starting_level_growth(p_class_data: ClassData, target_level: int) -> void:
	if p_class_data == null or target_level <= 1:
		return

	# Simulate each level-up from 2 to target_level
	var levels_to_simulate: int = target_level - 1

	for _i: int in range(levels_to_simulate):
		# Roll for each stat using enhanced growth rates
		max_hp += _calculate_growth(p_class_data.hp_growth)
		max_mp += _calculate_growth(p_class_data.mp_growth)
		strength += _calculate_growth(p_class_data.strength_growth)
		defense += _calculate_growth(p_class_data.defense_growth)
		agility += _calculate_growth(p_class_data.agility_growth)
		intelligence += _calculate_growth(p_class_data.intelligence_growth)
		luck += _calculate_growth(p_class_data.luck_growth)


## Calculate stat increase based on growth rate.
##
## Enhanced Shining Force-style system:
##   0-99:  Percentage chance of +1 (e.g., 50 = 50% chance of +1)
##   100+:  Guaranteed floor + remainder% chance of +1 more
##          (e.g., 150 = +1 guaranteed, 50% chance of +2)
##
## A 5% "lucky roll" can grant +1 extra for rates >= 50,
## creating the memorable "great level-up!" moments SF fans love.
##
## @param growth_rate: Growth rate (0-200+, typically 30-150)
## @return: Stat increase (0, 1, 2, or rarely 3+)
func _calculate_growth(growth_rate: int) -> int:
	# Base calculation: guaranteed gains from rate / 100
	var guaranteed: int = growth_rate / 100
	var remainder: int = growth_rate % 100

	# Roll for the remainder portion
	var bonus: int = 1 if (randi() % 100) < remainder else 0
	var result: int = guaranteed + bonus

	# Lucky roll: 5% chance of +1 extra for growth rates >= 50
	# Creates the "amazing level!" moments players remember
	if growth_rate >= 50 and (randi() % 100) < 5:
		result += 1

	return result


# ============================================================================
# EXPERIENCE & LEVELING METHODS
# ============================================================================

## Gain experience points.
## Automatically triggers level-up if threshold is reached.
##
## @param amount: Amount of XP to gain
func gain_xp(amount: int) -> void:
	# Check if already max level
	if ExperienceManager.config and level >= ExperienceManager.config.max_level:
		return

	current_xp += amount

	# Check for level-up (can happen multiple times if enough XP)
	var max_level: int = ExperienceManager.config.max_level if ExperienceManager.config else 20
	while current_xp >= xp_to_next_level and level < max_level:
		var overflow: int = current_xp - xp_to_next_level
		current_xp = overflow

		# Trigger level-up via ExperienceManager if we have owner reference
		if owner_unit != null and is_instance_valid(owner_unit):
			ExperienceManager._trigger_level_up(owner_unit)
		else:
			# Fallback: just increment level without stat growth
			level += 1


## Check if unit can level up.
##
## @return: True if XP threshold reached and not at max level
func can_level_up() -> bool:
	var max_level: int = ExperienceManager.config.max_level if ExperienceManager.config else 20
	return current_xp >= xp_to_next_level and level < max_level


## Get XP progress to next level (0.0 to 1.0).
## Useful for progress bars in UI.
##
## @return: Progress ratio (0.0 = no progress, 1.0 = ready to level)
func get_xp_progress() -> float:
	if xp_to_next_level == 0:
		return 0.0
	return float(current_xp) / float(xp_to_next_level)


## Reset battle-specific tracking.
## Called at end of battle to clear support action counts.
func reset_battle_tracking() -> void:
	support_actions_this_battle.clear()
