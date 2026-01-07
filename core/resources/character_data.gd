class_name CharacterData
extends Resource

const SpriteUtils = preload("res://core/utils/sprite_utils.gd")

## Represents a single character/unit in the game.
## Contains all stats, appearance, and equipment information.
##
## Each character has a unique ID (character_uid) that is auto-generated
## at creation and remains immutable. Use this UID in dialogs and cinematics
## to reference characters by ID rather than name, allowing name changes
## without breaking references.

## Auto-generated unique identifier (8 alphanumeric characters)
## This is immutable once generated - do not modify after creation
@export var character_uid: String = ""


func _init() -> void:
	# Auto-generate UID for new resources
	# When loading from disk, the saved UID will overwrite this after _init()
	if character_uid.is_empty():
		character_uid = generate_uid()

@export var character_name: String = ""
@export var character_class: ClassData
@export_group("Stats")
@export var base_hp: int = 10
@export var base_mp: int = 5
@export var base_strength: int = 5
@export var base_defense: int = 5
@export var base_agility: int = 5
@export var base_intelligence: int = 5
@export var base_luck: int = 5

@export_group("Appearance")
@export var portrait: Texture2D
@export var sprite_frames: SpriteFrames  ## Animated sprite for map exploration AND tactical battle grid (SF2-authentic: same sprite used everywhere)
@export var combat_animation_data: CombatAnimationData  ## Combat screen animations (optional - uses placeholder if null)

@export_group("Starting Configuration")
@export var starting_level: int = 1
@export var starting_equipment: Array[ItemData] = []
## Starting inventory items (by item ID, e.g. "healing_herb")
## These are items the character carries but doesn't have equipped
@export var starting_inventory: Array[String] = []

@export_group("Unique Abilities")
## Character-specific unique abilities (EXCEPTIONS ONLY)
## Most spells come from ClassData.class_abilities, NOT here
## Use for: Domingo's innate Freeze, hero special powers, unique character skills
## that transcend their class definition
@export var unique_abilities: Array[AbilityData] = []

@export_group("Lore")
@export_multiline var biography: String = ""

@export_group("Battle Configuration")
## Category helps organize characters in the editor and determines default behavior
## "player" - Playable characters (heroes, party members)
## "enemy" - Enemy units (standard and boss enemies)
## "neutral" - Non-combatant or ally NPCs
@export_enum("player", "enemy", "neutral") var unit_category: String = "player"

## If true, this is a boss enemy - defensive AI will prioritize protecting this unit
## and threat calculations are boosted. Use for important enemies that should be
## guarded by their allies.
@export var is_boss: bool = false

## If false, this is a template that can be used multiple times in battles (like "Goblin")
## If true, this is a unique character that should only appear once (like "Max" or "Kane")
@export var is_unique: bool = true

## If true, this character is the primary Hero/protagonist
## Only one hero can exist per party/save slot
## The hero is always the first member of the player party
@export var is_hero: bool = false

## If true, this character is included in the default starting party
## Only applies to player-category characters
## The hero is always included regardless of this flag
@export var is_default_party_member: bool = false

## Default AI behavior for this unit when used as an enemy
## Assign an AIBehaviorData resource from mods/*/data/ai_behaviors/
## Can be overridden per-instance in BattleData
## Edit AI behaviors in the AI Behaviors editor (data-driven, no code required)
@export var default_ai_behavior: AIBehaviorData = null

@export_group("AI Threat Configuration")
## Multiplier applied to this character's calculated threat score.
## Boss enemies should have higher values (2.0+) to make AI prioritize protecting them.
## Fodder enemies might have lower values (0.5) to make AI deprioritize them.
## Default 1.0 = no modification.
@export var ai_threat_modifier: float = 1.0

## Tags that modify AI targeting behavior.
## Supported tags: "priority_target" (AI focuses this unit), "avoid" (AI ignores this unit)
## "vip" (for defensive AI to protect non-boss high-value targets)
## Mods can add custom tags and handle them in custom AIBrain scripts.
@export var ai_threat_tags: Array[String] = []


## Get base stat value by name
## Returns 0 if stat_name is not a valid stat property
func get_base_stat(stat_name: String) -> int:
	if stat_name in self:
		return get(stat_name)
	push_warning("CharacterData: Unknown stat name '%s'" % stat_name)
	return 0


