class_name NPCData
extends Resource

## Represents an NPC that can be interacted with on maps.
## NPCs trigger cinematics when the player interacts with them.
##
## THE KEY UNIFICATION: Dialog IS a cinematic.
## Instead of directly referencing dialog resources, NPCs reference cinematics.
## The cinematic can contain dialog, movement, camera effects, or any combination.
## This gives designers full control over what happens when you talk to an NPC.
##
## CONDITIONAL DIALOGS:
## NPCs can have different responses based on game state (story flags).
## Use conditional_cinematics to define priority-ordered conditions.
## The first matching condition's cinematic plays; if none match, use fallback.
##
## Example conditional setup:
## - conditional_cinematics: [
##     { "flag": "rescued_princess", "cinematic_id": "elder_thanks" },
##     { "flag": "chapter_2_started", "cinematic_id": "elder_hint" }
##   ]
## - fallback_cinematic_id: "elder_greeting"
##
## If "rescued_princess" is set, plays "elder_thanks".
## Else if "chapter_2_started" is set, plays "elder_hint".
## Otherwise plays "elder_greeting".

## Unique identifier for this NPC (used in mod registry)
@export var npc_id: String = ""

## Display name shown in dialogs and UI
@export var npc_name: String = ""

## Character data for portrait and sprite (optional)
## If set, the NPC's portrait and sprite come from this character.
## If null, use the fallback portrait/sprite exports below.
@export var character_data: CharacterData

@export_group("Appearance (Fallback)")
## Portrait to show in dialogs (used if character_data is null)
@export var portrait: Texture2D
## Sprite for map display (used if character_data is null)
@export var map_sprite: Texture2D

@export_group("Interaction - Primary")
## The cinematic to play when player interacts (simple case)
## For conditional dialogs, leave this empty and use conditional_cinematics
@export var interaction_cinematic_id: String = ""

## Fallback cinematic if no conditions match (or for very simple NPCs)
@export var fallback_cinematic_id: String = ""

@export_group("Interaction - Conditional")
## Priority-ordered array of conditional cinematics
## Each entry is a Dictionary with:
##   - "flag": String (the GameState flag to check)
##   - "cinematic_id": String (the cinematic to play if flag is set)
##   - "negate": bool (optional, if true, triggers when flag is NOT set)
##
## Conditions are checked in order; first match wins.
## If no conditions match, fallback_cinematic_id is used.
@export var conditional_cinematics: Array[Dictionary] = []

@export_group("Behavior")
## If true, NPC turns to face player when interaction starts
@export var face_player_on_interact: bool = true

## Grid offset for facing (defaults to player position)
## Can be overridden for NPCs that should face a specific direction
@export var facing_override: String = ""  # "up", "down", "left", "right", or "" for auto


## Get the appropriate cinematic ID based on current game state
## Checks conditional_cinematics in order, returns first match
## Falls back to interaction_cinematic_id, then fallback_cinematic_id
func get_cinematic_id_for_state() -> String:
	# Check conditional cinematics in priority order
	for condition: Dictionary in conditional_cinematics:
		var flag_name: String = condition.get("flag", "")
		var cinematic_id: String = condition.get("cinematic_id", "")
		var negate: bool = condition.get("negate", false)

		if flag_name.is_empty() or cinematic_id.is_empty():
			continue

		var flag_set: bool = GameState.has_flag(flag_name)

		# Check if condition is met (considering negation)
		if (flag_set and not negate) or (not flag_set and negate):
			return cinematic_id

	# No conditions matched - use primary cinematic
	if not interaction_cinematic_id.is_empty():
		return interaction_cinematic_id

	# Last resort - use fallback
	return fallback_cinematic_id


## Get the display name for this NPC
## Uses character_data.character_name if available, otherwise npc_name
func get_display_name() -> String:
	if character_data and not character_data.character_name.is_empty():
		return character_data.character_name
	return npc_name


## Get the portrait texture for this NPC
## Uses character_data.portrait if available, otherwise the fallback portrait
func get_portrait() -> Texture2D:
	if character_data and character_data.portrait:
		return character_data.portrait
	return portrait


## Get the map sprite texture for this NPC
## Uses character_data.get_display_texture() if available, otherwise the fallback map_sprite
func get_map_sprite() -> Texture2D:
	if character_data:
		return character_data.get_display_texture()
	return map_sprite


## Validate that required fields are set
func validate() -> bool:
	if npc_id.is_empty():
		push_error("NPCData: npc_id is required")
		return false

	# Must have at least one way to respond to interaction
	var has_response: bool = (
		not interaction_cinematic_id.is_empty() or
		not fallback_cinematic_id.is_empty() or
		not conditional_cinematics.is_empty()
	)

	if not has_response:
		push_error("NPCData: NPC must have at least one cinematic defined")
		return false

	return true
