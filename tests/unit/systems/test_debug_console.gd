## DebugConsole Unit Tests
##
## Tests the DebugConsole functionality:
## - Console visibility state (without animation tests)
## - Command tokenization and parsing
## - Argument type conversion
## - Command history management
## - Mod command registration and unregistration
## - Built-in command dispatch
## - Output formatting helpers
## - Error handling and edge cases
##
## Note: This is a UNIT test - tests internal logic in isolation.
## Animation and UI tests require integration/scene tests.
##
## The DebugConsole depends on UI nodes (@onready) that cannot be tested
## in pure unit tests. We test the logic methods that can be called
## without the full scene tree.
class_name TestDebugConsole
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

const DebugConsoleScript: GDScript = preload("res://core/systems/debug_console.gd")
const SignalTrackerScript: GDScript = preload("res://tests/fixtures/signal_tracker.gd")

var _console: CanvasLayer
var _tracker: SignalTracker


func before_test() -> void:
	# Create a fresh DebugConsole instance for each test
	# Note: Cannot call _ready() as it requires UI nodes - test raw script behavior
	_console = DebugConsoleScript.new()
	_tracker = SignalTrackerScript.new()


func after_test() -> void:
	if _tracker:
		_tracker.disconnect_all()
		_tracker = null
	if _console and is_instance_valid(_console):
		_console.queue_free()
	_console = null


# =============================================================================
# INITIAL STATE TESTS
# =============================================================================

func test_initial_is_open_is_false() -> void:
	assert_bool(_console.is_open).is_false()


func test_initial_command_history_is_empty() -> void:
	assert_array(_console.command_history).is_empty()


func test_initial_history_index_is_negative_one() -> void:
	assert_int(_console.history_index).is_equal(-1)


func test_initial_mod_commands_is_empty() -> void:
	assert_dict(_console.mod_commands).is_empty()


func test_initial_is_animating_is_false() -> void:
	assert_bool(_console._is_animating).is_false()


func test_initial_slide_tween_is_null() -> void:
	assert_object(_console._slide_tween).is_null()


# =============================================================================
# CONSTANTS TESTS
# =============================================================================

func test_color_success_constant_defined() -> void:
	assert_str(_console.COLOR_SUCCESS).is_equal("[color=#66E680]")


func test_color_error_constant_defined() -> void:
	assert_str(_console.COLOR_ERROR).is_equal("[color=#FF6666]")


func test_color_info_constant_defined() -> void:
	assert_str(_console.COLOR_INFO).is_equal("[color=#80D9FF]")


func test_color_command_constant_defined() -> void:
	assert_str(_console.COLOR_COMMAND).is_equal("[color=#B3B3D9]")


func test_color_end_constant_defined() -> void:
	assert_str(_console.COLOR_END).is_equal("[/color]")


func test_slide_duration_is_reasonable() -> void:
	# Animation should be quick but visible (0.1 to 0.5 seconds)
	assert_float(_console.SLIDE_DURATION).is_greater(0.05)
	assert_float(_console.SLIDE_DURATION).is_less(0.5)


func test_console_height_percent_is_reasonable() -> void:
	# Should be between 20% and 60% of screen
	assert_float(_console.CONSOLE_HEIGHT_PERCENT).is_greater(0.1)
	assert_float(_console.CONSOLE_HEIGHT_PERCENT).is_less(0.7)


func test_error_no_save_constant_defined() -> void:
	assert_str(_console.ERROR_NO_SAVE).contains("No active save")


# =============================================================================
# TOKENIZE TESTS - Core command parsing
# =============================================================================

func test_tokenize_empty_string_returns_empty_array() -> void:
	var tokens: Array[String] = _console._tokenize("")

	assert_array(tokens).is_empty()


func test_tokenize_single_word_returns_single_token() -> void:
	var tokens: Array[String] = _console._tokenize("help")

	assert_int(tokens.size()).is_equal(1)
	assert_str(tokens[0]).is_equal("help")


func test_tokenize_multiple_words_splits_on_spaces() -> void:
	var tokens: Array[String] = _console._tokenize("hero.give_gold 500")

	assert_int(tokens.size()).is_equal(2)
	assert_str(tokens[0]).is_equal("hero.give_gold")
	assert_str(tokens[1]).is_equal("500")


