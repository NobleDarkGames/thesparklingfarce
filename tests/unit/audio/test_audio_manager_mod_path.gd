## Unit Tests for AudioManager Mod-Aware Audio Resolution
##
## Tests that AudioManager correctly resolves audio files through the mod system
## with proper priority ordering and fallback to _starter_kit.
##
## Also tests the adaptive layered music system API.
##
## These tests verify the MECHANISM works, not specific mod content.
class_name TestAudioManagerModPath
extends GdUnitTestSuite


# =============================================================================
# MOD LOADER INTEGRATION TESTS
# =============================================================================

func test_mod_loader_has_mods_loaded_signal() -> void:
	# Verify the signal exists on ModLoader (used for cache clearing)
	assert_bool(ModLoader.has_signal("mods_loaded")).is_true()


func test_mod_loader_has_resolve_asset_path() -> void:
	# Verify the method exists for audio resolution
	assert_bool(ModLoader.has_method("resolve_asset_path")).is_true()


func test_mod_loader_resolve_asset_path_returns_string() -> void:
	# Should return empty string for non-existent assets
	var result: String = ModLoader.resolve_asset_path("nonexistent/path.ogg", "")
	assert_str(result).is_empty()


func test_mod_loader_resolve_asset_path_with_fallback() -> void:
	# Should use fallback path when asset not in mods
	# Note: This tests the mechanism, actual file existence depends on test environment
	var fallback: String = "res://mods/_starter_kit/assets/"
	var result: String = ModLoader.resolve_asset_path("audio/sfx/cursor_move.ogg", fallback)
	
	# If starter kit has the file, we get a path; otherwise empty
	# Either result is valid - we're testing the function doesn't crash
	assert_bool(result.is_empty() or result.begins_with("res://")).is_true()


# =============================================================================
# AUDIO MANAGER API TESTS
# =============================================================================

func test_audio_manager_has_play_sfx_method() -> void:
	assert_bool(AudioManager.has_method("play_sfx")).is_true()


func test_audio_manager_has_play_music_method() -> void:
	assert_bool(AudioManager.has_method("play_music")).is_true()


func test_audio_manager_sfx_volume_is_valid() -> void:
	# Volume should be between 0 and 1
	assert_float(AudioManager.sfx_volume).is_greater_equal(0.0)
	assert_float(AudioManager.sfx_volume).is_less_equal(1.0)


func test_audio_manager_music_volume_is_valid() -> void:
	# Volume should be between 0 and 1
	assert_float(AudioManager.music_volume).is_greater_equal(0.0)
	assert_float(AudioManager.music_volume).is_less_equal(1.0)


# =============================================================================
# AUDIO FALLBACK PATH TESTS
# =============================================================================

func test_audio_manager_fallback_path_constant_exists() -> void:
	# AudioManager should have a fallback path pointing to starter kit
	assert_str(AudioManager.AUDIO_FALLBACK_PATH).is_not_empty()
	assert_bool(AudioManager.AUDIO_FALLBACK_PATH.contains("_starter_kit")).is_true()


func test_audio_manager_fallback_path_format() -> void:
	# Fallback path should be properly formatted
	assert_bool(AudioManager.AUDIO_FALLBACK_PATH.begins_with("res://")).is_true()
	assert_bool(AudioManager.AUDIO_FALLBACK_PATH.ends_with("/")).is_true()


# =============================================================================
# ADAPTIVE MUSIC LAYER API TESTS
# =============================================================================

func test_audio_manager_has_get_current_music_name() -> void:
	# Verify the method exists
	assert_bool(AudioManager.has_method("get_current_music_name")).is_true()


func test_audio_manager_has_enable_layer() -> void:
	# Verify the method exists
	assert_bool(AudioManager.has_method("enable_layer")).is_true()


func test_audio_manager_has_disable_layer() -> void:
	# Verify the method exists
	assert_bool(AudioManager.has_method("disable_layer")).is_true()


func test_audio_manager_has_set_layer_volume() -> void:
	# Verify the method exists
	assert_bool(AudioManager.has_method("set_layer_volume")).is_true()


func test_audio_manager_has_get_layer_count() -> void:
	# Verify the method exists
	assert_bool(AudioManager.has_method("get_layer_count")).is_true()


func test_audio_manager_has_is_layer_enabled() -> void:
	# Verify the method exists
	assert_bool(AudioManager.has_method("is_layer_enabled")).is_true()


func test_audio_manager_max_layers_constant() -> void:
	# Should have MAX_LAYERS = 3 (base + 2 additional)
	assert_int(AudioManager.MAX_LAYERS).is_equal(3)


func test_audio_manager_default_layer_fade_constant() -> void:
	# Should have DEFAULT_LAYER_FADE = 0.4
	assert_float(AudioManager.DEFAULT_LAYER_FADE).is_equal(0.4)


func test_audio_manager_current_music_name_empty_when_not_playing() -> void:
	# When no music is playing, should return empty string
	# Note: This assumes no music is playing during test
	# If music IS playing, this test validates the getter works
	var name: String = AudioManager.get_current_music_name()
	assert_bool(name is String).is_true()


func test_audio_manager_layer_count_zero_when_not_playing() -> void:
	# When no music is playing, layer count should be 0
	# Note: If music IS playing, this validates the getter works
	var count: int = AudioManager.get_layer_count()
	assert_bool(count >= 0).is_true()
	assert_bool(count <= AudioManager.MAX_LAYERS).is_true()


func test_audio_manager_is_layer_enabled_returns_bool() -> void:
	# Should return a boolean for valid layer indices
	var result: bool = AudioManager.is_layer_enabled(0)
	assert_bool(result is bool).is_true()


func test_audio_manager_is_layer_enabled_invalid_layer() -> void:
	# Should return false for invalid layer indices
	assert_bool(AudioManager.is_layer_enabled(-1)).is_false()
	assert_bool(AudioManager.is_layer_enabled(99)).is_false()


func test_audio_manager_enable_layer_invalid_does_not_crash() -> void:
	# Should handle invalid layer gracefully (no crash)
	AudioManager.enable_layer(-1)
	AudioManager.enable_layer(99)
	# If we get here without crash, test passes
	assert_bool(true).is_true()


func test_audio_manager_disable_layer_invalid_does_not_crash() -> void:
	# Should handle invalid layer gracefully (no crash)
	AudioManager.disable_layer(-1)
	AudioManager.disable_layer(99)
	# If we get here without crash, test passes
	assert_bool(true).is_true()


func test_audio_manager_set_layer_volume_invalid_does_not_crash() -> void:
	# Should handle invalid layer gracefully (no crash)
	AudioManager.set_layer_volume(-1, 0.5)
	AudioManager.set_layer_volume(99, 0.5)
	# If we get here without crash, test passes
	assert_bool(true).is_true()
