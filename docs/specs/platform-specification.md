# The Sparkling Farce Platform Specification

**For AI Agents** | Godot 4.5.1 | v3.0.0

*IMPORTANT* When writingt to this file, remember that is it intended to be read by AI agents, not humans, so keep the data minimal, relevant, and structured for AI consumption

---

## Quick Reference

| Category | Location |
|----------|----------|
| Platform code | `core/` |
| Game content | `mods/` |
| Base game | `mods/_base_game/` |
| Dev testing | `mods/_sandbox/` |
| Tests | `tests/` |
| Editor addon | `addons/sparkling_editor/` |

---

## Core Philosophy

**The platform is the engine. The game is a mod.**

All game content lives in `mods/`. The `core/` directory contains only platform infrastructure. Never add characters, items, battles, or any game content to `core/`.

---

## Directory Structure

```
sparklingfarce/
  core/                          # Platform code ONLY
    mod_system/                  # ModLoader, ModRegistry, ModManifest
    resources/                   # Resource class definitions
    systems/                     # Autoload singletons
    components/                  # Reusable node components
    registries/                  # Type registries
    scenes/                      # Base scenes (battle)
    templates/                   # Map templates

  mods/                          # ALL game content
    _base_game/                  # Official content (priority 0)
      mod.json                   # Manifest
      data/                      # Resources by type
        characters/, classes/, items/, abilities/
        battles/, parties/, dialogues/, cinematics/
        maps/, campaigns/, experience_configs/, terrain/
        caravans/, npcs/, shops/
      ai_brains/                 # AI behavior scripts
      audio/                     # Sound and music
        sfx/                     # Sound effects (.ogg, .wav)
        music/                   # Background music
      assets/                    # Art assets
        icons/items/             # Item icons (32x32 PNG)
        icons/abilities/         # Ability icons (32x32 PNG)
      scenes/, tilesets/, triggers/
    _sandbox/                    # Dev testing (priority 100)

  scenes/                        # Engine scenes (UI, exploration, tests)
  tests/                         # gdUnit4 tests
  addons/                        # gdUnit4, sparkling_editor
```

---

## Dogfood Rule
We have builtan advaced game editor in Godot plugin form, a complete cinemtatic and dialog system, and comprehensive UI patterns.  When generating code, ALWAYS look for existing components in the infrastructure that can/should be used before writing from scratch.  


## Code Standards

### Strict Typing (MANDATORY)
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

### Infrastructure (Load Order Critical)
| Singleton | File | Status | Purpose |
|-----------|------|--------|---------|
| ModLoader | `core/mod_system/mod_loader.gd` | Implemented | Mod discovery, registry, type registries |
| GameState | `core/systems/game_state.gd` | Implemented | Story flags, trigger tracking, namespaced flags |
| SaveManager | `core/systems/save_manager.gd` | Implemented | Save/load, slot management, current save |
| StorageManager | `core/systems/storage_manager.gd` | Implemented | Caravan depot (shared item storage) |
| SceneManager | `core/systems/scene_manager.gd` | Implemented | Scene transitions |
| TriggerManager | `core/systems/trigger_manager.gd` | Implemented | Map trigger routing |

### Party and Equipment
| Singleton | File | Status | Purpose |
|-----------|------|--------|---------|
| PartyManager | `core/systems/party_manager.gd` | Implemented | Party composition, item transfers |
| EquipmentManager | `core/systems/equipment_manager.gd` | Implemented | Equipment slot management, cursed items |
| ExperienceManager | `core/systems/experience_manager.gd` | Implemented | XP distribution, level-up, catch-up mechanics |
| PromotionManager | `core/systems/promotion_manager.gd` | Implemented | Class promotion, special promotions |
| ShopManager | `core/systems/shop_manager.gd` | Implemented | Buy/sell transactions, church services |

### Battle
| Singleton | File | Status | Purpose |
|-----------|------|--------|---------|
| BattleManager | `core/systems/battle_manager.gd` | Implemented | Battle orchestration |
| GridManager | `core/systems/grid_manager.gd` | Implemented | A* pathfinding, tile occupancy, terrain |
| TurnManager | `core/systems/turn_manager.gd` | Implemented | AGI-based turn order |
| InputManager | `core/systems/input_manager.gd` | Implemented | Battle input state machine |
| AIController | `core/systems/ai_controller.gd` | Implemented | Enemy AI execution |