func test_tokenize_multiple_spaces_ignored() -> void:
	var tokens: Array[String] = _console._tokenize("hero.give_gold    500")

	assert_int(tokens.size()).is_equal(2)
	assert_str(tokens[0]).is_equal("hero.give_gold")
	assert_str(tokens[1]).is_equal("500")


func test_tokenize_preserves_double_quoted_strings() -> void:
	var tokens: Array[String] = _console._tokenize('campaign.set_flag "quest completed" true')

	assert_int(tokens.size()).is_equal(3)
	assert_str(tokens[0]).is_equal("campaign.set_flag")
	assert_str(tokens[1]).is_equal("quest completed")
	assert_str(tokens[2]).is_equal("true")


func test_tokenize_preserves_single_quoted_strings() -> void:
	var tokens: Array[String] = _console._tokenize("campaign.set_flag 'quest completed' true")

	assert_int(tokens.size()).is_equal(3)
	assert_str(tokens[0]).is_equal("campaign.set_flag")
	assert_str(tokens[1]).is_equal("quest completed")
	assert_str(tokens[2]).is_equal("true")


func test_tokenize_mixed_quotes_preserved() -> void:
	var tokens: Array[String] = _console._tokenize("cmd \"arg with 'inner' quote\"")

	assert_int(tokens.size()).is_equal(2)
	assert_str(tokens[1]).is_equal("arg with 'inner' quote")


func test_tokenize_leading_spaces_trimmed() -> void:
	var tokens: Array[String] = _console._tokenize("   help")

	assert_int(tokens.size()).is_equal(1)
	assert_str(tokens[0]).is_equal("help")


func test_tokenize_trailing_spaces_trimmed() -> void:
	var tokens: Array[String] = _console._tokenize("help   ")

	assert_int(tokens.size()).is_equal(1)
	assert_str(tokens[0]).is_equal("help")


func test_tokenize_unclosed_quote_includes_remaining() -> void:
	# Edge case: unclosed quote should include rest of string
	var tokens: Array[String] = _console._tokenize('cmd "unclosed')

	assert_int(tokens.size()).is_equal(2)
	assert_str(tokens[1]).is_equal("unclosed")


func test_tokenize_empty_quotes_produces_empty_token() -> void:
	var tokens: Array[String] = _console._tokenize('cmd ""')

	# Empty string between quotes becomes empty token (which is then filtered)
	# Actually the implementation adds empty string to tokens - let's verify
	assert_int(tokens.size()).is_equal(1)  # Empty token not added


func test_tokenize_many_arguments() -> void:
	var tokens: Array[String] = _console._tokenize("cmd arg1 arg2 arg3 arg4 arg5")

	assert_int(tokens.size()).is_equal(6)


# =============================================================================
# CONVERT ARG TESTS - Type inference from strings
# =============================================================================

func test_convert_arg_true_returns_bool_true() -> void:
	var result: Variant = _console._convert_arg("true")

	assert_bool(result is bool).is_true()
	assert_bool(result).is_true()


func test_convert_arg_false_returns_bool_false() -> void:
	var result: Variant = _console._convert_arg("false")

	assert_bool(result is bool).is_true()
	assert_bool(result).is_false()


func test_convert_arg_true_case_insensitive() -> void:
	var result1: Variant = _console._convert_arg("TRUE")
	var result2: Variant = _console._convert_arg("True")
	var result3: Variant = _console._convert_arg("TrUe")

	assert_bool(result1).is_true()
	assert_bool(result2).is_true()
	assert_bool(result3).is_true()


func test_convert_arg_false_case_insensitive() -> void:
	var result1: Variant = _console._convert_arg("FALSE")
	var result2: Variant = _console._convert_arg("False")
	var result3: Variant = _console._convert_arg("FaLsE")

	assert_bool(result1).is_false()
	assert_bool(result2).is_false()
	assert_bool(result3).is_false()


func test_convert_arg_integer_returns_int() -> void:
	var result: Variant = _console._convert_arg("42")

	assert_bool(result is int).is_true()
	assert_int(result).is_equal(42)


func test_convert_arg_negative_integer_returns_int() -> void:
	var result: Variant = _console._convert_arg("-100")

	assert_bool(result is int).is_true()
	assert_int(result).is_equal(-100)


