class_name TilesetRegistry
extends RefCounted

## Registry for tileset declarations from mod manifests
##
## NOTE: This class cannot use class_name references for TileSetAutoGenerator
## because autoloads aren't available when this class loads. We use preload instead.
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
# PRELOADS
# =============================================================================

## TileSetAutoGenerator for auto-populating tile definitions on first access
const TileSetAutoGeneratorClass = preload("res://core/tools/tileset_auto_generator.gd")

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

# =============================================================================
# INTERNAL HELPERS
# =============================================================================

## Get a field from a tileset entry, with fallback
func _get_tileset_field(tileset_id: String, field: String, fallback: String = "") -> String:
	var lower: String = tileset_id.to_lower()
	if lower in _tilesets:
		return _tilesets[lower].get(field, fallback)
	return fallback


## Create a tileset entry dictionary
func _make_tileset_entry(id: String, path: String, display_name: String, source_mod: String, description: String = "") -> Dictionary:
	return {
		"id": id,
		"path": path,
		"display_name": display_name,
		"description": description,
		"source_mod": source_mod,
		"resource": null
	}


## Remove entries from a dictionary by mod_id, returns count removed
func _remove_entries_by_mod(entries: Dictionary, mod_id: String) -> int:
	var to_remove: Array[String] = []
	for entry_id: String in entries.keys():
		if entries[entry_id].get("source_mod", "") == mod_id:
			to_remove.append(entry_id)
	for entry_id: String in to_remove:
		entries.erase(entry_id)
	return to_remove.size()


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

	_tilesets[id_lower] = _make_tileset_entry(
		id_lower,
		full_path,
		str(data.get("display_name", tileset_id.capitalize())),
		mod_id,
		str(data.get("description", ""))
	)


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
			# Strip .remap suffix for export builds
			var original_name: String = file_name.trim_suffix(".remap")

			if original_name.ends_with(".tres"):
				var tileset_id: String = original_name.get_basename().to_lower()
				# Only register if not already declared in mod.json
				if tileset_id not in _tilesets:
					var full_path: String = tilesets_dir.path_join(original_name)
					_tilesets[tileset_id] = _make_tileset_entry(
						tileset_id,
						full_path,
						original_name.get_basename().capitalize(),
						mod_id
					)
					count += 1

		file_name = dir.get_next()

	dir.list_dir_end()

	if count > 0:
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


## Get all registered tilesets as dictionaries with metadata
## Returns: Array of {id, display_name, description, path, source_mod}
func get_all_tilesets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tileset_id: String in _tilesets.keys():
		var entry: Dictionary = _tilesets[tileset_id]
		var data: Dictionary = entry.duplicate()
		data.erase("resource")  # Don't include the cached resource
		result.append(data)
	# Sort by display name for consistent UI ordering
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("display_name", "") < b.get("display_name", "")
	)
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
	var result: String = _get_tileset_field(tileset_id, "display_name")
	return result if not result.is_empty() else tileset_id.capitalize()


## Get the description for a tileset
func get_description(tileset_id: String) -> String:
	return _get_tileset_field(tileset_id, "description")


## Get the path for a tileset
func get_tileset_path(tileset_id: String) -> String:
	return _get_tileset_field(tileset_id, "path")


## Check if a tileset is registered
func has_tileset(tileset_id: String) -> bool:
	return tileset_id.to_lower() in _tilesets


## Get which mod provides a tileset
func get_source_mod(tileset_id: String) -> String:
	return _get_tileset_field(tileset_id, "source_mod")


## Get the TileSet resource (lazy-loaded)
## Returns null if not found or failed to load
## Auto-generates tile definitions based on texture dimensions on first access
func get_tileset(tileset_id: String) -> TileSet:
	var lower: String = tileset_id.to_lower()

	if lower not in _tilesets:
		push_warning("TilesetRegistry: TileSet '%s' not found in registry" % tileset_id)
		return null

	var entry: Dictionary = _tilesets[lower]
	var entry_resource: Variant = entry.get("resource")
	var entry_path: String = entry.get("path", "")
	var auto_populated: bool = entry.get("auto_populated", false)

	# Lazy-load the resource on first access
	if entry_resource == null:
		var loaded: Resource = load(entry_path)
		entry_resource = loaded if loaded is TileSet else null
		entry["resource"] = entry_resource
		if entry_resource == null:
			push_error("TilesetRegistry: Failed to load TileSet from: %s" % entry_path)
			return null

	# Auto-discover textures and populate tile definitions (once per tileset)
	if entry_resource is TileSet and not auto_populated:
		var tileset: TileSet = entry_resource as TileSet

		# First, repair any invalid atlas sources (no texture, out-of-bounds tiles)
		var repaired: int = TileSetAutoGeneratorClass.repair_tileset(tileset, lower)
		if repaired > 0:
			print("TilesetRegistry: Repaired %d issue(s) in TileSet '%s'" % [repaired, lower])

		# Then, discover any new textures in the tileset's texture directory
		var discovered: int = TileSetAutoGeneratorClass.auto_discover_textures(tileset, entry_path, lower)
		if discovered > 0 and OS.is_debug_build():
			print("TilesetRegistry: Discovered %d new texture(s) for TileSet '%s'" % [discovered, lower])

		# Then, auto-populate tile definitions for all atlas sources
		var generated: int = TileSetAutoGeneratorClass.auto_populate_tileset(tileset, lower)
		entry["auto_populated"] = true
		if generated > 0 and OS.is_debug_build():
			print("TilesetRegistry: Auto-generated %d tile(s) for TileSet '%s'" % [generated, lower])

	return entry_resource if entry_resource is TileSet else null


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
	var removed: int = _remove_entries_by_mod(_tilesets, mod_id)
	if removed > 0:
		registrations_changed.emit()


## Clear all registrations (called on mod reload)
func clear_mod_registrations() -> void:
	_tilesets.clear()
	registrations_changed.emit()


## Get registration counts for debugging
func get_stats() -> Dictionary:
	return {
		"tileset_count": _tilesets.size()
	}
