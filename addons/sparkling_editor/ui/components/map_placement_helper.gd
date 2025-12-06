@tool
class_name MapPlacementHelper
extends RefCounted

## Helper class for placing NPCs (and other entities) onto map scenes
## Handles both open and closed scene modification via EditorInterface

signal placement_succeeded(map_path: String, node_name: String, position: Vector2)
signal placement_failed(error_message: String)


## Add an NPC node to a scene file
## Returns true on success, false on failure
func place_npc_on_map(
	scene_path: String,
	npc_resource_path: String,
	node_name: String,
	grid_position: Vector2i,
	tile_size: int = 32
) -> bool:
	if not Engine.is_editor_hint():
		push_error("MapPlacementHelper: Can only be used in the editor")
		placement_failed.emit("Can only place NPCs in the editor")
		return false

	if scene_path.is_empty() or not FileAccess.file_exists(scene_path):
		push_error("MapPlacementHelper: Invalid scene path: %s" % scene_path)
		placement_failed.emit("Invalid scene path")
		return false

	if npc_resource_path.is_empty() or not ResourceLoader.exists(npc_resource_path):
		push_error("MapPlacementHelper: Invalid NPC resource path: %s" % npc_resource_path)
		placement_failed.emit("Invalid NPC resource path")
		return false

	# Convert grid coords to pixel position
	var pixel_pos: Vector2 = Vector2(grid_position.x * tile_size, grid_position.y * tile_size)

	# Check if this scene is currently being edited
	var edited_root: Node = EditorInterface.get_edited_scene_root()
	var scene_is_open: bool = edited_root != null and edited_root.scene_file_path == scene_path

	var success: bool
	if scene_is_open:
		success = _add_npc_to_open_scene(edited_root, npc_resource_path, node_name, pixel_pos)
	else:
		success = _add_npc_to_closed_scene(scene_path, npc_resource_path, node_name, pixel_pos)

	if success:
		placement_succeeded.emit(scene_path, node_name, pixel_pos)
	else:
		placement_failed.emit("Failed to modify scene")

	return success


## Add NPC to a scene that's currently open in the editor
func _add_npc_to_open_scene(
	scene_root: Node,
	npc_resource_path: String,
	node_name: String,
	position: Vector2
) -> bool:
	# Find or create NPCs container
	var npcs_container: Node2D = scene_root.get_node_or_null("NPCs") as Node2D
	if not npcs_container:
		npcs_container = Node2D.new()
		npcs_container.name = "NPCs"
		scene_root.add_child(npcs_container)
		npcs_container.owner = scene_root

	# Generate unique node name if needed
	var final_node_name: String = _make_unique_node_name(npcs_container, node_name)

	# Load the NPC script and data
	var npc_script: GDScript = load("res://core/components/npc_node.gd") as GDScript
	if not npc_script:
		push_error("MapPlacementHelper: Failed to load npc_node.gd script")
		return false

	var npc_data: Resource = load(npc_resource_path)
	if not npc_data:
		push_error("MapPlacementHelper: Failed to load NPC data: %s" % npc_resource_path)
		return false

	# Create the NPC node
	var npc_node: Area2D = Area2D.new()
	npc_node.name = final_node_name
	npc_node.position = position
	npc_node.set_script(npc_script)
	npc_node.set("npc_data", npc_data)

	# Add to scene tree with proper ownership
	npcs_container.add_child(npc_node)
	npc_node.owner = scene_root

	# Mark the scene as modified so user knows to save
	EditorInterface.mark_scene_as_unsaved()

	print("MapPlacementHelper: Added %s to open scene (remember to save!)" % final_node_name)
	return true


## Add NPC to a scene that's not currently open
func _add_npc_to_closed_scene(
	scene_path: String,
	npc_resource_path: String,
	node_name: String,
	position: Vector2
) -> bool:
	# Load the scene as a PackedScene
	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if not packed_scene:
		push_error("MapPlacementHelper: Failed to load scene: %s" % scene_path)
		return false

	# Instantiate the scene to modify it
	var scene_root: Node = packed_scene.instantiate()
	if not scene_root:
		push_error("MapPlacementHelper: Failed to instantiate scene")
		return false

	# Find or create NPCs container
	var npcs_container: Node2D = scene_root.get_node_or_null("NPCs") as Node2D
	if not npcs_container:
		npcs_container = Node2D.new()
		npcs_container.name = "NPCs"
		scene_root.add_child(npcs_container)
		npcs_container.owner = scene_root

	# Generate unique node name if needed
	var final_node_name: String = _make_unique_node_name(npcs_container, node_name)

	# Load the NPC script and data
	var npc_script: GDScript = load("res://core/components/npc_node.gd") as GDScript
	if not npc_script:
		push_error("MapPlacementHelper: Failed to load npc_node.gd script")
		scene_root.queue_free()
		return false

	var npc_data: Resource = load(npc_resource_path)
	if not npc_data:
		push_error("MapPlacementHelper: Failed to load NPC data: %s" % npc_resource_path)
		scene_root.queue_free()
		return false

	# Create the NPC node
	var npc_node: Area2D = Area2D.new()
	npc_node.name = final_node_name
	npc_node.position = position
	npc_node.set_script(npc_script)
	npc_node.set("npc_data", npc_data)

	# Add to scene tree with proper ownership
	npcs_container.add_child(npc_node)
	npc_node.owner = scene_root

	# Pack the modified scene back
	var new_packed: PackedScene = PackedScene.new()
	var pack_result: Error = new_packed.pack(scene_root)
	if pack_result != OK:
		push_error("MapPlacementHelper: Failed to pack scene: %s" % error_string(pack_result))
		scene_root.queue_free()
		return false

	# Save the modified scene
	var save_result: Error = ResourceSaver.save(new_packed, scene_path)
	scene_root.queue_free()

	if save_result != OK:
		push_error("MapPlacementHelper: Failed to save scene: %s" % error_string(save_result))
		return false

	# Notify the editor to refresh
	EditorInterface.get_resource_filesystem().scan()

	return true


## Generate a unique node name by appending numbers if needed
func _make_unique_node_name(parent: Node, base_name: String) -> String:
	if not parent.has_node(base_name):
		return base_name

	var counter: int = 2
	while parent.has_node("%s%d" % [base_name, counter]):
		counter += 1
	return "%s%d" % [base_name, counter]


## Scan a mod's maps directory and return available map scenes
## Returns Array of {display_name: String, path: String}
static func get_available_maps(mod_path: String) -> Array[Dictionary]:
	var maps: Array[Dictionary] = []
	var maps_path: String = mod_path.path_join("maps/")

	if not DirAccess.dir_exists_absolute(maps_path):
		return maps

	var dir: DirAccess = DirAccess.open(maps_path)
	if not dir:
		return maps

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn"):
			maps.append({
				"display_name": file_name.get_basename(),
				"path": maps_path.path_join(file_name)
			})
		file_name = dir.get_next()

	dir.list_dir_end()
	return maps


## Check if a scene is currently open in the editor
static func is_scene_open(scene_path: String) -> bool:
	var edited_root: Node = EditorInterface.get_edited_scene_root()
	return edited_root != null and edited_root.scene_file_path == scene_path
