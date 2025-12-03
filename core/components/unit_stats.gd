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

	# Apply equipment bonuses
	for item in character.starting_equipment:
		if item != null:
			apply_equipment_bonus(item)

	# Set current HP/MP to max
	current_hp = max_hp
	current_mp = max_mp


## Apply bonuses from equipped item
func apply_equipment_bonus(item: ItemData) -> void:
	if item == null:
		return

	# Apply stat modifiers
	max_hp += item.hp_modifier
	max_mp += item.mp_modifier
	strength += item.strength_modifier
	defense += item.defense_modifier
	agility += item.agility_modifier
	intelligence += item.intelligence_modifier
	luck += item.luck_modifier


## Remove bonuses from equipped item (when unequipping)
func remove_equipment_bonus(item: ItemData) -> void:
	if item == null:
		return

	# Remove stat modifiers
	max_hp -= item.hp_modifier
	max_mp -= item.mp_modifier
	strength -= item.strength_modifier
	defense -= item.defense_modifier
	agility -= item.agility_modifier
	intelligence -= item.intelligence_modifier
	luck -= item.luck_modifier

	# Clamp current HP/MP
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
		var item: ItemData = ModLoader.registry.get_resource("item", item_id) as ItemData
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


## Get weapon attack power (0 if no weapon equipped)
func get_weapon_attack_power() -> int:
	if cached_weapon:
		return cached_weapon.attack_power
	return 0


## Get weapon attack range (1 = melee if no weapon)
func get_weapon_range() -> int:
	if cached_weapon:
		return cached_weapon.attack_range
	return 1


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


## Get effective strength (base + equipment + buffs)
func get_effective_strength() -> int:
	var total: int = strength + equipment_strength_bonus

	# Add strength buffs
	for effect: Dictionary in status_effects:
		if effect.type == "attack_up":
			total += effect.power
		elif effect.type == "attack_down":
			total -= effect.power

	return maxi(0, total)


## Get effective defense (base + equipment + buffs)
func get_effective_defense() -> int:
	var total: int = defense + equipment_defense_bonus

	# Add defense buffs
	for effect: Dictionary in status_effects:
		if effect.type == "defense_up":
			total += effect.power
		elif effect.type == "defense_down":
			total -= effect.power

	return maxi(0, total)


## Get effective agility (base + equipment + buffs)
func get_effective_agility() -> int:
	var total: int = agility + equipment_agility_bonus

	# Add agility buffs
	for effect: Dictionary in status_effects:
		if effect.type == "speed_up":
			total += effect.power
		elif effect.type == "speed_down":
			total -= effect.power

	return maxi(0, total)


## Get effective intelligence (base + equipment + buffs)
func get_effective_intelligence() -> int:
	var total: int = intelligence + equipment_intelligence_bonus
	return maxi(0, total)


## Get effective luck (base + equipment)
func get_effective_luck() -> int:
	return maxi(0, luck + equipment_luck_bonus)


## Get effective max HP (base + equipment)
func get_effective_max_hp() -> int:
	return maxi(1, max_hp + equipment_hp_bonus)


## Get effective max MP (base + equipment)
func get_effective_max_mp() -> int:
	return maxi(0, max_mp + equipment_mp_bonus)


## Add a status effect
func add_status_effect(effect_type: String, duration: int, power: int = 0) -> void:
	# Check if effect already exists
	for effect in status_effects:
		if effect.type == effect_type:
			# Refresh duration and power
			effect.duration = maxi(effect.duration, duration)
			effect.power = maxi(effect.power, power)
			return

	# Add new effect
	status_effects.append({
		"type": effect_type,
		"duration": duration,
		"power": power
	})


## Remove a status effect by type
func remove_status_effect(effect_type: String) -> void:
	for i in range(status_effects.size() - 1, -1, -1):
		if status_effects[i].type == effect_type:
			status_effects.remove_at(i)


## Check if unit has a specific status effect
func has_status_effect(effect_type: String) -> bool:
	for effect in status_effects:
		if effect.type == effect_type:
			return true
	return false


## Process status effects at end of turn
## Returns true if unit is still alive
func process_status_effects() -> bool:
	for i in range(status_effects.size() - 1, -1, -1):
		var effect: Dictionary = status_effects[i]

		# Process effect
		match effect.type:
			"poison":
				# Take damage based on power
				var damage: int = maxi(1, effect.power)
				current_hp -= damage

			"regen":
				# Heal based on power
				var heal: int = maxi(1, effect.power)
				current_hp = mini(current_hp + heal, max_hp)

		# Decrement duration
		effect.duration -= 1

		# Remove if expired
		if effect.duration <= 0:
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
	current_hp = mini(current_hp + amount, max_hp)


## Spend MP for ability
## Returns true if sufficient MP
func spend_mp(cost: int) -> bool:
	if current_mp >= cost:
		current_mp -= cost
		return true
	return false


## Restore MP
func restore_mp(amount: int) -> void:
	current_mp = mini(current_mp + amount, max_mp)


## Check if unit is alive
func is_alive() -> bool:
	return current_hp > 0


## Check if unit is at full HP
func is_at_full_hp() -> bool:
	return current_hp == max_hp


## Check if unit is at full MP
func is_at_full_mp() -> bool:
	return current_mp == max_mp


## Get HP percentage (0.0 to 1.0)
func get_hp_percent() -> float:
	if max_hp == 0:
		return 0.0
	return float(current_hp) / float(max_hp)


## Get MP percentage (0.0 to 1.0)
func get_mp_percent() -> float:
	if max_mp == 0:
		return 0.0
	return float(current_mp) / float(max_mp)

## Get summary string for debugging
func get_stats_string() -> String:
	return "Lv%d HP:%d/%d MP:%d/%d STR:%d DEF:%d AGI:%d INT:%d LUK:%d" % [
		level, current_hp, max_hp, current_mp, max_mp,
		strength, defense, agility, intelligence, luck
	]


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
