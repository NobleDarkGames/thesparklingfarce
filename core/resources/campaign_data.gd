## CampaignData - Top-level campaign definition resource
##
## Defines a complete campaign with nodes, chapters, and metadata.
## Campaigns are discovered by ModLoader from mods/*/data/campaigns/
##
## Usage:
##   var campaign: CampaignData = CampaignManager.get_campaign("base_game:main_story")
##   CampaignManager.start_campaign(campaign.campaign_id)
@tool
class_name CampaignData
extends Resource

## Maximum depth for circular transition detection to prevent infinite loops
const MAX_TRANSITION_CHAIN_DEPTH: int = 100

## Unique identifier for this campaign (namespaced: "mod_id:campaign_id")
@export var campaign_id: String = ""

## Display name for campaign selection
@export var campaign_name: String = ""

## Description shown in campaign selector
@export_multiline var campaign_description: String = ""

## Version string for compatibility checking
@export var campaign_version: String = "1.0.0"

## Starting node ID (where new games begin)
@export var starting_node_id: String = ""

## All campaign nodes (battles, towns, cutscenes, etc.)
@export var nodes: Array[Resource] = []  # Array of CampaignNode

## Default hub node ID (where player returns after battles/egress if not specified)
@export var default_hub_id: String = ""

## Campaign-specific story flags to initialize on new game
@export var initial_flags: Dictionary = {}

## Optional chapter organization (inline as Dictionary array for simplicity)
## Each entry: {"id": String, "name": String, "description": String, "number": int, "node_ids": Array}
@export var chapters: Array[Dictionary] = []

# ---- Node Lookup Cache for O(1) Access ----
var _node_cache: Dictionary = {}  # node_id -> CampaignNode
var _cache_built: bool = false


## Build the node lookup cache
func _build_cache() -> void:
	_node_cache.clear()
	for node_resource: Resource in nodes:
		if node_resource == null:
			continue
		# Access node_id property - check existence before accessing
		if not "node_id" in node_resource:
			push_warning("CampaignData: Node missing node_id property")
			continue
		var node_id: String = node_resource.node_id
		if node_id in _node_cache:
			push_warning("CampaignData: Duplicate node_id '%s' - later definition wins" % node_id)
		_node_cache[node_id] = node_resource
	_cache_built = true


## Validation - returns array of error messages (empty = valid)
func validate() -> Array[String]:
	var errors: Array[String] = []

	if campaign_id.is_empty():
		errors.append("campaign_id is required")
	if campaign_name.is_empty():
		errors.append("campaign_name is required")
	if starting_node_id.is_empty():
		errors.append("starting_node_id is required")

	# Build cache if needed
	if not _cache_built:
		_build_cache()

	if not starting_node_id.is_empty() and starting_node_id not in _node_cache:
		errors.append("starting_node_id '%s' not found in nodes" % starting_node_id)

	if not default_hub_id.is_empty() and default_hub_id not in _node_cache:
		errors.append("default_hub_id '%s' not found in nodes" % default_hub_id)

	# Validate all nodes and check transition targets
	for node_resource: Resource in nodes:
		if node_resource == null:
			errors.append("Null node in nodes array")
			continue

		# Validate node if it has validate method
		if node_resource.has_method("validate"):
			var node_errors: Array[String] = node_resource.validate()
			var node_id: String = node_resource.node_id if "node_id" in node_resource else "unknown"
			for error: String in node_errors:
				errors.append("Node '%s': %s" % [node_id, error])

		# Check transition targets exist
		for target_id: String in _get_all_transition_targets(node_resource):
			if not target_id.is_empty() and target_id not in _node_cache:
				var node_id: String = node_resource.node_id if "node_id" in node_resource else "unknown"
				errors.append("Node '%s': transition target '%s' not found" % [node_id, target_id])

	# Circular transition detection
	var circular_errors: Array[String] = _detect_circular_transitions()
	errors.append_array(circular_errors)

	return errors


