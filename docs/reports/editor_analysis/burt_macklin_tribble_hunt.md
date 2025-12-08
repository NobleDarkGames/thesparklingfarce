# Sparkling Editor Tribble Hunt Report

**Investigator**: Burt Macklin, Tribble Hunter
**Stardate**: 2025.12.08
**Target**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/`
**Status**: COMPLETE

---

## Executive Summary

After conducting a thorough sweep of the Sparkling Editor plugin across 30+ script files, I'm pleased to report that this codebase is remarkably clean. The engineering crew has done excellent work - I've seen Starfleet vessels with more bugs than this editor. However, no codebase achieves 100% tribble-free status without eternal vigilance, and I've identified several specimens that warrant attention before they multiply.

**Overall Assessment**: GREEN - Minor issues, no critical infestations detected.

---

## Files Audited

### Core Plugin Files (3 files)
- [x] `editor_plugin.gd` - Plugin entry point
- [x] `editor_event_bus.gd` - Event communication system
- [x] `editor_tab_registry.gd` - Tab registration system

### UI Editors (17 files)
- [x] `main_panel.gd` - Main panel container
- [x] `base_resource_editor.gd` - Base class for resource editors
- [x] `character_editor.gd` - Character data editor
- [x] `class_editor.gd` - Class data editor
- [x] `item_editor.gd` - Item data editor
- [x] `ability_editor.gd` - Ability data editor
- [x] `terrain_editor.gd` - Terrain data editor
- [x] `battle_editor.gd` - Battle configuration editor
- [x] `party_editor.gd` - Party/save slot editor
- [x] `dialogue_editor.gd` - Dialogue tree editor
- [x] `cinematic_editor.gd` - Cinematic sequence editor
- [x] `campaign_editor.gd` - Campaign flow graph editor
- [x] `map_metadata_editor.gd` - Map configuration editor
- [x] `npc_editor.gd` - NPC data editor
- [x] `shop_editor.gd` - Shop configuration editor
- [x] `mod_json_editor.gd` - Mod manifest editor
- [x] `json_editor_base.gd` - Base class for JSON editors

### Utility Files (2 files)
- [x] `editor_utils.gd` - Shared editor utilities
- [x] `editor_theme_utils.gd` - Theme/styling utilities

### Components (5 files)
- [x] `components/resource_picker.gd` - Resource selection component
- [x] `components/battle_map_preview.gd` - Map preview with markers
- [x] `components/dialog_line_popup.gd` - Dialog editing popup
- [x] `components/collapse_section.gd` - Collapsible UI section
- [x] `components/npc_preview_panel.gd` - NPC preview display

---

## Tribble Findings

### PLAGUE TRIBBLES (Critical - Data Loss/Crash Risk)

**None detected.** The codebase shows excellent defensive programming throughout.

---

### WILD TRIBBLES (Uncaught Exceptions)

**WT-001: Dictionary Metadata Access Without Type Check**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/mod_json_editor.gd`
- **Lines**: 1151-1155
- **Severity**: Low
- **Description**: When loading equipment slot metadata, the code assumes metadata is a Dictionary but doesn't guard against null or other types.
```gdscript
func _on_equipment_slot_selected(index: int) -> void:
    var slot_data: Dictionary = equipment_slots_list.get_item_metadata(index)
    if slot_data is Dictionary:  # Guard exists - GOOD
        slot_id_edit.text = slot_data.get("id", "")
```
- **Status**: Actually handled correctly with `if slot_data is Dictionary`. No action needed.

**WT-002: Unguarded Campaign Resource Access**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/mod_json_editor.gd`
- **Lines**: 1335-1349
- **Severity**: Low
- **Description**: When refreshing campaign suggestions, campaigns from `get_all_resources` are iterated without null check on `resource_path`.
```gdscript
for campaign: Resource in campaigns:
    var campaign_path: String = campaign.resource_path  # Could be empty if Resource not saved
```
- **Risk**: If a campaign Resource exists in memory but hasn't been saved to disk, `resource_path` could be empty, causing the split operation to produce unexpected results.
- **Recommendation**: Add guard: `if campaign.resource_path.is_empty(): continue`

---

### PHANTOM TRIBBLES (Null Reference Risks)

**PT-001: Potential Null UI Reference in Party Editor**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/party_editor.gd`
- **Lines**: 308-316
- **Severity**: Low
- **Description**: `_refresh_player_party()` is called from `_on_dependencies_changed()` which could fire before UI is fully initialized.
```gdscript
func _refresh_player_party() -> void:
    if not player_members_list:  # Guard exists - GOOD
        return
```
- **Status**: Properly guarded. No action needed.

