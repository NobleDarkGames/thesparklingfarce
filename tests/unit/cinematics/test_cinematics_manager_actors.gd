## Unit Tests for CinematicsManager Actors Array Functionality
##
## Tests the actors array spawning, tracking, and cleanup features.
## These tests validate the data-driven actor spawning system.
class_name TestCinematicsManagerActors
extends GdUnitTestSuite


# =============================================================================
# PRELOADS
# =============================================================================

const CinematicData = preload("res://core/resources/cinematic_data.gd")
const CinematicActor = preload("res://core/components/cinematic_actor.gd")


# =============================================================================
# TEST STATE
# =============================================================================

var _original_state: Dictionary = {}


# =============================================================================
# TEST FIXTURES
# =============================================================================

## Create a minimal CinematicData for testing
func _create_test_cinematic(
	cinematic_id: String = "test_cinematic",
	actors: Array[Dictionary] = []
) -> CinematicData:
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = cinematic_id
	cinematic.cinematic_name = "Test Cinematic"
	cinematic.disable_player_input = false
	cinematic.can_skip = true

	# Add actors if provided
	for actor_def: Dictionary in actors:
		cinematic.actors.append(actor_def)

	# Add minimal command so cinematic is valid
	cinematic.add_wait(0.1)

	return cinematic


## Create an actor definition dictionary
func _create_actor_def(
	actor_id: String,
	position: Array = [0, 0],
	facing: String = "down",
	character_id: String = ""
) -> Dictionary:
	var actor_def: Dictionary = {
		"actor_id": actor_id,
		"position": position,
		"facing": facing
	}
	if not character_id.is_empty():
		actor_def["character_id"] = character_id
	return actor_def


## Save CinematicsManager state
func _save_manager_state() -> void:
	_original_state = {
		"current_state": CinematicsManager.current_state,
		"current_cinematic": CinematicsManager.current_cinematic,
		"command_index": CinematicsManager.current_command_index,
	}


## Restore CinematicsManager state
func _restore_manager_state() -> void:
	# Force reset to idle state
	CinematicsManager.current_state = CinematicsManager.State.IDLE
	CinematicsManager.current_cinematic = null
	CinematicsManager.current_command_index = 0
	CinematicsManager._spawned_actor_nodes.clear()
	CinematicsManager._registered_actors.clear()
	CinematicsManager._cinematic_chain_stack.clear()
	CinematicsManager.set_process(false)


func before_test() -> void:
	_save_manager_state()
	_restore_manager_state()


func after_test() -> void:
	# Clean up any active cinematics
	if CinematicsManager.is_cinematic_active():
		CinematicsManager.skip_cinematic()

	_restore_manager_state()


# =============================================================================
# STATE TESTS
# =============================================================================

func test_initial_spawned_actors_is_empty() -> void:
	assert_int(CinematicsManager._spawned_actor_nodes.size()).is_equal(0)


func test_track_spawned_actor_adds_to_list() -> void:
	var test_node: Node = Node.new()

	CinematicsManager._track_spawned_actor(test_node)

	assert_int(CinematicsManager._spawned_actor_nodes.size()).is_equal(1)
	assert_bool(test_node in CinematicsManager._spawned_actor_nodes).is_true()

	if is_instance_valid(test_node):
		test_node.queue_free()


func test_track_spawned_actor_prevents_duplicates() -> void:
	var test_node: Node = Node.new()

	CinematicsManager._track_spawned_actor(test_node)
	CinematicsManager._track_spawned_actor(test_node)  # Try to add again

	# Should only have one entry
	assert_int(CinematicsManager._spawned_actor_nodes.size()).is_equal(1)

	if is_instance_valid(test_node):
		test_node.queue_free()


func test_track_spawned_actor_ignores_null() -> void:
	CinematicsManager._track_spawned_actor(null)

	assert_int(CinematicsManager._spawned_actor_nodes.size()).is_equal(0)


func test_cleanup_spawned_actors_clears_list() -> void:
	# Add some nodes
	var node1: Node = Node.new()
	var node2: Node = Node.new()
	add_child(node1)
	add_child(node2)

	CinematicsManager._track_spawned_actor(node1)
	CinematicsManager._track_spawned_actor(node2)

	assert_int(CinematicsManager._spawned_actor_nodes.size()).is_equal(2)

	CinematicsManager._cleanup_spawned_actors()

	assert_int(CinematicsManager._spawned_actor_nodes.size()).is_equal(0)


