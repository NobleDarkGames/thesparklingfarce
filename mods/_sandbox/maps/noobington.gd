## Noobington - A starter town for The Sparkling Farce
##
## This town serves as the first settlement players encounter.
extends "res://mods/_base_game/maps/templates/map_template.gd"

# =============================================================================
# MAP IDENTITY (Scene as Source of Truth)
# =============================================================================

## Unique identifier for this map (namespaced: "mod_id:map_name")
## Used by ModLoader registry and map transitions
@export var map_id: String = "sandbox:noobington"

## Map type determines Caravan visibility and party follower behavior
## TOWN: Caravan hidden, followers visible (SF2-style chain)
@export_enum("TOWN", "OVERWORLD", "DUNGEON", "INTERIOR", "BATTLE") var map_type: String = "TOWN"

## Display name for UI (save menu, map name popups)
@export var display_name: String = "Noobington"


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