### Content and Narrative
| Singleton | File | Status | Purpose |
|-----------|------|--------|---------|
| DialogManager | `core/systems/dialog_manager.gd` | Implemented | Dialog state machine |
| CinematicsManager | `core/systems/cinematics_manager.gd` | Implemented | Cutscene execution |
| CampaignManager | `core/systems/campaign_manager.gd` | Implemented | Campaign progression |
| CaravanController | `core/systems/caravan_controller.gd` | Implemented | Caravan HQ lifecycle |
| AudioManager | `core/systems/audio_manager.gd` | Implemented | Music, SFX, mod-aware paths |

### UI and Effects
| Singleton | File | Status | Purpose |
|-----------|------|--------|---------|
| ExplorationUIManager | `core/systems/exploration_ui_manager.gd` | Implemented | Auto-activating inventory/equipment UI |
| GameJuice | `core/systems/game_juice.gd` | Implemented | Screen shake, effects |
| DebugConsole | `core/systems/debug_console.tscn` | Implemented | Quake-style runtime console |
| ShopInterface | `scenes/ui/shops/shop_interface.tscn` | Implemented | SF2-authentic shop UI |

### Editor (Tool Mode)
| Singleton | File | Status | Purpose |
|-----------|------|--------|---------|
| EditorEventBus | `addons/sparkling_editor/editor_event_bus.gd` | Implemented | Editor tab communication |

### Static Utility (NOT Autoloads)
| Class | File | Purpose |
|-------|------|---------|
| CombatCalculator | `core/systems/combat_calculator.gd` | Pure static damage/hit/crit formulas |

Usage: `CombatCalculator.calculate_physical_damage(attacker, defender)`

---

## Type Registries

Accessed via `ModLoader.<registry_name>`:

| Registry | File | Purpose |
|----------|------|---------|
| `equipment_registry` | `core/registries/equipment_registry.gd` | Weapon/armor type registration |
| `equipment_type_registry` | `core/registries/equipment_type_registry.gd` | Subtype-to-category mappings |
| `equipment_slot_registry` | `core/registries/equipment_slot_registry.gd` | Data-driven equipment slots |
| `environment_registry` | `core/registries/environment_registry.gd` | Weather, time-of-day types |
| `unit_category_registry` | `core/registries/unit_category_registry.gd` | Unit categories (player, enemy, etc.) |
| `animation_offset_registry` | `core/registries/animation_offset_registry.gd` | Animation phase offset types |
| `trigger_type_registry` | `core/registries/trigger_type_registry.gd` | Map trigger types, scripts |
| `terrain_registry` | `core/registries/terrain_registry.gd` | Terrain data by type |
| `ai_brain_registry` | `core/registries/ai_brain_registry.gd` | AI brain scripts with metadata |
| `tileset_registry` | `core/registries/tileset_registry.gd` | TileSet resources with metadata |
| `inventory_config` | `core/systems/inventory_config.gd` | Inventory slot configuration |

---

## Resource Types

### Discovery Mapping

ModLoader scans `mods/*/data/<directory>/` automatically:

| Directory | Type Key | Format | Resource Class |
|-----------|----------|--------|----------------|
| `characters/` | character | .tres | CharacterData |
| `classes/` | class | .tres | ClassData |
| `items/` | item | .tres | ItemData |
| `abilities/` | ability | .tres | AbilityData |
| `battles/` | battle | .tres | BattleData |
| `parties/` | party | .tres | PartyData |
| `dialogues/` | dialogue | .tres | DialogueData |
| `cinematics/` | cinematic | .json/.tres | CinematicData |
| `maps/` | map | .json | MapMetadata |
| `campaigns/` | campaign | .json | CampaignData |
| `terrain/` | terrain | .tres | TerrainData |
| `experience_configs/` | experience_config | .tres | ExperienceConfig |
| `caravans/` | caravan | .tres | CaravanData |
| `npcs/` | npc | .tres | NPCData |
| `shops/` | shop | .tres | ShopData |

### All Resource Classes

