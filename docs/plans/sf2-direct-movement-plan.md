# SF2-Style Direct Character Movement System

**Status:** PLANNED
**Priority:** High - Core UX authenticity improvement
**Dependencies:** Phase 2.5 complete
**Target:** Before Phase 4 (Equipment/Magic/Items)
**Estimated Effort:** 9-13 hours

---

## Overview

This plan redesigns the player movement system during tactical battles to match Shining Force 2's direct character control, replacing the current Fire Emblem-style cursor-based movement.

**Current System (Fire Emblem-style):**
1. Player's turn starts, walkable tiles highlighted
2. Separate CURSOR moves with arrow keys within valid area
3. Path preview shows from unit to cursor position
4. Player confirms destination, unit teleports/animates along computed path
5. Action menu opens

**Target System (SF2-style):**
1. Player's turn starts, walkable tiles highlighted
2. Player controls CHARACTER directly with arrow keys (no separate cursor)
3. Character moves tile-by-tile, consuming movement points per step
4. Player can "undo" by walking backward (movement points refunded)
5. Player confirms position (A button), action menu opens
6. B button = full cancel, return to start position

---

## Strategic Context

**From Commander Claudius:**
> "Shining Force 1 & 2 (Genesis) used DIRECT CHARACTER CONTROL, not a separate cursor. Our current system is actually closer to Fire Emblem. This is exactly the kind of decision that will make Shining Force veterans smile when they first move a character. They'll know, instantly, that we GET it."

**From Lt. Claudbrain:**
> "The key insight is that we're not replacing the cursor - we're making the UNIT behave as its own cursor during movement, while keeping the grid cursor for inspection mode."

**SF2 Manual Reference:**
> "Move your character using the D-button. When you have picked the place you want to stop at, press button A or C. If you reconsider and want to move your character again, press button B and move your character to the new position."

---

## Problem Statement

### Current Implementation Analysis

**InputManager State Machine:**
```
EXPLORING_MOVEMENT → Cursor moves, unit stationary
INSPECTING → Free cursor for looking around
SELECTING_ACTION → Menu open
TARGETING → Selecting target
```

**Current Movement Flow (input_manager.gd lines 417-496):**
1. Arrow keys move `cursor_cell` position (line 430-445)
2. Cursor clamped to `walkable_cells` array (lines 587-597)
3. Path preview drawn from unit to cursor (lines 665-681)
4. Accept button triggers `_confirm_movement()` (line 469)
5. Unit teleports along computed path with tween animation

**Key Issues:**
| Issue | Impact |
|-------|--------|
| Cursor is separate entity from unit | Not authentic to SF2 |
| No movement cost tracking per step | Can't implement undo correctly |
| Path is computed, not player-chosen | Less tactical feel |
| No "walking back" refund mechanic | Undo is binary (cancel all) |

---

## Success Criteria

### Functional Requirements
- [ ] Player directly controls unit with arrow keys during movement phase
- [ ] Unit moves one tile per input, with brief animation (0.1s)
- [ ] Movement range display updates dynamically as unit moves
- [ ] Walking backward onto previous cell refunds movement cost
- [ ] B button cancels all movement and returns unit to start
- [ ] A button confirms position and opens action menu
- [ ] Can pass through allied units but cannot stop on them
- [ ] AI units still use pathfinding (no changes to AI behavior)
- [ ] Mouse click pathfinds to clicked cell (accessibility)

### Technical Requirements
- [ ] New `DIRECT_MOVEMENT` state in InputManager
- [ ] Movement path tracking with step history for undo
- [ ] GridManager occupation updates during movement phase
- [ ] Camera follows unit during direct movement
- [ ] Input blocked during step animation (prevent state corruption)
- [ ] Zero changes to AI controller code paths

### Quality Requirements
- [ ] Lt. Claudette code review: 4.5/5 or higher
- [ ] Commander Claudius authenticity approval
- [ ] All existing battle tests pass
- [ ] New tests cover edge cases documented below
- [ ] Feel matches SF2 reference footage

---

## Technical Architecture

### New State Machine

