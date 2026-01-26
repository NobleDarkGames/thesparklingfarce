## Unit Tests for Namespaced Story Flags
##
## Tests the namespaced flag API added to GameState in Phase 2.5.1.
## Verifies mod flag isolation and backwards compatibility.
class_name TestNamespacedFlags
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

func before_test() -> void:
	# Clear GameState before each test
	GameState.reset_all()
	GameState.clear_mod_namespace()


func after_test() -> void:
	# Clean up after each test
	GameState.reset_all()
	GameState.clear_mod_namespace()


# =============================================================================
# BACKWARDS COMPATIBILITY TESTS
# =============================================================================

func test_legacy_set_flag_still_works() -> void:
	GameState.set_flag("old_style_flag")

	assert_bool(GameState.has_flag("old_style_flag")).is_true()


func test_legacy_clear_flag_still_works() -> void:
	GameState.set_flag("test_flag")
	GameState.clear_flag("test_flag")

	assert_bool(GameState.has_flag("test_flag")).is_false()


# =============================================================================
# NAMESPACE MANAGEMENT TESTS
# =============================================================================

func test_set_mod_namespace() -> void:
	GameState.set_mod_namespace("my_mod")

	assert_str(GameState.get_mod_namespace()).is_equal("my_mod")


func test_clear_mod_namespace() -> void:
	GameState.set_mod_namespace("my_mod")
	GameState.clear_mod_namespace()

	assert_str(GameState.get_mod_namespace()).is_empty()


# =============================================================================
# SCOPED FLAG TESTS
# =============================================================================

func test_scoped_flag_with_explicit_mod_id() -> void:
	GameState.set_flag_scoped("quest_complete", true, "mod_a")

	assert_bool(GameState.has_flag_scoped("quest_complete", "mod_a")).is_true()
	# Should be stored with namespace prefix
	assert_bool(GameState.has_flag("mod_a:quest_complete")).is_true()


func test_scoped_flag_with_current_namespace() -> void:
	GameState.set_mod_namespace("mod_b")
	GameState.set_flag_scoped("boss_defeated")

	# Should use current namespace
	assert_bool(GameState.has_flag("mod_b:boss_defeated")).is_true()
	assert_bool(GameState.has_flag_scoped("boss_defeated")).is_true()


func test_scoped_flag_without_namespace_is_global() -> void:
	# No namespace set, no explicit mod_id
	GameState.set_flag_scoped("global_flag")

	# Should be stored without namespace (backwards compatible)
	assert_bool(GameState.has_flag("global_flag")).is_true()


func test_already_namespaced_flag_not_double_prefixed() -> void:
	GameState.set_mod_namespace("mod_x")
	# Flag already has a namespace
	GameState.set_flag_scoped("other_mod:some_flag")

	# Should NOT be stored as "mod_x:other_mod:some_flag"
	assert_bool(GameState.has_flag("other_mod:some_flag")).is_true()
	assert_bool(GameState.has_flag("mod_x:other_mod:some_flag")).is_false()


func test_clear_flag_scoped() -> void:
	GameState.set_flag_scoped("test_flag", true, "my_mod")
	GameState.clear_flag_scoped("test_flag", "my_mod")

	assert_bool(GameState.has_flag_scoped("test_flag", "my_mod")).is_false()


# =============================================================================
# MOD ISOLATION TESTS
# =============================================================================

func test_different_mods_can_have_same_flag_name() -> void:
	GameState.set_flag_scoped("quest_complete", true, "mod_a")
	GameState.set_flag_scoped("quest_complete", true, "mod_b")

	# Both should exist independently
	assert_bool(GameState.has_flag("mod_a:quest_complete")).is_true()
	assert_bool(GameState.has_flag("mod_b:quest_complete")).is_true()


func test_clearing_one_mod_flag_doesnt_affect_another() -> void:
	GameState.set_flag_scoped("shared_name", true, "mod_a")
	GameState.set_flag_scoped("shared_name", true, "mod_b")

	GameState.clear_flag_scoped("shared_name", "mod_a")

	assert_bool(GameState.has_flag_scoped("shared_name", "mod_a")).is_false()
	assert_bool(GameState.has_flag_scoped("shared_name", "mod_b")).is_true()


# =============================================================================
# GET FLAGS FOR MOD TESTS
# =============================================================================

func test_get_flags_for_mod() -> void:
	GameState.set_flag_scoped("flag_1", true, "test_mod")
	GameState.set_flag_scoped("flag_2", true, "test_mod")
	GameState.set_flag_scoped("other_flag", true, "other_mod")

	var flags: Dictionary = GameState.get_flags_for_mod("test_mod")

	assert_int(flags.size()).is_equal(2)
	assert_bool("flag_1" in flags).is_true()
	assert_bool("flag_2" in flags).is_true()
	assert_bool("other_flag" in flags).is_false()


func test_get_flags_for_mod_returns_empty_for_unknown_mod() -> void:
	var flags: Dictionary = GameState.get_flags_for_mod("nonexistent_mod")

	assert_int(flags.size()).is_equal(0)


# =============================================================================
# UTILITY FUNCTION TESTS
# =============================================================================

func test_is_flag_namespaced_true() -> void:
	assert_bool(GameState.is_flag_namespaced("mod:flag")).is_true()
	assert_bool(GameState.is_flag_namespaced("my_mod:quest_complete")).is_true()


func test_is_flag_namespaced_false() -> void:
	assert_bool(GameState.is_flag_namespaced("simple_flag")).is_false()
	assert_bool(GameState.is_flag_namespaced("no_colon_here")).is_false()


# =============================================================================
# SIGNAL EMISSION TESTS
# =============================================================================

# Use class-level dictionary for signal capture (closures don't capture locals reliably)
var _signal_data: Dictionary = {}


func test_scoped_flag_emits_signal_with_qualified_name() -> void:
	_signal_data.clear()
	_signal_data["received"] = false
	_signal_data["flag_name"] = ""

	var callback: Callable = _on_flag_changed_for_test
	GameState.flag_changed.connect(callback)
	GameState.set_flag_scoped("test_flag", true, "my_mod")
	GameState.flag_changed.disconnect(callback)

	assert_bool(_signal_data["received"]).is_true()
	assert_str(_signal_data["flag_name"]).is_equal("my_mod:test_flag")


func _on_flag_changed_for_test(flag_name: String, _value: bool) -> void:
	_signal_data["received"] = true
	_signal_data["flag_name"] = flag_name
