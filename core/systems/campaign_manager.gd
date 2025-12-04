extends Node
## CampaignManager - Tracks and manages player progress through storylines
##
## Responsibilities:
## - Load campaign data from mods via ModLoader
## - Track current campaign and node position
## - Handle node transitions based on outcomes
## - Use registry pattern for extensible node/trigger processing
## - Integrate with GameState for flags and SaveManager for persistence
## - Implement Shining Force authentic mechanics (XP persist, gold penalty, egress)

# Preload resource scripts for type access
const CampaignDataScript: GDScript = preload("res://core/resources/campaign_data.gd")
const CampaignNodeScript: GDScript = preload("res://core/resources/campaign_node.gd")

# ---- Signals ----

## Emitted when a campaign is started
signal campaign_started(campaign: Resource)

## Emitted when a campaign ends (completed or abandoned)
signal campaign_ended(campaign: Resource, completed: bool)

## Emitted when entering a new node
signal node_entered(node: Resource)

## Emitted when a node is completed
signal node_completed(node: Resource, outcome: Dictionary)

## Emitted when transitioning between nodes
signal transition_started(from_node: Resource, to_node: Resource)

## Emitted when a new chapter begins
signal chapter_started(chapter: Dictionary)

## Emitted when player requests egress (warp to hub)
signal egress_requested()

## Emitted when chapter boundary is reached (for save prompt UI)
signal chapter_boundary_reached(chapter: Dictionary)

## Emitted when returning to a scene after an encounter (carries return position)
signal encounter_return(scene_path: String, position: Vector2, facing: String)

## Emitted when a choice node is ready for player input
signal choice_requested(choices: Array[Dictionary])

# ---- State ----

## Currently active campaign (CampaignData resource)
var current_campaign: Resource = null

## Current campaign node (CampaignNode resource)
var current_node: Resource = null

## History of visited nodes (for back-tracking if needed)
var node_history: Array[String] = []

## Last hub visited (for egress return)
var last_hub_id: String = ""

## Registered campaigns (from all mods)
var _campaigns: Dictionary = {}  # campaign_id -> CampaignData

# ---- Encounter Return Context ----
## Stores scene and position to return to after triggered encounters
## Format: {"scene_path": String, "position": Vector2, "facing": String, "node_id": String}
var _return_context: Dictionary = {}

# ---- Registry Pattern: Node Processors ----
## Registered node type processors: node_type -> Callable
## Callable signature: func(node: Resource) -> void
var _node_processors: Dictionary = {}

# ---- Registry Pattern: Transition Trigger Evaluators ----
## Registered trigger evaluators: trigger_type -> Callable
## Callable signature: func(branch: Dictionary, outcome: Dictionary) -> bool
var _trigger_evaluators: Dictionary = {}

# ---- Registry Pattern: Custom Node Handlers ----
## For "custom:*" node types, modders register handlers here
## custom_type (without "custom:" prefix) -> Callable
## Handler signature: func(node: Resource, manager: Node) -> void
var _custom_handlers: Dictionary = {}


func _ready() -> void:
	_register_built_in_processors()
	_register_built_in_evaluators()

	# Wait for ModLoader to finish loading mods
	if ModLoader._is_loading:
		await ModLoader.mods_loaded

	_discover_campaigns()

	# Connect to BattleManager for battle completion
	if BattleManager:
		BattleManager.battle_ended.connect(_on_battle_ended)


## Register built-in node type processors
func _register_built_in_processors() -> void:
	register_node_processor("battle", _process_battle_node)
	register_node_processor("scene", _process_scene_node)
	register_node_processor("cutscene", _process_cutscene_node)
	register_node_processor("choice", _process_choice_node)


## Register built-in trigger evaluators
func _register_built_in_evaluators() -> void:
	register_trigger_evaluator("choice", _evaluate_choice_trigger)
	register_trigger_evaluator("flag", _evaluate_flag_trigger)
	register_trigger_evaluator("always", _evaluate_always_trigger)


