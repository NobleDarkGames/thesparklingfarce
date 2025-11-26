# Unified Grid Architecture - Executive Summary

**Date:** 2025-11-26
**Reviewer:** Modro (Mod Architect)
**Subject:** Lt. Claudbrain's Grid Consolidation Proposal

---

## THE BOTTOM LINE

**Verdict:** APPROVE WITH CRITICAL CHANGES

**TL;DR:** Lt. Claudbrain correctly identified the problem (70% duplication across Battle/Exploration/Cinematic) and proposed a solid consolidation strategy. However, the current design has moddability flaws that would block total conversions. With 4 critical architectural changes, this becomes a 9/10 platform-grade system.

---

## WHAT'S GOOD

1. **Grid Resource Pattern** - Brilliant! Each map links its own Grid.tres, making grid configs visible/tweakable in the editor.

2. **Standard Layer Structure** - GroundLayer/WallsLayer gives new modders a clear starting point (90% use case).

3. **GridEntity Component** - Godot-idiomatic approach (attach node to add capability).

4. **Delegation to TileMapLayer** - Grid resource delegates coordinate conversion instead of reimplementing it.

5. **Problem Identification** - Lt. Claudbrain nailed the diagnosis: Three systems doing the same thing differently is technical debt.

---

## WHAT'S BROKEN (CRITICAL)

### 1. HARDCODED MODE ENUM KILLS TOTAL CONVERSIONS

**Problem:**
```gdscript
enum GridMode { BATTLE, EXPLORATION, CINEMATIC }  # Only 3 modes allowed
```

**Why This is Unacceptable:**
A modder making a "stealth tactics" game needs custom modes with:
- Vision cone collision rules
- Sound radius detection
- Alert state pathfinding (enemies ignore occupied cells during pursuit)

They can't add STEALTH_MISSION mode without forking core code. That defeats the entire purpose of a unified, moddable platform.

**Fix:** Make modes data-driven Resources:
```gdscript
class_name GridModeConfig extends Resource
@export var mode_name: String
@export var collision_rules_script: GDScript  # Modders provide custom logic

# Mods register: GridManager.register_mode(my_stealth_mode)
```

---

### 2. SINGLETON GRIDMANAGER CREATES MOD CONFLICTS

**Problem:**
```gdscript
GridManager.setup_grid(my_grid, my_tilemap, mode)  # Stores state globally
```

**Why This is Unacceptable:**
- Mod A wants custom pathfinding (avoid fire tiles)
- Mod B wants different collision rules (ghosts pass through walls)
- Both mods load simultaneously in different scenes
- **CONFLICT:** They both try to configure the same singleton differently