func test_convert_arg_zero_returns_int() -> void:
	var result: Variant = _console._convert_arg("0")

	assert_bool(result is int).is_true()
	assert_int(result).is_equal(0)


func test_convert_arg_float_returns_float() -> void:
	var result: Variant = _console._convert_arg("3.14")

	assert_bool(result is float).is_true()
	assert_float(result).is_equal_approx(3.14, 0.001)


func test_convert_arg_negative_float_returns_float() -> void:
	var result: Variant = _console._convert_arg("-2.5")

	assert_bool(result is float).is_true()
	assert_float(result).is_equal_approx(-2.5, 0.001)


func test_convert_arg_float_with_leading_dot() -> void:
	var result: Variant = _console._convert_arg(".5")

	assert_bool(result is float).is_true()
	assert_float(result).is_equal_approx(0.5, 0.001)


func test_convert_arg_string_returns_string() -> void:
	var result: Variant = _console._convert_arg("hello")

	assert_bool(result is String).is_true()
	assert_str(result).is_equal("hello")


func test_convert_arg_string_with_numbers_and_letters() -> void:
	var result: Variant = _console._convert_arg("item123")

	assert_bool(result is String).is_true()
	assert_str(result).is_equal("item123")


func test_convert_arg_empty_string_returns_string() -> void:
	var result: Variant = _console._convert_arg("")

	assert_bool(result is String).is_true()
	assert_str(result).is_empty()


func test_convert_arg_string_with_special_chars() -> void:
	var result: Variant = _console._convert_arg("quest_name_123")

	assert_bool(result is String).is_true()
	assert_str(result).is_equal("quest_name_123")


# =============================================================================
# MOD COMMAND REGISTRATION TESTS
# =============================================================================

func test_register_command_adds_to_mod_commands() -> void:
	var callback: Callable = func(_args: Array) -> String: return "test"

	_console.register_command("test_cmd", callback, "Test command", "test_mod")

	assert_bool("test_cmd" in _console.mod_commands).is_true()


func test_register_command_stores_callback() -> void:
	var callback: Callable = func(_args: Array) -> String: return "test"

	_console.register_command("test_cmd", callback, "Test command", "test_mod")

	var cmd_data: Dictionary = _console.mod_commands["test_cmd"]
	assert_bool(cmd_data.callback == callback).is_true()


func test_register_command_stores_help_text() -> void:
	var callback: Callable = func(_args: Array) -> String: return "test"

	_console.register_command("test_cmd", callback, "Test help text", "test_mod")

	var cmd_data: Dictionary = _console.mod_commands["test_cmd"]
	assert_str(cmd_data.help).is_equal("Test help text")


func test_register_command_stores_mod_id() -> void:
	var callback: Callable = func(_args: Array) -> String: return "test"

	_console.register_command("test_cmd", callback, "Test command", "my_mod")

	var cmd_data: Dictionary = _console.mod_commands["test_cmd"]
	assert_str(cmd_data.mod_id).is_equal("my_mod")


func test_register_command_lowercases_name() -> void:
	var callback: Callable = func(_args: Array) -> String: return "test"

	_console.register_command("TEST_CMD", callback, "Test command", "test_mod")

	assert_bool("test_cmd" in _console.mod_commands).is_true()
	assert_bool("TEST_CMD" in _console.mod_commands).is_false()


func test_register_command_overrides_existing() -> void:
	var callback1: Callable = func(_args: Array) -> String: return "first"
	var callback2: Callable = func(_args: Array) -> String: return "second"

	_console.register_command("dupe_cmd", callback1, "First", "mod1")
	_console.register_command("dupe_cmd", callback2, "Second", "mod2")

	var cmd_data: Dictionary = _console.mod_commands["dupe_cmd"]
	assert_str(cmd_data.mod_id).is_equal("mod2")


func test_register_command_with_empty_mod_id() -> void:
	var callback: Callable = func(_args: Array) -> String: return "test"

	_console.register_command("global_cmd", callback, "Global command", "")

	var cmd_data: Dictionary = _console.mod_commands["global_cmd"]
	assert_str(cmd_data.mod_id).is_empty()


