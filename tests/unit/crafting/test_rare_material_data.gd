## Unit Tests for RareMaterialData Resource
##
## Tests the rare material data structure used in the crafting system.
class_name TestRareMaterialData
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

func _create_material(
	mat_name: String = "Test Material",
	category: String = "ore",
	rarity: RareMaterialData.Rarity = RareMaterialData.Rarity.COMMON,
	mat_tags: Array[String] = []
) -> RareMaterialData:
	var material: RareMaterialData = RareMaterialData.new()
	material.material_name = mat_name
	material.crafting_category = category
	material.rarity = rarity
	material.tags = mat_tags
	return material


# =============================================================================
# BASIC PROPERTY TESTS
# =============================================================================

func test_default_values() -> void:
	var material: RareMaterialData = RareMaterialData.new()

	assert_str(material.material_name).is_equal("")
	assert_str(material.crafting_category).is_equal("")
	assert_int(material.rarity).is_equal(RareMaterialData.Rarity.COMMON)
	assert_int(material.stack_limit).is_equal(99)
	assert_array(material.tags).is_empty()


func test_properties_set_correctly() -> void:
	var material: RareMaterialData = _create_material(
		"Mithril",
		"ore",
		RareMaterialData.Rarity.RARE,
		["metal", "magical"] as Array[String]
	)

	assert_str(material.material_name).is_equal("Mithril")
	assert_str(material.crafting_category).is_equal("ore")
	assert_int(material.rarity).is_equal(RareMaterialData.Rarity.RARE)
	assert_array(material.tags).contains(["metal", "magical"])


# =============================================================================
# TAG TESTS
# =============================================================================

func test_has_tag_returns_true_for_existing_tag() -> void:
	var material: RareMaterialData = _create_material(
		"Dragon Scale",
		"hide",
		RareMaterialData.Rarity.EPIC,
		["dragon", "fire", "armored"] as Array[String]
	)

	assert_bool(material.has_tag("dragon")).is_true()
	assert_bool(material.has_tag("fire")).is_true()
	assert_bool(material.has_tag("armored")).is_true()


func test_has_tag_returns_false_for_missing_tag() -> void:
	var material: RareMaterialData = _create_material(
		"Dragon Scale",
		"hide",
		RareMaterialData.Rarity.EPIC,
		["dragon", "fire"] as Array[String]
	)

	assert_bool(material.has_tag("ice")).is_false()
	assert_bool(material.has_tag("blessed")).is_false()


func test_has_tag_with_empty_tags() -> void:
	var material: RareMaterialData = _create_material("Plain Ore", "ore")

	assert_bool(material.has_tag("anything")).is_false()


# =============================================================================
# REQUIREMENT MATCHING TESTS
# =============================================================================

func test_matches_requirement_category_only() -> void:
	var material: RareMaterialData = _create_material("Iron Ore", "ore")

	assert_bool(material.matches_requirement("ore")).is_true()
	assert_bool(material.matches_requirement("gem")).is_false()


func test_matches_requirement_with_tags() -> void:
	var material: RareMaterialData = _create_material(
		"Holy Mithril",
		"ore",
		RareMaterialData.Rarity.LEGENDARY,
		["metal", "magical", "holy"] as Array[String]
	)

	# Should match with subset of tags
	assert_bool(material.matches_requirement("ore", ["metal"] as Array[String])).is_true()
	assert_bool(material.matches_requirement("ore", ["magical", "holy"] as Array[String])).is_true()

	# Should fail if any required tag is missing
	assert_bool(material.matches_requirement("ore", ["unholy"] as Array[String])).is_false()


func test_matches_requirement_wrong_category_with_right_tags() -> void:
	var material: RareMaterialData = _create_material(
		"Fire Gem",
		"gem",
		RareMaterialData.Rarity.RARE,
		["fire", "magical"] as Array[String]
	)

	# Category must match even if tags match
	assert_bool(material.matches_requirement("ore", ["fire"] as Array[String])).is_false()


# =============================================================================
# RARITY COLOR TESTS
# =============================================================================

func test_rarity_color_common() -> void:
	var material: RareMaterialData = _create_material("Common", "ore", RareMaterialData.Rarity.COMMON)
	assert_object(material.get_rarity_color()).is_equal(Color.WHITE)


func test_rarity_color_uncommon() -> void:
	var material: RareMaterialData = _create_material("Uncommon", "ore", RareMaterialData.Rarity.UNCOMMON)
	assert_object(material.get_rarity_color()).is_equal(Color.GREEN)


func test_rarity_color_rare() -> void:
	var material: RareMaterialData = _create_material("Rare", "ore", RareMaterialData.Rarity.RARE)
	assert_object(material.get_rarity_color()).is_equal(Color.CORNFLOWER_BLUE)


func test_rarity_color_epic() -> void:
	var material: RareMaterialData = _create_material("Epic", "ore", RareMaterialData.Rarity.EPIC)
	assert_object(material.get_rarity_color()).is_equal(Color.MEDIUM_PURPLE)


func test_rarity_color_legendary() -> void:
	var material: RareMaterialData = _create_material("Legendary", "ore", RareMaterialData.Rarity.LEGENDARY)
	assert_object(material.get_rarity_color()).is_equal(Color.ORANGE)


# =============================================================================
# RARITY NAME TESTS
# =============================================================================

func test_rarity_name_values() -> void:
	var common: RareMaterialData = _create_material("C", "ore", RareMaterialData.Rarity.COMMON)
	var uncommon: RareMaterialData = _create_material("U", "ore", RareMaterialData.Rarity.UNCOMMON)
	var rare: RareMaterialData = _create_material("R", "ore", RareMaterialData.Rarity.RARE)
	var epic: RareMaterialData = _create_material("E", "ore", RareMaterialData.Rarity.EPIC)
	var legendary: RareMaterialData = _create_material("L", "ore", RareMaterialData.Rarity.LEGENDARY)

	assert_str(common.get_rarity_name()).is_equal("Common")
	assert_str(uncommon.get_rarity_name()).is_equal("Uncommon")
	assert_str(rare.get_rarity_name()).is_equal("Rare")
	assert_str(epic.get_rarity_name()).is_equal("Epic")
	assert_str(legendary.get_rarity_name()).is_equal("Legendary")


# =============================================================================
# VALIDATION TESTS
# =============================================================================

func test_validate_passes_with_required_fields() -> void:
	var material: RareMaterialData = _create_material("Valid Material", "ore")

	assert_bool(material.validate()).is_true()


func test_validate_fails_without_name() -> void:
	var material: RareMaterialData = RareMaterialData.new()
	material.crafting_category = "ore"

	assert_bool(material.validate()).is_false()


func test_validate_fails_without_category() -> void:
	var material: RareMaterialData = RareMaterialData.new()
	material.material_name = "No Category"

	assert_bool(material.validate()).is_false()


func test_validate_fails_with_zero_stack_limit() -> void:
	var material: RareMaterialData = _create_material("Bad Stack", "ore")
	material.stack_limit = 0

	assert_bool(material.validate()).is_false()


func test_validate_passes_with_stack_limit_one() -> void:
	var material: RareMaterialData = _create_material("Unique Item", "ore")
	material.stack_limit = 1

	assert_bool(material.validate()).is_true()
