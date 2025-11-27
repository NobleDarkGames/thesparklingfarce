# USS Torvalds Implementation Plan
## The Sparkling Farce - Consolidated Agent Findings

**Compiled By**: Lt. Claudbrain (Technical Lead)
**Date**: 2025-11-26
**Last Updated**: 2025-11-27
**Status**: PHASES A, B, C, D, E COMPLETE ✅
**Report Sources**: 6 Agent Reviews (Commander Claudius, Commander Clean, Lt. Barclay, Lt. Claudbrain, Lt. Claudette, Modro)

---

## COMPLETION LOG

### Phase A+B: Critical & High Priority (COMPLETED 2025-11-26)
- ✅ CRIT-001: Removed DEBUG [TO REMOVE] prints from ai_brain.gd, unit.gd, ai_aggressive.gd
- ✅ CRIT-002: Fixed cinematics fade overlay leak with is_instance_valid check
- ✅ CRIT-003: Added GridManager null checks
- ✅ CRIT-004: Fixed CinematicActor signal accumulation with CONNECT_ONE_SHOT
- ✅ CRIT-005: Fixed TriggerManager signal race condition
- ✅ CRIT-006: Added TriggerManager trigger validity check
- ✅ HIGH-001: Removed action_menu.gd debug prints
- ✅ HIGH-002: Removed AI brain verbose logging
- ✅ HIGH-003: Fixed unit movement signal timing (emit after tween finishes)
- ✅ HIGH-004: Fixed BattleManager duplicate signal connection
- ✅ HIGH-005: Fixed SceneManager fade overlay timing
- ✅ HIGH-006: Fixed SetVariableExecutor value parameter
- ✅ HIGH-010: Added await_movement_completion() to Unit class

**Commit**: `fix: Resolve critical bugs and clean up debug code from team review`

### Phase C: Architecture Improvements (COMPLETED 2025-11-26)
- ✅ MED-003: DRY camera executor validation - Added get_camera_controller() to CinematicsManager
- ✅ HIGH-007: Camera lifecycle clarification - Added register_with_systems() and cleanup
- ✅ HIGH-008: Created BaseBattleScene class (~300 lines of shared battle setup)
- ✅ MED-010: Created TransitionContext class with backwards compatibility in GameState

**Commit**: `refactor: Phase C architecture improvements - camera lifecycle and code cleanup`

### Phase D: Code Cleanup (COMPLETED 2025-11-27)
- ✅ MED-001: Removed deprecated _handle_death function from unit.gd and battle_manager.gd
- ✅ MED-002: Moved test_ai_headless.* files to scenes/tests/, updated test_headless.sh
- ✅ MED-004: Converted 50+ Python-style docstrings to GDScript ## comments (11 files)
- ✅ MED-007: Removed 10 debug prints from party_editor.gd
- ✅ MED-008: Removed debug print from hero_controller.gd
- ✅ MED-005: Extracted magic numbers to constants in battle_manager.gd and combat_animation_scene.gd
- ✅ MED-006: Added DEBUG_VERBOSE toggle to map_test.gd and map_test_playable.gd
- ✅ LOW-002: Verified - no dictionary .has() usage found (already using `in` syntax)

---

## 1. EXECUTIVE SUMMARY

### Key Findings

The Sparkling Farce demonstrates strong foundational architecture with excellent engine/content separation. The mod system and cinematic command executor pattern are exemplary. However, six primary issues require immediate attention:

1. **DEBUG REMNANTS**: 18+ debug print statements marked "[TO REMOVE]" remain in production code (flagged by 4 agents)
2. **CINEMATICS BUGS**: Fade overlay leak and signal accumulation risks (flagged by 2 agents)
3. **GRID MANAGER NULL CHECKS**: Missing null validation can cause crashes (flagged by 2 agents)
4. **CODE DUPLICATION**: 150+ lines of duplicate code in test/battle scenes (flagged by 1 agent)
5. **HARDCODED FORMULAS**: Combat/turn formulas block total conversions (flagged by 2 agents)
6. **PHASE 2.5.2 INCOMPLETE**: Scene transition system blocks playable campaigns (flagged by 2 agents)

### Priority Distribution

| Priority | Issue Count | Estimated Effort |
|----------|-------------|------------------|
| CRITICAL | 6 | 2-4 hours |
| HIGH | 11 | 6-10 hours |
| MEDIUM | 12 | 8-12 hours |
| LOW | 8 | 4-6 hours |

### Cross-Agent Agreement Matrix

| Issue | Claudius | Clean | Barclay | Claudbrain | Claudette | Modro |
|-------|----------|-------|---------|------------|-----------|-------|
| Debug print removal | - | X | - | X | X | - |
| Cinematics fade leak | - | - | X | - | - | - |
| GridManager null check | - | - | X | X | - | - |
| Code duplication | - | X | - | - | - | - |
| Hardcoded formulas | X | - | - | X | - | X |
| Scene transitions | X | - | X | - | - | - |
| Signal connection patterns | - | - | X | X | X | - |
| Camera system integration | - | - | - | X | - | - |

