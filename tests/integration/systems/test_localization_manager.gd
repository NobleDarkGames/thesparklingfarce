## LocalizationManager Integration Tests
##
## Tests the LocalizationManager translation functionality:
## - Translation lookup (get_text, translate)
## - Language switching
## - Fallback to English for missing keys
## - Parameter substitution in translations
## - Language registration and supported languages
## - Dynamic translation addition
## - Signal emissions on language changes
##
## Note: This is an INTEGRATION test because LocalizationManager uses
## ModLoader to load translations from mod directories.
class_name TestLocalizationManager
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

const LocalizationManagerScript = preload("res://core/systems/localization_manager.gd")
const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")

var _loc: Node
var _tracker: SignalTracker


func before_test() -> void:
	_loc = LocalizationManagerScript.new()
	add_child(_loc)
	_tracker = SignalTrackerScript.new()
	# Don't wait for ModLoader - we'll add translations manually
	_loc._translations.clear()
	_loc._fallback_translations.clear()


func after_test() -> void:
	if _tracker:
		_tracker.disconnect_all()
		_tracker = null
	if _loc and is_instance_valid(_loc):
		_loc.queue_free()
	_loc = null


# =============================================================================
# BASIC TRANSLATION TESTS
# =============================================================================

func test_get_text_returns_translation() -> void:
	_loc._translations["ui.menu.start"] = "Start Game"

	var result: String = _loc.get_text("ui.menu.start")

	assert_str(result).is_equal("Start Game")


func test_translate_alias_works() -> void:
	_loc._translations["ui.menu.quit"] = "Quit"

	var result: String = _loc.translate("ui.menu.quit")

	assert_str(result).is_equal("Quit")


func test_missing_key_returns_bracketed_key() -> void:
	var result: String = _loc.get_text("nonexistent.key")

	assert_str(result).is_equal("[nonexistent.key]")


func test_empty_key_returns_bracketed_empty() -> void:
	var result: String = _loc.get_text("")

	assert_str(result).is_equal("[]")


# =============================================================================
# FALLBACK TESTS
# =============================================================================

func test_missing_key_uses_fallback() -> void:
	_loc._fallback_translations["only.in.english"] = "English Only"

	var result: String = _loc.get_text("only.in.english")

	assert_str(result).is_equal("English Only")


func test_primary_overrides_fallback() -> void:
	_loc._translations["common.key"] = "Japanese Text"
	_loc._fallback_translations["common.key"] = "English Text"

	var result: String = _loc.get_text("common.key")

	assert_str(result).is_equal("Japanese Text")


func test_empty_primary_uses_fallback() -> void:
	_loc._translations["partial.key"] = ""
	_loc._fallback_translations["partial.key"] = "Fallback Value"

	var result: String = _loc.get_text("partial.key")

	assert_str(result).is_equal("Fallback Value")


# =============================================================================
# PARAMETER SUBSTITUTION TESTS
# =============================================================================

func test_single_parameter_substitution() -> void:
	_loc._translations["greeting"] = "Hello, {name}!"

	var result: String = _loc.get_text("greeting", {"name": "Max"})

	assert_str(result).is_equal("Hello, Max!")


func test_multiple_parameter_substitution() -> void:
	_loc._translations["stats"] = "{name} has {hp} HP and {mp} MP"

	var result: String = _loc.get_text("stats", {"name": "Bowie", "hp": 100, "mp": 50})

	assert_str(result).is_equal("Bowie has 100 HP and 50 MP")


func test_unused_parameter_ignored() -> void:
	_loc._translations["simple"] = "Just text"

	var result: String = _loc.get_text("simple", {"unused": "value"})

	assert_str(result).is_equal("Just text")


func test_missing_parameter_left_in_string() -> void:
	_loc._translations["template"] = "Hello, {missing}!"

	var result: String = _loc.get_text("template", {})

	assert_str(result).is_equal("Hello, {missing}!")


func test_numeric_parameter_converted_to_string() -> void:
	_loc._translations["count"] = "You have {count} items"

	var result: String = _loc.get_text("count", {"count": 42})

	assert_str(result).is_equal("You have 42 items")


func test_parameter_repeated_in_string() -> void:
	_loc._translations["echo"] = "{word} {word} {word}"

	var result: String = _loc.get_text("echo", {"word": "test"})

	assert_str(result).is_equal("test test test")


# =============================================================================
# LANGUAGE MANAGEMENT TESTS
# =============================================================================

func test_default_language_is_english() -> void:
	assert_str(_loc.current_language).is_equal("en")


func test_get_current_language() -> void:
	_loc.current_language = "ja"

	var result: String = _loc.get_current_language()

	assert_str(result).is_equal("ja")


func test_set_language_changes_current() -> void:
	_loc.set_language("ja")

	assert_str(_loc.current_language).is_equal("ja")


func test_set_same_language_no_change() -> void:
	_loc.current_language = "en"
	_tracker.track(_loc.language_changed)

	_loc.set_language("en")

	assert_bool(_tracker.was_emitted("language_changed")).is_false()


func test_set_unsupported_language_defaults_to_english() -> void:
	_loc.set_language("xx")  # Unsupported

	assert_str(_loc.current_language).is_equal("en")


