class_name MaterialSpawnData
extends Resource

## Defines a world pickup location for a rare material on a specific map.
## This handles the "sparkly spot on the ground" style of material acquisition.
## Other acquisition methods (chests, battle rewards, NPC gifts) are handled
## by their respective systems.
##
## Accessibility is determined by story flags and chapter limits.
## The material itself has no opinion on missability - the world determines accessibility.

@export var material_id: String = ""

@export_group("Location")
## Which map this spawn is on
@export var map_id: String = ""
## Tile coordinates on the map
@export var grid_position: Vector2i = Vector2i.ZERO
## Unique identifier for this spawn point (for save system)
@export var spawn_id: String = ""

@export_group("Availability")
## Story flags that must be set to access this spawn
@export var required_flags: Array[String] = []
## Story flags that block access (creates missability when set)
@export var forbidden_flags: Array[String] = []
## Earliest chapter this becomes available (0 = always)
@export var min_chapter: int = 0
## Latest chapter this remains available (-1 = no limit)
@export var max_chapter: int = -1

@export_group("Spawn Properties")
## How many of this material spawn here
@export var quantity: int = 1
## Does this spawn respawn after collection?
@export var respawns: bool = false
## Flag that triggers respawn (if respawns is true)
@export var respawn_flag: String = ""

@export_group("Presentation")
## Visual indicator type for map placement (e.g., "sparkle", "glow", "subtle")
@export var visual_hint: String = "sparkle"
## Custom interaction text (empty = default "You found [material]!")
@export var interaction_prompt: String = ""


## Check if spawn is currently accessible given game state
func is_accessible(flag_checker: Callable, current_chapter: int) -> bool:
	# Check chapter window
	if current_chapter < min_chapter:
		return false
	if max_chapter >= 0 and current_chapter > max_chapter:
		return false

	# Check required flags (ALL must be set)
	for flag: String in required_flags:
		if not flag_checker.call(flag):
			return false

	# Check forbidden flags (NONE can be set)
	for flag: String in forbidden_flags:
		if flag_checker.call(flag):
			return false

	return true


## Get the full trigger_id for save system integration
## Format: "material_spawn:{map_id}:{spawn_id}"
func get_trigger_id() -> String:
	return "material_spawn:%s:%s" % [map_id, spawn_id]


## Check if this spawn can currently respawn
func can_respawn(flag_checker: Callable) -> bool:
	if not respawns:
		return false
	if respawn_flag.is_empty():
		return true
	return flag_checker.call(respawn_flag)


## Validate spawn data
func validate() -> bool:
	if material_id.is_empty():
		push_error("MaterialSpawnData: material_id is required")
		return false
	if map_id.is_empty():
		push_error("MaterialSpawnData: map_id is required")
		return false
	if spawn_id.is_empty():
		push_error("MaterialSpawnData: spawn_id is required")
		return false
	if quantity < 1:
		push_error("MaterialSpawnData: quantity must be at least 1")
		return false
	if max_chapter >= 0 and max_chapter < min_chapter:
		push_error("MaterialSpawnData: max_chapter cannot be less than min_chapter")
		return false
	return true
