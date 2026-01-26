class_name EditorTabRegistry
extends RefCounted

## Registry for editor tab definitions
##
## Provides a decoupled registration system for editor tabs. Instead of hardcoding
## tab creation in MainPanel, editors register themselves with metadata that
## allows MainPanel to dynamically create and manage them.
##
## Benefits:
## - Adding new editors doesn't require modifying MainPanel
## - Consistent refresh interface via standard refresh() method
## - Tabs sorted by category and priority
## - Mod-provided editor tabs use the same system as built-in tabs
##
## Usage:
## 1. Built-in tabs are auto-discovered from addons/sparkling_editor/ui/*.tscn
## 2. Mod tabs are registered via mod.json editor_extensions
## 3. MainPanel queries the registry to create tabs in the correct order
##
## Tab info format:
## {
##   "id": "character",              # Unique identifier (lowercase)
##   "display_name": "Characters",   # Tab title shown to user
##   "scene_path": "res://...",      # Path to the editor scene
##   "category": "content",          # Category for grouping (see CATEGORIES)
##   "priority": 100,                # Sort order within category (lower = first)
##   "source_mod": "",               # Which mod provided this (empty for built-in)
##   "refresh_method": "refresh"     # Method to call on refresh (default: refresh)
## }

# =============================================================================
# CONSTANTS
# =============================================================================

## Tab categories for logical grouping (two-tier navigation)
## Primary categories shown in category bar, secondary tabs shown below
const CATEGORIES: Array[String] = [
	"content",     # Characters, classes, items, abilities (core content creation)
	"battle",      # Maps, terrain, battles, AI (tactical scenario design)
	"story",       # NPCs, cinematics, campaigns, shops (narrative elements)
	"system",      # Overview, mod settings, new game configs, save editing
	"mod"          # Mod-provided custom tabs (always last)
]

## Display names for primary category tabs
const CATEGORY_DISPLAY_NAMES: Dictionary = {
	"content": "Content",
	"battle": "Battles",
	"story": "Story",
	"system": "System",
	"mod": "Mods"
}

## Default built-in tabs with their metadata
## These are registered automatically if the scene files exist
## Organized by two-tier category system for improved navigation
const BUILTIN_TABS: Array[Dictionary] = [
	# Content editors (core content creation)
	{"id": "characters", "display_name": "Characters", "scene": "character_editor.tscn", "category": "content", "priority": 10},
	{"id": "classes", "display_name": "Classes", "scene": "class_editor.tscn", "category": "content", "priority": 20},
	{"id": "abilities", "display_name": "Abilities", "scene": "ability_editor.tscn", "category": "content", "priority": 30},
	{"id": "items", "display_name": "Items", "scene": "item_editor.tscn", "category": "content", "priority": 40},
	{"id": "status_effects", "display_name": "Status Effects", "scene": "status_effect_editor.tscn", "category": "content", "priority": 50},

	# Battle editors (tactical scenario design)
	{"id": "maps", "display_name": "Maps", "scene": "map_metadata_editor.tscn", "category": "battle", "priority": 10},
	{"id": "terrain", "display_name": "Terrain Effects", "scene": "terrain_editor.tscn", "category": "battle", "priority": 20},
	{"id": "battles", "display_name": "Battles", "scene": "battle_editor.tscn", "category": "battle", "priority": 30},
	{"id": "ai_behaviors", "display_name": "AI Behaviors", "scene": "ai_brain_editor.tscn", "category": "battle", "priority": 40},

	# Story editors (narrative elements)
	{"id": "npcs", "display_name": "NPCs", "scene": "npc_editor.tscn", "category": "story", "priority": 10},
	{"id": "interactables", "display_name": "Interactables", "scene": "interactable_editor.tscn", "category": "story", "priority": 15},
	{"id": "cinematics", "display_name": "Cinematics", "scene": "cinematic_editor.tscn", "category": "story", "priority": 20},
	{"id": "shops", "display_name": "Shops", "scene": "shop_editor.tscn", "category": "story", "priority": 40},
	{"id": "crafters", "display_name": "Crafters", "scene": "crafter_editor.tscn", "category": "story", "priority": 50},
	{"id": "recipes", "display_name": "Recipes", "scene": "crafting_recipe_editor.tscn", "category": "story", "priority": 60},

	# System editors (configuration and setup)
	{"id": "overview", "display_name": "Overview", "category": "system", "priority": 0, "is_static": true},
	{"id": "mod_settings", "display_name": "Mod Settings", "scene": "mod_json_editor.tscn", "category": "system", "priority": 10},
	{"id": "new_game_configs", "display_name": "New Game Configs", "scene": "new_game_config_editor.tscn", "category": "system", "priority": 20},
	{"id": "save_slots", "display_name": "Save Slots", "scene": "save_slot_editor.tscn", "category": "system", "priority": 30},
	{"id": "caravans", "display_name": "Caravans", "scene": "caravan_editor.tscn", "category": "system", "priority": 40},
	{"id": "experience_configs", "display_name": "Experience", "scene": "experience_config_editor.tscn", "category": "system", "priority": 50}
]

