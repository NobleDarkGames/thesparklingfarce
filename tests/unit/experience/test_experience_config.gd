## Unit Tests for ExperienceConfig
##
## Tests the experience configuration resource, including the new catch-up mechanics
## added in Phase 4 for formation and support XP bonuses.
class_name TestExperienceConfig
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

var _config: ExperienceConfig


func before_test() -> void:
	# Create a fresh config for each test
	_config = ExperienceConfig.new()


# =============================================================================
# BASE XP LEVEL DIFFERENCE TESTS
# =============================================================================

func test_get_base_xp_same_level() -> void:
	var xp: int = _config.get_base_xp_from_level_diff(0)
	assert_int(xp).is_equal(50)


func test_get_base_xp_higher_enemy() -> void:
	var xp: int = _config.get_base_xp_from_level_diff(1)
	assert_int(xp).is_equal(50)


func test_get_base_xp_lower_enemy() -> void:
	var xp: int = _config.get_base_xp_from_level_diff(-2)
	assert_int(xp).is_equal(50)


func test_get_base_xp_much_lower_enemy() -> void:
	var xp: int = _config.get_base_xp_from_level_diff(-5)
	assert_int(xp).is_equal(20)


func test_get_base_xp_very_low_enemy_no_xp() -> void:
	var xp: int = _config.get_base_xp_from_level_diff(-7)
	assert_int(xp).is_equal(0)


func test_get_base_xp_extremely_low_clamps_to_minimum() -> void:
	var xp: int = _config.get_base_xp_from_level_diff(-20)
	assert_int(xp).is_equal(0)


func test_get_base_xp_extremely_high_clamps_to_maximum() -> void:
	var xp: int = _config.get_base_xp_from_level_diff(20)
	assert_int(xp).is_equal(50)


# =============================================================================
# ANTI-SPAM MULTIPLIER TESTS
# =============================================================================

func test_anti_spam_first_uses_full_xp() -> void:
	var mult: float = _config.get_anti_spam_multiplier(0)
	assert_float(mult).is_equal(1.0)


func test_anti_spam_below_medium_threshold_full_xp() -> void:
	var mult: float = _config.get_anti_spam_multiplier(4)
	assert_float(mult).is_equal(1.0)


func test_anti_spam_at_medium_threshold_reduced() -> void:
	var mult: float = _config.get_anti_spam_multiplier(5)
	assert_float(mult).is_equal(0.6)


func test_anti_spam_between_thresholds_reduced() -> void:
	var mult: float = _config.get_anti_spam_multiplier(7)
	assert_float(mult).is_equal(0.6)


func test_anti_spam_at_heavy_threshold_heavily_reduced() -> void:
	var mult: float = _config.get_anti_spam_multiplier(8)
	assert_float(mult).is_equal(0.3)


func test_anti_spam_above_heavy_threshold_heavily_reduced() -> void:
	var mult: float = _config.get_anti_spam_multiplier(20)
	assert_float(mult).is_equal(0.3)


func test_anti_spam_disabled_returns_full() -> void:
	_config.anti_spam_enabled = false
	var mult: float = _config.get_anti_spam_multiplier(100)
	assert_float(mult).is_equal(1.0)


# =============================================================================
# CATCH-UP RATE CONFIGURATION TESTS
# =============================================================================

func test_default_formation_catch_up_rate() -> void:
	assert_float(_config.formation_catch_up_rate).is_equal(0.15)


func test_default_support_catch_up_rate() -> void:
	assert_float(_config.support_catch_up_rate).is_equal(0.15)


func test_formation_catch_up_rate_export_range() -> void:
	# Should be clamped between 0.0 and 0.5
	assert_float(_config.formation_catch_up_rate).is_greater_equal(0.0)
	assert_float(_config.formation_catch_up_rate).is_less_equal(0.5)


func test_support_catch_up_rate_export_range() -> void:
	# Should be clamped between 0.0 and 0.5
	assert_float(_config.support_catch_up_rate).is_greater_equal(0.0)
	assert_float(_config.support_catch_up_rate).is_less_equal(0.5)


# =============================================================================
# FORMATION XP CONFIGURATION TESTS
# =============================================================================

func test_default_formation_enabled() -> void:
	assert_bool(_config.enable_formation_xp).is_true()


func test_default_formation_radius() -> void:
	assert_int(_config.formation_radius).is_equal(3)


func test_default_formation_multiplier() -> void:
	# Changed from 0.25 to 0.15 in the catch-up commit
	assert_float(_config.formation_multiplier).is_equal(0.15)


func test_default_formation_cap_ratio() -> void:
	assert_float(_config.formation_cap_ratio).is_equal(0.5)


# =============================================================================
# SUPPORT XP CONFIGURATION TESTS
# =============================================================================

func test_default_support_xp_enabled() -> void:
	assert_bool(_config.enable_enhanced_support_xp).is_true()


func test_default_heal_base_xp() -> void:
	assert_int(_config.heal_base_xp).is_equal(10)


func test_default_heal_ratio_multiplier() -> void:
	assert_int(_config.heal_ratio_multiplier).is_equal(25)


func test_default_buff_base_xp() -> void:
	assert_int(_config.buff_base_xp).is_equal(15)


func test_default_debuff_base_xp() -> void:
	assert_int(_config.debuff_base_xp).is_equal(15)


# =============================================================================
# LEVELING CONFIGURATION TESTS
# =============================================================================

func test_default_xp_per_level() -> void:
	assert_int(_config.xp_per_level).is_equal(100)


func test_default_max_level() -> void:
	assert_int(_config.max_level).is_equal(20)


func test_default_max_xp_per_action() -> void:
	assert_int(_config.max_xp_per_action).is_equal(49)


# =============================================================================
# CUSTOM CONFIGURATION TESTS
# =============================================================================

func test_custom_formation_catch_up_rate() -> void:
	_config.formation_catch_up_rate = 0.25
	assert_float(_config.formation_catch_up_rate).is_equal(0.25)


func test_custom_support_catch_up_rate() -> void:
	_config.support_catch_up_rate = 0.3
	assert_float(_config.support_catch_up_rate).is_equal(0.3)


func test_disabled_formation_catch_up() -> void:
	_config.formation_catch_up_rate = 0.0
	assert_float(_config.formation_catch_up_rate).is_equal(0.0)


func test_disabled_support_catch_up() -> void:
	_config.support_catch_up_rate = 0.0
	assert_float(_config.support_catch_up_rate).is_equal(0.0)


func test_custom_spam_thresholds() -> void:
	_config.spam_threshold_medium = 10
	_config.spam_threshold_heavy = 15

	# Below medium
	assert_float(_config.get_anti_spam_multiplier(9)).is_equal(1.0)
	# At medium
	assert_float(_config.get_anti_spam_multiplier(10)).is_equal(0.6)
	# At heavy
	assert_float(_config.get_anti_spam_multiplier(15)).is_equal(0.3)


# =============================================================================
# RESOURCE SERIALIZATION TESTS
# =============================================================================

func test_config_is_resource() -> void:
	assert_object(_config).is_instanceof(Resource)


func test_config_has_class_name() -> void:
	# get_class() returns "Resource", but the script defines class_name ExperienceConfig
	assert_str(_config.get_script().get_global_name()).is_equal("ExperienceConfig")
