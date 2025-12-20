## Unit Tests for MapMetadataLoader
##
## Tests JSON loading of MapMetadata resources.
class_name TestMapMetadataLoader
extends GdUnitTestSuite


const MapMetadataLoaderScript: GDScript = preload("res://core/systems/map_metadata_loader.gd")
const MapMetadataScript: GDScript = preload("res://core/resources/map_metadata.gd")


# =============================================================================
# TEST FIXTURES
# =============================================================================

## Create a valid JSON string for testing
func _create_valid_json() -> String:
	return """{
		"map_id": "test_mod:test_town",
		"display_name": "Test Town",
		"map_type": "TOWN",
		"caravan_visible": false,
		"caravan_accessible": false,
		"scene_path": "res://test/town.tscn",
		"music_id": "town_theme",
		"spawn_points": {
			"entrance": {
				"grid_position": [10, 15],
				"facing": "up",
				"is_default": true
			},
			"from_castle": {
				"grid_position": [5, 5],
				"facing": "down"
			}
		},
		"connections": [
			{
				"trigger_id": "north_gate",
				"target_map_id": "test_mod:overworld",
				"target_spawn_id": "town_entrance",
				"transition_type": "fade"
			}
		]
	}"""


## Create a minimal valid JSON string
func _create_minimal_json() -> String:
	return """{
		"map_id": "test:minimal",
		"display_name": "Minimal Map",
		"scene_path": "res://test.tscn",
		"spawn_points": {
			"default": {
				"grid_position": [0, 0],
				"facing": "down",
				"is_default": true
			}
		}
	}"""


# =============================================================================
# BASIC LOADING TESTS
# =============================================================================

func test_load_from_json_string_valid() -> void:
	var json: String = _create_valid_json()
	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json, "test.json")

	assert_object(metadata).is_not_null()
	assert_str(metadata.map_id).is_equal("test_mod:test_town")
	assert_str(metadata.display_name).is_equal("Test Town")


func test_load_from_json_string_minimal() -> void:
	var json: String = _create_minimal_json()
	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json)

	assert_object(metadata).is_not_null()
	assert_str(metadata.map_id).is_equal("test:minimal")
	# Should have default map type
	assert_int(metadata.map_type).is_equal(MapMetadataScript.MapType.TOWN)


func test_load_missing_map_id_succeeds_with_scene_as_truth() -> void:
	# With scene-as-truth architecture, map_id is OPTIONAL in JSON
	# It will be populated from the scene via populate_from_scene()
	var json: String = """{
		"display_name": "No ID",
		"scene_path": "res://test.tscn",
		"spawn_points": {"default": {"grid_position": [0,0], "facing": "down"}}
	}"""

	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json)
	# Should succeed - map_id will be populated from scene later
	assert_object(metadata).is_not_null()
	assert_str(metadata.map_id).is_empty()  # Not set yet, will come from scene
	assert_bool(metadata.get_meta("needs_scene_population")).is_true()


func test_load_missing_scene_path_returns_null() -> void:
	var json: String = """{
		"map_id": "test:no_scene",
		"display_name": "No Scene",
		"spawn_points": {"default": {"grid_position": [0,0], "facing": "down"}}
	}"""

	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json)
	assert_object(metadata).is_null()


func test_load_missing_spawn_points_succeeds_with_scene_as_truth() -> void:
	# With scene-as-truth architecture, spawn_points are OPTIONAL in JSON
	# They will be extracted from SpawnPoint nodes via populate_from_scene()
	var json: String = """{
		"map_id": "test:no_spawns",
		"display_name": "No Spawns",
		"scene_path": "res://test.tscn"
	}"""

	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json)
	# Should succeed - spawn_points will be populated from scene later
	assert_object(metadata).is_not_null()
	assert_bool(metadata.spawn_points.is_empty()).is_true()  # Not set yet


func test_load_invalid_json_returns_null() -> void:
	var json: String = "{ this is not valid json }"

	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json)
	assert_object(metadata).is_null()


# =============================================================================
# MAP TYPE PARSING TESTS
# =============================================================================

func test_parse_map_type_town() -> void:
	var json: String = """{
		"map_id": "test:town",
		"display_name": "Town",
		"map_type": "TOWN",
		"scene_path": "res://test.tscn",
		"spawn_points": {"default": {"grid_position": [0,0], "facing": "down", "is_default": true}}
	}"""

	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json)
	assert_int(metadata.map_type).is_equal(MapMetadataScript.MapType.TOWN)


func test_parse_map_type_overworld() -> void:
	var json: String = """{
		"map_id": "test:overworld",
		"display_name": "Overworld",
		"map_type": "OVERWORLD",
		"scene_path": "res://test.tscn",
		"spawn_points": {"default": {"grid_position": [0,0], "facing": "down", "is_default": true}}
	}"""

	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json)
	assert_int(metadata.map_type).is_equal(MapMetadataScript.MapType.OVERWORLD)


func test_parse_map_type_dungeon() -> void:
	var json: String = """{
		"map_id": "test:dungeon",
		"display_name": "Dungeon",
		"map_type": "DUNGEON",
		"scene_path": "res://test.tscn",
		"spawn_points": {"default": {"grid_position": [0,0], "facing": "down", "is_default": true}}
	}"""

	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json)
	assert_int(metadata.map_type).is_equal(MapMetadataScript.MapType.DUNGEON)


func test_parse_map_type_case_insensitive() -> void:
	var json: String = """{
		"map_id": "test:lower",
		"display_name": "Lower Case",
		"map_type": "overworld",
		"scene_path": "res://test.tscn",
		"spawn_points": {"default": {"grid_position": [0,0], "facing": "down", "is_default": true}}
	}"""

	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json)
	assert_int(metadata.map_type).is_equal(MapMetadataScript.MapType.OVERWORLD)


