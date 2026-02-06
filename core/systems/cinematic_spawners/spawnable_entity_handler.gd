## Base class for spawnable entity handlers
## Mods can extend this to add custom entity types that can be spawned in cinematics
class_name SpawnableEntityHandler
extends RefCounted


## Return the entity type identifier (e.g., "character", "interactable", "npc")
func get_type_id() -> String:
	push_error("SpawnableEntityHandler.get_type_id() must be overridden")
	return ""


## Return human-readable display name for the editor
func get_display_name() -> String:
	return get_type_id().capitalize()


## Return list of available entity IDs for this type from the registry
## Each entry is a Dictionary with at least: {"id": String, "name": String}
func get_available_entities() -> Array[Dictionary]:
	push_error("SpawnableEntityHandler.get_available_entities() must be overridden")
	return []


## Helper to build entity list from registry resources
## name_extractor: Callable(resource: Resource) -> String that extracts display name
func _build_entity_list_from_registry(resource_type: String, name_extractor: Callable) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []

	if not ModLoader or not ModLoader.registry:
		return entities

	var resources: Array = ModLoader.registry.get_all_resources(resource_type)
	for entry: Dictionary in resources:
		if "resource" not in entry:
			continue
		var resource: Resource = entry["resource"]
		if resource:
			var entity_id: String = str(entry["id"]) if "id" in entry else ""
			var display_name: String = name_extractor.call(resource, entity_id)
			entities.append({
				"id": entity_id,
				"name": display_name,
				"resource": resource
			})

	return entities


## Create the visual node (sprite) for the entity
## Returns the sprite node or null on failure
func create_sprite_node(entity_id: String, facing: String) -> Node2D:
	push_error("SpawnableEntityHandler.create_sprite_node() must be overridden")
	return null


## Fallback spritesheet used when entity data is missing from the registry.
const FALLBACK_SPRITESHEET_PATH: String = "res://mods/_starter_kit/assets/sprites/map/Character_Basic_1.png"
## Frame size matches the standard spritesheet layout (32x32 per frame).
const FALLBACK_FRAME_SIZE: Vector2i = Vector2i(32, 32)


## Create a placeholder sprite when entity data is missing.
## Loads a starter kit spritesheet and shows the first frame with a pink tint
## so modders can see something went wrong. Override in subclasses that need
## a different node type (e.g., Sprite2D for interactables).
func _create_placeholder_sprite() -> Node2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "PlaceholderSprite"
	var texture: Texture2D = load(FALLBACK_SPRITESHEET_PATH) as Texture2D
	if texture:
		sprite.texture = texture
		sprite.region_enabled = true
		sprite.region_rect = Rect2(Vector2.ZERO, Vector2(FALLBACK_FRAME_SIZE))
	sprite.modulate = Color(1.0, 0.4, 0.7, 1.0)
	return sprite


## Get editor metadata for this entity type's parameters
## Returns parameter hints for the cinematic editor
func get_editor_hints() -> Dictionary:
	return {
		"entity_id_hint": "Select a %s" % get_display_name().to_lower()
	}
