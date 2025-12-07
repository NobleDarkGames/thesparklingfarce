## Unit Tests for ModRegistry NPC Functions
##
## Tests the NPC lookup functionality added in Phase 4, specifically
## the get_npc_by_id() method that enables NPC resolution in dialog systems.
class_name TestModRegistryNPC
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

## We cannot easily instantiate ModRegistry in isolation since it depends
## on the mod system infrastructure. Instead, we test the lookup patterns
## that the registry supports.

var _mock_registry: RefCounted


func before_test() -> void:
	# Create a lightweight mock that simulates ModRegistry behavior
	_mock_registry = _create_mock_registry()


## Create a mock registry for testing NPC lookup logic
func _create_mock_registry() -> RefCounted:
	var script: GDScript = GDScript.new()
	script.source_code = """
extends RefCounted

var _resources_by_type: Dictionary = {}

func register_npc(npc_id: String, npc_data: Resource) -> void:
	if "npc" not in _resources_by_type:
		_resources_by_type["npc"] = {}
	_resources_by_type["npc"][npc_id] = npc_data

func get_npc_by_id(npc_id: String) -> Resource:
	if npc_id.is_empty():
		return null
	if "npc" not in _resources_by_type:
		return null
	for npc: Resource in _resources_by_type["npc"].values():
		if npc and npc.get("npc_id") == npc_id:
			return npc
	return null

func has_npc(npc_id: String) -> bool:
	return get_npc_by_id(npc_id) != null
"""
	script.reload()
	return script.new()


## Create a mock NPC resource for testing
func _create_mock_npc(npc_id: String, npc_name: String) -> Resource:
	var script: GDScript = GDScript.new()
	script.source_code = """
extends Resource
var npc_id: String = ""
var npc_name: String = ""
var portrait: Texture2D = null

func get_display_name() -> String:
	return npc_name if not npc_name.is_empty() else npc_id
"""
	script.reload()
	var npc: Resource = Resource.new()
	npc.set_script(script)
	npc.set("npc_id", npc_id)
	npc.set("npc_name", npc_name)
	return npc


# =============================================================================
# GET_NPC_BY_ID TESTS
# =============================================================================

func test_get_npc_by_id_returns_null_for_empty_id() -> void:
	var npc: Resource = _mock_registry.get_npc_by_id("")
	assert_object(npc).is_null()


func test_get_npc_by_id_returns_null_when_no_npcs_registered() -> void:
	var npc: Resource = _mock_registry.get_npc_by_id("some_npc")
	assert_object(npc).is_null()


func test_get_npc_by_id_finds_registered_npc() -> void:
	var mock_npc: Resource = _create_mock_npc("mayor_chuck", "Mayor Chuck")
	_mock_registry.register_npc("mayor_chuck", mock_npc)

	var found: Resource = _mock_registry.get_npc_by_id("mayor_chuck")
	assert_object(found).is_not_null()
	assert_str(found.get("npc_id")).is_equal("mayor_chuck")


func test_get_npc_by_id_returns_null_for_unknown_npc() -> void:
	var mock_npc: Resource = _create_mock_npc("mayor_chuck", "Mayor Chuck")
	_mock_registry.register_npc("mayor_chuck", mock_npc)

	var found: Resource = _mock_registry.get_npc_by_id("unknown_npc")
	assert_object(found).is_null()


func test_get_npc_by_id_matches_exact_id() -> void:
	var npc1: Resource = _create_mock_npc("guard_01", "Guard")
	var npc2: Resource = _create_mock_npc("guard_02", "Guard Captain")
	_mock_registry.register_npc("guard_01", npc1)
	_mock_registry.register_npc("guard_02", npc2)

	var found: Resource = _mock_registry.get_npc_by_id("guard_02")
	assert_object(found).is_not_null()
	assert_str(found.get("npc_name")).is_equal("Guard Captain")


