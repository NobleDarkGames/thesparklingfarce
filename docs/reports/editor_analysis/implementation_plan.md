# Sparkling Editor Implementation Plan

**Synthesized from Audit Reports**
**Date**: 2025-12-08
**Status**: Ready for Implementation

---

## Executive Summary

This plan addresses findings from four comprehensive audits:
- **Modro**: Mod architecture and total conversion support
- **Ed**: Plugin best practices and lifecycle management
- **Clauderina**: UI/UX improvements
- **Burt Macklin**: Bug hunting and defensive programming

The work is organized into four phases, prioritized by impact and dependency order. Quick wins are parallelizable within each phase.

---

## Phase 1: Critical Bug Fixes and Quick Wins

**Goal**: Fix bugs and low-effort improvements that provide immediate value.
**Estimated Total Effort**: 2-3 hours
**Parallelizable**: Yes (all tasks are independent)

### Task 1.1: Fix OptionButton Metadata Null Risk
**Complexity**: Small (5 min)
**Source**: Burt Macklin PT-003
**Files**:
- `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/campaign_editor.gd` (lines 569, 937-938)

**Problem**: `get_item_metadata(index)` could return null, causing type error when assigned to String.

**Implementation**:
```gdscript
# Before:
var node_id: String = "" if index == 0 else starting_node_option.get_item_metadata(index)

# After:
var metadata: Variant = starting_node_option.get_item_metadata(index)
var node_id: String = "" if (index == 0 or metadata == null) else str(metadata)
```

**Acceptance Criteria**:
- Selecting items in starting_node_option, on_victory_option, on_defeat_option, on_complete_option never causes null errors
- Manual test: Create campaign, add nodes, change dropdown selections

---

### Task 1.2: Guard Campaign Resource Path Access
**Complexity**: Small (2 min)
**Source**: Burt Macklin WT-002
**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/mod_json_editor.gd` (lines 1335-1349)

**Problem**: Iterating campaigns without checking for empty resource_path.

**Implementation**:
```gdscript
for campaign: Resource in campaigns:
    if campaign.resource_path.is_empty():
        continue
    # ... rest of existing code
```

**Acceptance Criteria**:
- No errors when campaigns exist in memory but haven't been saved
- Manual test: Refresh mod_json_editor after creating unsaved campaign

---

### Task 1.3: Add Dirty Tracking for Text Fields in mod_json_editor
**Complexity**: Small (10 min)
**Source**: Burt Macklin QT-001
**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/mod_json_editor.gd`

**Problem**: `is_dirty` flag not set when editing name_edit, version_edit, description_edit.

**Implementation**:
1. Connect `text_changed` signal for LineEdit fields
2. Connect `text_changed` signal for TextEdit fields

```gdscript
# In _setup_ui() or wherever these fields are created:
name_edit.text_changed.connect(_mark_dirty)
version_edit.text_changed.connect(_mark_dirty)
description_edit.text_changed.connect(_mark_dirty)
# ... for all text input fields

func _mark_dirty(_text: String = "") -> void:
    is_dirty = true
```

**Acceptance Criteria**:
- Changing any text field sets is_dirty = true
- Unsaved changes warning appears when switching away after text edits

---

### Task 1.4: Change enable_undo_redo Default to true
**Complexity**: Small (5 min)
**Source**: Ed Major Issue #1, Clauderina Suggestion
**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/base_resource_editor.gd` (line 21)

**Problem**: Users expect Ctrl+Z to work. Currently defaults to false.

**Implementation**:
```gdscript
# Before:
var enable_undo_redo: bool = false