# ==== Registry API ====

## Register a processor for a node type
## Callable signature: func(node: Resource) -> void
func register_node_processor(node_type: String, processor: Callable) -> void:
	_node_processors[node_type] = processor


## Register an evaluator for a transition trigger type
## Callable signature: func(branch: Dictionary, outcome: Dictionary) -> bool
func register_trigger_evaluator(trigger_type: String, evaluator: Callable) -> void:
	_trigger_evaluators[trigger_type] = evaluator


## Register a handler for custom node types (modders use this)
## Handler signature: func(node: Resource, manager: Node) -> void
func register_custom_handler(custom_type: String, handler: Callable) -> void:
	_custom_handlers[custom_type] = handler


# ==== Campaign Discovery ====

## Discover all campaigns from loaded mods
func _discover_campaigns() -> void:
	var campaigns: Array[Resource] = ModLoader.registry.get_all_resources("campaign")
	for campaign_resource: Resource in campaigns:
		var campaign: Resource = campaign_resource
		if campaign:
			var errors: Array[String] = campaign.validate()
			if errors.is_empty():
				if campaign.campaign_id in _campaigns:
					push_warning("CampaignManager: Campaign ID '%s' collision - overwriting previous" % campaign.campaign_id)
				_campaigns[campaign.campaign_id] = campaign
			else:
				push_error("CampaignManager: Campaign '%s' validation failed:" % campaign.campaign_id)
				for error: String in errors:
					push_error("  - %s" % error)


## Get all available campaigns (respecting hidden_campaigns from mods)
func get_available_campaigns() -> Array[Resource]:
	var result: Array[Resource] = []
	var hidden_patterns: Array[String] = _get_hidden_campaign_patterns()

	for campaign_id: String in _campaigns:
		var campaign: Resource = _campaigns[campaign_id]
		if not _is_campaign_hidden(campaign_id, hidden_patterns):
			result.append(campaign)
	return result


## Get hidden campaign patterns from all mods
func _get_hidden_campaign_patterns() -> Array[String]:
	return ModLoader.get_hidden_campaign_patterns()


## Check if a campaign matches any hidden pattern
func _is_campaign_hidden(campaign_id: String, patterns: Array[String]) -> bool:
	for pattern: String in patterns:
		if pattern.ends_with("*"):
			var prefix: String = pattern.substr(0, pattern.length() - 1)
			if campaign_id.begins_with(prefix):
				return true
		elif pattern == campaign_id:
			return true
	return false


## Get a specific campaign by ID
func get_campaign(campaign_id: String) -> Resource:
	if campaign_id in _campaigns:
		return _campaigns[campaign_id]
	return null


# ==== Campaign Flow ====

## Start a new campaign
func start_campaign(campaign_id: String) -> bool:
	var campaign: Resource = get_campaign(campaign_id)
	if not campaign:
		push_error("CampaignManager: Campaign '%s' not found" % campaign_id)
		return false

	current_campaign = campaign
	node_history.clear()
	last_hub_id = campaign.default_hub_id

	# Initialize campaign flags
	for flag_name: String in campaign.initial_flags:
		GameState.set_flag(flag_name, campaign.initial_flags[flag_name])

	# Set current campaign in GameState for saves
	GameState.set_campaign_data("current_campaign_id", campaign_id)
	GameState.set_campaign_data("current_node_id", "")

	campaign_started.emit(campaign)

	# Enter starting node
	return await enter_node(campaign.starting_node_id)


## Resume a campaign from save data
func resume_campaign(campaign_id: String, node_id: String) -> bool:
	var campaign: Resource = get_campaign(campaign_id)
	if not campaign:
		push_error("CampaignManager: Campaign '%s' not found for resume" % campaign_id)
		return false

	current_campaign = campaign

	# Restore last hub from GameState if available
	last_hub_id = GameState.get_campaign_data("last_hub_id", campaign.default_hub_id)

	# Enter the saved node
	return await enter_node(node_id)


