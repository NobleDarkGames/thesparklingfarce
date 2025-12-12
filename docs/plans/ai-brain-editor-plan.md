# AI Brain Editor Plan

**Date:** 2025-12-11
**Contributors:** Lt. Clauderina (UI/UX), Ed (Editor Plugin Specialist)
**Source:** Lt. Ears AI Intelligence Report

---

## Executive Summary

This plan outlines the design for an AI Brain Editor within the Sparkling Farce editor. The goal is to allow modders to create sophisticated AI behaviors **without writing code**, addressing the gap between the current 2-mode system (aggressive/stationary) and Lt. Ears' recommendations for role-based, configurable AI.

---

## Current State

### Existing AI System

**Location:** `core/resources/ai_brain.gd` (base class), `mods/_base_game/ai_brains/`

**Current Brains:**
- `AIAggressive` - Always moves toward and attacks nearest player
- `AIStationary` - Never moves, only attacks adjacent enemies

**Architecture Strengths:**
- Clean separation: AIBrain (content) vs AIController (engine)
- Mod-friendly: Brains live in `mods/*/ai_brains/` with registry support
- Stateless design: No persistent state between turns
- Context-driven: All decisions based on battlefield dictionary

**Gaps:**
- No visual editor for AI brains
- Current brains are script-only (requires coding)
- No preset system for common behaviors
- No threat weight configuration
- No retreat threshold tuning
- No ability usage rules

---

## Recommended Architecture

### Plugin Type: Dedicated Editor Tab

**Justification:**
1. Consistency with existing editors (Characters, Classes, Items, Abilities, Battles, Parties)
2. Complexity requires dedicated editing space (role, mode, threat weights, ability rules)
3. Visual sliders and form controls need proper layout
4. Proven patterns for cross-mod resource viewing and override creation

**Why NOT other approaches:**
- Inspector Plugin: Too cramped for multi-section forms
- Dock Panel: Better for auxiliary tools, not primary editing
- Separate Window: Breaks integrated workflow

---

## New Resource: AIBehaviorData

**File:** `core/resources/ai_behavior_data.gd`

Separates **data** (configurable parameters) from **code** (execution logic).

```gdscript
class_name AIBehaviorData
extends Resource

# =============================================================================
# IDENTITY
# =============================================================================
@export var behavior_id: String = ""
@export var display_name: String = ""
@export var description: String = ""

# =============================================================================
# ROLE & MODE (Core AI Personality)
# =============================================================================

## The unit's tactical role
## - SUPPORT: Prioritize healing/buffing allies
## - AGGRESSIVE: Prioritize dealing damage, pursue enemies
## - DEFENSIVE: Protect high-value targets, hold terrain
## - TACTICAL: Complex spell usage, debuffs, positioning
@export_enum("Support", "Aggressive", "Defensive", "Tactical") var role: int = 1

## Behavior mode within the role
## - AGGRESSIVE: Full commitment, chase targets
## - CAUTIOUS: Hold terrain, wait for engagement
## - OPPORTUNISTIC: Target wounded units, retreat when threatened
@export_enum("Aggressive", "Cautious", "Opportunistic") var behavior_mode: int = 0

# =============================================================================
# THREAT ASSESSMENT WEIGHTS
# =============================================================================
@export_range(0.0, 2.0) var wounded_target_priority: float = 1.0
@export_range(0.0, 2.0) var damage_dealer_priority: float = 1.0
@export_range(0.0, 2.0) var healer_priority: float = 1.0
@export_range(0.0, 2.0) var proximity_priority: float = 1.0
@export var ignore_protagonist_priority: bool = true  # Avoids "obsessively attack Max"

# =============================================================================
# RETREAT & SELF-PRESERVATION
# =============================================================================
@export_range(0, 100) var retreat_hp_threshold: int = 30
@export var retreat_when_outnumbered: bool = true
@export var seek_healer_when_wounded: bool = true

# =============================================================================
# ABILITY USAGE RULES (Spells)
# =============================================================================
@export_range(1, 5) var aoe_minimum_targets: int = 2
@export var conserve_mp_on_heals: bool = true
@export var prioritize_boss_heals: bool = true
@export var use_status_effects: bool = true
@export var preferred_status_effects: Array[String] = []

# =============================================================================
# ITEM USAGE RULES
# =============================================================================
@export var use_healing_items: bool = true
@export var use_attack_items: bool = true
@export var use_buff_items: bool = false

# =============================================================================
# ENGAGEMENT RULES
# =============================================================================
@export_range(0, 20) var alert_range: int = 8
@export_range(0, 20) var engagement_range: int = 5
@export var seek_terrain_advantage: bool = true
@export_range(0, 99) var max_idle_turns: int = 0
```