# After:
var enable_undo_redo: bool = true
```

**Acceptance Criteria**:
- Ctrl+Z works in all resource editors by default
- Manual test: Make changes, press Ctrl+Z, verify undo works

---

### Task 1.5: Consolidate Duplicated Constants
**Complexity**: Small (15 min)
**Source**: Ed Minor Issue #2
**Files**:
- `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/editor_theme_utils.gd` (lines 14-18)
- `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/editor_utils.gd` (lines 13-22)

**Problem**: Both files define DEFAULT_LABEL_WIDTH, SECTION_FONT_SIZE, HELP_FONT_SIZE.

**Implementation**:
1. Keep constants in EditorThemeUtils (it's the authoritative source for theme/styling)
2. Update editor_utils.gd to reference EditorThemeUtils constants
3. Search for any direct usages and update

**Acceptance Criteria**:
- Only one definition of each constant exists
- All references point to EditorThemeUtils

---

## Phase 2: Signal Cleanup and Lifecycle Management

**Goal**: Prevent memory leaks and ensure proper resource cleanup.
**Estimated Total Effort**: 1-2 hours
**Parallelizable**: Yes (each editor can be updated independently)
**Template**: Use `npc_editor.gd` and `resource_picker.gd` as reference implementations

### Task 2.1: Add _exit_tree() to base_resource_editor.gd
**Complexity**: Small (15 min)
**Source**: Ed Major Issue #2
**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/base_resource_editor.gd`

**Implementation**:
```gdscript
func _exit_tree() -> void:
    var event_bus: Node = get_node_or_null("/root/EditorEventBus")
    if event_bus:
        if event_bus.resource_saved.is_connected(_on_dependency_resource_changed):
            event_bus.resource_saved.disconnect(_on_dependency_resource_changed)
        if event_bus.resource_created.is_connected(_on_dependency_resource_changed):
            event_bus.resource_created.disconnect(_on_dependency_resource_changed)
        if event_bus.resource_deleted.is_connected(_on_dependency_resource_changed):
            event_bus.resource_deleted.disconnect(_on_dependency_resource_changed)
        if event_bus.mods_reloaded.is_connected(_on_mods_reloaded):
            event_bus.mods_reloaded.disconnect(_on_mods_reloaded)
```

**Note**: Since this is the base class, all child editors automatically get cleanup.

**Acceptance Criteria**:
- No signal connection warnings in editor output after tab switching
- Long editor sessions don't show memory growth from stale connections

---

### Task 2.2: Add _exit_tree() to json_editor_base.gd
**Complexity**: Small (10 min)
**Source**: Ed Action Items
**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/json_editor_base.gd`

**Implementation**: Same pattern as Task 2.1

---

### Task 2.3: Add _exit_tree() to campaign_editor.gd
**Complexity**: Small (10 min)
**Source**: Ed Individual Tab Analysis
**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/campaign_editor.gd`

**Implementation**: Same pattern as Task 2.1, plus disconnect campaign_list.item_selected

---

### Task 2.4: Add _exit_tree() to map_metadata_editor.gd
**Complexity**: Small (10 min)
**Source**: Ed Individual Tab Analysis
**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/map_metadata_editor.gd`

---

### Task 2.5: Add _exit_tree() to battle_editor.gd
**Complexity**: Small (10 min)
**Source**: Ed Individual Tab Analysis
**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/battle_editor.gd`

---

## Phase 3: UI/UX Improvements

**Goal**: Improve usability and developer experience.
**Estimated Total Effort**: 4-6 hours
**Parallelizable**: Tasks 3.1-3.3 can run in parallel

### Task 3.1: Fix Resource List Height Constraint
**Complexity**: Medium (30 min)
**Source**: Clauderina Major Issue #1
**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/base_resource_editor.gd` (line 210)

**Problem**: Fixed 150px height severely limits usability with many resources.

**Current Code**:
```gdscript
resource_list.custom_minimum_size = Vector2(0, 150)  # Fixed height to keep buttons visible
```

**Implementation Options** (choose one):
1. **Option A - Move buttons to top**: Rearrange left panel so Create/Refresh buttons are above the list, then use SIZE_EXPAND_FILL for list
2. **Option B - Use ScrollContainer**: Wrap the entire left panel in a ScrollContainer, allowing list to expand

**Recommended**: Option A (simpler, cleaner)

**Implementation**:
```gdscript
# Reorder: label, search, buttons row, then list
left_panel.add_child(help_label)
left_panel.add_child(search_filter)

# Button row at top
var btn_row: HBoxContainer = HBoxContainer.new()
btn_row.add_child(create_button)
btn_row.add_child(refresh_button)
left_panel.add_child(btn_row)

