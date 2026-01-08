class_name AIBrainRegistry
extends RefCounted

## Registry for AI brain declarations from mod manifests
##
## Instead of scanning directories at runtime, mods declare their AI brains
## in mod.json. This provides:
## - Display names and descriptions for editor dropdowns
## - Proper mod attribution and override tracking
## - Total conversion support (mods can hide/replace brains from other mods)
##
## mod.json schema:
## {
##   "ai_brains": {
##     "aggressive": {
##       "path": "ai_brains/ai_aggressive.gd",
##       "display_name": "Aggressive",
##       "description": "Always moves toward and attacks nearest enemy"
##     },
##     "defensive": {
##       "path": "ai_brains/ai_defensive.gd",
##       "display_name": "Defensive",
##       "description": "Prioritizes healing allies and staying near them"
##     }
##   }
## }
##
## For backwards compatibility, also discovers AI brains from ai_brains/
## directories that aren't explicitly declared in mod.json.

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when registrations change (for editor refresh)
signal registrations_changed()

# =============================================================================
# CONSTANTS
# =============================================================================

## Maximum number of cached brain instances to prevent unbounded memory growth
## When this limit is exceeded, least recently used instances are evicted
const MAX_CACHED_INSTANCES: int = 50

# =============================================================================
# DATA STORAGE
# =============================================================================

## Registered AI brains: {brain_id: {path, display_name, description, source_mod, resource}}
var _brains: Dictionary = {}

## Cached brain instances (lazy-loaded)
var _brain_instances: Dictionary = {}

## LRU tracking: Array of brain_ids in order of access (most recent at end)
## Used to evict least recently used entries when cache exceeds MAX_CACHED_INSTANCES
var _lru_order: Array[String] = []

## Cached sorted brain metadata for editor performance
var _cached_all_brains: Array[Dictionary] = []
var _cache_dirty: bool = true

# =============================================================================
# REGISTRATION API
# =============================================================================

## Register AI brains from a mod's configuration
## @param mod_id: The mod registering these brains
## @param config: The ai_brains dictionary from mod.json
## @param mod_directory: The mod's base directory path
func register_from_config(mod_id: String, config: Dictionary, mod_directory: String) -> void:
	for brain_id: String in config.keys():
		var brain_data: Variant = config[brain_id]
		if brain_data is Dictionary:
			_register_brain(mod_id, brain_id, brain_data, mod_directory)

	_cache_dirty = true
	registrations_changed.emit()


## Register a single AI brain
func _register_brain(mod_id: String, brain_id: String, data: Dictionary, mod_directory: String) -> void:
	var id_lower: String = brain_id.to_lower().strip_edges()
	if id_lower.is_empty():
		push_error("AIBrainRegistry: Empty brain ID from mod '%s'" % mod_id)
		return

	# Get the path (required)
	if "path" not in data:
		push_error("AIBrainRegistry: Brain '%s' from mod '%s' missing required 'path'" % [brain_id, mod_id])
		return

	var relative_path: String = str(data.path)
	var full_path: String = mod_directory.path_join(relative_path)

	# Verify the file exists - use ResourceLoader.exists() for export compatibility
	if not ResourceLoader.exists(full_path):
		push_warning("AIBrainRegistry: Brain script not found at '%s' (declared by mod '%s')" % [full_path, mod_id])
		# Still register it - the file might be added later

	# Check for override
	if id_lower in _brains:
		var existing: Dictionary = _brains[id_lower]
		push_warning("AIBrainRegistry: Mod '%s' overrides AI brain '%s' (was from '%s')" % [
			mod_id, brain_id, existing.get("source_mod", "unknown")
		])

	_brains[id_lower] = {
		"id": id_lower,
		"path": full_path,
		"display_name": str(data.get("display_name", brain_id.capitalize())),
		"description": str(data.get("description", "")),
		"source_mod": mod_id
	}

	# Clear cached instance if overriding (also remove from LRU tracking)
	if id_lower in _brain_instances:
		_brain_instances.erase(id_lower)
		var lru_idx: int = _lru_order.find(id_lower)
		if lru_idx >= 0:
			_lru_order.remove_at(lru_idx)


## Auto-discover AI brains from a mod's ai_brains/ directory
## Called for brains that aren't explicitly declared in mod.json
## @param mod_id: The mod ID
## @param mod_directory: The mod's base directory path
func discover_from_directory(mod_id: String, mod_directory: String) -> int:
	var ai_brains_dir: String = mod_directory.path_join("ai_brains")
	var dir: DirAccess = DirAccess.open(ai_brains_dir)

	if not dir:
		# No ai_brains directory - that's okay
		return 0

	var count: int = 0
	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gd"):
			var full_path: String = ai_brains_dir.path_join(file_name)
			# Extract brain ID from filename: ai_aggressive.gd -> aggressive
			var brain_id: String = file_name.get_basename()
			if brain_id.begins_with("ai_"):
				brain_id = brain_id.substr(3)  # Remove "ai_" prefix

			# Only register if not already declared in mod.json
			if brain_id.to_lower() not in _brains:
				_brains[brain_id.to_lower()] = {
					"id": brain_id.to_lower(),
					"path": full_path,
					"display_name": brain_id.capitalize(),
					"description": "",
					"source_mod": mod_id
				}
				count += 1

		file_name = dir.get_next()

	dir.list_dir_end()

	if count > 0:
		_cache_dirty = true
		registrations_changed.emit()

	return count


# =============================================================================
# LOOKUP API
# =============================================================================

## Get all registered AI brain IDs
func get_all_brain_ids() -> Array[String]:
	var result: Array[String] = []
	for brain_id: String in _brains.keys():
		result.append(brain_id)
	result.sort()
	return result


