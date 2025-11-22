# XP System Design Document

## Table of Contents
1. [Research Summary](#research-summary)
2. [The Problem](#the-problem)
3. [Solutions From Other Games](#solutions-from-other-games)
4. [Recommended Approach](#recommended-approach)
5. [Current Codebase Analysis](#current-codebase-analysis)
6. [Implementation Plan](#implementation-plan)
7. [Technical Specifications](#technical-specifications)
8. [Testing Strategy](#testing-strategy)

---

## Research Summary

### Shining Force XP Mechanics (SF1, SF2, GBA Remake)

#### Base Experience Formula
**Level Difference Calculation:**
- Character Level - Enemy Level ≤ 2: X = 50
- Difference of 3: X = 40
- Difference of 4: X = 30
- Difference of 5: X = 20
- Difference of 6: X = 10
- Difference ≥ 7: X = 0

Alternative formula: `X = 2^(B - A + 3)` where B is enemy level and A is character level.

#### Combat Experience
- `DamageEXP = RoundDown(X * (damage / MaxHP))`
- `KillEXP = DamageEXP + X`
- When you kill a monster, you get both the damage exp and the kill exp
- Maximum XP per action is capped at 49 (±1)

#### Healing Experience
- Base value: 25 EXP (static)
- Bonus based on percentage of HP healed
- If healing 50% of max HP, healer receives: 12.5 EXP (rounded down to 12)
- Minimum healing XP: 10
- Maximum healing XP: 20 in SF1, 25-26 in SF2
- SF1 and SF3: Healers do NOT gain XP for healing full HP characters
- SF2: Healers DO gain XP for healing full HP characters

#### Multi-Target Spells
- Damage to multiple targets is added up AFTER each individual result is rounded down
- This makes area spells less efficient for XP than they appear

#### Leveling
- 100 experience points = 1 level
- Upon promotion, characters return to level 1 of new class with slightly reduced stats

---

## The Problem

### Kill Shot-Focused XP Creates Snowballing

**Documented Issues:**

1. **Healer Disadvantage**
   - Healers end up 5-10 levels below combat units
   - Fighters get 30+ XP per hit and 48 XP per kill
   - Healers get only 10-15 XP per spell cast
   - This gap persists throughout the entire game

2. **Snowballing Effect**
   - Stronger characters "hog up all the experience"
   - Strong units get more kills → more XP → become even stronger
   - Weak units struggle to get kills → less XP → fall further behind
   - Late-game characters join unpromoted and significantly weaker, making catch-up extremely difficult

3. **Player Workarounds** (indicating design flaws)
   - **Heal Spamming:** Have priests use all MP every battle casting heals regardless of need
   - **Damage Softening:** Use strong characters to weaken enemies, then have weak characters finish
   - **Limit Healer Count:** Using only 1-2 healers prevents XP spreading too thin
   - **Accept the Gap:** Players rationalize that healers can afford being behind

### Why Kill-Focused XP Is Problematic
- Discourages team coordination
- Creates "kill stealing" behavior
- Undervalues strategic positioning, buffing, debuffing, tanking
- Healers and support characters become underpowered
- Reduces tactical diversity (everyone wants damage dealers)
- New/replacement units can never catch up

---

## Solutions From Other Games

### Triangle Strategy - Action-Based XP

**Mechanics:**
- EVERY action awards XP (except moving): attacking, healing, buffing, debuffing, using items
- Underleveled units (2+ levels below suggested): 40-75 XP per action
- Same-leveled units: 10-15 XP per action
- Overleveled units: ~5 XP per action
- 100 XP needed per level

**Pros:**
- Automatic roster balancing
- All roles gain equal XP potential
- Extremely generous catch-up mechanics
- Encourages using full roster

**Cons:**
- Can feel "gamey" to spam unnecessary heals/buffs
- Removes strategic choice of XP distribution
- Major departure from classic SRPG feel

---

### Fire Emblem - Adjutant System

**Mechanics:**
- Adjutants gain exactly 50% of deployed unit's XP (rounded up)
- Includes ALL sources: battling, healing, white magic, dancing
- Gains full skill experience and class mastery
- Experience/Knowledge Gems apply boosting effects
- Also builds support points passively
- Unlocks at specific progression milestones

**Pros:**
- Elegant catch-up mechanism for benched units
- Strategic depth through unit pairing
- Maintains combat focus
- Builds character relationships

**Cons:**
- Doesn't directly fix healer XP problem
- Requires additional UI for management
- Passive leveling may feel less engaging

---

### Fire Emblem - Support Action XP

**Mechanics:**
- Staff users: `(cost per use / 20) + 10`
- Dancing/singing: Fixed 10-20 points
- Stealing: Consistent 10 points
- **Anti-abuse mechanic:** XP scales down after repeated use on same map

**Pros:**
- Support actions properly rewarded
- Anti-abuse prevents exploitation
- Maintains strategic decision-making

**Cons:**
- Still somewhat favors combat
- Anti-staff-grinding can frustrate healer development
- Complexity increases

---

### Tactics Ogre (Reborn) - Union Level System

**Mechanics:**
- Union Level acts as progressive level cap
- Total battle XP divided among all deployed units
- "Skews noticeably towards lower classes"
- When unit hits cap, XP redistributes to rest of party
- Fresh units grouped with max-level characters level up extremely fast

**Pros:**
- Union Level prevents over-grinding
- Automatic catch-up for underleveled units
- Lower-level units explicitly gain more XP

**Cons:**
- Level caps can feel restrictive
- Some players dislike class-based over individual leveling
- Requires careful progression tuning

---

### XCOM 2 - Shared Mission XP

**Mechanics:**
- Everyone in mission gets XP for every kill
- Different class conversion rates:
  - Specialists: 3 squad kills = 1 kill XP
  - Rangers & Rookies: 4 squad kills = 1 kill XP
  - Sharpshooters & Grenadiers: 5 squad kills = 1 kill XP
- Fixed mission completion XP
- Smaller squads = more kills per soldier = more XP per soldier

**Pros:**
- Participation-based XP rewards teamwork
- Mission completion XP ensures everyone progresses
- One rank per mission prevents excessive snowballing

**Cons:**
- Still favors combat classes over pure support
- Class conversion rates feel arbitrary
- No explicit healing/support XP

---

### Disgaea 6 - Party-Wide Shared XP

**Mechanics:**
- Party-wide shared experience awarded after map completion
- Departure from individual action-based XP
- Eliminates within-party imbalance completely

**Pros:**
- Complete equality among all units
- Eliminates kill-stealing
- Simple to implement

**Cons:**
- Major departure from traditional tactical RPGs
- Less granular feedback during battle
- May feel unrewarding for standout performances

---

### Final Fantasy Tactics - Dual Progression

**Mechanics:**
1. **Experience Points (XP):** `10 + (Target's Level - Actor's Level)` + 10 for kill
2. **Job Points (JP):** `[(8 + (JobLevel * 2) + [Lv / 4]) * M]` for ANY successful action
3. **JP Spillover:** Party members earn `[gained JP / 4]` for that job

**Pros:**
- Dual progression provides depth and flexibility
- Spillover naturally helps underused jobs catch up
- Any action (damage, healing, buffing) grants progression
- No character left behind

**Cons:**
- Can be broken through job exploit grinding
- Complexity may overwhelm new players
- JP grinding can trivialize difficulty

---

## Recommended Approach

### Hybrid Participation XP System

**Design Philosophy:**
- Maintain Shining Force's familiar base formulas
- Solve healer/support XP problems
- Reward tactical positioning and teamwork
- Prevent kill-shot monopolization
- Keep everything configurable for content creators

### Core Components

#### 1. Participation-Based Combat XP

```
Base XP = Shining Force level difference formula
Participation XP = Base XP × 0.25 (for allies within 3-4 tiles)
Damage XP = Base XP × (Damage Dealt / Enemy Max HP)
Kill XP = Base XP × 0.5
Total = Participation + Damage + Kill (if applicable)
Max per action: 49 XP (maintain SF cap)
```

**Benefits:**
- Everyone in tactical range gets baseline XP
- Damage dealers still rewarded for effectiveness
- Kill shot provides bonus but doesn't monopolize XP
- Maintains Shining Force feel while fixing imbalance

#### 2. Enhanced Support Action XP

**Healing:**
```
Base Healing XP = 10
Ratio Bonus = 25 × (HP Restored / Target Max HP)
Total = Base + Ratio Bonus
```

**Buffs/Debuffs:**
- Fixed 15 XP per cast

**Anti-Spam Scaling:**
- Uses 1-4: Full XP
- Uses 5-7: 60% XP
- Uses 8+: 30% XP

**Benefits:**
- Healers gain competitive XP
- Prevents MP-dump exploitation
- Rewards meaningful support actions

#### 3. Skeleton for Future Adjutant System
- Data structure in place (Unit.adjutant field)
- Hook in ExperienceManager.award_xp()
- No UI or assignment logic yet

---

## Current Codebase Analysis

### Existing XP Implementation: PARTIALLY IMPLEMENTED

**What Exists:**
- `CombatCalculator.calculate_experience_gain()` - Basic level difference formula
- `BattleData.experience_reward` - Overall battle rewards
- Battle Editor UI for setting rewards

**What's Missing:**
- No XP tracking in UnitStats
- No XP awarding system in BattleManager (line 532: `# TODO: Award experience/items`)
- No level-up system
- No participation-based XP
- No support/healing XP

### Architecture Strengths

**Perfect Integration Points:**

1. **Signal Architecture**
   - `combat_resolved` - Emitted after every attack with full combat data
   - `died` - Emitted when unit dies (perfect for kill XP)
   - `healed` - Emitted when unit healed
   - `battle_ended` - Ideal for final XP distribution and level-up screens

2. **Grid System Ready**
   - `GridManager.get_distance(from, to)` - Manhattan distance
   - `GridManager.get_cells_in_range(center, range)` - AOE calculations
   - Perfect for "units within 3 spaces" participation logic

3. **Class Growth Rates Already Defined**
   - `ClassData` has growth rates for all stats
   - `get_growth_rate(stat_name)` method ready to use
   - Learnable abilities by level already structured

4. **Clean Component Architecture**
   - CharacterData (immutable base stats)
   - UnitStats (runtime state)
   - Unit (scene component)
   - Clear separation of concerns

### Files Structure

**Core Systems:**
- `core/systems/battle_manager.gd` - Combat resolution
- `core/systems/turn_manager.gd` - Turn order, battle flow
- `core/systems/grid_manager.gd` - Pathfinding, distance
- `core/systems/combat_calculator.gd` - Damage/XP formulas

**Components:**
- `core/components/unit.gd` - Unit scene component
- `core/components/unit_stats.gd` - Runtime stats (needs XP tracking)

**Resources:**
- `core/resources/character_data.gd` - Base character data
- `core/resources/class_data.gd` - Class stats and growth rates
- `core/resources/ability_data.gd` - Abilities (has types: HEAL, SUPPORT, etc.)
- `core/resources/battle_data.gd` - Battle configuration

---

## Implementation Status

**Last Updated:** November 21, 2025

### ✅ Phase 1: Foundation - COMPLETED

**Implementation Date:** November 21, 2025

**Status:** All components implemented and tested. Files staged in git.

**Files Created:**
- `core/resources/experience_config.gd` - Configuration resource (165 lines)
- `core/systems/experience_manager.gd` - Central XP management autoload (410 lines)

**Files Modified:**
- `core/components/unit_stats.gd` - Added XP tracking fields and methods
- `core/components/unit.gd` - Added owner_unit reference in initialize()
- `project.godot` - Registered ExperienceManager as autoload

**Testing Results:**
- ✅ All files load without parse errors
- ✅ Strict typing enforced throughout
- ✅ Follows Godot best practices
- ✅ ExperienceManager autoload initializes successfully
- ✅ Default ExperienceConfig created on startup

**Next Steps:**
- Proceed to Phase 2: Combat XP Integration
- Connect BattleManager to ExperienceManager signals
- Award XP on combat_resolved and unit death

---

## Implementation Plan

### Phase 1: Foundation (Core Systems) - ✅ COMPLETED

#### 1.1 Create ExperienceConfig Resource - ✅ DONE

**File:** `core/resources/experience_config.gd`

**Fields:**
```gdscript
# Combat XP Settings
@export var enable_participation_xp: bool = true
@export var participation_radius: int = 3
@export var participation_multiplier: float = 0.25
@export var kill_bonus_multiplier: float = 0.5
@export var max_xp_per_action: int = 49

# Level Difference XP Table (Shining Force style)
@export var level_diff_xp_table: Dictionary = {
    -20: 0, -7: 0, -6: 10, -5: 20, -4: 30, -3: 40,
    -2: 50, -1: 50, 0: 50, 1: 50, 2: 50, 20: 50
}

# Support XP Settings
@export var enable_enhanced_support_xp: bool = true
@export var heal_base_xp: int = 10
@export var heal_ratio_multiplier: int = 25
@export var buff_base_xp: int = 15
@export var debuff_base_xp: int = 15

# Anti-Spam Settings
@export var anti_spam_enabled: bool = true
@export var spam_threshold_medium: int = 5  # 60% XP
@export var spam_threshold_heavy: int = 8   # 30% XP

# Leveling Settings
@export var xp_per_level: int = 100
@export var max_level: int = 20
@export var promotion_level: int = 10

# Adjutant System (skeleton for future)
@export var enable_adjutant_system: bool = false
@export var adjutant_xp_share: float = 0.5
@export var max_adjutants: int = 3
```

#### 1.2 Create ExperienceManager Autoload - ✅ DONE

**File:** `core/systems/experience_manager.gd`

**Key Methods:**
- `award_combat_xp(attacker, defender, damage, got_kill)`
- `award_support_xp(supporter, action_type, target, amount)`
- `get_base_xp_from_level_diff(level_diff)`
- `get_units_in_participation_radius(center_unit)`
- `apply_level_up(unit)`
- `calculate_stat_increase(base_stat, growth_rate)`

**Responsibilities:**
- Calculate all XP awards
- Distribute XP to participating units
- Handle level-up logic
- Apply growth rates
- Learn new abilities
- Handle promotions

#### 1.3 Extend UnitStats - ✅ DONE

**File:** `core/components/unit_stats.gd` (modify existing)

**Add Fields:**
```gdscript
var current_xp: int = 0
var xp_to_next_level: int = 100
var support_actions_this_battle: Dictionary = {}  # action_type: count
```

**Add Methods:**
```gdscript
func gain_xp(amount: int) -> void
func can_level_up() -> bool
func level_up(stat_increases: Dictionary) -> void
func reset_battle_tracking() -> void
func get_xp_progress() -> float  # Returns 0.0-1.0 for UI
```

#### 1.4 Update Project Configuration - ✅ DONE

**File:** `project.godot` (modify existing)

Add autoload:
```ini
ExperienceManager="*res://core/systems/experience_manager.gd"
```

---

### Phase 2: Combat XP Integration - 🔜 NEXT

#### 2.1 Track Participation in BattleManager

**File:** `core/systems/battle_manager.gd` (modify existing)

**Changes:**
1. In `_execute_attack()` after combat_resolved signal:
   - Call `ExperienceManager.award_combat_xp()`
   - Pass attacker, defender, damage_dealt, false (not a kill yet)

2. In `_on_unit_died()` after death processing:
   - Call `ExperienceManager.award_combat_xp()` with got_kill=true
   - Award kill bonus to last attacker

3. Connect to ExperienceManager signals:
   - `unit_leveled_up(unit, old_level, new_level, stat_increases)`
   - Display level-up notification

#### 2.2 Implement Participation Radius Logic

**File:** `core/systems/experience_manager.gd`

**Method:**
```gdscript
func get_units_in_participation_radius(center_unit: Unit) -> Array[Unit]:
    var nearby_allies: Array[Unit] = []
    var center_pos: Vector2i = center_unit.grid_position
    var all_units: Array = TurnManager.all_units

    for unit in all_units:
        if unit == center_unit:
            continue
        if unit.team != center_unit.team:
            continue
        if not unit.stats.is_alive():
            continue

        var distance: int = GridManager.get_distance(center_pos, unit.grid_position)
        if distance <= config.participation_radius:
            nearby_allies.append(unit)

    return nearby_allies
```

#### 2.3 XP Distribution Logic

**File:** `core/systems/experience_manager.gd`

**Method:**
```gdscript
func award_combat_xp(attacker: Unit, defender: Unit, damage_dealt: int, got_kill: bool) -> void:
    var level_diff: int = defender.stats.level - attacker.stats.level
    var base_xp: int = get_base_xp_from_level_diff(level_diff)

    # 1. Calculate attacker XP
    var attacker_xp: int = 0

    if damage_dealt > 0:
        var damage_ratio: float = float(damage_dealt) / float(defender.stats.max_hp)
        attacker_xp += int(base_xp * damage_ratio)

    if got_kill:
        attacker_xp += int(base_xp * config.kill_bonus_multiplier)

    attacker_xp = mini(attacker_xp, config.max_xp_per_action)

    # Award to attacker
    _give_xp_to_unit(attacker, attacker_xp)

    # 2. Award participation XP to nearby allies
    if config.enable_participation_xp and damage_dealt > 0:
        var nearby_allies: Array[Unit] = get_units_in_participation_radius(attacker)
        var participation_xp: int = int(base_xp * config.participation_multiplier)

        for ally in nearby_allies:
            _give_xp_to_unit(ally, participation_xp)
```

---

### Phase 3: Support XP Integration

#### 3.1 Track Support Actions

**File:** `core/systems/battle_manager.gd` (modify existing)

**Changes:**
1. Connect to Unit `healed` signal
2. Track buff/debuff ability usage
3. Call `ExperienceManager.award_support_xp()`

**Note:** May need to add ability usage tracking to ability system

#### 3.2 Support XP Calculation

**File:** `core/systems/experience_manager.gd`

**Method:**
```gdscript
func award_support_xp(supporter: Unit, action_type: String, target: Unit, amount: int) -> void:
    if not config.enable_enhanced_support_xp:
        return

    var base_xp: int = 0

    match action_type:
        "heal":
            var heal_ratio: float = float(amount) / float(target.stats.max_hp)
            base_xp = config.heal_base_xp + int(config.heal_ratio_multiplier * heal_ratio)
        "buff":
            base_xp = config.buff_base_xp
        "debuff":
            base_xp = config.debuff_base_xp

    # Apply anti-spam scaling
    if config.anti_spam_enabled:
        var usage_count: int = supporter.stats.support_actions_this_battle.get(action_type, 0)
        supporter.stats.support_actions_this_battle[action_type] = usage_count + 1

        if usage_count >= config.spam_threshold_heavy:
            base_xp = int(base_xp * 0.3)
        elif usage_count >= config.spam_threshold_medium:
            base_xp = int(base_xp * 0.6)

    _give_xp_to_unit(supporter, base_xp)
```

#### 3.3 Battle Cleanup

**File:** `core/systems/battle_manager.gd` (modify existing)

In `_on_battle_ended()`:
```gdscript
# Reset support action tracking for all units
for unit in TurnManager.all_units:
    unit.stats.reset_battle_tracking()
```

---

### Phase 4: Level-Up System

#### 4.1 XP Gain and Level-Up Detection

**File:** `core/components/unit_stats.gd` (modify existing)

**Methods:**
```gdscript
func gain_xp(amount: int) -> void:
    if level >= ExperienceManager.config.max_level:
        return  # Already max level

    current_xp += amount

    # Check for level-up
    while current_xp >= xp_to_next_level and level < ExperienceManager.config.max_level:
        var overflow: int = current_xp - xp_to_next_level
        current_xp = overflow
        ExperienceManager._trigger_level_up(unit_reference)

func can_level_up() -> bool:
    return current_xp >= xp_to_next_level and level < ExperienceManager.config.max_level

func reset_battle_tracking() -> void:
    support_actions_this_battle.clear()
```

#### 4.2 Apply Growth Rates

**File:** `core/systems/experience_manager.gd`

**Method:**
```gdscript
func apply_level_up(unit: Unit) -> Dictionary:
    var old_level: int = unit.stats.level
    unit.stats.level += 1
    var new_level: int = unit.stats.level

    var stat_increases: Dictionary = {}
    var class_data: ClassData = unit.character_data.character_class

    # Roll for each stat increase
    var stats_to_grow: Array[String] = ["hp", "mp", "strength", "defense", "agility", "intelligence", "luck"]

    for stat_name in stats_to_grow:
        var growth_rate: int = class_data.get_growth_rate(stat_name)
        var increase: int = calculate_stat_increase(growth_rate)

        if increase > 0:
            stat_increases[stat_name] = increase

            # Apply the increase
            match stat_name:
                "hp":
                    unit.stats.max_hp += increase
                    unit.stats.current_hp += increase  # Heal on level-up
                "mp":
                    unit.stats.max_mp += increase
                    unit.stats.current_mp += increase
                "strength":
                    unit.stats.strength += increase
                "defense":
                    unit.stats.defense += increase
                "agility":
                    unit.stats.agility += increase
                "intelligence":
                    unit.stats.intelligence += increase
                "luck":
                    unit.stats.luck += increase

    # Check for ability learning
    var learned_abilities: Array = _check_learned_abilities(unit, new_level, class_data)
    if not learned_abilities.is_empty():
        stat_increases["abilities"] = learned_abilities

    # Emit signal for UI
    unit_leveled_up.emit(unit, old_level, new_level, stat_increases)

    return stat_increases

func calculate_stat_increase(growth_rate: int) -> int:
    # Shining Force style: growth_rate is percentage (0-100)
    # Roll random number 0-99, if less than growth_rate, stat increases
    var roll: int = randi() % 100
    return 1 if roll < growth_rate else 0

func _check_learned_abilities(unit: Unit, new_level: int, class_data: ClassData) -> Array:
    var learned: Array = []

    if "learnable_abilities" in class_data and class_data.learnable_abilities:
        if new_level in class_data.learnable_abilities:
            var abilities = class_data.learnable_abilities[new_level]
            for ability in abilities:
                unit.add_ability(ability)
                learned.append(ability)

    return learned
```

---

### Phase 5: UI & Feedback

#### 5.1 Level-Up Notification Screen

**File:** `scenes/ui/level_up_screen.tscn` + script

**Components:**
- Character portrait
- "Level Up!" text
- Old Level → New Level display
- Stat increases list (only show stats that increased)
- Learned abilities display
- "Continue" button

**Script:** `scenes/ui/level_up_screen.gd`

**Methods:**
```gdscript
func show_level_up(unit: Unit, old_level: int, new_level: int, stat_increases: Dictionary) -> void:
    # Populate UI with level-up data
    # Pause battle
    # Wait for player input
    # Resume battle

signal level_up_acknowledged
```

#### 5.2 XP Gain Visual Feedback

**File:** `core/components/unit.gd` (modify existing)

**Add floating text for XP gains:**
- Small floating number showing "+15 XP" above unit
- Different color for different XP types (combat vs support)
- Could use existing damage number system as template

#### 5.3 XP Progress UI (Optional)

**In unit info panel or during action preview:**
- Show current XP / next level XP
- Progress bar visualization
- Preview XP gain before confirming action

---

### Phase 6: Testing Strategy

#### 6.1 Unit Tests

**Create test scenes in:** `mods/_sandbox/scenes/`

**Test Scenarios:**

1. **Combat XP Test**
   - Verify base XP formula matches Shining Force
   - Test participation radius (3 tiles)
   - Verify damage XP scaling
   - Verify kill bonus (50% not 100%)

2. **Support XP Test**
   - Verify healing XP scales with HP restored
   - Test buff/debuff XP awards
   - Test anti-spam reduction (5+ and 8+ uses)

3. **Level-Up Test**
   - Verify stat increases based on growth rates
   - Test ability learning at milestone levels
   - Verify max HP/MP increases apply immediately
   - Test max level cap

4. **Participation Radius Test**
   - Unit at exact 3 tiles: should get XP
   - Unit at 4 tiles: should NOT get XP
   - Verify only same-team units get XP
   - Verify dead units don't get XP

5. **Balance Test (10 battles)**
   - All damage dealers party
   - All healers party
   - Mixed composition (2 fighters, 2 healers, 2 support)
   - Track final levels after 10 battles
   - **Goal:** Healers within 2 levels of fighters

#### 6.2 Integration Tests

**File:** `test_headless.sh` (modify existing)

Add XP system tests to headless test suite:
- Load test battle
- Execute predefined actions
- Verify expected XP awards
- Verify level-ups occur correctly

#### 6.3 Manual Testing

**Battle Editor:**
- Create test battles with level differences
- Verify XP preview shows correctly
- Test different team compositions
- Adjust config values and observe changes

---

## Technical Specifications

### Data Structures

#### ExperienceManager Signals
```gdscript
signal unit_gained_xp(unit: Unit, amount: int, source: String)
signal unit_leveled_up(unit: Unit, old_level: int, new_level: int, stat_increases: Dictionary)
signal unit_learned_ability(unit: Unit, ability: AbilityData)
signal unit_promoted(unit: Unit, old_class: ClassData, new_class: ClassData)
```

#### UnitStats New Fields
```gdscript
var current_xp: int = 0
var xp_to_next_level: int = 100
var support_actions_this_battle: Dictionary = {}  # "heal": 3, "buff": 2, etc.
```

#### XP Award Source Types
```gdscript
enum XPSource {
    DAMAGE,
    KILL,
    PARTICIPATION,
    HEAL,
    BUFF,
    DEBUFF,
    MISSION_COMPLETE
}
```

### Configuration Defaults

**Recommended Starting Values:**
```gdscript
participation_radius = 3
participation_multiplier = 0.25
kill_bonus_multiplier = 0.5
heal_base_xp = 10
heal_ratio_multiplier = 25
buff_base_xp = 15
spam_threshold_medium = 5
spam_threshold_heavy = 8
```

### Performance Considerations

**Participation Radius Checks:**
- Only calculate on damage/kill, not every frame
- Cache all_units array from TurnManager
- Use GridManager's optimized distance function

**Level-Up Processing:**
- Process level-ups after battle action completes
- Queue multiple level-ups if earning enough XP at once
- Don't block battle flow (show level-up screen between turns or at battle end)

**Memory:**
- ExperienceConfig is lightweight (mostly ints and floats)
- Support action tracking cleared after each battle
- No persistent XP history needed (only current_xp matters)

---

## Future Enhancements (Not in Initial Implementation)

### Adjutant System (Phase 2)
- UI for assigning adjutants to deployed units
- Adjutant selection screen before battle
- Support relationship building
- XP share implementation (skeleton already in place)

### Advanced Features
- XP multiplier items (Experience Gem, etc.)
- Difficulty mode XP modifiers
- Per-battle XP multiplier overrides
- XP curve visualization in battle editor
- Recommended level calculator
- Party balance suggestions

### Analytics
- Track XP sources over time
- Balance reporting tools
- Heatmaps for XP distribution
- Content creator guidelines for XP tuning

---

## Code Style Compliance

### Strict Typing
```gdscript
# All variables typed
var current_xp: int = 0
var nearby_allies: Array[Unit] = []
var config: ExperienceConfig

# All function parameters and returns typed
func award_combat_xp(attacker: Unit, defender: Unit, damage_dealt: int, got_kill: bool) -> void:
```

### Dictionary Key Checking
```gdscript
# CORRECT
if "learnable_abilities" in class_data:
    # ...

# INCORRECT (don't use)
if class_data.has("learnable_abilities"):
    # ...
```

### Naming Conventions
- snake_case for variables and functions
- PascalCase for classes
- UPPER_CASE for constants
- Private methods prefixed with underscore

### Documentation
```gdscript
## Calculates and awards combat XP to attacker and nearby allies.
##
## Takes into account level difference, damage dealt, kill bonus, and participation.
## Automatically applies anti-spam scaling for repeated actions.
##
## @param attacker: Unit that performed the attack
## @param defender: Unit that was attacked
## @param damage_dealt: Amount of damage dealt in the attack
## @param got_kill: Whether this attack resulted in defender's death
func award_combat_xp(attacker: Unit, defender: Unit, damage_dealt: int, got_kill: bool) -> void:
```

---

## Summary

This hybrid XP system:
- ✅ Solves the healer/support XP problem
- ✅ Maintains Shining Force's classic feel
- ✅ Rewards tactical positioning and teamwork
- ✅ Prevents kill-shot monopolization
- ✅ Provides catch-up mechanics through participation
- ✅ Fully configurable for content creators
- ✅ Follows Godot best practices
- ✅ Integrates cleanly with existing architecture
- ✅ Supports future adjutant system expansion

The implementation is broken into 6 clear phases, each fully testable before moving to the next. The system is modular, maintainable, and provides the flexibility needed for a platform that others will build upon.
