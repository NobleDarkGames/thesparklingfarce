## Unit tests for AIBehaviorFactory fixture
##
## Verifies that the factory creates valid AIBehaviorData resources
## with the expected properties.
class_name TestAIBehaviorFactory
extends GdUnitTestSuite


const AIBehaviorFactoryScript = preload("res://tests/fixtures/ai_behavior_factory.gd")


# =============================================================================
# AGGRESSIVE BEHAVIOR TESTS
# =============================================================================

func test_create_aggressive_returns_valid_behavior() -> void:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_aggressive()

	assert_object(behavior).is_not_null()
	assert_str(behavior.behavior_id).is_equal("test_aggressive")
	assert_str(behavior.role).is_equal("aggressive")
	assert_str(behavior.behavior_mode).is_equal("aggressive")
	assert_bool(behavior.retreat_enabled).is_false()


func test_create_aggressive_with_custom_id() -> void:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_aggressive("my_aggressive")

	assert_str(behavior.behavior_id).is_equal("my_aggressive")


# =============================================================================
# OPPORTUNISTIC BEHAVIOR TESTS
# =============================================================================

func test_create_opportunistic_returns_valid_behavior() -> void:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_opportunistic()

	assert_object(behavior).is_not_null()
	assert_str(behavior.behavior_id).is_equal("test_opportunistic")
	assert_str(behavior.behavior_mode).is_equal("opportunistic")
	assert_bool("wounded_target" in behavior.threat_weights).is_true()
	assert_float(behavior.threat_weights.wounded_target).is_equal(2.0)


# =============================================================================
# DEFENSIVE BEHAVIOR TESTS
# =============================================================================

func test_create_defensive_returns_valid_behavior() -> void:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_defensive()

	assert_object(behavior).is_not_null()
	assert_str(behavior.role).is_equal("defensive")
	assert_str(behavior.behavior_mode).is_equal("cautious")


# =============================================================================
# SUPPORT BEHAVIOR TESTS
# =============================================================================

func test_create_support_returns_valid_behavior() -> void:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_support()

	assert_object(behavior).is_not_null()
	assert_str(behavior.role).is_equal("support")
	assert_bool(behavior.retreat_enabled).is_true()
	assert_bool(behavior.use_healing_items).is_true()


# =============================================================================
# STATIONARY GUARD BEHAVIOR TESTS
# =============================================================================

func test_create_stationary_guard_returns_valid_behavior() -> void:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_stationary_guard()

	assert_object(behavior).is_not_null()
	assert_str(behavior.behavior_id).is_equal("test_stationary_guard")
	assert_int(behavior.alert_range).is_equal(1)
	assert_int(behavior.engagement_range).is_equal(1)
	assert_bool(behavior.retreat_enabled).is_false()


# =============================================================================
# RETREAT BEHAVIOR TESTS
# =============================================================================

func test_create_retreat_when_hurt_returns_valid_behavior() -> void:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_retreat_when_hurt()

	assert_object(behavior).is_not_null()
	assert_bool(behavior.retreat_enabled).is_true()
	assert_int(behavior.retreat_hp_threshold).is_equal(60)


func test_create_retreat_with_custom_threshold() -> void:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_retreat_when_hurt("test", 40)

	assert_int(behavior.retreat_hp_threshold).is_equal(40)


# =============================================================================
# CAUTIOUS BEHAVIOR TESTS
# =============================================================================

func test_create_cautious_returns_valid_behavior() -> void:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_cautious()

	assert_object(behavior).is_not_null()
	assert_str(behavior.behavior_mode).is_equal("cautious")
	assert_int(behavior.alert_range).is_equal(6)
	assert_int(behavior.engagement_range).is_equal(3)


func test_create_cautious_with_custom_ranges() -> void:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_cautious("test", 10, 5)

	assert_int(behavior.alert_range).is_equal(10)
	assert_int(behavior.engagement_range).is_equal(5)


# =============================================================================
# TACTICAL BEHAVIOR TESTS
# =============================================================================

func test_create_tactical_returns_valid_behavior() -> void:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_tactical()

	assert_object(behavior).is_not_null()
	assert_str(behavior.role).is_equal("tactical")
	assert_bool(behavior.use_status_effects).is_true()
	assert_bool("damage_dealer" in behavior.threat_weights).is_true()


# =============================================================================
# AOE MAGE BEHAVIOR TESTS
# =============================================================================

func test_create_aoe_mage_returns_valid_behavior() -> void:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_aoe_mage()

	assert_object(behavior).is_not_null()
	assert_int(behavior.aoe_minimum_targets).is_equal(2)


func test_create_aoe_mage_with_custom_minimum() -> void:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_aoe_mage("test", 3)

	assert_int(behavior.aoe_minimum_targets).is_equal(3)


# =============================================================================
# TERRAIN SEEKER BEHAVIOR TESTS
# =============================================================================

func test_create_terrain_seeker_returns_valid_behavior() -> void:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_terrain_seeker()

	assert_object(behavior).is_not_null()
	assert_bool(behavior.seek_terrain_advantage).is_true()


# =============================================================================
# RANGED BEHAVIOR TESTS
# =============================================================================

func test_create_ranged_returns_valid_behavior() -> void:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_ranged()

	assert_object(behavior).is_not_null()
	assert_str(behavior.behavior_mode).is_equal("opportunistic")
	assert_bool(behavior.retreat_enabled).is_true()
	assert_int(behavior.retreat_hp_threshold).is_equal(40)


# =============================================================================
# CUSTOM BEHAVIOR TESTS
# =============================================================================

func test_create_custom_with_defaults() -> void:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_custom({})

	assert_object(behavior).is_not_null()
	assert_str(behavior.behavior_id).is_equal("test_custom")
	assert_str(behavior.role).is_equal("aggressive")


func test_create_custom_with_all_options() -> void:
	var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_custom({
		"behavior_id": "custom_id",
		"display_name": "My Custom Behavior",
		"role": "support",
		"behavior_mode": "cautious",
		"retreat_enabled": true,
		"retreat_hp_threshold": 50,
		"use_healing_items": true,
		"use_status_effects": true,
		"alert_range": 8,
		"engagement_range": 4,
		"aoe_minimum_targets": 3,
		"seek_terrain_advantage": true,
		"threat_weights": {"custom_weight": 1.5}
	})

	assert_str(behavior.behavior_id).is_equal("custom_id")
	assert_str(behavior.display_name).is_equal("My Custom Behavior")
	assert_str(behavior.role).is_equal("support")
	assert_str(behavior.behavior_mode).is_equal("cautious")
	assert_bool(behavior.retreat_enabled).is_true()
	assert_int(behavior.retreat_hp_threshold).is_equal(50)
	assert_bool(behavior.use_healing_items).is_true()
	assert_bool(behavior.use_status_effects).is_true()
	assert_int(behavior.alert_range).is_equal(8)
	assert_int(behavior.engagement_range).is_equal(4)
	assert_int(behavior.aoe_minimum_targets).is_equal(3)
	assert_bool(behavior.seek_terrain_advantage).is_true()
	assert_bool("custom_weight" in behavior.threat_weights).is_true()