```gdscript
enum InputState {
    WAITING,              # Not player's turn
    INSPECTING,           # Free cursor mode (B button from WAITING)
    DIRECT_MOVEMENT,      # NEW: Player controlling unit tile-by-tile
    SELECTING_ACTION,     # Action menu open
    TARGETING,            # Selecting target for attack/spell
    EXECUTING,            # Action executing (animations)
}
```

**State Transitions:**
```
Turn Start → DIRECT_MOVEMENT
    ├── Arrow keys → Move unit one tile (stay in DIRECT_MOVEMENT)
    ├── A button → SELECTING_ACTION (menu opens)
    ├── B button → Return to start, stay in DIRECT_MOVEMENT
    └── (from SELECTING_ACTION) Cancel → DIRECT_MOVEMENT at current position

WAITING + B button → INSPECTING (unchanged)
```

### New Movement Tracking Variables

```gdscript
## Direct movement tracking (SF2-style)
var movement_path_taken: Array[Vector2i] = []  # Cells walked through in order
var movement_remaining: int = 0                 # Points left to spend
var movement_start_cell: Vector2i = Vector2i.ZERO
var is_direct_moving: bool = false              # True during step animation

## Step history for undo (refunds movement cost)
## Format: [{cell: Vector2i, cost: int}, ...]
var _step_history: Array[Dictionary] = []
```

### Core Algorithm: Try Direct Step

```gdscript
func _try_direct_step(direction: Vector2i) -> bool:
    if is_direct_moving:
        return false  # Block input during animation

    var target_cell: Vector2i = active_unit.grid_position + direction

    # Validate: bounds check
    if not grid_manager.is_within_bounds(target_cell):
        return false

    # Validate: not occupied by enemy
    var occupant: Unit = grid_manager.get_unit_at_cell(target_cell)
    if occupant and occupant.faction != active_unit.faction:
        return false  # Can't walk through enemies

    # Validate: terrain passable
    var movement_type: int = active_unit.character_data.character_class.movement_type
    var terrain_cost: int = grid_manager.get_terrain_cost(target_cell, movement_type)
    if terrain_cost >= GridManager.MAX_TERRAIN_COST:
        return false  # Impassable terrain

    # Validate: have enough movement points
    if terrain_cost > movement_remaining:
        _play_error_feedback()
        return false  # Not enough movement left

    # Check if walking back on our path (refund movement)
    if movement_path_taken.size() > 1:
        var previous_cell: Vector2i = movement_path_taken[-2]
        if target_cell == previous_cell:
            return _undo_last_step()

    # Execute the step
    _execute_direct_step(target_cell, terrain_cost)
    return true
```

### Step Execution with Animation

```gdscript
func _execute_direct_step(target_cell: Vector2i, cost: int) -> void:
    is_direct_moving = true

    # Record step for undo
    _step_history.append({
        "cell": active_unit.grid_position,
        "cost": cost
    })

    # Deduct movement cost
    movement_remaining -= cost

    # Update path taken
    movement_path_taken.append(target_cell)

    # Update grid occupation
    var old_pos: Vector2i = active_unit.grid_position
    grid_manager.clear_cell_occupied(old_pos)
    grid_manager.set_cell_occupied(target_cell, active_unit)
    active_unit.grid_position = target_cell

    # Quick tween to new position (faster than path following)
    var target_world: Vector2 = grid_manager.cell_to_world(target_cell)
    var step_tween: Tween = create_tween()
    step_tween.tween_property(active_unit, "position", target_world, 0.1)
    step_tween.set_trans(Tween.TRANS_LINEAR)

    await step_tween.finished
    is_direct_moving = false

    # Play step sound
    if audio_manager:
        audio_manager.play_sfx("footstep", AudioManager.SFXCategory.MOVEMENT)

    # Update visual feedback (remaining movement display)
    _update_movement_range_display()
```

### Undo Last Step (Walking Back)

```gdscript
func _undo_last_step() -> bool:
    if _step_history.is_empty():
        return false

    is_direct_moving = true

    var last_step: Dictionary = _step_history.pop_back()
    var previous_cell: Vector2i = last_step.cell
    var refunded_cost: int = last_step.cost

    # Refund movement points
    movement_remaining += refunded_cost

    # Remove from path taken
    movement_path_taken.pop_back()

    # Update grid occupation
    grid_manager.clear_cell_occupied(active_unit.grid_position)
    grid_manager.set_cell_occupied(previous_cell, active_unit)
    active_unit.grid_position = previous_cell

    # Animate back
    var target_world: Vector2 = grid_manager.cell_to_world(previous_cell)
    var step_tween: Tween = create_tween()
    step_tween.tween_property(active_unit, "position", target_world, 0.1)

    await step_tween.finished
    is_direct_moving = false

    _update_movement_range_display()
    return true
```

