# Implementation Plan: Missing Shining Force Features

## Executive Summary

This plan addresses 14 missing SF features categorized by priority. The existing codebase has solid foundations - several require only targeted modifications rather than new infrastructure.

---

## Status Overview

| Feature | Priority | Complexity | Status |
|---------|----------|------------|--------|
| 2.5 XP Cap at 49 | High | - | COMPLETE |
| 2.3 Counter Flow Fix | High | Low | COMPLETE |
| 2.1 Archer vs Flyer Bonus | High | Low | COMPLETE |
| 2.2 Promotion Stat Bonuses | High | Low | COMPLETE |
| 1.1 Boss Double Turns | Critical | Low | DEFERRED (needs design session) |
| 3.3 Animation Speed Toggle | Medium | Very Low | DEFERRED (settings UI needed) |
| 3.4 Dead Zone Visuals | Medium | Low | DEFERRED (minimal practical value) |
| 3.1 Sticky AI Targeting | Medium | Low | DEFERRED (counterproductive) |
| 1.2 Reinforcement Waves | Critical | Medium | COMPLETE |
| 2.6 Ring Durability | High | Medium | DEFERRED (needs design session) |
| 3.2 Pre-Battle Deployment | Medium | Medium-High | TODO |
| 2.4 Multi-Target XP | High | Very Low | COMPLETE (verified) |
| 3.5 Battle Equipment | Medium | Very Low | COMPLETE (verified) |
| 4.1 Difficulty AI | Low | Low | DEFERRED (low priority) |

---

## Phase 1: Critical SF Identity Features

### 1.1 Boss Double Turns (AGI > 100)

**Current State:** TurnManager calculates priority but no mechanism for multiple actions per cycle.

**Implementation:**
1. Modify `TurnManager.calculate_turn_order()` - Insert high-AGI units twice
2. Add `double_turn_agi_threshold: int = 100` to ExperienceConfig

**Files:**
- `core/systems/turn_manager.gd`
- `core/resources/experience_config.gd`

**Complexity:** Low | **Impact:** High

---

### 1.2 Reinforcement Wave System

**Status:** COMPLETE

**Implementation:**
Used a single `spawn_delay: int` field on existing enemy entries in `BattleData.enemies[]`.
No new files, managers, or signals required.

- `spawn_delay: 0` (or absent) = spawns at battle start (default, backwards compatible)
- `spawn_delay: 3` = appears at start of turn 3

1. `BattleData.gd` - Added `get_initial_enemies()`, `get_reinforcements_for_turn()`,
   and `has_pending_reinforcements()` helper methods. Enemy dictionary comment updated.
2. `BattleManager._spawn_all_units()` - Filters to only spawn initial enemies (delay 0).
3. `BattleManager.spawn_reinforcements()` - Public method spawns matching enemies at turn start.
   Called by TurnManager after turn order is calculated, so reinforcements act next cycle.
4. `TurnManager.start_new_turn_cycle()` - Calls `BattleManager.spawn_reinforcements(turn_number)`
   after `calculate_turn_order()` but before `_check_battle_end()`.
5. `TurnManager._check_victory_condition()` - DEFEAT_ALL_ENEMIES also checks
   `battle_data.has_pending_reinforcements()` to prevent premature victory.

**Files:**
- `core/resources/battle_data.gd`
- `core/systems/battle_manager.gd`
- `core/systems/turn_manager.gd`

**Complexity:** Medium | **Impact:** High

---

## Phase 2: High Priority (Balance/Feel)

### 2.1 Weapon Type Bonus System (Archer vs Flyer + Extensible)

**Status:** COMPLETE

**Implementation:**
Generalized weapon bonus system supporting both movement type and unit tag multipliers.
Data-driven: modders define bonuses on ItemData, no code changes needed for new bonus types.

1. `ItemData.gd` - Added `movement_type_bonuses: Dictionary` and `unit_tag_bonuses: Dictionary`
2. `CharacterData.gd` - Added `unit_tags: Array[String]` template field
3. `UnitStats.gd` - Added runtime `unit_tags` copied from CharacterData (modifiable mid-battle)
4. `CombatCalculator.gd` - Added `_calculate_weapon_bonus_multiplier()` and `_get_movement_type_bonus()`,
   integrated into both `_calculate_physical_damage_default()` and `_calculate_physical_damage_with_terrain_default()`
5. `CombatFormulaBase.gd` - Added `calculate_weapon_bonus_multiplier()` override point for total conversions

**Files:**
- `core/resources/item_data.gd`
- `core/resources/character_data.gd`
- `core/components/unit_stats.gd`
- `core/systems/combat_calculator.gd`
- `core/systems/combat_formula_base.gd`

**Complexity:** Low | **Impact:** Medium

---

### 2.2 Promotion Stat Bonuses (Flat Bonuses at Promotion)

