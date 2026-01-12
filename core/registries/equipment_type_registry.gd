class_name EquipmentTypeRegistry
extends RefCounted

## Maps equipment subtypes to categories for slot matching
##
## This registry enables modders to add new equipment types without modifying
## slot definitions. Subtypes (sword, bow, laser_rifle) map to categories
## (weapon, accessory), and slots accept categories via wildcards.
##
## Example flow:
##   Item has equipment_type = "bow"
##   Registry knows: "bow" -> category "weapon"
##   Slot accepts: ["weapon:*"]
##   Match: "bow" is in "weapon" category, slot accepts weapon:* -> SUCCESS
##
## Includes SF-standard defaults (sword, axe, spear, staff, ring, etc.).
## Mods can add new types or use "replace_all": true for total conversions.
##
## mod.json schema:
## {
##   "custom_types": {
##     "equipment_types": {
##       "replace_all": false,
##       "subtypes": {
##         "sword": {"category": "weapon", "display_name": "Sword"},
##         "laser_rifle": {"category": "weapon", "display_name": "Laser Rifle"}
##       },
##       "categories": {
##         "weapon": {"display_name": "Weapon"},
##         "cybernetic": {"display_name": "Cybernetic Implant"}
##       }
##     }
##   }
## }

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when registrations change (for editor refresh)
signal registrations_changed()

# =============================================================================
# DATA STORAGE
# =============================================================================

## Registered subtypes: {subtype_id: {category, display_name, source_mod}}
var _subtypes: Dictionary = {}

## Registered categories: {category_id: {display_name, description, source_mod}}
var _categories: Dictionary = {}

## Reverse index: {category_id: Array[String] of subtype_ids}
var _subtypes_by_category: Dictionary = {}

## Whether defaults have been initialized
var _defaults_initialized: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

## Initialize with SF-standard equipment types.
## Called automatically on first use, or can be called explicitly.
## Mods can override these via register_from_config() with "replace_all": true.
func init_defaults() -> void:
	if _defaults_initialized:
		return
	_defaults_initialized = true

	# Categories
	_categories["weapon"] = {
		"id": "weapon",
		"display_name": "Weapon",
		"description": "Equipped in weapon slot",
		"source_mod": "_core"
	}
	_categories["accessory"] = {
		"id": "accessory",
		"display_name": "Accessory",
		"description": "Rings and other accessories",
		"source_mod": "_core"
	}

	# Weapon subtypes (SF-standard)
	_subtypes["sword"] = {"id": "sword", "category": "weapon", "display_name": "Sword", "source_mod": "_core"}
	_subtypes["axe"] = {"id": "axe", "category": "weapon", "display_name": "Axe", "source_mod": "_core"}
	_subtypes["spear"] = {"id": "spear", "category": "weapon", "display_name": "Spear", "source_mod": "_core"}
	_subtypes["staff"] = {"id": "staff", "category": "weapon", "display_name": "Staff", "source_mod": "_core"}
	_subtypes["knife"] = {"id": "knife", "category": "weapon", "display_name": "Knife", "source_mod": "_core"}
	_subtypes["bow"] = {"id": "bow", "category": "weapon", "display_name": "Bow", "source_mod": "_core"}

	# Accessory subtypes
	_subtypes["ring"] = {"id": "ring", "category": "accessory", "display_name": "Ring", "source_mod": "_core"}

	_rebuild_reverse_index()
	registrations_changed.emit()


# =============================================================================
# REGISTRATION API
# =============================================================================

## Register equipment types from a mod's configuration
## @param mod_id: The mod registering these types
## @param config: The equipment_types dictionary from mod.json
func register_from_config(mod_id: String, config: Dictionary) -> void:
	# Check for replace_all flag (total conversions)
	var replace_all: bool = config.get("replace_all", false)
	if replace_all:
		_subtypes.clear()
		_categories.clear()
		push_warning("[EquipmentTypeRegistry] Mod '%s' replacing all equipment types" % mod_id)

	# Register categories first (so subtypes can reference them)
	if "categories" in config and config.categories is Dictionary:
		var categories_dict: Dictionary = config.categories
		for cat_id: String in categories_dict.keys():
			var cat_data: Variant = categories_dict[cat_id]
			if cat_data is Dictionary:
				_register_category(mod_id, cat_id, cat_data)

	# Register subtypes
	if "subtypes" in config and config.subtypes is Dictionary:
		var subtypes_dict: Dictionary = config.subtypes
		for subtype_id: String in subtypes_dict.keys():
			var subtype_data: Variant = subtypes_dict[subtype_id]
			if subtype_data is Dictionary:
				_register_subtype(mod_id, subtype_id, subtype_data)

	_rebuild_reverse_index()
	registrations_changed.emit()