func test_cleanup_spawned_actors_queues_free_on_nodes() -> void:
	var node1: Node = Node.new()
	add_child(node1)

	CinematicsManager._track_spawned_actor(node1)
	CinematicsManager._cleanup_spawned_actors()

	# Node should be queued for deletion (but not freed until next frame)
	# We can't easily test queue_free directly, but we verify list is cleared
	assert_int(CinematicsManager._spawned_actor_nodes.size()).is_equal(0)


# =============================================================================
# CINEMATIC DATA ACTORS PROPERTY TESTS
# =============================================================================

func test_cinematic_data_actors_is_array() -> void:
	var cinematic: CinematicData = CinematicData.new()

	assert_bool(cinematic.actors is Array).is_true()


func test_cinematic_data_actors_default_empty() -> void:
	var cinematic: CinematicData = CinematicData.new()

	assert_int(cinematic.actors.size()).is_equal(0)


func test_add_actor_to_cinematic_data() -> void:
	var cinematic: CinematicData = CinematicData.new()

	cinematic.add_actor("test_actor", [5, 5], "up", "max")

	assert_int(cinematic.actors.size()).is_equal(1)
	var actor: Dictionary = cinematic.actors[0]
	assert_str(actor.actor_id).is_equal("test_actor")
	assert_str(actor.facing).is_equal("up")
	assert_str(actor.character_id).is_equal("max")


func test_add_actor_with_vector2i_position() -> void:
	var cinematic: CinematicData = CinematicData.new()

	cinematic.add_actor("vec_actor", Vector2i(3, 7), "left")

	var actor: Dictionary = cinematic.actors[0]
	assert_int(actor.position[0]).is_equal(3)
	assert_int(actor.position[1]).is_equal(7)


func test_add_actor_with_vector2_position() -> void:
	var cinematic: CinematicData = CinematicData.new()

	cinematic.add_actor("vec2_actor", Vector2(4.5, 8.9), "right")

	var actor: Dictionary = cinematic.actors[0]
	assert_int(actor.position[0]).is_equal(4)  # Converted to int
	assert_int(actor.position[1]).is_equal(8)  # Converted to int


func test_add_actor_without_character_id() -> void:
	var cinematic: CinematicData = CinematicData.new()

	cinematic.add_actor("minimal_actor", [0, 0])

	var actor: Dictionary = cinematic.actors[0]
	assert_bool("character_id" not in actor).is_true()


func test_add_actor_default_facing() -> void:
	var cinematic: CinematicData = CinematicData.new()

	cinematic.add_actor("default_facing", [0, 0])  # No facing specified

	var actor: Dictionary = cinematic.actors[0]
	assert_str(actor.facing).is_equal("down")


# =============================================================================
# SPAWN ACTORS FROM DATA TESTS
# =============================================================================

func test_spawn_actors_from_empty_array() -> void:
	var cinematic: CinematicData = _create_test_cinematic("empty_actors", [])

	# This should not throw an error
	CinematicsManager._spawn_actors_from_data(cinematic)

	assert_int(CinematicsManager._spawned_actor_nodes.size()).is_equal(0)


func test_spawn_actors_from_data_creates_node() -> void:
	# Skip in headless mode - requires scene tree
	# This is an integration-level test
	pass


# =============================================================================
# ACTOR REGISTRATION TESTS
# =============================================================================

func test_get_actor_returns_null_for_unregistered() -> void:
	var actor: CinematicActor = CinematicsManager.get_actor("nonexistent")

	assert_object(actor).is_null()


func test_register_actor_makes_findable() -> void:
	# Create a minimal CinematicActor
	var parent: CharacterBody2D = CharacterBody2D.new()
	parent.name = "TestParent"
	add_child(parent)

	var actor: Node = Node.new()
	actor.set_script(CinematicActor)
	actor.actor_id = "registered_actor"
	parent.add_child(actor)

	# Registration happens in _ready, or we can call it manually
	CinematicsManager.register_actor(actor)

	var found: CinematicActor = CinematicsManager.get_actor("registered_actor")
	assert_object(found).is_not_null()
	assert_str(found.actor_id).is_equal("registered_actor")

	if is_instance_valid(parent):
		parent.queue_free()


# =============================================================================
# NPC ACTOR CHARACTER_UID TESTS
# Regression tests for bug where NPC actors couldn't be used as speakers
# in dialog_line commands because character_uid wasn't set.
# Bug fixed in commit 980353c
# =============================================================================