**Status:** COMPLETE

**Implementation:**
Flat stat bonuses applied once when a character promotes, sourced from the TARGET
ClassData's `promotion_bonus_*` fields (lines 72-82 of class_data.gd).

1. `ClassData.gd` - Has `@export` fields: `promotion_bonus_hp` (default 15),
   `promotion_bonus_mp` (10), `promotion_bonus_strength` (8), `promotion_bonus_defense` (8),
   `promotion_bonus_agility` (8), `promotion_bonus_intelligence` (8), `promotion_bonus_luck` (5)
2. `PromotionManager._calculate_promotion_bonuses()` - Reads all `promotion_bonus_*` properties
   from the target class via dynamic property access
3. `PromotionManager._apply_stat_bonuses()` - Applies bonuses directly to `unit.stats`,
   including both max and current HP/MP
4. `PromotionManager.execute_promotion()` - Calls calculate then apply, emits stat_changes
   via `promotion_completed` signal for UI feedback
5. `PromotionManager.preview_promotion()` - Also calls `_calculate_promotion_bonuses()` so
   UI can show bonuses before the player confirms

Modders customize bonuses by setting values on their promoted ClassData resources in the editor.
Zero values skip the bonus (only `bonus > 0` entries are included).

**Files:**
- `core/resources/class_data.gd` (promotion_bonus_* exports, lines 72-82)
- `core/systems/promotion_manager.gd` (_calculate_promotion_bonuses, _apply_stat_bonuses, execute_promotion)

**Complexity:** Low | **Impact:** Medium

**Note:** The original plan referenced a +25% promotion magic damage multiplier in
CombatCalculator. That is a separate concern from flat stat bonuses and would be a
new feature if desired (check `CharacterSaveData.is_promoted` in magic damage calc).

---

### 2.3 Counter Between Double Attacks (SF2-Authentic)

**Status:** COMPLETE

**Current:** Initial -> Double -> Counter
**SF2:** Initial -> Counter -> Double

**Implementation:**
Reordered `_build_combat_sequence()` in battle_manager.gd:
- Phase 1: Initial attack
- Phase 2: Counter (if defender survives)
- Phase 3: Double (if attacker survives counter)

Double attack eligibility is calculated before counter (using original state),
but the double attack phase only executes if the attacker survives the counter.

**Files:**
- `core/systems/battle_manager.gd` (lines ~1057-1132)

**Complexity:** Low | **Impact:** High

---

### 2.4 Multi-Target XP Multiplication

**Status:** COMPLETE (verified 2026-01-28)

Both player and AI spell paths already award XP per target hit:

- **Player path:** `_on_spell_cast_requested()` (line 784) loops `for spell_target: Unit in targets`
  and calls `_award_spell_xp(caster, spell_target, ability)` per target (line 818).
  Comment on line 817: "Award XP for each target hit (SF2-authentic: casters get XP per target)"
- **AI path:** `execute_ai_spell()` (line 1061) has identical loop structure calling
  `_award_spell_xp()` per target (line 1074).
- **XP backend:** `_award_spell_xp()` delegates to `ExperienceManager.award_support_xp()`,
  which applies anti-spam scaling and catch-up multipliers per call.

No changes needed.

**Files:**
- `core/systems/battle_manager.gd`
- `core/systems/experience_manager.gd`

**Complexity:** Very Low | **Impact:** Medium

---

### 2.5 XP Cap at 49 Per Action

**Status:** COMPLETE - Already in ExperienceConfig (`max_xp_per_action: int = 49`)

---

### 2.6 Ring Durability/Crack System

**Implementation:**
1. Extend ItemData:
   ```gdscript
   @export var has_durability: bool = false
   @export var crack_chance_per_use: float = 0.25
   @export var is_repairable: bool = true
   ```
2. Track item state in CharacterSaveData
3. Add crack/break checks in spell execution
4. Add repair service to shops

**Files:**
- `core/resources/item_data.gd`
- `core/resources/character_save_data.gd`
- `core/systems/battle_manager.gd`
- `core/systems/shop_manager.gd`

**Complexity:** Medium | **Impact:** Medium

**Note:** Opt-in via `has_durability: bool = false` default to preserve modder simplicity.

---

## Phase 3: Medium Priority (Polish)

### 3.1 Leashing AI Behavior (Sticky Targeting)

**Implementation:**
1. Add to AIBehaviorData:
   ```gdscript
   @export var sticky_targeting: bool = true
   @export var sticky_target_persist_turns: int = 0  # 0 = until death
   ```
2. Track locked targets in ConfigurableAIBrain

**Files:**
- `core/resources/ai_behavior_data.gd`
- `core/systems/ai/configurable_ai_brain.gd`

**Complexity:** Low | **Impact:** Medium

---

### 3.2 Pre-Battle Deployment

