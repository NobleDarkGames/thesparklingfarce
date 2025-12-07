# Sparkling Editor - Plugin Best Practices Review

**Reviewer**: Ed (Editor Plugin Specialist)
**Date**: 2025-12-06
**Status**: Complete

---

## Executive Summary

The Sparkling Editor is a well-architected bottom-panel EditorPlugin that provides comprehensive visual editing tools for The Sparkling Farce modding platform. The codebase demonstrates solid understanding of Godot's EditorPlugin patterns with a few areas needing improvement.

### Overall Architecture Health

| Category | Rating | Notes |
|----------|--------|-------|
| Plugin Structure | Good | Clean lifecycle management |
| Resource Handling | Good | Proper use of ResourceSaver/ResourceLoader |
| Signal Architecture | Good | Centralized EditorEventBus |
| Undo/Redo Support | **Needs Work** | Infrastructure exists but rarely used |
| Theme Integration | **Needs Work** | Hardcoded colors throughout |
| Error Handling | Good | Validation and graceful failures |
| Performance | Good | Lazy loading, appropriate caching |
| Code Consistency | Mixed | Some duplicated patterns |

### Key Strengths

1. **Mod-Aware Design**: Editors consistently respect ModLoader, active mod selection, and cross-mod references
2. **EditorEventBus**: Clean decoupled communication between editors
3. **Base Class Inheritance**: Good use of `BaseResourceEditor` and `JsonEditorBase` for shared patterns
4. **Validation Framework**: Comprehensive validation before save operations
5. **Progressive Disclosure**: Complex features hidden behind sensible defaults

### Critical Issues

1. **Memory leak in editor_plugin.gd** (unused event_bus instance)
2. **Undo/Redo not implemented** despite infrastructure existing
3. **Hardcoded theme colors** reduce compatibility with different editor themes

---

## 1. Main Plugin Architecture

### File: `/home/user/dev/sparklingfarce/addons/sparkling_editor/editor_plugin.gd`

**Status**: Good with one critical bug

#### Memory Leak Issue

```gdscript
# Current code (lines 17-19):
event_bus = EditorEventBus.new()        # Creates instance (NEVER USED)
event_bus.name = "EditorEventBus"       # Names it (NEVER USED)
add_autoload_singleton("EditorEventBus", "...")  # Creates ANOTHER instance
```

The `event_bus` variable is created but never added to the tree or freed. The autoload singleton creates a separate instance from the script path. The local instance leaks memory.

**Fix**:
```gdscript
func _enter_tree() -> void:
    # Just add the autoload - Godot creates the instance from script
    add_autoload_singleton("EditorEventBus",
        "res://addons/sparkling_editor/editor_event_bus.gd")

    main_panel = MainPanelScene.instantiate()
    add_control_to_bottom_panel(main_panel, "Sparkling Editor")
```

#### Proper Lifecycle

The `_enter_tree()` and `_exit_tree()` implementations otherwise follow correct patterns:
- Bottom panel added/removed correctly
- Autoload singleton registered/unregistered correctly

---

## 2. EditorEventBus

### File: `/home/user/dev/sparklingfarce/addons/sparkling_editor/editor_event_bus.gd`

**Status**: Good

This singleton provides decoupled communication between editor tabs. Signals include:
- `resource_saved(type, id, resource)`
- `resource_created(type, id, resource)`
- `resource_deleted(type, id)`
- `mods_reloaded()`
- `active_mod_changed(mod_id)`

**Strengths**:
- Well-documented signal parameters
- Convenience wrapper methods (`notify_resource_saved()`)
- Centralized location for editor-wide events

**Minor Concern**: No debouncing for rapid changes. If a user makes many quick edits, signals fire for each. This could cause performance issues with many connected editors.

---

## 3. Main Panel Architecture

### File: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/main_panel.gd`

**Status**: Good

#### Strengths

1. **Deferred Setup**: Uses `call_deferred("_setup_ui")` to handle editor plugin timing issues
2. **Lazy Instantiation**: Tabs are created from packed scenes on demand
3. **Settings Persistence**: Saves/loads to `user://sparkling_editor_settings.json`
4. **Mod Wizard**: Full wizard for creating new mods with proper structure
5. **Dynamic Extensions**: Mods can add custom editor tabs
6. **Safe Refresh**: `_is_safe_refresh_method()` prevents calling destructive methods on editors

#### Issues

**Hardcoded Colors**:
```gdscript
# Line 338
mod_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

# Line 646
type_help.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
```

