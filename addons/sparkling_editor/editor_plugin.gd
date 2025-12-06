@tool
extends EditorPlugin

## Main plugin for The Sparkling Farce content editor

const MainPanelScene: PackedScene = preload("res://addons/sparkling_editor/ui/main_panel.tscn")
const EditorEventBus: GDScript = preload("res://addons/sparkling_editor/editor_event_bus.gd")

var main_panel: Control


func _enter_tree() -> void:
	# Plugin initialization - debug logging removed for production

	# Register the EditorEventBus as an autoload
	# Note: Godot creates the instance from the script path - don't create our own
	add_autoload_singleton("EditorEventBus", "res://addons/sparkling_editor/editor_event_bus.gd")

	# Instantiate the main panel from scene
	main_panel = MainPanelScene.instantiate()

	# Add as a bottom panel (Godot manages the sizing)
	add_control_to_bottom_panel(main_panel, "Sparkling Editor")


func _exit_tree() -> void:
	# Plugin cleanup

	# Remove the panel
	if main_panel:
		remove_control_from_bottom_panel(main_panel)
		main_panel.queue_free()

	# Remove the event bus autoload
	remove_autoload_singleton("EditorEventBus")