**Scenario that Breaks:**
1. Player in Battle A (Mod A's custom pathfinding active)
2. Cinematic plays mid-battle (GridManager switches to CINEMATIC mode)
3. Cinematic ends, battle resumes
4. **BUG:** Mod A's pathfinding config is gone, battle breaks

**Fix:** Service locator pattern instead of stateful singleton:
```gdscript
# Each scene gets its own instance:
var battle_grid: GridInstance = GridManager.create_instance(grid, tilemap, mode_config)
battle_grid.find_path(from, to)  # Instance has isolated state
```

---

### 3. NO EXTENSION POINTS FOR CUSTOM MOVEMENT

**Problem:**
Proposal says GridEntity has `move_to(cell)` and `move_along_path(path)`. That's it. No way to customize:
- Pathfinding algorithm (flying units ignore walls)
- Collision validation (teleporting units skip intermediate cells)
- Movement preview (Fire Emblem-style range display)

**Why This is Unacceptable:**
A modder creating flying units can't make them ignore WallsLayer collision without editing GridEntity source code. That's not moddable.

**Fix:** Add strategy pattern:
```gdscript
class_name GridEntity extends Node

# Modders override:
func _get_pathfinding_strategy() -> PathfindingStrategy:
    return null  # Uses default, or custom

func _can_move_to(from: Vector2i, to: Vector2i) -> bool:
    return true  # Add custom validation
```

---

### 4. RIGID LAYER NAMING WITHOUT ESCAPE HATCH

**Problem:**
"Content creators MUST follow naming conventions: GroundLayer, WallsLayer"

**Why This is Limiting:**
Modder creating "airship battles" needs:
- GroundLayer (ship deck)
- WallsLayer (masts, cabins)
- **AerialLayer** (flying units move here)
- **RiggingLayer** (climbable ropes between levels)

Standard structure doesn't support multi-elevation. Modder is stuck.

**Fix:** Metadata-based layer detection with fallback:
```gdscript
# TileMapLayer has metadata: "grid_layer_purpose" = "walkable"
# GridManager checks metadata first (custom names OK)
# Then falls back to standard names (GroundLayer/WallsLayer)
```

---

## RECOMMENDED CHANGES (Priority Order)

### CRITICAL (Must Fix Before Implementation)

1. **Make GridMode Data-Driven**
   - Create GridModeConfig resource class
   - Add `GridManager.register_mode(config)`
   - Provide 3 built-ins: battle, exploration, cinematic
   - Modders create custom configs

2. **Convert GridManager to Service Locator**
   - Refactor `GridManager.setup_grid()` → `GridManager.create_instance()`
   - Return GridInstance with isolated state
   - No more singleton state sharing

3. **Add Extension Points to GridEntity**
   - Add `_get_pathfinding_strategy()` virtual method
   - Add `_can_move_to()` virtual method
   - Add comprehensive signal system (movement_started, movement_step, movement_completed)

4. **Make Layer Names Flexible**
   - Check TileMapLayer metadata first ("grid_layer_purpose")
   - Fallback to standard names (backward compatible)
   - Document both approaches

### IMPORTANT (Strongly Recommended)

5. **Add GridCoordinateSystem for Hexagonal Grids**
   - Create base class for coordinate conversion
   - Provide RectangularGridCoords (default)
   - Provide HexGridCoords (hexagonal)
   - Modders create custom systems

6. **Add Editor Validation**
   - `@tool` script with `_get_configuration_warnings()`
   - Catches missing Grid.tres, wrong layer types, typos
   - Prevents hours of debugging

7. **Document Stable API Contract**
   - Create API_STABILITY.md
   - List methods/signals guaranteed stable
   - Define deprecation policy (2 major versions notice)

### NICE TO HAVE (Future)

8. Scene templates and wizards
9. Visual grid editor plugin
10. Multi-level grid support (Vector3i)

---

## MODDABILITY SCORE

| Version | Score | Reasoning |
|---------|-------|-----------|
| **Current Proposal (As-Is)** | 6.5/10 | Solves duplication, but hardcoded modes and singleton conflicts block total conversions |
| **With Critical Changes (1-4)** | 9/10 | Data-driven, instance-isolated, extension points provided - platform-grade |
| **With All Recommended (1-7)** | 9.5/10 | Missing only battle-testing in production |

---

## COMPARISON TO PHASE 3 SUCCESS

**Phase 3 (Cinematics Refactor)** successfully demonstrated the right pattern:
- Executors are thin wrappers (not reimplementations)
- Delegate to reusable services (CameraController, GridManager)
- Registry pattern for extensibility
- Signal-based async operations

**This Grid Unification Should Follow the Same Model:**
- GridEntity as thin wrapper (not reimplementation)
- Delegate to GridInstance service (isolated state)
- Mode registry for extensibility
- Strategy pattern for custom behaviors

**What Worked in Phase 3 → Apply Here:**
```
Phase 3: CinematicsManager delegates to CameraController
Grid Unification: GridEntity delegates to GridInstance

Phase 3: Command executors registered in registry
Grid Unification: Mode configs registered in registry

Phase 3: Signal-based completion tracking
Grid Unification: Signal-based movement hooks
```

---

## IMPLEMENTATION RISKS

### LOW RISK (With Recommended Changes)
- Incremental migration (5 phases, backward compatible)
- Each phase independently testable
- Existing systems continue working during transition

### MEDIUM RISK (If Implemented As-Is)
- Hardcoded modes mean we'll need breaking changes later
- Singleton state means mod conflicts will be discovered in production
- Lack of extension points means modders will fork code

### HIGH RISK (If We Skip This Review)
- Ship a "unified" system that's actually less moddable than current separate systems
- Modders complain, reputation damage
- Forced to do Grid Unification 2.0 in 6 months

---

## NEXT STEPS

1. **Captain Decision:** Approve with critical changes, or defer until redesigned?

2. **If Approved:** Lt. Claudbrain updates proposal document with:
   - GridModeConfig resource design
   - GridInstance service locator pattern
   - Extension point specifications
   - Migration phases updated

3. **Before Implementation:** Create test mod to validate extensibility:
   ```
   Test Mod: "Stealth Tactics"
   - Custom GridModeConfig with vision cone collision
   - Custom PathfindingStrategy avoiding lit areas
   - Custom GridCoordinateSystem for irregular shapes
   ```
   If test mod works without editing core, we're ready.

4. **Phase 1 Implementation:**
   - GridModeConfig resource class
   - GridManager.create_instance() method
   - 3 built-in mode configs
   - Test suite validates isolation

---

## FINAL RECOMMENDATION

**APPROVE** Lt. Claudbrain's proposal with **CRITICAL CHANGES INTEGRATED**.

The core vision (consolidate duplication, standardize patterns, unify coordinate systems) is exactly what we need. The execution details must preserve extensibility. With the 4 critical changes, this becomes a world-class moddable grid system.

**Do Not Implement:**
- Hardcoded GridMode enum
- Stateful singleton GridManager
- Fixed layer naming without metadata fallback

**Do Implement:**
- GridModeConfig resource registry
- GridInstance service locator
- Extension points (strategy pattern, virtual methods, signals)
- Metadata-based layer detection

The path to 9/10 moddability is clear. Let's build a platform, not just a game.

---

**FULL REVIEW:** See `/home/user/dev/sparklingfarce/docs/MODRO_GRID_ARCHITECTURE_REVIEW.md` (comprehensive 40-page analysis)

**Modro out.**
