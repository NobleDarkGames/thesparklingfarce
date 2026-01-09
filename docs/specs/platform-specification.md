# The Sparkling Farce Platform Specification

**For AI Agents** | Godot 4.5.1 | v4.5.0

---

## Core Philosophy

**The platform is the engine. The game is a mod.**

- All game content lives in `mods/` — never in `core/`
- `core/` contains only platform infrastructure
- The demo campaign (`mods/demo_campaign/`) uses the same systems as third-party mods
- Higher-priority mods override same-ID resources from lower-priority mods

---

## Directory Structure

```
core/                    # Platform code ONLY
  mod_system/            # ModLoader, ModRegistry
  resources/             # Resource class definitions
  systems/               # Autoload singleton scripts
  components/            # Reusable node components
  registries/            # Type registries (equipment, terrain, AI, etc.)
  defaults/              # Core fallback assets
    cinematics/          # opening_cinematic.json
    tilesets/            # terrain_default.tres

mods/                    # ALL game content
  demo_campaign/         # Demo content (priority 100)
    mod.json             # Manifest
    data/                # Resources by type (see Resource Types)
    assets/              # Portraits, sprites, icons
      portraits/         # 128x128 PNG portraits
      sprites/map/       # 64x128 map spritesheets
      sprites/battle/    # Combat animation frames
      icons/items/       # 16x16 or 32x32 item icons
    audio/sfx/, music/   # Sound
    maps/                # Map scene files
    tilesets/            # TileSet resources
  _starter_kit/          # Core defaults (priority 0, set as -1 in mod.json)
    data/                # AI behaviors, terrain types
    assets/              # Fallback/placeholder sprites

scenes/                  # Engine scenes
  startup.tscn           # Main entry point (coordinator)
  cinematics/            # Core cinematic stages
  map_exploration/       # Hero controller, party followers
  ui/                    # All UI scenes
    main_menu.tscn       # Core fallback main menu
    shops/               # SF2-authentic shop interface
    caravan/             # SF2-authentic depot interface
    components/          # Reusable UI components
tests/                   # Automated test suite (at project root)
addons/                  # sparkling_editor (20+ visual editors)
templates/               # Code templates
```

---

## Code Standards (MANDATORY)

| Rule | Correct | Wrong |
|------|---------|-------|
| Strict typing | `var speed: float = 5.0` | `var speed = 5.0` |
| No walrus operator | `var x: int = calc()` | `var x := calc()` |
| Dictionary key checks | `if "key" in dict:` | `if dict.has("key"):` |
| Negative key checks | `if "key" not in dict:` | `if not "key" in dict:` |
| Typed loop variables | `for item: ItemData in items:` | `for item in items:` |
| Modern signal syntax | `my_signal.emit(value)` | `emit_signal("my_signal", value)` |

Project settings enforce: `untyped_declaration` = Error, `infer_on_variant` = Error

---

## Autoload Singletons

### Infrastructure
| Singleton | Purpose |
|-----------|---------|
| ModLoader | Mod discovery, registry access, type registries, `is_loading()` status |
| GameState | Story flags, trigger tracking |
| SaveManager | Save/load, gold management |
| StorageManager | Caravan depot (shared item storage) |
| SceneManager | Scene transitions |
| TriggerManager | Map trigger routing |
| SettingsManager | User preferences |
| LocalizationManager | Internationalization |
| RandomManager | Deterministic RNG for replays |
| GameEventBus | Cross-system event dispatch |

### Party & Equipment
| Singleton | Purpose |
|-----------|---------|
| PartyManager | Party composition, item transfers |
| EquipmentManager | Equipment slots, cursed items |
| ExperienceManager | XP distribution, level-up |
| PromotionManager | Class promotion |
| ShopManager | Buy/sell logic with atomic rollback, church services |
| ShopController | Shop UI state machine |
| CraftingManager | Crafter NPC transactions, recipe validation, material counting across inventories |

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
| DialogManager | Dialog state machine, external choice routing, save/load via `export_state()`/`import_state()` |
| CinematicsManager | Cutscene execution, choice signals |
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
| InputManagerHelpers | Targeting context, directional input, grid selection utilities |

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
| interactables/ | interactable | InteractableData |
| shops/ | shop | ShopData |
| caravans/ | caravan | CaravanData |
| experience_configs/ | experience_config | ExperienceConfig |
| new_game_configs/ | new_game_config | NewGameConfigData |
| ai_behaviors/ | ai_behavior | AIBehaviorData |
| status_effects/ | status_effect | StatusEffectData |
| crafting_recipes/ | crafting_recipe | CraftingRecipeData |
| crafters/ | crafter | CrafterData |

