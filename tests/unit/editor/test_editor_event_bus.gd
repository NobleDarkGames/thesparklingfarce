## Unit Tests for EditorEventBus
##
## Tests the centralized event system for the Sparkling Editor.
## Verifies signal emission, convenience methods, and debouncing behavior.
class_name TestEditorEventBus
extends GdUnitTestSuite


# =============================================================================
# TEST CONSTANTS
# =============================================================================

const TEST_MOD_ID: String = "_test_editor_event_bus"


# =============================================================================
# TEST FIXTURES
# =============================================================================

var _event_bus: Node


func before_test() -> void:
	# Create a fresh event bus for each test
	var EditorEventBusScript: GDScript = load("res://addons/sparkling_editor/editor_event_bus.gd")
	_event_bus = EditorEventBusScript.new()
	# Add to tree so _ready() is called and timer is created
	add_child(_event_bus)


func after_test() -> void:
	if _event_bus and is_instance_valid(_event_bus):
		_event_bus.queue_free()
	_event_bus = null


# =============================================================================
# SIGNAL PRESENCE TESTS
# =============================================================================

func test_resource_saved_signal_exists() -> void:
	assert_bool(_event_bus.has_signal("resource_saved")).is_true()


func test_resource_created_signal_exists() -> void:
	assert_bool(_event_bus.has_signal("resource_created")).is_true()


func test_resource_deleted_signal_exists() -> void:
	assert_bool(_event_bus.has_signal("resource_deleted")).is_true()


func test_active_mod_changed_signal_exists() -> void:
	assert_bool(_event_bus.has_signal("active_mod_changed")).is_true()


func test_mods_reloaded_signal_exists() -> void:
	assert_bool(_event_bus.has_signal("mods_reloaded")).is_true()


# =============================================================================
# RESOURCE_SAVED SIGNAL TESTS
# =============================================================================

var _saved_type: String = ""
var _saved_id: String = ""
var _saved_resource: Resource = null


func _on_resource_saved(res_type: String, res_id: String, resource: Resource) -> void:
	_saved_type = res_type
	_saved_id = res_id
	_saved_resource = resource


func test_resource_saved_emits_with_correct_parameters() -> void:
	_saved_type = ""
	_saved_id = ""
	_saved_resource = null

	_event_bus.resource_saved.connect(_on_resource_saved)

	var test_resource: Resource = Resource.new()
	_event_bus.resource_saved.emit("character", "hero", test_resource)

	assert_str(_saved_type).is_equal("character")
	assert_str(_saved_id).is_equal("hero")
	assert_object(_saved_resource).is_same(test_resource)


func test_notify_resource_saved_extracts_id_from_path() -> void:
	_saved_type = ""
	_saved_id = ""
	_saved_resource = null

	_event_bus.resource_saved.connect(_on_resource_saved)

	var test_resource: Resource = Resource.new()
	_event_bus.notify_resource_saved("character", "res://mods/" + TEST_MOD_ID + "/data/characters/hero.tres", test_resource)

	assert_str(_saved_type).is_equal("character")
	assert_str(_saved_id).is_equal("hero")
	assert_object(_saved_resource).is_same(test_resource)


func test_notify_resource_saved_handles_nested_paths() -> void:
	_saved_type = ""
	_saved_id = ""

	_event_bus.resource_saved.connect(_on_resource_saved)

	var test_resource: Resource = Resource.new()
	_event_bus.notify_resource_saved("item", "res://mods/expansion/data/items/weapons/legendary_sword.tres", test_resource)

	assert_str(_saved_type).is_equal("item")
	assert_str(_saved_id).is_equal("legendary_sword")


# =============================================================================
# RESOURCE_CREATED SIGNAL TESTS
# =============================================================================

var _created_type: String = ""
var _created_id: String = ""
var _created_resource: Resource = null


func _on_resource_created(res_type: String, res_id: String, resource: Resource) -> void:
	_created_type = res_type
	_created_id = res_id
	_created_resource = resource


