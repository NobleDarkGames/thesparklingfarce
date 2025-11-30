## Unit Tests for MaterialSpawnData Resource
##
## Tests the material spawn point data used for world pickups.
## Focuses heavily on accessibility logic with flags and chapters.
class_name TestMaterialSpawnData
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

func _create_spawn(
	material: String = "mithril",
	map: String = "town_01",
	spawn: String = "spawn_01",
	pos: Vector2i = Vector2i.ZERO
) -> MaterialSpawnData:
	var data: MaterialSpawnData = MaterialSpawnData.new()
	data.material_id = material
	data.map_id = map
	data.spawn_id = spawn
	data.grid_position = pos
	return data


## Flag checker that always returns false
func _no_flags(_flag: String) -> bool:
	return false


## Flag checker that always returns true
func _all_flags(_flag: String) -> bool:
	return true


## Create a flag checker from a list of set flags
func _flag_checker_from_list(flags: Array[String]) -> Callable:
	return func(flag: String) -> bool:
		return flag in flags


# =============================================================================
# BASIC PROPERTY TESTS
# =============================================================================

func test_default_values() -> void:
	var data: MaterialSpawnData = MaterialSpawnData.new()

	assert_str(data.material_id).is_equal("")
	assert_str(data.map_id).is_equal("")
	assert_str(data.spawn_id).is_equal("")
	assert_object(data.grid_position).is_equal(Vector2i.ZERO)
	assert_int(data.quantity).is_equal(1)
	assert_bool(data.respawns).is_false()
	assert_int(data.min_chapter).is_equal(0)
	assert_int(data.max_chapter).is_equal(-1)


func test_properties_set_correctly() -> void:
	var data: MaterialSpawnData = _create_spawn("dragon_scale", "cave_02", "ds_01", Vector2i(5, 10))
	data.quantity = 3
	data.visual_hint = "glow"

	assert_str(data.material_id).is_equal("dragon_scale")
	assert_str(data.map_id).is_equal("cave_02")
	assert_str(data.spawn_id).is_equal("ds_01")
	assert_object(data.grid_position).is_equal(Vector2i(5, 10))
	assert_int(data.quantity).is_equal(3)
	assert_str(data.visual_hint).is_equal("glow")


# =============================================================================
# ACCESSIBILITY TESTS - CHAPTERS
# =============================================================================

func test_accessible_with_no_restrictions() -> void:
	var data: MaterialSpawnData = _create_spawn()

	# No flags, any chapter should work
	assert_bool(data.is_accessible(_no_flags, 1)).is_true()
	assert_bool(data.is_accessible(_no_flags, 5)).is_true()
	assert_bool(data.is_accessible(_no_flags, 99)).is_true()


func test_accessible_respects_min_chapter() -> void:
	var data: MaterialSpawnData = _create_spawn()
	data.min_chapter = 3

	assert_bool(data.is_accessible(_no_flags, 1)).is_false()
	assert_bool(data.is_accessible(_no_flags, 2)).is_false()
	assert_bool(data.is_accessible(_no_flags, 3)).is_true()
	assert_bool(data.is_accessible(_no_flags, 4)).is_true()


func test_accessible_respects_max_chapter() -> void:
	var data: MaterialSpawnData = _create_spawn()
	data.max_chapter = 5

	assert_bool(data.is_accessible(_no_flags, 3)).is_true()
	assert_bool(data.is_accessible(_no_flags, 5)).is_true()
	assert_bool(data.is_accessible(_no_flags, 6)).is_false()
	assert_bool(data.is_accessible(_no_flags, 10)).is_false()


func test_accessible_chapter_window() -> void:
	var data: MaterialSpawnData = _create_spawn()
	data.min_chapter = 2
	data.max_chapter = 4

	assert_bool(data.is_accessible(_no_flags, 1)).is_false()
	assert_bool(data.is_accessible(_no_flags, 2)).is_true()
	assert_bool(data.is_accessible(_no_flags, 3)).is_true()
	assert_bool(data.is_accessible(_no_flags, 4)).is_true()
	assert_bool(data.is_accessible(_no_flags, 5)).is_false()


func test_accessible_max_chapter_minus_one_means_no_limit() -> void:
	var data: MaterialSpawnData = _create_spawn()
	data.max_chapter = -1

	assert_bool(data.is_accessible(_no_flags, 1)).is_true()
	assert_bool(data.is_accessible(_no_flags, 100)).is_true()
	assert_bool(data.is_accessible(_no_flags, 9999)).is_true()


# =============================================================================
# ACCESSIBILITY TESTS - REQUIRED FLAGS
# =============================================================================

func test_accessible_required_flags_all_set() -> void:
	var data: MaterialSpawnData = _create_spawn()
	data.required_flags = ["defeated_boss", "has_key"] as Array[String]

	var checker: Callable = _flag_checker_from_list(["defeated_boss", "has_key", "other_flag"] as Array[String])

	assert_bool(data.is_accessible(checker, 1)).is_true()


func test_accessible_required_flags_some_missing() -> void:
	var data: MaterialSpawnData = _create_spawn()
	data.required_flags = ["defeated_boss", "has_key"] as Array[String]

	var checker: Callable = _flag_checker_from_list(["defeated_boss"] as Array[String])

	assert_bool(data.is_accessible(checker, 1)).is_false()


