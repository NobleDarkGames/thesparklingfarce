# Sparkling Editor Architecture Review

**Author:** Chief Engineer Miles O'Brien
**Date:** 2025-12-06
**Status:** Complete

---

## Executive Summary

The Sparkling Editor is a well-structured Godot 4.5 editor plugin that provides a tabbed interface for creating content for The Sparkling Farce platform. Overall, the architecture demonstrates solid engineering principles with a clear inheritance hierarchy, proper event-driven communication, and good separation between resource types.

However, after a thorough analysis of the ~15,700 lines of code across 22 GDScript files, I've identified several areas requiring attention:

### Architectural Health Score: 7/10

**Strengths:**
- Clean base class abstractions (`BaseResourceEditor`, `JsonEditorBase`)
- Well-implemented EditorEventBus for cross-tab communication
- Proper mod-aware resource handling throughout
- Reusable `ResourcePicker` component

**Concerns:**
- One editor (NPC Editor at ~2000 lines) is significantly overengineered
- Inconsistent refresh method naming across editors
- Some code duplication in UI construction patterns
- Directory scanning code repeated in multiple places

---

## Component Dependency Analysis

### High-Level Architecture

```
EditorPlugin
    |
    +-- EditorEventBus (Singleton - signal hub)
    |
    +-- MainPanel
            |
            +-- ModSelector (Active mod management)
            |
            +-- TabContainer
                    |
                    +-- Overview Tab (Static content)
                    +-- Mod Settings Tab (ModJsonEditor extends JsonEditorBase)
                    +-- Class Editor (extends BaseResourceEditor)
                    +-- Character Editor (extends BaseResourceEditor)
                    +-- Item Editor (extends BaseResourceEditor)
                    +-- Ability Editor (extends BaseResourceEditor)
                    +-- Party Editor (extends BaseResourceEditor)
                    +-- Battle Editor (extends BaseResourceEditor)
                    +-- Map Metadata Editor (standalone - but should extend JsonEditorBase)
                    +-- Cinematic Editor (extends JsonEditorBase)
                    +-- Campaign Editor (extends JsonEditorBase)
                    +-- Terrain Editor (extends BaseResourceEditor)
                    +-- NPC Editor (extends BaseResourceEditor)
```

### Inheritance Hierarchy

```
Control
    |
    +-- BaseResourceEditor (1015 lines)
    |       |-- For .tres Resource files
    |       |-- Provides: list management, save/delete, search, mod workflows
    |       |-- Children override: _create_detail_form(), _load_resource_data(),
    |       |                      _save_resource_data(), _validate_resource(),
    |       |                      _create_new_resource(), _get_resource_display_name()
    |       |
    |       +-- CharacterEditor (714 lines)
    |       +-- ClassEditor (559 lines)
    |       +-- ItemEditor (713 lines)
    |       +-- AbilityEditor (518 lines)
    |       +-- TerrainEditor (526 lines)
    |       +-- PartyEditor (1174 lines)
    |       +-- BattleEditor (1404 lines)
    |       +-- NPCEditor (1956 lines) <-- COMPLEXITY HOTSPOT
    |
    +-- JsonEditorBase (341 lines)
            |-- For .json files (cinematics, campaigns, maps)
            |-- Provides: JSON load/save, error panels, directory scanning
            |
            +-- CinematicEditor (1253 lines)
            +-- CampaignEditor (1149 lines)
            +-- ModJsonEditor (1358 lines)
```

### Signal Flow (EditorEventBus)

```
Signals:
- resource_saved(resource_type, resource_id, resource)
- resource_created(resource_type, resource_id, resource)
- resource_deleted(resource_type, resource_id)
- active_mod_changed(mod_id)
- mods_reloaded()
- resource_copied(...)
- resource_override_created(...)

Consumers:
- BaseResourceEditor -> listens for cross-mod changes
- ResourcePicker -> auto-refreshes on mods_reloaded
- CinematicEditor -> refreshes character cache on resource_saved
- NPCEditor -> refreshes list on mods_reloaded
```

---

## Code Quality Analysis

### File Size Distribution (Lines of Code)

| File | Lines | Status |
|------|-------|--------|
| npc_editor.gd | 1956 | CRITICAL - Too large |
| battle_editor.gd | 1404 | WARNING - Consider splitting |
| mod_json_editor.gd | 1358 | WARNING |
| map_metadata_editor.gd | 1295 | WARNING |
| cinematic_editor.gd | 1253 | Acceptable (complex domain) |
| party_editor.gd | 1174 | Acceptable |
| campaign_editor.gd | 1149 | Acceptable |
| base_resource_editor.gd | 1015 | Acceptable (base class) |
| main_panel.gd | 816 | Acceptable |
| dialogue_editor.gd | 781 | Acceptable |
| item_editor.gd | 713 | Good |
| character_editor.gd | 714 | Good |
| battle_map_preview.gd | 706 | Good (specialized component) |
| class_editor.gd | 559 | Good |
| terrain_editor.gd | 526 | Good |
| ability_editor.gd | 518 | Good |
| resource_picker.gd | 453 | Excellent |
| json_editor_base.gd | 341 | Excellent |
| dialog_line_popup.gd | 249 | Excellent |
| editor_event_bus.gd | 65 | Excellent |
| editor_plugin.gd | 37 | Excellent |