---

## 2. CRITICAL ISSUES

### CRIT-001: DEBUG Print Statements Marked "[TO REMOVE]" ✅ COMPLETED
**Source Agents**: Commander Clean, Lt. Claudette, Lt. Claudbrain
**Complexity**: TRIVIAL
**Estimated Time**: 15 minutes

**Description**: Explicit "[TO REMOVE]" markers exist in production code and were never removed.

**Files and Lines**:
| File | Lines | Count |
|------|-------|-------|
| `/home/user/dev/sparklingfarce/core/resources/ai_brain.gd` | 26, 31, 35, 37, 39 | 5 |
| `/home/user/dev/sparklingfarce/core/components/unit.gd` | 226, 264 | 2 |
| `/home/user/dev/sparklingfarce/mods/base_game/ai_brains/ai_aggressive.gd` | 70, 77, 79 | 3 |

**Action**: DELETE all 10 lines containing "DEBUG [TO REMOVE]"

---

### CRIT-002: CinematicsManager Fade Overlay Scene Leak ✅ COMPLETED
**Source Agents**: Lt. Barclay
**Complexity**: SIMPLE
**Estimated Time**: 30 minutes

**Description**: The `_ensure_fade_overlay()` method adds overlay to `current_scene`. When scene changes, the overlay is freed but `_fade_overlay` reference remains pointing to freed memory.

**File**: `/home/user/dev/sparklingfarce/core/systems/cinematics_manager.gd`
**Lines**: 468-490

**Call Chain Leading to Bug**:
```
CinematicsManager._ensure_fade_overlay()
  -> adds ColorRect to current_scene
SceneManager.change_scene()
  -> frees current_scene (and ColorRect)
FadeScreenExecutor.execute()
  -> accesses freed _fade_overlay  [CRASH]
```

**Action**: Add `is_instance_valid(_fade_overlay)` check before access, OR add overlay to autoload itself instead of current scene.

---

### CRIT-003: GridManager Null Grid Checks Missing ✅ COMPLETED
**Source Agents**: Lt. Barclay, Lt. Claudbrain
**Complexity**: SIMPLE
**Estimated Time**: 20 minutes

**Description**: Several GridManager methods can crash if called before `setup_grid()`.

**File**: `/home/user/dev/sparklingfarce/core/systems/grid_manager.gd`

**Affected Methods**:
| Method | Line | Issue |
|--------|------|-------|
| `get_terrain_cost()` | 97 | Calls `grid.is_within_bounds()` without null check |
| `get_distance()` | 413 | Same issue |
| `get_cells_in_range()` | 418 | Same issue |

**Action**: Add null check at start of each method:
```gdscript
if grid == null:
    push_error("GridManager: Grid not initialized. Call setup_grid() first.")
    return <appropriate_default>
```

---

### CRIT-004: CinematicActor Animation Signal Accumulation ✅ COMPLETED
**Source Agents**: Lt. Barclay
**Complexity**: SIMPLE
**Estimated Time**: 15 minutes

**Description**: Signal connection to `animation_finished` is NOT one-shot and accumulates with each `play_animation()` call.

**File**: `/home/user/dev/sparklingfarce/core/components/cinematic_actor.gd`
**Line**: 321

**Current Code**:
```gdscript
if not sprite_node.animation_finished.is_connected(_on_animation_finished):
    sprite_node.animation_finished.connect(_on_animation_finished)
```

**Issue**: The `is_connected()` check only prevents duplicate connection of same callback. Multiple calls with `wait_for_finish: true` still create issues.

**Action**: Use `CONNECT_ONE_SHOT` flag:
```gdscript
sprite_node.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)
```

---

### CRIT-005: TriggerManager Signal Race Condition ✅ COMPLETED
**Source Agents**: Lt. Barclay
**Complexity**: MODERATE
**Estimated Time**: 45 minutes

**Description**: Await on `scene_transition_completed` can hang indefinitely if signal already emitted.

**File**: `/home/user/dev/sparklingfarce/core/systems/trigger_manager.gd`
**Lines**: 201-205

**Current Code**:
```gdscript
await SceneManager.scene_transition_completed
returned_from_battle.emit()
```

**Action**: Add timeout or check scene state before await:
```gdscript
if SceneManager.is_transitioning:
    await SceneManager.scene_transition_completed
returned_from_battle.emit()
```

---

### CRIT-006: TriggerManager Null Trigger Check Missing ✅ COMPLETED
**Source Agents**: Lt. Barclay
**Complexity**: TRIVIAL
**Estimated Time**: 10 minutes