| Class | File | Status | Purpose |
|-------|------|--------|---------|
| CharacterData | `core/resources/character_data.gd` | Implemented | Character definition |
| CharacterSaveData | `core/resources/character_save_data.gd` | Implemented | Runtime character state |
| ClassData | `core/resources/class_data.gd` | Implemented | Class stats, promotions |
| ItemData | `core/resources/item_data.gd` | Implemented | Items, equipment |
| AbilityData | `core/resources/ability_data.gd` | Implemented | Spells, skills |
| BattleData | `core/resources/battle_data.gd` | Implemented | Battle configuration |
| PartyData | `core/resources/party_data.gd` | Implemented | Party templates |
| DialogueData | `core/resources/dialogue_data.gd` | Implemented | Dialog trees |
| CinematicData | `core/resources/cinematic_data.gd` | Implemented | Cutscene commands |
| CampaignData | `core/resources/campaign_data.gd` | Implemented | Campaign nodes |
| CampaignNode | `core/resources/campaign_node.gd` | Implemented | Individual campaign node |
| MapMetadata | `core/resources/map_metadata.gd` | Implemented | Map configuration |
| TerrainData | `core/resources/terrain_data.gd` | Implemented | Terrain effects |
| ExperienceConfig | `core/resources/experience_config.gd` | Implemented | XP curve, catch-up |
| CaravanData | `core/resources/caravan_data.gd` | Implemented | Caravan HQ config |
| NPCData | `core/resources/npc_data.gd` | Implemented | NPC behavior |
| ShopData | `core/resources/shop_data.gd` | Implemented | Shop inventory, pricing |
| SaveData | `core/resources/save_data.gd` | Implemented | Save file structure |
| SlotMetadata | `core/resources/slot_metadata.gd` | Implemented | Save slot preview |
| AIBrain | `core/resources/ai_brain.gd` | Implemented | AI behavior base class |
| CombatPhase | `core/resources/combat_phase.gd` | Implemented | Combat animation phase |
| CombatAnimationData | `core/resources/combat_animation_data.gd` | Implemented | Battle sprite config |
| TransitionContext | `core/resources/transition_context.gd` | Implemented | Scene transition data |
| Grid | `core/resources/grid.gd` | Implemented | Grid utilities |

### Crafting Resources (Planned)
| Class | File | Status | Purpose |
|-------|------|--------|---------|
| CrafterData | `core/resources/crafter_data.gd` | Implemented | Crafter NPC capabilities |
| CraftingRecipeData | `core/resources/crafting_recipe_data.gd` | Implemented | Recipe definitions |
| RareMaterialData | `core/resources/rare_material_data.gd` | Implemented | Crafting materials |
| MaterialSpawnData | `core/resources/material_spawn_data.gd` | Implemented | Material spawn locations |

Note: Crafting resources are defined but not yet integrated into ModLoader discovery.

---

## Components

Reusable node scripts in `core/components/`:

| Component | File | Purpose |
|-----------|------|---------|
| Unit | `unit.gd` | Battle unit with stats, movement |
| UnitStats | `unit_stats.gd` | Runtime stat calculation |
| SpawnPoint | `spawn_point.gd` | Map entry point definition |
| MapTrigger | `map_trigger.gd` | Trigger zones (doors, battles) |
| NPCNode | `npc_node.gd` | Interactable NPC entity |
| CinematicActor | `cinematic_actor.gd` | Cinematic-controllable entity |
| CaravanFollower | `caravan_follower.gd` | Caravan overworld behavior |
| ExplorationUIController | `exploration_ui_controller.gd` | Hero-based UI activation |
| AnimationPhaseOffset | `animation_phase_offset.gd` | Classic 16-bit animation desync |
| TileMapAnimationHelper | `tilemap_animation_helper.gd` | Tilemap animation utilities |

---

## Cinematic Commands

Commands available in CinematicData:

| Command | Executor | Purpose |
|---------|----------|---------|
| `dialog_line` | `dialog_executor.gd` | Show dialog with portrait |
| `move_entity` | `move_entity_executor.gd` | Move actor along path |
| `set_facing` | `set_facing_executor.gd` | Change actor facing |
| `play_animation` | `play_animation_executor.gd` | Play actor animation |
| `spawn_entity` | `spawn_entity_executor.gd` | Create entity at position |
| `despawn_entity` | `despawn_entity_executor.gd` | Remove entity |
| `camera_move` | `camera_move_executor.gd` | Pan camera to position |
| `camera_shake` | `camera_shake_executor.gd` | Screen shake effect |
| `camera_follow` | `camera_follow_executor.gd` | Camera follow target |
| `fade_screen` | `fade_screen_executor.gd` | Fade in/out |
| `wait` | `wait_executor.gd` | Pause execution |
| `set_variable` | `set_variable_executor.gd` | Set story flag |
| `play_sound` | `play_sound_executor.gd` | Play sound effect |
| `play_music` | `play_music_executor.gd` | Change background music |
| `open_shop` | `open_shop_executor.gd` | Open shop interface |

---

## Mod System

### Manifest Schema (mod.json)

