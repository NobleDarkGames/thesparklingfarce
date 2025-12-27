## Unit Tests for CampaignData
##
## Tests the campaign data resource, including the new find_battle_node_by_resource_id()
## method added to enable map-triggered battles to set campaign flags on completion.
class_name TestCampaignData
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

var _campaign: CampaignData
var _mock_battle_node: CampaignNode
var _mock_cutscene_node: CampaignNode
var _mock_town_node: CampaignNode


func before_test() -> void:
	_campaign = CampaignData.new()
	_campaign.campaign_id = "test:main"
	_campaign.campaign_name = "Test Campaign"
	_campaign.starting_node_id = "start"

	# Create mock nodes using actual CampaignNode instances
	_mock_battle_node = _create_mock_node("battle_1", "battle", "test_battle_001")
	_mock_cutscene_node = _create_mock_node("cutscene_1", "cutscene", "")
	_mock_town_node = _create_mock_node("start", "town", "noobington")


## Create a mock campaign node for testing
func _create_mock_node(node_id: String, node_type: String, resource_id: String) -> CampaignNode:
	var node: CampaignNode = CampaignNode.new()
	node.node_id = node_id
	node.node_type = node_type
	node.resource_id = resource_id
	return node


# =============================================================================
# BASIC CAMPAIGN TESTS
# =============================================================================

func test_campaign_is_resource() -> void:
	assert_object(_campaign).is_instanceof(Resource)


func test_campaign_has_id() -> void:
	assert_str(_campaign.campaign_id).is_equal("test:main")


func test_campaign_has_name() -> void:
	assert_str(_campaign.campaign_name).is_equal("Test Campaign")


func test_campaign_starts_with_empty_nodes() -> void:
	assert_int(_campaign.nodes.size()).is_equal(0)


# =============================================================================
# NODE CACHE TESTS
# =============================================================================

func test_get_node_returns_null_for_empty_campaign() -> void:
	var node: CampaignNode = _campaign.get_node("nonexistent")
	assert_object(node).is_null()


func test_has_node_returns_false_for_empty_campaign() -> void:
	assert_bool(_campaign.has_node("nonexistent")).is_false()


func test_get_node_finds_existing_node() -> void:
	_campaign.nodes.append(_mock_town_node)
	_campaign.invalidate_cache()

	var found: CampaignNode = _campaign.get_node("start")
	assert_object(found).is_not_null()
	assert_str(found.node_id).is_equal("start")


func test_has_node_returns_true_for_existing_node() -> void:
	_campaign.nodes.append(_mock_town_node)
	_campaign.invalidate_cache()

	assert_bool(_campaign.has_node("start")).is_true()


func test_invalidate_cache_clears_lookup() -> void:
	_campaign.nodes.append(_mock_town_node)
	# First lookup builds cache
	var _unused: bool = _campaign.has_node("start")

	# Invalidate and remove node
	_campaign.invalidate_cache()
	_campaign.nodes.clear()

	# Should not find node after invalidation
	assert_bool(_campaign.has_node("start")).is_false()


# =============================================================================
# FIND_BATTLE_NODE_BY_RESOURCE_ID TESTS (NEW IN e81a1a7)
# =============================================================================

func test_find_battle_node_returns_null_for_empty_campaign() -> void:
	var node: Resource = _campaign.find_battle_node_by_resource_id("test_battle_001")
	assert_object(node).is_null()


func test_find_battle_node_returns_null_for_nonexistent_battle() -> void:
	_campaign.nodes.append(_mock_battle_node)
	_campaign.invalidate_cache()

	var node: Resource = _campaign.find_battle_node_by_resource_id("nonexistent_battle")
	assert_object(node).is_null()


func test_find_battle_node_finds_matching_battle() -> void:
	_campaign.nodes.append(_mock_battle_node)
	_campaign.invalidate_cache()

	var found: Resource = _campaign.find_battle_node_by_resource_id("test_battle_001")
	assert_object(found).is_not_null()
	assert_str(found.get("node_id")).is_equal("battle_1")


func test_find_battle_node_ignores_non_battle_nodes() -> void:
	# Add cutscene with matching resource_id
	var fake_cutscene: Resource = _create_mock_node("cutscene_2", "cutscene", "test_battle_001")
	_campaign.nodes.append(fake_cutscene)
	_campaign.nodes.append(_mock_battle_node)
	_campaign.invalidate_cache()

	var found: Resource = _campaign.find_battle_node_by_resource_id("test_battle_001")
	assert_object(found).is_not_null()
	# Should find the battle node, not the cutscene
	assert_str(found.get("node_type")).is_equal("battle")
	assert_str(found.get("node_id")).is_equal("battle_1")