**Description**: `_on_trigger_activated()` accesses trigger properties without validity check.

**File**: `/home/user/dev/sparklingfarce/core/systems/trigger_manager.gd`
**Lines**: 108-134

**Action**: Add validity check at method start:
```gdscript
func _on_trigger_activated(trigger: Node, player: Node2D) -> void:
    if not is_instance_valid(trigger):
        push_warning("TriggerManager: Trigger was freed before handling")
        return
    var trigger_type: int = trigger.get("trigger_type")
```

---

## 3. HIGH PRIORITY

### HIGH-001: Action Menu Debug Prints ✅ COMPLETED
**Source Agents**: Commander Clean
**Complexity**: TRIVIAL
**Estimated Time**: 15 minutes

**File**: `/home/user/dev/sparklingfarce/scenes/ui/action_menu.gd`
**Lines**: 53, 81, 92, 129, 230, 235, 240, 245-246, 250, 253-254, 265

**Action**: DELETE all 15 print statements. Convert critical error cases to `push_warning()`.

---

### HIGH-002: AI Brain Verbose Debug Logging ✅ COMPLETED
**Source Agents**: Commander Clean, Lt. Claudette
**Complexity**: TRIVIAL
**Estimated Time**: 15 minutes

**Files**:
- `/home/user/dev/sparklingfarce/mods/base_game/ai_brains/ai_aggressive.gd` (Lines 17-51, 9 prints)
- `/home/user/dev/sparklingfarce/mods/base_game/ai_brains/ai_stationary.gd` (Lines 16-57, 6 prints)

**Action**: REMOVE or convert to conditional debug flag.

---

### HIGH-003: Unit Movement Tween Signal Timing ✅ COMPLETED
**Source Agents**: Lt. Barclay
**Complexity**: MODERATE
**Estimated Time**: 1 hour

**Description**: `move_along_path()` emits `moved` signal before tween animation completes.

**File**: `/home/user/dev/sparklingfarce/core/components/unit.gd`
**Line**: 207

**Impact**: Systems listening for `moved` signal (like CinematicActor) proceed before unit visually reaches destination.

**Action**: Connect to tween `finished` signal and emit `moved` only after animation completes:
```gdscript
await _movement_tween.finished
moved.emit(old_position, end_cell)
```

---

### HIGH-004: BattleManager Duplicate Signal Connection Risk ✅ COMPLETED
**Source Agents**: Lt. Barclay, Lt. Claudette
**Complexity**: SIMPLE
**Estimated Time**: 20 minutes

**Description**: Death signal connection uses `.bind()` without checking if already connected.

**File**: `/home/user/dev/sparklingfarce/core/systems/battle_manager.gd`
**Lines**: 316-319

**Current Code**:
```gdscript
if unit.has_signal("died"):
    unit.died.connect(_on_unit_died.bind(unit))
```

**Action**: Add `is_connected()` check:
```gdscript
if unit.has_signal("died"):
    var callback: Callable = _on_unit_died.bind(unit)
    if not unit.died.is_connected(callback):
        unit.died.connect(callback)
```

---

### HIGH-005: SceneManager Deferred Fade Overlay Timing ✅ COMPLETED
**Source Agents**: Lt. Barclay
**Complexity**: SIMPLE
**Estimated Time**: 20 minutes

**Description**: `_fade_to_black()` may be called before deferred add completes.

**File**: `/home/user/dev/sparklingfarce/core/systems/scene_manager.gd`
**Lines**: 53-54

**Action**: Either use immediate `add_child()` or track ready state with flag.

---

### HIGH-006: SetVariableExecutor Ignores Value Parameter ✅ COMPLETED
**Source Agents**: Lt. Claudette
**Complexity**: SIMPLE
**Estimated Time**: 15 minutes

**Description**: Executor retrieves `value` parameter but never uses it.

**File**: `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/set_variable_executor.gd`

**Current Code**:
```gdscript
var value: Variant = params.get("value", null)  # Retrieved but unused!
GameState.set_flag(variable_name)  # Only sets boolean true
```

**Action**: Use value parameter:
```gdscript
if value != null:
    GameState.set_campaign_data(variable_name, value)
else:
    GameState.set_flag(variable_name)
```

---

### HIGH-007: Camera System Lifecycle Unclear ✅ COMPLETED
**Source Agents**: Lt. Claudbrain
**Complexity**: MODERATE
**Estimated Time**: 1-2 hours

**Description**: CameraController is not an autoload but multiple systems expect it. TurnManager has `battle_camera` that must be manually set.

**File**: `/home/user/dev/sparklingfarce/core/systems/turn_manager.gd`

**Questions**:
1. Who creates the camera?
2. Who registers it with TurnManager?
3. What happens during exploration (non-battle)?

**Action**: Either make CameraController an autoload OR create CameraManager singleton that tracks active camera.

