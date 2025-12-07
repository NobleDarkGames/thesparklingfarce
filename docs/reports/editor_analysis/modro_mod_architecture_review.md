# Sparkling Editor Mod Architecture Review

**Reviewer:** Modro (Mod Architecture Specialist)
**Date:** 2025-12-06
**Scope:** `addons/sparkling_editor/` - Full editor mod support audit

---

## Executive Summary

**Overall Moddability Score: 7.5/10**

The Sparkling Editor demonstrates a solid foundation for mod-aware content editing. The architecture correctly uses ModLoader for resource discovery, implements cross-mod ResourcePickers, and provides proper EditorEventBus integration for cross-tab communication. However, several hardcoded paths and fallback patterns compromise total conversion potential.

### Key Strengths
- ModLoader-driven resource discovery across all mods
- ResourcePicker component shows resources from ALL mods with source attribution
- EditorEventBus enables reactive cross-tab synchronization
- base_resource_editor.gd provides excellent mod-aware foundation
- "Copy to My Mod" and "Create Override" workflows support proper mod isolation

### Critical Issues Requiring Immediate Attention
1. Hardcoded `_base_game` fallback paths in 5+ editors
2. Map template extends hardcoded `_base_game` script path
3. AI brain discovery limited to hardcoded paths
4. No mechanism for mods to add custom editor tabs declaratively
5. Tileset fallback defaults to `_base_game`

---

## Architecture Overview

### Core Infrastructure

#### EditorEventBus (`/addons/sparkling_editor/editor_event_bus.gd`)
**Moddability Score: 9/10**

Excellent design. Provides centralized event system with proper signals:
- `resource_saved(resource_type, resource_id, resource)`
- `resource_created(resource_type, resource_id, resource)`
- `resource_deleted(resource_type, resource_id)`
- `active_mod_changed(mod_id)`
- `mods_reloaded()`
- `resource_copied(resource_type, source_path, target_mod_id, target_path)`
- `resource_override_created(resource_type, resource_id, mod_id)`

**Strengths:**
- Clean signal-based decoupling between editor tabs
- Proper mod lifecycle notifications
- Override tracking support

**No Issues Found**

---

#### base_resource_editor.gd (`/addons/sparkling_editor/ui/base_resource_editor.gd`)
**Moddability Score: 8.5/10**

Well-architected base class for .tres resource editors.

**Strengths:**
- Uses `ModLoader.get_active_mod()` for save paths (line 436)
- Cross-mod write protection with warning dialog (lines 580-588)
- "Copy to My Mod" and "Create Override" workflows (lines 617-763)
- Namespace conflict detection (lines 802-875)
- Source mod tracking per resource (`current_resource_source_mod`)
- Helper methods: `_get_active_mod_id()`, `_get_active_mod_folder()`, `_get_active_mod_directory()`

**Minor Issues:**
- `_scan_all_mods_for_resource_type()` iterates all mods sequentially (could be slow with many mods)
- No pagination for large mod collections

---

#### ResourcePicker (`/addons/sparkling_editor/ui/components/resource_picker.gd`)
**Moddability Score: 9/10**

Excellent cross-mod resource selection component.

**Strengths:**
- Shows resources from ALL mods with `[mod_id] Resource Name` format
- Override detection via `_scan_for_overrides()` (lines 242-289)
- Visual override indicators: `[ACTIVE - overrides: mod_x]` or `[overridden by: mod_y]`
- Auto-refresh on EditorEventBus.mods_reloaded signal
- Configurable filter function for slot-specific filtering

**Minor Issues:**
- Override scan iterates ALL mod directories each refresh (performance concern with many mods)

---

#### JsonEditorBase (`/addons/sparkling_editor/ui/json_editor_base.gd`)
**Moddability Score: 8/10**

Good base class for JSON-based editors (campaigns, maps, cinematics).

**Strengths:**
- `get_active_mod_resource_dir()` properly uses `ModLoader.get_active_mod()`
- `scan_all_mods_for_resources()` discovers across all `mods/*/data/{dir_name}/`
- EditorEventBus integration via `notify_resource_saved/created/deleted()`

**No Critical Issues Found**

---

### Tab Editor Analysis

#### Character Editor (`/addons/sparkling_editor/ui/character_editor.gd`)
**Moddability Score: 7/10**

**Strengths:**
- Uses ResourcePicker for class selection
- Uses ResourcePicker for equipment selection with filter functions
- Gets unit categories from `ModLoader.unit_category_registry` with fallback
- Gets equipment slots from `ModLoader.equipment_slot_registry` with fallback

