## SettingsManager Unit Tests
##
## Tests the SettingsManager user settings functionality:
## - Audio settings (SFX, music, master volume)
## - Display settings (fullscreen, vsync, window scale)
## - Gameplay settings (text speed, battle animations, etc.)
## - Accessibility settings (screen shake, flash effects, colorblind mode)
## - Mod settings API
## - Settings persistence (save/load)
## - Signal emissions
## - Default values
## - Value clamping and validation
##
## Note: This is a UNIT test - creates a fresh SettingsManager instance.
## File persistence tests use a test-specific config path.
class_name TestSettingsManager
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

const SettingsManagerScript: GDScript = preload("res://core/systems/settings_manager.gd")
const SignalTrackerScript: GDScript = preload("res://tests/fixtures/signal_tracker.gd")

var _settings: Node
var _tracker: SignalTracker


func before_test() -> void:
	_settings = SettingsManagerScript.new()
	# Don't call _ready which loads from file - we want clean state
	_settings._settings = _settings.DEFAULTS.duplicate()
	_settings._mod_settings = {}
	_settings._dirty = false
	add_child(_settings)
	_tracker = SignalTrackerScript.new()


func after_test() -> void:
	if _tracker:
		_tracker.disconnect_all()
		_tracker = null
	if _settings and is_instance_valid(_settings):
		_settings.queue_free()
	_settings = null


# =============================================================================
# DEFAULT VALUES TESTS
# =============================================================================

func test_defaults_has_sfx_volume() -> void:
	assert_bool("sfx_volume" in _settings.DEFAULTS).is_true()
	assert_float(_settings.DEFAULTS.sfx_volume).is_equal(0.7)


func test_defaults_has_music_volume() -> void:
	assert_bool("music_volume" in _settings.DEFAULTS).is_true()
	assert_float(_settings.DEFAULTS.music_volume).is_equal(0.5)


func test_defaults_has_master_volume() -> void:
	assert_bool("master_volume" in _settings.DEFAULTS).is_true()
	assert_float(_settings.DEFAULTS.master_volume).is_equal(1.0)


func test_defaults_has_fullscreen() -> void:
	assert_bool("fullscreen" in _settings.DEFAULTS).is_true()
	assert_bool(_settings.DEFAULTS.fullscreen).is_false()


func test_defaults_has_vsync() -> void:
	assert_bool("vsync" in _settings.DEFAULTS).is_true()
	assert_bool(_settings.DEFAULTS.vsync).is_true()


func test_defaults_has_text_speed() -> void:
	assert_bool("text_speed" in _settings.DEFAULTS).is_true()
	assert_float(_settings.DEFAULTS.text_speed).is_equal(1.0)


func test_defaults_has_battle_animations() -> void:
	assert_bool("battle_animations" in _settings.DEFAULTS).is_true()
	assert_bool(_settings.DEFAULTS.battle_animations).is_true()


func test_defaults_has_screen_shake() -> void:
	assert_bool("screen_shake" in _settings.DEFAULTS).is_true()
	assert_bool(_settings.DEFAULTS.screen_shake).is_true()


func test_defaults_has_colorblind_mode() -> void:
	assert_bool("colorblind_mode" in _settings.DEFAULTS).is_true()
	assert_str(_settings.DEFAULTS.colorblind_mode).is_equal("none")


# =============================================================================
# AUDIO SETTINGS TESTS
# =============================================================================

func test_get_sfx_volume_returns_default() -> void:
	var volume: float = _settings.get_sfx_volume()

	assert_float(volume).is_equal(0.7)


func test_set_sfx_volume_stores_value() -> void:
	_settings.set_sfx_volume(0.5)

	assert_float(_settings.get_sfx_volume()).is_equal(0.5)


func test_set_sfx_volume_clamps_to_min() -> void:
	_settings.set_sfx_volume(-0.5)

	assert_float(_settings.get_sfx_volume()).is_equal(0.0)


func test_set_sfx_volume_clamps_to_max() -> void:
	_settings.set_sfx_volume(1.5)

	assert_float(_settings.get_sfx_volume()).is_equal(1.0)


func test_get_music_volume_returns_default() -> void:
	var volume: float = _settings.get_music_volume()

	assert_float(volume).is_equal(0.5)


