@tool
class_name InteractableData
extends Resource

## Represents an interactive map object (chests, bookshelves, barrels, signs, etc.)
##
## Interactables are single-tile objects that respond to player interaction
## (like NPCs) but are typically for granting items, showing messages, or
## triggering one-shot events.
##
## SF2-AUTHENTIC BEHAVIOR:
## - Search command activates the object (same as NPC interaction)
## - Immediate feedback: "Found [item]!" - no pre-dialog
## - State persistence: opened chests stay opened
##
## USAGE:
## - Set interactable_type for appropriate default behavior
## - For chests: set item_rewards and/or gold_reward
## - For bookshelves/signs: set dialog_text for simple messages
## - For complex interactions: set interaction_cinematic_id
##
## STATE TRACKING:
## - Uses GameState flags for persistence
## - completion_flag is auto-generated if empty: "{interactable_id}_opened"
## - Check GameState.has_flag(completion_flag) for opened state

## Type of interactable object (affects default behavior and editor templates)
enum InteractableType {
	CHEST,      ## Contains items, opens when searched (one-shot)
	BOOKSHELF,  ## Read-only text, no state change (repeatable)
	BARREL,     ## Searchable container, may contain items (one-shot)
	SIGN,       ## Read-only text, typically outdoors (repeatable)
	LEVER,      ## Toggle state, triggers events (repeatable but tracks state)
	CUSTOM      ## Mod-defined behavior
}

## Default messages for empty interactables (centralized for localization)
const DEFAULT_EMPTY_MESSAGES: Dictionary = {
	InteractableType.CHEST: "The chest is empty.",
	InteractableType.BOOKSHELF: "Dusty tomes line the shelves...",
	InteractableType.BARREL: "There's nothing inside.",
	InteractableType.SIGN: "The sign is blank.",
	InteractableType.LEVER: "A rusty lever.",
}

## Default messages for already-opened interactables
const DEFAULT_ALREADY_OPENED_MESSAGES: Dictionary = {
	InteractableType.CHEST: "The chest has already been opened.",
	InteractableType.BARREL: "You've already searched this.",
}

## Fallback messages
const FALLBACK_EMPTY_MESSAGE: String = "There's nothing here."
const FALLBACK_ALREADY_OPENED_MESSAGE: String = "There's nothing more here."


## Get default message for an empty interactable of the given type
static func get_default_empty_message(type: InteractableType) -> String:
	if type in DEFAULT_EMPTY_MESSAGES:
		return DEFAULT_EMPTY_MESSAGES[type]
	return FALLBACK_EMPTY_MESSAGE


## Get default message for an already-opened interactable of the given type
static func get_already_opened_message(type: InteractableType) -> String:
	if type in DEFAULT_ALREADY_OPENED_MESSAGES:
		return DEFAULT_ALREADY_OPENED_MESSAGES[type]
	return FALLBACK_ALREADY_OPENED_MESSAGE


## Unique identifier for this interactable (used in mod registry)
@export var interactable_id: String = ""

## Display name shown in UI/messages (e.g., "Treasure Chest", "Dusty Bookshelf")
@export var display_name: String = ""

## Type determines default behavior and editor templates
@export var interactable_type: InteractableType = InteractableType.CHEST

@export_group("Appearance")
## Sprite for closed/unsearched state
@export var sprite_closed: Texture2D

## Sprite for opened/searched state (optional - uses closed if not set)
@export var sprite_opened: Texture2D

@export_group("Rewards")
## Items to grant when searched
## Each entry: {"item_id": String, "quantity": int (optional, default 1)}
@export var item_rewards: Array[Dictionary] = []

## Gold amount to grant when searched
@export var gold_reward: int = 0

@export_group("Interaction - Cinematic")
## Explicit cinematic to play on interaction (overrides auto-generation)
## Leave empty for default behavior based on interactable_type
@export var interaction_cinematic_id: String = ""

## Fallback cinematic if no conditions match
@export var fallback_cinematic_id: String = ""

## Conditional cinematics (same format as NPCData)
## Priority-ordered array of conditions:
##   - "flag": String (single flag must be true)
##   - "flags": Array[String] (AND logic - all must be true)
##   - "any_flags": Array[String] (OR logic - at least one must be true)
##   - "cinematic_id": String (cinematic to play if condition met)
##   - "negate": bool (optional - inverts overall result)
@export var conditional_cinematics: Array[Dictionary] = []

@export_group("Behavior")
## If true, can only be searched once (chests, barrels)
## If false, can be searched repeatedly (bookshelves, signs)
@export var one_shot: bool = true

## Required flags to interact (empty = always available)
@export var required_flags: Array[String] = []

## Flags that prevent interaction (e.g., quest not started yet)
@export var forbidden_flags: Array[String] = []

## Flag set after successful interaction
## Auto-generated if empty: "{interactable_id}_opened"
@export var completion_flag: String = ""


# =============================================================================
# RUNTIME METHODS
# =============================================================================

## Get the completion flag name (auto-generates if not set)
func get_completion_flag() -> String:
	if not completion_flag.is_empty():
		return completion_flag
	return "%s_opened" % interactable_id