### Full Cancel (Return to Start)

```gdscript
func _cancel_all_movement() -> void:
    if movement_path_taken.size() <= 1:
        return  # Already at start

    is_direct_moving = true

    # Update grid occupation back to start
    grid_manager.clear_cell_occupied(active_unit.grid_position)
    grid_manager.set_cell_occupied(movement_start_cell, active_unit)
    active_unit.grid_position = movement_start_cell

    # Instant teleport back (or could animate through path)
    active_unit.position = grid_manager.cell_to_world(movement_start_cell)

    # Reset state
    movement_path_taken = [movement_start_cell]
    _step_history.clear()
    movement_remaining = _get_unit_max_movement()

    is_direct_moving = false
    _update_movement_range_display()
```

### Dynamic Range Display Update

```gdscript
func _update_movement_range_display() -> void:
    grid_manager.clear_highlights()

    if movement_remaining <= 0:
        # No movement left - just highlight current cell
        grid_manager.highlight_cells([active_unit.grid_position], GridManager.HIGHLIGHT_CURRENT)
        return

    # Calculate reachable cells from CURRENT position with REMAINING movement
    var movement_type: int = active_unit.character_data.character_class.movement_type
    var reachable_cells: Array[Vector2i] = grid_manager.get_walkable_cells(
        active_unit.grid_position,
        movement_remaining,
        movement_type,
        active_unit.faction
    )

    # Highlight reachable area
    grid_manager.highlight_cells(reachable_cells, GridManager.HIGHLIGHT_BLUE)

    # Highlight current cell differently
    grid_manager.highlight_cell(active_unit.grid_position, GridManager.HIGHLIGHT_CURRENT)
```

### Enter Direct Movement (Turn Start)

```gdscript
func _on_enter_direct_movement() -> void:
    current_state = InputState.DIRECT_MOVEMENT

    # Initialize movement tracking
    movement_start_cell = active_unit.grid_position
    movement_path_taken = [movement_start_cell]
    _step_history.clear()
    movement_remaining = _get_unit_max_movement()
    is_direct_moving = false

    # Hide grid cursor during direct movement
    if grid_cursor:
        grid_cursor.visible = false

    # Calculate and display initial movement range
    _update_movement_range_display()

    # Camera focuses on unit
    if camera_controller:
        camera_controller.focus_on_cell(movement_start_cell)
```

---

## Edge Cases and Solutions

### 1. Invalid Direction Input
**Problem:** Player presses direction with no valid cell
**Solution:** Silently ignore (SF2-authentic) OR brief error beep
**Implementation:** `_try_direct_step()` returns false, optionally plays error sound

### 2. Diagonal Movement
**Problem:** Godot input system supports diagonal
**Solution:** Enforce cardinal-only in input handler
**Implementation:**
```gdscript
func _get_movement_direction() -> Vector2i:
    # Priority: last pressed key wins
    if Input.is_action_pressed("ui_up"):
        return Vector2i(0, -1)
    elif Input.is_action_pressed("ui_down"):
        return Vector2i(0, 1)
    elif Input.is_action_pressed("ui_left"):
        return Vector2i(-1, 0)
    elif Input.is_action_pressed("ui_right"):
        return Vector2i(1, 0)
    return Vector2i.ZERO
```

### 3. Ally Pass-Through
**Problem:** SF2 allows walking through allies but not stopping on them
**Solution:**
- During step: Allow movement to allied-occupied cells
- On confirm: Block if standing on ally, show error
**Implementation:**
```gdscript
func _can_confirm_position() -> bool:
    var occupant: Unit = grid_manager.get_unit_at_cell(active_unit.grid_position)
    if occupant and occupant != active_unit:
        _play_error_feedback()
        return false
    return true
```