# List now expands to fill
resource_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
left_panel.add_child(resource_list)
```

**Acceptance Criteria**:
- Resource list expands to fill available vertical space
- Create/Refresh buttons always visible
- Works correctly with 0, 10, and 100+ resources

---

### Task 3.2: Add Search by ID and Source Mod
**Complexity**: Medium (45 min)
**Source**: Clauderina Major Issue #2
**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/base_resource_editor.gd` (around line 425)

**Problem**: Search only filters by display name, can't search by ID or source mod.

**Implementation**:
1. Update `_on_search_filter_changed()` to search in:
   - Display name (current)
   - Resource filename/ID
   - Source mod ID (from path or stored metadata)
2. Add filter dropdown for mod selection (optional enhancement)

**Basic Implementation**:
```gdscript
func _matches_search(resource: Resource, path: String, filter: String) -> bool:
    var display_name: String = _get_resource_display_name(resource).to_lower()
    var filename: String = path.get_file().get_basename().to_lower()
    var filter_lower: String = filter.to_lower()

    # Extract mod ID from path: mods/MOD_ID/data/...
    var mod_id: String = ""
    if "/mods/" in path:
        var parts: PackedStringArray = path.split("/mods/")[1].split("/")
        if parts.size() > 0:
            mod_id = parts[0].to_lower()

    return display_name.contains(filter_lower) or \
           filename.contains(filter_lower) or \
           mod_id.contains(filter_lower)
```

**Acceptance Criteria**:
- Typing "base" finds all resources from _base_game mod
- Typing resource ID finds that resource
- Display name search still works

---

### Task 3.3: Implement Character Editor Reference Checking
**Complexity**: Medium (45 min)
**Source**: Clauderina Major Issue #4
**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/character_editor.gd` (lines 192-199)

**Problem**: Can delete characters that are referenced in battles, causing broken references.

**Current Code**:
```gdscript
func _check_resource_references(resource_to_check: Resource) -> Array[String]:
    var references: Array[String] = []
    # TODO: In Phase 2+, check battles and dialogues for references to this character
    return references
```

**Implementation**:
```gdscript
func _check_resource_references(resource_to_check: Resource) -> Array[String]:
    var character: CharacterData = resource_to_check as CharacterData
    if not character:
        return []

    var references: Array[String] = []
    var char_id: String = character.character_uid

    # Check battles across all mods
    var battle_files: Array[Dictionary] = _scan_all_mods_for_resource_type("battle")
    for file_info: Dictionary in battle_files:
        var battle: BattleData = load(file_info.path) as BattleData
        if battle:
            for enemy: Dictionary in battle.enemies:
                if enemy.get("character_id", "") == char_id:
                    references.append(file_info.path)
                    break
            for neutral: Dictionary in battle.neutral_units:
                if neutral.get("character_id", "") == char_id:
                    references.append(file_info.path)
                    break

    # Check cinematics for spawn_entity commands
    var cinematic_files: Array[Dictionary] = _scan_all_mods_for_resource_type("cinematic")
    for file_info: Dictionary in cinematic_files:
        var json: String = FileAccess.get_file_as_string(file_info.path)
        if char_id in json:  # Quick check before full parse
            references.append(file_info.path)

    return references
```

**Acceptance Criteria**:
- Attempting to delete a character used in a battle shows warning with references
- Characters not in use can still be deleted
- Manual test: Create character, add to battle, try to delete character

---

### Task 3.4: Clarify Item Editor Equipment Type/Slot Relationship
**Complexity**: Small (20 min)
**Source**: Clauderina Major Issue #3
**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/item_editor.gd`

**Problem**: Two fields (equipment_type_edit LineEdit, equipment_slot_option OptionButton) with unclear relationship.

**Implementation**:
1. Add help text explaining the relationship
2. Consider auto-populating equipment_slot based on equipment_type selection
3. Add tooltip explaining: "Equipment type (e.g., 'sword') determines category; Equipment slot (e.g., 'main_hand') determines where item is equipped"

```gdscript
var type_help: Label = Label.new()
type_help.text = "Type defines the weapon/armor category (sword, axe, light, heavy).\nSlot defines where it's equipped (main_hand, body, accessory)."
type_help.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
type_help.add_theme_font_size_override("font_size", EditorThemeUtils.HELP_FONT_SIZE)
section.add_child(type_help)
```

