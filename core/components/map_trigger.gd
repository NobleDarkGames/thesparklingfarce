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
enum TriggerType {
	BATTLE,       ## Initiate a tactical battle
	DIALOG,       ## Start a dialog/conversation
	CHEST,        ## Open a treasure chest
	DOOR,         ## Scene transition or locked door
	CUTSCENE,     ## Play a cutscene/story event
	TRANSITION,   ## Teleport to another map location
	CUSTOM        ## User-defined custom trigger type
}

## The type of this trigger
@export var trigger_type: TriggerType = TriggerType.BATTLE

## Unique identifier for this trigger (used for save system and completion tracking)
@export var trigger_id: String = ""

## If true, trigger can only activate once (tracked in GameState)
@export var one_shot: bool = true

## Story flags that MUST be set for this trigger to activate
## Example: ["defeated_first_boss", "talked_to_king"]
@export var required_flags: Array[String] = []

## Story flags that PREVENT this trigger from activating if set
## Example: ["already_got_treasure", "door_unlocked"]
@export var forbidden_flags: Array[String] = []

## Type-specific data payload (interpretation depends on trigger_type)
##
## For BATTLE triggers:
##   { "battle_id": "tutorial_battle_001" }
##
## For DIALOG triggers:
##   { "dialog_id": "king_greeting" }
##
## For CHEST triggers:
##   { "item_id": "healing_herb", "quantity": 3, "gold": 100 }
##
## For DOOR triggers:
##   { "destination_scene": "res://maps/town_interior.tscn", "spawn_point": "door_01" }
##
## For TRANSITION triggers:
##   { "target_position": Vector2(10, 15) }
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

	# Validate trigger configuration
	if trigger_id.is_empty():
		push_warning("MapTrigger at %s has no trigger_id - one_shot functionality won't work" % get_path())


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
