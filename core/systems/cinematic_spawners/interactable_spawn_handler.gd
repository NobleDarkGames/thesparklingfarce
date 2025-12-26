## Spawn handler for Interactable entities in cinematics
## Spawns static objects like chests, signs, levers, etc.
class_name InteractableSpawnHandler
extends SpawnableEntityHandler


func get_type_id() -> String:
	return "interactable"


func get_display_name() -> String:
	return "Interactable"


func get_available_entities() -> Array[Dictionary]:
	var entities: Array[Dictionary] = []

	if not ModLoader or not ModLoader.registry:
		return entities

	var interactables: Array = ModLoader.registry.get_all_resources("interactable")
	for entry: Dictionary in interactables:
		var inter_data: InteractableData = entry.get("resource") as InteractableData
		if inter_data:
			entities.append({
				"id": entry.get("id", ""),
				"name": inter_data.display_name if not inter_data.display_name.is_empty() else entry.get("id", ""),
				"resource": inter_data
			})

	return entities


func create_sprite_node(entity_id: String, facing: String) -> Node2D:
	var inter_data: InteractableData = ModLoader.registry.get_resource("interactable", entity_id) as InteractableData
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
	sprite.name = "Sprite2D"
	return sprite