---

### HIGH-008: Test Scene Code Duplication ✅ COMPLETED
**Source Agents**: Commander Clean
**Complexity**: MODERATE
**Estimated Time**: 1-2 hours

**Files**:
- `/home/user/dev/sparklingfarce/mods/_sandbox/scenes/test_unit.gd`
- `/home/user/dev/sparklingfarce/mods/_sandbox/scenes/battle_loader.gd`

**Duplicated Functions** (~150 lines):
- `_generate_test_map()` - IDENTICAL
- `_spawn_unit()` - IDENTICAL
- `_on_player_turn_started()` - NEARLY IDENTICAL
- `_on_enemy_turn_started()` - NEARLY IDENTICAL
- `_on_unit_turn_ended()` - IDENTICAL
- `_on_battle_ended()` - NEARLY IDENTICAL
- `_on_combat_resolved()` - NEARLY IDENTICAL

**Action**: Extract shared code into `BaseBattleScene` base class. Both test scenes extend it and override only differing behavior.

---

### HIGH-009: Stub Cinematic Executors
**Source Agents**: Commander Clean, Lt. Claudette
**Complexity**: MODERATE (per executor)
**Estimated Time**: 2-4 hours total

**Files**:
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/spawn_entity_executor.gd`
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/despawn_entity_executor.gd`
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/play_music_executor.gd`
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/play_sound_executor.gd`

**Current State**: Stubs with TODO comments and warning emissions.

**Action**: Track as Phase 4 items OR implement basic functionality now.

---

### HIGH-010: AIBrain Direct Tween Access (Encapsulation Violation) ✅ COMPLETED
**Source Agents**: Lt. Claudette
**Complexity**: SIMPLE
**Estimated Time**: 30 minutes

**Description**: Base `execute_async` accesses `unit._movement_tween` directly.

**File**: `/home/user/dev/sparklingfarce/core/resources/ai_brain.gd`
**Lines**: 34-39

**Current Code**:
```gdscript
if unit._movement_tween and unit._movement_tween.is_valid():
    await unit._movement_tween.finished
```

**Action**: Add public method to Unit:
```gdscript
# In unit.gd
func await_movement_completion() -> void:
    if _movement_tween and _movement_tween.is_valid():
        await _movement_tween.finished
```

Then update ai_brain.gd:
```gdscript
await unit.await_movement_completion()
```

---

### HIGH-011: Phase 2.5.2 Scene Transitions Incomplete
**Source Agents**: Commander Claudius, Lt. Barclay
**Complexity**: COMPLEX
**Estimated Time**: 4-6 hours

**Description**: The explore-battle-explore loop is incomplete. BattleManager doesn't return to map after victory.

**Files**:
- `/home/user/dev/sparklingfarce/core/systems/trigger_manager.gd`
- `/home/user/dev/sparklingfarce/core/systems/battle_manager.gd` (Lines 583-589)

**Current State**:
```gdscript
if GameState.has_return_data():
    print("BattleManager: Returning to map...")
    await get_tree().create_timer(2.0).timeout
    TriggerManager.return_to_map()  # Not fully implemented
```

**Impact**: BLOCKS all campaign creation. This is the core loop of Shining Force games.

**Action**: Complete TriggerManager.return_to_map() implementation per Phase 2.5.2 plan.

---

## 4. MEDIUM PRIORITY

### MED-001: Deprecated _handle_death Function ✅ COMPLETED
**Source Agents**: Commander Clean
**Complexity**: TRIVIAL
**Estimated Time**: 10 minutes

**File**: `/home/user/dev/sparklingfarce/core/components/unit.gd`
**Lines**: 406-412

**Action**: Verify no callers exist, then DELETE the deprecated function.

---

### MED-002: Root-Level Test Files ✅ COMPLETED
**Source Agents**: Commander Clean
**Complexity**: TRIVIAL
**Estimated Time**: 15 minutes

**Files**:
- `/home/user/dev/sparklingfarce/test_ai_headless.gd` (+ .tscn, .uid)
- `/home/user/dev/sparklingfarce/test_executors/` directory

**Action**: Move to `scenes/tests/` or remove if no longer needed.

---

### MED-003: Camera Executor Validation DRY Violation ✅ COMPLETED
**Source Agents**: Commander Clean
**Complexity**: SIMPLE
**Estimated Time**: 30 minutes

**Files**:
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/camera_move_executor.gd` (Lines 14-21)
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/camera_shake_executor.gd` (Lines 15-22)
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/camera_follow_executor.gd`

**Repeated Pattern**:
```gdscript
if not manager._active_camera:
    push_warning("Camera[X]Executor: No camera available")
    return true
if not manager._active_camera is CameraController:
    push_warning("Camera[X]Executor: Camera is Camera2D, not CameraController...")
    return true
