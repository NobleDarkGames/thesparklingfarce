# NPC System Implementation Plan

**Date**: 2025-12-06
**Status**: In Progress
**Phase**: NPC Editor Implementation

---

## Overview

The NPC system unifies dialog and character interaction through the cinematic system. NPCs don't just show dialog - they trigger full cinematics, allowing movement, camera effects, and complex scripted interactions.

**Key Insight**: Dialog IS a cinematic. Simple NPC interactions are 1-command cinematics; complex interactions use multiple commands.

---

## Completed Components

### NPCData Resource (`core/resources/npc_data.gd`)
```gdscript
npc_id: String                    # Unique identifier
npc_name: String                  # Display name
character_data: CharacterData     # Optional - for portrait/sprite
portrait: Texture2D               # Fallback if no character_data
map_sprite: Texture2D             # Fallback if no character_data
interaction_cinematic_id: String  # Primary cinematic
fallback_cinematic_id: String     # Default if no conditions match
conditional_cinematics: Array[Dictionary]  # Flag-based selection
face_player_on_interact: bool     # Turn to face player
facing_override: String           # Force specific facing
```

### NPCNode Component (`core/components/npc_node.gd`)
- Area2D-based scene component
- Auto-creates CinematicActor child for cinematic control
- Evaluates conditional cinematics against GameState flags
- Signals: `interaction_started`, `interaction_ended`

### Integration Points
- Hero as CinematicActor (`hero_controller.gd`) - allows cinematic control
- NPC lookup in map_template (`_find_npc_at_position()`)
- ModLoader registration (`"npcs": "npc"`)
- TriggerManager bug fix (method name correction)

---

## Current Phase: NPC Editor

### Architecture Decision

**Separate NPC Editor Tab** (not combined with Character Editor)

Rationale:
- Characters = battle units with stats, classes, equipment
- NPCs = map entities with dialog and conditional responses
- Optional relationship: NPCs can *reference* CharacterData for visuals
- Matches existing one-type-per-tab pattern

### UI Layout

```
+------------------+---------------------------------------------+
| NPCs             |  NPC Details                                |
|------------------|---------------------------------------------|
| [Search...]      |  Basic Information                          |
|------------------|  NPC ID: [______________]                   |
| * Elder Sage     |  Name:   [______________]                   |
|   Shop Keeper    |  Character: [ResourcePicker v]              |
|   Guard Captain  |                                             |
|                  |  Appearance Fallback (if no character)      |
|                  |  Portrait: [Select...]                      |
|                  |  Sprite:   [Select...]                      |
|                  |                                             |
|                  |  Interaction                                |
|                  |  Primary Cinematic: [dropdown v]            |
|                  |  Fallback Cinematic: [dropdown v]           |
|                  |                                             |
|                  |  Conditional Cinematics (priority order)    |
|                  |  +---------------------------------------+  |
|                  |  | #1 Flag: [____] [NOT] Cinematic: [v]  |  |
|                  |  | #2 Flag: [____] [ ]   Cinematic: [v]  |  |
|                  |  | [+ Add Condition]                     |  |
|                  |  +---------------------------------------+  |
|                  |                                             |
|                  |  Behavior                                   |
|                  |  [x] Face player on interact                |
|                  |  Facing Override: [Auto v]                  |
|                  |                                             |
| [Create New NPC] |  [Save Changes]  [Delete NPC]               |
| [Refresh List]   |  [Copy to My Mod] [Create Override]         |
+------------------+---------------------------------------------+
```

### Implementation Steps

| Step | Task | File | Status |
|------|------|------|--------|
| 1 | Create NPC Editor script | `addons/sparkling_editor/ui/npc_editor.gd` | Pending |
| 2 | Create minimal scene | `addons/sparkling_editor/ui/npc_editor.tscn` | Pending |
| 3 | Register tab in main panel | `addons/sparkling_editor/ui/main_panel.gd` | Pending |
| 4 | Basic fields (id, name) | npc_editor.gd | Pending |
| 5 | ResourcePicker for character | npc_editor.gd | Pending |
| 6 | Cinematic dropdowns | npc_editor.gd | Pending |
| 7 | Conditional array editor | npc_editor.gd | Pending |
| 8 | Behavior checkboxes | npc_editor.gd | Pending |
| 9 | Test save/load cycle | Manual testing | Pending |

### Technical Details

**Base Class**: Extend `base_resource_editor.gd`
- Provides: resource list, search, save/delete, cross-mod awareness
- Override: `_create_detail_form()`, `_load_resource_data()`, `_save_resource_data()`

**Cinematic Selection**:
- Initial: LineEdit with manual cinematic_id entry
- Future: CinematicPicker component scanning `mods/*/data/cinematics/*.json`

**Conditional Cinematics Array**:
```gdscript
# Each entry in the array
{
  "flag": "has_gate_pass",      # GameState flag to check
  "cinematic_id": "guard_pass", # Cinematic to play if condition met
  "negate": false               # If true, trigger when flag NOT set
}
```
- First matching condition wins (priority order)
- UI: VBoxContainer with add/remove/reorder for each entry

### Validation Rules
- `npc_id` is required and non-empty
- At least one cinematic must be defined (primary, fallback, or conditional)
- Each conditional entry requires both flag and cinematic_id

---

## Test Content Created

| File | Purpose |
|------|---------|
| `mods/_sandbox/data/npcs/test_elder.tres` | Simple NPC with one greeting |
| `mods/_sandbox/data/npcs/test_guard.tres` | Conditional NPC (flag-based) |
| `mods/_sandbox/data/cinematics/elder_greeting.json` | 3-line dialog cinematic |
| `mods/_sandbox/data/cinematics/guard_default.json` | "Need a pass" response |
| `mods/_sandbox/data/cinematics/guard_hints_pass.json` | "Talk to elder" hint |
| `mods/_sandbox/data/cinematics/guard_allows_passage.json` | "You may proceed" |

---

## Future Enhancements

1. **CinematicPicker Component** - Dropdown populated from cinematic JSON files
2. **NPC Preview** - Show portrait/sprite preview in editor
3. **Shop Integration** - Add shop_inventory fields when shop system exists
4. **Movement Behaviors** - Patrol paths, wandering (low priority)
5. **Context Variables** - `$interacted_npc` token resolution in cinematics

---

## Related Documentation

- `docs/specs/platform-specification.md` - NPCData resource type
- `CLAUDE.md` - Mod system architecture
- `core/resources/npc_data.gd` - NPCData implementation
- `core/components/npc_node.gd` - NPCNode implementation