**Implementation:**
1. Add deployment phase to InputManager
2. Extend BattleData:
   ```gdscript
   @export var allow_deployment: bool = false
   @export var deployment_zone: Array[Vector2i] = []
   ```
3. Create deployment UI screen
4. Hook into BattleLoader

**Files:**
- `core/resources/battle_data.gd`
- `core/systems/input_manager.gd`
- `scenes/battle_loader.gd`
- **NEW:** `scenes/ui/deployment_screen.gd`
- **NEW:** `scenes/ui/deployment_screen.tscn`

**Complexity:** Medium-High | **Impact:** Medium

---

### 3.3 Animation Speed Toggle

**Current:** GameJuice has `CombatAnimationMode` enum (FULL, FAST, MAP_ONLY)

**Implementation:**
1. Add `combat_animation_speed: int` to SettingsManager
2. Sync with GameJuice mode
3. Add to settings UI

**Files:**
- `core/systems/settings_manager.gd`
- `core/systems/game_juice.gd`

**Complexity:** Very Low | **Impact:** Medium

---

### 3.4 Visual Dead Zone Indicators

**Implementation:**
Modify `GridManager.show_attack_range_band()`:
```gdscript
func show_attack_range_band(from: Vector2i, min_range: int, max_range: int) -> void:
    for r in range(1, max_range + 1):
        var cells = _get_cells_at_range(from, r)
        if r < min_range:
            highlight_cells(cells, HIGHLIGHT_GRAY)  # Dead zone
        else:
            highlight_cells(cells, HIGHLIGHT_RED)   # Valid
```

**Files:**
- `core/systems/grid_manager.gd`

**Complexity:** Low | **Impact:** Medium

---

### 3.5 Battle Equipment Changes

**Status:** COMPLETE (verified 2026-01-28)

Mid-battle equipment changes are fully implemented and SF2-authentic:

- **State:** `InputState.SELECTING_EQUIP` (line 52) is a distinct state from `SELECTING_ITEM`.
- **Equip handler:** `_handle_equip_item()` (lines 419-469) validates the item, resolves the
  equipment slot, and calls `EquipmentManager.equip_item()`.
- **Turn preservation:** On success (line 464) AND failure (line 469), state transitions to
  `InputState.SELECTING_ACTION` -- not `EXECUTING`. Comment on line 463:
  "SF2 AUTHENTIC: Return to action menu - equipping doesn't end turn!"
- **Cancel path:** `_on_item_menu_cancelled()` (line 488) also returns to `SELECTING_ACTION`.
- **Stat refresh:** `unit.stats.recalculate_derived_stats()` is called after equip (line 461).

No changes needed.

**Files:**
- `core/systems/input_manager.gd`

**Complexity:** Very Low | **Impact:** Low

---

## Phase 4: Low Priority

### 4.1 Difficulty-Based AI Variants

**Implementation:**
1. Add `ai_difficulty: int` to SettingsManager (0=Easy, 1=Normal, 2=Hard)
2. Modify ConfigurableAIBrain to apply difficulty modifiers

**Files:**
- `core/systems/settings_manager.gd`
- `core/systems/ai/configurable_ai_brain.gd`

**Complexity:** Low | **Impact:** Low

---

## Recommended Implementation Order

1. **2.3 Counter Flow Fix** - Tiny change, high SF-feel impact
2. **2.1 Archer vs Flyer** - Small change, good tactical depth
3. **2.2 Promotion Stat Bonuses** - COMPLETE (already wired in PromotionManager)
4. **1.1 Boss Double Turns** - Medium change, essential for bosses
5. **3.3 Animation Speed** - Small change, infrastructure exists
6. **3.4 Dead Zone Visual** - Small change, clarity improvement
7. **3.1 Sticky Targeting** - Small change, AI authenticity
8. **1.2 Reinforcement System** - Medium change, enables key scenarios
9. **2.6 Ring Durability** - Medium change, optional SF feature
10. **3.2 Pre-Battle Deployment** - Large change, optional QoL

---

## TSF Philosophy Notes

All features should be **OFF by default** or gracefully degrade:
- Ring durability: `has_durability: bool = false`
- Pre-battle deployment: `allow_deployment: bool = false`
- Reinforcements: Empty array = no reinforcements

Existing battles work unchanged.

---

## Key Files Reference

| File | Features |
|------|----------|
| `core/systems/battle_manager.gd` | Counter flow, damage bonuses, reinforcements |
| `core/systems/turn_manager.gd` | Double turns, reinforcement triggers |
| `core/systems/combat_calculator.gd` | Type bonuses, promotion bonuses |
| `core/systems/grid_manager.gd` | Dead zone highlighting |
| `core/resources/battle_data.gd` | Reinforcement waves, deployment zones |
| `core/resources/experience_config.gd` | Thresholds and multipliers |
