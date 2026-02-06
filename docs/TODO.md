# The Sparkling Farce - Pending Tasks

Updated 2026-02-06. 225 fixes applied across Phases 1-6 of systematic codebase review.

---

## Release Blocking (Priority: CRITICAL)

- [ ] Complete modder documentation Tutorial 4 (Abilities and Magic)
- [ ] Replace 23 [PLACEHOLDER] entries across community docs

---

## Codebase Review — Remaining (Low/Deferred)

### Phase 1: Battle Core (12 Low)

- [ ] `battle_manager.gd:1764-1775` - `_on_hero_died_in_battle` no `battle_active` check between chained awaits
- [ ] `battle_manager.gd:1760` - `quit_battle_from_menu` doesn't await async exit
- [ ] `battle_manager.gd:349-353` - `.bind()` on `died` signal fragile if signal has parameters
- [ ] `battle_manager.gd:1560-1568` - Victory path silently fails on missing TransitionContext
- [ ] `input_manager.gd:713,719` - State enter handlers assume non-null `active_unit`
- [ ] `turn_manager.gd:277` - `boss_alive` misleading initialization
- [ ] `turn_manager.gd:692` - `_show_reinforcement_warning` missing `current_scene` null check
- [ ] `turn_manager.gd:706-707` - `_is_valid_living_unit` uses `!= null` instead of `is_instance_valid()`
- [ ] `turn_manager.gd:644` - `_show_popup` doesn't check `is_instance_valid(unit)`
- [ ] `grid_manager.gd:399-443` - BFS queue suboptimal with varied terrain costs (should be priority queue)
- [ ] `grid_manager.gd:171-186` - `load_terrain_data` early return blocks all layers if first has no tileset
- [ ] `battle_rewards_distributor.gd:18-60` - Double reward distribution unprotected

### Phase 2: Content & Narrative (7 Low/Style)

- [ ] `cinematics_manager.gd:613` - Untyped `command.get()` — style judgment
- [ ] `cinematics_manager.gd` - Inconsistent `command.get()` vs `DictUtils` — style judgment
- [ ] `cinematics_manager.gd:229,249` - Redundant `scene_root.get_tree()` — too risky for too little benefit
- [ ] `cinematics_manager.gd:894,899` - Magic string "CinematicStage" — standard Godot pattern
- [ ] Inconsistent default `wait` values across executor types — intentional per command semantics
- [ ] `cinematic_command_executor.gd:123-125` - Base `execute()` returns true — silent skip on unimplemented subclass
- [ ] `cinematic_loader.gd:168,198,235` - `.get()` used instead of `"key" in dict` — style judgment

### Phase 3: Party, Economy & Progression (4 Deferred Medium)

- [ ] `equipment_manager.gd` - `.get()` used defensively on system-created dicts (style judgment)
- [ ] `party_manager.gd:454` - `_insert_member()` edge case with `MAX_ACTIVE_SIZE` index (always valid given checks)
- [ ] `save_manager.gd:198-207` - TOCTOU race in `load_from_slot` (extremely unlikely in practice)
- [ ] `storage_manager.gd:367` - `load_config_from_manifest` unused `mod_id` parameter (needed for future fix)

### Phase 4: Infrastructure Singletons (7 Deferred Medium + 23 Low)

#### Deferred Medium
- [ ] `mod_loader.gd:319` - `load_threaded_get` on known-failed resources (safe, just wasteful)
- [ ] `mod_registry.gd:307-315` - `clear_mod_resources()` doesn't restore override chain (needs full reload)
- [ ] `mod_loader.gd:260-330` - Partial load marked as success (needs design discussion)
- [ ] `settings_manager.gd:48` - `voice_volume` dead setting (feature placeholder)
- [ ] `audio_manager.gd:74-75` - Audio cache grows unbounded (needs eviction strategy design)
- [ ] `random_manager.gd:55-58` - Global `randi()` for seed generation (fragile but works)
- [ ] `random_manager.gd` - No per-battle seed snapshot (architectural enhancement)

#### Low
- [ ] Scene/Events: stale fade signal, nullable weapon doc, pre_level_up cancel leak, import_state always true, import/reset no signals, set_flag null default, trigger_type_registry null
- [ ] Mod System: cancelled async leak, registry circular ref, stale partial data, create_mod hardcoded subdirs, untyped iteration, dead type check
- [ ] Settings/Audio/RNG: window_scale not applied, no type validation on loaded settings, duplicate screen_shake semantics, noop _update_volumes, in-flight SFX volume, stale fallback translations, unsanitized translations, unclamped hit_chance

### Phase 5: Components & Core Classes (16 Deferred Medium + 17 Low)

#### Deferred Medium
- [ ] `unit_stats.gd` - Poison/regen tick ordering (design decision on priority)
- [ ] `unit.gd` - Lambda accumulation in tween callbacks (Godot tweens clean up on kill)
- [ ] `unit.gd` - move_to facing skip on zero-distance moves (edge case only)
- [ ] `unit_stats.gd` - Equipment bonus architecture divergence between init and load paths (risky, needs design)
- [ ] `unit.gd`/`unit_stats.gd` - Status effect return contract void->bool (API change affects all callers)
- [ ] `cinematic_data.gd` - loop property declared but unimplemented (feature placeholder)
- [ ] `npc_data.gd`/`interactable_data.gd` - Condition eval duplication (refactoring scope expansion)
- [ ] `grid.gd` - Integer division truncation / warning_ignore (cell sizes always even in practice)
- [ ] `character_data.gd`/`class_data.gd` - Reflection type safety in get() (standard pattern with safe defaults)
- [ ] `caravan_data.gd` - Terrain validation not used by caravan follower
- [ ] `character_save_data.gd` - Equipment slot Dictionary schema validation (no type class)
- [ ] `combat_phase.gd` - Constructor validity checks (units guaranteed valid at creation)
- [ ] `ai_controller.gd`/`configurable_ai_brain.gd` - Singleton lifecycle during scene transitions (autoloads persist)
- [ ] `ai_controller.gd` - Stale context refs after async awaits (architectural refactor)
- [ ] `configurable_ai_brain.gd` - Direct BattleManager access bypasses context abstraction (architectural)

