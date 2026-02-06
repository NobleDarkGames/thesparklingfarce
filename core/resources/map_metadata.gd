## MapMetadata - Configuration resource for exploration maps
##
## ARCHITECTURE: Scene is source of truth for visual/physical elements.
## JSON provides runtime configuration only.
##
## What comes from SCENE (via populate_from_scene()):
##   - map_id, display_name, map_type (from @export vars on scene root)
##   - spawn_points (extracted from SpawnPoint nodes)
##   - connections (extracted from MapTrigger DOOR nodes)
##
## What comes from JSON (runtime config):
##   - scene_path (REQUIRED - links to the scene file)
##   - caravan_visible, caravan_accessible
##   - music_id, ambient_id
##   - edge_connections (overworld only)
##
## Usage:
##   # Load from JSON (minimal):
##   var metadata = MapMetadataLoader.load_from_json("path/to/map.json")
##
##   # Populate from scene (extracts identity, spawns, connections):
##   var scene = load(metadata.scene_path)
##   var instance = scene.instantiate()
##   metadata.populate_from_scene(instance)
##   instance.queue_free()
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
	var result: Dictionary = _find_spawn_by_flag("is_default")
	if not result.is_empty():
		return result

	# Fallback: return first spawn point if no default
	if not spawn_points.is_empty():
		var first_id: String = str(spawn_points.keys()[0])
		var first_val: Variant = spawn_points.get(first_id)
		if first_val is Dictionary:
			var data: Dictionary = first_val.duplicate()
			data["spawn_id"] = first_id
			return data

	return {}


## Get the caravan spawn point for this map
## Returns empty Dictionary if no caravan spawn is defined
func get_caravan_spawn_point() -> Dictionary:
	return _find_spawn_by_flag("is_caravan_spawn")


## Find a spawn point by a boolean flag (is_default, is_caravan_spawn)
func _find_spawn_by_flag(flag_name: String) -> Dictionary:
	for spawn_id_key: Variant in spawn_points.keys():
		var spawn_id: String = str(spawn_id_key)
		var data_val: Variant = spawn_points.get(spawn_id)
		if not data_val is Dictionary:
			continue
		var data: Dictionary = data_val
		if DictUtils.get_bool(data, flag_name, false):
			var result: Dictionary = data.duplicate()
			result["spawn_id"] = spawn_id
			return result
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
		var conn_trigger_id: String = DictUtils.get_string(connection, "trigger_id", "")
		if conn_trigger_id == trigger_id:
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
	# Only OVERWORLD has caravan visible/accessible by default
	var is_overworld: bool = map_type == MapType.OVERWORLD
	caravan_visible = is_overworld
	caravan_accessible = is_overworld


# =============================================================================
# Validation
# =============================================================================

## Validate the map metadata configuration (standard bool interface)
func validate() -> bool:
	var errors: Array[String] = get_validation_errors()
	return errors.is_empty()


## Validate the map metadata configuration with detailed error reporting
## Returns array of error strings (empty if valid)
## Note: With scene-as-truth, map_id/display_name/spawn_points may be empty
## until populate_from_scene() is called. Use validate_after_scene_population()
## for full validation after scene extraction.
func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []

	# scene_path is always required (it's how we find the scene)
	if scene_path.is_empty():
		errors.append("scene_path is required")
	elif not scene_path.ends_with(".tscn"):
		errors.append("scene_path must be a .tscn file")

	# Validate spawn point data if present
	for spawn_id_key: Variant in spawn_points.keys():
		var spawn_id: String = str(spawn_id_key)
		var data_val: Variant = spawn_points.get(spawn_id)
		if not data_val is Dictionary:
			errors.append("Spawn point '%s' has invalid data type" % spawn_id)
			continue
		var data: Dictionary = data_val
		if "grid_position" not in data:
			errors.append("Spawn point '%s' missing grid_position" % spawn_id)
		if "facing" not in data:
			errors.append("Spawn point '%s' missing facing direction" % spawn_id)
		else:
			var facing: String = DictUtils.get_string(data, "facing", "")
			if facing not in ["up", "down", "left", "right"]:
				errors.append("Spawn point '%s' has invalid facing: %s" % [spawn_id, facing])

	# Validate connections format if present
	for connection: Dictionary in connections:
		if "trigger_id" not in connection:
			errors.append("Connection missing trigger_id")
		# target_map_id OR destination_scene (legacy) required
		if "target_map_id" not in connection and "destination_scene" not in connection:
			errors.append("Connection missing target_map_id")

	# Validate Caravan settings match map type
	if map_type == MapType.TOWN and caravan_visible:
		errors.append("TOWN maps should not have caravan_visible=true")

	if caravan_visible and not caravan_accessible:
		errors.append("caravan_visible requires caravan_accessible to be useful")

	return errors