**Recommendation**:
```gdscript
# Use theme-aware colors
var disabled_color: Color = get_theme_color("font_disabled_color", "Editor")
mod_info_label.add_theme_color_override("font_color", disabled_color)
```

**Inconsistent Refresh Method Naming**:
```gdscript
# Different names across editors:
character_editor.has_method("_refresh_list")
mod_json_editor.has_method("_refresh_mod_list")
map_metadata_editor.has_method("_refresh_map_list")
cinematic_editor.has_method("_refresh_cinematic_list")
```

**Recommendation**: Standardize on `refresh_content()` in base classes.

---

## 4. Base Resource Editor

### File: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/base_resource_editor.gd`

**Status**: Good foundation with underutilized undo/redo

This is the primary base class for resource editors. It provides:
- List/detail split view layout
- Search/filter functionality
- Resource loading/saving with validation
- Cross-mod awareness and copy/override workflow
- Reference checking before deletion
- Error panel with animation

#### Undo/Redo Infrastructure (UNUSED)

The class has full undo/redo infrastructure (lines 984-1015):
```gdscript
var undo_redo: EditorUndoRedoManager

func _begin_undo_action(action_name: String) -> void:
    if undo_redo:
        undo_redo.create_action(action_name)

func _commit_undo_action() -> void:
    if undo_redo:
        undo_redo.commit_action()

func _add_undo_redo_property(...) -> void:
    # Implementation exists
```

**Problem**: These methods are never called by child classes. Users cannot undo their edits.

**Recommendation**: Wrap `_save_resource_data()` calls in undo/redo actions. Example:
```gdscript
func _on_save_resource() -> void:
    _begin_undo_action("Modify Character")

    var old_values: Dictionary = current_resource.duplicate()
    _save_resource_data()

    _add_undo_redo_property(current_resource, "property",
        old_values.property, current_resource.property)

    _commit_undo_action()
```

#### Hardcoded Error Colors
```gdscript
# Lines 234-248
error_style.bg_color = Color(0.6, 0.15, 0.15, 0.95)
error_style.border_color = Color(0.9, 0.3, 0.3, 1.0)
```

**Recommendation**:
```gdscript
var error_color: Color = get_theme_color("error_color", "Editor")
error_style.bg_color = error_color.darkened(0.5)
error_style.border_color = error_color
```

---

## 5. Individual Editor Analysis

### 5.1 Character Editor
**File**: `character_editor.gd`
**Base**: `base_resource_editor.gd`

**Strengths**:
- Comprehensive character editing (stats, portrait, class assignment)
- Good use of resource picker for class selection
- Level-up preview functionality
- Proper validation before save

**Issues**:
- Moderate complexity but well-organized

### 5.2 Class Editor
**File**: `class_editor.gd`
**Base**: `base_resource_editor.gd`

**Strengths**:
- Ability slot management
- Stat multiplier configuration
- Class tree visualization planned

### 5.3 Item Editor
**File**: `item_editor.gd`
**Base**: `base_resource_editor.gd`

**Strengths**:
- Dynamic effect management
- Equipment slot configuration
- Mod-aware resource references

### 5.4 Ability Editor
**File**: `ability_editor.gd`
**Base**: `base_resource_editor.gd`

**Strengths**:
- Complex ability effect configuration
- MP cost and range settings
- Target type selection

### 5.5 Battle Editor
**File**: `battle_editor.gd`
**Base**: `base_resource_editor.gd`

**Strengths**:
- Battle unit placement UI
- Victory/defeat condition configuration
- Map preview integration

### 5.6 Party Editor
**File**: `party_editor.gd`
**Base**: `base_resource_editor.gd`

**Strengths**:
- Dual-mode editing (Template Parties + Player Party)
- Save slot management for player party
- Direct file access for editor context (SaveManager workaround)
- Character preview with stats

**Issues**:
- Complex file containing two different editing modes
- Could be split into PartyTemplateEditor and SaveSlotEditor

### 5.7 NPC Editor
**File**: `npc_editor.gd`
**Base**: `base_resource_editor.gd`

**Strengths**:
- Quick Dialog popup for easy NPC dialogue creation
- Preview of dialogue tree

### 5.8 Cinematic Editor
**File**: `cinematic_editor.gd`
**Base**: `json_editor_base.gd`

**Strengths**:
- Visual command list editing
- Command reordering (drag/move up/down)
- Command type inspector with type-specific fields
- Quick Add Dialog for common operations
- Command color-coding by category