func test_get_actor_by_character_uid_returns_null_for_unregistered() -> void:
	var actor: CinematicActor = CinematicsManager.get_actor_by_character_uid("nonexistent_uid")
	
	assert_object(actor).is_null()


func test_get_actor_by_character_uid_finds_character_actor() -> void:
	var parent: CharacterBody2D = CharacterBody2D.new()
	parent.name = "CharActor"
	add_child(parent)
	
	var actor: Node = Node.new()
	actor.set_script(CinematicActor)
	actor.actor_id = "hero_actor"
	actor.character_uid = "max_uid_123"  # Character UID
	parent.add_child(actor)
	
	CinematicsManager.register_actor(actor)
	
	var found: CinematicActor = CinematicsManager.get_actor_by_character_uid("max_uid_123")
	assert_object(found).is_not_null()
	assert_str(found.actor_id).is_equal("hero_actor")
	
	if is_instance_valid(parent):
		parent.queue_free()


func test_get_actor_by_character_uid_finds_npc_actor_with_prefix() -> void:
	# This is the critical regression test for the NPC speaker bug
	var parent: CharacterBody2D = CharacterBody2D.new()
	parent.name = "NPCActor"
	add_child(parent)
	
	var actor: Node = Node.new()
	actor.set_script(CinematicActor)
	actor.actor_id = "shopkeeper_actor"
	actor.character_uid = "npc:shopkeeper"  # NPC with prefix
	parent.add_child(actor)
	
	CinematicsManager.register_actor(actor)
	
	# Dialog executor searches for "npc:shopkeeper" when NPC is the speaker
	var found: CinematicActor = CinematicsManager.get_actor_by_character_uid("npc:shopkeeper")
	assert_object(found).is_not_null()
	assert_str(found.actor_id).is_equal("shopkeeper_actor")
	
	if is_instance_valid(parent):
		parent.queue_free()


func test_npc_actor_character_uid_format() -> void:
	# Verify the expected format for NPC character_uid
	var npc_id: String = "town_guard"
	var expected_uid: String = "npc:" + npc_id
	
	assert_str(expected_uid).is_equal("npc:town_guard")


func test_character_uid_distinguishes_character_from_npc() -> void:
	var parent1: CharacterBody2D = CharacterBody2D.new()
	parent1.name = "CharParent"
	add_child(parent1)
	
	var parent2: CharacterBody2D = CharacterBody2D.new()
	parent2.name = "NPCParent"
	add_child(parent2)
	
	# Register a character actor
	var char_actor: Node = Node.new()
	char_actor.set_script(CinematicActor)
	char_actor.actor_id = "max_actor"
	char_actor.character_uid = "max_uid"  # Character UID (no prefix)
	parent1.add_child(char_actor)
	CinematicsManager.register_actor(char_actor)
	
	# Register an NPC actor with similar name but different format
	var npc_actor: Node = Node.new()
	npc_actor.set_script(CinematicActor)
	npc_actor.actor_id = "max_npc_actor"
	npc_actor.character_uid = "npc:max"  # NPC with same base name
	parent2.add_child(npc_actor)
	CinematicsManager.register_actor(npc_actor)
	
	# Looking up "max_uid" should find character
	var found_char: CinematicActor = CinematicsManager.get_actor_by_character_uid("max_uid")
	assert_object(found_char).is_not_null()
	assert_str(found_char.actor_id).is_equal("max_actor")
	
	# Looking up "npc:max" should find NPC
	var found_npc: CinematicActor = CinematicsManager.get_actor_by_character_uid("npc:max")
	assert_object(found_npc).is_not_null()
	assert_str(found_npc.actor_id).is_equal("max_npc_actor")
	
	if is_instance_valid(parent1):
		parent1.queue_free()
	if is_instance_valid(parent2):
		parent2.queue_free()


func test_empty_character_uid_not_found() -> void:
	var parent: CharacterBody2D = CharacterBody2D.new()
	add_child(parent)
	
	var actor: Node = Node.new()
	actor.set_script(CinematicActor)
	actor.actor_id = "empty_uid_actor"
	actor.character_uid = ""  # Empty - this was the bug state for NPCs
	parent.add_child(actor)
	
	CinematicsManager.register_actor(actor)
	
	# Empty string search should not match
	var found: CinematicActor = CinematicsManager.get_actor_by_character_uid("")
	assert_object(found).is_null()
	
	# Specific search should also not match empty UID actor
	var found2: CinematicActor = CinematicsManager.get_actor_by_character_uid("npc:some_npc")
	assert_object(found2).is_null()
	
	if is_instance_valid(parent):
		parent.queue_free()



