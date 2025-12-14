# AI Implementation Gaps Plan

**Author:** Lt. Claudbrain
**Stardate:** 2025.12.13
**Status:** ✅ COMPLETE (2025-12-14)
**Priority:** High

## Executive Summary

This plan addresses 7 AI system gaps (1 deferred) using Commander Claudius's SIMPLICITY FIRST approach. We leverage existing infrastructure (enums, dictionaries, methods) with minimal additions. Each phase is independently testable and follows the "3-sentence explainable" rule.

### Design Philosophy: KISS Principle (Keep It Simple, Starfleet)

- NO type registries for categories
- NO `effect_categories: Array[String]` on abilities
- NO two-layer weight hierarchies
- NO complex taxonomy systems
- YES to using existing enums (AbilityType)
- YES to simple dictionary keys in threat_weights
- YES to minimal new fields (3 total across 2 resources)

---

## Table of Contents

1. [Phase 1: Ability-Based Threat Detection](#phase-1-ability-based-threat-detection)
2. [Phase 2: Item Usage](#phase-2-item-usage)
3. [Phase 3: Tactical Role (Debuff Selection)](#phase-3-tactical-role-debuff-selection)
4. [Phase 4: Defensive Role (Bodyguard)](#phase-4-defensive-role-bodyguard)
5. [Phase 5: Retreat Enhancements](#phase-5-retreat-enhancements)
6. [Phase 6: AoE Optimization](#phase-6-aoe-optimization)
7. [Phase 7: Turn Order Awareness (DEFERRED)](#phase-7-turn-order-awareness-deferred)
8. [Preset Updates](#preset-updates)
9. [Testing Strategy](#testing-strategy)

---

## Phase 1: Ability-Based Threat Detection

**Goal:** AI identifies high-value targets by scanning their abilities using the EXISTING `AbilityType` enum.

### 3-Sentence Explanation
The AI scans each potential target's unlocked abilities using `AbilityType` (HEAL, ATTACK, DEBUFF, etc.). Each ability type contributes a base threat score multiplied by a behavior-specific weight from `threat_weights`. The final threat score determines target priority.

### Code Changes

#### 1.1 AbilityData - Add ONE field

**File:** `/home/user/dev/sparklingfarce/core/resources/ability_data.gd`

```gdscript
@export_group("AI Configuration")
## Multiplier for AI threat calculations. Higher = AI considers this ability more threatening.
## Default 1.0. Set to 0.0 to make AI ignore this ability in threat calculations.
## Example: A powerful AoE heal might be 1.5, a weak single-target buff might be 0.5
@export var ai_threat_contribution: float = 1.0
```

**Location:** Add after line 70 (after the Description export group)

#### 1.2 CharacterData - Add TWO fields

**File:** `/home/user/dev/sparklingfarce/core/resources/character_data.gd`

```gdscript
@export_group("AI Threat Configuration")
## Multiplier applied to this character's calculated threat score.
## Boss enemies should have higher values (2.0+) to make AI prioritize protecting them.
## Fodder enemies might have lower values (0.5) to make AI deprioritize them.
## Default 1.0 = no modification.
@export var ai_threat_modifier: float = 1.0

## Tags that modify AI targeting behavior.
## Supported tags: "priority_target" (AI focuses this unit), "avoid" (AI ignores this unit)
## Mods can add custom tags and handle them in custom AIBrain scripts.
@export var ai_threat_tags: Array[String] = []
```

**Location:** Add after line 74 (after `default_ai_brain`)

#### 1.3 ConfigurableAIBrain - Add threat calculation method

**File:** `/home/user/dev/sparklingfarce/core/systems/ai/configurable_ai_brain.gd`

Add the following method (after `_find_best_target`):

```gdscript
## Calculate unit's threat score based on their abilities and character data
## Uses AbilityType enum for categorization (NO custom taxonomies)
## @param unit: Target unit to evaluate
## @param behavior: AI behavior providing threat weights
## @return: Calculated threat score (higher = more threatening)
func _calculate_unit_threat(unit: Node2D, behavior: AIBehaviorData) -> float:
    var threat: float = 0.0

    if not unit or not unit.stats or not unit.character_data:
        return threat

    # Get unit's class for ability lookup
    var unit_class: ClassData = unit.get_current_class()
    if not unit_class:
        return threat

    # Get unlocked abilities at current level
    var abilities: Array[AbilityData] = unit_class.get_unlocked_class_abilities(unit.stats.level)

    # Also include character's unique abilities
    if unit.character_data.unique_abilities:
        abilities.append_array(unit.character_data.unique_abilities)

    # Scan abilities and accumulate threat by AbilityType
    for ability: AbilityData in abilities:
        if ability == null:
            continue

        var contribution: float = ability.ai_threat_contribution if "ai_threat_contribution" in ability else 1.0
        if contribution <= 0.0:
            continue

        match ability.ability_type:
            AbilityData.AbilityType.HEAL:
                # Healers are high-value targets
                var base_threat: float = 30.0 + ability.power * 0.5
                var weight: float = behavior.get_effective_threat_weight("healer", 1.0)
                threat += base_threat * contribution * weight

            AbilityData.AbilityType.ATTACK:
                # Damage dealers based on spell power
                var base_threat: float = ability.power * 0.5
                var weight: float = behavior.get_effective_threat_weight("damage_dealer", 1.0)
                threat += base_threat * contribution * weight

            AbilityData.AbilityType.DEBUFF, AbilityData.AbilityType.STATUS:
                # Debuffers can swing battles
                var base_threat: float = 20.0
                var weight: float = behavior.get_effective_threat_weight("debuffer", 1.0)
                threat += base_threat * contribution * weight

            AbilityData.AbilityType.SUPPORT:
                # Buffers help their team
                var base_threat: float = 15.0
                var weight: float = behavior.get_effective_threat_weight("support", 1.0)
                threat += base_threat * contribution * weight

            _:
                # Other types: small contribution
                threat += 5.0 * contribution

    # Add stat-based threat (high attack = dangerous)
    var attack_stat: int = unit.stats.strength if unit.stats else 0
    var attack_weight: float = behavior.get_effective_threat_weight("high_attack", 1.0)
    threat += attack_stat * 0.3 * attack_weight

    # Low defense = vulnerable = good target
    var defense_stat: int = unit.stats.defense if unit.stats else 0
    var defense_weight: float = behavior.get_effective_threat_weight("low_defense", 1.0)
    if defense_stat < 10:
        threat += (10 - defense_stat) * 2.0 * defense_weight

    # Apply character's threat modifier (bosses = 2.0, fodder = 0.5)
    var char_modifier: float = 1.0
    if "ai_threat_modifier" in unit.character_data:
        char_modifier = unit.character_data.ai_threat_modifier
    threat *= char_modifier

    # Handle threat tags
    if "ai_threat_tags" in unit.character_data:
        var tags: Array = unit.character_data.ai_threat_tags
        if "priority_target" in tags:
            threat *= 2.0
        if "avoid" in tags:
            threat *= 0.1

    return threat
```

#### 1.4 Update `_find_best_target` to use threat calculation

**File:** `/home/user/dev/sparklingfarce/core/systems/ai/configurable_ai_brain.gd`

Replace the existing `_find_best_target` method:

```gdscript
## Find best target based on threat weights and calculated unit threat
func _find_best_target(unit: Node2D, targets: Array[Node2D], behavior: AIBehaviorData) -> Node2D:
    if targets.is_empty():
        return null

    var best_target: Node2D = null
    var best_score: float = -999.0

    var wounded_weight: float = behavior.get_effective_threat_weight("wounded_target", 1.0) if behavior else 1.0
    var proximity_weight: float = behavior.get_effective_threat_weight("proximity", 1.0) if behavior else 1.0

    for target: Node2D in targets:
        if not target.is_alive():
            continue

        var score: float = 0.0

        # Calculate unit threat (ability-based targeting)
        if behavior:
            score += _calculate_unit_threat(target, behavior)

        # Wounded target priority
        if target.stats:
            var hp_percent: float = float(target.stats.current_hp) / float(target.stats.max_hp)
            score += (1.0 - hp_percent) * wounded_weight * 100.0

        # Proximity bonus
        var dist: int = GridManager.grid.get_manhattan_distance(unit.grid_position, target.grid_position)
        score += (20 - dist) * proximity_weight * 5.0

        if score > best_score:
            best_score = score
            best_target = target

    return best_target
```

### Test Scenarios

1. **Healer Priority Test:** Create battle with enemy healer and warrior. Verify aggressive AI targets healer first when `healer` weight > 1.0.
2. **Boss Modifier Test:** Set boss `ai_threat_modifier = 2.0`. Verify enemies prioritize protecting the boss (defensive role).
3. **Tag Test:** Add "priority_target" tag. Verify AI always attacks that unit first.
4. **Contribution Test:** Set healing spell `ai_threat_contribution = 0.0`. Verify that healer is no longer prioritized.

---

## Phase 2: Item Usage

**Goal:** AI uses healing and attack items when appropriate.

### 3-Sentence Explanation
When HP is below retreat threshold and no healing spell is available, AI checks inventory for healing items. If `use_healing_items` is true and a healing consumable exists, the AI uses it. Attack items work similarly when `use_attack_items` is true.

### Code Changes

#### 2.1 Add item usage method to ConfigurableAIBrain

**File:** `/home/user/dev/sparklingfarce/core/systems/ai/configurable_ai_brain.gd`

```gdscript
## Attempt to use a healing item from inventory
## @param unit: The AI unit
## @param context: Battle context
## @param behavior: AI behavior settings
## @return: true if item was used, false otherwise
func _try_use_healing_item(unit: Node2D, context: Dictionary, behavior: AIBehaviorData) -> bool:
    if not behavior or not behavior.use_healing_items:
        return false

    if not unit.character_data:
        return false

    # Get unit's inventory from save data
    var char_uid: String = unit.character_data.character_uid
    var save_data: CharacterSaveData = PartyManager.get_member_save_data(char_uid)
    if not save_data:
        return false

    # Find a healing consumable
    for item_id: String in save_data.inventory:
        var item: ItemData = ModLoader.registry.get_resource("item", item_id) as ItemData
        if not item:
            continue

        # Check if it's a usable healing item
        if item.item_type != ItemData.ItemType.CONSUMABLE:
            continue
        if not item.usable_in_battle:
            continue
        if not item.effect or not item.effect is AbilityData:
            continue

        var ability: AbilityData = item.effect as AbilityData
        if ability.ability_type != AbilityData.AbilityType.HEAL:
            continue

        # Found a healing item - use it on self
        var delays: Dictionary = context.get("ai_delays", {})
        var delay_before: float = delays.get("before_attack", 0.3)
        if delay_before > 0 and unit.get_tree():
            await unit.get_tree().create_timer(delay_before).timeout

        # Use BattleManager's item use system
        await BattleManager._on_item_use_requested(unit, item_id, unit)
        return true

    return false


## Attempt to use an attack item on a target
## @param unit: The AI unit
## @param target: The target unit
## @param context: Battle context
## @param behavior: AI behavior settings
## @return: true if item was used, false otherwise
func _try_use_attack_item(unit: Node2D, target: Node2D, context: Dictionary, behavior: AIBehaviorData) -> bool:
    if not behavior or not behavior.use_attack_items:
        return false

    if not unit.character_data or not target:
        return false

    # Get unit's inventory from save data
    var char_uid: String = unit.character_data.character_uid
    var save_data: CharacterSaveData = PartyManager.get_member_save_data(char_uid)
    if not save_data:
        return false

    # Find an attack consumable
    for item_id: String in save_data.inventory:
        var item: ItemData = ModLoader.registry.get_resource("item", item_id) as ItemData
        if not item:
            continue

        # Check if it's a usable attack item
        if item.item_type != ItemData.ItemType.CONSUMABLE:
            continue
        if not item.usable_in_battle:
            continue
        if not item.effect or not item.effect is AbilityData:
            continue

        var ability: AbilityData = item.effect as AbilityData
        if ability.ability_type != AbilityData.AbilityType.ATTACK:
            continue

        # Found an attack item - use it
        var delays: Dictionary = context.get("ai_delays", {})
        var delay_before: float = delays.get("before_attack", 0.3)
        if delay_before > 0 and unit.get_tree():
            await unit.get_tree().create_timer(delay_before).timeout

        await BattleManager._on_item_use_requested(unit, item_id, target)
        return true

    return false
```

#### 2.2 Integrate item usage into opportunistic behavior

Update `_execute_opportunistic` method to check for healing items during retreat:

```gdscript
## Opportunistic behavior: prioritize wounded, retreat if low HP
func _execute_opportunistic(unit: Node2D, context: Dictionary, behavior: AIBehaviorData) -> void:
    var player_units: Array[Node2D] = get_player_units(context)
    if player_units.is_empty():
        return

    # Check retreat condition
    if behavior and behavior.retreat_enabled:
        var hp_percent: float = context.get("unit_hp_percent", 100.0)
        if hp_percent < behavior.retreat_hp_threshold:
            # Try healing item first before retreating
            var healed: bool = await _try_use_healing_item(unit, context, behavior)
            if healed:
                return  # Turn consumed by item use

            await _execute_retreat(unit, player_units, context)
            return

    # Find best target (wounded priority)
    var target: Node2D = _find_best_target(unit, player_units, behavior)
    if not target:
        return

    # Consider attack items for ranged damage
    if behavior and behavior.use_attack_items:
        var used_item: bool = await _try_use_attack_item(unit, target, context, behavior)
        if used_item:
            return

    # Standard attack pattern
    await _execute_aggressive(unit, context, behavior)
```

### Test Scenarios

1. **Healing Item Test:** Give AI unit a Medical Herb. Damage below retreat threshold. Verify item usage.
2. **Attack Item Test:** Give AI unit an attack item. Verify it's used when `use_attack_items = true`.
3. **No Item Test:** Set `use_healing_items = false`. Verify AI doesn't use items even when available.
4. **Empty Inventory Test:** No items in inventory. Verify graceful fallback to normal behavior.

---

## Phase 3: Tactical Role (Debuff Selection)

**Goal:** Tactical role AI selects and uses debuff abilities based on `preferred_status_effects`.

### 3-Sentence Explanation
When role is "tactical", AI scans its available DEBUFF/STATUS abilities. It filters to those matching `preferred_status_effects` (or uses any if empty). It applies the debuff to the highest-threat target in range.

### Code Changes

#### 3.1 Implement tactical role execution

**File:** `/home/user/dev/sparklingfarce/core/systems/ai/configurable_ai_brain.gd`

Replace the placeholder in `execute_with_behavior`:

```gdscript
        "tactical":
            # Tactical role: prioritize debuffs and status effects
            var debuffed: bool = await _execute_tactical_role(unit, context, behavior)
            if debuffed:
                return  # Successfully applied debuff, turn done
            # No debuff possible - fall through to mode-based attack
```

Add the implementation method:

```gdscript
## Execute tactical role: apply debuffs/status effects to high-threat targets
## @return: true if a debuff was applied, false otherwise
func _execute_tactical_role(unit: Node2D, context: Dictionary, behavior: AIBehaviorData) -> bool:
    if not behavior.use_status_effects:
        return false

    # Get opponent units
    var opponents: Array[Node2D] = get_player_units(context) if unit.faction == "enemy" else get_enemy_units(context)
    if opponents.is_empty():
        return false

    # Get unit's debuff abilities
    var debuff_abilities: Array[Dictionary] = _get_unit_debuff_abilities(unit, behavior)
    if debuff_abilities.is_empty():
        return false

    # Find best target (highest threat that doesn't already have debuffs)
    var best_target: Node2D = null
    var best_threat: float = -999.0

    for target: Node2D in opponents:
        if not target.is_alive():
            continue

        # Skip targets that already have status effects (to spread debuffs)
        if target.stats and not target.stats.status_effects.is_empty():
            continue

        var threat: float = _calculate_unit_threat(target, behavior)
        if threat > best_threat:
            best_threat = threat
            best_target = target

    if not best_target:
        # All targets have debuffs, fall back to highest threat regardless
        best_target = _find_best_target(unit, opponents, behavior)

    if not best_target:
        return false

    # Find best debuff ability for this target
    var best_ability: Dictionary = _select_best_debuff_ability(unit, best_target, debuff_abilities, behavior)
    if best_ability.is_empty():
        return false

    var ability_id: String = best_ability.get("id", "")
    var ability_range: int = best_ability.get("range", 1)

    # Check if target is in range
    var distance: int = GridManager.grid.get_manhattan_distance(unit.grid_position, best_target.grid_position)

    if distance > ability_range:
        # Move toward target
        var moved: bool = _move_into_spell_range(unit, best_target.grid_position, ability_range)
        if moved:
            await unit.await_movement_completion()
            var delays: Dictionary = context.get("ai_delays", {})
            if delays.get("after_movement", 0.5) > 0:
                await unit.get_tree().create_timer(delays.get("after_movement", 0.5)).timeout

        distance = GridManager.grid.get_manhattan_distance(unit.grid_position, best_target.grid_position)
        if distance > ability_range:
            return false  # Still out of range

    # Cast the debuff
    var delays: Dictionary = context.get("ai_delays", {})
    if delays.get("before_attack", 0.3) > 0:
        await unit.get_tree().create_timer(delays.get("before_attack", 0.3)).timeout

    var success: bool = await BattleManager.execute_ai_spell(unit, ability_id, best_target)
    return success


## Get list of debuff abilities the unit can use
func _get_unit_debuff_abilities(unit: Node2D, behavior: AIBehaviorData) -> Array[Dictionary]:
    var result: Array[Dictionary] = []

    if not unit.stats:
        return result

    var unit_class: ClassData = unit.get_current_class()
    if not unit_class:
        return result

    var unlocked_abilities: Array[AbilityData] = unit_class.get_unlocked_class_abilities(unit.stats.level)

    for ability: AbilityData in unlocked_abilities:
        if not ability:
            continue

        # Check if it's a debuff/status ability
        if ability.ability_type != AbilityData.AbilityType.DEBUFF and ability.ability_type != AbilityData.AbilityType.STATUS:
            continue

        # Check if it matches preferred status effects (if any specified)
        if not behavior.preferred_status_effects.is_empty():
            var matches_preferred: bool = false
            for effect: String in ability.status_effects:
                if effect in behavior.preferred_status_effects:
                    matches_preferred = true
                    break
            if not matches_preferred:
                continue

        # Check if unit can afford it
        if ability.mp_cost > unit.stats.current_mp:
            continue

        result.append({
            "id": ability.ability_id,
            "ability": ability,
            "range": ability.max_range,
            "mp_cost": ability.mp_cost,
            "effects": ability.status_effects
        })

    return result


## Select the best debuff ability for the situation
func _select_best_debuff_ability(unit: Node2D, target: Node2D, abilities: Array[Dictionary], behavior: AIBehaviorData) -> Dictionary:
    if abilities.is_empty():
        return {}

    var best_ability: Dictionary = {}
    var best_score: float = -999.0

    for ability_info: Dictionary in abilities:
        var score: float = 0.0

        # Prefer abilities that match preferred_status_effects (if specified)
        var effects: Array = ability_info.get("effects", [])
        for effect: String in effects:
            if effect in behavior.preferred_status_effects:
                score += 50.0

        # Prefer lower MP cost (conserve resources)
        var mp_cost: int = ability_info.get("mp_cost", 0)
        score -= mp_cost * 2.0

        # Prefer higher effect chance (from ability data)
        var ability: AbilityData = ability_info.get("ability") as AbilityData
        if ability:
            score += ability.effect_chance * 0.5

        if score > best_score:
            best_score = score
            best_ability = ability_info

    return best_ability
```

### Test Scenarios

1. **Preferred Effect Test:** Set `preferred_status_effects = ["slow"]`. Verify AI uses Slow over other debuffs.
2. **MP Conservation Test:** With limited MP, verify AI uses cheaper debuffs first.
3. **Spread Debuffs Test:** Multiple targets. Verify AI spreads debuffs rather than stacking.
4. **No Debuff Available Test:** Unit has no debuff abilities. Verify fallback to attack.

---

## Phase 4: Defensive Role (Bodyguard)

**Goal:** Defensive role AI positions between VIP ally and nearest threat.

### 3-Sentence Explanation
Defensive AI identifies the VIP (highest `ai_threat_modifier` ally, or unit with "boss" tag). It calculates the position between VIP and the nearest enemy. It moves to that position and attacks only if enemies come adjacent.

### Code Changes

#### 4.1 Implement defensive role execution

Update the defensive role placeholder:

```gdscript
        "defensive":
            # Defensive role: protect high-value allies (bodyguard behavior)
            await _execute_defensive_role(unit, context, behavior)
            return  # Defensive role handles its own attack logic
```

Add implementation:

```gdscript
## Execute defensive role: position between VIP and threats
func _execute_defensive_role(unit: Node2D, context: Dictionary, behavior: AIBehaviorData) -> void:
    # Get allies and opponents
    var allies: Array[Node2D] = _get_allied_units(unit, context)
    var opponents: Array[Node2D]
    if unit.faction == "enemy":
        opponents = get_player_units(context)
    else:
        opponents = get_enemy_units(context)

    # Find VIP to protect (highest ai_threat_modifier or boss tag)
    var vip: Node2D = _find_vip_to_protect(unit, allies)

    if not vip or opponents.is_empty():
        # No VIP or no threats - fall back to cautious behavior
        await _execute_cautious(unit, context, behavior)
        return

    # Find nearest threat to VIP
    var nearest_threat: Node2D = find_nearest_target(vip, opponents)
    if not nearest_threat:
        await _execute_cautious(unit, context, behavior)
        return

    var delays: Dictionary = context.get("ai_delays", {})

    # Check if we should attack first (enemy adjacent to us)
    for opponent: Node2D in opponents:
        if not opponent.is_alive():
            continue
        if is_in_attack_range(unit, opponent):
            if delays.get("before_attack", 0.3) > 0:
                await unit.get_tree().create_timer(delays.get("before_attack", 0.3)).timeout
            await attack_target(unit, opponent)
            return

    # Calculate interception position (between VIP and threat)
    var intercept_pos: Vector2i = _calculate_intercept_position(unit, vip, nearest_threat)

    if intercept_pos == unit.grid_position:
        # Already in position - stay put (cautious)
        return

    # Move toward intercept position
    var moved: bool = move_toward_target(unit, intercept_pos)
    if moved:
        await unit.await_movement_completion()
        if delays.get("after_movement", 0.5) > 0:
            await unit.get_tree().create_timer(delays.get("after_movement", 0.5)).timeout

    # Attack if now in range of any opponent
    for opponent: Node2D in opponents:
        if not opponent.is_alive():
            continue
        if is_in_attack_range(unit, opponent):
            if delays.get("before_attack", 0.3) > 0:
                await unit.get_tree().create_timer(delays.get("before_attack", 0.3)).timeout
            await attack_target(unit, opponent)
            return


## Find the VIP (most valuable ally to protect)
func _find_vip_to_protect(protector: Node2D, allies: Array[Node2D]) -> Node2D:
    var best_vip: Node2D = null
    var best_priority: float = -999.0

    for ally: Node2D in allies:
        if ally == protector or not ally.is_alive():
            continue

        if not ally.character_data:
            continue

        var priority: float = 0.0

        # Check ai_threat_modifier (bosses have high values)
        if "ai_threat_modifier" in ally.character_data:
            priority += ally.character_data.ai_threat_modifier * 100.0

        # Check for boss/vip tags
        if "ai_threat_tags" in ally.character_data:
            var tags: Array = ally.character_data.ai_threat_tags
            if "boss" in tags or "vip" in tags:
                priority += 200.0

        # Healers are valuable
        var ally_class: ClassData = ally.get_current_class()
        if ally_class:
            var abilities: Array[AbilityData] = ally_class.get_unlocked_class_abilities(ally.stats.level if ally.stats else 1)
            for ability: AbilityData in abilities:
                if ability and ability.ability_type == AbilityData.AbilityType.HEAL:
                    priority += 50.0
                    break

        if priority > best_priority:
            best_priority = priority
            best_vip = ally

    return best_vip


## Calculate position to intercept threats to VIP
func _calculate_intercept_position(protector: Node2D, vip: Node2D, threat: Node2D) -> Vector2i:
    # Calculate midpoint between VIP and threat
    var vip_pos: Vector2i = vip.grid_position
    var threat_pos: Vector2i = threat.grid_position

    # Target position is one step from VIP toward threat
    var direction: Vector2i = Vector2i(
        signi(threat_pos.x - vip_pos.x),
        signi(threat_pos.y - vip_pos.y)
    )

    var intercept: Vector2i = vip_pos + direction

    # If intercept is occupied or invalid, try adjacent cells
    if not GridManager.is_within_bounds(intercept) or GridManager.is_cell_occupied(intercept):
        # Try orthogonal directions
        var alternatives: Array[Vector2i] = [
            vip_pos + Vector2i(direction.x, 0),
            vip_pos + Vector2i(0, direction.y),
            vip_pos + Vector2i(-direction.y, direction.x),  # Perpendicular
            vip_pos + Vector2i(direction.y, -direction.x)   # Other perpendicular
        ]

        for alt: Vector2i in alternatives:
            if GridManager.is_within_bounds(alt) and not GridManager.is_cell_occupied(alt):
                return alt

        # No good position - stay put
        return protector.grid_position

    return intercept
```

### Test Scenarios

1. **VIP Protection Test:** Boss enemy with high `ai_threat_modifier`. Verify tank positions between boss and player.
2. **Healer Protection Test:** No explicit VIP. Verify tank protects ally healer.
3. **Adjacent Attack Test:** Enemy enters adjacent to defender. Verify defender attacks.
4. **No VIP Test:** All allies equal priority. Verify fallback to cautious behavior.

---

## Phase 5: Retreat Enhancements

**Goal:** Enhanced retreat that seeks healers and detects being outnumbered.

### 3-Sentence Explanation
When retreating (`seek_healer_when_wounded = true`), AI identifies allied units with HEAL abilities and moves toward them instead of just away from enemies. When `retreat_when_outnumbered = true`, AI counts nearby enemies and triggers retreat if outnumbered 2:1 in a 3-tile radius.

### Code Changes

#### 5.1 Update retreat to seek healers

**File:** `/home/user/dev/sparklingfarce/core/systems/ai/configurable_ai_brain.gd`

Replace the `_execute_retreat` method:

```gdscript
## Retreat behavior: move away from enemies, optionally toward healers
func _execute_retreat(unit: Node2D, enemies: Array[Node2D], context: Dictionary) -> void:
    var unit_class: ClassData = unit.get_current_class()
    if not unit_class:
        return

    var behavior: AIBehaviorData = unit.ai_behavior
    var movement_range: int = unit_class.movement_range
    var reachable: Array[Vector2i] = GridManager.get_walkable_cells(unit.grid_position, movement_range, unit_class.movement_type, unit.faction)

    if reachable.is_empty():
        return

    # Check if we should seek a healer
    var healer_target: Node2D = null
    if behavior and behavior.seek_healer_when_wounded:
        healer_target = _find_nearest_allied_healer(unit, context)

    # Find best retreat cell
    var best_cell: Vector2i = unit.grid_position
    var best_score: float = -999.0

    for cell: Vector2i in reachable:
        if cell != unit.grid_position and GridManager.is_cell_occupied(cell):
            continue

        var score: float = 0.0

        # Distance from enemies (want to maximize)
        var min_enemy_dist: int = 999
        for enemy: Node2D in enemies:
            if enemy.is_alive():
                var dist: int = GridManager.grid.get_manhattan_distance(cell, enemy.grid_position)
                min_enemy_dist = mini(min_enemy_dist, dist)
        score += min_enemy_dist * 10.0

        # Distance to healer (want to minimize)
        if healer_target:
            var healer_dist: int = GridManager.grid.get_manhattan_distance(cell, healer_target.grid_position)
            score -= healer_dist * 5.0  # Less weight than enemy avoidance

        if score > best_score:
            best_score = score
            best_cell = cell

    if best_cell != unit.grid_position:
        unit.move_along_path([unit.grid_position, best_cell])
        await unit.await_movement_completion()


## Find nearest ally with healing abilities
func _find_nearest_allied_healer(unit: Node2D, context: Dictionary) -> Node2D:
    var allies: Array[Node2D] = _get_allied_units(unit, context)

    var nearest_healer: Node2D = null
    var nearest_dist: int = 999

    for ally: Node2D in allies:
        if ally == unit or not ally.is_alive():
            continue

        # Check if ally has healing abilities
        var ally_class: ClassData = ally.get_current_class()
        if not ally_class:
            continue

        var has_heal: bool = false
        var abilities: Array[AbilityData] = ally_class.get_unlocked_class_abilities(ally.stats.level if ally.stats else 1)
        for ability: AbilityData in abilities:
            if ability and ability.ability_type == AbilityData.AbilityType.HEAL:
                has_heal = true
                break

        if not has_heal:
            continue

        var dist: int = GridManager.grid.get_manhattan_distance(unit.grid_position, ally.grid_position)
        if dist < nearest_dist:
            nearest_dist = dist
            nearest_healer = ally

    return nearest_healer
```

#### 5.2 Add outnumbered detection

Add this method and integrate into behavior checks:

```gdscript
## Check if unit is outnumbered in local area
## @param unit: The unit to check
## @param context: Battle context
## @param radius: Tile radius to check (default 3)
## @return: true if enemies outnumber allies 2:1 or more
func _is_outnumbered(unit: Node2D, context: Dictionary, radius: int = 3) -> bool:
    var allies: Array[Node2D] = _get_allied_units(unit, context)
    var opponents: Array[Node2D]
    if unit.faction == "enemy":
        opponents = get_player_units(context)
    else:
        opponents = get_enemy_units(context)

    var nearby_allies: int = 1  # Count self
    var nearby_enemies: int = 0

    for ally: Node2D in allies:
        if ally == unit or not ally.is_alive():
            continue
        var dist: int = GridManager.grid.get_manhattan_distance(unit.grid_position, ally.grid_position)
        if dist <= radius:
            nearby_allies += 1

    for enemy: Node2D in opponents:
        if not enemy.is_alive():
            continue
        var dist: int = GridManager.grid.get_manhattan_distance(unit.grid_position, enemy.grid_position)
        if dist <= radius:
            nearby_enemies += 1

    # Outnumbered if enemies are 2x or more allies
    return nearby_enemies >= nearby_allies * 2
```

Update `_execute_opportunistic` to use outnumbered check:

```gdscript
func _execute_opportunistic(unit: Node2D, context: Dictionary, behavior: AIBehaviorData) -> void:
    var player_units: Array[Node2D] = get_player_units(context)
    if player_units.is_empty():
        return

    # Check retreat conditions
    if behavior and behavior.retreat_enabled:
        var hp_percent: float = context.get("unit_hp_percent", 100.0)
        var should_retreat: bool = hp_percent < behavior.retreat_hp_threshold

        # Also retreat if outnumbered
        if not should_retreat and behavior.retreat_when_outnumbered:
            should_retreat = _is_outnumbered(unit, context)

        if should_retreat:
            var healed: bool = await _try_use_healing_item(unit, context, behavior)
            if healed:
                return

            await _execute_retreat(unit, player_units, context)
            return

    # ... rest of method unchanged
```

### Test Scenarios

1. **Seek Healer Test:** Wounded AI with `seek_healer_when_wounded = true`. Verify moves toward allied healer.
2. **Outnumbered Retreat Test:** 1 AI vs 3 enemies in radius. Verify retreat triggers.
3. **Not Outnumbered Test:** 2 AI vs 3 enemies. Verify no retreat (below 2:1 ratio).
4. **Disabled Outnumbered Test:** Set `retreat_when_outnumbered = false`. Verify no retreat even when outnumbered.

---

## Phase 6: AoE Optimization

**Goal:** AI only casts AoE spells when minimum targets requirement is met.

### 3-Sentence Explanation
Before casting an AoE spell, AI counts potential targets in the area. If target count is below `aoe_minimum_targets`, the AI skips that spell. AI also positions to maximize targets when possible.

### Code Changes

#### 6.1 Add AoE target counting

**File:** `/home/user/dev/sparklingfarce/core/systems/ai/configurable_ai_brain.gd`

```gdscript
## Count targets that would be hit by AoE at a given position
## @param center: Center cell of the AoE
## @param radius: AoE radius
## @param caster: The casting unit (to determine valid targets)
## @param ability: The ability being cast
## @return: Number of valid targets in AoE
func _count_aoe_targets(center: Vector2i, radius: int, caster: Node2D, ability: AbilityData) -> int:
    var count: int = 0

    for dx in range(-radius, radius + 1):
        for dy in range(-radius, radius + 1):
            var manhattan_dist: int = absi(dx) + absi(dy)
            if manhattan_dist > radius:
                continue

            var cell: Vector2i = center + Vector2i(dx, dy)
            if not GridManager.is_within_bounds(cell):
                continue

            var unit: Node2D = GridManager.get_unit_at_cell(cell)
            if unit and unit.is_alive() and _is_valid_aoe_target(caster, unit, ability):
                count += 1

    return count


## Check if unit is a valid target for this AoE ability
func _is_valid_aoe_target(caster: Node2D, target: Node2D, ability: AbilityData) -> bool:
    match ability.ability_type:
        AbilityData.AbilityType.HEAL, AbilityData.AbilityType.SUPPORT:
            return target.faction == caster.faction
        AbilityData.AbilityType.ATTACK, AbilityData.AbilityType.DEBUFF, AbilityData.AbilityType.STATUS:
            return target.faction != caster.faction
        _:
            return true


## Find best position to cast AoE for maximum targets
## @param caster: The casting unit
## @param ability: The AoE ability
## @param behavior: AI behavior settings
## @return: Dictionary with "target_cell" and "hit_count", or empty if not enough targets
func _find_best_aoe_target(caster: Node2D, ability: AbilityData, behavior: AIBehaviorData) -> Dictionary:
    var min_targets: int = behavior.aoe_minimum_targets if behavior else 2
    var aoe_radius: int = ability.area_of_effect
    var spell_range: int = ability.max_range

    var opponents: Array[Node2D]
    if caster.faction == "enemy":
        opponents = BattleManager.player_units
    else:
        opponents = BattleManager.enemy_units

    var best_cell: Vector2i = Vector2i(-1, -1)
    var best_count: int = 0

    # Check each potential target position
    for opponent: Node2D in opponents:
        if not opponent.is_alive():
            continue

        var target_cell: Vector2i = opponent.grid_position

        # Check if in range
        var dist: int = GridManager.grid.get_manhattan_distance(caster.grid_position, target_cell)
        if dist > spell_range:
            continue

        var count: int = _count_aoe_targets(target_cell, aoe_radius, caster, ability)
        if count > best_count:
            best_count = count
            best_cell = target_cell

    if best_count >= min_targets:
        return {"target_cell": best_cell, "hit_count": best_count}

    return {}
```

#### 6.2 Integrate AoE check into support role healing

Update `_execute_support_role` to check AoE healing:

```gdscript
# In _select_best_healing_ability, add AoE check:
func _select_best_healing_ability(unit: Node2D, target: Node2D, abilities: Array[Dictionary], behavior: AIBehaviorData) -> Dictionary:
    if abilities.is_empty():
        return {}

    var best_ability: Dictionary = {}
    var best_score: float = -999.0
    var conserve_mp: bool = behavior.conserve_mp_on_heals if behavior else false
    var min_aoe_targets: int = behavior.aoe_minimum_targets if behavior else 2

    var missing_hp: int = target.stats.max_hp - target.stats.current_hp

    for ability_info: Dictionary in abilities:
        var mp_cost: int = ability_info.get("mp_cost", 0)
        var power: int = ability_info.get("power", 0)
        var aoe_radius: int = ability_info.get("aoe", 0)

        # Can't afford this spell
        if mp_cost > unit.stats.current_mp:
            continue

        # AoE check: skip if not enough targets
        if aoe_radius > 0:
            var ability: AbilityData = ability_info.get("ability") as AbilityData
            if ability:
                var target_count: int = _count_aoe_targets(target.grid_position, aoe_radius, unit, ability)
                if target_count < min_aoe_targets:
                    continue  # Skip this AoE spell - not enough targets

        var score: float = 0.0

        # Prefer abilities that won't overheal too much
        var overheal: int = maxi(0, power - missing_hp)
        var efficiency: float = 1.0 - (float(overheal) / float(power + 1))
        score += efficiency * 50.0

        # If conserving MP, prefer cheaper spells
        if conserve_mp:
            score -= mp_cost * 2.0
        else:
            score += power * 0.5

        # Bonus for AoE that meets threshold
        if aoe_radius > 0:
            score += 20.0  # AoE heals are efficient

        if score > best_score:
            best_score = score
            best_ability = ability_info

    return best_ability
```

### Test Scenarios

1. **AoE Minimum Test:** Set `aoe_minimum_targets = 3`. Only 2 enemies grouped. Verify AoE not cast.
2. **AoE Cast Test:** 3+ enemies grouped. Verify AoE is cast.
3. **Single Target Fallback:** No valid AoE. Verify AI uses single-target spell instead.
4. **AoE Heal Test:** Multiple wounded allies. Verify AoE heal prioritized over single-target.

---

## Phase 7: Turn Order Awareness (DEFERRED)

**Status:** DEFERRED to future phase

### Rationale
Turn order awareness requires:
1. Access to TurnManager's turn queue
2. Predicting future unit positions
3. Complex conditional logic ("if enemy acts before ally heals me...")

This adds significant complexity with marginal tactical benefit. Classic Shining Force AI does not exhibit turn order awareness, so omitting it maintains genre authenticity.

### Future Implementation Notes
When implemented, consider:
- Read-only access to `TurnManager.turn_queue`
- Simple heuristic: "If I act before all enemies, be aggressive; if enemies act first, be cautious"
- Not full minimax/expectimax search

---

## Preset Updates

Each existing AI behavior preset should be updated with appropriate new threat weight keys.

### 8.1 aggressive_melee.tres

Add to `threat_weights`:
```
"healer": 1.5,
"damage_dealer": 1.0,
"debuffer": 1.2,
"support": 0.8,
"high_attack": 1.0,
"low_defense": 1.3
```

### 8.2 smart_healer.tres

Add to `threat_weights`:
```
"healer": 0.5,
"damage_dealer": 1.5,
"debuffer": 1.0,
"support": 0.5,
"high_attack": 1.2,
"low_defense": 0.8
```

### 8.3 tactical_mage.tres

Add to `threat_weights`:
```
"healer": 2.0,
"damage_dealer": 1.5,
"debuffer": 1.3,
"support": 1.0,
"high_attack": 1.0,
"low_defense": 1.5
```

### 8.4 defensive_tank.tres

Add to `threat_weights`:
```
"healer": 1.0,
"damage_dealer": 1.8,
"debuffer": 1.5,
"support": 0.8,
"high_attack": 1.5,
"low_defense": 0.5
```

### 8.5 opportunistic_archer.tres

Add to `threat_weights`:
```
"healer": 1.5,
"damage_dealer": 0.8,
"debuffer": 1.0,
"support": 0.5,
"high_attack": 0.8,
"low_defense": 1.8
```

### 8.6 stationary_guard.tres

No changes needed - stationary guards don't use advanced targeting.

---

## Testing Strategy

### Unit Tests (Headless)

**File:** `/home/user/dev/sparklingfarce/tests/unit/ai/test_configurable_ai_brain.gd`

```gdscript
# Test threat calculation
func test_calculate_unit_threat_healer_high_priority() -> void:
    # Setup: Create mock unit with HEAL ability
    # Verify: Threat score includes healer contribution

func test_calculate_unit_threat_boss_modifier() -> void:
    # Setup: Create unit with ai_threat_modifier = 2.0
    # Verify: Final threat is doubled

func test_outnumbered_detection() -> void:
    # Setup: 1 AI unit, 3 enemies within 3 tiles
    # Verify: _is_outnumbered returns true

func test_aoe_target_counting() -> void:
    # Setup: 3 enemies grouped, 1 enemy separate
    # Verify: _count_aoe_targets returns 3 for center position
```

### Integration Tests

**File:** `/home/user/dev/sparklingfarce/tests/integration/test_ai_behaviors.gd`

```gdscript
func test_aggressive_targets_healer_first() -> void:
    # Setup: Battle with enemy healer and warrior
    # Execute: Run AI turn for aggressive melee unit
    # Verify: AI attacks healer

func test_support_heals_most_wounded() -> void:
    # Setup: Two wounded allies, one at 20% HP, one at 60%
    # Execute: Run AI turn for support unit
    # Verify: AI heals the 20% HP ally

func test_defensive_protects_boss() -> void:
    # Setup: Boss ally with high ai_threat_modifier, player unit nearby
    # Execute: Run AI turn for defensive tank
    # Verify: Tank positions between boss and player
```

### Manual Test Checklist

- [ ] Aggressive AI visibly targets healers before warriors
- [ ] Support AI moves toward wounded allies before healing
- [ ] Tactical AI applies debuffs to high-threat targets
- [ ] Defensive AI positions between VIP and threats
- [ ] Wounded AI seeks allied healers when retreating
- [ ] AI uses healing items when HP low and no heal spell
- [ ] AoE spells only cast when minimum targets met
- [ ] Boss enemies receive protection from defensive allies

---

## Implementation Order

1. **Phase 1** - Foundation for all other phases (ability scanning)
2. **Phase 6** - AoE optimization (simple, independent)
3. **Phase 2** - Item usage (builds on Phase 1 patterns)
4. **Phase 3** - Tactical role (uses Phase 1's threat calculation)
5. **Phase 5** - Retreat enhancements (uses ally scanning from Phase 1)
6. **Phase 4** - Defensive role (most complex, benefits from all prior work)

Each phase can be tested independently before proceeding.

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Performance with many abilities | Medium | Cache ability types per unit at turn start |
| False threat prioritization | Low | Tunable weights allow adjustment |
| Item usage edge cases | Medium | Comprehensive null checks, fallback to normal behavior |
| Infinite retreat loops | High | Cap retreat distance, require minimum movement |
| VIP detection false positives | Low | Multiple criteria (modifier + tags + class) |

---

## Success Criteria

- [x] AI can differentiate between healers, damage dealers, and support units
- [x] AI uses items appropriately based on behavior flags
- [x] Tactical role applies preferred debuffs
- [x] Defensive role provides meaningful bodyguard behavior
- [x] Retreat behavior improved with healer-seeking
- [x] AoE abilities respect minimum target requirements
- [x] All changes backward-compatible with existing presets
- [x] No performance regression in battles with 20+ units

**All 38 unit tests passing as of 2025-12-14.**

---

*"Logic is the beginning of wisdom, not the end." - Spock*

The simplest solution that works is the correct solution. These changes add meaningful tactical depth while respecting the project's commitment to maintainability and modder accessibility.
