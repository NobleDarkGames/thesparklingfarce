# Map System Implementation Plan

## Executive Summary

This document outlines the implementation plan for The Sparkling Farce's map exploration system, following the **SF2 Open World Model** as our foundational design decision. The system will support four distinct map types (Town, Overworld, Dungeon, Battle), a mobile Caravan system, seamless map transitions, and comprehensive modder support.

**Design Authority**: This plan follows the decisions established in `/docs/design/sf1_vs_sf2_world_map_analysis.md` - SF2's open world model with free exploration and backtracking, NOT SF1's linear chapter system.

---

## Current State Analysis

### Existing Infrastructure (What We Have)

The codebase already has a solid foundation for map exploration:

| Component | Location | Status | Notes |
|-----------|----------|--------|-------|
| HeroController | `scenes/map_exploration/hero_controller.gd` | Functional | Grid-based movement, tile history, interaction signals |
| PartyFollower | `scenes/map_exploration/party_follower.gd` | Functional | SF2-style chain following with tile history |
| MapCamera | `scenes/map_exploration/map_camera.gd` | Functional | Smooth follow with optional lookahead |
| MapTrigger | `core/components/map_trigger.gd` | Functional | 7 trigger types, flag conditions, one-shot support |
| TriggerManager | `core/systems/trigger_manager.gd` | Functional | Handles battle/dialog/door/transition triggers |
| CampaignManager | `core/systems/campaign_manager.gd` | Functional | Node-based progression, egress, encounter return |
| SceneManager | `core/systems/scene_manager.gd` | Functional | Fade transitions, scene path registry |
| GameState | `core/systems/game_state.gd` | Functional | Story flags, trigger completion, transition context |
| TransitionContext | `core/resources/transition_context.gd` | Functional | Position restoration after battles |
| MapTemplate | `mods/_base_game/maps/templates/map_template.gd` | Functional | Base template for map scenes |

### What's Missing (Gaps to Fill)

1. **No Map Type Classification System**: Maps don't declare their type (town/overworld/dungeon/battle)
2. **No Caravan System**: Mobile HQ concept not implemented
3. **No Map Connection Graph**: No system for defining how maps connect spatially
4. **No Spawn Point System**: Doors reference spawn points but they don't exist
5. **No Visual Scale Configuration**: No camera zoom or art-style markers per map type
6. **No Overworld-Specific Features**: No region-based map loading, no caravan visibility logic
7. **No Map Transition Animations**: Door/entrance transitions are instant scene changes

### Architecture Alignment Assessment

**Well-Aligned with SF2 Model:**
- CampaignManager already supports hub nodes and egress (Caravan return concept)
- TriggerManager's DOOR type handles scene transitions
- MapTrigger supports conditional activation (required/forbidden flags)
- Encounter system preserves position for exploration-battle-exploration loop

**Needs Enhancement:**
- CampaignNode's scene type needs map metadata (type, connections, caravan access)
- TriggerManager's DOOR handler lacks spawn point resolution
- No concept of "adjacent maps" for overworld exploration

---

## Map Type System

### Design Overview

Each map will declare its type via a new **MapMetadata** resource, providing:
- Map type classification
- Caravan visibility rules
- Visual scale settings
- Connection definitions
- Spawn point declarations

### MapType Enum

```gdscript
## Map types following SF2's categorical model
enum MapType {
    TOWN,       ## Detailed interior/building tilesets, no Caravan visible
    OVERWORLD,  ## Terrain-focused, Caravan visible and accessible
    DUNGEON,    ## Mix of styles, battle triggers common, Caravan optional
    BATTLE,     ## Tactical grid combat (separate from exploration)
    INTERIOR    ## Sub-locations within towns (shops, houses, churches)
}
```

### MapMetadata Architecture: Scene as Source of Truth

**Design Decision**: The scene file (`.tscn`) is the canonical source for visual/physical map elements. The JSON metadata provides runtime configuration only.

**Rationale**:
- Modders should drag SpawnPoints in the Godot editor, not calculate grid coordinates in JSON
- Eliminates duplication between scene nodes and JSON definitions
- Visual editing is the natural Godot workflow

**What lives in the scene** (via `@export` vars and nodes):
- `map_id: String` - Unique namespaced identifier
- `map_type: MapType` - TOWN, OVERWORLD, DUNGEON, etc.
- `display_name: String` - Human-readable name
- SpawnPoint nodes - Extracted automatically at load time
- MapTrigger (DOOR) nodes - Connections extracted automatically

