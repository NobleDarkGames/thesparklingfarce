## Spawn handler for Interactable entities in cinematics
## Spawns static objects like chests, signs, levers, etc.
class_name InteractableSpawnHandler
extends SpawnableEntityHandler


func get_type_id() -> String:
	return "interactable"


func get_display_name() -> String:
	return "Interactable"


func get_available_entities() -> Array[Dictionary]:
	return _build_entity_list_from_registry("interactable", func(res: Resource, fallback_id: String) -> String:
		var inter_data: InteractableData = res as InteractableData
		return inter_data.display_name if inter_data and not inter_data.display_name.is_empty() else fallback_id
	)


func create_sprite_node(entity_id: String, _facing: String) -> Node2D:
	var inter_data: InteractableData = ModLoader.registry.get_interactable(entity_id)
	if inter_data == null:
		push_warning("InteractableSpawnHandler: InteractableData '%s' not found in registry" % entity_id)
		return _create_placeholder_sprite()

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite2D"

	# Interactables use static textures (sprite_closed for initial state)
	if inter_data.sprite_closed != null:
		sprite.texture = inter_data.sprite_closed
	else:
		push_warning("InteractableSpawnHandler: InteractableData '%s' has no sprite_closed" % entity_id)

	return sprite


func get_editor_hints() -> Dictionary:
	return {
		"entity_id_hint": "Select an interactable object (chest, sign, etc.)"
	}


func _create_placeholder_sprite() -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "PlaceholderSprite"
	var texture: Texture2D = load(FALLBACK_SPRITESHEET_PATH) as Texture2D
	if texture:
		sprite.texture = texture
		sprite.region_enabled = true
		sprite.region_rect = Rect2(Vector2.ZERO, Vector2(FALLBACK_FRAME_SIZE))
	sprite.modulate = Color(1.0, 0.4, 0.7, 1.0)
	return sprite
