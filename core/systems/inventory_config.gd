class_name InventoryConfig
extends RefCounted

## Configuration for character inventory system
##
## Allows mods to customize inventory behavior via mod.json:
## {
##   "inventory_config": {
##     "slots_per_character": 6,
##     "allow_duplicates": true
##   }
## }
##
## Default SF-style: 4 slots per character, duplicates allowed

## Default SF-style inventory (4 slots per character)
const DEFAULT_SLOTS_PER_CHARACTER: int = 4
const DEFAULT_ALLOW_DUPLICATES: bool = true

## Current configuration values
var slots_per_character: int = DEFAULT_SLOTS_PER_CHARACTER
var allow_duplicates: bool = DEFAULT_ALLOW_DUPLICATES

## Tracking which mod provided this configuration
var _source_mod: String = ""


## Load inventory config from mod manifest data
## Called by ModLoader when processing mod.json
func load_from_manifest(mod_id: String, config: Dictionary) -> void:
	if "slots_per_character" in config:
		var slots: Variant = config.slots_per_character
		if slots is int or slots is float:
			slots_per_character = maxi(1, int(slots))

	if "allow_duplicates" in config:
		var allow: Variant = config.allow_duplicates
		if allow is bool:
			allow_duplicates = allow

	_source_mod = mod_id
	print("InventoryConfig: Loaded from mod '%s' (%d slots, duplicates=%s)" % [
		mod_id,
		slots_per_character,
		str(allow_duplicates)
	])


## Get maximum inventory slots per character
func get_max_slots() -> int:
	return slots_per_character


## Check if duplicate items are allowed
func allows_duplicates() -> bool:
	return allow_duplicates


## Get which mod provided this configuration
func get_source_mod() -> String:
	if _source_mod.is_empty():
		return "base"
	return _source_mod


## Reset to defaults (called on mod reload)
func reset_to_defaults() -> void:
	slots_per_character = DEFAULT_SLOTS_PER_CHARACTER
	allow_duplicates = DEFAULT_ALLOW_DUPLICATES
	_source_mod = ""
