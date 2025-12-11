# Sparkling Editor Expansion Plan

**Status:** Phases 1-6 Complete, Phase 7.1-7.4 Complete, Phase 7.5-7.6 Planned
**Priority:** High - Critical for modder accessibility
**Dependencies:** Phase 2.5.1 complete (mod extensibility)
**Target:** Before Phase 5 (advanced systems)
**Estimated Effort:** 11.5-17 days (Phases 1-6) + 3.75 days (Phase 7)
**Created:** December 3, 2025
**Last Verified:** December 11, 2025
**Approved:** December 3, 2025 (Captain Obvious, with O'Brien architectural review)
**Phase 7 Added:** December 11, 2025 (Party/Config workflow improvements)

---

## Implementation Progress

| Phase | Component | Status | Commit | Notes |
|-------|-----------|--------|--------|-------|
| 1A | ResourcePicker widget | ✅ Complete | `c09df5f` | Cross-mod dropdowns with `[mod_id]` format |
| 1A | Editor integration | ✅ Complete | `0493833` | battle_editor, character_editor updated |
| 1B | mod.json editor | ✅ Complete | `298454a` | All 9 sections, EditorEventBus fix |
| 2 | MapMetadata editor | ✅ Complete | `a0a4352` | JSON-based editor, all map metadata fields |
| 3 | CinematicData editor | ✅ Complete | `45a5037` | 19 command types, command inspector panel |
| 4 | CampaignData editor | ✅ Complete | `cf9375c` | GraphEdit visual node graph with color-coding |
| 5 | Dynamic tab registration | ✅ Complete | `1e5eb99` | Mods can add custom editor tabs via mod.json |
| 6 | UX polish | ✅ Complete | (staged) | Search/filter, keyboard shortcuts (Ctrl+S/N) |
| 7.1 | Auto-create default config | ✅ Complete | (staged) | Mod wizard creates NewGameConfigData |
| 7.2 | "Set as Default" button | ✅ Complete | (staged) | One-click party assignment in party_editor |
| 7.3 | Resource list badges | ✅ Complete | (staged) | [ACTIVE DEFAULT] visual indicators |
| 7.4 | Preview config panel | ✅ Complete | (staged) | Shows effective party at game start |
| 7.5 | Character party status | 📋 Planned | - | Info when is_default_party_member checked |
| 7.6 | Template config file | 📋 Planned | - | Example in _template mod |

---

## Verification Summary (December 3, 2025)

**Updated after Phase 1 completion:**
- **8 editors exist:** Character, Class, Item, Ability, Dialogue, Party, Battle, **Mod Settings (NEW)**
- **All resource dropdowns now use ResourcePicker** - shows ALL mods with `[mod_id]` prefix
- **EditorEventBus references fixed** - use `get_node_or_null()` for runtime lookup
- **Tab registration still hardcoded** in `main_panel.gd` (Phase 5 will address)

**Original assessment (preserved for reference):**
- Map dropdown ALREADY implements multi-mod pattern - used as template for ResourcePicker

---

## Overview

The Sparkling Editor plugin currently covers 7 of ~15 moddable resource types (47% coverage). This plan addresses the gaps to ensure non-technical modders can create full game content without manually editing GDScript or JSON files.

**Away Team:** Lt. Claudbrain, Clauderina, Ed
**Architectural Review:** Modro

---

## Current State Assessment

### Editor Coverage

| Covered (7) | Missing - High Priority (3) | Missing - Medium/Low (5) |
|-------------|----------------------------|--------------------------|
| CharacterData | CinematicData | TerrainData |
| ClassData | CampaignData | AIBrain (visual) |
| ItemData | MapMetadata | mod.json editor |
| AbilityData | | SaveData (runtime, intentional) |
| DialogueData | | CombatAnimationData |
| PartyData | | |
| BattleData | | |

### Architectural Strengths (Keep These)

1. **Base class pattern** (`base_resource_editor.gd`) - 90% boilerplate handled
2. **EditorEventBus** - Cross-editor communication works well
3. **Mod-aware design** - Active mod selector, cross-mod write protection
4. **Type registry integration** - Mods can add types that auto-appear in dropdowns
5. **Consistent UI patterns** - Split-List-Detail layout, sectioned forms

### Moddability Score: 7.5/10

**Justification (Modro):** The existing editor foundation is solid - ModLoader integration, type registries, cross-mod write protection, and EditorEventBus show the team understands mod-first design. However, gaps exist that limit total conversion capability.

---

## Critical Issues Identified

### Issue 1: Resource References and Mod Override Visibility (MEDIUM)

**Location:** All editor files when storing resource references

**Original Concern:** Dropdowns store Resource objects directly, not `{mod_id, resource_id}` pairs. When a referenced resource is from base_game but the modder's mod has a same-ID override, the wrong resource gets loaded depending on save order.

**Chief O'Brien's Analysis (December 3, 2025):** After examining actual `.tres` file format, Godot's native resource serialization already stores references using `ext_resource` with full paths and UIDs:
```
[ext_resource type="Resource" uid="uid://csan6ysxhu3p0" path="res://mods/_base_game/data/characters/max.tres" id="2_max"]
```

The resource path IS preserved in the .tres file. The real issues are:
1. **Editor Dropdown Population** - Only showing active mod resources (addressed in Issue 2)
2. **Override Ambiguity at Runtime** - If a higher-priority mod overrides `max.tres`, the .tres file still points to the original path, but `ModLoader.registry.get_resource()` would return the override

**Approved Solution (Native Godot References):**
- Keep Godot's native resource reference mechanism (battle-tested, no migration needed)
- When loading resources at runtime, check if referenced resource ID has an override in a higher-priority mod
- Provide clear visual feedback in editor showing which mod provides selected resource AND whether it has overrides
- Add `ModRegistry.get_resource_source_by_resource()` convenience method

**Alternative Considered (Soft References):**
Store references as `{mod_id: String, resource_id: String}` pairs, resolved at runtime via ModLoader.registry. This approach was rejected due to:
- Requires migration of all existing .tres files
- Requires changes to core Resource class definitions
- Requires custom serialization/deserialization logic
- Adds complexity without clear benefit over native approach

---

### Issue 2: Dropdown Populations Show Only Active Mod (PARTIAL - Map Dropdown Already Fixed)

**Location:** Multiple files - `character_editor.gd`, `battle_editor.gd`, `party_editor.gd`

**Good News:** The `battle_editor.gd` already implements multi-mod resource display for **map selection** (lines 745-795). It scans ALL mods and displays as `[mod_name] filename`. This is the correct pattern!

**Example of WORKING pattern from `battle_editor.gd` `_update_map_dropdown()`:**
```gdscript
# Scans ALL mod directories for maps
var mods_dir: DirAccess = DirAccess.open("res://mods/")
mods_dir.list_dir_begin()
var mod_name: String = mods_dir.get_next()

while mod_name != "":
    if mods_dir.current_is_dir() and not mod_name.begins_with("."):
        var maps_path: String = "res://mods/%s/maps/" % mod_name
        # ... scan and add with "[mod_name] filename" format
```

**Still Broken:** Character, class, party, dialogue, and AI brain dropdowns only query active mod:

**Example from `battle_editor.gd` lines 646-652 (NEEDS FIXING):**
```gdscript
if ModLoader:
    var active_mod: ModManifest = ModLoader.get_active_mod()
    if active_mod:
        var resource_dirs: Dictionary = ModLoader.get_resource_directories(active_mod.mod_id)
        if "character" in resource_dirs:
            character_dir = resource_dirs["character"]
```

**Solution:** Apply the map dropdown pattern to all resource reference dropdowns:
```gdscript
func _populate_resource_picker(resource_type: String, option_button: OptionButton) -> void:
    option_button.clear()
    option_button.add_item("(None)", -1)

    # Get ALL resources of type from registry (all mods)
    var all_resources: Array[Resource] = ModLoader.registry.get_all_resources(resource_type)

    for i in range(all_resources.size()):
        var resource: Resource = all_resources[i]
        var display_name: String = _get_display_name(resource)
        var source_mod: String = ModLoader.registry.get_resource_source(_get_resource_id(resource))

        # Format: "[mod_id] Display Name"
        option_button.add_item("[%s] %s" % [source_mod, display_name], i)
        option_button.set_item_metadata(i + 1, resource)
```

---

### Issue 3: No mod.json Editor (HIGH)

**Impact:** Total conversion mods cannot visually configure:
- `equipment_slot_layout` (custom equipment slots)
- `custom_types` (new weapon types, weather types, etc.)
- `scene_overrides` (replace main menu, battle scene, etc.)
- `party_config` (replaces_lower_priority for total conversions)
- `inventory_config` (slots per character, allow duplicates)

Modders must hand-edit JSON, which is error-prone and intimidating.

---

### Issue 4: Editor Tab Registration is Hardcoded (MEDIUM)

**Location:** `main_panel.gd` lines 7-13

```gdscript
const CharacterEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/character_editor.tscn")
const ClassEditorScene: PackedScene = preload("res://addons/sparkling_editor/ui/class_editor.tscn")
# ... hardcoded
```

**Problem:** Mods cannot provide custom editor tabs for their own resource types.

**Solution:** Move to data-driven tab discovery with mod extension support.

---

## Proposed Solutions

### Phase 1A: Fix Resource Dropdowns (0.5-1 day)

**Objective:** Show all mod resources in reference pickers with source attribution

**Template Already Exists:** The `battle_editor.gd` `_update_map_dropdown()` method (lines 745-795) already implements this pattern correctly. It:
- Scans ALL mod directories (not just active mod)
- Displays as `[mod_name] filename`
- Stores full path in metadata

**Implementation:**

1. Create reusable `ResourcePicker` widget based on existing map dropdown pattern
2. Generalize to work with ModLoader.registry for typed resources
3. Display format: `"[mod_id] Resource Name"`
4. Store both mod_id and resource_id in item metadata
5. Update all existing editors to use the new widget:
   - `character_editor.gd` - class dropdown (line 405-437)
   - `item_editor.gd` - effect dropdown
   - `battle_editor.gd` - character/AI/party/dialogue dropdowns (lines 641-674, 1029-1064, 1079-1115)
   - `party_editor.gd` - character dropdown
   - `ability_editor.gd` - status effect references

**Effort Reduced:** Having a working template in the codebase reduces implementation time.

**Deliverables:**
- `ResourcePicker` reusable component (based on map dropdown pattern)
- All editors updated to use mod-aware dropdowns
- Source mod visible in all resource selections

---

### Phase 1B: mod.json Editor (2 days)

**Objective:** Visual editor for mod manifest configuration

**Essential Sections:**

1. **Basic Info**
   - id (read-only after creation)
   - name, version, author, description
   - godot_version

2. **Load Priority**
   - SpinBox with range labels
   - 0-99: Official content
   - 100-8999: User mods
   - 9000-9999: Total conversions

3. **Dependencies**
   - List editor with mod ID autocomplete
   - Visual dependency graph (stretch goal)

4. **Custom Types**
   - Sub-editors for each type registry:
     - weapon_types
     - armor_types
     - weather_types
     - time_of_day
     - unit_categories
     - trigger_types
     - animation_offset_types

5. **Equipment Slot Layout** (Total Conversion)
   - Visual slot editor
   - id, display_name, accepts_types per slot
   - Add/remove/reorder slots

6. **Inventory Config**
   - slots_per_character (SpinBox)
   - allow_duplicates (CheckBox)

7. **Party Config**
   - replaces_lower_priority (CheckBox with warning text)

8. **Scene Overrides**
   - Table: scene_id -> relative path
   - Scene picker for path selection
   - Show which mod provides current override

9. **Content Paths**
   - data_path (default: "data/")
   - assets_path (default: "assets/")

**Deliverables:**
- `mod_json_editor.gd` extending base_resource_editor
- Full coverage of mod.json capabilities
- Validation for required fields

---

### Phase 2: MapMetadata Editor (1-2 days)

**Objective:** Visual editor for map configuration

**Features:**

1. **Basic Properties**
   - map_id, display_name
   - map_type dropdown (TOWN, OVERWORLD, DUNGEON, BATTLE, INTERIOR)
   - apply_type_defaults button (auto-fill based on type)

2. **Caravan Settings**
   - caravan_accessible (CheckBox)
   - caravan_visible (CheckBox)

3. **Camera Settings**
   - camera_zoom (SpinBox, 0.5-2.0)

4. **Scene Reference**
   - Scene picker for map .tscn files
   - Validates scene exists

5. **Spawn Points Editor**
   - List of spawn points
   - Each: id, grid_position (Vector2i), facing, is_default
   - Add/remove spawn points

6. **Connections Editor**
   - Table: target_map_id, target_spawn_id, trigger_position
   - Dropdown for target_map_id from loaded MapMetadata

7. **Audio Settings**
   - music_id, ambient_id (with preview buttons, stretch goal)

8. **Encounter Settings**
   - random_encounters_enabled (CheckBox)
   - base_encounter_rate (SpinBox, 0.0-1.0)
   - save_anywhere (CheckBox)

**Technical Consideration:** MapMetadata uses JSON format, requires manual serialization.

**Deliverables:**
- `map_metadata_editor.gd`
- JSON serialization/deserialization
- Connection validation (target map exists)

---

### Phase 3: CinematicData Editor (3-4 days)

**Objective:** Visual timeline editor for cutscene sequences

**Architecture Decision:** Start with list-based command editor, add timeline view in Phase 2 enhancement.

**Command Types to Support:**
- move_entity, set_facing, play_animation
- show_dialog, add_inline_dialog
- camera_move, camera_follow, camera_shake
- wait, fade_screen
- play_sound, play_music
- spawn_entity, despawn_entity
- trigger_battle, change_scene
- set_variable, conditional, parallel

**Features:**

1. **Command List**
   - Drag-and-drop reordering
   - Expand/collapse for parameters
   - Copy/paste commands
   - Command type picker

2. **Command Inspector Panel**
   - Right-side panel for selected command
   - Type-specific parameter forms
   - Entity ID picker (characters + special IDs: player, camera, screen)

3. **Dialog Integration**
   - Reference existing DialogueData
   - Inline dialog editor for simple cases

4. **Metadata**
   - cinematic_id, cinematic_name, description
   - can_skip, skip_key
   - fade_in_duration, fade_out_duration
   - next_cinematic reference

**Technical Consideration:** CinematicData supports JSON format.

**Deliverables:**
- `cinematic_editor.gd`
- Command list with reordering
- Per-command-type parameter forms
- JSON serialization

---

### Phase 4: CampaignData Editor (3-4 days)

**Objective:** GraphEdit-based node graph for campaign progression

**Implementation Approach:**

**Phase 4.1 - MVP (2 days):**
- GraphEdit with CampaignNode as GraphNode
- Color-coded by type:
  - Battle: Red
  - Scene: Blue
  - Cutscene: Yellow
  - Choice: Purple
  - Hub: Green border
- Basic connections: on_victory, on_defeat, on_complete
- Start node indicator (starting_node_id)
- Chapter boundary visual separators

**Phase 4.2 - Enhancement (1-2 days):**
- Flag requirements as badges on nodes
- Branch labels on connection lines
- Zoom/pan for large campaigns
- Simple mode / Advanced mode toggle

**Node Inspector Panel:**
- node_id, display_name
- node_type (from TriggerTypeRegistry)
- resource_id (ResourcePicker filtered by node_type)
- Transition targets (on_victory, on_defeat, on_complete)
- Flags: on_enter_flags, on_complete_flags
- Requirements: required_flags, forbidden_flags
- Settings: repeatable, allow_egress, is_hub, is_chapter_boundary

**Deliverables:**
- `campaign_editor.gd` using GraphEdit
- CampaignNodeGraphNode custom GraphNode
- Visual connections with labels
- Node inspector panel

---

### Phase 5: Infrastructure Enhancements (2 days)

**5.1 Dynamic Tab Registration (1 day)**

Allow mods to provide custom editor tabs:

```json
// mod.json
{
  "editor_extensions": {
    "puzzle": {
      "resource_type": "puzzle",
      "editor_scene": "editor_plugins/puzzle_data_editor.tscn",
      "tab_name": "Puzzles"
    }
  }
}
```

**Implementation:**
- `main_panel.gd` scans mods for `editor_extensions`
- Dynamically instantiates mod-provided editor scenes
- Adds as tabs after built-in editors

**5.2 Mod Isolation Workflow Features (1 day)**

1. **"Copy to my mod" button**
   - On resource selection when viewing other mod's resource
   - Creates new file in active mod with unique ID
   - Opens copied resource for editing

2. **"Create Override" button**
   - When viewing base_game resource
   - Creates same-ID resource in active mod (higher priority wins)
   - Shows warning about override behavior

3. **Visual Diff View** (stretch goal)
   - When resource has matching ID in multiple mods
   - Split view: base version (read-only) | override (editable)
   - Highlight changed fields

---

### Phase 6: UX Polish (1-2 days)

**6.1 Shared Theme Resource**
- Create `editor_theme.tres` in `addons/sparkling_editor/`
- Define constants: font sizes (title: 24, section: 14, help: 11)
- Define colors: help_text, error, success, warning
- Define spacing constants

**6.2 Search/Filter**
- Add search LineEdit above ItemList in base_resource_editor
- Fuzzy text matching on resource names
- Preserve selection across filter changes

**6.3 Resource Previews**
- Thumbnail generation for Characters (portrait)
- Thumbnail generation for Items (icon)
- Display in ItemList

**6.4 Tooltips Pass**
- Add tooltips to all form fields
- Explain purpose, valid ranges, examples

**6.5 Keyboard Shortcuts**
- Ctrl+S: Save current resource
- Ctrl+N: Create new resource
- Ctrl+D: Duplicate resource (copy to active mod)

**6.6 EditorUndoRedoManager Integration**
- Add to base_resource_editor.gd
- Track changes before save
- Allow undo/redo of field edits

---

## Implementation Priority (Modro's Recommendation)

| Priority | Phase | Component | Effort | Rationale |
|----------|-------|-----------|--------|-----------|
| 1 | 1A | Fix resource dropdowns | 0.5-1 day | Blocks correct resource referencing (template exists!) |
| 2 | 1B | mod.json editor | 2 days | Unlocks total conversion config |
| 3 | 2 | MapMetadata editor | 1-2 days | Foundation for world-building |
| 4 | 3 | CinematicData editor | 3-4 days | Enables story content creation |
| 5 | 4 | CampaignData editor | 3-4 days | Complex, defer until simpler tools solid |
| 6 | 5 | Dynamic tab registration | 1 day | Enables mod-provided editors |
| 7 | 6 | UX polish | 1-2 days | Quality of life improvements |

**Total Estimated Effort:** 11.5-17 days (reduced due to existing map dropdown pattern)

---

## Testing Strategy

### Unit Tests
- ResourcePicker shows all mods' resources
- mod.json editor serializes correctly
- MapMetadata JSON round-trips correctly
- CinematicData command serialization

### Integration Tests
- Create resource in mod A, reference from mod B
- Override base_game resource, verify priority
- Campaign node connections validated
- Scene picker finds correct files

### Regression Tests
- All existing editors continue working
- EditorEventBus signals fire correctly
- Cross-mod write protection still works
- Type registry integration preserved

---

## Success Criteria

### Functional Requirements
- [ ] Resource dropdowns show all loaded mods with source attribution
- [ ] mod.json can be fully edited without manual JSON editing
- [ ] MapMetadata can be created/edited for all map types
- [ ] Cinematics can be authored with visual command list
- [ ] Campaign node graphs can be designed visually
- [ ] Mods can provide custom editor tabs

### Quality Requirements
- [ ] Lt. Claudette code review: 4.5/5 or higher
- [ ] Clauderina UI/UX review: Consistent with established patterns
- [ ] Modro moddability score: 9.0/10 or higher
- [ ] All existing tests pass

### Coverage Target
- Before: 7/15 resource types (47%)
- After: 11/15 resource types (73%)
- Remaining: TerrainData, AIBrain (visual), CombatAnimationData, SaveData (runtime)

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| GraphEdit complexity (Campaign) | Medium | High | Start with MVP, layer features |
| JSON serialization bugs | Medium | Medium | Extensive round-trip testing |
| Resource reference refactoring breaks saves | Low | High | Version old format, migration path |
| Performance with large mod libraries | Low | Medium | Lazy loading, virtual lists |

---

## Open Questions

1. **Resource Reference Migration**
   - How do we handle existing BattleData/PartyData that store direct Resource references?
   - Add migration on load?
   - Decision: TBD by Captain

2. **Cinematic Preview**
   - Is in-editor preview feasible with @tool scripts?
   - Or defer to "test in game" workflow?
   - Decision: TBD by Lt. Claudbrain

3. **Campaign Complexity Toggle**
   - Simple mode (just connections) vs Advanced mode (full flags)?
   - Or always show full complexity?
   - Decision: TBD by Captain

---

## Files to Create

```
addons/sparkling_editor/
  ui/
    components/
      resource_picker.gd         # Reusable mod-aware resource dropdown
      resource_picker.tscn
    mod_json_editor.gd           # Phase 1B
    mod_json_editor.tscn
    map_metadata_editor.gd       # Phase 2
    map_metadata_editor.tscn
    cinematic_editor.gd          # Phase 3
    cinematic_editor.tscn
    campaign_editor.gd           # Phase 4
    campaign_editor.tscn
    campaign_node_graph_node.gd  # GraphNode for campaign nodes
  editor_theme.tres              # Phase 6
```

## Files to Modify

```
addons/sparkling_editor/
  ui/
    main_panel.gd                # Add new tabs, dynamic registration
    base_resource_editor.gd      # Add search, undo/redo, shared styling
    character_editor.gd          # Use ResourcePicker
    class_editor.gd              # Use ResourcePicker
    item_editor.gd               # Use ResourcePicker
    ability_editor.gd            # Use ResourcePicker
    dialogue_editor.gd           # Use ResourcePicker
    party_editor.gd              # Use ResourcePicker
    battle_editor.gd             # Use ResourcePicker
```

---

## Post-Completion Tasks

1. Update modding documentation with editor capabilities
2. Create video walkthrough for modders
3. Add "Getting Started" overlay to Overview tab
4. Consider TerrainData editor for Phase 6+
5. Blog post: "Sparkling Editor: Visual Modding for Everyone"

---

**Plan Created:** December 3, 2025
**Away Team:** Lt. Claudbrain, Clauderina, Ed
**Architectural Review:** Modro, Chief O'Brien
**Approved By:** Captain Obvious (December 3, 2025)
**Implementation Started:** December 3, 2025 (Phase 1A - ResourcePicker)

---

## Appendix A: Modro's Critical Recommendations

### On ResourcePicker Implementation

> "The active mod filter should only apply to the resource LIST (what you're editing), not to REFERENCE DROPDOWNS (what you're selecting from)."

### On mod.json Editor Completeness

> "Do NOT hide advanced options. Total conversion mods need all of these."

Essential capabilities to expose:
- `replaces_default_party` in party_config
- Scene overrides with visual registry
- Dependencies visualization (which mod provides what)
- Provides/overrides preview for debugging

### On CampaignData Complexity

> "Start simple, layer complexity. Simple mode (just connections) and advanced mode (full logic) toggle."

MVP: Colored nodes, basic connections, start indicator
Enhancement: Flag badges, branch labels, chapter separators
Advanced: Conditional logic visualization (may not be needed)

### On Mod Isolation

All three features are essential:
1. "Copy to my mod" - Clone resource to active mod
2. "Create Override" - Same-ID in active mod (higher priority wins)
3. "Visual Diff" - Split view for override comparison

---

## Appendix B: Current Editor Patterns to Maintain

### Split-List-Detail Layout
```
[Resource List]  |  [Detail Form with ScrollContainer]
  - Filter btns  |    - Sectioned VBoxContainers
  - ItemList     |    - Labeled input fields
  - Create/      |    - Save/Delete buttons
    Refresh      |    - Error panel (animated, styled)
```

### Standard Field Creation
```gdscript
var container: HBoxContainer = HBoxContainer.new()
var label: Label = Label.new()
label.text = "Field Name:"
label.custom_minimum_size.x = 120  # Consistent label width
container.add_child(label)

var input: LineEdit = LineEdit.new()
input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
container.add_child(input)
```

### Error Panel Styling
- PanelContainer with StyleBoxFlat (red bg, red border, rounded corners)
- RichTextLabel with BBCode support
- Animated pulse on appearance
- Hides on selection change or successful save

### EditorEventBus Signals
```gdscript
signal resource_saved(resource_type: String, resource_id: String, resource: Resource)
signal resource_created(resource_type: String, resource_id: String, resource: Resource)
signal resource_deleted(resource_type: String, resource_id: String)
signal active_mod_changed(mod_id: String)
signal mods_reloaded()
```

---

## Appendix C: Chief O'Brien's Architectural Review (December 3, 2025)

### Resource Reference Strategy Decision

> "The resource path IS preserved in the .tres file. The issue is not with how resources are *stored*, but rather with editor dropdown population and runtime override resolution."

**Approved Approach:** Keep Godot's native resource references. This avoids:
- Migration of 60+ existing .tres files
- Custom serialization/deserialization logic
- Changes to core Resource class definitions
- Breaking third-party mod compatibility

### Recommended ModRegistry Enhancement

```gdscript
func get_resource_source_by_resource(resource: Resource) -> String:
    if not resource or resource.resource_path.is_empty():
        return ""
    var resource_id: String = resource.resource_path.get_file().get_basename()
    return get_resource_source(resource_id)
```

### EditorEventBus Signal Additions for Copy/Override Workflows

```gdscript
signal resource_copied(source_type: String, source_id: String, target_mod: String, new_id: String)
signal resource_override_created(resource_type: String, resource_id: String, override_mod: String)
```

### JSON Serialization Abstraction

Multiple new editors (MapMetadata, CinematicData, CampaignData) need JSON handling. Abstract into shared utility rather than duplicating code.

### GraphEdit Contingency

If GraphEdit proves unstable for Campaign Editor, have fallback options ready:
- Tree-based view (Godot's Tree node is more stable)
- Table-based view with connection columns
- Export to/Import from external graph tools

---

## Appendix D: Unified Texture/Sprite Picker Architecture (Ed's Design)

**Created:** December 10, 2025
**Purpose:** Reusable component architecture for picking portraits, battle sprites, and map spritesheets

### The Problem

The Sparkling Farce platform requires three distinct texture/sprite asset types:

| Asset Type | Format | Animation | Validation | Use Case |
|------------|--------|-----------|------------|----------|
| **Portrait** | Single PNG/WebP | None | Dimensions vary, 2:1 to 1:1 aspect recommended | Dialog boxes, character info |
| **Battle Sprite** | Single PNG/WebP | None | Should be 32x32 or 64x64 for grid consistency | Tactical battle grid units |
| **Map Spritesheet** | PNG spritesheet | Yes (SpriteFrames) | Must be 64x128 (2 cols x 4 rows of 32x32) | Overworld/town exploration |

All three need:
- Mod-aware file browsing (scan all mods, show `[mod_id]` prefix)
- Preview panel showing the selected asset
- Path validation (file exists, correct format)
- Integration with EditorFileDialog

But they differ in:
- Validation rules (dimensions, grid layout)
- Preview rendering (static vs animated)
- Output (Texture2D vs SpriteFrames resource path)

### Design Philosophy

Like the universal translator handles dozens of languages through a common protocol with language-specific modules, we design a **base picker** with **specialized configurations**.

### Component Hierarchy

```
TexturePickerBase (abstract/shared)
├── PortraitPicker (static, flexible dimensions)
├── BattleSpritePicker (static, grid-constrained)
└── MapSpritesheetPicker (animated, strict grid layout)
```

### Shared Infrastructure

#### TexturePickerBase

A reusable HBoxContainer component providing:

```gdscript
@tool
class_name TexturePickerBase
extends HBoxContainer

## Signals
signal texture_selected(path: String, texture: Texture2D)
signal texture_cleared()
signal validation_changed(is_valid: bool, message: String)

## Configuration (set by subclasses or exports)
@export var label_text: String = "Texture:"
@export var label_min_width: float = 120.0
@export var placeholder_text: String = "res://mods/<mod>/assets/..."
@export var preview_size: Vector2 = Vector2(48, 48)
@export var file_filters: PackedStringArray = ["*.png ; PNG", "*.webp ; WebP"]
@export var default_browse_subpath: String = "assets/"

## Internal state
var _current_path: String = ""
var _is_valid: bool = false

## UI Components (created in _setup_ui)
var _label: Label
var _preview_panel: PanelContainer
var _preview_rect: TextureRect  # or AnimatedSprite2D for spritesheets
var _path_edit: LineEdit
var _browse_button: Button
var _clear_button: Button
var _validation_icon: TextureRect  # green check / red X
var _file_dialog: EditorFileDialog
```

**Key Methods:**

```gdscript
## Override in subclasses for custom validation
func _validate_texture(path: String, texture: Texture2D) -> Dictionary:
    # Returns { "valid": bool, "message": String }
    # Base implementation: just checks file exists
    return { "valid": texture != null, "message": "" if texture else "File not found" }

## Override for custom preview rendering
func _update_preview(texture: Texture2D) -> void:
    _preview_rect.texture = texture

## Public API
func set_texture_path(path: String) -> void
func get_texture_path() -> String
func get_texture() -> Texture2D
func is_valid() -> bool
func clear() -> void
```

#### Shared Preview Panel

All pickers use a common preview panel style:

```gdscript
func _create_preview_panel() -> PanelContainer:
    var panel: PanelContainer = PanelContainer.new()
    panel.custom_minimum_size = preview_size + Vector2(8, 8)  # padding

    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.12, 0.15)
    style.border_color = Color(0.3, 0.3, 0.35)
    style.set_border_width_all(1)
    style.set_corner_radius_all(4)
    style.set_content_margin_all(4)
    panel.add_theme_stylebox_override("panel", style)

    return panel
```

#### Mod-Aware Browse Dialog

The browse button opens to the active mod's appropriate asset directory:

```gdscript
func _get_default_browse_path() -> String:
    if not ModLoader:
        return "res://mods/"

    var active_mod: ModManifest = ModLoader.get_active_mod()
    if not active_mod:
        return "res://mods/"

    # Subclass-specific subpath (e.g., "assets/portraits/", "art/sprites/")
    var path: String = "res://mods/%s/%s" % [active_mod.mod_id, default_browse_subpath]

    # Create directory if it doesn't exist
    if not DirAccess.dir_exists_absolute(path):
        DirAccess.make_dir_recursive_absolute(path)

    return path
```

### Specialized Subclasses

#### PortraitPicker

```gdscript
@tool
class_name PortraitPicker
extends TexturePickerBase

## Portrait-specific configuration
func _init() -> void:
    label_text = "Portrait:"
    placeholder_text = "res://mods/<mod>/assets/portraits/..."
    preview_size = Vector2(64, 64)  # Larger preview for portraits
    default_browse_subpath = "assets/portraits/"

## Portrait validation: flexible, just warn on unusual aspect ratios
func _validate_texture(path: String, texture: Texture2D) -> Dictionary:
    if texture == null:
        return { "valid": false, "message": "File not found" }

    var size: Vector2 = texture.get_size()
    var aspect: float = size.x / size.y

    # Warn but don't fail on unusual aspects
    if aspect < 0.5 or aspect > 2.0:
        return { "valid": true, "message": "Unusual aspect ratio (%.1f:1)" % aspect }

    return { "valid": true, "message": "" }
```

#### BattleSpritePicker

```gdscript
@tool
class_name BattleSpritePicker
extends TexturePickerBase

## Expected dimensions for battle sprites
const VALID_SIZES: Array[Vector2i] = [Vector2i(32, 32), Vector2i(64, 64)]

func _init() -> void:
    label_text = "Battle Sprite:"
    placeholder_text = "res://mods/<mod>/assets/battle_sprites/..."
    preview_size = Vector2(48, 48)
    default_browse_subpath = "assets/battle_sprites/"

## Battle sprite validation: strict size requirements
func _validate_texture(path: String, texture: Texture2D) -> Dictionary:
    if texture == null:
        return { "valid": false, "message": "File not found" }

    var size: Vector2i = Vector2i(texture.get_size())

    if size in VALID_SIZES:
        return { "valid": true, "message": "" }

    # Warn on non-standard sizes
    return {
        "valid": true,  # Allow but warn
        "message": "Non-standard size %dx%d (expected 32x32 or 64x64)" % [size.x, size.y]
    }
```

#### MapSpritesheetPicker

This is the most complex picker - it needs to validate spritesheet layout AND optionally generate SpriteFrames.

```gdscript
@tool
class_name MapSpritesheetPicker
extends TexturePickerBase

## Spritesheet requirements (matches generate_map_sprite_frames.gd)
const FRAME_SIZE: Vector2i = Vector2i(32, 32)
const EXPECTED_COLS: int = 2  # 2 frames per animation
const EXPECTED_ROWS: int = 4  # down, left, right, up
const EXPECTED_SIZE: Vector2i = Vector2i(64, 128)  # 2*32 x 4*32

## Signals
signal sprite_frames_generated(sprite_frames_path: String)

## Additional state
var _sprite_frames_path: String = ""
var _generate_button: Button
var _animated_preview: AnimatedSprite2D  # replaces static TextureRect

func _init() -> void:
    label_text = "Map Spritesheet:"
    placeholder_text = "res://mods/<mod>/art/sprites/hero_spritesheet.png"
    preview_size = Vector2(64, 64)  # Show animated preview
    default_browse_subpath = "art/sprites/"
    file_filters = PackedStringArray(["*.png ; PNG Spritesheet"])

## Override to use AnimatedSprite2D for preview
func _create_preview_control() -> Control:
    _animated_preview = AnimatedSprite2D.new()
    _animated_preview.centered = true
    # Will be configured when spritesheet is loaded
    return _animated_preview

## Strict validation for spritesheet layout
func _validate_texture(path: String, texture: Texture2D) -> Dictionary:
    if texture == null:
        return { "valid": false, "message": "File not found" }

    var size: Vector2i = Vector2i(texture.get_size())

    if size != EXPECTED_SIZE:
        return {
            "valid": false,
            "message": "Invalid spritesheet size: %dx%d (expected %dx%d for 2-frame walk cycle)" % [
                size.x, size.y, EXPECTED_SIZE.x, EXPECTED_SIZE.y
            ]
        }

    return { "valid": true, "message": "Valid spritesheet layout" }

## Generate SpriteFrames resource from spritesheet
func generate_sprite_frames(output_path: String) -> bool:
    # Reuse logic from core/tools/generate_map_sprite_frames.gd
    # Returns true on success, false on failure
    pass

## Update animated preview
func _update_preview(texture: Texture2D) -> void:
    if not _animated_preview or texture == null:
        return

    # Create temporary SpriteFrames for preview
    var preview_frames: SpriteFrames = _create_preview_sprite_frames(texture)
    _animated_preview.sprite_frames = preview_frames
    _animated_preview.animation = "walk_down"
    _animated_preview.play()
```

### UI Layout

All three pickers share a common layout:

```
[Label: 120px] [Preview: 48-64px] [Path LineEdit: expand] [Browse] [Clear] [Validation Icon]
```

For MapSpritesheetPicker, add a "Generate SpriteFrames" button below:

```
[Label: 120px] [Preview: 64px] [Path LineEdit: expand] [Browse] [Clear] [Validation Icon]
               [   Generate SpriteFrames   ]  [SpriteFrames path or "Not generated"]
```

### Integration with Character Editor

The Character Editor's Appearance section would use all three:

```gdscript
## In character_editor.gd

var portrait_picker: PortraitPicker
var battle_sprite_picker: BattleSpritePicker
var map_spritesheet_picker: MapSpritesheetPicker

func _create_appearance_section() -> void:
    var section: VBoxContainer = _create_section("Appearance")

    # Portrait
    portrait_picker = PortraitPicker.new()
    portrait_picker.texture_selected.connect(_on_portrait_selected)
    section.add_child(portrait_picker)

    # Battle Sprite
    battle_sprite_picker = BattleSpritePicker.new()
    battle_sprite_picker.texture_selected.connect(_on_battle_sprite_selected)
    section.add_child(battle_sprite_picker)

    # Map Spritesheet (with SpriteFrames generation)
    map_spritesheet_picker = MapSpritesheetPicker.new()
    map_spritesheet_picker.texture_selected.connect(_on_spritesheet_selected)
    map_spritesheet_picker.sprite_frames_generated.connect(_on_sprite_frames_generated)
    section.add_child(map_spritesheet_picker)

func _load_character_to_ui(character: CharacterData) -> void:
    # ...
    portrait_picker.set_texture_path(character.portrait.resource_path if character.portrait else "")
    battle_sprite_picker.set_texture_path(character.battle_sprite.resource_path if character.battle_sprite else "")
    map_spritesheet_picker.set_sprite_frames_path(character.map_sprite_frames.resource_path if character.map_sprite_frames else "")

func _save_character_from_ui() -> void:
    # ...
    character.portrait = portrait_picker.get_texture()
    character.battle_sprite = battle_sprite_picker.get_texture()
    character.map_sprite_frames = load(map_spritesheet_picker.get_sprite_frames_path()) if map_spritesheet_picker.has_sprite_frames() else null
```

### Files to Create

```
addons/sparkling_editor/ui/components/
    texture_picker_base.gd       # Shared infrastructure
    portrait_picker.gd           # Static portrait selection
    battle_sprite_picker.gd      # Static battle sprite selection
    map_spritesheet_picker.gd    # Animated spritesheet + SpriteFrames generation
```

### Implementation Priority

1. **TexturePickerBase** (0.5 days) - Foundation shared by all three
2. **PortraitPicker** (0.25 days) - Simplest, just flexible dimensions
3. **BattleSpritePicker** (0.25 days) - Adds size validation
4. **MapSpritesheetPicker** (1 day) - Most complex: grid validation, animated preview, SpriteFrames generation
5. **Character Editor Integration** (0.5 days) - Replace current manual texture fields

**Total Estimated Effort:** 2.5 days

### Future Extensibility

This architecture can easily extend to support:
- **Combat Animation Spritesheets**: Different grid layout (attack frames, cast frames, etc.)
- **Item Icons**: 32x32 strict validation, batch import from icon sheets
- **Tileset Textures**: Preview individual tiles from a tileset image
- **Particle Textures**: Animated effect spritesheets

### Clauderina Review Needed

Before implementation, recommend UX review with Clauderina on:
1. Validation feedback placement (inline vs tooltip vs popup)
2. Animated preview behavior (auto-play vs hover-to-play vs click-to-play)
3. SpriteFrames generation workflow (auto-generate on valid spritesheet vs manual button)
4. Error state visual treatment (red border, shake animation, etc.)

---

## Appendix E: Phase 7 - Party/Config Workflow Improvements

**Created:** December 11, 2025
**Status:** 7.1-7.4 Complete, 7.5-7.6 Planned
**Completed:** December 11, 2025 (Phases 7.1-7.4 by Ed)
**Priority:** High - Critical pain point for new modders
**Away Team:** Modro (architecture), Ed (implementation), Clauderina (UX)

### Problem Statement

New modders creating a starting party for their mod encounter significant friction:

1. Must manually create `NewGameConfigData` with `is_default = true`
2. Must know to name party file identically to base_game's (`default_party.tres`) to override
3. Connection between `starting_party_id` and PartyData filename is non-obvious
4. No visual feedback on which config/party will actually be used at game start
5. Template mod missing `NewGameConfigData` example

**Current Moddability Score:** 6/10 (Modro assessment)
**Target Moddability Score:** 9/10

### Root Cause Analysis

The resource override system uses **filename as resource ID**:
- `mods/_base_game/data/parties/default_party.tres` → ID: "default_party"
- `mods/_sandbox/data/parties/my_party.tres` → ID: "my_party"

For sandbox to override base_game's party, the file must be named `default_party.tres`.

The `NewGameConfigData.starting_party_id` field references by filename, not by display name.

### Approved Solutions

#### Phase 7.1: Auto-Create Default NewGameConfigData (High Priority) - COMPLETE

**File:** `addons/sparkling_editor/ui/main_panel.gd`

When mod creation wizard runs, auto-create:
```
mods/<new_mod>/data/new_game_configs/default_config.tres
```

With contents:
```gdscript
config_id = "default"
config_name = "Default"
is_default = true
starting_party_id = ""  # Uses auto-detect (character flags)
```

**Effort:** 0.5 days
**Implementation:** `_create_default_new_game_config()` in main_panel.gd

#### Phase 7.2: "Set as Default Starting Party" Button (High Priority) - COMPLETE

**File:** `addons/sparkling_editor/ui/party_editor.gd`

Add button to Party Templates editor that:
1. Gets or creates the active mod's default `NewGameConfigData`
2. Sets `starting_party_id` to selected party's filename
3. Ensures `is_default = true`
4. Shows success message

**Effort:** 1 day
**Implementation:**
- `_add_default_party_section()` - Creates UI section with button
- `_on_set_default_party()` - Handles button press
- `_get_or_create_default_config()` - Finds/creates config
- `_show_success_message()` - Visual feedback on success

#### Phase 7.3: [ACTIVE DEFAULT] Badge in Resource Lists (Medium Priority) - COMPLETE

**Files:**
- `addons/sparkling_editor/ui/new_game_config_editor.gd`
- `addons/sparkling_editor/ui/party_editor.gd`

Display badges in resource list:
- `[ACTIVE DEFAULT]` - This config/party will be used at game start
- `[DEFAULT]` - Marked as default but overridden by higher-priority mod

**Effort:** 0.5 days
**Implementation:**
- `_load_default_party_info()` / `_load_active_default_info()` - Track active defaults
- `_get_resource_display_name()` override - Adds badges to list items
- `resource_dependencies = ["new_game_config"]` - Auto-refresh when configs change

#### Phase 7.4: Preview Configuration Panel (Medium Priority) - COMPLETE

**File:** `addons/sparkling_editor/ui/new_game_config_editor.gd`

Add collapsible "Preview Configuration" panel that shows:
- Which config is actually active (considering mod priority)
- List of party members that will be loaded
- Warning if this config is overridden by a higher-priority mod
- Starting gold and depot items count
- Caravan unlock status

**Effort:** 1 day
**Implementation:**
- `_add_preview_configuration_panel()` - Creates collapsible preview UI
- `_update_preview_panel()` - Populates preview with active config data
- `_get_active_default_config()` - Retrieves the effective config
- `_get_auto_detected_party_members()` / `_get_party_template_members()` - Party preview

#### Phase 7.5: Character Editor Party Status (Low Priority)

**File:** `addons/sparkling_editor/ui/character_editor.gd`

When `is_default_party_member` checkbox is checked, show info panel:
- "This character will be included in the default starting party"
- Whether active config uses auto-detect or explicit PartyData
- Link to NewGameConfig editor

**Effort:** 0.5 days

#### Phase 7.6: Template Mod NewGameConfigData (Low Priority)

**File:** `mods/_template/data/new_game_configs/default_config.tres`

Create template file with comments explaining each field.

**Effort:** 0.25 days

### Implementation Priority

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| 1 | 7.1 Auto-create default config | 0.5 days | Eliminates most common mistake |
| 2 | 7.2 "Set as Default" button | 1 day | One-click workflow |
| 3 | 7.3 Resource list badges | 0.5 days | Visual clarity |
| 4 | 7.4 Preview panel | 1 day | Debug capability |
| 5 | 7.5 Character status panel | 0.5 days | Polish |
| 6 | 7.6 Template file | 0.25 days | Documentation |

**Total Estimated Effort:** 3.75 days

### Ideal Workflow After Implementation

**Simple Path (2 clicks):**
1. Create party in Party Templates tab
2. Click "Set as Default Starting Party"
3. Done - party is configured and will be used

**Current Path (5+ steps):**
1. Create party
2. Note the filename
3. Go to New Game Configs tab
4. Create NewGameConfigData
5. Check `is_default`
6. Select party from dropdown
7. Save

### Success Criteria

- [ ] New mod creation includes default `NewGameConfigData`
- [ ] Party Templates has "Set as Default Starting Party" button
- [ ] Resource lists show which config/party is actually active
- [ ] Preview panel shows effective party composition
- [ ] Template mod includes example NewGameConfigData
- [ ] Moddability score reaches 9/10

### Files to Modify

```
addons/sparkling_editor/ui/
    main_panel.gd              # Auto-create config in mod wizard
    party_template_editor.gd   # "Set as Default" button, badges
    new_game_config_editor.gd  # Preview panel, badges
    character_editor.gd        # Party status panel

mods/_template/data/
    new_game_configs/
        default_config.tres    # Template file (NEW)
```

### Verification Checklist

After implementation, verify with fresh mod:
1. [ ] Create new mod via wizard → default_config.tres exists
2. [ ] Create character with `is_default_party_member = true`
3. [ ] Create party with that character
4. [ ] Click "Set as Default Starting Party"
5. [ ] Start new game → correct party loads
6. [ ] Badge shows [ACTIVE DEFAULT] in config list
7. [ ] Preview shows correct party members
