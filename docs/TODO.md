# The Sparkling Farce - Pending Tasks

This document tracks all pending work items. Updated 2026-01-21.

---

## Critical Async Safety Bugs (Priority: CRITICAL)

From multi-agent code review 2026-01-21. Fixed in commit 74adaab.

### BattleManager Async Issues
- [x] `battle_manager.gd:2027-2030` - Unchecked canvas reference after timer await
- [x] `battle_manager.gd:1559` - Unguarded unit access after tween.finished
- [x] `battle_manager.gd:1783-1785` - `_wait_for_level_ups` infinite loop without timeout
- [x] `battle_manager.gd:1366` - Unguarded get_tree() after timer await
- [x] `battle_manager.gd:340-344` - Unit signal callback binding reference leak
- [x] `battle_manager.gd:121-125` - Null cached scene returned without validation
- [x] `battle_manager.gd:1320-1356` - combat_anim_instance validity not checked after multiple awaits

### SceneManager Async Issues
- [x] `scene_manager.gd:146-172` - Double-await state corruption in fade_to_black
- [x] `scene_manager.gd:150-151,182-183` - Concurrent fade requests cause deadlock
- [x] `scene_manager.gd:256-262` - go_back() overwrites previous_scene_path

### ShopManager Transaction Safety
- [x] `shop_manager.gd:905-927` - Rollback failure in `_add_items_with_rollback`

### CinematicsManager State Issues
- [x] `cinematics_manager.gd:658-663` - `_on_dialog_ended` doesn't verify current_cinematic validity
- [x] `cinematics_manager.gd:630` - Off-by-one command index tracking (increments even on failure)

---

## High Severity Bugs (Priority: HIGH)

### Singleton Issues (Fixed in commit 74adaab)
- [x] `caravan_controller.gd:383-386` - Menu state restoration incorrect on scene change
- [x] `caravan_controller.gd:627-628` - `is_spawned()` doesn't use is_instance_valid()
- [x] `debug_console.gd:390-394` - Mod command callback errors not handled
- [x] `turn_manager.gd:59` - `_active_popup_labels` not cleaned on battle exit

### UI Async Issues (Fixed in commit 74adaab)
- [x] `dialog_box.gd:237-251` - `_on_dialog_ended` awaits without guard
- [x] `promotion_ceremony.gd:72-73` - Never disconnects PromotionManager signal
- [x] `choice_selector.gd:126-134` - Hide animation race with `_on_choices_ready`
- [x] `shops/shop_controller.gd:127-138` - Close-shop re-entrancy through signal chain

### ModLoader Issues (Fixed)
- [x] `mod_loader.gd:688-695` - Path traversal now emits `path_security_violation` signal
- [x] `mod_loader.gd:349-378` - Added async load cancellation mechanism

---

## Architecture Improvements (Priority: HIGH)

From Chief Engineer O'Brien's architecture review.

### BattleManager Decomposition (Complete)
- [x] Extract `BattleRewardsDistributor` - gold and item distribution (commit 7bc03d4)
- [x] Extract `BattleCleanup` - encapsulate all cleanup calls (commit 2b6e403)
- [x] Extract `BattleExitController` - Egress, Angel Wing, defeat transitions (commit 8b182e3)
- [x] Extract `CombatSessionExecutor` - combat animation session, XP pooling (commit 7fc5d5c)

### Event System Consistency
- [x] Route BattleManager signals through GameEventBus for mod hook consistency
- [x] Add pre/post events for item use, spell cast to GameEventBus
- [x] Document which events support cancellation

### State Management
- [x] Resolve TurnManager.battle_active state duplication with BattleManager
- [ ] Consider separating GridManager battle functions from exploration utilities

### Test Coverage Gaps
- [x] InputManager (2,419 lines) - 95 test cases in test_input_manager.gd (808 lines)
- [x] CaravanController (860 lines) - 96 test cases in test_caravan_controller.gd (1,126 lines)
- [x] DebugConsole (1,148 lines) - 126 test cases in test_debug_console.gd (1,034 lines)

---

## Editor Bugs (Priority: HIGH)

Critical bugs found in Sparkling Editor code review:

### Off-by-One Metadata Bugs (Fixed)
- [x] `battle_editor.gd:633` - AI dropdown metadata at wrong index
- [x] `battle_editor.gd:604` - Audio dropdown item ID off by one
- [x] `character_editor.gd:731` - AI behavior dropdown metadata off by one

### Missing Dirty Tracking (Already Fixed)
- [x] `class_editor.gd:261-269` - Equipment section already calls `_mark_dirty`
- [x] `ability_editor.gd:435` - Status effect changes already trigger dirty flag

### Memory Leaks (Already Fixed)
- [x] `cinematic_editor.gd:1289-1299` - ConfirmationDialog cleanup via visibility_changed
- [x] `caravan_editor.gd:443-444` - EditorFileDialog cleanup via visibility_changed

### Data Integrity (Fixed)
- [x] `save_slot_editor.gd:942-968` - Simplified to single-loop pattern, no orphans

**Full report:** `docs/untracked/EDITOR_CODE_REVIEW.md`

---

## Release Blocking (Priority: CRITICAL)

2 items remaining before alpha release:

- [ ] Complete modder documentation Tutorial 4 (Abilities and Magic)
- [ ] Replace 23 [PLACEHOLDER] entries across community docs

---

## Editor Code Quality (Priority: MEDIUM)

From code review - consolidation opportunities (~650 lines reducible).

### Duplication to Consolidate
- [x] `_updating_ui` pattern - 15 editors now use inherited var from base class (~30 lines removed)
- [ ] Place on Map sections (~80 lines duplicated in npc_editor.gd, interactable_editor.gd)
- [ ] Advanced Options section duplication (npc_editor.gd, interactable_editor.gd) (~60 lines)
- [ ] Conditional cinematics section duplication (~40 lines)
- [x] `_load_texture` helper moved to SparklingEditorUtils.load_texture()
- [x] Spawn handler boilerplate - added _build_entity_list_from_registry() helper (~45 lines consolidated)
- [x] CRAFTER_TYPES constant moved to SparklingEditorUtils
- [x] Registry fallback patterns - added populate_registry_dropdown() helper (3 files consolidated)

### Debug Code Cleanup
- [x] `cinematic_editor.gd:1522` - Migration print converted to push_warning
- [x] `save_slot_selector.gd` - 17 debug print() calls removed

### Large Files to Split
- [ ] `cinematic_editor.gd` (2,236 lines) - Split into base, command inspector, actor panel
- [ ] `character_editor.gd` (1,428 lines) - Extract sections
- [ ] `base_resource_editor.gd` (1,817 lines) - Decompose `_setup_base_ui()` (154 lines)

---

## Deferred Features (Priority: BACKLOG)

- [ ] Dialog box auto-positioning (avoid portrait overlap)
- [ ] Mod field menu options (position parameter support)
- [ ] Spell animation system enhancements
- [ ] Additional cinematic commands
- [ ] Save slot management improvements
- [ ] Advanced AI behavior patterns

---

## Reference Documents

- `docs/untracked/PHASE_STATUS.md` - High-level project status
- `docs/untracked/EDITOR_CODE_REVIEW.md` - Full editor code review findings
- `docs/specs/platform-specification.md` - Technical specification
