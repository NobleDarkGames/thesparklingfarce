# The Sparkling Farce Platform Specification

**For AI Agents** | Godot 4.5.1 | v4.0.0

---

## Core Philosophy

**The platform is the engine. The game is a mod.**

- All game content lives in `mods/` — never in `core/`
- `core/` contains only platform infrastructure
- The base game (`mods/_base_game/`) uses the same systems as third-party mods
- Higher-priority mods override same-ID resources from lower-priority mods

---

## Directory Structure

```
core/                    # Platform code ONLY
  mod_system/            # ModLoader, ModRegistry
  resources/             # Resource class definitions
  systems/               # Autoload singletons
  components/            # Reusable node components
  registries/            # Type registries

mods/                    # ALL game content
  _base_game/            # Official content (priority 0)
    mod.json             # Manifest
    data/                # Resources: characters/, classes/, items/, abilities/,
                         #   battles/, parties/, dialogues/, cinematics/, maps/,
                         #   campaigns/, terrain/, npcs/, shops/, caravans/
    ai_brains/           # AI behavior scripts
    assets/              # Art, icons
    audio/sfx/, music/   # Sound
    tilesets/            # TileSet resources
  _sandbox/              # Dev testing (priority 100)

scenes/                  # Engine scenes (UI, exploration)
tests/                   # gdUnit4 tests
addons/                  # gdUnit4, sparkling_editor
```

---

## Code Standards (MANDATORY)

| Rule | Correct | Wrong |
|------|---------|-------|
| Strict typing | `var speed: float = 5.0` | `var speed = 5.0` |
| No walrus operator | `var x: int = calc()` | `var x := calc()` |
| Dictionary key checks | `if "key" in dict:` | `if dict.has("key"):` |

Project settings enforce: `untyped_declaration` = Error, `infer_on_variant` = Error

---

## Autoload Singletons

### Infrastructure
| Singleton | Purpose |
|-----------|---------|
| ModLoader | Mod discovery, registry access, type registries |
| GameState | Story flags, trigger tracking |
| SaveManager | Save/load, gold management |
| StorageManager | Caravan depot (shared item storage) |
| SceneManager | Scene transitions |
| TriggerManager | Map trigger routing |

### Party & Equipment
| Singleton | Purpose |
|-----------|---------|
| PartyManager | Party composition, item transfers |
| EquipmentManager | Equipment slots, cursed items |
| ExperienceManager | XP distribution, level-up |
| PromotionManager | Class promotion |
| ShopManager | Buy/sell, church services |

### Battle
| Singleton | Purpose |
|-----------|---------|
| BattleManager | Battle orchestration |
| GridManager | A* pathfinding, tile occupancy, terrain |
| TurnManager | AGI-based turn order |
| InputManager | Battle input state machine |
| AIController | Enemy AI execution |

### Content & Narrative
| Singleton | Purpose |
|-----------|---------|
| DialogManager | Dialog state machine |
| CinematicsManager | Cutscene execution |
| CampaignManager | Campaign progression |
| CaravanController | Caravan HQ lifecycle |
| AudioManager | Music, SFX |

### UI
| Singleton | Purpose |
|-----------|---------|
| ExplorationUIManager | Auto-activating exploration UI |
| GameJuice | Screen shake, effects |
| DebugConsole | Runtime console (F1/F12/~) |

### Static Utility (NOT Autoload)
| Class | Purpose |
|-------|---------|
| CombatCalculator | Pure static damage/hit/crit formulas |

---

## Resource Types

ModLoader auto-discovers from `mods/*/data/<directory>/`:

| Directory | Type Key | Class |
|-----------|----------|-------|
| characters/ | character | CharacterData |
| classes/ | class | ClassData |
| items/ | item | ItemData |
| abilities/ | ability | AbilityData |
| battles/ | battle | BattleData |
| parties/ | party | PartyData |
| dialogues/ | dialogue | DialogueData |
| cinematics/ | cinematic | CinematicData |
| maps/ | map | MapMetadata |
| campaigns/ | campaign | CampaignData |
| terrain/ | terrain | TerrainData |
| npcs/ | npc | NPCData |
| shops/ | shop | ShopData |
| caravans/ | caravan | CaravanData |
| experience_configs/ | experience_config | ExperienceConfig |
| new_game_configs/ | new_game_config | NewGameConfigData |