**JSON-supported types:** cinematic, campaign, map

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
| ai_mode_registry | AI behavior modes |
| status_effect_registry | Status effect definitions |
| tileset_registry | TileSet resources |
| trigger_type_registry | Map trigger types |
| unit_category_registry | Unit type categories |
| animation_offset_registry | Sprite animation offsets |
| inventory_config | Inventory size/rules |

**All registries emit `registrations_changed` signal** when registrations are added/removed/modified. Connect to this signal for editor refresh or dynamic UI updates.

---

## Spawnable Entity System

The cinematic system supports spawning entities at runtime via a registry of handlers. Mods can register custom entity types.

### Built-in Spawnable Types

| Type | Handler | Description |
|------|---------|-------------|
| character | CharacterSpawnHandler | Characters with animated sprites |
| npc | NPCSpawnHandler | NPCs (uses character_data or own sprite_frames) |
| interactable | InteractableSpawnHandler | Static objects (chests, signs, etc.) |

### Registration (for mods)

```gdscript
# Extend SpawnableEntityHandler for custom types
class_name MyEntityHandler extends SpawnableEntityHandler

func get_type_id() -> String:
    return "my_entity"

func get_available_entities() -> Array[Dictionary]:
    # Return [{id, name, resource}, ...] for editor dropdowns
    return []

func create_sprite_node(entity_id: String, facing: String) -> Node2D:
    # Create and return the visual node
    return Sprite2D.new()

# Register in mod _ready()
CinematicsManager.register_spawnable_type(MyEntityHandler.new())
```

### Usage in Cinematics

Cinematics can spawn entities two ways:

1. **actors array** - Pre-spawn before commands execute:
```json
{
  "actors": [
    {"actor_id": "hero", "entity_type": "character", "entity_id": "max", "position": [5, 3], "facing": "down"}
  ],
  "commands": [...]
}
```

2. **spawn_entity command** - Spawn during execution:
```json
{"type": "spawn_entity", "params": {"actor_id": "chest", "entity_type": "interactable", "entity_id": "treasure_chest", "position": [7, 4]}}
```

Backward compatibility: `character_id` maps to `entity_type: "character"`.

---

## Mod System

### Load Priority
| Range | Purpose |
|-------|---------|
| 0 | Platform defaults (`_starter_kit`, clamped from -1) |
| 1-99 | Reserved for official content |
| 100-8999 | User mods, campaigns (`demo_campaign` = 100) |
| 9000-9999 | Total conversions |

### Registry Access (REQUIRED PATTERN)
```gdscript
# CORRECT - always use registry
var char: CharacterData = ModLoader.registry.get_resource("character", "max")
var battles: Array[Resource] = ModLoader.registry.get_all_resources("battle")
if ModLoader.registry.has_resource("item", "healing_herb"):
    pass

# WRONG - breaks mod override system
var char = load("res://mods/demo_campaign/data/characters/max.tres")
```

---

## Game Startup Architecture

**Entry Point:** `scenes/startup.tscn` (main_scene in project.godot)

```
startup.tscn (coordinator)
    |
    v
Wait for autoloads (ModLoader, etc.)
    |
    v
Load opening_cinematic scene:
  1. Check ModLoader.registry for mod-provided scene
  2. Fall back to core: scenes/cinematics/opening_cinematic_stage.tscn
    |
    v
Wait for CinematicsManager.cinematic_ended signal
    |
    v
Transition to main_menu:
  1. Check ModLoader.registry for mod-provided scene
  2. Fall back to core: scenes/ui/main_menu.tscn
```

**Design Principles:**
- Cinematic scenes are ONLY responsible for playing cinematics (no navigation)
- Startup coordinator owns all scene transition decisions
- Core fallbacks ensure game works even if all mods fail to load

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

## Interactable Objects

`InteractableData` defines searchable map objects (chests, bookshelves, signs, levers).

### Types

| Type | Behavior | State |
|------|----------|-------|
| CHEST | Contains items, opens when searched | One-shot |
| BOOKSHELF | Read-only text | Repeatable |
| BARREL | Searchable container | One-shot |
| SIGN | Read-only text (outdoor) | Repeatable |
| LEVER | Toggle state, triggers events | Stateful |
| CUSTOM | Mod-defined behavior | Varies |

### Key Properties

