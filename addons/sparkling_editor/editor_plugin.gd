@tool
extends EditorPlugin

## Main plugin for The Sparkling Farce content editor

const MainPanelScene: PackedScene = preload("res://addons/sparkling_editor/ui/main_panel.tscn")

var main_panel: Control


func _enter_tree() -> void:
	print("Sparkling Editor: Initializing...")

	# Instantiate the main panel from scene
	main_panel = MainPanelScene.instantiate()

	# Add as a bottom panel (Godot manages the sizing)
	add_control_to_bottom_panel(main_panel, "Sparkling Editor")

	print("Sparkling Editor: Ready!")


func _exit_tree() -> void:
	print("Sparkling Editor: Cleaning up...")

	# Remove the panel
	if main_panel:
		remove_control_from_bottom_panel(main_panel)
		main_panel.queue_free()