---

## Type Registries

Accessed via `ModLoader.<registry_name>`:

| Registry | Purpose |
|----------|---------|
| equipment_registry | Weapon/armor type registration |
| equipment_type_registry | Subtype-to-category mappings |
| equipment_slot_registry | Data-driven equipment slots |
| terrain_registry | Terrain data by type |
| ai_brain_registry | AI brain scripts |
| tileset_registry | TileSet resources |
| trigger_type_registry | Map trigger types |

---

## Mod System

### Load Priority
| Range | Purpose |
|-------|---------|
| 0-99 | Official core (`_base_game` = 0) |
| 100-8999 | User mods (`_sandbox` = 100) |
| 9000-9999 | Total conversions |

### Registry Access (REQUIRED PATTERN)
```gdscript
# CORRECT - always use registry
var char: CharacterData = ModLoader.registry.get_resource("character", "max")
var battles: Array[Resource] = ModLoader.registry.get_all_resources("battle")
if ModLoader.registry.has_resource("item", "healing_herb"):
    pass

# WRONG - breaks mod override system
var char = load("res://mods/_base_game/data/characters/max.tres")
```

---

## Map Architecture

**SF2 open-world model:** Free backtracking, mobile Caravan, no permanent lockouts.

| Type | Scale | Caravan | Encounters |
|------|-------|---------|------------|
| TOWN | 1:1 | Hidden | No |
| OVERWORLD | Abstract | Visible | Yes |
| DUNGEON | Mixed | Optional | Yes |
| INTERIOR | 1:1 | Hidden | No |
| BATTLE | Grid | No | N/A |

---

## Spell System

**Spells are CLASS-BASED** (SF2 design):
- Primary source: `ClassData.class_abilities`
- Level gating: `ClassData.ability_unlock_levels`
- Rare exceptions: `CharacterData.unique_abilities`

---

## Modal UI Input Blocking (CRITICAL)

Godot's `_unhandled_input()` does NOT block `Input.is_action_pressed()` polling.

**When creating modal UI, add checks to:**
1. `ExplorationUIController.is_blocking_input()`
2. `HeroController._is_modal_ui_active()` (defense-in-depth)
3. `DebugConsole._is_other_modal_active()`

**Existing modal checks:** `DebugConsole.is_open`, `ShopManager.is_shop_open()`, `DialogManager.is_dialog_active()`, `ExplorationUIController.current_state != EXPLORING`

---

## Dogfood Rule

We have built an advanced game editor, complete cinematic/dialog system, and comprehensive UI patterns. **Always look for existing infrastructure before writing from scratch.**

Key UI patterns in `scenes/ui/`:
- `components/modal_screen_base.gd` — Base class for modal screen-stack UIs
- `shops/` — SF2-authentic shop interface
- `caravan/` — SF2-authentic depot interface
- `exploration_field_menu.tscn` — SF2-style field menu

---

## Debug Console

Toggle: **F1**, **F12**, or **~**

| Namespace | Example Commands |
|-----------|------------------|
| hero.* | gold, give_gold, set_level, heal, give_item |
| party.* | grant_xp, add, remove, list, heal_all |
| campaign.* | set_flag, clear_flag, list_flags |
| battle.* | win, lose, spawn, kill |
| debug.* | clear, fps, reload_mods, scene |

---

## Common Mistakes

| Mistake | Correct Approach |
|---------|------------------|
| Content in `core/` | Put in `mods/_base_game/data/` |
| Hardcoded resource paths | Use `ModLoader.registry.get_resource()` |
| `dict.has("key")` | `if "key" in dict:` |
| Walrus operator `:=` | Explicit type annotation |
| Missing explicit types | Add type to all declarations |
| Modal UI without input blocking | Add to blocking checks (see above) |

---

*Live long and ship quality code.*