---

## Architecture Diagram

```
                    EDITOR LAYER (addons/sparkling_editor/)
    +-------------------------------------------------------------+
    |  EditorTabRegistry                                          |
    |      |                                                      |
    |      +-- AI Brains Tab (ai_brain_editor.gd)                 |
    |              |                                              |
    |              +-- Extends base_resource_editor.gd            |
    |              +-- Lists AIBehaviorData resources             |
    |              +-- Visual form for all parameters             |
    |              +-- Role/Mode selectors                        |
    |              +-- Threat weight sliders                      |
    |              +-- Ability/Item rule toggles                  |
    |              +-- Preview panel showing behavior summary     |
    +-------------------------------------------------------------+
                              |
                              | Creates/Edits
                              v
                    CONTENT LAYER (mods/*/data/ai_behaviors/)
    +-------------------------------------------------------------+
    |  AIBehaviorData.tres files                                  |
    |    - aggressive_melee.tres                                  |
    |    - smart_healer.tres                                      |
    |    - defensive_tank.tres                                    |
    |    - tactical_mage.tres                                     |
    |    - opportunistic_archer.tres                              |
    +-------------------------------------------------------------+
                              |
                              | Referenced by
                              v
                    BATTLE CONFIGURATION
    +-------------------------------------------------------------+
    |  BattleData.tres                                            |
    |    enemies: [                                               |
    |      {character: goblin.tres, ai_behavior: aggressive.tres} |
    |      {character: priest.tres, ai_behavior: smart_healer.tres}|
    |    ]                                                        |
    |                                                             |
    |  CharacterData.tres                                         |
    |    default_ai_behavior: AIBehaviorData                      |
    +-------------------------------------------------------------+
                              |
                              | Consumed by
                              v
                    RUNTIME LAYER (core/systems/ai/)
    +-------------------------------------------------------------+
    |  AIController (autoload)                                    |
    |      +-- Builds context dictionary                          |
    |      +-- Passes AIBehaviorData to AIBrain                   |
    |                                                             |
    |  ConfigurableAIBrain (new)                                  |
    |      +-- Reads AIBehaviorData parameters                    |
    |      +-- ThreatEvaluator: calculates target scores          |
    |      +-- RoleBehaviors: Support, Aggressive, etc.           |
    |      +-- ActionSelectors: spell/item/movement logic         |
    +-------------------------------------------------------------+
```

---

## Template/Preset System

**Critical for accessibility.** Modders select a template, then tweak parameters.

| Template | Role | Mode | Key Settings |
|----------|------|------|--------------|
| **Smart Healer** | Support | Cautious | Boss heal priority, retreat at 40% |
| **Aggressive Melee** | Aggressive | Aggressive | High wounded priority, no retreat |
| **Defensive Tank** | Defensive | Cautious | Protect boss, hold terrain |
| **Tactical Mage** | Tactical | Opportunistic | AoE optimization, status effects |
| **Cowardly Archer** | Aggressive | Cautious | Retreat at 60%, self-preservation |
| **Berserker** | Aggressive | Aggressive | 0% retreat threshold, max damage |

---

## Editor UI Wireframe

