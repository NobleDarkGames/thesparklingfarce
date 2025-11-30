class_name RareMaterialData
extends Resource

## Represents a rare crafting material in the game.
## These are special items used in the crafting system, separate from regular inventory items.
## Materials define their identity and crafting properties - spawn locations are handled
## by MaterialSpawnData.

enum Rarity {
	COMMON,      ## Frequently found, basic crafting
	UNCOMMON,    ## Moderately rare, standard equipment upgrades
	RARE,        ## Difficult to find, powerful recipes
	EPIC,        ## Very rare, unique equipment
	LEGENDARY    ## Exceptionally rare, artifact-level crafting
}

@export var material_name: String = ""
@export var icon: Texture2D
@export var rarity: Rarity = Rarity.COMMON

@export_group("Crafting")
## Category for recipe matching (e.g., "ore", "gem", "hide", "essence")
@export var crafting_category: String = ""
## Flexible tags for recipe filters (e.g., "fire", "blessed", "dragon")
@export var tags: Array[String] = []

@export_group("Inventory")
## Maximum stack size (1 for unique materials)
@export var stack_limit: int = 99

@export_group("Description")
@export_multiline var description: String = ""
## Optional hint about where to find it
@export var lore_hint: String = ""


## Check if material has a specific tag
func has_tag(tag: String) -> bool:
	return tag in tags


## Check if material matches a crafting requirement
func matches_requirement(category: String, required_tags: Array[String] = []) -> bool:
	if crafting_category != category:
		return false
	for tag: String in required_tags:
		if not has_tag(tag):
			return false
	return true


## Get display color for rarity (for UI styling)
func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color.WHITE
		Rarity.UNCOMMON:
			return Color.GREEN
		Rarity.RARE:
			return Color.CORNFLOWER_BLUE
		Rarity.EPIC:
			return Color.MEDIUM_PURPLE
		Rarity.LEGENDARY:
			return Color.ORANGE
		_:
			return Color.WHITE


## Get rarity display name for UI
func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
		Rarity.LEGENDARY:
			return "Legendary"
		_:
			return "Unknown"


## Validate required fields
func validate() -> bool:
	if material_name.is_empty():
		push_error("RareMaterialData: material_name is required")
		return false
	if crafting_category.is_empty():
		push_error("RareMaterialData: crafting_category is required")
		return false
	if stack_limit < 1:
		push_error("RareMaterialData: stack_limit must be at least 1")
		return false
	return true
