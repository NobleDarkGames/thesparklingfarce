## Set backdrop command executor
## Loads a scene as a visual backdrop for cinematics without triggering gameplay logic
##
## This command loads a scene (map, custom scene, etc.) and adds it as a child
## of the current cinematic stage. The scene is loaded in "backdrop mode" which
## tells map_template and other gameplay scenes to skip party loading, camera
## setup, and other gameplay initialization.
##
## USAGE IN CINEMATICS:
## {
##     "type": "set_backdrop",
##     "params": {
##         "scene_path": "res://mods/my_mod/maps/town_square.tscn",  # Direct path
##         "scene_id": "town_square",  # OR use registered scene ID
##         "map_id": "town_square",    # OR use registered map ID
##         "transition": "instant",    # Optional: "instant" or "fade" (default: instant)
##         "fade_duration": 0.5        # Optional, for fade transition
##     }
## }
##
## Priority: scene_path > scene_id > map_id
class_name SetBackdropExecutor
extends CinematicCommandExecutor


## Track if this executor was interrupted during async operation
var _interrupted: bool = false
## Reference to manager for async completion
var _active_manager: Node = null
## Reference to instantiated backdrop for cleanup
var _backdrop_instance: Node = null


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})

	# Get scene path from various sources (priority order)
	var scene_path: String = _resolve_scene_path(params)

	if scene_path.is_empty():
		push_error("SetBackdropExecutor: No valid scene_path, scene_id, or map_id provided")
		return true  # Complete immediately on error

	if not ResourceLoader.exists(scene_path):
		push_error("SetBackdropExecutor: Scene does not exist: %s" % scene_path)
		return true

	var transition: String = params.get("transition", "instant")
	var fade_duration: float = params.get("fade_duration", 0.5)

	# Reset state
	_interrupted = false
	_active_manager = manager

	# Load and add backdrop
	if transition == "fade":
		_load_backdrop_with_fade(scene_path, fade_duration)
		return false  # Async
	else:
		_load_backdrop_instant(scene_path)
		return true  # Sync


## Called when the cinematic is interrupted (e.g., skipped by player)
func interrupt() -> void:
	_interrupted = true
	_active_manager = null
	# Note: backdrop remains in scene - cleanup happens when cinematic stage is freed


## Resolve scene path from params (priority: scene_path > scene_id > map_id)
func _resolve_scene_path(params: Dictionary) -> String:
	# Direct scene path takes priority
	var scene_path: String = params.get("scene_path", "")
	if not scene_path.is_empty():
		return scene_path

	# Try scene_id (registered scene)
	var scene_id: String = params.get("scene_id", "")
	if not scene_id.is_empty() and ModLoader and ModLoader.registry:
		scene_path = ModLoader.registry.get_scene_path(scene_id)
		if not scene_path.is_empty():
			return scene_path

	# Try map_id (get scene from map metadata)
	var map_id: String = params.get("map_id", "")
	if not map_id.is_empty() and ModLoader and ModLoader.registry:
		var map_data: MapMetadata = ModLoader.registry.get_resource("map", map_id) as MapMetadata
		if map_data and "scene_path" in map_data:
			return map_data.scene_path

	return ""


## Load backdrop instantly (no transition)
func _load_backdrop_instant(scene_path: String) -> void:
	var scene: PackedScene = load(scene_path)
	if not scene:
		push_error("SetBackdropExecutor: Failed to load scene: %s" % scene_path)
		return

	_instantiate_backdrop(scene)


## Load backdrop with fade transition
func _load_backdrop_with_fade(scene_path: String, fade_duration: float) -> void:
	# Fade to black first
	if SceneManager and not SceneManager.is_faded_to_black:
		await SceneManager.fade_to_black(fade_duration)

		if _interrupted:
			return

	# Load and instantiate
	var scene: PackedScene = load(scene_path)
	if not scene:
		push_error("SetBackdropExecutor: Failed to load scene: %s" % scene_path)
		_complete()
		return

	_instantiate_backdrop(scene)

	# Fade back in
	if SceneManager:
		await SceneManager.fade_from_black(fade_duration)

		if _interrupted:
			return

	_complete()


## Instantiate the backdrop scene and add to cinematic stage
func _instantiate_backdrop(scene: PackedScene) -> void:
	# Signal that we're loading a backdrop (map_template checks this)
	if CinematicsManager:
		CinematicsManager._loading_backdrop = true

	# Instantiate the scene
	_backdrop_instance = scene.instantiate()

	# Clear the flag after instantiation (before _ready runs on children)
	# Note: _ready runs during add_child, so flag must be set before that
	# The flag is checked in map_template._ready()

	# Find the cinematic stage (current scene or parent with cinematic stage script)
	var stage: Node = _find_cinematic_stage()
	if not stage:
		push_error("SetBackdropExecutor: Could not find cinematic stage to add backdrop to")
		_backdrop_instance.queue_free()
		_backdrop_instance = null
		if CinematicsManager:
			CinematicsManager._loading_backdrop = false
		return

	# Add backdrop as child, positioned behind UI elements
	# Most cinematic stages have: Background, CinematicCamera, UILayer
	# We want backdrop after Background but before UILayer
	var insert_index: int = 1  # After first child (Background)

	# Try to find the Background node to insert after
	var background: Node = stage.get_node_or_null("Background")
	if background:
		insert_index = background.get_index() + 1

	# Name the backdrop for debugging
	_backdrop_instance.name = "CinematicBackdrop"

	# Add to stage
	stage.add_child(_backdrop_instance)
	stage.move_child(_backdrop_instance, insert_index)

	# Clear the loading flag
	if CinematicsManager:
		CinematicsManager._loading_backdrop = false

	# Hide the original Background ColorRect since we have a real backdrop now
	if background and background is ColorRect:
		background.hide()


## Find the cinematic stage node
func _find_cinematic_stage() -> Node:
	var scene_root: Node = Engine.get_main_loop().current_scene if Engine.get_main_loop() else null

	# Check if current scene IS the cinematic stage
	if scene_root and scene_root.name.contains("CinematicStage"):
		return scene_root

	# Check if current scene is OpeningCinematicStage specifically
	if scene_root and scene_root.name == "OpeningCinematicStage":
		return scene_root

	# Fallback: just use current scene
	return scene_root


## Signal completion to the cinematic manager
func _complete() -> void:
	if _active_manager and is_instance_valid(_active_manager):
		_active_manager._command_completed = true
	_active_manager = null


## Editor metadata for the cinematic editor
func get_editor_metadata() -> Dictionary:
	return {
		"description": "Load a scene as visual backdrop (skips gameplay initialization)",
		"category": "Scene",
		"params": {
			"scene_path": {
				"type": "string",
				"description": "Direct path to scene file",
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
				"description": "Map ID to use as backdrop",
				"required": false
			},
			"transition": {
				"type": "enum",
				"description": "How to transition to the backdrop",
				"options": ["instant", "fade"],
				"default": "instant"
			},
			"fade_duration": {
				"type": "float",
				"description": "Duration of fade transition in seconds",
				"default": 0.5,
				"min": 0.1,
				"max": 3.0
			}
		}
	}
