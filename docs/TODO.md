# The Sparkling Farce - Pending Tasks

This document tracks all pending work items. Updated 2026-01-21.

---

## Critical Async Safety Bugs (Priority: CRITICAL)

From multi-agent code review 2026-01-21. These are crash/corruption risks under edge conditions.

### BattleManager Async Issues
- [ ] `battle_manager.gd:2027-2030` - Unchecked canvas reference after timer await (crash if scene transitions during delay)
- [ ] `battle_manager.gd:1559` - Unguarded unit access after tween.finished
- [ ] `battle_manager.gd:1783-1785` - `_wait_for_level_ups` infinite loop without timeout (deadlock risk)
- [ ] `battle_manager.gd:1366` - Unguarded get_tree() after timer await
- [ ] `battle_manager.gd:340-344` - Unit signal callback binding reference leak (no disconnect in end_battle)
- [ ] `battle_manager.gd:121-125` - Null cached scene returned without validation
- [ ] `battle_manager.gd:1320-1356` - combat_anim_instance validity not checked after multiple awaits

### SceneManager Async Issues
- [ ] `scene_manager.gd:146-172` - Double-await state corruption in fade_to_black (no guard after await)
- [ ] `scene_manager.gd:150-151,182-183` - Concurrent fade requests cause deadlock (caller awaiting rejected fade never completes)
- [ ] `scene_manager.gd:256-262` - go_back() overwrites previous_scene_path breaking double back-navigation

### ShopManager Transaction Safety
- [ ] `shop_manager.gd:905-927` - Rollback failure in `_add_items_with_rollback` causes silent inventory corruption

### CinematicsManager State Issues
- [ ] `cinematics_manager.gd:658-663` - `_on_dialog_ended` doesn't verify current_cinematic validity before proceeding
- [ ] `cinematics_manager.gd:630` - Off-by-one command index tracking (increments even on failure)

---

## High Severity Bugs (Priority: HIGH)

### Singleton Issues
- [ ] `caravan_controller.gd:383-386` - Menu state restoration incorrect on scene change
- [ ] `caravan_controller.gd:627-628` - `is_spawned()` doesn't use is_instance_valid()
- [ ] `debug_console.gd:390-394` - Mod command callback errors not handled (crashes console)
- [ ] `turn_manager.gd:59` - `_active_popup_labels` not cleaned on battle exit

### UI Async Issues
- [ ] `dialog_box.gd:237-251` - `_on_dialog_ended` awaits without guard
- [ ] `promotion_ceremony.gd:72-73` - Never disconnects PromotionManager signal (memory leak)
- [ ] `choice_selector.gd:126-134` - Hide animation race with `_on_choices_ready`
- [ ] `shops/shop_controller.gd:127-138` - Close-shop re-entrancy through signal chain

### ModLoader Issues
- [ ] `mod_loader.gd:688-695` - Path traversal detection swallows error silently
- [ ] `mod_loader.gd:349-378` - Async load missing cancellation mechanism

---

## Architecture Improvements (Priority: HIGH)

From Chief Engineer O'Brien's architecture review.

### BattleManager Decomposition
- [ ] Extract `CombatSessionExecutor` - combat animation session, phase execution, XP pooling
- [ ] Extract `BattleExitController` - Egress, Angel Wing, defeat transitions
- [ ] Extract `BattleRewardsDistributor` - XP and loot distribution
- [ ] Create `BattleCleanup.execute()` to encapsulate all cleanup calls

### Event System Consistency
- [ ] Route BattleManager signals through GameEventBus for mod hook consistency
- [ ] Add pre/post events for item use, spell cast to GameEventBus
- [ ] Document which events support cancellation

### State Management
- [ ] Resolve TurnManager.battle_active state duplication with BattleManager
- [ ] Consider separating GridManager battle functions from exploration utilities

### Test Coverage Gaps
- [ ] InputManager (2,419 lines, HIGH risk, untested) - Add state machine tests
- [ ] CaravanController (860 lines, untested)
- [ ] DebugConsole (1,148 lines, untested)

---

## Editor Bugs (Priority: HIGH)

Critical bugs found in Sparkling Editor code review:

### Off-by-One Metadata Bugs
- [ ] `battle_editor.gd:633` - AI dropdown metadata at wrong index
- [ ] `battle_editor.gd:604` - Audio dropdown item ID off by one
- [ ] `character_editor.gd:731` - AI behavior dropdown metadata off by one

### Missing Dirty Tracking
- [ ] `class_editor.gd:261-269` - Equipment section never calls `_mark_dirty`
- [ ] `ability_editor.gd:435` - Status effect changes don't trigger dirty flag

### Memory Leaks
- [ ] `cinematic_editor.gd:1289-1299` - ConfirmationDialog never freed
- [ ] `caravan_editor.gd:443-444` - EditorFileDialog not freed

### Data Integrity
- [ ] `save_slot_editor.gd:942-968` - Creates orphaned/duplicate metadata entries

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
- [ ] `_updating_ui` pattern - 17 editors declare own var instead of using inherited `_is_loading` (~200 lines)
- [ ] Place on Map sections (~80 lines duplicated in npc_editor.gd, interactable_editor.gd)
- [ ] Advanced Options section duplication (npc_editor.gd, interactable_editor.gd) (~60 lines)
- [ ] Conditional cinematics section duplication (~40 lines)
- [ ] `_load_texture` helper duplication (npc_editor.gd:815, interactable_editor.gd:966) (~12 lines)
- [ ] Spawn handler boilerplate in cinematic_spawners/ (~30 lines)
- [ ] CRAFTER_TYPES constant (duplicated in crafter_editor.gd, crafting_recipe_editor.gd)
- [ ] Registry fallback patterns (4 files have identical lookup code)

### Debug Code Cleanup
- [ ] `cinematic_editor.gd:1475` - Migration print should be push_warning or removed
- [ ] `save_slot_selector.gd:162-309` - 17 debug print() calls to remove

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