## Base path for built-in editor scenes
const BUILTIN_SCENE_PATH: String = "res://addons/sparkling_editor/ui/"

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when tab registrations change (for MainPanel refresh)
signal registrations_changed()

## Emitted when a specific tab is registered
signal tab_registered(tab_id: String)

## Emitted when a specific tab is unregistered
signal tab_unregistered(tab_id: String)

# =============================================================================
# DATA STORAGE
# =============================================================================

## Registered tabs: {tab_id: {id, display_name, scene_path, category, priority, source_mod, instance}}
var _tabs: Dictionary[String, Dictionary] = {}

## Tab instances (populated when MainPanel creates the tabs)
var _instances: Dictionary[String, Control] = {}

## Cached sorted tab list (rebuilt when dirty)
var _sorted_tabs: Array[Dictionary] = []
var _cache_dirty: bool = true

# =============================================================================
# INITIALIZATION
# =============================================================================

## Register all built-in tabs
## Called by MainPanel during initialization
func register_builtin_tabs() -> void:
	for tab_def: Dictionary in BUILTIN_TABS:
		var tab_id: String = DictUtils.get_string(tab_def, "id", "")
		if tab_id.is_empty():
			continue

		var scene_path: String = ""
		if "scene" in tab_def:
			var scene_name: String = DictUtils.get_string(tab_def, "scene", "")
			scene_path = BUILTIN_SCENE_PATH + scene_name

		# For static tabs (like Overview), scene_path can be empty
		var is_static: bool = DictUtils.get_bool(tab_def, "is_static", false)

		# Verify scene exists (unless it's a static tab)
		if not is_static and not scene_path.is_empty():
			if not ResourceLoader.exists(scene_path):
				push_warning("EditorTabRegistry: Built-in tab '%s' scene not found: %s" % [tab_id, scene_path])
				continue

		var display_name: String = DictUtils.get_string(tab_def, "display_name", tab_id.capitalize())
		var category: String = DictUtils.get_string(tab_def, "category", "content")
		var priority: int = DictUtils.get_int(tab_def, "priority", 100)

		_tabs[tab_id] = {
			"id": tab_id,
			"display_name": display_name,
			"scene_path": scene_path,
			"category": category,
			"priority": priority,
			"source_mod": "",
			"refresh_method": "refresh",
			"is_static": is_static
		}

	_cache_dirty = true
	registrations_changed.emit()


# =============================================================================
# REGISTRATION API
# =============================================================================

## Register a tab from a mod's editor_extensions
## @param mod_id: The mod providing this tab
## @param ext_id: The extension ID within the mod
## @param config: The extension configuration from mod.json
## @param mod_directory: The mod's base directory
func register_mod_tab(mod_id: String, ext_id: String, config: Dictionary, mod_directory: String) -> void:
	var tab_id: String = "%s:%s" % [mod_id, ext_id]

	var scene_path: String = DictUtils.get_string(config, "editor_scene", "")
	if scene_path.is_empty():
		push_warning("EditorTabRegistry: Mod '%s' tab '%s' missing editor_scene" % [mod_id, ext_id])
		return

	# Security: Validate path doesn't attempt directory traversal
	if ".." in scene_path or scene_path.begins_with("/"):
		push_warning("EditorTabRegistry: Mod '%s' tab '%s' has invalid path (traversal attempt blocked)" % [mod_id, ext_id])
		return

	# Resolve full path
	var full_path: String = mod_directory.path_join(scene_path)

	# Security: Use simplify_path() for canonical path comparison to prevent traversal attacks
	var canonical_mod: String = mod_directory.simplify_path()
	var canonical_full: String = full_path.simplify_path()
	if not canonical_full.begins_with(canonical_mod):
		push_warning("EditorTabRegistry: Mod '%s' tab '%s' path escapes mod directory (blocked)" % [mod_id, ext_id])
		return

	if not ResourceLoader.exists(full_path):
		push_warning("EditorTabRegistry: Mod '%s' tab '%s' scene not found: %s" % [mod_id, ext_id, full_path])
		return

	var tab_name: String = DictUtils.get_string(config, "tab_name", ext_id)
	var priority: int = DictUtils.get_int(config, "priority", 100)
	var refresh_method: String = DictUtils.get_string(config, "refresh_method", "refresh")

	_tabs[tab_id] = {
		"id": tab_id,
		"display_name": "[%s] %s" % [mod_id, tab_name],
		"scene_path": full_path,
		"category": "mod",
		"priority": priority,
		"source_mod": mod_id,
		"refresh_method": refresh_method,
		"is_static": false
	}

	_cache_dirty = true
	tab_registered.emit(tab_id)
	registrations_changed.emit()