**Acceptance Criteria**:
- Users understand the difference between equipment type and slot
- Help text clearly visible in the UI

---

### Task 3.5: Replace Hardcoded Colors with Theme Utils
**Complexity**: Small (30 min)
**Source**: Ed Minor Issue #1
**Files**:
- `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/base_resource_editor.gd` (lines 196-197, 1118)
- `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/editor_utils.gd` (line 71)
- `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/map_metadata_editor.gd` (multiple)
- `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/campaign_editor.gd` (NODE_COLORS constant)

**Implementation**:
```gdscript
# Before:
help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

# After:
help_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
```

Add to EditorThemeUtils if not present:
```gdscript
static func get_help_color() -> Color:
    var base_control: Control = EditorInterface.get_base_control()
    if base_control:
        return base_control.get_theme_color("font_disabled_color", "Editor")
    return Color(0.7, 0.7, 0.7)
```

**Acceptance Criteria**:
- Editor adapts correctly to light/dark themes
- No hardcoded Color() values for UI elements

---

## Phase 4: Mod Architecture - Type Registries

**Goal**: Enable total conversions by making hardcoded enums data-driven.
**Estimated Total Effort**: 8-12 hours
**Parallelizable**: Task 4.1 must complete first; then 4.2-4.5 can be parallel
**Architecture Decision Required**: Yes (design type registry system)

### Task 4.1: Design Type Registry Architecture
**Complexity**: Large (2-3 hours)
**Source**: Modro Priority 1 Recommendations
**New File**: `core/registries/type_registry.gd` (design document first)

**Problem**: Multiple hardcoded enums prevent total conversions:
- AbilityType (ATTACK, HEAL, SUPPORT, DEBUFF, SPECIAL)
- TargetType (SINGLE_ENEMY, SINGLE_ALLY, SELF, etc.)
- MovementType (WALKING, FLYING, FLOATING)
- Campaign node types (battle, scene, cutscene, choice)
- Cinematic commands (wait, dialog_line, move_entity, etc.)

**Architecture Decision Points**:
1. **Registry Location**: Single TypeRegistry class vs. multiple specialized registries?
   - Recommendation: Single TypeRegistry with type categories
2. **Storage Format**: How do mods declare custom types in mod.json?
   - Current: `custom_types.weapon_types: ["laser"]` exists
   - Extend to: `custom_types.ability_types`, `custom_types.movement_types`, etc.
3. **Fallback Behavior**: What happens if registry unavailable?
   - Must have hardcoded defaults for core types
4. **Enum Compatibility**: How to maintain compatibility with existing GDScript enums?
   - Option A: String-based types everywhere (breaking change)
   - Option B: Hybrid - core types use enums, custom types use strings
   - Recommendation: Option B for backward compatibility

**Implementation Sketch**:
```gdscript
# core/registries/type_registry.gd
class_name TypeRegistry
extends RefCounted

var _types: Dictionary = {}  # category -> {type_id -> metadata}

func register_type(category: String, type_id: String, metadata: Dictionary) -> void:
    if not category in _types:
        _types[category] = {}
    _types[category][type_id] = metadata

func get_types(category: String) -> Array[String]:
    if not category in _types:
        return []
    return Array(_types[category].keys(), TYPE_STRING, "", null)

func get_type_metadata(category: String, type_id: String) -> Dictionary:
    if category in _types and type_id in _types[category]:
        return _types[category][type_id]
    return {}
```

**mod.json Extension**:
```json
{
  "custom_types": {
    "ability_types": [
      {"id": "draw", "display_name": "Draw Card", "description": "Draw from deck"}
    ],
    "target_types": [
      {"id": "deck", "display_name": "Deck", "description": "Target the deck"}
    ],
    "movement_types": [
      {"id": "teleport", "display_name": "Teleport", "terrain_ignore": true}
    ],
    "campaign_node_types": [
      {"id": "puzzle", "display_name": "Puzzle", "color": "#FFAA00"}
    ],
    "cinematic_commands": [
      {"id": "beam_teleport", "description": "Star Trek transporter effect", "params": {...}}
    ]
  }
}
```