**What lives in JSON** (runtime config only):
- `scene_path` - Required link to scene file
- `caravan_visible`, `caravan_accessible` - Behavioral flags
- `music_id`, `ambient_id` - Audio (placeholder for vertical mixing system)
- `random_encounters_enabled`, `save_anywhere` - Map behaviors
- `edge_connections` - Overworld map stitching

**Battle positions are separate**: BattleData defines `player_spawn_point` and `enemies[].position` independently of map SpawnPoints. The same scene can serve as both exploration map and battle arena.

### MapMetadata Resource

**File**: `core/resources/map_metadata.gd`

```gdscript
class_name MapMetadata
extends Resource

## Runtime-populated from scene @export or JSON
var map_id: String = ""
var display_name: String = ""
var map_type: MapType = MapType.TOWN

## Runtime configuration (from JSON)
@export var scene_path: String = ""
@export var caravan_accessible: bool = false
@export var caravan_visible: bool = false
@export_range(0.5, 2.0, 0.1) var camera_zoom: float = 1.0
@export var music_id: String = ""
@export var ambient_id: String = ""
@export var random_encounters_enabled: bool = false
@export var save_anywhere: bool = true

## Extracted from scene at load time (not stored in JSON)
var spawn_points: Dictionary = {}  # spawn_id -> {grid_position, facing, is_default}
var connections: Array[Dictionary] = []  # trigger_id, target info

## Overworld-specific (must be in JSON - cannot derive from scene)
@export var edge_connections: Dictionary = {}

## Populate spawn_points and connections from loaded scene
func populate_from_scene(scene_root: Node) -> void:
    # Extract SpawnPoints
    var found_spawns: Array = SpawnPoint.find_all_in_tree(scene_root)
    for spawn in found_spawns:
        spawn_points[spawn.spawn_id] = spawn.to_dict()

    # Extract DOOR triggers as connections
    _extract_door_connections(scene_root)

    # Extract identity from scene exports
    if scene_root.get("map_id"):
        map_id = scene_root.map_id
    if scene_root.get("display_name"):
        display_name = scene_root.display_name
    if scene_root.get("map_type") != null:
        map_type = scene_root.map_type
```

### Type-Specific Behaviors

| Feature | TOWN | OVERWORLD | DUNGEON | INTERIOR |
|---------|------|-----------|---------|----------|
| Caravan Visible | No | Yes | Optional | No |
| Caravan Accessible | No | Yes | Optional | No |
| Default Camera Zoom | 1.0 | 0.75-0.85 | 1.0 | 1.0 |
| Random Encounters | No | Yes | Yes | No |
| NPC Density | High | Low | Medium | High |
| Save Anywhere | Yes | Yes | Optional | Yes |

---

## Caravan System

### Design Overview

The Caravan is the player's mobile headquarters, inspired directly by SF2. It appears on overworld maps and provides:
- Party management (swap active/reserve members)
- Item storage access
- Rest/healing services
- Mobile save point

### Caravan Node Architecture

**File**: `core/components/caravan.gd`

```gdscript
class_name Caravan
extends CharacterBody2D

## Caravan follows the hero but stays N tiles behind
const FOLLOW_DISTANCE_TILES: int = 3

## The hero to follow
var follow_target: Node2D = null

## Is the caravan currently accessible (player can interact)?
var is_accessible: bool = true

## Grid position tracking (same pattern as PartyFollower)
var grid_position: Vector2i = Vector2i.ZERO
var target_tile: Vector2i = Vector2i.ZERO

## Caravan can cross rivers (SF2 mechanic)
var can_cross_water: bool = true

## Visual representation
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

signal interaction_requested()
signal party_management_opened()
signal storage_opened()
```

### Caravan Visibility Logic

The Caravan's visibility is managed by the map scene based on MapMetadata:

```gdscript
## In map scene _ready():
func _setup_caravan() -> void:
    var metadata: MapMetadata = _get_map_metadata()

    if metadata.caravan_visible:
        _spawn_caravan()
    else:
        _hide_caravan()

    if metadata.caravan_accessible:
        _enable_caravan_interaction()
```

### Caravan Services

| Service | Description | Implementation |
|---------|-------------|----------------|
| Party Swap | Switch active/reserve members | Opens PartyManager UI |
| Storage | Access item storage | Opens InventoryManager storage view |
| Rest | Heal party (costs gold in some modes) | Calls HealingService |
| Save | Save game progress | Opens SaveManager UI |

### Caravan Spawn Rules

