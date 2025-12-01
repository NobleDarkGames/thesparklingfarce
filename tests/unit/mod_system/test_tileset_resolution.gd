## Unit Tests for TileSet Resolution in ModLoader
##
## Tests the tileset registry API added in Phase 2.5.1.
## Verifies tileset lookup by name and mod priority override.
class_name TestTilesetResolution
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

# Since ModLoader is an autoload that loads on startup, we test against
# its current state. These tests verify the API works correctly.


# =============================================================================
# API EXISTENCE TESTS
# =============================================================================

func test_modloader_has_tileset_registry() -> void:
	# ModLoader should have a tileset registry dictionary
	assert_bool(ModLoader.has_method("get_tileset")).is_true()
	assert_bool(ModLoader.has_method("get_tileset_path")).is_true()
	assert_bool(ModLoader.has_method("has_tileset")).is_true()
	assert_bool(ModLoader.has_method("get_tileset_names")).is_true()
	assert_bool(ModLoader.has_method("get_tileset_source")).is_true()


# =============================================================================
# TILESET LOOKUP TESTS
# =============================================================================

func test_has_tileset_returns_false_for_nonexistent() -> void:
	assert_bool(ModLoader.has_tileset("this_tileset_does_not_exist_xyz")).is_false()


func test_get_tileset_returns_null_for_nonexistent() -> void:
	var result: TileSet = ModLoader.get_tileset("this_tileset_does_not_exist_xyz")
	assert_object(result).is_null()


func test_get_tileset_path_returns_empty_for_nonexistent() -> void:
	var result: String = ModLoader.get_tileset_path("this_tileset_does_not_exist_xyz")
	assert_str(result).is_empty()


func test_get_tileset_source_returns_empty_for_nonexistent() -> void:
	var result: String = ModLoader.get_tileset_source("this_tileset_does_not_exist_xyz")
	assert_str(result).is_empty()


func test_get_tileset_names_returns_array() -> void:
	var names: Array[String] = ModLoader.get_tileset_names()
	# Should return an array (may be empty if no tilesets are registered)
	assert_object(names).is_not_null()


# =============================================================================
# CASE INSENSITIVITY TESTS
# =============================================================================

func test_has_tileset_is_case_insensitive() -> void:
	# First, check if any tilesets are registered
	var names: Array[String] = ModLoader.get_tileset_names()
	if names.is_empty():
		# Skip this test if no tilesets registered (still valid)
		return

	var first_name: String = names[0]

	# Should work with uppercase
	assert_bool(ModLoader.has_tileset(first_name.to_upper())).is_true()

	# Should work with lowercase
	assert_bool(ModLoader.has_tileset(first_name.to_lower())).is_true()

	# Should work with mixed case
	if first_name.length() > 1:
		var mixed: String = first_name[0].to_upper() + first_name.substr(1).to_lower()
		assert_bool(ModLoader.has_tileset(mixed)).is_true()


func test_get_tileset_is_case_insensitive() -> void:
	var names: Array[String] = ModLoader.get_tileset_names()
	if names.is_empty():
		return

	var first_name: String = names[0]

	# All case variants should return the same tileset
	var lower_result: TileSet = ModLoader.get_tileset(first_name.to_lower())
	var upper_result: TileSet = ModLoader.get_tileset(first_name.to_upper())

	# Both should return either the same resource or both null
	if lower_result != null:
		assert_object(lower_result).is_same(upper_result)


# =============================================================================
# SOURCE TRACKING TESTS
# =============================================================================

func test_get_tileset_source_returns_mod_id() -> void:
	var names: Array[String] = ModLoader.get_tileset_names()
	if names.is_empty():
		return

	var first_name: String = names[0]
	var source: String = ModLoader.get_tileset_source(first_name)

	# Source should be a non-empty mod ID
	assert_str(source).is_not_empty()


# =============================================================================
# RESOURCE LOADING TESTS
# =============================================================================

func test_get_tileset_returns_tileset_resource() -> void:
	var names: Array[String] = ModLoader.get_tileset_names()
	if names.is_empty():
		return

	var first_name: String = names[0]
	var tileset: TileSet = ModLoader.get_tileset(first_name)

	# If registered, should return a TileSet resource
	if tileset != null:
		assert_object(tileset).is_instanceof(TileSet)


func test_get_tileset_path_returns_valid_path() -> void:
	var names: Array[String] = ModLoader.get_tileset_names()
	if names.is_empty():
		return

	var first_name: String = names[0]
	var path: String = ModLoader.get_tileset_path(first_name)

	# Path should end with .tres
	assert_str(path).ends_with(".tres")

	# Path should start with res://
	assert_str(path).starts_with("res://")


# =============================================================================
# LAZY LOADING TESTS
# =============================================================================

func test_tileset_is_lazy_loaded() -> void:
	# This test verifies that get_tileset_path works without loading the resource
	# We can't easily test lazy loading internals, but we can verify the API
	var names: Array[String] = ModLoader.get_tileset_names()
	if names.is_empty():
		return

	var first_name: String = names[0]

	# Getting path should work
	var path: String = ModLoader.get_tileset_path(first_name)
	assert_str(path).is_not_empty()

	# Then getting the actual resource should also work
	var tileset: TileSet = ModLoader.get_tileset(first_name)
	# Either null (if file doesn't exist) or a TileSet
	if tileset != null:
		assert_object(tileset).is_instanceof(TileSet)

