@tool
extends EditorPlugin

## Main plugin for The Sparkling Farce content editor

const MainPanelScene: PackedScene = preload("res://addons/sparkling_editor/ui/main_panel.tscn")
const EditorEventBus = preload("res://addons/sparkling_editor/editor_event_bus.gd")
const TileSetAutoGenerator = preload("res://core/tools/tileset_auto_generator.gd")
const ResourceInspectorPlugin = preload("res://addons/sparkling_editor/inspector/resource_inspector_plugin.gd")

var main_panel: Control
var _resource_inspector_plugin: EditorInspectorPlugin


func _enter_tree() -> void:
	# Plugin initialization - debug logging removed for production

	# Register the EditorEventBus as an autoload
	# Note: Godot creates the instance from the script path - don't create our own
	add_autoload_singleton("EditorEventBus", "res://addons/sparkling_editor/editor_event_bus.gd")

	# Auto-discover and configure tileset textures
	_refresh_tilesets()

	# Instantiate the main panel from scene
	main_panel = MainPanelScene.instantiate()
	if not main_panel:
		push_error("SparklingEditor: Failed to instantiate main panel")
		return

	# Add as a bottom panel (Godot manages the sizing)
	add_control_to_bottom_panel(main_panel, "Sparkling Editor")

	# Register custom inspector plugin for mod-aware resource pickers
	_resource_inspector_plugin = ResourceInspectorPlugin.new()
	add_inspector_plugin(_resource_inspector_plugin)


## Scan for tilesets and auto-discover new textures
func _refresh_tilesets() -> void:
	var tileset_paths: Array[String] = _find_tileset_files()

	for tileset_path: String in tileset_paths:
		var tileset: TileSet = load(tileset_path) as TileSet
		if not tileset:
			continue

		var tileset_name: String = tileset_path.get_file().get_basename()

		# Run auto-discovery and auto-population
		var discovered: int = TileSetAutoGenerator.auto_discover_textures(tileset, tileset_path, tileset_name)
		var generated: int = TileSetAutoGenerator.auto_populate_tileset(tileset, tileset_name)

		# Save if any changes were made
		if discovered > 0 or generated > 0:
			var err: Error = ResourceSaver.save(tileset, tileset_path)
			if err != OK:
				push_error("SparklingEditor: Failed to save tileset '%s': %s" % [tileset_name, err])


## Find all tileset .tres files in known locations
func _find_tileset_files() -> Array[String]:
	var paths: Array[String] = []

	# Check core defaults
	_scan_directory_for_tilesets("res://core/defaults/tilesets", paths)

	# Check mod directories
	var mods_dir: DirAccess = DirAccess.open("res://mods")
	if mods_dir:
		mods_dir.list_dir_begin()
		var mod_name: String = mods_dir.get_next()
		while mod_name != "":
			if mods_dir.current_is_dir() and not mod_name.begins_with("."):
				_scan_directory_for_tilesets("res://mods/%s/data/tilesets" % mod_name, paths)
			mod_name = mods_dir.get_next()
		mods_dir.list_dir_end()

	return paths


## Scan a directory for .tres files that are TileSets
func _scan_directory_for_tilesets(dir_path: String, paths: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var filename: String = dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(".tres"):
			paths.append(dir_path.path_join(filename))
		filename = dir.get_next()
	dir.list_dir_end()


func _exit_tree() -> void:
	# Plugin cleanup

	# Remove the panel
	if main_panel:
		remove_control_from_bottom_panel(main_panel)
		main_panel.queue_free()

	# Remove the event bus autoload
	remove_autoload_singleton("EditorEventBus")

	# Remove inspector plugin
	if _resource_inspector_plugin:
		remove_inspector_plugin(_resource_inspector_plugin)
