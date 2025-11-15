# Testing Guide - Phase 3 Week 3 (BattleManager & Combat)

## What We're Testing

The complete integration of:
1. **BattleManager** - Battle orchestration and combat execution
2. **CombatCalculator** - Damage formulas and combat math
3. **Proper separation of concerns** - Map scenes contain Grid, BattleData references map
4. **Full combat flow** - Move → Action Menu → Target → Execute → Damage → Turn End

---

## Test Scene

**Location**: `res://mods/_sandbox/scenes/test_full_battle.tscn`

This scene creates a complete battle programmatically to test all systems working together.

### What It Tests

1. **BattleData Creation** (content layer)
   - Creating battle data programmatically
   - Referencing a map scene
   - Defining player and enemy units

2. **Map Scene with Grid** (proper architecture)
   - Map scene contains its own Grid resource
   - BattleManager extracts Grid FROM map
   - No hardcoded grid info in BattleData

3. **BattleManager Orchestration** (engine layer)
   - Loads BattleData
   - Instantiates map scene
   - Extracts Grid from map
   - Spawns units at correct positions
   - Initializes TurnManager

4. **Combat Flow**
   - Turn order (AGI-based, Shining Force style)
   - Player input → action selection → targeting
   - CombatCalculator damage formulas
   - Hit/miss/crit mechanics
   - Unit death handling
   - Turn advancement

---

## How to Run the Test

### Method 1: Direct Play (Recommended)

1. Open Godot editor
2. Open scene: `res://mods/_sandbox/scenes/test_full_battle.tscn`
3. Press **F6** (Play Scene) or click "Play Scene" button
4. Watch console output for detailed logs

### Method 2: Set as Main Scene

1. Project → Project Settings → Application → Run
2. Set Main Scene: `res://mods/_sandbox/scenes/test_full_battle.tscn`
3. Press **F5** (Play Project)

---

## Expected Behavior

### 1. Scene Initialization

Console should show:
```
==================================================
TEST: Full Battle Flow with BattleManager
==================================================

TEST: Creating test BattleData...
TEST: Created test character: Hero
TEST: Created test character: Goblin
TEST: Created test character: Orc
TEST: Created 1 player units
TEST: Created 2 enemy units
TEST: BattleData created successfully

TEST: Starting battle...

========================================
BattleManager: Starting battle - Test Battle - BattleManager Integration
========================================

TestMap: Created default Grid (20, 11)
BattleManager: Map scene loaded
BattleManager: Grid initialized from map (20 x 11)
BattleManager: Units spawned - 1 player, 2 enemy, 0 neutral
BattleManager: Signals connected
BattleManager: Battle initialized successfully

=== Battle Started ===
Total units: 3

--- Turn Order Calculated ---
  1. Hero (PLAYER) - AGI 6.0 → Priority X.XX
  2. Goblin (ENEMY) - AGI 5.0 → Priority X.XX
  3. Orc (ENEMY) - AGI 4.0 → Priority X.XX

========== TURN 1 ==========

--- Hero's Turn ---
Waiting for player input...
InputManager: Player turn started for Hero at (3, 5)
InputManager: X walkable cells
```

### 2. Player Turn Flow

**Step 1: Movement**
- Grid cursor appears on Hero's position
- Blue highlights show walkable cells (4 tile range)
- Click a highlighted cell OR use arrow keys + Enter
- Hero moves to selected position
- Console: `InputManager: Moving unit to (X, Y)`

**Step 2: Action Menu**
- Menu appears with options: Attack, Magic, Item, Stay
- "Attack" is highlighted if enemies in range (1 tile)
- Click an action or use arrow keys + Enter

**Step 3: Targeting** (if Attack selected)
- Click on an enemy unit (Goblin or Orc)
- Console shows combat resolution:
  ```
  BattleManager: Executing attack - Hero -> Goblin
    → HIT! 4 damage (80% hit chance)
  ```
  OR
  ```
    → MISS! (75% hit chance)
  ```

**Step 4: Damage Applied**
- Enemy's HP decreases
- If HP reaches 0:
  ```
    → Goblin was defeated!
  ```
