# Ability System Plan

**Author**: Lt. Claudbrain, USS Torvalds
**Date**: 2025-12-06
**Updated**: 2025-12-08 (Phase S1 + S2 COMPLETE - Spell system working!)
**Status**: Phase S1-S2 Complete, Phase S3 In Progress (UI polish needed)

---

## Executive Summary

This plan outlines a comprehensive ability/skill system for The Sparkling Farce platform that bridges Shining Force authenticity with Fire Emblem-style depth. The system distinguishes between **active abilities** (spells/skills used in combat) and **passive abilities** (skills that provide ongoing effects). It also introduces an **aura system** for range-based effects that can influence nearby allies or enemies.

The design prioritizes:
1. Platform extensibility (mods can add any ability type)
2. SF-authentic base game (minimal skill complexity)
3. FE-style mechanics available for mods that want them
4. Clear visual feedback for tactical decision-making
5. Data-driven design with scripting escape hatches

---

## PRIORITY: Active Spell Implementation

**Updated 2025-12-08**: Commander Claudius's assessment confirms we're 80-85% ready for active spell implementation. This section covers the immediate path to working spells.

### Spell Source Architecture (SF-Authentic)

**Core Principle**: Spells are CLASS-BASED, not character-based.

```
Character's Available Spells = ClassData.class_abilities + CharacterData.unique_abilities
```

**ClassData** defines spell lists (primary source):
- MAGE class → Blaze 1-4
- PRIEST class → Heal 1-4
- WIZARD class (promoted MAGE) → Blaze 1-4, Freeze 1-4
- Boss classes → Custom spell lists per boss type

**CharacterData.unique_abilities** (rare exceptions only):
- Domingo's innate Freeze (before learning other spells)
- Special hero abilities
- Unique character powers that transcend class

This matches SF2's design where a character's spells come from their class, and promotion to a new class grants new/upgraded spells.

### Infrastructure Already In Place ✅

1. **AbilityData Resource** (`core/resources/ability_data.gd`)
   - Complete with targeting, range, MP costs, power, status effects
   - Production-ready, no changes needed

2. **CombatCalculator.calculate_magic_damage()**
   - SF2-authentic INT-based formula already implemented
   - `(Ability Power + Attacker INT - Defender INT/2) * variance`

3. **Item System Pattern**
   - `item_menu.gd` provides complete blueprint for spell menu
   - `InputManager` states for selection → targeting → execution
   - `BattleManager._apply_item_effect()` pattern to clone

4. **Mod Discovery**
   - Abilities auto-register from `mods/*/data/abilities/`

### Key Gaps to Fill ⚠️

1. **ClassData needs `class_abilities` field** (CRITICAL)
   ```gdscript
   @export var class_abilities: Array[AbilityData] = []
   @export var ability_unlock_levels: Dictionary = {}  # {"heal_2": 12}
   ```

2. **CharacterData needs `unique_abilities` field** (for exceptions)
   ```gdscript
   @export var unique_abilities: Array[AbilityData] = []
   ```

3. **SpellMenu UI** - Clone ItemMenu, show MP costs, disable if insufficient MP

4. **InputManager spell states** - Add SELECTING_SPELL, SELECTING_SPELL_TARGET

5. **BattleManager spell execution** - Clone item execution with MP deduction

### Spell Implementation Phases

#### Phase S1: Foundation ✅ COMPLETE
1. ✅ Add `class_abilities` and `ability_unlock_levels` to ClassData
2. ✅ Add `unique_abilities` to CharacterData
3. ✅ Create test spells: `heal_1.tres`, `blaze_1.tres` in `mods/_base_game/data/abilities/`
4. ✅ Assign spells to test class (MAGE gets Blaze and Heal)

**Deliverable**: Characters have spell lists derived from class ✅

#### Phase S2: Core Execution ✅ COMPLETE
1. ✅ Add InputManager spell states (SELECTING_SPELL, SELECTING_SPELL_TARGET)
2. ✅ Create SpellMenu (shows MP cost, disables if insufficient MP)
3. ✅ Add BattleManager spell execution (MP deduction, damage/healing)
4. ✅ Wire "Magic" action to spell menu (shows when character has spells)

**Deliverable**: Spells execute correctly in battle ✅

**Note**: The _base_game Maggie character uses an inline SubResource for her Mage class, which required adding `class_abilities` directly to the character file.

