# Simple Test Guide - BattleManager & CombatCalculator

## Quick Test Scene

**Location**: `res://mods/_sandbox/scenes/test_battle_manager.tscn`

This is a **minimal, working test** that demonstrates:
- ✅ CombatCalculator damage formulas
- ✅ Hit/miss/crit mechanics
- ✅ BattleManager setup
- ✅ Unit spawning with correct colors
- ✅ Visual grid display

---

## How to Run

### In Godot Editor

```bash
1. Open: res://mods/_sandbox/scenes/test_battle_manager.tscn
2. Press F6 (Play Scene)
3. You should see:
   - Green checkerboard grid (20×11)
   - Cyan square at left (Hero)
   - Red square at right (Goblin)
```

### Controls

- **SPACE**: Attack enemy (tests combat!)
- **ESC**: Quit

---

## Expected Behavior

### Visual

- Green 20×11 grid
- **Cyan square** (Hero) at grid position (3, 5)
- **Red square** (Goblin) at grid position (10, 5)

### Console Output

```
========================================
TEST: BattleManager & CombatCalculator
========================================

GridManager: Initialized with grid size (20, 11), cell size 32
Unit initialized: Hero (Lv1 player)
Unit initialized: Goblin (Lv1 enemy)
Units spawned:
  - Hero at (3, 5) (cyan square)
  - Goblin at (10, 5) (red square)

BattleManager initialized

Controls:
  SPACE: Attack enemy (tests CombatCalculator)
  ESC: Quit

Press SPACE to test combat!
```

### When You Press SPACE

```
--- Testing Combat ---
Hero attacks Goblin!
  Hit chance: 82%
  → HIT! 4 damage
  Goblin: 8/12 HP

(Press SPACE again to attack)
```

After 3 hits:
```
🎉 Goblin defeated! Victory!
```

---

## What This Tests

### CombatCalculator Formulas

```gdscript
# Hit chance
CombatCalculator.calculate_hit_chance(attacker, defender)
# Base 80% + (Attacker AGI - Defender AGI) * 2
# Hero AGI 6, Goblin AGI 5 → 80% + 2% = 82%

# Damage
CombatCalculator.calculate_physical_damage(attacker, defender)
# (Attacker STR - Defender DEF) * variance(0.9-1.1)
# Hero STR 8, Goblin DEF 4 → 4 * ~1.0 = 4 damage

# Critical hit
CombatCalculator.calculate_crit_chance(attacker, defender)
# Base 5% + (Attacker LUK - Defender LUK)
# Hero LUK 4, Goblin LUK 3 → 6% crit chance
```

### BattleManager Setup

- Tracks all units (player + enemy)
- References Units container node
- Ready for combat execution (Week 4)

---

## Success Criteria

✅ **Scene loads without errors**
✅ **Units visible** (cyan and red squares)
✅ **Grid renders** (green checkerboard)
✅ **Combat works** (press SPACE, see damage)
✅ **Hit/miss rolls** (sometimes attacks miss)
✅ **Critical hits** (rare, double damage)
✅ **Death handling** (enemy fades at 0 HP)

---

## Next Steps

After confirming this works:

1. **Week 4 Task**: Integrate with TurnManager for turn-based flow
2. **Week 4 Task**: Add enemy AI (currently manual testing only)
3. **Week 4 Task**: Create real BattleData and test full BattleManager flow

---

## Why This Test is Simple

This test intentionally avoids:
- ❌ BattleData loading (Phase 4 needs party system)
- ❌ Turn-based flow (Week 4)
- ❌ InputManager integration (Week 4)
- ❌ Action menus (Week 4)

It ONLY tests:
- ✅ Core combat math (CombatCalculator)
- ✅ Basic setup (BattleManager.setup())
- ✅ Unit spawning and display

**This is the foundation.** Build on it incrementally!

---

**Created**: Phase 3, Week 3
**Status**: ✅ Working and tested headlessly
**Complexity**: Minimal (as requested!)
