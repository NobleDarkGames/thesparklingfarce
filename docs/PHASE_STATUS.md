# The Sparkling Farce - Development Phase Status

**Last Updated:** December 5, 2025
**Current Phase:** Phase 4 - Core Mechanics (Equipment, Magic, Items) 🚧

---

## Overview

The Sparkling Farce is a tactical RPG platform inspired by Shining Force, built in Godot 4.5. Development follows a phased approach with each phase thoroughly tested before proceeding.

---

## Phase Completion Status

### ✅ Phase 1 - Foundation & Map Exploration (COMPLETE)

**Status:** Production Ready
**Completion Date:** November 2025

**Deliverables:**
- Grid-based hero movement with smooth interpolation
- Party follower system (breadcrumb trail following)
- Camera system with smooth following
- Position history tracking (20 positions)
- Teleportation system for scene transitions
- Test scenes (playable and headless)

**Key Files:**
- `scenes/map_exploration/hero_controller.gd`
- `scenes/map_exploration/party_follower.gd`
- `scenes/map_exploration/map_camera.gd`

---

### ✅ Phase 2 - Battle System Polish (70% COMPLETE)

**Status:** Functional, needs UI polish
**Completion Date:** Ongoing

**Completed:**
- AGI-based turn order (Shining Force II formula)
- Grid-based movement with A* pathfinding
- Combat mechanics (hit/miss/crit/counterattack)
- Combat animation system (full-screen)
- Movement and attack range visualization
- Input system with Shining Force-authentic flow

**Remaining:**
- Floating damage/XP numbers
- Level-up screen UI
- Victory/defeat screens with rewards
- Magic/spell system (Phase 4)
- Item usage (Phase 4)
- Equipment system (Phase 4)

---

### ✅ Phase 3 - Dialog, Save, Party Systems (COMPLETE)

**Status:** Production Ready
**Completion Date:** November 2025

**Phase 3.1 - Dialog Foundation:**
- Typewriter text effect with punctuation pauses
- Dialog box positioning (top/bottom/center)
- State machine architecture
- Mod-based dialog discovery

**Phase 3.2 - Dialog Visual Polish:**
- Character portraits (64x64) with slide-in animations
- Multiple expressions per character
- Smooth transitions

**Phase 3.3 - Choice & Branching:**
- Yes/No choices
- Multi-option selections (2-4 choices)
- Branch flow to other DialogData resources

**Phase 3.4 - Save System:**
- 3-slot save system (Shining Force style)
- JSON-based saves with validation
- Mod compatibility tracking
- Character progression persistence
- Campaign progress tracking

**Phase 3.5 - Party Management:**
- Party composition storage
- Hero character protection
- Battle spawn data generation
- Save/load integration

---

### ✅ Phase 2.5 - Collision & Trigger System (COMPLETE)

**Status:** Production Ready
**Completion Date:** November 25, 2025
**Commit:** `f8fc551`

**Critical Infrastructure Milestone**

This phase addresses the critical gap preventing campaign creation by implementing collision detection and trigger systems.

**Core Systems:**
- **GameState Autoload** - Story flags, trigger tracking, campaign data
- **MapTrigger Base Class** - Extensible Area2D-based triggers
- **Collision Detection** - TileMapLayer physics integration
- **16px Tile System** - Proper TileSet configuration

**Deliverables:**
- Story flag system (set_flag, has_flag, clear_flag)
- Trigger completion tracking (one-shot functionality)
- MapTrigger with conditional activation (required/forbidden flags)
- Hero collision with TileMapLayer
- Placeholder tileset (6x 16x16 tiles: grass, wall, water, road, door, battle)
- TileSet resources (terrain_placeholder, interaction_placeholder)
- Battle trigger template scene
- Test map with collision and working trigger
- Comprehensive documentation (970 lines)

**Testing Verified:**
- ✅ Hero collision detection (blocks walls/water, allows grass/road)
- ✅ Hero centers on tiles (16px grid alignment)
- ✅ Party followers correct size
- ✅ Battle trigger activates on entry
- ✅ Trigger sends battle_id correctly
- ✅ One-shot functionality works
- ✅ Story flags operational

**What This Unlocks:**
- Working explore → battle → explore loop foundation
- Extensible trigger system for all interaction types
- Story flag system for branching narratives
- Platform for campaign creation

