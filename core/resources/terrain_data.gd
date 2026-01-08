class_name TerrainData
extends Resource

## Represents terrain type data for tactical battles.
## Defines movement costs, combat modifiers, and turn effects.
##
## IMPORTANT: This is ENGINE CODE (mechanics).
## Terrain definitions come from mods/ (content).

## Unique identifier for this terrain type (e.g., "forest", "lava")
@export var terrain_id: String = ""

## Display name shown in UI
@export var display_name: String = ""

## Icon for UI display (optional)
@export var icon: Texture2D = null

@export_group("Movement")
## Base movement cost for ground units (1 = normal, 2 = double cost)
@export_range(1, 99) var movement_cost_walking: int = 1
## Movement cost for floating units (typically less than walking)
@export_range(1, 99) var movement_cost_floating: int = 1
## Movement cost for flying units (always 1 unless completely impassable)
@export_range(1, 99) var movement_cost_flying: int = 1
## If true, ground units cannot enter at all
@export var impassable_walking: bool = false
## If true, floating units cannot enter
@export var impassable_floating: bool = false
## If true, flying units cannot enter (rare - anti-air zones, ceilings)
@export var impassable_flying: bool = false

@export_group("Combat Modifiers")
## Defense bonus when standing on this terrain (0-10)
@export_range(0, 10) var defense_bonus: int = 0
## Evasion bonus percentage (0-50%)
@export_range(0, 50) var evasion_bonus: int = 0

@export_group("Turn Effects")
## Damage dealt at start of turn (0 = none, positive = damage)
@export var damage_per_turn: int = 0
## Healing at start of turn (0 = none, positive = heal)
@export var healing_per_turn: int = 0



## Get movement cost for a specific movement type
## Flying units always cost 1 (unless impassable)
func get_movement_cost(movement_type: int) -> int:
	match movement_type:
		ClassData.MovementType.WALKING:
			if impassable_walking:
				return 99  # GridManager.MAX_TERRAIN_COST
			return movement_cost_walking
		ClassData.MovementType.FLOATING:
			if impassable_floating:
				return 99
			return movement_cost_floating
		ClassData.MovementType.FLYING:
			if impassable_flying:
				return 99
			return movement_cost_flying  # Flying always uses this (typically 1)
		ClassData.MovementType.SWIMMING:
			# Aquatic units use floating cost as reasonable default
			# Water terrain should define lower floating costs for swimmers
			if impassable_floating:
				return 99
			return movement_cost_floating
		ClassData.MovementType.CUSTOM:
			# Custom movement types fall back to walking cost
			# Mods should override terrain data for custom movement handling
			if impassable_walking:
				return 99
			return movement_cost_walking
		_:
			return movement_cost_walking  # Default to walking


## Check if passable for a movement type
func is_passable(movement_type: int) -> bool:
	match movement_type:
		ClassData.MovementType.WALKING:
			return not impassable_walking
		ClassData.MovementType.FLOATING:
			return not impassable_floating
		ClassData.MovementType.FLYING:
			return not impassable_flying
		ClassData.MovementType.SWIMMING:
			# Aquatic units use floating passability
			return not impassable_floating
		ClassData.MovementType.CUSTOM:
			# Custom movement types use walking passability by default
			return not impassable_walking
		_:
			return not impassable_walking


## Check if this terrain deals damage over time
func has_damage_effect() -> bool:
	return damage_per_turn > 0


## Check if this terrain has any combat modifiers
func has_combat_modifiers() -> bool:
	return defense_bonus > 0 or evasion_bonus > 0


## Validate resource
func validate() -> bool:
	if terrain_id.is_empty():
		push_error("TerrainData: terrain_id is required")
		return false
	if display_name.is_empty():
		push_warning("TerrainData: display_name is empty for terrain '%s'" % terrain_id)
	return true
