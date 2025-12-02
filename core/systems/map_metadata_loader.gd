class_name MapMetadataLoader
extends RefCounted

## Loads MapMetadata from JSON files
##
## This allows modders to define map metadata in pure JSON without writing GDScript.
## JSON maps define the configuration, spawn points, and connections for exploration maps.
##
## Example JSON format:
## {
##   "map_id": "base_game:granseal",
##   "display_name": "Granseal Town",
##   "map_type": "TOWN",
##   "caravan_visible": false,
##   "caravan_accessible": false,
##   "camera_zoom": 1.0,
##   "scene_path": "res://mods/_base_game/maps/granseal.tscn",
##   "music_id": "town_theme",
##   "spawn_points": {
##     "entrance": {
##       "grid_position": [10, 15],
##       "facing": "up",
##       "is_default": true
##     },
##     "from_castle": {
##       "grid_position": [5, 5],
##       "facing": "down"
##     }
##   },
##   "connections": [
##     {
##       "trigger_id": "north_gate",
##       "target_map_id": "base_game:overworld_south",
##       "target_spawn_id": "granseal_entrance",
##       "transition_type": "fade"
##     }
##   ],
##   "edge_connections": {
##     "north": {
##       "target_map_id": "base_game:overworld_central",
##       "target_spawn_id": "south_edge",
##       "overlap_tiles": 1
##     }
##   }
## }

const MapMetadataScript: GDScript = preload("res://core/resources/map_metadata.gd")


## Load a MapMetadata resource from a JSON file
## Returns null if loading fails
static func load_from_json(json_path: String) -> Resource:
	if not FileAccess.file_exists(json_path):
		push_error("MapMetadataLoader: File not found: %s" % json_path)
		return null

	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("MapMetadataLoader: Failed to open file: %s" % json_path)
		return null

	var json_text: String = file.get_as_text()
	file.close()

	return load_from_json_string(json_text, json_path)


## Load a MapMetadata resource from a JSON string
## source_path is optional, used for error messages
static func load_from_json_string(json_text: String, source_path: String = "<string>") -> Resource:
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_text)

	if error != OK:
		push_error("MapMetadataLoader: JSON parse error in %s at line %d: %s" % [
			source_path, json.get_error_line(), json.get_error_message()
		])
		return null

	var data: Variant = json.data
	if not data is Dictionary:
		push_error("MapMetadataLoader: Root element must be a dictionary in %s" % source_path)
		return null

	return _build_metadata_from_dict(data as Dictionary, source_path)


## Build MapMetadata from a parsed JSON dictionary
static func _build_metadata_from_dict(data: Dictionary, source_path: String) -> Resource:
	var metadata: Resource = MapMetadataScript.new()

	# Required fields
	if "map_id" in data:
		metadata.map_id = str(data["map_id"])
	else:
		push_error("MapMetadataLoader: Missing required 'map_id' in %s" % source_path)
		return null

	if "display_name" in data:
		metadata.display_name = str(data["display_name"])
	else:
		push_error("MapMetadataLoader: Missing required 'display_name' in %s" % source_path)
		return null

	# Map type (parse from string)
	if "map_type" in data:
		var type_str: String = str(data["map_type"]).to_upper()
		match type_str:
			"TOWN":
				metadata.map_type = MapMetadataScript.MapType.TOWN
			"OVERWORLD":
				metadata.map_type = MapMetadataScript.MapType.OVERWORLD
			"DUNGEON":
				metadata.map_type = MapMetadataScript.MapType.DUNGEON
			"BATTLE":
				metadata.map_type = MapMetadataScript.MapType.BATTLE
			"INTERIOR":
				metadata.map_type = MapMetadataScript.MapType.INTERIOR
			_:
				push_warning("MapMetadataLoader: Unknown map_type '%s' in %s, defaulting to TOWN" % [type_str, source_path])
				metadata.map_type = MapMetadataScript.MapType.TOWN

	# Caravan settings
	if "caravan_visible" in data:
		metadata.caravan_visible = bool(data["caravan_visible"])

	if "caravan_accessible" in data:
		metadata.caravan_accessible = bool(data["caravan_accessible"])

	# Camera zoom
	if "camera_zoom" in data:
		metadata.camera_zoom = clampf(float(data["camera_zoom"]), 0.5, 2.0)

	# Scene path
	if "scene_path" in data:
		metadata.scene_path = str(data["scene_path"])
	else:
		push_error("MapMetadataLoader: Missing required 'scene_path' in %s" % source_path)
		return null

	# Audio settings
	if "music_id" in data:
		metadata.music_id = str(data["music_id"])

	if "ambient_id" in data:
		metadata.ambient_id = str(data["ambient_id"])

	# Encounter settings
	if "random_encounters_enabled" in data:
		metadata.random_encounters_enabled = bool(data["random_encounters_enabled"])

	if "base_encounter_rate" in data:
		metadata.base_encounter_rate = clampf(float(data["base_encounter_rate"]), 0.0, 1.0)

	if "save_anywhere" in data:
		metadata.save_anywhere = bool(data["save_anywhere"])

	# Spawn points
	if "spawn_points" in data and data["spawn_points"] is Dictionary:
		metadata.spawn_points = _parse_spawn_points(data["spawn_points"] as Dictionary, source_path)
	else:
		push_error("MapMetadataLoader: Missing required 'spawn_points' in %s" % source_path)
		return null

	# Connections
	if "connections" in data and data["connections"] is Array:
		metadata.connections.clear()
		for conn_data: Variant in data["connections"]:
			if conn_data is Dictionary:
				var connection: Dictionary = _parse_connection(conn_data as Dictionary, source_path)
				if not connection.is_empty():
					metadata.connections.append(connection)

	# Edge connections
	if "edge_connections" in data and data["edge_connections"] is Dictionary:
		metadata.edge_connections = _parse_edge_connections(data["edge_connections"] as Dictionary, source_path)

	# Validate the metadata
	var errors: Array[String] = metadata.validate()
	if not errors.is_empty():
		push_error("MapMetadataLoader: Map '%s' validation failed:" % metadata.map_id)
		for err: String in errors:
			push_error("  - %s" % err)
		return null

	return metadata