**Key Files:**
- `core/systems/game_state.gd` (150 lines)
- `core/components/map_trigger.gd` (186 lines)
- `mods/_base_game/art/tilesets/placeholder/` (6 tiles + README)
- `mods/_base_game/tilesets/` (2 TileSet resources)
- `mods/_base_game/triggers/battle_trigger.tscn`
- `mods/_base_game/maps/test/collision_test_001.tscn`
- `docs/plans/phase-2.5-collision-triggers-plan.md` (520 lines)
- `docs/guides/phase-2.5-setup-instructions.md` (450 lines)

---

## Upcoming Phases

### 🔜 Phase 2.5.1 - Mod Extensibility Improvements (PLANNED)

**Priority:** Medium
**Dependencies:** Phase 2.5 complete ✅
**Target:** Before Phase 4 (Equipment/Magic/Items)

**Strategic Context:**
This phase addresses 4 critical mod system integration gaps identified by Modro's comprehensive review of Phase 2.5. While the current implementation is functional for base game development, these improvements are essential for supporting total conversion mods and third-party content creators.

**Critical Issues to Address:**

1. **ModLoader Cannot Discover Triggers**
   - Impact: Modders cannot add new trigger types without editing core code
   - Solution: Extend ModLoader to scan and register triggers from `mods/*/triggers/`

2. **TriggerType Enum Cannot Be Extended**
   - Impact: Total conversion mods stuck with base game's trigger types
   - Solution: String-based type system with mod registration

3. **GameState Flag Namespace Collision**
   - Impact: Mod A can accidentally overwrite Mod B's story flags
   - Solution: Namespaced flags like `"mod_name:flag_name"`

4. **Hardcoded TileSet Paths**
   - Impact: Replacing base tilesets requires editing scene files
   - Solution: ModLoader provides tileset resolution by logical name

**Expected Improvements:**
- Moddability score: 6.5/10 → 8.5/10+
- Trigger extensibility: Hardcoded enum → Fully dynamic
- Flag isolation: None → Namespace protected
- Asset override: Manual editing → Declarative (mod.json)

**Estimated Effort:** 8-12 hours

**Detailed Plan:** See `/docs/plans/phase-2.5.1-mod-extensibility-plan.md`

---

### ✅ Phase 2.5.2 - Scene Transition System (COMPLETE)

**Status:** Production Ready
**Completion Date:** November 2025

**Implemented:**
- TriggerManager stores return scene path and hero grid position in TransitionContext
- BattleManager returns to exploration map after battle completion
- Hero position restored to exact grid coordinates via `hero.teleport_to_grid()`
- Hero facing direction preserved and restored
- Trigger marked complete prevents re-activation (one-shot battles work)
- SceneManager handles fade transitions between scenes

**Key Files:**
- `core/systems/trigger_manager.gd` - Battle trigger handling, return_to_map()
- `core/systems/game_state.gd` - TransitionContext storage
- `core/resources/transition_context.gd` - Return data encapsulation
- `mods/_base_game/maps/templates/map_template.gd` - Hero restoration on scene load

**The Core Gameplay Loop is COMPLETE:**
`Exploration → Battle Trigger → Battle Scene → Victory → Return to Map → Resume Exploration`

---

### 🔜 Phase 2.5.3 - Extended Trigger Types

**Priority:** Medium
**Dependencies:** Phase 2.5.2

**Scope:**
- Dialog triggers (NPC conversations)
- Chest triggers (item rewards, one-shot)
- Door triggers (scene transitions, key checks)
- Cutscene triggers (story events)

**Estimated Effort:** 8-12 hours

---

### 🚧 Phase 4.1 - Promotion System (COMPLETE)

**Status:** Core Complete
**Completion Date:** December 2, 2025

**Implemented:**
- PromotionManager autoload singleton
- ClassData extensions: `special_promotion_class`, `special_promotion_item`, `promotion_level`
- CharacterSaveData extensions: `cumulative_level`, `promotion_count`, `current_class_mod_id/resource_id`
- PromotionCeremony UI scene (full-screen transformation celebration)
- SF2-style special promotions (item-gated alternate paths)

**Remaining:**
- PartyManager persistence integration for promoted classes
- Unit.apply_promotion() method

---

### 🚧 Phase 4.2 - Equipment System (IN PROGRESS)

**Status:** 95% Complete - Core Infrastructure Done
**Started:** December 2, 2025

**Implemented (Staged, Not Committed):**

