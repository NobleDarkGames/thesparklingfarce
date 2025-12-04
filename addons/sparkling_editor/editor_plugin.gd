@tool
extends EditorPlugin

## Main plugin for The Sparkling Farce content editor

const MainPanelScene: PackedScene = preload("res://addons/sparkling_editor/ui/main_panel.tscn")
const EditorEventBus: GDScript = preload("res://addons/sparkling_editor/editor_event_bus.gd")

var main_panel: Control
var event_bus: Node


func _enter_tree() -> void:
	# Plugin initialization - debug logging removed for production

	# Create and register the EditorEventBus as an autoload
	event_bus = EditorEventBus.new()
	event_bus.name = "EditorEventBus"
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