1. **New Map Entry**: Caravan spawns at designated caravan_spawn point or 3 tiles behind hero
2. **Battle Return**: Caravan returns to pre-battle position
3. **Egress**: Caravan and party teleport to last hub's caravan_spawn point

---

## Map Transitions

### Transition Types

| Type | Trigger | Example | Animation |
|------|---------|---------|-----------|
| Door | MapTrigger.DOOR | Town entrance | Fade to black |
| Edge | Walking off map edge | Overworld region change | Scroll transition |
| Stairs | MapTrigger.TRANSITION + visual | Dungeon floor change | Fade + sound effect |
| Warp | MapTrigger.CUSTOM | Egress spell, teleporter | Flash effect |
| Battle | MapTrigger.BATTLE | Enemy encounter | Battle transition swirl |

### Enhanced Door Trigger Data

The existing DOOR trigger type will be enhanced:

```gdscript
## For DOOR triggers in MapTrigger.trigger_data:
{
    "target_map_id": "base_game:granseal_castle",  ## MapMetadata reference
    "target_spawn_id": "entrance_main",            ## Spawn point ID
    "transition_type": "fade",                     ## fade, instant, scroll
    "requires_key": "",                            ## Item ID if locked
    "one_way": false                               ## Can player return?
}
```

### Spawn Point System

**File**: `core/components/spawn_point.gd`

```gdscript
class_name SpawnPoint
extends Marker2D

## Unique identifier within this map
@export var spawn_id: String = ""

## Grid position (calculated from world position)
var grid_position: Vector2i:
    get:
        return GridManager.world_to_cell(global_position)

## Direction player should face when spawning
@export_enum("up", "down", "left", "right") var facing: String = "down"

## Is this the default spawn point for the map?
@export var is_default: bool = false

## Is this a caravan spawn point?
@export var is_caravan_spawn: bool = false
```

### Transition Flow

```
Player enters DOOR trigger
    |
    v
TriggerManager._handle_door_trigger()
    |
    +-- Look up target MapMetadata by target_map_id
    +-- Store current hero position in TransitionContext
    +-- Store target_spawn_id in TransitionContext
    |
    v
SceneManager.change_scene(target_map.scene_path)
    |
    v
New map scene _ready()
    |
    +-- Check TransitionContext for spawn_id
    +-- Find SpawnPoint node with matching spawn_id
    +-- Teleport hero to spawn_point.grid_position
    +-- Set hero.facing_direction
    +-- Spawn Caravan if caravan_visible
    +-- Clear TransitionContext
```

### Edge Transition (Overworld)

For seamless overworld navigation, maps can define edge connections:

```gdscript
## In MapMetadata.connections:
[
    {
        "edge": "north",                        ## Which map edge
        "target_map_id": "base_game:grans_north",
        "target_spawn_id": "south_edge",
        "overlap_tiles": 1                       ## SF2-style 1-tile overlap
    }
]
```

---

## Visual Scale Handling

### Design Decision: Camera Zoom + Art Direction

Following the SF2 analysis, we'll achieve the "zoomed out" overworld feel through:

1. **Camera Zoom**: Configurable per-map via MapMetadata.camera_zoom
2. **Art Direction**: Overworld tilesets use abstract, terrain-focused art
3. **Multi-tile Features**: Mountains/forests as 2x2 or 3x3 tile groups

### Camera Zoom Implementation

**Enhancement to MapCamera** (`scenes/map_exploration/map_camera.gd`):

```gdscript
## Target zoom level (from MapMetadata)
var target_zoom: float = 1.0

## Current zoom (for smooth transitions)
var current_zoom: float = 1.0

## Zoom transition speed
const ZOOM_LERP_SPEED: float = 3.0

func set_map_zoom(zoom_level: float) -> void:
    target_zoom = clampf(zoom_level, 0.5, 2.0)

func _process(delta: float) -> void:
    # ... existing follow logic ...

    # Smooth zoom transition
    if not is_equal_approx(current_zoom, target_zoom):
        current_zoom = lerpf(current_zoom, target_zoom, ZOOM_LERP_SPEED * delta)
        zoom = Vector2(current_zoom, current_zoom)
```

### Recommended Zoom Levels

| Map Type | Recommended Zoom | Visual Effect |
|----------|------------------|---------------|
| TOWN | 1.0 | Standard detail view |
| INTERIOR | 1.0 - 1.2 | Close-up for indoor areas |
| OVERWORLD | 0.75 - 0.85 | "Zoomed out" world map feel |
| DUNGEON | 0.9 - 1.0 | Slightly wider for tactical awareness |