**Acceptance Criteria**:
- Design document approved
- TypeRegistry class implemented with tests
- ModLoader loads custom_types from mod.json

---

### Task 4.2: Update Ability Editor for Type Registry
**Complexity**: Medium (1-2 hours)
**Source**: Modro Critical Issue - Ability Editor
**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/ability_editor.gd` (lines 279-301)

**Current Code**:
```gdscript
ability_type_option.add_item("Attack", AbilityData.AbilityType.ATTACK)
ability_type_option.add_item("Heal", AbilityData.AbilityType.HEAL)
# ... hardcoded
```

**Implementation**:
```gdscript
func _populate_ability_types() -> void:
    ability_type_option.clear()

    # Add core types (maintain enum compatibility)
    ability_type_option.add_item("Attack", AbilityData.AbilityType.ATTACK)
    ability_type_option.add_item("Heal", AbilityData.AbilityType.HEAL)
    ability_type_option.add_item("Support", AbilityData.AbilityType.SUPPORT)
    ability_type_option.add_item("Debuff", AbilityData.AbilityType.DEBUFF)
    ability_type_option.add_item("Special", AbilityData.AbilityType.SPECIAL)

    # Add custom types from registry
    if ModLoader and ModLoader.type_registry:
        var custom_types: Array[String] = ModLoader.type_registry.get_types("ability_types")
        for type_id in custom_types:
            var meta: Dictionary = ModLoader.type_registry.get_type_metadata("ability_types", type_id)
            var display: String = meta.get("display_name", type_id.capitalize())
            # Use negative IDs for custom types to distinguish from enums
            ability_type_option.add_item(display, -1)
            ability_type_option.set_item_metadata(ability_type_option.item_count - 1, type_id)
```

**Note**: AbilityData resource may need update to store custom types as strings.

**Acceptance Criteria**:
- Core ability types still work with existing resources
- Custom types from mods appear in dropdown
- Selecting custom type saves correctly

---

### Task 4.3: Update Class Editor for Movement Type Registry
**Complexity**: Medium (1 hour)
**Source**: Modro Major Issue - Class Editor
**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/class_editor.gd` (lines 251-255)

**Current Code**:
```gdscript
movement_type_option.add_item("Walking", ClassData.MovementType.WALKING)
movement_type_option.add_item("Flying", ClassData.MovementType.FLYING)
movement_type_option.add_item("Floating", ClassData.MovementType.FLOATING)
```

**Implementation**: Same pattern as Task 4.2

**Note**: ClassData.movement_type needs to support string values for custom types.

---

### Task 4.4: Update Campaign Editor for Node Type Registry
**Complexity**: Medium (1-2 hours)
**Source**: Modro Major Issue - Campaign Editor
**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/campaign_editor.gd` (line 20)

**Current Code**:
```gdscript
const NODE_TYPES: Array[String] = ["battle", "scene", "cutscene", "choice"]
```

**Implementation**:
```gdscript
func _get_node_types() -> Array[String]:
    var types: Array[String] = ["battle", "scene", "cutscene", "choice"]  # Core types
    if ModLoader and ModLoader.type_registry:
        var custom: Array[String] = ModLoader.type_registry.get_types("campaign_node_types")
        types.append_array(custom)
    return types

func _get_node_color(node_type: String) -> Color:
    # Check core types first
    if node_type in NODE_COLORS:
        return NODE_COLORS[node_type]
    # Check registry for custom type color
    if ModLoader and ModLoader.type_registry:
        var meta: Dictionary = ModLoader.type_registry.get_type_metadata("campaign_node_types", node_type)
        if "color" in meta:
            return Color.html(meta["color"])
    return Color.WHITE  # Default for unknown types
```

---

### Task 4.5: Update Cinematic Editor for Command Registry
**Complexity**: Large (2-3 hours)
**Source**: Modro Major Issue - Cinematic Editor
**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/cinematic_editor.gd` (lines 15-154)

**Problem**: COMMAND_DEFINITIONS is a massive hardcoded constant.

**Implementation**:
1. Create `CinematicCommandRegistry` class
2. Load base commands from constant
3. Merge mod-provided commands from type_registry
4. Update cinematic_editor to query registry instead of constant