## Enter a campaign node
func enter_node(node_id: String) -> bool:
	if not current_campaign:
		push_error("CampaignManager: No active campaign")
		return false

	var node_resource: Resource = current_campaign.get_node(node_id)
	if not node_resource:
		push_error("CampaignManager: Node '%s' not found in campaign" % node_id)
		_handle_missing_node_error(node_id)
		return false

	var node: Resource = node_resource
	if not node:
		push_error("CampaignManager: Node '%s' is not a valid CampaignNode" % node_id)
		return false

	# Check access requirements
	if not node.can_access(GameState.has_flag):
		push_error("CampaignManager: Cannot access node '%s' - requirements not met" % node_id)
		return false

	# Track history
	if current_node:
		node_history.append(current_node.node_id)

	current_node = node

	# Update last hub if this is a hub
	if node.is_hub:
		last_hub_id = node.node_id
		GameState.set_campaign_data("last_hub_id", last_hub_id)

	# Update GameState
	GameState.set_campaign_data("current_node_id", node_id)

	# Set on_enter flags
	for flag_name: String in node.on_enter_flags:
		GameState.set_flag(flag_name, node.on_enter_flags[flag_name])

	# Check for chapter change
	_check_chapter_transition(node)

	node_entered.emit(node)

	# Play pre-cinematic if present
	if not node.pre_cinematic_id.is_empty():
		await _play_cinematic(node.pre_cinematic_id)

	# Handle chapter boundary save prompt
	if node.is_chapter_boundary:
		var chapter: Dictionary = current_campaign.get_chapter_for_node(node_id)
		chapter_boundary_reached.emit(chapter)

	# Process node based on type
	_process_node(node)

	return true


## Track recovery attempts to prevent infinite loops
var _recovery_attempts: int = 0
const MAX_RECOVERY_ATTEMPTS: int = 3


## Handle error when a node cannot be found (error recovery)
func _handle_missing_node_error(node_id: String) -> void:
	_recovery_attempts += 1
	push_error("CampaignManager: Attempting recovery from missing node '%s' (attempt %d/%d)" % [
		node_id, _recovery_attempts, MAX_RECOVERY_ATTEMPTS
	])

	# Prevent infinite recovery loops
	if _recovery_attempts >= MAX_RECOVERY_ATTEMPTS:
		push_error("CampaignManager: Max recovery attempts reached - campaign in invalid state")
		push_error("CampaignManager: Manual intervention required. Check node_id: '%s'" % node_id)
		_recovery_attempts = 0  # Reset for future attempts
		return

	# Try to return to last hub or default hub
	var recovery_target: String = last_hub_id if not last_hub_id.is_empty() else ""
	if recovery_target.is_empty() and current_campaign:
		recovery_target = current_campaign.default_hub_id

	# Don't try to recover to the same node that failed
	if recovery_target == node_id:
		push_error("CampaignManager: Recovery target is same as failed node - aborting")
		_recovery_attempts = 0
		return

	if not recovery_target.is_empty() and current_campaign and current_campaign.has_node(recovery_target):
		push_warning("CampaignManager: Recovering to hub '%s'" % recovery_target)
		# Use call_deferred to avoid recursion issues
		call_deferred("enter_node", recovery_target)
	else:
		push_error("CampaignManager: No valid recovery target - campaign in invalid state")
		_recovery_attempts = 0


## Process a node based on its type using registry
func _process_node(node: Resource) -> void:
	var node_type: String = node.node_type

	# Handle custom:* types
	if node_type.begins_with("custom:"):
		var custom_type: String = node_type.substr(7)  # Remove "custom:" prefix
		if custom_type in _custom_handlers:
			_custom_handlers[custom_type].call(node, self)
		else:
			push_error("CampaignManager: No handler registered for '%s'" % node_type)
			push_error("  Register with: CampaignManager.register_custom_handler('%s', handler)" % custom_type)
		return

	# Handle built-in types via registry
	if node_type in _node_processors:
		_node_processors[node_type].call(node)
	else:
		push_error("CampaignManager: No processor registered for node type '%s'" % node_type)