```
+---------------+---------------------------------------------+
| Behaviors     | Behavior Details                            |
| (List)        |                                             |
|               | +- Basic Info -------------------------+    |
| [Search...]   | | Name: [Smart Healer______________]    |    |
|               | | Description: [Prioritizes healing...]|    |
| [New] [Dupe]  | | Base Template: [Support AI v]        |    |
|               | +-------------------------------------+    |
| * Aggressive  |                                             |
| * Stationary  | +- Role Configuration -----------------+    |
| > SmartHealer | | Role: [Support v]                    |    |
| * DefensiveTank| | Behavior Mode: [Cautious v]          |    |
| * TacticalMage| +-------------------------------------+    |
|               |                                             |
|               | +- Threat Assessment Weights ----------+    |
|               | | Wounded Targets:     [====--] 80%    |    |
|               | | High Damage Dealers: [===---] 60%    |    |
|               | | Proximity to Allies: [==----] 40%    |    |
|               | | Class Vulnerabilities:[===---] 70%   |    |
|               | +-------------------------------------+    |
|               |                                             |
|               | +- Retreat & Positioning --------------+    |
|               | | Retreat HP Threshold: [==----] 40%   |    |
|               | | [x] Retreat to healer range          |    |
|               | | [x] Avoid outnumbered (3:1)          |    |
|               | | [ ] Protect boss units               |    |
|               | +-------------------------------------+    |
|               |                                             |
|               | +- Ability Usage Rules ----------------+    |
|               | | Spell Priority: [AoE > Kill Shot v]  |    |
|               | | Item Usage:     [When healer dead v] |    |
|               | | Status Effects: [Debuff threats v]   |    |
|               | +-------------------------------------+    |
|               |                                             |
|               | +- Preview Behavior -------------------+    |
|               | | This AI will:                        |    |
|               | | * Prioritize healing wounded allies  |    |
|               | | * Retreat when below 40% HP          |    |
|               | | * Use items if healers are dead      |    |
|               | +-------------------------------------+    |
|               |                                             |
|               | [Save] [Delete] [Test in Simulator]         |
+---------------+---------------------------------------------+
```

---

## Battle Editor Integration

Enhance existing Enemy Forces section:

```
Enemy Forces
+-- Enemy #1 [^] [v] [X]
|   +-- Character: [Max Goblin v]
|   +-- Position: (5, 3) [Place on Map]
|   +-- AI Brain: [Smart Healer v] [Edit]  <-- NEW
|   +-- Preview: "Heals wounded allies, retreats at 40% HP"  <-- NEW
```

---

## File Structure

```
addons/sparkling_editor/ui/
  ai_brain_editor.gd          # Editor tab (extends base_resource_editor.gd)
  ai_brain_editor.tscn        # Editor tab scene

core/resources/
  ai_behavior_data.gd         # The moddable Resource class

core/systems/ai/
  configurable_ai_brain.gd    # Data-driven AIBrain implementation
  threat_evaluator.gd         # Static threat score calculations

mods/_base_game/data/ai_behaviors/
  aggressive_melee.tres       # Default aggressive behavior
  smart_healer.tres           # Healer with boss prioritization
  defensive_tank.tres         # Defensive with retreat disabled
  tactical_mage.tres          # Spell-focused with AoE optimization
  opportunistic_archer.tres   # Targets wounded, retreats when threatened
```

---

## ModLoader Integration

Add to `RESOURCE_TYPE_DIRS`:

```gdscript
const RESOURCE_TYPE_DIRS: Dictionary = {
    # ... existing entries ...
    "ai_behaviors": "ai_behavior",
}
```

Auto-discovers `.tres` files from `mods/*/data/ai_behaviors/`.

---

## Implementation Phases

### Phase 1: Foundation (MVP)
- Create `AIBehaviorData` resource class
- Create basic AI Brain Editor tab (identity, role, mode)
- Register with EditorTabRegistry and ModLoader
- Template system (5 basic presets)

### Phase 2: Battle Editor Integration
- AI Brain dropdown in enemy forces section
- Edit button linking to configurator
- Behavior preview label
- Save/load brain IDs in BattleData

### Phase 3: Runtime Implementation
- `ConfigurableAIBrain` with role-based execution
- Threat evaluation system
- Spell/item selection logic
- Retreat/positioning behaviors

### Phase 4: Polish
- Behavior preview panel (auto-generated text)
- AI battle simulator (test without full battle)
- Validation and conflict warnings
- Advanced scripting hooks

---

## Success Criteria

