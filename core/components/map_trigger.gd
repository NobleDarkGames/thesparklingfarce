class_name MapTrigger
extends Area2D
## Base class for map triggers - handles conditional activation and one-shot functionality
##
## MapTrigger is the foundation for all map-based interactions in The Sparkling Farce:
## - Battle triggers (initiate tactical battles)
## - Dialog triggers (start conversations)
## - Chest triggers (grant items/rewards)
## - Door triggers (scene transitions, key checks)
## - Cutscene triggers (story events)
##
## Supports story flag conditions:
## - Required flags: Trigger only activates if ALL are set
## - Forbidden flags: Trigger won't activate if ANY are set
##
## One-shot triggers are marked as completed in GameState after activation.

## Type of trigger (determines handling by TriggerManager)
## DEPRECATED: Use trigger_type_string instead for mod extensibility
enum TriggerType {
	BATTLE,       ## Initiate a tactical battle
	DIALOG,       ## Start a dialog/conversation
	CHEST,        ## Open a treasure chest
	DOOR,         ## Scene transition or locked door
	CUTSCENE,     ## Play a cutscene/story event
	TRANSITION,   ## Teleport to another map location
	CUSTOM        ## User-defined custom trigger type
}

## Mapping from enum values to string names (for backwards compatibility)
const TRIGGER_TYPE_NAMES: Dictionary = {
	TriggerType.BATTLE: "battle",
	TriggerType.DIALOG: "dialog",
	TriggerType.CHEST: "chest",
	TriggerType.DOOR: "door",
	TriggerType.CUTSCENE: "cutscene",
	TriggerType.TRANSITION: "transition",
	TriggerType.CUSTOM: "custom"
}

## The type of this trigger (determines handling by TriggerManager)
@export var trigger_type: TriggerType = TriggerType.BATTLE

## Unique identifier for this trigger (used for save system and completion tracking)
## Leave empty to auto-generate from node name
@export var trigger_id: String = ""

## If true, trigger can only activate once (tracked in GameState)
@export var one_shot: bool = true

## Story flags that MUST be set for this trigger to activate
@export var required_flags: Array[String] = []

## Story flags that PREVENT this trigger from activating if set
@export var forbidden_flags: Array[String] = []

# =============================================================================
# TYPE-SPECIFIC SETTINGS (use these instead of trigger_data)
# =============================================================================

@export_group("Door Settings")
## Scene to transition to (e.g., "res://mods/my_mod/maps/town.tscn")
@export_file("*.tscn") var destination_scene: String = ""
## Spawn point ID in the destination scene
@export var spawn_point: String = ""
## Item ID required to use this door (leave empty for unlocked)
@export var requires_key: String = ""

@export_group("Battle Settings")
## Battle ID to initiate (from mod's data/battles/)
@export var battle_id: String = ""

@export_group("Dialog Settings")
## Dialog ID to start (from mod's data/dialogues/)
@export var dialog_id: String = ""

@export_group("Cutscene Settings")
## Cinematic ID to play (from mod's data/cinematics/)
@export var cinematic_id: String = ""

@export_group("Chest Settings")
## Item ID to grant (leave empty for gold-only chest)
@export var chest_item_id: String = ""
## Quantity of item to grant
@export var chest_quantity: int = 1
## Gold to grant
@export var chest_gold: int = 0

@export_group("Advanced")
## String-based trigger type for mod-defined custom types
## Only needed for custom trigger types (e.g., "puzzle", "minigame")
@export var trigger_type_string: String = ""
## Raw trigger data (for advanced use - convenience fields above are preferred)
@export var trigger_data: Dictionary = {}

## Emitted when the trigger is activated (player enters and conditions met)
signal triggered(trigger: MapTrigger, player: Node2D)

## Emitted when activation is attempted but conditions not met
signal activation_failed(trigger: MapTrigger, reason: String)


func _ready() -> void:
	# Ensure collision layer is set correctly (layer 2 for triggers)
	collision_layer = 2
	collision_mask = 1  # Detect layer 1 (player/hero)

	# Connect to body entered signal
	body_entered.connect(_on_body_entered)

	# Auto-generate trigger_id from node name if not set
	# "ExitSouth" → "exit_south", "BattleTrigger1" → "battle_trigger_1"
	if trigger_id.is_empty():
		trigger_id = name.to_snake_case()

	# Populate trigger_data from convenience fields (if set)
	_populate_trigger_data()


