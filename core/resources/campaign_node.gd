## CampaignNode - Individual story node in a campaign
##
## Represents a single point in the campaign (battle, scene, cutscene, choice).
## Uses string-based node_type for extensibility via registry pattern.
##
## Built-in node types:
##   - "battle": Tactical battle (references BattleData)
##   - "scene": Town/dungeon/hub exploration
##   - "cutscene": Story cinematic
##   - "choice": Branching decision point
##   - "custom:*": Mod-defined types (e.g., "custom:minigame")
@tool
class_name CampaignNode
extends Resource

## Unique identifier for this node (within campaign)
@export var node_id: String = ""

## Display name for save files and UI
@export var display_name: String = ""

## Type of this node (String for registry extensibility)
## Built-in: "battle", "scene", "cutscene", "choice"
## Custom: "custom:minigame", "custom:puzzle", etc.
@export var node_type: String = "scene"

## Resource reference based on type:
## - battle: BattleData resource ID
## - scene: Scene path (alternative to scene_path)
## - cutscene: CinematicData resource ID
## - choice: Not used (choices defined in branches)
## - custom:*: Custom data as needed
@export var resource_id: String = ""

## Direct scene path (for scene type, alternative to resource_id)
@export var scene_path: String = ""

# ---- Simplified Transitions ----

## Target node on battle victory
@export var on_victory: String = ""

## Target node on battle defeat
@export var on_defeat: String = ""

## Target node on non-battle completion (cutscene ends, player exits scene)
@export var on_complete: String = ""

## Complex branching for choices and flag-based paths
## Each entry: {"trigger": String, "target": String, "priority": int,
##              "required_flags": Array, "forbidden_flags": Array,
##              "choice_value": String, "required_flag": String}
## Trigger types: "choice", "flag", "always"
@export var branches: Array[Dictionary] = []

# ---- Shining Force Authentic Mechanics ----

## For battle nodes: XP gained persists even on defeat (SF core mechanic)
@export var retain_xp_on_defeat: bool = true

## For battle nodes: Gold penalty on defeat (0.5 = lose 50% gold, SF default)
@export_range(0.0, 1.0, 0.05) var defeat_gold_penalty: float = 0.5

## For battle nodes: Can this battle be replayed for grinding?
@export var repeatable: bool = false

## For battle nodes: Does replaying this battle advance the story?
@export var replay_advances_story: bool = false

## For scene nodes: Can player use Egress to warp back to hub?
@export var allow_egress: bool = true

## Is this node a hub (affects egress return point)?
@export var is_hub: bool = false

## Is this a chapter boundary? Triggers save prompt and chapter transition UI
@export var is_chapter_boundary: bool = false

# ---- Cinematics ----

## Pre-node cinematic (plays before node starts)
@export var pre_cinematic_id: String = ""

## Post-node cinematic (plays after node completes, before transition)
@export var post_cinematic_id: String = ""

# ---- Flags ----

## Flags to set when this node is entered
@export var on_enter_flags: Dictionary = {}

## Flags to set when this node is completed
@export var on_complete_flags: Dictionary = {}

## Required flags to access this node (gating)
@export var required_flags: Array[String] = []

## Forbidden flags that prevent access to this node
@export var forbidden_flags: Array[String] = []

# ---- Completion Triggers for Scene Nodes ----

## How scene nodes complete: "exit_trigger", "flag_set", "npc_interaction", "manual"
@export var completion_trigger: String = "exit_trigger"

## For flag_set completion: which flag triggers completion
@export var completion_flag: String = ""

## For npc_interaction completion: which NPC ID triggers completion
@export var completion_npc_id: String = ""


## Validation - returns array of error messages (empty = valid)
func validate() -> Array[String]:
	var errors: Array[String] = []

	if node_id.is_empty():
		errors.append("node_id is required")
	if display_name.is_empty():
		errors.append("display_name is required")
	if node_type.is_empty():
		errors.append("node_type is required")

	# Type-specific validation
	if node_type == "battle":
		if resource_id.is_empty():
			errors.append("battle nodes require resource_id")
	elif node_type == "scene":
		if resource_id.is_empty() and scene_path.is_empty():
			errors.append("scene nodes require resource_id or scene_path")
	elif node_type == "cutscene":
		if resource_id.is_empty():
			errors.append("cutscene nodes require resource_id")

	# Validate defeat_gold_penalty range
	if defeat_gold_penalty < 0.0 or defeat_gold_penalty > 1.0:
		errors.append("defeat_gold_penalty must be between 0.0 and 1.0")

	# Validate branches structure
	for i: int in range(branches.size()):
		var branch: Dictionary = branches[i]
		if "target" not in branch:
			errors.append("branch[%d] missing 'target'" % i)
		if "trigger" not in branch:
			errors.append("branch[%d] missing 'trigger'" % i)

	return errors


## Get the appropriate transition target based on outcome
## game_state_checker: Callable that takes a flag name and returns bool
func get_transition_target(outcome: Dictionary, game_state_checker: Callable) -> String:
	# Check simple transitions first based on outcome type
	if "victory" in outcome:
		if outcome["victory"] and not on_victory.is_empty():
			return on_victory
		elif not outcome["victory"] and not on_defeat.is_empty():
			return on_defeat

	# For choice outcomes or when checking branches
	if "choice" in outcome or not branches.is_empty():
		# Sort branches by priority (higher first)
		var sorted_branches: Array[Dictionary] = branches.duplicate()
		sorted_branches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var a_priority: int = DictUtils.get_int(a, "priority", 0)
			var b_priority: int = DictUtils.get_int(b, "priority", 0)
			return a_priority > b_priority
		)

		for branch: Dictionary in sorted_branches:
			if _branch_matches(branch, outcome, game_state_checker):
				return DictUtils.get_string(branch, "target", "")

	# Fallback to on_complete
	return on_complete


## Check if a branch matches the given outcome and game state
func _branch_matches(branch: Dictionary, outcome: Dictionary, game_state_checker: Callable) -> bool:
	var trigger: String = DictUtils.get_string(branch, "trigger", "always")

	match trigger:
		"choice":
			var choice_value: String = DictUtils.get_string(branch, "choice_value", "")
			var outcome_choice: String = DictUtils.get_string(outcome, "choice", "")
			if outcome_choice != choice_value:
				return false
		"flag":
			var required_flag: String = DictUtils.get_string(branch, "required_flag", "")
			if not required_flag.is_empty() and not game_state_checker.call(required_flag):
				return false
		"always":
			pass  # Always matches
		_:
			push_warning("CampaignNode: Unknown trigger type '%s'" % trigger)
			return false

	# Check additional required flags
	var required_flags_list: Array = DictUtils.get_array(branch, "required_flags", [])
	for flag_variant: Variant in required_flags_list:
		var flag: String = flag_variant if flag_variant is String else ""
		if not flag.is_empty() and not game_state_checker.call(flag):
			return false

	# Check forbidden flags
	var forbidden_flags_list: Array = DictUtils.get_array(branch, "forbidden_flags", [])
	for flag_variant: Variant in forbidden_flags_list:
		var flag: String = flag_variant if flag_variant is String else ""
		if not flag.is_empty() and game_state_checker.call(flag):
			return false

	return true


## Check if this node can be accessed given current flags
func can_access(game_state_checker: Callable) -> bool:
	# Check required flags
	for flag: String in required_flags:
		if not game_state_checker.call(flag):
			return false

	# Check forbidden flags
	for flag: String in forbidden_flags:
		if game_state_checker.call(flag):
			return false

	return true
