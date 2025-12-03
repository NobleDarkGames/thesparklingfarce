# Sparkling Editor Expansion Plan

**Status:** Proposed
**Priority:** High - Critical for modder accessibility
**Dependencies:** Phase 2.5.1 complete (mod extensibility)
**Target:** Before Phase 5 (advanced systems)
**Estimated Effort:** 12-18 days total
**Created:** December 3, 2025

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

### Issue 1: Resource References Lose Mod Origin (CRITICAL)

**Location:** All editor files when storing resource references

**Problem:** Dropdowns store Resource objects directly, not `{mod_id, resource_id}` pairs. When a referenced resource is from base_game but the modder's mod has a same-ID override, the wrong resource gets loaded depending on save order.

**Example from `battle_editor.gd`:**
```gdscript
var enemy_dict: Dictionary = {
    "character": character,  # Just the resource object - loses mod origin!
    "position": Vector2i(...),
    "ai_brain": ai_brain
}
```

**Solution:** Store references as `{mod_id: String, resource_id: String}` pairs, resolved at runtime via ModLoader.registry.

---

### Issue 2: Dropdown Populations Show Only Active Mod (CRITICAL)

**Location:** Multiple files - `character_editor.gd`, `battle_editor.gd`, `party_editor.gd`

**Example from `battle_editor.gd` lines 646-652:**
```gdscript
if ModLoader:
    var active_mod: ModManifest = ModLoader.get_active_mod()
    if active_mod:
        var resource_dirs: Dictionary = ModLoader.get_resource_directories(active_mod.mod_id)
        if "character" in resource_dirs:
            character_dir = resource_dirs["character"]
```

**Problem:** Reference dropdowns should show ALL resources from ALL loaded mods. Modders frequently reference base_game content (items, classes, abilities).

**Correct Approach:**
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

### Phase 1A: Fix Resource Dropdowns (1 day)

**Objective:** Show all mod resources in reference pickers with source attribution

**Implementation:**

1. Create reusable `ResourcePicker` widget in `addons/sparkling_editor/ui/components/`
2. Query `ModLoader.registry.get_all_resources(type)` instead of scanning active mod only
3. Display format: `"[mod_id] Resource Name"`
4. Store both mod_id and resource_id in item metadata
5. Update all existing editors to use the new widget:
   - `character_editor.gd` - class dropdown
   - `item_editor.gd` - effect dropdown
   - `battle_editor.gd` - character/AI dropdowns
   - `party_editor.gd` - character dropdown
   - `ability_editor.gd` - status effect references

**Deliverables:**
- `ResourcePicker` reusable component
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
| 1 | 1A | Fix resource dropdowns | 1 day | Blocks correct resource referencing |
| 2 | 1B | mod.json editor | 2 days | Unlocks total conversion config |
| 3 | 2 | MapMetadata editor | 1-2 days | Foundation for world-building |
| 4 | 3 | CinematicData editor | 3-4 days | Enables story content creation |
| 5 | 4 | CampaignData editor | 3-4 days | Complex, defer until simpler tools solid |
| 6 | 5 | Dynamic tab registration | 1 day | Enables mod-provided editors |
| 7 | 6 | UX polish | 1-2 days | Quality of life improvements |

**Total Estimated Effort:** 12-18 days

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
**Architectural Review:** Modro
**Approved By:** Pending Captain's approval

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
