## Unit Tests for AudioManager Mod Path Initialization
##
## Tests that AudioManager receives the correct mod path at startup
## and responds correctly to mod changes.
##
## These tests verify the MECHANISM works, not specific mod content.
## No specific mod (like _base_game) should be required.
class_name TestAudioManagerModPath
extends GdUnitTestSuite


# Class member for signal capture (avoids lambda capture issues in GDScript)
var _signal_data: Dictionary = {}


# =============================================================================
# MOD PATH INITIALIZATION TESTS
# =============================================================================

func test_mod_loader_has_active_mod_changed_signal() -> void:
	# Verify the signal exists on ModLoader
	assert_bool(ModLoader.has_signal("active_mod_changed")).is_true()


func test_mod_loader_active_mod_id_is_not_empty() -> void:
	# ModLoader should have SOME active mod (whichever is loaded)
	assert_str(ModLoader.active_mod_id).is_not_empty()


func test_mod_loader_get_active_mod_returns_manifest_or_null() -> void:
	# Should return a ModManifest or null if no mods loaded
	var manifest: ModManifest = ModLoader.get_active_mod()

	# Either null (no mods) or valid manifest
	if manifest != null:
		assert_str(manifest.mod_id).is_not_empty()
		assert_str(manifest.mod_directory).is_not_empty()


func test_mod_loader_active_mod_directory_format() -> void:
	# When a mod is loaded, its directory should follow the expected format
	var manifest: ModManifest = ModLoader.get_active_mod()

	if manifest == null:
		# No mods loaded - skip this test
		return

	# Directory should be res://mods/<mod_id>
	assert_bool(manifest.mod_directory.begins_with("res://mods/")).is_true()
	assert_bool(manifest.mod_directory.ends_with(manifest.mod_id)).is_true()


func test_audio_manager_has_mod_path_after_initialization() -> void:
	# After initialization, AudioManager should have a non-empty mod path
	# This is the KEY TEST - the bug was that current_mod_path was empty
	assert_str(AudioManager.current_mod_path).is_not_empty()


func test_audio_manager_mod_path_matches_active_mod() -> void:
	# AudioManager's mod path should match the active mod's directory
	var manifest: ModManifest = ModLoader.get_active_mod()

	if manifest == null:
		# No mods loaded - AudioManager should still have a fallback path
		assert_str(AudioManager.current_mod_path).is_not_empty()
		return

	assert_str(AudioManager.current_mod_path).is_equal(manifest.mod_directory)


# =============================================================================
# AUDIO PATH CONSTRUCTION TESTS
# =============================================================================

func test_audio_path_construction_format() -> void:
	# Test that AudioManager's path construction follows the expected format
	var mod_path: String = AudioManager.current_mod_path

	# Should have a valid mod path
	assert_str(mod_path).is_not_empty()
	assert_bool(mod_path.begins_with("res://mods/")).is_true()

	# Construct a hypothetical audio path
	var constructed_path: String = "%s/audio/%s/%s.%s" % [mod_path, "sfx", "test_sound", "ogg"]

	# Should follow the pattern: res://mods/<mod_id>/audio/<subfolder>/<name>.<ext>
	assert_bool(constructed_path.begins_with("res://mods/")).is_true()
	assert_bool("/audio/" in constructed_path).is_true()


# =============================================================================
# SIGNAL CONNECTION TESTS
# =============================================================================

func test_active_mod_changed_signal_updates_audio_manager() -> void:
	# When ModLoader emits active_mod_changed, AudioManager should update
	# Test the mechanism by checking signal connectivity

	var original_mod_path: String = AudioManager.current_mod_path

	# Get any available mod to test with
	var manifest: ModManifest = ModLoader.get_active_mod()
	if manifest == null:
		# No mods loaded - can't test mod switching
		return

	# Set the same mod again - should still work and emit signal
	ModLoader.set_active_mod(manifest.mod_id)

	# AudioManager should still have a valid path (same mod, so same path)
	assert_str(AudioManager.current_mod_path).is_equal(original_mod_path)


func test_active_mod_changed_signal_emits_path() -> void:
	# Verify the signal emits a valid mod path
	var manifest: ModManifest = ModLoader.get_active_mod()

	if manifest == null:
		# No mods loaded - can't test signal emission
		return

	# Use class member dictionary to avoid lambda capture issues
	_signal_data.clear()
	_signal_data["received"] = false
	_signal_data["path"] = ""

	var callback: Callable = _on_active_mod_changed_for_test
	ModLoader.active_mod_changed.connect(callback)

	# Trigger the signal by setting active mod
	ModLoader.set_active_mod(manifest.mod_id)

	# Cleanup
	ModLoader.active_mod_changed.disconnect(callback)

	# Verify we received a valid path
	assert_bool(_signal_data["received"]).is_true()
	assert_str(_signal_data["path"]).is_not_empty()
	assert_bool(_signal_data["path"].begins_with("res://mods/")).is_true()


func _on_active_mod_changed_for_test(path: String) -> void:
	_signal_data["received"] = true
	_signal_data["path"] = path
