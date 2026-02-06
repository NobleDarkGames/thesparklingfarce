## Unit Tests for AIBehaviorData
##
## Tests the data-driven AI behavior configuration resource.
## Validates phase evaluation, threat weights, and validation.
##
## The AI Behavior system is critical for the "Dark Priest Problem" fix -
## ensuring support units heal allies before attacking.
##
## Note: Inheritance system was removed in refactor (commit 286a40d).
class_name TestAIBehaviorData
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

## Create a minimal AIBehaviorData for testing
func _create_test_behavior(
	p_behavior_id: String = "test_behavior",
	p_role: String = "",
	p_mode: String = ""
) -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = p_behavior_id
	behavior.display_name = p_behavior_id.capitalize()
	if not p_role.is_empty():
		behavior.role = p_role
	if not p_mode.is_empty():
		behavior.behavior_mode = p_mode
	return behavior


# =============================================================================
# IDENTITY TESTS
# =============================================================================

func test_behavior_id_stored_correctly() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("my_custom_behavior")
	assert_str(behavior.behavior_id).is_equal("my_custom_behavior")


func test_display_name_stored_correctly() -> void:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.display_name = "My Custom AI"
	assert_str(behavior.display_name).is_equal("My Custom AI")


func test_description_stored_correctly() -> void:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.description = "A test AI behavior for unit testing."
	assert_str(behavior.description).is_equal("A test AI behavior for unit testing.")


# =============================================================================
# ROLE & MODE TESTS
# =============================================================================

func test_role_stored_correctly() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test", "support")
	assert_str(behavior.role).is_equal("support")


func test_role_defaults_to_aggressive() -> void:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	assert_str(behavior.role).is_equal("aggressive")


func test_behavior_mode_stored_correctly() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test", "", "cautious")
	assert_str(behavior.behavior_mode).is_equal("cautious")


func test_behavior_mode_defaults_to_aggressive() -> void:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	assert_str(behavior.behavior_mode).is_equal("aggressive")


# =============================================================================
# THREAT WEIGHT TESTS
# =============================================================================

func test_get_threat_weight_returns_own_value() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.threat_weights = {"wounded_target": 2.0}
	var weight: float = behavior.get_threat_weight("wounded_target", 1.0)
	assert_float(weight).is_equal(2.0)


func test_get_threat_weight_returns_default_when_missing() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	var weight: float = behavior.get_threat_weight("nonexistent_key", 1.5)
	assert_float(weight).is_equal(1.5)


func test_threat_weights_dictionary_can_store_multiple() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.threat_weights = {"healer": 1.8, "wounded_target": 2.0, "proximity": 1.2}

	assert_float(behavior.get_threat_weight("healer", 0.0)).is_equal(1.8)
	assert_float(behavior.get_threat_weight("wounded_target", 0.0)).is_equal(2.0)
	assert_float(behavior.get_threat_weight("proximity", 0.0)).is_equal(1.2)


func test_threat_weights_empty_returns_default() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	var weight: float = behavior.get_threat_weight("any_key", 1.0)
	assert_float(weight).is_equal(1.0)


# =============================================================================
# RETREAT TESTS
# =============================================================================

func test_retreat_hp_threshold_stored_correctly() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.retreat_hp_threshold = 50
	assert_int(behavior.retreat_hp_threshold).is_equal(50)


func test_retreat_hp_threshold_defaults_to_30() -> void:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	assert_int(behavior.retreat_hp_threshold).is_equal(30)


func test_retreat_enabled_defaults_to_true() -> void:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	assert_bool(behavior.retreat_enabled).is_true()


func test_retreat_enabled_can_be_disabled() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.retreat_enabled = false
	assert_bool(behavior.retreat_enabled).is_false()


# =============================================================================
# PHASE EVALUATION TESTS
# =============================================================================

func test_evaluate_phase_changes_returns_empty_when_no_phases() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	var context: Dictionary = {"unit_hp_percent": 50.0}
	var changes: Dictionary = behavior.evaluate_phase_changes(context)
	assert_bool(changes.is_empty()).is_true()


func test_evaluate_phase_changes_hp_below_triggers() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.behavior_phases = [
		{"trigger": "hp_below", "value": 50, "changes": {"behavior_mode": "cautious"}}
	]

	var context: Dictionary = {"unit_hp_percent": 30.0}
	var changes: Dictionary = behavior.evaluate_phase_changes(context)

	assert_str(changes.get("behavior_mode", "")).is_equal("cautious")


func test_evaluate_phase_changes_hp_below_does_not_trigger_when_above() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.behavior_phases = [
		{"trigger": "hp_below", "value": 50, "changes": {"behavior_mode": "cautious"}}
	]

	var context: Dictionary = {"unit_hp_percent": 75.0}
	var changes: Dictionary = behavior.evaluate_phase_changes(context)

	assert_bool(changes.is_empty()).is_true()


