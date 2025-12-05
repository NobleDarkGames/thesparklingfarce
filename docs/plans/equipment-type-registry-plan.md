# EquipmentTypeRegistry Implementation Plan

**Status:** APPROVED - Ready for Implementation
**Date:** December 5, 2025
**Authors:** Lt. Claudbrain (Planning), Chief O'Brien (Architecture), Modro (Mod Architecture)
**Approved by:** Captain Obvious

---

## Executive Summary

Create an `EquipmentTypeRegistry` that maps equipment subtypes (sword, bow, ring) to categories (weapon, accessory). This enables modders to add new equipment types without modifying slot definitions, and supports total conversion mods with entirely custom equipment systems.

**Key Design Decisions:**
- Defaults live in `_base_game/mod.json`, NOT code (enables total replacement)
- Category wildcards supported: `weapon:*` matches any weapon subtype
- Additive merging by default; `replace_all: true` for total conversions
- Non-breaking: existing items continue to work unchanged

---

## The Problem

Current system has a type mismatch:
- Items declare: `equipment_type: "sword"`
- Slots accept: `accepts_types: ["weapon"]`
- These don't match, so swords don't appear in weapon slot dropdowns

**Quick fix applied:** Slots now list all subtypes explicitly. This works but doesn't scale for modders.

**Proper fix:** Registry maps subtypes to categories, slots accept categories.

---

## Architecture Overview

```
                    ┌─────────────────────────────────────┐
                    │       EquipmentTypeRegistry         │
                    │     (Populated from mod.json)       │
                    ├─────────────────────────────────────┤
                    │ Subtypes → Categories:              │
                    │   "sword" → "weapon"                │
                    │   "bow" → "weapon"                  │
                    │   "laser_rifle" → "weapon" (mod)    │
                    │   "ring" → "accessory"              │
                    └─────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────┐    ┌─────────────────────────────────────┐
│     ItemData           │    │       EquipmentSlotRegistry         │
│ equipment_type="bow"   │───►│                                     │
│                        │    │ Weapon slot accepts: ["weapon:*"]   │
└────────────────────────┘    │                                     │
                              │ Resolution:                         │
                              │   1. Direct match? No               │
                              │   2. "bow" → category "weapon"      │
                              │   3. "weapon" matches "weapon:*"? ✓ │
                              └─────────────────────────────────────┘
```

---

## mod.json Schema

### Adding New Subtypes (Most Common)

```json
{
  "custom_types": {
    "equipment_types": {
      "subtypes": {
        "laser_rifle": {
          "category": "weapon",
          "display_name": "Laser Rifle"
        },
        "plasma_pistol": {
          "category": "weapon",
          "display_name": "Plasma Pistol"
        }
      }
    }
  }
}
```

### Defining New Categories (Total Conversions)

```json
{
  "custom_types": {
    "equipment_types": {
      "replace_all": true,
      "subtypes": {
        "assault_rifle": {"category": "firearm", "display_name": "Assault Rifle"},
        "body_armor": {"category": "armor", "display_name": "Body Armor"},
        "neural_implant": {"category": "cybernetic", "display_name": "Neural Implant"}
      },
      "categories": {
        "firearm": {"display_name": "Firearm"},
        "armor": {"display_name": "Armor"},
        "cybernetic": {"display_name": "Cybernetic Implant"}
      }
    }
  }
}
```

### Base Game Defaults (_base_game/mod.json)

```json
{
  "custom_types": {
    "equipment_types": {
      "subtypes": {
        "sword": {"category": "weapon", "display_name": "Sword"},
        "axe": {"category": "weapon", "display_name": "Axe"},
        "lance": {"category": "weapon", "display_name": "Lance"},
        "spear": {"category": "weapon", "display_name": "Spear"},
        "bow": {"category": "weapon", "display_name": "Bow"},
        "staff": {"category": "weapon", "display_name": "Staff"},
        "tome": {"category": "weapon", "display_name": "Tome"},
        "knife": {"category": "weapon", "display_name": "Knife"},
        "dagger": {"category": "weapon", "display_name": "Dagger"},
        "ring": {"category": "accessory", "display_name": "Ring"},
        "accessory": {"category": "accessory", "display_name": "Accessory"}
      },
      "categories": {
        "weapon": {"display_name": "Weapon"},
        "accessory": {"display_name": "Accessory"}
      }
    }
  }
}
```

---

## Category Wildcards

### In Slot Definitions

```json
{
  "equipment_slot_layout": [
    {"id": "weapon", "display_name": "Weapon", "accepts_types": ["weapon:*"]},
    {"id": "ring_1", "display_name": "Ring 1", "accepts_types": ["ring"]},
    {"id": "accessory", "display_name": "Accessory", "accepts_types": ["accessory:*"]}
  ]
}
```

- `weapon:*` = accepts ANY subtype in the "weapon" category
- `ring` = accepts ONLY the literal "ring" subtype (no wildcard)

### In Class Restrictions