# ==== Built-in Node Processors ====

## Process a battle node
func _process_battle_node(node: Resource) -> void:
	# Look up battle data from registry
	var battle_data: Resource = ModLoader.registry.get_resource("battle", node.resource_id)
	if not battle_data:
		push_error("CampaignManager: Battle '%s' not found" % node.resource_id)
		_handle_missing_node_error(node.node_id)
		return

	# Store campaign context in GameState for battle return
	GameState.set_campaign_data("battle_node_id", node.node_id)
	GameState.set_campaign_data("retain_xp_on_defeat", node.retain_xp_on_defeat)
	GameState.set_campaign_data("defeat_gold_penalty", node.defeat_gold_penalty)
	GameState.set_campaign_data("battle_repeatable", node.repeatable)
	GameState.set_campaign_data("replay_advances_story", node.replay_advances_story)

	# Start battle via TriggerManager
	TriggerManager.start_battle_with_data(battle_data)


## Process a scene node (town, hub, exploration, dungeon)
func _process_scene_node(node: Resource) -> void:
	var target_scene_path: String = node.scene_path

	if target_scene_path.is_empty() and not node.resource_id.is_empty():
		# Look up scene from registry
		target_scene_path = ModLoader.registry.get_scene_path(node.resource_id)

	if target_scene_path.is_empty():
		push_error("CampaignManager: No scene for node '%s'" % node.node_id)
		_handle_missing_node_error(node.node_id)
		return

	SceneManager.change_scene(target_scene_path)


## Process a cutscene node
func _process_cutscene_node(node: Resource) -> void:
	if not _has_cinematics_manager():
		push_warning("CampaignManager: CinematicsManager not available, skipping cutscene")
		complete_current_node({})
		return

	await _play_cinematic(node.resource_id)
	# Auto-complete after cutscene
	complete_current_node({})


## Process a choice node
func _process_choice_node(node: Resource) -> void:
	# Extract choices from branches for UI
	var choices: Array[Dictionary] = []
	for branch: Dictionary in node.branches:
		if branch.get("trigger") == "choice":
			choices.append({
				"value": branch.get("choice_value", ""),
				"label": branch.get("label", branch.get("choice_value", "Option")),
				"description": branch.get("description", "")
			})

	if choices.is_empty():
		push_warning("CampaignManager: Choice node '%s' has no choice branches" % node.node_id)
		# Auto-complete with empty choice if no choices defined
		complete_current_node({})
		return

	# Emit signal for UI to display choice dialog
	# UI should call on_choice_made(choice_value) when player selects
	choice_requested.emit(choices)


# ==== Completion Handlers ====

## Complete the current node with an outcome
func complete_current_node(outcome: Dictionary) -> void:
	if not current_node:
		push_error("CampaignManager: No current node to complete")
		return

	# Set on_complete flags
	for flag_name: String in current_node.on_complete_flags:
		GameState.set_flag(flag_name, current_node.on_complete_flags[flag_name])

	# Play post-cinematic if present
	if not current_node.post_cinematic_id.is_empty():
		await _play_cinematic(current_node.post_cinematic_id)

	node_completed.emit(current_node, outcome)

	# Find and execute transition
	_execute_transition(outcome)


## Handle battle completion (called via BattleManager.battle_ended signal)
func _on_battle_ended(victory: bool) -> void:
	# Check if this was an encounter (position-preserving battle)
	if has_encounter_return():
		_handle_encounter_return(victory)
		return

	# Otherwise, handle as normal campaign node battle
	on_battle_completed(victory)


