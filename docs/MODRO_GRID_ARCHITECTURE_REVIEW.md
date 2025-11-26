# MODRO'S MOD EXTENSIBILITY REVIEW
## Unified Grid Architecture Proposal

**Reviewer:** Modro (Mod Architect)
**Subject:** Lt. Claudbrain's Unified Grid Architecture
**Date:** 2025-11-26
**Status:** ARCHITECTURAL REVIEW - NOT YET IMPLEMENTED

---

## EXECUTIVE SUMMARY

**Overall Verdict:** APPROVE WITH CRITICAL CHANGES

**Moddability Score:** 6.5/10 (Current Proposal) → 9/10 (With Recommended Changes)

Lt. Claudbrain's unified grid architecture correctly identifies the ~70% code duplication problem and proposes a sensible consolidation strategy. However, the current proposal has **critical moddability flaws** that would severely limit total conversion mods and create mod conflict scenarios. The core concept is sound, but the execution needs significant adjustments to meet our platform vision.

**Primary Concerns:**
1. Hardcoded mode system blocks total conversion capability
2. Singleton GridManager creates mod conflict bottlenecks
3. Missing extension points for custom movement behaviors
4. Standard layer naming is too rigid without escape hatches
5. Grid resource pattern lacks data-driven flexibility

**The Good News:** All issues are fixable with architectural adjustments before implementation begins.

---

## DETAILED ASSESSMENT

### 1. MOD AUTHOR EXPERIENCE

#### STRENGTHS
- **Grid Resource Pattern**: Having each map scene link a `Grid.tres` is actually brilliant - it makes grid configuration visible and tweakable in the editor without touching code. Modders can create 24px, 48px, or hexagonal grids (with coordinate conversion overrides) just by creating new Grid resources.

- **TileMapLayer Structure**: Standardizing on GroundLayer/WallsLayer is reasonable for 90% of use cases and gives modders a clear starting point. The problem isn't the standard, it's the lack of flexibility around it.

- **GridEntity Component**: Conceptually good - attaching a child node to add grid behavior is Godot-idiomatic and modular. Modders understand "attach component to add capability."

#### CRITICAL ISSUES

**Issue 1.1: Mode System is Hardcoded**
```gdscript
# Proposed (BAD for mods):
enum GridMode { BATTLE, EXPLORATION, CINEMATIC }

func setup_grid_for_mode(grid, tilemap, mode: GridMode):
    match mode:
        BATTLE: # 32px, occupation, AStar
        EXPLORATION: # 16px, simple collision
        CINEMATIC: # mixed
```

**Why This Kills Total Conversions:**
A modder creating a "stealth tactics" mod needs:
- Visibility zones (line of sight calculations)
- Sound radius detection (different from movement range)
- Cover system (half-cover, full-cover tiles)
- Alert state collision rules (enemies ignore occupied cells during pursuit)

None of these fit BATTLE/EXPLORATION/CINEMATIC. The modder must either:
1. Hack one of the existing modes (brittle, breaks other mods)
2. Fork GridManager (defeats the purpose of a unified system)
3. Give up and not make the mod

**Fix:** Make modes data-driven, not enum-hardcoded.

**Issue 1.2: Layer Naming Enforcement Without Escape Hatch**
```gdscript
# Proposed (BAD for mods):
# REQUIRED layers: GroundLayer, WallsLayer
# Content creators MUST follow naming conventions
```

**Why This Limits Creativity:**
A modder creating an "airship battle" system needs:
- GroundLayer (ship deck)
- WallsLayer (masts, cabins)
- **AerialLayer** (flying units move here)
- **RiggingLayer** (climbable ropes between levels)

The standard structure doesn't support multi-elevation grids. Modder is stuck.

**Fix:** Standard layers should be DEFAULT, not REQUIRED. Provide a `get_layer(purpose)` abstraction that checks standard names first, then custom metadata.

---

### 2. EXTENSIBILITY & CUSTOMIZATION

#### STRENGTHS
- **Grid Resource Delegates to TileMapLayer**: This is excellent! The Grid resource doesn't try to own all logic - it delegates coordinate conversion to TileMapLayer when available, falls back to internal math when standalone. This is the right delegation pattern.

- **GridEntity as Universal Interface**: If done right, this could let modders create custom movement components that work everywhere (battles, exploration, cinematics). That's powerful.

#### CRITICAL ISSUES

