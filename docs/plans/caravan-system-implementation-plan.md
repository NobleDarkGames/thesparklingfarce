# Caravan System Implementation Plan

**Created:** 2025-12-05
**Status:** ✅ COMPLETE (All Phases)
**Priority:** CRITICAL (Mission Priority One)
**Last Updated:** 2025-12-08
**Completed:** 2025-12-05 (UI Refactor: 2025-12-08)

---

## Executive Summary

The Caravan system is the heart of SF2's open-world design and the critical feature that made it superior to SF1. This plan captures the unified intelligence from Commander Claudius, Mr. Nerdlinger, Lt. Ears, and Clauderina to create a Caravan system that will become the gold standard for SF-style tactical RPGs.

**Goal:** Make Justin squeal with fanboy glee.

---

## Current State Assessment

### PHASE 1 COMPLETE (Committed: 812d82f)

- [x] **CaravanData resource** (`core/resources/caravan_data.gd`) - Moddable wagon config
- [x] **CaravanController autoload** (`core/systems/caravan_controller.gd`) - Lifecycle management
- [x] **CaravanFollower component** (`core/components/caravan_follower.gd`) - Breadcrumb following
- [x] **Default caravan config** (`mods/_base_game/data/caravans/default_caravan.tres`)
- [x] **Placeholder wagon sprite** (`mods/_base_game/assets/sprites/caravan_wagon.png`)
- [x] **SF2-authentic visibility** - Party followers in towns, caravan on overworld
- [x] **MapMetadata integration** - Caravan spawns when `caravan_visible=true`

### PHASE 2 COMPLETE (Committed: f39feec)