### Tileset Art Guidelines

Document for modders specifying art style differences:

**Town/Interior Tiles:**
- High detail (individual stones, wood grain)
- 1:1 scale representation
- Rich color palettes

**Overworld Tiles:**
- Abstract terrain representation
- Single tile = larger geographic area
- Simplified patterns
- Multi-tile terrain features (hills: 3x3, mountains: 2x2 blocks)

---

## Battle Triggers

### Current Implementation

The existing MapTrigger.BATTLE type works well:

```gdscript
trigger_type = TriggerType.BATTLE
trigger_data = {"battle_id": "battle_resource_id"}
```

TriggerManager handles:
1. Looking up BattleData from ModLoader.registry
2. Storing return data in GameState
3. Transitioning to battle_loader scene

### Enhancements Needed

#### 1. Encounter vs Story Battle Distinction

```gdscript
## In trigger_data:
{
    "battle_id": "ambush_001",
    "is_encounter": true,           ## Position-preserving encounter
    "defeat_behavior": "retry",     ## retry, game_over, continue
    "pre_battle_dialog": "",        ## Optional dialog before battle
    "post_victory_dialog": ""       ## Optional dialog after victory
}
```

#### 2. Random Encounter System

New component for overworld/dungeon maps:

**File**: `core/components/random_encounter_zone.gd`

```gdscript
class_name RandomEncounterZone
extends Area2D

## Encounter table: battle_id -> weight
@export var encounter_table: Dictionary = {}

## Steps between encounter checks
@export var steps_per_check: int = 10

## Base encounter rate (0.0 - 1.0)
@export_range(0.0, 1.0) var base_encounter_rate: float = 0.1

## Encounter rate modifier based on terrain type
@export var terrain_modifiers: Dictionary = {}

## Current step counter
var _step_count: int = 0

func _on_hero_moved(tile_pos: Vector2i) -> void:
    _step_count += 1
    if _step_count >= steps_per_check:
        _step_count = 0
        _check_encounter()

func _check_encounter() -> void:
    var roll: float = randf()
    var effective_rate: float = _calculate_effective_rate()

    if roll < effective_rate:
        var battle_id: String = _select_random_battle()
        CampaignManager.trigger_encounter(battle_id, _get_hero_position())
```

#### 3. Trigger Visualization (Editor Tool)

For modders to see trigger zones in the editor:

```gdscript
## In MapTrigger, add @tool and _draw():
@tool
class_name MapTrigger

func _draw() -> void:
    if not Engine.is_editor_hint():
        return

    var color: Color = _get_debug_color()
    # Draw trigger area visualization
```

---

## Modder Support

### Map Creation Workflow

1. **Create MapMetadata Resource**
   - Define map_id, display_name, map_type
   - Set caravan_visible and caravan_accessible
   - Configure camera_zoom

2. **Create Map Scene**
   - Extend MapTemplate or create from scratch
   - Add TileMapLayer with appropriate tileset
   - Add SpawnPoint nodes with unique spawn_ids
   - Add MapTrigger nodes for doors/battles/etc.

3. **Register in mod.json**
   - Add scene path to scenes registry
   - Declare map in provides section

4. **Connect to Campaign**
   - Add as CampaignNode with node_type: "scene"
   - Define transitions (on_complete, branches)

### Example Map Scene Structure

```
MyTownMap (Node2D)
  +-- TileMapLayer (terrain, walkability)
  +-- Hero (CharacterBody2D with HeroController)
  +-- MapCamera (Camera2D with MapCamera script)
  +-- Followers (Node2D container)
  +-- SpawnPoints (Node2D container)
  |     +-- entrance_main (SpawnPoint, is_default: true)
  |     +-- from_castle (SpawnPoint)
  |     +-- from_shop (SpawnPoint)
  +-- Triggers (Node2D container)
  |     +-- CastleDoor (MapTrigger, type: DOOR)
  |     +-- ShopDoor (MapTrigger, type: DOOR)
  |     +-- NPCTalk (MapTrigger, type: DIALOG)
  +-- NPCs (Node2D container)
  +-- Decorations (Node2D container)
```

### MapMetadata JSON Format (Simplified)

With scene-as-truth, the JSON is now minimal - runtime configuration only:

```json
{
  "scene_path": "res://mods/my_mod/maps/hometown.tscn",
  "caravan_visible": false,
  "caravan_accessible": false,
  "camera_zoom": 1.0,
  "music_id": "town_theme_01",
  "ambient_id": "",
  "random_encounters_enabled": false,
  "save_anywhere": true
}
```

