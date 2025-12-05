# Terrain Effects for Battle Movement System

**Status:** ✅ IMPLEMENTED (75% - Core Complete, Minor Features Deferred)
**Priority:** High - Core tactical gameplay feature
**Dependencies:** None (builds on existing GridManager and movement systems)
**Estimated Effort:** 15-20 hours
**Plan Created:** December 2, 2025
**Implemented:** December 2025
**Authors:** Lt. Claudbrain

---

## Implementation Status (Verified December 5, 2025)

| Component | Status | Notes |
|-----------|--------|-------|
| TerrainData resource class | ✅ Complete | All properties defined in `core/resources/terrain_data.gd` |
| TerrainRegistry | ✅ Complete | Integrated with ModLoader, source tracking |
| GridManager terrain caching | ✅ Complete | `load_terrain_data()`, `get_terrain_at_cell()` |
| GridManager terrain costs | ✅ Complete | `get_terrain_cost()` uses actual TerrainData |
| Movement passability | ✅ Complete | Per-movement-type impassable flags |
| Defense/Evasion bonuses | ✅ Complete | Applied in CombatCalculator for attack AND counter |
| Damage per turn | ✅ Complete | Processed at turn start, flying units immune |
| TileSet custom data | ✅ Complete | "terrain_type" layer in terrain_placeholder.tres |
| Base game terrain content | ✅ Complete | 10+ terrain types in `mods/_base_game/data/terrain/` |
| TerrainInfoPanel UI | ✅ Complete | Shows all active effects dynamically |
| **healing_per_turn** | ⚠️ Deferred | Field exists, processing not implemented |
| **status_effect_on_entry** | ⚠️ Deferred | Field exists, processing not implemented |
| **footstep_sound** | ⚠️ Deferred | Field exists, not connected to audio |
| **walk_particle** | ⚠️ Deferred | Field exists, not instantiated |

---

## Executive Summary

This plan details the implementation of a comprehensive terrain effects system for The Sparkling Farce's tactical battle mode. The system will provide Shining Force-authentic terrain interactions including movement cost modifiers, defensive bonuses, damage-over-time effects, healing zones, status effect application, and movement type restrictions (ground/floating/flying).

Captain, what we have here is a solid foundation that needs the tactical depth that makes Shining Force battles meaningful. The current implementation has the scaffolding - now we need to add the substance.

---

## Current State Analysis

### What Exists

#### 1. Movement Types in ClassData (`core/resources/class_data.gd`)
```gdscript
enum MovementType {
    WALKING,    ## Ground movement only, affected by terrain
    FLYING,     ## Can fly over obstacles, ignores terrain penalties
    FLOATING    ## Hovers over terrain, some terrain penalties
}
```
**Assessment:** The enum exists and is exported, but is not meaningfully consumed by the terrain system.

#### 2. Terrain Cost Infrastructure in GridManager (`core/systems/grid_manager.gd`)
- `_terrain_costs: Dictionary` - Exists but is never populated
- `set_terrain_cost(tile_id, movement_type, cost)` - Exists but is never called
- `get_terrain_cost(cell, movement_type)` - Returns DEFAULT_TERRAIN_COST (1) always
- Pathfinding respects terrain costs via `_update_astar_weights()`

**Assessment:** The cost infrastructure is present but dormant. No terrain data is actually loaded.

#### 3. TerrainInfoPanel (`scenes/ui/terrain_info_panel.gd`)
- Hardcoded terrain names and effects dictionaries
- `_get_terrain_type_at_cell()` returns 0 (Plains) always
- TODO comment mentions integrating with GridManager

**Assessment:** Pure placeholder - needs complete rewrite to use actual terrain data.

#### 4. TileSet (`mods/_base_game/tilesets/terrain_placeholder.tres`)
- 9 tile sources: grass, wall, water, road, forest, mountain, sand, bridge, dirt
- Physics layers defined for wall, water, mountain (collision)
- **NO custom data layers** for terrain type or effects

**Assessment:** Visual assets exist, but no terrain metadata is attached to tiles.

### What Is Missing