var camera: CameraController = manager._active_camera as CameraController
```

**Action**: Create helper method in CinematicsManager:
```gdscript
func get_camera_controller() -> CameraController:
    if not _active_camera:
        push_warning("CinematicsManager: No camera available")
        return null
    if not _active_camera is CameraController:
        push_warning("CinematicsManager: Camera is not CameraController")
        return null
    return _active_camera as CameraController
```

---

### MED-004: Python-Style Docstrings ✅ COMPLETED
**Source Agents**: Lt. Claudette
**Complexity**: TRIVIAL
**Estimated Time**: 20 minutes

**Files**:
- `/home/user/dev/sparklingfarce/scenes/map_exploration/hero_controller.gd` (Lines 77, 98, 135)
- `/home/user/dev/sparklingfarce/scenes/map_exploration/map_camera.gd` (Line 51)
- `/home/user/dev/sparklingfarce/core/systems/camera_controller.gd` (Line 226)

**Current**:
```gdscript
"""Smoothly interpolate to target position."""
```

**Correct GDScript Style**:
```gdscript
## Smoothly interpolate to target position.
```

**Action**: Convert all Python-style docstrings to GDScript `##` comments.

---

### MED-005: Magic Numbers in Combat Calculations
**Source Agents**: Lt. Claudette
**Complexity**: SIMPLE
**Estimated Time**: 30 minutes

**Files**:
- `/home/user/dev/sparklingfarce/core/systems/battle_manager.gd` (Lines 428, 529)
- `/home/user/dev/sparklingfarce/scenes/ui/combat_animation_scene.gd`

**Example**:
```gdscript
await get_tree().create_timer(1.2).timeout  # Magic number
```

**Action**: Extract to named constants:
```gdscript
const COMBAT_SETTLE_DELAY: float = 1.2
```

---

### MED-006: Verbose Map Test Scene Logging
**Source Agents**: Commander Clean
**Complexity**: SIMPLE
**Estimated Time**: 20 minutes

**Files**:
- `/home/user/dev/sparklingfarce/scenes/map_exploration/map_test.gd` (15+ prints)
- `/home/user/dev/sparklingfarce/scenes/map_exploration/map_test_playable.gd` (30+ prints)
- `/home/user/dev/sparklingfarce/scenes/map_exploration/test_map_headless.gd` (30+ prints)

**Action**: Add debug toggle:
```gdscript
var DEBUG_VERBOSE: bool = false

func _debug_print(msg: String) -> void:
    if DEBUG_VERBOSE:
        print(msg)
```

---

### MED-007: Party Editor Debug Prints ✅ COMPLETED
**Source Agents**: Commander Clean
**Complexity**: TRIVIAL
**Estimated Time**: 15 minutes

**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/party_editor.gd`
**Lines**: 415, 442, 586, 591, 597, 624, 633, 670, 727, 909

**Action**: Remove all 10 print statements for cleaner editor experience.

---

### MED-008: Hero Controller Debug Print ✅ COMPLETED
**Source Agents**: Commander Clean
**Complexity**: TRIVIAL
**Estimated Time**: 5 minutes

**File**: `/home/user/dev/sparklingfarce/scenes/map_exploration/hero_controller.gd`
**Line**: 205

**Action**: Remove or convert to conditional debug.

---

### MED-009: A* Performance (Documentation)
**Source Agents**: Lt. Barclay, Lt. Claudbrain
**Complexity**: N/A (documentation only for now)
**Estimated Time**: 10 minutes

**File**: `/home/user/dev/sparklingfarce/core/systems/grid_manager.gd`
**Lines**: 269-284

**Current State**: Correctly documented in code comments. O(width * height) per pathfind call.

**Action**: Add TODO comment for future optimization when larger maps are needed:
```gdscript
## TODO: Cache A* weights per movement type when maps exceed 30x30
```

---

### MED-010: TransitionContext Class Needed ✅ COMPLETED
**Source Agents**: Lt. Claudbrain
**Complexity**: MODERATE
**Estimated Time**: 1 hour

**Description**: Battle transition data passes through GameState mixing saveable state with temporary context.

**Current Pattern**:
```gdscript
GameState.set_return_data(scene_path, hero_pos, hero_grid_pos)
```

**Action**: Create dedicated TransitionContext:
```gdscript
class_name TransitionContext extends RefCounted

var transition_type: String  # "battle", "door", "cutscene"
var payload: Dictionary
var return_scene: String
var return_position: Vector2
```

---

### MED-011: ModLoader Resource Load Error Handling
**Source Agents**: Lt. Barclay
**Complexity**: SIMPLE
**Estimated Time**: 30 minutes

**File**: `/home/user/dev/sparklingfarce/core/mod_system/mod_loader.gd`
**Lines**: 129-138

**Current Behavior**: Silent warning on load failure, game continues with missing content.

**Action**: Consider fail-fast mode or graceful degradation with user notification.

---

### MED-012: Missing Cinematic Editor Tab
**Source Agents**: Lt. Claudbrain
**Complexity**: COMPLEX
**Estimated Time**: 4-8 hours

**File**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/main_panel.gd`