**Issue 2.1: No Plugin Points for Custom Movement**

The proposal describes GridEntity as a "universal movement component" but doesn't specify how modders override behavior. Example scenarios that must be possible:

**Scenario A: Flying Unit**
```gdscript
# Modder needs to:
# - Ignore WallsLayer collision
# - Pathfind over obstacles
# - Move at different speeds over terrain
```

**Scenario B: Teleporting Unit**
```gdscript
# Modder needs to:
# - Skip intermediate cells
# - Validate only destination, not path
# - Trigger different animations/effects
```

**Scenario C: Turn-Based Tactical (Fire Emblem style)**
```gdscript
# Modder needs to:
# - Show full movement range before moving
# - Preview paths on hover
# - Commit movement only after destination selected
```

**Current Proposal:** GridEntity has `move_to(cell)` and `move_along_path(path)`. That's it. No override points for pathfinding, collision rules, or movement validation.

**Fix:** GridEntity needs a strategy pattern or virtual methods:
```gdscript
# GridEntity should have:
func _get_pathfinding_strategy() -> PathfindingStrategy:
    return default_strategy  # Modders override this

func _get_collision_rules() -> CollisionRules:
    return default_rules  # Modders override this

func _validate_movement(from: Vector2i, to: Vector2i) -> bool:
    return true  # Modders add custom logic
```

**Issue 2.2: GridMode Cannot Be Extended**

Proposal says "Three modes: BATTLE, EXPLORATION, CINEMATIC" with different collision rules. But what if a modder needs:
- **STEALTH_MISSION** mode (adds vision cones, alert states)
- **PUZZLE_GRID** mode (blocks, switches, pressure plates)
- **PLATFORMER_GRID** mode (gravity, jumping, multi-level)

**Current Proposal:** Enum-based modes mean modders must modify core GridManager code. That's unacceptable.

**Fix:** Make modes data-driven Resources:
```gdscript
class_name GridModeConfig extends Resource

@export var mode_name: String
@export var default_tile_size: int = 32
@export var use_astar_pathfinding: bool = true
@export var use_occupation_tracking: bool = true
@export var collision_layer_names: Array[String] = ["WallsLayer"]
@export var custom_collision_script: GDScript  # For total customization

# Modders create:
# res://mods/stealth_mod/configs/stealth_mode.tres
# Then: GridManager.register_mode(stealth_mode_config)
```

**Issue 2.3: No Clear Extension Points for Coordinate Systems**

Proposal mentions "24px tiles or hexagonal grids" as a question but doesn't answer it. The Grid resource has `cell_size` but coordinate conversion is baked into `map_to_local()` and `local_to_map()`.

**Hexagonal Grids Require:**
- Offset coordinate systems (odd-r, even-r, odd-q, even-q)
- Different neighbor calculations (6 neighbors, not 4)
- Different distance metrics (not Manhattan)

**Fix:** Make Grid.gd support custom coordinate converters:
```gdscript
# Grid.gd
class_name Grid extends Resource

@export var coordinate_system: GridCoordinateSystem  # Default: RectangularGrid

func map_to_local(grid_pos: Vector2i) -> Vector2:
    if coordinate_system:
        return coordinate_system.map_to_local(grid_pos, cell_size)
    # Fallback to default rectangular logic
```

---

### 3. MOD ISOLATION & COMPATIBILITY

#### STRENGTHS
- **Grid Resource Per Scene**: Each map has its own Grid.tres, so Mod A's 32px battle grid doesn't conflict with Mod B's 16px exploration grid. Good isolation.

- **Component-Based GridEntity**: Since GridEntity is a node component, modders can extend it via inheritance or composition without global conflicts.

#### CRITICAL ISSUES

**Issue 3.1: Singleton GridManager is a Mod Conflict Bottleneck**

**Problem:**
```gdscript
# Proposed architecture:
GridManager.setup_grid_for_mode(my_grid, my_tilemap, GridMode.BATTLE)

# But what if:
# - Mod A wants custom pathfinding (avoid fire tiles)
# - Mod B wants different collision rules (ghosts pass through walls)
# - Both mods are active simultaneously in different scenes
```

The singleton GridManager holds state (`grid`, `tilemap`, `_occupied_cells`, `_astar`). If Mod A and Mod B both try to configure GridManager differently, they'll conflict.

