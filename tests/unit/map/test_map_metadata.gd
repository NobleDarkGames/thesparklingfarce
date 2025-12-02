## Unit Tests for MapMetadata Resource
##
## Tests the map metadata configuration system following SF2's open world model.
## Pure resource tests - no scene dependencies.
class_name TestMapMetadata
extends GdUnitTestSuite


const MapMetadataScript: GDScript = preload("res://core/resources/map_metadata.gd")


# =============================================================================
# TEST FIXTURES
# =============================================================================

## Create a basic valid MapMetadata for testing
func _create_valid_metadata() -> Resource:
	var metadata: Resource = MapMetadataScript.new()
	metadata.map_id = "test_mod:test_map"
	metadata.display_name = "Test Map"
	metadata.map_type = MapMetadataScript.MapType.TOWN
	metadata.scene_path = "res://test/map.tscn"
	metadata.add_spawn_point("entrance", Vector2i(10, 15), "up", true)
	return metadata


# =============================================================================
# BASIC VALIDATION TESTS
# =============================================================================

func test_empty_metadata_is_invalid() -> void:
	var metadata: Resource = MapMetadataScript.new()
	var errors: Array[String] = metadata.validate()

	assert_bool(errors.is_empty()).is_false()
	assert_array(errors).contains(["map_id is required"])


func test_valid_metadata_passes_validation() -> void:
	var metadata: Resource = _create_valid_metadata()
	var errors: Array[String] = metadata.validate()

	assert_bool(metadata.is_valid()).is_true()
	assert_array(errors).is_empty()


func test_missing_display_name_fails_validation() -> void:
	var metadata: Resource = MapMetadataScript.new()
	metadata.map_id = "test:map"
	metadata.scene_path = "res://test.tscn"
	metadata.add_spawn_point("default", Vector2i.ZERO)

	var errors: Array[String] = metadata.validate()
	assert_array(errors).contains(["display_name is required"])


func test_missing_scene_path_fails_validation() -> void:
	var metadata: Resource = MapMetadataScript.new()
	metadata.map_id = "test:map"
	metadata.display_name = "Test"
	metadata.add_spawn_point("default", Vector2i.ZERO)

	var errors: Array[String] = metadata.validate()
	assert_array(errors).contains(["scene_path is required"])


func test_no_spawn_points_fails_validation() -> void:
	var metadata: Resource = MapMetadataScript.new()
	metadata.map_id = "test:map"
	metadata.display_name = "Test"
	metadata.scene_path = "res://test.tscn"

	var errors: Array[String] = metadata.validate()
	assert_array(errors).contains(["At least one spawn point is required"])


# =============================================================================
# MAP TYPE TESTS
# =============================================================================

func test_map_type_defaults_to_town() -> void:
	var metadata: Resource = MapMetadataScript.new()
	assert_int(metadata.map_type).is_equal(MapMetadataScript.MapType.TOWN)


func test_apply_type_defaults_for_town() -> void:
	var metadata: Resource = MapMetadataScript.new()
	metadata.map_type = MapMetadataScript.MapType.TOWN
	metadata.apply_type_defaults()

	assert_bool(metadata.caravan_visible).is_false()
	assert_bool(metadata.caravan_accessible).is_false()
	assert_float(metadata.camera_zoom).is_equal_approx(1.0, 0.01)
	assert_bool(metadata.random_encounters_enabled).is_false()
	assert_bool(metadata.save_anywhere).is_true()


func test_apply_type_defaults_for_overworld() -> void:
	var metadata: Resource = MapMetadataScript.new()
	metadata.map_type = MapMetadataScript.MapType.OVERWORLD
	metadata.apply_type_defaults()

	assert_bool(metadata.caravan_visible).is_true()
	assert_bool(metadata.caravan_accessible).is_true()
	assert_float(metadata.camera_zoom).is_equal_approx(1.0, 0.01)  # 1.0 for pixel-perfect rendering
	assert_bool(metadata.random_encounters_enabled).is_true()
	assert_float(metadata.base_encounter_rate).is_equal_approx(0.1, 0.01)


func test_apply_type_defaults_for_dungeon() -> void:
	var metadata: Resource = MapMetadataScript.new()
	metadata.map_type = MapMetadataScript.MapType.DUNGEON
	metadata.apply_type_defaults()

	assert_bool(metadata.caravan_visible).is_false()
	assert_bool(metadata.random_encounters_enabled).is_true()
	assert_bool(metadata.save_anywhere).is_false()


