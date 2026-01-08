class_name TilesetRegistry
extends RefCounted

## Registry for tileset declarations from mod manifests
##
## Instead of just scanning directories, mods can declare their tilesets
## in mod.json with metadata. This provides:
## - Display names and descriptions for editor dropdowns
## - Proper mod attribution and override tracking
## - Total conversion support (mods can replace all tilesets)
##
## mod.json schema:
## {
##   "tilesets": {
##     "terrain": {
##       "path": "tilesets/terrain.tres",
##       "display_name": "Terrain Tiles",
##       "description": "Standard outdoor terrain tileset"
##     },
##     "dungeon": {
##       "path": "tilesets/dungeon.tres",
##       "display_name": "Dungeon Tiles",
##       "description": "Indoor dungeon and cave tileset"
##     }
##   }
## }
##
## For backwards compatibility, also discovers tilesets from tilesets/
## directories that aren't explicitly declared in mod.json.

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when registrations change (for editor refresh)
signal registrations_changed()

# =============================================================================
# DATA STORAGE
# =============================================================================

## Registered tilesets: {tileset_id: {path, display_name, description, source_mod, resource}}
var _tilesets: Dictionary = {}

## Cached sorted tileset metadata for editor performance
var _cached_all_tilesets: Array[Dictionary] = []
var _cache_dirty: bool = true

# =============================================================================
# REGISTRATION API
# =============================================================================

## Register tilesets from a mod's configuration
## @param mod_id: The mod registering these tilesets
## @param config: The tilesets dictionary from mod.json
## @param mod_directory: The mod's base directory path
func register_from_config(mod_id: String, config: Dictionary, mod_directory: String) -> void:
	for tileset_id: String in config.keys():
		var tileset_data: Variant = config[tileset_id]
		if tileset_data is Dictionary:
			_register_tileset(mod_id, tileset_id, tileset_data, mod_directory)

	_cache_dirty = true
	registrations_changed.emit()


## Register a single tileset
func _register_tileset(mod_id: String, tileset_id: String, data: Dictionary, mod_directory: String) -> void:
	var id_lower: String = tileset_id.to_lower().strip_edges()
	if id_lower.is_empty():
		push_error("TilesetRegistry: Empty tileset ID from mod '%s'" % mod_id)
		return

	# Get the path (required)
	if "path" not in data:
		push_error("TilesetRegistry: Tileset '%s' from mod '%s' missing required 'path'" % [tileset_id, mod_id])
		return

	var relative_path: String = str(data.path)
	var full_path: String = mod_directory.path_join(relative_path)

	# Verify the file exists - use ResourceLoader.exists() for export compatibility
	if not ResourceLoader.exists(full_path):
		push_warning("TilesetRegistry: Tileset not found at '%s' (declared by mod '%s')" % [full_path, mod_id])

	# Check for override
	if id_lower in _tilesets:
		var existing: Dictionary = _tilesets[id_lower]
		push_warning("TilesetRegistry: Mod '%s' overrides tileset '%s' (was from '%s')" % [
			mod_id, tileset_id, existing.get("source_mod", "unknown")
		])

	_tilesets[id_lower] = {
		"id": id_lower,
		"path": full_path,
		"display_name": str(data.get("display_name", tileset_id.capitalize())),
		"description": str(data.get("description", "")),
		"source_mod": mod_id,
		"resource": null  # Lazy-loaded
	}


## Auto-discover tilesets from a mod's tilesets/ directory
## Called for tilesets that aren't explicitly declared in mod.json
## @param mod_id: The mod ID
## @param mod_directory: The mod's base directory path
func discover_from_directory(mod_id: String, mod_directory: String) -> int:
	var tilesets_dir: String = mod_directory.path_join("tilesets")
	var dir: DirAccess = DirAccess.open(tilesets_dir)

	if not dir:
		# No tilesets directory - that's okay
		return 0

	var count: int = 0
	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			# Strip .remap suffix when listing directories (for export builds)
			var original_name: String = file_name
			if file_name.ends_with(".remap"):
				original_name = file_name.substr(0, file_name.length() - 6)

			if original_name.ends_with(".tres"):
				var full_path: String = tilesets_dir.path_join(original_name)
				var tileset_id: String = original_name.get_basename().to_lower()

				# Only register if not already declared in mod.json
				if tileset_id not in _tilesets:
					_tilesets[tileset_id] = {
						"id": tileset_id,
						"path": full_path,
						"display_name": original_name.get_basename().capitalize(),
						"description": "",
						"source_mod": mod_id,
						"resource": null
					}
					count += 1
				else:
					# Update path if the mod is overriding (higher priority wins)
					# This is handled by load order - later mods override earlier ones
					pass

		file_name = dir.get_next()

	dir.list_dir_end()

	if count > 0:
		_cache_dirty = true
		registrations_changed.emit()

	return count


