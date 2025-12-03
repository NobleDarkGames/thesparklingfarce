# The Sparkling Farce Platform Specification

**Version:** 1.1.0
**Status:** Revised (Senior Staff Review)
**Last Updated:** December 2, 2025
**Godot Version:** 4.5.1

---

## Table of Contents

1. [Project Mission](#1-project-mission)
2. [Architecture Overview](#2-architecture-overview)
3. [Autoload Singletons](#3-autoload-singletons)
4. [Mod System](#4-mod-system)
   - Manifest Format, Load Priority, Resource Discovery
   - Type Registries, Trigger Discovery, TileSet Resolution
   - Namespaced Story Flags
5. [Resource Types](#5-resource-types)
6. [Map System](#6-map-system) (Five Map Types)
7. [Battle System](#7-battle-system)
8. [Dialog and Cinematics](#8-dialog-and-cinematics)
9. [Save System](#9-save-system)
10. [Key Patterns](#10-key-patterns)
11. [Implementation Status](#11-implementation-status)
    - Complete, Functional, Phase 4/5/6 Roadmap
12. [Code Standards](#12-code-standards)
13. [Appendix A: Quick Reference](#appendix-a-quick-reference-for-agents)
14. [Revision History](#revision-history)

---

## 1. Project Mission

### What The Sparkling Farce Is

The Sparkling Farce is a **modding platform** for creating tactical RPGs in the Shining Force tradition. It provides the engine, systems, and tools while content creators (including the official team) provide characters, items, battles, and stories through the mod system.

**Key Distinction:** The platform is the engine. The game is a mod.

### Design Inspirations

- **Shining Force II** (open world model, mobile Caravan, backtracking)
- **Shining Force I** (tactical combat, character recruitment)
- **Shining Force GBA** (visual polish, class promotions)
- **Fire Emblem** (grid-based tactical combat patterns)

### What It Is Not

- Not a finished game (it is a platform for games)
- Not a linear chapter-based experience (SF1 model explicitly rejected)
- Not hardcoded content (all game content lives in mods)

---

## 2. Architecture Overview

### Directory Structure

```
sparklingfarce/
  core/                          # Platform code ONLY
    mod_system/                  # ModLoader, ModRegistry, ModManifest
    resources/                   # Resource class definitions
    systems/                     # Autoload singletons and managers
    components/                  # Reusable node components
    registries/                  # Type registries (trigger types, etc.)

  mods/                          # ALL game content lives here
    _base_game/                  # Official base content (priority 0)
      mod.json                   # Manifest
      data/                      # Resources by type
        characters/, classes/, items/, abilities/
        battles/, parties/, dialogues/, cinematics/
        maps/, campaigns/
      assets/                    # Art, audio
      scenes/                    # Moddable scenes
      tilesets/                  # TileSet resources
      triggers/                  # Trigger scene templates
    _sandbox/                    # Development testing (priority 100)

  scenes/                        # Engine scenes (not content)
    battle/                      # Battle UI and loader
    map_exploration/             # Hero controller, camera
    ui/                          # Dialog box, menus
    tests/                       # Test harnesses

  tests/                         # Automated tests (gdUnit4)
    unit/                        # Unit tests by domain
    integration/                 # Integration tests

  addons/
    gdUnit4/                     # Testing framework
    sparkling_editor/            # In-editor content tools
```

### Core Separation Principle

**`core/`** contains only platform code:
- System managers (autoloads)
- Resource class definitions (schemas)
- Base components (Unit, MapTrigger, etc.)
- Type registries

**`mods/`** contains all content:
- Character definitions
- Battle scenarios
- Map metadata
- Dialogue scripts
- Tileset art

**Agents must never add game content to `core/`.**

---

## 3. Autoload Singletons

The platform uses 17 core autoload singletons plus 1 editor-specific autoload for global state and orchestration.

### Core Infrastructure

| Singleton | Path | Purpose |
|-----------|------|---------|
| **ModLoader** | `core/mod_system/mod_loader.gd` | Mod discovery, loading, registry access |
| **GameState** | `core/systems/game_state.gd` | Story flags, trigger tracking, transition context |
| **SaveManager** | `core/systems/save_manager.gd` | Save/load operations, slot management |
| **SceneManager** | `core/systems/scene_manager.gd` | Scene transitions, fade effects |

### Battle Systems

| Singleton | Path | Purpose |
|-----------|------|---------|
| **BattleManager** | `core/systems/battle_manager.gd` | Battle orchestration, map loading, combat execution |
| **GridManager** | `core/systems/grid_manager.gd` | A* pathfinding, tile occupancy, range calculation |
| **TurnManager** | `core/systems/turn_manager.gd` | AGI-based turn order, turn session IDs |
| **InputManager** | `core/systems/input_manager.gd` | Battle input state machine |
| **AIController** | `core/systems/ai_controller.gd` | Enemy AI brain execution |

### Static Utility Classes (Not Autoloads)

| Class | Path | Purpose |
|-------|------|---------|
| **CombatCalculator** | `core/systems/combat_calculator.gd` | Pure damage/hit/crit formulas (static methods) |

> **Note:** `CombatCalculator` is a static utility class extending `RefCounted`, not an autoload. All methods are `static func` and called directly: `CombatCalculator.calculate_physical_damage(attacker, defender)`

### Content Systems

| Singleton | Path | Purpose |
|-----------|------|---------|
| **PartyManager** | `core/systems/party_manager.gd` | Party composition, hero protection |
| **ExperienceManager** | `core/systems/experience_manager.gd` | XP distribution, level-up handling |
| **DialogManager** | `core/systems/dialog_manager.gd` | Dialog state machine, typewriter effect |
| **CinematicsManager** | `core/systems/cinematics_manager.gd` | Scripted cutscene execution |
| **CampaignManager** | `core/systems/campaign_manager.gd` | Campaign node progression |
| **TriggerManager** | `core/systems/trigger_manager.gd` | Map trigger routing and handling |
| **AudioManager** | `core/systems/audio_manager.gd` | Music, SFX, mod-aware paths |
| **GameJuice** | `core/systems/game_juice.gd` | Screen shake, visual feedback |

### Editor Autoloads

| Singleton | Path | Purpose |
|-----------|------|---------|
| **EditorEventBus** | `addons/sparkling_editor/editor_event_bus.gd` | Editor plugin communication (only active in-editor) |

### Accessing Autoloads

```gdscript
# Direct access by name (preferred)
var battle: BattleData = ModLoader.registry.get_resource("battle", "tutorial_001")
GameState.set_flag("defeated_boss")
SceneManager.change_scene("res://maps/town.tscn")

# Never store autoload references as member variables (anti-pattern)
```

---

## 4. Mod System

### Manifest Format (mod.json)

```json
{
  "id": "my_mod",
  "name": "My Awesome Mod",
  "version": "1.0.0",
  "author": "Author Name",
  "description": "Mod description",
  "godot_version": "4.5",
  "dependencies": ["base_game"],
  "load_priority": 500,
  "content": {
    "data_path": "data/",
    "assets_path": "assets/"
  },
  "scenes": {
    "main_menu": "scenes/custom_menu.tscn"
  },
  "provides": {
    "characters": ["*"],
    "battles": ["*"]
  },
  "overrides": []
}
```

### Load Priority Strategy

| Range | Purpose | Examples |
|-------|---------|----------|
| 0-99 | Official core content | `_base_game` (0) |
| 100-8999 | User mods, expansions | `_sandbox` (100), community mods |
| 9000-9999 | Total conversions | Complete game replacements |

Higher priority mods override lower priority resources with matching IDs. Same-priority mods load alphabetically.

### Resource Discovery

ModLoader scans `mods/*/data/<directory>/` for resources. The mapping is **directory → resource type**:

```gdscript
const RESOURCE_TYPE_DIRS: Dictionary = {
    "characters": "character",    # Directory name → resource type
    "classes": "class",
    "items": "item",
    "abilities": "ability",
    "battles": "battle",
    "parties": "party",
    "dialogues": "dialogue",
    "cinematics": "cinematic",
    "maps": "map",
    "campaigns": "campaign"
}
```

**File Format Support:** Only certain types support JSON loading:
```gdscript
const JSON_SUPPORTED_TYPES: Array[String] = ["cinematic", "campaign", "map"]
```
All other resource types require `.tres` files.

### Accessing Resources

```gdscript
# Get single resource
var char: CharacterData = ModLoader.registry.get_resource("character", "max")

# Get all of a type
var all_battles: Array[Resource] = ModLoader.registry.get_all_resources("battle")

# Check existence
if ModLoader.registry.has_resource("item", "healing_herb"):
    pass

# Get scene path (mod-registered)
var menu_path: String = ModLoader.registry.get_scene_path("main_menu")
```

### Override Mechanics

Resources with the same type and ID from higher-priority mods replace those from lower-priority mods. This enables:

- Character stat rebalancing
- Battle scenario modifications
- Complete content replacement (total conversions)

### Type Registries (Mod Extensibility)

ModLoader provides five type registries that allow mods to extend enum-like values:

| Registry | Purpose | Example Extensions |
|----------|---------|-------------------|
| `equipment_registry` | Weapon/armor types | "laser", "plasma", "energy_shield" |
| `environment_registry` | Weather, time of day | "acid_rain", "eclipse" |
| `unit_category_registry` | Unit classifications | "mech", "cyborg", "undead" |
| `animation_offset_registry` | Sprite animation offsets | Custom positioning |
| `trigger_type_registry` | Custom trigger behaviors | "puzzle", "shop", "teleporter" |

**Registering Custom Types (mod.json):**
```json
{
  "custom_types": {
    "weapon_types": ["laser", "plasma"],
    "weather_types": ["acid_rain"],
    "unit_categories": ["mech", "cyborg"],
    "trigger_types": ["puzzle", "shop"]
  }
}
```

**Accessing Type Registries:**
```gdscript
ModLoader.equipment_registry.get_weapon_types()
ModLoader.trigger_type_registry.is_valid_trigger_type("puzzle")
ModLoader.unit_category_registry.get_all_categories()
```

### Trigger Script Discovery

Mods can provide custom trigger behaviors by placing scripts in `mods/*/triggers/`:

```
mods/my_mod/
  triggers/
    puzzle_trigger.gd     # Auto-discovered as "puzzle" type
    teleporter_trigger.gd # Auto-discovered as "teleporter" type
```

Trigger scripts must extend `MapTrigger` and set `trigger_type_string`:

```gdscript
extends MapTrigger

func _ready() -> void:
    trigger_type_string = "puzzle"
    # Custom behavior...
```

Access via: `ModLoader.trigger_type_registry.get_trigger_script_path("puzzle")`

### TileSet Resolution

Mods can provide tilesets that are auto-discovered from `mods/*/tilesets/*.tres`:

```gdscript
# Get tileset by logical name (highest-priority mod wins)
var tileset: TileSet = ModLoader.get_tileset("terrain_placeholder")
var path: String = ModLoader.get_tileset_path("terrain_placeholder")
var source_mod: String = ModLoader.get_tileset_source("terrain_placeholder")

# Check existence
if ModLoader.has_tileset("my_tileset"):
    pass
```

### Namespaced Story Flags

GameState provides a scoped flag API to prevent mod conflicts:

```gdscript
# Set mod namespace (typically in mod initialization)
GameState.set_mod_namespace("my_mod")

# Scoped flag operations (auto-prefixed to "my_mod:flag_name")
GameState.set_flag_scoped("boss_defeated")  # Sets "my_mod:boss_defeated"
GameState.has_flag_scoped("boss_defeated")  # Checks "my_mod:boss_defeated"

# Get all flags for a specific mod
var my_flags: Dictionary = GameState.get_flags_for_mod("my_mod")
```

**Best Practice:** Always use namespaced flags for mod-specific state to avoid collisions.

---

## 5. Resource Types

### CharacterData

Defines a playable or enemy character.

| Property | Type | Description |
|----------|------|-------------|
| `character_name` | String | Display name |
| `character_uid` | String | Unique identifier (auto-generated if empty) |
| `character_class` | ClassData | Reference to class |
| `is_hero` | bool | True for protagonist (one per game) |
| `is_unique` | bool | True for named characters (vs generic enemies) |
| `unit_category` | String | "hero", "ally", "enemy", "npc", etc. |
| `base_hp/mp/str/def/agi/int/luck` | int | Starting stats |
| `portrait` | Texture2D | UI portrait |
| `battle_sprite` | Texture2D | Battle map sprite |
| `combat_animation_data` | CombatAnimationData | Animation configuration |

### ClassData

Defines a character class with growth rates and combat parameters.

| Property | Type | Description |
|----------|------|-------------|
| `display_name` | String | Class name |
| `movement_type` | enum | WALKING, FLYING, FLOATING |
| `movement_range` | int | Tiles per turn |
| `counter_rate` | int | Counterattack % (SF2: 3, 6, 12, or 25) |
| `*_growth` | int | Stat growth rates (0-100%) |
| `equippable_weapon_types` | Array[String] | Allowed weapon types |
| `promotion_class` | ClassData | Class after promotion |

### BattleData

Defines a complete battle scenario.

| Property | Type | Description |
|----------|------|-------------|
| `battle_name` | String | Display name |
| `map_scene` | PackedScene | Battle map scene |
| `player_spawn_point` | Vector2i | Starting position |
| `enemies` | Array[Dictionary] | Enemy units with positions and AI |
| `victory_condition` | enum | DEFEAT_ALL, DEFEAT_BOSS, SURVIVE, etc. |
| `defeat_condition` | enum | ALL_DEFEATED, LEADER_DEFEATED, etc. |
| `pre_battle_dialogue` | DialogueData | Dialog before battle |
| `victory_dialogue` | DialogueData | Dialog on win |
| `experience_reward` | int | Base XP for victory |

**Enemy Dictionary Format:**
```gdscript
{
    "character": CharacterData,
    "position": Vector2i,
    "ai_brain": AIBrain
}
```

### ItemData

Defines weapons, armor, and consumables.

| Property | Type | Description |
|----------|------|-------------|
| `item_name` | String | Display name |
| `item_type` | enum | WEAPON, ARMOR, CONSUMABLE, KEY_ITEM |
| `equipment_type` | String | "sword", "axe", "bow", etc. |
| `attack_power` | int | Weapon damage bonus |
| `attack_range` | int | Weapon reach (1 = melee) |
| `*_modifier` | int | Stat modifiers when equipped |
| `effect` | AbilityData | For consumables |

### AbilityData

Defines spells, skills, and item effects.

| Property | Type | Description |
|----------|------|-------------|
| `ability_name` | String | Display name |
| `ability_type` | enum | ATTACK, HEAL, SUPPORT, DEBUFF, SPECIAL |
| `target_type` | enum | SINGLE_ENEMY, SINGLE_ALLY, AREA, etc. |
| `min_range/max_range` | int | Targeting range |
| `area_of_effect` | int | Splash radius |
| `mp_cost/hp_cost` | int | Resource costs |
| `power` | int | Base effectiveness |
| `status_effects` | Array[String] | Effects to apply |

### DialogueData

Defines conversation sequences.

| Property | Type | Description |
|----------|------|-------------|
| `dialogue_id` | String | Unique identifier |
| `lines` | Array[Dictionary] | Dialogue lines |
| `choices` | Array[Dictionary] | Player choice options |
| `box_position` | enum | BOTTOM, TOP, CENTER, AUTO |
| `next_dialogue` | DialogueData | Chain to next dialogue |

**Line Dictionary Format:**
```gdscript
{
    "speaker_name": "Max",
    "text": "Let's go!",
    "emotion": "determined",
    "portrait": Texture2D  # Optional
}
```

### CinematicData

Defines scripted cutscene sequences.

| Property | Type | Description |
|----------|------|-------------|
| `cinematic_id` | String | Unique identifier |
| `commands` | Array[Dictionary] | Sequence of commands |
| `disable_player_input` | bool | Lock input during cinematic |
| `can_skip` | bool | Allow skip with cancel |
| `next_cinematic` | CinematicData | Chain to next |

**Command Types:**
- `move_entity`, `set_facing`, `play_animation`
- `show_dialog`, `camera_move`, `camera_follow`, `camera_shake`
- `wait`, `fade_screen`
- `spawn_entity`, `despawn_entity`
- `play_sound`, `play_music`
- `set_variable`

### MapMetadata

Defines map properties and connections (stored as JSON).

| Property | Type | Description |
|----------|------|-------------|
| `map_id` | String | Unique identifier |
| `display_name` | String | Name shown in UI |
| `scene_path` | String | Path to map scene |
| `map_type` | String | "town", "overworld", "dungeon", "battle", "interior" |
| `spawn_points` | Dictionary | Named spawn positions |
| `connections` | Array | Links to other maps |

### CampaignData

Defines a complete campaign with node graph.

| Property | Type | Description |
|----------|------|-------------|
| `campaign_id` | String | Unique identifier |
| `campaign_name` | String | Display name |
| `starting_node_id` | String | First node |
| `nodes` | Array[CampaignNode] | All campaign nodes |
| `default_hub_id` | String | Default return point |
| `chapters` | Array[Dictionary] | Chapter organization |

### PartyData

Defines party composition for battles.

| Property | Type | Description |
|----------|------|-------------|
| `party_name` | String | Display name |
| `members` | Array[Dictionary] | Party members |
| `max_size` | int | Maximum party size (default 8) |

---

## 6. Map System

### SF2 Open World Model

The Sparkling Farce uses Shining Force 2's open world approach:

- **Free exploration**: Players can backtrack and revisit locations
- **Mobile Caravan**: Party management available on overworld
- **No permanent lockouts**: Content remains accessible
- **Discrete map scenes**: Each location is a separate scene

### Five Map Types

#### Town Maps
- Detailed interior tilesets
- NPCs, shops, save points
- 1:1 visual scale (tile = floor tile)
- No Caravan visible (waits outside)
- No battle triggers

#### Overworld Maps
- Terrain-focused tilesets
- Abstract scale (tile = region)
- Caravan visible and accessible
- Battle triggers (story encounters)
- Landmarks for town/dungeon entry

#### Dungeon Maps
- Mix of detailed and abstract
- Battle triggers common
- May or may not allow Caravan
- More linear than overworld

#### Battle Maps
- Grid-based tactical combat
- Loaded as distinct scenes
- Terrain affects movement/defense

#### Interior Maps
- Sub-locations within towns (shops, houses, churches)
- Detailed interior tilesets
- Typically single-room or small multi-room layouts
- No Caravan, no battles
- Used for shops, inns, churches, key story locations

### Visual Scale Implementation

The "zoomed out" overworld feel is achieved through **art direction**, not tile size changes:

- Same underlying tile grid
- Terrain tiles represent larger areas conceptually
- Multi-tile terrain patterns (mountains as 2x2 groups)
- Lower detail density in overworld art
- Optional camera zoom adjustments

### Map Transitions

Handled by `TriggerManager` via DOOR triggers:

```gdscript
# Door trigger data
{
    "target_map_id": "granseal_castle",  # MapMetadata lookup
    "target_spawn_id": "entrance",        # Spawn point in destination
    "transition_type": "fade"             # "fade", "instant", "scroll"
}
```

### Spawn Points

Defined in MapMetadata JSON and resolved during transitions:

```json
{
    "spawn_points": {
        "default": {"position": [5, 10], "facing": "down"},
        "from_overworld": {"position": [8, 15], "facing": "up"}
    }
}
```

---

## 7. Battle System

### Turn System

AGI-based turn order with randomization for tactical variety:

```gdscript
# Turn priority calculation (higher values act first)
var random_mult: float = randf_range(0.875, 1.125)  # 87.5% to 112.5%
var random_offset: float = float(randi_range(-1, 1))  # -1, 0, or +1
priority = (unit.agility * random_mult) + random_offset
```

**Higher priority values act first.** The variance prevents identical AGI units from having deterministic turn order. TurnManager tracks turn sessions with unique IDs for defensive programming.

### Combat Formulas

All formulas in `CombatCalculator`:

**Physical Damage:**
```
damage = (attacker.strength - defender.defense) * variance(0.9-1.1)
minimum = 1
```

**Hit Chance:**
```
hit = 80 + (attacker.agility - defender.agility) * 2
clamped to 10-99%
```

**Critical Chance:**
```
crit = 5 + (attacker.luck - defender.luck)
clamped to 0-50%
```

**Counter Chance:**
```
counter = class.counter_rate  # SF2-style class rates (3, 6, 12, or 25%)
clamped to 0-50%
```

**Experience Gain:**
```
multiplier = 1.0 + (enemy_level - player_level) * 0.2  # If enemy higher
multiplier = max(0.5, 1.0 + (enemy_level - player_level) * 0.1)  # If lower
xp = base_xp * multiplier
```

### Victory/Defeat Conditions

**Victory Conditions:**
- `DEFEAT_ALL_ENEMIES`: All enemies defeated
- `DEFEAT_BOSS`: Specific enemy defeated (indexed)
- `SURVIVE_TURNS`: Survive N turns
- `REACH_LOCATION`: Unit reaches position
- `PROTECT_UNIT`: Neutral survives
- `CUSTOM`: Script-based

**Defeat Conditions:**
- `ALL_UNITS_DEFEATED`: Party wiped
- `LEADER_DEFEATED`: Hero falls
- `TURN_LIMIT`: Time runs out
- `UNIT_DIES`: Protected unit falls
- `CUSTOM`: Script-based

### AI Brains

Enemy behavior defined by `AIBrain` resources in `mods/*/data/ai_brains/`:

- **Aggressive**: Move toward nearest enemy, attack when in range
- **Defensive**: Hold position, attack only if adjacent
- **Support**: Prioritize healing allies
- (More behaviors planned for Phase 5)

### Battle Flow

1. BattleManager loads map scene from BattleData
2. GridManager extracts grid from TileMapLayer
3. Units spawned at designated positions
4. TurnManager calculates initial turn order
5. Loop: Current unit acts (player input or AI)
6. InputManager handles action selection (MOVE/ATTACK/STAY)
7. CombatCalculator resolves combat
8. Check victory/defeat conditions
9. Award XP on victory, return to exploration

---

## 8. Dialog and Cinematics

### Dialog System

**State Machine States:**
1. `IDLE`: No dialog active
2. `DIALOG_STARTING`: Fade in, load first line
3. `SHOWING_LINE`: Typewriter reveal in progress
4. `WAITING_FOR_INPUT`: Line complete, await advance
5. `WAITING_FOR_CHOICE`: Showing choice selector
6. `DIALOG_ENDING`: Fade out, cleanup

**Features:**
- Typewriter effect (30 chars/sec, 0.15s punctuation pause)
- Portrait system (64x64, emotion variants)
- Slide-in animations for speaker changes
- 2-4 choice branching
- Circular reference protection (MAX_DEPTH=10)

**Starting Dialog:**
```gdscript
DialogManager.start_dialogue(dialogue_data)  # From resource
DialogManager.start_dialogue_by_id("greeting_001")  # From registry
```

### Cinematics System

**Command Executor Pattern:**

CinematicsManager uses registered executors for each command type:

```gdscript
# Register custom executor
CinematicsManager.register_command_executor("custom_effect", MyExecutor.new())
```

**Built-in Commands:**
- `wait`, `set_variable`, `show_dialog`
- `move_entity`, `set_facing`, `play_animation`
- `camera_move`, `camera_follow`, `camera_shake`
- `fade_screen`, `play_sound`, `play_music`
- `spawn_entity`, `despawn_entity`

**Actor Registration:**

Actors must be registered before cinematics can reference them:

```gdscript
CinematicsManager.register_actor(actor_node)  # CinematicActor component
```

**Playing Cinematics:**
```gdscript
CinematicsManager.play_cinematic("opening_scene")  # By ID
CinematicsManager.play_cinematic_from_resource(cinematic_data)  # Direct
```

---

## 9. Save System

### Slot Structure

3 save slots (Shining Force tradition):

```
user://saves/
  slot_1.sav
  slot_2.sav
  slot_3.sav
  slots.meta    # Slot previews and metadata
```

> **Note:** Save files use `.sav` extension (not `.json`). The metadata file is `slots.meta`.

### SaveData Contents

```gdscript
{
    "slot_number": 1,
    "save_version": "1.0",
    "timestamp": "2025-12-02T10:30:00",
    "playtime_seconds": 3600,
    "current_map_id": "granseal",
    "current_position": {"x": 10, "y": 15},
    "party_members": [CharacterSaveData...],
    "story_flags": {"defeated_boss": true},
    "inventory": {"healing_herb": 5},
    "gold": 1500,
    "campaign_progress": {...},
    "active_mods": ["base_game", "expansion_1"]
}
```

### Save Operations

```gdscript
# Save current state
SaveManager.save_game(slot_number)

# Load game
SaveManager.load_game(slot_number)

# Check slot
if SaveManager.has_save_data(slot_number):
    var metadata: Dictionary = SaveManager.get_slot_metadata(slot_number)
```

### Hero Protection

- One character marked `is_hero = true` per game
- Hero cannot be removed from party
- Hero always at party position 0
- New game auto-initializes with hero

---

## 10. Key Patterns

### Signal-Driven Architecture

Systems communicate via signals, not direct calls:

```gdscript
# Good: Signal-based loose coupling
BattleManager.battle_ended.connect(_on_battle_ended)

# Avoid: Direct method calls creating tight coupling
BattleManager._internal_method()  # Never do this
```

### Resource-Based Data

All content stored as Godot Resources for:
- Editor integration
- Serialization
- Mod override support

### Defensive Programming

**Turn Session IDs:**
```gdscript
# TurnManager uses session IDs to prevent stale operations
if session_id != _current_session_id:
    push_warning("Stale turn operation attempted")
    return
```

**Null Checks:**
```gdscript
if not resource:
    push_error("Required resource is null")
    return
```

### Dictionary Access Pattern

```gdscript
# Correct (per project standard)
if "key" in dict:
    var value = dict["key"]

# Incorrect (do not use)
if dict.has("key"):  # Avoid this form
```

### Validation Pattern

Resources implement `validate()` for self-checking:

```gdscript
func validate() -> bool:
    if required_field.is_empty():
        push_error("ResourceType: required_field is required")
        return false
    return true
```

### Registry Access Pattern

Always access mod content through registry:

```gdscript
# Correct: Registry lookup
var char: CharacterData = ModLoader.registry.get_resource("character", "max")

# Incorrect: Direct path (breaks mod override)
var char = load("res://mods/_base_game/data/characters/max.tres")
```

---

## 11. Implementation Status

### Complete (Production Ready)

| System | Phase | Notes |
|--------|-------|-------|
| Map Exploration | 1, 2.5 | Grid movement, collision, party followers |
| Collision Detection | 2.5 | TileMapLayer physics integration |
| Trigger System | 2.5 | Battle, door, dialog triggers, custom trigger discovery |
| Story Flags | 2.5 | GameState tracking with namespaced flag support |
| Dialog System | 3.1-3.3 | Typewriter, portraits, branching |
| Save System | 3.4 | 3-slot persistence |
| Party Management | 3.5 | Composition, hero protection |
| Mod System | 1, 2.5.1 | Priority loading, override, type registries, tileset resolution |
| Audio Manager | 1 | Music, SFX |

### Functional (Needs Polish)

| System | Phase | Notes |
|--------|-------|-------|
| Battle Core | 2 | 70% complete, needs floating damage numbers |
| AI System | 2 | 30% complete, only Aggressive/Defensive behaviors |
| UI Systems | 2, 3 | Battle UI done, missing menus |
| Cinematics | 3.2 | Core working, needs more command executors |

### Roadmap: Phase 4 (Core SF Mechanics) 🚧

These are **critical Shining Force mechanics** that define the genre feel:

| System | Priority | Description |
|--------|----------|-------------|
| **Promotion System** | CRITICAL | Class advancement, stat boosts, visual transformation. *The* signature SF mechanic. |
| **Equipment System** | HIGH | Weapon/armor equipping, stat modifiers, class restrictions |
| **Caravan System** | HIGH | Mobile HQ for party management, storage, services (SF2 defining feature) |
| **Terrain Effects** | HIGH | Movement costs by terrain type, defense bonuses |
| **Magic/Spells** | HIGH | MP costs, targeting, area effects |
| **Items/Inventory** | MEDIUM | Consumables, storage, shop integration |
| **Retreat/Death** | MEDIUM | Units retreat when defeated (not permadeath), resurrection at church |

### Roadmap: Phase 5 (Polish & Advanced) 🔮

| System | Priority | Description |
|--------|----------|-------------|
| **Status Effects** | HIGH | Poison, paralysis, sleep, stat debuffs |
| **Double-Attack** | MEDIUM | High-AGI units attack twice (classic SF mechanic) |
| **AI Brain Expansion** | MEDIUM | Support, Coward, Patrol, Boss behaviors |
| **Counterattack Range** | LOW | Ranged weapons prevent counters |
| **Attack Direction Bonus** | LOW | Backstab damage multiplier |
| **Battle Rank System** | LOW | Performance grades (A-F) with bonus rewards |

### Roadmap: Phase 6 (Content & QoL) 🎮

| System | Description |
|--------|-------------|
| **Shop System** | Buy/sell items, dynamic pricing, stock management |
| **Formation System** | Pre-battle party arrangement on spawn points |
| **Hidden Content** | Searchable items, secret character recruitment |
| **Egress/Fast Travel** | Return to town spell, map quick travel |

### Known Gaps

1. **Battle UI Polish**: Floating damage numbers, level-up celebration screens

2. **Campaign Flow**: Full explore-battle-explore loop verification needed

3. **XP Balance**: No catch-up mechanics for underleveled characters (SF historical problem)

4. **World Graph**: Map connection graph and gating logic not yet implemented

---

## 12. Code Standards

### Strict Typing

All code uses explicit types:

```gdscript
# Correct
var speed: float = 5.0
func calculate_damage(attacker: UnitStats, defender: UnitStats) -> int:

# Incorrect (rejected by project settings)
var speed = 5.0
func calculate_damage(attacker, defender):
```

### No Walrus Operator

```gdscript
# Correct
var result: int = calculate()

# Incorrect
var result := calculate()  # Do not use
```

### Dictionary Key Checks

```gdscript
# Correct
if "key" in dictionary:

# Incorrect
if dictionary.has("key"):  # Avoid
```

### Warning Levels

Project enforces strict warnings (`project.godot`):
- `untyped_declaration`: Error (level 2)
- `infer_on_variant`: Error (level 2)
- `unsafe_*`: Warning (level 1)

### Documentation Comments

Use triple-hash for class and method documentation:

```gdscript
## CombatCalculator - Combat damage and resolution formulas
##
## Static utility class for calculating combat outcomes using Shining Force-inspired
## formulas. All methods are pure calculations with no side effects.
class_name CombatCalculator
extends RefCounted


## Calculate physical attack damage
## Formula: (Attacker STR - Defender DEF) * variance(0.9 to 1.1)
## Returns: Minimum of 1 damage
static func calculate_physical_damage(attacker: UnitStats, defender: UnitStats) -> int:
```

---

## Appendix A: Quick Reference for Agents

### Adding New Content

1. Create resource file in `mods/_base_game/data/<type>/`
2. Resource will be auto-discovered by ModLoader
3. Access via `ModLoader.registry.get_resource(type, id)`

### Adding New Resource Types

1. Create Resource class in `core/resources/my_type_data.gd`
2. Add mapping to `ModLoader.RESOURCE_TYPE_DIRS`
3. Resources auto-discovered from `mods/*/data/<type_dir>/`

### Common Mistakes

- Putting content in `core/` (must go in `mods/`)
- Hardcoding resource paths (use registry)
- Using `dict.has()` instead of `"key" in dict`
- Using walrus operator (`:=`)
- Missing explicit types

### Key File Locations

| Purpose | Path |
|---------|------|
| Mod manifest | `mods/<mod_id>/mod.json` |
| Character resources | `mods/<mod_id>/data/characters/*.tres` |
| Battle resources | `mods/<mod_id>/data/battles/*.tres` |
| Map metadata | `mods/<mod_id>/data/maps/*.json` |
| Dialogue resources | `mods/<mod_id>/data/dialogues/*.tres` |
| Tileset art | `mods/<mod_id>/art/tilesets/<name>/*.png` |
| TileSet resources | `mods/<mod_id>/tilesets/*.tres` |

---

*Live long and ship quality code.*

---

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-12-02 | Initial baseline specification |
| 1.1.0 | 2025-12-02 | Senior staff review corrections |

**v1.1.0 Changes:**
- Fixed `RESOURCE_TYPE_DIRS` mapping direction (directory → type)
- Corrected `CombatCalculator` as static utility class, not autoload
- Fixed turn order formula (AGI-based with variance, higher acts first)
- Fixed save file extensions (`.sav`, `slots.meta`)
- Added 5th map type: INTERIOR
- Added `EditorEventBus` autoload documentation
- Fixed `CharacterData` properties (`character_uid`, `unit_category`, `is_unique`, `battle_sprite`)
- Added `JSON_SUPPORTED_TYPES` documentation
- Added Type Registries documentation (5 registries)
- Added Trigger Script Discovery documentation
- Added TileSet Resolution documentation
- Added Namespaced Story Flags documentation
- Reorganized Implementation Status with proper Phase 4/5/6 roadmap
- Elevated Promotion System to Phase 4 CRITICAL priority
- Added Caravan System, Terrain Effects, Retreat/Death to roadmap

*This specification was generated by Mr. Spec, Science Officer, USS Torvalds.*
*Revised following Senior Staff Review: Commander Claudius, Chief O'Brien, Modro, Lt. Ears, Lt. Claudbrain.*
