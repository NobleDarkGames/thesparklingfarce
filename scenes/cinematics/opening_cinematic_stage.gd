extends Node2D

## Opening Cinematic Stage (Core Version)
##
## A mod-independent opening cinematic stage that can run even if the mods/
## folder is completely deleted. This scene is the fallback main_scene in
## project.godot.
##
## Scene Resolution Order:
## 1. If a mod registered an "opening_cinematic" scene, redirect to that scene
## 2. Otherwise, use this core scene
##
## Cinematic Data Resolution Order (for this core scene):
## 1. Mods with higher load_priority (opening_cinematic.json in data/cinematics/)
## 2. Mods with lower load_priority
## 3. _base_game (priority 0)
## 4. Core fallback: res://core/defaults/cinematics/opening_cinematic.json
##
## IMPORTANT: This scene has ZERO dependencies on anything in mods/.
## It uses only core systems and res://scenes/ui/dialog_box.tscn.

const SCENE_ID: String = "opening_cinematic"
const CINEMATIC_ID: String = "opening_cinematic"
const CORE_FALLBACK_CINEMATIC: String = "res://core/defaults/cinematics/opening_cinematic.json"

## Preload CinematicLoader for fallback loading
const CinematicLoader: GDScript = preload("res://core/systems/cinematic_loader.gd")

@onready var camera: Camera2D = $CinematicCamera
@onready var dialog_box: Control = $UILayer/DialogBox


func _ready() -> void:
	# Wait for autoloads to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# Check if a mod registered a custom opening_cinematic scene
	# If so, redirect to that scene instead of using this core scene
	if _should_redirect_to_mod_scene():
		return  # Scene change is already in progress

	# Register camera with CinematicsManager
	if CinematicsManager:
		CinematicsManager.register_camera(camera)

	# Register the dialog box with DialogManager
	if DialogManager and dialog_box:
		DialogManager.dialog_box = dialog_box
		dialog_box.hide()

	# Start the cinematic
	_start_cinematic()


## Check if a mod provides a custom opening_cinematic scene and redirect if so
## Returns true if redirecting (caller should return early)
func _should_redirect_to_mod_scene() -> bool:
	if not ModLoader or not ModLoader.registry:
		return false

	var mod_scene_path: String = ModLoader.registry.get_scene_path(SCENE_ID)
	if mod_scene_path.is_empty():
		return false

	# Don't redirect to ourselves (avoid infinite loop)
	if mod_scene_path == scene_file_path:
		return false

	# Verify the mod scene exists
	if not ResourceLoader.exists(mod_scene_path):
		push_warning("OpeningCinematic: Mod scene '%s' not found, using core scene" % mod_scene_path)
		return false

	# Redirect to the mod's custom scene
	print("OpeningCinematic: Redirecting to mod scene: %s" % mod_scene_path)
	get_tree().change_scene_to_file(mod_scene_path)
	return true


func _start_cinematic() -> void:
	# Connect to cinematic_ended to transition after
	CinematicsManager.cinematic_ended.connect(_on_cinematic_ended, CONNECT_ONE_SHOT)

	# Try to play from ModRegistry first
	var success: bool = false

	# Check if ModLoader is available and has loaded mods
	if ModLoader and ModLoader.registry:
		# Try to get the cinematic from the registry (respects mod priority)
		var cinematic: Resource = ModLoader.registry.get_resource("cinematic", CINEMATIC_ID)
		if cinematic:
			success = CinematicsManager.play_cinematic(CINEMATIC_ID)

	# If no mod provided the cinematic, load the core fallback directly
	if not success:
		print("OpeningCinematic: No mod cinematic found, using core fallback")
		var fallback_cinematic: Resource = CinematicLoader.load_from_json(CORE_FALLBACK_CINEMATIC)
		if fallback_cinematic:
			success = CinematicsManager.play_cinematic_from_resource(fallback_cinematic)
		else:
			push_error("OpeningCinematic: Failed to load core fallback cinematic!")

	if not success:
		push_error("OpeningCinematic: Failed to play any cinematic")
		_on_cinematic_ended("")


func _on_cinematic_ended(_cinematic_id: String) -> void:
	print("OpeningCinematic: Sequence complete, transitioning to main menu...")

	# Wait for any pending fade to complete before transitioning
	while SceneManager.is_fading:
		await get_tree().process_frame

	# Ensure screen is black before transition
	if not SceneManager.is_faded_to_black:
		await SceneManager.fade_to_black(0.5)

	# Brief pause before transition
	await get_tree().create_timer(0.3).timeout

	# Transition to main menu
	SceneManager.goto_main_menu(true)


func _unhandled_input(event: InputEvent) -> void:
	# Allow skipping the cinematic with cancel button
	if event.is_action_pressed("sf_cancel") or event.is_action_pressed("ui_cancel"):
		if CinematicsManager.is_cinematic_active():
			CinematicsManager.skip_cinematic()
			get_viewport().set_input_as_handled()
