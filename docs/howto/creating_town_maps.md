# HowTo: Creating a Town Map (Granseal-Style)

*Prepared by Lt. Claudbrain & Professor Suung, USS Torvalds*

This guide covers creating an exploration town map for The Sparkling Farce, following the SF2 open-world model where towns are detailed, explorable areas with NPCs, shops, and transitions to other maps.

---

## Table of Contents

1. [Prerequisites and Setup](#1-prerequisites-and-setup)
2. [Creating a Town Map Step-by-Step](#2-creating-a-town-map-step-by-step)
3. [Adding Map Transitions](#3-adding-map-transitions)
4. [Populating the Town](#4-populating-the-town)
5. [Campaign Integration](#5-campaign-integration)
6. [Testing Your Town](#6-testing-your-town)
7. [Quick Reference](#7-quick-reference)

---

## 1. Prerequisites and Setup

### Required Knowledge

- Basic Godot 4.5 editor navigation (scene tree, inspector, TileMap painting)
- Understanding of grid-based tile systems (32x32 pixel tiles)
- Familiarity with JSON syntax for configuration files
- Reading GDScript (for understanding scripts attached to nodes)

### Tools Needed

- Godot 4.5 or later
- A text editor for JSON files
- Image editor for tileset artwork (if creating custom tiles)

### Project Structure Overview

Maps live within mod directories:

```
mods/
  your_mod/
    mod.json                    # Mod manifest (required)
    data/
      maps/                     # MapMetadata JSON files
        granseal.json
      campaigns/                # Campaign definitions
        main_story.json
      material_spawns/          # Rare material locations
        granseal_materials.tres
    maps/                       # Scene files
      granseal.tscn
      granseal.gd
    art/
      tilesets/                 # Tile artwork
        town_tiles/
```

### Key Reference Files

| Purpose | Path |
|---------|------|
| Map Template Scene | `mods/_base_game/maps/templates/map_template.tscn` |
| Map Template Script | `mods/_base_game/maps/templates/map_template.gd` |
| Working Example | `mods/_sandbox/maps/opening_game_map.tscn` |

---

## 2. Creating a Town Map Step-by-Step

### Step 1: Duplicate the Map Template

Copy the template files to your mod:

```
Source:  mods/_base_game/maps/templates/map_template.tscn
         mods/_base_game/maps/templates/map_template.gd
Target:  mods/your_mod/maps/granseal.tscn
         mods/your_mod/maps/granseal.gd
```

Rename the root node from `MapTemplate` to `Granseal` (or your town name).

### Step 2: Scene Structure

**Required nodes** (production):

```
Granseal (Node2D)                     # Root node with map script
  TileMapLayer                        # Terrain and collision
  SpawnPoints (Node2D)                # Container for spawn markers
    DefaultStart (Marker2D)           # Default spawn point
  Followers (Node2D)                  # Party member container (dynamically populated)
  MapCamera (Camera2D)                # Camera controller
  Triggers (Node2D)                   # Container for door/battle triggers
```

**Optional nodes** (for isolated testing):

```
  Hero (CharacterBody2D)              # Placeholder for F5 testing
    SpriteVisual (ColorRect)          # Placeholder visual
    CollisionShape2D                  # Physics collision
    InteractionRay (RayCast2D)        # For NPC detection
```

#### About Hero and Party Nodes

In production gameplay, the Hero and party followers are spawned dynamically from `PartyManager` data when entering a map via `CampaignManager`. The scene does not need to include these nodes.

However, the current map template includes a placeholder Hero for development convenience:

1. **Isolated testing**: Allows running the scene directly (F5 in editor) without campaign context
2. **Development convenience**: Provides immediate visual feedback while building maps

The map template's `_setup_party_followers()` function has a TODO to integrate with PartyManager:

```gdscript
## TODO: Integrate with PartyManager to use actual party data
func _setup_party_followers() -> void:
    # TODO: Get actual party from PartyManager
    # var party: Array = PartyManager.get_party_members()
```

**Critical for triggers:** The Hero (whether placeholder or dynamically spawned) MUST be in the "hero" group for triggers to detect it.

### Step 3: Configure the Root Node Script

Extend the base map template:

```gdscript
# granseal.gd
extends "res://mods/_base_game/maps/templates/map_template.gd"

## Custom town-specific logic goes here

func _on_hero_interaction(interaction_pos: Vector2i) -> void:
    super._on_hero_interaction(interaction_pos)
    # Add custom NPC or object interaction checks
```

The template script provides:
- Automatic battle return handling (restores hero position after combat)
- Spawn point resolution for map transitions
- Camera following with smooth interpolation
- SF2-style party follower chain

### Step 4: Configure the TileMapLayer

**Tileset Assignment:**

Reference an existing tileset or create your own. The placeholder tileset is at:
`mods/_base_game/tilesets/terrain_placeholder.tres`

Tile sources from the placeholder tileset:
| Source ID | Type | Collision |
|-----------|------|-----------|
| 0 | Grass | None (walkable) |
| 1 | Wall | Full (blocked) |
| 2 | Water | Full (blocked) |
| 3 | Road | None (walkable) |
| 4 | Forest | None (walkable) |
| 5 | Mountain | Full (blocked) |
| 6 | Sand | None (walkable) |
| 7 | Bridge | None (walkable) |
| 8 | Dirt | None (walkable) |

**Collision Configuration:**

Tiles with physics collision polygons are impassable. In the tileset (`.tres` file), collision is defined per tile:

```
0:0/0/physics_layer_0/polygon_0/points = PackedVector2Array(-16, -16, 16, -16, 16, 16, -16, 16)
```

The HeroController (`scenes/map_exploration/hero_controller.gd`) checks walkability:

```gdscript
func _is_tile_walkable(tile_pos: Vector2i) -> bool:
    var tile_data: TileData = tile_map.get_cell_tile_data(tile_pos)
    if tile_data == null:
        return true  # Empty space is walkable
    var has_collision: bool = tile_data.get_collision_polygons_count(0) > 0
    return not has_collision
```

**Tile Size:**

All maps use **32x32 pixel tiles**. This is the SF-authentic unified tile size used throughout the codebase.

### Step 5: Grid System

For exploration maps, the grid is implicit in the TileMapLayer. The HeroController handles grid-based movement automatically:

```gdscript
@export var tile_size: int = 32  ## SF-authentic: unified 32px tiles
@export var movement_speed: float = 4.0  ## tiles per second
```

No additional grid configuration is needed for town maps. The GridManager autoload (`core/systems/grid_manager.gd`) is used for battle maps only.

---

## 3. Adding Map Transitions

### Understanding Spawn Points

Spawn points define where players appear when entering a map. Use the SpawnPoint component (`core/components/spawn_point.gd`).

**Add Marker2D nodes under SpawnPoints:**

```
SpawnPoints (Node2D)
  DefaultStart (Marker2D)         # spawn_id="default_start", is_default=true
  FromCastle (Marker2D)           # spawn_id="from_castle"
  FromOverworld (Marker2D)        # spawn_id="from_overworld"
```

**SpawnPoint Properties:**

| Property | Type | Description |
|----------|------|-------------|
| spawn_id | String | Unique identifier (e.g., "from_castle") |
| facing | Enum | Direction hero faces: "up", "down", "left", "right" |
| is_default | bool | True for the primary spawn point |
| is_caravan_spawn | bool | True for Caravan positioning (overworld only) |
| tile_size | int | Should match tilemap (32) |

**Example from opening_game_map.tscn:**

```
[node name="DefaultStart" type="Marker2D" parent="SpawnPoints"]
position = Vector2(88, 88)
script = ExtResource("6_spawn")
spawn_id = "default_start"
is_default = true
```

### Setting Up Door Triggers

Use MapTrigger (`core/components/map_trigger.gd`) for scene transitions.

**Trigger Types:**

```gdscript
enum TriggerType {
    BATTLE,      # Initiate tactical battle
    DIALOG,      # Start conversation
    CHEST,       # Open treasure
    DOOR,        # Scene transition
    CUTSCENE,    # Story event
    TRANSITION,  # Teleport within scene
    CUSTOM       # User-defined
}
```

**Door Trigger Configuration:**

```
DoorTrigger (Area2D)
  Script: core/components/map_trigger.gd
  trigger_type = DOOR (3)
  trigger_id = "north_gate"
  one_shot = false                    # Doors are reusable
  trigger_data = {
    "destination_scene": "res://mods/your_mod/maps/overworld.tscn",
    "spawn_point": "from_granseal"
  }
  CollisionShape2D
    Shape: RectangleShape2D (16x16)
```

**Alternative: Using MapMetadata connections (preferred):**

```gdscript
trigger_data = {
    "target_map_id": "your_mod:overworld_central",
    "target_spawn_id": "granseal_entrance",
    "transition_type": "fade"
}
```

The TriggerManager handles both legacy (`destination_scene`) and MapMetadata-style (`target_map_id`) transitions.

### Battle Trigger Setup

Instance the pre-made battle trigger prefab:
`mods/_base_game/triggers/battle_trigger.tscn`

Configure in the Inspector:
```gdscript
trigger_type = BATTLE (0)
trigger_id = "granseal_training_battle"
one_shot = true                       # One-time battles
trigger_data = {
    "battle_id": "tutorial_battle"
}
```

---

## 4. Populating the Town

### NPC Placement

NPCs are implemented as custom objects with dialog triggers:

```
NPC_Elder (Area2D or CharacterBody2D)
  Sprite2D                            # NPC visual
  CollisionShape2D                    # Blocking collision (optional)
  DialogArea (Area2D)                 # Trigger zone
    MapTrigger script attached
      trigger_type = DIALOG
      trigger_id = "elder_talk"
      trigger_data = {"dialog_id": "elder_greeting"}
```

Connect NPC interaction to your map script's `_on_hero_interaction` callback.

### Shop Configuration

Shops use NPCs with special dialog branches that invoke shop UI. Shop data references ItemData resources from `mods/*/data/items/`.

### Interactive Objects (Chests, Signs, Bookshelves)

The InteractableNode system provides SF2-authentic searchable objects. These work like NPCs but grant items, show messages, or trigger events when searched.

**Using the Sparkling Editor:**

1. Open Sparkling Editor → Story → Interactables
2. Click "New" and select a template (Treasure Chest, Bookshelf, Sign Post, etc.)
3. Configure rewards (items, gold) and/or dialog text
4. Save to `mods/your_mod/data/interactables/`

**Manual Placement in Scene:**

1. Add an InteractableNode to your scene
2. Create or assign an InteractableData resource
3. Position on the grid (auto-snaps to 32px tiles)

```
Interactables (Node2D)
  TownChest01 (InteractableNode)
    interactable_data = preload("res://mods/your_mod/data/interactables/town_chest_01.tres")
```

**InteractableData Properties:**

| Property | Type | Description |
|----------|------|-------------|
| interactable_id | String | Unique ID (used for state tracking) |
| interactable_type | Enum | CHEST, BOOKSHELF, BARREL, SIGN, LEVER, CUSTOM |
| display_name | String | Shown in editor (e.g., "Town Chest") |
| sprite_closed | Texture2D | Visual when not yet opened |
| sprite_opened | Texture2D | Visual after opening (optional) |
| item_rewards | Array | Items to grant: `[{item_id, quantity}]` |
| gold_reward | int | Gold to grant |
| dialog_text | String | Message to show (for signs, bookshelves) |
| one_shot | bool | If true, can only be searched once |
| required_flags | Array | Flags that must be set to interact |
| forbidden_flags | Array | Flags that block interaction |

**Example InteractableData (.tres):**

```gdscript
[resource]
script = ExtResource("res://core/resources/interactable_data.gd")
interactable_id = "granseal_chest_01"
display_name = "Treasure Chest"
interactable_type = 0  # CHEST
item_rewards = [{"item_id": "healing_herb", "quantity": 2}]
gold_reward = 50
one_shot = true
```

**SF2-Authentic Behavior:**

- Player must face the object and press the interact button
- Immediate feedback: "Found Healing Herb!" (no pre-dialog)
- Opened state persists via GameState flags (`{id}_opened`)
- Objects block movement like NPCs

**Conditional Content:**

Like NPCs, interactables support conditional cinematics for story-reactive behavior:

```gdscript
conditional_cinematics = [
    {"flag": "rescued_princess", "cinematic_id": "chest_special_reward"}
]
fallback_cinematic_id = "chest_normal_reward"
```

The collection state is tracked via `GameState.has_flag("{interactable_id}_opened")`.

### Material Spawn Points (Rare Materials System)

The crafting system (`core/resources/material_spawn_data.gd`) supports "sparkly spots" for rare material collection.

**Create a MaterialSpawnData resource (.tres file):**

```gdscript
[resource]
script = ExtResource("res://core/resources/material_spawn_data.gd")
material_id = "iron_ore"
map_id = "your_mod:granseal"
grid_position = Vector2i(15, 22)
spawn_id = "granseal_ore_01"
quantity = 1
respawns = false
visual_hint = "sparkle"
required_flags = []                   # Flags that must be set
forbidden_flags = []                  # Flags that block access
min_chapter = 0                       # Earliest availability
max_chapter = -1                      # Latest (-1 = no limit)
```

**MaterialSpawnData Properties:**

| Property | Type | Description |
|----------|------|-------------|
| material_id | String | Which material to give |
| map_id | String | Namespaced map ID |
| grid_position | Vector2i | Tile coordinates |
| spawn_id | String | Unique ID for save tracking |
| quantity | int | Amount to give |
| respawns | bool | Can be collected again |
| visual_hint | String | "sparkle", "chest", "pile" |
| required_flags | Array[String] | ALL must be set |
| forbidden_flags | Array[String] | NONE can be set |
| min_chapter | int | Earliest availability |
| max_chapter | int | Latest availability (-1 = none) |

Place a visual indicator in your scene at the grid position. The accessibility check:

```gdscript
func is_accessible(flag_checker: Callable, current_chapter: int) -> bool:
    # Checks required_flags, forbidden_flags, min_chapter, max_chapter
```

---

## 5. Campaign Integration

### Scene as Source of Truth

**Important architectural change**: The scene file is now the canonical source for map identity, spawn points, and door connections. The JSON metadata provides runtime configuration only.

**In your map scene script**, add these exports:

```gdscript
# granseal.gd
extends "res://mods/_base_game/maps/templates/map_template.gd"

## Unique identifier (namespaced: "mod_id:map_name")
@export var map_id: String = "your_mod:granseal"

## Map type determines Caravan visibility and party follower behavior
@export_enum("TOWN", "OVERWORLD", "DUNGEON", "INTERIOR", "BATTLE") var map_type: String = "TOWN"

## Display name for UI (save menu, map popups)
@export var display_name: String = "Granseal Town"
```

**SpawnPoints** are defined as nodes in the scene (see Section 3). They are extracted automatically at load time.

**Door triggers** with their `trigger_data` define connections. They are also extracted automatically.

### Creating a MapMetadata JSON File (Simplified)

The JSON now contains **runtime configuration only** - no spawn_points or connections!

Place in `mods/your_mod/data/maps/granseal.json`:

```json
{
  "scene_path": "res://mods/your_mod/maps/granseal.tscn",
  "caravan_visible": false,
  "caravan_accessible": false,
  "camera_zoom": 1.0,
  "music_id": "town_theme",
  "ambient_id": "",
  "random_encounters_enabled": false,
  "save_anywhere": true
}
```

That's it! The `map_id`, `display_name`, `map_type`, spawn points, and connections are all extracted from your scene file automatically.

### What's Extracted from Scene vs JSON

| Data | Source | Notes |
|------|--------|-------|
| map_id | Scene `@export` | Unique identifier |
| display_name | Scene `@export` | UI display |
| map_type | Scene `@export` | TOWN, OVERWORLD, etc. |
| spawn_points | SpawnPoint nodes | Positions, facing, defaults |
| connections | MapTrigger DOOR nodes | Door destinations |
| caravan_visible | JSON | Runtime behavior |
| caravan_accessible | JSON | Runtime behavior |
| music_id | JSON | Audio config (placeholder for vertical mixing) |
| random_encounters | JSON | Runtime behavior |
| edge_connections | JSON | Overworld map stitching only |

**MapType Values:**

| Type | Caravan Visible | Camera Zoom | Random Encounters | Party Followers |
|------|-----------------|-------------|-------------------|-----------------|
| TOWN | false | 1.0 | false | Visible (SF2 chain) |
| OVERWORLD | true | 0.75-0.85 | true | Hidden |
| DUNGEON | false | 0.9-1.0 | true | Visible |
| INTERIOR | false | 1.0-1.2 | false | Visible |
| BATTLE | false | 1.0 | false | N/A |

### Creating a Campaign Node

Add to `mods/your_mod/data/campaigns/main_story.json`:

```json
{
  "campaign_id": "your_mod:main_story",
  "campaign_name": "Your Epic Adventure",
  "campaign_description": "A tale of heroes...",
  "campaign_version": "1.0.0",
  "starting_node_id": "granseal_hub",
  "default_hub_id": "granseal_hub",
  "initial_flags": {},
  "chapters": [
    {
      "id": "ch1",
      "name": "Chapter 1: Beginnings",
      "number": 1,
      "node_ids": ["granseal_hub", "first_battle"]
    }
  ],
  "nodes": [
    {
      "node_id": "granseal_hub",
      "display_name": "Granseal Town",
      "node_type": "scene",
      "scene_path": "res://mods/your_mod/maps/granseal.tscn",
      "is_hub": true,
      "allow_egress": true,
      "completion_trigger": "exit_trigger",
      "on_complete": "first_battle"
    },
    {
      "node_id": "first_battle",
      "display_name": "Training Battle",
      "node_type": "battle",
      "resource_id": "tutorial_battle",
      "on_victory": "granseal_hub",
      "on_defeat": "granseal_hub",
      "retain_xp_on_defeat": true,
      "defeat_gold_penalty": 0.5
    }
  ]
}
```

**Node Types:**

| Type | Description |
|------|-------------|
| scene | Town/dungeon/hub exploration |
| battle | Tactical combat |
| cutscene | Story cinematic |
| choice | Branching decision point |
| custom:* | Mod-defined types |

**CampaignNode Properties (for scene type):**

| Property | Type | Description |
|----------|------|-------------|
| node_id | String | Unique within campaign |
| display_name | String | UI display name |
| node_type | String | "scene" for towns |
| scene_path | String | Path to .tscn file |
| is_hub | bool | Egress return destination |
| allow_egress | bool | Can use Egress spell here |
| completion_trigger | String | How scene ends |
| on_complete | String | Next node_id |

### Registering Resources in mod.json

```json
{
  "id": "your_mod",
  "name": "Your Mod Name",
  "version": "1.0.0",
  "author": "You",
  "godot_version": "4.5",
  "load_priority": 100,
  "dependencies": ["base_game"],
  "content": {
    "data_path": "data/",
    "assets_path": "assets/"
  },
  "provides": {
    "maps": ["*"],
    "campaigns": ["*"],
    "material_spawns": ["*"]
  }
}
```

The ModLoader automatically discovers:
- Maps from `data/maps/*.json`
- Campaigns from `data/campaigns/*.json`
- Material spawns from `data/material_spawns/*.tres`

---

## 6. Testing Your Town

### Understanding Test Contexts

Maps can be tested in two different contexts, and understanding the difference is important:

| Context | Hero/Party Source | Triggers Work | Campaign Flow |
|---------|-------------------|---------------|---------------|
| **Isolated** (F5 on scene) | Placeholder nodes in scene | Partially | No |
| **Campaign** (full game) | PartyManager data | Fully | Yes |

### Isolated Testing (Development)

Run your scene directly by opening it and pressing F5:

```
Advantages:
- Fast iteration - no need to navigate through menus
- Hero movement works immediately
- Camera follows hero
- Party followers display (placeholder visuals)

Limitations:
- Door triggers may fail (no campaign context for target resolution)
- Battle triggers work but return may fail
- No actual party data (uses placeholder CharacterData)
- No GameState flags for conditional triggers
```

**The placeholder Hero node exists specifically to enable this workflow.** Without it, you'd need the full campaign context to test anything.

### Testing with Campaign Context

For full integration testing:

**Option A: Temporary Main Scene**
1. In Project Settings → Application → Run, set Main Scene to your map
2. Create a bootstrap script that initializes PartyManager with test data
3. Run the project

**Option B: Test Campaign**
Create a minimal test campaign in `mods/_sandbox/data/campaigns/test_campaign.json`:

```json
{
  "campaign_id": "_sandbox:map_test",
  "campaign_name": "Map Test",
  "starting_node_id": "your_map",
  "default_hub_id": "your_map",
  "nodes": [
    {
      "node_id": "your_map",
      "display_name": "Test Map",
      "node_type": "scene",
      "scene_path": "res://mods/your_mod/maps/granseal.tscn",
      "is_hub": true
    }
  ]
}
```

Then start the game and select this campaign.

**Option C: Existing Test Infrastructure**
Use `scenes/map_exploration/map_test_playable.gd` as a reference for how to set up test party data before loading a map.

### Headless Testing

Run the test suite to verify no parser errors:

```bash
./test_headless.sh
```

**Create a test for your map (optional):**

```gdscript
# tests/unit/map/test_granseal.gd
extends "res://tests/test_runner.gd"

func test_spawn_points_exist() -> void:
    var scene: PackedScene = load("res://mods/your_mod/maps/granseal.tscn")
    var instance: Node = scene.instantiate()

    var spawn_points: Node = instance.get_node_or_null("SpawnPoints")
    assert(spawn_points != null, "SpawnPoints container missing")
    assert(spawn_points.get_child_count() > 0, "No spawn points defined")

    instance.queue_free()

func test_hero_in_group() -> void:
    var scene: PackedScene = load("res://mods/your_mod/maps/granseal.tscn")
    var instance: Node = scene.instantiate()

    var hero: Node = instance.get_node_or_null("Hero")
    assert(hero != null, "Hero node missing")
    assert(hero.is_in_group("hero"), "Hero not in 'hero' group")

    instance.queue_free()
```

### Common Issues and Troubleshooting

**Hero cannot move:**
- Check TileMapLayer has a tileset assigned
- Verify tile collision is correctly configured (no physics = walkable)
- Ensure Hero has HeroController script attached
- Confirm Hero is in the "hero" group

**Door trigger not activating:**
- Verify trigger collision layer = 2, mask = 1
- Check trigger_data has valid destination_scene or target_map_id
- Confirm spawn_point ID exists in destination map
- Ensure Hero is in "hero" group

**Hero spawns at wrong position:**
- Verify spawn_id in trigger_data matches a SpawnPoint.spawn_id in target scene
- Check is_default = true on your fallback spawn point
- Look for warnings in console about missing spawn points

**Campaign not loading:**
- Validate JSON syntax (use a JSON linter)
- Check starting_node_id exists in nodes array
- Verify scene_path is correct and file exists

**MapMetadata not registering:**
- Confirm file is in `mods/your_mod/data/maps/` directory
- Check mod.json has correct data_path
- Look for validation errors in console on startup

---

## 7. Quick Reference

### Key File Paths

| Purpose | Path |
|---------|------|
| Map Template Scene | `mods/_base_game/maps/templates/map_template.tscn` |
| Map Template Script | `mods/_base_game/maps/templates/map_template.gd` |
| Hero Controller | `scenes/map_exploration/hero_controller.gd` |
| Spawn Point Component | `core/components/spawn_point.gd` |
| Map Trigger Component | `core/components/map_trigger.gd` |
| MapMetadata Resource | `core/resources/map_metadata.gd` |
| Campaign Node Resource | `core/resources/campaign_node.gd` |
| Campaign Data Resource | `core/resources/campaign_data.gd` |
| Trigger Manager | `core/systems/trigger_manager.gd` |
| Campaign Manager | `core/systems/campaign_manager.gd` |
| Campaign Loader | `core/systems/campaign_loader.gd` |
| Material Spawn Data | `core/resources/material_spawn_data.gd` |
| Placeholder Tileset | `mods/_base_game/tilesets/terrain_placeholder.tres` |
| Example Map | `mods/_sandbox/maps/opening_game_map.tscn` |
| Battle Trigger Prefab | `mods/_base_game/triggers/battle_trigger.tscn` |

### Minimum Viable Town Checklist

**Required for production:**
- [ ] Scene with root Node2D extending map_template.gd (or town_map_template.gd)
- [ ] Scene exports: `map_id`, `map_type`, `display_name`
- [ ] TileMapLayer with walkable/blocked tiles
- [ ] SpawnPoints container with at least one default spawn
- [ ] Followers container (dynamically populated from PartyManager)
- [ ] MapCamera (follows hero)
- [ ] At least one door trigger to exit
- [ ] MapMetadata JSON file (simplified - runtime config only)
- [ ] Campaign node registration

**Scene exports (in your map script):**
```gdscript
@export var map_id: String = "your_mod:town_name"
@export_enum("TOWN", "OVERWORLD", "DUNGEON", "INTERIOR", "BATTLE") var map_type: String = "TOWN"
@export var display_name: String = "Town Name"
```

**For isolated testing (optional but recommended during development):**
- [ ] Placeholder Hero CharacterBody2D in "hero" group with HeroController
- [ ] Placeholder visual on Hero (ColorRect or Sprite2D)

Note: The placeholder Hero enables F5 testing of your scene without needing the full campaign context. In production gameplay, the hero will be spawned dynamically from PartyManager data.

### Systems Still In Development

As of this documentation, some systems are planned but not yet complete:

| System | Status | Notes |
|--------|--------|-------|
| Dynamic Hero Spawning | TODO | Hero should spawn from PartyManager, not scene placeholder |
| PartyManager → Exploration Integration | TODO | Party followers should use real CharacterData |
| NPC Component | Planned | Use custom Area2D with dialog triggers |
| Shop System | Planned | Use dialog-based workaround |
| Caravan System | Planned | Only for overworld maps |
| RandomEncounterZone | Planned | Only for overworld/dungeon maps |
| Material Spawn Instantiation | Phase 1 | Resource exists, visual spawners pending |

**Current transitional architecture:** The map template currently expects a Hero node in the scene (used as placeholder for testing). The TODO at `map_template.gd:219` indicates the intended future: the hero and followers should be dynamically spawned from `PartyManager` data when entering a map via `CampaignManager`.

---

*"Make it so, Number One. The town awaits its creation."*

*- Captain Obvious, USS Torvalds*
