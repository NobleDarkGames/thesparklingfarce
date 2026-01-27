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
  templates/             # Code templates
  tools/                 # Utilities (TileSetAutoGenerator, etc.)
  utils/                 # Helper scripts

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
tests/                   # Automated test suite (GdUnit4)
  unit/                  # Isolated class tests (no autoloads)
  integration/           # Multi-system tests (uses autoloads)
  fixtures/              # Shared test factories (CharacterFactory, UnitFactory, etc.)
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
| SaveManager | Save/load, gold management, playtime tracking |
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

### Battle System State Contract

Tests and systems that initialize battle state MUST clean up when done. Battle singletons maintain global state that persists across scenes.

**Required cleanup calls:**
```gdscript
TurnManager.clear_battle()
BattleManager.player_units.clear()
BattleManager.enemy_units.clear()
BattleManager.all_units.clear()
GridManager.clear_grid()
```

Failure to clean up causes test pollution and unpredictable behavior in subsequent battles or tests.

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

**JSON-supported types:** cinematic, map

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
| virtual | VirtualSpawnHandler | Off-screen actors (narrators, radio voices, thoughts) |

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

### mod.json Structure

```json
{
    "id": "demo_campaign",
    "name": "Demo Campaign",
    "version": "1.0.0",
    "author": "The Sparkling Farce Team",
    "description": "A sandbox style mod...",
    "godot_version": "4.5",
    "load_priority": 100,
    "dependencies": [],
    "scenes": {
        "main_menu": "scenes/ui/main_menu.tscn",
        "opening_cinematic": "scenes/cinematics/my_opening.tscn"
    }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique mod identifier (lowercase, underscores) |
| `name` | Yes | Human-readable display name |
| `version` | Yes | Semantic version string |
| `load_priority` | Yes | Resource override priority |
| `dependencies` | No | Array of required mod IDs |
| `scenes` | No | Named scene overrides |

### Load Priority

| Range | Purpose |
|-------|---------|
| 0 | Platform defaults (`_starter_kit`, clamped from -1) |
| 1-99 | Reserved for official content |
| 100-8999 | User mods, campaigns (`demo_campaign` = 100) |
| 9000-9999 | Total conversions |

Higher priority mods override same-ID resources from lower priority mods.

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

### Resource Registration

ModLoader auto-discovers resources from `mods/*/data/<type>/`:

```
mods/my_mod/
  mod.json
  data/
    characters/       -> registered as "character" type
    items/            -> registered as "item" type
    abilities/        -> registered as "ability" type
    ai_behaviors/     -> registered as "ai_behavior" type
    status_effects/   -> registered as "status_effect" type
    terrain/          -> registered as "terrain" type
    ...
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

## AI Combat System

### Architecture

The AI system is divided into engine and content:
- `AIController` (engine): Orchestrates AI turn execution
- `AIBrain` (engine): Abstract base class with helper methods
- `ConfigurableAIBrain` (engine): Interprets data-driven behaviors
- `AIBehaviorData` (content): Data-driven behavior configuration

### AI Behavior Configuration

`AIBehaviorData` resources define behavior without code:

```gdscript
@export var role: String = "aggressive"        # tactical, support, defensive, aggressive
@export var behavior_mode: String = "aggressive"  # aggressive, cautious, opportunistic
@export var retreat_hp_threshold: int = 30     # HP% to trigger retreat
@export var aoe_minimum_targets: int = 2       # Skip AoE if fewer targets
@export var seek_terrain_advantage: bool = true
```

### AI Roles

| Role | Primary Behavior |
|------|-----------------|
| aggressive | Attack highest-threat target |
| support | Heal wounded allies, then attack |
| defensive | Protect VIP allies (bodyguard) |
| tactical | Apply debuffs/status effects first |

### AI Modes

| Mode | Movement Pattern |
|------|-----------------|
| aggressive | Chase enemies, attack immediately |
| cautious | Hold position, engage within alert/engagement range |
| opportunistic | Prioritize wounded targets, retreat when low HP |

### Threat Calculation

AI targeting uses weighted threat scores (deterministic, no RNG):

```gdscript
threat_weights: Dictionary = {
    "wounded_target": 1.0,   # Priority for damaged enemies
    "healer": 1.5,           # Priority for healers
    "damage_dealer": 1.0,    # Priority for high-attack units
    "proximity": 1.0,        # Distance modifier
    "low_defense": 1.0       # Vulnerable target bonus
}
```

Character-level modifiers:
- `CharacterData.ai_threat_modifier`: Multiplier (bosses = 2.0, fodder = 0.5)
- `CharacterData.ai_threat_tags`: `["priority_target"]`, `["avoid"]`, `["vip"]`

### Behavior Phases

Trigger-based behavior changes during battle:

```gdscript
behavior_phases: Array[Dictionary] = [
    {"trigger": "hp_below", "value": 75, "changes": {"behavior_mode": "cautious"}},
    {"trigger": "hp_below", "value": 25, "changes": {"role": "berserker", "retreat_enabled": false}},
    {"trigger": "ally_died", "value": "boss_healer", "changes": {"prioritize_revenge": true}}
]
```

Available triggers: `hp_below`, `hp_above`, `turn_count`, `ally_died`, `ally_count_below`, `enemy_count_below`, `flag_set`

### Item/Spell Usage Rules

```gdscript
@export var use_healing_items: bool = true
@export var use_attack_items: bool = true
@export var use_buff_items: bool = false
@export var conserve_mp_on_heals: bool = true
@export var prioritize_boss_heals: bool = true
@export var use_status_effects: bool = true
```

---

## Terrain System

### TerrainData Properties

| Property | Description |
|----------|-------------|
| `terrain_id` | Unique identifier (e.g., "forest", "lava") |
| `movement_cost_walking` | Movement cost for ground units (1.0 normal) |
| `movement_cost_floating` | Movement cost for floating units |
| `movement_cost_flying` | Movement cost for flying units (typically 1.0) |
| `impassable_walking` | Block ground units entirely |
| `impassable_floating` | Block floating units |
| `impassable_flying` | Block flying units (rare - ceilings) |
| `defense_bonus` | Defense stat bonus (0-10) |
| `evasion_bonus` | Evasion percentage (0-50%) |
| `damage_per_turn` | Damage at turn start (lava, poison tiles) |
| `healing_per_turn` | Healing at turn start (healing springs) |

### Layered Terrain

`GridManager` supports multiple terrain layers sorted by z_index:

```gdscript
# Terrain lookup uses custom tile data first, falls back to atlas filename
var terrain_type: String = tile_data.get_custom_data("terrain_type")
if terrain_type.is_empty():
    terrain_type = _get_terrain_id_from_atlas(...)
```

Higher z_index layers override lower layers for terrain effects.

### A* Pathfinding

`GridManager` uses Godot's `AStarGrid2D` with faction-aware movement:
- Units can pass through allies
- Units cannot pass through enemies
- Terrain costs affect path selection

---

## Status Effects

### StatusEffectData Properties

| Property | Description |
|----------|-------------|
| `effect_id` | Unique identifier (e.g., "poison", "sleep") |
| `duration` | Turns until expiry (0 = permanent until removed) |
| `trigger_timing` | When effect processes (TURN_START, TURN_END, ON_DAMAGE, ON_ACTION, PASSIVE) |
| `skips_turn` | Unit cannot act (sleep, stun) |
| `recovery_chance_per_turn` | Chance to auto-recover (paralysis = 25%) |
| `damage_per_turn` | DoT damage (positive) or HoT (negative) |
| `stat_modifiers` | Dictionary of stat changes |
| `removed_on_damage` | Wake on hit (sleep) |
| `action_modifier` | RANDOM_TARGET (confusion), ATTACK_ALLIES (berserk), etc. |

### Built-in Effects

| Effect | Behavior |
|--------|----------|
| poison | Damage at turn end |
| sleep | Skip turn, wake on damage |
| paralysis | Skip turn, 25% recovery/turn |
| confusion | Random target selection |
| attack_up/down | Stat modifier (passive) |
| defense_up/down | Stat modifier (passive) |
| regen | Healing at turn end |

### Registering Custom Effects

Effects are data-driven via `ModLoader.status_effect_registry`:

```gdscript
# Effects defined in mods/*/data/status_effects/*.tres
# Looked up by effect_id at runtime
var effect: StatusEffectData = ModLoader.status_effect_registry.get_effect("custom_effect")
```

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

**Note:** Hero death ALWAYS triggers defeat regardless of configured condition (SF2-authentic).

### Battle Configuration

```gdscript
@export var is_story_battle: bool = false  # Prevents menu quit
@export var turn_dialogues: Dictionary = {} # {turn_number: DialogueData}
@export var music_id: String = ""           # Battle music track
```

### Rewards

```gdscript
@export var experience_reward: int = 0
@export var gold_reward: int = 0
@export var item_rewards: Array[ItemData] = []
@export var character_rewards: Array[CharacterData] = []  # Characters that join
```

### XP Distribution

`BattleManager` XP constants:
- `HEALER_ITEM_XP = 10` (healers using healing items)
- `NON_HEALER_ITEM_XP = 1` (non-healers using healing items)
- `HEAL_SPELL_XP = 10` (healing spells)
- `ATTACK_SPELL_BASE_XP = 8` (damage spells)

### Battle Exit Reasons

`BattleManager.BattleExitReason` enum:
- `EGRESS`: Tactical retreat spell
- `ANGEL_WING`: Item-based escape
- `HERO_DEATH`: Hero died (triggers defeat)
- `MENU_QUIT`: Player quit from menu

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

## Combat System

### Turn Order (AGI-Based Queue)

`TurnManager` uses Shining Force II-style individual turn order:

```
Priority = AGI * Random(0.875 to 1.125) + Random(-1, 0, +1)
```

- All units (player, enemy, neutral) intermixed in single queue
- Priority recalculated each turn cycle
- No separate phases - one unit acts at a time

### Combat Phases

`BattleManager` uses session-based combat (SF2-authentic):

```
Attack Session = Initial Attack -> Double Attack (optional) -> Counter (optional)
```

| Phase | Trigger | Damage |
|-------|---------|--------|
| Initial | Always | 100% |
| Double | `ClassData.double_attack_rate` roll | 100% |
| Counter | Defender survives + `ClassData.counter_rate` roll | 75% |

### Damage Calculation

`CombatCalculator` (static class) handles all formulas:

- Base damage considers attacker strength, weapon power, defender defense
- Flying units receive NO terrain defense bonus
- Terrain defense applied to ground/floating units

### Movement Types

| Type | Terrain Cost | Terrain Defense |
|------|--------------|-----------------|
| WALKING | Pays full cost | Yes |
| FLOATING | Ignores cost (1 always) | Yes |
| FLYING | Ignores cost (1 always) | No |
| CUSTOM | Mod-defined | Mod-defined |

---

## Ability System

**Spells are CLASS-BASED** (SF2 design):
- Primary source: `ClassData.class_abilities`
- Level gating: `ClassData.ability_unlock_levels`
- Rare exceptions: `CharacterData.unique_abilities`

### Ability Types

| Type | Purpose |
|------|---------|
| ATTACK | Deals damage |
| HEAL | Restores HP |
| SUPPORT | Buffs allies |
| DEBUFF | Weakens enemies (stat reductions) |
| STATUS | Applies status effects (Sleep, Freeze) |
| SUMMON | Summons units or effects |
| COUNTER | Reactive abilities |
| SPECIAL | Unique effects |
| CUSTOM | Mod-defined type |

### Targeting Modes

| Mode | Description |
|------|-------------|
| SINGLE_ENEMY | One hostile unit |
| SINGLE_ALLY | One friendly unit |
| SELF | Caster only |
| ALL_ENEMIES | All hostile units |
| ALL_ALLIES | All friendly units |
| AREA | AoE with `area_of_effect` radius |

### Range Properties

```gdscript
@export var min_range: int = 1      # 0 = self, 1 = adjacent
@export var max_range: int = 1      # Maximum targeting distance
@export var area_of_effect: int = 0 # 0 = single, 1+ = splash radius
```

Range bands support dead zones (e.g., bow with `min_range: 2` cannot hit adjacent enemies).

---

## Modal UI Input Blocking (CRITICAL)

Godot's `_unhandled_input()` does NOT block `Input.is_action_pressed()` polling.

**Add modal UIs to these checks:**
1. `ExplorationUIController.is_blocking_input()`
2. `HeroController._is_modal_ui_active()` (defense-in-depth)

**Existing modal checks:** `DebugConsole.is_open`, `ShopManager.is_shop_open()`, `DialogManager.is_dialog_active()`, `ExplorationUIController.current_state != EXPLORING`

---

## Debug Console

Toggle: **F12** or **~**

| Namespace | Example Commands |
|-----------|------------------|
| hero.* | gold, give_gold, set_level, heal, give_item |
| party.* | grant_xp, add, remove, list, heal_all |
| campaign.* | set_flag, clear_flag, list_flags |
| battle.* | win, lose, spawn, kill |
| debug.* | clear, fps, reload_mods, scene |

---

## Character System

### CharacterData Properties

| Property | Description |
|----------|-------------|
| `character_uid` | Auto-generated 8-char unique ID (immutable) |
| `character_name` | Display name |
| `character_class` | Reference to ClassData |
| `base_hp`, `base_mp`, etc. | Starting stats |
| `starting_level` | Initial level |
| `starting_equipment` | Array of ItemData |
| `starting_inventory` | Array of item IDs |
| `unique_abilities` | Character-specific abilities (exceptions only) |
| `is_hero` | Primary protagonist flag |
| `is_boss` | Boss enemy flag |
| `is_unique` | True = named character, False = template (Goblin) |
| `unit_category` | "player", "enemy", or "neutral" |
| `default_ai_behavior` | AIBehaviorData for enemy use |
| `ai_threat_modifier` | Threat calculation multiplier |
| `ai_threat_tags` | `["priority_target"]`, `["avoid"]`, `["vip"]` |

### ClassData Properties

| Property | Description |
|----------|-------------|
| `display_name` | Class name |
| `movement_type` | WALKING, FLOATING, FLYING, CUSTOM |
| `movement_range` | Tiles per turn |
| `counter_rate` | Counterattack percentage (3, 6, 12, 25) |
| `double_attack_rate` | Double attack percentage |
| `crit_rate_bonus` | Added to base crit calculation |
| `*_growth` | Stat growth rates (0-200) |
| `equippable_weapon_types` | Array of weapon types |
| `class_abilities` | Array of AbilityData |
| `ability_unlock_levels` | `{"ability_id": level}` |
| `promotion_paths` | Array of PromotionPath |
| `promotion_level` | Minimum level to promote (default 10) |
| `promotion_resets_level` | Reset to level 1 on promote |
| `promotion_bonus_*` | Stats gained on promotion |

### Stat Growth System

Enhanced Shining Force-style growth:
- 0-99: Percentage chance of +1
- 100+: Guaranteed +1, remainder% chance of +2
- 5% "lucky roll" for rates >= 50 grants +1 extra

### Equipment System

| Slot | Types |
|------|-------|
| weapon | sword, axe, spear, bow, staff, knife |
| ring_1 | ring |
| ring_2 | ring |
| accessory | accessory |

Weapon properties:
- `attack_power`: Base damage
- `min_attack_range` / `max_attack_range`: Range band (dead zone if min > 1)
- `hit_rate` / `critical_rate`: Combat modifiers
- `is_cursed`: Cannot unequip until uncursed

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

### SaveManager

#### Playtime Tracking

SaveManager automatically tracks session playtime using timestamp differences (zero per-frame overhead).

```gdscript
# Session lifecycle
SaveManager.set_current_save(save_data)    # Starts session timer
SaveManager.clear_current_save()            # Stops session timer

# Before saving, sync_current_save_state() accumulates elapsed time
SaveManager.sync_and_save_to_slot(slot)     # Syncs playtime + saves
```

**Design notes:**
- Uses `Time.get_unix_time_from_system()` for accuracy
- Time continues accumulating when paused or alt-tabbed (thinking time counts as play time)
- `sync_current_save_state()` resets the session timer after accumulating, enabling multiple saves per session

#### Save File Structure

```
user://saves/
  slot_1.sav          # SaveData as JSON
  slot_2.sav
  slot_3.sav
  slots.meta          # Array of SlotMetadata for quick UI display
```

#### What Gets Saved

| Data | Source |
|------|--------|
| Party members | `PartyManager.export_to_save()` |
| Story flags | `GameState.story_flags` |
| Gold | `SaveData.gold` |
| Playtime | Accumulated from session timestamps |
| Current location | Map/scene identifier |
| Dialog state | `DialogManager.export_state()` |

#### Mod Dependency Handling

On load, SaveManager validates mod dependencies:

```gdscript
var mod_check: Dictionary = save_data.validate_mod_dependencies()
# Returns: {valid: bool, missing_mods: Array, orphaned_items: Array, orphaned_characters: Array}

# Orphaned content (from uninstalled mods) is automatically cleaned:
save_data.remove_orphaned_content(mod_check)
```

#### Atomic File Writes

All save operations use atomic write pattern to prevent corruption:
1. Write to `.tmp` file
2. Backup existing to `.bak`
3. Atomic rename `.tmp` to final
4. Delete `.bak` on success

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

### Cinematic Commands

The cinematic system supports these built-in commands:

| Command | Purpose |
|---------|---------|
| `wait` | Pause for duration |
| `dialog` / `show_dialog` | Show dialog box |
| `move_entity` | Move actor along path |
| `set_facing` | Change actor facing direction |
| `set_position` | Teleport actor to position |
| `play_animation` | Play sprite animation |
| `camera_move` | Pan camera to position |
| `camera_follow` | Camera follows actor |
| `camera_shake` | Screen shake effect |
| `fade_screen` | Fade to/from black |
| `play_sound` | Play sound effect |
| `play_music` | Change music track |
| `spawn_entity` | Spawn actor at runtime |
| `despawn_entity` | Remove spawned actor |
| `open_shop` | Open shop interface |
| `add_party_member` | Recruit character |
| `remove_party_member` | Remove from party |
| `rejoin_party_member` | Departed member returns |
| `set_character_status` | Modify alive/available flags |
| `grant_items` | Give items/gold |
| `change_scene` | Scene transition |
| `set_backdrop` | Load map as visual backdrop |
| `show_choice` | Present player choices |
| `trigger_battle` | Start battle |
| `check_flag` / `check_flags` | Conditional branching |
| `set_variable` | Set campaign variable |

#### set_backdrop

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

#### Custom Commands

Mods can register custom cinematic commands:

```gdscript
class MyCustomExecutor extends CinematicCommandExecutor:
    func get_command_type() -> String:
        return "my_custom_command"

    func execute(command: Dictionary, manager: Node) -> bool:
        # Execute command, return true if complete
        return true

# In mod initialization:
CinematicsManager.register_command_executor("my_custom_command", MyCustomExecutor.new())
```

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

## Known Limitations

Issues identified but not yet implemented:

| Issue | Location | Status |
|-------|----------|--------|
| No translation files | `mods/*/translations/` | LocalizationManager API works but no actual .po/.csv translation files exist; game is English-only |
| Spell animation system | `ability_editor.gd:398-400` | Animation fields ignored; spells have no VFX. **Planned approach**: Use Godot particle effects (GPUParticles2D), screen shake, flash/tint effects, and projectile motion as default effects. System should be mod-friendly—mods can override default particles with custom sprites/animations per ability. Deferred as significant scope. |
| Dialog box auto-positioning | `dialog_box.gd:363-365` | AUTO position falls back to BOTTOM instead of smart speaker-based positioning |
| Mod field menu options | `exploration_field_menu.gd:330-331` | `_add_mod_options()` commented out; mods cannot add custom field menu options |
| Battle equip setting | `item_action_menu.gd:285-286` | Equipment always exploration-only; cannot equip during battle (SF2 allows it) |
| Editor reference scanning | Multiple editors | Phase 2+ TODO for scanning resource references (e.g., find all uses of a character) |

### Test Coverage Gaps

Critical untested autoloads:

| System | Lines | Risk |
|--------|-------|------|
| InputManager | 2,392 | HIGH — all player input |
| SceneManager | 263 | HIGH — scene transitions |

Additional untested: CaravanController, ExplorationUIManager, GameJuice, DebugConsole, SettingsManager, CraftingManager

Recently tested (with dedicated suites): RandomManager (27 tests), GameEventBus (31 tests), TextInterpolator (32 tests), LocalizationManager (39 tests)

**Test suite status:** 1760 test cases (80 suites). See `docs/testing-reference.md` for testing patterns.

### Features Requiring Additional Documentation

Working features that may need expanded modder documentation:

| Feature | Description |
|---------|-------------|
| VirtualSpawnHandler | Off-screen actors for narrators, radio voices, thoughts |
| Church Services | HEAL, REVIVE, UNCURSE, PROMOTION, SAVE modes in shop system |
| Crafter System | Recipe browser, material transformation |
| Equipment Bonus System | Full stat modifier caching in UnitStats |

---

*Live long and ship quality code.*