| Feature | Current State | Required |
|---------|--------------|----------|
| Terrain Type Custom Data | Not present | Add to TileSet |
| TerrainData Resource | Does not exist | Create new resource class |
| Terrain Registry | Does not exist | Create for mod extensibility |
| Defense/Evasion Bonuses | Hardcoded placeholders | Dynamic from TerrainData |
| Damage Over Time (DoT) | Not implemented | Process at turn start |
| Healing Terrain | Not implemented | Process at turn start |
| Status Effect Application | Stub only | Apply based on terrain |
| Flying Unit Movement | Ignored | Skip terrain costs entirely |
| Floating Unit Movement | Ignored | Partial terrain cost reduction |
| Terrain Cost Loading | Not implemented | Load from TileSet custom data |

---

## Design Goals

### 1. Shining Force Authenticity
Terrain effects should feel like Shining Force 1 & 2:
- Forests provide defense bonuses and slow ground units
- Water is impassable to ground units, free for flying
- Mountains provide high defense but heavily slow movement
- Roads provide no bonus but cost less to traverse
- Lava/poison swamps deal damage each turn

### 2. Mod Extensibility
Following the "game is just a mod" philosophy:
- Terrain types defined in mod data, not hardcoded
- TerrainData resources loadable via ModLoader
- New terrain types addable without engine changes
- Mods can override base terrain definitions

### 3. Performance Considerations
- Terrain lookups occur frequently (pathfinding, movement)
- Cache terrain data per-map on battle start
- Avoid repeated TileData lookups during pathfinding

### 4. Clear Trigger Points
Effects must trigger at well-defined moments:
- **Movement cost:** During pathfinding and movement
- **Defense/Evasion bonus:** During combat resolution
- **Damage/Healing:** At turn start (before movement)
- **Status effects:** On cell entry

---

## Technical Architecture

### New Resource: TerrainData

```gdscript
# core/resources/terrain_data.gd
class_name TerrainData
extends Resource

## Unique identifier for this terrain type (e.g., "forest", "lava")
@export var terrain_id: String = ""

## Display name shown in UI
@export var display_name: String = ""

## Icon for UI display (optional)
@export var icon: Texture2D = null

@export_group("Movement")
## Base movement cost for ground units (1 = normal, 2 = double cost)
@export_range(1, 99) var movement_cost_walking: int = 1
## Movement cost for floating units (typically less than walking)
@export_range(1, 99) var movement_cost_floating: int = 1
## Movement cost for flying units (always 1 unless completely impassable)
@export_range(1, 99) var movement_cost_flying: int = 1
## If true, ground units cannot enter at all
@export var impassable_walking: bool = false
## If true, floating units cannot enter
@export var impassable_floating: bool = false
## If true, flying units cannot enter (rare - anti-air zones, ceilings)
@export var impassable_flying: bool = false

@export_group("Combat Modifiers")
## Defense bonus when standing on this terrain (0-10)
@export_range(0, 10) var defense_bonus: int = 0
## Evasion bonus percentage (0-50%)
@export_range(0, 50) var evasion_bonus: int = 0

@export_group("Turn Effects")
## Damage dealt at start of turn (0 = none, positive = damage)
@export var damage_per_turn: int = 0
## Healing at start of turn (0 = none, positive = heal)
@export var healing_per_turn: int = 0
## Status effect applied on entry (empty = none)
@export var status_effect_on_entry: String = ""
## Duration of applied status effect (turns)
@export_range(1, 10) var status_effect_duration: int = 1

@export_group("Visual/Audio")
## Footstep sound override for this terrain
@export var footstep_sound: String = ""
## Particle effect when walking on terrain (future)
@export var walk_particle: PackedScene = null


## Get movement cost for a specific movement type
func get_movement_cost(movement_type: int) -> int:
    match movement_type:
        ClassData.MovementType.WALKING:
            if impassable_walking:
                return 99  # GridManager.MAX_TERRAIN_COST
            return movement_cost_walking
        ClassData.MovementType.FLOATING:
            if impassable_floating:
                return 99
            return movement_cost_floating
        ClassData.MovementType.FLYING:
            if impassable_flying:
                return 99
            return movement_cost_flying
        _:
            return movement_cost_walking  # Default to walking


## Check if passable for a movement type
func is_passable(movement_type: int) -> bool:
    match movement_type:
        ClassData.MovementType.WALKING:
            return not impassable_walking
        ClassData.MovementType.FLOATING:
            return not impassable_floating
        ClassData.MovementType.FLYING:
            return not impassable_flying
        _:
            return not impassable_walking


## Validate resource
func validate() -> bool:
    if terrain_id.is_empty():
        push_error("TerrainData: terrain_id is required")
        return false
    return true
```

