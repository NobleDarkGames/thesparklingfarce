extends Node

## SettingsManager - Centralized user settings with validation and persistence
##
## Manages all user-configurable options:
## - Audio volumes (SFX, Music, Voice)
## - Display settings (fullscreen, resolution, vsync)
## - Gameplay options (text speed, battle animations)
## - Accessibility features
##
## Settings are automatically saved to user://settings.cfg
## Mods can register custom settings via the mod settings API
##
## Usage:
##   SettingsManager.set_sfx_volume(0.8)
##   var vol: float = SettingsManager.get_sfx_volume()
##   SettingsManager.save_settings()

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when any setting changes (for UI updates)
signal setting_changed(key: String, value: Variant)

## Emitted when settings are saved
signal settings_saved()

## Emitted when settings are loaded
signal settings_loaded()

# ============================================================================
# CONSTANTS
# ============================================================================

const SETTINGS_FILE: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "settings"
const MOD_SETTINGS_SECTION: String = "mod_settings"

# ============================================================================
# DEFAULT VALUES
# ============================================================================

const DEFAULTS: Dictionary = {
	# Audio
	"sfx_volume": 0.7,
	"music_volume": 0.5,
	"voice_volume": 0.8,
	"master_volume": 1.0,

	# Display
	"fullscreen": false,
	"vsync": true,
	"window_scale": 2,  # 1x, 2x, 3x, 4x for pixel art scaling

	# Gameplay
	"text_speed": 1.0,  # 0.5 = slow, 1.0 = normal, 2.0 = fast
	"battle_animations": true,  # Show combat animations
	"auto_end_turn": false,  # Auto-advance after actions
	"confirm_attacks": true,  # Require confirmation before attacking
	"church_revival_hp_percent": 0,  # 0 = 1 HP (SF2-authentic), 1-100 = percentage of max HP

	# Accessibility
	"screen_shake": true,
	"flash_effects": true,
	"colorblind_mode": "none",  # "none", "deuteranopia", "protanopia", "tritanopia"
	"font_scale": 1.0,
}

# ============================================================================
# RUNTIME STATE
# ============================================================================

## Current settings (loaded from file or defaults)
var _settings: Dictionary = {}

## Mod-specific settings (keyed by mod_id)
var _mod_settings: Dictionary = {}

## Track if settings have been modified since last save
var _dirty: bool = false


func _ready() -> void:
	load_settings()


# ============================================================================
# AUDIO SETTINGS
# ============================================================================

func get_sfx_volume() -> float:
	return _get_setting("sfx_volume")


func set_sfx_volume(volume: float) -> void:
	_set_setting("sfx_volume", clampf(volume, 0.0, 1.0))
	# Apply to AudioManager if available
	if AudioManager:
		AudioManager.set_sfx_volume(volume)


func get_music_volume() -> float:
	return _get_setting("music_volume")


func set_music_volume(volume: float) -> void:
	_set_setting("music_volume", clampf(volume, 0.0, 1.0))
	# Apply to AudioManager if available
	if AudioManager:
		AudioManager.set_music_volume(volume)


func get_master_volume() -> float:
	return _get_setting("master_volume")


func set_master_volume(volume: float) -> void:
	_set_setting("master_volume", clampf(volume, 0.0, 1.0))
	# Apply to AudioServer
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(volume))


# ============================================================================
# DISPLAY SETTINGS
# ============================================================================

func is_fullscreen() -> bool:
	return _get_setting("fullscreen")


func set_fullscreen(enabled: bool) -> void:
	_set_setting("fullscreen", enabled)
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func is_vsync_enabled() -> bool:
	return _get_setting("vsync")


func set_vsync(enabled: bool) -> void:
	_set_setting("vsync", enabled)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	)


func get_window_scale() -> int:
	return _get_setting("window_scale")


func set_window_scale(scale: int) -> void:
	scale = clampi(scale, 1, 4)
	_set_setting("window_scale", scale)
	# Apply window size (base resolution * scale)
	# Base resolution is typically 320x240 for retro pixel art
	var base_size: Vector2i = Vector2i(320, 240)
	DisplayServer.window_set_size(base_size * scale)


# ============================================================================
# GAMEPLAY SETTINGS
# ============================================================================

func get_text_speed() -> float:
	return _get_setting("text_speed")


func set_text_speed(speed: float) -> void:
	_set_setting("text_speed", clampf(speed, 0.25, 4.0))


func are_battle_animations_enabled() -> bool:
	return _get_setting("battle_animations")


func set_battle_animations(enabled: bool) -> void:
	_set_setting("battle_animations", enabled)


func is_auto_end_turn_enabled() -> bool:
	return _get_setting("auto_end_turn")


func set_auto_end_turn(enabled: bool) -> void:
	_set_setting("auto_end_turn", enabled)


func is_attack_confirmation_enabled() -> bool:
	return _get_setting("confirm_attacks")


func set_attack_confirmation(enabled: bool) -> void:
	_set_setting("confirm_attacks", enabled)


func get_church_revival_hp_percent() -> int:
	return _get_setting("church_revival_hp_percent")


func set_church_revival_hp_percent(percent: int) -> void:
	_set_setting("church_revival_hp_percent", clampi(percent, 0, 100))


# ============================================================================
# ACCESSIBILITY SETTINGS
# ============================================================================

func is_screen_shake_enabled() -> bool:
	return _get_setting("screen_shake")


func set_screen_shake(enabled: bool) -> void:
	_set_setting("screen_shake", enabled)


func are_flash_effects_enabled() -> bool:
	return _get_setting("flash_effects")


