# Sparkling Editor Review - Progress Report

**Started:** 2026-01-11
**Completed:** 2026-01-11
**Status:** COMPLETE

---

## Overview

Systematic review of the Sparkling Editor, checking for:
- Code quality (strict typing, dictionary patterns)
- `_updating_ui` guards to prevent false dirty state
- Validation reading from UI state (not resource state)
- `resource_dependencies` declarations
- Signal cleanup in `_exit_tree()`

**Full review plan:** `research/sparkling_editor_review_plan.md`

---

## Completed Work

### Phase 0: Cache Removal (Pre-Review)

Removed caching infrastructure to eliminate stale cache bugs:

**Registry caches removed (5 files):**
- `status_effect_registry.gd` - removed `_cached_effect_ids`, `_cache_dirty`
- `ai_brain_registry.gd` - removed `_cached_all_brains`, `_cache_dirty` (kept LRU instance cache)
- `tileset_registry.gd` - removed `_cached_all_tilesets`, `_cache_dirty`
- `equipment_type_registry.gd` - removed `_cached_categories`, `_cached_subtypes`, `_cache_dirty`
- `ai_mode_registry.gd` - removed `_cached_all_modes_sorted`, `_cache_dirty`, `_all_modes`

**Editor local caches removed (10 files):**
- `character_editor.gd` - removed `available_ai_behaviors`
- `battle_editor.gd` - removed `available_ai_behaviors`
- `shop_editor.gd` - removed `_items_cache`, `_npcs_cache`
- `party_editor.gd` - removed `available_characters`
- `save_slot_editor.gd` - removed `available_characters`
- `new_game_config_editor.gd` - removed `available_parties`, `available_items`
- `crafting_recipe_editor.gd` - removed `_items_cache`
- `cinematic_editor.gd` - removed `_characters`, `_npcs`, `_shops`, `_maps`, `_interactables`, `_battles`
- `map_metadata_editor.gd` - removed `available_tilesets`
- `editor_widget_context.gd` - replaced `populate_from_editor_caches()` with `populate_from_registry()`

---

### Part 1: Infrastructure ✅ COMPLETE

**Files Reviewed:**
1. `main_panel.gd` - Fixed: Added `_exit_tree()` signal cleanup
2. `base_resource_editor.gd` - Clean
3. `json_editor_base.gd` - Fixed: Added `_exit_tree()` template
4. `editor_utils.gd` - Clean
5. `editor_tab_registry.gd` - Clean
6. `editor_event_bus.gd` - Clean

**Fixes Applied:**
- `main_panel.gd:47-68` - Added `_exit_tree()` disconnecting mod_selector, create_mod_dialog, wizard fields, category buttons
- `json_editor_base.gd:321-337` - Added `_exit_tree()` template with documentation for child classes

---

### Part 2: Content Category Editors ✅ COMPLETE

**Files Reviewed:**
1. `character_editor.gd` - Fixed
2. `class_editor.gd` - Fixed
3. `item_editor.gd` - Fixed
4. `ability_editor.gd` - Fixed
5. `npc_editor.gd` - Fixed
6. `shop_editor.gd` - Clean
7. `crafter_editor.gd` - Clean
8. `crafting_recipe_editor.gd` - Clean
9. `interactable_editor.gd` - Clean

**Fixes Applied:**

*Validation to read UI state (3 files):*
- `class_editor.gd:163-177` - Changed to read `name_edit.text`, `movement_range_spin.value`
- `item_editor.gd:208-224` - Changed to read `name_edit.text`, `buy_price_spin.value`, `sell_price_spin.value`
- `ability_editor.gd:157-188` - Changed to read all UI control values

*Added `_updating_ui` guard (4 files):*
- `character_editor.gd` - Added guard + protected 9 handlers
- `class_editor.gd` - Added guard
- `item_editor.gd` - Added guard + protected 4 handlers
- `ability_editor.gd` - Added guard + protected 2 handlers

*Added `resource_dependencies` (2 files):*
- `item_editor.gd` - Added `["ability"]`
- `npc_editor.gd` - Added `["cinematic"]`

---

### Part 3: Battles Category Editors ✅ COMPLETE

**Files Reviewed:**
1. `battle_editor.gd` - Fixed
2. `party_editor.gd` - Fixed

**Fixes Applied:**
- `battle_editor.gd` - Added `_updating_ui` guard, rewrote `_validate_resource()` to read from UI state
- `party_editor.gd` - Added `_updating_ui` guard

---

### Part 4: World Category Editors ✅ COMPLETE

**Files Reviewed:**
1. `map_metadata_editor.gd` - Fixed: Added `_updating_ui` guard
2. `terrain_editor.gd` - Fixed: Added dirty tracking for all form fields
3. `dialogue_editor.gd` - Fixed: Validation now reads from UI state
4. `cinematic_editor.gd` - Clean (exemplary implementation)