### New Registry: TerrainRegistry

```gdscript
# core/registries/terrain_registry.gd
class_name TerrainRegistry
extends RefCounted

## Registry for terrain types.
## Allows mods to define custom terrain beyond the defaults.
##
## Default terrain types: plains, forest, mountain, water, road, sand, bridge, lava
##
## Mods register terrain via:
## 1. TerrainData .tres files in mods/*/data/terrain/
## 2. Terrain type entries in mod.json custom_terrain_types array

# Default terrain that is always available (fallback if no data found)
const DEFAULT_TERRAIN: Dictionary = {
    "plains": {"display_name": "Plains", "movement_cost_walking": 1, "defense_bonus": 0},
    "forest": {"display_name": "Forest", "movement_cost_walking": 2, "defense_bonus": 1},
    "mountain": {"display_name": "Mountain", "movement_cost_walking": 3, "defense_bonus": 2, "impassable_floating": false},
    "water": {"display_name": "Water", "impassable_walking": true, "impassable_floating": false, "movement_cost_flying": 1},
    "road": {"display_name": "Road", "movement_cost_walking": 1, "defense_bonus": 0},
    "sand": {"display_name": "Sand", "movement_cost_walking": 2, "defense_bonus": 0},
    "bridge": {"display_name": "Bridge", "movement_cost_walking": 1, "defense_bonus": 0},
    "lava": {"display_name": "Lava", "impassable_walking": true, "impassable_floating": true, "movement_cost_flying": 1, "damage_per_turn": 5},
    "wall": {"display_name": "Wall", "impassable_walking": true, "impassable_floating": true, "impassable_flying": true},
}

# Registered TerrainData resources: terrain_id -> TerrainData
var _terrain_data: Dictionary = {}

# Source tracking: terrain_id -> mod_id
var _terrain_sources: Dictionary = {}


## Register a TerrainData resource from a mod
func register_terrain(terrain: TerrainData, mod_id: String) -> void:
    if not terrain or terrain.terrain_id.is_empty():
        push_warning("TerrainRegistry: Cannot register invalid terrain")
        return

    _terrain_data[terrain.terrain_id] = terrain
    _terrain_sources[terrain.terrain_id] = mod_id


## Get TerrainData by ID (returns generated default if not found)
func get_terrain(terrain_id: String) -> TerrainData:
    if terrain_id in _terrain_data:
        return _terrain_data[terrain_id]

    # Generate from defaults if available
    if terrain_id in DEFAULT_TERRAIN:
        return _create_default_terrain(terrain_id)

    # Fallback to plains
    push_warning("TerrainRegistry: Unknown terrain '%s', using plains" % terrain_id)
    return _create_default_terrain("plains")


## Check if terrain type exists
func has_terrain(terrain_id: String) -> bool:
    return terrain_id in _terrain_data or terrain_id in DEFAULT_TERRAIN


## Get all registered terrain IDs
func get_all_terrain_ids() -> Array[String]:
    var ids: Array[String] = []
    for id: String in _terrain_data.keys():
        ids.append(id)
    for id: String in DEFAULT_TERRAIN.keys():
        if id not in ids:
            ids.append(id)
    return ids


## Get which mod registered a terrain (or "base" for defaults)
func get_terrain_source(terrain_id: String) -> String:
    if terrain_id in _terrain_sources:
        return _terrain_sources[terrain_id]
    if terrain_id in DEFAULT_TERRAIN:
        return "base"
    return ""


## Clear all mod registrations
func clear_mod_registrations() -> void:
    _terrain_data.clear()
    _terrain_sources.clear()


## Create TerrainData from default dictionary
func _create_default_terrain(terrain_id: String) -> TerrainData:
    var data: TerrainData = TerrainData.new()
    data.terrain_id = terrain_id

    var defaults: Dictionary = DEFAULT_TERRAIN.get(terrain_id, {})
    data.display_name = defaults.get("display_name", terrain_id.capitalize())
    data.movement_cost_walking = defaults.get("movement_cost_walking", 1)
    data.movement_cost_floating = defaults.get("movement_cost_floating", 1)
    data.movement_cost_flying = defaults.get("movement_cost_flying", 1)
    data.impassable_walking = defaults.get("impassable_walking", false)
    data.impassable_floating = defaults.get("impassable_floating", false)
    data.impassable_flying = defaults.get("impassable_flying", false)
    data.defense_bonus = defaults.get("defense_bonus", 0)
    data.evasion_bonus = defaults.get("evasion_bonus", 0)
    data.damage_per_turn = defaults.get("damage_per_turn", 0)
    data.healing_per_turn = defaults.get("healing_per_turn", 0)

    return data
```