func test_resource_created_emits_with_correct_parameters() -> void:
	_created_type = ""
	_created_id = ""
	_created_resource = null

	_event_bus.resource_created.connect(_on_resource_created)

	var test_resource: Resource = Resource.new()
	_event_bus.resource_created.emit("ability", "fireball", test_resource)

	assert_str(_created_type).is_equal("ability")
	assert_str(_created_id).is_equal("fireball")
	assert_object(_created_resource).is_same(test_resource)


func test_notify_resource_created_extracts_id_from_path() -> void:
	_created_type = ""
	_created_id = ""
	_created_resource = null

	_event_bus.resource_created.connect(_on_resource_created)

	var test_resource: Resource = Resource.new()
	_event_bus.notify_resource_created("class", "res://mods/_sandbox/data/classes/knight.tres", test_resource)

	assert_str(_created_type).is_equal("class")
	assert_str(_created_id).is_equal("knight")
	assert_object(_created_resource).is_same(test_resource)


# =============================================================================
# RESOURCE_DELETED SIGNAL TESTS
# =============================================================================

var _deleted_type: String = ""
var _deleted_id: String = ""


func _on_resource_deleted(res_type: String, res_id: String) -> void:
	_deleted_type = res_type
	_deleted_id = res_id


func test_resource_deleted_emits_with_correct_parameters() -> void:
	_deleted_type = ""
	_deleted_id = ""

	_event_bus.resource_deleted.connect(_on_resource_deleted)

	_event_bus.resource_deleted.emit("dialogue", "intro_scene")

	assert_str(_deleted_type).is_equal("dialogue")
	assert_str(_deleted_id).is_equal("intro_scene")


func test_notify_resource_deleted_extracts_id_from_path() -> void:
	_deleted_type = ""
	_deleted_id = ""

	_event_bus.resource_deleted.connect(_on_resource_deleted)

	_event_bus.notify_resource_deleted("battle", "res://mods/" + TEST_MOD_ID + "/data/battles/final_boss.tres")

	assert_str(_deleted_type).is_equal("battle")
	assert_str(_deleted_id).is_equal("final_boss")


# =============================================================================
# ACTIVE_MOD_CHANGED SIGNAL TESTS
# =============================================================================

var _changed_mod_id: String = ""


func _on_active_mod_changed(mod_id: String) -> void:
	_changed_mod_id = mod_id


func test_active_mod_changed_emits_with_mod_id() -> void:
	_changed_mod_id = ""

	_event_bus.active_mod_changed.connect(_on_active_mod_changed)

	_event_bus.active_mod_changed.emit("my_custom_mod")

	assert_str(_changed_mod_id).is_equal("my_custom_mod")


func test_active_mod_changed_handles_empty_mod_id() -> void:
	_changed_mod_id = "placeholder"

	_event_bus.active_mod_changed.connect(_on_active_mod_changed)

	_event_bus.active_mod_changed.emit("")

	assert_str(_changed_mod_id).is_equal("")


# =============================================================================
# MODS_RELOADED SIGNAL TESTS
# =============================================================================

var _mods_reloaded_count: int = 0


func _on_mods_reloaded() -> void:
	_mods_reloaded_count += 1


func test_mods_reloaded_emits() -> void:
	_mods_reloaded_count = 0

	_event_bus.mods_reloaded.connect(_on_mods_reloaded)

	_event_bus.mods_reloaded.emit()

	assert_int(_mods_reloaded_count).is_equal(1)


# =============================================================================
# DEBOUNCING TESTS
# =============================================================================

func test_notify_mods_reloaded_debounced_sets_pending_flag() -> void:
	_event_bus.notify_mods_reloaded_debounced()

	assert_bool(_event_bus._mods_reloaded_pending).is_true()


