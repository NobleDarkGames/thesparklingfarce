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


## Add Interactable to a scene that's currently open in the editor
func _add_interactable_to_open_scene(
	scene_root: Node,
	interactable_resource_path: String,
	node_name: String,
	position: Vector2
) -> bool:
	# Find or create Interactables container
	var interactables_container: Node2D = scene_root.get_node_or_null("Interactables") as Node2D
	if not interactables_container:
		interactables_container = Node2D.new()
		interactables_container.name = "Interactables"
		scene_root.add_child(interactables_container)
		interactables_container.owner = scene_root

	# Generate unique node name if needed
	var final_node_name: String = _make_unique_node_name(interactables_container, node_name)

	# Load the Interactable script and data
	# Use CACHE_MODE_REUSE to get the canonical resource instance with proper resource_path
	# This ensures the resource is saved as an external reference, not embedded
	var interactable_script: GDScript = ResourceLoader.load("res://core/components/interactable_node.gd", "", ResourceLoader.CACHE_MODE_REUSE) as GDScript
	if not interactable_script:
		push_error("MapPlacementHelper: Failed to load interactable_node.gd script")
		return false

	var interactable_data: Resource = ResourceLoader.load(interactable_resource_path, "", ResourceLoader.CACHE_MODE_REUSE)
	if not interactable_data:
		push_error("MapPlacementHelper: Failed to load interactable data: %s" % interactable_resource_path)
		return false

	# Create the Interactable node
	var interactable_node: Area2D = Area2D.new()
	interactable_node.name = final_node_name
	interactable_node.position = position
	interactable_node.set_script(interactable_script)
	interactable_node.set("interactable_data", interactable_data)

	# Add to scene tree with proper ownership
	interactables_container.add_child(interactable_node)
	interactable_node.owner = scene_root

	# Mark the scene as modified so user knows to save
	EditorInterface.mark_scene_as_unsaved()

	return true