### 4. No Movement Range
**Problem:** Unit has 0 movement (immobilized, terrain)
**Solution:** Skip directly to action menu
**Implementation:**
```gdscript
func start_player_turn(unit: Unit) -> void:
    active_unit = unit
    if _get_unit_max_movement() <= 0:
        _enter_selecting_action()  # Skip movement phase
    else:
        _on_enter_direct_movement()
```

### 5. Surrounded by Enemies
**Problem:** All adjacent cells blocked by enemies
**Solution:** Movement range calculation already handles this; unit stays in place
**Implementation:** Existing `get_walkable_cells()` returns empty, confirm opens menu at start

### 6. Camera Following
**Problem:** Camera should track unit during movement
**Solution:** Update camera focus after each step
**Implementation:**
```gdscript
# In _execute_direct_step(), after tween:
if camera_controller:
    camera_controller.focus_on_cell(target_cell, true)  # smooth follow
```

### 7. Mouse Click Support
**Problem:** Accessibility - some players prefer mouse
**Solution:** Click on valid cell = pathfind there automatically
**Implementation:**
```gdscript
func _handle_mouse_click(cell: Vector2i) -> void:
    if not _is_cell_in_current_range(cell):
        return

    # Pathfind from current position to clicked cell
    var path: Array[Vector2i] = grid_manager.find_path(
        active_unit.grid_position,
        cell,
        active_unit.character_data.character_class.movement_type
    )

    # Execute each step in sequence
    for i in range(1, path.size()):
        var direction: Vector2i = path[i] - path[i-1]
        if not _try_direct_step(direction):
            break  # Stop if blocked (shouldn't happen with valid path)
```

### 8. Input During Animation
**Problem:** Rapid input could corrupt state
**Solution:** `is_direct_moving` flag blocks input during tween
**Implementation:** Already in `_try_direct_step()` - first check is `if is_direct_moving: return false`

### 9. Action Menu Cancel
**Problem:** What happens when menu is cancelled?
**Solution:** Return to DIRECT_MOVEMENT at current position (can continue moving if points remain)
**Implementation:**
```gdscript
func _on_action_menu_cancelled() -> void:
    current_state = InputState.DIRECT_MOVEMENT
    # Unit stays at current position, can continue moving
    _update_movement_range_display()
```

### 10. Turn End Without Moving
**Problem:** Player opens menu immediately without moving
**Solution:** Allowed - just like SF2, you can act without moving
**Implementation:** No special handling needed, movement_remaining just isn't used

---

## Files Requiring Modification

### Primary Changes

| File | Changes | Complexity |
|------|---------|------------|
| `core/systems/input_manager.gd` | New state, direct movement logic, input handling | High (~300 new, ~150 modified) |
| `core/components/unit.gd` | Optional: lightweight `step_to()` method | Low (~30 lines) |
| `core/systems/grid_manager.gd` | New highlight color constant | Low (~10 lines) |

### Secondary Changes

| File | Changes | Complexity |
|------|---------|------------|
| `scenes/ui/grid_cursor.gd` | Hide during DIRECT_MOVEMENT | Low (~5 lines) |
| `core/scenes/base_battle_scene.gd` | Update cursor visibility handling | Low (~5 lines) |

### No Changes Required

| File | Reason |
|------|--------|
| `core/systems/ai_controller.gd` | AI uses pathfinding, separate code path |
| `core/resources/ai_brain.gd` | AI movement API unchanged |
| `mods/_base_game/ai_brains/*.gd` | AI brains use existing pathfinding |
| `core/systems/turn_manager.gd` | Turn flow unchanged |
| `core/systems/battle_manager.gd` | Action handling unchanged |

---

## Implementation Plan

### Phase 1: Foundation (2-3 hours)
**Goal:** Basic tile-by-tile stepping with validation

**Tasks:**
1. Add `DIRECT_MOVEMENT` state to InputState enum
2. Add movement tracking variables to InputManager
3. Implement `_on_enter_direct_movement()` initialization
4. Implement `_try_direct_step()` with all validations
5. Implement `_execute_direct_step()` with animation
6. Wire up arrow key input to call `_try_direct_step()`

**Test Criteria:**
- [ ] Unit moves one tile per arrow key press
- [ ] Movement blocked at map boundaries
- [ ] Movement blocked by enemy units
- [ ] Movement blocked by impassable terrain
- [ ] Movement points correctly deducted

