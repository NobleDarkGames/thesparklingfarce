@tool
class_name NewGameConfigData
extends Resource

## NewGameConfigData - Defines initial game state for new games
##
## Mods provide NewGameConfigData resources to customize the starting experience.
## The highest-priority mod's default config is used (complete replacement, no merging).
##
## Discovery: mods/*/data/new_game_configs/*.tres
## Type key: "new_game_config"
##
## Design Philosophy:
## - Simple replacement semantics - higher priority mods completely override lower ones
## - No merge complexity - if you want specific starting conditions, define them all
## - Debuggable - you always know exactly where your starting state comes from

# ============================================================================
# IDENTITY
# ============================================================================

## Unique identifier for this config (e.g., "standard", "hard_mode", "demo")
@export var config_id: String = "default"

## Human-readable name for UI display
@export var config_name: String = "Standard"

## Description explaining this configuration
@export_multiline var config_description: String = ""

## If true, this is the default config for the providing mod
## Only one config per mod should have this set to true
@export var is_default: bool = true

# ============================================================================
# STARTING SCENE
# ============================================================================

## Scene path to load when starting a new game
## Example: "res://mods/demo_campaign/scenes/mudford.tscn"
@export_file("*.tscn") var starting_scene_path: String = ""

## Optional spawn point ID within the starting scene
@export var starting_spawn_point: String = ""

## Optional cinematic ID to play before loading the starting scene
## Use for intro cutscenes, story setup, etc.
@export var intro_cinematic_id: String = ""

# ============================================================================
# LEGACY CAMPAIGN (deprecated)
# ============================================================================

## @deprecated Use starting_scene_path instead
## Campaign ID to start (can be namespaced: "mod_id:campaign_id")
@export var starting_campaign_id: String = ""

# ============================================================================
# LOCATION DISPLAY
# ============================================================================

## Display text for save slot (e.g., "Prologue", "Chapter 1", "Tutorial")
## This is cosmetic - actual location determined by campaign starting node
@export var starting_location_label: String = "Prologue"

# ============================================================================
# ECONOMY
# ============================================================================

## Starting gold amount (SF2 authentic default: 0)
@export_range(0, 99999) var starting_gold: int = 0

## Items to place in Caravan depot at game start
## Array of item IDs (strings) - duplicates allowed for stacking
## Example: ["healing_seed", "healing_seed", "bronze_sword"]
@export var starting_depot_items: Array[String] = []

# ============================================================================
# STORY STATE
# ============================================================================

## Story flags to set at game start
## Format: {"flag_name": true, "another_flag": false}
## These supplement the campaign's initial_flags (config values take precedence)
@export var starting_story_flags: Dictionary = {}

# ============================================================================
# PARTY CONFIGURATION
# ============================================================================

## Party template ID to use for starting party
## References a PartyData resource by ID (e.g., "default_party")
## If empty, uses ModLoader.get_default_party() (is_hero + is_default_party_member)
## If specified, COMPLETELY REPLACES the default party resolution
@export var starting_party_id: String = ""

# ============================================================================
# CARAVAN STATE
# ============================================================================

## Whether the Caravan is unlocked at game start
## In SF2, the Caravan is acquired early in the game, not from the very beginning
## Set to false for authentic SF2 experience, true for testing or alternate starts
@export var caravan_unlocked: bool = false

# ============================================================================
# VALIDATION
# ============================================================================

## Validate that config is properly formed
## Returns true if valid, false if critical errors found
func validate() -> bool:
	var is_valid: bool = true

	if config_id.is_empty():
		push_error("NewGameConfigData: config_id is required")
		is_valid = false

	if config_name.is_empty():
		push_error("NewGameConfigData: config_name is required")
		is_valid = false

	# Warn about potentially missing items (non-fatal)
	for item_id: String in starting_depot_items:
		if ModLoader and ModLoader.registry:
			if not ModLoader.registry.has_resource("item", item_id):
				push_warning("NewGameConfigData '%s': Unknown item '%s' in starting_depot_items" % [config_id, item_id])

	# Warn about potentially missing party (non-fatal)
	if not starting_party_id.is_empty():
		if ModLoader and ModLoader.registry:
			if not ModLoader.registry.has_resource("party", starting_party_id):
				push_warning("NewGameConfigData '%s': Party '%s' not found" % [config_id, starting_party_id])

	return is_valid


## Get a summary string for debugging
func get_debug_summary() -> String:
	var summary: String = "NewGameConfigData '%s' (%s)\n" % [config_id, config_name]
	summary += "  Gold: %d\n" % starting_gold
	summary += "  Depot Items: %d\n" % starting_depot_items.size()
	summary += "  Story Flags: %d\n" % starting_story_flags.size()
	summary += "  Starting Scene: %s\n" % (starting_scene_path if not starting_scene_path.is_empty() else "(none)")
	summary += "  Party: %s\n" % (starting_party_id if not starting_party_id.is_empty() else "(default resolution)")
	summary += "  Caravan: %s\n" % ("unlocked" if caravan_unlocked else "locked")
	return summary