## Check if this interactable has already been opened/searched
func is_opened() -> bool:
	if not one_shot:
		return false  # Repeatable objects are never "opened"
	return GameState.has_flag(get_completion_flag())


## Check if the player can interact with this object
## @return: Dictionary with "can_interact": bool, "reason": String (if blocked)
func can_interact() -> Dictionary:
	if is_opened():
		return {"can_interact": false, "reason": "already_opened"}

	var missing_flag: String = _find_missing_required_flag()
	if not missing_flag.is_empty():
		return {"can_interact": false, "reason": "missing_flag", "flag": missing_flag}

	var forbidden_flag: String = _find_set_forbidden_flag()
	if not forbidden_flag.is_empty():
		return {"can_interact": false, "reason": "forbidden_flag", "flag": forbidden_flag}

	return {"can_interact": true, "reason": ""}


## Find the first required flag that is not set, or empty string if all are set
func _find_missing_required_flag() -> String:
	for flag_name: String in required_flags:
		if not flag_name.is_empty() and not GameState.has_flag(flag_name):
			return flag_name
	return ""


## Find the first forbidden flag that is set, or empty string if none are set
func _find_set_forbidden_flag() -> String:
	for flag_name: String in forbidden_flags:
		if not flag_name.is_empty() and GameState.has_flag(flag_name):
			return flag_name
	return ""


## Get the appropriate cinematic ID based on current game state
## Priority: conditional_cinematics > interaction_cinematic_id > fallback > auto-generated
func get_cinematic_id_for_state() -> String:
	# Check conditional cinematics in priority order
	for condition: Dictionary in conditional_cinematics:
		var cinematic_id: String = DictUtils.get_string(condition, "cinematic_id", "")
		if cinematic_id.is_empty():
			continue

		if _evaluate_condition(condition):
			return cinematic_id

	# Use explicit cinematic if set
	if not interaction_cinematic_id.is_empty():
		return interaction_cinematic_id

	# Use fallback if set
	if not fallback_cinematic_id.is_empty():
		return fallback_cinematic_id

	# Auto-generate based on type and rewards
	return _get_auto_cinematic_id()


## Mark this interactable as opened (sets completion flag)
func mark_opened() -> void:
	if one_shot:
		GameState.set_flag(get_completion_flag())


## Check if this interactable has any rewards to grant
func has_rewards() -> bool:
	return gold_reward > 0 or not item_rewards.is_empty()


## Get sprite for current state
func get_current_sprite() -> Texture2D:
	if is_opened() and sprite_opened:
		return sprite_opened
	return sprite_closed


# =============================================================================
# PRIVATE METHODS
# =============================================================================

## Evaluate a condition entry (same logic as NPCData)
func _evaluate_condition(condition: Dictionary) -> bool:
	var negate: bool = DictUtils.get_bool(condition, "negate", false)
	var has_any_condition: bool = false
	var all_conditions_pass: bool = true

	# Single flag (legacy support)
	var single_flag: String = DictUtils.get_string(condition, "flag", "")
	if not single_flag.is_empty():
		has_any_condition = true
		if not GameState.has_flag(single_flag):
			all_conditions_pass = false

	# AND logic: all flags must be true
	var and_flags: Array = DictUtils.get_array(condition, "flags", [])
	if not and_flags.is_empty():
		has_any_condition = true
		if not _all_flags_set(and_flags):
			all_conditions_pass = false

	# OR logic: at least one must be true
	var or_flags: Array = DictUtils.get_array(condition, "any_flags", [])
	if not or_flags.is_empty():
		has_any_condition = true
		if not _any_flag_set(or_flags):
			all_conditions_pass = false

	if not has_any_condition:
		return false

	return not all_conditions_pass if negate else all_conditions_pass


## Check if all flags in the array are set
func _all_flags_set(flags: Array) -> bool:
	for flag_variant: Variant in flags:
		var flag_name: String = flag_variant as String if flag_variant is String else ""
		if not flag_name.is_empty() and not GameState.has_flag(flag_name):
			return false
	return true


## Check if any flag in the array is set
func _any_flag_set(flags: Array) -> bool:
	for flag_variant: Variant in flags:
		var flag_name: String = flag_variant as String if flag_variant is String else ""
		if not flag_name.is_empty() and GameState.has_flag(flag_name):
			return true
	return false


## Generate auto-cinematic ID for default behavior
## Format: __auto_interactable__{interactable_id}
func _get_auto_cinematic_id() -> String:
	return "__auto_interactable__%s" % interactable_id


# =============================================================================
# VALIDATION
# =============================================================================

## Validate that required fields are set
func validate() -> bool:
	if interactable_id.is_empty():
		push_error("InteractableData: interactable_id is required")
		return false

	# Must have some form of interaction defined
	# Interactables should either have rewards OR an explicit cinematic
	# For text-only objects (signs, bookshelves), use an explicit cinematic
	var has_interaction: bool = (
		not interaction_cinematic_id.is_empty() or
		not fallback_cinematic_id.is_empty() or
		not conditional_cinematics.is_empty() or
		has_rewards()
	)

	if not has_interaction:
		push_error("InteractableData: Must have rewards or a cinematic defined")
		return false

	return true
