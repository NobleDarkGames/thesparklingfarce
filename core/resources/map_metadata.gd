## MapMetadata - Configuration resource for exploration maps
##
## Defines the type, behavior, and connections of a map scene following
## the SF2 open world model. Each map declares its type (Town, Overworld,
## Dungeon, etc.) which controls Caravan visibility, camera zoom, and
## other type-specific behaviors.
##
## Usage:
##   # Create in editor or code:
##   var metadata = MapMetadata.new()
##   metadata.map_id = "base_game:granseal"
##   metadata.map_type = MapMetadata.MapType.TOWN
##   metadata.camera_zoom = 1.0
##
##   # Register spawn points:
##   metadata.add_spawn_point("entrance", Vector2i(10, 15), "up")
##   metadata.add_spawn_point("from_castle", Vector2i(5, 5), "down", false, true)
##
##   # Define connections to other maps:
##   metadata.add_connection("north_gate", "base_game:overworld_south", "town_entrance")
class_name MapMetadata
extends Resource

## Map types following SF2's categorical model
## Each type has different default behaviors for Caravan, camera, encounters
enum MapType {
	TOWN,       ## Detailed interior/building tilesets, no Caravan visible, 1:1 scale
	OVERWORLD,  ## Terrain-focused, Caravan visible and accessible, zoomed out
	DUNGEON,    ## Mix of styles, battle triggers common, Caravan optional
	BATTLE,     ## Tactical grid combat (loaded separately from exploration)
	INTERIOR    ## Sub-locations within towns (shops, houses, churches)
}

## Unique identifier for this map (namespaced: "mod_id:map_id")
@export var map_id: String = ""

## Display name for UI, save files, and debug
@export var display_name: String = ""

## Type classification - controls default behaviors
@export var map_type: MapType = MapType.TOWN

## Can the Caravan be accessed (interacted with) on this map?
## Only relevant for OVERWORLD and DUNGEON types
@export var caravan_accessible: bool = false

## Should the Caravan sprite be visible on this map?
## Typically true only for OVERWORLD maps
@export var caravan_visible: bool = false

## Camera zoom level (1.0 = default, <1.0 = zoomed out for overworld feel)
## Recommended: TOWN=1.0, OVERWORLD=0.75-0.85, DUNGEON=0.9-1.0
@export_range(0.5, 2.0, 0.05) var camera_zoom: float = 1.0

## Scene path for this map (res://mods/mod_id/maps/scene.tscn)
@export_file("*.tscn") var scene_path: String = ""

## Spawn points defined in this map
## Key: spawn_id (String)
## Value: Dictionary with "grid_position" (Vector2i), "facing" (String),
##        "is_default" (bool), "is_caravan_spawn" (bool)
@export var spawn_points: Dictionary = {}

## Connections to other maps (for door triggers and edge transitions)
## Each entry: {
##   "trigger_id": String,        # ID of the MapTrigger that activates this connection
##   "target_map_id": String,     # MapMetadata.map_id of destination
##   "target_spawn_id": String,   # Spawn point ID in destination map
##   "transition_type": String,   # "fade", "instant", "scroll" (default: "fade")
##   "requires_key": String,      # Item ID if door is locked (optional)
##   "one_way": bool              # If true, cannot return through this connection
## }
@export var connections: Array[Dictionary] = []

## Edge connections for seamless overworld navigation
## Key: "north", "south", "east", "west"
## Value: Dictionary with "target_map_id", "target_spawn_id", "overlap_tiles"
@export var edge_connections: Dictionary = {}

## Background music track ID (looked up in audio registry)
@export var music_id: String = ""

## Ambient sound ID (looked up in audio registry)
@export var ambient_id: String = ""

## Whether random encounters can occur on this map
@export var random_encounters_enabled: bool = false

## Base encounter rate for random battles (0.0 - 1.0)
## Only used if random_encounters_enabled is true
@export_range(0.0, 1.0, 0.01) var base_encounter_rate: float = 0.0

## Whether the player can save anywhere on this map
@export var save_anywhere: bool = true


# =============================================================================
# Spawn Point Management
# =============================================================================

## Add a spawn point to this map
## @param spawn_id: Unique identifier within this map
## @param grid_position: Tile coordinates where player spawns
## @param facing: Direction player faces ("up", "down", "left", "right")
## @param is_default: If true, this is the fallback spawn point
## @param is_caravan_spawn: If true, Caravan spawns here on this map
func add_spawn_point(
	spawn_id: String,
	grid_position: Vector2i,
	facing: String = "down",
	is_default: bool = false,
	is_caravan_spawn: bool = false
) -> void:
	spawn_points[spawn_id] = {
		"grid_position": grid_position,
		"facing": facing,
		"is_default": is_default,
		"is_caravan_spawn": is_caravan_spawn
	}