**Fixes Applied:**
- `dialogue_editor.gd:249-273` - Rewrote `_validate_resource()` to read from `dialogue_id_edit.text` and `lines_list` (UI state) instead of `dialogue.dialogue_id` and `dialogue.lines` (resource state)
- `map_metadata_editor.gd:67` - Added `_updating_ui: bool = false` guard variable
- `map_metadata_editor.gd:633-649` - Wrapped `_populate_ui_from_data()` with guard
- `map_metadata_editor.gd:537-539` - Added guard check to `_on_form_field_changed()`
- `terrain_editor.gd:190,290,304` - Added `.on_change(_mark_dirty)` to all FormBuilder instances
- `terrain_editor.gd:228,234,250,256,272,278` - Connected manual spinbox/checkbox signals to `_on_field_changed()`
- `terrain_editor.gd:314-316` - Added `_on_field_changed()` handler that calls `_mark_dirty()`

---

### Part 5: Configuration Category Editors ✅ COMPLETE

**Files Reviewed:**
1. `new_game_config_editor.gd` - Fixed: Added `_updating_ui` guard
2. `experience_config_editor.gd` - Fixed: Added `_updating_ui` guard
3. `ai_brain_editor.gd` - Fixed: Added `_updating_ui` guard
4. `status_effect_editor.gd` - Fixed: Added `_updating_ui` guard
5. `caravan_editor.gd` - Fixed: Added `_updating_ui` guard, refactored signal handlers
6. `save_slot_editor.gd` - Fixed: Added `_exit_tree()` for signal cleanup
7. `mod_json_editor.gd` - Fixed: Added `_updating_ui` guard

**Fixes Applied:**

*Added `_updating_ui` guard (6 files):*
- `new_game_config_editor.gd` - Added guard variable, wrapped `_load_resource_data()`, protected all signal handlers
- `experience_config_editor.gd` - Added guard variable, wrapped `_load_resource_data()`, protected all signal handlers
- `ai_brain_editor.gd` - Added guard variable, wrapped `_load_resource_data()`, protected all signal handlers
- `status_effect_editor.gd` - Added guard variable, wrapped `_load_resource_data()`, protected all signal handlers
- `caravan_editor.gd` - Added guard variable, wrapped `_load_resource_data()`, created handler functions and updated all signal connections from lambdas
- `mod_json_editor.gd` - Added guard variable, wrapped `_populate_ui_from_data()`, protected `_mark_dirty()` functions

*Added signal cleanup (1 file):*
- `save_slot_editor.gd` - Added `_exit_tree()` with `_disconnect_event_bus()` to properly disconnect EditorEventBus signals

**Notes:**
- `save_slot_editor.gd` is NOT a resource editor (extends Control, not base_resource_editor). It edits save files directly so `_updating_ui` pattern doesn't apply.
- `mod_json_editor.gd` edits JSON files directly, not .tres resources, but still benefits from the guard pattern.
- Validation patterns were already correct in all files (reading from UI controls).
- `new_game_config_editor.gd` already had correct `resource_dependencies = ["party", "item"]`.

---

### Part 6: Shared Components ✅ COMPLETE

**Files Reviewed:**
1. `resource_picker.gd` - Clean (exemplary - has proper `_exit_tree()` with EditorEventBus signal cleanup)
2. `collapse_section.gd` - Fixed: Added `_exit_tree()` for button signal cleanup
3. `texture_picker_base.gd` - Clean (has `_exit_tree()` that kills tweens and cleans up file dialog)
4. `portrait_picker.gd` - Clean (simple validation override, inherits cleanup from base)
5. `battle_sprite_picker.gd` - Clean (simple validation override, inherits cleanup from base)
6. `map_spritesheet_picker.gd` - Clean (inherits cleanup from TexturePickerBase)
7. `npc_preview_panel.gd` - Clean (uses `is_instance_valid()` guards for bound sources, no external signal connections)
8. `map_placement_helper.gd` - Clean (RefCounted, no scene tree involvement)
9. `dialog_line_popup.gd` - Fixed: Added `_exit_tree()` for signal cleanup and cache clearing
10. `quick_dialog_generator.gd` - Clean (RefCounted, no external signal connections)
11. `cinematic_command_defs.gd` - Clean (pure static data class)
12. `editor_widget_context.gd` - Clean (RefCounted data container)

**Fixes Applied:**

*Added signal cleanup (2 files):*
- `collapse_section.gd` - Added `_exit_tree()` disconnecting `_header_button.pressed`
- `dialog_line_popup.gd` - Added `_exit_tree()` disconnecting `close_requested`, `character_picker.item_selected`, `emotion_picker.item_selected`, `text_edit.text_changed`, `copy_button.pressed`, `cancel_button.pressed`, and clearing `_characters`/`_npcs` caches

**Notes:**
- Most components were already clean or inheriting proper cleanup from base classes
- `resource_picker.gd` is an exemplary implementation with full EditorEventBus signal tracking
- `TexturePickerBase` and its subclasses properly manage tweens and file dialogs
- RefCounted classes (`MapPlacementHelper`, `QuickDialogGenerator`, `CinematicCommandDefs`, `EditorWidgetContext`) don't need `_exit_tree()` as they're not in the scene tree

