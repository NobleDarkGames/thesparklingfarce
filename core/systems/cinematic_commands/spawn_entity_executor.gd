## Spawn entity command executor
## Creates an entity at runtime with CinematicActor component
## Spawned entities can be controlled by move_entity, set_facing, etc.
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
		grid_pos = Vector2i(int(pos_param[0]), int(pos_param[1]))
	elif pos_param is Vector2:
		grid_pos = Vector2i(pos_param)
	elif pos_param is Vector2i:
		grid_pos = pos_param
	else:
		push_warning("SpawnEntityExecutor: Invalid position format, defaulting to (0, 0)")

	# Get facing direction
	var facing: String = params.get("facing", "down").to_lower()
	if facing not in ["up", "down", "left", "right"]:
		push_warning("SpawnEntityExecutor: Invalid facing '%s', defaulting to 'down'" % facing)
		facing = "down"

	# Get optional character_id for sprite
	var character_id: String = params.get("character_id", "")

	# Create the spawned entity structure:
	# SpawnedActor_{actor_id} (CharacterBody2D)
	# +-- AnimatedSprite2D (sprite_frames from CharacterData)
	# +-- CinematicActor (actor_id, auto-registers)

	var entity: CharacterBody2D = CharacterBody2D.new()
	entity.name = "SpawnedActor_%s" % actor_id

	# Position at grid coordinates
	entity.global_position = GridManager.cell_to_world(grid_pos)

	# Ensure spawned entities render above backdrop tilemaps
	entity.z_index = 10

	# Create AnimatedSprite2D if we have character data
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"

	if not character_id.is_empty():
		var char_data: CharacterData = ModLoader.registry.get_resource("character", character_id) as CharacterData
		if char_data != null:
			if char_data.sprite_frames != null:
				sprite.sprite_frames = char_data.sprite_frames
				# Play initial facing animation (SF2-authentic: walk animation even when stationary)
				var initial_anim: String = "walk_" + facing
				if sprite.sprite_frames.has_animation(initial_anim):
					sprite.play(initial_anim)
			else:
				push_warning("SpawnEntityExecutor: CharacterData '%s' has no sprite_frames" % character_id)
		else:
			push_warning("SpawnEntityExecutor: CharacterData '%s' not found in registry" % character_id)

	entity.add_child(sprite)

	# Create CinematicActor component
	var cinematic_actor: CinematicActor = CinematicActor.new()
	cinematic_actor.name = "CinematicActor"
	cinematic_actor.actor_id = actor_id
	cinematic_actor.sprite_node = sprite  # Pre-set the sprite reference
	entity.add_child(cinematic_actor)

	# Add to scene tree
	# Find a good parent - use current scene root
	var scene_root: Node = manager.get_tree().current_scene
	if scene_root:
		scene_root.add_child(entity)
	else:
		push_error("SpawnEntityExecutor: No current scene to add entity to")
		entity.queue_free()
		return true

	# Track spawned node for cleanup (Phase 3)
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
			"character_id": {"type": "character", "default": "", "hint": "CharacterData to spawn (optional)"}
		}
	}
