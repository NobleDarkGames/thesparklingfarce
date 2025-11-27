# Commander Clean Efficiency Report
## Codebase Cleanliness Analysis - The Sparkling Farce

**Report Date:** 2025-11-26
**Analyst:** Commander Clean (Code Efficiency Agent)
**Target:** Full GDScript codebase review

---

## EXECUTIVE SUMMARY

| Category | Issue Count | Severity | Estimated LOC Reduction |
|----------|-------------|----------|------------------------|
| DEBUG_REMNANT | 18 | CRITICAL | 45+ lines |
| DUPLICATION | 4 major patterns | HIGH | 150+ lines |
| DRY_VIOLATION | 3 patterns | MEDIUM | 80+ lines |
| DEAD_CODE | 2 items | MEDIUM | 15+ lines |
| OVER_COMPLEX | 2 areas | LOW | 30+ lines |

**Total Estimated Savings:** 320+ lines of code

---

## CRITICAL ISSUES

### CATEGORY: DEBUG_REMNANT

#### Issue DR-001: Marked "DEBUG [TO REMOVE]" Statements
**Severity:** CRITICAL
**Impact:** These are explicitly marked for removal by the original author.

**Locations:**
- `/home/user/dev/sparklingfarce/core/resources/ai_brain.gd:26`
- `/home/user/dev/sparklingfarce/core/resources/ai_brain.gd:31`
- `/home/user/dev/sparklingfarce/core/resources/ai_brain.gd:35`
- `/home/user/dev/sparklingfarce/core/resources/ai_brain.gd:37`
- `/home/user/dev/sparklingfarce/core/resources/ai_brain.gd:39`
- `/home/user/dev/sparklingfarce/core/components/unit.gd:226`
- `/home/user/dev/sparklingfarce/core/components/unit.gd:264`
- `/home/user/dev/sparklingfarce/mods/base_game/ai_brains/ai_aggressive.gd:70`
- `/home/user/dev/sparklingfarce/mods/base_game/ai_brains/ai_aggressive.gd:77`
- `/home/user/dev/sparklingfarce/mods/base_game/ai_brains/ai_aggressive.gd:79`

**Code Samples:**
```gdscript
# ai_brain.gd:26
print("DEBUG [TO REMOVE]: execute_async called for %s" % unit.character_data.character_name)

# unit.gd:226
print("DEBUG [TO REMOVE]: %s animating movement over %.2fs (distance: %.1f)" % [character_data.character_name, duration, distance])
```

**Action:** DELETE all 10 lines containing "DEBUG [TO REMOVE]"

---

#### Issue DR-002: Action Menu Debug Logging
**Severity:** HIGH
**Location:** `/home/user/dev/sparklingfarce/scenes/ui/action_menu.gd`
**Lines:** 53, 81, 92, 129, 230, 235, 240, 245-246, 250, 253-254, 265

**Description:** 15+ print statements in production UI code. These were likely added during debugging of session ID issues but should be removed.

**Code Samples:**
```gdscript
# action_menu.gd:53
print("ActionMenu: Storing session_id=%d for this menu instance" % _menu_session_id)

# action_menu.gd:245-246
print("ActionMenu: _confirm_selection called, selected_index=%d, action=%s" % [selected_index, selected_action])
print("ActionMenu: available_actions = %s" % str(available_actions))
```

**Action:** REMOVE all print statements. Convert critical ones to push_warning if needed for error cases only.

---

#### Issue DR-003: AI Brain Debug Logging
**Severity:** MEDIUM
**Locations:**
- `/home/user/dev/sparklingfarce/mods/base_game/ai_brains/ai_aggressive.gd:17-51` (9 print statements)
- `/home/user/dev/sparklingfarce/mods/base_game/ai_brains/ai_stationary.gd:16-57` (6 print statements)

**Description:** Verbose turn-by-turn logging in AI decision code.

**Action:** REMOVE or convert to conditional debug flag.

---

## HIGH PRIORITY ISSUES

### CATEGORY: DUPLICATION

#### Issue DUP-001: test_unit.gd and battle_loader.gd Near-Duplicate Code
**Severity:** HIGH
**Locations:**
- `/home/user/dev/sparklingfarce/mods/_sandbox/scenes/test_unit.gd`
- `/home/user/dev/sparklingfarce/mods/_sandbox/scenes/battle_loader.gd`

