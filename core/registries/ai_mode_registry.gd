class_name AIModeRegistry
extends RefCounted

## Registry for AI behavior modes.
## Allows mods to define custom AI modes beyond the defaults.
##
## Default modes: aggressive, cautious, opportunistic
##
## Mods can register additional modes via their mod.json:
## {
##   "ai_modes": {
##     "berserk": {
##       "display_name": "Berserk",
##       "description": "Maximum aggression, ignores self-preservation"
##     },
##     "protective": {
##       "display_name": "Protective",
##       "description": "Stays near designated allies, intercepts threats"
##     }
##   }
## }
##
## Modes modify HOW a role executes, not WHAT it prioritizes.
## Role = what (heal vs attack), Mode = how (carefully vs aggressively)

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when registrations change (for editor refresh)
signal registrations_changed()

# =============================================================================
# CONSTANTS
# =============================================================================

## Default modes that are always available
const DEFAULT_MODES: Dictionary = {
	"aggressive": {
		"display_name": "Aggressive",
		"description": "Full commitment, chase targets, take risks"
	},
	"cautious": {
		"display_name": "Cautious",
		"description": "Hold terrain, wait for engagement, self-preservation"
	},
	"opportunistic": {
		"display_name": "Opportunistic",
		"description": "Target wounded units, retreat when threatened"
	}
}

# =============================================================================
# DATA STORAGE
# =============================================================================

## Registered modes from mods: {mode_id: {display_name, description, source_mod}}
var _mod_modes: Dictionary = {}

## Cached merged dictionary (rebuilt when mods change)
var _all_modes: Dictionary = {}
var _cache_dirty: bool = true

# =============================================================================
# REGISTRATION API
# =============================================================================

## Register AI modes from a mod's configuration
## @param mod_id: The mod registering these modes
## @param config: The ai_modes dictionary from mod.json
func register_from_config(mod_id: String, config: Dictionary) -> void:
	for mode_id: String in config.keys():
		var mode_data: Variant = config[mode_id]
		if mode_data is Dictionary:
			_register_mode(mod_id, mode_id, mode_data)

	registrations_changed.emit()


## Register a single AI mode
func _register_mode(mod_id: String, mode_id: String, data: Dictionary) -> void:
	var id_lower: String = mode_id.to_lower().strip_edges()
	if id_lower.is_empty():
		push_error("AIModeRegistry: Empty mode ID from mod '%s'" % mod_id)
		return

	var display_name: String = str(data.get("display_name", mode_id.capitalize()))
	var description: String = str(data.get("description", ""))

	# Check for override
	if id_lower in _mod_modes:
		var existing: Dictionary = _mod_modes[id_lower]
		push_warning("AIModeRegistry: Mod '%s' overrides AI mode '%s' (was from '%s')" % [
			mod_id, mode_id, existing.get("source_mod", "unknown")
		])

	_mod_modes[id_lower] = {
		"id": id_lower,
		"display_name": display_name,
		"description": description,
		"source_mod": mod_id
	}

	_cache_dirty = true


## Unregister all modes from a mod (called when mod is unloaded)
func unregister_mod(mod_id: String) -> void:
	var changed: bool = false
	var to_remove: Array[String] = []

	for mode_id: String in _mod_modes.keys():
		var mode_entry: Dictionary = _mod_modes[mode_id]
		if mode_entry.get("source_mod") == mod_id:
			to_remove.append(mode_id)

	for mode_id: String in to_remove:
		_mod_modes.erase(mode_id)
		changed = true

	if changed:
		_cache_dirty = true
		registrations_changed.emit()


## Clear all mod registrations (called on full mod reload)
func clear_mod_registrations() -> void:
	_mod_modes.clear()
	_cache_dirty = true
	registrations_changed.emit()


# =============================================================================
# LOOKUP API
# =============================================================================

## Get all available mode IDs (defaults + mod-registered)
func get_mode_ids() -> Array[String]:
	_rebuild_cache_if_dirty()
	var result: Array[String] = []
	for mode_id: String in _all_modes.keys():
		result.append(mode_id)
	result.sort()
	return result


## Get all registered modes as dictionaries with metadata
## Returns: Array of {id, display_name, description, source_mod}
func get_all_modes() -> Array[Dictionary]:
	_rebuild_cache_if_dirty()
	var result: Array[Dictionary] = []
	for mode_id: String in _all_modes.keys():
		var entry: Dictionary = _all_modes[mode_id]
		result.append(entry.duplicate())
	# Sort by display name for consistent UI ordering
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("display_name", "") < b.get("display_name", "")
	)
	return result


## Get a specific mode's metadata
## Returns empty dictionary if not found
func get_mode(mode_id: String) -> Dictionary:
	_rebuild_cache_if_dirty()
	var lower: String = mode_id.to_lower()
	if lower in _all_modes:
		var entry: Dictionary = _all_modes[lower]
		return entry.duplicate()
	return {}


## Get the display name for a mode
func get_display_name(mode_id: String) -> String:
	_rebuild_cache_if_dirty()
	var lower: String = mode_id.to_lower()
	if lower in _all_modes:
		var entry: Dictionary = _all_modes[lower]
		return entry.get("display_name", mode_id.capitalize())
	return mode_id.capitalize()


## Get the description for a mode
func get_description(mode_id: String) -> String:
	_rebuild_cache_if_dirty()
	var lower: String = mode_id.to_lower()
	if lower in _all_modes:
		var entry: Dictionary = _all_modes[lower]
		return entry.get("description", "")
	return ""


## Check if a mode is valid
func is_valid_mode(mode_id: String) -> bool:
	_rebuild_cache_if_dirty()
	return mode_id.to_lower() in _all_modes


## Check if a mode is one of the built-in defaults
func is_default_mode(mode_id: String) -> bool:
	return mode_id.to_lower() in DEFAULT_MODES


## Get which mod registered a mode (or "base" for defaults)
func get_mode_source(mode_id: String) -> String:
	var lower: String = mode_id.to_lower()
	if lower in DEFAULT_MODES and lower not in _mod_modes:
		return "base"
	if lower in _mod_modes:
		var entry: Dictionary = _mod_modes[lower]
		return entry.get("source_mod", "")
	return ""


# =============================================================================
# INTERNAL HELPERS
# =============================================================================

## Rebuild the cached merged dictionary
func _rebuild_cache_if_dirty() -> void:
	if not _cache_dirty:
		return

	# Start with defaults
	_all_modes.clear()
	for mode_id: String in DEFAULT_MODES.keys():
		var mode_data: Dictionary = DEFAULT_MODES[mode_id]
		var display_name: String = mode_data.get("display_name", "")
		var description: String = mode_data.get("description", "")
		_all_modes[mode_id] = {
			"id": mode_id,
			"display_name": display_name,
			"description": description,
			"source_mod": "base"
		}

	# Add/override with mod modes
	for mode_id: String in _mod_modes.keys():
		var entry: Dictionary = _mod_modes[mode_id]
		_all_modes[mode_id] = entry.duplicate()

	_cache_dirty = false


# =============================================================================
# UTILITY API
# =============================================================================

## Get registration counts for debugging
func get_stats() -> Dictionary:
	_rebuild_cache_if_dirty()
	return {
		"mode_count": _all_modes.size(),
		"mod_mode_count": _mod_modes.size()
	}
