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

	return _build_metadata_from_dict(data, source_path)


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
	if "spawn_points" in data:
		var spawn_points_raw: Variant = data["spawn_points"]
		if spawn_points_raw is Dictionary:
			var spawn_points_dict: Dictionary = spawn_points_raw
			metadata.spawn_points = _parse_spawn_points(spawn_points_dict, source_path)

	# Connections - OPTIONAL in JSON (will be extracted from scene)
	if "connections" in data:
		var connections_raw: Variant = data["connections"]
		if connections_raw is Array:
			var connections_arr: Array = connections_raw
			metadata.connections.clear()
			for i: int in range(connections_arr.size()):
				var conn_raw: Variant = connections_arr[i]
				if conn_raw is Dictionary:
					var conn_dict: Dictionary = conn_raw
					var connection: Dictionary = _parse_connection(conn_dict, source_path)
					if not connection.is_empty():
						metadata.connections.append(connection)

	# Edge connections - must be in JSON (cannot derive from scene geometry)
	if "edge_connections" in data:
		var edge_connections_raw: Variant = data["edge_connections"]
		if edge_connections_raw is Dictionary:
			var edge_connections_dict: Dictionary = edge_connections_raw
			metadata.edge_connections = _parse_edge_connections(edge_connections_dict, source_path)

	# Mark as needing scene population if identity fields are missing
	metadata.set_meta("needs_scene_population", metadata.map_id.is_empty())
	metadata.set_meta("source_json_path", source_path)

	return metadata


## Parse spawn points from JSON
static func _parse_spawn_points(data: Dictionary, source_path: String) -> Dictionary:
	var spawn_points: Dictionary = {}

	var data_keys: Array = data.keys()
	for i: int in range(data_keys.size()):
		var spawn_id_raw: Variant = data_keys[i]
		var spawn_id: String = str(spawn_id_raw)
		var spawn_data_raw: Variant = data[spawn_id]
		if not spawn_data_raw is Dictionary:
			push_warning("MapMetadataLoader: Invalid spawn point '%s' in %s" % [spawn_id, source_path])
			continue

		var spawn_dict: Dictionary = spawn_data_raw
		var parsed: Dictionary = {}

		# Grid position (required for JSON-defined spawn points)
		if "grid_position" in spawn_dict:
			var pos_raw: Variant = spawn_dict["grid_position"]
			if pos_raw is Array:
				var pos_arr: Array = pos_raw
				var pos_size: int = pos_arr.size()
				if pos_size >= 2:
					var x_raw: Variant = pos_arr[0]
					var y_raw: Variant = pos_arr[1]
					var x_val: int = _variant_to_int(x_raw)
					var y_val: int = _variant_to_int(y_raw)
					parsed["grid_position"] = Vector2i(x_val, y_val)
				else:
					push_warning("MapMetadataLoader: Invalid grid_position for spawn '%s' in %s" % [spawn_id, source_path])
					continue
			elif pos_raw is Dictionary:
				var pos_dict: Dictionary = pos_raw
				if "x" in pos_dict and "y" in pos_dict:
					var x_raw: Variant = pos_dict["x"]
					var y_raw: Variant = pos_dict["y"]
					var x_val: int = _variant_to_int(x_raw)
					var y_val: int = _variant_to_int(y_raw)
					parsed["grid_position"] = Vector2i(x_val, y_val)
				else:
					push_warning("MapMetadataLoader: Invalid grid_position for spawn '%s' in %s" % [spawn_id, source_path])
					continue
			else:
				push_warning("MapMetadataLoader: Invalid grid_position for spawn '%s' in %s" % [spawn_id, source_path])
				continue
		else:
			push_warning("MapMetadataLoader: Spawn point '%s' missing grid_position in %s" % [spawn_id, source_path])
			continue

		# Facing direction (optional, default "down")
		var facing_raw: Variant = spawn_dict.get("facing", "down")
		parsed["facing"] = str(facing_raw)

		# Flags (optional, default false)
		var is_default_raw: Variant = spawn_dict.get("is_default", false)
		var is_caravan_raw: Variant = spawn_dict.get("is_caravan_spawn", false)
		parsed["is_default"] = bool(is_default_raw)
		parsed["is_caravan_spawn"] = bool(is_caravan_raw)

		spawn_points[spawn_id] = parsed

	return spawn_points