```gdscript
func _get_command_definitions() -> Dictionary:
    var commands: Dictionary = COMMAND_DEFINITIONS.duplicate(true)
    if ModLoader and ModLoader.type_registry:
        var custom: Array[String] = ModLoader.type_registry.get_types("cinematic_commands")
        for cmd_id in custom:
            var meta: Dictionary = ModLoader.type_registry.get_type_metadata("cinematic_commands", cmd_id)
            commands[cmd_id] = meta
    return commands
```

**Note**: Mods must provide complete command schemas in mod.json.

---

### Task 4.6: Extend Override Detection to JSON Files
**Complexity**: Medium (1 hour)
**Source**: Modro Major Issue - ResourcePicker
**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/components/resource_picker.gd` (line 270)

**Current Code**:
```gdscript
if not res_dir.current_is_dir() and file_name.ends_with(".tres"):
```

**Implementation**:
```gdscript
if not res_dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".json")):
```

---

## Phase 5: Future Enhancements (Lower Priority)

These items are documented for future consideration but not scheduled.

### 5.1: Add Unsaved Changes Check on Mod Switch
**Source**: Modro Priority 2 #6
**File**: main_panel.gd
**Description**: Before changing active mod, check all editors for is_dirty and prompt.

### 5.2: Status Effect Autocomplete
**Source**: Modro Priority 3 #7
**File**: ability_editor.gd
**Description**: Pull status effects from type registry for autocomplete.

### 5.3: Resource Reference Autocomplete in Campaign Editor
**Source**: Modro Priority 3 #8
**File**: campaign_editor.gd
**Description**: resource_id field should offer picker from BattleData/CinematicData.

### 5.4: Cross-Mod Dependency Validation
**Source**: Modro Priority 2 #5
**Description**: Warn when referencing resources from mods not in dependency list.

### 5.5: Bulk Operations
**Source**: Clauderina Suggestion
**Description**: Multi-select for delete/export/copy operations.

### 5.6: Recent Files in Overview Tab
**Source**: Clauderina Suggestion
**Description**: Show last 5-10 edited resources for quick access.

### 5.7: Keyboard Shortcuts Help Panel
**Source**: Clauderina Minor Issue
**Description**: Add "?" button or menu showing available shortcuts.

### 5.8: Virtualized Lists for Large Resource Sets
**Source**: Burt Macklin TE-001
**Description**: Performance optimization for 100+ resources.

---

## Testing Requirements

### Unit Tests (gdUnit4)
Each phase should include unit tests for new functionality:

- Phase 1: No new tests needed (bug fixes)
- Phase 2: Test signal connections/disconnections in mocked editor context
- Phase 3: Test search filter matching logic
- Phase 4: TypeRegistry tests for registration, lookup, mod merging

### Manual Testing Checklist

**After Phase 1**:
- [ ] Create campaign, manipulate dropdowns - no errors
- [ ] Edit mod.json fields, switch tabs - unsaved warning appears
- [ ] Ctrl+Z works in all resource editors

**After Phase 2**:
- [ ] Open/close editor tabs repeatedly - no memory growth
- [ ] Check Godot output for signal connection warnings

**After Phase 3**:
- [ ] Resource list expands to fill panel height
- [ ] Search finds resources by ID and mod name
- [ ] Attempt to delete character used in battle - warning shown

**After Phase 4**:
- [ ] Create mod with custom ability type in mod.json
- [ ] Ability editor shows custom type in dropdown
- [ ] Save ability with custom type, reload - type preserved

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Phase 4 breaks existing resources | Medium | High | Use hybrid enum/string approach |
| UI changes affect screen readers | Low | Medium | Maintain semantic structure |
| Performance regression in search | Low | Low | Profile before/after |
| Type registry complexity | Medium | Medium | Start simple, iterate |

---

## Implementation Order Summary

1. **Phase 1** (Quick Wins) - Do first, all parallel
2. **Phase 2** (Signal Cleanup) - Do second, all parallel
3. **Phase 3** (UI/UX) - Can overlap with Phase 2
4. **Phase 4** (Type Registries) - Do after 1-3, requires design review

---

*Plan compiled by Lt. Claudbrain, USS Torvalds*
*"Make it so, but test it first."*