```gdscript
# Warrior can use swords, axes, and ALL spear subtypes
equippable_weapon_types = ["sword", "axe", "spear:*"]

# Mage can use ANY weapon (rare, for testing)
equippable_weapon_types = ["weapon:*"]
```

---

## Override Behavior

| Scenario | Behavior |
|----------|----------|
| Two mods add same subtype | Higher priority wins, warning logged |
| Mod changes subtype's category | Higher priority wins, warning logged |
| `replace_all: true` | Wipes ALL lower-priority registrations |
| Unregistered subtype on item | Warning logged, item still usable |

---

## Modder Experience: Creating "The Destroyer" Bow

### Step 1: Item Configuration (Editor)

```
Item Name:       The Destroyer
Item Type:       WEAPON (enum)
Equipment Type:  bow (dropdown - registered subtypes)
Attack Power:    25
Description:     A legendary bow of immense power
```

### Step 2: Registry Already Knows (from _base_game/mod.json)

```
"bow" → category "weapon"
```

### Step 3: Result

- Fits in weapon slot (category match via `weapon:*`)
- Usable by classes with `["bow"]` or `["weapon:*"]` in allowed types
- Shows up in "Weapon" filters in UI

---

## Implementation Phases

### Phase 1: Core Registry (1-2 hours)

**Create:** `/home/user/dev/sparklingfarce/core/registries/equipment_type_registry.gd`

```gdscript
class_name EquipmentTypeRegistry
extends RefCounted

## Maps equipment subtypes to categories
## Populated entirely from mod.json files - NO hardcoded defaults

# Registered subtypes: {subtype_id: {category, display_name, source_mod}}
var _subtypes: Dictionary = {}

# Registered categories: {category_id: {display_name, source_mod}}
var _categories: Dictionary = {}

## Register equipment types from a mod's config
func register_from_config(mod_id: String, config: Dictionary, replace_all: bool = false) -> void

## Get category for a subtype (empty string if not found)
func get_category(subtype: String) -> String

## Check if subtype matches an accepts_types entry (handles wildcards)
func matches_accept_type(subtype: String, accept_type: String) -> bool

## Get all subtypes for a category
func get_subtypes_for_category(category: String) -> Array[String]

## Validation helpers
func is_valid_subtype(subtype: String) -> bool
func is_valid_category(category: String) -> bool

## Clear for mod reload
func clear_mod_registrations() -> void
```

**Key method - wildcard matching:**

```gdscript
func matches_accept_type(subtype: String, accept_type: String) -> bool:
    var lower_subtype: String = subtype.to_lower()
    var lower_accept: String = accept_type.to_lower()

    # Direct match
    if lower_subtype == lower_accept:
        return true

    # Category wildcard: "weapon:*"
    if lower_accept.ends_with(":*"):
        var category: String = lower_accept.trim_suffix(":*")
        var subtype_category: String = get_category(lower_subtype)
        return subtype_category == category

    # No match
    return false
```

**Deliverables:**
- [ ] EquipmentTypeRegistry class with full API
- [ ] Unit tests for all public methods
- [ ] Wildcard matching tests

---

### Phase 2: ModLoader Integration (1 hour)

**Modify:** `/home/user/dev/sparklingfarce/core/mod_system/mod_manifest.gd`

Add property:
```gdscript
@export var equipment_type_config: Dictionary = {}
```

Add parsing in `load_from_file()`:
```gdscript
if "equipment_types" in custom_types:
    manifest.equipment_type_config = custom_types.equipment_types
```

**Modify:** `/home/user/dev/sparklingfarce/core/mod_system/mod_loader.gd`

Add registry:
```gdscript
var equipment_type_registry: RefCounted = null  # EquipmentTypeRegistry

func _init() -> void:
    equipment_type_registry = EquipmentTypeRegistry.new()
```

In `_register_mod_type_definitions()`:
```gdscript
if not manifest.equipment_type_config.is_empty():
    var replace_all: bool = manifest.equipment_type_config.get("replace_all", false)
    equipment_type_registry.register_from_config(
        manifest.mod_id,
        manifest.equipment_type_config,
        replace_all
    )
```

**Deliverables:**
- [ ] ModManifest parses equipment_type_config
- [ ] ModLoader instantiates and populates registry
- [ ] reload_mods() clears and repopulates

---

### Phase 3: Slot Registry Integration (30 minutes)

**Modify:** `/home/user/dev/sparklingfarce/core/registries/equipment_slot_registry.gd`

Update `slot_accepts_type()`:

```gdscript
func slot_accepts_type(slot_id: String, item_type: String) -> bool:
    var slot: Dictionary = get_slot(slot_id)
    if slot.is_empty():
        return false

    var accepts: Array = slot.get("accepts_types", [])
    var lower_type: String = item_type.to_lower()

    # Check each accept entry (may include wildcards)
    for accept_entry: String in accepts:
        # Use EquipmentTypeRegistry for matching (handles wildcards)
        if ModLoader and ModLoader.equipment_type_registry:
            if ModLoader.equipment_type_registry.matches_accept_type(lower_type, accept_entry):
                return true
        else:
            # Fallback: direct match only
            if lower_type == accept_entry.to_lower():
                return true

    return false
```

