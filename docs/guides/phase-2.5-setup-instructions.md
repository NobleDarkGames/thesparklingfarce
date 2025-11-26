# Phase 2.5 Setup Instructions - Collision & Trigger Testing

**Date:** November 25, 2025
**Phase:** 2.5 - Map Collision & Trigger System
**Status:** Implementation Complete - Testing Required

---

## What Was Implemented

Phase 2.5 implementation is **COMPLETE**. The following systems are now in place:

### ✅ Completed Components

1. **Placeholder Tileset Art** (`mods/_base_game/art/tilesets/placeholder/`)
   - grass.png (green) - Walkable terrain
   - wall.png (gray) - Impassable obstacle
   - water.png (blue) - Impassable water
   - road.png (brown) - Walkable path
   - door.png (yellow) - Trigger interaction
   - battle_trigger.png (red) - Battle encounter trigger

2. **TileSet Resources**
   - `mods/_base_game/tilesets/terrain_placeholder.tres` - Terrain tiles with collision
   - `mods/_base_game/tilesets/interaction_placeholder.tres` - Interaction tiles

3. **GameState Autoload** (`core/systems/game_state.gd`)
   - Story flag system (set_flag, has_flag, clear_flag)
   - Trigger completion tracking (set_trigger_completed, is_trigger_completed)
   - Campaign progress data
   - Save/load integration (export_state, import_state)

4. **MapTrigger Base Class** (`core/components/map_trigger.gd`)
   - Area2D-based trigger detection
   - TriggerType enum (BATTLE, DIALOG, CHEST, DOOR, CUTSCENE, TRANSITION, CUSTOM)
   - Conditional activation (required_flags, forbidden_flags)
   - One-shot functionality
   - Signal-based event dispatch

5. **Hero Collision Detection** (`scenes/map_exploration/hero_controller.gd`)
   - TileMapLayer reference added
   - `_is_tile_walkable()` now checks TileMap collision data
   - Hero added to "hero" group for trigger detection
   - Proper physics layer checking

6. **Battle Trigger Scene** (`mods/_base_game/triggers/battle_trigger.tscn`)
   - Pre-configured MapTrigger with BATTLE type
   - 32x32 collision shape
   - Debug visual (red semi-transparent, hidden by default)
   - Ready to instantiate in maps

7. **Test Map Scene** (`mods/_base_game/maps/test/collision_test_001.tscn`)
   - Configured with terrain_placeholder tileset
   - Hero controller integrated
   - Camera setup
   - Ready for tile painting

---

## What You Need to Do (Godot Editor)

The code implementation is complete, but you need to configure and test in the Godot editor.

### Step 1: Open the Project

1. Launch Godot 4.5
2. Open The Sparkling Farce project
3. Wait for initial asset import/reload

---

### Step 2: Verify TileSet Configuration

The TileSet resources were created programmatically but may need verification:

1. Open `mods/_base_game/tilesets/terrain_placeholder.tres` in the editor
2. In the TileSet panel (bottom of editor), verify:
   - **Grass tile** (Source ID 0) - No collision polygon
   - **Wall tile** (Source ID 1) - Has collision polygon (full 16x16 square)
   - **Water tile** (Source ID 2) - Has collision polygon (full 16x16 square)
   - **Road tile** (Source ID 3) - No collision polygon

**If collision polygons are missing:**

1. Select the tile source (wall or water)
2. Click the "Physics" tab in the tile editor
3. Select "Physics Layer 0"
4. Draw a collision polygon covering the entire 16x16 tile
5. Repeat for other obstacle tiles

---

### Step 3: Paint the Test Map

1. Open `mods/_base_game/maps/test/collision_test_001.tscn`
2. Select the `TileMapLayer` node
3. In the TileMap editor (bottom panel):
   - Select the terrain_placeholder TileSet
   - Choose grass (green) and paint a large walkable area
   - Choose wall (gray) and paint borders/obstacles
   - Choose water (blue) and paint water sections
   - Choose road (brown) and paint paths

