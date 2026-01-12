## Spawn handler for virtual (off-screen) actors
## Virtual actors have no visual representation on the map - they exist only for dialog
## Use for narrators, radio voices, character thoughts, etc.
class_name VirtualSpawnHandler
extends SpawnableEntityHandler


## Return the entity type identifier
func get_type_id() -> String:
	return "virtual"


## Return human-readable display name for the editor
func get_display_name() -> String:
	return "Virtual (Off-Screen)"


## Virtual actors don't come from registry - they're defined inline in the cinematic
## Returns empty array since there's nothing to select
func get_available_entities() -> Array[Dictionary]:
	return []


## Virtual actors have no sprite - they only appear in dialog
## Returns null intentionally
func create_sprite_node(_entity_id: String, _facing: String) -> Node2D:
	return null


## Get editor metadata for virtual actor parameters
func get_editor_hints() -> Dictionary:
	return {
		"entity_id_hint": "Virtual actors use display_source to reference an NPC or character for portrait",
		"requires_position": false,
		"requires_facing": false,
		"requires_entity_id": false
	}
