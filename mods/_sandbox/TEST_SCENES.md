# Test Scenes Documentation

This directory contains test scenes for manual and automated testing of The Sparkling Farce battle systems.

## For Manual Testing

### 🎮 **test_unit.tscn** - PRIMARY MANUAL TEST SCENE

**Use this scene for all manual testing and as a basis for future tests.**

**Location:** `mods/_sandbox/scenes/test_unit.tscn`

**What it tests:**
- Complete turn-based battle flow
- Player-controlled unit with full input system
- AI-controlled enemy with aggressive behavior
- Movement, combat, and action menu
- Visual feedback (grid cursor, path preview, health bars)

**How to use:**
1. Open `mods/_sandbox/scenes/test_unit.tscn` in Godot
2. Press **F6** (Play Scene) or **F5** (Play Project)
3. Use arrow keys to move, Enter to confirm, Escape to cancel

**Controls:**
- **Arrow Keys** - Move cursor during your turn
- **Enter/Space** - Confirm movement (opens action menu)
- **Escape** - Cancel movement or action
- **Action Menu** - Arrow keys to navigate, Enter to select

**Features tested:**
- ✅ GridManager pathfinding
- ✅ TurnManager AGI-based turn order
- ✅ InputManager state machine (movement → action → targeting)
- ✅ BattleManager combat resolution
- ✅ CombatCalculator damage formulas
- ✅ AIController enemy behavior
- ✅ Unit movement and combat
- ✅ UI systems (action menu, grid cursor)

---

## For Automated Testing

### 🤖 **test_ai_headless.tscn** - Automated Regression Test

**Location:** `test_ai_headless.tscn` (project root)

**Purpose:** Quick automated validation that battle systems work correctly.

**What it tests:**
- AI vs AI combat without player input
- Turn management
- Combat resolution
- Unit death handling
- Battle end conditions

**How to run:**
```bash
godot --headless --path . test_ai_headless.tscn
```

**Note:** This test auto-ends player turns without input, so AI combat can run continuously.

---

## Creating New Test Scenes

When you need to create a new test scene:

1. **Start with test_unit.tscn as a template**
2. Copy the scene and script
3. Modify only what you need to test
4. Keep the core battle setup intact

**Why:** test_unit.tscn has all the necessary setup:
- GridManager initialization
- InputManager UI references (action menu, grid cursor)
- BattleManager setup
- TurnManager battle start
- Proper signal connections

---

## Test Scene History

**Removed obsolete tests (2025-11-25 Cleanup):**
- ❌ test_full_battle.tscn/gd - BattleData integration test (superseded by battle_loader.tscn)
- ❌ test_xp_system.tscn/gd - XP system test (system complete, now in core/)
- ❌ test_save_system.tscn/gd - Save system test (system complete, now in core/)
- ❌ test_battle_manager.tscn - Simple combat test (broken, missing .gd file)
- ❌ test_battle.tscn - Early battle prototype (broken, missing dependency)
- ❌ test_map.gd - Map provider for test_full_battle (no longer needed)
- ❌ test_battle_setup - Camera testing only
- ❌ test_grid_manager - Basic pathfinding visualization

**Note:** For dynamic battle loading from BattleData resources, use `battle_loader.tscn` (production system).

These were development/testing scenes superseded by the production battle_loader and the comprehensive test_unit scene.

---

**Last Updated:** 2025-11-25