**What's NOT in JSON anymore** (extracted from scene):
- `map_id` - Scene export `@export var map_id: String`
- `display_name` - Scene export `@export var display_name: String`
- `map_type` - Scene export `@export var map_type: MapType`
- `spawn_points` - Extracted from SpawnPoint nodes in scene
- `connections` - Extracted from MapTrigger DOOR nodes in scene

**Exception - edge_connections** (overworld only):
```json
{
  "scene_path": "res://mods/my_mod/maps/overworld_south.tscn",
  "caravan_visible": true,
  "caravan_accessible": true,
  "random_encounters_enabled": true,
  "edge_connections": {
    "north": {
      "target_map_id": "my_mod:overworld_central",
      "target_spawn_id": "south_edge",
      "overlap_tiles": 1
    }
  }
}
```
Edge connections cannot be derived from scene geometry, so they remain in JSON.

### CampaignNode Scene Type Enhancement

The existing scene node type will be enhanced to reference MapMetadata:

```json
{
  "node_id": "hometown_hub",
  "display_name": "Hometown",
  "node_type": "scene",
  "map_id": "my_mod:hometown",
  "is_hub": true,
  "completion_trigger": "exit_trigger",
  "on_complete": "overworld_exploration"
}
```

---

## Phased Implementation

### Phase 1: Map Metadata Foundation (Week 1)

**Objective**: Establish map classification system without breaking existing functionality

**Tasks**:
1. Create `MapMetadata` resource class
2. Create `SpawnPoint` component
3. Add spawn point resolution to TriggerManager DOOR handler
4. Update TransitionContext to include spawn_point_id
5. Create map metadata loader in ModLoader

**Testing**:
- Unit tests for MapMetadata validation
- Integration test: DOOR trigger with spawn point resolution
- Manual test: Town-to-town transition with correct positioning

**Dependencies**: None (builds on existing TriggerManager)

---

### Phase 2: Camera Zoom System (Week 1-2)

**Objective**: Enable visual scale differentiation between map types

**Tasks**:
1. Enhance MapCamera with zoom property and smooth transitions
2. Add camera_zoom configuration to MapMetadata
3. Update map scene initialization to apply zoom from metadata
4. Create zoom transition effects for map changes

**Testing**:
- Unit test: Camera zoom lerp behavior
- Manual test: Transition from zoom=1.0 map to zoom=0.8 map

**Dependencies**: Phase 1 (MapMetadata)

---

### Phase 3: Caravan System Core (Week 2-3)

**Objective**: Implement mobile headquarters for overworld maps

**Tasks**:
1. Create Caravan component with movement/follow logic
2. Implement caravan visibility toggle based on map type
3. Create CaravanService for party management access
4. Add caravan_spawn points to spawn point system
5. Handle caravan persistence across map transitions

**Testing**:
- Unit tests for Caravan follow behavior
- Integration test: Caravan appears on overworld, hidden in town
- Manual test: Full flow - town -> overworld (caravan appears) -> battle -> return

**Dependencies**: Phase 1 (MapMetadata, SpawnPoints)

---

### Phase 4: Enhanced Transitions (Week 3-4)

**Objective**: Polish map transition experience

**Tasks**:
1. Implement edge detection for overworld map connections
2. Add transition animation variants (fade, scroll, warp)
3. Create door/entrance sound effects hooks
4. Add locked door handling with key item checks
5. Implement one-way door support

**Testing**:
- Unit tests for edge transition detection
- Integration test: Scroll transition between adjacent overworld maps
- Manual test: Locked door with key requirement

**Dependencies**: Phase 1-3

---

### Phase 5: Random Encounters (Week 4-5)

**Objective**: Enable overworld/dungeon random battles

**Tasks**:
1. Create RandomEncounterZone component
2. Implement encounter rate calculation with terrain modifiers
3. Create encounter table weighting system
4. Add flee/avoid encounter mechanics (optional)
5. Integrate with existing encounter return system

**Testing**:
- Unit tests for encounter rate calculation
- Integration test: Random encounter triggers battle, returns to position
- Manual test: Extended overworld exploration with random battles

**Dependencies**: Phase 1, existing CampaignManager.trigger_encounter()

---

### Phase 6: Modder Tools & Documentation (Week 5-6)

**Objective**: Enable content creators to easily build maps

