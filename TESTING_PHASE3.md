# Phase 3 Manual Testing Guide

## How to Test the Current Build

### Prerequisites
1. Open the project in Godot 4.5+
2. Ensure the Sparkling Editor plugin is enabled (Project → Settings → Plugins)
3. Current main scene is set to `res://mods/_sandbox/scenes/test_unit.tscn`

### Test Scene: Unit Movement and Combat

**What's Currently Implemented:**
- GridManager with A* pathfinding
- Unit spawning from CharacterData
- Grid-based movement
- Basic combat system
- Health tracking

**How to Run:**
1. Press **F5** or click the "Play" button in Godot
2. The test scene will launch with:
   - A Hero unit (cyan, left side at position 3,5)
   - A Goblin enemy (red, right side at position 10,5)
   - A checkerboard battlefield grid

**Controls:**
- **Left Click on Ground**: Move Hero to clicked cell
  - If the cell is within movement range (4 tiles), Hero will move there
  - If out of range, blue highlights show walkable cells
  - If occupied, nothing happens
  - **Camera follows Hero automatically** as they move

- **SPACE**: Attack the enemy
  - Only works if Hero is adjacent to Goblin (1 tile away)
  - Damage is calculated: Hero STR (8) - Goblin DEF (4) = 4 damage
  - Goblin has 12 HP, so it takes 3 hits to defeat

- **ESC**: Quit the test

**Note:** Camera is locked to the active unit (Hero). Free camera movement will be designed in Phase 3, Week 2 with the InputManager.

**What to Look For:**

✅ **Grid Movement:**
- Click near Hero → movement range highlights appear (blue overlay)
- Click a highlighted cell → Hero moves to it instantly
- Grid manager prevents moving to occupied cells
- Pathfinding works around obstacles

✅ **Combat:**
- Press SPACE when next to Goblin → damage numbers in console
- Goblin's health bar decreases
- After 3 attacks, Goblin fades out and dies

✅ **Debug Info:**
- Top-left label shows:
  - Current mouse grid position
  - Hero stats (HP, MP, STR, DEF, etc.)
  - Goblin stats
  - Controls reminder

**Expected Console Output:**
```
GridManager: A* grid initialized
GridManager: Initialized with grid size (20, 11), cell size 32
Unit initialized: Hero (Lv1 player)
Unit initialized: Goblin (Lv1 enemy)
=== Unit Test Scene Ready ===
Player unit: Lv1 HP:15/15 MP:10/10 STR:8 DEF:7 AGI:6 INT:5 LUK:4
Enemy unit: Lv1 HP:12/12 MP:5/5 STR:6 DEF:4 AGI:5 INT:3 LUK:3
```

---

## Alternative Test Scene: GridManager Only

**To test just pathfinding without units:**

1. Change main scene to `res://mods/_sandbox/scenes/test_grid_manager.tscn`
   - Project → Project Settings → Application → Run → Main Scene
2. Press F5

**Controls:**
- **Left Click**: Calculate path from green marker to clicked cell
  - Red overlay shows the path
  - Path is printed in console
- **SPACE**: Toggle movement range display
  - Blue overlay shows all cells within 5 tiles
- **ESC**: Quit

---

## Testing in Godot Editor (Scene Tab)

**You can also test without running:**

1. Open `res://mods/_sandbox/scenes/test_unit.tscn` in the editor
2. In the Scene tree, select nodes to inspect:
   - **Units/Unit** - See unit properties
   - **Map/GroundLayer** - View tilemap
   - **Map/HighlightLayer** - See highlight system

3. Select **Units/Unit** node and look at:
   - Inspector → Script Variables
   - `character_data` (should reference a CharacterData)
   - `grid_position` (Vector2i)
   - `faction` (String)

4. You can modify values in the Inspector:
   - Change `test_movement_range` on TestUnit root node
   - Adjust unit spawn positions in the script

---

## Creating Your Own Test Battle

**Want to test with different characters?**

1. Open Sparkling Editor (bottom panel)
2. Go to **Characters** tab
3. Create a new character or edit existing ones
4. Go to **Classes** tab and ensure classes have:
   - Movement range set (default: 4)
   - Movement type chosen (Walking, Flying, Floating)

5. Modify test script to use your characters:
   ```gdscript
   # In test_unit.gd, _ready() function:
   var player_character: CharacterData = load("res://mods/_base_game/data/characters/your_hero.tres")
   var enemy_character: CharacterData = load("res://mods/_base_game/data/characters/your_enemy.tres")
   ```

---

## Common Issues & Solutions

### Issue: "Unit doesn't move when I click"
**Solution:**
- Check console for errors
- Ensure clicked cell is within movement range (4 tiles by default)
- Unit may already be at that position

### Issue: "Attack doesn't work"
**Solution:**
- Move Hero adjacent to Goblin first (1 tile away)
- Attack only works when distance = 1

### Issue: "No visual feedback"
**Solution:**
- Highlight layer may be hidden
- Check that TileMapLayer "HighlightLayer" has modulate alpha > 0

### Issue: "Unit appears as colored square"
**Solution:**
- This is expected! We're using placeholder sprites
- Cyan square = Player unit
- Red square = Enemy unit
- Actual sprite support comes in Phase 3.5

---

## What's NOT Implemented Yet

❌ **Not in this build:**
- Turn-based system (units can move unlimited times)
- Player/Enemy phase separation
- AI behavior (enemies don't act)
- Ability usage (only basic attack)
- Item usage
- Status effects (poison, buffs, etc.)
- Victory/Defeat conditions
- Multiple player units (only 1 hero)
- Animation (movement is instant teleport)
- Sound effects
- Battle UI (action menus, unit info panels)

These features are coming in **Week 2-4** of Phase 3!

---

## Performance Testing

**Check FPS:**
- Debug → Deploy with Remote Debug
- In running game, press F3 to show FPS counter
- Should maintain 60 FPS easily with current implementation

**Pathfinding Stress Test:**
- Rapidly click different cells
- GridManager should handle without lag
- Console should show path calculations < 1ms

---

## Next Steps After Testing

Once you've verified the current functionality:

1. ✅ Confirm GridManager pathfinding works
2. ✅ Confirm Units spawn and move correctly
3. ✅ Confirm basic combat applies damage
4. ➡️ Ready to implement TurnManager (Phase 3, Week 2)
5. ➡️ Ready to implement InputManager (Phase 3, Week 2)

**Report any bugs or unexpected behavior!**

---

**Last Updated:** November 14, 2025
**Phase:** 3.1 - Grid & Units
**Status:** Ready for Manual Testing
