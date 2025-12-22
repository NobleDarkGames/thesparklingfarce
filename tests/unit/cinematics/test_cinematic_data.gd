## Unit Tests for CinematicData
##
## Tests cinematic data validation, command construction, and actors array handling.
## Pure resource tests - no scene dependencies.
class_name TestCinematicData
extends GdUnitTestSuite


# =============================================================================
# PRELOADS
# =============================================================================

const CinematicData: GDScript = preload("res://core/resources/cinematic_data.gd")


# =============================================================================
# TEST FIXTURES
# =============================================================================

## Create a minimal valid CinematicData
func _create_test_cinematic(cinematic_id: String = "test_cinematic") -> CinematicData:
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = cinematic_id
	cinematic.cinematic_name = "Test Cinematic"
	cinematic.add_wait(0.1)  # At least one command required
	return cinematic


# =============================================================================
# VALIDATION TESTS
# =============================================================================

func test_validate_requires_cinematic_id() -> void:
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = ""  # Empty ID
	cinematic.add_wait(0.1)

	var result: bool = cinematic.validate()

	assert_bool(result).is_false()


func test_validate_requires_commands() -> void:
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = "test"
	# No commands added

	var result: bool = cinematic.validate()

	assert_bool(result).is_false()


func test_validate_passes_with_id_and_commands() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	var result: bool = cinematic.validate()

	assert_bool(result).is_true()


func test_validate_command_requires_type() -> void:
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = "test"
	# Add malformed command (missing type)
	cinematic.commands.append({"params": {}})

	var result: bool = cinematic.validate()

	assert_bool(result).is_false()


func test_validate_command_requires_params() -> void:
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = "test"
	# Add malformed command (missing params)
	cinematic.commands.append({"type": "wait"})

	var result: bool = cinematic.validate()

	assert_bool(result).is_false()


# =============================================================================
# ACTORS ARRAY TESTS
# =============================================================================

func test_actors_default_empty() -> void:
	var cinematic: CinematicData = CinematicData.new()

	assert_int(cinematic.actors.size()).is_equal(0)


func test_add_actor_basic() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_actor("npc_001", [5, 10], "down")

	assert_int(cinematic.actors.size()).is_equal(1)
	var actor: Dictionary = cinematic.actors[0]
	assert_str(actor.actor_id).is_equal("npc_001")
	assert_int(actor.position[0]).is_equal(5)
	assert_int(actor.position[1]).is_equal(10)
	assert_str(actor.facing).is_equal("down")


func test_add_actor_with_character_id() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_actor("hero", [0, 0], "right", "max")

	var actor: Dictionary = cinematic.actors[0]
	assert_str(actor.character_id).is_equal("max")


func test_add_actor_without_character_id() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_actor("generic", [0, 0], "up")

	var actor: Dictionary = cinematic.actors[0]
	assert_bool("character_id" not in actor).is_true()


func test_add_actor_vector2i_position() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_actor("vec2i_actor", Vector2i(7, 3), "left")

	var actor: Dictionary = cinematic.actors[0]
	assert_int(actor.position[0]).is_equal(7)
	assert_int(actor.position[1]).is_equal(3)


func test_add_actor_vector2_position_converts() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_actor("vec2_actor", Vector2(4.7, 8.2), "down")

	var actor: Dictionary = cinematic.actors[0]
	# Should truncate to int
	assert_int(actor.position[0]).is_equal(4)
	assert_int(actor.position[1]).is_equal(8)


func test_add_multiple_actors() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_actor("actor_a", [1, 1], "up")
	cinematic.add_actor("actor_b", [2, 2], "down")
	cinematic.add_actor("actor_c", [3, 3], "left")

	assert_int(cinematic.actors.size()).is_equal(3)


func test_add_actor_default_facing() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_actor("default_face", [0, 0])  # No facing specified

	var actor: Dictionary = cinematic.actors[0]
	assert_str(actor.facing).is_equal("down")


# =============================================================================
# SPAWN ENTITY COMMAND TESTS
# =============================================================================

func test_add_spawn_entity_creates_command() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_spawn_entity("dynamic_npc", Vector2(5, 5), "up")

	# Last command should be spawn_entity (wait was first)
	assert_int(cinematic.commands.size()).is_greater(1)
	var cmd: Dictionary = cinematic.commands[cinematic.commands.size() - 1]
	assert_str(cmd.type).is_equal("spawn_entity")
	assert_str(cmd.params.actor_id).is_equal("dynamic_npc")
	assert_str(cmd.params.facing).is_equal("up")