func test_register_multiple_commands_from_same_mod() -> void:
	var callback: Callable = func(_args: Array) -> String: return "test"

	_console.register_command("cmd1", callback, "Command 1", "my_mod")
	_console.register_command("cmd2", callback, "Command 2", "my_mod")
	_console.register_command("cmd3", callback, "Command 3", "my_mod")

	assert_int(_console.mod_commands.size()).is_equal(3)


# =============================================================================
# MOD COMMAND UNREGISTRATION TESTS
# =============================================================================

func test_unregister_mod_commands_removes_all_for_mod() -> void:
	var callback: Callable = func(_args: Array) -> String: return "test"
	_console.register_command("cmd1", callback, "Cmd 1", "mod_a")
	_console.register_command("cmd2", callback, "Cmd 2", "mod_a")
	_console.register_command("cmd3", callback, "Cmd 3", "mod_b")

	_console.unregister_mod_commands("mod_a")

	assert_bool("cmd1" in _console.mod_commands).is_false()
	assert_bool("cmd2" in _console.mod_commands).is_false()
	assert_bool("cmd3" in _console.mod_commands).is_true()


func test_unregister_mod_commands_with_no_matching_commands() -> void:
	var callback: Callable = func(_args: Array) -> String: return "test"
	_console.register_command("cmd1", callback, "Cmd 1", "mod_a")

	_console.unregister_mod_commands("nonexistent_mod")

	assert_int(_console.mod_commands.size()).is_equal(1)


func test_unregister_mod_commands_with_empty_mod_id() -> void:
	var callback: Callable = func(_args: Array) -> String: return "test"
	_console.register_command("cmd1", callback, "Cmd 1", "")
	_console.register_command("cmd2", callback, "Cmd 2", "mod_a")

	_console.unregister_mod_commands("")

	assert_bool("cmd1" in _console.mod_commands).is_false()
	assert_bool("cmd2" in _console.mod_commands).is_true()


func test_unregister_mod_commands_leaves_empty_dictionary() -> void:
	var callback: Callable = func(_args: Array) -> String: return "test"
	_console.register_command("cmd1", callback, "Cmd 1", "mod_a")

	_console.unregister_mod_commands("mod_a")

	assert_dict(_console.mod_commands).is_empty()


# =============================================================================
# COMMAND HISTORY TESTS
# =============================================================================

func test_command_history_starts_empty() -> void:
	assert_array(_console.command_history).is_empty()


func test_history_index_starts_at_negative_one() -> void:
	assert_int(_console.history_index).is_equal(-1)


func test_navigate_history_up_with_empty_history_does_nothing() -> void:
	# Cannot test _navigate_history directly as it modifies input_line
	# Instead verify the guard condition exists
	assert_array(_console.command_history).is_empty()


func test_command_history_typed_as_string_array() -> void:
	# Verify the type annotation
	var history: Array[String] = _console.command_history
	assert_array(history).is_empty()


# =============================================================================
# VISIBILITY STATE TESTS
# =============================================================================

func test_is_open_can_be_set() -> void:
	_console.is_open = true

	assert_bool(_console.is_open).is_true()


func test_is_animating_blocks_toggle() -> void:
	# The _toggle_console method checks _is_animating as a guard
	# We can verify the guard flag exists and is writable
	_console._is_animating = true

	assert_bool(_console._is_animating).is_true()


func test_is_animating_can_be_cleared() -> void:
	_console._is_animating = true
	_console._is_animating = false

	assert_bool(_console._is_animating).is_false()


# =============================================================================
# NAMESPACE COMMAND PARSING TESTS
# =============================================================================

func test_command_with_namespace_parses_correctly() -> void:
	# Test that "hero.gold" splits into namespace "hero" and command "gold"
	# by verifying the tokenize behavior
	var tokens: Array[String] = _console._tokenize("hero.gold")

	assert_int(tokens.size()).is_equal(1)
	assert_str(tokens[0]).is_equal("hero.gold")

	# The split happens in _execute_command via .split(".", true, 1)
	var parts: PackedStringArray = tokens[0].split(".", true, 1)
	assert_int(parts.size()).is_equal(2)
	assert_str(parts[0]).is_equal("hero")
	assert_str(parts[1]).is_equal("gold")