**Description**: Editor has tabs for Characters, Classes, Items, Abilities, Dialogues, Parties, Battles - but NOT Cinematics.

**Action**: Add CinematicEditor tab for:
- Command sequence building
- Actor references
- Timing parameters
- Chaining to other cinematics

---

## 5. LOW PRIORITY

### LOW-001: Resource Naming Convention Inconsistency
**Source Agents**: Lt. Claudbrain
**Complexity**: TRIVIAL
**Estimated Time**: N/A (documentation/future consideration)

**Description**: Some resources use `*Data` suffix, others don't:
- CharacterData, ClassData, ItemData (consistent)
- Grid, AIBrain (inconsistent)

**Action**: Document convention. Consider standardizing in future major refactor.

---

### LOW-002: Dictionary Key Check Style Audit
**Source Agents**: Lt. Claudbrain, Lt. Claudette
**Complexity**: SIMPLE
**Estimated Time**: 30 minutes

**Description**: Project specifies `if "key" in dict` but some files may use `.has()`.

**Action**: Run grep for `.has(` on dictionary variables and convert to `in` syntax.

---

### LOW-003: TODO Comments Without Tracking
**Source Agents**: Lt. Claudette
**Complexity**: N/A (process improvement)
**Estimated Time**: N/A

**Description**: 30+ TODO comments across codebase without consistent format.

**Action**: Establish format like `TODO(Phase4):` for searchability.

---

### LOW-004: Signal vs Direct Call Documentation
**Source Agents**: Lt. Claudbrain
**Complexity**: N/A (documentation)
**Estimated Time**: 30 minutes

**Description**: Inconsistent use of signals vs direct calls between systems.

**Action**: Document guidelines:
- Signals for: Events multiple systems may care about
- Direct calls for: Sequential flow control within subsystem

---

### LOW-005: Autoload Namespacing (Future)
**Source Agents**: Lt. Claudbrain
**Complexity**: COMPLEX
**Estimated Time**: N/A (future consideration)

**Description**: 16 autoloads approaches recommended limit.

**Recommendation**: Consider grouping in future:
- Core: ModLoader, GameState, SaveManager, SceneManager
- Battle: BattleManager, TurnManager, GridManager, InputManager, AIController
- Presentation: DialogManager, CinematicsManager, AudioManager

**Action**: Track for future refactor. Current count acceptable.

---

### LOW-006: Hardcoded Combat Formulas (Platform Enhancement)
**Source Agents**: Commander Claudius, Lt. Claudbrain, Modro
**Complexity**: COMPLEX
**Estimated Time**: 8-16 hours

**Files**:
- `/home/user/dev/sparklingfarce/core/systems/combat_calculator.gd`
- `/home/user/dev/sparklingfarce/core/systems/turn_manager.gd`

**Description**: Combat/turn formulas are hardcoded, blocking total conversion mods.

**Action**: Phase 5 consideration. Create CombatConfig resource like ExperienceConfig.

---

### LOW-007: Hardcoded Stats (Platform Enhancement)
**Source Agents**: Modro
**Complexity**: COMPLEX
**Estimated Time**: 8-16 hours

**Files**:
- `/home/user/dev/sparklingfarce/core/resources/character_data.gd`
- `/home/user/dev/sparklingfarce/core/resources/class_data.gd`
- `/home/user/dev/sparklingfarce/core/systems/experience_manager.gd`

**Description**: Stat names (hp, mp, strength, etc.) are hardcoded properties. Custom stats for total conversions not supported.

**Action**: Phase 5 consideration. Replace with Dictionary-based stats.

---

### LOW-008: Mod Lifecycle Hooks
**Source Agents**: Modro
**Complexity**: MODERATE
**Estimated Time**: 2-4 hours

**File**: `/home/user/dev/sparklingfarce/core/mod_system/mod_loader.gd`

**Description**: Mods cannot execute initialization code. No `on_load()` or `on_unload()` hooks.

**Action**: Phase 5 consideration. Add optional script reference in mod.json.

---

## 6. PHASE BREAKDOWN

### Phase A: Critical Bug Fixes ✅ COMPLETED
**Prerequisites**: None
**Testing**: Headless tests for each fix

| Task ID | Description | Effort | Owner |
|---------|-------------|--------|-------|
| CRIT-001 | Remove DEBUG [TO REMOVE] prints | 15m | Any |
| CRIT-002 | Fix cinematics fade overlay leak | 30m | Any |
| CRIT-003 | Add GridManager null checks | 20m | Any |
| CRIT-004 | Fix CinematicActor signal accumulation | 15m | Any |
| CRIT-005 | Fix TriggerManager signal race | 45m | Any |
| CRIT-006 | Add TriggerManager trigger validity check | 10m | Any |