## Parse spawn points from JSON
static func _parse_spawn_points(data: Dictionary, source_path: String) -> Dictionary:
	var spawn_points: Dictionary = {}

	for spawn_id: String in data.keys():
		var spawn_data: Variant = data[spawn_id]
		if not spawn_data is Dictionary:
			push_warning("MapMetadataLoader: Invalid spawn point '%s' in %s" % [spawn_id, source_path])
			continue

		var spawn_dict: Dictionary = spawn_data as Dictionary
		var parsed: Dictionary = {}

		# Grid position (required)
		if "grid_position" in spawn_dict:
			var pos: Variant = spawn_dict["grid_position"]
			if pos is Array and pos.size() >= 2:
				parsed["grid_position"] = Vector2i(int(pos[0]), int(pos[1]))
			elif pos is Dictionary and "x" in pos and "y" in pos:
				parsed["grid_position"] = Vector2i(int(pos["x"]), int(pos["y"]))
			else:
				push_warning("MapMetadataLoader: Invalid grid_position for spawn '%s' in %s" % [spawn_id, source_path])
				continue
		else:
			push_warning("MapMetadataLoader: Spawn point '%s' missing grid_position in %s" % [spawn_id, source_path])
			continue

		# Facing direction (optional, default "down")
		parsed["facing"] = str(spawn_dict.get("facing", "down"))

		# Flags (optional, default false)
		parsed["is_default"] = bool(spawn_dict.get("is_default", false))
		parsed["is_caravan_spawn"] = bool(spawn_dict.get("is_caravan_spawn", false))

		spawn_points[spawn_id] = parsed

	return spawn_points


## Parse a connection dictionary from JSON
static func _parse_connection(data: Dictionary, source_path: String) -> Dictionary:
	var connection: Dictionary = {}

	# Required fields
	if "trigger_id" in data:
		connection["trigger_id"] = str(data["trigger_id"])
	else:
		push_warning("MapMetadataLoader: Connection missing 'trigger_id' in %s" % source_path)
		return {}

	if "target_map_id" in data:
		connection["target_map_id"] = str(data["target_map_id"])
	else:
		push_warning("MapMetadataLoader: Connection missing 'target_map_id' in %s" % source_path)
		return {}

	if "target_spawn_id" in data:
		connection["target_spawn_id"] = str(data["target_spawn_id"])
	else:
		push_warning("MapMetadataLoader: Connection missing 'target_spawn_id' in %s" % source_path)
		return {}

	# Optional fields
	connection["transition_type"] = str(data.get("transition_type", "fade"))
	connection["requires_key"] = str(data.get("requires_key", ""))
	connection["one_way"] = bool(data.get("one_way", false))

	return connection


## Parse edge connections from JSON
static func _parse_edge_connections(data: Dictionary, source_path: String) -> Dictionary:
	var edge_connections: Dictionary = {}
	var valid_edges: Array[String] = ["north", "south", "east", "west"]

	for edge: String in data.keys():
		if edge not in valid_edges:
			push_warning("MapMetadataLoader: Invalid edge '%s' in %s (must be north/south/east/west)" % [edge, source_path])
			continue

		var edge_data: Variant = data[edge]
		if not edge_data is Dictionary:
			push_warning("MapMetadataLoader: Invalid edge connection data for '%s' in %s" % [edge, source_path])
			continue

		var edge_dict: Dictionary = edge_data as Dictionary
		var parsed: Dictionary = {}

		if "target_map_id" in edge_dict:
			parsed["target_map_id"] = str(edge_dict["target_map_id"])
		else:
			push_warning("MapMetadataLoader: Edge '%s' missing 'target_map_id' in %s" % [edge, source_path])
			continue

		if "target_spawn_id" in edge_dict:
			parsed["target_spawn_id"] = str(edge_dict["target_spawn_id"])
		else:
			push_warning("MapMetadataLoader: Edge '%s' missing 'target_spawn_id' in %s" % [edge, source_path])
			continue

		parsed["overlap_tiles"] = int(edge_dict.get("overlap_tiles", 1))

		edge_connections[edge] = parsed

	return edge_connections