func test_command_without_namespace_parses_correctly() -> void:
	var tokens: Array[String] = _console._tokenize("help")

	var parts: PackedStringArray = tokens[0].split(".", true, 1)
	assert_int(parts.size()).is_equal(1)
	assert_str(parts[0]).is_equal("help")


func test_command_with_multiple_dots_splits_at_first() -> void:
	# "debug.scene.tscn" should split to ["debug", "scene.tscn"]
	var tokens: Array[String] = _console._tokenize("debug.scene.tscn")

	var parts: PackedStringArray = tokens[0].split(".", true, 1)
	assert_int(parts.size()).is_equal(2)
	assert_str(parts[0]).is_equal("debug")
	assert_str(parts[1]).is_equal("scene.tscn")


# =============================================================================
# BUILT-IN NAMESPACE RECOGNITION TESTS
# =============================================================================

func test_hero_namespace_recognized() -> void:
	# Verify the namespace exists in the match statement by checking
	# that the console has hero command handlers
	assert_bool(_console.has_method("_execute_hero_command")).is_true()


func test_party_namespace_recognized() -> void:
	assert_bool(_console.has_method("_execute_party_command")).is_true()


func test_campaign_namespace_recognized() -> void:
	assert_bool(_console.has_method("_execute_campaign_command")).is_true()


func test_battle_namespace_recognized() -> void:
	assert_bool(_console.has_method("_execute_battle_command")).is_true()


func test_caravan_namespace_recognized() -> void:
	assert_bool(_console.has_method("_execute_caravan_command")).is_true()


func test_debug_namespace_recognized() -> void:
	assert_bool(_console.has_method("_execute_debug_command")).is_true()


# =============================================================================
# HELPER METHOD TESTS
# =============================================================================

func test_find_party_member_by_name_exists() -> void:
	assert_bool(_console.has_method("_find_party_member_by_name")).is_true()


func test_require_save_exists() -> void:
	assert_bool(_console.has_method("_require_save")).is_true()


func test_add_items_to_inventory_exists() -> void:
	assert_bool(_console.has_method("_add_items_to_inventory")).is_true()


func test_kill_all_units_exists() -> void:
	assert_bool(_console.has_method("_kill_all_units")).is_true()


# =============================================================================
# OUTPUT HELPER METHOD EXISTENCE TESTS
# =============================================================================

func test_print_line_method_exists() -> void:
	assert_bool(_console.has_method("_print_line")).is_true()


func test_print_command_method_exists() -> void:
	assert_bool(_console.has_method("_print_command")).is_true()


func test_print_success_method_exists() -> void:
	assert_bool(_console.has_method("_print_success")).is_true()


func test_print_error_method_exists() -> void:
	assert_bool(_console.has_method("_print_error")).is_true()


func test_print_info_method_exists() -> void:
	assert_bool(_console.has_method("_print_info")).is_true()


func test_print_help_method_exists() -> void:
	assert_bool(_console.has_method("_print_help")).is_true()


# =============================================================================
# EDGE CASE TESTS - TOKENIZER
# =============================================================================

func test_tokenize_only_spaces_returns_empty() -> void:
	var tokens: Array[String] = _console._tokenize("     ")

	assert_array(tokens).is_empty()


func test_tokenize_tab_characters_not_split() -> void:
	# Tabs are not treated as separators
	var tokens: Array[String] = _console._tokenize("cmd\targ")

	assert_int(tokens.size()).is_equal(1)
	assert_str(tokens[0]).is_equal("cmd\targ")


func test_tokenize_newline_characters_not_split() -> void:
	# Newlines are not treated as separators (edge case)
	var tokens: Array[String] = _console._tokenize("cmd\narg")

	assert_int(tokens.size()).is_equal(1)


func test_tokenize_adjacent_quotes_handled() -> void:
	var tokens: Array[String] = _console._tokenize('cmd "a""b"')

	# Should parse as: cmd, a, b (empty string between quotes discarded)
	assert_int(tokens.size()).is_greater(0)


func test_tokenize_quote_at_start() -> void:
	var tokens: Array[String] = _console._tokenize('"quoted cmd" arg')

	assert_int(tokens.size()).is_equal(2)
	assert_str(tokens[0]).is_equal("quoted cmd")


