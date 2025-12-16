# The Sparkling Farce - Development Status

**Last Updated:** December 16, 2025
**Current Phase:** Phase 5 Complete — Battle System Feature-Complete

---

## Quick Status

| What's Done | What's In Progress | What's Next |
|-------------|-------------------|-------------|
| Map exploration, collision, triggers | — | — |
| Battle system (turn order, combat, AI) | | |
| Dialog system (branching, portraits) | | |
| Save/load (3-slot, mod-compatible) | | |
| Equipment system (items, effects) | | |
| Magic/spells (single + AOE targeting) | | |
| Terrain (movement costs, def/eva bonuses) | | |
| Caravan mobile HQ | | |
| Campaign progression | | |
| Promotion system | | |
| Status effects (poison, sleep, confusion, etc.) | | |

---

## Completed Phases (Summary)

### Phase 1 - Foundation (November 2025)
Grid-based movement, party followers, camera system, teleportation.

### Phase 2 - Battle System (November-December 2025)
AGI-based turn order, A* pathfinding, combat mechanics (hit/miss/crit/counter), combat animations, input flow.

### Phase 2.5 - Collision & Triggers (November 2025)
GameState story flags, MapTrigger system, TileMapLayer collision, scene transitions. **Unlocked the core gameplay loop:** Exploration -> Battle -> Victory -> Return to Map.

### Phase 3 - Dialog, Save, Party (November 2025)
Typewriter dialog with portraits, branching choices, 3-slot save system, party composition management.

### Phase 4.1 - Promotion System (December 2025)
PromotionManager, SF2-style special promotions with item-gated alternate paths, PromotionCeremony UI.

### Phase 4.4 - Caravan System (December 2025)
SF2-authentic mobile HQ with party management, depot storage, screen-stack navigation UI.

### Phase 4.5 - Campaign Progression (December 2025)
Node-graph campaign structure, chapter boundaries, animated title cards, save prompts.

---

## Recently Completed: Phase 4.3 - Magic/Spells

**Status:** Complete (December 2025)

**Delivered:**
- Spell menu UI (shows available spells, MP costs)
- Single-target and AOE spell targeting
- MP consumption and validation
- Spell effects (damage, healing, buffs)
- Class-based spell learning (ClassData.class_abilities)
- Spell XP awards (SF2-authentic)

---

## Recently Completed: Phase 4.2 - Equipment System

**Status:** Complete (December 2025)

**Delivered:**
- Equipment slot registry (weapon, ring_1, ring_2, accessory)
- EquipmentManager autoload with equip/unequip API
- ItemData extensions (equipment_slot, is_cursed, uncurse_items)
- Combat integration (weapon stats in damage/hit/crit formulas)
- Item Menu UI with item effects (heal, damage, buffs)
- PartyManager runtime save data tracking

---

## Recently Completed: Phase 5 - Status Effects

**Status:** Complete (December 16, 2025)

**Delivered:**
- StatusEffectData resource with predefined behavior types
- StatusEffectRegistry following existing registry pattern
- 11 base game status effects (poison, sleep, confusion, paralysis, etc.)
- Status spell combat overlay with animation
- Ability editor dropdown picker for status effects
- Hostile spell targeting with red highlights

---

## Upcoming Work

### Polish & Content
- Additional status effect animations
- More spell varieties

### Minor UI Polish
- ✅ Terrain panel now updates during unit movement (December 16, 2025)

---

## System Completion

| System | Status | Notes |
|--------|--------|-------|
| Map Exploration | Complete | Collision, triggers, scene transitions |
| Battle Core | Complete | Combat, status effects, animations |
| Dialog System | Complete | Branching, portraits, choices |
| Save System | Complete | 3-slot, mod-compatible |
| Party Management | Complete | Active/reserve, hero protection |
| Experience/Leveling | Complete | SF2-authentic pooled XP |
| Trigger System | Complete | Flag-based, one-shot, extensible |
| Mod System | Complete | Priority-based loading |
| Audio Manager | Complete | Music, SFX, mod-aware |
| AI System | Complete | Roles, modes, phases, items, retreat, defensive positioning |
| Equipment | Complete | Items, effects, cursed items |
| Magic/Spells | Complete | Single + AOE targeting, MP, status spells |
| Promotion | Complete | SF2-style paths |
| Caravan | Complete | SF2-authentic mobile HQ |
| Campaign | Complete | Node-graph, chapter UI |
| Status Effects | Complete | 11 effects, data-driven, combat overlay |

---

## Technical Overview

**Codebase:**
- ~690 GDScript files
- ~147,000 lines of code (excluding GUT framework)
- 1,180 automated tests
- Godot 4.5.1 stable

**Autoload Singletons (30):**
ModLoader, GameState, SaveManager, StorageManager, SceneManager, TriggerManager, PartyManager, ExperienceManager, PromotionManager, EquipmentManager, ShopManager, AudioManager, DialogManager, CinematicsManager, GridManager, TurnManager, InputManager, BattleManager, ExplorationUIManager, AIController, CampaignManager, GameJuice, CaravanController, DebugConsole, ShopController, RandomManager, SettingsManager, GameEventBus, LocalizationManager, EditorEventBus

**Design Principles:**
- "The base game is a mod" - complete engine/content separation
- Signal-driven architecture (loose coupling)
- Resource-based data (mod-friendly)
- Strict typing enforcement

---

## Known Issues

- Placeholder art throughout (by design - modder content)

---

## Recent Session (December 16, 2025)

**Status Effects System:**
- Data-driven StatusEffectData with behavior types (skip turn, DoT, stat mods, random targeting)
- StatusEffectRegistry following existing registry pattern
- 11 base game effects: poison, sleep, confusion, paralysis, slow, muddle, attack up/down, defense up/down, boost
- Combat overlay for status spells (purple flash for applied, white flash for resisted)
- Ability editor dropdown picker for status effects

**AI Combat Fixes:**
- Fixed BattleManager._spawn_units() to register units with GridManager (critical pathfinding bug)
- Fixed cautious mode to recalculate distance AFTER movement for attack decisions
- Improved defensive role to score positions for both VIP protection AND attack opportunity
- Added null safety checks for get_tree() calls in async AI code

**Infrastructure:**
- InputManagerHelpers: Extracted targeting utilities (TargetingContext, directional input, grid selection)
- Resource picker: Resolves embedded SubResources to registered equivalents by UID
- Defensive AI debug test for behavioral verification

**Content:**
- New "Confuse" status spell (range 2, 2 MP)
- "Rodent of Unusual Size" enemy character
- BASE Mage class: adjusted growth, added Confuse ability

---

## Previous Session (December 15, 2025)

**Major Changes:**
1. **Startup Coordinator** - New `scenes/startup.tscn` entry point handles opening cinematics and navigation
2. **Core Fallback Main Menu** - `scenes/ui/main_menu.tscn` works without mods
3. **SF2-Authentic Walk Animations** - Removed idle animations (walk plays continuously, 50% less art required)
4. **Core Default Tileset** - `core/defaults/tilesets/terrain_default.tres` for map creation fallback
5. **Editor Improvements** - Two-tier tab navigation, SpriteFrames bug fix
6. **Cleanup** - Removed `mods/_template/` (replaced by Create Mod wizard)

---

## Resources

- `/docs/specs/platform-specification.md` - Architecture reference
- `/docs/plans/` - Implementation plans
- `/docs/guides/` - Setup instructions
- `/docs/MOD_SYSTEM.md` - Modding guide