### Complexity Hotspots

#### 1. NPC Editor (CRITICAL)

At 1956 lines, the NPC Editor is nearly double the size of the next largest editor and contains:

- Full preview panel with live updates
- Template system for common NPC types
- Quick Dialog creation (auto-generates cinematics)
- Place on Map functionality (modifies scene files)
- ID auto-generation with lock/unlock
- Conditional cinematics UI management
- Appearance fallback section management

**Analysis:** This editor attempts to be a "one-stop shop" for NPC creation, but it violates the Single Responsibility Principle. The "Place on Map" functionality alone is 200+ lines that should be a separate component.

**Recommendation:** Extract into smaller components:
1. `NPCPreviewPanel` - Live preview rendering
2. `MapPlacementDialog` - Scene modification logic
3. `QuickDialogCreator` - Cinematic generation from text
4. Keep core NPC editing in the main editor

#### 2. Battle Editor

Large but justified by the complexity of battle configuration. The `BattleMapPreview` component is already properly extracted.

#### 3. Map Metadata Editor (Inheritance Problem)

At 1295 lines, this editor does NOT extend `JsonEditorBase` despite handling JSON files. It contains:

**Duplicated Code from JsonEditorBase:**
- `_create_error_panel()` - 28 lines duplicating error panel creation
- `_show_errors()` / `_hide_errors()` - 15 lines duplicating error display logic
- JSON load/save logic - duplicated parsing and file writing
- Active mod helpers (`_get_active_mod_id_safe()`, `_get_active_mod_directory_safe()`) - 15 lines

**Unique Functionality (justifies some size):**
- "Create New Map" wizard that generates scene + script + JSON
- Edge connection dropdowns with map-to-map linking
- Tileset scanning and selection

**Technical Debt:** The `_create_error_panel()` function duplicates 28 lines that are identical to `JsonEditorBase.create_error_panel()`. The only reason it exists is because `MapMetadataEditor` extends `Control` directly instead of `JsonEditorBase`.

**Recommendation:** Refactor to extend `JsonEditorBase` and delete ~100 lines of duplicate code.

---

## Code Duplication Analysis

### Pattern 1: Section Creation

Every editor creates sections with this pattern:
```gdscript
var section: VBoxContainer = VBoxContainer.new()
var section_label: Label = Label.new()
section_label.text = "Section Name"
section_label.add_theme_font_size_override("font_size", 16)
section.add_child(section_label)
```

**Found in:** CharacterEditor, ItemEditor, NPCEditor, ClassEditor, AbilityEditor, TerrainEditor, PartyEditor, BattleEditor

**Recommendation:** Add to base class:
```gdscript
func _create_section(title: String) -> VBoxContainer:
    var section: VBoxContainer = VBoxContainer.new()
    var label: Label = Label.new()
    label.text = title
    label.add_theme_font_size_override("font_size", 16)
    section.add_child(label)
    return section
```

### Pattern 2: Labeled Field Row Creation

```gdscript
var container: HBoxContainer = HBoxContainer.new()
var label: Label = Label.new()
label.text = "Field Name:"
label.custom_minimum_size.x = 120  # Varies: 120, 140, 150
container.add_child(label)
```

**Found in:** Every editor, with inconsistent label widths (120, 140, 150 pixels)

**Recommendation:** `JsonEditorBase` already has `create_field_row()` and `create_line_edit_field()`. These should be promoted to a shared base or utility class that `BaseResourceEditor` also uses.

### Pattern 3: Directory Scanning

Both `BaseResourceEditor._scan_all_mods_for_resource_type()` and `ResourcePicker._scan_for_overrides()` perform similar mod directory scanning:

```gdscript
var mods_dir: DirAccess = DirAccess.open("res://mods/")
mods_dir.list_dir_begin()
var mod_name: String = mods_dir.get_next()
while mod_name != "":
    if mods_dir.current_is_dir() and not mod_name.begins_with("."):
        # ... scan mod's data directory
    mod_name = mods_dir.get_next()
mods_dir.list_dir_end()
```