## Register a single category
func _register_category(mod_id: String, category_id: String, data: Dictionary) -> void:
	var id_lower: String = category_id.to_lower().strip_edges()
	if id_lower.is_empty():
		push_error("EquipmentTypeRegistry: Empty category ID from mod '%s'" % mod_id)
		return

	# Check for override
	if id_lower in _categories:
		var existing: Dictionary = _categories[id_lower]
		push_warning("EquipmentTypeRegistry: Mod '%s' overrides category '%s' (was from '%s')" % [
			mod_id, category_id, existing.get("source_mod", "unknown")
		])

	_categories[id_lower] = {
		"id": id_lower,
		"display_name": str(data.get("display_name", category_id.capitalize())),
		"description": str(data.get("description", "")),
		"source_mod": mod_id
	}


## Register a single subtype
func _register_subtype(mod_id: String, subtype_id: String, data: Dictionary) -> void:
	var id_lower: String = subtype_id.to_lower().strip_edges()
	if id_lower.is_empty():
		push_error("EquipmentTypeRegistry: Empty subtype ID from mod '%s'" % mod_id)
		return

	# Validate required category field
	if "category" not in data:
		push_error("EquipmentTypeRegistry: Subtype '%s' from mod '%s' missing required 'category'" % [
			subtype_id, mod_id
		])
		return

	var category: String = str(data.category).to_lower().strip_edges()
	if category.is_empty():
		push_error("EquipmentTypeRegistry: Subtype '%s' from mod '%s' has empty category" % [
			subtype_id, mod_id
		])
		return

	# Warn if category doesn't exist (might be registered by a later mod)
	if category not in _categories:
		push_warning("EquipmentTypeRegistry: Subtype '%s' references unregistered category '%s'" % [
			subtype_id, category
		])

	# Check for override
	if id_lower in _subtypes:
		var existing: Dictionary = _subtypes[id_lower]
		push_warning("EquipmentTypeRegistry: Mod '%s' overrides subtype '%s' (was from '%s')" % [
			mod_id, subtype_id, existing.get("source_mod", "unknown")
		])
		if existing.get("category", "") != category:
			push_warning("EquipmentTypeRegistry: Category changed from '%s' to '%s'" % [
				existing.get("category", ""), category
			])

	_subtypes[id_lower] = {
		"id": id_lower,
		"category": category,
		"display_name": str(data.get("display_name", subtype_id.capitalize())),
		"source_mod": mod_id
	}


# =============================================================================
# LOOKUP API
# =============================================================================

## Get the category for a subtype
## Returns empty string if subtype is not registered
func get_category(subtype: String) -> String:
	var lower: String = subtype.to_lower()
	if lower in _subtypes:
		var entry: Dictionary = _subtypes[lower]
		return entry.get("category", "")
	return ""


## Check if a subtype matches an accepts_types entry
## Handles category wildcards like "weapon:*"
## @param subtype: The item's equipment_type (e.g., "sword")
## @param accept_type: An entry from slot's accepts_types (e.g., "weapon:*" or "sword")
func matches_accept_type(subtype: String, accept_type: String) -> bool:
	var lower_subtype: String = subtype.to_lower()
	var lower_accept: String = accept_type.to_lower()

	# Direct match (exact subtype or category name)
	if lower_subtype == lower_accept:
		return true

	# Category wildcard: "weapon:*" matches any subtype in weapon category
	if lower_accept.ends_with(":*"):
		var category: String = lower_accept.trim_suffix(":*")
		var subtype_category: String = get_category(lower_subtype)
		if not subtype_category.is_empty() and subtype_category == category:
			return true
		# Also check if the subtype IS the category (e.g., "weapon" matches "weapon:*")
		if lower_subtype == category:
			return true

	return false


## Check if a subtype is registered
func is_valid_subtype(subtype: String) -> bool:
	return subtype.to_lower() in _subtypes


## Check if a category is registered
func is_valid_category(category: String) -> bool:
	return category.to_lower() in _categories


## Get all subtypes that belong to a category (O(1) lookup via reverse index)
func get_subtypes_for_category(category: String) -> Array[String]:
	var lower_category: String = category.to_lower()
	if lower_category in _subtypes_by_category:
		var subtypes: Array = _subtypes_by_category[lower_category]
		var result: Array[String] = []
		for subtype_id: Variant in subtypes:
			result.append(str(subtype_id))
		return result
	return []


## Get all registered categories
func get_all_categories() -> Array[String]:
	var result: Array[String] = []
	for cat_id: String in _categories.keys():
		result.append(cat_id)
	result.sort()
	return result


## Get all registered subtypes
func get_all_subtypes() -> Array[String]:
	var result: Array[String] = []
	for subtype_id: String in _subtypes.keys():
		result.append(subtype_id)
	result.sort()
	return result


## Get display name for a subtype
func get_subtype_display_name(subtype: String) -> String:
	var lower: String = subtype.to_lower()
	if lower in _subtypes:
		var entry: Dictionary = _subtypes[lower]
		return entry.get("display_name", subtype.capitalize())
	return subtype.capitalize()


