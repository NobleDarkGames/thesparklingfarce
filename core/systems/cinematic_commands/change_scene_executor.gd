## Change scene command executor
## Loads a new scene/map during a cinematic, optionally with fade transition
##
## IMPORTANT: This command ENDS the current cinematic and transitions to the new scene.
## The scene change happens AFTER the cinematic_ended signal fires, ensuring any
## listeners (like startup.gd) can handle the signal before the scene changes.
##
## USAGE IN CINEMATICS:
## {
##     "type": "change_scene",
##     "params": {
##         "scene_path": "res://mods/my_mod/maps/town_square.tscn",  # Direct path
##         "scene_id": "town_square",  # OR use registered scene ID
##         "map_id": "town_square",    # OR use registered map ID (loads map's scene)
##         "use_fade": true,           # Optional, default true
##         "fade_duration": 0.5        # Optional, default 0.5
##     }
## }
##
## Priority: scene_path > scene_id > map_id
## If use_fade is true, fades to black before storing destination
class_name ChangeSceneExecutor
extends CinematicCommandExecutor


## Track if this executor was interrupted during async operation
var _interrupted: bool = false
## Reference to manager for async completion
var _active_manager: Node = null


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})

	# Get scene path from various sources (priority order)
	var scene_path: String = CinematicCommandExecutor.resolve_scene_path(params)

	if scene_path.is_empty():
		push_error("ChangeSceneExecutor: No valid scene path, scene_id, or map_id provided")
		return true  # Complete immediately on error

	if not ResourceLoader.exists(scene_path):
		push_error("ChangeSceneExecutor: Scene does not exist: %s" % scene_path)
		return true

	var use_fade: bool = params.get("use_fade", true)
	var fade_duration: float = params.get("fade_duration", 0.5)

	# Reset state
	_interrupted = false
	_active_manager = manager

	# Store destination and optionally fade, then complete
	# The actual scene change happens when the cinematic ends
	_prepare_scene_change(scene_path, use_fade, fade_duration)

	return false  # Async (for fade)


## Called when the cinematic is interrupted (e.g., skipped by player)
func interrupt() -> void:
	_interrupted = true
	_active_manager = null


## Prepare scene change: fade to black if needed, then store destination
## The actual scene change happens when CinematicsManager ends the cinematic
func _prepare_scene_change(scene_path: String, use_fade: bool, fade_duration: float) -> void:
	if use_fade and SceneManager and not SceneManager.is_faded_to_black:
		await SceneManager.fade_to_black(fade_duration)

		if _interrupted:
			return

	# Store the destination in CinematicsManager
	# The scene change will happen AFTER cinematic_ended signal fires
	if _active_manager and is_instance_valid(_active_manager):
		_active_manager.set_next_destination(scene_path, use_fade)

	_complete()


## Signal completion to the cinematic manager
func _complete() -> void:
	CinematicCommandExecutor.complete_async_command(_active_manager, false)
	_active_manager = null


## Editor metadata for the cinematic editor
func get_editor_metadata() -> Dictionary:
	return {
		"description": "End cinematic and change to a different scene or map",
		"category": "Scene",
		"params": {
			"scene_path": {
				"type": "string",
				"description": "Direct path to scene file (e.g., res://mods/my_mod/maps/town.tscn)",
				"hint": "Leave blank to use Scene Id or Map Id instead",
				"required": false
			},
			"scene_id": {
				"type": "scene_id",
				"description": "Registered scene ID from mod.json",
				"required": false
			},
			"map_id": {
				"type": "map_id",
				"description": "Map ID to load (uses map's scene_path)",
				"required": false
			},
			"use_fade": {
				"type": "bool",
				"description": "Fade to black during transition",
				"default": true
			},
			"fade_duration": {
				"type": "float",
				"description": "Duration of fade in seconds",
				"default": 0.5
			}
		}
	}