### TileSet Custom Data Layer

Add a custom data layer to terrain tilesets:

| Layer Name | Type | Purpose |
|------------|------|---------|
| `terrain_type` | String | ID matching TerrainData (e.g., "forest", "water") |

This is configured in the TileSet editor and allows each tile to specify which TerrainData applies.

### GridManager Terrain Integration

Modify `GridManager` to load terrain data and apply it:

```gdscript
# Additions to core/systems/grid_manager.gd

## Cached terrain data for current map: {Vector2i: TerrainData}
var _cell_terrain_cache: Dictionary = {}

## Reference to terrain registry
var terrain_registry: RefCounted = null  # Set by ModLoader


## Initialize terrain data for the current map
## Call this after setup_grid() and before any pathfinding
func load_terrain_data() -> void:
    _cell_terrain_cache.clear()

    if not tilemap or not tilemap.tile_set:
        return

    # Check if tileset has terrain_type custom data
    var has_terrain_data: bool = _tileset_has_terrain_type()
    if not has_terrain_data:
        push_warning("GridManager: TileSet has no 'terrain_type' custom data layer")
        return

    # Cache terrain data for each cell
    for x in range(grid.grid_size.x):
        for y in range(grid.grid_size.y):
            var cell: Vector2i = Vector2i(x, y)
            var terrain_id: String = _get_terrain_id_at_cell(cell)
            if not terrain_id.is_empty():
                var terrain: TerrainData = terrain_registry.get_terrain(terrain_id)
                _cell_terrain_cache[cell] = terrain


## Check if tileset has terrain_type custom data layer
func _tileset_has_terrain_type() -> bool:
    if not tilemap or not tilemap.tile_set:
        return false

    var custom_data_count: int = tilemap.tile_set.get_custom_data_layers_count()
    for i in range(custom_data_count):
        if tilemap.tile_set.get_custom_data_layer_name(i) == "terrain_type":
            return true
    return false


## Get terrain ID from tile custom data
func _get_terrain_id_at_cell(cell: Vector2i) -> String:
    if not tilemap:
        return ""

    var tile_data: TileData = tilemap.get_cell_tile_data(cell)
    if tile_data == null:
        return ""

    var terrain_type: Variant = tile_data.get_custom_data("terrain_type")
    if terrain_type is String:
        return terrain_type
    return ""


## Get TerrainData at a cell (cached)
func get_terrain_at_cell(cell: Vector2i) -> TerrainData:
    if cell in _cell_terrain_cache:
        return _cell_terrain_cache[cell]
    return terrain_registry.get_terrain("plains")  # Default fallback


## UPDATED: Get terrain cost using TerrainData
func get_terrain_cost(cell: Vector2i, movement_type: int) -> int:
    if not grid.is_within_bounds(cell):
        return MAX_TERRAIN_COST

    var terrain: TerrainData = get_terrain_at_cell(cell)
    return terrain.get_movement_cost(movement_type)
```