**Verification**: Run all existing headless tests. Manual test of cinematics across scene transitions.

---

### Phase B: High Priority Cleanup ✅ COMPLETED
**Prerequisites**: Phase A complete
**Testing**: Headless tests, manual battle testing

| Task ID | Description | Effort | Owner |
|---------|-------------|--------|-------|
| HIGH-001 | Remove action_menu.gd debug prints | 15m | Any |
| HIGH-002 | Remove AI brain verbose logging | 15m | Any |
| HIGH-003 | Fix unit movement signal timing | 1h | Any |
| HIGH-004 | Fix BattleManager signal connection | 20m | Any |
| HIGH-005 | Fix SceneManager fade overlay timing | 20m | Any |
| HIGH-006 | Fix SetVariableExecutor value usage | 15m | Any |
| HIGH-010 | Fix AIBrain tween encapsulation | 30m | Any |

**Verification**: Full battle flow test. Cinematic system test.

---

### Phase C: Architecture Improvements ✅ COMPLETED
**Prerequisites**: Phase B complete
**Testing**: Manual testing of affected systems

| Task ID | Description | Effort | Owner |
|---------|-------------|--------|-------|
| HIGH-007 | Clarify camera system lifecycle | 1-2h | Claudbrain |
| HIGH-008 | Extract BaseBattleScene class | 1-2h | Any |
| MED-003 | DRY camera executor validation | 30m | Any |
| MED-010 | Create TransitionContext class | 1h | Any |

**Verification**: Battle scenes work with refactored base class. Camera system documented.

---

### Phase D: Code Cleanup ✅ COMPLETED
**Prerequisites**: None (can run in parallel with B/C)
**Testing**: Minimal - style changes only
**Completed**: 2025-11-27

| Task ID | Description | Effort | Status |
|---------|-------------|--------|--------|
| MED-001 | Remove deprecated _handle_death | 10m | ✅ |
| MED-002 | Move root-level test files | 15m | ✅ |
| MED-004 | Convert Python docstrings | 20m | ✅ |
| MED-005 | Extract magic numbers to constants | 30m | ✅ |
| MED-006 | Add debug toggle to map tests | 20m | ✅ |
| MED-007 | Remove party editor debug prints | 15m | ✅ |
| MED-008 | Remove hero controller debug print | 5m | ✅ |
| LOW-002 | Audit dictionary key check style | 30m | ✅ (already compliant) |

**Verification**: Code compiles. Style consistent.

---

### Phase E: Phase 2.5.2 Completion ✅ COMPLETED
**Prerequisites**: Phase A, B complete
**Testing**: Full explore-battle-explore manual test
**Completed**: Previously completed (verified 2025-11-27)

| Task ID | Description | Effort | Status |
|---------|-------------|--------|--------|
| HIGH-011 | Complete scene transition system | 4-6h | ✅ |

**Deliverables**:
1. ✅ TriggerManager.return_to_map() fully implemented
2. ✅ Hero position restored after battle (via TransitionContext)
3. ✅ One-shot triggers persist across round-trip
4. ✅ Victory/defeat both return to map correctly

**Verification**: Manual test: Walk to battle trigger, win battle, return to map at correct position.

---

### Phase F: Future Considerations (Not Scheduled)

| Task ID | Description | Effort | Notes |
|---------|-------------|--------|-------|
| HIGH-009 | Implement stub executors | 2-4h | Phase 4 |
| MED-012 | Add Cinematic Editor tab | 4-8h | Phase 4+ |
| LOW-006 | CombatConfig resource | 8-16h | Phase 5 |
| LOW-007 | Dictionary-based stats | 8-16h | Phase 5 |
| LOW-008 | Mod lifecycle hooks | 2-4h | Phase 5 |
| MED-011 | ModLoader error handling | 30m | Phase 5 |

---

## 7. CONFLICTS/DECISIONS NEEDED

### Decision 1: Camera System Architecture
**Conflicting Views**: Lt. Claudbrain suggests either making CameraController an autoload OR creating CameraManager singleton.

**Options**:
| Option | Pros | Cons |
|--------|------|------|
| CameraController as autoload | Single source of truth, simple access | May conflict with scene-specific cameras |
| CameraManager singleton | Tracks active camera, supports multiple | Additional complexity |
| Keep current manual registration | Minimal change | Continues unclear lifecycle |

**Recommendation**: CameraManager singleton - provides flexibility while adding clarity.

---

### Decision 2: Debug Logging Strategy
**Agents**: Commander Clean, Lt. Claudette both recommend removing debug prints.

