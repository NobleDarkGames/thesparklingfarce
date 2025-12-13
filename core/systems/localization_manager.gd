extends Node

## LocalizationManager - Foundation for multi-language support
##
## Provides infrastructure for translating game text. Mods can contribute
## translation files that are automatically merged.
##
## File Format: JSON files in mods/*/translations/<language_code>.json
## Example: mods/_base_game/translations/en.json
##
## Translation File Structure:
## {
##     "ui.menu.new_game": "New Game",
##     "ui.menu.continue": "Continue",
##     "character.max.name": "Max",
##     "battle.victory": "Victory!"
## }
##
## Usage:
##   var text = LocalizationManager.tr("ui.menu.new_game")
##   LocalizationManager.set_language("ja")

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when the language changes (for UI refresh)
signal language_changed(language_code: String)

## Emitted when translations are reloaded
signal translations_loaded(language_code: String)

# ============================================================================
# CONSTANTS
# ============================================================================

const TRANSLATIONS_SUBDIR: String = "translations"
const DEFAULT_LANGUAGE: String = "en"

## Supported languages (can be extended by mods)
var supported_languages: Dictionary = {
	"en": "English",
	"ja": "日本語",
	"es": "Español",
	"de": "Deutsch",
	"fr": "Français",
}

# ============================================================================
# STATE
# ============================================================================

## Current language code
var current_language: String = DEFAULT_LANGUAGE

## Translation strings (keyed by translation key)
var _translations: Dictionary = {}

## Fallback translations (English, loaded separately for missing keys)
var _fallback_translations: Dictionary = {}


func _ready() -> void:
	# Wait for ModLoader to be ready
	if ModLoader._is_loading:
		await ModLoader.mods_loaded

	# Load translations for default language
	load_translations(current_language)


# ============================================================================
# PUBLIC API
# ============================================================================

## Translate a key to the current language
## @param key: Translation key (e.g., "ui.menu.new_game")
## @param params: Optional parameters for string formatting
## @return: Translated string, or the key itself if not found
func get_text(key: String, params: Dictionary = {}) -> String:
	var translation: String = _translations.get(key, "")

	# Try fallback if not found in current language
	if translation.is_empty():
		translation = _fallback_translations.get(key, "")

	# Return key if still not found (helps identify missing translations)
	if translation.is_empty():
		push_warning("LocalizationManager: Missing translation for '%s' in '%s'" % [key, current_language])
		return "[%s]" % key  # Bracket notation indicates missing translation

	# Apply parameter substitution
	if not params.is_empty():
		translation = _apply_params(translation, params)

	return translation


## Alias for get_text() - shorter name for common usage
func translate(key: String, params: Dictionary = {}) -> String:
	return get_text(key, params)


## Set the current language
## @param language_code: Two-letter language code (e.g., "en", "ja")
func set_language(language_code: String) -> void:
	if language_code == current_language:
		return

	if language_code not in supported_languages:
		push_warning("LocalizationManager: Unsupported language '%s', using '%s'" % [
			language_code, DEFAULT_LANGUAGE
		])
		language_code = DEFAULT_LANGUAGE

	current_language = language_code
	load_translations(language_code)
	language_changed.emit(language_code)


## Get the current language code
func get_current_language() -> String:
	return current_language


## Get display name for a language code
func get_language_name(language_code: String) -> String:
	return supported_languages.get(language_code, language_code)


## Get all supported language codes
func get_supported_languages() -> Array[String]:
	var codes: Array[String] = []
	for code: String in supported_languages:
		codes.append(code)
	return codes


## Check if a translation key exists
func has_translation(key: String) -> bool:
	return key in _translations or key in _fallback_translations


# ============================================================================
# LOADING
# ============================================================================

## Load translations for a language from all mods
func load_translations(language_code: String) -> void:
	_translations.clear()

	# Always load English as fallback first
	if language_code != DEFAULT_LANGUAGE:
		_fallback_translations = _load_language_from_all_mods(DEFAULT_LANGUAGE)
	else:
		_fallback_translations.clear()

	# Load requested language
	_translations = _load_language_from_all_mods(language_code)

	translations_loaded.emit(language_code)


## Load translations from all mods for a language
func _load_language_from_all_mods(language_code: String) -> Dictionary:
	var combined: Dictionary = {}

	# Load from each mod in priority order (lower priority first, higher overrides)
	var mods: Array[ModManifest] = ModLoader.loaded_mods.duplicate()
	mods.sort_custom(func(a: ModManifest, b: ModManifest) -> bool:
		return a.load_priority < b.load_priority
	)

	for mod: ModManifest in mods:
		var translations_dir: String = mod.mod_directory.path_join(TRANSLATIONS_SUBDIR)
		var translation_file: String = translations_dir.path_join("%s.json" % language_code)

		# Don't use FileAccess.file_exists() - it fails in exports where files are in PCK
		# Just try to load and let _load_translation_file handle missing files
		var mod_translations: Dictionary = _load_translation_file(translation_file)
		if not mod_translations.is_empty():
			combined.merge(mod_translations, true)  # Overwrite with higher priority

	return combined


## Load a single translation file
func _load_translation_file(file_path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("LocalizationManager: Failed to open translation file: %s" % file_path)
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var error: Error = json.parse(json_text)
	if error != OK:
		push_error("LocalizationManager: Failed to parse translation file: %s - %s" % [
			file_path, json.get_error_message()
		])
		return {}

	if json.data is Dictionary:
		return json.data
	else:
		push_error("LocalizationManager: Translation file must be a JSON object: %s" % file_path)
		return {}


## Apply parameter substitution to a translation string
## Parameters are formatted as {param_name}
func _apply_params(text: String, params: Dictionary) -> String:
	var result: String = text
	for param_name: String in params:
		result = result.replace("{%s}" % param_name, str(params[param_name]))
	return result


# ============================================================================
# MOD API
# ============================================================================

## Register additional supported languages (called by mods)
## @param language_code: Two-letter code
## @param display_name: Display name in the language itself
func register_language(language_code: String, display_name: String) -> void:
	if language_code not in supported_languages:
		supported_languages[language_code] = display_name


## Add translations programmatically (for dynamic content)
## @param key: Translation key
## @param translation: Translated text
## @param language_code: Which language (default: current)
func add_translation(key: String, translation: String, language_code: String = "") -> void:
	if language_code.is_empty() or language_code == current_language:
		_translations[key] = translation
	elif language_code == DEFAULT_LANGUAGE:
		_fallback_translations[key] = translation


# ============================================================================
# UTILITY
# ============================================================================

## Get debug string showing translation stats
func get_debug_string() -> String:
	return "LocalizationManager: language=%s, keys=%d, fallback_keys=%d" % [
		current_language,
		_translations.size(),
		_fallback_translations.size()
	]