**Suggested Test Map Layout:**
```
W W W W W W W W W W W
W G G G W G G G G G W
W G G G W G G G G G W
W G G G W G G G G G W
W W W O W G G G G G W
W G G G G G W W W G W
W G G G G G W ~ ~ W W
W G G G G G W ~ ~ W W
W G G G G G W W W W W
W G G G G G G G G G W
W W W W W W W W W W W

Legend:
W = Wall (gray)
G = Grass (green)
~ = Water (blue)
O = Opening (gap in wall)
```

---

### Step 4: Add a Battle Trigger

1. In the scene tree, right-click the root node (`CollisionTest001`)
2. Select "Instantiate Child Scene"
3. Navigate to `mods/_base_game/triggers/battle_trigger.tscn`
4. Select and instantiate it
5. In the Inspector panel, configure the trigger:
   - **trigger_id**: `"test_battle_001"`
   - **trigger_type**: `BATTLE` (should be default)
   - **one_shot**: `true` (should be default)
   - **trigger_data**: Add key `"battle_id"`, value `"tutorial_battle_001"`
6. Position the trigger in the map (drag in 2D viewport)
   - Place it in an open walkable area (grass)
   - Position: ~(160, 256) or similar

**Optional:** Enable the DebugVisual node to see the trigger area (red transparent square)

---

### Step 5: Test Collision Detection

1. Save the collision_test_001.tscn scene
2. Run the scene (F6 or play button with scene selected)
3. **Test 1: Movement**
   - Use arrow keys to move the hero (green square)
   - **Expected:** Hero can walk on grass and road
   - **Expected:** Hero CANNOT walk through walls or water
4. **Test 2: Boundaries**
   - Try to walk into walls from all directions
   - **Expected:** Hero stops at wall edge, doesn't pass through
5. **Test 3: Gaps**
   - Walk through the opening in the wall
   - **Expected:** Hero can pass through gaps normally

**If collision isn't working:**
- Check TileSet collision polygons (Step 2)
- Verify HeroController has TileMapLayer reference (check console for warnings)
- Ensure tiles are painted on the TileMapLayer, not a different layer

---

### Step 6: Test Battle Trigger

**Important:** Battle trigger will only work if a battle exists with matching ID.

**Quick Test (without full battle system):**

1. Open the battle trigger scene properties
2. Connect the `triggered` signal to a test function:
   ```gdscript
   func _on_battle_trigger_triggered(trigger, player):
       print("Battle trigger activated! Battle ID: ", trigger.trigger_data["battle_id"])
       print("Trigger marked as completed: ", GameState.is_trigger_completed("test_battle_001"))
   ```
3. Run the scene
4. Walk the hero onto the trigger position
5. **Expected Console Output:**
   ```
   Battle trigger activated! Battle ID: tutorial_battle_001
   Trigger marked as completed: true
   ```
6. Walk away and return to the trigger
7. **Expected:** Trigger does NOT activate again (one-shot)

**Full Battle Integration Test (if battle system is available):**

1. Ensure a battle with ID `"tutorial_battle_001"` exists in `mods/_base_game/battles/`
2. Implement TriggerManager or connect MapTrigger.triggered to BattleManager
3. Run the scene
4. Walk onto the trigger
5. **Expected:** Battle scene loads
6. Complete the battle
7. **Expected:** Return to map at hero's position
8. **Expected:** Trigger doesn't re-activate (completed)

---

### Step 7: Test Story Flags

**Manual Flag Testing:**

1. Open the Godot console/debugger
2. Add this test code to map_test.gd `_ready()`:
   ```gdscript
   func _ready() -> void:
       # Test flag system
       print("Flag 'test_flag' initially: ", GameState.has_flag("test_flag"))
       GameState.set_flag("test_flag", true)
       print("Flag 'test_flag' after set: ", GameState.has_flag("test_flag"))
       GameState.clear_flag("test_flag")
       print("Flag 'test_flag' after clear: ", GameState.has_flag("test_flag"))
   ```
3. Run the map
4. **Expected Console Output:**
   ```
   Flag 'test_flag' initially: false
   Flag 'test_flag' after set: true
   Flag 'test_flag' after clear: false
   ```

**Conditional Trigger Testing:**

1. Duplicate the battle trigger (name it `BattleTrigger_Conditional`)
2. Configure it:
   - **trigger_id**: `"conditional_test"`
   - **required_flags**: `["flag_example"]`
