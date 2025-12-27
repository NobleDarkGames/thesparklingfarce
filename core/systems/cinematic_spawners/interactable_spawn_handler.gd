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
		if "resource" not in entry:
			continue
		var inter_data: InteractableData = entry["resource"] as InteractableData
		if inter_data:
			var entity_id: String = str(entry["id"]) if "id" in entry else ""
			var display_name: String = inter_data.display_name if not inter_data.display_name.is_empty() else entity_id
			entities.append({
				"id": entity_id,
				"name": display_name,
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
