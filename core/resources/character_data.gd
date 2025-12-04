class_name CharacterData
extends Resource

## Represents a single character/unit in the game.
## Contains all stats, appearance, and equipment information.
##
## Each character has a unique ID (character_uid) that is auto-generated
## at creation and remains immutable. Use this UID in dialogs and cinematics
## to reference characters by ID rather than name, allowing name changes
## without breaking references.

## Auto-generated unique identifier (6-8 alphanumeric characters)
## This is immutable once generated - do not modify after creation
@export var character_uid: String = ""

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
@export var battle_sprite: Texture2D  ## Map sprite used on battlefield
@export var combat_animation_data: CombatAnimationData  ## Combat screen animations (optional - uses placeholder if null)

@export_group("Starting Configuration")
@export var starting_level: int = 1
@export var starting_equipment: Array[ItemData] = []
## Starting inventory items (by item ID, e.g. "healing_herb")
## These are items the character carries but doesn't have equipped
@export var starting_inventory: Array[String] = []

@export_group("Lore")
@export_multiline var biography: String = ""

@export_group("Battle Configuration")
## Category helps organize characters in the editor and determines default behavior
## "player" - Playable characters (heroes, party members)
## "enemy" - Standard enemy units (can be spawned multiple times)
## "boss" - Unique boss enemies (usually spawned once)
## "neutral" - Non-combatant or ally NPCs
@export_enum("player", "enemy", "boss", "neutral") var unit_category: String = "player"

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
## Can be overridden in BattleData on a per-instance basis
@export var default_ai_brain: AIBrain = null


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
