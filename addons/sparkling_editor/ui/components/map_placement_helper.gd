@tool
class_name MapPlacementHelper
extends RefCounted

## Helper class for placing NPCs, Interactables, and other entities onto map scenes
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
	var scene_is_open: bool = is_instance_valid(edited_root) and edited_root.scene_file_path == scene_path

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


## Add an Interactable node to a scene file
## Returns true on success, false on failure
func place_interactable_on_map(
	scene_path: String,
	interactable_resource_path: String,
	node_name: String,
	grid_position: Vector2i,
	tile_size: int = 32
) -> bool:
	if not Engine.is_editor_hint():
		push_error("MapPlacementHelper: Can only be used in the editor")
		placement_failed.emit("Can only place interactables in the editor")
		return false

	if scene_path.is_empty() or not FileAccess.file_exists(scene_path):
		push_error("MapPlacementHelper: Invalid scene path: %s" % scene_path)
		placement_failed.emit("Invalid scene path")
		return false

	if interactable_resource_path.is_empty() or not ResourceLoader.exists(interactable_resource_path):
		push_error("MapPlacementHelper: Invalid interactable resource path: %s" % interactable_resource_path)
		placement_failed.emit("Invalid interactable resource path")
		return false

	# Convert grid coords to pixel position (center of tile)
	var pixel_pos: Vector2 = Vector2(
		grid_position.x * tile_size + tile_size / 2.0,
		grid_position.y * tile_size + tile_size / 2.0
	)

	# Check if this scene is currently being edited
	var edited_root: Node = EditorInterface.get_edited_scene_root()
	var scene_is_open: bool = is_instance_valid(edited_root) and edited_root.scene_file_path == scene_path

	var success: bool
	if scene_is_open:
		success = _add_interactable_to_open_scene(edited_root, interactable_resource_path, node_name, pixel_pos)
	else:
		success = _add_interactable_to_closed_scene(scene_path, interactable_resource_path, node_name, pixel_pos)

	if success:
		placement_succeeded.emit(scene_path, node_name, pixel_pos)
	else:
		placement_failed.emit("Failed to modify scene")

	return success


## Add an entity to a scene that's currently open in the editor
func _add_entity_to_open_scene(
	scene_root: Node,
	container_name: String,
	script_path: String,
	data_path: String,
	data_property_name: String,
	node_name: String,
	position: Vector2
) -> bool:
	# Find or create container
	var container: Node2D = scene_root.get_node_or_null(container_name) as Node2D
	if not container:
		container = Node2D.new()
		container.name = container_name
		scene_root.add_child(container)
		container.owner = scene_root

	# Generate unique node name if needed
	var final_node_name: String = _make_unique_node_name(container, node_name)

	# Load the script and data
	# Use CACHE_MODE_REUSE to get the canonical resource instance with proper resource_path
	# This ensures the resource is saved as an external reference, not embedded
	var entity_script: GDScript = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_REUSE) as GDScript
	if not entity_script:
		push_error("MapPlacementHelper: Failed to load script: %s" % script_path)
		return false

	var entity_data: Resource = ResourceLoader.load(data_path, "", ResourceLoader.CACHE_MODE_REUSE)
	if not entity_data:
		push_error("MapPlacementHelper: Failed to load data: %s" % data_path)
		return false

	# CRITICAL: Ensure resource is NOT local to scene (prevents embedding as SubResource)
	# This keeps it as an ExtResource reference to the external .tres file
	entity_data.resource_local_to_scene = false

	# Create the entity node
	var entity_node: Area2D = Area2D.new()
	entity_node.name = final_node_name
	entity_node.position = position
	entity_node.set_script(entity_script)
	entity_node.set(data_property_name, entity_data)

	# Add to scene tree with proper ownership
	container.add_child(entity_node)
	entity_node.owner = scene_root

	# Mark the scene as modified so user knows to save
	EditorInterface.mark_scene_as_unsaved()

	return true


## Add an entity to a scene that's not currently open (uses PackedScene API)
func _add_entity_to_closed_scene(
	scene_path: String,
	container_name: String,
	script_path: String,
	data_path: String,
	data_property_name: String,
	node_name: String,
	position: Vector2
) -> bool:
	# Load the scene as a PackedScene
	var loaded: Resource = load(scene_path)
	var packed_scene: PackedScene = loaded if loaded is PackedScene else null
	if not packed_scene:
		push_error("MapPlacementHelper: Failed to load scene: %s" % scene_path)
		return false

	# Instantiate the scene to modify it
	var scene_root: Node = packed_scene.instantiate()
	if not scene_root:
		push_error("MapPlacementHelper: Failed to instantiate scene")
		return false

	# Find or create container
	var container: Node2D = scene_root.get_node_or_null(container_name) as Node2D
	if not container:
		container = Node2D.new()
		container.name = container_name
		scene_root.add_child(container)
		container.owner = scene_root

	# Generate unique node name if needed
	var final_node_name: String = _make_unique_node_name(container, node_name)

	# Load the script and data
	# Use CACHE_MODE_REUSE to get the canonical resource instance with proper resource_path
	# This ensures the resource is saved as an external reference, not embedded
	var entity_script: GDScript = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_REUSE) as GDScript
	if not entity_script:
		push_error("MapPlacementHelper: Failed to load script: %s" % script_path)
		scene_root.queue_free()
		return false

	var entity_data: Resource = ResourceLoader.load(data_path, "", ResourceLoader.CACHE_MODE_REUSE)
	if not entity_data:
		push_error("MapPlacementHelper: Failed to load data: %s" % data_path)
		scene_root.queue_free()
		return false

	# Create the entity node
	var entity_node: Area2D = Area2D.new()
	entity_node.name = final_node_name
	entity_node.position = position
	entity_node.set_script(entity_script)
	entity_node.set(data_property_name, entity_data)

	# Add to scene tree with proper ownership
	container.add_child(entity_node)
	entity_node.owner = scene_root

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


