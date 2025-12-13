class_name CampaignLoader
extends RefCounted

## Loads CampaignData from JSON files
##
## This allows modders to define campaigns in pure JSON without writing GDScript.
## JSON campaigns define the complete story flow with nodes, transitions, and chapters.
##
## Example JSON format:
## {
##   "campaign_id": "mymod:main_story",
##   "campaign_name": "My Epic Adventure",
##   "campaign_description": "A tale of heroes and villains",
##   "campaign_version": "1.0.0",
##   "starting_node_id": "intro_town",
##   "default_hub_id": "main_hub",
##   "initial_flags": {"chapter_1_started": true},
##   "chapters": [
##     {"id": "ch1", "name": "Chapter 1", "number": 1, "node_ids": ["intro_town", "first_battle"]}
##   ],
##   "nodes": [
##     {
##       "node_id": "intro_town",
##       "display_name": "Introduction Town",
##       "node_type": "scene",
##       "scene_path": "res://mods/mymod/maps/intro_town.tscn",
##       "is_hub": true,
##       "on_complete": "first_battle"
##     },
##     {
##       "node_id": "first_battle",
##       "display_name": "First Battle",
##       "node_type": "battle",
##       "resource_id": "battle_crossroads",
##       "on_victory": "intro_town",
##       "on_defeat": "intro_town",
##       "retain_xp_on_defeat": true,
##       "defeat_gold_penalty": 0.5
##     }
##   ]
## }

const CampaignDataScript: GDScript = preload("res://core/resources/campaign_data.gd")
const CampaignNodeScript: GDScript = preload("res://core/resources/campaign_node.gd")


## Load a CampaignData resource from a JSON file
## Returns null if loading fails
static func load_from_json(json_path: String) -> Resource:
	# Don't use FileAccess.file_exists() - it fails in exports where files are in PCK
	# Just try to open the file directly
	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("CampaignLoader: File not found or failed to open: %s" % json_path)
		return null

	var json_text: String = file.get_as_text()
	file.close()

	return load_from_json_string(json_text, json_path)


## Load a CampaignData resource from a JSON string
## source_path is optional, used for error messages
static func load_from_json_string(json_text: String, source_path: String = "<string>") -> Resource:
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_text)

	if error != OK:
		push_error("CampaignLoader: JSON parse error in %s at line %d: %s" % [
			source_path, json.get_error_line(), json.get_error_message()
		])
		return null

	var data: Variant = json.data
	if not data is Dictionary:
		push_error("CampaignLoader: Root element must be a dictionary in %s" % source_path)
		return null

	return _build_campaign_from_dict(data as Dictionary, source_path)


## Build CampaignData from a parsed JSON dictionary
static func _build_campaign_from_dict(data: Dictionary, source_path: String) -> Resource:
	var campaign: Resource = CampaignDataScript.new()

	# Required fields
	if "campaign_id" in data:
		campaign.campaign_id = str(data["campaign_id"])
	else:
		push_error("CampaignLoader: Missing required 'campaign_id' in %s" % source_path)
		return null

	if "campaign_name" in data:
		campaign.campaign_name = str(data["campaign_name"])
	else:
		push_error("CampaignLoader: Missing required 'campaign_name' in %s" % source_path)
		return null

	if "starting_node_id" in data:
		campaign.starting_node_id = str(data["starting_node_id"])
	else:
		push_error("CampaignLoader: Missing required 'starting_node_id' in %s" % source_path)
		return null

	# Optional metadata
	if "campaign_description" in data:
		campaign.campaign_description = str(data["campaign_description"])

	if "campaign_version" in data:
		campaign.campaign_version = str(data["campaign_version"])

	if "default_hub_id" in data:
		campaign.default_hub_id = str(data["default_hub_id"])

	# Initial flags
	if "initial_flags" in data and data["initial_flags"] is Dictionary:
		campaign.initial_flags = data["initial_flags"].duplicate()

	# Chapters (Array of Dictionary) - use clear() to preserve typed array
	if "chapters" in data and data["chapters"] is Array:
		campaign.chapters.clear()
		for chapter_data: Variant in data["chapters"]:
			if chapter_data is Dictionary:
				var chapter: Dictionary = _parse_chapter(chapter_data as Dictionary, source_path)
				if not chapter.is_empty():
					campaign.chapters.append(chapter)

	# Nodes (Array of CampaignNode resources) - use clear() to preserve typed array
	if "nodes" in data and data["nodes"] is Array:
		campaign.nodes.clear()
		for node_data: Variant in data["nodes"]:
			if node_data is Dictionary:
				var node: Resource = _build_node_from_dict(node_data as Dictionary, source_path)
				if node:
					campaign.nodes.append(node)
	else:
		push_error("CampaignLoader: Missing required 'nodes' array in %s" % source_path)
		return null

	# Validate the campaign
	var errors: Array[String] = campaign.validate()
	if not errors.is_empty():
		push_error("CampaignLoader: Campaign '%s' validation failed:" % campaign.campaign_id)
		for err: String in errors:
			push_error("  - %s" % err)
		return null

	return campaign