## Full validation after scene population
## Use this after calling populate_from_scene() to ensure all required data exists
func validate_after_scene_population() -> Array[String]:
	var errors: Array[String] = get_validation_errors()

	# These fields should be populated from scene
	if map_id.is_empty():
		errors.append("map_id is required (should come from scene @export)")

	if display_name.is_empty():
		errors.append("display_name is required (should come from scene @export)")

	if spawn_points.is_empty():
		errors.append("At least one spawn point is required (should come from SpawnPoint nodes)")

	return errors


## Check if metadata is valid
func is_valid() -> bool:
	return get_validation_errors().is_empty()


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
		"scene_path": scene_path,
		"spawn_points": spawn_points.duplicate(true),
		"connections": connections.duplicate(true),
		"edge_connections": edge_connections.duplicate(true),
		"music_id": music_id,
		"ambient_id": ambient_id
	}


## Import from dictionary (for JSON loading)
static func from_dict(data: Dictionary) -> MapMetadata:
	var metadata: MapMetadata = MapMetadata.new()

	metadata.map_id = DictUtils.get_string(data, "map_id", "")
	metadata.display_name = DictUtils.get_string(data, "display_name", "")
	metadata.map_type = parse_map_type(DictUtils.get_string(data, "map_type", "TOWN"))
	metadata.caravan_accessible = DictUtils.get_bool(data, "caravan_accessible", false)
	metadata.caravan_visible = DictUtils.get_bool(data, "caravan_visible", false)
	metadata.scene_path = DictUtils.get_string(data, "scene_path", "")
	metadata.spawn_points = DictUtils.get_dict(data, "spawn_points", {})
	var connections_data: Array = DictUtils.get_array(data, "connections", [])
	if not connections_data.is_empty():
		metadata.connections.assign(connections_data)
	metadata.edge_connections = DictUtils.get_dict(data, "edge_connections", {})
	metadata.music_id = DictUtils.get_string(data, "music_id", "")
	metadata.ambient_id = DictUtils.get_string(data, "ambient_id", "")

	return metadata


## Get human-readable map type name
func get_type_name() -> String:
	return MapType.keys()[map_type]


## Parse a map type string to enum value, returns TOWN as default
static func parse_map_type(type_str: String) -> MapType:
	var type_map: Dictionary = {
		"TOWN": MapType.TOWN,
		"OVERWORLD": MapType.OVERWORLD,
		"DUNGEON": MapType.DUNGEON,
		"BATTLE": MapType.BATTLE,
		"INTERIOR": MapType.INTERIOR
	}
	var upper: String = type_str.to_upper()
	if upper in type_map:
		return type_map[upper]
	return MapType.TOWN


# =============================================================================
# Scene Population (Source of Truth)
# =============================================================================

## Populate metadata from a scene instance
## Extracts map_id, display_name, map_type from scene exports
## Extracts spawn_points from SpawnPoint nodes
## Extracts connections from MapTrigger DOOR nodes
## Call this after loading the JSON and instantiating the scene
func populate_from_scene(scene_root: Node) -> void:
	_extract_identity_from_scene(scene_root)
	_extract_spawn_points_from_scene(scene_root)
	_extract_connections_from_scene(scene_root)