## Process battle completion with SF-authentic mechanics
func on_battle_completed(victory: bool) -> void:
	if not current_node or current_node.node_type != "battle":
		push_warning("CampaignManager: Battle completed but not in battle node")
		return

	# Handle defeat mechanics (Shining Force style)
	if not victory:
		# Apply gold penalty if configured
		var gold_penalty: float = current_node.defeat_gold_penalty
		if gold_penalty > 0.0:
			var current_gold: int = GameState.get_campaign_data("gold", 0)
			var penalty_amount: int = int(float(current_gold) * gold_penalty)
			GameState.set_campaign_data("gold", current_gold - penalty_amount)

	complete_current_node({"victory": victory})


## Handle player choice (called by choice UI)
func on_choice_made(choice_value: String) -> void:
	if not current_node or current_node.node_type != "choice":
		push_warning("CampaignManager: Choice made but not in choice node")
		return

	complete_current_node({"choice": choice_value})


## Handle egress (warp back to hub - Egress spell)
func request_egress() -> bool:
	if not current_node:
		return false

	if not current_node.allow_egress:
		push_warning("CampaignManager: Egress not allowed from current node")
		return false

	var egress_target: String = last_hub_id
	if egress_target.is_empty() and current_campaign:
		egress_target = current_campaign.default_hub_id

	if egress_target.is_empty():
		push_warning("CampaignManager: No hub available for egress")
		return false

	egress_requested.emit()
	await enter_node(egress_target)
	return true


# ==== Encounter System (Position-Preserving Battles) ====

## Trigger a battle encounter that returns to the current scene position afterward
## Use this for exploration triggers, ambushes, random encounters, etc.
## @param battle_id: The battle resource ID to start
## @param return_position: Player's position to restore after battle
## @param return_facing: Optional facing direction ("up", "down", "left", "right")
func trigger_encounter(battle_id: String, return_position: Vector2, return_facing: String = "") -> void:
	# Store return context
	var current_scene_path: String = SceneManager.current_scene.scene_file_path if SceneManager.current_scene else ""

	if current_scene_path.is_empty():
		push_warning("CampaignManager: No current scene for encounter return context")

	_return_context = {
		"scene_path": current_scene_path,
		"position": return_position,
		"facing": return_facing,
		"node_id": current_node.node_id if current_node else "",
		"is_encounter": true
	}

	# Store encounter context in GameState for battle return
	GameState.set_campaign_data("encounter_battle_id", battle_id)
	GameState.set_campaign_data("encounter_return_scene", current_scene_path)
	GameState.set_campaign_data("encounter_return_position_x", return_position.x)
	GameState.set_campaign_data("encounter_return_position_y", return_position.y)
	GameState.set_campaign_data("encounter_return_facing", return_facing)

	# Start the battle via TriggerManager
	TriggerManager.start_battle(battle_id)


## Check if we have a pending encounter return
func has_encounter_return() -> bool:
	return not _return_context.is_empty() and _return_context.get("is_encounter", false)


## Get the stored return position (for scenes to query on load)
func get_encounter_return_position() -> Vector2:
	return _return_context.get("position", Vector2.ZERO)


## Get the stored return facing direction
func get_encounter_return_facing() -> String:
	return _return_context.get("facing", "")


## Clear the return context (called after position is restored)
func clear_encounter_return() -> void:
	_return_context.clear()
	GameState.set_campaign_data("encounter_return_scene", "")


## Handle return to scene after encounter battle completes
func _handle_encounter_return(victory: bool) -> void:
	if not has_encounter_return():
		return

	var scene_path: String = _return_context.get("scene_path", "")
	var position: Vector2 = _return_context.get("position", Vector2.ZERO)
	var facing: String = _return_context.get("facing", "")
	var original_node_id: String = _return_context.get("node_id", "")

	# Emit signal so scenes can prepare for position restoration
	encounter_return.emit(scene_path, position, facing)

	# Return to the scene
	if not scene_path.is_empty():
		SceneManager.change_scene(scene_path)
	elif not original_node_id.is_empty() and current_campaign:
		# Fallback: re-enter the original node
		await enter_node(original_node_id)

	# Note: Scene should call clear_encounter_return() after restoring player position


