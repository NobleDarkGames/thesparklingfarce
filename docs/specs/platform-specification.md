# The Sparkling Farce Platform Specification

**For AI Agents** | Godot 4.5.1 | v2.0.0

---

## Core Philosophy

**The platform is the engine. The game is a mod.**

All game content lives in `mods/`. The `core/` directory contains only platform infrastructure. Never add characters, items, battles, or any game content to `core/`.

---

## Directory Structure

```
sparklingfarce/
  core/                          # Platform code ONLY (never game content)
    mod_system/                  # ModLoader, ModRegistry, ModManifest
    resources/                   # Resource class definitions (schemas)
    systems/                     # Autoload singletons
    components/                  # Reusable node components
    registries/                  # Type registries

  mods/                          # ALL game content
    _base_game/                  # Official content (priority 0)
      mod.json                   # Manifest
      data/                      # Resources by type
        characters/, classes/, items/, abilities/
        battles/, parties/, dialogues/, cinematics/
        maps/, campaigns/, experience_configs/, terrains/
      audio/                     # Sound and music (separate from assets/)
        sfx/                     # Sound effects (.ogg, .wav, .mp3)
        music/                   # Background music
      assets/                    # Art assets
        icons/items/             # Item icons (32x32 PNG)
        icons/abilities/         # Ability icons (32x32 PNG)
      scenes/, tilesets/, triggers/
    _sandbox/                    # Dev testing (priority 100)

  scenes/                        # Engine scenes (battle UI, exploration, tests)
  tests/                         # gdUnit4 tests
  addons/                        # gdUnit4, sparkling_editor
```

---

## Code Standards (MANDATORY)

### Strict Typing
```gdscript
# CORRECT
var speed: float = 5.0
func calc(attacker: UnitStats, defender: UnitStats) -> int:

# WRONG - rejected by project settings
var speed = 5.0
func calc(attacker, defender):
```

### No Walrus Operator
```gdscript
# CORRECT
var result: int = calculate()

# WRONG
var result := calculate()
```

### Dictionary Key Checks
```gdscript
# CORRECT
if "key" in dict:

# WRONG
if dict.has("key"):
```

### Warning Levels (project.godot)
- `untyped_declaration`: Error
- `infer_on_variant`: Error
- `unsafe_*`: Warning

---

## Autoload Singletons

### Infrastructure
| Singleton | Purpose |
|-----------|---------|
| **ModLoader** | Mod discovery, registry access |
| **GameState** | Story flags, trigger tracking |
| **SaveManager** | Save/load operations |
| **SceneManager** | Scene transitions |

### Battle
| Singleton | Purpose |
|-----------|---------|
| **BattleManager** | Battle orchestration |
| **GridManager** | A* pathfinding, tile occupancy |
| **TurnManager** | AGI-based turn order |
| **InputManager** | Battle input state machine |
| **AIController** | Enemy AI execution |

### Content
| Singleton | Purpose |
|-----------|---------|
| **PartyManager** | Party composition, item transfers |
| **StorageManager** | Caravan depot (shared item storage) |
| **EquipmentManager** | Equipment slot management |
| **ExperienceManager** | XP distribution, level-up |
| **PromotionManager** | Class promotion |
| **DialogManager** | Dialog state machine |
| **CinematicsManager** | Cutscene execution |
| **CampaignManager** | Campaign progression |
| **CaravanController** | Caravan HQ lifecycle, party/item services |
| **TriggerManager** | Map trigger routing |
| **AudioManager** | Music, SFX |
| **GameJuice** | Screen shake, effects |

### Exploration UI
| Singleton | Purpose |
|-----------|---------|
| **ExplorationUIManager** | Auto-activating inventory/equipment UI |

ExplorationUIManager automatically provides inventory UI for any exploration map:
- Activates when scene has a node in `"hero"` group
- Deactivates during battles
- No setup required by map creators

### Static Utility (NOT an autoload)
| Class | Purpose |
|-------|---------|
| **CombatCalculator** | Pure static damage/hit/crit formulas |

Usage: `CombatCalculator.calculate_physical_damage(attacker, defender)`

---

## Mod System

### Manifest (mod.json)
```json
{
  "id": "my_mod",
  "name": "My Mod",
  "version": "1.0.0",
  "load_priority": 500,
  "dependencies": ["base_game"],
  "custom_types": {
    "weapon_types": ["laser"],
    "trigger_types": ["puzzle"]
  },
  "hidden_campaigns": ["base_game:*"]
}
```

- `hidden_campaigns`: Array of campaign ID patterns to hide (supports wildcards)

### Load Priority
| Range | Purpose |
|-------|---------|
| 0-99 | Official core (`_base_game` = 0) |
| 100-8999 | User mods (`_sandbox` = 100) |
| 9000-9999 | Total conversions |

Higher priority overrides same-ID resources from lower priority.

### Resource Discovery

ModLoader scans `mods/*/data/<directory>/` automatically:

| Directory | Type | Format |
|-----------|------|--------|
| characters/ | character | .tres |
| classes/ | class | .tres |
| items/ | item | .tres |
| abilities/ | ability | .tres |
| battles/ | battle | .tres |
| parties/ | party | .tres |
| dialogues/ | dialogue | .tres |
| cinematics/ | cinematic | .json |
| maps/ | map | .json |
| campaigns/ | campaign | .json |
| experience_configs/ | experience_config | .tres |
| terrains/ | terrain | .tres |

### Accessing Resources
```gdscript
# Get single resource
var char: CharacterData = ModLoader.registry.get_resource("character", "max")

# Get all of a type
var battles: Array[Resource] = ModLoader.registry.get_all_resources("battle")

# Check existence
if ModLoader.registry.has_resource("item", "healing_herb"):
    pass
```

### Type Registries
Mods can extend enum-like values via mod.json:
```gdscript
ModLoader.trigger_type_registry.is_valid_trigger_type("puzzle")
ModLoader.unit_category_registry.get_all_categories()
```

### Equipment Type Registry
Maps equipment subtypes (sword, bow, ring) to categories (weapon, accessory). Enables slot wildcards and mod-extensible equipment systems.

**mod.json configuration:**
```json
{
  "equipment_types": {
    "categories": {
      "weapon": {"display_name": "Weapon"},
      "accessory": {"display_name": "Accessory"}
    },
    "subtypes": {
      "sword": {"category": "weapon", "display_name": "Sword"},
      "laser_rifle": {"category": "weapon", "display_name": "Laser Rifle"},
      "ring": {"category": "accessory", "display_name": "Ring"}
    }
  }
}
```

**Category wildcards:** Slots and classes can use `weapon:*` to match ANY weapon subtype:
```json
{"id": "weapon", "display_name": "Weapon", "accepts_types": ["weapon:*"]}
```

**Total conversions:** Use `"replace_all": true` to clear all base equipment types before registering new ones.

**API:**
```gdscript
ModLoader.equipment_type_registry.get_category("sword")  # Returns "weapon"
ModLoader.equipment_type_registry.matches_accept_type("bow", "weapon:*")  # Returns true
ModLoader.equipment_type_registry.get_subtypes_for_category("weapon")  # Returns ["sword", "bow", ...]
ModLoader.equipment_type_registry.is_valid_subtype("sword")  # Returns true
```

### TileSet Resolution
```gdscript
var tileset: TileSet = ModLoader.get_tileset("terrain_placeholder")
```

### Namespaced Story Flags
```gdscript
GameState.set_mod_namespace("my_mod")
GameState.set_flag_scoped("boss_defeated")  # Sets "my_mod:boss_defeated"
GameState.has_flag_scoped("boss_defeated")
```

---

## Resource Types (Key Fields)

### CharacterData
- `character_name`, `character_uid`: Identity
- `character_class`: ClassData reference
- `is_hero`: One per game
- `is_default_party_member`: Include in starting party
- `unit_category`: "hero", "ally", "enemy", "npc"
- `base_hp/mp/str/def/agi/int/luck`: Stats
- `portrait`, `battle_sprite`: Visuals

### ClassData
- `display_name`, `movement_type`, `movement_range`
- `counter_rate`: 3, 6, 12, or 25%
- `*_growth`: Stat growth rates (0-100%)
- `equippable_weapon_types`: Array[String]
- `promotion_class`, `promotion_level`: Standard path
- `special_promotion_class`, `special_promotion_item`: SF2-style alternate

### BattleData
- `battle_name`, `map_scene`
- `player_spawn_point`: Vector2i
- `enemies`: Array[Dictionary] with character, position, ai_brain
- `victory_condition`, `defeat_condition`
- `pre_battle_dialogue`, `victory_dialogue`

### ItemData
- `item_name`, `item_type`: WEAPON, ARMOR, CONSUMABLE, KEY_ITEM
- `equipment_type`: "sword", "axe", etc.
- `attack_power`, `attack_range`
- `*_modifier`: Stat modifiers
- `icon`: Texture2D (32x32 PNG recommended, stored in `assets/icons/items/`)

### AbilityData
- `ability_name`, `ability_type`
- `target_type`, `min_range/max_range`, `area_of_effect`
- `mp_cost/hp_cost`, `power`

### DialogueData
- `dialogue_id`, `lines`, `choices`
- Line format: `{speaker_name, text, emotion, portrait}`

### CinematicData
- `cinematic_id`, `commands`
- Commands: move_entity, show_dialog, camera_move, wait, fade_screen, etc.

### MapMetadata (JSON)
- `map_id`, `display_name`, `scene_path`
- `map_type`: town, overworld, dungeon, battle, interior
- `spawn_points`: Dictionary of named positions

### CampaignData (JSON)
- `campaign_id`, `campaign_name`
- `starting_node_id`, `nodes`

### ExperienceConfig
- `base_xp`, `level_difference_table`: XP curve settings
- `promotion_level`, `xp_reset_on_promotion`: Promotion behavior
- `enable_formation_xp`, `formation_radius`: Formation bonuses
- `spam_threshold_*`, `spam_*_multiplier`: Anti-grinding protection

### TerrainData
- `terrain_name`, `terrain_type`
- `movement_cost_*`: Per-movement-type costs
- `defense_modifier`, `evasion_modifier`: Combat bonuses
- `blocks_movement`, `blocks_los`: Pathing restrictions