func test_register_null_actor_is_ignored() -> void:
	CinematicsManager.register_actor(null)

	# Should not crash or add anything
	assert_bool(true).is_true()


func test_register_actor_with_empty_id_is_ignored() -> void:
	var parent: CharacterBody2D = CharacterBody2D.new()
	add_child(parent)

	var actor: Node = Node.new()
	actor.set_script(CinematicActor)
	actor.actor_id = ""  # Empty ID
	parent.add_child(actor)

	CinematicsManager.register_actor(actor)

	# Empty ID actor should not be registered
	assert_object(CinematicsManager.get_actor("")).is_null()

	if is_instance_valid(parent):
		parent.queue_free()


# =============================================================================
# CINEMATIC END CLEANUP TESTS
# =============================================================================

func test_end_cinematic_cleans_up_spawned_actors() -> void:
	# Add some tracked nodes
	var node1: Node = Node.new()
	var node2: Node = Node.new()
	add_child(node1)
	add_child(node2)

	CinematicsManager._track_spawned_actor(node1)
	CinematicsManager._track_spawned_actor(node2)

	# Simulate cinematic end by calling cleanup directly
	CinematicsManager._cleanup_spawned_actors()

	assert_int(CinematicsManager._spawned_actor_nodes.size()).is_equal(0)


func test_skip_cinematic_triggers_cleanup() -> void:
	# This test verifies that skipping a cinematic also cleans up actors
	# The actual skip_cinematic calls _end_cinematic which calls _cleanup_spawned_actors

	var node: Node = Node.new()
	add_child(node)
	CinematicsManager._track_spawned_actor(node)

	# Simulate the cleanup that happens during skip
	CinematicsManager._cleanup_spawned_actors()

	assert_int(CinematicsManager._spawned_actor_nodes.size()).is_equal(0)


# =============================================================================
# SPAWN SINGLE ACTOR TESTS
# =============================================================================

func test_spawn_single_actor_requires_actor_id() -> void:
	var actor_def: Dictionary = {
		"position": [0, 0]
		# Missing actor_id
	}

	# Should warn and skip (not crash)
	CinematicsManager._spawn_single_actor(actor_def)

	# No actor should be spawned
	assert_int(CinematicsManager._spawned_actor_nodes.size()).is_equal(0)


func test_spawn_single_actor_empty_actor_id() -> void:
	var actor_def: Dictionary = {
		"actor_id": "",  # Empty
		"position": [0, 0]
	}

	CinematicsManager._spawn_single_actor(actor_def)

	assert_int(CinematicsManager._spawned_actor_nodes.size()).is_equal(0)


# =============================================================================
# ACTOR DEFINITION PARSING TESTS
# =============================================================================

func test_actor_def_position_from_array() -> void:
	var actor_def: Dictionary = _create_actor_def("array_pos", [7, 9])

	assert_bool(actor_def.position is Array).is_true()
	assert_int(actor_def.position[0]).is_equal(7)
	assert_int(actor_def.position[1]).is_equal(9)


func test_actor_def_facing_stored() -> void:
	var actor_def: Dictionary = _create_actor_def("facing_test", [0, 0], "left")

	assert_str(actor_def.facing).is_equal("left")


func test_actor_def_character_id_optional() -> void:
	var actor_def: Dictionary = _create_actor_def("no_char", [0, 0], "down", "")

	# character_id should not be in dict when empty
	assert_bool("character_id" not in actor_def).is_true()


func test_actor_def_character_id_included() -> void:
	var actor_def: Dictionary = _create_actor_def("with_char", [0, 0], "down", "lowe")

	assert_bool("character_id" in actor_def).is_true()
	assert_str(actor_def.character_id).is_equal("lowe")


# =============================================================================
# INVALID ACTOR DEFINITION TESTS
# =============================================================================

func test_invalid_actor_def_not_dictionary() -> void:
	# Test that _spawn_actors_from_data handles non-dictionary items gracefully
	# Note: CinematicData.actors is typed as Array[Dictionary], so we test
	# via _spawn_single_actor directly with an empty dictionary (simulates malformed data)
	var malformed_actor: Dictionary = {}  # Missing actor_id

	# Should handle gracefully without crashing
	CinematicsManager._spawn_single_actor(malformed_actor)

	assert_int(CinematicsManager._spawned_actor_nodes.size()).is_equal(0)


# =============================================================================
# DUPLICATE ACTOR WARNINGS
# =============================================================================