**CRITICAL ISSUE - Hardcoded AI Brain Paths (lines 395-396):**
```gdscript
var ai_dirs: Array[String] = [
    "res://mods/_base_game/ai_brains/",
    "res://core/ai/"  # Future location for built-in AI
]
```

This prevents total conversions from using their own AI brain locations. A total conversion mod cannot override or extend the AI brain discovery.

**Recommendation:**
```gdscript
# Should scan ALL mods for ai_brains directories
var ai_dirs: Array[String] = []
var mods: Array[ModManifest] = ModLoader.get_all_mods()
for mod in mods:
    ai_dirs.append(mod.mod_directory.path_join("ai_brains/"))
ai_dirs.append("res://core/ai/")  # Core fallback last
```

---

#### Battle Editor (`/addons/sparkling_editor/ui/battle_editor.gd`)
**Moddability Score: 7/10**

**Strengths:**
- Uses ResourcePicker for party, character, and dialogue selection
- Gets weather types from `ModLoader.environment_registry` with fallback
- Gets time of day from `ModLoader.environment_registry` with fallback
- Map dropdown scans all `mods/*/maps/` directories

**CRITICAL ISSUE - Hardcoded AI Brain Paths (lines 899-901):**
```gdscript
var ai_dirs: Array[String] = [
    "res://mods/_base_game/ai_brains/",
    "res://core/ai/"
]
```

Same issue as Character Editor - total conversions cannot use their own AI brains.

---

#### Map Metadata Editor (`/addons/sparkling_editor/ui/map_metadata_editor.gd`)
**Moddability Score: 5/10** (Lowest Score)

Multiple hardcoded path issues make this problematic for total conversions.

**CRITICAL ISSUE 1 - Hardcoded Tileset Fallback (lines 960-961):**
```gdscript
# Add default fallback
if available_tilesets.is_empty():
    available_tilesets.append("res://mods/_base_game/tilesets/terrain_placeholder.tres")
```

**CRITICAL ISSUE 2 - Hardcoded Tileset in Scene Generation (line 1007):**
```gdscript
var tileset_path: String = "res://mods/_base_game/tilesets/terrain_placeholder.tres"
```

**CRITICAL ISSUE 3 - Hardcoded Map Template Path (line 1107):**
```gdscript
lines.append('extends "res://mods/_base_game/maps/templates/map_template.gd"')
```

This is the most severe issue. Every new map created will ALWAYS extend `_base_game`'s template script, even in a total conversion that completely replaces `_base_game`.

**CRITICAL ISSUE 4 - Hardcoded Active Mod Fallbacks (lines 1286, 1295):**
```gdscript
func _get_active_mod_id_safe() -> String:
    ...
    return "_base_game"

func _get_active_mod_directory_safe() -> String:
    ...
    return "res://mods/_base_game/"
```

**Recommendation:**
1. Move `map_template.gd` to `core/templates/` (platform code, not mod content)
2. Make tileset fallback configurable via mod.json or remove it entirely
3. Fallback to `_sandbox` development mod, not `_base_game`
4. Consider a "Map Template" picker that discovers templates from all mods

---

#### Cinematic Editor (`/addons/sparkling_editor/ui/cinematic_editor.gd`)
**Moddability Score: 7.5/10**

**ISSUE - Hardcoded Active Mod Fallback (lines 1241-1246):**
```gdscript
func _get_active_mod() -> String:
    if ModLoader:
        var active_mod: ModManifest = ModLoader.get_active_mod()
        if active_mod:
            return active_mod.mod_id
    return "_base_game"  # <-- Hardcoded fallback
```

**Recommendation:** Return empty string or error state, not a specific mod ID.

---

#### NPC Editor (`/addons/sparkling_editor/ui/npc_editor.gd`)
**Moddability Score: 7.5/10**

**Strengths:**
- Uses ResourcePicker for character selection
- Connects to EditorEventBus.mods_reloaded
- Creates cinematics in active mod path

**ISSUE - Hardcoded Sandbox Fallback:**
At some point in the code (grep showed line 1627), there's a fallback to `res://mods/_sandbox/` when active mod cannot be determined.

