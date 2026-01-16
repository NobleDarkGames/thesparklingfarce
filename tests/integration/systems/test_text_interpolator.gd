## TextInterpolator Integration Tests
##
## Tests the TextInterpolator variable replacement functionality:
## - Built-in variables ({player_name}, {gold}, {party_count}, etc.)
## - Story flag interpolation ({flag:name})
## - Campaign data interpolation ({var:key})
## - Character reference interpolation ({char:id})
## - Edge cases (empty strings, no variables, malformed patterns)
##
## Note: This is an INTEGRATION test because TextInterpolator uses autoloads
## (GameState, PartyManager, SaveManager, ModLoader) for lookups.
class_name TestTextInterpolator
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

var _original_flags: Dictionary
var _original_campaign_data: Dictionary


func before_test() -> void:
	# Save original GameState
	if GameState:
		_original_flags = GameState.story_flags.duplicate()
		_original_campaign_data = GameState.campaign_data.duplicate()
		# Clear for clean test state
		GameState.story_flags.clear()
		GameState.campaign_data = {
			"current_chapter": 0,
			"battles_won": 0,
			"enemies_defeated": 0
		}


func after_test() -> void:
	# Restore original GameState
	if GameState:
		GameState.story_flags = _original_flags
		GameState.campaign_data = _original_campaign_data


# =============================================================================
# BASIC INTERPOLATION TESTS
# =============================================================================

func test_empty_string_returns_empty() -> void:
	var result: String = TextInterpolator.interpolate("")

	assert_str(result).is_empty()


func test_string_without_variables_unchanged() -> void:
	var input: String = "Hello, world!"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Hello, world!")


func test_string_without_braces_unchanged() -> void:
	var input: String = "No variables here at all"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("No variables here at all")


func test_unrecognized_variable_left_as_is() -> void:
	var input: String = "Hello, {unknown_var}!"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Hello, {unknown_var}!")


# =============================================================================
# BUILT-IN VARIABLE TESTS
# =============================================================================

func test_player_name_replaced() -> void:
	# This test depends on PartyManager having a hero
	# If no hero exists, should fallback to "Hero"
	var input: String = "Welcome, {player_name}!"

	var result: String = TextInterpolator.interpolate(input)

	# Should either be the hero name or "Hero" fallback
	assert_str(result).contains("Welcome, ")
	assert_str(result).is_not_equal("Welcome, {player_name}!")


func test_gold_replaced_with_number() -> void:
	var input: String = "You have {gold} gold."

	var result: String = TextInterpolator.interpolate(input)

	# Should be a number, not the variable
	assert_str(result).is_not_equal("You have {gold} gold.")
	assert_str(result).contains("You have ")
	assert_str(result).contains(" gold.")


func test_party_count_replaced() -> void:
	var input: String = "Party size: {party_count}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_not_equal("Party size: {party_count}")


func test_active_count_replaced() -> void:
	var input: String = "Active members: {active_count}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_not_equal("Active members: {active_count}")


func test_chapter_replaced() -> void:
	GameState.set_campaign_data("current_chapter", 3)
	var input: String = "Chapter {chapter}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Chapter 3")


func test_multiple_builtins_in_one_string() -> void:
	GameState.set_campaign_data("current_chapter", 2)
	var input: String = "Chapter {chapter}: {player_name} has {gold} gold."

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).contains("Chapter 2:")
	assert_str(result).is_not_equal(input)


# =============================================================================
# FLAG INTERPOLATION TESTS
# =============================================================================

func test_flag_true_returns_true_string() -> void:
	GameState.set_flag("test_flag", true)
	var input: String = "Flag value: {flag:test_flag}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Flag value: true")


func test_flag_false_returns_false_string() -> void:
	GameState.set_flag("test_flag", false)
	var input: String = "Flag value: {flag:test_flag}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Flag value: false")


func test_unset_flag_returns_false() -> void:
	# test_unset_flag was never set
	var input: String = "Has treasure: {flag:has_treasure}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Has treasure: false")


func test_multiple_flags_in_string() -> void:
	GameState.set_flag("flag_a", true)
	GameState.set_flag("flag_b", false)
	var input: String = "A={flag:flag_a}, B={flag:flag_b}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("A=true, B=false")


func test_namespaced_flag_interpolation() -> void:
	GameState.story_flags["my_mod:special_flag"] = true
	var input: String = "Special: {flag:my_mod:special_flag}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Special: true")


