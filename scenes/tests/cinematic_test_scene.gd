extends Node2D

## Cinematic System Test Scene
## Tests basic cinematic functionality with character movement

const CinematicActor: GDScript = preload("res://core/components/cinematic_actor.gd")

@onready var test_label: Label = $CanvasLayer/TestLabel
@onready var hero: CharacterBody2D = $Hero
@onready var cinematic_actor: Node = $Hero/CinematicActor


func _ready() -> void:
	# Wait for ModLoader to finish loading
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for autoloads

	test_label.text = "Cinematic Test Scene - Phase 1\nPress 1: Test Movement Cinematic\nPress ESC: Skip Cinematic"

	# Connect to cinematic signals for testing
	CinematicsManager.cinematic_started.connect(_on_cinematic_started)
	CinematicsManager.cinematic_ended.connect(_on_cinematic_ended)
	CinematicsManager.command_executed.connect(_on_command_executed)
	CinematicsManager.cinematic_skipped.connect(_on_cinematic_skipped)

	# Register the hero actor with CinematicsManager
	if cinematic_actor:
		CinematicsManager.register_actor(cinematic_actor)
		print("Hero actor registered with ID: ", cinematic_actor.actor_id)
	else:
		push_error("CinematicActor component not found on Hero!")


func _input(event: InputEvent) -> void:
	# Only respond if no cinematic is active
	if CinematicsManager.is_cinematic_active():
		# Allow skipping with ESC
		if event.is_action_pressed("ui_cancel"):
			CinematicsManager.skip_cinematic()
			get_viewport().set_input_as_handled()
		return

	# Test cinematic selection with number keys
	if event is InputEventKey and event.pressed:
		var key_event: InputEventKey = event as InputEventKey
		match key_event.keycode:
			KEY_1:
				_start_test_cinematic("test_movement")
		get_viewport().set_input_as_handled()


func _start_test_cinematic(cinematic_id: String = "test_movement") -> void:
	test_label.text = "Starting cinematic: " + cinematic_id

	# Try to start the specified cinematic
	var success: bool = CinematicsManager.play_cinematic(cinematic_id)

	if not success:
		test_label.text = "ERROR: Failed to start cinematic!\nCheck console for details."


func _on_cinematic_started(cinematic_id: String) -> void:
	test_label.text = "Cinematic active: " + cinematic_id + "\nPress ESC to skip"
	print("Cinematic started: ", cinematic_id)


func _on_cinematic_ended(cinematic_id: String) -> void:
	test_label.text = "Cinematic ended: " + cinematic_id + "\nPress 1 to test again"
	print("Cinematic ended: ", cinematic_id)


func _on_command_executed(command_type: String, command_index: int) -> void:
	print("Command executed: [%d] %s" % [command_index, command_type])


func _on_cinematic_skipped() -> void:
	test_label.text = "Cinematic skipped!\nPress 1 to test again"
	print("Cinematic skipped!")