## Get all transition target IDs from a node
func _get_all_transition_targets(node: Resource) -> Array[String]:
	var targets: Array[String] = []

	if "on_victory" in node:
		var on_victory_value: Variant = node.get("on_victory")
		var on_victory: String = on_victory_value if on_victory_value is String else ""
		if not on_victory.is_empty():
			targets.append(on_victory)
	if "on_defeat" in node:
		var on_defeat_value: Variant = node.get("on_defeat")
		var on_defeat: String = on_defeat_value if on_defeat_value is String else ""
		if not on_defeat.is_empty():
			targets.append(on_defeat)
	if "on_complete" in node:
		var on_complete_value: Variant = node.get("on_complete")
		var on_complete: String = on_complete_value if on_complete_value is String else ""
		if not on_complete.is_empty():
			targets.append(on_complete)

	if "branches" in node:
		var branches_value: Variant = node.get("branches")
		var branches_array: Array = branches_value if branches_value is Array else []
		for branch: Dictionary in branches_array:
			var branch_target: String = DictUtils.get_string(branch, "target", "")
			if not branch_target.is_empty():
				targets.append(branch_target)

	return targets


## Detect circular immediate transitions (A->B->A without player action)
func _detect_circular_transitions() -> Array[String]:
	var errors: Array[String] = []

	# Only check for immediate loops (cutscene->cutscene chains that could infinite loop)
	for node_resource: Resource in nodes:
		if node_resource == null:
			continue
		if not "node_type" in node_resource:
			continue

		var node_type: String = node_resource.node_type
		if node_type == "cutscene":
			var node_id: String = node_resource.node_id
			var visited: Array[String] = [node_id]
			var current_target: String = node_resource.on_complete if "on_complete" in node_resource else ""
			var depth: int = 0

			while not current_target.is_empty() and depth < MAX_TRANSITION_CHAIN_DEPTH:
				depth += 1
				if current_target in visited:
					errors.append("Circular transition detected: %s" % " -> ".join(visited + [current_target]))
					break
				visited.append(current_target)

				if current_target in _node_cache:
					var target_node: CampaignNode = _node_cache[current_target]
					var target_node_type: String = target_node.node_type if target_node else ""
					if target_node_type == "cutscene":
						current_target = target_node.on_complete if target_node else ""
					else:
						break  # Non-cutscene nodes require player action
				else:
					break

	return errors


## Get a node by ID (O(1) with cache)
func get_node(node_id: String) -> Resource:
	if not _cache_built:
		_build_cache()
	if node_id in _node_cache:
		return _node_cache[node_id]
	return null


## Check if a node exists
func has_node(node_id: String) -> bool:
	if not _cache_built:
		_build_cache()
	return node_id in _node_cache


## Find a battle node by its resource_id (the battle ID)
## Returns the CampaignNode if found, null otherwise
func find_battle_node_by_resource_id(battle_resource_id: String) -> Resource:
	if not _cache_built:
		_build_cache()
	for node: Resource in nodes:
		if node == null:
			continue
		if not "node_type" in node or not "resource_id" in node:
			continue
		var node_type: String = node.node_type
		var resource_id: String = node.resource_id
		if node_type == "battle" and resource_id == battle_resource_id:
			return node
	return null


## Get chapter data for a node
func get_chapter_for_node(node_id: String) -> Dictionary:
	for chapter: Dictionary in chapters:
		if "node_ids" in chapter:
			var node_ids: Array[String] = []
			var raw_node_ids: Array = DictUtils.get_array(chapter, "node_ids", [])
			for raw_id: Variant in raw_node_ids:
				if raw_id is String:
					node_ids.append(raw_id)
			if node_id in node_ids:
				return chapter
	return {}


## Invalidate cache (call after modifying nodes array)
func invalidate_cache() -> void:
	_cache_built = false
	_node_cache.clear()
