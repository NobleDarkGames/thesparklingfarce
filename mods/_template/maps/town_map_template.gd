## TownMapTemplate - Template for creating town/settlement map scenes
##
## USAGE: Duplicate this file AND town_map_template.tscn to create new town maps.
##
## Towns in The Sparkling Farce (SF2-style):
## - Detailed tilesets with buildings, NPCs, shops
## - 1:1 visual scale (close-up view vs overworld's abstract scale)
## - Party followers VISIBLE (they follow the hero in SF2-style chain)
## - Caravan NOT visible (stays on overworld)
## - No random encounters
## - Save anywhere enabled
##
## SCENE AS SOURCE OF TRUTH:
## The scene defines map identity via @export variables:
## - map_id: Unique namespaced ID (e.g., "my_mod:granseal")
## - map_type: TOWN, OVERWORLD, DUNGEON, etc.
## - display_name: Human-readable name for UI
##
## SpawnPoints and door connections are extracted from scene nodes automatically.
##
## MAP METADATA JSON (simplified - runtime config only):
## Create a JSON file in data/maps/:
##   {
##     "scene_path": "res://mods/my_mod/maps/my_town.tscn",
##     "caravan_visible": false,
##     "caravan_accessible": false,
##     "music_id": "town_theme",
##     "random_encounters_enabled": false,
##     "save_anywhere": true
##   }
##
## CAMPAIGN INTEGRATION:
## Add a node to your campaign JSON:
##   {
##     "node_id": "my_town",
##     "display_name": "Granseal",
##     "node_type": "scene",
##     "scene_path": "res://mods/my_mod/maps/my_town.tscn",
##     "is_hub": true,
##     "completion_trigger": "exit_trigger",
##     "on_complete": "overworld_node_id"
##   }
##
## DOOR TRIGGERS:
## Add DoorTrigger nodes to connect to other maps:
##   trigger_type: DOOR
##   trigger_data: {
##     "target_map_id": "my_mod:overworld",
##     "target_spawn_id": "from_town"
##   }
##
## NPC PLACEMENT (Future):
## NPCs will be Area2D nodes with DialogTrigger type and dialog_id in trigger_data.
## For now, you can create custom dialog triggers manually.
extends "res://mods/_base_game/maps/templates/map_template.gd"

# =============================================================================
# MAP IDENTITY (Scene as Source of Truth)
# =============================================================================

## Unique identifier for this map (namespaced: "mod_id:map_name")
## Used by ModLoader registry and map transitions
@export var map_id: String = "my_mod:example_town"

## Map type determines Caravan visibility and party follower behavior
## TOWN: Caravan hidden, followers visible (SF2-style chain)
@export_enum("TOWN", "OVERWORLD", "DUNGEON", "INTERIOR", "BATTLE") var map_type: String = "TOWN"

## Display name for UI (save menu, map name popups)
@export var display_name: String = "Example Town"


# =============================================================================
# TOWN-SPECIFIC BEHAVIOR
# =============================================================================

func _ready() -> void:
	# Call parent to set up hero, followers, camera, etc.
	super._ready()

	# Town-specific initialization
	_setup_town()


func _setup_town() -> void:
	# Music is handled by MapMetadata JSON (music_id field)
	# The AudioManager will use vertical mixing in the future

	# Towns always show party followers (SF2-style)
	# This is handled by map_template.gd checking caravan_visible = false

	_debug_print("TownMapTemplate: Town '%s' ready!" % display_name)


# =============================================================================
# OVERRIDE HOOKS FOR CUSTOM TOWN BEHAVIOR
# =============================================================================

## Called when hero moves to a new tile
## Override to add custom tile-based events (stepping on switches, etc.)
func _on_hero_moved(tile_pos: Vector2i) -> void:
	super._on_hero_moved(tile_pos)
	# Add town-specific tile events here:
	# - Hidden item discovery
	# - Floor switch activation
	# - Area-based dialog triggers


## Called when hero presses interaction button
## Override to handle town-specific interactions
func _on_hero_interaction(interaction_pos: Vector2i) -> void:
	super._on_hero_interaction(interaction_pos)
	# Add town-specific interactions here:
	# - NPC conversations
	# - Reading signs
	# - Opening barrels/pots
	# - Entering buildings


# =============================================================================
# TOWN UTILITY FUNCTIONS
# =============================================================================

## Get all door triggers in this town (for debugging/tooling)
func get_door_triggers() -> Array[Node]:
	var doors: Array[Node] = []
	var triggers: Node = get_node_or_null("Triggers")
	if triggers:
		for child: Node in triggers.get_children():
			if child.has_method("get_trigger_type_name"):
				if child.get_trigger_type_name() == "door":
					doors.append(child)
	return doors


## Get all NPC triggers in this town (for debugging/tooling)
func get_npc_triggers() -> Array[Node]:
	var npcs: Array[Node] = []
	var triggers: Node = get_node_or_null("Triggers")
	if triggers:
		for child: Node in triggers.get_children():
			if child.has_method("get_trigger_type_name"):
				if child.get_trigger_type_name() == "dialog":
					npcs.append(child)
	return npcs
