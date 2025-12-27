## Spawn handler for Character entities in cinematics
class_name CharacterSpawnHandler
extends SpawnableEntityHandler


func get_type_id() -> String:
	return "character"


func get_display_name() -> String:
	return "Character"


func get_available_entities() -> Array[Dictionary]:
	var entities: Array[Dictionary] = []

	if not ModLoader or not ModLoader.registry:
		return entities

	var characters: Array = ModLoader.registry.get_all_resources("character")
	for entry: Dictionary in characters:
		if "resource" not in entry:
			continue
		var char_data: CharacterData = entry["resource"] as CharacterData
		if char_data:
			var entity_id: String = str(entry["id"]) if "id" in entry else ""
			var display_name: String = char_data.character_name if not char_data.character_name.is_empty() else entity_id
			entities.append({
				"id": entity_id,
				"name": display_name,
				"resource": char_data
			})

	return entities


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


func _create_placeholder_sprite() -> AnimatedSprite2D:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	return sprite