### CombatCalculator Terrain Modifiers

Add terrain-based defense and evasion to combat:

```gdscript
# Additions to core/systems/combat_calculator.gd

## Calculate hit chance with terrain evasion bonus
## Formula: Base 80% + (AGI diff * 2) - terrain_evasion
static func calculate_hit_chance_with_terrain(
    attacker_stats: UnitStats,
    defender_stats: UnitStats,
    terrain_evasion_bonus: int
) -> int:
    var base_hit: int = calculate_hit_chance(attacker_stats, defender_stats)
    return clampi(base_hit - terrain_evasion_bonus, 10, 99)


## Calculate effective defense with terrain bonus
static func get_effective_defense_with_terrain(
    defender_stats: UnitStats,
    terrain_defense_bonus: int
) -> int:
    return defender_stats.get_effective_defense() + terrain_defense_bonus
```

### TurnManager Terrain Effects

Process terrain DoT/healing at turn start:

```gdscript
# Additions to core/systems/turn_manager.gd

## Process terrain effects for a unit at turn start
## Called before unit can move
func _process_terrain_effects(unit: Node2D) -> void:
    var terrain: TerrainData = GridManager.get_terrain_at_cell(unit.grid_position)
    if terrain == null:
        return

    # Flying units ignore ground-based terrain effects
    if unit.character_data and unit.character_data.character_class:
        var movement_type: int = unit.character_data.character_class.movement_type
        if movement_type == ClassData.MovementType.FLYING:
            return  # No terrain effects for flying units

    # Apply damage
    if terrain.damage_per_turn > 0:
        unit.take_damage(terrain.damage_per_turn)
        # TODO: Show terrain damage popup

    # Apply healing
    if terrain.healing_per_turn > 0:
        unit.heal(terrain.healing_per_turn)
        # TODO: Show terrain healing popup

    # Apply status effect if not already present
    if not terrain.status_effect_on_entry.is_empty():
        if not unit.has_status_effect(terrain.status_effect_on_entry):
            unit.add_status_effect(
                terrain.status_effect_on_entry,
                terrain.status_effect_duration
            )
```

### TerrainInfoPanel Update

Rewrite to use actual terrain data:

```gdscript
# Updated scenes/ui/terrain_info_panel.gd

func show_terrain_info(unit_cell: Vector2i) -> void:
    # Kill any existing tween
    if _current_tween and _current_tween.is_valid():
        _current_tween.kill()
        _current_tween = null

    # Get terrain data from GridManager
    var terrain: TerrainData = GridManager.get_terrain_at_cell(unit_cell)

    # Update labels
    terrain_name_label.text = terrain.display_name
    terrain_effect_label.text = _format_terrain_effects(terrain)

    # Animate in
    visible = true
    modulate.a = 0.0
    _current_tween = create_tween()
    _current_tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _format_terrain_effects(terrain: TerrainData) -> String:
    var effects: Array[String] = []

    if terrain.defense_bonus > 0:
        effects.append("DEF +%d" % terrain.defense_bonus)

    if terrain.evasion_bonus > 0:
        effects.append("EVA +%d%%" % terrain.evasion_bonus)

    if terrain.damage_per_turn > 0:
        effects.append("DMG %d/turn" % terrain.damage_per_turn)

    if terrain.healing_per_turn > 0:
        effects.append("HEAL %d/turn" % terrain.healing_per_turn)

    if terrain.movement_cost_walking > 1:
        effects.append("MOV x%d" % terrain.movement_cost_walking)

    if terrain.impassable_walking:
        effects.append("Ground: Blocked")

    if effects.is_empty():
        return "No effect"

    return ", ".join(effects)
```

---

## Flying and Floating Unit Behavior

