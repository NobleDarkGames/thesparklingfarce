# The Sparkling Farce - Development Status

**Last Updated:** December 18, 2025
**Current Phase:** Phase 5.2 Complete — Editor & Tooling Feature-Complete

---

## Quick Status

| What's Done | What's In Progress | What's Next |
|-------------|-------------------|-------------|
| Map exploration, collision, triggers | — | — |
| Battle system (turn order, combat, AI) | | |
| Dialog system (branching, portraits, interpolation) | | |
| Save/load (3-slot, mod-compatible) | | |
| Equipment system (items, effects) | | |
| Magic/spells (single + AOE targeting) | | |
| Terrain (movement costs, def/eva bonuses) | | |
| Caravan mobile HQ | | |
| Campaign progression | | |
| Promotion system | | |
| Status effects (poison, sleep, confusion, etc.) | | |
| Cinematic party management (recruit/remove/rejoin) | | |
| NPC conditional dialogs (AND/OR flag logic) | | |
| Crafting system (crafter NPCs, recipes) | | |
| Sparkling Editor (20/20 editors, 100% coverage) | | |
| External choice support (dialog/campaign integration) | | |

---

## Completed Phases (Summary)

### Phase 1 - Foundation (November 2025)
Grid-based movement, party followers, camera system, teleportation.

### Phase 2 - Battle System (November-December 2025)
AGI-based turn order, A* pathfinding, combat mechanics (hit/miss/crit/counter), combat animations, input flow.

### Phase 2.5 - Collision & Triggers (November 2025)
GameState story flags, MapTrigger system, TileMapLayer collision, scene transitions. **Unlocked the core gameplay loop:** Exploration -> Battle -> Victory -> Return to Map. Full loop validated through manual playtesting including both victory and defeat paths (with resurrection system).

### Phase 3 - Dialog, Save, Party (November 2025)
Typewriter dialog with portraits, branching choices, 3-slot save system, party composition management.

### Phase 4.1 - Promotion System (December 2025)
PromotionManager, SF2-style special promotions with item-gated alternate paths, PromotionCeremony UI.

### Phase 4.4 - Caravan System (December 2025)
SF2-authentic mobile HQ with party management, depot storage, screen-stack navigation UI.

### Phase 4.5 - Campaign Progression (December 2025)
Node-graph campaign structure, chapter boundaries, animated title cards, save prompts.

---

## Recently Completed: Phase 5.2 - Editor & Tooling (December 18, 2025)

**Status:** Complete

**Delivered:**
- **Sparkling Editor 100% Resource Coverage** (20 visual editors):
  - New: Status Effect Editor (triggers, stat modifiers, DoT, action modifiers)
  - New: Experience Config Editor (combat XP, leveling, promotion bonuses, adjutant system)
  - New: Caravan Editor (appearance, following behavior, terrain, services, audio)
  - Crafting Tab consolidates Crafter + Recipe editors
  - Removed: Armor system (SF2 had weapon + rings only), Party Template editor (redundant)
- **Create New Mod Wizard**: Now scaffolds all 20 resource directories
- **Integration Test Infrastructure**:
  - EditorScript for manual stress testing (tools/editor_scripts/)
  - GUT integration tests for CI (tests/integration/editor/)
  - Comprehensive stress test report
- **SF2 Authenticity Refactor**: Removed armor, streamlined editors (-1,300 lines)

**Editor Tab Organization (Two-Tier):**
| Category | Editors |
|----------|---------|
| Content | Characters, Classes, Abilities, Items, Status Effects |
| Battles | Maps, Terrain, Battles, AI Behaviors |
| Story | NPCs, Cinematics, Campaigns, Shops, Crafting |
| System | Overview, Mod Settings, New Game Configs, Save Slots, Caravans, Experience |

---

## Recently Completed: Phase 5.1.5 - External Choice & Crafter Systems

**Status:** Complete (December 17, 2025)

**Delivered:**
- **External Choice Support**: DialogManager integration with CampaignManager for branching storylines
- **Crafter NPC System**:
  - New CRAFTER NPC role with auto-cinematic support
  - Recipe browser, action select, and confirm screens
  - CraftingManager autoload for crafting transactions
  - Debug command: `caravan.add_item` for testing