```json
{
  "id": "my_mod",
  "name": "My Mod",
  "version": "1.0.0",
  "author": "Author Name",
  "description": "Mod description",
  "godot_version": "4.5",
  "load_priority": 500,
  "dependencies": ["base_game"],

  "content": {
    "data_path": "data/",
    "assets_path": "assets/"
  },

  "scenes": {
    "main_menu": "scenes/ui/main_menu.tscn"
  },

  "equipment_types": {
    "categories": {"weapon": {"display_name": "Weapon"}},
    "subtypes": {"laser": {"category": "weapon", "display_name": "Laser"}}
  },

  "equipment_slot_layout": [
    {"id": "main_hand", "display_name": "Main Hand", "accepts_types": ["weapon:*"]}
  ],

  "inventory_config": {
    "slots_per_character": 4
  },

  "ai_brains": {
    "aggressive": {
      "path": "ai_brains/ai_aggressive.gd",
      "display_name": "Aggressive",
      "description": "Always attacks nearest enemy"
    }
  },

  "tilesets": {
    "terrain": {
      "path": "tilesets/terrain.tres",
      "display_name": "Terrain Tiles"
    }
  },

  "custom_types": {
    "weapon_types": ["laser"],
    "trigger_types": ["puzzle"]
  },

  "hidden_campaigns": ["base_game:*"],

  "caravan_config": {
    "enabled": true,
    "caravan_data_id": "custom_caravan"
  },

  "party_config": {
    "replaces_lower_priority": false
  }
}
```

### Load Priority
| Range | Purpose |
|-------|---------|
| 0-99 | Official core (`_base_game` = 0) |
| 100-8999 | User mods (`_sandbox` = 100) |
| 9000-9999 | Total conversions |

Higher priority overrides same-ID resources from lower priority.

### Accessing Resources
```gdscript
# Get single resource
var char: CharacterData = ModLoader.registry.get_resource("character", "max")

# Get all of a type
var battles: Array[Resource] = ModLoader.registry.get_all_resources("battle")

# Check existence
if ModLoader.registry.has_resource("item", "healing_herb"):
    pass

# Get source mod
var source: String = ModLoader.registry.get_resource_source("max")

# Get registered scene path
var menu_path: String = ModLoader.registry.get_scene_path("main_menu")
```

### TileSet Resolution
```gdscript
var tileset: TileSet = ModLoader.get_tileset("terrain_placeholder")
var path: String = ModLoader.get_tileset_path("terrain_placeholder")

# New registry API
var info: Dictionary = ModLoader.tileset_registry.get_tileset_info("terrain_placeholder")
```

### AI Brain Resolution
```gdscript
var brain: Resource = ModLoader.ai_brain_registry.get_brain_instance("aggressive")
var all_brains: Array[Dictionary] = ModLoader.ai_brain_registry.get_all_brains()
```

### Namespaced Story Flags
```gdscript
GameState.set_mod_namespace("my_mod")
GameState.set_flag_scoped("boss_defeated")  # Sets "my_mod:boss_defeated"
GameState.has_flag_scoped("boss_defeated")
```

---

## Key Resource Details

### CharacterData
- `character_name`, `character_uid`: Identity
- `character_class`: ClassData reference
- `is_hero`: One per game (always party position 0)
- `is_default_party_member`: Include in starting party
- `unit_category`: "player", "enemy", "neutral", "npc"
- `base_hp/mp/str/def/agi/int/luck`: Base stats

### ClassData
- `display_name`, `movement_type`, `movement_range`
- `counter_rate`: 3, 6, 12, or 25%
- `*_growth`: Stat growth rates (0-100%)
- `equippable_weapon_types`: Array[String]
- `promotion_class`, `promotion_level`: Standard path
- `special_promotion_class`, `special_promotion_item`: SF2-style alternate

### ItemData
- `item_name`, `item_type`: WEAPON, ARMOR, CONSUMABLE, KEY_ITEM
- `equipment_type`: Subtype ("sword", "ring", etc.)
- `attack_power`, `attack_range`
- `*_modifier`: Stat modifiers
- `buy_price`, `sell_price`: Economy
- `icon`: Texture2D

### ShopData
- `shop_id`, `shop_name`, `shop_type`: Identity
- `shop_type`: WEAPON, ITEM, CHURCH, CRAFTER, SPECIAL
- `inventory`: Array of {item_id, stock, price_override}
- `deals_inventory`: Discounted items
- `buy_multiplier`, `sell_multiplier`, `deals_discount`: Price modifiers
- `required_flags`, `forbidden_flags`: Availability gates
- Church services: `heal_cost`, `revive_base_cost`, `uncurse_base_cost`

