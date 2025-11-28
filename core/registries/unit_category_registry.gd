class_name UnitCategoryRegistry
extends RefCounted

## Registry for unit categories.
## Allows mods to define additional unit categories beyond the defaults.
##
## Default categories: player, enemy, boss, neutral
##
## Mods can register additional categories via their mod.json:
## {
##   "unit_categories": ["ally_npc", "summon", "mercenary"]
## }
##
## Note: Custom categories require corresponding AI/battle logic to be meaningful.
## The base game only has built-in handling for the default four categories.

# Default categories that are always available
const DEFAULT_CATEGORIES: Array[String] = ["player", "enemy", "boss", "neutral"]

# Registered categories from mods (mod_id -> Array[String])
var _mod_categories: Dictionary = {}

# Cached merged array (rebuilt when mods change)
var _all_categories: Array[String] = []
var _cache_dirty: bool = true


## Register unit categories from a mod
func register_categories(mod_id: String, categories: Array) -> void:
	var typed_array: Array[String] = []
	for c: Variant in categories:
		var cat_str: String = str(c).to_lower().strip_edges()
		if not cat_str.is_empty():
			typed_array.append(cat_str)

	if not typed_array.is_empty():
		_mod_categories[mod_id] = typed_array
		_cache_dirty = true
		print("UnitCategoryRegistry: Registered categories from '%s': %s" % [mod_id, typed_array])


## Unregister all categories from a mod (called when mod is unloaded)
func unregister_mod(mod_id: String) -> void:
	if mod_id in _mod_categories:
		_mod_categories.erase(mod_id)
		_cache_dirty = true


## Clear all mod registrations (called on full mod reload)
func clear_mod_registrations() -> void:
	_mod_categories.clear()
	_cache_dirty = true


## Get all available unit categories (defaults + mod-registered)
func get_categories() -> Array[String]:
	_rebuild_cache_if_dirty()
	return _all_categories.duplicate()


## Check if a category is valid
func is_valid_category(category: String) -> bool:
	_rebuild_cache_if_dirty()
	return category.to_lower() in _all_categories


## Check if a category is one of the built-in defaults
func is_default_category(category: String) -> bool:
	return category.to_lower() in DEFAULT_CATEGORIES


## Get which mod registered a category (or "base" for defaults)
func get_category_source(category: String) -> String:
	var lower_cat: String = category.to_lower()
	if lower_cat in DEFAULT_CATEGORIES:
		return "base"
	for mod_id: String in _mod_categories:
		if lower_cat in _mod_categories[mod_id]:
			return mod_id
	return ""


## Rebuild the cached merged array
func _rebuild_cache_if_dirty() -> void:
	if not _cache_dirty:
		return

	# Start with defaults
	_all_categories = DEFAULT_CATEGORIES.duplicate()

	# Add mod categories (avoiding duplicates)
	for mod_id: String in _mod_categories:
		for category: String in _mod_categories[mod_id]:
			if category not in _all_categories:
				_all_categories.append(category)

	_cache_dirty = false