**Description:** These two files share ~70% identical code including:
- `_generate_test_map()` function (lines 161-186 vs 209-235) - IDENTICAL
- `_spawn_unit()` function (lines 212-230 vs 240-258) - IDENTICAL
- `_on_player_turn_started()` (lines 305-319 vs 307-321) - NEARLY IDENTICAL
- `_on_enemy_turn_started()` (lines 322-332 vs 324-334) - NEARLY IDENTICAL
- `_on_unit_turn_ended()` (lines 335-343 vs 337-345) - IDENTICAL
- `_on_battle_ended()` (lines 346-352 vs 348-356) - NEARLY IDENTICAL
- `_on_combat_resolved()` (lines 355-363 vs 359-367) - NEARLY IDENTICAL
- `_process()` camera following logic (lines 233-269 vs 261-303) - SIMILAR

**Code Sample - _generate_test_map() (IDENTICAL in both files):**
```gdscript
func _generate_test_map() -> void:
	var grid_visual: Node2D = Node2D.new()
	grid_visual.name = "GridVisual"
	$Map.add_child(grid_visual)
	for x in range(20):
		for y in range(11):
			var cell_rect: ColorRect = ColorRect.new()
			cell_rect.size = Vector2(32, 32)
			cell_rect.position = Vector2(x * 32, y * 32)
			if (x + y) % 2 == 0:
				cell_rect.color = Color(0.3, 0.4, 0.3)
			else:
				cell_rect.color = Color(0.4, 0.5, 0.4)
			grid_visual.add_child(cell_rect)
	if _ground_layer and _ground_layer.tile_set:
		for x in range(20):
			for y in range(11):
				_ground_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
```

**Refactoring Recommendation:**
1. Extract shared code into a base class `BaseBattleScene`
2. Have both `test_unit.gd` and `battle_loader.gd` extend it
3. Override only the differing behavior (unit spawning logic)

**Estimated LOC Reduction:** 120+ lines

---

#### Issue DUP-002: Controls Help Text Duplication
**Severity:** MEDIUM
**Locations:**
- `/home/user/dev/sparklingfarce/mods/_sandbox/scenes/test_unit.gd:151-158`
- `/home/user/dev/sparklingfarce/mods/_sandbox/scenes/battle_loader.gd:199-206`

**Code (IDENTICAL):**
```gdscript
print("\n=== Controls ===")
print("Arrow keys = Move cursor")
print("Enter/Space/Z = Confirm position / Open action menu")
print("Backspace/X = Free cursor inspect mode (B button)")
print("Arrow keys = Navigate action menu")
print("Enter/Space/Z = Confirm action")
print("Backspace/X in menu = Cancel and return to movement")
print("Q = Quit")
```

**Action:** Extract to utility function or remove entirely (these are test scenes).

---

#### Issue DUP-003: _create_character Function Pattern
**Severity:** MEDIUM
**Locations:**
- `/home/user/dev/sparklingfarce/mods/_sandbox/scenes/test_unit.gd:189-209` - `_create_test_character()`
- `/home/user/dev/sparklingfarce/test_ai_headless.gd:62-80` - `_create_character()`

**Description:** Nearly identical character creation logic with slightly different signatures.

**Action:** Consider a factory utility in core/utils/ for test character creation.

---

### CATEGORY: DRY_VIOLATION

#### Issue DRY-001: Camera Check Pattern in Executors
**Severity:** LOW
**Locations:**
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/camera_move_executor.gd:14-21`
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/camera_shake_executor.gd:15-22`
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/camera_follow_executor.gd` (similar pattern)

**Code Pattern Repeated:**
```gdscript
if not manager._active_camera:
	push_warning("Camera[X]Executor: No camera available")
	return true

if not manager._active_camera is CameraController:
	push_warning("Camera[X]Executor: Camera is Camera2D, not CameraController...")
	return true

var camera: CameraController = manager._active_camera as CameraController
```

**Refactoring Recommendation:**
Create helper method in `CinematicsManager` or base executor:
```gdscript
func _get_camera_controller(manager: Node) -> CameraController:
	if not manager._active_camera:
		push_warning("No camera available")
		return null
	if not manager._active_camera is CameraController:
		push_warning("Camera is not CameraController")
		return null
	return manager._active_camera as CameraController
```

---

## MEDIUM PRIORITY ISSUES

### CATEGORY: DEAD_CODE

#### Issue DC-001: Deprecated _handle_death Function
**Severity:** MEDIUM
**Location:** `/home/user/dev/sparklingfarce/core/components/unit.gd:406-412`

**Code:**
```gdscript
## Handle unit death (DEPRECATED - death visuals now handled by BattleManager)
## This method is kept for backwards compatibility but no longer creates tweens
func _handle_death() -> void:
	print("%s has died!" % character_data.character_name)
	GridManager.clear_cell_occupied(grid_position)
	died.emit()
	# Note: BattleManager is responsible for death visuals and cleanup