Simplify `DEFAULT_SLOTS`:
```gdscript
const DEFAULT_SLOTS: Array[Dictionary] = [
    {"id": "weapon", "display_name": "Weapon", "accepts_types": ["weapon:*"]},
    {"id": "ring_1", "display_name": "Ring 1", "accepts_types": ["accessory:*"]},
    {"id": "ring_2", "display_name": "Ring 2", "accepts_types": ["accessory:*"]},
    {"id": "accessory", "display_name": "Accessory", "accepts_types": ["accessory:*"]}
]
```

**Deliverables:**
- [ ] slot_accepts_type() uses registry for wildcard matching
- [ ] DEFAULT_SLOTS simplified to use categories
- [ ] Integration tests pass

---

### Phase 4: Base Game Configuration (30 minutes)

**Modify:** `/home/user/dev/sparklingfarce/mods/_base_game/mod.json`

Add equipment_types section with all default subtypes and categories (see schema above).

**Cleanup fallbacks in:**
- `core/resources/item_data.gd` - `_get_default_valid_slots()`
- `addons/sparkling_editor/ui/character_editor.gd` - `_get_equipment_slots()`

These can now delegate to the registry or use minimal fallbacks.

**Deliverables:**
- [ ] _base_game/mod.json has complete equipment_types
- [ ] Fallback code simplified or removed
- [ ] All existing items still work

---

### Phase 5: Class Restrictions + Polish (30 minutes)

**Modify:** `/home/user/dev/sparklingfarce/core/resources/class_data.gd`

Update weapon type checking to support wildcards:

```gdscript
func can_equip_weapon_type(weapon_subtype: String) -> bool:
    var lower_subtype: String = weapon_subtype.to_lower()

    for allowed: String in equippable_weapon_types:
        if ModLoader and ModLoader.equipment_type_registry:
            if ModLoader.equipment_type_registry.matches_accept_type(lower_subtype, allowed):
                return true
        elif allowed.to_lower() == lower_subtype:
            return true

    return false
```

**Deliverables:**
- [ ] Class restrictions support category wildcards
- [ ] Manual testing passes
- [ ] Debug output removed from earlier fixes

---

### Phase 6: Documentation + Tests (30 minutes)

**Create:** `/home/user/dev/sparklingfarce/tests/unit/test_equipment_type_registry.gd`

Test cases:
- Subtype registration and lookup
- Category registration
- Wildcard matching (`weapon:*`)
- `replace_all` behavior
- Override warnings
- Invalid/missing subtype handling

**Update:** `/home/user/dev/sparklingfarce/docs/specs/platform-specification.md`

Document the equipment type system for modders.

**Deliverables:**
- [ ] Comprehensive unit tests
- [ ] Platform spec updated
- [ ] This plan marked COMPLETE

---

## Files to Create/Modify

| Action | File |
|--------|------|
| CREATE | `core/registries/equipment_type_registry.gd` |
| MODIFY | `core/registries/equipment_slot_registry.gd` |
| MODIFY | `core/mod_system/mod_loader.gd` |
| MODIFY | `core/mod_system/mod_manifest.gd` |
| MODIFY | `core/resources/class_data.gd` |
| MODIFY | `core/resources/item_data.gd` |
| MODIFY | `mods/_base_game/mod.json` |
| MODIFY | `addons/sparkling_editor/ui/character_editor.gd` |
| CREATE | `tests/unit/test_equipment_type_registry.gd` |
| MODIFY | `docs/specs/platform-specification.md` |

---

## Estimated Effort

| Phase | Task | Time |
|-------|------|------|
| 1 | Core Registry | 1-2 hrs |
| 2 | ModLoader Integration | 1 hr |
| 3 | Slot Registry Integration | 30 min |
| 4 | Base Game Configuration | 30 min |
| 5 | Class Restrictions + Polish | 30 min |
| 6 | Documentation + Tests | 30 min |
| **Total** | | **4-5 hrs** |

---

## Success Criteria

1. **Existing items work unchanged** - No migration required
2. **Modders can add new subtypes** - Just add to mod.json, no slot editing
3. **Total conversions work** - `replace_all: true` wipes base types
4. **Category wildcards work** - `weapon:*` matches any weapon
5. **Class restrictions work** - Support both explicit subtypes and wildcards
6. **Editor integration** - Dropdowns show registered subtypes grouped by category

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Registry not loaded in editor | Fallback to direct matching |
| Circular category references | Validate on registration, skip invalid |
| Missing _base_game/mod.json | Minimal code fallback for core functionality |
| Performance with many subtypes | Cache lookups, lazy evaluation |

---

## Post-Implementation Cleanup

After this system is stable:
1. Remove debug print statements from party_equipment_menu.gd
2. Remove debug print statements from character_editor.gd
3. Remove debug print statements from resource_picker.gd
4. Consider deprecating `ItemData.equipment_slot` field (optional override only)

---

*Plan approved. Engage!*