func test_parse_map_type_unknown_defaults_to_town() -> void:
	var json: String = """{
		"map_id": "test:unknown",
		"display_name": "Unknown Type",
		"map_type": "SPACE_STATION",
		"scene_path": "res://test.tscn",
		"spawn_points": {"default": {"grid_position": [0,0], "facing": "down", "is_default": true}}
	}"""

	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json)
	assert_int(metadata.map_type).is_equal(MapMetadataScript.MapType.TOWN)


# =============================================================================
# SPAWN POINT PARSING TESTS
# =============================================================================

func test_parse_spawn_points_array_format() -> void:
	var json: String = """{
		"map_id": "test:array",
		"display_name": "Array Format",
		"scene_path": "res://test.tscn",
		"spawn_points": {
			"entrance": {
				"grid_position": [10, 20],
				"facing": "up",
				"is_default": true
			}
		}
	}"""

	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json)
	var spawn: Dictionary = metadata.spawn_points["entrance"]

	assert_object(spawn["grid_position"]).is_equal(Vector2i(10, 20))
	assert_str(spawn["facing"]).is_equal("up")
	assert_bool(spawn["is_default"]).is_true()


func test_parse_spawn_points_object_format() -> void:
	var json: String = """{
		"map_id": "test:object",
		"display_name": "Object Format",
		"scene_path": "res://test.tscn",
		"spawn_points": {
			"entrance": {
				"grid_position": {"x": 5, "y": 10},
				"facing": "down",
				"is_default": true
			}
		}
	}"""

	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json)
	var spawn: Dictionary = metadata.spawn_points["entrance"]

	assert_object(spawn["grid_position"]).is_equal(Vector2i(5, 10))


func test_parse_spawn_points_default_facing() -> void:
	var json: String = """{
		"map_id": "test:default_facing",
		"display_name": "Default Facing",
		"scene_path": "res://test.tscn",
		"spawn_points": {
			"entrance": {
				"grid_position": [0, 0],
				"is_default": true
			}
		}
	}"""

	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json)
	var spawn: Dictionary = metadata.spawn_points["entrance"]

	# Should default to "down"
	assert_str(spawn["facing"]).is_equal("down")


# =============================================================================
# CONNECTION PARSING TESTS
# =============================================================================

func test_parse_connections() -> void:
	var json: String = _create_valid_json()
	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json)

	assert_int(metadata.connections.size()).is_equal(1)

	var conn: Dictionary = metadata.connections[0]
	assert_str(conn["trigger_id"]).is_equal("north_gate")
	assert_str(conn["target_map_id"]).is_equal("test_mod:overworld")
	assert_str(conn["target_spawn_id"]).is_equal("town_entrance")
	assert_str(conn["transition_type"]).is_equal("fade")


func test_parse_connections_defaults() -> void:
	var json: String = """{
		"map_id": "test:conn",
		"display_name": "Connections",
		"scene_path": "res://test.tscn",
		"spawn_points": {"default": {"grid_position": [0,0], "facing": "down", "is_default": true}},
		"connections": [
			{
				"trigger_id": "door",
				"target_map_id": "other:map",
				"target_spawn_id": "entrance"
			}
		]
	}"""

	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json)
	var conn: Dictionary = metadata.connections[0]

	# Should have default transition type
	assert_str(conn["transition_type"]).is_equal("fade")
	assert_str(conn["requires_key"]).is_equal("")
	assert_bool(conn["one_way"]).is_false()


# =============================================================================
# EDGE CONNECTION PARSING TESTS
# =============================================================================

func test_parse_edge_connections() -> void:
	var json: String = """{
		"map_id": "test:edges",
		"display_name": "Edge Test",
		"scene_path": "res://test.tscn",
		"spawn_points": {"default": {"grid_position": [0,0], "facing": "down", "is_default": true}},
		"edge_connections": {
			"north": {
				"target_map_id": "test:north_map",
				"target_spawn_id": "south_edge",
				"overlap_tiles": 1
			}
		}
	}"""

	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json)

	assert_bool("north" in metadata.edge_connections).is_true()

	var edge: Dictionary = metadata.edge_connections["north"]
	assert_str(edge["target_map_id"]).is_equal("test:north_map")
	assert_str(edge["target_spawn_id"]).is_equal("south_edge")
	assert_int(edge["overlap_tiles"]).is_equal(1)


func test_parse_invalid_edge_direction_ignored() -> void:
	var json: String = """{
		"map_id": "test:bad_edge",
		"display_name": "Bad Edge",
		"scene_path": "res://test.tscn",
		"spawn_points": {"default": {"grid_position": [0,0], "facing": "down", "is_default": true}},
		"edge_connections": {
			"diagonal": {
				"target_map_id": "test:map",
				"target_spawn_id": "spawn"
			}
		}
	}"""

	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json)

	# Invalid edge should be ignored
	assert_bool("diagonal" in metadata.edge_connections).is_false()


# =============================================================================
# OPTIONAL FIELD TESTS
# =============================================================================

func test_parse_optional_fields() -> void:
	var json: String = """{
		"map_id": "test:full",
		"display_name": "Full Options",
		"scene_path": "res://test.tscn",
		"spawn_points": {"default": {"grid_position": [0,0], "facing": "down", "is_default": true}},
		"music_id": "epic_theme",
		"ambient_id": "forest_sounds"
	}"""

	var metadata: Resource = MapMetadataLoaderScript.load_from_json_string(json)

	assert_str(metadata.music_id).is_equal("epic_theme")
	assert_str(metadata.ambient_id).is_equal("forest_sounds")