## Add Interactable to a scene that's currently open in the editor
func _add_interactable_to_open_scene(
	scene_root: Node,
	interactable_resource_path: String,
	node_name: String,
	position: Vector2
) -> bool:
	return _add_entity_to_open_scene(
		scene_root,
		"Interactables",
		"res://core/components/interactable_node.gd",
		interactable_resource_path,
		"interactable_data",
		node_name,
		position
	)


## Add Interactable to a scene that's not currently open
func _add_interactable_to_closed_scene(
	scene_path: String,
	interactable_resource_path: String,
	node_name: String,
	position: Vector2
) -> bool:
	return _add_entity_to_closed_scene(
		scene_path,
		"Interactables",
		"res://core/components/interactable_node.gd",
		interactable_resource_path,
		"interactable_data",
		node_name,
		position
	)


## Add NPC to a scene that's currently open in the editor
func _add_npc_to_open_scene(
	scene_root: Node,
	npc_resource_path: String,
	node_name: String,
	position: Vector2
) -> bool:
	return _add_entity_to_open_scene(
		scene_root,
		"NPCs",
		"res://core/components/npc_node.gd",
		npc_resource_path,
		"npc_data",
		node_name,
		position
	)


## Add NPC to a scene that's not currently open
func _add_npc_to_closed_scene(
	scene_path: String,
	npc_resource_path: String,
	node_name: String,
	position: Vector2
) -> bool:
	return _add_entity_to_closed_scene(
		scene_path,
		"NPCs",
		"res://core/components/npc_node.gd",
		npc_resource_path,
		"npc_data",
		node_name,
		position
	)


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
	return is_instance_valid(edited_root) and edited_root.scene_file_path == scene_path


## Validate that all NPC and Interactable data in a scene are external references (not embedded)
## Returns Array of warning strings for any embedded resources found
## Empty array means all resources are properly external
static func validate_external_resources(scene_root: Node) -> Array[String]:
	var warnings: Array[String] = []

	# Check NPCs container
	var npcs_container: Node = scene_root.get_node_or_null("NPCs")
	if npcs_container:
		for child in npcs_container.get_children():
			var npc_data: Resource = child.get("npc_data")
			if npc_data:
				var issue: String = _check_resource_embedding(npc_data, child.name, "npc_data")
				if not issue.is_empty():
					warnings.append(issue)

	# Check Interactables container
	var interactables_container: Node = scene_root.get_node_or_null("Interactables")
	if interactables_container:
		for child in interactables_container.get_children():
			var interactable_data: Resource = child.get("interactable_data")
			if interactable_data:
				var issue: String = _check_resource_embedding(interactable_data, child.name, "interactable_data")
				if not issue.is_empty():
					warnings.append(issue)

	return warnings


## Check if a specific resource is embedded and return a warning message if so
static func _check_resource_embedding(res: Resource, node_name: String, property_name: String) -> String:
	if res.resource_path.is_empty():
		return "%s.%s: EMBEDDED (no resource_path) - changes won't sync with external .tres file" % [node_name, property_name]

	if res.resource_local_to_scene:
		return "%s.%s: EMBEDDED (resource_local_to_scene=true) - changes won't sync with external .tres file" % [node_name, property_name]

	# Resource appears to be a proper external reference
	return ""


## Validate the currently edited scene and print warnings to console
## Returns true if all resources are external, false if any are embedded
static func validate_current_scene() -> bool:
	var edited_root: Node = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(edited_root):
		push_warning("MapPlacementHelper: No scene currently being edited")
		return true

	var warnings: Array[String] = validate_external_resources(edited_root)

	if warnings.is_empty():
		print("MapPlacementHelper: All NPC/Interactable resources are external references ✓")
		return true

	push_warning("MapPlacementHelper: Found %d embedded resource(s) in scene '%s':" % [warnings.size(), edited_root.scene_file_path])
	for warning in warnings:
		push_warning("  - %s" % warning)
	push_warning("To fix: Re-assign the resource from the external .tres file in the Inspector")

	return false
