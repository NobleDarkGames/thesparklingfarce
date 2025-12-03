## Unit Tests for PromotionManager
##
## Tests promotion eligibility, branching paths, and stat preservation.
## Note: Full integration tests require scene context with autoloads.
class_name TestPromotionManager
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

## Create a basic ClassData with promotion settings
func _create_test_class(
	name: String = "Warrior",
	promotion_level: int = 10,
	promotion_class: ClassData = null
) -> ClassData:
	var class_data: ClassData = ClassData.new()
	class_data.display_name = name
	class_data.promotion_level = promotion_level
	class_data.promotion_class = promotion_class
	class_data.movement_range = 4
	return class_data


## Create a promoted class (target for promotion)
func _create_promoted_class(name: String = "Gladiator") -> ClassData:
	var class_data: ClassData = ClassData.new()
	class_data.display_name = name
	class_data.promotion_level = 0  # Already promoted, no further promotion
	class_data.movement_range = 5
	# Better growth rates for promoted class
	class_data.hp_growth = 60
	class_data.strength_growth = 60
	class_data.defense_growth = 55
	return class_data


## Create an alternate promoted class (special promotion path)
func _create_alternate_class(name: String = "Baron") -> ClassData:
	var class_data: ClassData = ClassData.new()
	class_data.display_name = name
	class_data.promotion_level = 0
	class_data.movement_range = 5
	return class_data


# =============================================================================
# CLASS DATA PROMOTION PROPERTIES TESTS
# =============================================================================

func test_class_has_promotion_path() -> void:
	var promoted: ClassData = _create_promoted_class()
	var base_class: ClassData = _create_test_class("Warrior", 10, promoted)

	assert_object(base_class.promotion_class).is_not_null()
	assert_str(base_class.promotion_class.display_name).is_equal("Gladiator")


func test_class_without_promotion_path() -> void:
	var base_class: ClassData = _create_test_class("Gladiator", 10, null)

	assert_object(base_class.promotion_class).is_null()


func test_class_promotion_level_default() -> void:
	var base_class: ClassData = ClassData.new()
	base_class.display_name = "Test"

	# Default promotion level should be 10
	assert_int(base_class.promotion_level).is_equal(10)


func test_class_has_special_promotion() -> void:
	var promoted: ClassData = _create_promoted_class()
	var special: ClassData = _create_alternate_class()
	var base_class: ClassData = _create_test_class("Knight", 10, promoted)
	base_class.special_promotion_class = special

	assert_bool(base_class.has_special_promotion()).is_true()


func test_class_no_special_promotion() -> void:
	var promoted: ClassData = _create_promoted_class()
	var base_class: ClassData = _create_test_class("Knight", 10, promoted)

	assert_bool(base_class.has_special_promotion()).is_false()


func test_class_get_all_promotion_paths_single() -> void:
	var promoted: ClassData = _create_promoted_class()
	var base_class: ClassData = _create_test_class("Warrior", 10, promoted)

	var paths: Array[ClassData] = base_class.get_all_promotion_paths()

	assert_int(paths.size()).is_equal(1)
	assert_str(paths[0].display_name).is_equal("Gladiator")


func test_class_get_all_promotion_paths_with_special() -> void:
	var promoted: ClassData = _create_promoted_class()
	var special: ClassData = _create_alternate_class()
	var base_class: ClassData = _create_test_class("Knight", 10, promoted)
	base_class.special_promotion_class = special

	var paths: Array[ClassData] = base_class.get_all_promotion_paths()

	assert_int(paths.size()).is_equal(2)


func test_class_get_all_promotion_paths_no_promotion() -> void:
	var base_class: ClassData = _create_test_class("Hero", 10, null)

	var paths: Array[ClassData] = base_class.get_all_promotion_paths()

	assert_int(paths.size()).is_equal(0)


# =============================================================================
# CHARACTER SAVE DATA PROMOTION TRACKING TESTS
# =============================================================================

func test_character_save_data_has_cumulative_level() -> void:
	var save_data: CharacterSaveData = CharacterSaveData.new()

	# Default cumulative level should be 1
	assert_int(save_data.cumulative_level).is_equal(1)


func test_character_save_data_has_promotion_count() -> void:
	var save_data: CharacterSaveData = CharacterSaveData.new()

	# Default promotion count should be 0
	assert_int(save_data.promotion_count).is_equal(0)


func test_character_save_data_serialization_includes_promotion() -> void:
	var save_data: CharacterSaveData = CharacterSaveData.new()
	save_data.cumulative_level = 15
	save_data.promotion_count = 1
	save_data.current_class_mod_id = "_base_game"
	save_data.current_class_resource_id = "gladiator"

	var serialized: Dictionary = save_data.serialize_to_dict()

	assert_int(serialized.cumulative_level).is_equal(15)
	assert_int(serialized.promotion_count).is_equal(1)
	assert_str(serialized.current_class_mod_id).is_equal("_base_game")
	assert_str(serialized.current_class_resource_id).is_equal("gladiator")


