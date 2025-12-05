## CaravanData - Configuration resource for the mobile Caravan headquarters
##
## Defines the appearance, behavior, and available services of the Caravan.
## This is fully moddable - mods can create custom caravans with different
## sprites, follow distances, terrain restrictions, and services.
##
## SF2 Authenticity:
## - The Caravan follows the party on overworld maps
## - Provides party management, item storage, and rest services
## - Hidden in towns (handled by MapMetadata.caravan_visible)
## - No healing/saving inside (churches remain relevant)
##
## Usage:
##   # In mod's data/caravans/ directory, create a .tres file:
##   var caravan = CaravanData.new()
##   caravan.caravan_id = "base_game:default_caravan"
##   caravan.follow_distance_tiles = 3
class_name CaravanData
extends Resource

## Unique identifier for this caravan configuration (namespaced: "mod_id:caravan_id")
@export var caravan_id: String = ""

## Display name shown in UI (e.g., "Caravan Headquarters")
@export var display_name: String = "Caravan"

# =============================================================================
# Visual Appearance
# =============================================================================

@export_group("Appearance")

## Main wagon sprite (single frame or idle state)
@export var wagon_sprite: Texture2D

## Animated sprite frames for directional movement (optional)
## If null, uses wagon_sprite for all directions
@export var wagon_animation_frames: SpriteFrames

## Scale factor for the wagon sprite
@export var wagon_scale: Vector2 = Vector2.ONE

## Z-index offset for rendering order (higher = in front)
@export var z_index_offset: int = 0

# =============================================================================
# Following Behavior
# =============================================================================

@export_group("Following")

## How many tiles behind the last party member the caravan follows
## SF2 default is approximately 2-3 tiles
@export_range(1, 10, 1) var follow_distance_tiles: int = 3

## Movement speed in pixels per second for smooth animation
@export var follow_speed: float = 96.0

## Whether to use breadcrumb trail following (true) or direct pathfinding (false)
## SF2-authentic behavior uses breadcrumb trailing
@export var use_chain_following: bool = true

## Maximum tiles of movement history to maintain
## Should be >= follow_distance_tiles + max_party_size
@export var max_history_size: int = 20

# =============================================================================
# Terrain Restrictions
# =============================================================================

@export_group("Terrain")

## Can the caravan cross water tiles (ferries, bridges)?
## SF2's caravan could use certain water crossings
@export var can_cross_water: bool = true

## Terrain types the caravan cannot traverse
## Uses terrain_type strings from TerrainData
@export var blocked_terrain_types: Array[String] = ["mountain", "deep_water", "wall"]

## Can the caravan enter forest tiles?
@export var can_enter_forest: bool = false

# =============================================================================
# Services Available
# =============================================================================

@export_group("Services")

## Enable item storage (SF2's depot)
@export var has_item_storage: bool = true

## Enable party management (swap active/reserve members)
@export var has_party_management: bool = true

## Enable rest service (free heal all party members)
@export var has_rest_service: bool = true

## Enable shop service (buy/sell items - typically false for base game)
@export var has_shop_service: bool = false

## Enable promotion service (class promotion - typically at specific locations)
@export var has_promotion_service: bool = false

# =============================================================================
# Interior Scene (Future)
# =============================================================================

@export_group("Interior")

## Path to walkable interior scene (optional, for future expansion)
## If empty, caravan uses the standard menu interface
@export_file("*.tscn") var interior_scene_path: String = ""

## NPCs available inside the caravan (for interior scene)
## Key: npc_id, Value: Dictionary with position, dialogue_id, etc.
@export var interior_npcs: Dictionary = {}

# =============================================================================
# Audio
# =============================================================================

@export_group("Audio")

## Sound effect when opening caravan menu
@export var menu_open_sfx: String = ""

## Sound effect when closing caravan menu
@export var menu_close_sfx: String = ""

## Sound effect for heal/rest service
@export var heal_sfx: String = ""

## Ambient sound while caravan menu is open (optional)
@export var ambient_sfx: String = ""


# =============================================================================
# Methods
# =============================================================================

## Validate that required fields are set
func validate() -> bool:
	var is_valid: bool = true

	if caravan_id.is_empty():
		push_error("CaravanData: caravan_id is required")
		is_valid = false

	if display_name.is_empty():
		push_error("CaravanData: display_name is required")
		is_valid = false

	if follow_distance_tiles < 1:
		push_error("CaravanData: follow_distance_tiles must be at least 1")
		is_valid = false

	if follow_speed <= 0:
		push_error("CaravanData: follow_speed must be positive")
		is_valid = false

	return is_valid


## Check if a service is available
func has_service(service_name: String) -> bool:
	match service_name:
		"item_storage", "storage", "depot":
			return has_item_storage
		"party_management", "party":
			return has_party_management
		"rest", "heal":
			return has_rest_service
		"shop":
			return has_shop_service
		"promotion":
			return has_promotion_service
		_:
			return false


## Get list of available services
func get_available_services() -> Array[String]:
	var services: Array[String] = []

	if has_party_management:
		services.append("party_management")
	if has_item_storage:
		services.append("item_storage")
	if has_rest_service:
		services.append("rest")
	if has_shop_service:
		services.append("shop")
	if has_promotion_service:
		services.append("promotion")

	return services


## Check if the caravan can traverse a terrain type
func can_traverse_terrain(terrain_type: String) -> bool:
	if terrain_type in blocked_terrain_types:
		return false

	if terrain_type == "water" or terrain_type == "shallow_water":
		return can_cross_water

	if terrain_type == "forest":
		return can_enter_forest

	return true