func test_get_type_name_returns_correct_string() -> void:
	var metadata: Resource = _create_valid_metadata()

	metadata.map_type = MapMetadataScript.MapType.TOWN
	assert_str(metadata.get_type_name()).is_equal("TOWN")

	metadata.map_type = MapMetadataScript.MapType.OVERWORLD
	assert_str(metadata.get_type_name()).is_equal("OVERWORLD")

	metadata.map_type = MapMetadataScript.MapType.DUNGEON
	assert_str(metadata.get_type_name()).is_equal("DUNGEON")


# =============================================================================
# SPAWN POINT TESTS
# =============================================================================

func test_add_spawn_point_basic() -> void:
	var metadata: Resource = MapMetadataScript.new()
	metadata.add_spawn_point("entrance", Vector2i(10, 15), "up")

	assert_bool("entrance" in metadata.spawn_points).is_true()

	var spawn_data: Dictionary = metadata.spawn_points["entrance"]
	assert_object(spawn_data["grid_position"]).is_equal(Vector2i(10, 15))
	assert_str(spawn_data["facing"]).is_equal("up")
	assert_bool(spawn_data["is_default"]).is_false()
	assert_bool(spawn_data["is_caravan_spawn"]).is_false()


func test_add_spawn_point_with_flags() -> void:
	var metadata: Resource = MapMetadataScript.new()
	metadata.add_spawn_point("main", Vector2i(5, 5), "down", true, true)

	var spawn_data: Dictionary = metadata.spawn_points["main"]
	assert_bool(spawn_data["is_default"]).is_true()
	assert_bool(spawn_data["is_caravan_spawn"]).is_true()


func test_get_spawn_point_returns_data() -> void:
	var metadata: Resource = _create_valid_metadata()

	var spawn_data: Dictionary = metadata.get_spawn_point("entrance")
	assert_bool(spawn_data.is_empty()).is_false()
	assert_object(spawn_data["grid_position"]).is_equal(Vector2i(10, 15))


func test_get_spawn_point_returns_empty_for_missing() -> void:
	var metadata: Resource = _create_valid_metadata()

	var spawn_data: Dictionary = metadata.get_spawn_point("nonexistent")
	assert_bool(spawn_data.is_empty()).is_true()


func test_get_default_spawn_point_returns_marked_default() -> void:
	var metadata: Resource = MapMetadataScript.new()
	metadata.add_spawn_point("first", Vector2i(1, 1), "down")
	metadata.add_spawn_point("default_one", Vector2i(5, 5), "up", true)
	metadata.add_spawn_point("last", Vector2i(10, 10), "left")

	var default_spawn: Dictionary = metadata.get_default_spawn_point()
	assert_str(default_spawn["spawn_id"]).is_equal("default_one")
	assert_object(default_spawn["grid_position"]).is_equal(Vector2i(5, 5))


func test_get_default_spawn_point_fallback_to_first() -> void:
	var metadata: Resource = MapMetadataScript.new()
	metadata.add_spawn_point("only_spawn", Vector2i(3, 3), "right")

	var default_spawn: Dictionary = metadata.get_default_spawn_point()
	assert_bool(default_spawn.is_empty()).is_false()


func test_get_caravan_spawn_point() -> void:
	var metadata: Resource = MapMetadataScript.new()
	metadata.add_spawn_point("player_start", Vector2i(1, 1), "down", true)
	metadata.add_spawn_point("caravan_spot", Vector2i(3, 1), "down", false, true)

	var caravan_spawn: Dictionary = metadata.get_caravan_spawn_point()
	assert_str(caravan_spawn["spawn_id"]).is_equal("caravan_spot")


# =============================================================================
# CONNECTION TESTS
# =============================================================================

func test_add_connection_basic() -> void:
	var metadata: Resource = _create_valid_metadata()
	metadata.add_connection("north_door", "other_mod:other_map", "south_entrance")

	assert_int(metadata.connections.size()).is_equal(1)

	var conn: Dictionary = metadata.connections[0]
	assert_str(conn["trigger_id"]).is_equal("north_door")
	assert_str(conn["target_map_id"]).is_equal("other_mod:other_map")
	assert_str(conn["target_spawn_id"]).is_equal("south_entrance")
	assert_str(conn["transition_type"]).is_equal("fade")
	assert_bool(conn["one_way"]).is_false()


