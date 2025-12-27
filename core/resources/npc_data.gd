class_name NPCData
extends Resource

const SpriteUtils: GDScript = preload("res://core/utils/sprite_utils.gd")

## Represents an NPC that can be interacted with on maps.
## NPCs trigger cinematics when the player interacts with them.
##
## THE KEY UNIFICATION: Dialog IS a cinematic.
## Instead of directly referencing dialog resources, NPCs reference cinematics.
## The cinematic can contain dialog, movement, camera effects, or any combination.
## This gives designers full control over what happens when you talk to an NPC.
##
## QUICK SETUP (NEW):
## For simple shop/church NPCs, set npc_role and shop_id instead of manually
## creating cinematics. The system auto-generates: greeting -> open_shop -> farewell
## Example: Set role=PRIEST, shop_id="granseal_church", done!
##
## CONDITIONAL DIALOGS:
## NPCs can have different responses based on game state (story flags).
## Use conditional_cinematics to define priority-ordered conditions.
## The first matching condition's cinematic plays; if none match, use fallback.
##
## Supported condition formats:
##   - "flag": String (legacy single flag - still supported)
##   - "flags": Array[String] (AND logic - ALL must be true)
##   - "any_flags": Array[String] (OR logic - at least ONE must be true)
##   - "negate": bool (optional - inverts the overall result)
##
## Example conditional setup:
## - conditional_cinematics: [
##     { "flag": "rescued_princess", "cinematic_id": "elder_thanks" },
##     { "flags": ["chapter_2", "talked_to_king"], "cinematic_id": "elder_quest" },
##     { "any_flags": ["saved_village", "saved_castle"], "cinematic_id": "elder_praise" },
##     { "flags": ["chapter_3"], "any_flags": ["hero_a_joined", "hero_b_joined"], "cinematic_id": "elder_advice" }
##   ]
## - fallback_cinematic_id: "elder_greeting"
##
## Conditions are checked in order. First match wins.

## NPC Role for Quick Setup - simplifies shop/service NPC creation
enum NPCRole {
	NONE,           ## Standard NPC - uses manual cinematic configuration
	SHOPKEEPER,     ## Opens a weapon or item shop
	PRIEST,         ## Opens a church (healing, revival, etc.)
	INNKEEPER,      ## Opens an inn (rest/save)
	CARAVAN_DEPOT,  ## Opens the caravan storage interface
	CRAFTER         ## Opens a crafting shop (mithril forge, enchanter, etc.)
}

## Unique identifier for this NPC (used in mod registry)
@export var npc_id: String = ""

## Display name shown in dialogs and UI
@export var npc_name: String = ""

@export_group("Quick Setup")
## NPC's role - set this for automatic shop/service behavior
## When role != NONE and shop_id is set, cinematics are auto-generated
@export var npc_role: NPCRole = NPCRole.NONE

## Shop/service to open when interacting (requires npc_role != NONE)
## For CARAVAN_DEPOT, leave empty - it opens the caravan interface directly
@export var shop_id: String = ""

## Custom greeting text (optional - uses role-specific default if empty)
## Shopkeeper default: "Welcome to my shop!"
## Priest default: "Welcome, weary traveler. How may I serve you?"
## Innkeeper default: "Welcome, traveler. Looking for a place to rest?"
@export_multiline var greeting_text: String = ""

## Custom farewell text (optional - uses role-specific default if empty)
## Shopkeeper default: "Come again!"
## Priest default: "May light guide your path..."
## Innkeeper default: "Rest well!"
@export_multiline var farewell_text: String = ""

## Character data for portrait and sprite (optional)
## If set, the NPC's portrait and sprite come from this character.
## If null, use the fallback portrait/sprite exports below.
@export var character_data: CharacterData

@export_group("Appearance (Fallback)")
## Portrait to show in dialogs (used if character_data is null)
@export var portrait: Texture2D
## Animated sprite frames for map display (used if character_data is null)
## SF2-authentic: should contain walk_up, walk_down, walk_left, walk_right animations
@export var sprite_frames: SpriteFrames

@export_group("Interaction - Primary")
## The cinematic to play when player interacts (simple case)
## For conditional dialogs, leave this empty and use conditional_cinematics
@export var interaction_cinematic_id: String = ""

## Fallback cinematic if no conditions match (or for very simple NPCs)
@export var fallback_cinematic_id: String = ""

