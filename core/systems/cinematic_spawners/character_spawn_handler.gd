## Spawn handler for Character entities in cinematics
class_name CharacterSpawnHandler
extends SpawnableEntityHandler


func get_type_id() -> String:
	return "character"


func get_display_name() -> String:
	return "Character"


func get_available_entities() -> Array[Dictionary]:
	return _build_entity_list_from_registry("character", func(res: Resource, fallback_id: String) -> String:
		var char_data: CharacterData = res as CharacterData
		return char_data.character_name if char_data and not char_data.character_name.is_empty() else fallback_id
	)


func create_sprite_node(entity_id: String, facing: String) -> Node2D:
	var char_data: CharacterData = ModLoader.registry.get_character(entity_id)
	if char_data == null:
		push_warning("CharacterSpawnHandler: CharacterData '%s' not found in registry" % entity_id)
		return _create_placeholder_sprite()

	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"

	if char_data.sprite_frames != null:
		sprite.sprite_frames = char_data.sprite_frames
		# Play initial facing animation (SF2-authentic: walk animation even when stationary)
		var initial_anim: String = "walk_" + facing
		if sprite.sprite_frames.has_animation(initial_anim):
			sprite.play(initial_anim)
	else:
		push_warning("CharacterSpawnHandler: CharacterData '%s' has no sprite_frames" % entity_id)

	return sprite


func get_editor_hints() -> Dictionary:
	return {
		"entity_id_hint": "Select a character to spawn"
	}
