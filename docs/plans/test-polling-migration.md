# Status: COMPLETED

This plan has been fully implemented as of January 2026.

---

# Test Polling Migration Plan

Migration plan to update test suite polling patterns for GdUnit4 v6.0.2+ compatibility.

## Problem Statement

GdUnit4 v6.0.2+ has stricter signal cleanup that causes test hangs with our current patterns:
- **11 test files** use `await get_tree().process_frame` polling loops
- **17 test files** connect directly to autoload singleton signals

The risk is that pending signal connections and async operations may not clean up properly between tests, causing hangs or flaky behavior.

---

## Current Patterns Analysis

### Pattern 1: Polling Loops with `await get_tree().process_frame`

Used to wait for unit movement completion or state changes.

```gdscript
# PROBLEMATIC: Can hang if condition never becomes false
while unit.is_moving() and (Time.get_ticks_msec() - wait_start) < 3000:
    await get_tree().process_frame
```

**Files using this pattern:**
| File | Line | Context | Priority |
|------|------|---------|----------|
| `tests/integration/ai/test_defensive_positioning.gd` | 204 | Wait for movement | HIGH |
| `tests/integration/ai/test_cautious_engagement.gd` | 229 | Wait for movement | HIGH |
| `tests/integration/ai/test_retreat_behavior.gd` | 172 | Wait for movement | HIGH |
| `tests/integration/ai/test_stationary_guard.gd` | 197 | Wait for movement | HIGH |
| `tests/integration/ai/test_healer_prioritization.gd` | 209 | Wait for movement | HIGH |
| `tests/integration/ai/test_tactical_debuff.gd` | 198 | Wait for movement | HIGH |
| `tests/integration/ai/test_ranged_ai_positioning.gd` | 179 | Wait for movement | HIGH |
| `tests/integration/ai/test_aoe_targeting.gd` | 230 | Wait for movement | HIGH |
| `tests/integration/ai/test_terrain_advantage.gd` | 182 | Wait for movement | HIGH |
| `tests/integration/ai/test_opportunistic_targeting.gd` | 159 | Wait for movement | HIGH |
| `tests/integration/battle/test_battle_flow.gd` | 126 | Wait for battle complete | HIGH |
| `tests/unit/editor/test_character_editor_validation.gd` | 27 | Wait for UI init | MEDIUM |
| `tests/integration/editor/test_collapse_section.gd` | 24, 328, 341 | Wait for UI init | MEDIUM |

### Pattern 2: Direct Singleton Signal Connections

Manual connect/disconnect to autoload singletons in before/after hooks.

**Files using this pattern:**
| File | Singleton | Signals | Priority |
|------|-----------|---------|----------|
| `tests/integration/turn/test_turn_manager.gd` | TurnManager | 6 signals | HIGH |
| `tests/integration/experience/test_experience_manager.gd` | ExperienceManager | 3 signals | HIGH |
| `tests/integration/cinematics/test_cinematic_spawn_flow.gd` | CinematicsManager | 3 signals | HIGH |
| `tests/integration/ai/test_defensive_positioning.gd` | BattleManager | 1 signal | MEDIUM |
| `tests/integration/ai/test_cautious_engagement.gd` | BattleManager | 1 signal | MEDIUM |
| `tests/integration/ai/test_retreat_behavior.gd` | BattleManager | 1 signal | MEDIUM |
| `tests/integration/ai/test_stationary_guard.gd` | BattleManager | 1 signal | MEDIUM |
| `tests/integration/ai/test_healer_prioritization.gd` | BattleManager | 1 signal | MEDIUM |
| `tests/integration/ai/test_tactical_debuff.gd` | BattleManager | 1 signal | MEDIUM |
| `tests/integration/ai/test_ranged_ai_positioning.gd` | BattleManager | 1 signal | MEDIUM |
| `tests/integration/ai/test_aoe_targeting.gd` | BattleManager | 1 signal | MEDIUM |
| `tests/integration/ai/test_opportunistic_targeting.gd` | BattleManager | 1 signal | MEDIUM |
| `tests/integration/mod_system/test_namespaced_flags.gd` | GameState | 1 signal | LOW |

### Pattern 3: Using SignalTracker (Already Good)