## Extract map identity from scene exports (map_id, display_name, map_type)
func _extract_identity_from_scene(scene_root: Node) -> void:
	# Only extract if not already set (JSON can override for special cases)
	if map_id.is_empty() and "map_id" in scene_root:
		map_id = str(scene_root.get("map_id"))

	if display_name.is_empty() and "display_name" in scene_root:
		display_name = str(scene_root.get("display_name"))

	# Extract map_type if scene has it as a string
	if "map_type" in scene_root:
		var scene_type: Variant = scene_root.get("map_type")
		if scene_type is String:
			map_type = MapMetadata.parse_map_type(scene_type)


## Extract spawn points from SpawnPoint nodes in the scene
func _extract_spawn_points_from_scene(scene_root: Node) -> void:
	# Only extract if spawn_points is empty (JSON can override)
	if not spawn_points.is_empty():
		return

	# Use SpawnPoint's static helper to find all spawn points
	var loaded_script: Resource = load("res://core/components/spawn_point.gd")
	var spawn_point_script: GDScript = loaded_script if loaded_script is GDScript else null
	if spawn_point_script and spawn_point_script.has_method("find_all_in_tree"):
		var found_spawns: Array = spawn_point_script.find_all_in_tree(scene_root)
		for spawn_node: Node in found_spawns:
			if spawn_node.has_method("to_dict"):
				var spawn_data: Dictionary = spawn_node.to_dict()
				var spawn_id: String = spawn_node.get("spawn_id") if "spawn_id" in spawn_node else ""
				if not spawn_id.is_empty():
					spawn_points[spawn_id] = spawn_data
	else:
		# Fallback: manually search for SpawnPoint nodes
		_find_spawn_points_recursive(scene_root)


## Recursive fallback for finding spawn points
func _find_spawn_points_recursive(node: Node) -> void:
	# Check if this node is a SpawnPoint
	if node.has_method("to_dict") and "spawn_id" in node:
		var spawn_id: String = node.get("spawn_id")
		if not spawn_id.is_empty():
			spawn_points[spawn_id] = node.to_dict()

	# Recurse into children
	for child: Node in node.get_children():
		_find_spawn_points_recursive(child)


## Extract door connections from MapTrigger DOOR nodes in the scene
func _extract_connections_from_scene(scene_root: Node) -> void:
	# Only extract if connections is empty (JSON can override)
	if not connections.is_empty():
		return

	_find_door_triggers_recursive(scene_root)


## Recursive search for door triggers
func _find_door_triggers_recursive(node: Node) -> void:
	# Check if this node is a MapTrigger with DOOR type
	if "trigger_type" in node and "trigger_data" in node:
		var trigger_type: Variant = node.get("trigger_type")
		# DOOR = 3 in the enum
		if trigger_type == 3 or (trigger_type is String and trigger_type.to_upper() == "DOOR"):
			var trigger_id: String = node.get("trigger_id") if "trigger_id" in node else ""
			var trigger_data: Variant = node.get("trigger_data")

			if not trigger_id.is_empty() and trigger_data is Dictionary:
				var data: Dictionary = trigger_data
				var connection: Dictionary = {
					"trigger_id": trigger_id,
					"transition_type": "fade"
				}

				# Extract target info from trigger_data
				if "target_map_id" in data:
					connection["target_map_id"] = str(data["target_map_id"])
				if "target_spawn_id" in data:
					connection["target_spawn_id"] = str(data["target_spawn_id"])
				# Legacy format support
				if "destination_scene" in data and "target_map_id" not in connection:
					connection["destination_scene"] = str(data["destination_scene"])
				if "spawn_point" in data and "target_spawn_id" not in connection:
					connection["target_spawn_id"] = str(data["spawn_point"])

				# Only add if we have meaningful connection data
				if "target_map_id" in connection or "destination_scene" in connection:
					connections.append(connection)

	# Recurse into children
	for child: Node in node.get_children():
		_find_door_triggers_recursive(child)