func test_find_battle_node_with_multiple_battles() -> void:
	var battle_a: Resource = _create_mock_node("battle_a", "battle", "plains_ambush")
	var battle_b: Resource = _create_mock_node("battle_b", "battle", "bridge_defense")
	var battle_c: Resource = _create_mock_node("battle_c", "battle", "castle_siege")

	_campaign.nodes.append(battle_a)
	_campaign.nodes.append(battle_b)
	_campaign.nodes.append(battle_c)
	_campaign.invalidate_cache()

	var found: Resource = _campaign.find_battle_node_by_resource_id("bridge_defense")
	assert_object(found).is_not_null()
	assert_str(found.get("node_id")).is_equal("battle_b")


func test_find_battle_node_returns_first_match() -> void:
	# If there are duplicate resource_ids (shouldn't happen, but test behavior)
	var battle_1: Resource = _create_mock_node("first_battle", "battle", "duplicate_id")
	var battle_2: Resource = _create_mock_node("second_battle", "battle", "duplicate_id")

	_campaign.nodes.append(battle_1)
	_campaign.nodes.append(battle_2)
	_campaign.invalidate_cache()

	var found: Resource = _campaign.find_battle_node_by_resource_id("duplicate_id")
	assert_object(found).is_not_null()
	# Should return the first one
	assert_str(found.get("node_id")).is_equal("first_battle")


func test_find_battle_node_handles_empty_resource_id() -> void:
	_campaign.nodes.append(_mock_battle_node)
	_campaign.invalidate_cache()

	# Looking for empty string should not match
	var found: Resource = _campaign.find_battle_node_by_resource_id("")
	assert_object(found).is_null()


func test_find_battle_node_handles_null_nodes() -> void:
	# Add a null to the nodes array (shouldn't happen but test robustness)
	_campaign.nodes.append(null)
	_campaign.nodes.append(_mock_battle_node)
	_campaign.invalidate_cache()

	# Should skip null and find the valid battle
	var found: Resource = _campaign.find_battle_node_by_resource_id("test_battle_001")
	assert_object(found).is_not_null()


# =============================================================================
# CHAPTER TESTS
# =============================================================================

func test_get_chapter_for_node_returns_empty_when_no_chapters() -> void:
	_campaign.nodes.append(_mock_town_node)

	var chapter: Dictionary = _campaign.get_chapter_for_node("start")
	assert_bool(chapter.is_empty()).is_true()


func test_get_chapter_for_node_finds_chapter() -> void:
	_campaign.nodes.append(_mock_town_node)
	_campaign.chapters = [
		{
			"id": "chapter_1",
			"name": "The Beginning",
			"node_ids": ["start", "battle_1"]
		}
	]

	var chapter: Dictionary = _campaign.get_chapter_for_node("start")
	assert_bool(chapter.is_empty()).is_false()
	assert_str(chapter.get("id", "")).is_equal("chapter_1")


func test_get_chapter_for_node_returns_empty_for_unknown_node() -> void:
	_campaign.chapters = [
		{
			"id": "chapter_1",
			"node_ids": ["start"]
		}
	]

	var chapter: Dictionary = _campaign.get_chapter_for_node("unknown_node")
	assert_bool(chapter.is_empty()).is_true()


# =============================================================================
# VALIDATION TESTS
# =============================================================================

func test_validate_requires_campaign_id() -> void:
	_campaign.campaign_id = ""
	var errors: Array[String] = _campaign.validate()
	assert_bool("campaign_id is required" in errors).is_true()


func test_validate_requires_campaign_name() -> void:
	_campaign.campaign_name = ""
	var errors: Array[String] = _campaign.validate()
	assert_bool("campaign_name is required" in errors).is_true()


func test_validate_requires_starting_node_id() -> void:
	_campaign.starting_node_id = ""
	var errors: Array[String] = _campaign.validate()
	assert_bool("starting_node_id is required" in errors).is_true()


func test_validate_warns_about_missing_starting_node() -> void:
	_campaign.starting_node_id = "nonexistent"
	var errors: Array[String] = _campaign.validate()
	assert_bool(errors.size() > 0).is_true()
	var found_error: bool = false
	for error: String in errors:
		if "starting_node_id" in error and "not found" in error:
			found_error = true
			break
	assert_bool(found_error).is_true()


func test_validate_passes_with_valid_campaign() -> void:
	_campaign.nodes.append(_mock_town_node)
	_campaign.invalidate_cache()

	var errors: Array[String] = _campaign.validate()
	assert_int(errors.size()).is_equal(0)