func test_evaluate_phase_changes_hp_above_triggers() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.behavior_phases = [
		{"trigger": "hp_above", "value": 80, "changes": {"role": "aggressive"}}
	]

	var context: Dictionary = {"unit_hp_percent": 95.0}
	var changes: Dictionary = behavior.evaluate_phase_changes(context)

	assert_str(changes.get("role", "")).is_equal("aggressive")


func test_evaluate_phase_changes_turn_count_triggers() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.behavior_phases = [
		{"trigger": "turn_count", "value": 5, "changes": {"retreat_enabled": false}}
	]

	var context: Dictionary = {"turn_number": 7}
	var changes: Dictionary = behavior.evaluate_phase_changes(context)

	assert_bool(changes.get("retreat_enabled", true)).is_false()


func test_evaluate_phase_changes_turn_count_does_not_trigger_early() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.behavior_phases = [
		{"trigger": "turn_count", "value": 5, "changes": {"retreat_enabled": false}}
	]

	var context: Dictionary = {"turn_number": 3}
	var changes: Dictionary = behavior.evaluate_phase_changes(context)

	assert_bool(changes.is_empty()).is_true()


func test_evaluate_phase_changes_ally_died_triggers() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.behavior_phases = [
		{"trigger": "ally_died", "value": "boss_healer", "changes": {"behavior_mode": "berserk"}}
	]

	var context: Dictionary = {"dead_ally_ids": ["boss_healer", "minion_1"]}
	var changes: Dictionary = behavior.evaluate_phase_changes(context)

	assert_str(changes.get("behavior_mode", "")).is_equal("berserk")


func test_evaluate_phase_changes_ally_count_below_triggers() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.behavior_phases = [
		{"trigger": "ally_count_below", "value": 3, "changes": {"retreat_when_outnumbered": true}}
	]

	var context: Dictionary = {"ally_count": 2}
	var changes: Dictionary = behavior.evaluate_phase_changes(context)

	assert_bool(changes.get("retreat_when_outnumbered", false)).is_true()


func test_evaluate_phase_changes_enemy_count_below_triggers() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.behavior_phases = [
		{"trigger": "enemy_count_below", "value": 2, "changes": {"behavior_mode": "aggressive"}}
	]

	var context: Dictionary = {"enemy_count": 1}
	var changes: Dictionary = behavior.evaluate_phase_changes(context)

	assert_str(changes.get("behavior_mode", "")).is_equal("aggressive")


func test_evaluate_phase_changes_flag_set_triggers() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.behavior_phases = [
		{"trigger": "flag_set", "value": "boss_enraged", "changes": {"role": "aggressive"}}
	]

	var context: Dictionary = {"story_flags": {"boss_enraged": true}}
	var changes: Dictionary = behavior.evaluate_phase_changes(context)

	assert_str(changes.get("role", "")).is_equal("aggressive")


func test_evaluate_phase_changes_multiple_phases_merge() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.behavior_phases = [
		{"trigger": "hp_below", "value": 75, "changes": {"behavior_mode": "cautious"}},
		{"trigger": "hp_below", "value": 25, "changes": {"role": "berserker", "retreat_enabled": false}}
	]

	var context: Dictionary = {"unit_hp_percent": 20.0}
	var changes: Dictionary = behavior.evaluate_phase_changes(context)

	# Both phases should trigger, with later phases overriding earlier
	assert_str(changes.get("behavior_mode", "")).is_equal("cautious")
	assert_str(changes.get("role", "")).is_equal("berserker")
	assert_bool(changes.get("retreat_enabled", true)).is_false()


func test_evaluate_phase_changes_later_phases_override_earlier() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.behavior_phases = [
		{"trigger": "hp_below", "value": 80, "changes": {"behavior_mode": "cautious"}},
		{"trigger": "hp_below", "value": 40, "changes": {"behavior_mode": "opportunistic"}}
	]

	var context: Dictionary = {"unit_hp_percent": 30.0}
	var changes: Dictionary = behavior.evaluate_phase_changes(context)

	# Later phase should override - both trigger but "opportunistic" wins
	assert_str(changes.get("behavior_mode", "")).is_equal("opportunistic")


func test_evaluate_phase_changes_unknown_trigger_ignored() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.behavior_phases = [
		{"trigger": "unknown_trigger_type", "value": 100, "changes": {"role": "invalid"}}
	]

	var context: Dictionary = {"some_value": 100}
	var changes: Dictionary = behavior.evaluate_phase_changes(context)

	assert_bool(changes.is_empty()).is_true()


# =============================================================================
# VALIDATION TESTS
# =============================================================================

func test_validate_passes_with_valid_data() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("valid_behavior", "aggressive", "aggressive")
	var result: Dictionary = behavior.validate_detailed()
	assert_bool(result.valid).is_true()
	assert_int(result.errors.size()).is_equal(0)