**Issues**:
- Hardcoded command colors:
```gdscript
func _get_command_color(cmd_type: String) -> Color:
    match cmd_type:
        "dialog_line", "show_dialog":
            return Color(0.4, 0.8, 0.4)  # Green
        # ... etc
```

### 5.9 Map Metadata Editor
**File**: `map_metadata_editor.gd`
**Base**: Custom (extends Control directly)

**Observation**: This editor does not use `JsonEditorBase` even though it edits JSON files. It could benefit from refactoring to use the base class.

**Strengths**:
- Scene-as-truth architecture (JSON only stores runtime config)
- New Map Wizard creates scene, script, and metadata together
- Edge connection configuration for overworld maps
- Tileset scanning for available tilesets

**Issues**:
- Duplicated error panel code (could use JsonEditorBase)
- Duplicated JSON save/load code

### 5.10 Campaign Editor
**File**: `campaign_editor.gd` (if exists)
**Base**: `json_editor_base.gd`

*Not reviewed in this pass.*

---

## 6. Component Analysis

### 6.1 ResourcePicker
**File**: `components/resource_picker.gd`

**Status**: Excellent

A reusable mod-aware dropdown for selecting resources. Features:
- Displays resources from ALL loaded mods with source attribution
- Shows override indicators when resources exist in multiple mods
- Proper signal disconnection in `_exit_tree()`
- Filter function support
- Refresh on mod reload

**Example of good cleanup**:
```gdscript
func _exit_tree() -> void:
    var event_bus: Node = get_node_or_null("/root/EditorEventBus")
    if event_bus:
        if event_bus.mods_reloaded.is_connected(_on_mods_reloaded):
            event_bus.mods_reloaded.disconnect(_on_mods_reloaded)
```

### 6.2 DialogLinePopup
**File**: `components/dialog_line_popup.gd`

**Status**: Good

Popup for quickly creating dialog_line JSON commands:
- Character picker with portrait preview
- Emotion dropdown
- Real-time JSON preview
- Copy to clipboard functionality

**Minor Issue**: Hardcoded preview color:
```gdscript
result_preview.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
```

---

## 7. Cross-Cutting Concerns Analysis

### 7.1 Workflow Assessment

| Tab | Steps to Complete Task | Rating |
|-----|------------------------|--------|
| Character Editor | 4-5 steps (create, fill fields, save) | Good |
| Class Editor | 3-4 steps | Good |
| Item Editor | 4-5 steps | Good |
| Party Editor | 5-7 steps (dual mode adds complexity) | Acceptable |
| Battle Editor | 5-6 steps | Good |
| Cinematic Editor | 3-4 steps per command | Excellent |
| Map Editor | 4-5 steps with wizard | Good |
| NPC Editor | 3-4 steps | Good |

### 7.2 Field Validation

All editors implement `_validate_resource()` returning a structured result:
```gdscript
return {
    "valid": errors.is_empty(),
    "errors": errors
}
```

Validation is consistent and comprehensive.

### 7.3 Save Behavior

- **Resource editors**: Save on button click, uses `ResourceSaver.save()`
- **JSON editors**: Save on button click, uses `FileAccess.open()` + `JSON.stringify()`
- **Dirty tracking**: All editors track `is_dirty` but don't warn on close

**Recommendation**: Add unsaved changes warning when switching tabs or closing.

### 7.4 Data Synchronization

Editors use EditorEventBus signals to stay synchronized:
- `resource_saved` triggers list refreshes in related editors
- `mods_reloaded` triggers full refresh across all editors
- `active_mod_changed` updates target directories

**Issue Observed**: Some editors connect to signals without checking if already connected:
```gdscript
# Potential double-connection if editor is re-entered
event_bus.resource_saved.connect(_on_resource_changed)
```

**Recommendation**: Always check before connecting:
```gdscript
if not event_bus.resource_saved.is_connected(_on_resource_changed):
    event_bus.resource_saved.connect(_on_resource_changed)
```

### 7.5 Duplicate/Unnecessary Code

1. **Error panel creation**: Duplicated in `base_resource_editor.gd`, `json_editor_base.gd`, and `map_metadata_editor.gd`

2. **Mod scanning**: Duplicated directory scanning logic across multiple files

3. **Color overrides**: Same hardcoded colors appear in multiple files