## Parse a chapter dictionary from JSON
static func _parse_chapter(data: Dictionary, source_path: String) -> Dictionary:
	var chapter: Dictionary = {}

	if "id" in data:
		chapter["id"] = str(data["id"])
	else:
		push_warning("CampaignLoader: Chapter missing 'id' in %s" % source_path)
		return {}

	if "name" in data:
		chapter["name"] = str(data["name"])

	if "description" in data:
		chapter["description"] = str(data["description"])

	if "number" in data:
		chapter["number"] = int(data["number"])

	if "node_ids" in data and data["node_ids"] is Array:
		var node_ids: Array[String] = []
		for node_id: Variant in data["node_ids"]:
			node_ids.append(str(node_id))
		chapter["node_ids"] = node_ids

	return chapter


## Build a CampaignNode from a parsed JSON dictionary
static func _build_node_from_dict(data: Dictionary, source_path: String) -> Resource:
	var node: Resource = CampaignNodeScript.new()

	# Required fields
	if "node_id" in data:
		node.node_id = str(data["node_id"])
	else:
		push_warning("CampaignLoader: Node missing 'node_id' in %s" % source_path)
		return null

	if "display_name" in data:
		node.display_name = str(data["display_name"])
	else:
		node.display_name = node.node_id  # Fallback to node_id

	if "node_type" in data:
		node.node_type = str(data["node_type"])

	# Resource references
	if "resource_id" in data:
		node.resource_id = str(data["resource_id"])

	if "scene_path" in data:
		node.scene_path = str(data["scene_path"])

	# Simple transitions
	if "on_victory" in data:
		node.on_victory = str(data["on_victory"])

	if "on_defeat" in data:
		node.on_defeat = str(data["on_defeat"])

	if "on_complete" in data:
		node.on_complete = str(data["on_complete"])

	# Complex branching - use clear() to preserve typed array
	if "branches" in data and data["branches"] is Array:
		node.branches.clear()
		for branch_data: Variant in data["branches"]:
			if branch_data is Dictionary:
				var branch: Dictionary = _parse_branch(branch_data as Dictionary)
				if not branch.is_empty():
					node.branches.append(branch)

	# Shining Force mechanics
	if "retain_xp_on_defeat" in data:
		node.retain_xp_on_defeat = bool(data["retain_xp_on_defeat"])

	if "defeat_gold_penalty" in data:
		node.defeat_gold_penalty = float(data["defeat_gold_penalty"])

	if "repeatable" in data:
		node.repeatable = bool(data["repeatable"])

	if "replay_advances_story" in data:
		node.replay_advances_story = bool(data["replay_advances_story"])

	if "allow_egress" in data:
		node.allow_egress = bool(data["allow_egress"])

	if "is_hub" in data:
		node.is_hub = bool(data["is_hub"])

	if "is_chapter_boundary" in data:
		node.is_chapter_boundary = bool(data["is_chapter_boundary"])

	# Cinematics
	if "pre_cinematic_id" in data:
		node.pre_cinematic_id = str(data["pre_cinematic_id"])

	if "post_cinematic_id" in data:
		node.post_cinematic_id = str(data["post_cinematic_id"])

	# Flags
	if "on_enter_flags" in data and data["on_enter_flags"] is Dictionary:
		node.on_enter_flags = data["on_enter_flags"].duplicate()

	if "on_complete_flags" in data and data["on_complete_flags"] is Dictionary:
		node.on_complete_flags = data["on_complete_flags"].duplicate()

	if "required_flags" in data and data["required_flags"] is Array:
		node.required_flags.clear()
		for flag: Variant in data["required_flags"]:
			node.required_flags.append(str(flag))

	if "forbidden_flags" in data and data["forbidden_flags"] is Array:
		node.forbidden_flags.clear()
		for flag: Variant in data["forbidden_flags"]:
			node.forbidden_flags.append(str(flag))

	# Completion triggers (for scene nodes)
	if "completion_trigger" in data:
		node.completion_trigger = str(data["completion_trigger"])

	if "completion_flag" in data:
		node.completion_flag = str(data["completion_flag"])

	if "completion_npc_id" in data:
		node.completion_npc_id = str(data["completion_npc_id"])

	return node


## Parse a branch dictionary from JSON
static func _parse_branch(data: Dictionary) -> Dictionary:
	var branch: Dictionary = {}

	# Required: trigger and target
	if "trigger" in data:
		branch["trigger"] = str(data["trigger"])
	else:
		branch["trigger"] = "always"

	if "target" in data:
		branch["target"] = str(data["target"])
	else:
		return {}  # Target is required

	# Optional fields
	if "priority" in data:
		branch["priority"] = int(data["priority"])

	if "choice_value" in data:
		branch["choice_value"] = str(data["choice_value"])

	if "required_flag" in data:
		branch["required_flag"] = str(data["required_flag"])

	if "required_flags" in data and data["required_flags"] is Array:
		var flags: Array[String] = []
		for flag: Variant in data["required_flags"]:
			flags.append(str(flag))
		branch["required_flags"] = flags

	if "forbidden_flags" in data and data["forbidden_flags"] is Array:
		var flags: Array[String] = []
		for flag: Variant in data["forbidden_flags"]:
			flags.append(str(flag))
		branch["forbidden_flags"] = flags

	if "label" in data:
		branch["label"] = str(data["label"])

	if "description" in data:
		branch["description"] = str(data["description"])

	return branch


## Validate a loaded campaign has required structure
static func validate_campaign(campaign: Resource) -> bool:
	if campaign == null:
		return false

	if campaign.campaign_id.is_empty():
		push_error("CampaignLoader: Campaign has empty campaign_id")
		return false

	if campaign.nodes.is_empty():
		push_error("CampaignLoader: Campaign '%s' has no nodes" % campaign.campaign_id)
		return false

	return true