- Enemy fades out
- Turn ends

### 3. Enemy Turn

```
--- Goblin's Turn ---
AI processing...
```

Currently enemies just wait 0.5s and end turn (AI implementation is Week 4).

### 4. Turn Cycle

After all 3 units act:
```
========== TURN 2 ==========

--- Turn Order Calculated ---
  (new randomized AGI order)
```

### 5. Victory

When all enemies defeated:
```
========================================
VICTORY!
========================================

BattleManager: Battle ended
```

---

## What to Verify

### ✅ Architecture (Separation of Concerns)

- [ ] BattleData doesn't contain Grid resource
- [ ] Map scene provides Grid to BattleManager
- [ ] BattleManager extracts Grid automatically
- [ ] No errors about missing grid

### ✅ Battle Initialization

- [ ] Map scene loads and displays (checkerboard pattern)
- [ ] Grid dimensions correct (20x11)
- [ ] 1 player unit spawns at position (3, 5)
- [ ] 2 enemy units spawn at positions (16, 5) and (16, 6)
- [ ] Turn order calculated (AGI-based)

### ✅ Turn System

- [ ] Turn order shows player and enemy units intermixed
- [ ] AGI randomization creates variety
- [ ] Active unit's turn starts
- [ ] Player units trigger InputManager
- [ ] Enemy units trigger AI (currently just waits)

### ✅ Input & Movement

- [ ] Cursor appears on active unit
- [ ] Walkable cells highlighted (4 tile range)
- [ ] Click or keyboard movement works
- [ ] Unit moves to selected cell
- [ ] Action menu appears after movement

### ✅ Combat Execution

- [ ] Attack action available when enemy in range
- [ ] Targeting cursor works
- [ ] Click enemy to target
- [ ] BattleManager executes attack (not InputManager)
- [ ] CombatCalculator computes damage
- [ ] Hit/miss roll works
- [ ] Critical hit occasionally occurs (low chance)
- [ ] Damage applied to defender
- [ ] Console shows damage numbers

### ✅ Unit Death

- [ ] Unit at 0 HP triggers death handler
- [ ] Unit fades out (modulate alpha → 0)
- [ ] Dead units skipped in turn queue
- [ ] Victory condition checked

### ✅ Turn Advancement

- [ ] After action, turn ends
- [ ] Next unit in queue starts turn
- [ ] When queue empty, new cycle starts
- [ ] Turn counter increments

### ✅ Victory

- [ ] All enemies defeated → Victory message
- [ ] Battle ends cleanly
- [ ] No crashes or errors

---

## Controls

- **Mouse Click**: Select cell for movement or targeting
- **Arrow Keys**: Move cursor (during movement phase)
- **Enter/Space**: Confirm selection
- **ESC**: Quit test
- **R**: Restart battle (reload scene)

---

## Expected Console Output (Sample)

```
TEST: Full Battle Flow with BattleManager
TEST: Creating test BattleData...
TEST: Loaded existing character: Max
TEST: Created 1 player units
TEST: Created test character: Goblin
TEST: Created test character: Orc
TEST: Created 2 enemy units
TEST: BattleData created successfully

TEST: Starting battle...

BattleManager: Starting battle - Test Battle - BattleManager Integration
TestMap: Created default Grid (20, 11)
GridManager: A* grid initialized
GridManager: Initialized with grid size (20, 11), cell size 32
BattleManager: Grid initialized from map (20 x 11)
Unit initialized: Max (Lv1 player)
BattleManager: unit spawned
Unit initialized: Goblin (Lv1 enemy)
BattleManager: unit spawned
Unit initialized: Orc (Lv1 enemy)
BattleManager: unit spawned
BattleManager: Units spawned - 1 player, 2 enemy, 0 neutral

=== Battle Started ===
Total units: 3

--- Turn Order Calculated ---
  1. Max (PLAYER) - AGI 6 → Priority 6.45
  2. Goblin (ENEMY) - AGI 5 → Priority 5.12
  3. Orc (ENEMY) - AGI 4 → Priority 3.89

========== TURN 1 ==========

--- Max's Turn ---
Waiting for player input...
InputManager: Player turn started for Max at (3, 5)
InputManager: 49 walkable cells

[User clicks cell (5, 5)]
InputManager: Moving unit to (5, 5)
InputManager: Action selected: Attack

[User clicks enemy]
BattleManager: Target selected - Max targets Goblin

BattleManager: Executing attack - Max -> Goblin
  → HIT! 4 damage (82% hit chance)
  Goblin: 12 HP → 8 HP

--- Goblin's Turn ---
AI processing...
Goblin's turn ended

--- Orc's Turn ---
AI processing...
Orc's turn ended

========== TURN 2 ==========
[continues...]
```