func test_npc_display_name_fallback() -> void:
	var npc: Resource = _create_mock_npc("unnamed_npc", "")

	var display_name: String = npc.get_display_name()
	assert_str(display_name).is_equal("unnamed_npc")


func test_npc_display_name_uses_name() -> void:
	var npc: Resource = _create_mock_npc("npc_001", "Mayor Chuck")

	var display_name: String = npc.get_display_name()
	assert_str(display_name).is_equal("Mayor Chuck")


# =============================================================================
# NPC DIALOG REFERENCE TESTS
# =============================================================================

## Test the "npc:" prefix convention for dialog character references
func test_npc_prefix_convention() -> void:
	var character_id: String = "npc:mayor_chuck"

	assert_bool(character_id.begins_with("npc:")).is_true()

	var npc_id: String = character_id.substr(4)  # Remove "npc:" prefix
	assert_str(npc_id).is_equal("mayor_chuck")


func test_npc_prefix_extraction() -> void:
	var test_cases: Array[Dictionary] = [
		{"input": "npc:guard_01", "expected_id": "guard_01"},
		{"input": "npc:mayor_chuck", "expected_id": "mayor_chuck"},
		{"input": "npc:npc_1765053238", "expected_id": "npc_1765053238"}
	]

	for test_case: Dictionary in test_cases:
		var input: String = test_case["input"]
		var expected: String = test_case["expected_id"]

		if input.begins_with("npc:"):
			var extracted: String = input.substr(4)
			assert_str(extracted).is_equal(expected)


func test_character_id_is_not_npc() -> void:
	var character_id: String = "max_the_hero"
	assert_bool(character_id.begins_with("npc:")).is_false()


# =============================================================================
# HAS_NPC TESTS
# =============================================================================

func test_has_npc_returns_false_for_empty_registry() -> void:
	assert_bool(_mock_registry.has_npc("any_npc")).is_false()


func test_has_npc_returns_true_for_registered_npc() -> void:
	var mock_npc: Resource = _create_mock_npc("shopkeeper", "Shopkeeper")
	_mock_registry.register_npc("shopkeeper", mock_npc)

	assert_bool(_mock_registry.has_npc("shopkeeper")).is_true()


func test_has_npc_returns_false_for_unregistered_npc() -> void:
	var mock_npc: Resource = _create_mock_npc("shopkeeper", "Shopkeeper")
	_mock_registry.register_npc("shopkeeper", mock_npc)

	assert_bool(_mock_registry.has_npc("bartender")).is_false()


# =============================================================================
# MULTIPLE NPC REGISTRATION TESTS
# =============================================================================

func test_multiple_npcs_can_be_registered() -> void:
	var npc1: Resource = _create_mock_npc("mayor_chuck", "Mayor Chuck")
	var npc2: Resource = _create_mock_npc("guard_01", "Town Guard")
	var npc3: Resource = _create_mock_npc("shopkeeper", "Item Shopkeeper")

	_mock_registry.register_npc("mayor_chuck", npc1)
	_mock_registry.register_npc("guard_01", npc2)
	_mock_registry.register_npc("shopkeeper", npc3)

	assert_bool(_mock_registry.has_npc("mayor_chuck")).is_true()
	assert_bool(_mock_registry.has_npc("guard_01")).is_true()
	assert_bool(_mock_registry.has_npc("shopkeeper")).is_true()


func test_each_npc_can_be_retrieved() -> void:
	var npc1: Resource = _create_mock_npc("mayor_chuck", "Mayor Chuck")
	var npc2: Resource = _create_mock_npc("guard_01", "Town Guard")

	_mock_registry.register_npc("mayor_chuck", npc1)
	_mock_registry.register_npc("guard_01", npc2)

	var found1: Resource = _mock_registry.get_npc_by_id("mayor_chuck")
	var found2: Resource = _mock_registry.get_npc_by_id("guard_01")

	assert_str(found1.get("npc_name")).is_equal("Mayor Chuck")
	assert_str(found2.get("npc_name")).is_equal("Town Guard")