1. **0-to-AI in under 5 minutes** - Modder creates functional AI behavior without coding
2. **Templates feel good** - "Smart Healer" works out-of-box without tweaking
3. **80% of behaviors need no code** - Custom scripts are escape hatch, not requirement
4. **Dark Priest problem solved** - Support units actually support (heal boss, not self)
5. **No "obsessive Max targeting"** - Threat assessment uses tactical weights, not protagonist flags

---

## Technical Constraints

### What CAN Be Configured (Data-Driven)
- Threat weights for target selection
- Retreat thresholds and positioning rules
- Spell/item usage preferences
- Role-based decision templates
- MP conservation strategies

### What REQUIRES Custom Script
- Phase-based boss behavior (HP triggers different tactics)
- Conditional ability unlocks mid-battle
- Multi-turn combo setups
- Custom pathfinding algorithms
- Reactive counters to player actions

**Escape Hatch:** "Custom (Script)" template option with script path field.

---

## Backwards Compatibility

- Existing `AIBrain` scripts (`ai_aggressive.gd`, `ai_stationary.gd`) continue to work
- `ConfigurableAIBrain` is a new option, not a replacement
- `AIBrainRegistry` supports both script-based and data-driven brains

---

## Open Questions for Review

1. Should AIBehaviorData support inheritance/composition (base behavior + overrides)?
2. Should threat weights be exposed per-battle or only per-behavior?
3. How should the editor handle cross-mod behavior conflicts?
4. Should we support "behavior phases" (change tactics when HP < 50%) in data?

---

## Modro's Revisions (2025-12-11)

**Reviewer:** Modro (Mod Architect)
**Status:** Approved with required changes

Modro identified critical extensibility concerns that would prevent total conversion mods from adding new AI concepts. The following revisions are REQUIRED before implementation.

### Issue 1: Hardcoded Role/Mode Enums (CRITICAL)

**Problem:** The original plan used `@export_enum("Support", "Aggressive", "Defensive", "Tactical")` which prevents TC mods from adding new roles like "Hacking", "Psionic", "Berserker".

**Solution:** Use registry-based strings with `AIRoleRegistry` and `AIModeRegistry`.

```gdscript
# BEFORE (wrong - hardcoded enum)
@export_enum("Support", "Aggressive", "Defensive", "Tactical") var role: int = 1

# AFTER (correct - registry-based)
@export var role: String = "aggressive"  # Validated against AIRoleRegistry

# Registry populated from mod.json:
# "ai_roles": {
#   "hacking": {"display_name": "Hacking", "description": "Prioritizes disabling systems"}
# }
```

### Issue 2: Monolithic ConfigurableAIBrain (CRITICAL)

**Problem:** Role logic hardcoded in one class means mods cannot add new roles without overriding everything.

**Solution:** Pluggable role behavior scripts that mods register.

```gdscript
# AIRoleBehavior base class (core/systems/ai/)
class_name AIRoleBehavior
extends RefCounted

func evaluate_targets(unit: Node2D, context: Dictionary, behavior: AIBehaviorData) -> Array[Dictionary]:
    push_error("AIRoleBehavior.evaluate_targets() must be overridden")
    return []

func select_action(unit: Node2D, context: Dictionary, behavior: AIBehaviorData) -> Dictionary:
    push_error("AIRoleBehavior.select_action() must be overridden")
    return {}
```

Mods register role scripts in mod.json:
```json
"ai_roles": {
  "hacking": {
    "display_name": "Hacking",
    "description": "Prioritizes disabling enemy systems",
    "script_path": "ai_roles/hacking_role.gd"
  }
}
```

### Issue 3: Hardcoded Threat Weights

**Problem:** Fixed threat weight properties (`wounded_target_priority`, etc.) cannot accommodate custom factors.

**Solution:** Use Dictionary with extensible keys.

```gdscript
# BEFORE (wrong - fixed properties)
@export_range(0.0, 2.0) var wounded_target_priority: float = 1.0
@export_range(0.0, 2.0) var healer_priority: float = 1.0

# AFTER (correct - extensible dictionary)
@export var threat_weights: Dictionary = {
    "wounded_target": 1.0,
    "damage_dealer": 1.0,
    "healer": 1.0,
    "proximity": 1.0
}
# Mods can add: "psionic_power": 1.5, "hacking_vulnerability": 2.0
```