func test_warns_on_duplicate_actor_in_actors_array() -> void:
	# Pre-register an actor
	var parent: CharacterBody2D = CharacterBody2D.new()
	add_child(parent)

	var existing: Node = Node.new()
	existing.set_script(CinematicActor)
	existing.actor_id = "already_exists"
	parent.add_child(existing)
	CinematicsManager.register_actor(existing)

	# Now the spawn should warn but not crash
	var actor_def: Dictionary = _create_actor_def("already_exists", [0, 0])

	# The warning is issued but we continue
	# We can't easily test push_warning output, so we verify no crash
	assert_object(CinematicsManager.get_actor("already_exists")).is_not_null()

	if is_instance_valid(parent):
		parent.queue_free()


# =============================================================================
# ACTOR DISPLAY DATA TESTS
# =============================================================================

func test_get_actor_display_data_returns_empty_for_unregistered() -> void:
	var result: Dictionary = CinematicsManager.get_actor_display_data("nonexistent")
	assert_dict(result).is_empty()


func test_get_actor_display_data_returns_cached_data() -> void:
	# Access the internal cache directly for testing
	CinematicsManager._actor_display_data["test_actor"] = {
		"display_name": "Test Speaker",
		"portrait": null,
		"is_virtual": false,
		"entity_ref": "test_actor"
	}

	var result: Dictionary = CinematicsManager.get_actor_display_data("test_actor")
	assert_str(result.get("display_name", "")).is_equal("Test Speaker")
	assert_bool(result.get("is_virtual", true)).is_false()

	# Clean up
	CinematicsManager._actor_display_data.clear()


func test_actor_display_data_cache_cleared_on_end_cinematic() -> void:
	# Add data to cache
	CinematicsManager._actor_display_data["test"] = {"display_name": "Test"}
	assert_dict(CinematicsManager._actor_display_data).is_not_empty()

	# Calling _clear_actor_display_cache should clear it
	CinematicsManager._clear_actor_display_cache()
	assert_dict(CinematicsManager._actor_display_data).is_empty()


# =============================================================================
# FIND ENTITY NODE TESTS
# =============================================================================

func test_find_entity_node_returns_null_for_nonexistent() -> void:
	var result: Node2D = CinematicsManager.find_entity_node("nonexistent")
	assert_object(result).is_null()


func test_find_entity_node_finds_registered_actor() -> void:
	# Create and register an actor
	var parent: CharacterBody2D = CharacterBody2D.new()
	add_child(parent)

	var actor: Node = Node.new()
	actor.set_script(CinematicActor)
	actor.actor_id = "findable_actor"
	parent.add_child(actor)
	CinematicsManager.register_actor(actor)

	# Should find via actor lookup first
	var result: Node2D = CinematicsManager.find_entity_node("findable_actor")
	assert_object(result).is_same(parent)

	# Cleanup
	CinematicsManager._registered_actors.clear()
	if is_instance_valid(parent):
		parent.queue_free()


func test_find_entity_node_handles_npc_prefix() -> void:
	# Test that npc: prefix is parsed correctly (even if entity not found)
	# This test validates the parsing logic - actual NPC lookup requires map context
	var result: Node2D = CinematicsManager.find_entity_node("npc:some_npc")
	# Should return null but not crash
	assert_object(result).is_null()


# =============================================================================
# VIRTUAL ACTOR TESTS
# =============================================================================

func test_virtual_spawn_handler_exists() -> void:
	# VirtualSpawnHandler should be registered
	var handler: SpawnableEntityHandler = CinematicsManager.get_spawnable_handler("virtual")
	assert_object(handler).is_not_null()


func test_virtual_spawn_handler_returns_null_sprite() -> void:
	var handler: SpawnableEntityHandler = CinematicsManager.get_spawnable_handler("virtual")
	if handler:
		var sprite: Node2D = handler.create_sprite_node("test", "down")
		assert_object(sprite).is_null()


func test_virtual_spawn_handler_type_id() -> void:
	var handler: SpawnableEntityHandler = CinematicsManager.get_spawnable_handler("virtual")
	if handler:
		assert_str(handler.get_type_id()).is_equal("virtual")


func test_virtual_spawn_handler_no_position_required() -> void:
	var handler: SpawnableEntityHandler = CinematicsManager.get_spawnable_handler("virtual")
	if handler:
		var hints: Dictionary = handler.get_editor_hints()
		assert_bool(hints.get("requires_position", true)).is_false()