While `_sandbox` is better than `_base_game` (it's a development mod, not content), this still represents a hardcoded assumption.

---

#### Terrain Editor (`/addons/sparkling_editor/ui/terrain_editor.gd`)
**Moddability Score: 8.5/10**

**Strengths:**
- Properly extends base_resource_editor.gd
- Sets `resource_type_id = "terrain"` and `resource_type_name = "Terrain"`
- Comment documents: `# resource_directory is set dynamically via base class using ModLoader.get_active_mod()`

**No Critical Issues Found**

---

#### Other Resource Editors (Class, Item, Ability, Party)
**Moddability Score: 8/10**

These editors properly extend `base_resource_editor.gd` and inherit its mod-aware functionality. They use ResourcePickers where appropriate for cross-mod references.

---

### Main Panel (`/addons/sparkling_editor/ui/main_panel.gd`)
**Moddability Score: 7.5/10**

**Strengths:**
- Active Mod selector at top with proper ModLoader integration
- `_load_mod_editor_extensions()` discovers custom editor tabs from mods
- Persists last selected mod to `user://sparkling_editor_settings.json`
- Create New Mod wizard with proper folder structure
- Safe refresh method validation (`_is_safe_refresh_method`)
- Dynamic editor tabs from `mod.json` `editor_extensions`

**Minor Issue - Hidden Campaigns Default (line 801):**
```gdscript
if type_data.type == "total_conversion":
    mod_json["hidden_campaigns"] = ["_base_game:*"]
```

This assumes total conversions want to hide `_base_game` campaigns. While reasonable, it's an implicit assumption.

---

## Critical Issues Summary

### Priority 1: Blocks Total Conversions

| Issue | Location | Impact |
|-------|----------|--------|
| Hardcoded map template extends `_base_game` | map_metadata_editor.gd:1107 | Every new map inherits from _base_game, even in total conversions |
| Hardcoded `_base_game` tileset fallback | map_metadata_editor.gd:961, 1007 | Total conversions get incorrect default tileset |
| Hardcoded AI brain discovery | character_editor.gd:395-396, battle_editor.gd:899-901 | Total conversions cannot use their own AI brains |

### Priority 2: Violates Mod Isolation

| Issue | Location | Impact |
|-------|----------|--------|
| `_base_game` fallback in mod ID getters | map_metadata_editor.gd:1286, 1295 | Operations may incorrectly target _base_game |
| `_base_game` fallback in cinematic_editor | cinematic_editor.gd:1246 | Same issue |
| `_sandbox` fallback in npc_editor | npc_editor.gd:~1627 | Development mod assumption |

### Priority 3: Data-Driven Gaps

| Issue | Location | Impact |
|-------|----------|--------|
| AI brain paths not data-driven | Multiple editors | Cannot configure via mod.json |
| Map template not configurable | map_metadata_editor.gd | Total conversions need custom templates |
| Equipment slot wildcard types hardcoded as fallback | character_editor.gd:592-597 | Works but relies on registry availability |

---

## Mod Isolation Analysis

### What Works Well

1. **Resource Write Protection:**
   - base_resource_editor.gd tracks `current_resource_source_mod`
   - Warning dialog shown when attempting cross-mod writes
   - "Copy to My Mod" creates unique ID in active mod
   - "Create Override" creates same-ID file in active mod

2. **Resource Discovery:**
   - ResourcePicker shows ALL mods' resources
   - Override detection shows which mod's version is active
   - `[mod_id] Resource Name` format provides clear attribution

3. **Cross-Tab Communication:**
   - EditorEventBus properly broadcasts resource changes
   - Pickers auto-refresh when mods reload
   - Active mod changes propagate to all tabs

### Potential Conflict Points

1. **Same-ID Resources:**
   - Multiple mods can have `character_hero.tres`
   - ResourcePicker correctly shows override status
   - But visual differentiation could be stronger (color coding?)

2. **Generated Content:**
   - New maps always extend `_base_game` template
   - If total conversion removes `_base_game`, map creation breaks

3. **Fallback Behavior:**
   - When ModLoader unavailable, editors fall back to hardcoded paths
   - Should fail gracefully or show clear error instead

---

## Recommendations

### Immediate Fixes (High Impact, Low Effort)

1. **Move map_template.gd to core:**
```
core/templates/map_template.gd
```
This makes it platform code, not mod content.

2. **Fix fallback functions to return empty/error:**
```gdscript
func _get_active_mod_id_safe() -> String:
    if ModLoader:
        var active_mod: ModManifest = ModLoader.get_active_mod()
        if active_mod:
            return active_mod.mod_id
    push_error("No active mod selected")
    return ""  # Empty, not a specific mod
```

3. **Scan ALL mods for AI brains:**
```gdscript
func _load_available_ai_brains() -> void:
    available_ai_brains.clear()

    # Scan all mods
    if ModLoader:
        for mod in ModLoader.get_all_mods():
            var ai_path: String = mod.mod_directory.path_join("ai_brains/")
            _scan_ai_directory(ai_path)

    # Core fallback
    _scan_ai_directory("res://core/ai/")
```

### Architecture Improvements (Medium Effort)

1. **Configurable Map Templates:**
   - Add `map_templates` to mod.json
   - MapMetadataEditor presents picker for available templates
   - Default to core template if none specified

2. **AI Brain Registry:**
   - Create `ModLoader.ai_brain_registry` similar to other registries
   - Mods declare AI brains in mod.json
   - Editors query registry instead of scanning directories

3. **Tileset Registry:**
   - Create `ModLoader.tileset_registry`
   - Mods declare their tilesets in mod.json
   - No hardcoded fallback needed

### Editor Extension Enhancements (Higher Effort)

1. **Tab Registration API:**
   Current `editor_extensions` in mod.json is a good start. Enhance with:
   - Tab ordering/priority
   - Tab grouping (Content, Battle, Story, etc.)
   - Tab dependencies (only show if another tab exists)

2. **Custom Field Types:**
   - Allow mods to register custom ResourcePicker types
   - Enable mod-specific property editors

3. **Validation Extension:**
   - Allow mods to hook into resource validation
   - Custom validation rules via mod.json or scripts

---

## Editor Integration Assessment

### What Modders Can Do Through the Editor

| Task | Supported | Notes |
|------|-----------|-------|
| Create resources in active mod | Yes | Correct path resolution |
| Edit cross-mod resources | Yes | With warning dialog |
| Copy resources to active mod | Yes | With unique ID |
| Create overrides | Yes | Same ID in active mod |
| See resource sources | Yes | `[mod_id]` prefix |
| Create new mod | Yes | Wizard creates structure |
| Select active mod | Yes | Dropdown in header |
| Add custom editor tabs | Partial | Via `editor_extensions` |
| Configure custom AI | No | Hardcoded paths |
| Use custom map templates | No | Hardcoded to _base_game |

### What Modders Cannot Do (Gaps)

1. Define AI brains that editors discover
2. Provide custom map templates
3. Override tileset defaults
4. Add custom property editors
5. Extend validation rules
6. Register new resource types via editor

---

## Conclusion

The Sparkling Editor has a strong foundation for mod support. The core architecture (EditorEventBus, base_resource_editor, ResourcePicker) demonstrates excellent mod-aware design principles. The main issues are localized to specific editors with hardcoded paths that should be easy to fix.

**Recommended Fix Priority:**

1. **Week 1:** Move map_template.gd to core, fix AI brain discovery
2. **Week 2:** Replace all `_base_game` fallbacks with proper error handling
3. **Week 3:** Create AI Brain registry for data-driven discovery
4. **Week 4:** Create Tileset registry, configurable map templates

After these fixes, the editor would score **9/10** for moddability and fully support total conversion mods.

---

## Appendix: Files Reviewed

### Core Infrastructure
- `/addons/sparkling_editor/editor_event_bus.gd` (66 lines)
- `/addons/sparkling_editor/ui/main_panel.gd` (817 lines)
- `/addons/sparkling_editor/ui/base_resource_editor.gd` (1016 lines)
- `/addons/sparkling_editor/ui/json_editor_base.gd` (342 lines)

### Shared Components
- `/addons/sparkling_editor/ui/components/resource_picker.gd` (454 lines)

### Tab Editors
- `/addons/sparkling_editor/ui/character_editor.gd` (715 lines)
- `/addons/sparkling_editor/ui/battle_editor.gd` (1405 lines)
- `/addons/sparkling_editor/ui/map_metadata_editor.gd` (1296 lines)
- `/addons/sparkling_editor/ui/cinematic_editor.gd` (~1254 lines)
- `/addons/sparkling_editor/ui/npc_editor.gd` (1957 lines)
- `/addons/sparkling_editor/ui/terrain_editor.gd` (527 lines)

### Grep Searches Performed
- `_base_game` - Found 11 occurrences across 6 files
- `_sandbox` - Found fallback in npc_editor.gd
- `res://mods/` - Pattern analysis for path construction