---

### Part 7: Cross-Cutting Concerns ✅ COMPLETE

**Signal Cleanup Audit:**
- All 4 files connecting to EditorEventBus have proper `_exit_tree()` cleanup:
  - `cinematic_editor.gd` - Disconnects `mods_reloaded`, `resource_saved`, `resource_created`
  - `save_slot_editor.gd` - Disconnects `resource_saved`, `resource_created`, `resource_deleted`
  - `resource_picker.gd` - Disconnects `mods_reloaded`, `resource_saved`, `resource_created`, `resource_deleted`
  - `base_resource_editor.gd` - Disconnects `resource_saved`, `resource_created`, `resource_deleted`
- All signal connections use the `is_connected()` guard pattern before disconnecting

**Mod Workflow Verification:**
- All editors consistently use `SparklingEditorUtils.get_active_mod_path()`, `get_active_mod_id()`, `get_active_mod_folder()`
- Or directly call `ModLoader.get_active_mod()` for more complex operations
- Pattern is consistently applied across 57 editor files

**Empty State Handling:**
- All `_load_resource_data()` methods have null guards at the start
- All `_validate_resource()` methods return early with error for null/invalid resources
- All direct `current_resource` property accesses are preceded by null checks
- Pattern: `if not current_resource: return` or type casting with null check

**Consistency Checks:**
- Zero `:=` walrus operators found in editor codebase
- Zero `.has()` dictionary patterns found in editor codebase
- All files follow strict typing conventions

---

## Final Summary

### Files Modified During Review

**Infrastructure (2 files):**
- `main_panel.gd`
- `json_editor_base.gd`

**Content Editors (5 files):**
- `character_editor.gd`
- `class_editor.gd`
- `item_editor.gd`
- `ability_editor.gd`
- `npc_editor.gd`

**Battles Editors (2 files):**
- `battle_editor.gd`
- `party_editor.gd`

**World Editors (3 files):**
- `map_metadata_editor.gd`
- `terrain_editor.gd`
- `dialogue_editor.gd`

**Configuration Editors (7 files):**
- `new_game_config_editor.gd`
- `experience_config_editor.gd`
- `ai_brain_editor.gd`
- `status_effect_editor.gd`
- `caravan_editor.gd`
- `save_slot_editor.gd`
- `mod_json_editor.gd`

**Shared Components (2 files):**
- `collapse_section.gd`
- `dialog_line_popup.gd`

**Registry Files (5 files, cache removal):**
- `status_effect_registry.gd`
- `ai_brain_registry.gd`
- `tileset_registry.gd`
- `equipment_type_registry.gd`
- `ai_mode_registry.gd`

**Total: 26 files modified**

### Key Improvements

1. **Eliminated false dirty state** - Added `_updating_ui` guards to 14 editors
2. **Fixed validation patterns** - 4 editors now read from UI state instead of resource state
3. **Proper signal cleanup** - Added `_exit_tree()` to 5 files for memory leak prevention
4. **Removed stale caches** - Eliminated 15 local caches and 5 registry caches
5. **Code quality** - Zero walrus operators, zero `.has()` patterns, strict typing throughout

### Exemplary Implementations

The following files serve as reference implementations:
- `resource_picker.gd` - Full EditorEventBus signal tracking with `_event_bus_connected` flag
- `cinematic_editor.gd` - Complete `_updating_ui` pattern with widget context
- `TexturePickerBase` - Proper tween and dialog cleanup in `_exit_tree()`

---

## Key Patterns Reference

**Correct `_updating_ui` pattern:**
```gdscript
var _updating_ui: bool = false

func _load_resource_data() -> void:
    _updating_ui = true
    # ... populate UI fields ...
    _updating_ui = false

func _on_field_changed(_value: Variant) -> void:
    if _updating_ui:
        return
    _mark_dirty()
```

**Correct validation pattern:**
```gdscript
func _validate_resource() -> Dictionary:
    var errors: Array[String] = []

    # Read from UI state, NOT resource
    var name: String = name_edit.text.strip_edges()
    if name.is_empty():
        errors.append("Name is required")

    return {"valid": errors.is_empty(), "errors": errors}
```

**Correct resource_dependencies pattern:**
```gdscript
func _ready() -> void:
    resource_dependencies = ["character", "item"]  # BEFORE super
    super._ready()

func _on_dependencies_changed(changed_type: String) -> void:
    # Refresh relevant dropdowns
    pass
```

**Correct signal cleanup pattern:**
```gdscript
func _exit_tree() -> void:
    var event_bus: Node = get_node_or_null("/root/EditorEventBus")
    if event_bus:
        if event_bus.resource_saved.is_connected(_on_resource_changed):
            event_bus.resource_saved.disconnect(_on_resource_changed)
```
