# Caravan System Implementation Plan

**Created:** 2025-12-05
**Status:** IN PROGRESS
**Priority:** CRITICAL (Mission Priority One)

---

## Executive Summary

The Caravan system is the heart of SF2's open-world design and the critical feature that made it superior to SF1. This plan captures the unified intelligence from Commander Claudius, Mr. Nerdlinger, Lt. Ears, and Clauderina to create a Caravan system that will become the gold standard for SF-style tactical RPGs.

**Goal:** Make Justin squeal with fanboy glee.

---

## Current State Assessment

### What We Have (Excellent Foundation)

- [x] **StorageManager autoload** - Depot backend with unlimited storage
- [x] **CaravanDepotPanel** - Item storage UI with Take/Store functionality
- [x] **Item type filters** - Better than SF2 (which had none!)
- [x] **MapMetadata flags** - `caravan_visible` and `caravan_accessible` exist
- [x] **PartyFollower chain system** - Can be reused for Caravan following
- [x] **PartyManager** - Manages party members and save data

### Critical Gaps

- [ ] **Caravan sprite on overworld** - No visible wagon following hero
- [ ] **Caravan Main Menu** - No hub menu (Party/Storage/Rest/Exit)
- [ ] **Party Management UI** - Cannot swap active/reserve members
- [ ] **CaravanController** - No lifecycle management for caravan
- [ ] **CaravanData resource** - No moddable wagon configuration
- [ ] **Overworld interaction** - No way to interact with Caravan sprite

---

## Sacred Cows (DO NOT VIOLATE)

These are non-negotiable based on SF2 authenticity and fandom expectations:

1. **Unlimited storage** - Capping depot capacity would betray SF2's core promise
2. **Overworld-only visibility** - Caravan hidden in towns is CORRECT design
3. **No healing/saving inside** - Churches in towns must remain relevant
4. **Hero locked to slot 0** - Protagonist can never be removed from party
5. **Manual party management** - No auto-optimize or recommended builds
6. **Walk to access** - No "summon caravan" button; requires physical proximity

---

## Architecture Overview

### Three-Layer Approach

```
Layer 1: PLATFORM INFRASTRUCTURE (core/)
├── CaravanController (autoload) - lifecycle, mod config, signals
├── CaravanData (resource) - moddable wagon properties
└── Integration with ExplorationManager

Layer 2: COMPONENTS (core/components/)
├── CaravanFollower - physical wagon sprite, chain following
├── InteractableCaravan - Area2D for player access
└── CaravanInteriorScene - NPC services (future)

Layer 3: CONTENT (mods/)
├── default_caravan.tres - base game wagon config
├── caravan sprites - wagon directional art
└── NPC characters - advisors, shopkeepers (future)
```

### Key Integration Points

- **MapManager** - Spawn/despawn caravan based on MapMetadata
- **PartyManager** - Active (12) / Reserve roster management
- **StorageManager** - Already complete, wire to menu
- **CampaignManager** - Egress returns near caravan, encounter position preservation
- **GameState** - Caravan position in TransitionContext

---

## Phase 1: Foundation (Minimum Viable Caravan)

**Estimated Time:** 2-3 days
**Goal:** Caravan appears and follows hero on overworld maps

### Tasks

- [ ] **1.1 Create CaravanData resource class**
  - File: `core/resources/caravan_data.gd`
  - Properties: wagon_sprite, follow_distance, can_cross_water, services_enabled
  - Fully moddable via registry

- [ ] **1.2 Create CaravanController autoload**
  - File: `core/systems/caravan_controller.gd`
  - Responsibilities: load config, spawn/despawn, coordinate with MapMetadata
  - Signals: caravan_spawned, caravan_despawned, caravan_menu_opened

- [ ] **1.3 Create CaravanFollower component**
  - File: `core/components/caravan_follower.gd`
  - Reuse PartyFollower tile history pattern
  - Follow last party member (or hero if no party)
  - Directional sprite support

- [ ] **1.4 Create base game CaravanData resource**
  - File: `mods/_base_game/data/caravans/default_caravan.tres`
  - Configure default wagon properties

- [ ] **1.5 Integrate with MapMetadata**
  - Use existing `caravan_visible` flag
  - Spawn caravan on overworld maps
  - Despawn on town/battle maps

- [ ] **1.6 Add placeholder wagon sprite**
  - File: `mods/_base_game/assets/sprites/caravan_wagon.png`
  - Simple directional wagon (can be placeholder)

### Phase 1 Verification

- [ ] Caravan wagon visible on overworld test map
- [ ] Caravan follows hero using chain pattern
- [ ] Caravan disappears when entering town
- [ ] Caravan reappears when exiting town

---

## Phase 2: Services Integration