func set_flash_effects(enabled: bool) -> void:
	_set_setting("flash_effects", enabled)


func get_colorblind_mode() -> String:
	return _get_setting("colorblind_mode")


func set_colorblind_mode(mode: String) -> void:
	var valid_modes: Array[String] = ["none", "deuteranopia", "protanopia", "tritanopia"]
	if mode not in valid_modes:
		push_warning("SettingsManager: Invalid colorblind mode '%s', using 'none'" % mode)
		mode = "none"
	_set_setting("colorblind_mode", mode)


func get_font_scale() -> float:
	return _get_setting("font_scale")


func set_font_scale(scale: float) -> void:
	_set_setting("font_scale", clampf(scale, 0.75, 2.0))


# ============================================================================
# MOD SETTINGS API
# ============================================================================

## Get a mod-specific setting
## @param mod_id: The mod's unique identifier
## @param key: Setting key
## @param default: Default value if not set
func get_mod_setting(mod_id: String, key: String, default: Variant = null) -> Variant:
	if mod_id not in _mod_settings:
		return default
	var mod_dict: Dictionary = _mod_settings[mod_id]
	return mod_dict.get(key, default)


## Set a mod-specific setting
## @param mod_id: The mod's unique identifier
## @param key: Setting key
## @param value: Setting value
func set_mod_setting(mod_id: String, key: String, value: Variant) -> void:
	if mod_id not in _mod_settings:
		_mod_settings[mod_id] = {}
	_mod_settings[mod_id][key] = value
	_dirty = true
	setting_changed.emit("%s:%s" % [mod_id, key], value)


## Get all settings for a mod (for settings UI)
func get_all_mod_settings(mod_id: String) -> Dictionary:
	var settings_val: Variant = _mod_settings.get(mod_id, {})
	var mod_settings: Dictionary = settings_val if settings_val is Dictionary else {}
	return mod_settings.duplicate()


# ============================================================================
# GENERIC SETTING ACCESS
# ============================================================================

## Get a setting by key (with type safety)
func _get_setting(key: String) -> Variant:
	if key in _settings:
		return _settings[key]
	return DEFAULTS.get(key, null)


## Set a setting by key
func _set_setting(key: String, value: Variant) -> void:
	var old_value: Variant = _settings.get(key)
	if old_value != value:
		_settings[key] = value
		_dirty = true
		setting_changed.emit(key, value)


## Get a setting with explicit type cast
func get_setting(key: String, default: Variant = null) -> Variant:
	if key in _settings:
		return _settings[key]
	return DEFAULTS.get(key, default)


## Set a setting (generic)
func set_setting(key: String, value: Variant) -> void:
	_set_setting(key, value)


# ============================================================================
# PERSISTENCE
# ============================================================================

## Save settings to file
func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()

	# Save core settings
	for key: String in _settings:
		config.set_value(SETTINGS_SECTION, key, _settings[key])

	# Save mod settings
	for mod_id: String in _mod_settings:
		var dict_val: Variant = _mod_settings.get(mod_id)
		if not dict_val is Dictionary:
			continue
		var mod_dict: Dictionary = dict_val
		for key: String in mod_dict:
			var full_key: String = "%s:%s" % [mod_id, key]
			config.set_value(MOD_SETTINGS_SECTION, full_key, mod_dict[key])

	var err: Error = config.save(SETTINGS_FILE)
	if err != OK:
		push_error("SettingsManager: Failed to save settings: %d" % err)
		return

	_dirty = false
	settings_saved.emit()


## Load settings from file
func load_settings() -> void:
	# Start with defaults
	_settings = DEFAULTS.duplicate()
	_mod_settings.clear()

	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(SETTINGS_FILE)

	if err == ERR_FILE_NOT_FOUND:
		# First run - use defaults
		settings_loaded.emit()
		return

	if err != OK:
		push_error("SettingsManager: Failed to load settings: %d" % err)
		settings_loaded.emit()
		return

	# Load core settings (validate against defaults)
	if config.has_section(SETTINGS_SECTION):
		for key: String in config.get_section_keys(SETTINGS_SECTION):
			if key in DEFAULTS:
				_settings[key] = config.get_value(SETTINGS_SECTION, key)

	# Load mod settings
	if config.has_section(MOD_SETTINGS_SECTION):
		for full_key: String in config.get_section_keys(MOD_SETTINGS_SECTION):
			if ":" in full_key:
				var parts: PackedStringArray = full_key.split(":", true, 1)
				var mod_id: String = parts[0]
				var key: String = parts[1]
				if mod_id not in _mod_settings:
					_mod_settings[mod_id] = {}
				_mod_settings[mod_id][key] = config.get_value(MOD_SETTINGS_SECTION, full_key)

	_dirty = false
	settings_loaded.emit()

	# Apply loaded settings
	_apply_all_settings()


## Apply all loaded settings to game systems
func _apply_all_settings() -> void:
	# Audio
	if AudioManager:
		AudioManager.set_sfx_volume(get_sfx_volume())
		AudioManager.set_music_volume(get_music_volume())

	# Display
	set_fullscreen(is_fullscreen())
	set_vsync(is_vsync_enabled())

	# Master volume
	set_master_volume(get_master_volume())


## Reset all settings to defaults
func reset_to_defaults() -> void:
	_settings = DEFAULTS.duplicate()
	_mod_settings.clear()
	_dirty = true
	_apply_all_settings()
	save_settings()


## Check if there are unsaved changes
func has_unsaved_changes() -> bool:
	return _dirty