## Parse a connection dictionary from JSON
static func _parse_connection(data: Dictionary, source_path: String) -> Dictionary:
	var connection: Dictionary = {}

	# Required fields
	if "trigger_id" in data:
		var trigger_id_raw: Variant = data["trigger_id"]
		connection["trigger_id"] = str(trigger_id_raw)
	else:
		push_warning("MapMetadataLoader: Connection missing 'trigger_id' in %s" % source_path)
		return {}

	if "target_map_id" in data:
		var target_map_id_raw: Variant = data["target_map_id"]
		connection["target_map_id"] = str(target_map_id_raw)
	else:
		push_warning("MapMetadataLoader: Connection missing 'target_map_id' in %s" % source_path)
		return {}

	if "target_spawn_id" in data:
		var target_spawn_id_raw: Variant = data["target_spawn_id"]
		connection["target_spawn_id"] = str(target_spawn_id_raw)
	else:
		push_warning("MapMetadataLoader: Connection missing 'target_spawn_id' in %s" % source_path)
		return {}

	# Optional fields
	var transition_raw: Variant = data.get("transition_type", "fade")
	var requires_key_raw: Variant = data.get("requires_key", "")
	var one_way_raw: Variant = data.get("one_way", false)
	connection["transition_type"] = str(transition_raw)
	connection["requires_key"] = str(requires_key_raw)
	connection["one_way"] = bool(one_way_raw)

	return connection


## Parse edge connections from JSON
static func _parse_edge_connections(data: Dictionary, source_path: String) -> Dictionary:
	var edge_connections: Dictionary = {}
	var valid_edges: Array[String] = ["north", "south", "east", "west"]

	var data_keys: Array = data.keys()
	for i: int in range(data_keys.size()):
		var edge_raw: Variant = data_keys[i]
		var edge: String = str(edge_raw)
		if edge not in valid_edges:
			push_warning("MapMetadataLoader: Invalid edge '%s' in %s (must be north/south/east/west)" % [edge, source_path])
			continue

		var edge_data_raw: Variant = data[edge]
		if not edge_data_raw is Dictionary:
			push_warning("MapMetadataLoader: Invalid edge connection data for '%s' in %s" % [edge, source_path])
			continue

		var edge_dict: Dictionary = edge_data_raw
		var parsed: Dictionary = {}

		if "target_map_id" in edge_dict:
			var target_map_id_raw: Variant = edge_dict["target_map_id"]
			parsed["target_map_id"] = str(target_map_id_raw)
		else:
			push_warning("MapMetadataLoader: Edge '%s' missing 'target_map_id' in %s" % [edge, source_path])
			continue

		if "target_spawn_id" in edge_dict:
			var target_spawn_id_raw: Variant = edge_dict["target_spawn_id"]
			parsed["target_spawn_id"] = str(target_spawn_id_raw)
		else:
			push_warning("MapMetadataLoader: Edge '%s' missing 'target_spawn_id' in %s" % [edge, source_path])
			continue

		var overlap_raw: Variant = edge_dict.get("overlap_tiles", 1)
		var overlap_tiles: int = 1
		if overlap_raw is int:
			overlap_tiles = overlap_raw
		elif overlap_raw is float:
			overlap_tiles = int(overlap_raw)
		parsed["overlap_tiles"] = overlap_tiles

		edge_connections[edge] = parsed

	return edge_connections


## Safely convert a Variant to int with type checking
static func _variant_to_int(value: Variant) -> int:
	if value is int:
		return value
	elif value is float:
		return int(value)
	return 0