These files already use the SignalTracker pattern correctly:
- `tests/integration/battle/test_battle_flow.gd` - Uses SignalTracker for TurnManager/BattleManager
- `tests/integration/editor/test_collapse_section.gd` - Uses SignalTracker for component signals
- `tests/unit/systems/test_game_event_bus.gd` - Uses SignalTracker for event bus signals
- `tests/unit/editor/test_editor_event_bus.gd` - Uses SignalTracker for component signals
- `tests/unit/editor/test_resource_picker_widget.gd` - Uses local signal connections (test-owned objects)

---

## Migration Strategies

### Strategy A: Replace Polling with `await_millis()` (Simple Cases)

For cases where we just need a brief wait:

```gdscript
# BEFORE
await get_tree().process_frame

# AFTER
await await_idle_frame()
```

**Applicable to:**
- `test_character_editor_validation.gd:27` - Single frame wait for UI
- `test_collapse_section.gd:24,328,341` - Single frame wait for UI

### Strategy B: Replace Polling Loops with Signal-Based Waiting

For movement completion, replace polling with signal waiting:

```gdscript
# BEFORE
while unit.is_moving() and (Time.get_ticks_msec() - wait_start) < 3000:
    await get_tree().process_frame

# AFTER - If Unit has movement_finished signal
await await_signal_on(unit, "movement_finished", [], 3000)

# AFTER - If no signal available, use bounded await_millis
await await_millis(100)  # Short wait for frame processing
if unit.is_moving():
    await await_millis(500)  # Allow more time if still moving
```

**Applicable to:** All 10 AI test files

### Strategy C: Migrate to SignalTracker Pattern

For singleton signal connections, migrate to SignalTracker:

```gdscript
# BEFORE
func before() -> void:
    TurnManager.turn_cycle_started.connect(_on_turn_cycle_started)
    TurnManager.player_turn_started.connect(_on_player_turn_started)

func after() -> void:
    if TurnManager.turn_cycle_started.is_connected(_on_turn_cycle_started):
        TurnManager.turn_cycle_started.disconnect(_on_turn_cycle_started)
    if TurnManager.player_turn_started.is_connected(_on_player_turn_started):
        TurnManager.player_turn_started.disconnect(_on_player_turn_started)

# AFTER
var _tracker: SignalTracker

func before() -> void:
    _tracker = SignalTracker.new()
    _tracker.track_with_callback(TurnManager.turn_cycle_started, _on_turn_cycle_started)
    _tracker.track_with_callback(TurnManager.player_turn_started, _on_player_turn_started)

func after() -> void:
    if _tracker:
        _tracker.disconnect_all()
        _tracker = null
```

**Applicable to:** All files with direct singleton connections

---

## Prioritized Migration Order

### Phase 1: HIGH Priority - Battle/AI Tests (Most Likely to Hang)

These tests have complex async behavior and are most likely to cause hangs.

| # | File | Changes | Est. Lines |
|---|------|---------|------------|
| 1 | `tests/integration/battle/test_battle_flow.gd` | Replace polling loop with bounded waits | ~10 |
| 2 | `tests/integration/ai/test_defensive_positioning.gd` | Replace polling + migrate to SignalTracker | ~25 |
| 3 | `tests/integration/ai/test_cautious_engagement.gd` | Replace polling + migrate to SignalTracker | ~25 |
| 4 | `tests/integration/ai/test_retreat_behavior.gd` | Replace polling + migrate to SignalTracker | ~25 |
| 5 | `tests/integration/ai/test_stationary_guard.gd` | Replace polling + migrate to SignalTracker | ~25 |
| 6 | `tests/integration/ai/test_healer_prioritization.gd` | Replace polling + migrate to SignalTracker | ~25 |
| 7 | `tests/integration/ai/test_tactical_debuff.gd` | Replace polling + migrate to SignalTracker | ~25 |
| 8 | `tests/integration/ai/test_ranged_ai_positioning.gd` | Replace polling + migrate to SignalTracker | ~25 |
| 9 | `tests/integration/ai/test_aoe_targeting.gd` | Replace polling + migrate to SignalTracker | ~25 |
| 10 | `tests/integration/ai/test_terrain_advantage.gd` | Replace polling + migrate to SignalTracker | ~25 |
| 11 | `tests/integration/ai/test_opportunistic_targeting.gd` | Replace polling + migrate to SignalTracker | ~25 |