### Flying Units (e.g., Bird Knights, Dragons)
- **Movement cost:** Always 1 regardless of terrain (except impassable_flying zones)
- **Terrain effects:** IMMUNE to damage_per_turn, healing_per_turn, status_effect_on_entry
- **Defense/Evasion:** DO receive terrain defense/evasion bonuses (they're still standing there during combat)
- **Water:** Passable, cost 1
- **Lava:** Passable, cost 1, no damage
- **Walls/Ceilings:** Impassable (only blocked by impassable_flying)

### Floating Units (e.g., Ghosts, Hover Tanks)
- **Movement cost:** Uses movement_cost_floating (typically less than walking but more than flying)
- **Terrain effects:** IMMUNE to movement-based status effects (mud slow) but NOT damage
- **Water:** Passable
- **Lava:** Takes damage (floating too close to heat)
- **Defensive bonuses:** Receive full terrain defense/evasion

### Ground Units (e.g., Knights, Infantry)
- **Movement cost:** Uses movement_cost_walking (full terrain cost)
- **Terrain effects:** Subject to all effects
- **Water:** Impassable unless bridge
- **Defensive bonuses:** Full effect

---

## Mod System Integration

### ModLoader Changes

Add terrain loading to `ModLoader._load_mod()`:

```gdscript
# In core/mod_system/mod_loader.gd

# Add to RESOURCE_TYPE_DIRS
const RESOURCE_TYPE_DIRS: Dictionary = {
    # ... existing entries ...
    "terrain": "terrain"  # NEW: mods/*/data/terrain/*.tres
}

# In _load_mod():
# After loading other resources, terrain is auto-loaded via RESOURCE_TYPE_DIRS

# Add terrain_registry to ModLoader
var terrain_registry: RefCounted = TerrainRegistryClass.new()
```

### mod.json Extension

Mods can declare custom terrain types:

```json
{
  "id": "my_mod",
  "custom_terrain_types": ["ice", "sacred_ground", "corrupted_earth"],
  "provides": {
    "terrain": ["*"]
  }
}
```

### Base Game Terrain Data

Create TerrainData resources in `mods/_base_game/data/terrain/`:

```
mods/_base_game/data/terrain/
  plains.tres
  forest.tres
  mountain.tres
  water.tres
  road.tres
  sand.tres
  bridge.tres
  lava.tres
  wall.tres
```

---

## Implementation Plan

### Phase 1: Core Resources and Registry (3-4 hours)

**Goal:** Create TerrainData resource and TerrainRegistry

**Tasks:**
1. Create `core/resources/terrain_data.gd` with all properties
2. Create `core/registries/terrain_registry.gd` with registration and lookup
3. Add terrain_registry to ModLoader
4. Add "terrain" to RESOURCE_TYPE_DIRS for auto-loading
5. Update ModManifest to support custom_terrain_types

**Test Criteria:**
- [ ] TerrainData resource can be created in editor
- [ ] TerrainRegistry loads default terrain
- [ ] ModLoader discovers terrain .tres files

### Phase 2: TileSet Integration (2-3 hours)

**Goal:** Add terrain_type custom data to tilesets

**Tasks:**
1. Add "terrain_type" custom data layer (String) to terrain_placeholder.tres
2. Set terrain_type for each tile (grass="plains", trees="forest", etc.)
3. Implement `GridManager._get_terrain_id_at_cell()`
4. Implement `GridManager.load_terrain_data()` caching
5. Call load_terrain_data() from battle scene setup

**Test Criteria:**
- [ ] Tiles have terrain_type in inspector
- [ ] GridManager reads terrain_type from tiles
- [ ] Terrain cache populated on battle start

### Phase 3: Movement Cost Integration (2-3 hours)

**Goal:** Pathfinding respects terrain costs and movement types

**Tasks:**
1. Update `GridManager.get_terrain_cost()` to use TerrainData
2. Verify `get_walkable_cells()` uses correct movement type costs
3. Verify `find_path()` respects movement type
4. Test flying units ignore terrain costs
5. Test floating units use reduced costs
6. Test ground units blocked by water

**Test Criteria:**
- [ ] Forest cells cost 2 for ground units
- [ ] Flying units move freely over water
- [ ] Ground units cannot path through water
- [ ] Movement range display reflects terrain costs

### Phase 4: Combat Modifier Integration (2-3 hours)

**Goal:** Terrain affects defense and evasion in combat

**Tasks:**
1. Add `calculate_hit_chance_with_terrain()` to CombatCalculator
2. Add `get_effective_defense_with_terrain()` to CombatCalculator
3. Modify BattleManager._execute_attack() to fetch terrain data
4. Apply terrain defense bonus to damage calculation
5. Apply terrain evasion bonus to hit chance calculation

**Test Criteria:**
- [ ] Unit on forest has +1 DEF
- [ ] Unit on mountain has +2 DEF
- [ ] Hit chance reduced by terrain evasion bonus
- [ ] Combat forecast shows terrain-adjusted values

### Phase 5: Turn Effects (DoT/Healing) (2-3 hours)

**Goal:** Terrain applies damage/healing at turn start

**Tasks:**
1. Implement `TurnManager._process_terrain_effects()`
2. Call at start of each unit's turn (before movement)
3. Skip effects for flying units
4. Show damage/healing popup (reuse existing damage display)
5. Handle unit death from terrain damage

**Test Criteria:**
- [ ] Standing on lava deals damage each turn
- [ ] Sacred ground heals each turn
- [ ] Flying units over lava take no damage
- [ ] Death from terrain damage handled correctly

### Phase 6: Status Effects (1-2 hours)

**Goal:** Terrain can apply status effects on entry

**Tasks:**
1. Add status_effect_on_entry handling to terrain effects
2. Apply when unit enters cell (during movement)
3. Respect duration from TerrainData
4. Skip for flying units
5. Implement mud terrain with "slow" effect

**Test Criteria:**
- [ ] Entering mud applies "slow" status
- [ ] Status has correct duration
- [ ] Flying units not affected
- [ ] Status shown in unit panel

### Phase 7: UI Polish (2-3 hours)

**Goal:** TerrainInfoPanel and visual feedback

**Tasks:**
1. Rewrite TerrainInfoPanel to use GridManager.get_terrain_at_cell()
2. Format effects string dynamically
3. Show movement type indicator for impassable terrain
4. Add terrain damage/heal animation (floating numbers)
5. Optional: terrain-specific footstep sounds

**Test Criteria:**
- [ ] Panel shows correct terrain name
- [ ] Panel shows all active effects
- [ ] "Blocked" indicator for impassable terrain
- [ ] Damage numbers appear on terrain damage

### Phase 8: Base Game Content (1-2 hours)

**Goal:** Create TerrainData for all base game tiles

**Tasks:**
1. Create plains.tres, forest.tres, mountain.tres, etc.
2. Set appropriate values for each terrain type
3. Configure terrain_type on all tiles in terrain_placeholder.tres
4. Add bridge.tres (crosses water)
5. Add lava.tres (damage + impassable ground)

**Test Criteria:**
- [ ] All 9 terrain types have .tres files
- [ ] All tiles have terrain_type assigned
- [ ] Values match Shining Force conventions

### Phase 9: Testing and Documentation (2 hours)

**Goal:** Comprehensive testing and documentation

**Tasks:**
1. Write headless tests for terrain cost calculations
2. Write headless tests for terrain effects processing
3. Manual playtest on battle with varied terrain
4. Update TILEMAP_STANDARD.md with terrain_type requirement
5. Document terrain modding in CLAUDE.md

**Test Criteria:**
- [ ] All automated tests pass
- [ ] Manual playtest reveals no issues
- [ ] Documentation updated

---

## Edge Cases and Solutions

### 1. Missing Terrain Type
**Problem:** Tile has no terrain_type custom data
**Solution:** Default to "plains" with warning

### 2. Unknown Terrain ID
**Problem:** terrain_type value not in registry
**Solution:** Return default TerrainData for "plains"

### 3. Unit Spawns on Damaging Terrain
**Problem:** Unit starts battle on lava
**Solution:** Terrain damage applies at turn start, not spawn

### 4. Death from Terrain Damage
**Problem:** Unit dies from lava at turn start
**Solution:** Handle in _process_terrain_effects(), emit died signal

### 5. Healing Over Max HP
**Problem:** Sacred ground heals past max HP
**Solution:** `unit.heal()` already clamps to max_hp

### 6. Stacking Status Effects
**Problem:** Multiple mud tiles, multiple slow applications
**Solution:** UnitStats.add_status_effect() already refreshes duration

### 7. Combat on Damaging Terrain
**Problem:** Does terrain damage during combat?
**Solution:** No - terrain effects only at turn start (SF convention)

---

## Shining Force Reference Values

Based on Shining Force 1 & 2 mechanics:

| Terrain | Move Cost (Ground) | Move Cost (Float) | Move Cost (Fly) | DEF Bonus | Notes |
|---------|-------------------|-------------------|-----------------|-----------|-------|
| Plains | 1 | 1 | 1 | 0 | Standard terrain |
| Forest | 2 | 1 | 1 | +1 | Cover |
| Mountain | 3 | 2 | 1 | +2 | High ground |
| Water | Blocked | 1 | 1 | 0 | Impassable to ground |
| Road | 1 | 1 | 1 | 0 | Fast travel |
| Sand/Desert | 2 | 2 | 1 | 0 | Slows all but flying |
| Bridge | 1 | 1 | 1 | 0 | Crosses water |
| Wall | Blocked | Blocked | Blocked | - | Total obstruction |
| Lava | Blocked | Blocked | 1 | 0 | 5 damage/turn to flying |

---

## Files to Create

| File | Purpose |
|------|---------|
| `core/resources/terrain_data.gd` | TerrainData resource class |
| `core/registries/terrain_registry.gd` | Terrain type registry |
| `mods/_base_game/data/terrain/plains.tres` | Plains terrain data |
| `mods/_base_game/data/terrain/forest.tres` | Forest terrain data |
| `mods/_base_game/data/terrain/mountain.tres` | Mountain terrain data |
| `mods/_base_game/data/terrain/water.tres` | Water terrain data |
| `mods/_base_game/data/terrain/road.tres` | Road terrain data |
| `mods/_base_game/data/terrain/sand.tres` | Sand terrain data |
| `mods/_base_game/data/terrain/bridge.tres` | Bridge terrain data |
| `mods/_base_game/data/terrain/lava.tres` | Lava terrain data |
| `mods/_base_game/data/terrain/wall.tres` | Wall terrain data |

## Files to Modify

| File | Changes |
|------|---------|
| `core/systems/grid_manager.gd` | Add terrain cache, update get_terrain_cost() |
| `core/systems/turn_manager.gd` | Add _process_terrain_effects() |
| `core/systems/combat_calculator.gd` | Add terrain modifier functions |
| `core/systems/battle_manager.gd` | Pass terrain data to combat |
| `core/mod_system/mod_loader.gd` | Add terrain_registry, terrain resource type |
| `core/mod_system/mod_manifest.gd` | Add custom_terrain_types field |
| `scenes/ui/terrain_info_panel.gd` | Rewrite to use TerrainData |
| `mods/_base_game/tilesets/terrain_placeholder.tres` | Add terrain_type custom data |
| `mods/_base_game/mod.json` | Add terrain to provides |

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Pathfinding performance regression | Low | Medium | Cache terrain data per-map |
| TileSet custom data migration | Medium | Low | Provide migration guide |
| Edge cases in terrain effects | Medium | Low | Comprehensive edge case handling |
| Breaking existing battles | Medium | Medium | Default to plains if no terrain_type |
| Mod compatibility | Low | Medium | TerrainRegistry fallback to defaults |

---

## Success Metrics

**Before:**
- Terrain is purely visual
- All cells have cost 1
- No combat modifiers from terrain
- TerrainInfoPanel shows placeholder data

**After:**
- Terrain affects movement costs by type
- Forests/mountains provide defense bonuses
- Flying units freely traverse water
- Lava/poison deals turn damage
- TerrainInfoPanel shows actual effects
- Mods can define custom terrain

---

**Plan Status:** Ready for Implementation
**Reviewed By:** Pending Captain approval
**Next Step:** Begin Phase 1 - Core Resources and Registry

*"Captain, the tactical depth of proper terrain effects is what separates a strategic battle from a mere skirmish. As Commander Spock might say, this is only logical." - Lt. Claudbrain*