## Register a custom tab programmatically
## Used for special tabs that aren't defined in BUILTIN_TABS or mod.json
func register_tab(tab_id: String, display_name: String, scene_path: String,
		category: String = "content", priority: int = 100) -> void:
	if tab_id.is_empty():
		push_error("EditorTabRegistry: Cannot register tab with empty ID")
		return

	_tabs[tab_id] = {
		"id": tab_id,
		"display_name": display_name,
		"scene_path": scene_path,
		"category": category if category in CATEGORIES else "content",
		"priority": priority,
		"source_mod": "",
		"refresh_method": "refresh",
		"is_static": false
	}

	_cache_dirty = true
	tab_registered.emit(tab_id)
	registrations_changed.emit()


## Unregister a tab
func unregister_tab(tab_id: String) -> void:
	if tab_id in _tabs:
		_tabs.erase(tab_id)
		if tab_id in _instances:
			_instances.erase(tab_id)
		_cache_dirty = true
		tab_unregistered.emit(tab_id)
		registrations_changed.emit()


## Clear all mod-provided tabs (called on mod reload)
func clear_mod_registrations() -> void:
	var to_remove: Array[String] = []
	for tab_id: String in _tabs.keys():
		var tab_info: Dictionary = _tabs[tab_id]
		var source_mod_str: String = DictUtils.get_string(tab_info, "source_mod", "")
		if not source_mod_str.is_empty():
			to_remove.append(tab_id)

	for tab_id: String in to_remove:
		_tabs.erase(tab_id)
		if tab_id in _instances:
			_instances.erase(tab_id)

	_cache_dirty = true
	registrations_changed.emit()


# =============================================================================
# INSTANCE MANAGEMENT
# =============================================================================

## Store a reference to a tab's Control instance
## Called by MainPanel after instantiating the tab
func set_instance(tab_id: String, instance: Control) -> void:
	_instances[tab_id] = instance


## Get a tab's Control instance
## Returns null if the tab doesn't exist or has been freed
func get_instance(tab_id: String) -> Control:
	if tab_id in _instances:
		var instance: Control = _instances[tab_id]
		if is_instance_valid(instance):
			return instance
	return null


## Check if a tab has been instantiated and is still valid
## Uses is_instance_valid() to properly detect freed nodes
func has_instance(tab_id: String) -> bool:
	if tab_id in _instances:
		var instance: Control = _instances[tab_id]
		return is_instance_valid(instance)
	return false


# =============================================================================
# LOOKUP API
# =============================================================================

## Get all registered tab IDs
func get_all_tab_ids() -> Array[String]:
	var result: Array[String] = []
	for tab_id: String in _tabs.keys():
		result.append(tab_id)
	return result


## Get all tabs sorted by category and priority
func get_all_tabs_sorted() -> Array[Dictionary]:
	_rebuild_cache_if_dirty()
	return _sorted_tabs.duplicate(true)


## Get tabs in a specific category, sorted by priority
func get_tabs_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tab: Dictionary in get_all_tabs_sorted():
		var tab_category_str: String = DictUtils.get_string(tab, "category", "")
		if tab_category_str == category:
			result.append(tab.duplicate())
	return result


## Get a specific tab's metadata
func get_tab(tab_id: String) -> Dictionary:
	if tab_id in _tabs:
		return _tabs[tab_id].duplicate()
	return {}


## Check if a tab is registered
func has_tab(tab_id: String) -> bool:
	return tab_id in _tabs


## Get which mod provided a tab (empty for built-in)
func get_source_mod(tab_id: String) -> String:
	if tab_id in _tabs:
		var tab_info: Dictionary = _tabs[tab_id]
		return DictUtils.get_string(tab_info, "source_mod", "")
	return ""


## Get a tab's display name
func get_display_name(tab_id: String) -> String:
	if tab_id in _tabs:
		var tab_info: Dictionary = _tabs[tab_id]
		return DictUtils.get_string(tab_info, "display_name", tab_id.capitalize())
	return tab_id.capitalize()


