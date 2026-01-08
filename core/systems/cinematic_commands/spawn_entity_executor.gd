## Spawn entity command executor
## Creates an entity at runtime with CinematicActor component
## Spawned entities can be controlled by move_entity, set_facing, etc.
## Supports any registered spawnable type (character, interactable, npc, mod-defined types)
class_name SpawnEntityExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})

	var actor_id: String = params.get("actor_id", "")
	if actor_id.is_empty():
		push_error("SpawnEntityExecutor: actor_id is required")
		return true  # Complete immediately on error

	# Check for existing actor with this ID
	if manager.get_actor(actor_id) != null:
		push_warning("SpawnEntityExecutor: Actor '%s' already exists, will be overwritten" % actor_id)

	# Parse position (grid coordinates)
	var grid_pos: Vector2i = Vector2i.ZERO
	var pos_param: Variant = params.get("position", [0, 0])
	if pos_param is Array and pos_param.size() >= 2:
		var x_val: Variant = pos_param[0]
		var y_val: Variant = pos_param[1]
		if (x_val is int or x_val is float) and (y_val is int or y_val is float):
			grid_pos = Vector2i(int(x_val), int(y_val))
		else:
			push_warning("SpawnEntityExecutor: Position array elements must be numeric")
	elif pos_param is Vector2:
		grid_pos = Vector2i(pos_param)
	elif pos_param is Vector2i:
		grid_pos = pos_param
	else:
		push_warning("SpawnEntityExecutor: Invalid position format, defaulting to (0, 0)")

	# Get facing direction
	var facing_raw: String = str(params.get("facing", "down"))
	var facing: String = facing_raw.to_lower()
	if facing not in ["up", "down", "left", "right"]:
		push_warning("SpawnEntityExecutor: Invalid facing '%s', defaulting to 'down'" % facing)
		facing = "down"

	# Determine entity type and ID (with backward compatibility)
	var entity_type: String = params.get("entity_type", "")
	var entity_id: String = params.get("entity_id", "")

	# Backward compatibility: character_id -> entity_type="character"
	if entity_type.is_empty() and entity_id.is_empty():
		var character_id: String = params.get("character_id", "")
		if not character_id.is_empty():
			entity_type = "character"
			entity_id = character_id

	# Backward compatibility: interactable_id -> entity_type="interactable"
	if entity_type.is_empty() and entity_id.is_empty():
		var interactable_id: String = params.get("interactable_id", "")
		if not interactable_id.is_empty():
			entity_type = "interactable"
			entity_id = interactable_id

	# Default to character if no type specified
	if entity_type.is_empty():
		entity_type = "character"

	# Create the spawned entity structure:
	# SpawnedActor_{actor_id} (CharacterBody2D)
	# +-- Sprite node (from handler)
	# +-- CinematicActor (actor_id, auto-registers)

	var entity: CharacterBody2D = CharacterBody2D.new()
	entity.name = "SpawnedActor_%s" % actor_id

	# Position at grid coordinates
	entity.global_position = GridManager.cell_to_world(grid_pos)

	# Ensure spawned entities render above backdrop tilemaps
	entity.z_index = 10

	# Create sprite using the registry handler
	var sprite_node: Node2D = null
	var handler: SpawnableEntityHandler = CinematicsManager.get_spawnable_handler(entity_type)

	if handler and not entity_id.is_empty():
		sprite_node = handler.create_sprite_node(entity_id, facing)

	# Fallback to empty placeholder if no handler or entity_id
	if sprite_node == null:
		var placeholder: AnimatedSprite2D = AnimatedSprite2D.new()
		placeholder.name = "AnimatedSprite2D"
		sprite_node = placeholder
		if not entity_id.is_empty():
			push_warning("SpawnEntityExecutor: No handler for entity_type '%s' or entity '%s' not found" % [entity_type, entity_id])

	entity.add_child(sprite_node)

	# Create CinematicActor component
	var cinematic_actor: CinematicActor = CinematicActor.new()
	cinematic_actor.name = "CinematicActor"
	cinematic_actor.actor_id = actor_id
	cinematic_actor.sprite_node = sprite_node
	entity.add_child(cinematic_actor)

	# Add to scene tree (use cinematic stage if available, otherwise current scene)
	var actor_parent: Node = CinematicsManager._find_actor_parent() if CinematicsManager else null
	if actor_parent:
		actor_parent.add_child(entity)
	else:
		push_error("SpawnEntityExecutor: No scene to add entity to")
		entity.queue_free()
		return true

	# Track spawned node for cleanup
	if manager.has_method("_track_spawned_actor"):
		manager._track_spawned_actor(entity)

	return true  # Complete immediately (spawning is instant)


func get_editor_metadata() -> Dictionary:
	return {
		"description": "Spawn an entity at a position",
		"category": "Entity",
		"icon": "Node2D",
		"params": {
			"actor_id": {"type": "string", "default": "", "hint": "Actor ID to assign (must be unique)"},
			"position": {"type": "vector2", "default": [0, 0], "hint": "Spawn position (grid coordinates)"},
			"facing": {"type": "enum", "default": "down", "options": ["up", "down", "left", "right"], "hint": "Initial facing direction"},
			"entity_type": {"type": "spawnable_type", "default": "character", "hint": "Type of entity to spawn"},
			"entity_id": {"type": "spawnable_entity", "default": "", "hint": "ID of entity to spawn (depends on entity_type)"}
		}
	}