func test_debounce_timer_created_on_ready() -> void:
	assert_object(_event_bus._debounce_timer).is_not_null()
	assert_bool(_event_bus._debounce_timer.one_shot).is_true()


func test_multiple_debounced_calls_result_in_single_emission() -> void:
	_mods_reloaded_count = 0
	_event_bus.mods_reloaded.connect(_on_mods_reloaded)

	# Call debounced method multiple times rapidly
	_event_bus.notify_mods_reloaded_debounced()
	_event_bus.notify_mods_reloaded_debounced()
	_event_bus.notify_mods_reloaded_debounced()

	# Pending should be true
	assert_bool(_event_bus._mods_reloaded_pending).is_true()

	# Wait for debounce timer to fire
	await await_millis(150)

	# Should have only emitted once
	assert_int(_mods_reloaded_count).is_equal(1)
	assert_bool(_event_bus._mods_reloaded_pending).is_false()


func test_debounce_delay_constant_is_reasonable() -> void:
	# Debounce delay should be between 50ms and 500ms for responsive UX
	assert_float(_event_bus.DEBOUNCE_DELAY_MS).is_greater_equal(50.0)
	assert_float(_event_bus.DEBOUNCE_DELAY_MS).is_less_equal(500.0)


# =============================================================================
# ID EXTRACTION EDGE CASES
# =============================================================================

func test_notify_handles_path_with_no_extension() -> void:
	_saved_type = ""
	_saved_id = ""

	_event_bus.resource_saved.connect(_on_resource_saved)

	var test_resource: Resource = Resource.new()
	# Unusual case: path with no extension
	_event_bus.notify_resource_saved("test", "res://mods/test/data/items/no_extension", test_resource)

	# get_file().get_basename() should return the full filename
	assert_str(_saved_id).is_equal("no_extension")


func test_notify_handles_path_with_multiple_dots() -> void:
	_saved_type = ""
	_saved_id = ""

	_event_bus.resource_saved.connect(_on_resource_saved)

	var test_resource: Resource = Resource.new()
	# Path with multiple dots in filename
	_event_bus.notify_resource_saved("test", "res://mods/test/data/items/item.v2.tres", test_resource)

	# get_basename() returns "item.v2" (strips only last extension)
	assert_str(_saved_id).is_equal("item.v2")


func test_notify_handles_simple_filename() -> void:
	_deleted_type = ""
	_deleted_id = ""

	_event_bus.resource_deleted.connect(_on_resource_deleted)

	# Just a filename, no path
	_event_bus.notify_resource_deleted("test", "simple_file.tres")

	assert_str(_deleted_id).is_equal("simple_file")


# =============================================================================
# MULTIPLE LISTENERS TESTS
# =============================================================================

var _listener_a_count: int = 0
var _listener_b_count: int = 0


func _listener_a(_type: String, _id: String, _res: Resource) -> void:
	_listener_a_count += 1


func _listener_b(_type: String, _id: String, _res: Resource) -> void:
	_listener_b_count += 1


func test_multiple_listeners_receive_signal() -> void:
	_listener_a_count = 0
	_listener_b_count = 0

	_event_bus.resource_saved.connect(_listener_a)
	_event_bus.resource_saved.connect(_listener_b)

	var test_resource: Resource = Resource.new()
	_event_bus.resource_saved.emit("test", "test_id", test_resource)

	assert_int(_listener_a_count).is_equal(1)
	assert_int(_listener_b_count).is_equal(1)


func test_disconnected_listener_does_not_receive_signal() -> void:
	_listener_a_count = 0
	_listener_b_count = 0

	_event_bus.resource_saved.connect(_listener_a)
	_event_bus.resource_saved.connect(_listener_b)
	_event_bus.resource_saved.disconnect(_listener_a)

	var test_resource: Resource = Resource.new()
	_event_bus.resource_saved.emit("test", "test_id", test_resource)

	assert_int(_listener_a_count).is_equal(0)
	assert_int(_listener_b_count).is_equal(1)
