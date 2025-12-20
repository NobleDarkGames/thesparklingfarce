class_name AbilityData
extends Resource

## Represents an ability/skill/spell that can be used in battle.
## Contains targeting, damage/healing, status effects, and cost information.

enum AbilityType {
	ATTACK,      ## Deals damage
	HEAL,        ## Restores HP
	SUPPORT,     ## Buffs allies
	DEBUFF,      ## Weakens enemies
	SUMMON,      ## Summons units or effects (SF2's Peter, summoning spells)
	STATUS,      ## Applies status effects (Sleep, Freeze, Muddle - distinct from stat debuffs)
	COUNTER,     ## Reactive abilities triggered by enemy actions
	SPECIAL,     ## Unique effects that don't fit other categories
	CUSTOM       ## Mod-defined type (use custom_ability_type field)
}

enum TargetType {
	SINGLE_ENEMY,
	SINGLE_ALLY,
	SELF,
	ALL_ENEMIES,
	ALL_ALLIES,
	AREA
}

@export var ability_name: String = ""
## Unique identifier for this ability (used in ability_unlock_levels dictionary)
## Should be lowercase with underscores (e.g., "heal_1", "blaze_2")
@export var ability_id: String = ""
@export var ability_type: AbilityType = AbilityType.ATTACK
## Custom ability type ID (only used when ability_type == CUSTOM)
## Allows mods to define their own ability types beyond the core set
@export var custom_ability_type: String = ""
@export var target_type: TargetType = TargetType.SINGLE_ENEMY

@export_group("Range and Area")
## Minimum range (0 = self, 1 = adjacent, etc.)
@export var min_range: int = 1
## Maximum range
@export var max_range: int = 1
## Area of effect radius (0 = single target, 1+ = splash)
@export var area_of_effect: int = 0

@export_group("Cost")
@export var mp_cost: int = 0
@export var hp_cost: int = 0

@export_group("Potency")
## Base potency/effectiveness of the ability (damage for attacks, healing amount for heals)
@export var potency: int = 10
## Accuracy percentage
@export_range(0, 100) var accuracy: int = 100

@export_group("Effects")
## Status effects to apply (e.g., "poison", "paralysis", "attack_up")
@export var status_effects: Array[String] = []
## Chance to apply status effect (percentage)
@export_range(0, 100) var effect_chance: int = 100

@export_group("Animation and Audio")
@export var animation_name: String = ""
@export var sound_effect: AudioStream
@export var particle_effect: PackedScene

@export_group("Description")
@export_multiline var description: String = ""

@export_group("AI Configuration")
## Multiplier for AI threat calculations. Higher = AI considers this ability more threatening.
## Default 1.0. Set to 0.0 to make AI ignore this ability in threat calculations.
## Example: A powerful AoE heal might be 1.5, a weak single-target buff might be 0.5
@export var ai_threat_contribution: float = 1.0


## Check if ability can target enemies
func can_target_enemies() -> bool:
	return target_type in [TargetType.SINGLE_ENEMY, TargetType.ALL_ENEMIES, TargetType.AREA]


## Check if ability can target allies
func can_target_allies() -> bool:
	return target_type in [TargetType.SINGLE_ALLY, TargetType.ALL_ALLIES, TargetType.SELF, TargetType.AREA]


## Check if position is within range
func is_in_range(distance: int) -> bool:
	return distance >= min_range and distance <= max_range


## Check if ability applies status effects
func has_status_effects() -> bool:
	return status_effects.size() > 0


## Get formatted cost string for UI
func get_cost_string() -> String:
	var costs: Array[String] = []
	if mp_cost > 0:
		costs.append(str(mp_cost) + " MP")
	if hp_cost > 0:
		costs.append(str(hp_cost) + " HP")
	if costs.is_empty():
		return "No cost"
	return " / ".join(costs)


## Validate that required fields are set
func validate() -> bool:
	if ability_name.is_empty():
		push_error("AbilityData: ability_name is required")
		return false
	if max_range < min_range:
		push_error("AbilityData: max_range must be >= min_range")
		return false
	if mp_cost < 0 or hp_cost < 0:
		push_error("AbilityData: costs cannot be negative")
		return false
	return true