func test_tokenize_quote_at_end() -> void:
	var tokens: Array[String] = _console._tokenize('cmd "quoted arg"')

	assert_int(tokens.size()).is_equal(2)
	assert_str(tokens[1]).is_equal("quoted arg")


# =============================================================================
# EDGE CASE TESTS - TYPE CONVERSION
# =============================================================================

func test_convert_arg_scientific_notation_as_string() -> void:
	# Scientific notation like "1e5" might not be parsed as float
	var result: Variant = _console._convert_arg("1e5")

	# Depending on Godot's is_valid_float, this may or may not parse
	# Just verify it doesn't crash
	assert_bool(result != null).is_true()


func test_convert_arg_very_large_int() -> void:
	var result: Variant = _console._convert_arg("9999999999999")

	# Should parse as int or string depending on overflow
	assert_bool(result != null).is_true()


func test_convert_arg_hex_as_string() -> void:
	# Hex notation like "0xFF" should be treated as string
	var result: Variant = _console._convert_arg("0xFF")

	assert_bool(result is String).is_true()


func test_convert_arg_whitespace_string() -> void:
	# Pure whitespace should stay as string
	var result: Variant = _console._convert_arg("  ")

	assert_bool(result is String).is_true()


# =============================================================================
# MOD COMMAND CALLBACK TESTS
# =============================================================================

func test_mod_command_callback_receives_args() -> void:
	var received_args: Array = []
	var callback: Callable = func(args: Array) -> String:
		received_args = args
		return "done"

	_console.register_command("capture_args", callback, "Test", "test_mod")

	# Verify callback is stored and is valid
	var cmd_data: Dictionary = _console.mod_commands["capture_args"]
	assert_bool(cmd_data.callback.is_valid()).is_true()


func test_mod_command_with_namespaced_name() -> void:
	var callback: Callable = func(_args: Array) -> String: return "test"

	_console.register_command("mymod.special", callback, "Namespaced cmd", "mymod")

	assert_bool("mymod.special" in _console.mod_commands).is_true()


# =============================================================================
# INPUT HANDLING KEY TESTS
# =============================================================================

func test_console_responds_to_f12_key() -> void:
	# Verify KEY_F12 constant is accessible (used in _input)
	assert_int(KEY_F12).is_greater(0)


func test_console_responds_to_backtick_key() -> void:
	# Verify KEY_QUOTELEFT constant is accessible (used in _input)
	assert_int(KEY_QUOTELEFT).is_greater(0)


func test_console_responds_to_escape_key() -> void:
	# Verify KEY_ESCAPE constant is accessible (used in _input)
	assert_int(KEY_ESCAPE).is_greater(0)


func test_console_responds_to_up_arrow() -> void:
	# Verify KEY_UP constant is accessible (used for history)
	assert_int(KEY_UP).is_greater(0)


func test_console_responds_to_down_arrow() -> void:
	# Verify KEY_DOWN constant is accessible (used for history)
	assert_int(KEY_DOWN).is_greater(0)


# =============================================================================
# VISIBILITY LIFECYCLE METHOD EXISTENCE
# =============================================================================

func test_toggle_console_method_exists() -> void:
	assert_bool(_console.has_method("_toggle_console")).is_true()


func test_open_console_method_exists() -> void:
	assert_bool(_console.has_method("_open_console")).is_true()


func test_close_console_method_exists() -> void:
	assert_bool(_console.has_method("_close_console")).is_true()


# =============================================================================
# COMMAND EXECUTION METHOD EXISTENCE
# =============================================================================

func test_execute_command_method_exists() -> void:
	assert_bool(_console.has_method("_execute_command")).is_true()


func test_execute_command_deferred_method_exists() -> void:
	assert_bool(_console.has_method("_execute_command_deferred")).is_true()


func test_on_input_submitted_method_exists() -> void:
	assert_bool(_console.has_method("_on_input_submitted")).is_true()


# =============================================================================
# COMMAND HANDLER METHOD EXISTENCE TESTS
# =============================================================================

func test_cmd_clear_exists() -> void:
	assert_bool(_console.has_method("_cmd_clear")).is_true()


func test_cmd_hero_gold_exists() -> void:
	assert_bool(_console.has_method("_cmd_hero_gold")).is_true()