1. **Core Data Structures:**
   - `core/registries/equipment_slot_registry.gd` - Data-driven slot system (weapon, ring_1, ring_2, accessory)
   - `core/systems/equipment_slot.gd` - Convenience constants
   - `core/systems/inventory_config.gd` - Configurable inventory (default 4 slots)
   - `core/systems/equipment_manager.gd` - Autoload with equip/unequip API and signals

2. **Resource Modifications:**
   - `ItemData` - Added `equipment_slot`, `is_cursed`, `uncurse_items`; removed `durability`
   - `CharacterSaveData` - Added `inventory: Array[String]`, updated `equipped_items` format with `curse_broken`
   - `CharacterData` - Added `starting_inventory: Array[String]` for initial character items
   - `ModManifest` - Parses `equipment_slot_layout` and `inventory_config` from mod.json

3. **Combat Integration:**
   - `UnitStats` - Equipment cache, weapon stat accessors (`get_weapon_attack_power()`, etc.)
   - `CombatCalculator` - Weapon stats integrated into damage/hit/crit formulas
   - `Unit` - `refresh_equipment_cache()` method

4. **Party Manager Runtime Save Data:**
   - `PartyManager._member_save_data` - Dictionary tracking CharacterSaveData by character_uid
   - `PartyManager.get_member_save_data(uid)` - Retrieves character's inventory/equipment state
   - `PartyManager.update_member_save_data(uid, data)` - Updates character state
   - Auto-creation of save data when characters join party

5. **Item Menu:**
   - `scenes/ui/item_menu.gd` and `.tscn` - Full UI implementation
   - `InputManager` - Added `SELECTING_ITEM` state
   - `BattleManager` - Connected to item signals
   - `base_battle_scene.gd` - Wires up item menu

6. **Test Items (in mods/_sandbox/data/items/):**
   - `healing_herb.tres` - Consumable with `usable_in_battle: true`
   - `medical_herb.tres` - Consumable with `usable_in_battle: true`
   - `antidote.tres` - Consumable with `usable_in_battle: true`

**✅ BUG FIXED: Item Menu Infrastructure (December 3, 2025)**

Root causes identified and fixed:
1. ✅ `PartyManager.get_member_save_data()` - Implemented
2. ✅ Items with `usable_in_battle: true` - Created (3 test items)
3. ✅ Characters with starting inventory - Added `starting_inventory` field to CharacterData
4. ✅ CharacterSaveData copies starting inventory - Updated `populate_from_character_data()`

**Test Results:** 76 tests passing (3 new item menu integration tests added)

**Remaining Work:**
- Manual testing of item menu in actual battle
- Item effect execution (using items to heal, cure status, etc.)
- Equipment stat bonuses display in UI

**Key Files (All Staged):**
- `scenes/ui/item_menu.gd` - Item menu script
- `core/systems/party_manager.gd` - Added runtime save data tracking
- `core/systems/input_manager.gd` - Modified for SELECTING_ITEM state
- `core/systems/equipment_manager.gd` - New autoload
- `core/registries/equipment_slot_registry.gd` - New registry
- `core/resources/character_data.gd` - Added starting_inventory field
- `core/resources/character_save_data.gd` - Copies starting_inventory

---

### ✅ Phase 4.4 - Caravan System (COMPLETE)

**Status:** Production Ready
**Completion Date:** December 5, 2025

**SF2-Authentic Mobile HQ Implementation:**

The Caravan system provides the signature Shining Force 2 mobile headquarters experience, following the player on overworld maps and offering essential services.

**Core Systems:**
- **CaravanController Autoload** - Central lifecycle management, service delegation
- **CaravanMainMenu** - Data-driven service menu (dynamically queries available services)
- **Party Management Panel** - Active/reserve party swap with hero protection
- **Caravan Depot Panel** - Unlimited shared storage with inventory integration
- **Overworld Caravan Scene** - Visible wagon sprite that follows hero

**Key Features:**
- SF2-authentic "Check on soldiers" menu flow
- Active party (12 max) / Reserve party split
- Depot storage (unlimited, saved/loaded with game)
- Custom service registration for mod extensibility
- Accessibility feedback when caravan unavailable

**Key Files:**
- `core/systems/caravan_controller.gd` - Autoload singleton
- `scenes/ui/caravan_main_menu.gd` - Service menu
- `scenes/ui/party_management_panel.gd` - Party UI
- `scenes/ui/caravan_depot_panel.gd` - Storage UI
- `scenes/map_exploration/overworld_caravan.gd` - Visual sprite