### Issue 4: Missing Behavior Inheritance

**Problem:** Every behavior must specify ALL parameters (massive duplication).

**Solution:** Support `base_behavior` reference with override semantics.

```gdscript
@export var base_behavior: AIBehaviorData = null  # Inherit from this
# Only non-default values need to be set - others inherit from base
```

Runtime resolution:
```gdscript
func get_effective_role() -> String:
    if role != "":
        return role
    if base_behavior:
        return base_behavior.get_effective_role()
    return "aggressive"  # Fallback default
```

### Issue 5: Missing Per-Battle Overrides

**Problem:** Same enemy type might behave differently in different battles (tutorial goblin vs late-game goblin).

**Solution:** Add `ai_overrides` to BattleData.enemies.

```gdscript
# In BattleData.enemies array:
{
    "character": goblin_data,
    "position": Vector2i(5, 3),
    "ai_behavior": "aggressive_melee",  # Base behavior
    "ai_overrides": {                    # Per-battle tweaks
        "retreat_hp_threshold": 50,      # More cautious in this battle
        "alert_range": 12                # Wider detection
    }
}
```

### Issue 6: Missing Behavior Phases

**Problem:** Boss phase changes (HP triggers different tactics) require custom scripts.

**Solution:** Add trigger-based phase system in data.

```gdscript
@export var behavior_phases: Array[Dictionary] = []
# Example:
# [
#   {"trigger": "hp_below", "value": 75, "changes": {"behavior_mode": "cautious"}},
#   {"trigger": "hp_below", "value": 25, "changes": {"role": "berserker", "retreat_enabled": false}},
#   {"trigger": "ally_died", "value": "boss_healer", "changes": {"prioritize_revenge": true}}
# ]
```

---

## Revised Resource: AIBehaviorData

Incorporating all of Modro's feedback:

```gdscript
class_name AIBehaviorData
extends Resource

# =============================================================================
# IDENTITY
# =============================================================================
@export var behavior_id: String = ""
@export var display_name: String = ""
@export var description: String = ""

# =============================================================================
# INHERITANCE
# =============================================================================
## Base behavior to inherit from (only override what differs)
@export var base_behavior: AIBehaviorData = null

# =============================================================================
# ROLE & MODE (Registry-Based, NOT Hardcoded Enums)
# =============================================================================

## The unit's tactical role - validated against AIRoleRegistry
## Default roles: "support", "aggressive", "defensive", "tactical"
## Mods can add: "hacking", "psionic", "berserker", etc.
@export var role: String = ""

## Behavior mode - validated against AIModeRegistry
## Default modes: "aggressive", "cautious", "opportunistic"
## Mods can add: "berserk", "protective", "evasive", etc.
@export var behavior_mode: String = ""

# =============================================================================
# THREAT ASSESSMENT WEIGHTS (Extensible Dictionary)
# =============================================================================
## Weights for target selection. Mods can add custom keys.
## Default keys: wounded_target, damage_dealer, healer, proximity
@export var threat_weights: Dictionary = {}

## Ignore protagonist priority (avoids "obsessively attack Max")
@export var ignore_protagonist_priority: bool = true

# =============================================================================
# RETREAT & SELF-PRESERVATION
# =============================================================================
@export_range(0, 100) var retreat_hp_threshold: int = 30
@export var retreat_when_outnumbered: bool = true
@export var seek_healer_when_wounded: bool = true
@export var retreat_enabled: bool = true

# =============================================================================
# ABILITY USAGE RULES (Spells)
# =============================================================================
@export_range(1, 5) var aoe_minimum_targets: int = 2
@export var conserve_mp_on_heals: bool = true
@export var prioritize_boss_heals: bool = true
@export var use_status_effects: bool = true
@export var preferred_status_effects: Array[String] = []

# =============================================================================
# ITEM USAGE RULES
# =============================================================================
@export var use_healing_items: bool = true
@export var use_attack_items: bool = true
@export var use_buff_items: bool = false

# =============================================================================
# ENGAGEMENT RULES
# =============================================================================
@export_range(0, 20) var alert_range: int = 8
@export_range(0, 20) var engagement_range: int = 5
@export var seek_terrain_advantage: bool = true
@export_range(0, 99) var max_idle_turns: int = 0

# =============================================================================
# BEHAVIOR PHASES (Trigger-Based State Changes)
# =============================================================================
## Phase triggers that modify behavior during battle
## Format: {"trigger": "hp_below", "value": 50, "changes": {"role": "berserker"}}
@export var behavior_phases: Array[Dictionary] = []

# =============================================================================
# EFFECTIVE VALUE RESOLUTION (Inheritance Support)
# =============================================================================

func get_effective_role() -> String:
    if not role.is_empty():
        return role
    if base_behavior:
        return base_behavior.get_effective_role()
    return "aggressive"


func get_effective_mode() -> String:
    if not behavior_mode.is_empty():
        return behavior_mode
    if base_behavior:
        return base_behavior.get_effective_mode()
    return "aggressive"


func get_effective_threat_weight(key: String, default: float = 1.0) -> float:
    if key in threat_weights:
        return threat_weights[key]
    if base_behavior:
        return base_behavior.get_effective_threat_weight(key, default)
    return default
```