**Tasks**:
1. Create MapMetadata editor plugin for visual editing
2. Add trigger visualization in editor (@tool)
3. Create spawn point gizmos for positioning
4. Write comprehensive modder documentation
5. Create example maps demonstrating each map type
6. Add map validation tool (checks connections, spawn points)

**Testing**:
- Manual test: Create complete town map using only editor tools
- Manual test: Create overworld region with connections
- Documentation review by external party

**Dependencies**: Phases 1-5

---

## Risk Assessment

### High Risk

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking existing CampaignManager flow | Core gameplay broken | Maintain backward compatibility, add new fields as optional |
| Performance with large overworld maps | Stuttering, long loads | Implement region-based loading, lazy spawn point resolution |

### Medium Risk

| Risk | Impact | Mitigation |
|------|--------|------------|
| Caravan position edge cases | Stuck caravan, visual glitches | Extensive position validation, fallback spawn logic |
| Transition context lost on crash | Player stuck in wrong location | Add recovery mechanism using last known good position |

### Low Risk

| Risk | Impact | Mitigation |
|------|--------|------------|
| Zoom causing visual artifacts | Minor visual issues | Provide recommended zoom ranges, test with various tilesets |
| Random encounter frustration | Player annoyance | Add encounter rate configuration, "repel" item type |

---

## Integration Points

### Systems That Need Updates

1. **TriggerManager**: Enhanced DOOR handling with spawn points
2. **CampaignManager**: Map metadata resolution for scene nodes
3. **SceneManager**: Transition animation variants
4. **MapCamera**: Zoom control and smooth transitions
5. **ModLoader**: MapMetadata resource discovery
6. **SaveManager**: Caravan position persistence

### New Systems Required

1. **Caravan**: Mobile headquarters component
2. **SpawnPoint**: Map spawn location marker
3. **MapMetadata**: Map configuration resource
4. **RandomEncounterZone**: Overworld encounter areas

### Signal Additions

```gdscript
## CampaignManager
signal map_entered(map_metadata: MapMetadata)
signal map_exited(map_metadata: MapMetadata)

## Caravan
signal caravan_interaction_started()
signal caravan_interaction_ended()
signal party_swap_requested()

## TriggerManager
signal door_transition_started(from_map: String, to_map: String)
signal door_transition_completed(spawn_point: SpawnPoint)
```

---

## File Structure

```
core/
  resources/
    map_metadata.gd          # NEW: Map configuration resource
  components/
    spawn_point.gd           # NEW: Spawn location marker
    caravan.gd               # NEW: Mobile headquarters
    random_encounter_zone.gd # NEW: Encounter area

scenes/
  map_exploration/
    hero_controller.gd       # EXISTS: Minor updates for caravan interaction
    party_follower.gd        # EXISTS: No changes needed
    map_camera.gd            # EXISTS: Add zoom functionality
    caravan.tscn             # NEW: Caravan scene template

mods/_base_game/
  maps/
    templates/
      map_template.gd        # EXISTS: Add spawn point/caravan logic
      town_template.tscn     # NEW: Town map template
      overworld_template.tscn # NEW: Overworld map template
      dungeon_template.tscn  # NEW: Dungeon map template
    example_town/            # NEW: Example town implementation
    example_overworld/       # NEW: Example overworld region

docs/
  modding/
    map_creation_guide.md    # NEW: Comprehensive modder guide
```

---

## Success Criteria

### Phase 1 Complete When:
- [ ] MapMetadata resource can be created and validated
- [ ] SpawnPoints resolve correctly on scene load
- [ ] DOOR triggers use spawn point positioning

### Phase 3 Complete When:
- [ ] Caravan appears on overworld maps only
- [ ] Caravan can be interacted with to open party management
- [ ] Caravan position persists through battle transitions

### Phase 6 Complete When:
- [ ] Modder can create a complete town map in under 30 minutes
- [ ] Modder can connect multiple overworld regions
- [ ] All example maps pass validation
- [ ] Documentation covers all map types and features

---

## Appendix: SF2 Reference Data

### SF2 Map Counts (Reference)
- Total maps: ~78
- Overworld regions: ~12
- All maps: 64x64 tiles
- Overworld overlap: 1 tile at borders

### SF2 Caravan Behavior
- Follows on overworld only
- Stops at town entrances (doesn't enter)
- Can cross rivers (special terrain)
- Provides: Party swap, storage, save, healing

---

*Document prepared by Lt. Claudbrain, USS Torvalds*
*Stardate 2025.333 (November 29, 2025)*
*"The needs of the many outweigh the needs of the few... but good architecture serves both."*
