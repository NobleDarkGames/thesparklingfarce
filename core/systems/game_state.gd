extends Node
## GameState singleton - Manages story flags, trigger completion, and campaign state

## Preload TransitionContext to ensure it's available before autoload init
const TransitionContextScript: GDScript = preload("res://core/resources/transition_context.gd")
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

## Battle transition context - encapsulates all transition data
## Use TransitionContext for type safety and extensibility
var _transition_context: RefCounted = null  # Actually TransitionContext

## Legacy accessors (maintained for backwards compatibility)
var return_scene_path: String:
	get:
		return _transition_context.return_scene_path if _transition_context else ""
	set(value):
		if not _transition_context:
			_transition_context = TransitionContextScript.new()
		_transition_context.return_scene_path = value

var return_hero_position: Vector2:
	get:
		return _transition_context.hero_world_position if _transition_context else Vector2.ZERO
	set(value):
		if not _transition_context:
			_transition_context = TransitionContextScript.new()
		_transition_context.hero_world_position = value

var return_hero_grid_position: Vector2i:
	get:
		return _transition_context.hero_grid_position if _transition_context else Vector2i.ZERO
	set(value):
		if not _transition_context:
			_transition_context = TransitionContextScript.new()
		_transition_context.hero_grid_position = value

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
	clear_return_data()


## Store where to return after battle (legacy API - uses TransitionContext internally)
func set_return_data(scene_path: String, hero_pos: Vector2, hero_grid_pos: Vector2i) -> void:
	_transition_context = TransitionContextScript.new()
	_transition_context.return_scene_path = scene_path
	_transition_context.hero_world_position = hero_pos
	_transition_context.hero_grid_position = hero_grid_pos
	print("GameState: Stored return data - Scene: %s, Position: %s" % [scene_path, hero_grid_pos])


## Check if there's return data available
func has_return_data() -> bool:
	return _transition_context != null and _transition_context.is_valid()


## Clear return data after using it
func clear_return_data() -> void:
	_transition_context = null


## NEW API: Set full transition context
func set_transition_context(context: RefCounted) -> void:
	_transition_context = context
	print("GameState: Stored transition context - Scene: %s" % context.return_scene_path)


## NEW API: Get current transition context (returns TransitionContext or null)
func get_transition_context() -> RefCounted:
	return _transition_context


## NEW API: Clear transition context
func clear_transition_context() -> void:
	_transition_context = null