## Get a tab's scene path
func get_scene_path(tab_id: String) -> String:
	if tab_id in _tabs:
		var tab_info: Dictionary = _tabs[tab_id]
		return DictUtils.get_string(tab_info, "scene_path", "")
	return ""


## Check if a tab is static (no scene, created programmatically)
func is_static_tab(tab_id: String) -> bool:
	if tab_id in _tabs:
		var tab_info: Dictionary = _tabs[tab_id]
		return DictUtils.get_bool(tab_info, "is_static", false)
	return false


# =============================================================================
# CATEGORY API (Two-Tier Navigation)
# =============================================================================

## Get all categories that have at least one registered tab
func get_active_categories() -> Array[String]:
	var active: Array[String] = []
	for category: String in CATEGORIES:
		if not get_tabs_by_category(category).is_empty():
			active.append(category)
	return active


## Get display name for a category
func get_category_display_name(category: String) -> String:
	if category in CATEGORY_DISPLAY_NAMES:
		var display_name: Variant = CATEGORY_DISPLAY_NAMES[category]
		if display_name is String:
			return display_name
		return category.capitalize()
	return category.capitalize()


## Get all category display names (for categories with tabs)
func get_category_display_names() -> Dictionary:
	var result: Dictionary = {}
	for category: String in get_active_categories():
		result[category] = get_category_display_name(category)
	return result


# =============================================================================
# REFRESH API
# =============================================================================

## Refresh all tabs that have instances
## Calls the registered refresh method on each tab
func refresh_all() -> void:
	for tab_id: String in _instances.keys():
		refresh_tab(tab_id)


## Refresh a specific tab
func refresh_tab(tab_id: String) -> void:
	if tab_id not in _tabs:
		# Tab unregistered, clean up stale instance if present
		if tab_id in _instances:
			_instances.erase(tab_id)
		return

	if tab_id not in _instances:
		return

	var instance: Control = _instances[tab_id]
	if not is_instance_valid(instance):
		# Instance was freed, clean up the stale reference
		_instances.erase(tab_id)
		return

	var tab_info: Dictionary = _tabs[tab_id]
	var refresh_method: String = DictUtils.get_string(tab_info, "refresh_method", "refresh")

	# Security: Only allow safe refresh method names
	if not _is_safe_refresh_method(refresh_method):
		push_warning("EditorTabRegistry: Tab '%s' has unsafe refresh_method '%s'" % [tab_id, refresh_method])
		return

	if instance.has_method(refresh_method):
		instance.call(refresh_method)


## Validate that a refresh method name is safe
func _is_safe_refresh_method(method_name: String) -> bool:
	return method_name.begins_with("refresh") or method_name.begins_with("_refresh")


# =============================================================================
# CACHE MANAGEMENT
# =============================================================================

## Rebuild the sorted tab cache
func _rebuild_cache_if_dirty() -> void:
	if not _cache_dirty:
		return

	_sorted_tabs.clear()

	for tab_id: String in _tabs.keys():
		_sorted_tabs.append(_tabs[tab_id].duplicate())

	# Sort by category order, then by priority within category
	_sorted_tabs.sort_custom(_compare_tabs)

	_cache_dirty = false


## Compare two tabs for sorting
func _compare_tabs(a: Dictionary, b: Dictionary) -> bool:
	var cat_a: String = DictUtils.get_string(a, "category", "content")
	var cat_b: String = DictUtils.get_string(b, "category", "content")

	var cat_order_a: int = CATEGORIES.find(cat_a)
	var cat_order_b: int = CATEGORIES.find(cat_b)

	# Unknown categories go to the end
	if cat_order_a < 0:
		cat_order_a = CATEGORIES.size()
	if cat_order_b < 0:
		cat_order_b = CATEGORIES.size()

	# Different categories: sort by category order
	if cat_order_a != cat_order_b:
		return cat_order_a < cat_order_b

	# Same category: sort by priority
	var priority_a: int = DictUtils.get_int(a, "priority", 100)
	var priority_b: int = DictUtils.get_int(b, "priority", 100)
	return priority_a < priority_b


# =============================================================================
# UTILITY API
# =============================================================================

## Get registration stats for debugging
func get_stats() -> Dictionary[String, int]:
	var builtin_count: int = 0
	var mod_count: int = 0

	for tab_id: String in _tabs.keys():
		var tab_info: Dictionary = _tabs[tab_id]
		var source_mod_str: String = DictUtils.get_string(tab_info, "source_mod", "")
		if source_mod_str.is_empty():
			builtin_count += 1
		else:
			mod_count += 1

	return {
		"total_tabs": _tabs.size(),
		"builtin_tabs": builtin_count,
		"mod_tabs": mod_count,
		"instantiated": _instances.size()
	}
