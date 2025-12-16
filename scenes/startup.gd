extends Node

## Game Startup Coordinator
##
## This is the main_scene entry point. It coordinates the startup flow:
## 1. Wait for autoloads to initialize
## 2. Load and play the opening cinematic (from mod or core)
## 3. Wait for cinematic to complete
## 4. Transition to main menu
##
## IMPORTANT: Cinematic scenes are NOT responsible for navigation.
## This coordinator handles all scene transitions, ensuring consistent
## behavior regardless of which mod provides the opening cinematic.

const SCENE_ID: String = "opening_cinematic"
const CORE_OPENING_CINEMATIC: String = "res://scenes/cinematics/opening_cinematic_stage.tscn"

var _cinematic_scene: Node = null


func _ready() -> void:
	# Wait for autoloads to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# Connect to cinematic completion BEFORE loading the scene
	# This ensures we catch the signal even if cinematic is very short
	CinematicsManager.cinematic_ended.connect(_on_cinematic_ended, CONNECT_ONE_SHOT)

	# Load and start the opening cinematic
	_load_opening_cinematic()


## Load the opening cinematic scene (from mod or core fallback)
func _load_opening_cinematic() -> void:
	var cinematic_scene_path: String = _get_opening_cinematic_path()

	# Load the scene
	var scene_resource: PackedScene = load(cinematic_scene_path) as PackedScene
	if not scene_resource:
		push_error("Startup: Failed to load opening cinematic scene: %s" % cinematic_scene_path)
		_skip_to_main_menu()
		return

	# Instantiate and add as child
	_cinematic_scene = scene_resource.instantiate()
	add_child(_cinematic_scene)
	print("Startup: Loaded opening cinematic from: %s" % cinematic_scene_path)


## Get the path to the opening cinematic scene (mod or core)
func _get_opening_cinematic_path() -> String:
	# Check if a mod provides a custom opening_cinematic scene
	if ModLoader and ModLoader.registry:
		var mod_scene_path: String = ModLoader.registry.get_scene_path(SCENE_ID)
		if not mod_scene_path.is_empty() and ResourceLoader.exists(mod_scene_path):
			print("Startup: Using mod opening cinematic: %s" % mod_scene_path)
			return mod_scene_path

	# Fall back to core scene
	print("Startup: Using core opening cinematic")
	return CORE_OPENING_CINEMATIC


## Handle cinematic completion - transition to main menu
func _on_cinematic_ended(_cinematic_id: String) -> void:
	print("Startup: Cinematic complete, transitioning to main menu...")

	# Wait for any pending fade to complete
	while SceneManager.is_fading:
		await get_tree().process_frame

	# Ensure screen is black before transition
	if not SceneManager.is_faded_to_black:
		await SceneManager.fade_to_black(0.5)

	# Brief pause
	await get_tree().create_timer(0.3).timeout

	# Transition to main menu
	SceneManager.goto_main_menu(true)


## Skip directly to main menu (error recovery)
func _skip_to_main_menu() -> void:
	push_warning("Startup: Skipping cinematic, going directly to main menu")
	# Disconnect signal if connected (prevent double-call)
	if CinematicsManager.cinematic_ended.is_connected(_on_cinematic_ended):
		CinematicsManager.cinematic_ended.disconnect(_on_cinematic_ended)
	await get_tree().process_frame
	SceneManager.goto_main_menu(false)