**Scenario:**
1. Player enters Battle A (Mod A's custom fire-avoidance pathfinding)
2. During battle, a cinematic plays (switches GridManager to CINEMATIC mode)
3. Cinematic ends, battle resumes
4. **BUG:** GridManager is in wrong state, Mod A's pathfinding config is gone

**Fix:** GridManager should be a **service locator**, not a stateful singleton:
```gdscript
# Instead of:
GridManager.setup_grid_for_mode(grid, tilemap, mode)  # Stores state globally
GridManager.find_path(from, to)  # Uses global state

# Do this:
var battle_grid_instance: GridInstance = GridManager.create_instance(grid, tilemap, mode_config)
battle_grid_instance.find_path(from, to)  # Instance has its own state

# Each scene/mod has its own GridInstance
# No conflicts, no state sharing issues
```

**Issue 3.2: Cinematics from Mod A Won't Work in Mod B's Maps**

**Problem:**
Mod A's cinematic uses `move_entity` commands with waypoints. But Mod B's map uses custom layer names (`MyGroundLayer`, `MyWallsLayer` instead of standard names). The cinematic executor calls GridManager, which expects standard layer names, and fails.

**Fix:** GridEntity/GridInstance should query the TileMapLayer's metadata for layer purposes, not hardcode names:
```gdscript
# TileMapLayer metadata:
# "grid_layer_purpose" = "walkable"  # Instead of requiring name "GroundLayer"
# "grid_layer_purpose" = "collision"  # Instead of requiring name "WallsLayer"

# GridManager checks:
func _find_walkable_layer(tilemap: Node) -> TileMapLayer:
    for child in tilemap.get_children():
        if child is TileMapLayer and child.get_meta("grid_layer_purpose") == "walkable":
            return child
    # Fallback: Check standard names
    return tilemap.get_node_or_null("GroundLayer")
```

---

### 4. API STABILITY & EVOLUTION

#### STRENGTHS
- **Grid Resource as Interface**: Making Grid a Resource means we can version it (`class_name GridV2 extends Grid`) and maintain backward compatibility. Good forward-thinking.

#### CONCERNS

**Issue 4.1: GridEntity API Stability Unknown**

The proposal says "GridEntity handles grid position tracking, tweening, pathfinding" but doesn't specify the public API. What methods do modders rely on? What can change in future versions?

**Required Stability Guarantees:**
```gdscript
# These methods MUST remain stable (never change signature):
func move_to(target: Vector2i) -> void
func move_along_path(path: Array[Vector2i]) -> void
func get_grid_position() -> Vector2i
func teleport_to(target: Vector2i) -> void

# Signals MUST remain stable:
signal movement_started(from: Vector2i)
signal movement_completed(to: Vector2i)
signal movement_blocked(reason: String)
```

**Recommendation:** Document the stable API in a `GridEntity.STABLE_API.md` file before implementation. Any method in that file is a breaking change to remove/modify.

**Issue 4.2: No Deprecation Strategy**

If we add features to GridManager later (e.g., multi-level grids, dynamic terrain), how do we avoid breaking existing mods?

**Fix:** Adopt a deprecation policy:
```gdscript
# OLD API (keep working, but warn):
func setup_grid(grid: Grid, tilemap: TileMapLayer):
    push_warning("GridManager.setup_grid() is deprecated. Use create_instance() instead.")
    # Still works, but routes to new system

# NEW API:
func create_instance(grid: Grid, tilemap: TileMapLayer, config: GridModeConfig) -> GridInstance:
    return GridInstance.new(grid, tilemap, config)
```

**Issue 4.3: Missing Signals for Mod Hooks**

GridEntity should emit signals at key points so modders can hook in custom logic without modifying core code:

**Required Signals:**
```gdscript
# GridEntity should emit:
signal movement_requested(from: Vector2i, to: Vector2i)  # BEFORE validation
signal movement_validated(from: Vector2i, to: Vector2i, valid: bool)  # AFTER validation
signal movement_started(from: Vector2i, to: Vector2i)  # BEFORE tween
signal movement_step_completed(cell: Vector2i)  # EACH cell in path
signal movement_completed(from: Vector2i, to: Vector2i)  # AFTER tween
signal movement_cancelled(reason: String)  # If interrupted

# Modders connect:
func _on_movement_requested(from, to):
    if is_in_dangerous_zone(to):
        # Cancel movement, show warning
        grid_entity.cancel_movement("Too dangerous!")
```

---

### 5. CONTENT CREATION WORKFLOW

#### STRENGTHS
- **Grid Resource is Editor-Visible**: Modders can create/edit Grid.tres files in the Godot inspector without touching code. This is a huge win for non-programmers.

- **Standard Structure Reduces Cognitive Load**: New modders see "GroundLayer, WallsLayer" and immediately understand the pattern. Good onboarding.

#### CONCERNS

**Issue 5.1: No Validation or Error Messages**

Proposal says "content creators must follow naming conventions" but doesn't specify what happens if they don't. Modders will make mistakes:

**Common Errors:**
- Typo: `GroundLayers` (plural) instead of `GroundLayer`
- Wrong node type: `TileMap` instead of `TileMapLayer` (Godot 3 vs 4 confusion)
- Missing required layers
- Grid.tres not linked to scene

**Fix:** Add `@tool` validation script that runs in editor:
```gdscript
@tool
extends Node2D

func _get_configuration_warnings() -> PackedStringArray:
    var warnings: PackedStringArray = []

    # Check for Grid resource
    if not grid_resource:
        warnings.append("No Grid resource assigned. Create Grid.tres and assign it.")

    # Check for TileMapLayer
    var tilemap: Node = get_node_or_null("TileMapLayer")
    if not tilemap:
        warnings.append("TileMapLayer not found. Add as child of this scene.")
    elif not tilemap is TileMapLayer:
        warnings.append("TileMapLayer is wrong type. Use TileMapLayer, not TileMap.")

    # Check for standard layers
    if tilemap:
        if not tilemap.get_node_or_null("GroundLayer"):
            warnings.append("GroundLayer not found. Add as child of TileMapLayer.")

    return warnings
```

**Issue 5.2: No Templates or Scene Wizards**

New modders will struggle to set up the structure correctly. They need:
- **Scene Template:** `map_template.tscn` with Grid.tres pre-linked and standard layers already created
- **Editor Plugin:** "Create Grid Map" wizard that generates the structure automatically
- **Example Maps:** 3-4 fully configured maps showing different grid sizes/modes

**Issue 5.3: Grid Resource Linking is Manual and Error-Prone**

Proposal says "content creators link Grid.tres to their map scenes." How? Via export variable? Via metadata? Via naming convention?

**Current GridManager Code:**
```gdscript
func setup_grid(p_grid: Grid, p_tilemap: TileMapLayer):
    grid = p_grid  # Passed as parameter
```

**Problem:** Scene file must call `GridManager.setup_grid()` in `_ready()`. Modders will forget or do it wrong.

**Fix:** Use scene metadata or auto-detection:
```gdscript
# Option A: Scene-level metadata
# In map scene root node:
# Metadata: "grid_resource" = res://my_grid.tres

# GridManager auto-detects on scene load:
func _on_scene_tree_entered(node: Node):
    if node.has_meta("grid_resource"):
        var grid: Grid = node.get_meta("grid_resource")
        setup_grid_auto(node, grid)

# Option B: Standard export variable
# Map scene root has:
@export var grid_resource: Grid
@export var tilemap_node: NodePath

# GridManager checks for this pattern and auto-initializes
```

---

### 6. POWER VS. SIMPLICITY

#### THE FUNDAMENTAL TENSION

**Simple Mode (90% of modders):**
- Use standard GroundLayer/WallsLayer structure
- Use default BATTLE/EXPLORATION/CINEMATIC modes
- Grid.tres has `grid_size` and `cell_size`, that's it
- GridEntity "just works" with zero configuration

**Advanced Mode (10% of modders making total conversions):**
- Custom layer names with metadata
- Custom GridModeConfig resources
- Custom PathfindingStrategy scripts
- Custom GridCoordinateSystem for hexagonal grids
- Override GridEntity virtual methods

**Current Proposal:** Optimized for simple mode, but BLOCKS advanced mode. That's backwards for a platform.

**Correct Balance:**
```gdscript
# Default behavior is simple:
var grid: Grid = Grid.new()  # Uses default rectangular coordinates
grid.grid_size = Vector2i(20, 11)
grid.cell_size = 32

GridManager.setup_grid(grid, tilemap)  # Uses default BATTLE mode
grid_entity.move_to(Vector2i(5, 5))  # Just works

# But advanced modders can override:
var hex_grid: Grid = Grid.new()
hex_grid.coordinate_system = HexGridCoordinateSystem.new()  # Custom

var stealth_mode: GridModeConfig = load("res://mods/stealth/stealth_mode.tres")
var battle_grid: GridInstance = GridManager.create_instance(grid, tilemap, stealth_mode)

grid_entity.pathfinding_strategy = AvoidFirePathfinding.new()  # Custom
```

**Principle:** Provide high-level defaults that handle 90% of cases, but expose low-level hooks for the 10% building something unique.

---

## RECOMMENDED CHANGES

### CRITICAL (Must Fix Before Implementation)

**1. Make GridMode Data-Driven**
```gdscript
class_name GridModeConfig extends Resource

@export var mode_name: String = "Battle"
@export var tile_size: int = 32
@export var use_pathfinding: bool = true
@export var use_occupation_tracking: bool = true
@export var collision_layers: Array[String] = ["WallsLayer"]
@export var custom_rules_script: GDScript  # Advanced: custom collision logic

# Built-in modes:
# res://core/configs/grid_mode_battle.tres
# res://core/configs/grid_mode_exploration.tres
# res://core/configs/grid_mode_cinematic.tres

# Modders create:
# res://mods/my_mod/stealth_mode.tres
```

**2. Convert GridManager from Stateful Singleton to Service Locator**
```gdscript
# OLD (singleton with state):
GridManager.setup_grid(grid, tilemap, mode)
GridManager.find_path(from, to)  # Uses global state

# NEW (service locator returning instances):
var grid_instance: GridInstance = GridManager.create_grid_instance(grid, tilemap, mode_config)
grid_instance.find_path(from, to)  # Instance has its own state

# Scene stores its instance:
@onready var my_grid: GridInstance = GridManager.create_grid_instance($Grid, $TileMapLayer, battle_mode)
```

**3. Add Extension Points to GridEntity**
```gdscript
class_name GridEntity extends Node

# Override these for custom behavior:
func _get_pathfinding_strategy() -> PathfindingStrategy:
    return null  # Use default

func _get_collision_validator() -> CollisionValidator:
    return null  # Use default

func _can_move_to(from: Vector2i, to: Vector2i) -> bool:
    return true  # Add custom validation

# Signals for hooking:
signal movement_requested(from: Vector2i, to: Vector2i)
signal movement_validated(from: Vector2i, to: Vector2i, valid: bool)
signal movement_started(path: Array[Vector2i])
signal movement_step(current_cell: Vector2i, next_cell: Vector2i)
signal movement_completed(final_cell: Vector2i)
signal movement_cancelled(reason: String)
```

**4. Make Layer Names Flexible with Metadata Fallback**
```gdscript
# Standard approach (simple):
# Layers named: GroundLayer, WallsLayer
# GridManager finds by name

# Custom approach (advanced):
# Layers have metadata: grid_layer_purpose = "walkable" / "collision"
# GridManager finds by metadata first, then by name

func _find_layer_by_purpose(tilemap: Node, purpose: String) -> TileMapLayer:
    # Check metadata first (advanced modders)
    for child in tilemap.get_children():
        if child is TileMapLayer and child.get_meta("grid_layer_purpose", "") == purpose:
            return child

    # Fallback to standard names (simple modders)
    match purpose:
        "walkable": return tilemap.get_node_or_null("GroundLayer")
        "collision": return tilemap.get_node_or_null("WallsLayer")

    return null
```

### IMPORTANT (Strongly Recommended)

**5. Add GridCoordinateSystem for Non-Rectangular Grids**
```gdscript
class_name GridCoordinateSystem extends Resource

# Virtual methods for modders to override:
func map_to_local(grid_pos: Vector2i, cell_size: int) -> Vector2:
    return Vector2.ZERO  # Override in subclass

func local_to_map(world_pos: Vector2, cell_size: int) -> Vector2i:
    return Vector2i.ZERO  # Override in subclass

func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
    return []  # Override in subclass

func get_distance(from: Vector2i, to: Vector2i) -> int:
    return 0  # Override in subclass

# Built-in:
class_name RectangularGridCoords extends GridCoordinateSystem
# Manhattan distance, 4 neighbors

class_name HexGridCoords extends GridCoordinateSystem
# Hex distance, 6 neighbors
```

**6. Add Editor Validation and Templates**
```gdscript
# Map scene root node (tool script):
@tool
@export var grid_resource: Grid
@export var walkable_layer: NodePath
@export var collision_layer: NodePath

func _get_configuration_warnings() -> PackedStringArray:
    var warnings: PackedStringArray = []
    if not grid_resource:
        warnings.append("Assign Grid resource")
    if not has_node(walkable_layer):
        warnings.append("Assign walkable layer")
    return warnings
```

**7. Document Stable API Contract**
Create `docs/API_STABILITY.md`:
```markdown
# Grid System Stable API

These methods/signals are guaranteed stable across minor versions:

## Grid.gd
- `map_to_local(grid_pos: Vector2i) -> Vector2`
- `local_to_map(world_pos: Vector2) -> Vector2i`
- `is_within_bounds(grid_pos: Vector2i) -> bool`
- `get_neighbors(grid_pos: Vector2i) -> Array[Vector2i]`

## GridEntity.gd
- `move_to(target: Vector2i) -> void`
- `move_along_path(path: Array[Vector2i]) -> void`
- `get_grid_position() -> Vector2i`
- Signal: `movement_completed(to: Vector2i)`

Any changes to these APIs will be deprecated for 2 major versions before removal.
```

### NICE TO HAVE (Future Improvements)

**8. GridManager Auto-Registration System**
```gdscript
# Instead of manual setup_grid() calls in every map scene:
# GridManager auto-detects grids on scene load

func _on_node_entered_tree(node: Node):
    if node.has_method("get_grid_config"):
        var config = node.get_grid_config()
        _register_scene_grid(node, config)
```

**9. Mod Load Order Configuration**
```
# mods/my_mod/mod.cfg
[grid_overrides]
mode_configs = ["stealth_mode.tres"]  # Registers custom modes
coordinate_systems = ["hex_grid.gd"]  # Registers custom coordinate systems
```

**10. Visual Grid Editor Plugin**
```gdscript
# EditorPlugin that adds:
# - "Create Grid Map" wizard
# - Visual grid overlay in editor
# - Grid property inspector extensions
```

---

## EXTENSIBILITY GAPS IDENTIFIED

### Missing: Custom Pathfinding Strategies
**Current:** GridManager has hardcoded AStar pathfinding.
**Needed:** Plugin system for custom pathfinding (A*, Dijkstra, Jump Point Search, flow fields).

**Fix:**
```gdscript
class_name PathfindingStrategy extends Resource
func find_path(from: Vector2i, to: Vector2i, grid_instance: GridInstance) -> Array[Vector2i]:
    return []  # Override in subclass

# GridInstance.pathfinding_strategy = MyCustomPathfinding.new()
```

### Missing: Dynamic Terrain Cost Updates
**Current:** Terrain costs set once at initialization.
**Needed:** Ability to change costs at runtime (burning tiles, frozen water becoming walkable).

**Fix:**
```gdscript
# GridInstance should emit:
signal terrain_changed(cells: Array[Vector2i])

# Modders connect:
func _on_fire_spread(burning_cells: Array[Vector2i]):
    for cell in burning_cells:
        grid_instance.set_terrain_cost(cell, MovementType.WALK, 99)  # Now impassable
    grid_instance.terrain_changed.emit(burning_cells)
```

### Missing: Multi-Level Grid Support
**Current:** Grid is 2D (Vector2i).
**Needed:** Some mods need 3D grids (Vector3i) for flying units, underground, multi-story buildings.

**Fix:**
```gdscript
# Grid.gd should support:
@export var is_multi_level: bool = false
@export var level_height: int = 32  # Pixels between levels

func map_to_local_3d(grid_pos: Vector3i) -> Vector3:
    var base_2d: Vector2 = map_to_local(Vector2i(grid_pos.x, grid_pos.y))
    return Vector3(base_2d.x, base_2d.y, grid_pos.z * level_height)
```

### Missing: Grid State Serialization
**Current:** No save/load for grid state.
**Needed:** Modders want to save occupation, terrain modifications, dynamic obstacles.

**Fix:**
```gdscript
# GridInstance should have:
func serialize() -> Dictionary:
    return {
        "occupied_cells": _occupied_cells,
        "terrain_costs": _custom_terrain_costs,
        "mode": mode_config.resource_path
    }

func deserialize(data: Dictionary) -> void:
    _occupied_cells = data.occupied_cells
    _apply_terrain_costs(data.terrain_costs)
```

---

## CONTENT CREATOR DOCUMENTATION NEEDS

### Required Documentation (Before Launch)

**1. Quick Start Guide: "Your First Grid Map"**
- Step-by-step: Create Grid.tres
- Add GroundLayer and WallsLayer
- Link to map scene
- Test movement
- Target: Complete in 10 minutes

**2. Reference: Grid System API**
- Every public method in Grid, GridManager, GridEntity
- All signals with example use cases
- All exports with valid value ranges

**3. Tutorial: "Custom Movement Types"**
- Implement flying units
- Implement teleporting units
- Implement phasing (pass through walls)

**4. Tutorial: "Custom Grid Modes"**
- Create GridModeConfig resource
- Register with GridManager
- Use in battle/exploration/custom scene

**5. Tutorial: "Hexagonal Grids"**
- Create HexGridCoordinateSystem
- Configure hex tiles in TileMapLayer
- Handle 6-directional movement

**6. Cookbook: Common Patterns**
- Multi-level grids (buildings with floors)
- Dynamic terrain (fire spreading, ice melting)
- Fog of war (hiding unexplored cells)
- Stealth vision cones
- Cover systems
- Pushable blocks

**7. Migration Guide: "Upgrading from Separate Systems"**
- Convert Battle GridManager usage → GridInstance
- Convert Exploration TileMapLayer usage → GridInstance
- Convert Cinematic movement → GridEntity

### Recommended Examples

**Example 1: Simple Battle Map**
```
res://examples/grid_simple_battle/
├── simple_battle.tscn
├── simple_battle_grid.tres (20x11, 32px)
├── README.md
```

**Example 2: Exploration Map with Triggers**
```
res://examples/grid_exploration_town/
├── town.tscn
├── town_grid.tres (40x30, 16px)
├── triggers/ (NPCs, doors, chests)
├── README.md
```

**Example 3: Custom Stealth Mode**
```
res://examples/grid_stealth_mission/
├── stealth_map.tscn
├── stealth_grid_mode.tres (custom GridModeConfig)
├── vision_cone.gd (custom collision validator)
├── README.md
```

**Example 4: Hexagonal Battle Grid**
```
res://examples/grid_hex_battle/
├── hex_battle.tscn
├── hex_grid.tres (uses HexGridCoordinateSystem)
├── hex_tiles.tres (hexagonal TileSet)
├── README.md
```

---

## COMPARISON TO SUCCESSFUL MODDABLE GAMES

### What Skyrim Got Right
- **Plugin load order** lets modders override without conflicts
- **FormIDs** provide stable references across mods
- **Script extenders** add functionality without editing core

**Apply to Grid System:**
- Mod load order for GridModeConfigs
- Stable actor IDs for cross-mod references
- Extension points for custom behaviors

### What Minecraft Got Right
- **Block behaviors** are data-driven (JSON)
- **Custom dimensions** are fully moddable
- **Event system** lets mods hook into everything

**Apply to Grid System:**
- GridModeConfig as data (not code)
- Custom coordinate systems (like custom dimensions)
- Rich signal system for mod hooks

### What Mount & Blade Got Right
- **Module system** isolates mods
- **Scene props** are easily added
- **AI behaviors** are pluggable

**Apply to Grid System:**
- GridInstance isolation (not singleton)
- TileMapLayer standardization (like scene props)
- PathfindingStrategy plugin system (like AI behaviors)

---

## FINAL VERDICT

### APPROVE WITH CRITICAL CHANGES

Lt. Claudbrain's unified grid architecture is **conceptually sound** and solves real problems (70% code duplication, inconsistent behavior). However, **as currently proposed, it would severely limit modding capability** and create the exact kind of rigid platform we're trying to avoid.

### MUST CHANGE (Blocking Issues)
1. Convert GridMode enum → GridModeConfig resource (data-driven)
2. Convert GridManager singleton → GridInstance service locator (mod isolation)
3. Add PathfindingStrategy and CollisionValidator extension points (custom behaviors)
4. Add layer metadata fallback (flexible layer naming)

### SHOULD CHANGE (Strongly Recommended)
5. Add GridCoordinateSystem for hexagonal/custom grids
6. Add editor validation and scene templates
7. Document stable API contract
8. Add comprehensive signal system for mod hooks

### CAN DEFER (Future Improvements)
9. Auto-registration system
10. Visual grid editor plugin
11. Multi-level grid support
12. Grid state serialization

### MODDABILITY SCORE TRAJECTORY

**Current Proposal (As-Is):** 6.5/10
- Solves duplication ✓
- Standard structure ✓
- But hardcoded modes ✗
- But singleton conflicts ✗
- But no extension points ✗

**With Critical Changes:** 9/10
- Solves duplication ✓
- Standard with flexibility ✓
- Data-driven modes ✓
- Instance isolation ✓
- Extension points ✓
- Missing: Visual tooling (not critical for modding)

**With All Recommended Changes:** 9.5/10
- Platform-grade moddability
- Total conversion capable
- Clear upgrade path
- Comprehensive docs
- Only missing: Battle-tested in production (requires implementation)

---

## IMPLEMENTATION ROADMAP

### Phase 1: Core Architecture (CRITICAL)
- Implement GridModeConfig resource
- Refactor GridManager → GridInstance service locator
- Add PathfindingStrategy base class
- Add CollisionValidator base class
- Create 3 built-in configs (battle, exploration, cinematic)

**Deliverable:** Mods can register custom modes

### Phase 2: GridEntity Refactor (CRITICAL)
- Add extension point methods
- Add comprehensive signal system
- Implement in Unit.gd, HeroController.gd, CinematicActor.gd
- Backward compatibility wrappers

**Deliverable:** Mods can customize movement behavior

### Phase 3: Flexible Layer System (IMPORTANT)
- Add metadata-based layer detection
- Update GridManager to check metadata first
- Add editor validation scripts
- Create scene templates

**Deliverable:** Mods can use custom layer names

### Phase 4: Documentation & Examples (IMPORTANT)
- Write 7 required tutorials
- Create 4 example projects
- API reference doc
- Migration guide

**Deliverable:** Modders can learn the system

### Phase 5: Advanced Features (OPTIONAL)
- GridCoordinateSystem for hexagonal grids
- Multi-level grid support
- Visual editor plugin
- Grid state serialization

**Deliverable:** Advanced total conversion support

---

## OPEN QUESTIONS FOR LT. CLAUDBRAIN

**Q1:** How does GridEntity handle entities that exist across multiple scenes (e.g., persistent battle units that also appear in cinematics)?

**Q2:** What's the plan for backward compatibility during the 5-phase migration? Can battles, exploration, and cinematics run simultaneously during transition?

**Q3:** How do modders override the default pathfinding without forking GridManager? Is PathfindingStrategy part of the initial design or a future addition?

**Q4:** Should GridModeConfig support composition (e.g., "stealth mode" extends "battle mode" adds vision rules)?

**Q5:** What happens if a mod needs to change grid configuration mid-scene (e.g., bridge collapses, new cells become unwalkable)? Is GridInstance mutable at runtime?

---

## CONCLUSION

This unified grid architecture can become a **world-class moddable system** with the recommended changes. The core insight (consolidate duplication, standardize patterns) is exactly right. The execution details need adjustment to preserve the flexibility that makes total conversions possible.

**Recommendation:** Approve the project with critical changes integrated into Phase 1 planning. Do not implement the hardcoded mode enum. Do not implement a stateful singleton GridManager. Those decisions would haunt us for years.

The path to 9/10 moddability is clear. Let's build a platform, not just a game.

**Modro out.**

---

**FILE PATHS FOR CAPTAIN'S REFERENCE:**

**Current System Files:**
- `/home/user/dev/sparklingfarce/core/systems/grid_manager.gd` - Singleton with state
- `/home/user/dev/sparklingfarce/core/resources/grid.gd` - Grid resource (good foundation)
- `/home/user/dev/sparklingfarce/core/components/unit.gd` - Battle movement
- `/home/user/dev/sparklingfarce/scenes/map_exploration/hero_controller.gd` - Exploration movement (16px)
- `/home/user/dev/sparklingfarce/core/components/cinematic_actor.gd` - Cinematic movement (mixed)

**Documentation:**
- `/home/user/dev/sparklingfarce/docs/PHASE_3_COMPLETE.md` - Recent refactoring success
- `/home/user/dev/sparklingfarce/scenes/map_exploration/README.md` - Exploration system architecture
- `/home/user/dev/sparklingfarce/CLAUDE.md` - Project guidelines

**Key Observation:** Phase 3 (cinematic refactor) successfully demonstrated the delegation pattern. The same approach (thin wrappers over reusable services) should guide this grid unification.