# ==== Transition Logic ====

## Find and execute the appropriate transition
func _execute_transition(outcome: Dictionary) -> void:
	if not current_node:
		return

	# Use the node's transition logic with our flag checker
	var target_id: String = current_node.get_transition_target(outcome, GameState.has_flag)

	if target_id.is_empty():
		# No transition found - check for default hub fallback
		if current_campaign and current_node.node_type == "battle":
			if not current_campaign.default_hub_id.is_empty():
				enter_node(current_campaign.default_hub_id)
				return

		push_warning("CampaignManager: No valid transition from node '%s'" % current_node.node_id)
		return

	var to_node_resource: Resource = current_campaign.get_node(target_id)
	if not to_node_resource:
		push_error("CampaignManager: Transition target '%s' not found" % target_id)
		_handle_missing_node_error(target_id)
		return

	var to_node: Resource = to_node_resource
	transition_started.emit(current_node, to_node)
	await enter_node(target_id)


# ==== Helper Functions ====

## Check if CinematicsManager is available
func _has_cinematics_manager() -> bool:
	# Check if CinematicsManager autoload exists
	return has_node("/root/CinematicsManager")


## Play a cinematic by ID
func _play_cinematic(cinematic_id: String) -> void:
	if not _has_cinematics_manager():
		push_warning("CampaignManager: CinematicsManager not available")
		return

	var cinematic: Resource = ModLoader.registry.get_resource("cinematic", cinematic_id)
	if cinematic:
		var cinematics_manager: Node = get_node("/root/CinematicsManager")
		await cinematics_manager.play_cinematic(cinematic)
	else:
		push_warning("CampaignManager: Cinematic '%s' not found" % cinematic_id)


## Check for chapter transitions
func _check_chapter_transition(node: Resource) -> void:
	var chapter: Dictionary = current_campaign.get_chapter_for_node(node.node_id)
	if chapter.is_empty():
		return

	var chapter_id: String = chapter.get("id", "")
	var current_chapter_id: String = GameState.get_campaign_data("current_chapter_id", "")

	if chapter_id != current_chapter_id:
		GameState.set_campaign_data("current_chapter_id", chapter_id)
		chapter_started.emit(chapter)


# ==== Built-in Trigger Evaluators ====

func _evaluate_choice_trigger(branch: Dictionary, outcome: Dictionary) -> bool:
	var choice_value: String = branch.get("choice_value", "")
	return outcome.get("choice", "") == choice_value


func _evaluate_flag_trigger(branch: Dictionary, _outcome: Dictionary) -> bool:
	var required_flag: String = branch.get("required_flag", "")
	return required_flag.is_empty() or GameState.has_flag(required_flag)


func _evaluate_always_trigger(_branch: Dictionary, _outcome: Dictionary) -> bool:
	return true


# ==== Save/Load Support ====

## Export campaign state for saves
func export_state() -> Dictionary:
	return {
		"current_campaign_id": current_campaign.campaign_id if current_campaign else "",
		"current_node_id": current_node.node_id if current_node else "",
		"node_history": node_history.duplicate(),
		"last_hub_id": last_hub_id
	}


## Import campaign state from saves
func import_state(state: Dictionary) -> void:
	node_history.clear()
	var raw_history: Array = state.get("node_history", [])
	for history_node_id: Variant in raw_history:
		if history_node_id is String:
			node_history.append(history_node_id)

	last_hub_id = state.get("last_hub_id", "")
	var campaign_id: String = state.get("current_campaign_id", "")
	var node_id: String = state.get("current_node_id", "")

	if not campaign_id.is_empty() and not node_id.is_empty():
		resume_campaign(campaign_id, node_id)