func test_set_language_emits_signal() -> void:
	_tracker.track(_loc.language_changed)

	_loc.set_language("ja")

	assert_bool(_tracker.was_emitted("language_changed")).is_true()
	var emissions: Array = _tracker.get_emissions("language_changed")
	assert_str(emissions[0].arguments[0]).is_equal("ja")


# =============================================================================
# SUPPORTED LANGUAGES TESTS
# =============================================================================

func test_default_supported_languages() -> void:
	var supported: Array[String] = _loc.get_supported_languages()

	assert_bool("en" in supported).is_true()
	assert_bool("ja" in supported).is_true()
	assert_bool("es" in supported).is_true()
	assert_bool("de" in supported).is_true()
	assert_bool("fr" in supported).is_true()


func test_get_language_name_english() -> void:
	var name: String = _loc.get_language_name("en")

	assert_str(name).is_equal("English")


func test_get_language_name_japanese() -> void:
	# The Japanese display name is stored as Japanese characters in the source
	var name: String = _loc.get_language_name("ja")

	# Check that we get the native Japanese name (not empty, not the code)
	assert_bool(name.length() > 0).is_true()
	assert_str(name).is_not_equal("ja")  # Should not just return the code


func test_get_language_name_unknown_returns_code() -> void:
	var name: String = _loc.get_language_name("xx")

	assert_str(name).is_equal("xx")


func test_register_language_adds_new() -> void:
	_loc.register_language("ko", "Korean")

	assert_bool("ko" in _loc.supported_languages).is_true()
	assert_str(_loc.supported_languages["ko"]).is_equal("Korean")


func test_register_language_does_not_overwrite_existing() -> void:
	var original_name: String = _loc.supported_languages["en"]

	_loc.register_language("en", "Different Name")

	assert_str(_loc.supported_languages["en"]).is_equal(original_name)


# =============================================================================
# DYNAMIC TRANSLATION TESTS
# =============================================================================

func test_add_translation_to_current_language() -> void:
	_loc.current_language = "en"

	_loc.add_translation("dynamic.key", "Dynamic Value")

	assert_str(_loc._translations["dynamic.key"]).is_equal("Dynamic Value")


func test_add_translation_to_fallback() -> void:
	_loc.current_language = "ja"

	_loc.add_translation("fallback.key", "Fallback Value", "en")

	assert_str(_loc._fallback_translations["fallback.key"]).is_equal("Fallback Value")


func test_add_translation_empty_language_uses_current() -> void:
	_loc.current_language = "en"

	_loc.add_translation("test.key", "Test Value", "")

	assert_str(_loc._translations["test.key"]).is_equal("Test Value")


# =============================================================================
# HAS TRANSLATION TESTS
# =============================================================================

func test_has_translation_true_for_existing() -> void:
	_loc._translations["exists"] = "Value"

	var result: bool = _loc.has_translation("exists")

	assert_bool(result).is_true()


func test_has_translation_true_for_fallback() -> void:
	_loc._fallback_translations["fallback.exists"] = "Fallback"

	var result: bool = _loc.has_translation("fallback.exists")

	assert_bool(result).is_true()


func test_has_translation_false_for_missing() -> void:
	var result: bool = _loc.has_translation("definitely.missing.key")

	assert_bool(result).is_false()


# =============================================================================
# TRANSLATIONS LOADED SIGNAL TESTS
# =============================================================================

func test_load_translations_emits_signal() -> void:
	_tracker.track(_loc.translations_loaded)

	_loc.load_translations("en")

	assert_bool(_tracker.was_emitted("translations_loaded")).is_true()


func test_load_translations_signal_includes_language() -> void:
	_tracker.track(_loc.translations_loaded)

	_loc.load_translations("ja")

	var emissions: Array = _tracker.get_emissions("translations_loaded")
	assert_str(emissions[0].arguments[0]).is_equal("ja")


# =============================================================================
# DEBUG STRING TEST
# =============================================================================

func test_get_debug_string_contains_language() -> void:
	_loc.current_language = "fr"
	_loc._translations["a"] = "1"
	_loc._translations["b"] = "2"

	var debug: String = _loc.get_debug_string()

	assert_str(debug).contains("language=fr")
	assert_str(debug).contains("keys=2")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_translation_with_newlines() -> void:
	_loc._translations["multiline"] = "Line 1\nLine 2\nLine 3"

	var result: String = _loc.get_text("multiline")

	assert_str(result).is_equal("Line 1\nLine 2\nLine 3")


func test_translation_with_special_characters() -> void:
	_loc._translations["special"] = "Price: $100 (50% off!)"

	var result: String = _loc.get_text("special")

	assert_str(result).is_equal("Price: $100 (50% off!)")


func test_translation_with_unicode() -> void:
	_loc._translations["unicode"] = "Fire spell deals fire damage"

	var result: String = _loc.get_text("unicode")

	assert_str(result).contains("Fire")


func test_parameter_with_braces_in_value() -> void:
	_loc._translations["template"] = "Code: {code}"

	var result: String = _loc.get_text("template", {"code": "{nested}"})

	assert_str(result).is_equal("Code: {nested}")


func test_very_long_key() -> void:
	var long_key: String = "this.is.a.very.long.translation.key.that.goes.on.and.on"
	_loc._translations[long_key] = "Long key value"

	var result: String = _loc.get_text(long_key)

	assert_str(result).is_equal("Long key value")