- `item_rewards`: Array of `{item_id, quantity}` dictionaries
- `gold_reward`: Gold amount
- `dialog_text`: Simple text (auto-generates cinematic)
- `interaction_cinematic_id`: Explicit cinematic to play
- `conditional_cinematics`: Flag-based branching (same format as NPCData)
- `completion_flag`: Auto-generated as `{interactable_id}_opened` if empty

---

## Battle Victory/Defeat Conditions

`BattleData` defines win/loss conditions for battles.

### Victory Conditions

| Condition | Parameters | Description |
|-----------|------------|-------------|
| DEFEAT_ALL_ENEMIES | — | All enemies defeated (default) |
| DEFEAT_BOSS | `victory_boss_index` | Kill specific enemy |
| SURVIVE_TURNS | `victory_turn_count` | Survive N turns |
| REACH_LOCATION | `victory_target_position` | Unit reaches tile |
| PROTECT_UNIT | `victory_protect_index` | Neutral survives |
| CUSTOM | `custom_victory_script` | GDScript evaluator |

### Defeat Conditions

| Condition | Parameters | Description |
|-----------|------------|-------------|
| ALL_UNITS_DEFEATED | — | Party wiped |
| LEADER_DEFEATED | — | Hero dies (default) |
| TURN_LIMIT | `defeat_turn_limit` | Exceeded N turns |
| UNIT_DIES | `defeat_protect_index` | Neutral dies |
| CUSTOM | `custom_defeat_script` | GDScript evaluator |

### Rewards

```gdscript
@export var experience_reward: int = 0
@export var gold_reward: int = 0
@export var item_rewards: Array[ItemData] = []
```

---

## Character Sprites (SF2-Authentic)

**Walk animation plays continuously** — NO separate idle animations (matches SF2, halves art requirements).

### SpriteFrames Structure
| Animation | Frames | Usage |
|-----------|--------|-------|
| walk_down | 2 | Default facing, dialog display |
| walk_up | 2 | Moving/facing up |
| walk_left | 2 | Moving/facing left |
| walk_right | 2 | Moving/facing right |

### Spritesheet Format
**64x128 pixels** (2 columns x 4 rows of 32x32 frames)

```
Row 0: walk_down  [frame0, frame1]
Row 1: walk_left  [frame0, frame1]
Row 2: walk_right [frame0, frame1]
Row 3: walk_up    [frame0, frame1]
```

### Storage
- Location: `mods/*/data/sprite_frames/<entity>_map_sprites.tres`
- Referenced by: `CharacterData.sprite_frames`, `NPCData.sprite_frames`
- Always external resources (ExtResource), never embedded

---

## Spell System

**Spells are CLASS-BASED** (SF2 design):
- Primary source: `ClassData.class_abilities`
- Level gating: `ClassData.ability_unlock_levels`
- Rare exceptions: `CharacterData.unique_abilities`

---

## Modal UI Input Blocking (CRITICAL)

Godot's `_unhandled_input()` does NOT block `Input.is_action_pressed()` polling.

**Add modal UIs to these checks:**
1. `ExplorationUIController.is_blocking_input()`
2. `HeroController._is_modal_ui_active()` (defense-in-depth)
3. `DebugConsole._is_other_modal_active()`

**Existing modal checks:** `DebugConsole.is_open`, `ShopManager.is_shop_open()`, `DialogManager.is_dialog_active()`, `ExplorationUIController.current_state != EXPLORING`

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

## Reusable Infrastructure

Key patterns to use instead of writing from scratch:

| Location | Purpose |
|----------|---------|
| `scenes/ui/components/modal_screen_base.gd` | Base class for modal screen-stack UIs |
| `scenes/ui/shops/` | SF2-authentic shop interface |
| `scenes/ui/caravan/` | SF2-authentic depot interface |
| `scenes/ui/exploration_field_menu.tscn` | SF2-style field menu |

---

## Common Mistakes

| Mistake | Correct Approach |
|---------|------------------|
| Content in `core/` | Put in `mods/demo_campaign/data/` or your mod |
| Hardcoded resource paths | Use `ModLoader.registry.get_resource()` |
| `dict.has("key")` | `if "key" in dict:` |
| `not "key" in dict` | `if "key" not in dict:` |
| Walrus operator `:=` | Explicit type annotation |
| Missing explicit types | Add type to all declarations |
| Untyped loop variables | `for item: Type in array:` |
| `emit_signal("name")` | `signal_name.emit()` |
| Modal UI without input blocking | Add to blocking checks (see above) |

---

## Key API Reference