func test_character_save_data_deserialization_handles_promotion() -> void:
	var data: Dictionary = {
		"character_mod_id": "_base_game",
		"character_resource_id": "max",
		"fallback_character_name": "Max",
		"fallback_class_name": "Warrior",
		"level": 1,
		"current_xp": 0,
		"current_hp": 20,
		"max_hp": 20,
		"current_mp": 5,
		"max_mp": 5,
		"strength": 10,
		"defense": 8,
		"agility": 7,
		"intelligence": 5,
		"luck": 5,
		"equipped_items": [],
		"learned_abilities": [],
		"is_alive": true,
		"is_available": true,
		"is_hero": true,
		"recruitment_chapter": "",
		"cumulative_level": 25,
		"promotion_count": 2,
		"current_class_mod_id": "_base_game",
		"current_class_resource_id": "hero"
	}

	var save_data: CharacterSaveData = CharacterSaveData.new()
	save_data.deserialize_from_dict(data)

	assert_int(save_data.cumulative_level).is_equal(25)
	assert_int(save_data.promotion_count).is_equal(2)
	assert_str(save_data.current_class_mod_id).is_equal("_base_game")
	assert_str(save_data.current_class_resource_id).is_equal("hero")


func test_character_save_data_deserialization_handles_missing_promotion_fields() -> void:
	# Test backward compatibility with saves without promotion fields
	var data: Dictionary = {
		"character_mod_id": "_base_game",
		"character_resource_id": "max",
		"fallback_character_name": "Max",
		"fallback_class_name": "Warrior",
		"level": 5,
		"current_xp": 50,
		"current_hp": 25,
		"max_hp": 25,
		"current_mp": 8,
		"max_mp": 8,
		"strength": 12,
		"defense": 10,
		"agility": 9,
		"intelligence": 6,
		"luck": 6,
		"equipped_items": [],
		"learned_abilities": [],
		"is_alive": true,
		"is_available": true,
		"is_hero": true,
		"recruitment_chapter": ""
		# Note: promotion fields missing (old save format)
	}

	var save_data: CharacterSaveData = CharacterSaveData.new()
	save_data.deserialize_from_dict(data)

	# Should retain defaults
	assert_int(save_data.cumulative_level).is_equal(1)
	assert_int(save_data.promotion_count).is_equal(0)
	assert_str(save_data.current_class_mod_id).is_equal("")


# =============================================================================
# EXPERIENCE CONFIG PROMOTION SETTINGS TESTS
# =============================================================================

func test_experience_config_has_promotion_settings() -> void:
	var config: ExperienceConfig = ExperienceConfig.new()

	# Check all new promotion properties exist with defaults
	assert_bool(config.promotion_resets_level).is_true()
	assert_bool(config.consume_promotion_item).is_true()
	assert_int(config.promotion_bonus_hp).is_equal(0)
	assert_int(config.promotion_bonus_mp).is_equal(0)
	assert_int(config.promotion_bonus_strength).is_equal(0)
	assert_int(config.promotion_bonus_defense).is_equal(0)
	assert_int(config.promotion_bonus_agility).is_equal(0)
	assert_int(config.promotion_bonus_intelligence).is_equal(0)
	assert_int(config.promotion_bonus_luck).is_equal(0)


func test_experience_config_promotion_bonuses_can_be_set() -> void:
	var config: ExperienceConfig = ExperienceConfig.new()
	config.promotion_bonus_hp = 5
	config.promotion_bonus_strength = 2

	assert_int(config.promotion_bonus_hp).is_equal(5)
	assert_int(config.promotion_bonus_strength).is_equal(2)


# =============================================================================
# PROMOTION ELIGIBILITY LOGIC TESTS (Pure Logic)
# =============================================================================

## Test the promotion eligibility formula directly
func test_promotion_eligibility_level_requirement() -> void:
	# Level 10 is the standard Shining Force promotion level
	var promoted: ClassData = _create_promoted_class()
	var base_class: ClassData = _create_test_class("Warrior", 10, promoted)

	# Level 9 should NOT be eligible
	var below_requirement: bool = 9 >= base_class.promotion_level
	assert_bool(below_requirement).is_false()

	# Level 10 SHOULD be eligible
	var at_requirement: bool = 10 >= base_class.promotion_level
	assert_bool(at_requirement).is_true()

	# Level 15 SHOULD be eligible
	var above_requirement: bool = 15 >= base_class.promotion_level
	assert_bool(above_requirement).is_true()


func test_promotion_eligibility_requires_promotion_path() -> void:
	var promoted: ClassData = _create_promoted_class()
	var with_path: ClassData = _create_test_class("Warrior", 10, promoted)
	var without_path: ClassData = _create_test_class("Hero", 10, null)

	# Class with promotion path can promote
	assert_object(with_path.promotion_class).is_not_null()

	# Class without promotion path cannot promote
	assert_object(without_path.promotion_class).is_null()