**Detailed Plan:** See `/docs/plans/caravan-system-implementation-plan.md`

---

### ✅ Phase 4.5 - Campaign Progression (COMPLETE)

**Status:** Production Ready
**Completion Date:** December 5, 2025

**Campaign System for Story-Driven Gameplay:**

The Campaign system manages story progression through a node-graph structure, tracking chapter boundaries, handling transitions, and providing UI for chapter title cards and save prompts.

**Core Systems:**
- **CampaignManager Autoload** - Node graph traversal, chapter tracking
- **CampaignData Resource** - JSON-based campaign definitions
- **ChapterTransitionUI** - Animated title cards and save prompts

**Key Features:**
- Node-graph campaign structure (battles, dialogues, cinematics, choices)
- Chapter boundary detection with save prompts
- Animated chapter title cards (fade in/hold/fade out)
- Progress persistence via SaveManager integration
- Error recovery for missing nodes/resources

**Key Files:**
- `core/systems/campaign_manager.gd` - Campaign orchestration
- `core/resources/campaign_data.gd` - Campaign schema
- `scenes/ui/chapter_transition_ui.gd` - Chapter UI

**Detailed Plan:** See `/docs/plans/campaign_progression_plan.md`

---

### 🔜 Phase 4.3 - Magic/Spells

**Priority:** High
**Dependencies:** Phase 4.2 complete

**Scope:**
- Magic/spell targeting and effects
- Spell animations
- MP consumption

**Estimated Effort:** 20-30 hours

---

### 🔜 Phase 5 - Advanced Features

**Priority:** Low
**Dependencies:** Phase 4 complete

**Scope:**
- Advanced AI behaviors (defensive, support, boss patterns)
- Status effects (poison, sleep, paralysis)
- Terrain effects (movement costs, defense bonuses)
- Character relationships and support conversations
- Promotion system
- New Game+

**Estimated Effort:** 80-120 hours

---

## System Completion Overview

| System | Status | Phase | Notes |
|--------|--------|-------|-------|
| Map Exploration | ✅ Complete | 1, 2.5 | Collision & triggers working |
| Battle Core | 🟡 85% | 2 | Magic & items remaining |
| Dialog System | ✅ Complete | 3 | Branching, portraits, choices |
| Save System | ✅ Complete | 3 | 3-slot, mod-compatible |
| Party Management | ✅ Complete | 3 | Composition, hero protection |
| Experience/Leveling | ✅ Complete | 2 | SF2-authentic pooled XP, participation |
| Collision Detection | ✅ Complete | 2.5 | TileMapLayer integration |
| Trigger System | ✅ Complete | 2.5 | Flag-based, one-shot, extensible |
| Story Flags | ✅ Complete | 2.5 | GameState tracking |
| Mod System | ✅ Complete | 1 | Priority-based loading |
| Audio Manager | ✅ Complete | 1 | Music, SFX, mod-aware, init from ModLoader |
| AI System | 🟡 30% | 2 | Only 2 basic behaviors |
| Equipment | 🟡 80% | 4.2 | Core done, Item Menu working |
| Magic/Spells | ⬜ 0% | 4.3 | Not started |
| Items/Inventory | 🟡 60% | 4.2 | Item Menu functional, effects pending |
| Promotion | ✅ Complete | 4.1 | Core done, CharacterData immutable |
| Caravan System | ✅ Complete | 4.4 | SF2-authentic mobile HQ |
| Campaign System | ✅ Complete | 4.5 | Node-graph progression, chapter UI |
| UI Systems | 🟡 70% | 2, 3 | Battle screen polished, pixel-perfect effects |

---

## Technical Metrics

**Current Stats (as of Phase 2.5 completion):**

- **Code Quality:** 100% strict typing, 0 critical issues
- **GDScript Files:** ~70 files
- **Core Systems:** ~5,000 lines of code
- **Documentation:** ~3,500 lines
- **Test Coverage:** Manual testing, headless tests for key systems
- **Godot Version:** 4.5.1 stable
- **Platform:** Linux (primary), cross-platform compatible

**Recent Commits:**
- Phase 2.5: +1,561 insertions, 27 files changed
- Phase 3: +2,000 insertions (dialog, save, party)
- Phase 2: +3,500 insertions (battle system)
- Phase 1: +2,500 insertions (map exploration)