**Regression Check:**
- [ ] AI movement still works (uses different code path)
- [ ] Turn transitions work correctly

### Phase 2: Visual Feedback (1-2 hours)
**Goal:** Dynamic range display as unit moves

**Tasks:**
1. Implement `_update_movement_range_display()`
2. Add `HIGHLIGHT_CURRENT` constant to GridManager
3. Call range update after each step
4. Hide grid cursor during DIRECT_MOVEMENT
5. Show cursor only during INSPECTING state

**Test Criteria:**
- [ ] Blue highlight shrinks as movement consumed
- [ ] Current cell highlighted differently
- [ ] Grid cursor not visible during movement
- [ ] Grid cursor visible during inspection (B button from WAITING)

**Regression Check:**
- [ ] Inspection mode still works
- [ ] Targeting mode cursor still works

### Phase 3: Undo/Cancel (2 hours)
**Goal:** Walking back and full cancel functionality

**Tasks:**
1. Implement step detection for walking backward
2. Implement `_undo_last_step()` with movement refund
3. Implement `_cancel_all_movement()` for B button
4. Handle edge case: cancel at start position (no-op)

**Test Criteria:**
- [ ] Walking backward refunds correct movement cost
- [ ] Multiple undo steps work correctly
- [ ] B button returns unit to exact start position
- [ ] Movement range fully restored after cancel
- [ ] Path history cleared after cancel

**Regression Check:**
- [ ] B button still enters inspection from WAITING state

### Phase 4: Action Menu Integration (1 hour)
**Goal:** Seamless transition from movement to actions

**Tasks:**
1. A button calls `_can_confirm_position()` then opens menu
2. Block confirm if standing on allied unit
3. Menu cancel returns to DIRECT_MOVEMENT
4. Handle "no movement" case (0 range = skip to menu)

**Test Criteria:**
- [ ] A button opens action menu at current position
- [ ] Cannot confirm position on allied unit
- [ ] Menu cancel returns to movement phase
- [ ] Can continue moving after menu cancel if points remain
- [ ] Immobilized units skip directly to action menu

**Regression Check:**
- [ ] Action menu works correctly (attack, magic, items)
- [ ] Targeting phase works after menu selection

### Phase 5: Polish and Edge Cases (2 hours)
**Goal:** SF2 authenticity and robustness