#### Phase S3: UI & Polish (IN PROGRESS)
1. ✅ Add "Magic" to action menu (hidden if no spells)
2. ⚠️ Spell menu position needs adjustment (UI bug)
3. ⏳ Spell targeting range visualization
4. ⏳ Combat animation integration
5. ⏳ MP display in unit stats panel

**Deliverable**: Full player-facing spell system

#### Phase S4: Spell Progression (Optional, ~3-4 hours)
1. Level-based spell unlocks from `ability_unlock_levels`
2. Spell tier progression (Heal 1 → 2 → 3 → 4)
3. Area-of-effect spells using `area_of_effect` field

**Deliverable**: SF2-authentic spell progression

### Estimated Total: 8-12 hours for complete spell system

---

## Part 1: Research Findings

### 1.1 Fire Emblem Fan-Favorite Mechanics

Based on extensive research of Fire Emblem communities, the following mechanics are most beloved:

#### Personal Skills (Character-Unique)
First introduced in **Genealogy of the Holy War** (1996), expanded significantly in **Fates** and **Three Houses**. Every character has a unique passive ability reflecting their personality.

**Fan Favorites**:
- **Philanderer** (Sylvain): Bonus damage when adjacent to female allies
- **Rivalry** (Leonie): Bonus damage when adjacent to male allies
- **Honorable Spirit** (Yuri): Bonus damage when NOT adjacent to allies
- Skills that reflect character personality are praised for adding narrative depth

#### Class Skills (Promotion-Based)
Skills learned by mastering a class, retained even after changing classes.

**Most Praised**:
- **Vantage**: Attack first when HP is low (Genealogy origin, appears in many games)
- **Canto**: Move remaining distance after acting (mounted units)
- **Astra**: 5 consecutive attacks at 30% power
- **Luna**: Ignore portion of enemy defense
- **Paragon**: Double XP gain (beloved for training units)

#### Support/Adjacency Bonuses
Units adjacent to allies with support relationships gain stat bonuses.

**Mechanics**:
- Support ranks (C/B/A/S) increase bonuses
- Each adjacent supported ally adds bonuses
- Maximum support rank totals per character
- Bonuses scale with relationship depth

#### Pair Up / Dual System (Awakening/Fates)
Two units occupy one tile, providing stat bonuses and occasional Dual Strikes/Guards.

**Key Features**:
- Lead unit gets stat bonuses from support
- Dual Strike: Support unit sometimes attacks too
- Dual Guard: Support unit sometimes blocks damage
- Criticized for being "too strong" in Awakening

#### Weapon Triangle
Rock-paper-scissors advantage system (Sword > Axe > Lance > Sword).

**Fan Opinions (Mixed)**:
- Pro: "Adds positioning strategy"
- Con: "Becomes irrelevant late-game due to stat inflation"
- Three Houses removed it; Engage brought it back with "Break" mechanic
- Some prefer Berwick Saga's approach: unique weapon properties without RPS

#### Battalions and Gambits (Three Houses)
Units equip battalions providing stat bonuses and gambit attacks.

**Mechanics**:
- Gambits have AoE effects
- Cannot be counterattacked
- Cause "Rattled" status (stat penalty, prevents movement)
- Level up with use

### 1.2 Shining Force Mechanics and Mod Improvements

#### Aura Spell (SF2 - Verified)
The **Aura** spell is a defensive healing spell that heals multiple allies near the caster. The Vicar class (promoted Priest) specializes in this:
- Aura Level 1-3: Heal nearby allies in increasing radius
- Aura Level 4: Full HP restoration to ALL allies on battlefield
- More MP-efficient than Heal when 3+ allies are affected

This is NOT an aura in the passive sense - it's an active AoE heal spell. However, the concept of area-affecting support is highly valued.

#### Class-Based Combat Rates (SF2)
- **Counter Rate**: Class determines chance (3%, 6%, 12%, or 25%)
- **Double Attack Rate**: Class determines chance
- **Critical Rate**: Weapon skill level affects chance (20%/30%/40%)

#### Weapon Skill Levels (SF3)
Each weapon type has skill levels (0-3) that unlock special attacks and improve crit rate.

#### Shining Force Alternate Improvements
This romhack added:
- New abilities and ranges for non-magic users
- Improved AI that uses abilities strategically
- Training feature for catching up underleveled characters
- Poison does more damage per turn
- More aggressive enemy AI using status effects

#### SF2 Maeson Improvements
- Every class can use some magic (more versatility)
- Offensive spells strengthened significantly
- Status effects more accurate and threatening
- Extended spell ranges
- RNG removed from turn order (pure Agility)