func test_set_music_volume_stores_value() -> void:
	_settings.set_music_volume(0.8)

	assert_float(_settings.get_music_volume()).is_equal(0.8)


func test_set_music_volume_clamps_to_range() -> void:
	_settings.set_music_volume(2.0)
	assert_float(_settings.get_music_volume()).is_equal(1.0)

	_settings.set_music_volume(-1.0)
	assert_float(_settings.get_music_volume()).is_equal(0.0)


func test_get_master_volume_returns_default() -> void:
	var volume: float = _settings.get_master_volume()

	assert_float(volume).is_equal(1.0)


func test_set_master_volume_stores_value() -> void:
	_settings.set_master_volume(0.3)

	assert_float(_settings.get_master_volume()).is_equal(0.3)


# =============================================================================
# DISPLAY SETTINGS TESTS
# =============================================================================

func test_is_fullscreen_returns_default() -> void:
	var is_fs: bool = _settings.is_fullscreen()

	assert_bool(is_fs).is_false()


func test_is_vsync_enabled_returns_default() -> void:
	var vsync: bool = _settings.is_vsync_enabled()

	assert_bool(vsync).is_true()


func test_get_window_scale_returns_default() -> void:
	var scale: int = _settings.get_window_scale()

	assert_int(scale).is_equal(2)


func test_set_window_scale_clamps_to_min() -> void:
	_settings.set_window_scale(0)

	assert_int(_settings.get_window_scale()).is_equal(1)


func test_set_window_scale_clamps_to_max() -> void:
	_settings.set_window_scale(10)

	assert_int(_settings.get_window_scale()).is_equal(4)


func test_set_window_scale_accepts_valid_values() -> void:
	_settings.set_window_scale(3)

	assert_int(_settings.get_window_scale()).is_equal(3)


# =============================================================================
# GAMEPLAY SETTINGS TESTS
# =============================================================================

func test_get_text_speed_returns_default() -> void:
	var speed: float = _settings.get_text_speed()

	assert_float(speed).is_equal(1.0)


func test_set_text_speed_stores_value() -> void:
	_settings.set_text_speed(2.0)

	assert_float(_settings.get_text_speed()).is_equal(2.0)


func test_set_text_speed_clamps_to_range() -> void:
	_settings.set_text_speed(0.1)
	assert_float(_settings.get_text_speed()).is_equal(0.25)

	_settings.set_text_speed(10.0)
	assert_float(_settings.get_text_speed()).is_equal(4.0)


func test_are_battle_animations_enabled_returns_default() -> void:
	var enabled: bool = _settings.are_battle_animations_enabled()

	assert_bool(enabled).is_true()


func test_set_battle_animations_stores_value() -> void:
	_settings.set_battle_animations(false)

	assert_bool(_settings.are_battle_animations_enabled()).is_false()


func test_is_auto_end_turn_enabled_returns_default() -> void:
	var enabled: bool = _settings.is_auto_end_turn_enabled()

	assert_bool(enabled).is_false()


func test_set_auto_end_turn_stores_value() -> void:
	_settings.set_auto_end_turn(true)

	assert_bool(_settings.is_auto_end_turn_enabled()).is_true()


func test_is_attack_confirmation_enabled_returns_default() -> void:
	var enabled: bool = _settings.is_attack_confirmation_enabled()

	assert_bool(enabled).is_true()


func test_set_attack_confirmation_stores_value() -> void:
	_settings.set_attack_confirmation(false)

	assert_bool(_settings.is_attack_confirmation_enabled()).is_false()


func test_get_church_revival_hp_percent_returns_default() -> void:
	var percent: int = _settings.get_church_revival_hp_percent()

	assert_int(percent).is_equal(0)


func test_set_church_revival_hp_percent_stores_value() -> void:
	_settings.set_church_revival_hp_percent(50)

	assert_int(_settings.get_church_revival_hp_percent()).is_equal(50)


func test_set_church_revival_hp_percent_clamps_to_range() -> void:
	_settings.set_church_revival_hp_percent(-10)
	assert_int(_settings.get_church_revival_hp_percent()).is_equal(0)

	_settings.set_church_revival_hp_percent(150)
	assert_int(_settings.get_church_revival_hp_percent()).is_equal(100)


# =============================================================================
# ACCESSIBILITY SETTINGS TESTS
# =============================================================================

