extends Node2D

## Opening Cinematic Stage (Sandbox Version)
##
## Plays the opening cinematic with custom actors (Spade, Henchman, Artifact).
## This scene is ONLY responsible for playing the cinematic - it does NOT
## handle navigation to the main menu. The startup coordinator listens
## for cinematic_ended and handles all scene transitions.
##
## This scene is registered in mod.json as "opening_cinematic" scene, which
## the startup coordinator loads instead of the core version. This allows
## custom actors to be on stage for the cinematic commands.
##
## CinematicActors auto-register in _ready() and auto-unregister in _exit_tree().

## The cinematic ID to play (looked up from ModRegistry)
const CINEMATIC_ID: String = "opening_cinematic"

@onready var camera: Camera2D = $CinematicCamera
@onready var dialog_box: Control = $UILayer/DialogBox


func _ready() -> void:
	# Wait for autoloads and actor auto-registration to complete
	await get_tree().process_frame
	await get_tree().process_frame

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
	# Play the cinematic from ModRegistry
	var success: bool = CinematicsManager.play_cinematic(CINEMATIC_ID)
	if not success:
		push_error("OpeningCinematic: Failed to play cinematic '%s'" % CINEMATIC_ID)
		# Signal completion so startup coordinator can proceed
		CinematicsManager.cinematic_ended.emit("")


func _unhandled_input(event: InputEvent) -> void:
	# Allow skipping the cinematic with cancel button
	if event.is_action_pressed("sf_cancel") or event.is_action_pressed("ui_cancel"):
		if CinematicsManager.is_cinematic_active():
			CinematicsManager.skip_cinematic()
			get_viewport().set_input_as_handled()
