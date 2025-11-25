# Map Exploration System

## Overview

This is the Phase 1 implementation of the overworld map exploration system for The Sparkling Farce. It provides grid-based movement with party members following the hero in a snake-like pattern, inspired by Shining Force 2.

## Components

### Core Scripts

- **hero_controller.gd** - Main player character controller
  - Grid-based movement with smooth interpolation
  - 4-directional input (no diagonals)
  - Position history tracking for followers
  - Interaction system (RayCast-based)
  - Teleportation support for scene transitions

- **party_follower.gd** - Party member follower
  - Breadcrumb trail following algorithm
  - Smooth interpolation between positions
  - Configurable follow distance
  - Automatic facing direction updates

- **map_camera.gd** - Camera controller
  - Smooth following with lerp
  - Optional lookahead in movement direction
  - Snap-to-target for instant positioning

### Test Scenes

- **map_test_playable.tscn** - Interactive test scene
  - Loads party from PartyManager or creates test party
  - Visual representation of characters (colored squares + labels)
  - Grid overlay for reference
  - Debug controls

- **test_map_headless.tscn** - Automated headless test
  - Validates all systems programmatically
  - Simulates movement
  - Reports test results

## How to Test

### Method 1: Run the launcher script
```bash
./test_map_exploration.sh
```

### Method 2: Run directly from Godot
1. Open the project in Godot
2. Open `scenes/map_exploration/map_test_playable.tscn`
3. Press F5 or click "Run Current Scene"

### Method 3: Command line
```bash
godot --path /home/user/dev/sparklingfarce res://scenes/map_exploration/map_test_playable.tscn
```

## Controls

- **Arrow Keys** - Move the hero character
- **Enter / Z** - Interact (sf_confirm action)
- **F1** - Show debug position info
- **F2** - Teleport test (moves hero to grid 15,10)
- **ESC** - Quit test scene

## Features Implemented

✅ Grid-based movement (32x32 tiles)
✅ Smooth interpolation between tiles
✅ 4-directional input (up, down, left, right)
✅ Position history buffer (20 positions)
✅ Party follower system (breadcrumb trail)
✅ Camera following with smooth lerp
✅ Interaction ray casting
✅ Teleportation system
✅ Party data integration

## What's NOT Yet Implemented

The following features are planned for future phases:

⬜ TileMap collision detection (currently all tiles are walkable)
⬜ NPC interaction
⬜ Map trigger zones (battles, events, transitions)
⬜ Character sprites and animations
⬜ Terrain types and movement costs
⬜ Audio feedback (footsteps, interactions)
⬜ Map editor tools
⬜ Save/load map state

## Architecture Notes

### Position History System

The hero maintains a circular buffer of past positions. Each follower reads from this buffer at a different offset:
- Follower 1: 6 steps behind
- Follower 2: 12 steps behind
- Follower 3: 18 steps behind

This creates the classic "snake" following behavior.

### Movement System

Movement is handled in two stages:
1. **Input Processing** - Detects directional input and validates movement
2. **Interpolation** - Smoothly moves character from current tile to target tile

The `is_moving` flag prevents new movement commands while interpolation is in progress.

### Camera System

The camera uses lerp-based following with an optional lookahead feature that predicts where the hero is moving and adjusts the camera position ahead of time.

## Integration Points

This system is designed to integrate with:
- **PartyManager** - Loads party composition
- **DialogManager** - Blocks input during dialogs (TODO)
- **SceneManager** - Handles map transitions (TODO)
- **BattleManager** - Triggers battle encounters (TODO)

## Testing

Run the headless test to validate all systems:
```bash
godot --headless --path /home/user/dev/sparklingfarce res://scenes/map_exploration/test_map_headless.tscn
```

Expected output: All tests passing with movement simulation results.

## Next Steps (Phase 2)

1. Integrate TileMap collision detection
2. Add NPC interaction system
3. Create map trigger zones for battles
4. Implement character sprites and animations
5. Build map editor tools