# =============================================================================
# CAMPAIGN DATA INTERPOLATION TESTS
# =============================================================================

func test_var_returns_campaign_data_value() -> void:
	GameState.set_campaign_data("battles_won", 42)
	var input: String = "Battles won: {var:battles_won}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Battles won: 42")


func test_var_unset_returns_empty_string() -> void:
	# custom_key was never set, default is empty string
	var input: String = "Value: {var:nonexistent_key}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Value: ")


func test_var_string_value() -> void:
	GameState.set_campaign_data("hero_title", "Champion")
	var input: String = "Title: {var:hero_title}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Title: Champion")


func test_multiple_vars_in_string() -> void:
	GameState.set_campaign_data("wins", 10)
	GameState.set_campaign_data("losses", 3)
	var input: String = "Record: {var:wins}W - {var:losses}L"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Record: 10W - 3L")


# =============================================================================
# CHARACTER REFERENCE INTERPOLATION TESTS
# =============================================================================

func test_char_unknown_returns_bracketed_id() -> void:
	# Character that doesn't exist should return [id]
	var input: String = "Hero: {char:nonexistent_char}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Hero: [nonexistent_char]")


func test_char_empty_id_left_as_is() -> void:
	# Empty char id {char:} doesn't match the regex (requires at least one character)
	# so it's left unchanged - this is expected behavior
	var input: String = "Name: {char:}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Name: {char:}")


func test_multiple_char_refs() -> void:
	var input: String = "{char:alice} and {char:bob} are friends"

	var result: String = TextInterpolator.interpolate(input)

	# Both should be bracketed since they don't exist
	assert_str(result).is_equal("[alice] and [bob] are friends")


# =============================================================================
# MIXED INTERPOLATION TESTS
# =============================================================================

func test_mixed_variable_types() -> void:
	GameState.set_flag("quest_complete", true)
	GameState.set_campaign_data("current_chapter", 5)
	GameState.set_campaign_data("gold_earned", 500)
	var input: String = "Chapter {chapter}: Quest done? {flag:quest_complete}. Earned {var:gold_earned}g."

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Chapter 5: Quest done? true. Earned 500g.")


func test_complex_dialogue_with_many_variables() -> void:
	GameState.set_campaign_data("current_chapter", 1)
	GameState.set_flag("met_king", true)
	var input: String = "In chapter {chapter}, {player_name} met the king ({flag:met_king}) with {gold} gold."

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).contains("In chapter 1,")
	assert_str(result).contains("met the king (true)")


# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_adjacent_variables() -> void:
	GameState.set_campaign_data("current_chapter", 1)
	var input: String = "{chapter}{chapter}{chapter}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("111")


func test_nested_braces_not_supported() -> void:
	# Nested braces should be left as-is (not a supported pattern)
	var input: String = "Value: {{nested}}"

	var result: String = TextInterpolator.interpolate(input)

	# The inner brace creates an invalid pattern
	assert_str(result).is_equal("Value: {{nested}}")


func test_unclosed_brace_left_as_is() -> void:
	var input: String = "Unclosed {brace"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Unclosed {brace")


func test_empty_variable_name_left_as_is() -> void:
	var input: String = "Empty: {}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Empty: {}")


func test_whitespace_in_variable_name() -> void:
	# Variables with spaces should not match
	var input: String = "Invalid: {player name}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Invalid: {player name}")


func test_special_characters_in_flag_name() -> void:
	GameState.story_flags["flag-with-dashes"] = true
	var input: String = "Flag: {flag:flag-with-dashes}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Flag: true")


func test_numeric_flag_name() -> void:
	GameState.story_flags["123"] = true
	var input: String = "Numeric: {flag:123}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).is_equal("Numeric: true")


# =============================================================================
# PERFORMANCE EDGE CASES
# =============================================================================

func test_many_variables_in_long_string() -> void:
	GameState.set_campaign_data("current_chapter", 7)
	GameState.set_flag("a", true)
	GameState.set_flag("b", false)
	var input: String = "Ch{chapter}: {flag:a}, {flag:b}, {player_name}, {gold}, {party_count}, {active_count}"

	var result: String = TextInterpolator.interpolate(input)

	assert_str(result).contains("Ch7:")
	assert_str(result).contains("true")
	assert_str(result).contains("false")