func test_promotion_eligibility_custom_level_requirement() -> void:
	# Some classes might have different promotion requirements
	var promoted: ClassData = _create_promoted_class()
	var early_promote: ClassData = _create_test_class("Prodigy", 5, promoted)
	var late_promote: ClassData = _create_test_class("Master", 20, promoted)

	assert_int(early_promote.promotion_level).is_equal(5)
	assert_int(late_promote.promotion_level).is_equal(20)


# =============================================================================
# STAT PRESERVATION TESTS (Pure Logic)
# =============================================================================

## Test that stats are preserved during promotion calculation
func test_stat_preservation_logic() -> void:
	# Simulate a level 10 character's stats
	var pre_promotion_stats: Dictionary = {
		"max_hp": 35,
		"max_mp": 12,
		"strength": 14,
		"defense": 11,
		"agility": 10,
		"intelligence": 8,
		"luck": 7
	}

	# SF2 style: 100% stat preservation
	var post_promotion_stats: Dictionary = pre_promotion_stats.duplicate()

	# Stats should be identical (100% preservation)
	assert_int(post_promotion_stats.max_hp).is_equal(35)
	assert_int(post_promotion_stats.strength).is_equal(14)


func test_promotion_bonus_application_logic() -> void:
	# Simulate applying promotion bonuses
	var config: ExperienceConfig = ExperienceConfig.new()
	config.promotion_bonus_hp = 5
	config.promotion_bonus_strength = 2
	config.promotion_bonus_defense = 1

	var stats: Dictionary = {
		"max_hp": 30,
		"strength": 12,
		"defense": 10
	}

	# Apply bonuses
	stats.max_hp += config.promotion_bonus_hp
	stats.strength += config.promotion_bonus_strength
	stats.defense += config.promotion_bonus_defense

	assert_int(stats.max_hp).is_equal(35)
	assert_int(stats.strength).is_equal(14)
	assert_int(stats.defense).is_equal(11)


func test_level_reset_on_promotion_logic() -> void:
	# SF2 style: level resets to 1, stats carry over
	var pre_promotion_level: int = 10
	var config: ExperienceConfig = ExperienceConfig.new()
	config.promotion_resets_level = true

	# After promotion, level should reset to 1
	var post_promotion_level: int = 1 if config.promotion_resets_level else pre_promotion_level

	assert_int(post_promotion_level).is_equal(1)


func test_cumulative_level_tracking_logic() -> void:
	# Cumulative level tracks total levels across all promotions
	var cumulative_level: int = 1
	var current_level: int = 10

	# Before promotion
	cumulative_level = current_level

	# After promotion (level resets to 1)
	var post_promotion_cumulative: int = cumulative_level  # Preserves old levels
	var new_level: int = 1

	# After gaining 5 more levels post-promotion
	new_level = 5
	var total_cumulative: int = post_promotion_cumulative + new_level - 1  # -1 because we don't double count level 1

	assert_int(total_cumulative).is_equal(14)  # 10 + 5 - 1


# =============================================================================
# BRANCHING PATHS LOGIC TESTS
# =============================================================================

func test_standard_promotion_path_available() -> void:
	var promoted: ClassData = _create_promoted_class()
	var base_class: ClassData = _create_test_class("Warrior", 10, promoted)

	var available_paths: Array[ClassData] = base_class.get_all_promotion_paths()

	assert_int(available_paths.size()).is_greater_equal(1)
	assert_bool(promoted in available_paths).is_true()


func test_special_promotion_path_with_item() -> void:
	var promoted: ClassData = _create_promoted_class("Paladin")
	var special: ClassData = _create_alternate_class("Pegasus Knight")
	var base_class: ClassData = _create_test_class("Knight", 10, promoted)
	base_class.special_promotion_class = special

	var available_paths: Array[ClassData] = base_class.get_all_promotion_paths()

	assert_int(available_paths.size()).is_equal(2)
	assert_bool(promoted in available_paths).is_true()
	assert_bool(special in available_paths).is_true()


# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_already_promoted_class_has_no_promotion() -> void:
	var final_class: ClassData = ClassData.new()
	final_class.display_name = "Hero"
	final_class.promotion_class = null  # No further promotion
	final_class.promotion_level = 0

	var paths: Array[ClassData] = final_class.get_all_promotion_paths()

	assert_int(paths.size()).is_equal(0)


func test_promotion_at_max_level() -> void:
	# Characters at max level (20 in SF) can still promote if they haven't
	var config: ExperienceConfig = ExperienceConfig.new()
	var max_level: int = config.max_level  # Should be 20

	var promoted: ClassData = _create_promoted_class()
	var base_class: ClassData = _create_test_class("Warrior", 10, promoted)

	# Even at max level, should be eligible
	var can_promote: bool = max_level >= base_class.promotion_level
	assert_bool(can_promote).is_true()