3. Position it in a different location
4. Run the scene
5. Walk onto the conditional trigger
6. **Expected:** Nothing happens (flag not set)
7. Open console and run: `GameState.set_flag("flag_example", true)`
8. Walk onto the trigger again
9. **Expected:** Trigger activates now

---

## Success Criteria

Phase 2.5 is **VERIFIED** when all of the following work:

- [ ] Hero can walk on grass and road tiles
- [ ] Hero CANNOT walk through wall or water tiles
- [ ] Battle trigger activates when hero enters its area
- [ ] Battle trigger only activates once (one-shot)
- [ ] Trigger completion is tracked in GameState
- [ ] Story flags can be set, checked, and cleared
- [ ] Conditional triggers respect required_flags

---

## Next Steps After Verification

Once Phase 2.5 is verified:

1. **Integrate with SaveManager**
   - Add GameState.export_state() to SaveData
   - Add GameState.import_state() when loading saves
   - Test that trigger completion persists across saves

2. **Create TriggerManager Autoload** (Phase 2.5.2)
   - Dispatcher that listens to MapTrigger.triggered signals
   - Routes BATTLE triggers to BattleManager
   - Routes DIALOG triggers to DialogManager
   - Routes other trigger types to appropriate handlers

3. **Scene Transition System** (Phase 2.5.3)
   - BattleManager returns to map after battle completion
   - Store pre-battle map scene and hero position
   - Restore hero position after battle victory

4. **Extended Trigger Types** (Phase 2.5.4)
   - Implement chest triggers (grant items, one-shot)
   - Implement door triggers (scene transitions, key checks)
   - Implement dialog triggers (NPC conversations)

---

## Troubleshooting

### Hero walks through walls

**Cause:** Collision polygons not configured on wall/water tiles

**Fix:**
1. Open `mods/_base_game/tilesets/terrain_placeholder.tres`
2. Select wall tile source
3. Go to Physics tab → Physics Layer 0
4. Draw collision polygon covering entire 16x16 tile
5. Repeat for water tile

---

### Trigger doesn't activate

**Cause 1:** Hero not in "hero" group

**Fix:** Hero is now automatically added to group in _ready() - check console for errors

**Cause 2:** Trigger collision layers wrong

**Fix:**
1. Select BattleTrigger node
2. Inspector → Collision Layer: 2
3. Inspector → Collision Mask: 1

**Cause 3:** Trigger already completed

**Fix:** Reset GameState: `GameState.reset_trigger("test_battle_001")`

---

### Console shows "No TileMapLayer found"

**Cause:** Hero can't find TileMapLayer sibling

**Fix:**
1. Ensure scene structure is:
   ```
   RootNode
   ├─ TileMapLayer (must be named exactly this)
   ├─ Hero
   ```
2. If TileMapLayer is nested differently, update hero_controller.gd line 46

---

## Files Modified/Created

### New Files
- `core/systems/game_state.gd` - Story flag & trigger tracking
- `core/components/map_trigger.gd` - Trigger base class
- `mods/_base_game/art/tilesets/placeholder/*.png` - 6 tile images
- `mods/_base_game/art/tilesets/placeholder/README.txt` - Replacement guide
- `mods/_base_game/tilesets/terrain_placeholder.tres` - Terrain tileset
- `mods/_base_game/tilesets/interaction_placeholder.tres` - Interaction tileset
- `mods/_base_game/triggers/battle_trigger.tscn` - Battle trigger template
- `mods/_base_game/maps/test/collision_test_001.tscn` - Test map
- `docs/plans/phase-2.5-collision-triggers-plan.md` - Implementation plan
- `docs/guides/phase-2.5-setup-instructions.md` - This file

### Modified Files
- `project.godot` - Added GameState autoload
- `mods/_base_game/mod.json` - Added provides/example_overrides
- `scenes/map_exploration/hero_controller.gd` - Collision detection implemented

---

## Questions?

If you encounter issues not covered here:
1. Check console for warnings/errors
2. Review `/docs/plans/phase-2.5-collision-triggers-plan.md` for architectural details
3. Verify Godot version is 4.5+
4. Ensure project settings have strict typing enabled

---

**Captain, Phase 2.5 implementation is complete and ready for your testing verification.**

Make it so! 🖖