# =============================================================================
# LOOKUP API
# =============================================================================

## Get all registered tileset IDs
func get_all_tileset_ids() -> Array[String]:
	var result: Array[String] = []
	for tileset_id: String in _tilesets.keys():
		result.append(tileset_id)
	result.sort()
	return result


## Get all registered tilesets as dictionaries with metadata (cached for editor performance)
## Returns: Array of {id, display_name, description, path, source_mod}
func get_all_tilesets() -> Array[Dictionary]:
	_rebuild_cache_if_dirty()
	var result: Array[Dictionary] = []
	for entry: Dictionary in _cached_all_tilesets:
		result.append(entry.duplicate())
	return result


## Get a specific tileset's metadata
## Returns empty dictionary if not found
func get_tileset_info(tileset_id: String) -> Dictionary:
	var lower: String = tileset_id.to_lower()
	if lower in _tilesets:
		var entry: Dictionary = _tilesets[lower]
		var data: Dictionary = entry.duplicate()
		data.erase("resource")
		return data
	return {}


## Get the display name for a tileset
func get_display_name(tileset_id: String) -> String:
	var lower: String = tileset_id.to_lower()
	if lower in _tilesets:
		var entry: Dictionary = _tilesets[lower]
		return entry.get("display_name", tileset_id.capitalize())
	return tileset_id.capitalize()


## Get the description for a tileset
func get_description(tileset_id: String) -> String:
	var lower: String = tileset_id.to_lower()
	if lower in _tilesets:
		var entry: Dictionary = _tilesets[lower]
		return entry.get("description", "")
	return ""


## Get the path for a tileset
func get_tileset_path(tileset_id: String) -> String:
	var lower: String = tileset_id.to_lower()
	if lower in _tilesets:
		var entry: Dictionary = _tilesets[lower]
		return entry.get("path", "")
	return ""


## Check if a tileset is registered
func has_tileset(tileset_id: String) -> bool:
	return tileset_id.to_lower() in _tilesets


## Get which mod provides a tileset
func get_source_mod(tileset_id: String) -> String:
	var lower: String = tileset_id.to_lower()
	if lower in _tilesets:
		var entry: Dictionary = _tilesets[lower]
		return entry.get("source_mod", "")
	return ""


## Get the TileSet resource (lazy-loaded)
## Returns null if not found or failed to load
func get_tileset(tileset_id: String) -> TileSet:
	var lower: String = tileset_id.to_lower()

	if lower not in _tilesets:
		return null

	var entry: Dictionary = _tilesets[lower]

	# Lazy-load the resource on first access
	if entry.resource == null:
		entry.resource = load(entry.path) as TileSet
		if entry.resource == null:
			push_error("TilesetRegistry: Failed to load TileSet from: %s" % entry.path)
			return null

	return entry.resource


## Get all tileset paths (for backwards compatibility with editors)
func get_all_tileset_paths() -> Array[String]:
	var result: Array[String] = []
	for tileset_id: String in _tilesets.keys():
		var entry: Dictionary = _tilesets[tileset_id]
		result.append(entry.get("path", ""))
	return result


# =============================================================================
# UTILITY API
# =============================================================================

## Unregister all tilesets from a specific mod
func unregister_mod(mod_id: String) -> void:
	var changed: bool = false
	var to_remove: Array[String] = []
	
	for tileset_id: String in _tilesets.keys():
		var entry: Dictionary = _tilesets[tileset_id]
		if entry.get("source_mod", "") == mod_id:
			to_remove.append(tileset_id)
	
	for tileset_id: String in to_remove:
		_tilesets.erase(tileset_id)
		changed = true
	
	if changed:
		_cache_dirty = true
		registrations_changed.emit()


## Clear all registrations (called on mod reload)
func clear_mod_registrations() -> void:
	_tilesets.clear()
	_cache_dirty = true
	registrations_changed.emit()


## Get registration counts for debugging
func get_stats() -> Dictionary:
	return {
		"tileset_count": _tilesets.size()
	}


## Rebuild cached sorted array if dirty
func _rebuild_cache_if_dirty() -> void:
	if not _cache_dirty:
		return
	
	_cached_all_tilesets.clear()
	for tileset_id: String in _tilesets.keys():
		var entry: Dictionary = _tilesets[tileset_id]
		var data: Dictionary = entry.duplicate()
		data.erase("resource")  # Don't include the cached resource
		_cached_all_tilesets.append(data)
	# Sort by display name for consistent UI ordering
	_cached_all_tilesets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("display_name", "") < b.get("display_name", "")
	)
	_cache_dirty = false