#### Fan Wishlist (Shining Force Central)
- XP carry over when leveling
- Better item management/display
- Show attack predictions before combat
- Turn order display
- Alternative promotion paths (like SF2)
- Free roam instead of chapter-based (SF2 model - we have this!)
- Ability information in-game

### 1.3 Design Principles from Tactical RPG Communities

#### What Makes Abilities "Tactical" vs "Menu Bloat"

**Good Design**:
- Passives that enable unique playstyles (not just "+5 damage")
- Skills with interesting activation conditions
- Visible effects that inform tactical decisions
- Skills that interact with positioning/terrain
- Clear feedback when skills activate

**Bad Design**:
- Too many percentage-based passive bonuses
- Skills that require extensive menu diving
- Invisible modifiers players forget exist
- Power creep that invalidates positioning
- Skills that make certain characters auto-pick

#### Balance Considerations
- Keep passive bonuses modest (5-10% range)
- Activation-based skills more interesting than always-on
- Personal skills should define playstyle, not dominate
- Class skills should reinforce class identity
- Avoid "must-have" skills that warp team composition

---

## Part 2: Ability Type Taxonomy

### 2.1 Proposed Ability Categories

```
AbilityCategory
  ACTIVE          # Requires action to use (spells, combat arts)
  PASSIVE         # Always active, modifies stats or mechanics
  TRIGGERED       # Activates automatically under conditions
  AURA            # Affects nearby units (can be ally or enemy)
  REACTION        # Activates in response to events (counter, guard)
```

### 2.2 Detailed Category Breakdown