func test_add_connection_with_options() -> void:
	var metadata: Resource = _create_valid_metadata()
	metadata.add_connection(
		"locked_door",
		"mod:secret_room",
		"entrance",
		"instant",
		"skeleton_key",
		true
	)

	var conn: Dictionary = metadata.connections[0]
	assert_str(conn["transition_type"]).is_equal("instant")
	assert_str(conn["requires_key"]).is_equal("skeleton_key")
	assert_bool(conn["one_way"]).is_true()


func test_get_connection_for_trigger() -> void:
	var metadata: Resource = _create_valid_metadata()
	metadata.add_connection("door_a", "map:a", "spawn_a")
	metadata.add_connection("door_b", "map:b", "spawn_b")

	var conn: Dictionary = metadata.get_connection_for_trigger("door_b")
	assert_str(conn["target_map_id"]).is_equal("map:b")


func test_get_connection_for_missing_trigger() -> void:
	var metadata: Resource = _create_valid_metadata()

	var conn: Dictionary = metadata.get_connection_for_trigger("missing")
	assert_bool(conn.is_empty()).is_true()


# =============================================================================
# EDGE CONNECTION TESTS
# =============================================================================

func test_add_edge_connection() -> void:
	var metadata: Resource = _create_valid_metadata()
	metadata.add_edge_connection("north", "mod:north_map", "south_edge", 1)

	assert_bool("north" in metadata.edge_connections).is_true()

	var edge: Dictionary = metadata.edge_connections["north"]
	assert_str(edge["target_map_id"]).is_equal("mod:north_map")
	assert_str(edge["target_spawn_id"]).is_equal("south_edge")
	assert_int(edge["overlap_tiles"]).is_equal(1)


func test_get_edge_connection() -> void:
	var metadata: Resource = _create_valid_metadata()
	metadata.add_edge_connection("west", "mod:west_map", "east_edge")

	var edge: Dictionary = metadata.get_edge_connection("west")
	assert_str(edge["target_map_id"]).is_equal("mod:west_map")


func test_get_edge_connection_missing() -> void:
	var metadata: Resource = _create_valid_metadata()

	var edge: Dictionary = metadata.get_edge_connection("east")
	assert_bool(edge.is_empty()).is_true()


# =============================================================================
# SERIALIZATION TESTS
# =============================================================================

func test_to_dict_includes_all_fields() -> void:
	var metadata: Resource = _create_valid_metadata()
	metadata.music_id = "town_theme"
	metadata.random_encounters_enabled = true

	var dict: Dictionary = metadata.to_dict()

	assert_str(dict["map_id"]).is_equal("test_mod:test_map")
	assert_str(dict["display_name"]).is_equal("Test Map")
	assert_str(dict["map_type"]).is_equal("TOWN")
	assert_str(dict["scene_path"]).is_equal("res://test/map.tscn")
	assert_str(dict["music_id"]).is_equal("town_theme")
	assert_bool(dict["random_encounters_enabled"]).is_true()
	assert_bool("spawn_points" in dict).is_true()


func test_from_dict_roundtrip() -> void:
	var original: Resource = _create_valid_metadata()
	original.camera_zoom = 0.85
	original.music_id = "overworld_theme"
	original.add_connection("door", "target:map", "spawn")

	var dict: Dictionary = original.to_dict()
	var restored: Resource = MapMetadataScript.from_dict(dict)

	assert_str(restored.map_id).is_equal(original.map_id)
	assert_str(restored.display_name).is_equal(original.display_name)
	assert_float(restored.camera_zoom).is_equal_approx(0.85, 0.01)
	assert_str(restored.music_id).is_equal("overworld_theme")


# =============================================================================
# VALIDATION EDGE CASES
# =============================================================================

func test_invalid_facing_direction_fails_validation() -> void:
	var metadata: Resource = MapMetadataScript.new()
	metadata.map_id = "test:map"
	metadata.display_name = "Test"
	metadata.scene_path = "res://test.tscn"
	metadata.spawn_points["bad_spawn"] = {
		"grid_position": Vector2i(0, 0),
		"facing": "diagonal"  # Invalid!
	}

	var errors: Array[String] = metadata.validate()
	# Should contain an error about invalid facing
	assert_bool(errors.size() > 0).is_true()


func test_caravan_visible_on_town_warns() -> void:
	var metadata: Resource = _create_valid_metadata()
	metadata.map_type = MapMetadataScript.MapType.TOWN
	metadata.caravan_visible = true
	metadata.caravan_accessible = true

	var errors: Array[String] = metadata.validate()
	# Should contain warning about caravan on town
	assert_bool(errors.size() > 0).is_true()