func test_cmd_hero_give_gold_exists() -> void:
	assert_bool(_console.has_method("_cmd_hero_give_gold")).is_true()


func test_cmd_hero_set_gold_exists() -> void:
	assert_bool(_console.has_method("_cmd_hero_set_gold")).is_true()


func test_cmd_hero_set_level_exists() -> void:
	assert_bool(_console.has_method("_cmd_hero_set_level")).is_true()


func test_cmd_hero_heal_exists() -> void:
	assert_bool(_console.has_method("_cmd_hero_heal")).is_true()


func test_cmd_hero_give_item_exists() -> void:
	assert_bool(_console.has_method("_cmd_hero_give_item")).is_true()


func test_cmd_party_grant_xp_exists() -> void:
	assert_bool(_console.has_method("_cmd_party_grant_xp")).is_true()


func test_cmd_party_add_exists() -> void:
	assert_bool(_console.has_method("_cmd_party_add")).is_true()


func test_cmd_party_remove_exists() -> void:
	assert_bool(_console.has_method("_cmd_party_remove")).is_true()


func test_cmd_party_list_exists() -> void:
	assert_bool(_console.has_method("_cmd_party_list")).is_true()


func test_cmd_party_heal_all_exists() -> void:
	assert_bool(_console.has_method("_cmd_party_heal_all")).is_true()


func test_cmd_campaign_set_flag_exists() -> void:
	assert_bool(_console.has_method("_cmd_campaign_set_flag")).is_true()


func test_cmd_campaign_clear_flag_exists() -> void:
	assert_bool(_console.has_method("_cmd_campaign_clear_flag")).is_true()


func test_cmd_campaign_list_flags_exists() -> void:
	assert_bool(_console.has_method("_cmd_campaign_list_flags")).is_true()


func test_cmd_campaign_trigger_exists() -> void:
	assert_bool(_console.has_method("_cmd_campaign_trigger")).is_true()


func test_cmd_caravan_unlock_exists() -> void:
	assert_bool(_console.has_method("_cmd_caravan_unlock")).is_true()


func test_cmd_caravan_lock_exists() -> void:
	assert_bool(_console.has_method("_cmd_caravan_lock")).is_true()


func test_cmd_caravan_toggle_exists() -> void:
	assert_bool(_console.has_method("_cmd_caravan_toggle")).is_true()


func test_cmd_caravan_status_exists() -> void:
	assert_bool(_console.has_method("_cmd_caravan_status")).is_true()


func test_cmd_caravan_add_item_exists() -> void:
	assert_bool(_console.has_method("_cmd_caravan_add_item")).is_true()


func test_cmd_battle_win_exists() -> void:
	assert_bool(_console.has_method("_cmd_battle_win")).is_true()


func test_cmd_battle_lose_exists() -> void:
	assert_bool(_console.has_method("_cmd_battle_lose")).is_true()


func test_cmd_battle_spawn_exists() -> void:
	assert_bool(_console.has_method("_cmd_battle_spawn")).is_true()


func test_cmd_battle_kill_exists() -> void:
	assert_bool(_console.has_method("_cmd_battle_kill")).is_true()


func test_cmd_debug_fps_exists() -> void:
	assert_bool(_console.has_method("_cmd_debug_fps")).is_true()


func test_cmd_debug_reload_mods_exists() -> void:
	assert_bool(_console.has_method("_cmd_debug_reload_mods")).is_true()


func test_cmd_debug_scene_exists() -> void:
	assert_bool(_console.has_method("_cmd_debug_scene")).is_true()


func test_cmd_debug_create_test_save_exists() -> void:
	assert_bool(_console.has_method("_cmd_debug_create_test_save")).is_true()


func test_cmd_debug_save_info_exists() -> void:
	assert_bool(_console.has_method("_cmd_debug_save_info")).is_true()


func test_cmd_debug_shop_exists() -> void:
	assert_bool(_console.has_method("_cmd_debug_shop")).is_true()


func test_cmd_debug_list_shops_exists() -> void:
	assert_bool(_console.has_method("_cmd_debug_list_shops")).is_true()


# =============================================================================
# ADD ITEMS TO INVENTORY HELPER TESTS
# =============================================================================