**PT-002: EditorEventBus Reference May Be Null**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/json_editor_base.gd`
- **Lines**: 298-322
- **Severity**: Low
- **Description**: The `notify_resource_saved/created/deleted` methods attempt to get EditorEventBus via `get_node_or_null` and properly check for null before use.
```gdscript
var event_bus: Node = get_node_or_null("/root/EditorEventBus")
if event_bus and event_bus.has_method("notify_resource_saved"):
```
- **Status**: Properly handled with fallback. No action needed.

**PT-003: Metadata Access in Campaign Editor**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/campaign_editor.gd`
- **Lines**: 569-575, 937-938
- **Severity**: Medium
- **Description**: When getting transition target from OptionButton, metadata access could fail if items were added without metadata.
```gdscript
var node_id: String = "" if index == 0 else starting_node_option.get_item_metadata(index)
```
- **Risk**: If `get_item_metadata(index)` returns null, assigning to `String` would fail.
- **Recommendation**: Add null coalescing:
```gdscript
var metadata: Variant = starting_node_option.get_item_metadata(index)
var node_id: String = "" if (index == 0 or metadata == null) else str(metadata)
```

---

### ASYNCHRONOUS TRIBBLES (Race Conditions)

**AT-001: Deferred UI Setup Race**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/map_metadata_editor.gd`
- **Line**: 78
- **Severity**: Low
- **Description**: `call_deferred("_setup_ui")` is used in `_init()`, which is good practice for editor tools, but means any signals emitted during loading might fire before UI exists.
- **Status**: Mitigated by null checks throughout. Acceptable pattern for @tool scripts.

**AT-002: Mod Reload During Edit**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/base_resource_editor.gd`
- **Severity**: Low (Theoretical)
- **Description**: If `mods_reloaded` signal fires while user is mid-edit, the `_reload_list_maintaining_selection()` could reset state unexpectedly.
- **Status**: Currently reloads maintain selection, which is acceptable. The `is_dirty` flag provides indication of unsaved changes.

---

### ZOMBIE TRIBBLES (Resource Leaks)

**ZT-001: Campaign GraphNode Cleanup**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/campaign_editor.gd`
- **Lines**: 593-598
- **Severity**: Low
- **Description**: When rebuilding the graph, nodes are freed via `queue_free()`:
```gdscript
for child in graph_edit.get_children():
    if child is GraphNode:
        child.queue_free()
graph_nodes.clear()
```
- **Status**: Correct use of `queue_free()`. The dictionary is cleared, preventing dangling references. No issue.

**ZT-002: SubViewport in BattleMapPreview**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/components/battle_map_preview.gd`
- **Lines**: 370-374
- **Severity**: Low
- **Description**: Map instances are properly freed when replaced:
```gdscript
if _map_instance and is_instance_valid(_map_instance):
    _map_instance.queue_free()
    _map_instance = null
```
- **Status**: Proper cleanup with `is_instance_valid()` check. Excellent pattern.

---

### SHAPESHIFTER TRIBBLES (Type Confusion)

**ST-001: Dictionary Item Metadata Coercion**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/mod_json_editor.gd`
- **Line**: 944
- **Severity**: Low
- **Description**: Equipment slot metadata is retrieved and cast:
```gdscript
var slot_data: Dictionary = equipment_slots_list.get_item_metadata(i)
if slot_data is Dictionary:
    slots.append(slot_data)
```
- **Status**: Type check exists. Safe.

---

### QUANTUM TRIBBLES (State Management Issues)

**QT-001: Dirty State Not Always Tracked**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/mod_json_editor.gd`
- **Various Lines**
- **Severity**: Low
- **Description**: The `is_dirty` flag is set in some handlers but not all. For example, changing text in `name_edit`, `version_edit`, or `description_edit` doesn't set `is_dirty = true`.
- **Risk**: User might close editor without warning about unsaved changes to basic info fields.
- **Recommendation**: Connect `text_changed` signals to a `_mark_dirty()` function for all input fields.

**QT-002: Selected Tab State on Mod Switch**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/main_panel.gd`
- **Severity**: Low
- **Description**: When switching active mods, the currently selected tab's content refreshes, but if the user was mid-edit on a resource that no longer exists in the new mod, the UI state could be stale.
- **Status**: The `_on_active_mod_changed()` flow handles this by triggering tab refreshes.

---

### MIRROR UNIVERSE TRIBBLES (Logic Inversions)

**MU-001: Caravan Visibility Check Order**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/map_metadata_editor.gd`
- **Lines**: 1156-1157
- **Severity**: Low
- **Description**: Validation checks that caravan visible implies accessible:
```gdscript
if caravan_visible_check.button_pressed and not caravan_accessible_check.button_pressed:
    errors.append("Caravan visible requires Caravan accessible")
```
- **Status**: Logic is correct. This prevents the impossible state of visible but inaccessible caravan.