- [x] **CaravanMainMenu UI** (`scenes/ui/caravan_main_menu.gd`) - Party/Items/Rest/Exit
- [x] **Interaction trigger** - Press sf_confirm when near caravan opens menu
- [x] **Items option** - Wired to existing CaravanDepotPanel via ExplorationUIManager
- [x] **Menu centering fix** - Panel now properly centered using PRESET_FULL_RECT + child anchoring
- [x] **Input isolation fix** - Game pauses while menu open (PROCESS_MODE_ALWAYS on UI)
- [x] **Party Management Panel** - `scenes/ui/party_management_panel.gd` with grid UI
- [x] **PartyManager roster methods** - `get_active_party()`, `get_reserve_party()`, `swap_active_reserve()`, etc.
- [x] **Rest & Heal** - Fully implemented (disabled in base game per Sacred Cow #3, available for mods)

### PHASE 3 COMPLETE (Committed: c58c95d)

- [x] **Mod override of caravan data** - Higher priority mods can replace wagon config
- [x] **Rest service enabled via override** - Test mod enables rest service
- [x] **Custom services registration** - Mods can add custom menu options
- [x] **Caravan disable via config** - Mods can set `enabled: false`
- [x] **19 automated tests passing** - Comprehensive modding support verification

### PHASE 4 COMPLETE (Committed: see below)

- [x] **Directional wagon sprites** - 4 directions supported via CaravanFollower
- [x] **Sound effects** - Menu open/select/cancel/hover/error sounds
- [x] **Save/load integration** - Caravan position in TransitionContext
- [x] **Depot sorting options** - Sort by Name, Type, Value
- [x] **Batch transfer operations** - Store All, Take All buttons
- [x] **Visual polish** - Menu fade transitions (150ms)

### TECHNICAL DEBT FIXES (Committed: 36e5e85)

- [x] **Data-driven menu options** - CaravanMainMenu queries CaravanController
- [x] **Custom service handler** - Mod-provided services load dynamically
- [x] **PartyManager encapsulation** - Added swap_within_active/reserve methods
- [x] **Duplicate item selection bug** - Fixed via slot index binding
- [x] **User feedback for inaccessible caravan** - Sound + floating notification
- [x] **Standardized null-checking** - Consistent autoload guards

### UI REFACTOR (Committed: 2681900, December 8, 2025)

Complete refactor to use shared ModalScreenBase architecture (matching Shop UI):

- [x] **ModalScreenBase** - Shared base class for screen-stack modal UIs (`scenes/ui/components/modal_screen_base.gd`)
- [x] **CaravanScreenBase** - Caravan-specific extension with depot/inventory helpers
- [x] **CaravanInterfaceController** - CanvasLayer-based screen stack manager
- [x] **CaravanContext** - Session state container (filter, sort, selections)
- [x] **SF2-authentic UX** - "Selection = action" pattern (minimal confirmations)
- [x] **Equipment warnings** - Warns when giving equipment to incompatible characters
- [x] **Font standardization** - All fonts use 16/24px Monogram pixel font sizes
- [x] **Auto-focus management** - Proper gamepad/keyboard navigation

**New Screens:**
- `action_select` - Choose TAKE or STORE mode
- `depot_browser` - Browse depot items with L/R filter cycling
- `char_select` - Select character (immediate action in TAKE mode)
- `char_inventory` - Browse character inventory, store items

**Key Files:**
- `scenes/ui/caravan/caravan_interface.tscn` - Main interface scene
- `scenes/ui/caravan/caravan_interface_controller.gd` - Screen stack manager
- `scenes/ui/caravan/caravan_context.gd` - Session state
- `scenes/ui/caravan/screens/*.gd` - Individual screen implementations

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

### Phase 1 Verification ✅

- [x] Caravan wagon visible on overworld test map
- [x] Caravan follows hero using chain pattern
- [x] Caravan disappears when entering town
- [x] Caravan reappears when exiting town

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

### Phase 2 Verification ✅

- [x] Can interact with Caravan on overworld
- [x] Main menu opens with all options
- [x] Can swap party members between active/reserve
- [x] Can access depot through menu
- [x] Rest service heals all party members
- [x] Item icons visible in depot

---

## Phase 3: Modding Support

**Estimated Time:** 1-2 days
**Goal:** Total conversion mods can replace or remove caravan

### Tasks

- [x] **3.1 Add caravan_config to mod.json parsing**
  - Added `caravan_config` to ModManifest with fields: `enabled`, `caravan_data_id`, `custom_services`
  - CaravanController reads from mod manifests in priority order

- [x] **3.2 Register CaravanData in ModLoader**
  - Already registered in RESOURCE_TYPE_DIRS as "caravans" -> "caravan"
  - Auto-discovers from `mods/*/data/caravans/`

- [x] **3.3 Support CaravanData override**
  - Higher priority mods override via `caravan_data_id` in mod.json
  - CaravanController._load_caravan_config() iterates mods by priority

- [x] **3.4 Support custom services**
  - `_custom_services` dict in CaravanController
  - `_register_custom_service()` parses from mod's caravan_config.custom_services
  - Format: `{service_id: {scene_path: String, display_name: String}}`

- [x] **3.5 Create test mod**
  - Created `mods/_sandbox/data/caravans/test_caravan.tres`
  - Settings: has_rest_service=true, wagon_scale=1.5, follow_distance=2, speed=128
  - Added caravan_config to _sandbox/mod.json pointing to test_caravan

### Phase 3 Verification ✅

- [x] Test mod can override default caravan appearance (Rest should be enabled)
- [x] Test mod can disable caravan entirely (set enabled: false)
- [x] Custom services can be registered by mods
- [x] 19 automated tests verify all modding scenarios

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

### Phase 4 Verification ✅

- [x] Wagon animates directionally when moving
- [x] Sound effects play appropriately
- [x] Caravan position persists across save/load
- [x] Depot has sorting and batch operations
- [x] Overall experience feels like SF2 mobile HQ

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

## Success Criteria ✅ ALL MET

Phase 1 Complete When:
- [x] Caravan wagon visible and following on overworld
- [x] Caravan hidden when entering towns/battles

Phase 2 Complete When:
- [x] Full SF2 caravan functionality working
- [x] Can manage party, store items, heal

Phase 3 Complete When:
- [x] Mods can customize or replace caravan

Phase 4 Complete When:
- [x] Justin would write a glowing blog post about it

---

## Session Log

### 2025-12-05 - Planning Session
- Deployed specialist agents (Claudius, Nerdlinger, Ears, Clauderina)
- Compiled unified intelligence briefing
- Created this implementation plan
- Identified current state vs gaps
- Established sacred cows and improvement opportunities

### 2025-12-05 - Implementation Sessions
- Phase 1: CaravanData, CaravanController, CaravanFollower (Commit: 812d82f)
- Phase 2: Party management, depot access, rest service, bug fixes (Commit: f39feec)
- Phase 3: Modding support infrastructure, 19 tests passing (Commit: c58c95d)
- Phase 4: Polish, sorting, batch ops, sound effects, transitions (Commit: see git log)
- Technical Debt: Data-driven menus, encapsulation fixes, bug fixes (Commit: 36e5e85)

### Completion
- All phases complete
- 76+ unit tests passing
- Reviewed by Modro (mod architect) and O'Brien (chief engineer)
- Technical debt addressed proactively

### 2025-12-08 - UI Refactor Session
- Unified Shop and Caravan UI with shared ModalScreenBase pattern
- Created screen-stack navigation system (CaravanInterfaceController)
- Implemented SF2-authentic "selection = action" flow
- Added equipment compatibility warnings for TAKE operations
- Standardized all fonts to 16/24px Monogram pixel font
- Removed unnecessary confirmation steps
- Reviewed by Clauderina (UI/UX)

---

## References

- `/home/user/dev/sparklingfarce/docs/design/sf1_vs_sf2_world_map_analysis.md`
- `/home/user/dev/sparklingfarce/scenes/ui/caravan_depot_panel.gd`
- `/home/user/dev/sparklingfarce/core/components/party_follower.gd`
- Justin's Blog: `docs/blog/2025-11-29-following-the-force.md`
