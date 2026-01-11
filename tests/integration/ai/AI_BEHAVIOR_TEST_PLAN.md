# AI Behavior Integration Test Plan

## Overview

These tests verify that AI units behave according to their role's intent, not just that configuration loads correctly. Each test creates a controlled scenario and validates the behavioral outcome.

All tests follow the pattern established by `test_ranged_ai_positioning.tscn`.

---

## Test 1: Healer Prioritization (Dark Priest Problem) ✅ IMPLEMENTED

**File:** `test_healer_prioritization.gd`

**Scenario:**
- Healer unit (support role, smart_healer behavior) at position (5, 5)
- Wounded ally at (6, 5) with 30% HP
- Enemy at (7, 5) within attack range

**Expected Behavior:**
- Healer should cast heal on wounded ally
- Healer should NOT attack the enemy

**Success Criteria:**
- Healing spell was cast (track via signal or MP consumption)
- Ally HP increased
- No combat_resolved signal with healer as attacker

**Why This Matters:**
A healer that attacks instead of healing is the "Dark Priest Problem" - technically valid config but wrong behavior.

---

## Test 2: Retreat Behavior ✅ IMPLEMENTED

**File:** `test_retreat_behavior.gd`

**Scenario:**
- Enemy unit with retreat enabled (opportunistic_archer, retreat_hp_threshold: 60%)
- Unit starts at 50% HP (below threshold)
- Player unit nearby threatening

**Expected Behavior:**
- Enemy should move AWAY from player unit
- Enemy should NOT move toward or attack

**Success Criteria:**
- Final distance to player > initial distance
- No combat_resolved signal

**Why This Matters:**
Retreat behavior creates tactical depth - wounded enemies fleeing to regroup.

---

## Test 3: Opportunistic Target Selection (Wounded Priority) ✅ IMPLEMENTED

**File:** `test_opportunistic_targeting.gd`

**Scenario:**
- Opportunistic attacker at (2, 5)
- Full HP enemy at (4, 5) - distance 2, adjacent
- Wounded enemy (20% HP) at (6, 5) - distance 4, still in range

**Expected Behavior:**
- Attacker should move toward and attack the WOUNDED target
- Should ignore the closer full-HP target

**Success Criteria:**
- Combat occurred with wounded target as defender
- NOT with full-HP target

**Why This Matters:**
Opportunistic units should "finish off" weak enemies, not just attack the nearest.

---

## Test 4: Defensive Tank Positioning ✅ IMPLEMENTED

**File:** `test_defensive_positioning.gd`

**Scenario:**
- Tank unit (defensive role) at (2, 5)
- VIP ally (healer or low-HP unit) at (5, 5)
- Enemy threat at (8, 5) approaching VIP

**Expected Behavior:**
- Tank should move to intercept position BETWEEN VIP and threat
- Should position closer to VIP than to enemy

**Success Criteria:**
- Tank final position is between VIP and threat (on the line or closer to VIP)
- Tank is closer to VIP than enemy is to VIP

**Why This Matters:**
Defensive units should actively protect valuable allies, not just attack.

---

## Test 5: Cautious Engagement Range ✅ IMPLEMENTED

**File:** `test_cautious_engagement.gd`

**Scenario A (Outside Alert Range):**
- Cautious unit at (2, 5) with alert_range: 6, engagement_range: 3
- Player at (10, 5) - distance 8 (outside alert range)

**Expected Behavior A:**
- Unit should NOT move at all

**Scenario B (Inside Alert, Outside Engagement):**
- Same unit, player at (6, 5) - distance 4 (inside alert, outside engagement)

**Expected Behavior B:**
- Unit should move toward player
- Unit should NOT attack (not committed to engagement yet)

**Scenario C (Inside Engagement):**
- Same unit, player at (4, 5) - distance 2 (inside engagement)

**Expected Behavior C:**
- Unit should attack

**Success Criteria:**
- Scenario A: No movement
- Scenario B: Movement occurred, no combat
- Scenario C: Combat occurred

**Why This Matters:**
Cautious mode creates guard-like behavior - units that don't chase forever.

---

## Test 6: Stationary Guard Behavior ✅ IMPLEMENTED

**File:** `test_stationary_guard.gd`

**Scenario:**
- Guard unit with engagement_range: 1 (stationary_guard behavior)
- Player approaches from distance 5 to distance 1

**Expected Behavior:**
- Guard should NOT move regardless of player distance
- Guard should ONLY attack when player is adjacent (distance 1)

**Success Criteria:**
- Guard position unchanged after AI turn
- Combat only occurs at distance 1

**Why This Matters:**
Stationary guards should hold position - important for map design and puzzle encounters.

---

## Test 7: Tactical Debuff Usage ✅ IMPLEMENTED

**File:** `test_tactical_debuff.gd`

**Scenario:**
- Tactical mage (tactical role) with debuff ability
- High-threat target (damage dealer) in range
- Debuff not yet applied to target

**Expected Behavior:**
- Mage should cast debuff on high-threat target before attacking

**Success Criteria:**
- Spell was cast (MP consumed)
- Target received status effect OR spell animation played

**Why This Matters:**
Tactical units should use debuffs strategically, not just spam attacks.

---

## Test 8: AoE Minimum Targets ✅ IMPLEMENTED

**File:** `test_aoe_targeting.gd`

**Scenario:**
- Unit with AoE ability, aoe_minimum_targets: 2
- Single isolated target
- Group of 3 clustered targets

**Expected Behavior:**
- Should prefer targeting the cluster
- Should NOT waste AoE on single target

**Success Criteria:**
- AoE center is within range of 2+ targets
- OR falls back to single-target attack if AoE requirements not met

**Why This Matters:**
Smart AoE usage is a key tactical differentiator for mage-type enemies.

---

## Implementation Order

1. ✅ Ranged Positioning (DONE)
2. ✅ Healer Prioritization (DONE)
3. ✅ Retreat Behavior (DONE)
4. ✅ Opportunistic Targeting (DONE)
5. ✅ Cautious Engagement (DONE)
6. ✅ Defensive Positioning (DONE)
7. ✅ Stationary Guard (DONE)
8. ✅ Tactical Debuff (DONE)
9. ✅ AoE Targeting (DONE)

---

## Test Infrastructure Notes

Each test should:
- Be a standalone .tscn scene
- Set up minimal grid and units
- Run AI turn programmatically
- Validate outcome and print clear PASSED/FAILED
- Exit with code 0 (pass) or 1 (fail)
- Be added to test_headless.sh

Common setup can be extracted to a shared test helper if patterns emerge.