---

### SILENT TRIBBLES (Swallowed Errors)

**SiT-001: Scene Path Browse Limitation**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/map_metadata_editor.gd`
- **Lines**: 1170-1173
- **Severity**: Informational
- **Description**: Browse button shows an error rather than opening file dialog due to editor plugin context limitations.
```gdscript
func _on_browse_scene() -> void:
    _show_errors(["Browse not available in plugin context..."])
```
- **Status**: This is documented behavior, not a swallowed error. Acceptable.

**SiT-002: Tileset Load Failure Handling**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/map_metadata_editor.gd`
- **Lines**: 883-893
- **Severity**: Low
- **Description**: If no tilesets are found, only a warning is logged:
```gdscript
if available_tilesets.is_empty():
    push_warning("MapMetadataEditor: No tilesets found...")
```
- **Status**: Warning is appropriate for this scenario. User will see empty dropdown.

---

### TEMPORAL TRIBBLES (Hardcoded Values)

**TT-001: Save Slot Count Hardcoded**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/party_editor.gd`
- **Lines**: 175-177
- **Severity**: Low
- **Description**: Save slot selector hardcodes 3 slots:
```gdscript
save_slot_selector.add_item("Slot 1", 0)
save_slot_selector.add_item("Slot 2", 1)
save_slot_selector.add_item("Slot 3", 2)
```
- **Risk**: If game configuration changes max slots, editor won't reflect it.
- **Recommendation**: Read slot count from a configuration or constant.

**TT-002: Map Types Hardcoded Array**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/map_metadata_editor.gd`
- **Line**: 66
- **Severity**: Low
- **Description**: Map types are hardcoded:
```gdscript
const MAP_TYPES: Array[String] = ["TOWN", "OVERWORLD", "DUNGEON", "BATTLE", "INTERIOR"]
```
- **Status**: These match MapMetadata.MapType enum. If enum changes, this needs sync.
- **Recommendation**: Consider deriving from the actual MapMetadata enum if possible.

**TT-003: Font Sizes Throughout**
- **Various Files**
- **Severity**: Informational
- **Description**: Font sizes like `16` are hardcoded throughout for section labels. The codebase does use `SparklingEditorUtils.SECTION_FONT_SIZE` in some places but not consistently.
- **Recommendation**: Standardize on utility constants.

---

### PARASITIC TRIBBLES (Tight Coupling)

**PAT-001: ModLoader Dependency**
- **Various Files**
- **Severity**: Informational (Design Choice)
- **Description**: Multiple editors directly access `ModLoader` and `ModLoader.registry` globals. This is acceptable given the mod-centric architecture but means editors cannot function without the ModLoader autoload.
- **Status**: Intentional design. Editors check for ModLoader existence before use.

---

### BABY TRIBBLES (Minor Issues/Code Smells)

**BT-001: Duplicate Error Panel Creation**
- **Files**: `mod_json_editor.gd`, `campaign_editor.gd` (vs. using `json_editor_base.gd`)
- **Severity**: Minor
- **Description**: `mod_json_editor.gd` and `campaign_editor.gd` create their own error panels rather than extending `JsonEditorBase`. This duplicates code.
- **Recommendation**: Consider refactoring these to extend `JsonEditorBase`.

**BT-002: Inconsistent Separator Creation**
- **Various Files**
- **Severity**: Style
- **Description**: Some editors use `_add_separator()` helper, others inline the separator creation.
- **Status**: Works correctly, just inconsistent.

**BT-003: Style Guide Compliance**
- **All Files**
- **Severity**: Style
- **Description**: The codebase correctly avoids walrus operator (`:=`) as per CLAUDE.md. Dictionary key checks correctly use `if "key" in dict` pattern. Strict typing is used throughout.
- **Status**: EXCELLENT - Full compliance with project style guide.

---

### TRIBBLE EGGS (Potential Future Issues)

**TE-001: Large Resource List Performance**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/base_resource_editor.gd`
- **Severity**: Potential
- **Description**: Resource lists are rebuilt entirely on each refresh. With hundreds of resources across multiple mods, this could become slow.
- **Recommendation**: Consider virtualized lists or incremental updates for large datasets.

**TE-002: Undo/Redo Not Implemented**
- **All Editors**
- **Severity**: Potential (Feature Gap)
- **Description**: No integration with Godot's UndoRedo system. Users cannot undo changes made through the editor.
- **Recommendation**: Future enhancement to track changes via EditorUndoRedoManager.

**TE-003: Rapid Tab Switching**
- **File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/main_panel.gd`
- **Severity**: Potential
- **Description**: Rapid tab switching could trigger multiple simultaneous refreshes.
- **Status**: Current debounce in EditorEventBus mitigates this, but extremely rapid switching might queue up operations.