```

**Action:** Verify no callers exist, then DELETE. The docstring confirms it's deprecated.

---

#### Issue DC-002: Root-Level Test Files
**Severity:** LOW
**Locations:**
- `/home/user/dev/sparklingfarce/test_ai_headless.gd` (+ .tscn, .uid)
- `/home/user/dev/sparklingfarce/test_executors/` directory

**Description:** Test files in project root rather than in `scenes/tests/` or `mods/_sandbox/`.

**Action:** Move to appropriate test directories or remove if no longer needed.

---

### CATEGORY: OVER_COMPLEX

#### Issue OC-001: Verbose Map Test Scene Logging
**Severity:** LOW
**Locations:**
- `/home/user/dev/sparklingfarce/scenes/map_exploration/map_test.gd` (15+ print statements)
- `/home/user/dev/sparklingfarce/scenes/map_exploration/map_test_playable.gd` (30+ print statements)
- `/home/user/dev/sparklingfarce/scenes/map_exploration/test_map_headless.gd` (30+ print statements)

**Description:** Extensive console logging in test scenes. While acceptable for tests, the quantity is excessive.

**Action:** Consider a debug flag to toggle verbosity:
```gdscript
var DEBUG_VERBOSE: bool = false
func _debug_print(msg: String) -> void:
	if DEBUG_VERBOSE:
		print(msg)
```

---

## LOW PRIORITY ISSUES

### CATEGORY: DEBUG_REMNANT

#### Issue DR-004: Hero Controller Debug Print
**Severity:** LOW
**Location:** `/home/user/dev/sparklingfarce/scenes/map_exploration/hero_controller.gd:205`

**Code:**
```gdscript
print("HeroController: Attempting interaction at ", interaction_pos)
```

**Action:** Remove or convert to conditional debug.

---

#### Issue DR-005: Party Editor Debug Prints
**Severity:** LOW
**Location:** `/home/user/dev/sparklingfarce/addons/sparkling_editor/ui/party_editor.gd`
**Lines:** 415, 442, 586, 591, 597, 624, 633, 670, 727, 909

**Description:** 10 print statements in editor plugin code.

**Action:** Remove for cleaner editor experience.

---

### CATEGORY: STUB_TODO_FILES

#### Issue STUB-001: Unimplemented Cinematic Executors
**Severity:** LOW (by design)
**Locations:**
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/spawn_entity_executor.gd`
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/despawn_entity_executor.gd`
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/play_music_executor.gd`
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/play_sound_executor.gd`

**Description:** Stub implementations with TODO comments. These are placeholders for Phase 4.

**Action:** No immediate action needed - track in project roadmap.

---

## SUMMARY BY FILE

| File | Issue Count | Priority Actions |
|------|-------------|------------------|
| `ai_brain.gd` | 5 | Remove DEBUG prints |
| `ai_aggressive.gd` | 12 | Remove DEBUG + verbose prints |
| `ai_stationary.gd` | 6 | Remove verbose prints |
| `action_menu.gd` | 15 | Remove all prints |
| `unit.gd` | 3 | Remove DEBUG prints + deprecated function |
| `test_unit.gd` | 20+ | Extract to base class |
| `battle_loader.gd` | 20+ | Extract to base class |
| `map_test*.gd` | 45+ | Add debug toggle |

---

## RECOMMENDED REFACTORING PRIORITY

1. **IMMEDIATE:** Remove all "DEBUG [TO REMOVE]" statements (10 lines, 5 minutes)
2. **HIGH:** Remove action_menu.gd debug prints (15 lines, 10 minutes)
3. **HIGH:** Remove AI brain verbose logging (15 lines, 10 minutes)
4. **MEDIUM:** Create BaseBattleScene class for test_unit/battle_loader (150+ lines saved, 1-2 hours)
5. **LOW:** Consolidate camera executor validation (20 lines, 30 minutes)
6. **LOW:** Clean up test file locations (organization, 15 minutes)

---

## COMPLIANCE NOTES

### Godot Style Guide Violations Found: NONE
- Strict typing is used consistently
- No walrus operator `:=` usage detected
- Dictionary key checks use `if 'key' in dict` pattern correctly

### Code Quality Observations
- Good use of signals for decoupling
- Consistent naming conventions
- Appropriate use of push_error/push_warning for actual errors
- Well-structured base class pattern in editor (base_resource_editor.gd)

---

**Report Generated By:** Commander Clean
**Mission Status:** COMPLETE - Awaiting orders for cleanup execution
