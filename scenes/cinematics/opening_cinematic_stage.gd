extends Node2D

## Opening Cinematic Stage (Core Version)
##
## Plays the opening cinematic when loaded by the startup coordinator.
## This scene is ONLY responsible for playing the cinematic - it does NOT
## handle navigation to the main menu. The startup coordinator listens
## for cinematic_ended and handles all scene transitions.
##
## Cinematic Data Resolution Order:
## 1. Mods with higher load_priority (opening_cinematic.json in data/cinematics/)
## 2. Mods with lower load_priority
## 3. _base_game (priority 0)
## 4. Core fallback: res://core/defaults/cinematics/opening_cinematic.json
##
## IMPORTANT: This scene has ZERO dependencies on anything in mods/.
## It uses only core systems and res://scenes/ui/dialog_box.tscn.

const CINEMATIC_ID: String = "opening_cinematic"
const CORE_FALLBACK_CINEMATIC: String = "res://core/defaults/cinematics/opening_cinematic.json"

## Preload CinematicLoader for fallback loading
const CinematicLoader: GDScript = preload("res://core/systems/cinematic_loader.gd")

@onready var camera: Camera2D = $CinematicCamera
@onready var dialog_box: Control = $UILayer/DialogBox


func _ready() -> void:
	# Register camera with CinematicsManager
	if CinematicsManager:
		CinematicsManager.register_camera(camera)

	# Register the dialog box with DialogManager
	if DialogManager and dialog_box:
		DialogManager.dialog_box = dialog_box
		dialog_box.hide()

	# Start the cinematic
	_start_cinematic()


func _start_cinematic() -> void:
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
		# Signal completion so startup coordinator can proceed
		CinematicsManager.cinematic_ended.emit("")


func _unhandled_input(event: InputEvent) -> void:
	# Allow skipping the cinematic with cancel button
	if event.is_action_pressed("sf_cancel") or event.is_action_pressed("ui_cancel"):
		if CinematicsManager.is_cinematic_active():
			CinematicsManager.skip_cinematic()
			get_viewport().set_input_as_handled()