## Get spawn point data by ID
## Returns null if spawn point doesn't exist
func get_spawn_point(spawn_id: String) -> Dictionary:
	if spawn_id in spawn_points:
		return spawn_points[spawn_id]
	return {}


## Get the default spawn point for this map
## Returns empty Dictionary if no default is defined
func get_default_spawn_point() -> Dictionary:
	for spawn_id: String in spawn_points.keys():
		var data: Dictionary = spawn_points[spawn_id]
		if data.get("is_default", false):
			data["spawn_id"] = spawn_id
			return data

	# Fallback: return first spawn point if no default
	if not spawn_points.is_empty():
		var first_id: String = spawn_points.keys()[0]
		var data: Dictionary = spawn_points[first_id].duplicate()
		data["spawn_id"] = first_id
		return data

	return {}


## Get the caravan spawn point for this map
## Returns empty Dictionary if no caravan spawn is defined
func get_caravan_spawn_point() -> Dictionary:
	for spawn_id: String in spawn_points.keys():
		var data: Dictionary = spawn_points[spawn_id]
		if data.get("is_caravan_spawn", false):
			data["spawn_id"] = spawn_id
			return data
	return {}


# =============================================================================
# Connection Management
# =============================================================================

## Add a connection to another map
## @param trigger_id: ID of the MapTrigger that activates this connection
## @param target_map_id: MapMetadata.map_id of the destination map
## @param target_spawn_id: Spawn point ID in the destination map
## @param transition_type: Visual transition style ("fade", "instant", "scroll")
## @param requires_key: Item ID if door requires a key (empty = unlocked)
## @param one_way: If true, player cannot return through this connection
func add_connection(
	trigger_id: String,
	target_map_id: String,
	target_spawn_id: String,
	transition_type: String = "fade",
	requires_key: String = "",
	one_way: bool = false
) -> void:
	connections.append({
		"trigger_id": trigger_id,
		"target_map_id": target_map_id,
		"target_spawn_id": target_spawn_id,
		"transition_type": transition_type,
		"requires_key": requires_key,
		"one_way": one_way
	})


## Get connection data for a specific trigger
## Returns empty Dictionary if no connection exists for this trigger
func get_connection_for_trigger(trigger_id: String) -> Dictionary:
	for connection: Dictionary in connections:
		if connection.get("trigger_id", "") == trigger_id:
			return connection
	return {}


## Add an edge connection for seamless overworld transitions
## @param edge: Direction ("north", "south", "east", "west")
## @param target_map_id: MapMetadata.map_id of adjacent map
## @param target_spawn_id: Spawn point ID where player appears
## @param overlap_tiles: Number of tiles that overlap (SF2 uses 1)
func add_edge_connection(
	edge: String,
	target_map_id: String,
	target_spawn_id: String,
	overlap_tiles: int = 1
) -> void:
	edge_connections[edge] = {
		"target_map_id": target_map_id,
		"target_spawn_id": target_spawn_id,
		"overlap_tiles": overlap_tiles
	}


## Get edge connection for a direction
## Returns empty Dictionary if no edge connection exists
func get_edge_connection(edge: String) -> Dictionary:
	if edge in edge_connections:
		return edge_connections[edge]
	return {}


# =============================================================================
# Type-Based Defaults
# =============================================================================

## Apply default settings based on map type
## Call this after setting map_type to apply recommended defaults
func apply_type_defaults() -> void:
	match map_type:
		MapType.TOWN:
			caravan_visible = false
			caravan_accessible = false
			camera_zoom = 1.0
			random_encounters_enabled = false
			save_anywhere = true

		MapType.OVERWORLD:
			caravan_visible = true
			caravan_accessible = true
			camera_zoom = 0.8
			random_encounters_enabled = true
			base_encounter_rate = 0.1
			save_anywhere = true

		MapType.DUNGEON:
			caravan_visible = false
			caravan_accessible = false
			camera_zoom = 0.95
			random_encounters_enabled = true
			base_encounter_rate = 0.15
			save_anywhere = false  # Dungeons often restrict saving

		MapType.INTERIOR:
			caravan_visible = false
			caravan_accessible = false
			camera_zoom = 1.0
			random_encounters_enabled = false
			save_anywhere = true

		MapType.BATTLE:
			caravan_visible = false
			caravan_accessible = false
			camera_zoom = 1.0
			random_encounters_enabled = false
			save_anywhere = false


