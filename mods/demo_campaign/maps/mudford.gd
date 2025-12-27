extends "res://core/templates/map_template.gd"

# =============================================================================
# MAP IDENTITY (Scene as Source of Truth)
# =============================================================================

## Unique identifier for this map (namespaced: "mod_id:map_name")
@export var map_id: String = "demo_campaign:mudford"

## Map type determines Caravan visibility and party follower behavior
@export_enum("TOWN", "OVERWORLD", "DUNGEON", "INTERIOR", "BATTLE") var map_type: String = "TOWN"

## Display name for UI (save menu, map name popups)
@export var display_name: String = "Mudford"


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()
	_debug_print("Map '%s' ready!" % display_name)