#### ACTIVE Abilities (Existing System - Extend)
Current `AbilityData` covers this. Extensions needed:
- Combat Arts (weapon-based special attacks)
- Gambits (AoE effects that can't be countered)
- MP cost, HP cost, or uses-per-battle cost

#### PASSIVE Abilities (New)
Always-on effects that modify unit capabilities:
- **Stat Modifiers**: +STR, +DEF, +AGI, etc.
- **Rate Modifiers**: +Crit%, +Counter%, +Double Attack%
- **Conditional Bonuses**: "When HP < 50%, +10 DEF"
- **Immunity**: Immune to poison, immune to criticals

#### TRIGGERED Abilities (New)
Activate when specific conditions are met:
- **Vantage**: When HP < 50%, attack first when attacked
- **Miracle**: When taking lethal damage, survive with 1 HP (once per battle)
- **Pursuit**: When AGI > enemy AGI by 5+, double attack guaranteed
- **Wrath**: When HP < 25%, guaranteed critical

#### AURA Abilities (New)
Provide effects to units within range:
- **Commander Aura**: Allies within 2 tiles get +2 ATK
- **Intimidate Aura**: Enemies within 2 tiles get -2 DEF
- **Healing Aura**: Allies within 1 tile heal 5 HP at turn start
- **Zone of Control**: Enemies within 1 tile cannot move through

#### REACTION Abilities (New)
Respond to combat events:
- **Counter** (existing in class): Counterattack on defense
- **Dual Guard**: Chance to negate damage when adjacent to ally
- **Revenge**: Deal bonus damage after taking damage
- **Aegis**: Chance to halve magic damage

### 2.3 Ability Source Types

Where abilities come from (for UI display and balance):

```
AbilitySource
  INNATE          # Character's personal ability (1 per character)
  CLASS           # From current class
  CLASS_MASTERY   # Retained after mastering a class (FE-style)
  EQUIPMENT       # Granted by equipped item
  STATUS          # Temporary from buff/debuff
  TERRAIN         # Granted by current terrain
```

---

## Part 3: Core Architecture

### 3.1 Extended AbilityData Resource

The existing `AbilityData` should be extended to support the new categories:

```gdscript
# core/resources/ability_data.gd (Extended)
class_name AbilityData
extends Resource

enum AbilityCategory {
    ACTIVE,
    PASSIVE,
    TRIGGERED,
    AURA,
    REACTION
}

enum TriggerCondition {
    NONE,                    # For active abilities
    ALWAYS,                  # Passive always-on
    HP_BELOW_PERCENT,        # e.g., Vantage at HP < 50%
    HP_ABOVE_PERCENT,        # e.g., Full HP bonuses
    TURN_START,              # At start of unit's turn
    TURN_END,                # At end of unit's turn
    ON_ATTACK,               # When attacking
    ON_DEFEND,               # When being attacked
    ON_KILL,                 # After defeating enemy
    ON_TAKE_DAMAGE,          # After receiving damage
    ADJACENT_TO_ALLY,        # When next to ally
    ADJACENT_TO_ENEMY,       # When next to enemy
    NO_ADJACENT_ALLY,        # When isolated
    FIRST_COMBAT,            # First combat each battle
    CUSTOM                   # Uses custom script
}

# Existing fields remain...
@export var ability_category: AbilityCategory = AbilityCategory.ACTIVE
@export var trigger_condition: TriggerCondition = TriggerCondition.NONE
@export var trigger_threshold: int = 50  # For HP_BELOW/ABOVE_PERCENT

@export_group("Passive Effects")
@export var stat_modifiers: Dictionary = {}  # {"strength": 3, "defense": -1}
@export var rate_modifiers: Dictionary = {}  # {"crit_rate": 10, "counter_rate": 5}

@export_group("Aura Configuration")
@export var aura_range: int = 0  # 0 = not an aura, 1+ = tile radius
@export var aura_affects_allies: bool = true
@export var aura_affects_enemies: bool = false
@export var aura_affects_self: bool = false

@export_group("Advanced")
@export var custom_script: GDScript  # For complex behaviors
@export var stacks_with_same: bool = false  # Can multiple instances stack?
@export var max_stacks: int = 1
@export var uses_per_battle: int = -1  # -1 = unlimited
```

### 3.2 New PassiveSkillData Resource

For simpler passive skills that don't need full AbilityData complexity:

```gdscript
# core/resources/passive_skill_data.gd
class_name PassiveSkillData
extends Resource

@export var skill_name: String = ""
@export var skill_id: String = ""  # For mod referencing
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Trigger")
@export var trigger_condition: AbilityData.TriggerCondition = AbilityData.TriggerCondition.ALWAYS
@export var trigger_threshold: int = 50

@export_group("Effects")
@export var stat_modifiers: Dictionary = {}
@export var rate_modifiers: Dictionary = {}
@export var grants_immunity: Array[String] = []  # ["poison", "sleep"]
@export var grants_ability: String = ""  # ID of ability this unlocks

@export_group("Script Override")
@export var custom_script: GDScript
```

### 3.3 CharacterData Extensions

```gdscript
# Additional exports for CharacterData
@export_group("Personal Abilities")
## Character's unique personal skill (like FE personal skills)
## Leave null for characters without personal skills
@export var personal_skill: PassiveSkillData

## Character-specific unique abilities (EXCEPTIONS ONLY)
## Most spells come from ClassData.class_abilities, NOT here
## Use for: Domingo's innate Freeze, hero special powers, unique character skills
@export var unique_abilities: Array[AbilityData] = []
```

**Spell Resolution at Runtime**:
```gdscript
func get_available_spells(character: CharacterData, level: int) -> Array[AbilityData]:
    var spells: Array[AbilityData] = []

    # 1. Class abilities (primary source)
    if character.character_class:
        for ability in character.character_class.class_abilities:
            var unlock_level: int = character.character_class.ability_unlock_levels.get(ability.ability_id, 1)
            if level >= unlock_level:
                spells.append(ability)

    # 2. Character unique abilities (rare exceptions)
    spells.append_array(character.unique_abilities)

    return spells
```

### 3.4 ClassData Extensions

```gdscript
# Additional exports for ClassData
@export_group("Active Abilities (Spells)")
## Active spells/abilities granted by this class (PRIMARY spell source)
## Characters get their spells from their class, not individually
@export var class_abilities: Array[AbilityData] = []

## Level requirements for each ability {"ability_id": level_required}
## Abilities not in this dict are available at level 1
@export var ability_unlock_levels: Dictionary = {}  # {"heal_2": 12, "heal_3": 20}

@export_group("Passive Skills")
## Passive skills granted by this class
@export var class_skills: Array[PassiveSkillData] = []

## Skill granted upon mastering this class (retained after changing)
## Leave null if class has no mastery skill
@export var mastery_skill: PassiveSkillData

## XP required to master this class (0 = cannot master)
@export var mastery_xp_required: int = 0
```

**Example Class Spell Lists**:
- MAGE: `[blaze_1, blaze_2, blaze_3, blaze_4]` with unlock levels `{blaze_2: 8, blaze_3: 16, blaze_4: 24}`
- PRIEST: `[heal_1, heal_2, heal_3, heal_4]` with unlock levels `{heal_2: 8, heal_3: 16, heal_4: 24}`
- WIZARD (promoted MAGE): Inherits MAGE spells + adds `[freeze_1, freeze_2]`

### 3.5 Ability Registry

Following the existing registry pattern:

```gdscript
# core/registries/ability_type_registry.gd
class_name AbilityTypeRegistry
extends RefCounted

const DEFAULT_ABILITY_TYPES: Array[String] = [
    "attack", "heal", "support", "debuff", "special",
    "passive", "triggered", "aura", "reaction"
]

const DEFAULT_TRIGGER_CONDITIONS: Array[String] = [
    "always", "hp_below", "hp_above", "turn_start", "turn_end",
    "on_attack", "on_defend", "on_kill", "adjacent_ally", "custom"
]

var _mod_ability_types: Dictionary = {}
var _mod_trigger_conditions: Dictionary = {}
# ... standard registry pattern
```

---

## Part 4: Trigger System

### 4.1 Ability Trigger Manager

A new system to evaluate and execute ability triggers:

```gdscript
# core/systems/ability_trigger_manager.gd
extends Node

signal passive_activated(unit: Node2D, ability: AbilityData)
signal aura_effect_applied(source: Node2D, target: Node2D, ability: AbilityData)
signal triggered_ability_fired(unit: Node2D, ability: AbilityData, context: Dictionary)

## Called at battle start to initialize passive effects
func initialize_unit_passives(unit: Node2D) -> void

## Called when checking combat modifiers
func get_combat_modifiers(attacker: Node2D, defender: Node2D) -> Dictionary

## Called to check trigger conditions
func check_triggers(unit: Node2D, event: String, context: Dictionary) -> Array[AbilityData]

## Called to apply aura effects to nearby units
func apply_aura_effects(source: Node2D, aura: AbilityData) -> void

## Called to recalculate all auras when units move
func recalculate_auras() -> void
```

### 4.2 Trigger Event Types

Events that can fire ability triggers:

| Event | Context Data | Example Abilities |
|-------|-------------|-------------------|
| `battle_start` | {} | "First Strike" bonus |
| `turn_start` | {turn_number} | Regen, poison damage |
| `turn_end` | {turn_number} | End-of-turn healing |
| `before_attack` | {target, distance} | Vantage, accuracy boosts |
| `after_attack` | {target, damage, killed} | Kill bonuses, Astra |
| `before_defend` | {attacker, distance} | Defense boosts |
| `after_defend` | {attacker, damage} | Revenge, counter boosts |
| `unit_moved` | {from, to, path} | Aura recalculation |
| `hp_changed` | {old_hp, new_hp, percent} | Wrath, Defiant skills |
| `ally_adjacent` | {ally} | Support bonuses |
| `enemy_adjacent` | {enemy} | Intimidation effects |

### 4.3 Integration with CombatCalculator

The `CombatCalculator` will need hooks for ability modifiers:

```gdscript
# In CombatCalculator - new static methods

## Get total stat modifier from all active abilities
static func get_ability_stat_modifier(
    unit_stats: UnitStats,
    stat_name: String,
    context: Dictionary
) -> int

## Get total rate modifier (crit, counter, double attack)
static func get_ability_rate_modifier(
    unit_stats: UnitStats,
    rate_name: String,
    context: Dictionary
) -> int

## Check if any ability grants advantage/disadvantage
static func check_ability_advantages(
    attacker_stats: UnitStats,
    defender_stats: UnitStats
) -> Dictionary
```

---

## Part 5: Aura System

### 5.1 Aura Controller

Manages active auras and their effects:

```gdscript
# core/systems/aura_controller.gd
extends Node

## Active aura sources: {unit_instance_id: Array[AbilityData]}
var _active_auras: Dictionary = {}

## Cached aura effects on targets: {unit_instance_id: Array[AuraEffect]}
var _aura_effects: Dictionary = {}

## Register a unit's auras when they enter battle
func register_unit_auras(unit: Node2D) -> void

## Unregister when unit dies or leaves
func unregister_unit_auras(unit: Node2D) -> void

## Recalculate all aura effects (call after any unit moves)
func recalculate_all_auras() -> void

## Get aura effects currently affecting a unit
func get_aura_effects_on_unit(unit: Node2D) -> Array[AuraEffect]
```

### 5.2 AuraEffect Data Class

```gdscript
# core/resources/aura_effect.gd
class_name AuraEffect
extends RefCounted

var source_unit: Node2D
var source_ability: AbilityData
var stat_modifiers: Dictionary = {}
var rate_modifiers: Dictionary = {}

func get_description() -> String:
    return "%s from %s" % [source_ability.ability_name, source_unit.get_display_name()]
```

### 5.3 Aura Stacking Rules

To prevent runaway stacking (a common balance issue):

1. **Same-Source Rule**: A unit can only benefit from each unique ability once
2. **Category Caps**: Maximum total bonus per stat from auras (e.g., +10 max from all auras)
3. **Priority System**: Higher-tier auras override lower-tier (not stack)

Configuration in ExperienceConfig or a new AbilityConfig:

```gdscript
@export_group("Aura Balance")
@export var max_aura_stat_bonus: int = 10  # Cap per stat
@export var aura_stacking_mode: String = "best_only"  # "additive", "best_only", "first_only"
```

### 5.4 Aura Visualization

Auras should be visible on the battlefield for tactical clarity:

1. **Source Indicator**: Subtle glow or icon on aura-providing units
2. **Range Indicator**: When selecting unit, show aura range (like movement range)
3. **Effect Indicator**: Small icons on affected units showing active aura bonuses
4. **Toggle Option**: Let players toggle aura visualization on/off

---

## Part 6: Mod Integration

### 6.1 mod.json Configuration

Mods can register custom ability types and trigger conditions:

```json
{
  "id": "advanced_skills",
  "name": "Advanced Skills Pack",
  "custom_ability_types": ["gambit", "combat_art", "battalion"],
  "custom_trigger_conditions": ["below_half_mp", "terrain_forest", "weather_rain"],
  "ability_type_scripts": {
    "gambit": "res://mods/advanced_skills/scripts/gambit_handler.gd"
  }
}
```

### 6.2 AbilityData Discovery

Abilities are auto-discovered from `mods/*/data/abilities/`:

```
mods/
  _base_game/
    data/
      abilities/
        heal_1.tres      # Heal Level 1
        blaze_1.tres     # Blaze Level 1
        # ... active spells
      passive_skills/    # NEW directory
        vantage.tres
        paragon.tres
        # ... passive skills
```

### 6.3 Custom Ability Scripts

For complex abilities that can't be data-driven:

```gdscript
# Example: mods/advanced_skills/scripts/abilities/miracle.gd
extends AbilityScript

## Called when trigger condition is met
func on_trigger(unit: Node2D, context: Dictionary) -> bool:
    # Check if this is lethal damage
    var damage: int = context.get("damage", 0)
    var current_hp: int = unit.stats.current_hp

    if damage >= current_hp:
        # Survive with 1 HP instead
        unit.stats.current_hp = 1
        # Mark as used (once per battle)
        mark_used(unit)
        return true  # Ability activated
    return false
```

### 6.4 Total Conversion Support

Mods can completely replace the ability system:

```json
{
  "id": "total_conversion",
  "load_priority": 9000,
  "replace_systems": {
    "ability_trigger_manager": "res://mods/total_conversion/systems/my_ability_system.gd"
  },
  "hidden_ability_types": ["*"],  # Hide all base types
  "custom_ability_types": ["spell", "technique", "limit_break"]
}
```

---

## Part 7: Base Game Scope

### 7.1 What _base_game Should Demonstrate

The base game mod should include minimal but complete examples:

#### Active Abilities (Existing - Keep Simple)
- Heal Levels 1-4
- Blaze Levels 1-4
- Freeze Levels 1-4
- Bolt Levels 1-4
- Basic attack abilities per weapon type

#### Passive Skills (New - SF-Authentic)
Only class-intrinsic passives that match SF style:
- **Flying** (Birdman/Pegasus): Ignore terrain movement costs
- **Aquatic** (Merman): Move freely in water
- **Undead** (Vampire): Immune to poison, weak to holy

#### Triggered Abilities (New - Minimal)
Only the most iconic that SF already implies:
- **Counter** (already in ClassData as rate)
- **Double Attack** (already in ClassData as rate)
- **Critical Hit** (already exists as rate)

#### Auras (New - Optional Example)
One example aura to demonstrate the system:
- **Hero's Inspiration** (Hero only): Allies within 2 tiles +1 ATK
- This is OPTIONAL - base game works fine without it

### 7.2 What Should Be Left to Mods

#### Advanced FE-Style Skills (_sandbox or skill pack mods)
- Vantage, Wrath, Miracle, etc.
- Personal skills per character
- Class mastery skills
- Skill inheritance

#### Weapon Triangle (_fe_mechanics mod)
- Sword > Axe > Lance > Sword
- Magic triangle variant
- Break mechanic from Engage

#### Support System (_relationship_mod)
- Support conversations
- Support rank bonuses
- Pair Up / Dual System

#### Battalions/Gambits (_battalion_mod)
- Battalion equipping
- Gambit attacks
- Rattled status

---

## Part 8: Implementation Phases

### Phase 1: Foundation (Core Infrastructure)
**Goal**: Extend AbilityData and create registry

1. Extend `AbilityData` with new enums and fields
2. Create `PassiveSkillData` resource
3. Create `AbilityTypeRegistry` following existing patterns
4. Update ModLoader to discover passive skills
5. Write unit tests for new resource types

**Deliverables**:
- Extended AbilityData
- PassiveSkillData resource
- AbilityTypeRegistry
- Unit tests

### Phase 2: Passive System
**Goal**: Passives work and affect combat

1. Extend `CharacterData` with personal_skill field
2. Extend `ClassData` with class_skills array
3. Create `AbilityTriggerManager` singleton
4. Integrate with `UnitStats` for stat modifiers
5. Integrate with `CombatCalculator` for rate modifiers
6. Write integration tests

**Deliverables**:
- Working passive stat/rate modifiers
- Trigger condition evaluation
- Integration tests

### Phase 3: Aura System
**Goal**: Auras provide range-based effects

1. Create `AuraController` singleton
2. Create `AuraEffect` data class
3. Implement aura range checking
4. Implement stacking rules
5. Add aura visualization toggle
6. Write integration tests

**Deliverables**:
- Working aura effects
- Stacking configuration
- Basic visualization
- Integration tests

### Phase 4: Triggered Abilities
**Goal**: Abilities fire on events

1. Define trigger event system
2. Integrate triggers with combat flow
3. Add "Vantage" as reference implementation
4. Add "Miracle" as reference implementation
5. Support custom trigger scripts
6. Write integration tests

**Deliverables**:
- Event-driven trigger system
- Reference triggered abilities
- Script support
- Integration tests

### Phase 5: UI and Polish
**Goal**: Players can see and understand abilities

1. Add ability icons to unit info panel
2. Add passive skill display in battle forecast
3. Add aura range visualization (toggle)
4. Add aura effect indicators on units
5. Add trigger activation visual feedback
6. Manual testing and polish

**Deliverables**:
- Complete UI integration
- Visual feedback for all ability types
- Player-facing documentation

### Phase 6: Editor Integration
**Goal**: Easy ability creation in Sparkling Editor

1. Add PassiveSkillData editor panel
2. Add ability assignment UI for Characters
3. Add class skill configuration UI
4. Add aura preview in battle editor
5. Add trigger condition wizard

**Deliverables**:
- Editor support for all ability features
- In-editor documentation

---

## Part 9: Balance Guidelines for Modders

### 9.1 Stat Modifier Guidelines

| Modifier Type | Weak | Moderate | Strong | Overpowered |
|--------------|------|----------|--------|-------------|
| STR/DEF/etc. | +1-2 | +3-4 | +5-6 | +7+ |
| Crit Rate | +3-5% | +8-10% | +12-15% | +20%+ |
| Counter Rate | +3-5% | +8-10% | +12-15% | +20%+ |
| Damage % | +5-10% | +15-20% | +25-30% | +40%+ |

### 9.2 Activation Condition Guidelines

**Reliable** (Always/Easy to achieve):
- Keep effects modest (+1-2 stats)
- Example: "Adjacent to ally: +1 DEF"

**Conditional** (Sometimes achievable):
- Can be moderate (+3-4 stats)
- Example: "HP below 50%: +3 ATK"

**Rare** (Hard to achieve/maintain):
- Can be strong (+5-6 stats)
- Example: "First combat of battle: +5 ATK, guaranteed hit"

### 9.3 Aura Balance Guidelines

- Range 1: Strong effects OK (adjacent only)
- Range 2: Moderate effects (small group)
- Range 3+: Weak effects only (large group)
- Global auras: Very weak or with drawbacks

### 9.4 Common Balance Mistakes to Avoid

1. **Stacking multipliers**: Multiple +50% damage sources become +200%+
2. **Guaranteed criticals**: Trivializes tactical decisions
3. **Free actions**: Extra attacks without drawbacks
4. **Immunity stacking**: Becoming immune to everything
5. **Must-have skills**: Skills so good every unit needs them

---

## Part 10: Technical Notes

### 10.1 Performance Considerations

- Cache aura calculations (only recalculate when units move)
- Use spatial hashing for aura range queries if unit count > 30
- Lazy evaluation of trigger conditions (only check when relevant)
- Pool aura effect objects to avoid GC pressure

### 10.2 Save/Load Considerations

New data to persist:
- Class mastery progress per character
- Triggered ability use counts (per battle)
- Active status effect abilities

### 10.3 Networking Considerations (Future)

If multiplayer is added:
- All ability calculations must be deterministic
- Trigger order must be consistent
- Aura effects sync with unit positions

### 10.4 Compatibility Notes

This system is designed to be backwards-compatible:
- Existing AbilityData resources work unchanged
- New fields have sensible defaults
- Mods without abilities still function

---

## Appendix A: Research Sources

### Fire Emblem Resources
- [Fire Emblem Wiki - Skills](https://fireemblem.fandom.com/wiki/Skills)
- [Serenes Forest - Three Houses Abilities](https://serenesforest.net/three-houses/miscellaneous/abilities/)
- [Fire Emblem Wiki - Pair Up](https://fireemblem.fandom.com/wiki/Pair_Up)
- [Fire Emblem Wiki - Support](https://fireemblem.fandom.com/wiki/Support)
- [Fire Emblem Wiki - Weapon Triangle](https://fireemblem.fandom.com/wiki/Weapon_Triangle)
- [Fire Emblem Universe - Skill Balance Discussion](https://feuniverse.us/t/how-do-you-balance-skills/12098)
- [Fire Emblem Wiki - Battalions](https://fireemblem.fandom.com/wiki/Gambit)

### Shining Force Resources
- [Shining Wiki - Vicar Class](https://shining.fandom.com/wiki/Vicar)
- [Shining Wiki - Aura Spell](https://shining.fandom.com/wiki/Aura)
- [Shining Force Mods - SF Alternate](https://sfmods.com/resources/shining-force-alternate.167/)
- [Shining Force Central - Critical Rates](https://forums.shiningforcecentral.com/viewtopic.php?t=48497)
- [Shining Force Central - Counter/Double/Crit](https://forums.shiningforcecentral.com/viewtopic.php?t=17212)
- [Shining Force Central - Fan Wishlist](https://forums.shiningforcecentral.com/viewtopic.php?t=50480)
- [SF Mods - Community Patch Suggestions](https://sfmods.com/threads/shining-force-community-patch-suggestions.77/)
- [ROMHacking - SF2 Maeson](https://www.romhacking.net/hacks/3271/)

---

## Appendix B: Example Ability Definitions

### Personal Skill Example (Philanderer-style)

```tres
[gd_resource type="PassiveSkillData"]
[resource]
skill_name = "Charming"
skill_id = "charming"
description = "Gains +2 ATK when adjacent to opposite-gender ally."
trigger_condition = 4  # ADJACENT_TO_ALLY
stat_modifiers = {"strength": 2}
# Note: Gender check would require custom_script
```

### Class Skill Example (Canto)

```tres
[gd_resource type="PassiveSkillData"]
[resource]
skill_name = "Canto"
skill_id = "canto"
description = "Can move remaining distance after attacking."
trigger_condition = 1  # ALWAYS (handled specially by movement system)
# Canto is a special skill that requires code integration
custom_script = preload("res://mods/_sandbox/scripts/abilities/canto.gd")
```

### Aura Example (Commander)

```tres
[gd_resource type="AbilityData"]
[resource]
ability_name = "Commander's Presence"
ability_category = 3  # AURA
trigger_condition = 1  # ALWAYS
aura_range = 2
aura_affects_allies = true
aura_affects_enemies = false
aura_affects_self = false
stat_modifiers = {"strength": 2, "defense": 1}
description = "Allies within 2 tiles gain +2 ATK and +1 DEF."
```

### Triggered Ability Example (Vantage)

```tres
[gd_resource type="AbilityData"]
[resource]
ability_name = "Vantage"
ability_category = 2  # TRIGGERED
trigger_condition = 5  # ON_DEFEND (when being attacked)
trigger_threshold = 50  # HP below 50%
description = "When HP is below 50%, attack first when attacked."
# Vantage requires special combat flow integration
custom_script = preload("res://core/scripts/abilities/vantage.gd")
```

---

*Live long and balance your skills wisely.*