# =============================================================================
# Validation
# =============================================================================

## Validate the map metadata configuration
## Returns array of error strings (empty if valid)
func validate() -> Array[String]:
	var errors: Array[String] = []

	if map_id.is_empty():
		errors.append("map_id is required")

	if display_name.is_empty():
		errors.append("display_name is required")

	if scene_path.is_empty():
		errors.append("scene_path is required")
	elif not scene_path.ends_with(".tscn"):
		errors.append("scene_path must be a .tscn file")

	if spawn_points.is_empty():
		errors.append("At least one spawn point is required")

	# Validate spawn point data
	for spawn_id: String in spawn_points.keys():
		var data: Dictionary = spawn_points[spawn_id]
		if "grid_position" not in data:
			errors.append("Spawn point '%s' missing grid_position" % spawn_id)
		if "facing" not in data:
			errors.append("Spawn point '%s' missing facing direction" % spawn_id)
		elif data["facing"] not in ["up", "down", "left", "right"]:
			errors.append("Spawn point '%s' has invalid facing: %s" % [spawn_id, data["facing"]])

	# Validate connections reference valid spawn points in target maps
	# (Can't fully validate without loading target maps, so just check format)
	for connection: Dictionary in connections:
		if "trigger_id" not in connection:
			errors.append("Connection missing trigger_id")
		if "target_map_id" not in connection:
			errors.append("Connection missing target_map_id")
		if "target_spawn_id" not in connection:
			errors.append("Connection missing target_spawn_id")

	# Validate Caravan settings match map type
	if map_type == MapType.TOWN and caravan_visible:
		errors.append("TOWN maps should not have caravan_visible=true")

	if caravan_visible and not caravan_accessible:
		errors.append("caravan_visible requires caravan_accessible to be useful")

	return errors


## Check if metadata is valid
func is_valid() -> bool:
	return validate().is_empty()


# =============================================================================
# Serialization
# =============================================================================

## Export to dictionary (for JSON save/load)
func to_dict() -> Dictionary:
	return {
		"map_id": map_id,
		"display_name": display_name,
		"map_type": MapType.keys()[map_type],
		"caravan_accessible": caravan_accessible,
		"caravan_visible": caravan_visible,
		"camera_zoom": camera_zoom,
		"scene_path": scene_path,
		"spawn_points": spawn_points.duplicate(true),
		"connections": connections.duplicate(true),
		"edge_connections": edge_connections.duplicate(true),
		"music_id": music_id,
		"ambient_id": ambient_id,
		"random_encounters_enabled": random_encounters_enabled,
		"base_encounter_rate": base_encounter_rate,
		"save_anywhere": save_anywhere
	}


## Import from dictionary (for JSON loading)
## Note: Returns Resource (actually MapMetadata) - use type casting if needed
static func from_dict(data: Dictionary) -> Resource:
	var script: GDScript = load("res://core/resources/map_metadata.gd")
	var metadata: Resource = script.new()

	metadata.map_id = data.get("map_id", "")
	metadata.display_name = data.get("display_name", "")

	# Parse map type from string
	var type_str: String = data.get("map_type", "TOWN")
	match type_str.to_upper():
		"TOWN":
			metadata.map_type = MapType.TOWN
		"OVERWORLD":
			metadata.map_type = MapType.OVERWORLD
		"DUNGEON":
			metadata.map_type = MapType.DUNGEON
		"BATTLE":
			metadata.map_type = MapType.BATTLE
		"INTERIOR":
			metadata.map_type = MapType.INTERIOR
		_:
			metadata.map_type = MapType.TOWN

	metadata.caravan_accessible = data.get("caravan_accessible", false)
	metadata.caravan_visible = data.get("caravan_visible", false)
	metadata.camera_zoom = data.get("camera_zoom", 1.0)
	metadata.scene_path = data.get("scene_path", "")
	metadata.spawn_points = data.get("spawn_points", {})
	metadata.connections.assign(data.get("connections", []))
	metadata.edge_connections = data.get("edge_connections", {})
	metadata.music_id = data.get("music_id", "")
	metadata.ambient_id = data.get("ambient_id", "")
	metadata.random_encounters_enabled = data.get("random_encounters_enabled", false)
	metadata.base_encounter_rate = data.get("base_encounter_rate", 0.0)
	metadata.save_anywhere = data.get("save_anywhere", true)

	return metadata


## Get human-readable map type name
func get_type_name() -> String:
	return MapType.keys()[map_type]
