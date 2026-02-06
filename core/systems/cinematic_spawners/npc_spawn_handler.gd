## Spawn handler for NPC entities in cinematics
## NPCs have their own sprite_frames for map display
class_name NPCSpawnHandler
extends SpawnableEntityHandler


func get_type_id() -> String:
	return "npc"


func get_display_name() -> String:
	return "NPC"


func get_available_entities() -> Array[Dictionary]:
	return _build_entity_list_from_registry("npc", func(res: Resource, fallback_id: String) -> String:
		var npc_data: NPCData = res as NPCData
		return npc_data.npc_name if npc_data and not npc_data.npc_name.is_empty() else fallback_id
	)


func create_sprite_node(entity_id: String, facing: String) -> Node2D:
	var npc_data: NPCData = ModLoader.registry.get_npc(entity_id)
	if npc_data == null:
		push_warning("NPCSpawnHandler: NPCData '%s' not found in registry" % entity_id)
		return _create_placeholder_sprite()

	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"

	# NPCs use their own sprite_frames directly
	var frames: SpriteFrames = npc_data.sprite_frames

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