- **Battle Defeat Flow**: Now correctly transitions to campaign hub
- **SF2-Authentic Shop Flow**: Auto-return after transactions
- **Members UI Improvements**: Updated layout and navigation

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

## Recently Completed: Phase 5.1 - Cinematic Enhancements

**Status:** Complete (December 16, 2025)

**Delivered:**
- **Text Interpolation System**: `TextInterpolator` class with runtime variable replacement
  - Supported: `{player_name}`, `{gold}`, `{chapter}`, `{party_count}`, `{active_count}`
  - Character references: `{char:id}` (by resource ID or character_uid)
  - Story flags: `{flag:name}` returns "true"/"false"
  - Campaign data: `{var:key}` for custom variables
- **Party Management Cinematic Commands**:
  - `add_party_member`: Recruit characters with system messages
  - `remove_party_member`: Story departures with reason tracking (left, died, captured, betrayed)
  - `rejoin_party_member`: Return departed characters with resurrection support
  - `set_character_status`: Modify is_alive/is_available flags
  - All commands support custom messages with text interpolation
- **NPC Conditional Dialog Logic**: AND/OR flag combinations
  - `flags` array (AND logic): all must be true
  - `any_flags` array (OR logic): at least one must be true
  - `negate` option to invert condition results
  - Backward-compatible with legacy single `flag` key
- **Character UID System**: Auto-generated 8-character unique IDs
  - Generated in `CharacterData._init()`
  - Immutable after creation, stable across renames
  - Used by text interpolation and cinematic commands

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
| Dialog System | Complete | Branching, portraits, choices, text interpolation |
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
| Cinematic System | Complete | 19 command types, party management, text interpolation |
| NPC System | Complete | Conditional dialogs with AND/OR logic, Quick Setup roles |
| Crafting System | Complete | Crafter NPCs, recipe browser, material transformation |
| Sparkling Editor | Complete | 20/20 editors, 100% resource coverage, two-tier navigation |

---

## Technical Overview

**Codebase:**
- ~703 GDScript files
- ~154,500 lines of code (excluding GUT framework)
- ~1,155 automated tests
- Godot 4.5.1 stable

**Autoload Singletons (31):**
ModLoader, GameState, SaveManager, StorageManager, SceneManager, TriggerManager, PartyManager, ExperienceManager, PromotionManager, EquipmentManager, ShopManager, CraftingManager, AudioManager, DialogManager, CinematicsManager, GridManager, TurnManager, InputManager, BattleManager, ExplorationUIManager, AIController, CampaignManager, GameJuice, CaravanController, EditorEventBus, DebugConsole, ShopController, RandomManager, SettingsManager, GameEventBus, LocalizationManager

**Design Principles:**
- "The base game is a mod" - complete engine/content separation
- Signal-driven architecture (loose coupling)
- Resource-based data (mod-friendly)
- Strict typing enforcement

---

## Known Issues

- Placeholder art throughout (by design - modder content)

---

## Recent Session (December 18, 2025)

**Sparkling Editor 100% Coverage:**
- Three new visual editors (Status Effect, Experience Config, Caravan)
- Create New Mod Wizard now scaffolds all 20 resource directories
- Integration test infrastructure (EditorScript + GUT tests)
- Stress test report documenting findings

**SF2 Authenticity Refactor:**
- Removed armor system (SF2 had weapon + rings only)
- Deleted party_template_editor (redundant with party_editor)
- Merged Crafter + Recipe editors into unified Crafting tab
- Net reduction of ~1,300 lines

---

## Session (December 17, 2025)

**External Choice & Crafter Systems:**
- External choice support in DialogManager for CampaignManager integration
- Crafter NPC system with recipe browser UI
- Battle defeat flow now correctly transitions to campaign hub
- SF2-authentic shop flow with auto-return after transactions
- Members UI improvements (layout, navigation)

---

## Session (December 16, 2025)

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

## Session (December 15, 2025)

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
