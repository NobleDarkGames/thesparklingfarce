class_name MapMetadataLoader
extends RefCounted

## Loads MapMetadata from JSON files with scene-as-truth architecture
##
## ARCHITECTURE: Scene is source of truth for visual/physical elements.
## JSON provides runtime configuration only.
##
## What comes from SCENE (via populate_from_scene()):
##   - map_id, display_name, map_type (from @export vars)
##   - spawn_points (extracted from SpawnPoint nodes)
##   - connections (extracted from MapTrigger DOOR nodes)
##
## What comes from JSON (runtime config):
##   - scene_path (REQUIRED - links to the scene file)
##   - caravan_visible, caravan_accessible
##   - music_id, ambient_id
##   - edge_connections (overworld only - cannot derive from scene)
##
## Minimal JSON example:
## {
##   "scene_path": "res://mods/my_mod/maps/my_town.tscn"
## }
##
## Full JSON example (with optional overrides):
## {
##   "scene_path": "res://mods/my_mod/maps/my_town.tscn",
##   "caravan_visible": false,
##   "caravan_accessible": false,
##   "music_id": "town_theme",
##   "ambient_id": "",
##   "edge_connections": {}
## }

const MapMetadataScript: GDScript = preload("res://core/resources/map_metadata.gd")


## Load a MapMetadata resource from a JSON file
## Returns null if loading fails
static func load_from_json(json_path: String) -> Resource:
	# Don't use FileAccess.file_exists() - it fails in exports where files are in PCK
	# Just try to open the file directly
	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("MapMetadataLoader: File not found or failed to open: %s" % json_path)
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
## Scene-as-truth: map_id, display_name, map_type, spawn_points, connections are OPTIONAL
## They will be populated from the scene via populate_from_scene() after loading
static func _build_metadata_from_dict(data: Dictionary, source_path: String) -> Resource:
	var metadata: Resource = MapMetadataScript.new()

	# Scene path is REQUIRED - it's how we link to the scene
	if "scene_path" in data:
		metadata.scene_path = str(data["scene_path"])
	else:
		push_error("MapMetadataLoader: Missing required 'scene_path' in %s" % source_path)
		return null

	# Identity fields are OPTIONAL - will be populated from scene
	# But we accept them for backward compatibility or JSON-only override
	if "map_id" in data:
		metadata.map_id = str(data["map_id"])

	if "display_name" in data:
		metadata.display_name = str(data["display_name"])

	# Map type (parse from string) - OPTIONAL
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

	# Caravan settings (runtime config)
	if "caravan_visible" in data:
		metadata.caravan_visible = bool(data["caravan_visible"])

	if "caravan_accessible" in data:
		metadata.caravan_accessible = bool(data["caravan_accessible"])

	# Audio settings (runtime config - placeholder for vertical mixing)
	if "music_id" in data:
		metadata.music_id = str(data["music_id"])

	if "ambient_id" in data:
		metadata.ambient_id = str(data["ambient_id"])

	# Spawn points - OPTIONAL in JSON (will be extracted from scene)
	if "spawn_points" in data and data["spawn_points"] is Dictionary:
		metadata.spawn_points = _parse_spawn_points(data["spawn_points"] as Dictionary, source_path)

	# Connections - OPTIONAL in JSON (will be extracted from scene)
	if "connections" in data and data["connections"] is Array:
		metadata.connections.clear()
		for conn_data: Variant in data["connections"]:
			if conn_data is Dictionary:
				var connection: Dictionary = _parse_connection(conn_data as Dictionary, source_path)
				if not connection.is_empty():
					metadata.connections.append(connection)

	# Edge connections - must be in JSON (cannot derive from scene geometry)
	if "edge_connections" in data and data["edge_connections"] is Dictionary:
		metadata.edge_connections = _parse_edge_connections(data["edge_connections"] as Dictionary, source_path)

	# Mark as needing scene population if identity fields are missing
	metadata.set_meta("needs_scene_population", metadata.map_id.is_empty())
	metadata.set_meta("source_json_path", source_path)

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

		# Grid position (required for JSON-defined spawn points)
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