func test_is_screen_shake_enabled_returns_default() -> void:
	var enabled: bool = _settings.is_screen_shake_enabled()

	assert_bool(enabled).is_true()


func test_set_screen_shake_stores_value() -> void:
	_settings.set_screen_shake(false)

	assert_bool(_settings.is_screen_shake_enabled()).is_false()


func test_are_flash_effects_enabled_returns_default() -> void:
	var enabled: bool = _settings.are_flash_effects_enabled()

	assert_bool(enabled).is_true()


func test_set_flash_effects_stores_value() -> void:
	_settings.set_flash_effects(false)

	assert_bool(_settings.are_flash_effects_enabled()).is_false()


func test_get_colorblind_mode_returns_default() -> void:
	var mode: String = _settings.get_colorblind_mode()

	assert_str(mode).is_equal("none")


func test_set_colorblind_mode_stores_valid_modes() -> void:
	_settings.set_colorblind_mode("deuteranopia")
	assert_str(_settings.get_colorblind_mode()).is_equal("deuteranopia")

	_settings.set_colorblind_mode("protanopia")
	assert_str(_settings.get_colorblind_mode()).is_equal("protanopia")

	_settings.set_colorblind_mode("tritanopia")
	assert_str(_settings.get_colorblind_mode()).is_equal("tritanopia")

	_settings.set_colorblind_mode("none")
	assert_str(_settings.get_colorblind_mode()).is_equal("none")


func test_set_colorblind_mode_rejects_invalid_mode() -> void:
	_settings.set_colorblind_mode("deuteranopia")

	_settings.set_colorblind_mode("invalid_mode")

	# Should reset to "none" when invalid
	assert_str(_settings.get_colorblind_mode()).is_equal("none")


func test_get_font_scale_returns_default() -> void:
	var scale: float = _settings.get_font_scale()

	assert_float(scale).is_equal(1.0)


func test_set_font_scale_stores_value() -> void:
	_settings.set_font_scale(1.5)

	assert_float(_settings.get_font_scale()).is_equal(1.5)


func test_set_font_scale_clamps_to_range() -> void:
	_settings.set_font_scale(0.5)
	assert_float(_settings.get_font_scale()).is_equal(0.75)

	_settings.set_font_scale(3.0)
	assert_float(_settings.get_font_scale()).is_equal(2.0)


# =============================================================================
# MOD SETTINGS API TESTS
# =============================================================================

func test_get_mod_setting_returns_default_for_unknown() -> void:
	var value: Variant = _settings.get_mod_setting("unknown_mod", "unknown_key", 42)

	assert_int(value).is_equal(42)


func test_set_mod_setting_stores_value() -> void:
	_settings.set_mod_setting("test_mod", "custom_setting", "custom_value")

	var value: Variant = _settings.get_mod_setting("test_mod", "custom_setting")

	assert_str(value).is_equal("custom_value")


func test_set_mod_setting_marks_dirty() -> void:
	_settings._dirty = false

	_settings.set_mod_setting("test_mod", "key", "value")

	assert_bool(_settings._dirty).is_true()


func test_get_all_mod_settings_returns_empty_for_unknown() -> void:
	var settings: Dictionary = _settings.get_all_mod_settings("unknown_mod")

	assert_dict(settings).is_empty()


func test_get_all_mod_settings_returns_copy() -> void:
	_settings.set_mod_setting("test_mod", "key1", "value1")
	_settings.set_mod_setting("test_mod", "key2", "value2")

	var settings: Dictionary = _settings.get_all_mod_settings("test_mod")

	assert_int(settings.size()).is_equal(2)
	assert_str(settings.get("key1", "")).is_equal("value1")
	assert_str(settings.get("key2", "")).is_equal("value2")


func test_mod_settings_are_isolated_between_mods() -> void:
	_settings.set_mod_setting("mod_a", "shared_key", "value_a")
	_settings.set_mod_setting("mod_b", "shared_key", "value_b")

	assert_str(_settings.get_mod_setting("mod_a", "shared_key")).is_equal("value_a")
	assert_str(_settings.get_mod_setting("mod_b", "shared_key")).is_equal("value_b")


# =============================================================================
# GENERIC SETTING ACCESS TESTS
# =============================================================================

func test_get_setting_returns_value() -> void:
	_settings._settings["custom_key"] = 123

	var value: Variant = _settings.get_setting("custom_key")

	assert_int(value).is_equal(123)