---

## Revised File Structure

```
core/registries/
  ai_role_registry.gd           # Registry for AI roles (string-based, mod-extensible)
  ai_mode_registry.gd           # Registry for AI behavior modes

core/resources/
  ai_behavior_data.gd           # The moddable Resource class (revised)

core/systems/ai/
  ai_role_behavior.gd           # Base class for pluggable role behaviors
  configurable_ai_brain.gd      # Data-driven AIBrain that uses registries

mods/_base_game/
  ai_roles/                     # Role behavior scripts
    support_role.gd
    aggressive_role.gd
    defensive_role.gd
    tactical_role.gd
  data/ai_behaviors/            # AIBehaviorData .tres files
    aggressive_melee.tres
    smart_healer.tres
    defensive_tank.tres
    tactical_mage.tres

addons/sparkling_editor/ui/
  ai_brain_editor.gd            # Editor tab (extends base_resource_editor.gd)
  ai_brain_editor.tscn          # Editor tab scene
```

---

## Revised mod.json Schema

```json
{
  "ai_roles": {
    "hacking": {
      "display_name": "Hacking",
      "description": "Prioritizes disabling enemy systems and technology",
      "script_path": "ai_roles/hacking_role.gd"
    },
    "psionic": {
      "display_name": "Psionic",
      "description": "Uses mental powers, targets low-willpower enemies",
      "script_path": "ai_roles/psionic_role.gd"
    }
  },
  "ai_modes": {
    "berserk": {
      "display_name": "Berserk",
      "description": "Maximum aggression, ignores self-preservation"
    },
    "protective": {
      "display_name": "Protective",
      "description": "Stays near designated allies, intercepts threats"
    }
  },
  "ai_threat_factors": ["psionic_power", "hacking_vulnerability", "morale"]
}
```

---

## Answers to Open Questions

Based on Modro's review, the open questions are now resolved:

1. **Inheritance/Composition**: YES - `base_behavior` reference with override semantics
2. **Threat weights per-battle**: YES - `ai_overrides` in BattleData.enemies allows per-battle tweaks
3. **Cross-mod conflicts**: Use standard registry override pattern (higher priority wins)
4. **Behavior phases**: YES - `behavior_phases` array with trigger-based state changes

---

## Implementation Priority

Modro's revisions are REQUIRED for Phase 1 foundation to avoid locking in a non-extensible design:

1. **Phase 1A**: Create AIRoleRegistry, AIModeRegistry (follow existing registry patterns)
2. **Phase 1B**: Create AIBehaviorData with registry-based roles/modes and inheritance
3. **Phase 1C**: Create AIRoleBehavior base class
4. **Phase 1D**: Create AI Brain Editor tab
5. **Phase 2**: Battle Editor integration with ai_overrides
6. **Phase 3**: ConfigurableAIBrain runtime implementation with phase triggers