## Add Interactable to a scene that's not currently open
func _add_interactable_to_closed_scene(
	scene_path: String,
	interactable_resource_path: String,
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

	# Find or create Interactables container
	var interactables_container: Node2D = scene_root.get_node_or_null("Interactables") as Node2D
	if not interactables_container:
		interactables_container = Node2D.new()
		interactables_container.name = "Interactables"
		scene_root.add_child(interactables_container)
		interactables_container.owner = scene_root

	# Generate unique node name if needed
	var final_node_name: String = _make_unique_node_name(interactables_container, node_name)

	# Load the Interactable script and data
	# Use CACHE_MODE_REUSE to get the canonical resource instance with proper resource_path
	# This ensures the resource is saved as an external reference, not embedded
	var interactable_script: GDScript = ResourceLoader.load("res://core/components/interactable_node.gd", "", ResourceLoader.CACHE_MODE_REUSE) as GDScript
	if not interactable_script:
		push_error("MapPlacementHelper: Failed to load interactable_node.gd script")
		scene_root.queue_free()
		return false

	var interactable_data: Resource = ResourceLoader.load(interactable_resource_path, "", ResourceLoader.CACHE_MODE_REUSE)
	if not interactable_data:
		push_error("MapPlacementHelper: Failed to load interactable data: %s" % interactable_resource_path)
		scene_root.queue_free()
		return false

	# Create the Interactable node
	var interactable_node: Area2D = Area2D.new()
	interactable_node.name = final_node_name
	interactable_node.position = position
	interactable_node.set_script(interactable_script)
	interactable_node.set("interactable_data", interactable_data)

	# Add to scene tree with proper ownership
	interactables_container.add_child(interactable_node)
	interactable_node.owner = scene_root

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
	# Use CACHE_MODE_REUSE to get the canonical resource instance with proper resource_path
	# This ensures the resource is saved as an external reference, not embedded
	var npc_script: GDScript = ResourceLoader.load("res://core/components/npc_node.gd", "", ResourceLoader.CACHE_MODE_REUSE) as GDScript
	if not npc_script:
		push_error("MapPlacementHelper: Failed to load npc_node.gd script")
		return false

	var npc_data: Resource = ResourceLoader.load(npc_resource_path, "", ResourceLoader.CACHE_MODE_REUSE)
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

	return true


## Add NPC to a scene that's not currently open
## Uses direct .tscn file manipulation to ensure ExtResource references (not embedded SubResources)
func _add_npc_to_closed_scene(
	scene_path: String,
	npc_resource_path: String,
	node_name: String,
	position: Vector2
) -> bool:
	# Read the scene file as text
	var file: FileAccess = FileAccess.open(scene_path, FileAccess.READ)
	if not file:
		push_error("MapPlacementHelper: Failed to open scene file: %s" % scene_path)
		return false

	var scene_text: String = file.get_as_text()
	file.close()

	# Get the NPC resource UID
	var npc_uid: String = _get_resource_uid(npc_resource_path)
	if npc_uid.is_empty():
		push_error("MapPlacementHelper: Failed to get UID for NPC resource: %s" % npc_resource_path)
		return false

	# Generate a unique ExtResource ID
	var ext_id: String = _generate_unique_ext_id(scene_text)

	# Check if NPC script ExtResource already exists
	var npc_script_id: String = _find_ext_resource_id(scene_text, "res://core/components/npc_node.gd")
	if npc_script_id.is_empty():
		push_error("MapPlacementHelper: Scene doesn't have npc_node.gd script reference")
		return false

	# Add ExtResource for the NPC data file (before first sub_resource or node)
	var ext_resource_line: String = '[ext_resource type="Resource" uid="%s" path="%s" id="%s"]\n' % [npc_uid, npc_resource_path, ext_id]

	# Find insertion point for new ExtResource (after last ext_resource, before first sub_resource or node)
	var insert_pos: int = _find_ext_resource_insert_position(scene_text)
	if insert_pos < 0:
		push_error("MapPlacementHelper: Failed to find insertion point in scene file")
		return false

	scene_text = scene_text.insert(insert_pos, ext_resource_line)

	# Find the NPCs container node path and check if it exists
	var has_npcs_container: bool = scene_text.contains('[node name="NPCs"')

	# Generate unique node name
	var final_node_name: String = node_name
	var name_counter: int = 2
	while scene_text.contains('[node name="%s"' % final_node_name):
		final_node_name = "%s%d" % [node_name, name_counter]
		name_counter += 1

	# Build the node definition
	var node_text: String = '\n[node name="%s" type="Area2D" parent="NPCs"]\n' % final_node_name
	node_text += 'position = Vector2(%d, %d)\n' % [int(position.x), int(position.y)]
	node_text += 'script = ExtResource("%s")\n' % npc_script_id
	node_text += 'npc_data = ExtResource("%s")\n' % ext_id

	# If no NPCs container, we need to add it too
	if not has_npcs_container:
		var npcs_container_text: String = '\n[node name="NPCs" type="Node2D" parent="."]\n'
		# Find a good place to insert (after map root node children, before Interactables if exists)
		var interactables_pos: int = scene_text.find('[node name="Interactables"')
		if interactables_pos > 0:
			scene_text = scene_text.insert(interactables_pos, npcs_container_text)
		else:
			# Append before the end
			scene_text += npcs_container_text

	# Append the node (scene files end with nodes)
	scene_text += node_text

	# Update load_steps count in header
	scene_text = _increment_load_steps(scene_text)

	# Write back to file
	file = FileAccess.open(scene_path, FileAccess.WRITE)
	if not file:
		push_error("MapPlacementHelper: Failed to write scene file: %s" % scene_path)
		return false

	file.store_string(scene_text)
	file.close()

	# Notify the editor to refresh
	EditorInterface.get_resource_filesystem().scan()

	return true


## Get the UID of a resource file
func _get_resource_uid(resource_path: String) -> String:
	var file: FileAccess = FileAccess.open(resource_path, FileAccess.READ)
	if not file:
		return ""

	# Read first line to find UID
	var first_line: String = file.get_line()
	file.close()

	# Parse uid from line like: [gd_resource ... uid="uid://xyz" ...]
	var uid_start: int = first_line.find('uid="')
	if uid_start < 0:
		return ""

	uid_start += 5  # Skip 'uid="'
	var uid_end: int = first_line.find('"', uid_start)
	if uid_end < 0:
		return ""

	return first_line.substr(uid_start, uid_end - uid_start)


## Generate a unique ExtResource ID for the scene
func _generate_unique_ext_id(scene_text: String) -> String:
	var counter: int = 1
	var base: String = "npc_data_"
	while scene_text.contains('id="%s%d"' % [base, counter]):
		counter += 1
	return "%s%d" % [base, counter]


## Find the ID of an existing ExtResource by path
func _find_ext_resource_id(scene_text: String, resource_path: String) -> String:
	var search: String = 'path="%s"' % resource_path
	var pos: int = scene_text.find(search)
	if pos < 0:
		return ""

	# Find the id on the same line
	var line_start: int = scene_text.rfind("\n", pos)
	if line_start < 0:
		line_start = 0
	var line_end: int = scene_text.find("\n", pos)
	if line_end < 0:
		line_end = scene_text.length()

	var line: String = scene_text.substr(line_start, line_end - line_start)
	var id_start: int = line.find('id="')
	if id_start < 0:
		return ""

	id_start += 4  # Skip 'id="'
	var id_end: int = line.find('"', id_start)
	if id_end < 0:
		return ""

	return line.substr(id_start, id_end - id_start)


## Find the position to insert a new ExtResource (after last ext_resource line)
func _find_ext_resource_insert_position(scene_text: String) -> int:
	# Find the last [ext_resource line
	var last_ext: int = scene_text.rfind("[ext_resource")
	if last_ext < 0:
		# No ext_resources, insert after header line
		var header_end: int = scene_text.find("]\n")
		if header_end > 0:
			return header_end + 2
		return -1

	# Find end of this ext_resource line
	var line_end: int = scene_text.find("\n", last_ext)
	if line_end < 0:
		return -1

	return line_end + 1


## Increment the load_steps count in scene header
func _increment_load_steps(scene_text: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile('load_steps=(\\d+)')
	var result: RegExMatch = regex.search(scene_text)
	if result:
		var current_steps: int = int(result.get_string(1))
		var new_steps: int = current_steps + 1
		scene_text = scene_text.replace(
			"load_steps=%d" % current_steps,
			"load_steps=%d" % new_steps
		)
	return scene_text


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