**Options**:
| Option | Pros | Cons |
|--------|------|------|
| Remove all prints | Clean output, better performance | No debug info when needed |
| Convert to DebugLogger autoload | Configurable verbosity | Additional system to maintain |
| Keep with debug flag per file | Simple, local control | Inconsistent across files |

**Recommendation**: Remove all non-essential prints now. Consider DebugLogger autoload for Phase 5.

---

### Decision 3: SetVariableExecutor Behavior
**Lt. Claudette** identified that `value` parameter is ignored.

**Options**:
| Option | Pros | Cons |
|--------|------|------|
| Use value with set_campaign_data | Full flexibility | Requires GameState.set_campaign_data() to exist |
| Document as boolean-only | No code change | Limited functionality |
| Create separate set_data executor | Clear separation | Two similar executors |

**Recommendation**: Implement with value support. GameState already has campaign_data Dictionary.

---

### Decision 4: Test Scene Refactoring Scope
**Commander Clean** identified 150+ lines of duplication.

**Options**:
| Option | Pros | Cons |
|--------|------|------|
| Full BaseBattleScene extraction | Maximum DRY, maintainable | 1-2 hours work |
| Partial extraction (just _generate_test_map) | Quick win | Still some duplication |
| Leave as-is (test code) | No work | Technical debt remains |

**Recommendation**: Full extraction. Test scenes are actively used and will continue to evolve.

---

### Decision 5: Platform Enhancement Priority
**Commander Claudius, Lt. Claudbrain, Modro** all note hardcoded formulas limit total conversions.

**Current Score**: 7/10 moddability (per Modro)
**Target**: 9/10 with CombatConfig and Dictionary stats

**Options**:
| Option | Pros | Cons |
|--------|------|------|
| Address in Phase 4 | Earlier platform maturity | Delays core features |
| Address in Phase 5 | Focus on gameplay first | Delayed platform promise |
| Partial now (CombatConfig only) | Moderate effort | Stats still hardcoded |

**Recommendation**: Phase 5. Focus on completing core gameplay loop first. Document as known limitation.

---

## APPENDIX A: AGENT REPORT SUMMARY

| Agent | Focus Area | Report Quality | Key Contribution |
|-------|------------|----------------|------------------|
| Commander Claudius | Vision/SF Fidelity | Comprehensive | Phase prioritization, SF authenticity validation |
| Commander Clean | Code Efficiency | Detailed | Debug print identification, duplication analysis |
| Lt. Barclay | Diagnostics/Bugs | Thorough | Critical bug identification, signal analysis |
| Lt. Claudbrain | Architecture | Systematic | System design review, planning gaps |
| Lt. Claudette | Godot Best Practices | Detailed | Style compliance, type safety audit |
| Modro | Mod Architecture | Comprehensive | Extensibility gaps, platform assessment |

---

## APPENDIX B: FILE QUICK REFERENCE

### Critical Files (Immediate Attention)
- `/home/user/dev/sparklingfarce/core/systems/cinematics_manager.gd`
- `/home/user/dev/sparklingfarce/core/systems/grid_manager.gd`
- `/home/user/dev/sparklingfarce/core/systems/trigger_manager.gd`
- `/home/user/dev/sparklingfarce/core/components/cinematic_actor.gd`
- `/home/user/dev/sparklingfarce/core/resources/ai_brain.gd`
- `/home/user/dev/sparklingfarce/core/components/unit.gd`

### High Priority Files
- `/home/user/dev/sparklingfarce/scenes/ui/action_menu.gd`
- `/home/user/dev/sparklingfarce/mods/base_game/ai_brains/ai_aggressive.gd`
- `/home/user/dev/sparklingfarce/mods/base_game/ai_brains/ai_stationary.gd`
- `/home/user/dev/sparklingfarce/core/systems/battle_manager.gd`
- `/home/user/dev/sparklingfarce/core/systems/scene_manager.gd`
- `/home/user/dev/sparklingfarce/mods/_sandbox/scenes/test_unit.gd`
- `/home/user/dev/sparklingfarce/mods/_sandbox/scenes/battle_loader.gd`

### Medium Priority Files
- `/home/user/dev/sparklingfarce/scenes/map_exploration/hero_controller.gd`
- `/home/user/dev/sparklingfarce/scenes/map_exploration/map_camera.gd`
- `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/party_editor.gd`
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/camera_move_executor.gd`
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/camera_shake_executor.gd`
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/set_variable_executor.gd`

---

**End of Implementation Plan**

*"The first duty of every Starfleet officer is to the truth. Whether it's scientific truth, or historical truth, or personal truth. It is the guiding principle upon which Starfleet is based."* - Captain Picard

*And in software, the first duty is to the bug tracker.*

---

**Lt. Claudbrain**
*Technical Lead, USS Torvalds*
*Stardate 2025.330*
