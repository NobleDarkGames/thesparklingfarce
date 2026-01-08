---
name: resource-access
description: Correct patterns for accessing game resources via ModLoader registry. Use when loading characters, items, abilities, or any mod content.
---

## Resource Access Patterns

The Sparkling Farce uses a registry system for all game content access. This enables mod overrides and prevents hardcoded dependencies.

### The Rule

```gdscript
# CORRECT - Uses registry, supports mod overrides
ModLoader.registry.get_resource("character", "max")

# WRONG - Bypasses mod system, breaks overrides
load("res://mods/_base_game/data/characters/max.tres")
```

### Why This Matters

1. **Mod Overrides**: Higher-priority mods can replace resources
2. **No Hardcoded Paths**: Content can move between mods
3. **Validation**: Registry validates resources exist
4. **Tracking**: System knows which mod provided each resource

### Registry Access Methods

```gdscript
# Generic access
ModLoader.registry.get_resource(type: String, id: String) -> Resource

# Type-safe getters (preferred)
ModLoader.registry.get_character(id: String) -> CharacterData
ModLoader.registry.get_item(id: String) -> ItemData
ModLoader.registry.get_ability(id: String) -> AbilityData
ModLoader.registry.get_class(id: String) -> ClassData
ModLoader.registry.get_battle(id: String) -> BattleData
ModLoader.registry.get_map(id: String) -> MapMetadata
ModLoader.registry.get_cinematic(id: String) -> CinematicData
ModLoader.registry.get_dialogue(id: String) -> DialogueData
ModLoader.registry.get_npc(id: String) -> NPCData
ModLoader.registry.get_shop(id: String) -> ShopData
```

### Type Registries

For type definitions (not content), use type registries:

```gdscript
ModLoader.equipment_registry.get_slot(slot_id: String)
ModLoader.terrain_registry.get_terrain(terrain_id: String)
ModLoader.status_effect_registry.get_effect(effect_id: String)
ModLoader.ai_brain_registry.get_brain(brain_id: String)
```

### When Direct Load IS Acceptable

Only for **core platform resources** that mods should never override:

```gdscript
# OK - Core platform scripts/resources
const CharacterDataScript = preload("res://core/resources/character_data.gd")

# OK - Platform UI components
var scene = load("res://scenes/ui/components/modal_base.tscn")
```

### Content Placement

| Type | Location |
|------|----------|
| Game content | `mods/*/data/` |
| Platform code | `core/` |
| Never | Game content in `core/` |

### Checking Resource Existence

```gdscript
# Check before access
if ModLoader.registry.has_resource("character", character_id):
    var char_data: CharacterData = ModLoader.registry.get_character(character_id)
```