### ModLoader

```gdscript
# Check if mods are currently being loaded (useful for startup sequencing)
if ModLoader.is_loading():
    await ModLoader.mods_loaded
```

### DialogManager Save/Load

```gdscript
# Export dialog state for save system
var dialog_state: Dictionary = DialogManager.export_state()
save_data.dialog_state = dialog_state

# Import dialog state when loading
if "dialog_state" in save_data:
    DialogManager.import_state(save_data.dialog_state)
```

### Text Interpolation

`TextInterpolator` replaces variables in dialog and cinematic text with runtime values. Applied automatically by DialogBox.

| Syntax | Result |
|--------|--------|
| `{player_name}` | Hero character's name |
| `{party_count}` | Total party size |
| `{active_count}` | Active party members |
| `{gold}` | Current gold |
| `{chapter}` | Current chapter number |
| `{char:id}` | Character name by resource ID or UID |
| `{flag:name}` | "true" or "false" |
| `{var:key}` | Campaign data value |

```gdscript
# Manual interpolation (rarely needed - DialogBox handles automatically)
var text: String = TextInterpolator.interpolate("Hello, {player_name}! You have {gold} gold.")
```

### ShopManager Atomic Transactions

Bulk buy/sell operations are atomic with automatic rollback. If any item in a multi-quantity transaction fails, all previously added/removed items are restored:

```gdscript
# Buy 5 healing herbs - if slot 3 fails, slots 1-2 are rolled back
var result: Dictionary = ShopManager.buy_item("healing_herb", 5, "caravan")
if not result.success:
    # No partial state - either all 5 succeed or none do
    print(result.error)
```

### Registry Change Notifications

```gdscript
# React to registry modifications (useful for editor plugins)
ModLoader.terrain_registry.registrations_changed.connect(_on_terrain_changed)
ModLoader.equipment_registry.registrations_changed.connect(_refresh_equipment_ui)
```

### Character UID System

Every `CharacterData` has an auto-generated `character_uid` (8 alphanumeric characters). Generated in `_init()`, immutable once created.

```gdscript
# UIDs enable stable references across renames
var char: CharacterData = ModLoader.registry.get_character_by_uid("hk7wm4np")

# Text interpolation uses UIDs
var text: String = "Thanks, {char:hk7wm4np}!"  # Resolves to character name
```

### Party Management Cinematic Commands

Four commands for story-driven party changes:

| Command | Purpose | Key Parameters |
|---------|---------|----------------|
| `add_party_member` | Recruit character | `character_id`, `to_active`, `show_message`, `custom_message` |
| `remove_party_member` | Story departure/death | `character_id`, `reason`, `mark_dead`, `mark_unavailable`, `show_message` |
| `rejoin_party_member` | Return departed member | `character_id`, `to_active`, `resurrect`, `show_message` |
| `set_character_status` | Modify flags | `character_id`, `is_alive`, `is_available` |

System messages auto-display with text interpolation. Customize via `custom_message` parameter or disable via `show_message: false`.

Default messages by reason:
- `left`: "{char:id} has left the party."
- `died`: "{char:id} has fallen..."
- `captured`: "{char:id} was captured!"
- `betrayed`: "{char:id} has betrayed the force!"

### set_backdrop Cinematic Command

Load a map as a visual-only backdrop (no party loading, camera setup, or gameplay initialization):

```json
{"type": "set_backdrop", "params": {"map_id": "town_square", "transition": "fade", "fade_duration": 0.5}}
```

Parameters (priority order):
- `scene_path`: Direct path to scene file
- `scene_id`: Registered scene ID from mod.json
- `map_id`: Map ID to use as backdrop
- `transition`: "instant" (default) or "fade"
- `fade_duration`: Seconds (default 0.5)

### NPC Conditional Cinematics

NPCs support complex flag-based dialog branching via `conditional_cinematics` array.

| Key | Logic | Description |
|-----|-------|-------------|
| `flag` | Single | Legacy single flag check |
| `flags` | AND | All flags must be true |
| `any_flags` | OR | At least one flag must be true |
| `negate` | Invert | Inverts the overall result |

Conditions checked in order; first match wins. Fallback used if none match.

```gdscript
# Example: Complex condition combining AND + OR
conditional_cinematics = [
    {
        "flags": ["chapter_2", "met_elder"],           # AND: both required
        "any_flags": ["saved_princess", "saved_prince"], # OR: at least one
        "cinematic_id": "elder_thanks"
    }
]
```

---

*Live long and ship quality code.*
