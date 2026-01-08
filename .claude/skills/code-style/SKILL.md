---
name: code-style
description: GDScript coding standards for The Sparkling Farce. Use when writing or reviewing code for style compliance.
---

## Code Style Standards

The Sparkling Farce enforces strict GDScript style. These are **non-negotiable**.

### Strict Typing (REQUIRED)

```gdscript
# CORRECT - Explicit type annotation
var health: int = 100
var name: String = "Max"
var position: Vector2 = Vector2.ZERO
var items: Array[ItemData] = []
var stats: Dictionary[String, int] = {}

# WRONG - Type inference (walrus operator)
var health := 100
var name := "Max"
var position := Vector2.ZERO
```

**Why**: Project settings enforce `untyped_declaration = Error` and `infer_on_variant = Error`.

### Dictionary Checks

```gdscript
# CORRECT
if "key" in dict:
    var value = dict["key"]

if "key" not in dict:
    push_error("Missing key")

# WRONG
if dict.has("key"):
    var value = dict["key"]
```

### Function Signatures

```gdscript
# CORRECT - All parameters and return types annotated
func calculate_damage(attacker: Unit, defender: Unit, is_critical: bool = false) -> int:
    return 0

# WRONG - Missing types
func calculate_damage(attacker, defender, is_critical = false):
    return 0
```

### Loop Variables

```gdscript
# CORRECT - Typed loop variable
for item: ItemData in inventory:
    process(item)

for i: int in range(10):
    print(i)

for key: String in dict.keys():
    print(key)

# WRONG - Untyped loop variable
for item in inventory:
    process(item)
```

### Signal Syntax

```gdscript
# CORRECT - Direct signal emission
battle_started.emit(battle_data)
damage_dealt.emit(attacker, defender, amount)

# WRONG - String-based emission
emit_signal("battle_started", battle_data)
```

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Classes | PascalCase | `CharacterData`, `BattleManager` |
| Functions | snake_case | `calculate_damage()`, `get_active_unit()` |
| Variables | snake_case | `current_hp`, `active_units` |
| Constants | UPPER_SNAKE | `MAX_HP`, `DEFAULT_SPEED` |
| Private | _prefix | `_internal_state`, `_calculate_bonus()` |
| Signals | snake_case | `battle_started`, `unit_died` |

### Import Style

```gdscript
# Preload for constants (compile-time)
const CharacterData = preload("res://core/resources/character_data.gd")

# Load for runtime resources
var scene: PackedScene = load("res://scenes/battle/battle.tscn")
```

### Documentation

```gdscript
## Brief description of the class.
##
## Longer description if needed, explaining purpose,
## usage patterns, and integration notes.
class_name MyClass
extends Node

## Calculates damage between two units.
## 
## [param attacker]: The unit dealing damage
## [param defender]: The unit receiving damage
## [return]: The final damage amount after modifiers
func calculate_damage(attacker: Unit, defender: Unit) -> int:
    pass
```

### Reference

Full style guide: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html