## Populate trigger_data dictionary from convenience @export fields.
## Convenience fields take precedence over raw trigger_data entries.
func _populate_trigger_data() -> void:
	# Door settings
	if not destination_scene.is_empty():
		trigger_data["destination_scene"] = destination_scene
	if not spawn_point.is_empty():
		trigger_data["spawn_point"] = spawn_point
	if not requires_key.is_empty():
		trigger_data["requires_key"] = requires_key

	# Battle settings
	if not battle_id.is_empty():
		trigger_data["battle_id"] = battle_id

	# Dialog settings
	if not dialog_id.is_empty():
		trigger_data["dialog_id"] = dialog_id

	# Cutscene settings
	if not cinematic_id.is_empty():
		trigger_data["cinematic_id"] = cinematic_id

	# Chest settings
	if not chest_item_id.is_empty():
		trigger_data["item_id"] = chest_item_id
	if chest_quantity > 1:
		trigger_data["quantity"] = chest_quantity
	if chest_gold > 0:
		trigger_data["gold"] = chest_gold


## Called when a body enters the trigger area
func _on_body_entered(body: Node2D) -> void:
	# Only activate for hero character
	if not body.is_in_group("hero"):
		return

	# Check if trigger can activate
	if can_trigger():
		activate(body)
	else:
		var reason: String = _get_failure_reason()
		activation_failed.emit(self, reason)


## Check if this trigger can currently activate
func can_trigger() -> bool:
	# Check if already triggered (for one-shot triggers)
	if one_shot and not trigger_id.is_empty():
		if GameState.is_trigger_completed(trigger_id):
			return false

	# Check required flags (ALL must be set)
	for flag: String in required_flags:
		if not GameState.has_flag(flag):
			return false

	# Check forbidden flags (NONE can be set)
	for flag: String in forbidden_flags:
		if GameState.has_flag(flag):
			return false

	return true


## Activate the trigger (called when player enters and conditions met)
func activate(player: Node2D) -> void:
	# Emit signal for handling (TriggerManager listens)
	triggered.emit(self, player)

	# Mark as completed for one-shot triggers
	if one_shot and not trigger_id.is_empty():
		GameState.set_trigger_completed(trigger_id)


## Get human-readable reason why trigger failed to activate
func _get_failure_reason() -> String:
	# Check one-shot
	if one_shot and not trigger_id.is_empty():
		if GameState.is_trigger_completed(trigger_id):
			return "Already completed"

	# Check required flags
	for flag: String in required_flags:
		if not GameState.has_flag(flag):
			return "Missing required flag: %s" % flag

	# Check forbidden flags
	for flag: String in forbidden_flags:
		if GameState.has_flag(flag):
			return "Forbidden flag set: %s" % flag

	return "Unknown reason"


## Get the effective trigger type as a string
## Prefers trigger_type_string if set, otherwise converts enum to string
## This is the recommended way to check trigger type for handling
func get_trigger_type_name() -> String:
	# Prefer string-based type if set
	if not trigger_type_string.is_empty():
		return trigger_type_string.to_lower()

	# Fall back to enum-based type
	return TRIGGER_TYPE_NAMES.get(trigger_type, "custom")


## Check if this trigger is of a specific type (string comparison)
## Works with both enum-based and string-based trigger types
func is_trigger_type(type_name: String) -> bool:
	return get_trigger_type_name() == type_name.to_lower()


## Get type-specific data from trigger_data
func get_trigger_value(key: String, default: Variant = null) -> Variant:
	return trigger_data.get(key, default)


## Set type-specific data in trigger_data
func set_trigger_value(key: String, value: Variant) -> void:
	trigger_data[key] = value


## Reset this trigger (allows re-activation even if one-shot)
## Use sparingly - most triggers should stay completed
func reset() -> void:
	if not trigger_id.is_empty():
		GameState.reset_trigger(trigger_id)