## Get all registered AI brains as dictionaries with metadata (cached for editor performance)
## Returns: Array of {id, display_name, description, path, source_mod}
func get_all_brains() -> Array[Dictionary]:
	_rebuild_cache_if_dirty()
	var result: Array[Dictionary] = []
	for entry: Dictionary in _cached_all_brains:
		result.append(entry.duplicate())
	return result


## Get a specific brain's metadata
## Returns empty dictionary if not found
func get_brain(brain_id: String) -> Dictionary:
	var lower: String = brain_id.to_lower()
	if lower in _brains:
		var entry: Dictionary = _brains[lower]
		return entry.duplicate()
	return {}


## Get the display name for a brain
func get_display_name(brain_id: String) -> String:
	var lower: String = brain_id.to_lower()
	if lower in _brains:
		var entry: Dictionary = _brains[lower]
		return entry.get("display_name", brain_id.capitalize())
	return brain_id.capitalize()


## Get the description for a brain
func get_description(brain_id: String) -> String:
	var lower: String = brain_id.to_lower()
	if lower in _brains:
		var entry: Dictionary = _brains[lower]
		return entry.get("description", "")
	return ""


## Get the script path for a brain
func get_brain_path(brain_id: String) -> String:
	var lower: String = brain_id.to_lower()
	if lower in _brains:
		var entry: Dictionary = _brains[lower]
		return entry.get("path", "")
	return ""


## Check if a brain is registered
func has_brain(brain_id: String) -> bool:
	return brain_id.to_lower() in _brains


## Get which mod provides a brain
func get_source_mod(brain_id: String) -> String:
	var lower: String = brain_id.to_lower()
	if lower in _brains:
		var entry: Dictionary = _brains[lower]
		return entry.get("source_mod", "")
	return ""


## Get an instance of the AI brain Resource
## Returns null if not found or failed to load
func get_brain_instance(brain_id: String) -> Resource:
	var lower: String = brain_id.to_lower()

	# Return cached instance if available (and update LRU order)
	if lower in _brain_instances:
		_update_lru_access(lower)
		return _brain_instances[lower]

	# Try to load and instantiate
	if lower not in _brains:
		return null

	var brain_entry: Dictionary = _brains[lower]
	var path: String = brain_entry.get("path", "")
	if path.is_empty():
		return null

	var script: GDScript = load(path) as GDScript
	if not script:
		push_warning("AIBrainRegistry: Failed to load brain script: %s" % path)
		return null

	if not script.can_instantiate():
		push_warning("AIBrainRegistry: Brain script cannot be instantiated (check for errors): %s" % path)
		return null

	var instance: Resource = script.new()
	if not instance:
		push_warning("AIBrainRegistry: Failed to instantiate brain: %s" % path)
		return null

	# Evict LRU entries if cache is full before adding new instance
	_evict_lru_if_needed()

	_brain_instances[lower] = instance
	_lru_order.append(lower)
	return instance


## Update LRU tracking when an instance is accessed
## Moves the brain_id to the end of the list (most recently used)
func _update_lru_access(brain_id: String) -> void:
	var idx: int = _lru_order.find(brain_id)
	if idx >= 0:
		_lru_order.remove_at(idx)
	_lru_order.append(brain_id)


## Evict least recently used cache entries if at capacity
func _evict_lru_if_needed() -> void:
	while _brain_instances.size() >= MAX_CACHED_INSTANCES and _lru_order.size() > 0:
		var lru_id: String = _lru_order[0]
		_lru_order.remove_at(0)
		if lru_id in _brain_instances:
			_brain_instances.erase(lru_id)


## Get all brain instances (for editors that need the actual Resource objects)
## Returns Array of AI brain Resource instances
func get_all_brain_instances() -> Array[Resource]:
	var result: Array[Resource] = []
	for brain_id: String in _brains.keys():
		var instance: Resource = get_brain_instance(brain_id)
		if instance:
			result.append(instance)
	return result


# =============================================================================
# UTILITY API
# =============================================================================

## Unregister all brains from a specific mod
func unregister_mod(mod_id: String) -> void:
	var changed: bool = false
	var to_remove: Array[String] = []
	
	for brain_id: String in _brains.keys():
		var entry: Dictionary = _brains[brain_id]
		if entry.get("source_mod", "") == mod_id:
			to_remove.append(brain_id)
	
	for brain_id: String in to_remove:
		_brains.erase(brain_id)
		# Also clear cached instance
		if brain_id in _brain_instances:
			_brain_instances.erase(brain_id)
			var lru_idx: int = _lru_order.find(brain_id)
			if lru_idx >= 0:
				_lru_order.remove_at(lru_idx)
		changed = true
	
	if changed:
		_cache_dirty = true
		registrations_changed.emit()


## Clear all registrations (called on mod reload)
func clear_mod_registrations() -> void:
	_brains.clear()
	_brain_instances.clear()
	_lru_order.clear()
	_cache_dirty = true
	registrations_changed.emit()


## Rebuild cached sorted array if dirty
func _rebuild_cache_if_dirty() -> void:
	if not _cache_dirty:
		return
	
	_cached_all_brains.clear()
	for brain_id: String in _brains.keys():
		var entry: Dictionary = _brains[brain_id]
		_cached_all_brains.append(entry.duplicate())
	# Sort by display name for consistent UI ordering
	_cached_all_brains.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("display_name", "") < b.get("display_name", "")
	)
	_cache_dirty = false


## Get registration counts for debugging
func get_stats() -> Dictionary:
	return {
		"brain_count": _brains.size(),
		"cached_instances": _brain_instances.size()
	}