---

## Troubleshooting

### Issue: "BattleManager autoload not found"
**Solution**: Check `project.godot` has `BattleManager="*res://core/systems/battle_manager.gd"` under `[autoload]`

### Issue: "Map scene must provide a Grid resource"
**Solution**: This validates the architecture - map scenes MUST export a Grid. The test scene creates one automatically.

### Issue: "Invalid BattleData"
**Solution**: Check console for specific validation error. BattleData.validate() runs automatically.

### Issue: No units spawn
**Solution**:
- Check console for spawn errors
- Verify CharacterData has `character_class` set
- Ensure positions are within grid bounds (20x11)

### Issue: Action menu doesn't appear
**Solution**:
- Check that movement completed (console shows "Moving unit to...")
- Verify InputManager state changed to SELECTING_ACTION
- Look for action menu initialization errors

### Issue: Attack does nothing
**Solution**:
- Ensure enemy is adjacent (1 tile away)
- Check console for "Executing attack" message
- Verify BattleManager signals are connected

### Issue: Damage seems wrong
**Solution**:
- Check CombatCalculator formula: `(STR - DEF) * variance(0.9-1.1)`
- Hero STR=8, Goblin DEF=4 → base 4 damage
- Variance means 3-5 damage range
- Critical hits double damage

---

## Known Limitations (Week 3)

These are intentional and will be addressed later:

- ❌ **No AI behavior yet** - Enemies just end turn (Week 4)
- ❌ **No counterattacks** - One-way damage only (Phase 4)
- ❌ **No magic system** - Attack only (Phase 4)
- ❌ **No item usage** - Menu exists but not functional (Phase 4)
- ❌ **No animations** - Instant movement, simple fade on death (Phase 3.5)
- ❌ **No sound effects** - Silent combat (Phase 4)
- ❌ **No battle UI** - Console-only feedback (Week 4)
- ❌ **No experience/leveling** - Units don't gain XP (Phase 4)

---

## Success Criteria

The test is successful if:

1. ✅ Battle loads without errors
2. ✅ Map displays with grid (20x11 checkerboard)
3. ✅ 3 units spawn (1 player, 2 enemies)
4. ✅ Turn order calculated (AGI-based)
5. ✅ Player can move unit (click or keyboard)
6. ✅ Action menu appears after movement
7. ✅ Attack action can be selected
8. ✅ Enemy can be targeted
9. ✅ Damage is calculated and applied
10. ✅ Enemy dies when HP reaches 0
11. ✅ Turn advances to next unit
12. ✅ Victory triggers when all enemies defeated
13. ✅ No crashes, no errors

---

## Next Steps After Testing

Once this test passes:

1. **Week 4 Task 1**: Implement basic AI
   - Aggressive: Move toward player, attack when in range
   - Stationary: Don't move, attack if in range
   - Defensive: Only attack if attacked first

2. **Week 4 Task 2**: Create real battle content
   - Proper map scenes with TileMapLayer
   - BattleData resources in Sparkling Editor
   - Test with actual game content (not programmatic)

3. **Week 4 Task 3**: Battle UI
   - Unit info panels
   - HP bars
   - Damage numbers (floating text)
   - Victory/defeat screens

4. **Week 4 Task 4**: Polish
   - Movement animation (smooth tween)
   - Attack animation (unit slides toward target)
   - Camera follow improvements
   - Demo battle scenario

---

**Created**: Phase 3, Week 3 completion
**Status**: Ready for testing
**Next Review**: After manual testing confirms all systems working
