class_name AIRoleRegistry
extends RefCounted

## Registry for AI tactical roles.
## Allows mods to define custom AI roles beyond the defaults.
##
## Default roles: support, aggressive, defensive, tactical
##
## Mods can register additional roles via their mod.json:
## {
##   "ai_roles": {
##     "hacking": {
##       "display_name": "Hacking",
##       "description": "Prioritizes disabling enemy systems",
##       "script_path": "ai_roles/hacking_role.gd"
##     }
##   }
## }
##
## Each role can optionally have an associated behavior script that implements
## AIRoleBehavior for custom target evaluation and action selection logic.

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when registrations change (for editor refresh)
signal registrations_changed()

# =============================================================================
# CONSTANTS
# =============================================================================

## Default roles that are always available
const DEFAULT_ROLES: Dictionary = {
	"support": {
		"display_name": "Support",
		"description": "Prioritize healing and buffing allies"
	},
	"aggressive": {
		"display_name": "Aggressive",
		"description": "Prioritize dealing damage, pursue enemies"
	},
	"defensive": {
		"display_name": "Defensive",
		"description": "Protect high-value targets, hold terrain"
	},
	"tactical": {
		"display_name": "Tactical",
		"description": "Complex spell usage, debuffs, positioning"
	}
}

## Maximum number of cached role instances
const MAX_CACHED_INSTANCES: int = 20

# =============================================================================
# DATA STORAGE
# =============================================================================

## Registered roles from mods: {role_id: {display_name, description, script_path, source_mod}}
var _mod_roles: Dictionary = {}

## Cached merged dictionary (rebuilt when mods change)
var _all_roles: Dictionary = {}
var _cache_dirty: bool = true

## Cached role behavior instances (lazy-loaded)
var _role_instances: Dictionary = {}

## LRU tracking for instance cache
var _lru_order: Array[String] = []

# =============================================================================
# REGISTRATION API
# =============================================================================

## Register AI roles from a mod's configuration
## @param mod_id: The mod registering these roles
## @param config: The ai_roles dictionary from mod.json
## @param mod_directory: The mod's base directory path
func register_from_config(mod_id: String, config: Dictionary, mod_directory: String) -> void:
	for role_id: String in config.keys():
		var role_data: Variant = config[role_id]
		if role_data is Dictionary:
			_register_role(mod_id, role_id, role_data, mod_directory)

	registrations_changed.emit()


## Register a single AI role
func _register_role(mod_id: String, role_id: String, data: Dictionary, mod_directory: String) -> void:
	var id_lower: String = role_id.to_lower().strip_edges()
	if id_lower.is_empty():
		push_error("AIRoleRegistry: Empty role ID from mod '%s'" % mod_id)
		return

	var display_name: String = str(data.get("display_name", role_id.capitalize()))
	var description: String = str(data.get("description", ""))
	var script_path: String = ""

	# Handle optional script path
	if "script_path" in data:
		var relative_path: String = str(data.script_path)
		script_path = mod_directory.path_join(relative_path)
		if not FileAccess.file_exists(script_path):
			push_warning("AIRoleRegistry: Role script not found at '%s' (declared by mod '%s')" % [script_path, mod_id])
			# Still register - the file might be added later

	# Check for override
	if id_lower in _mod_roles:
		var existing: Dictionary = _mod_roles[id_lower]
		push_warning("AIRoleRegistry: Mod '%s' overrides AI role '%s' (was from '%s')" % [
			mod_id, role_id, existing.get("source_mod", "unknown")
		])
		# Clear cached instance if overriding
		if id_lower in _role_instances:
			_role_instances.erase(id_lower)
			var lru_idx: int = _lru_order.find(id_lower)
			if lru_idx >= 0:
				_lru_order.remove_at(lru_idx)

	_mod_roles[id_lower] = {
		"id": id_lower,
		"display_name": display_name,
		"description": description,
		"script_path": script_path,
		"source_mod": mod_id
	}

	_cache_dirty = true


## Unregister all roles from a mod (called when mod is unloaded)
func unregister_mod(mod_id: String) -> void:
	var changed: bool = false
	var to_remove: Array[String] = []

	for role_id: String in _mod_roles.keys():
		if _mod_roles[role_id].get("source_mod") == mod_id:
			to_remove.append(role_id)

	for role_id: String in to_remove:
		_mod_roles.erase(role_id)
		if role_id in _role_instances:
			_role_instances.erase(role_id)
			var lru_idx: int = _lru_order.find(role_id)
			if lru_idx >= 0:
				_lru_order.remove_at(lru_idx)
		changed = true

	if changed:
		_cache_dirty = true
		registrations_changed.emit()


## Clear all mod registrations (called on full mod reload)
func clear_mod_registrations() -> void:
	_mod_roles.clear()
	_role_instances.clear()
	_lru_order.clear()
	_cache_dirty = true
	registrations_changed.emit()


# =============================================================================
# LOOKUP API
# =============================================================================