func test_validate_fails_with_empty_id() -> void:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = ""
	var result: Dictionary = behavior.validate_detailed()
	assert_bool(result.valid).is_false()
	assert_bool("Behavior ID cannot be empty" in result.errors[0]).is_true()


func test_validate_fails_with_whitespace_only_id() -> void:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = "   "
	var result: Dictionary = behavior.validate_detailed()
	assert_bool(result.valid).is_false()


func test_validate_fails_with_phase_missing_trigger() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.behavior_phases = [
		{"value": 50, "changes": {"role": "aggressive"}}  # Missing "trigger"
	]
	var result: Dictionary = behavior.validate_detailed()
	assert_bool(result.valid).is_false()
	assert_bool("missing 'trigger'" in result.errors[0]).is_true()


func test_validate_fails_with_phase_missing_changes() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.behavior_phases = [
		{"trigger": "hp_below", "value": 50}  # Missing "changes"
	]
	var result: Dictionary = behavior.validate_detailed()
	assert_bool(result.valid).is_false()
	assert_bool("missing 'changes'" in result.errors[0]).is_true()


func test_validate_accumulates_multiple_errors() -> void:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = ""  # Error 1: empty ID
	behavior.behavior_phases = [
		{"value": 50, "changes": {}},  # Error 2: missing trigger
		{"trigger": "hp_below"}  # Error 3: missing changes
	]

	var result: Dictionary = behavior.validate_detailed()
	assert_bool(result.valid).is_false()
	assert_int(result.errors.size()).is_equal(3)


# =============================================================================
# BEHAVIOR SUMMARY TESTS
# =============================================================================

func test_get_behavior_summary_includes_role_and_mode() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test", "support", "cautious")
	var summary: String = behavior.get_behavior_summary()
	assert_bool(summary.contains("Support")).is_true()
	assert_bool(summary.contains("Cautious")).is_true()


func test_get_behavior_summary_includes_retreat_info() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test", "aggressive", "aggressive")
	behavior.retreat_hp_threshold = 40
	behavior.retreat_enabled = true
	var summary: String = behavior.get_behavior_summary()
	assert_bool(summary.contains("40%")).is_true()


func test_get_behavior_summary_shows_no_retreat_when_disabled() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test", "aggressive", "aggressive")
	behavior.retreat_enabled = false
	var summary: String = behavior.get_behavior_summary()
	assert_bool(summary.contains("No retreat")).is_true()


func test_get_behavior_summary_includes_phase_count() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test", "tactical", "cautious")
	behavior.behavior_phases = [
		{"trigger": "hp_below", "value": 50, "changes": {}},
		{"trigger": "hp_below", "value": 25, "changes": {}}
	]
	var summary: String = behavior.get_behavior_summary()
	assert_bool(summary.contains("2 phase")).is_true()


# =============================================================================
# EXPORTED PROPERTY DEFAULTS TESTS
# =============================================================================

func test_default_aoe_minimum_targets() -> void:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	assert_int(behavior.aoe_minimum_targets).is_equal(2)


func test_default_conserve_mp_on_heals() -> void:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	assert_bool(behavior.conserve_mp_on_heals).is_true()


func test_default_prioritize_boss_heals() -> void:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	assert_bool(behavior.prioritize_boss_heals).is_true()


func test_default_use_status_effects() -> void:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	assert_bool(behavior.use_status_effects).is_true()


func test_default_use_healing_items() -> void:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	assert_bool(behavior.use_healing_items).is_true()


func test_default_alert_range() -> void:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	assert_int(behavior.alert_range).is_equal(8)


func test_default_engagement_range() -> void:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	assert_int(behavior.engagement_range).is_equal(5)


func test_default_ignore_protagonist_priority() -> void:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	assert_bool(behavior.ignore_protagonist_priority).is_true()


# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_empty_threat_weights_dictionary_access() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	# Should not crash and return default
	var weight: float = behavior.get_threat_weight("any_key", 1.0)
	assert_float(weight).is_equal(1.0)


func test_phase_with_empty_changes_dictionary() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.behavior_phases = [
		{"trigger": "hp_below", "value": 50, "changes": {}}
	]
	var context: Dictionary = {"unit_hp_percent": 30.0}
	var changes: Dictionary = behavior.evaluate_phase_changes(context)
	# Should not crash, returns empty since changes was empty
	assert_bool(changes.is_empty()).is_true()


func test_phase_with_non_dictionary_changes_ignored() -> void:
	var behavior: AIBehaviorData = _create_test_behavior("test")
	behavior.behavior_phases = [
		{"trigger": "hp_below", "value": 50, "changes": "not a dictionary"}
	]
	var context: Dictionary = {"unit_hp_percent": 30.0}
	var changes: Dictionary = behavior.evaluate_phase_changes(context)
	# Should not crash
	assert_bool(changes.is_empty()).is_true()