---

## Architecture Highlights

**Design Principles:**
- "The base game is a mod" - Complete engine/content separation
- Signal-driven architecture (loose coupling)
- Resource-based data (mod-friendly)
- Strict typing enforcement (project settings)
- Defensive programming (turn session IDs, validation)

**Autoload Singletons (17 total):**
1. ModLoader - Mod discovery and loading
2. GameState - Story flags and trigger tracking
3. SaveManager - Save/load operations
4. SceneManager - Scene transitions
5. PartyManager - Party composition
6. StorageManager - Caravan depot storage
7. ExperienceManager - XP and leveling
8. AudioManager - Sound/music
9. DialogManager - Dialog state machine
10. CinematicsManager - Cutscene execution
11. CampaignManager - Campaign progression
12. CaravanController - Caravan HQ lifecycle (Phase 4.4)
13. GridManager - Pathfinding and grid state
14. TurnManager - Turn order
15. InputManager - Player input
16. BattleManager - Battle orchestration
17. AIController - Enemy AI

**Resource Types (10 total):**
- CharacterData, ClassData, ItemData, AbilityData
- BattleData, DialogueData, PartyData
- Grid, SaveData, ExperienceConfig

---

## Blockers & Known Issues

**No Active Blockers**

**Minor Issues:**
- Map exploration party following uses "snake" pattern (works but could be improved to formation-based)
- Placeholder art needs replacement (by design - modder content)
- No persistent dialog flags across scenes (Phase 3 limitation)
- Item effect execution not yet implemented (items show in menu but USE action needs work)

---

## Next Milestone

**Target:** Complete Phase 4 Core Mechanics (Magic, Items, Retreat)
**Goal:** Finish remaining SF-defining systems for a complete tactical RPG experience

**Success Criteria:**
- ✅ Equipment system with stat bonuses and class restrictions
- Magic/spell system with MP, targeting, and area effects
- Item/inventory system with consumables (USE action effects)
- ✅ Caravan mobile HQ for party management (SF2 signature feature)
- ✅ Campaign progression with chapter UI
- Retreat/resurrection system (units don't permadeath)

---

## Resources

**Documentation:**
- `/docs/plans/` - Implementation plans for each phase
- `/docs/guides/` - Setup and testing instructions
- `/scenes/map_exploration/README.md` - Map system documentation
- `/docs/MOD_SYSTEM.md` - Modding guide

**Testing:**
- `mods/_base_game/maps/test/collision_test_001.tscn` - Collision & trigger test
- `scenes/battle/test_unit.tscn` - Battle system test
- Dialog test scenes in `mods/_sandbox/`

---

**Phase Status Last Updated:** December 5, 2025 by Lt. Clauderina & Crew

**Session Notes (December 5, 2025):**
- Completed Caravan System (Phase 4.4) - SF2-authentic mobile HQ with party management and depot
- Completed Campaign Progression (Phase 4.5) - node-graph progression with chapter UI
- Fixed Caravan technical debt: data-driven menus, PartyManager encapsulation, depot selection bug
- Added ChapterTransitionUI for animated chapter title cards and save prompts
- Added CaravanController autoload singleton
- Documentation updated: platform-specification.md, PHASE_STATUS.md, caravan-system-implementation-plan.md

**Recent Commits:**
- `c58c95d` - feat: Implement Caravan Phase 3 - Modding support infrastructure
- `f39feec` - feat: Complete Caravan Phase 2 - Rest service and bug fixes
- `80c0731` - feat: Implement Caravan Phase 2 - Party Management and menu fixes
- `812d82f` - feat: Implement Caravan system Phase 1 - SF2-authentic mobile HQ

**Previous Session Notes (December 4, 2025):**
- Replaced all UI zoom/scale effects with pixel-perfect alternatives (brightness flashes, slides)
- Fixed AudioManager initialization - now receives mod path from ModLoader at startup
- Added menu_select.ogg sound effect to pre-game menus (main menu, save slot selector)
- Created `docs/modding/audio-sfx-reference.md` - comprehensive SFX guide for modders

**Previous Session Notes (December 2-3, 2025):**
- Implemented Equipment System (Phase 4.2) - equipment slots, cursed items, inventory config
- Implemented Item Menu UI - visual display bug fixed
- Full code review completed (103 files, 35,726 LOC, 77 fixes)