## Get all available role IDs (defaults + mod-registered)
func get_role_ids() -> Array[String]:
	_rebuild_cache_if_dirty()
	var result: Array[String] = []
	for role_id: String in _all_roles.keys():
		result.append(role_id)
	result.sort()
	return result


## Get all registered roles as dictionaries with metadata
## Returns: Array of {id, display_name, description, script_path, source_mod}
func get_all_roles() -> Array[Dictionary]:
	_rebuild_cache_if_dirty()
	var result: Array[Dictionary] = []
	for role_id: String in _all_roles.keys():
		result.append(_all_roles[role_id].duplicate())
	# Sort by display name for consistent UI ordering
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("display_name", "") < b.get("display_name", "")
	)
	return result


## Get a specific role's metadata
## Returns empty dictionary if not found
func get_role(role_id: String) -> Dictionary:
	_rebuild_cache_if_dirty()
	var lower: String = role_id.to_lower()
	if lower in _all_roles:
		return _all_roles[lower].duplicate()
	return {}


## Get the display name for a role
func get_display_name(role_id: String) -> String:
	_rebuild_cache_if_dirty()
	var lower: String = role_id.to_lower()
	if lower in _all_roles:
		return _all_roles[lower].get("display_name", role_id.capitalize())
	return role_id.capitalize()


## Get the description for a role
func get_description(role_id: String) -> String:
	_rebuild_cache_if_dirty()
	var lower: String = role_id.to_lower()
	if lower in _all_roles:
		return _all_roles[lower].get("description", "")
	return ""


## Check if a role is valid
func is_valid_role(role_id: String) -> bool:
	_rebuild_cache_if_dirty()
	return role_id.to_lower() in _all_roles


## Check if a role is one of the built-in defaults
func is_default_role(role_id: String) -> bool:
	return role_id.to_lower() in DEFAULT_ROLES


## Get which mod registered a role (or "base" for defaults)
func get_role_source(role_id: String) -> String:
	var lower: String = role_id.to_lower()
	if lower in DEFAULT_ROLES and lower not in _mod_roles:
		return "base"
	if lower in _mod_roles:
		return _mod_roles[lower].get("source_mod", "")
	return ""


## Get the script path for a role (empty if no custom script)
func get_role_script_path(role_id: String) -> String:
	_rebuild_cache_if_dirty()
	var lower: String = role_id.to_lower()
	if lower in _all_roles:
		return _all_roles[lower].get("script_path", "")
	return ""


## Get an instance of the role behavior script
## Returns null if role has no script or failed to load
func get_role_instance(role_id: String) -> RefCounted:
	var lower: String = role_id.to_lower()

	# Return cached instance if available (and update LRU order)
	if lower in _role_instances:
		_update_lru_access(lower)
		return _role_instances[lower]

	# Get script path
	var script_path: String = get_role_script_path(lower)
	if script_path.is_empty():
		return null

	# Try to load and instantiate
	var script: GDScript = load(script_path) as GDScript
	if not script:
		push_warning("AIRoleRegistry: Failed to load role script: %s" % script_path)
		return null

	var instance: RefCounted = script.new()
	if not instance:
		push_warning("AIRoleRegistry: Failed to instantiate role: %s" % script_path)
		return null

	# Evict LRU entries if cache is full before adding new instance
	_evict_lru_if_needed()

	_role_instances[lower] = instance
	_lru_order.append(lower)
	return instance


# =============================================================================
# INTERNAL HELPERS
# =============================================================================

## Rebuild the cached merged dictionary
func _rebuild_cache_if_dirty() -> void:
	if not _cache_dirty:
		return

	# Start with defaults
	_all_roles.clear()
	for role_id: String in DEFAULT_ROLES.keys():
		_all_roles[role_id] = {
			"id": role_id,
			"display_name": DEFAULT_ROLES[role_id].display_name,
			"description": DEFAULT_ROLES[role_id].description,
			"script_path": "",
			"source_mod": "base"
		}

	# Add/override with mod roles
	for role_id: String in _mod_roles.keys():
		_all_roles[role_id] = _mod_roles[role_id].duplicate()

	_cache_dirty = false


## Update LRU tracking when an instance is accessed
func _update_lru_access(role_id: String) -> void:
	var idx: int = _lru_order.find(role_id)
	if idx >= 0:
		_lru_order.remove_at(idx)
	_lru_order.append(role_id)


## Evict least recently used cache entries if at capacity
func _evict_lru_if_needed() -> void:
	while _role_instances.size() >= MAX_CACHED_INSTANCES and _lru_order.size() > 0:
		var lru_id: String = _lru_order[0]
		_lru_order.remove_at(0)
		if lru_id in _role_instances:
			_role_instances.erase(lru_id)


# =============================================================================
# UTILITY API
# =============================================================================

## Get registration counts for debugging
func get_stats() -> Dictionary:
	_rebuild_cache_if_dirty()
	return {
		"role_count": _all_roles.size(),
		"mod_role_count": _mod_roles.size(),
		"cached_instances": _role_instances.size()
	}
