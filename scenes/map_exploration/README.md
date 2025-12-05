# Map Exploration System

## Overview

This is the Phase 1-2.5 implementation of the overworld map exploration system for The Sparkling Farce. It provides grid-based movement with party members following the hero in a snake-like pattern, inspired by Shining Force 2, now with full collision detection and trigger systems.

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
- **I** - Open/close Party Equipment menu (inventory & equipment)
- **F1** - Show debug position info
- **F2** - Teleport test (moves hero to grid 15,10)
- **ESC** - Quit test scene / Close menus

## Features Implemented

### Phase 1 - Movement & Following
✅ Grid-based movement (16x16 tiles for maps, 32x32 for battles)
✅ Smooth interpolation between tiles
✅ 4-directional input (up, down, left, right)
✅ Position history buffer (20 positions)
✅ Party follower system (breadcrumb trail)
✅ Camera following with smooth lerp
✅ Interaction ray casting
✅ Teleportation system
✅ Party data integration

### Phase 2.5 - Collision & Triggers
✅ TileMapLayer collision detection (hero blocked by walls/water)
✅ Proper 16px tile system with TileSet configuration
✅ MapTrigger system (Area2D-based with conditional activation)
✅ GameState autoload (story flags & trigger tracking)
✅ Battle trigger template (one-shot functionality)
✅ Story flag conditions (required/forbidden flags)
✅ Grid positioning using TileMapLayer.map_to_local() methods
✅ Test map with collision and working triggers

### Phase 2.5.5 - Inventory & Equipment UI
✅ **ExplorationUIManager** autoload - automatic UI for any exploration map
✅ **PartyEquipmentMenu** - multi-character equipment screen with tabs
✅ **CaravanDepotPanel** - SF2-style unlimited shared storage
✅ **InventoryPanel** - single character equipment/inventory display
✅ **ItemSlot** - 32x32 reusable slot component
✅ Input blocking - hero movement disabled while menus open
✅ Toggle behavior - press I to open/close
✅ Zero setup required - UI auto-activates on any map with "hero" group node

## What's NOT Yet Implemented

The following features are planned for future phases:

⬜ NPC interaction (framework ready)
⬜ Extended trigger types (doors, chests, dialogs - base system complete)
⬜ Character sprites and animations
⬜ Terrain types and movement costs
⬜ Audio feedback (footsteps, interactions)
⬜ Map editor tools
⬜ Scene transition system (Phase 2.5.2)
⬜ Save/load map state integration with GameState

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
- **PartyManager** - Loads party composition, item transfers
- **StorageManager** - Caravan depot shared storage
- **ExplorationUIManager** - Auto-activating inventory/equipment UI
- **DialogManager** - Blocks input during dialogs (TODO)
- **SceneManager** - Handles map transitions
- **BattleManager** - Triggers battle encounters, UI deactivates during battle

## Testing

Run the headless test to validate all systems:
```bash
godot --headless --path /home/user/dev/sparklingfarce res://scenes/map_exploration/test_map_headless.tscn
```

Expected output: All tests passing with movement simulation results.

## Next Steps (Phase 2.5.2 & Beyond)

1. ✅ ~~Integrate TileMap collision detection~~ (COMPLETE)
2. ✅ ~~Create map trigger zones for battles~~ (COMPLETE)
3. Scene transition system (battle → map return)
4. Extended trigger types (doors, chests, NPCs, dialogs)
5. Add NPC interaction system
6. Implement character sprites and animations
7. Build map editor tools

## Phase 2.5 Components

### New Core Systems
- **game_state.gd** - Story flags, trigger completion, campaign data
- **map_trigger.gd** - Extensible trigger base class with flag conditions

### New Assets
- **Placeholder tiles** - 16x16 grass, wall, water, road, door, battle_trigger
- **TileSets** - terrain_placeholder.tres, interaction_placeholder.tres
- **Battle trigger** - Reusable trigger scene template
- **Test map** - collision_test_001.tscn with working collision and triggers

### Documentation
- **docs/plans/phase-2.5-collision-triggers-plan.md** - Implementation plan
- **docs/guides/phase-2.5-setup-instructions.md** - Testing & setup guide