---

## Key Patterns

### Registry Access (REQUIRED)
```gdscript
# CORRECT
var char: CharacterData = ModLoader.registry.get_resource("character", "max")

# WRONG - breaks mod override
var char = load("res://mods/_base_game/data/characters/max.tres")
```

### Signal-Driven Architecture
```gdscript
# CORRECT
BattleManager.battle_ended.connect(_on_battle_ended)

# WRONG
BattleManager._internal_method()
```

### Defensive Null Checks
```gdscript
if not resource:
    push_error("Required resource is null")
    return
```

### Resource Validation
```gdscript
func validate() -> bool:
    if required_field.is_empty():
        push_error("ResourceType: required_field is required")
        return false
    return true
```

---

## Quick Reference

### Adding Content
1. Create resource in `mods/_base_game/data/<type>/` or `mods/_sandbox/data/<type>/`
2. Auto-discovered by ModLoader
3. Access via `ModLoader.registry.get_resource(type, id)`

### Adding New Resource Types
1. Create Resource class in `core/resources/my_type_data.gd`
2. Add mapping to `ModLoader.RESOURCE_TYPE_DIRS`
3. Auto-discovered from `mods/*/data/<type_dir>/`

### File Locations
| Purpose | Path |
|---------|------|
| Mod manifest | `mods/<mod_id>/mod.json` |
| Characters | `mods/<mod_id>/data/characters/*.tres` |
| Classes | `mods/<mod_id>/data/classes/*.tres` |
| Items | `mods/<mod_id>/data/items/*.tres` |
| Abilities | `mods/<mod_id>/data/abilities/*.tres` |
| Battles | `mods/<mod_id>/data/battles/*.tres` |
| Terrains | `mods/<mod_id>/data/terrains/*.tres` |
| XP Config | `mods/<mod_id>/data/experience_configs/*.tres` |
| Maps | `mods/<mod_id>/data/maps/*.json` |
| Campaigns | `mods/<mod_id>/data/campaigns/*.json` |
| Dialogues | `mods/<mod_id>/data/dialogues/*.tres` |
| Cinematics | `mods/<mod_id>/data/cinematics/*.json` |
| TileSets | `mods/<mod_id>/tilesets/*.tres` |
| Item Icons | `mods/<mod_id>/assets/icons/items/*.png` |
| Ability Icons | `mods/<mod_id>/assets/icons/abilities/*.png` |
| Sound Effects | `mods/<mod_id>/audio/sfx/*.ogg` |
| Music | `mods/<mod_id>/audio/music/*.ogg` |

### Common Mistakes
- Putting content in `core/` instead of `mods/`
- Hardcoding resource paths instead of using registry
- Using `dict.has()` instead of `"key" in dict`
- Using walrus operator (`:=`)
- Missing explicit types

---

## Map Types

| Type | Scale | Caravan | Battles |
|------|-------|---------|---------|
| Town | 1:1 | No | No |
| Overworld | Abstract | Yes | Yes |
| Dungeon | Mixed | Maybe | Yes |
| Battle | Grid | No | Yes |
| Interior | 1:1 | No | No |

SF2 open-world model: free backtracking, mobile Caravan, no permanent lockouts.

---

## Save System

3 slots: `user://saves/slot_1.sav`, `slot_2.sav`, `slot_3.sav`, `slots.meta`

```gdscript
SaveManager.save_game(slot_number)
SaveManager.load_game(slot_number)
if SaveManager.has_save_data(slot_number):
    var meta: Dictionary = SaveManager.get_slot_metadata(slot_number)
```

Hero (`is_hero = true`) always at party position 0, cannot be removed.

### SaveData Fields
| Field | Type | Purpose |
|-------|------|---------|
| `depot_items` | Array[String] | Caravan depot contents (item IDs) |
| `party_members` | Array[CharacterData] | Current party |
| `story_flags` | Dictionary | Triggered story flags |

---

## Inventory & Equipment System

### Exploration UI (Automatic)
Press **I** during exploration to open Party Equipment menu:
- Tab between party members
- 4 equipment slots: Weapon, Ring 1, Ring 2, Accessory
- 4 inventory slots per character
- "Give to..." transfers items between characters
- "Store in Depot" sends items to Caravan

### Caravan Depot (SF2-Style)
Unlimited shared storage accessible from the equipment menu:
```gdscript
StorageManager.add_to_depot("healing_seed")
StorageManager.remove_from_depot("bronze_sword")
var items: Array[String] = StorageManager.get_depot_contents()
```

### Item Transfers
```gdscript
# Between party members
PartyManager.transfer_item_between_members(from_char, to_char, item_id)

# To/from depot
StorageManager.add_to_depot(item_id)
StorageManager.remove_from_depot(item_id)
```

### Input Actions
| Action | Default Key | Context |
|--------|-------------|---------|
| `sf_confirm` | Enter, Space, Z | Interact, confirm |
| `sf_cancel` | Escape, X | Cancel, close menu |
| `sf_inventory` | I | Open equipment menu |

---

*Live long and ship quality code.*