## Validate that required fields are set
func validate() -> bool:
	if character_name.is_empty():
		push_error("CharacterData: character_name is required")
		return false
	if character_class == null:
		push_error("CharacterData: character_class is required")
		return false
	if starting_level < 1:
		push_error("CharacterData: starting_level must be at least 1")
		return false
	return true


## Ensure character has a UID, generating one if needed
## Call this when creating new characters or loading legacy characters without UIDs
func ensure_uid() -> void:
	if character_uid.is_empty():
		character_uid = generate_uid()


## Generate a new unique identifier (8 alphanumeric characters)
## Uses a combination of timestamp and random characters for uniqueness
static func generate_uid() -> String:
	const CHARS: String = "abcdefghjkmnpqrstuvwxyz23456789"  # Removed ambiguous: i, l, o, 0, 1
	const UID_LENGTH: int = 8

	# Seed with current time for additional entropy
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_usec()

	var uid: String = ""
	for i: int in range(UID_LENGTH):
		uid += CHARS[rng.randi() % CHARS.length()]

	return uid


## Check if this character has a valid UID
func has_valid_uid() -> bool:
	return not character_uid.is_empty() and character_uid.length() >= 6


## Get the character's unique identifier
## Ensures UID exists before returning (auto-generates if needed)
func get_uid() -> String:
	ensure_uid()
	return character_uid


## Get all available spells/abilities for this character at a given level
## Combines: ClassData.class_abilities (filtered by level) + unique_abilities
## This is the PRIMARY method to get a character's spell list
func get_available_abilities(level: int) -> Array[AbilityData]:
	var abilities: Array[AbilityData] = []

	# 1. Class abilities (primary source) - filtered by unlock level
	if character_class != null:
		abilities.append_array(character_class.get_unlocked_class_abilities(level))

	# 2. Character unique abilities (rare exceptions like Domingo's Freeze)
	abilities.append_array(unique_abilities)

	return abilities


## Check if this character has any spells/abilities available at a given level
func has_abilities(level: int) -> bool:
	return get_available_abilities(level).size() > 0


# ============================================================================
# SAFE ASSET GETTERS (with fallbacks)
# ============================================================================

## Placeholder texture for missing portraits (cached at class level)
static var _placeholder_portrait: Texture2D = null

## Get portrait texture with fallback for missing assets
## Returns a placeholder if portrait is null or fails to load
## Safe to call without null checks - always returns a valid Texture2D
func get_portrait_safe() -> Texture2D:
	if portrait != null:
		return portrait

	# Use cached placeholder
	if CharacterData._placeholder_portrait == null:
		CharacterData._placeholder_portrait = _create_placeholder_portrait()

	return CharacterData._placeholder_portrait


## Get a static texture from sprite_frames for UI contexts (thumbnails, etc.)
## Extracts first frame of walk_down animation, with fallbacks
## Safe to call without null checks - always returns a valid Texture2D
func get_display_texture() -> Texture2D:
	# Try sprite_frames first
	var sprite_texture: Texture2D = SpriteUtils.extract_texture_from_sprite_frames(sprite_frames)
	if sprite_texture:
		return sprite_texture

	# Fallback to portrait
	if portrait != null:
		return portrait

	# Ultimate fallback: placeholder
	if CharacterData._placeholder_portrait == null:
		CharacterData._placeholder_portrait = _create_placeholder_portrait()

	return CharacterData._placeholder_portrait


## Create a simple placeholder portrait (magenta square for visibility)
static func _create_placeholder_portrait() -> Texture2D:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	# Fill with magenta (missing texture indicator)
	img.fill(Color(1.0, 0.0, 1.0, 1.0))

	# Draw a simple "?" pattern in white
	for x: int in range(24, 40):
		for y: int in range(12, 20):  # Top of question mark
			img.set_pixel(x, y, Color.WHITE)
	for x: int in range(32, 40):
		for y: int in range(20, 36):  # Stem of question mark
			img.set_pixel(x, y, Color.WHITE)
	for x: int in range(32, 40):
		for y: int in range(44, 52):  # Dot of question mark
			img.set_pixel(x, y, Color.WHITE)

	return ImageTexture.create_from_image(img)
