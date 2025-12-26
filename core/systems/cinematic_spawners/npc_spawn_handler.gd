## Spawn handler for NPC entities in cinematics
## NPCs can have their own sprite_frames or derive from character_data
class_name NPCSpawnHandler
extends SpawnableEntityHandler


func get_type_id() -> String:
	return "npc"


func get_display_name() -> String:
	return "NPC"


func get_available_entities() -> Array[Dictionary]:
	var entities: Array[Dictionary] = []

	if not ModLoader or not ModLoader.registry:
		return entities

	var npcs: Array = ModLoader.registry.get_all_resources("npc")
	for entry: Dictionary in npcs:
		var npc_data: NPCData = entry.get("resource") as NPCData
		if npc_data:
			entities.append({
				"id": entry.get("id", ""),
				"name": npc_data.npc_name if not npc_data.npc_name.is_empty() else entry.get("id", ""),
				"resource": npc_data
			})

	return entities


func create_sprite_node(entity_id: String, facing: String) -> Node2D:
	var npc_data: NPCData = ModLoader.registry.get_resource("npc", entity_id) as NPCData
	if npc_data == null:
		push_warning("NPCSpawnHandler: NPCData '%s' not found in registry" % npc_data)
		return _create_placeholder_sprite()

	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"

	# NPCs can use character_data.sprite_frames OR their own sprite_frames
	var frames: SpriteFrames = null
	if npc_data.character_data != null and npc_data.character_data.sprite_frames != null:
		frames = npc_data.character_data.sprite_frames
	elif npc_data.sprite_frames != null:
		frames = npc_data.sprite_frames

	if frames != null:
		sprite.sprite_frames = frames
		# Play initial facing animation
		var initial_anim: String = "walk_" + facing
		if sprite.sprite_frames.has_animation(initial_anim):
			sprite.play(initial_anim)
	else:
		push_warning("NPCSpawnHandler: NPCData '%s' has no sprite_frames" % entity_id)

	return sprite


func get_editor_hints() -> Dictionary:
	return {
		"entity_id_hint": "Select an NPC to spawn"
	}


func _create_placeholder_sprite() -> AnimatedSprite2D:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	return sprite