**Recommendation:** Create a shared utility:
```gdscript
class_name EditorUtils

static func scan_all_mods(callback: Callable) -> void:
    # Unified mod scanning logic

static func scan_mod_resources(mod_id: String, resource_type: String) -> Array[Dictionary]:
    # Return [{path, resource_id}]
```

### Pattern 4: Active Mod Path Resolution

The following pattern appears in 5+ locations:
```gdscript
var mod_path: String = ""
if ModLoader:
    var active_mod: ModManifest = ModLoader.get_active_mod()
    if active_mod:
        mod_path = active_mod.mod_directory
```

**Recommendation:** Add to base classes or create utility function.

---

## Inconsistency Analysis

### Refresh Method Naming

| Editor | Method Name |
|--------|-------------|
| BaseResourceEditor children | `_refresh_list()` |
| ModJsonEditor | `_refresh_mod_list()` |
| MapMetadataEditor | `_refresh_map_list()` |
| CinematicEditor | `_refresh_cinematic_list()` |
| CampaignEditor | `_refresh_campaign_list()` |
| NPCEditor | `_refresh_list()` |

**Problem:** MainPanel has to know about each editor's specific refresh method name:
```gdscript
if mod_json_editor and mod_json_editor.has_method("_refresh_mod_list"):
    mod_json_editor._refresh_mod_list()
if map_metadata_editor and map_metadata_editor.has_method("_refresh_map_list"):
    map_metadata_editor._refresh_map_list()
```

**Recommendation:** Standardize on `_refresh_list()` for all editors, or define an interface:
```gdscript
func refresh() -> void:  # Public method all editors implement
    _refresh_list()
```

### Label Width Inconsistency

- CharacterEditor: 120px
- ItemEditor: 150px
- NPCEditor: 140px
- JsonEditorBase default: 120px

**Recommendation:** Define a constant in a shared location.

---

## Coupling Analysis

### Tight Coupling Issues

1. **NPCEditor -> Scene Files**
   - `_add_npc_to_scene()` directly manipulates PackedScene files
   - Creates tight coupling between editor and scene structure
   - Assumes "NPCs" node container exists or should be created

2. **MainPanel -> All Editors**
   - Hardcoded list of editor scene preloads
   - Hardcoded refresh method calls with specific names
   - Adding a new editor requires modifying MainPanel in 3+ places

### Loose Coupling (Good)

1. **EditorEventBus**
   - Proper signal-based decoupling
   - Editors don't need to know about each other

2. **ResourcePicker**
   - Self-contained component
   - Configurable via properties
   - Auto-subscribes to EditorEventBus

3. **DialogueEditor List Pattern**
   - Uses `lines_list: Array[Dictionary]` to track dynamic UI elements
   - Clean add/remove/reorder pattern with `_add_line_ui()`, `_on_remove_line()`, `_on_move_line_up/down()`
   - Could be extracted as a reusable "DynamicListEditor" component
   - Same pattern appears in CinematicEditor for command lists

---

## Recommendations (Prioritized)

### Priority 1: Critical (Address Soon)

#### 1.1 Refactor NPC Editor
**Impact:** High | **Effort:** Medium

Extract the following into separate components:
- `MapPlacementHelper` class for scene manipulation
- `QuickDialogGenerator` for cinematic creation
- `NPCPreviewPanel` for live preview

This will reduce the file from ~2000 to ~800 lines.

#### 1.2 Fix Map Metadata Editor Inheritance
**Impact:** Medium | **Effort:** Low

Have `MapMetadataEditor` extend `JsonEditorBase` to eliminate duplicate JSON handling code.

### Priority 2: Important (Next Sprint)

#### 2.1 Standardize Refresh Methods
**Impact:** Medium | **Effort:** Low

Create a standard `refresh()` public method all editors implement. Update MainPanel to use this consistently.

#### 2.2 Create EditorUtils Class
**Impact:** Medium | **Effort:** Medium

Extract shared utilities:
- `scan_all_mods()`
- `get_active_mod_path()`
- `create_section()`
- `create_field_row()`

#### 2.3 Unify UI Construction Helpers
**Impact:** Medium | **Effort:** Medium

Promote `JsonEditorBase`'s helper methods to a shared location or base class that all editors can use.

### Priority 3: Nice to Have (Backlog)

#### 3.1 Standardize Label Widths
**Impact:** Low | **Effort:** Low

Define constants for standard label widths.

#### 3.2 Add Unit Test Coverage
**Impact:** Medium | **Effort:** High

The editor code is difficult to test due to tight UI coupling. Consider extracting pure functions for validation logic.

#### 3.3 Editor Registration System
**Impact:** Medium | **Effort:** Medium

Instead of hardcoded editor lists in MainPanel, consider a registration pattern where editors register themselves.

---

## Extracted Utilities Proposal

