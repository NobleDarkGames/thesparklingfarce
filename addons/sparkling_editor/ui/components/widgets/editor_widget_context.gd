@tool
class_name EditorWidgetContext
extends RefCounted

## Shared context for editor widgets
## Contains resource caches and nesting depth tracking for recursive widget embedding
##
## This context is populated by the parent editor (e.g., CinematicEditor) and passed
## to widgets so they can populate dropdowns without re-querying ModLoader.
##
## Usage:
##   var context: EditorWidgetContext = EditorWidgetContext.new()
##   context.characters = _characters  # From cinematic editor's cache
##   context.npcs = _npcs
##   widget.set_context(context)

const MAX_NESTING_DEPTH: int = 3

# Resource caches (populated from cinematic editor or other parent)
var characters: Array[Resource] = []
var npcs: Array[Resource] = []
var shops: Array[Resource] = []
var battles: Array[Resource] = []
var maps: Array[Resource] = []
var cinematics: Array[Dictionary] = []  # [{path: String, mod_id: String, name: String}]
var actor_ids: Array[String] = []  # Current cinematic's actors

# Nesting depth for recursive widget embedding (e.g., cinematic picker inside cinematic editor)
var nesting_depth: int = 0


## Create a copy of this context with incremented nesting depth
## Used when embedding widgets that might themselves contain pickers
func with_incremented_depth() -> EditorWidgetContext:
	var new_context: EditorWidgetContext = EditorWidgetContext.new()
	new_context.characters = characters
	new_context.npcs = npcs
	new_context.shops = shops
	new_context.battles = battles
	new_context.maps = maps
	new_context.cinematics = cinematics
	new_context.actor_ids = actor_ids
	new_context.nesting_depth = nesting_depth + 1
	return new_context


## Check if we've hit the nesting limit
## Prevents infinite recursion when cinematics reference other cinematics
func is_at_depth_limit() -> bool:
	return nesting_depth >= MAX_NESTING_DEPTH


## Update actor IDs from a cinematic's commands
## Extracts actor IDs from spawn_actor commands in the given command list
func update_actors_from_commands(commands: Array) -> void:
	actor_ids.clear()
	for cmd: Variant in commands:
		if cmd is Dictionary:
			var cmd_dict: Dictionary = cmd
			if cmd_dict.get("type", "") == "spawn_actor":
				var params: Dictionary = cmd_dict.get("params", {})
				var actor_id: String = params.get("actor_id", "")
				if not actor_id.is_empty() and actor_id not in actor_ids:
					actor_ids.append(actor_id)


## Populate this context by querying the registry directly
## Call this after creating a new context to provide resource access to widgets
##
## Parameters:
##   p_cinematics: Array of cinematic info dictionaries [{path, mod_id, name}]
##   p_actor_ids: Array of actor ID strings from current cinematic
func populate_from_registry(
	p_cinematics: Array[Dictionary],
	p_actor_ids: Array[String]
) -> void:
	# Query registry fresh each time - no caches
	characters.clear()
	npcs.clear()
	shops.clear()
	battles.clear()
	maps.clear()

	if ModLoader and ModLoader.registry:
		characters = ModLoader.registry.get_all_resources("character")
		npcs = ModLoader.registry.get_all_resources("npc")
		shops = ModLoader.registry.get_all_resources("shop")
		battles = ModLoader.registry.get_all_resources("battle")
		maps = ModLoader.registry.get_all_resources("map")

	cinematics = p_cinematics
	actor_ids = p_actor_ids
