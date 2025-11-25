extends Node2D

## Dialog System Test Scene
## Tests basic dialog functionality

@onready var dialog_box: Control = $CanvasLayer/DialogBox
@onready var test_label: Label = $CanvasLayer/TestLabel


func _ready() -> void:
	# Wait for ModLoader to finish loading
	await get_tree().process_frame

	test_label.text = "Dialog Test Scene - Phase 3 Choices\n1: Basic | 2: Phase 2 Polish | 3: YES/NO Choice | 4: 3-Way Choice"

	# Connect to dialog signals for testing
	DialogManager.dialog_started.connect(_on_dialog_started)
	DialogManager.dialog_ended.connect(_on_dialog_ended)
	DialogManager.choices_ready.connect(_on_choices_ready)


func _input(event: InputEvent) -> void:
	# Only respond if no dialog is active
	if DialogManager.is_dialog_active():
		return

	# Test dialog selection with number keys
	if event is InputEventKey and event.pressed:
		var key_event: InputEventKey = event as InputEventKey
		match key_event.keycode:
			KEY_1:
				_start_test_dialog("test_dialog")
			KEY_2:
				_start_test_dialog("phase2_test_dialog")
			KEY_3:
				_start_test_dialog("branch_test_start")
			KEY_4:
				_start_test_dialog("branch_test_3way")
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
	test_label.text = "Dialog ended: " + dialogue_data.dialogue_title + "\nPress 1-4 to test"
	print("Dialog ended: ", dialogue_data.dialogue_id)


func _on_choices_ready(choices: Array[Dictionary]) -> void:
	test_label.text = "Choices displayed! Use arrow keys or mouse to select."
	print("Choices ready: ", choices.size(), " options")