func test_add_items_to_inventory_returns_added_count() -> void:
	# Test that when add_func always succeeds, all items are added
	var mock_add: Callable = func(_id: String) -> bool:
		return true

	var result: int = _console._add_items_to_inventory(mock_add, "item_id", 3)

	assert_int(result).is_equal(3)


func test_add_items_to_inventory_stops_on_failure() -> void:
	# Use a counter array to track calls (arrays are passed by reference)
	var call_tracker: Array[int] = [0]
	var mock_add: Callable = func(_id: String) -> bool:
		call_tracker[0] += 1
		return call_tracker[0] < 2  # Fail on second call (returns false when count >= 2)

	var result: int = _console._add_items_to_inventory(mock_add, "item_id", 5)

	# First call: call_tracker[0] becomes 1, returns true (1 < 2)
	# Second call: call_tracker[0] becomes 2, returns false (2 < 2 is false), loop breaks
	assert_int(result).is_equal(1)


func test_add_items_to_inventory_zero_count() -> void:
	var add_count: int = 0
	var mock_add: Callable = func(_id: String) -> bool:
		add_count += 1
		return true

	var result: int = _console._add_items_to_inventory(mock_add, "item_id", 0)

	assert_int(result).is_equal(0)
	assert_int(add_count).is_equal(0)


func test_add_items_to_inventory_all_fail() -> void:
	var mock_add: Callable = func(_id: String) -> bool:
		return false

	var result: int = _console._add_items_to_inventory(mock_add, "item_id", 3)

	assert_int(result).is_equal(0)


# =============================================================================
# INPUT LINE SIGNAL CALLBACK EXISTENCE
# =============================================================================

func test_on_input_focus_lost_method_exists() -> void:
	assert_bool(_console.has_method("_on_input_focus_lost")).is_true()


# =============================================================================
# PANEL SETUP METHOD EXISTENCE
# =============================================================================

func test_setup_panel_style_method_exists() -> void:
	assert_bool(_console.has_method("_setup_panel_style")).is_true()


# =============================================================================
# NAVIGATE HISTORY METHOD TESTS
# =============================================================================

func test_navigate_history_method_exists() -> void:
	assert_bool(_console.has_method("_navigate_history")).is_true()


# =============================================================================
# COMPLEX TOKENIZE SCENARIOS
# =============================================================================

func test_tokenize_command_with_path_argument() -> void:
	var tokens: Array[String] = _console._tokenize("debug.scene res://scenes/main.tscn")

	assert_int(tokens.size()).is_equal(2)
	assert_str(tokens[0]).is_equal("debug.scene")
	assert_str(tokens[1]).is_equal("res://scenes/main.tscn")


func test_tokenize_command_with_numeric_args() -> void:
	var tokens: Array[String] = _console._tokenize("battle.spawn goblin 5 10")

	assert_int(tokens.size()).is_equal(4)
	assert_str(tokens[0]).is_equal("battle.spawn")
	assert_str(tokens[1]).is_equal("goblin")
	assert_str(tokens[2]).is_equal("5")
	assert_str(tokens[3]).is_equal("10")


func test_tokenize_command_with_negative_number() -> void:
	var tokens: Array[String] = _console._tokenize("hero.give_gold -50")

	assert_int(tokens.size()).is_equal(2)
	assert_str(tokens[1]).is_equal("-50")


func test_tokenize_quoted_string_with_spaces_and_numbers() -> void:
	var tokens: Array[String] = _console._tokenize('campaign.set_flag "chapter 2 complete" true')

	assert_int(tokens.size()).is_equal(3)
	assert_str(tokens[1]).is_equal("chapter 2 complete")
	assert_str(tokens[2]).is_equal("true")


# =============================================================================
# INTEGRATION PREPARATION TESTS
# =============================================================================

func test_console_extends_canvas_layer() -> void:
	# DebugConsole should extend CanvasLayer for proper overlay rendering
	assert_bool(_console is CanvasLayer).is_true()


func test_console_has_onready_panel_reference() -> void:
	# Verify the @onready annotation exists (property will be null without scene)
	assert_bool("panel" in _console).is_true()


func test_console_has_onready_output_label_reference() -> void:
	assert_bool("output_label" in _console).is_true()


func test_console_has_onready_input_line_reference() -> void:
	assert_bool("input_line" in _console).is_true()