func test_add_spawn_entity_default_facing() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_spawn_entity("npc", Vector2(0, 0))

	var cmd: Dictionary = cinematic.commands[cinematic.commands.size() - 1]
	assert_str(cmd.params.facing).is_equal("down")


# =============================================================================
# DESPAWN ENTITY COMMAND TESTS
# =============================================================================

func test_add_despawn_entity_creates_command() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_despawn_entity("npc_to_remove")

	var cmd: Dictionary = cinematic.commands[cinematic.commands.size() - 1]
	assert_str(cmd.type).is_equal("despawn_entity")
	assert_str(cmd.target).is_equal("npc_to_remove")


# =============================================================================
# MOVE ENTITY COMMAND TESTS
# =============================================================================

func test_add_move_entity_creates_command() -> void:
	var cinematic: CinematicData = _create_test_cinematic()
	var path: Array = [[5, 5], [6, 5], [7, 5]]

	cinematic.add_move_entity("hero", path, 3.0, true)

	var cmd: Dictionary = cinematic.commands[cinematic.commands.size() - 1]
	assert_str(cmd.type).is_equal("move_entity")
	assert_str(cmd.target).is_equal("hero")
	assert_array(cmd.params.path).is_equal(path)
	assert_float(cmd.params.speed).is_equal(3.0)
	assert_bool(cmd.params.wait).is_true()


func test_add_move_entity_default_wait() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_move_entity("npc", [[0, 0], [1, 1]])

	var cmd: Dictionary = cinematic.commands[cinematic.commands.size() - 1]
	assert_bool(cmd.params.wait).is_true()


# =============================================================================
# SET FACING COMMAND TESTS
# =============================================================================

func test_add_set_facing_creates_command() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_set_facing("hero", "left")

	var cmd: Dictionary = cinematic.commands[cinematic.commands.size() - 1]
	assert_str(cmd.type).is_equal("set_facing")
	assert_str(cmd.target).is_equal("hero")
	assert_str(cmd.params.direction).is_equal("left")


# =============================================================================
# WAIT COMMAND TESTS
# =============================================================================

func test_add_wait_creates_command() -> void:
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = "test"

	cinematic.add_wait(2.5)

	var cmd: Dictionary = cinematic.commands[0]
	assert_str(cmd.type).is_equal("wait")
	assert_float(cmd.params.duration).is_equal(2.5)


# =============================================================================
# DIALOG COMMAND TESTS
# =============================================================================

func test_add_dialog_line_creates_command() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_dialog_line("Max", "Hello, world!", "happy")

	var cmd: Dictionary = cinematic.commands[cinematic.commands.size() - 1]
	assert_str(cmd.type).is_equal("show_dialog")
	assert_int(cmd.params.lines.size()).is_equal(1)
	var line: Dictionary = cmd.params.lines[0]
	assert_str(line.speaker_name).is_equal("Max")
	assert_str(line.text).is_equal("Hello, world!")
	assert_str(line.emotion).is_equal("happy")


func test_add_dialog_line_default_emotion() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_dialog_line("NPC", "Text")

	var cmd: Dictionary = cinematic.commands[cinematic.commands.size() - 1]
	var line: Dictionary = cmd.params.lines[0]
	assert_str(line.emotion).is_equal("neutral")


func test_add_show_dialog_creates_command() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_show_dialog("intro_dialogue")

	var cmd: Dictionary = cinematic.commands[cinematic.commands.size() - 1]
	assert_str(cmd.type).is_equal("show_dialog")
	assert_str(cmd.params.dialogue_id).is_equal("intro_dialogue")


# =============================================================================
# CAMERA COMMAND TESTS
# =============================================================================

func test_add_camera_move_creates_command() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_camera_move(Vector2(100, 200), 2.0, true)

	var cmd: Dictionary = cinematic.commands[cinematic.commands.size() - 1]
	assert_str(cmd.type).is_equal("camera_move")
	assert_vector(cmd.params.target_pos).is_equal(Vector2(100, 200))
	assert_float(cmd.params.speed).is_equal(2.0)
	assert_bool(cmd.params.wait).is_true()


