class_name EquipmentRegistry
extends RefCounted

## Registry for equipment types (weapons and armor).
## Allows mods to extend available equipment categories beyond the defaults.
##
## Default weapon types: sword, axe, lance, bow, staff, tome
## Default armor types: light, heavy, robe, shield
##
## Mods can register additional types via their mod.json:
## {
##   "equipment_types": {
##     "weapon_types": ["laser", "plasma"],
##     "armor_types": ["energy_shield", "power_armor"]
##   }
## }

## Emitted when registrations change (for editor refresh)
signal registrations_changed()

# Default types that are always available
const DEFAULT_WEAPON_TYPES: Array[String] = ["sword", "axe", "lance", "bow", "staff", "tome"]
const DEFAULT_ARMOR_TYPES: Array[String] = ["light", "heavy", "robe", "shield"]

# Registered types from mods (mod_id -> Array[String])
var _mod_weapon_types: Dictionary = {}
var _mod_armor_types: Dictionary = {}

# Cached merged arrays (rebuilt when mods change)
var _all_weapon_types: Array[String] = []
var _all_armor_types: Array[String] = []
var _cache_dirty: bool = true


## Register weapon types from a mod
## Only accepts string values - non-strings are logged as warnings and skipped
func register_weapon_types(mod_id: String, types: Array) -> void:
	var typed_array: Array[String] = []
	for t: Variant in types:
		# Validate that the type is a string - arrays/dicts produce garbage IDs
		if t is not String:
			push_warning("EquipmentRegistry: Mod '%s' provided non-string weapon type (got %s), skipping" % [mod_id, type_string(typeof(t))])
			continue
		var type_str: String = t.to_lower().strip_edges()
		if not type_str.is_empty():
			typed_array.append(type_str)

	if not typed_array.is_empty():
		_mod_weapon_types[mod_id] = typed_array
		_cache_dirty = true
		registrations_changed.emit()


## Register armor types from a mod
## Only accepts string values - non-strings are logged as warnings and skipped
func register_armor_types(mod_id: String, types: Array) -> void:
	var typed_array: Array[String] = []
	for t: Variant in types:
		# Validate that the type is a string - arrays/dicts produce garbage IDs
		if t is not String:
			push_warning("EquipmentRegistry: Mod '%s' provided non-string armor type (got %s), skipping" % [mod_id, type_string(typeof(t))])
			continue
		var type_str: String = t.to_lower().strip_edges()
		if not type_str.is_empty():
			typed_array.append(type_str)

	if not typed_array.is_empty():
		_mod_armor_types[mod_id] = typed_array
		_cache_dirty = true
		registrations_changed.emit()


## Unregister all types from a mod (called when mod is unloaded)
func unregister_mod(mod_id: String) -> void:
	var changed: bool = false
	if mod_id in _mod_weapon_types:
		_mod_weapon_types.erase(mod_id)
		changed = true
	if mod_id in _mod_armor_types:
		_mod_armor_types.erase(mod_id)
		changed = true
	if changed:
		_cache_dirty = true
		registrations_changed.emit()


## Clear all mod registrations (called on full mod reload)
func clear_mod_registrations() -> void:
	_mod_weapon_types.clear()
	_mod_armor_types.clear()
	_cache_dirty = true
	registrations_changed.emit()


## Get all available weapon types (defaults + mod-registered)
func get_weapon_types() -> Array[String]:
	_rebuild_cache_if_dirty()
	return _all_weapon_types.duplicate()


## Get all available armor types (defaults + mod-registered)
func get_armor_types() -> Array[String]:
	_rebuild_cache_if_dirty()
	return _all_armor_types.duplicate()


## Check if a weapon type is valid
func is_valid_weapon_type(weapon_type: String) -> bool:
	_rebuild_cache_if_dirty()
	return weapon_type.to_lower() in _all_weapon_types


## Check if an armor type is valid
func is_valid_armor_type(armor_type: String) -> bool:
	_rebuild_cache_if_dirty()
	return armor_type.to_lower() in _all_armor_types


## Get which mod registered a weapon type (or "base" for defaults)
func get_weapon_type_source(weapon_type: String) -> String:
	var lower_type: String = weapon_type.to_lower()
	if lower_type in DEFAULT_WEAPON_TYPES:
		return "base"
	for mod_id: String in _mod_weapon_types:
		var types: Array = _mod_weapon_types[mod_id]
		if lower_type in types:
			return mod_id
	return ""


## Get which mod registered an armor type (or "base" for defaults)
func get_armor_type_source(armor_type: String) -> String:
	var lower_type: String = armor_type.to_lower()
	if lower_type in DEFAULT_ARMOR_TYPES:
		return "base"
	for mod_id: String in _mod_armor_types:
		var types: Array = _mod_armor_types[mod_id]
		if lower_type in types:
			return mod_id
	return ""


## Get registration stats for debugging
func get_stats() -> Dictionary:
	_rebuild_cache_if_dirty()
	return {
		"weapon_type_count": _all_weapon_types.size(),
		"armor_type_count": _all_armor_types.size(),
		"weapon_types": _all_weapon_types.duplicate(),
		"armor_types": _all_armor_types.duplicate()
	}


## Rebuild the cached merged arrays
func _rebuild_cache_if_dirty() -> void:
	if not _cache_dirty:
		return

	# Use Dictionary for O(1) deduplication
	var weapon_set: Dictionary = {}
	var armor_set: Dictionary = {}
	
	# Start with defaults
	for weapon_type: String in DEFAULT_WEAPON_TYPES:
		weapon_set[weapon_type] = true
	for armor_type: String in DEFAULT_ARMOR_TYPES:
		armor_set[armor_type] = true

	# Add mod types (O(1) lookup for duplicates)
	for mod_id: String in _mod_weapon_types:
		var weapon_types: Array = _mod_weapon_types[mod_id]
		for weapon_type: String in weapon_types:
			weapon_set[weapon_type] = true

	for mod_id: String in _mod_armor_types:
		var armor_types: Array = _mod_armor_types[mod_id]
		for armor_type: String in armor_types:
			armor_set[armor_type] = true

	# Convert back to arrays
	_all_weapon_types.clear()
	for weapon_type: String in weapon_set.keys():
		_all_weapon_types.append(weapon_type)
	
	_all_armor_types.clear()
	for armor_type: String in armor_set.keys():
		_all_armor_types.append(armor_type)

	_cache_dirty = false