## Get display name for a category
func get_category_display_name(category: String) -> String:
	var lower: String = category.to_lower()
	if lower in _categories:
		var entry: Dictionary = _categories[lower]
		return entry.get("display_name", category.capitalize())
	return category.capitalize()


## Get which mod registered a subtype
func get_subtype_source_mod(subtype: String) -> String:
	var lower: String = subtype.to_lower()
	if lower in _subtypes:
		var entry: Dictionary = _subtypes[lower]
		return entry.get("source_mod", "")
	return ""


## Get which mod registered a category
func get_category_source_mod(category: String) -> String:
	var lower: String = category.to_lower()
	if lower in _categories:
		var entry: Dictionary = _categories[lower]
		return entry.get("source_mod", "")
	return ""


## Get subtypes grouped by category (for editor dropdowns)
## Returns: {category_id: [{id, display_name, source_mod}, ...], ...}
func get_subtypes_grouped_by_category() -> Dictionary:
	var result: Dictionary = {}

	# Initialize with all categories
	for cat_id: String in _categories.keys():
		result[cat_id] = []

	# Add subtypes to their categories
	for subtype_id: String in _subtypes.keys():
		var subtype_data: Dictionary = _subtypes[subtype_id]
		var category: String = subtype_data.get("category", "")

		if category not in result:
			result[category] = []

		var category_list: Array = result[category]
		category_list.append({
			"id": subtype_id,
			"display_name": subtype_data.get("display_name", subtype_id.capitalize()),
			"source_mod": subtype_data.get("source_mod", "")
		})

	return result


# =============================================================================
# UTILITY API
# =============================================================================

## Unregister all types from a specific mod
func unregister_mod(mod_id: String) -> void:
	var changed: bool = false
	
	# Remove subtypes from this mod
	var subtypes_to_remove: Array[String] = []
	for subtype_id: String in _subtypes.keys():
		var entry: Dictionary = _subtypes[subtype_id]
		if entry.get("source_mod", "") == mod_id:
			subtypes_to_remove.append(subtype_id)
	for subtype_id: String in subtypes_to_remove:
		_subtypes.erase(subtype_id)
		changed = true
	
	# Remove categories from this mod
	var categories_to_remove: Array[String] = []
	for cat_id: String in _categories.keys():
		var entry: Dictionary = _categories[cat_id]
		if entry.get("source_mod", "") == mod_id:
			categories_to_remove.append(cat_id)
	for cat_id: String in categories_to_remove:
		_categories.erase(cat_id)
		changed = true
	
	if changed:
		_rebuild_reverse_index()
		registrations_changed.emit()


## Clear all registrations (called on mod reload)
## Re-initializes defaults after clearing so mods can build on them
func clear_mod_registrations() -> void:
	_subtypes.clear()
	_categories.clear()
	_subtypes_by_category.clear()
	_defaults_initialized = false
	init_defaults()  # Re-apply defaults so mods can override


## Get registration counts for debugging
func get_stats() -> Dictionary:
	return {
		"subtype_count": _subtypes.size(),
		"category_count": _categories.size()
	}


## Validate an item's equipment_type against the registry
## Returns a validation result dictionary
func validate_equipment_type(equipment_type: String) -> Dictionary:
	if equipment_type.is_empty():
		return {"valid": true, "warning": ""}  # Empty is valid (non-equippable item)

	var lower: String = equipment_type.to_lower()

	if lower in _subtypes:
		return {"valid": true, "warning": ""}

	# Not registered - provide helpful message
	var similar: Array[String] = _find_similar_subtypes(lower)
	var warning: String = "Equipment type '%s' is not registered." % equipment_type
	if not similar.is_empty():
		warning += " Did you mean: %s?" % ", ".join(similar)

	return {"valid": false, "warning": warning}


## Find similar subtype names (for typo suggestions)
func _find_similar_subtypes(query: String) -> Array[String]:
	if query.is_empty():
		return []

	var suggestions: Array[String] = []

	for subtype_id: String in _subtypes.keys():
		# Simple similarity: starts with same letter or contains query
		if subtype_id.begins_with(query[0]) or query in subtype_id or subtype_id in query:
			suggestions.append(subtype_id)
			if suggestions.size() >= 3:
				break

	return suggestions


## Rebuild the reverse index mapping categories to subtypes
func _rebuild_reverse_index() -> void:
	_subtypes_by_category.clear()
	for subtype_id: String in _subtypes.keys():
		var entry: Dictionary = _subtypes[subtype_id]
		var category: String = entry.get("category", "")
		if category.is_empty():
			continue
		if category not in _subtypes_by_category:
			_subtypes_by_category[category] = []
		var cat_list: Array = _subtypes_by_category[category]
		cat_list.append(subtype_id)