### BattleData
- `battle_name`, `map_scene`
- `player_spawn_point`: Vector2i
- `enemies`: Array[Dictionary] with character, position, ai_brain
- `victory_condition`, `defeat_condition`
- `pre_battle_dialogue`, `victory_dialogue`

### NPCData
- `npc_id`, `npc_name`: Identity
- `interaction_cinematic_id`: Primary cinematic
- `fallback_cinematic_id`: Default if no conditions match
- `conditional_cinematics`: Array of {flag, cinematic_id, negate}

NPCs trigger cinematics, not dialogs directly. Dialog IS a cinematic command.

### ExperienceConfig
- `base_xp`, `level_difference_table`: XP curve
- `promotion_level`, `xp_reset_on_promotion`: Promotion behavior
- `formation_catch_up_rate`: Bonus XP for underleveled allies (15% per level gap)
- `support_catch_up_rate`: Bonus XP for healers supporting higher-level allies
- `spam_threshold_*`, `spam_*_multiplier`: Anti-grinding protection

---

## Save System

3 slots: `user://saves/slot_1.sav`, `slot_2.sav`, `slot_3.sav`, `slots.meta`

```gdscript
SaveManager.save_game(slot_number)
SaveManager.load_game(slot_number)
if SaveManager.has_save_data(slot_number):
    var meta: Dictionary = SaveManager.get_slot_metadata(slot_number)

# Gold management
SaveManager.get_current_gold()
SaveManager.set_current_gold(amount)
SaveManager.add_current_gold(amount)
```

### SaveData Fields
| Field | Type | Purpose |
|-------|------|---------|
| `gold` | int | Party currency |
| `depot_items` | Array[String] | Caravan storage (item IDs) |
| `party_members` | Array[CharacterData] | Current party |
| `story_flags` | Dictionary | Triggered flags |
| `current_location` | String | Last map |
| `play_time_seconds` | float | Total play time |

---

## Map Types

| Type | Scale | Caravan | Encounters | Party Visible |
|------|-------|---------|------------|---------------|
| TOWN | 1:1 | Hidden | No | Yes (chain) |
| OVERWORLD | Abstract | Visible | Yes | Hidden |
| DUNGEON | Mixed | Optional | Yes | Yes |
| INTERIOR | 1:1 | Hidden | No | Yes |
| BATTLE | Grid | No | N/A | N/A |

SF2 open-world model: free backtracking, mobile Caravan, no permanent lockouts.

---

## Debug Console

Toggle: **F1**, **F12**, or **~** (tilde). Close: **ESC**.

### Command Namespaces
| Namespace | Commands |
|-----------|----------|
| `hero.*` | `gold`, `give_gold`, `set_gold`, `set_level`, `heal`, `give_item` |
| `party.*` | `grant_xp`, `add`, `remove`, `list`, `heal_all` |
| `campaign.*` | `set_flag`, `clear_flag`, `list_flags`, `trigger` |
| `battle.*` | `win`, `lose`, `spawn`, `kill` |
| `debug.*` | `clear`, `fps`, `reload_mods`, `scene`, `create_test_save`, `save_info` |

### Mod Extension API
```gdscript
DebugConsole.register_command("weather", _cmd_weather, "Set weather: weather <type>", "my_mod")
DebugConsole.unregister_mod_commands("my_mod")
```

Callback signature: `func(args: Array) -> String`

---

## Input Actions

| Action | Default Key | Context |
|--------|-------------|---------|
| `sf_confirm` | Enter, Space, Z | Interact, confirm |
| `sf_cancel` | Escape, X | Cancel, close |
| `sf_inventory` | I | Open equipment menu |
| `toggle_debug_console` | F1, F12, ~ | Toggle console |

---

## Editor Addon

`addons/sparkling_editor/` provides in-editor tools:

### Editors Available
| Editor | File | Purpose |
|--------|------|---------|
| Character Editor | `character_editor.gd` | Edit CharacterData |
| Class Editor | `class_editor.gd` | Edit ClassData |
| Item Editor | `item_editor.gd` | Edit ItemData |
| Ability Editor | `ability_editor.gd` | Edit AbilityData |
| Battle Editor | `battle_editor.gd` | Edit BattleData |
| Dialogue Editor | `dialogue_editor.gd` | Edit DialogueData |
| Cinematic Editor | `cinematic_editor.gd` | Edit CinematicData |
| Campaign Editor | `campaign_editor.gd` | Edit CampaignData |
| Terrain Editor | `terrain_editor.gd` | Edit TerrainData |
| Map Metadata Editor | `map_metadata_editor.gd` | Edit MapMetadata |
| Party Editor | `party_editor.gd` | Edit PartyData |
| NPC Editor | `npc_editor.gd` | Edit NPCData |
| Shop Editor | `shop_editor.gd` | Edit ShopData |
| Save Slot Editor | `save_slot_editor.gd` | Debug save files |
| Mod JSON Editor | `mod_json_editor.gd` | Edit mod.json |

### EditorEventBus Signals
```gdscript
EditorEventBus.resource_saved.emit(type, id, resource)
EditorEventBus.resource_created.emit(type, id, resource)
EditorEventBus.resource_deleted.emit(type, id)
EditorEventBus.active_mod_changed.emit(mod_id)
EditorEventBus.mods_reloaded.emit()
```

---

## Test Structure

Tests use gdUnit4 in `tests/`:

```
tests/
  unit/
    combat/           # CombatCalculator tests
    crafting/         # Crafting resource tests
    equipment/        # Equipment system tests
    storage/          # StorageManager tests
    promotion/        # PromotionManager tests
    experience/       # ExperienceManager tests
    campaign/         # CampaignData tests
    map/              # Map metadata tests
    audio/            # AudioManager tests
    shop/             # Shop system tests
    mod_system/       # Registry, flags tests
    editor/           # Editor component tests
    registries/       # AI brain, tileset tests
  integration/
    battle/           # Full battle flow tests
```

---

## File Locations Reference

| Purpose | Path Pattern |
|---------|--------------|
| Mod manifest | `mods/<mod_id>/mod.json` |
| Characters | `mods/<mod_id>/data/characters/*.tres` |
| Classes | `mods/<mod_id>/data/classes/*.tres` |
| Items | `mods/<mod_id>/data/items/*.tres` |
| Abilities | `mods/<mod_id>/data/abilities/*.tres` |
| Battles | `mods/<mod_id>/data/battles/*.tres` |
| Terrain | `mods/<mod_id>/data/terrain/*.tres` |
| XP Config | `mods/<mod_id>/data/experience_configs/*.tres` |
| Caravans | `mods/<mod_id>/data/caravans/*.tres` |
| NPCs | `mods/<mod_id>/data/npcs/*.tres` |
| Shops | `mods/<mod_id>/data/shops/*.tres` |
| Map Metadata | `mods/<mod_id>/data/maps/*.json` |
| Map Scenes | `mods/<mod_id>/maps/*.tscn` |
| Campaigns | `mods/<mod_id>/data/campaigns/*.json` |
| Dialogues | `mods/<mod_id>/data/dialogues/*.tres` |
| Cinematics | `mods/<mod_id>/data/cinematics/*.json` |
| TileSets | `mods/<mod_id>/tilesets/*.tres` |
| AI Brains | `mods/<mod_id>/ai_brains/ai_*.gd` |
| Triggers | `mods/<mod_id>/triggers/*_trigger.gd` |
| Item Icons | `mods/<mod_id>/assets/icons/items/*.png` |
| Sound Effects | `mods/<mod_id>/audio/sfx/*.ogg` |
| Music | `mods/<mod_id>/audio/music/*.ogg` |

---

## Common Patterns

### Adding New Content
1. Create resource in `mods/_base_game/data/<type>/`
2. Auto-discovered by ModLoader
3. Access via `ModLoader.registry.get_resource(type, id)`

### Adding New Resource Types
1. Create Resource class in `core/resources/my_type_data.gd`
2. Add mapping to `ModLoader.RESOURCE_TYPE_DIRS`
3. Auto-discovered from `mods/*/data/<type_dir>/`

### Registry Access (REQUIRED)
```gdscript
# CORRECT
var char: CharacterData = ModLoader.registry.get_resource("character", "max")

# WRONG - breaks mod override
var char = load("res://mods/_base_game/data/characters/max.tres")
```

### Common Mistakes
- Putting content in `core/` instead of `mods/`
- Hardcoding resource paths instead of using registry
- Using `dict.has()` instead of `"key" in dict`
- Using walrus operator (`:=`)
- Missing explicit types

---

## Implementation Status Key

- Implemented: Fully functional, tested
- Partial: Core functionality works, some features missing
- Planned: Designed but not yet implemented
- Deprecated: Scheduled for removal

---

*Live long and ship quality code.*