func test_accessible_required_flags_none_set() -> void:
	var data: MaterialSpawnData = _create_spawn()
	data.required_flags = ["defeated_boss"] as Array[String]

	assert_bool(data.is_accessible(_no_flags, 1)).is_false()


# =============================================================================
# ACCESSIBILITY TESTS - FORBIDDEN FLAGS (MISSABILITY)
# =============================================================================

func test_accessible_forbidden_flags_none_set() -> void:
	var data: MaterialSpawnData = _create_spawn()
	data.forbidden_flags = ["area_destroyed", "timeline_advanced"] as Array[String]

	assert_bool(data.is_accessible(_no_flags, 1)).is_true()


func test_accessible_forbidden_flags_one_set() -> void:
	var data: MaterialSpawnData = _create_spawn()
	data.forbidden_flags = ["area_destroyed", "timeline_advanced"] as Array[String]

	var checker: Callable = _flag_checker_from_list(["area_destroyed"] as Array[String])

	assert_bool(data.is_accessible(checker, 1)).is_false()


func test_accessible_forbidden_flags_creates_missability() -> void:
	# This tests the core "missability is emergent" design
	var data: MaterialSpawnData = _create_spawn()
	data.forbidden_flags = ["volcano_erupted"] as Array[String]

	# Before event: accessible
	assert_bool(data.is_accessible(_no_flags, 1)).is_true()

	# After event: missed forever
	var post_event: Callable = _flag_checker_from_list(["volcano_erupted"] as Array[String])
	assert_bool(data.is_accessible(post_event, 1)).is_false()


# =============================================================================
# ACCESSIBILITY TESTS - COMBINED CONDITIONS
# =============================================================================

func test_accessible_combined_chapter_and_flags() -> void:
	var data: MaterialSpawnData = _create_spawn()
	data.min_chapter = 2
	data.max_chapter = 5
	data.required_flags = ["temple_open"] as Array[String]
	data.forbidden_flags = ["temple_collapsed"] as Array[String]

	var has_temple_open: Callable = _flag_checker_from_list(["temple_open"] as Array[String])

	# Wrong chapter
	assert_bool(data.is_accessible(has_temple_open, 1)).is_false()

	# Right chapter, right flags
	assert_bool(data.is_accessible(has_temple_open, 3)).is_true()

	# Too late
	assert_bool(data.is_accessible(has_temple_open, 6)).is_false()

	# Right chapter, but temple collapsed
	var temple_collapsed: Callable = _flag_checker_from_list(["temple_open", "temple_collapsed"] as Array[String])
	assert_bool(data.is_accessible(temple_collapsed, 3)).is_false()


# =============================================================================
# TRIGGER ID TESTS
# =============================================================================

func test_get_trigger_id_format() -> void:
	var data: MaterialSpawnData = _create_spawn("mithril", "cave_01", "mithril_spot_1")

	var trigger_id: String = data.get_trigger_id()

	assert_str(trigger_id).is_equal("material_spawn:cave_01:mithril_spot_1")


# =============================================================================
# RESPAWN TESTS
# =============================================================================

func test_can_respawn_when_disabled() -> void:
	var data: MaterialSpawnData = _create_spawn()
	data.respawns = false

	assert_bool(data.can_respawn(_all_flags)).is_false()


func test_can_respawn_when_enabled_no_condition() -> void:
	var data: MaterialSpawnData = _create_spawn()
	data.respawns = true
	data.respawn_flag = ""

	assert_bool(data.can_respawn(_no_flags)).is_true()


func test_can_respawn_with_condition_met() -> void:
	var data: MaterialSpawnData = _create_spawn()
	data.respawns = true
	data.respawn_flag = "new_moon"

	var checker: Callable = _flag_checker_from_list(["new_moon"] as Array[String])

	assert_bool(data.can_respawn(checker)).is_true()


func test_can_respawn_with_condition_not_met() -> void:
	var data: MaterialSpawnData = _create_spawn()
	data.respawns = true
	data.respawn_flag = "new_moon"

	assert_bool(data.can_respawn(_no_flags)).is_false()


# =============================================================================
# VALIDATION TESTS
# =============================================================================

func test_validate_passes_with_required_fields() -> void:
	var data: MaterialSpawnData = _create_spawn("mithril", "cave_01", "spawn_01")

	assert_bool(data.validate()).is_true()


func test_validate_fails_without_material_id() -> void:
	var data: MaterialSpawnData = _create_spawn("", "cave_01", "spawn_01")

	assert_bool(data.validate()).is_false()


func test_validate_fails_without_map_id() -> void:
	var data: MaterialSpawnData = _create_spawn("mithril", "", "spawn_01")

	assert_bool(data.validate()).is_false()


func test_validate_fails_without_spawn_id() -> void:
	var data: MaterialSpawnData = _create_spawn("mithril", "cave_01", "")

	assert_bool(data.validate()).is_false()


func test_validate_fails_with_zero_quantity() -> void:
	var data: MaterialSpawnData = _create_spawn()
	data.quantity = 0

	assert_bool(data.validate()).is_false()


func test_validate_fails_with_invalid_chapter_range() -> void:
	var data: MaterialSpawnData = _create_spawn()
	data.min_chapter = 5
	data.max_chapter = 3

	assert_bool(data.validate()).is_false()


func test_validate_passes_with_max_chapter_minus_one() -> void:
	var data: MaterialSpawnData = _create_spawn()
	data.min_chapter = 5
	data.max_chapter = -1

	assert_bool(data.validate()).is_true()
