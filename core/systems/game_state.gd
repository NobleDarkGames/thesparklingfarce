extends Node
## GameState singleton - Manages story flags, trigger completion, and campaign state
##
## This autoload manages persistent game state including:
## - Story flags (boolean flags for quest/narrative progression)
## - Completed triggers (one-shot trigger tracking)
## - Campaign progress tracking
##
## Story flags enable conditional content:
## - Required flags: Trigger only activates if flag is set
## - Forbidden flags: Trigger won't activate if flag is set
##
## Integration with SaveManager for persistence across game sessions.

## Story flags - boolean flags for narrative/quest progression
## Example: "defeated_first_boss", "rescued_princess", "chapter_2_unlocked"
var story_flags: Dictionary = {}

## Completed triggers - tracks one-shot triggers that have been activated
## Key: trigger_id (String), Value: true (triggered) or false/absent (not triggered)
var completed_triggers: Dictionary = {}

## Campaign progress data (extensible for future needs)
var campaign_data: Dictionary = {
	"current_chapter": 0,
	"battles_won": 0,
	"treasures_found": 0,
}

## Emitted when a story flag changes
signal flag_changed(flag_name: String, value: bool)

## Emitted when a trigger is marked as completed
signal trigger_completed(trigger_id: String)

## Emitted when campaign data is updated
signal campaign_data_changed(key: String, value: Variant)


func _ready() -> void:
	# Register with SaveManager for persistence
	if SaveManager:
		# Note: SaveManager integration will be added in Phase 2.5.2
		pass


## Check if a story flag is set to true
func has_flag(flag_name: String) -> bool:
	return story_flags.get(flag_name, false)


## Set a story flag (default: true)
func set_flag(flag_name: String, value: bool = true) -> void:
	if story_flags.get(flag_name) == value:
		return  # No change, don't emit signal

	story_flags[flag_name] = value
	flag_changed.emit(flag_name, value)


## Clear a story flag (set to false)
func clear_flag(flag_name: String) -> void:
	set_flag(flag_name, false)


## Check if a trigger has been completed
func is_trigger_completed(trigger_id: String) -> bool:
	return completed_triggers.get(trigger_id, false)


## Mark a trigger as completed (one-shot triggers use this)
func set_trigger_completed(trigger_id: String) -> void:
	if completed_triggers.get(trigger_id):
		return  # Already completed

	completed_triggers[trigger_id] = true
	trigger_completed.emit(trigger_id)


## Reset a trigger (allows re-activation)
## Use sparingly - most triggers should be one-shot
func reset_trigger(trigger_id: String) -> void:
	if trigger_id in completed_triggers:
		completed_triggers.erase(trigger_id)


## Get campaign progress value
func get_campaign_data(key: String, default: Variant = null) -> Variant:
	return campaign_data.get(key, default)


## Set campaign progress value
func set_campaign_data(key: String, value: Variant) -> void:
	if campaign_data.get(key) == value:
		return  # No change

	campaign_data[key] = value
	campaign_data_changed.emit(key, value)


## Increment a numeric campaign value
func increment_campaign_data(key: String, amount: int = 1) -> void:
	var current_value: int = campaign_data.get(key, 0)
	set_campaign_data(key, current_value + amount)


## Export state for save system
func export_state() -> Dictionary:
	return {
		"story_flags": story_flags.duplicate(),
		"completed_triggers": completed_triggers.duplicate(),
		"campaign_data": campaign_data.duplicate(),
	}


## Import state from save system
func import_state(state: Dictionary) -> void:
	story_flags = state.get("story_flags", {}).duplicate()
	completed_triggers = state.get("completed_triggers", {}).duplicate()
	campaign_data = state.get("campaign_data", {}).duplicate()


## Clear all state (for new game)
func reset_all() -> void:
	story_flags.clear()
	completed_triggers.clear()
	campaign_data = {
		"current_chapter": 0,
		"battles_won": 0,
		"treasures_found": 0,
	}
