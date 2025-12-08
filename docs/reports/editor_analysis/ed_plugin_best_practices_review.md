# Sparkling Editor Plugin - Best Practices Audit Report

**Auditor**: Ed (Editor Plugin Specialist)
**Date**: 2025-12-08
**Status**: Complete

---

## Executive Summary

This audit evaluates the Sparkling Editor plugin (`addons/sparkling_editor/`) against Godot EditorPlugin best practices, focusing on plugin architecture, lifecycle management, API usage, and maintainability.

**Overall Assessment**: The plugin demonstrates solid foundational architecture with a well-designed tab registry system and proper base class inheritance. However, there are areas for improvement in cleanup patterns, undo/redo implementation, and some code organization.

---

## Table of Contents

1. [Plugin Architecture](#1-plugin-architecture)
2. [Lifecycle Management](#2-lifecycle-management)
3. [Editor API Usage](#3-editor-api-usage)
4. [Theme Compliance](#4-theme-compliance)
5. [Performance Considerations](#5-performance-considerations)
6. [Code Organization](#6-code-organization)
7. [Individual Tab Analysis](#7-individual-tab-analysis)
8. [Recommendations](#8-recommendations)

---

## 1. Plugin Architecture

### 1.1 Main Plugin Entry Point (`editor_plugin.gd`)

**Status**: Good

**Strengths**:
- Properly extends `EditorPlugin` (line 2)
- Uses `@tool` annotation (line 1)
- Clean `_enter_tree()` and `_exit_tree()` implementation
- Correctly registers EditorEventBus as autoload singleton
- Uses bottom panel (appropriate for this type of tool)

**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/editor_plugin.gd`

```gdscript
func _exit_tree() -> void:
    if main_panel:
        remove_control_from_bottom_panel(main_panel)
        main_panel.queue_free()
    remove_autoload_singleton("EditorEventBus")
```

**Minor Issue**: The cleanup order is correct (remove from panel before freeing), which is good practice.

### 1.2 Tab Registry System (`editor_tab_registry.gd`)

**Status**: Excellent

**Strengths**:
- Uses `class_name EditorTabRegistry` for clean access
- Decoupled registration system allows adding editors without modifying MainPanel
- Security validation for mod-provided tabs (path traversal prevention, lines 164-173)
- Caching with dirty flag pattern for sorted tabs
- Proper signals for registration changes
- Safe refresh method validation (line 379-380)

**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/editor_tab_registry.gd`

```gdscript
# Security: Validate path doesn't attempt directory traversal
if ".." in scene_path or scene_path.begins_with("/"):
    push_warning("EditorTabRegistry: Mod '%s' tab '%s' has invalid path (traversal attempt blocked)" % [mod_id, ext_id])
    return
```

**Suggestion**: Consider adding a validation for script injection through refresh_method beyond the prefix check.

### 1.3 EditorEventBus (`editor_event_bus.gd`)

**Status**: Good

**Strengths**:
- Proper debouncing for expensive signals (mods_reloaded)
- Well-documented signals with parameter types
- Convenience methods for common operations
- Properly creates and cleans up timer in `_ready()`

**Minor Issue**: Timer cleanup not explicitly handled in `_exit_tree()`, though Node's default cleanup should handle it.

### 1.4 Base Resource Editor (`base_resource_editor.gd`)

**Status**: Very Good

**Strengths**:
- Comprehensive base class for all resource editors
- Automatic dependency tracking via EditorEventBus
- Built-in unsaved changes warning system
- Cross-mod workflow support (Copy to My Mod, Create Override)
- EditorUndoRedoManager integration (optional per-editor)
- Namespace conflict detection
- Visual feedback (error panels, success messages)
- Keyboard shortcuts (Ctrl+S, Ctrl+N, Ctrl+D, Ctrl+F, Delete, Escape)

**Areas for Improvement**:
- Signal connections in `_setup_dependency_tracking()` are not disconnected on cleanup (potential memory leak if tabs are removed/recreated)
- Uses `_input()` for keyboard handling instead of `_shortcut_input()` or proper action mapping

**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/base_resource_editor.gd`

Lines 332-339 - Signal connections without cleanup tracking:
```gdscript
if not event_bus.resource_saved.is_connected(_on_dependency_resource_changed):
    event_bus.resource_saved.connect(_on_dependency_resource_changed)
```

---

## 2. Lifecycle Management

### 2.1 Plugin Enable/Disable

**Status**: Good

The main plugin properly handles:
- Adding autoload singleton
- Instantiating main panel
- Adding to bottom panel
- Cleanup in `_exit_tree()`

### 2.2 Tab Lifecycle

**Status**: Needs Attention

**Issue**: When tabs are dynamically created from the registry, there's no corresponding cleanup system for individual tab signal connections.

**Affected File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/main_panel.gd`

In `_reload_mod_tabs()` (lines 216-245), mod tabs are removed by calling `queue_free()`, but there's no mechanism to ensure those tabs disconnect from EditorEventBus first.

**Severity**: Minor (Godot handles most cases automatically, but could cause issues with very long editor sessions)

### 2.3 Resource Cleanup

**Status**: Generally Good

The base_resource_editor properly:
- Clears arrays when refreshing lists
- Handles dialog cleanup
- Uses `is_instance_valid()` checks before using cached references

---

## 3. Editor API Usage

### 3.1 EditorUndoRedoManager

**Status**: Implemented but Underutilized

**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/base_resource_editor.gd`

**Strengths**:
- Correctly retrieves via `EditorInterface.get_editor_undo_redo()` (line 84)
- Helper methods provided (`_begin_undo_action`, `_commit_undo_action`, etc.)
- State capture/restore system implemented

**Issue**: The `enable_undo_redo` flag defaults to `false` (line 21), meaning most editors don't actually use undo/redo:

```gdscript
# Enable undo/redo for save operations (set in subclass)
var enable_undo_redo: bool = false
```

**Severity**: Major - Users expect Ctrl+Z to work in editor tools

### 3.2 EditorInterface Usage

**Status**: Good

Proper usage of:
- `EditorInterface.get_editor_undo_redo()`
- `EditorInterface.get_resource_filesystem().scan()`
- `EditorInterface.get_base_control()` (in theme utils)

### 3.3 Resource Loading/Saving

**Status**: Good

- Uses `ResourceSaver.save()` properly
- Triggers filesystem scan after creating new resources
- Duplicates loaded resources before editing (prevents corrupting cache)

---

## 4. Theme Compliance

### 4.1 EditorThemeUtils (`editor_theme_utils.gd`)

**Status**: Excellent

**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/editor_theme_utils.gd`

**Strengths**:
- Static utility class with proper `class_name`
- Accesses colors through `EditorInterface.get_base_control().get_theme_color()`
- Provides fallback colors for non-editor contexts
- Creates themed StyleBoxes for consistent UI

**Note**: The success color is hardcoded (line 59) rather than derived from theme, which is acceptable since Godot doesn't define a standard success color.

### 4.2 Hardcoded Colors

**Status**: Needs Review

Several places still use hardcoded colors instead of theme utils:

**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/base_resource_editor.gd`
- Line 197: `Color(0.7, 0.7, 0.7)` for help text
- Line 1118: `[color=#6699cc]` hardcoded blue for info messages

**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/editor_utils.gd`
- Line 71: `Color(0.6, 0.6, 0.6)` for help labels

**Severity**: Minor - These work but don't adapt to light themes

---

## 5. Performance Considerations

### 5.1 List Population

**Status**: Acceptable

The base resource editor scans directories synchronously, which could cause brief freezes with many resources. However:
- Uses filtering to reduce displayed items
- Caching is employed for registry lookups

### 5.2 Debouncing

**Status**: Good

EditorEventBus implements debouncing for `mods_reloaded` signal (100ms delay), preventing rapid-fire refreshes.

### 5.3 Cache Invalidation

**Status**: Good

Tab registry uses dirty flag pattern to avoid rebuilding sorted list unnecessarily.

---

## 6. Code Organization

### 6.1 File Structure

**Status**: Good

```
addons/sparkling_editor/
  plugin.cfg
  editor_plugin.gd          # Main entry point
  editor_event_bus.gd       # Communication singleton
  editor_tab_registry.gd    # Tab management
  ui/
    main_panel.gd/.tscn     # Tab container
    base_resource_editor.gd # Base class for editors
    editor_theme_utils.gd   # Theme utilities
    editor_utils.gd         # General utilities
    *_editor.gd/.tscn       # Individual editors
    components/             # Reusable UI components
```

### 6.2 Inheritance Hierarchy

**Status**: Good

- All resource editors extend `base_resource_editor.gd`
- JSON editors extend `json_editor_base.gd`
- Consistent patterns across editors

### 6.3 Code Duplication

**Status**: Needs Review

Both `EditorThemeUtils` and `SparklingEditorUtils` define:
- `DEFAULT_LABEL_WIDTH: int = 140`
- `SECTION_FONT_SIZE: int = 16`
- `HELP_FONT_SIZE: int = 12`

**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/editor_theme_utils.gd` (lines 14-18)
**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/editor_utils.gd` (lines 13-22)

**Severity**: Minor - Could consolidate to single source of truth

---

## 7. Individual Tab Analysis

This section provides detailed analysis of each editor tab, evaluating best practices compliance, UX patterns, and specific issues.

### 7.1 NPC Editor (`npc_editor.gd`)

**Status**: Excellent - Best Practice Example

**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/npc_editor.gd` (1149 lines)

**Strengths**:
- **Proper signal cleanup**: Implements `_exit_tree()` to disconnect EditorEventBus signals (lines 110-113):
  ```gdscript
  func _exit_tree() -> void:
      var event_bus: Node = get_node_or_null("/root/EditorEventBus")
      if event_bus and event_bus.mods_reloaded.is_connected(_on_mods_reloaded):
          event_bus.mods_reloaded.disconnect(_on_mods_reloaded)
  ```
- Uses `_updating_ui` flag to prevent signal feedback loops during UI population
- Well-organized into components: NPCPreviewPanel, MapPlacementHelper, QuickDialogGenerator
- Comprehensive validation before saving

**Recommendation**: Use this editor as a template for signal cleanup patterns.

---

### 7.2 Resource Picker Component (`components/resource_picker.gd`)

**Status**: Excellent - Reusable Component

**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/components/resource_picker.gd` (454 lines)

**Strengths**:
- Proper `_exit_tree()` signal cleanup (lines 101-106)
- Mod-aware resource selection with cross-mod support
- Override detection for same resource ID across multiple mods
- Flexible configuration via `allowed_mods` filter

**Best Practice Example**:
```gdscript
func _exit_tree() -> void:
    var event_bus: Node = get_node_or_null("/root/EditorEventBus")
    if event_bus:
        if event_bus.mods_reloaded.is_connected(_on_mods_reloaded):
            event_bus.mods_reloaded.disconnect(_on_mods_reloaded)
```

---

### 7.3 Collapse Section Component (`components/collapse_section.gd`)

**Status**: Good - Clean UI Component

**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/components/collapse_section.gd` (173 lines)

**Strengths**:
- Clean collapsible UI with `class_name CollapseSection`
- Proper exports: title, start_collapsed, title_font_size
- `add_content_child()` method for safe child addition
- Handles deferred initialization gracefully

**Minor Issue**: Uses ASCII `[+]/[-]` instead of Unicode arrows, which is acceptable for compatibility.

---

### 7.4 JSON Editor Base (`json_editor_base.gd`)

**Status**: Very Good - Shared Base Class

**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/json_editor_base.gd` (350 lines)

**Strengths**:
- Clean JSON loading/saving with proper error handling
- EditorEventBus integration via helper methods
- `scan_all_mods_for_resources()` for consistent resource discovery
- Reusable error panel creation

**Note**: Provides a different inheritance path from `base_resource_editor.gd` for JSON-based content (maps, cinematics, campaigns).

---

### 7.5 Battle Editor (`battle_editor.gd`)

**Status**: Good - Complex Editor

**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/battle_editor.gd` (1465 lines)

**Strengths**:
- Visual map preview integration
- Uses ResourcePicker for cross-mod support
- Uses CollapseSection for enemy/neutral forces
- Debounced preview updates via `_schedule_preview_update()`
- Comprehensive validation in `_collect_battle_validation_errors()`

**Areas for Improvement**:
- Large file (1465 lines) - could benefit from component extraction
- Many hardcoded minimum sizes rather than theme-based values

---

### 7.6 Campaign Editor (`campaign_editor.gd`)

**Status**: Very Good - Advanced GraphEdit Usage

**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/campaign_editor.gd` (1155 lines)

**Strengths**:
- Uses `GraphEdit` for visual campaign flow editing
- Node type color-coding (battle=red, scene=blue, cutscene=yellow, choice=purple)
- Hub nodes get green border, start nodes get teal accent
- Proper connection/disconnection handling
- `_updating_ui` flag prevents recursive updates

**Areas for Improvement**:
- Hardcoded colors in `NODE_COLORS` constant (lines 8-14) - should use theme utils
- Error panel creates its own StyleBox (lines 213-219) instead of using EditorThemeUtils
- No `_exit_tree()` signal cleanup

**Issue - Missing Cleanup**:
```gdscript
# Campaign editor connects to item_selected but never disconnects
campaign_list.item_selected.connect(_on_campaign_selected)
```

---

### 7.7 Map Metadata Editor (`map_metadata_editor.gd`)

**Status**: Good - Extends JsonEditorBase

**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/map_metadata_editor.gd` (1174 lines)

**Strengths**:
- Extends `JsonEditorBase` for shared functionality
- Comprehensive map creation wizard with dialog
- Generates map script, scene, and metadata files together
- Tileset integration via TilesetRegistry
- Scene-as-truth architecture support

**Areas for Improvement**:
- Hardcoded colors for help text (lines 110-111, 242-243, etc.):
  ```gdscript
  help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
  ```
- No `_exit_tree()` signal cleanup for map_list.item_selected connection

**UX Note**: The "Browse..." button shows an error message instead of opening a file dialog, which is a known limitation of editor plugin context.

---

### 7.8 Resource Editors (Character, Class, Item, Ability, etc.)

**Status**: Consistent - Follow Base Pattern

All resource editors extending `base_resource_editor.gd` share consistent patterns:
- List/detail split layout
- Filter/search functionality
- Create/Edit/Delete operations
- Cross-mod workflow support

**Common Issues Across Resource Editors**:
1. Most do NOT implement `_exit_tree()` to clean up signals
2. Rely on base class `enable_undo_redo = false` default
3. Some use hardcoded colors instead of theme utils

---

### 7.9 Summary: Signal Cleanup Compliance

| Editor | Has `_exit_tree()` | Cleanup Status |
|--------|-------------------|----------------|
| npc_editor.gd | Yes | Proper |
| resource_picker.gd | Yes | Proper |
| campaign_editor.gd | No | Missing |
| map_metadata_editor.gd | No | Missing |
| battle_editor.gd | No | Missing |
| base_resource_editor.gd | No | Missing |
| json_editor_base.gd | No | Missing |

**Recommendation**: Add `_exit_tree()` signal cleanup to all editors that connect to EditorEventBus.

---

## 8. Recommendations

### Critical

*None identified* - The plugin is functional and follows most best practices.

### Major

1. **Enable Undo/Redo by Default**: Change `enable_undo_redo` default to `true` in base_resource_editor.gd, or audit all subclasses to enable it explicitly. Users expect Ctrl+Z to work in editor tools.

2. **Standardize Signal Cleanup**: Add `_exit_tree()` to all editors that connect to EditorEventBus. Use `npc_editor.gd` and `resource_picker.gd` as templates:
   ```gdscript
   func _exit_tree() -> void:
       var event_bus: Node = get_node_or_null("/root/EditorEventBus")
       if event_bus:
           if event_bus.mods_reloaded.is_connected(_on_mods_reloaded):
               event_bus.mods_reloaded.disconnect(_on_mods_reloaded)
           if event_bus.resource_saved.is_connected(_on_dependency_resource_changed):
               event_bus.resource_saved.disconnect(_on_dependency_resource_changed)
   ```

### Minor

1. **Theme Colors**: Replace hardcoded colors with EditorThemeUtils calls. Affected files:
   - `base_resource_editor.gd` (lines 197, 1118)
   - `editor_utils.gd` (line 71)
   - `map_metadata_editor.gd` (multiple locations)
   - `campaign_editor.gd` (NODE_COLORS constant)

2. **Consolidate Constants**: Remove duplicated constants between EditorThemeUtils and SparklingEditorUtils:
   - `DEFAULT_LABEL_WIDTH`
   - `SECTION_FONT_SIZE`
   - `HELP_FONT_SIZE`

   Keep them in one location (recommend EditorThemeUtils) and reference from there.

3. **Use EditorThemeUtils for Error Panels**: `campaign_editor.gd` creates its own error panel StyleBox instead of using `EditorThemeUtils.create_error_panel_style()`.

### Suggestions

1. **Consider `_shortcut_input()`**: Replace `_input()` keyboard handling with `_shortcut_input()` for better integration with Godot's input system and to avoid conflicts with other editor shortcuts.

2. **EditorEventBus Timer Cleanup**: Add explicit timer cleanup in `_exit_tree()` for completeness (though Godot's Node cleanup handles this automatically).

3. **Component Extraction for Large Editors**: Consider extracting reusable components from large editors like `battle_editor.gd` (1465 lines) and `map_metadata_editor.gd` (1174 lines).

4. **File Dialog Alternative**: The "Browse..." button in map_metadata_editor shows an error message. Consider implementing a custom file browser or using `EditorFileDialog` if available in the plugin context.

---

## 9. Positive Patterns Worth Preserving

The following patterns are excellent and should be maintained:

1. **Tab Registry System**: Decoupled, extensible, with security validation for mod-provided tabs.

2. **EditorEventBus Debouncing**: The 100ms debounce on `mods_reloaded` prevents performance issues.

3. **`_updating_ui` Flag Pattern**: Used in NPC editor and Campaign editor to prevent signal feedback loops.

4. **Base Class Inheritance**: Both `base_resource_editor.gd` and `json_editor_base.gd` provide consistent foundations.

5. **Cross-Mod Workflow**: "Copy to My Mod" and "Create Override" features support modding workflows.

6. **ResourcePicker Component**: Reusable, mod-aware, with override detection.

7. **CollapseSection Component**: Clean, reusable collapsible UI component.

---

## Appendix A: Files Reviewed

| File | Lines | Status |
|------|-------|--------|
| `editor_plugin.gd` | 36 | Reviewed - Good |
| `editor_event_bus.gd` | 95 | Reviewed - Good |
| `editor_tab_registry.gd` | 446 | Reviewed - Excellent |
| `ui/main_panel.gd` | 663 | Reviewed - Good |
| `ui/base_resource_editor.gd` | 1458 | Reviewed - Very Good |
| `ui/editor_theme_utils.gd` | 144 | Reviewed - Excellent |
| `ui/editor_utils.gd` | 286 | Reviewed - Good |
| `ui/json_editor_base.gd` | 350 | Reviewed - Very Good |
| `ui/npc_editor.gd` | 1149 | Reviewed - Excellent |
| `ui/battle_editor.gd` | 1465 | Reviewed - Good |
| `ui/campaign_editor.gd` | 1155 | Reviewed - Very Good |
| `ui/map_metadata_editor.gd` | 1174 | Reviewed - Good |
| `ui/components/resource_picker.gd` | 454 | Reviewed - Excellent |
| `ui/components/collapse_section.gd` | 173 | Reviewed - Good |

---

## Appendix B: Summary Statistics

- **Total Files Reviewed**: 14
- **Total Lines of Code**: ~8,147
- **Critical Issues**: 0
- **Major Issues**: 2
- **Minor Issues**: 3
- **Suggestions**: 4

---

## Appendix C: Action Items Checklist

- [ ] Add `_exit_tree()` to `base_resource_editor.gd`
- [ ] Add `_exit_tree()` to `json_editor_base.gd`
- [ ] Add `_exit_tree()` to `campaign_editor.gd`
- [ ] Add `_exit_tree()` to `map_metadata_editor.gd`
- [ ] Add `_exit_tree()` to `battle_editor.gd`
- [ ] Change `enable_undo_redo` default to `true` or audit all subclasses
- [ ] Replace hardcoded colors with EditorThemeUtils calls
- [ ] Consolidate duplicated constants to single source

---

**Report Status**: Complete
**Last Updated**: 2025-12-08
**Auditor**: Ed (Editor Plugin Specialist)
