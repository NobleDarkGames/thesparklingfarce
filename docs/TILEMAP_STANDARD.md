# TileMapLayer Standard for Battle Scenes

## Overview

This document defines the standard TileMapLayer structure for battle scenes in The Sparkling Farce. Following this convention ensures consistency between battles and cinematics, making the codebase easier to maintain and mod.

## Standard Layer Structure

All battle scenes **MUST** include these layers under a `Map` Node2D parent:

### Required Layers

#### 1. GroundLayer (TileMapLayer)
- **Purpose:** Terrain visuals (grass, stone, dirt, roads, etc.)
- **Z-Index:** 0 (default)
- **Collision:** No (visual only)
- **TileSet:** Battle-specific terrain tileset (32x32 tiles)

#### 2. WallsLayer (TileMapLayer)
- **Purpose:** Impassable obstacles (walls, water, cliffs, trees)
- **Z-Index:** 1
- **Collision:** Yes - used by GridManager for pathfinding
- **TileSet:** Same as GroundLayer or separate obstacle tileset
- **Note:** GridManager checks this layer for collision detection

### Optional Layers

#### 3. DecorationLayer (TileMapLayer)
- **Purpose:** Visual-only decorations (flowers, rubble, shadows, effects)
- **Z-Index:** 2
- **Collision:** No
- **TileSet:** Decoration-specific tileset
- **Note:** Can be omitted if not needed

#### 4. HighlightLayer (TileMapLayer)
- **Purpose:** Battle UI - movement ranges, attack ranges, selection highlights
- **Z-Index:** 10 (above all other layers)
- **Collision:** No
- **TileSet:** highlight_tileset.tres
- **Note:** Programmatically controlled by BattleManager, not painted in editor

## Scene Structure Example

```
BattleScene (Node2D)
├─ Background (ColorRect)
├─ Map (Node2D)
│  ├─ GroundLayer (TileMapLayer)      # Terrain visuals
│  ├─ WallsLayer (TileMapLayer)       # Collision obstacles
│  ├─ DecorationLayer (TileMapLayer)  # Optional: Visual decorations
│  └─ HighlightLayer (TileMapLayer)   # Battle UI highlights
├─ Units (Node2D)                      # Player and enemy units
├─ Effects (Node2D)                    # Particle effects, animations
├─ Camera (Camera2D + CameraController)
└─ UI (CanvasLayer)
```

## Tile Size

- **Standard:** 32x32 pixels
- **Battle scenes MUST use 32x32** for consistency with GridManager
- Exploration scenes may use different sizes (typically 16x16)

## GridManager Integration

Battle scenes must provide these to GridManager:

```gdscript
# In battle scene script
@export var grid: Grid                     # Grid resource with cell_size = 32
@export var walkable_layer: TileMapLayer   # Usually GroundLayer
@export var collision_layer: TileMapLayer  # Usually WallsLayer

func _ready() -> void:
    GridManager.setup_grid(grid, collision_layer)
```

## Cinematics Compatibility

Cinematic scenes that contain battles (mid-battle cutscenes, enemy reinforcements) **SHOULD** follow this same structure. This ensures:

- Characters move consistently between gameplay and cinematics
- GridManager pathfinding works in both contexts
- Mod-created cinematics integrate smoothly with battles

Standalone story cinematics (pre-battle, post-battle) do **NOT** require TileMapLayers - they can use simple Node2D structures.

## For Modders

### Creating a New Battle Map

1. Duplicate `/scenes/battle_scene.tscn` as your starting template
2. Paint terrain tiles on `GroundLayer`
3. Paint obstacles on `WallsLayer` (these block movement)
4. Optionally add decorations on `DecorationLayer`
5. Leave `HighlightLayer` empty (it's controlled by code)
6. Configure your Grid resource with appropriate `grid_size`

### Layer Naming is Important

The names `GroundLayer`, `WallsLayer`, etc. are **conventions, not requirements**. However:

- Code and documentation assume these names
- Other modders will expect this structure
- Following the convention makes debugging easier

You CAN use different names if needed, but you'll need to manually wire them to GridManager via exported properties.

## Migration from Old Scenes

If you have existing battle scenes with different layer names:

1. Rename layers to match this standard:
   - `ObjectsLayer` → `WallsLayer`
   - `TerrainLayer` → `GroundLayer`
2. Ensure `WallsLayer` has collision enabled if needed
3. Set z-index values as specified above
4. Test that GridManager pathfinding still works

## Questions?

See `/docs/PHASE_3_COMPLETE.md` for details on how cinematics integrate with the battle system.

---

**Version:** 1.0
**Last Updated:** 2025-11-26
**Starfleet Approved** by Commander Claudius, Lt. Claudbrain, and Modro