**Estimated Time:** 2-3 days
**Goal:** Full caravan functionality matches SF2

### Tasks

- [ ] **2.1 Create Caravan Main Menu**
  - File: `scenes/ui/caravan_main_menu.gd`
  - Options: Party Management, Item Storage, Rest & Heal, Exit
  - SF2-style centered panel with cursor navigation
  - Keyboard/gamepad first, mouse secondary

- [ ] **2.2 Create Party Management Panel**
  - File: `scenes/ui/party_management_panel.gd`
  - Portrait grid: 4x3 active (12 max) + reserves section
  - Character info panel on selection
  - Swap button to move between active/reserve

- [ ] **2.3 Add PartyManager roster methods**
  - `get_active_party() -> Array[CharacterData]` (first 12)
  - `get_reserve_party() -> Array[CharacterData]` (beyond 12)
  - `swap_active_reserve(active_uid, reserve_uid) -> bool`
  - Hero (slot 0) cannot be swapped out

- [ ] **2.4 Wire CaravanDepotPanel to menu**
  - "Item Storage" option opens existing depot panel
  - Ensure depot panel can be opened from menu context

- [ ] **2.5 Implement Rest & Heal service**
  - Free healing (restore all HP/MP)
  - Confirmation dialog: "Heal all party members?"
  - Sound effect on heal

- [ ] **2.6 Add caravan interaction on overworld**
  - Area2D proximity detection (1-2 tiles)
  - Show interaction prompt when in range
  - Action button opens Caravan Main Menu

- [ ] **2.7 Add item icons to depot slots**
  - Load ItemData.icon_texture into slot display
  - Fallback to colored square if no icon

### Phase 2 Verification

- [ ] Can interact with Caravan on overworld
- [ ] Main menu opens with all options
- [ ] Can swap party members between active/reserve
- [ ] Can access depot through menu
- [ ] Rest service heals all party members
- [ ] Item icons visible in depot

---

## Phase 3: Modding Support

**Estimated Time:** 1-2 days
**Goal:** Total conversion mods can replace or remove caravan

### Tasks

- [ ] **3.1 Add caravan_config to mod.json parsing**
  - Support `caravan_data_id` override
  - Support `enabled: false` to disable caravan
  - Support custom `interior_scene_path`

- [ ] **3.2 Register CaravanData in ModLoader**
  - Add "caravan" to RESOURCE_TYPE_DIRS
  - Auto-discover from `mods/*/data/caravans/`

- [ ] **3.3 Support CaravanData override**
  - Higher priority mods can replace wagon config
  - Verify with test mod

- [ ] **3.4 Support custom services**
  - `CaravanController.register_service(id, scene)`
  - Mods can add blacksmith, promotion altar, etc.

- [ ] **3.5 Create test mod**
  - `mods/_sandbox/data/caravans/test_caravan.tres`
  - Different sprite, different follow distance
  - Verify override works

### Phase 3 Verification

- [ ] Test mod can override default caravan appearance
- [ ] Test mod can disable caravan entirely
- [ ] Custom services can be registered by mods

---

## Phase 4: Polish & Special Mechanics

**Estimated Time:** 1-2 days
**Goal:** Fanboy glee achieved

### Tasks

- [ ] **4.1 Add directional wagon sprites**
  - 4 directions: up, down, left, right
  - Animate based on movement direction

- [ ] **4.2 Add sound effects**
  - Caravan menu open: warm door chime
  - Item transfer: satisfying clink
  - Heal: calming harp arpeggio
  - Menu navigation: cursor move sounds

- [ ] **4.3 Add Caravan position to save data**
  - Store in TransitionContext
  - Restore position on load

- [ ] **4.4 Implement river crossing (optional)**
  - Special terrain type "caravan_crossing"
  - Caravan can traverse, hero alone cannot
  - Automatic ferry when approaching crossing

- [ ] **4.5 Add depot sorting options**
  - Sort by: Name, Type, Value
  - Extend filter dropdown

- [ ] **4.6 Add batch transfer operations**
  - "Store All Consumables" button
  - "Take All" for selected type

- [ ] **4.7 Visual polish**
  - Wagon idle breathing animation
  - Menu transitions (100-150ms fade)
  - Selection highlight effects

### Phase 4 Verification

- [ ] Wagon animates directionally when moving
- [ ] Sound effects play appropriately
- [ ] Caravan position persists across save/load
- [ ] Depot has sorting and batch operations
- [ ] Overall experience feels like SF2 mobile HQ

---

## Future Enhancements (Post-MVP)

These are not required for initial implementation but noted for future consideration:

