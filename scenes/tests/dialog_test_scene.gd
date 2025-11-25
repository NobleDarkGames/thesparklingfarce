extends Node2D

## Dialog System Test Scene
## Tests basic dialog functionality

@onready var dialog_box: Control = $CanvasLayer/DialogBox
@onready var test_label: Label = $CanvasLayer/TestLabel


func _ready() -> void:
	# Wait for ModLoader to finish loading
	await get_tree().process_frame

	test_label.text = "Dialog Test Scene - Phase 2 Polish\nPress ENTER to start\nPress 1 for basic test, 2 for Phase 2 test"

	# Connect to dialog signals for testing
	DialogManager.dialog_started.connect(_on_dialog_started)
	DialogManager.dialog_ended.connect(_on_dialog_ended)


func _input(event: InputEvent) -> void:
	# Only respond if no dialog is active
	if DialogManager.is_dialog_active():
		return

	if event.is_action_pressed("sf_confirm"):
		_start_test_dialog("test_dialog")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_text_submit"):
		_start_test_dialog("phase2_test_dialog")
		get_viewport().set_input_as_handled()


func _start_test_dialog(dialog_id: String = "phase2_test_dialog") -> void:
	test_label.text = "Starting dialog: " + dialog_id

	# Try to start the specified dialog
	var success: bool = DialogManager.start_dialog(dialog_id)

	if not success:
		test_label.text = "ERROR: Failed to start dialog!\nCheck console for details."


func _on_dialog_started(dialogue_data: DialogueData) -> void:
	test_label.text = "Dialog active: " + dialogue_data.dialogue_title
	print("Dialog started: ", dialogue_data.dialogue_id)


func _on_dialog_ended(dialogue_data: DialogueData) -> void:
	test_label.text = "Dialog ended: " + dialogue_data.dialogue_title + "\nPress ENTER to restart"
	print("Dialog ended: ", dialogue_data.dialogue_id)