@export_group("Interaction - Conditional")
## Priority-ordered array of conditional cinematics
## Each entry is a Dictionary with:
##   - "flag": String (legacy single flag - still supported for backward compatibility)
##   - "flags": Array[String] (AND logic - ALL flags must be true)
##   - "any_flags": Array[String] (OR logic - at least ONE flag must be true)
##   - "cinematic_id": String (the cinematic to play if condition is met)
##   - "negate": bool (optional, applies to the OVERALL result of the condition)
##
## You can combine "flags" and "any_flags" - both conditions must pass.
## Example: {"flags": ["chapter_2"], "any_flags": ["saved_princess", "saved_prince"], "cinematic_id": "thanks"}
## This triggers when chapter_2 is set AND (saved_princess OR saved_prince) is set.
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
## Finally, if NPC role is set, returns auto-generated cinematic ID
func get_cinematic_id_for_state() -> String:
	# Check conditional cinematics in priority order
	for condition: Dictionary in conditional_cinematics:
		var cinematic_id: String = DictUtils.get_string(condition, "cinematic_id", "")
		if cinematic_id.is_empty():
			continue

		var condition_met: bool = _evaluate_condition(condition)
		if condition_met:
			return cinematic_id

	# No conditions matched - use primary cinematic (explicit takes precedence)
	if not interaction_cinematic_id.is_empty():
		return interaction_cinematic_id

	# Check for Quick Setup auto-generation
	# Only triggers when: role is set AND no explicit cinematic is defined
	if npc_role != NPCRole.NONE:
		# CARAVAN_DEPOT doesn't need a shop_id, others do
		if npc_role == NPCRole.CARAVAN_DEPOT or not shop_id.is_empty():
			return _get_auto_cinematic_id()

	# Last resort - use fallback
	return fallback_cinematic_id


## Evaluate a single condition entry from conditional_cinematics
## Supports legacy "flag" key, "flags" array (AND), and "any_flags" array (OR)
## Returns true if the condition is met (after applying negate if present)
func _evaluate_condition(condition: Dictionary) -> bool:
	var negate: bool = DictUtils.get_bool(condition, "negate", false)

	# Track whether we have any conditions to check
	var has_any_condition: bool = false
	var all_conditions_pass: bool = true

	# Legacy single flag support (backward compatibility)
	var single_flag: String = DictUtils.get_string(condition, "flag", "")
	if not single_flag.is_empty():
		has_any_condition = true
		if not GameState.has_flag(single_flag):
			all_conditions_pass = false

	# AND logic: all flags in "flags" array must be true
	var and_flags: Array = DictUtils.get_array(condition, "flags", [])
	if not and_flags.is_empty():
		has_any_condition = true
		for flag_variant: Variant in and_flags:
			var flag_name: String = str(flag_variant) if flag_variant is String else ""
			if not flag_name.is_empty() and not GameState.has_flag(flag_name):
				all_conditions_pass = false
				break

	# OR logic: at least one flag in "any_flags" array must be true
	var or_flags: Array = DictUtils.get_array(condition, "any_flags", [])
	if not or_flags.is_empty():
		has_any_condition = true
		var any_or_flag_set: bool = false
		for flag_variant: Variant in or_flags:
			var flag_name: String = str(flag_variant) if flag_variant is String else ""
			if not flag_name.is_empty() and GameState.has_flag(flag_name):
				any_or_flag_set = true
				break
		if not any_or_flag_set:
			all_conditions_pass = false

	# If no conditions were specified, the condition is not met
	if not has_any_condition:
		return false

	# Apply negation to the overall result
	var result: bool = all_conditions_pass
	if negate:
		result = not result

	return result


## Generate auto-cinematic ID for Quick Setup NPCs
## Format: __auto__{npc_id}::{shop_id} (parsed by CinematicsManager)
## Uses :: delimiter to avoid conflicts with underscores in IDs
func _get_auto_cinematic_id() -> String:
	var effective_shop_id: String = shop_id if not shop_id.is_empty() else "caravan"
	return "__auto__%s::%s" % [npc_id, effective_shop_id]


## Check if this NPC uses Quick Setup (role-based auto-cinematics)
func uses_quick_setup() -> bool:
	if npc_role == NPCRole.NONE:
		return false
	# Must have shop_id set (except for CARAVAN_DEPOT which doesn't need one)
	if npc_role == NPCRole.CARAVAN_DEPOT:
		return true
	return not shop_id.is_empty()


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


## Get the sprite frames for this NPC (animated directional sprites)
## Priority: character_data.sprite_frames > sprite_frames > null
func get_sprite_frames() -> SpriteFrames:
	if character_data and character_data.sprite_frames:
		return character_data.sprite_frames
	return sprite_frames


## Get a static texture for this NPC (for UI previews, etc.)
## Priority: character_data.get_display_texture() > extract from sprite_frames
func get_map_sprite() -> Texture2D:
	if character_data:
		return character_data.get_display_texture()
	# Extract first frame from sprite_frames if available
	return SpriteUtils.extract_texture_from_sprite_frames(sprite_frames)


## Validate that required fields are set
func validate() -> bool:
	if npc_id.is_empty():
		push_error("NPCData: npc_id is required")
		return false

	# Must have at least one way to respond to interaction
	# This includes: explicit cinematics OR Quick Setup role configuration
	var has_response: bool = (
		not interaction_cinematic_id.is_empty() or
		not fallback_cinematic_id.is_empty() or
		not conditional_cinematics.is_empty() or
		uses_quick_setup()
	)

	if not has_response:
		push_error("NPCData: NPC must have at least one cinematic defined or use Quick Setup")
		return false

	return true