- [ ] **Walkable Caravan interior scene** - NPCs you can talk to
- [ ] **Advisor NPC** - Minister Astral equivalent with contextual hints
- [ ] **Caravan Events** - Random merchants, recruitable characters
- [ ] **Multiple Caravan types** - Ship, airship, fortress for different campaigns
- [ ] **Caravan upgrade system** - Expand services over game progression
- [ ] **Pre-battle Caravan access** - Optional: access before battle starts

---

## Files Reference

### To Create

| File | Purpose | Phase |
|------|---------|-------|
| `core/resources/caravan_data.gd` | Moddable wagon resource | 1 |
| `core/systems/caravan_controller.gd` | Autoload singleton | 1 |
| `core/components/caravan_follower.gd` | Physical wagon node | 1 |
| `scenes/ui/caravan_main_menu.gd` | Hub menu UI | 2 |
| `scenes/ui/party_management_panel.gd` | Party swap UI | 2 |
| `mods/_base_game/data/caravans/default_caravan.tres` | Base config | 1 |

### To Modify

| File | Changes | Phase |
|------|---------|-------|
| `core/systems/party_manager.gd` | Add active/reserve methods | 2 |
| `core/systems/mod_loader.gd` | Add caravan_config parsing | 3 |
| `scenes/ui/caravan_depot_panel.gd` | Add item icons | 2 |
| `project.godot` | Register CaravanController autoload | 1 |

### Existing (No Changes)

| File | Status |
|------|--------|
| `core/systems/storage_manager.gd` | Complete - depot backend |
| `core/resources/map_metadata.gd` | Has caravan flags |
| `core/components/party_follower.gd` | Reference for chain pattern |

---

## Design Specifications

### CaravanData Resource Properties

```gdscript
class_name CaravanData
extends Resource

## Visual appearance
@export var wagon_sprite: Texture2D
@export var wagon_animation_frames: SpriteFrames
@export var wagon_scale: Vector2 = Vector2.ONE

## Following behavior
@export var follow_distance_tiles: int = 3
@export var follow_speed: float = 4.0
@export var use_chain_following: bool = true

## Special abilities
@export var can_cross_water: bool = true
@export var blocked_terrain_types: Array[String] = ["mountain", "forest"]

## Services available
@export var has_item_storage: bool = true
@export var has_party_management: bool = true
@export var has_rest_service: bool = true
@export var has_shop_service: bool = false

## Interior scene (optional)
@export var interior_scene_path: String = ""
```

### Caravan Main Menu Options

```
CARAVAN HEADQUARTERS
--------------------
> Party Management    -> Opens PartyManagementPanel
  Item Storage        -> Opens CaravanDepotPanel
  Rest & Heal         -> Heals all party (free)
  Exit                -> Returns to overworld
```

### Party Management Layout

```
PARTY MANAGEMENT                                    [X]
============================================================
ACTIVE PARTY (12 max)          |  RESERVES
[1] [2] [3] [4]                |  [R1] [R2]
[5] [6] [7] [8]                |  [R3] [R4]
[9] [10][11][12]               |
                               |  Selected:
[Swap] [Info]                  |  MAX Lv:3 HP:45/45
============================================================
```

---

## Improvement Over SF2

| SF2 Limitation | Our Solution | Status |
|----------------|--------------|--------|
| No depot filters | Filter dropdown | [x] Done |
| Chronological storage | Add sorting options | [ ] Phase 4 |
| One-at-a-time transfers | Batch operations | [ ] Phase 4 |
| Must walk to Caravan | Town menu depot access (optional) | [ ] Future |
| No item comparison | Stat diff on hover | [ ] Future |

---

## Success Criteria

Phase 1 Complete When:
- [ ] Caravan wagon visible and following on overworld
- [ ] Caravan hidden when entering towns/battles

Phase 2 Complete When:
- [ ] Full SF2 caravan functionality working
- [ ] Can manage party, store items, heal

Phase 3 Complete When:
- [ ] Mods can customize or replace caravan

Phase 4 Complete When:
- [ ] Justin would write a glowing blog post about it

---

## Session Log

### 2025-12-05 - Planning Session
- Deployed specialist agents (Claudius, Nerdlinger, Ears, Clauderina)
- Compiled unified intelligence briefing
- Created this implementation plan
- Identified current state vs gaps
- Established sacred cows and improvement opportunities

### Next Session
- Begin Phase 1 implementation
- Start with CaravanData resource class

---

## References

- `/home/user/dev/sparklingfarce/docs/design/sf1_vs_sf2_world_map_analysis.md`
- `/home/user/dev/sparklingfarce/scenes/ui/caravan_depot_panel.gd`
- `/home/user/dev/sparklingfarce/core/components/party_follower.gd`
- Justin's Blog: `docs/blog/2025-11-29-following-the-force.md`