**TE-004: File Watcher Integration**
- **All Editors**
- **Severity**: Potential (Feature Gap)
- **Description**: Editors don't detect external file changes. If user edits a .tres or .json file in external editor, the plugin won't auto-refresh.
- **Recommendation**: Consider filesystem watcher for resource directories.

---

## Positive Observations

The trouble with tribbles is they breed in the dark corners you forget to check. But this engineering team left the lights on throughout. Here's what impressed me:

1. **Excellent Security in EditorTabRegistry**: Path traversal prevention at lines 164-174 is well implemented. No one's sneaking malicious paths through this airlock.

2. **Consistent `is_instance_valid()` Usage**: The team knows nodes can be freed unexpectedly in Godot. Proper validation throughout.

3. **Smart Debouncing**: EditorEventBus implements 100ms debounce for expensive operations, preventing cascade refreshes.

4. **Cache Management**: Tab registry uses dirty flag pattern (`_cache_dirty`) for efficient cache rebuilds.

5. **Proper Signal Cleanup**: Base resource editor correctly disconnects signals when switching resources to prevent memory leaks and stale callbacks.

6. **Defensive UI Guards**: Nearly every UI update function checks for null UI references before proceeding.

7. **Type Safety**: Strict typing throughout with explicit type annotations. No walrus operator abuse.

8. **Dictionary Access**: Correct use of `if "key" in dict` pattern as specified in CLAUDE.md.

9. **Resource Path Validation**: Scene paths and resource paths are validated before use.

10. **Graceful Degradation**: When ModLoader isn't available, editors fail gracefully with warnings rather than crashes.

---

## Tribble Count Summary

| Category | Count | Severity |
|----------|-------|----------|
| PLAGUE (Critical) | 0 | - |
| WILD (Exceptions) | 1 | Low |
| PHANTOM (Null Refs) | 1 | Medium |
| ASYNCHRONOUS (Races) | 0 (Mitigated) | - |
| ZOMBIE (Leaks) | 0 | - |
| SHAPESHIFTER (Types) | 0 | - |
| QUANTUM (State) | 1 | Low |
| MIRROR (Logic) | 0 | - |
| SILENT (Swallowed) | 0 | - |
| TEMPORAL (Hardcoded) | 3 | Low |
| PARASITIC (Coupling) | 0 (Design Choice) | - |
| BABY (Smells) | 3 | Style |
| EGGS (Future Risk) | 4 | Potential |

**Total Active Issues**: 6 Low + 1 Medium = 7 minor issues
**Total Potential Issues**: 4 future considerations

---

## Tribble-Proofing Recommendations

### Priority 1: Quick Wins
1. **Add null coalescing for OptionButton metadata** (PT-003) - 5 minutes fix
2. **Guard campaign resource_path access** (WT-002) - 2 minutes fix
3. **Add dirty tracking for text fields in mod_json_editor** (QT-001) - 10 minutes

### Priority 2: Code Quality
4. **Extract save slot count to constant** (TT-001)
5. **Standardize font size usage via SparklingEditorUtils** (TT-003)
6. **Consider having mod_json_editor extend JsonEditorBase** (BT-001)

### Priority 3: Future Proofing
7. **Plan undo/redo integration** (TE-002) - Major feature
8. **Consider virtualized lists for large resource sets** (TE-001)
9. **Add file watcher for external changes** (TE-004)

---

## Ship Status

**CONDITION: GREEN**

This codebase is almost tribble-free. Almost only counts in horseshoes and photon torpedoes, but in this case, the remaining specimens are so minor they pose no threat to mission operations.

The Sparkling Editor shows the hallmarks of disciplined Starfleet engineering:
- Defensive programming throughout
- Proper resource management
- Consistent code style
- Clear separation of concerns
- Good use of base classes for shared functionality

I've seen cleaner code only in the theoretical computer science labs on Vulcan. The engineering team has done the USS Torvalds proud.

**Recommendation**: Deploy with confidence. Address the 7 minor issues during regular maintenance cycles. Monitor the 4 potential future issues as the codebase grows.

---

*"The trouble with tribbles is they breed in the dark corners you forget to check. This team left the lights on."*

**- Burt Macklin, Tribble Hunter**

*Report filed Stardate 2025.12.08*
*End transmission.*
