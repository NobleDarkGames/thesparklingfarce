extends Node2D

## Opening Cinematic Stage
## Sets up the temple scene and plays the opening cinematic sequence.
## This scene plays before the main menu, SF2-style.

const CinematicData: GDScript = preload("res://core/resources/cinematic_data.gd")
const CinematicActor: GDScript = preload("res://core/components/cinematic_actor.gd")

@onready var spade_actor: Node2D = $SpadeActor
@onready var henchman_actor: Node2D = $HenchmanActor
@onready var camera: Camera2D = $CinematicCamera
@onready var prismatic_shard: ColorRect = $Pedestal/PrismaticShard
@onready var dialog_box: Control = $UILayer/DialogBox

var cinematic_data: CinematicData = null
var _actors_registered: bool = false


func _ready() -> void:
	# Hide initially for fade-in effect
	modulate.a = 1.0

	# Wait for autoloads to be ready
	await get_tree().process_frame
	await get_tree().process_frame

	# Register camera with CinematicsManager
	if CinematicsManager:
		CinematicsManager.register_camera(camera)

	# Register the dialog box with DialogManager
	if DialogManager and dialog_box:
		DialogManager.dialog_box = dialog_box
		dialog_box.hide()

	# Register actors with CinematicsManager
	_register_actors()

	# Build and start the cinematic
	_build_cinematic()
	_start_cinematic()


func _register_actors() -> void:
	# Get CinematicActor components and register them
	var spade_cinematic: CinematicActor = spade_actor.get_node_or_null("CinematicActor")
	var henchman_cinematic: CinematicActor = henchman_actor.get_node_or_null("CinematicActor")

	if spade_cinematic:
		CinematicsManager.register_actor(spade_cinematic)
	else:
		push_warning("OpeningCinematic: Spade CinematicActor not found")

	if henchman_cinematic:
		CinematicsManager.register_actor(henchman_cinematic)
	else:
		push_warning("OpeningCinematic: Henchman CinematicActor not found")

	_actors_registered = true
	print("OpeningCinematic: Registered actors 'spade' and 'henchman'")


func _build_cinematic() -> void:
	cinematic_data = CinematicData.new()
	cinematic_data.cinematic_id = "opening_cinematic"
	cinematic_data.cinematic_name = "Opening - The Pilfered Prism"
	cinematic_data.disable_player_input = true
	cinematic_data.can_skip = true
	cinematic_data.fade_in_duration = 1.0
	cinematic_data.fade_out_duration = 1.0

	# Phase 1: Fade in from black
	cinematic_data.add_fade_screen("in", 2.0)
	cinematic_data.add_wait(0.5)

	# Phase 2: First dialog exchange (fear of statues)
	cinematic_data.add_show_dialog("opening_dialog_01")
	cinematic_data.add_wait(0.3)

	# Phase 2b: Second dialog exchange (the warning)
	cinematic_data.add_show_dialog("opening_dialog_02")
	cinematic_data.add_wait(0.3)

	# Phase 3: Spade turns to face the prize
	cinematic_data.add_set_facing("spade", "up")
	cinematic_data.add_wait(1.0)

	# Phase 4: Final dialog (grab the gem, consequences begin)
	cinematic_data.add_show_dialog("opening_dialog_03")

	# Phase 5: Camera shake - the temple reacts!
	cinematic_data.commands.append({
		"type": "camera_shake",
		"params": {
			"intensity": 6.0,
			"duration": 1.5,
			"frequency": 20.0
		}
	})
	cinematic_data.add_wait(0.5)

	# Phase 6: Fade to black
	cinematic_data.add_fade_screen("out", 1.5)

	print("OpeningCinematic: Built sequence with %d commands" % cinematic_data.commands.size())


func _start_cinematic() -> void:
	# Connect to cinematic_ended to transition after
	CinematicsManager.cinematic_ended.connect(_on_cinematic_ended, CONNECT_ONE_SHOT)

	# Play the cinematic
	var success: bool = CinematicsManager.play_cinematic_from_resource(cinematic_data)
	if not success:
		push_error("OpeningCinematic: Failed to start cinematic!")
		_on_cinematic_ended("")


func _on_cinematic_ended(_cinematic_id: String) -> void:
	print("OpeningCinematic: Sequence complete, transitioning to main menu...")

	# Clean up actors
	if _actors_registered:
		CinematicsManager.unregister_actor("spade")
		CinematicsManager.unregister_actor("henchman")

	# Brief pause before transition
	await get_tree().create_timer(0.5).timeout

	# Transition to main menu
	SceneManager.goto_main_menu(false)  # No fade since we just faded out


func _unhandled_input(event: InputEvent) -> void:
	# Allow skipping the cinematic with cancel button
	if event.is_action_pressed("sf_cancel") or event.is_action_pressed("ui_cancel"):
		if CinematicsManager.is_cinematic_active() and cinematic_data and cinematic_data.can_skip:
			CinematicsManager.skip_cinematic()
			get_viewport().set_input_as_handled()