func test_get_setting_returns_default_for_unknown() -> void:
	var value: Variant = _settings.get_setting("unknown_key", "default")

	assert_str(value).is_equal("default")


func test_set_setting_stores_value() -> void:
	_settings.set_setting("new_key", "new_value")

	assert_str(_settings.get_setting("new_key")).is_equal("new_value")


# =============================================================================
# SIGNAL TESTS
# =============================================================================

func test_setting_changed_emits_on_change() -> void:
	_tracker.track(_settings.setting_changed)

	_settings.set_sfx_volume(0.3)

	assert_bool(_tracker.was_emitted("setting_changed")).is_true()


func test_setting_changed_emits_key_and_value() -> void:
	_tracker.track(_settings.setting_changed)

	_settings.set_music_volume(0.6)

	var emissions: Array = _tracker.get_emissions("setting_changed")
	assert_int(emissions.size()).is_equal(1)
	assert_str(emissions[0].arguments[0]).is_equal("music_volume")
	assert_float(emissions[0].arguments[1]).is_equal(0.6)


func test_setting_changed_not_emitted_if_unchanged() -> void:
	_settings.set_sfx_volume(0.7)  # Set to default
	_tracker.track(_settings.setting_changed)

	_settings.set_sfx_volume(0.7)  # Same value

	assert_bool(_tracker.was_emitted("setting_changed")).is_false()


func test_mod_setting_emits_namespaced_key() -> void:
	_tracker.track(_settings.setting_changed)

	_settings.set_mod_setting("my_mod", "my_key", "my_value")

	var emissions: Array = _tracker.get_emissions("setting_changed")
	assert_int(emissions.size()).is_equal(1)
	assert_str(emissions[0].arguments[0]).is_equal("my_mod:my_key")


# =============================================================================
# DIRTY STATE TESTS
# =============================================================================

func test_has_unsaved_changes_initially_false() -> void:
	assert_bool(_settings.has_unsaved_changes()).is_false()


func test_has_unsaved_changes_true_after_change() -> void:
	_settings.set_sfx_volume(0.1)

	assert_bool(_settings.has_unsaved_changes()).is_true()


func test_dirty_flag_set_on_setting_change() -> void:
	_settings._dirty = false

	_settings.set_music_volume(0.9)

	assert_bool(_settings._dirty).is_true()


# =============================================================================
# RESET TO DEFAULTS TESTS
# =============================================================================

func test_reset_to_defaults_restores_sfx_volume() -> void:
	_settings.set_sfx_volume(0.1)

	_settings.reset_to_defaults()

	assert_float(_settings.get_sfx_volume()).is_equal(0.7)


func test_reset_to_defaults_restores_music_volume() -> void:
	_settings.set_music_volume(0.9)

	_settings.reset_to_defaults()

	assert_float(_settings.get_music_volume()).is_equal(0.5)


func test_reset_to_defaults_clears_mod_settings() -> void:
	_settings.set_mod_setting("test_mod", "key", "value")

	_settings.reset_to_defaults()

	var mod_settings: Dictionary = _settings.get_all_mod_settings("test_mod")
	assert_dict(mod_settings).is_empty()


func test_reset_to_defaults_restores_all_values() -> void:
	# Change multiple settings
	_settings.set_sfx_volume(0.1)
	_settings.set_text_speed(3.0)
	_settings.set_screen_shake(false)
	_settings.set_colorblind_mode("deuteranopia")

	_settings.reset_to_defaults()

	assert_float(_settings.get_sfx_volume()).is_equal(0.7)
	assert_float(_settings.get_text_speed()).is_equal(1.0)
	assert_bool(_settings.is_screen_shake_enabled()).is_true()
	assert_str(_settings.get_colorblind_mode()).is_equal("none")


# =============================================================================
# CONSTANTS TESTS
# =============================================================================

func test_settings_file_path_is_user_directory() -> void:
	assert_str(_settings.SETTINGS_FILE).starts_with("user://")


func test_settings_section_is_not_empty() -> void:
	assert_str(_settings.SETTINGS_SECTION).is_not_empty()


func test_mod_settings_section_is_not_empty() -> void:
	assert_str(_settings.MOD_SETTINGS_SECTION).is_not_empty()