#### Low
- [ ] Unit/Stats/NPC: stale power comment, idle/walk duplication, placeholder pattern, untyped members, emergency sprite incomplete, defensive variant iteration
- [ ] Resources: emoji in code, validate return type overview, docstring mismatch, RefCounted placement, missing display_name validation
- [ ] AI: dead null checks, magic 9999, redundant property check, naming, unused params

### Phase 6: UI Layer (30 Medium + 24 Low)

From Opus 4.6 systematic codebase review 2026-02-06. 82 files, ~22,000 lines reviewed.
39 of 93 findings fixed (13 Critical, 26 High). 30 Medium + 24 Low remain.

### Phases 7-8: Not Yet Reviewed

- Phase 7: Sparkling Editor (~31,000 lines, ~40 files)
- Phase 8: Test Suite Audit (~31,000 lines, 86 files)

---

## Editor Code Quality (Priority: MEDIUM)

### Duplication to Consolidate
- [ ] Place on Map sections (~80 lines duplicated in npc_editor.gd, interactable_editor.gd)
- [ ] Advanced Options section duplication (npc_editor.gd, interactable_editor.gd) (~60 lines)
- [ ] Conditional cinematics section duplication (~40 lines)

---

## Deferred Features (Priority: BACKLOG)

- [ ] Dialog box auto-positioning (avoid portrait overlap)
- [ ] Mod field menu options (position parameter support)
- [ ] Spell animation system enhancements
- [ ] Additional cinematic commands
- [ ] Save slot management improvements
- [ ] Advanced AI behavior patterns

### Deferred from Missing SF Features Review (2026-01-28)

- [ ] Boss mechanics: double turns / boss danger system (needs dedicated design session)
- [ ] Item balance: charges system for rings/items instead of durability (needs dedicated design session)
- [ ] Dead zone visuals: gray highlight for min-range dead zones (minimal practical value)
- [ ] Sticky AI targeting: leashing behavior (decided against — makes AI predictable)
- [ ] Difficulty AI variants: Easy/Normal/Hard AI behavior modifiers (low priority)

### Unimplemented Settings (SettingsManager keys exist, need consumers)

- [ ] Screen shake: Connect `GameJuice.screen_shake_requested` signal to camera controller
- [ ] Flash effects: Add `SettingsManager.are_flash_effects_enabled()` checks before flash VFX
- [ ] Colorblind mode: Implement shader/color overlay system
- [ ] Font scale: Implement UI theme scaling
- [ ] Window scale on launch: Add `window_scale` to `SettingsManager._apply_all_settings()`

---

## Game Juice Enhancements (Priority: POLISH)

Visual polish opportunities identified 2026-01-28. All use pixel-safe techniques.

### Trivial Complexity (color/brightness tweens only)

#### Combat & Battle UI
- [ ] Combat forecast color coding (`combat_forecast_panel.gd`) - green=advantage, red=disadvantage
- [ ] Turn order slot flash on turn start (`turn_order_panel.gd`) - brightness 1.3->1.0

#### Level-Up & Rewards
- [ ] XP number brightness pulse (`combat_results_panel.gd`)
- [ ] Ability learned color pulse (`level_up_celebration.gd`) - cyan shimmer

#### Victory Screen
- [ ] Victory title slide-in with overshoot (`victory_screen.gd`) - TRANS_BACK easing

#### Menus
- [ ] Hover brightness boost (main_menu, save_slot_selector, shop screens) - 1.1 modulate
- [ ] Selection change brightness flash (pause_screen, field_menu) - 1.3->1.0 on cursor move

#### Exploration
- [ ] Interaction prompt intensity ramp (`interaction_prompt.gd`) - bob amplitude ramp
- [ ] NPC/interactable confirmation flash - white flash on interact

### Low Complexity (position tweens, simple particles)

#### Combat
- [ ] Defender recoil animation - 15px pushback, spring return

#### Victory & Rewards
- [ ] Gold counter animation (`victory_screen.gd`) - count up from 0
- [ ] Level-up particle burst - gold sparkles on panel appear

#### Battle Grid
- [ ] Radial highlight reveal - tiles fade in from unit outward
- [ ] Attack range red flash on confirm

#### Exploration
- [ ] NPC "notice" head turn - face toward player in 2-tile range

#### Menus
- [ ] Pause menu panel slide-in
- [ ] Inventory equip success flash

### Medium Complexity (particles, more complex choreography)

- [ ] Cursor movement trail/afterimage
- [ ] Movement dust particles
- [ ] Promotion transformation particles
- [ ] Victory confetti

### Sound Design Hooks

- [ ] `stat_increase` SFX - tick per stat reveal
- [ ] `gold_earned` SFX - coin clink loop
- [ ] `hp_drain` SFX - drain sound during HP bar tween
- [ ] `item_acquired` SFX - pickup jingle for victory rewards

---

## Reference Documents

- `docs/untracked/PHASE_STATUS.md` - High-level project status
- `docs/untracked/EDITOR_CODE_REVIEW.md` - Full editor code review findings
- `docs/specs/platform-specification.md` - Technical specification
