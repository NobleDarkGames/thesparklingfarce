extends Node2D

## Opening Cinematic Stage
## Sets up the temple scene and plays the opening cinematic sequence.
## This scene plays before the main menu, SF2-style.
##
## The cinematic sequence is loaded from ModRegistry ("game_opening"),
## allowing mods to completely replace the opening cinematic by:
## 1. Providing their own game_opening.json cinematic data
## 2. Optionally providing their own opening_cinematic scene
##
## CinematicActors auto-register in _ready() and auto-unregister in _exit_tree().

## The cinematic ID to play (looked up from ModRegistry)
const CINEMATIC_ID: String = "game_opening"

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
	# Connect to cinematic_ended to transition after
	CinematicsManager.cinematic_ended.connect(_on_cinematic_ended, CONNECT_ONE_SHOT)

	# Play the cinematic from ModRegistry
	var success: bool = CinematicsManager.play_cinematic(CINEMATIC_ID)
	if not success:
		push_error("OpeningCinematic: Failed to play cinematic '%s'" % CINEMATIC_ID)
		_on_cinematic_ended("")


func _on_cinematic_ended(_cinematic_id: String) -> void:
	print("OpeningCinematic: Sequence complete, transitioning to main menu...")

	# Wait for any pending fade to complete before transitioning
	# This prevents race conditions where the cinematic's fade_out finishes
	# after we've already started the scene transition
	while SceneManager.is_fading:
		await get_tree().process_frame

	# Ensure screen is black before transition (cinematic should have faded out)
	if not SceneManager.is_faded_to_black:
		await SceneManager.fade_to_black(0.5)

	# Brief pause before transition
	await get_tree().create_timer(0.3).timeout

	# Transition to main menu - SceneManager will fade FROM black
	SceneManager.goto_main_menu(true)


func _unhandled_input(event: InputEvent) -> void:
	# Allow skipping the cinematic with cancel button
	if event.is_action_pressed("sf_cancel") or event.is_action_pressed("ui_cancel"):
		if CinematicsManager.is_cinematic_active():
			CinematicsManager.skip_cinematic()
			get_viewport().set_input_as_handled()