**Recommendation**: Create shared utility classes:
- `EditorThemeUtils.gd` for theme-aware colors
- `EditorFileUtils.gd` for mod directory scanning

### 7.6 Alignment with Platform Specification

The editor aligns well with the platform specification:
- Resources created in correct `mods/<mod_name>/data/<type>/` directories
- ModLoader integration is consistent
- Active mod selection is respected
- Mod priority is shown in resource pickers

---

## 8. Performance Analysis

### 8.1 Expensive Operations

**Directory Scanning**: Several editors scan the entire `mods/` directory tree:
- `_refresh_list()` in base_resource_editor.gd
- `_scan_all_mods_for_resources()` in json_editor_base.gd
- `_refresh_map_list()` in map_metadata_editor.gd

These operations are typically O(n*m) where n = number of mods and m = files per mod.

**Current Mitigation**: Scanning only happens on explicit refresh or tab switch, not on every frame.

**Recommendation**: Add debouncing if automatic refresh is needed:
```gdscript
var _refresh_timer: Timer

func _request_refresh() -> void:
    _refresh_timer.start(0.5)  # Debounce 500ms

func _on_refresh_timer_timeout() -> void:
    _refresh_list()
```

### 8.2 Process Functions

No editors have expensive `_process()` implementations. Most editors are event-driven.

### 8.3 Resource Caching

ResourcePicker and base editors cache loaded resources appropriately. The ModLoader registry serves as the primary cache.

---

## 9. Theme Integration Audit

### Hardcoded Colors Found

| File | Line(s) | Color | Purpose |
|------|---------|-------|---------|
| main_panel.gd | 338, 646 | `Color(0.6-0.7, ...)` | Hint text |
| base_resource_editor.gd | 234-248 | Red tones | Error panel |
| json_editor_base.gd | 181 | `Color(0.4, 0.1, 0.1)` | Error panel |
| map_metadata_editor.gd | 436-449 | Red tones | Error panel |
| cinematic_editor.gd | 675-692 | Various | Command colors |
| dialog_line_popup.gd | 124 | `Color(0.6, 0.8, 0.6)` | JSON preview |

### Recommended Theme-Aware Approach

```gdscript
# Get editor theme colors
func _get_editor_color(name: String) -> Color:
    var control: Control = EditorInterface.get_base_control()
    return control.get_theme_color(name, "Editor")

# Usage
var error_color: Color = _get_editor_color("error_color")
var warning_color: Color = _get_editor_color("warning_color")
var success_color: Color = _get_editor_color("success_color")
var disabled_color: Color = _get_editor_color("font_disabled_color")
```

---

## 10. Recommendations Summary

### Immediate Fixes (Critical)

1. **Fix memory leak in editor_plugin.gd**
   - Remove unused `event_bus` variable creation
   - Priority: HIGH

### Short-Term Improvements

2. **Implement undo/redo for all editors**
   - Use the existing `undo_redo` infrastructure in base classes
   - Start with character/item editors as proof of concept
   - Priority: HIGH

3. **Replace hardcoded colors with theme lookups**
   - Create `EditorThemeUtils` singleton
   - Refactor all color overrides
   - Priority: MEDIUM

4. **Add unsaved changes warning**
   - Prompt when switching tabs with dirty state
   - Priority: MEDIUM

5. **Standardize refresh method naming**
   - Use `refresh_content()` across all editors
   - Priority: LOW

### Long-Term Improvements

6. **Refactor MapMetadataEditor to use JsonEditorBase**
   - Eliminate duplicate error panel and JSON code
   - Priority: LOW

7. **Consider splitting PartyEditor**
   - Separate PartyTemplateEditor and SaveSlotEditor
   - Priority: LOW

8. **Add performance profiling for large mod collections**
   - Test with 10+ mods and hundreds of resources
   - Priority: LOW

---

## 11. Conclusion

The Sparkling Editor demonstrates solid EditorPlugin development practices with a clear mod-aware architecture. The main areas needing attention are:

1. **Undo/Redo**: The infrastructure exists but is not utilized - this significantly impacts user experience
2. **Theme Integration**: Hardcoded colors reduce compatibility with custom editor themes
3. **Code Deduplication**: Some patterns are repeated across files that could be centralized

The editor successfully achieves its goal of making mod creation accessible to non-programmers. The visual tools for cinematics, battles, and NPCs are particularly well-designed for the target audience.

---

*Report generated by Ed, Editor Plugin Specialist*
*USS Torvalds, Sparkling Farce Modding Platform*
