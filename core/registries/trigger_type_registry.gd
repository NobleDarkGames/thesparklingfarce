class_name TriggerTypeRegistry
extends RefCounted

## Registry for trigger types.
## Allows mods to extend available trigger types beyond the defaults.
##
## Default trigger types: battle, dialog, chest, door, cutscene, transition
##
## Mods can register additional types via their mod.json:
## {
##   "custom_trigger_types": ["puzzle", "minigame", "shop"]
## }
##
## Or programmatically:
##   ModLoader.trigger_type_registry.register_trigger_types("my_mod", ["puzzle", "minigame"])

## Emitted when registrations change (for editor refresh)
signal registrations_changed()

# Default types that are always available (matching the original enum)
const DEFAULT_TRIGGER_TYPES: Array[String] = [
	"battle",
	"dialog",
	"chest",
	"door",
	"cutscene",
	"transition",
	"custom"  # Generic fallback for unregistered types
]

# Registered types from mods (mod_id -> Array[String])
var _mod_trigger_types: Dictionary = {}

# Registered trigger scripts (trigger_type -> script_path)
# Allows mods to provide custom handlers for their trigger types
var _trigger_scripts: Dictionary = {}

# Cached merged array (rebuilt when mods change)
var _all_trigger_types: Array[String] = []
var _cache_dirty: bool = true


## Register trigger types from a mod
func register_trigger_types(mod_id: String, types: Array) -> void:
	var typed_array: Array[String] = []
	for t: Variant in types:
		var type_str: String = str(t).to_lower().strip_edges()
		if not type_str.is_empty():
			typed_array.append(type_str)

	if not typed_array.is_empty():
		_mod_trigger_types[mod_id] = typed_array
		_cache_dirty = true
		registrations_changed.emit()


## Register a trigger script for a specific trigger type
## This allows mods to provide custom behavior classes for their trigger types
func register_trigger_script(trigger_type: String, script_path: String, mod_id: String) -> void:
	var type_lower: String = trigger_type.to_lower()
	_trigger_scripts[type_lower] = {
		"path": script_path,
		"mod_id": mod_id
	}
	registrations_changed.emit()


## Unregister all types from a mod (called when mod is unloaded)
func unregister_mod(mod_id: String) -> void:
	var changed: bool = false
	if mod_id in _mod_trigger_types:
		_mod_trigger_types.erase(mod_id)
		changed = true

	# Also remove any trigger scripts from this mod
	var scripts_to_remove: Array[String] = []
	for trigger_type: String in _trigger_scripts:
		var script_entry: Dictionary = _trigger_scripts[trigger_type]
		if script_entry.get("mod_id", "") == mod_id:
			scripts_to_remove.append(trigger_type)

	for trigger_type: String in scripts_to_remove:
		_trigger_scripts.erase(trigger_type)

	if changed:
		_cache_dirty = true
		registrations_changed.emit()


## Clear all mod registrations (called on full mod reload)
func clear_mod_registrations() -> void:
	_mod_trigger_types.clear()
	_trigger_scripts.clear()
	_cache_dirty = true
	registrations_changed.emit()


## Get all available trigger types (defaults + mod-registered)
func get_trigger_types() -> Array[String]:
	_rebuild_cache_if_dirty()
	return _all_trigger_types.duplicate()


## Check if a trigger type is valid
func is_valid_trigger_type(trigger_type: String) -> bool:
	_rebuild_cache_if_dirty()
	return trigger_type.to_lower() in _all_trigger_types


## Get which mod registered a trigger type (or "base" for defaults)
func get_trigger_type_source(trigger_type: String) -> String:
	var lower_type: String = trigger_type.to_lower()
	if lower_type in DEFAULT_TRIGGER_TYPES:
		return "base"
	for mod_id: String in _mod_trigger_types:
		if lower_type in _mod_trigger_types[mod_id]:
			return mod_id
	return ""


## Get the script path for a trigger type (if one is registered)
func get_trigger_script_path(trigger_type: String) -> String:
	var lower_type: String = trigger_type.to_lower()
	if lower_type in _trigger_scripts:
		return _trigger_scripts[lower_type].get("path", "")
	return ""


## Get all registered trigger scripts
func get_all_trigger_scripts() -> Dictionary:
	return _trigger_scripts.duplicate()


## Rebuild the cached merged array
func _rebuild_cache_if_dirty() -> void:
	if not _cache_dirty:
		return

	# Start with defaults
	_all_trigger_types = DEFAULT_TRIGGER_TYPES.duplicate()

	# Add mod types (avoiding duplicates)
	for mod_id: String in _mod_trigger_types:
		for trigger_type: String in _mod_trigger_types[mod_id]:
			if trigger_type not in _all_trigger_types:
				_all_trigger_types.append(trigger_type)

	_cache_dirty = false