**Tasks:**
1. Ally pass-through (walk through, can't stop on)
2. Input buffering (queue next direction during animation)
3. Sound effects (footstep per step, error beep)
4. Camera smooth follow during movement
5. Mouse click pathfinding (accessibility)
6. Tune step animation speed (0.1s target)

**Test Criteria:**
- [ ] Can walk through allied units
- [ ] Error feedback when trying to stop on ally
- [ ] Footstep sound per tile moved
- [ ] Camera smoothly tracks unit
- [ ] Mouse click moves unit along path
- [ ] Movement feels responsive (no input lag)

**SF2 Authenticity Check:**
- [ ] Compare side-by-side with SF2 footage
- [ ] Adjust timings if needed

### Phase 6: Testing and Validation (1-2 hours)
**Goal:** Full battle flow validation and automated tests

**Tasks:**
1. Manual playtest complete battle with new system
2. Write/update headless tests for movement
3. Test all edge cases from this document
4. Verify AI behavior unchanged
5. Performance check (no frame drops during movement)

**Test Criteria:**
- [ ] Full battle completable with new system
- [ ] All automated tests pass
- [ ] AI units move correctly (pathfinding)
- [ ] No performance regression
- [ ] Edge cases handled gracefully

---

## Testing Strategy

### Unit Tests (Major Testo)

**Movement Validation:**
- `test_step_blocked_at_boundary` - Cannot step outside map
- `test_step_blocked_by_enemy` - Cannot step into enemy cell
- `test_step_blocked_by_terrain` - Cannot step into impassable terrain
- `test_step_blocked_insufficient_points` - Cannot step if cost > remaining
- `test_step_allowed_through_ally` - Can step into ally cell (pass-through)

**Movement Cost Tracking:**
- `test_movement_cost_deducted` - Points decrease by terrain cost
- `test_movement_undo_refunds` - Walking back refunds correct cost
- `test_movement_cancel_restores_all` - Full cancel restores max movement
- `test_variable_terrain_costs` - Forest costs more than plains

**State Transitions:**
- `test_enter_direct_movement_initializes` - All tracking vars reset
- `test_confirm_transitions_to_menu` - A button opens action menu
- `test_cancel_stays_in_movement` - B button doesn't leave state
- `test_menu_cancel_returns_to_movement` - Can continue after menu cancel

### Integration Tests

**Full Turn Flow:**
- `test_player_turn_move_and_attack` - Complete turn with movement + action
- `test_player_turn_no_movement` - Act without moving
- `test_player_turn_cancel_redo` - Move, cancel, move differently, act
- `test_ai_turn_uses_pathfinding` - AI behavior unchanged

**Multi-Unit Scenarios:**
- `test_multiple_allies_pass_through` - Navigate around friendly units
- `test_confirm_blocked_on_ally` - Can't end turn on ally cell
- `test_enemy_blocks_movement` - Enemies block path correctly

### Regression Tests

**Existing Functionality:**
- All tests in `tests/integration/battle/test_battle_flow.gd` pass
- All tests in `tests/unit/combat/test_combat_calculator.gd` pass
- AI controller tests unchanged
- Turn manager tests unchanged

### Manual Test Checklist

- [ ] Move unit to edge of range, verify can't go further
- [ ] Walk through 3 allies, confirm at empty cell
- [ ] Walk through ally, try to confirm on ally (should fail)
- [ ] Move 3 tiles, walk back 2, move different direction
- [ ] Use B to cancel from various positions
- [ ] Open menu without moving, cancel, then move
- [ ] Click mouse on valid cell, unit pathfinds there
- [ ] Rapid arrow key input doesn't break state
- [ ] AI turn looks identical to before

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Grid occupation race condition | Medium | High | Atomic occupation updates, `is_direct_moving` flag |
| Input corruption during animation | Medium | High | Block all input while `is_direct_moving` |
| Performance on large maps | Low | Medium | Cache walkable set, only recalculate on move |
| Breaking existing tests | Medium | Medium | Run full test suite each phase |
| Mouse/keyboard state conflict | Low | Low | Clear input state on mode transitions |
| Camera jitter during movement | Low | Low | Smooth follow with easing |

---

## Rollback Plan

If critical issues discovered:

1. **Phase 1-3:** Revert InputManager changes, restore EXPLORING_MOVEMENT
2. **Phase 4-6:** Likely fixable without full rollback

**Git Strategy:**
- Create feature branch `feature/sf2-direct-movement`
- Commit after each phase
- Squash merge to main only after all phases complete

---

## Success Metrics

**Before:**
- Movement style: Fire Emblem (cursor → confirm → animate)
- SF authenticity: Partial
- Player feedback: Indirect (preview path, then commit)

**After:**
- Movement style: Shining Force 2 (direct character control)
- SF authenticity: High
- Player feedback: Immediate (arrow → unit moves)

**Validation:**
- Side-by-side video comparison with SF2 gameplay
- SF fan feedback (if available)
- Commander Claudius authenticity approval

---

## Documentation Updates Required

After implementation:
- [ ] Update CLAUDE.md if movement architecture changes affect modding
- [ ] Update any battle system documentation
- [ ] Blog post candidate: "Authentic SF2 Movement in The Sparkling Farce"

---

## Open Questions

1. **Step Animation Duration**
   - Proposed: 0.1s per tile
   - SF2 reference: ~0.1s (nearly instant)
   - **Decision:** Start with 0.1s, tune based on feel

2. **Input Repeat Rate**
   - Current: 0.3s initial, 0.1s repeat
   - Proposed: 0.15s initial, 0.08s repeat (more responsive)
   - **Decision:** TBD after playtesting

3. **Path Taken Highlight**
   - Option A: Show path taken in different color
   - Option B: No path highlight (SF2-authentic)
   - **Decision:** Start with Option B, add if requested

4. **Cancel Animation**
   - Option A: Instant teleport to start
   - Option B: Quick animation through path backwards
   - **Decision:** Option A (simpler, SF2 was instant)

---

**Plan Created:** December 1, 2025
**Authors:** Commander Claudius, Lt. Claudbrain
**Reviewed By:** First Officer (Numba One)
**Approved By:** Pending Captain approval