func test_add_camera_follow_creates_command() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_camera_follow("hero")

	var cmd: Dictionary = cinematic.commands[cinematic.commands.size() - 1]
	assert_str(cmd.type).is_equal("camera_follow")
	assert_str(cmd.target).is_equal("hero")


func test_add_camera_shake_creates_command() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_camera_shake(10.0, 0.8, 25.0, true)

	var cmd: Dictionary = cinematic.commands[cinematic.commands.size() - 1]
	assert_str(cmd.type).is_equal("camera_shake")
	assert_float(cmd.params.intensity).is_equal(10.0)
	assert_float(cmd.params.duration).is_equal(0.8)
	assert_float(cmd.params.frequency).is_equal(25.0)
	assert_bool(cmd.params.wait).is_true()


func test_add_camera_shake_defaults() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_camera_shake()

	var cmd: Dictionary = cinematic.commands[cinematic.commands.size() - 1]
	assert_float(cmd.params.intensity).is_equal(6.0)
	assert_float(cmd.params.duration).is_equal(0.5)
	assert_float(cmd.params.frequency).is_equal(30.0)
	assert_bool(cmd.params.wait).is_false()


# =============================================================================
# FLOW CONTROL TESTS
# =============================================================================

func test_get_command_valid_index() -> void:
	var cinematic: CinematicData = _create_test_cinematic()
	cinematic.add_wait(1.0)

	var cmd: Dictionary = cinematic.get_command(0)

	assert_bool(cmd.is_empty()).is_false()
	assert_str(cmd.type).is_equal("wait")


func test_get_command_invalid_index() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	var cmd: Dictionary = cinematic.get_command(999)

	assert_bool(cmd.is_empty()).is_true()


func test_get_command_negative_index() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	var cmd: Dictionary = cinematic.get_command(-1)

	assert_bool(cmd.is_empty()).is_true()


func test_get_command_count() -> void:
	var cinematic: CinematicData = _create_test_cinematic()
	cinematic.add_wait(1.0)
	cinematic.add_wait(2.0)

	var count: int = cinematic.get_command_count()

	assert_int(count).is_equal(3)  # Original wait + 2 new


func test_has_next_false_by_default() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	assert_bool(cinematic.has_next()).is_false()


func test_has_next_true_when_set() -> void:
	var cinematic: CinematicData = _create_test_cinematic()
	cinematic.next_cinematic = _create_test_cinematic("next")

	assert_bool(cinematic.has_next()).is_true()


# =============================================================================
# PARTY MANAGEMENT COMMAND TESTS
# =============================================================================

func test_add_party_member_creates_command() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_party_member("lowe", true, "chapter_1")

	var cmd: Dictionary = cinematic.commands[cinematic.commands.size() - 1]
	assert_str(cmd.type).is_equal("add_party_member")
	assert_str(cmd.params.character_id).is_equal("lowe")
	assert_bool(cmd.params.to_active).is_true()
	assert_str(cmd.params.recruitment_chapter).is_equal("chapter_1")


func test_remove_party_member_creates_command() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.remove_party_member("casualty", "died", true, false)

	var cmd: Dictionary = cinematic.commands[cinematic.commands.size() - 1]
	assert_str(cmd.type).is_equal("remove_party_member")
	assert_str(cmd.params.character_id).is_equal("casualty")
	assert_str(cmd.params.reason).is_equal("died")
	assert_bool(cmd.params.mark_dead).is_true()
	assert_bool(cmd.params.mark_unavailable).is_false()


func test_rejoin_party_member_creates_command() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.rejoin_party_member("returning_hero", false, true)

	var cmd: Dictionary = cinematic.commands[cinematic.commands.size() - 1]
	assert_str(cmd.type).is_equal("rejoin_party_member")
	assert_str(cmd.params.character_id).is_equal("returning_hero")
	assert_bool(cmd.params.to_active).is_false()
	assert_bool(cmd.params.resurrect).is_true()


# =============================================================================
# SHOP COMMAND TESTS
# =============================================================================

func test_add_open_shop_creates_command() -> void:
	var cinematic: CinematicData = _create_test_cinematic()

	cinematic.add_open_shop("weapon_shop")

	var cmd: Dictionary = cinematic.commands[cinematic.commands.size() - 1]
	assert_str(cmd.type).is_equal("open_shop")
	assert_str(cmd.params.shop_id).is_equal("weapon_shop")
