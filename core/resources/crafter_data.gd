class_name CrafterData
extends Resource

## Represents a crafter NPC or crafting location in the game.
## Crafters have types and skill levels that determine which recipes they can perform.
## Examples: village blacksmith, master enchanter, ancient forge
##
## Note: This defines the crafter's capabilities. The actual NPC placement and
## dialogue are handled by the map/character systems.

@export var crafter_name: String = ""
## Type identifier matched against recipe requirements (e.g., "blacksmith", "enchanter")
@export var crafter_type: String = ""

@export_group("Capabilities")
## Crafting skill level (determines available recipes)
@export var skill_level: int = 1
## Crafting categories with expertise (e.g., "swords", "fire", "holy")
@export var specializations: Array[String] = []

@export_group("Location")
## Which map this crafter is on (for lookup/fast travel)
@export var location_map_id: String = ""
## Grid position on the map
@export var location_grid_position: Vector2i = Vector2i.ZERO

@export_group("NPC Link")
## Optional: linked CharacterData ID for portrait/dialogue
@export var character_id: String = ""

@export_group("Availability")
## Story flags required to access this crafter
@export var required_flags: Array[String] = []
## Story flags that block access to this crafter
@export var forbidden_flags: Array[String] = []

@export_group("Economy")
## Multiplier for gold costs (1.0 = normal, 0.8 = discount, 1.5 = premium)
@export var service_fee_modifier: float = 1.0

@export_group("Description")
@export_multiline var description: String = ""


## Check if crafter meets the requirements to perform a recipe
func can_craft_recipe(required_type: String, required_skill: int) -> bool:
	if crafter_type != required_type:
		return false
	if skill_level < required_skill:
		return false
	return true


## Check if crafter is currently available to the player
func is_available(flag_checker: Callable) -> bool:
	# Check required flags (ALL must be set)
	for flag: String in required_flags:
		if not flag_checker.call(flag):
			return false

	# Check forbidden flags (NONE can be set)
	for flag: String in forbidden_flags:
		if flag_checker.call(flag):
			return false

	return true


## Check if crafter has expertise in a category (for potential bonuses)
func has_specialization(category: String) -> bool:
	return category in specializations


## Calculate modified gold cost for a recipe
func get_modified_cost(base_cost: int) -> int:
	return int(base_cost * service_fee_modifier)


## Validate crafter data
func validate() -> bool:
	if crafter_name.is_empty():
		push_error("CrafterData: crafter_name is required")
		return false
	if crafter_type.is_empty():
		push_error("CrafterData: crafter_type is required")
		return false
	if skill_level < 1:
		push_error("CrafterData: skill_level must be at least 1")
		return false
	if service_fee_modifier <= 0.0:
		push_error("CrafterData: service_fee_modifier must be positive")
		return false
	return true
