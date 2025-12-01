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
## For mod safety, use namespaced flags: "mod_id:flag_name" (e.g., "my_mod:boss_defeated")
var story_flags: Dictionary = {}

## Completed triggers - tracks one-shot triggers that have been activated
## Key: trigger_id (String), Value: true (triggered) or false/absent (not triggered)
var completed_triggers: Dictionary = {}

## Current mod namespace for scoped flag operations
## Set by mod scripts to auto-prefix flags with their mod ID
var _current_mod_namespace: String = ""

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


## Global quit handler - Q key quits the game (development convenience)
## Uses _unhandled_input for efficiency (only fires on actual input, not every frame)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			get_tree().quit()


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


# ==== Namespaced Flag API (Phase 2.5.1) ====

## Set the current mod namespace for scoped flag operations
## Call this at the start of mod scripts to enable auto-prefixing
## Example: GameState.set_mod_namespace("my_cool_mod")
func set_mod_namespace(mod_id: String) -> void:
	_current_mod_namespace = mod_id


## Clear the current mod namespace
func clear_mod_namespace() -> void:
	_current_mod_namespace = ""


## Get the current mod namespace
func get_mod_namespace() -> String:
	return _current_mod_namespace


## Build a fully-qualified flag name with namespace
## If flag already contains ":", assumes it's already namespaced
## If no namespace set and flag has no ":", uses flag as-is (backwards compatible)
func _qualify_flag_name(flag_name: String, mod_id: String = "") -> String:
	# Already namespaced
	if ":" in flag_name:
		return flag_name

	# Use provided mod_id, fall back to current namespace
	var ns: String = mod_id if not mod_id.is_empty() else _current_mod_namespace

	# If we have a namespace, prefix the flag
	if not ns.is_empty():
		return "%s:%s" % [ns, flag_name]

	# No namespace - return as-is (backwards compatible)
	return flag_name


## Check if a story flag is set (with automatic namespacing)
## If mod_id is provided, uses that namespace
## Otherwise uses current mod namespace if set
## Falls back to exact flag name for backwards compatibility
func has_flag_scoped(flag_name: String, mod_id: String = "") -> bool:
	var qualified_name: String = _qualify_flag_name(flag_name, mod_id)
	return story_flags.get(qualified_name, false)


## Set a story flag with automatic namespacing
## If mod_id is provided, uses that namespace
## Otherwise uses current mod namespace if set
## Falls back to exact flag name for backwards compatibility
func set_flag_scoped(flag_name: String, value: bool = true, mod_id: String = "") -> void:
	var qualified_name: String = _qualify_flag_name(flag_name, mod_id)
	if story_flags.get(qualified_name) == value:
		return  # No change, don't emit signal

	story_flags[qualified_name] = value
	flag_changed.emit(qualified_name, value)


## Clear a story flag with automatic namespacing
func clear_flag_scoped(flag_name: String, mod_id: String = "") -> void:
	set_flag_scoped(flag_name, false, mod_id)


## Get all flags for a specific mod namespace
## Returns dictionary of {flag_name_without_prefix: value}
func get_flags_for_mod(mod_id: String) -> Dictionary:
	var prefix: String = mod_id + ":"
	var result: Dictionary = {}

	for flag_name: String in story_flags:
		if flag_name.begins_with(prefix):
			var short_name: String = flag_name.substr(prefix.length())
			result[short_name] = story_flags[flag_name]

	return result


## Check if a flag name is properly namespaced
func is_flag_namespaced(flag_name: String) -> bool:
	return ":" in flag_name


## Issue a deprecation warning for non-namespaced flags (call during development)
## Set enabled = true to activate warnings
func warn_unnamespaced_flags(enabled: bool = true) -> void:
	if not enabled:
		return

	for flag_name: String in story_flags:
		if not is_flag_namespaced(flag_name):
			push_warning("GameState: Non-namespaced flag '%s' detected. Consider using 'mod_id:%s' format." % [flag_name, flag_name])


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


## Check if there's return data available
func has_return_data() -> bool:
	return _transition_context != null and _transition_context.is_valid()


## Clear return data after using it
func clear_return_data() -> void:
	_transition_context = null


## NEW API: Set full transition context
func set_transition_context(context: RefCounted) -> void:
	_transition_context = context


## NEW API: Get current transition context (returns TransitionContext or null)
func get_transition_context() -> RefCounted:
	return _transition_context


## NEW API: Clear transition context
func clear_transition_context() -> void:
	_transition_context = null