```gdscript
# addons/sparkling_editor/ui/editor_utils.gd
class_name SparklingEditorUtils

const DEFAULT_LABEL_WIDTH: int = 140
const SECTION_FONT_SIZE: int = 16

static func create_section(title: String, parent: Control = null) -> VBoxContainer:
    var section: VBoxContainer = VBoxContainer.new()
    var label: Label = Label.new()
    label.text = title
    label.add_theme_font_size_override("font_size", SECTION_FONT_SIZE)
    section.add_child(label)
    if parent:
        parent.add_child(section)
    return section

static func create_field_row(label_text: String, label_width: int = DEFAULT_LABEL_WIDTH) -> HBoxContainer:
    var row: HBoxContainer = HBoxContainer.new()
    var label: Label = Label.new()
    label.text = label_text
    label.custom_minimum_size.x = label_width
    row.add_child(label)
    return row

static func get_active_mod_path() -> String:
    if not ModLoader:
        return ""
    var active_mod: ModManifest = ModLoader.get_active_mod()
    if active_mod:
        return active_mod.mod_directory
    return ""

static func scan_all_mod_directories() -> Array[String]:
    var mods: Array[String] = []
    var mods_dir: DirAccess = DirAccess.open("res://mods/")
    if not mods_dir:
        return mods
    mods_dir.list_dir_begin()
    var mod_name: String = mods_dir.get_next()
    while mod_name != "":
        if mods_dir.current_is_dir() and not mod_name.begins_with("."):
            mods.append(mod_name)
        mod_name = mods_dir.get_next()
    mods_dir.list_dir_end()
    return mods
```

---

## Workflow Assessment

### Creating a New Character (Good)
1. Select active mod
2. Go to Characters tab
3. Click "Create New Character"
4. Fill in fields
5. Save

**Assessment:** Straightforward, 5 steps, clear workflow.

### Creating an NPC with Dialog (Complex but Functional)
1. Select active mod
2. Go to NPCs tab
3. Click "Create New NPC"
4. Fill in name (ID auto-generates)
5. Type dialog text in Quick Dialog section
6. Click "Create Dialog"
7. Optionally place on map
8. Save

**Assessment:** The Quick Dialog feature is genuinely useful - it removes the need to manually create cinematics for simple NPCs. However, the 2000-line file suggests this convenience came at a maintainability cost.

### Field Validation
- Most editors validate on save only
- Validation errors shown in a red panel with pulse animation (good UX)
- Cross-mod write protection works correctly
- Namespace conflict detection is informational, not blocking

---

## Data Flow Assessment

### Resource -> UI -> Resource
```
1. User selects resource from list
2. current_resource = loaded_resource.duplicate(true)
3. current_resource.take_over_path(original_path)
4. _load_resource_data() populates UI fields
5. User edits fields
6. _save_resource_data() reads UI into current_resource
7. ResourceSaver.save(current_resource, path)
8. EditorEventBus.notify_resource_saved()
```

**Assessment:** Clean pattern. The duplication prevents modifying the cached resource directly.

### Mod Selection Flow
```
1. User selects mod in dropdown
2. MainPanel._on_mod_selected()
3. ModLoader.set_active_mod(mod_id)
4. EditorEventBus.active_mod_changed.emit()
5. Each editor refreshes its list (if listening)
6. MainPanel._refresh_all_editors() as backup
```

**Assessment:** There's redundancy here - editors both listen to EditorEventBus AND get explicitly refreshed. This is probably defensive but could be simplified.

---

## Alignment with Platform Specification

### Correct
- Resources saved to `mods/<mod_id>/data/<type>/`
- All content accessed through ModLoader.registry
- No game content in `core/`
- Proper mod priority handling
- Override detection and display in ResourcePicker

### Missing/Incomplete
- No validation that created resources match expected schema
- Equipment type validation relies on runtime registry (could fail silently if registry not loaded)

---

## Conclusion

The Sparkling Editor is fundamentally well-architected with proper separation of concerns at the high level. The main issues are:

1. **One significantly overengineered editor** (NPC Editor) that should be decomposed
2. **Missed opportunities for code reuse** in UI construction patterns
3. **Inconsistent naming conventions** for refresh methods

None of these are critical bugs - the editor works correctly. They're maintainability concerns that will become more important as the codebase grows.

The `BaseResourceEditor` and `JsonEditorBase` classes provide good foundations. The `EditorEventBus` is a proper implementation of the observer pattern. The `ResourcePicker` component is well-designed and reusable.

**Bottom line:** This is solid work that could be made excellent with targeted refactoring, particularly of the NPC Editor.

---

*"I've seen worse, Captain. Much worse. This won't take a warp core breach to fix - just some focused refactoring during a quiet week."*

-- Chief Engineer Miles O'Brien