**Phase 1 Total: ~260 lines changed**

### Phase 2: HIGH Priority - Multi-Signal Manager Tests

These tests connect to many singleton signals and need careful cleanup.

| # | File | Changes | Est. Lines |
|---|------|---------|------------|
| 12 | `tests/integration/turn/test_turn_manager.gd` | Migrate 6 signals to SignalTracker | ~40 |
| 13 | `tests/integration/experience/test_experience_manager.gd` | Migrate 3 signals to SignalTracker | ~30 |
| 14 | `tests/integration/cinematics/test_cinematic_spawn_flow.gd` | Migrate 3 signals to SignalTracker | ~30 |

**Phase 2 Total: ~100 lines changed**

### Phase 3: MEDIUM Priority - Editor Tests

These are less likely to hang but should still be updated for consistency.

| # | File | Changes | Est. Lines |
|---|------|---------|------------|
| 15 | `tests/unit/editor/test_character_editor_validation.gd` | Replace with await_idle_frame() | ~3 |
| 16 | `tests/integration/editor/test_collapse_section.gd` | Replace with await_idle_frame() | ~6 |

**Phase 3 Total: ~9 lines changed**

### Phase 4: LOW Priority - Isolated Signal Tests

These have minimal risk but should be reviewed.

| # | File | Changes | Est. Lines |
|---|------|---------|------------|
| 17 | `tests/integration/mod_system/test_namespaced_flags.gd` | Single signal, inline disconnect - OK as-is | 0 |

**Phase 4 Total: 0 lines (acceptable as-is)**

---

## Implementation Details

### AI Test Migration Template

All 10 AI tests follow the same pattern. Here is the template change:

```gdscript
# Add to class variables
var _tracker: SignalTracker

# Update before() or before_test()
func before_test() -> void:
    _tracker = SignalTracker.new()
    # ... existing setup ...
    # Replace direct connect with tracker
    _tracker.track_with_callback(BattleManager.combat_resolved, _on_combat_resolved)

# Update after() or after_test()
func after_test() -> void:
    # Disconnect all tracked signals FIRST
    if _tracker:
        _tracker.disconnect_all()
        _tracker = null
    # ... rest of cleanup ...

# Update _execute_*_turn() function
func _execute_unit_turn() -> void:
    # ... existing AI brain execution ...

    # BEFORE: Polling loop
    # while unit.is_moving() and (Time.get_ticks_msec() - wait_start) < 3000:
    #     await get_tree().process_frame

    # AFTER: Bounded await with check
    await await_millis(100)
    if _unit.is_moving():
        await await_millis(500)
```

### Turn/Experience/Cinematics Manager Template

For tests with many signal connections:

```gdscript
# Add SignalTracker
var _tracker: SignalTracker

func before() -> void:
    _tracker = SignalTracker.new()
    # Replace all direct connects:
    _tracker.track_with_callback(TurnManager.turn_cycle_started, _on_turn_cycle_started)
    _tracker.track_with_callback(TurnManager.player_turn_started, _on_player_turn_started)
    # ... etc

func after() -> void:
    # Single cleanup call handles all
    if _tracker:
        _tracker.disconnect_all()
        _tracker = null
    # ... rest of cleanup
```

### Editor Test Template

Simple replacement:

```gdscript
# BEFORE
await get_tree().process_frame

# AFTER
await await_idle_frame()
```

---

## Verification Checklist

After each migration:

- [ ] Run the individual test file: `./test_headless.sh --add "res://tests/integration/ai/test_<name>.gd"`
- [ ] Verify no orphan warnings in output
- [ ] Verify no timeout/hang issues
- [ ] Run full test suite to check for regressions

After all migrations:

- [ ] Full test suite passes: `./test_headless.sh`
- [ ] No increase in test runtime
- [ ] No flaky test failures

---

## Summary

| Phase | Files | Est. Lines | Risk Reduction |
|-------|-------|------------|----------------|
| 1 | 11 | ~260 | High - fixes most likely hang sources |
| 2 | 3 | ~100 | High - fixes complex signal cleanup |
| 3 | 2 | ~9 | Medium - consistency improvement |
| 4 | 1 | 0 | Low - acceptable as-is |

**Total: 17 files, ~369 lines changed**

The migration can be done incrementally, with Phase 1 providing the most immediate benefit for test stability.
