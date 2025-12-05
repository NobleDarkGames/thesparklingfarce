# Equipment System Plan

**Status:** Phases 4.2.1-4.2.4 COMPLETE | Phases 4.2.5-4.2.6 Ready for Implementation
**Authors:** Commander Claudius (Design), Lt. Claudbrain (Architecture), Modro (Mod Review)
**Date:** 2025-12-02
**Last Updated:** December 5, 2025
**Phase:** 4.2
**Moddability Score:** 9/10 (after Modro's revisions)

**Officer Reviews (December 5, 2025):**
- ✅ Lt. Claudbrain (Architecture): APPROVED - Found phases 4.2.1-4.2.4 already implemented
- ✅ Commander Claudius (SF Vision): APPROVED WITH CHANGES - Minor clarifications needed
- ✅ Mr. Nerdlinger (SF2 Purist): APPROVED WITH CHANGES - Authenticity deviation documented
- ✅ Chief O'Brien (Engineering): Recommends keeping current architecture
- ✅ Modro (Mod Architecture): Recommends keeping current architecture

---

## Priority Note (December 5, 2025)

With the completion of:
- ✅ SF2-style direct movement
- ✅ Terrain effects system
- ✅ Sparkling Editor expansion (all phases)
- ✅ Total conversion modding P0 items

**This equipment system is now the next major feature to implement.** It will enable:
- Weapons with attack power and range
- Rings for SF-signature stat customization
- Cursed items with uncurse mechanics
- Class-restricted equipment
- 4-slot inventory per character (configurable)

---

## Architectural Decision: Typed Slots vs SF2 Generic Slots

**Decision Date:** December 5, 2025
**Decision:** Keep current typed-slot architecture

### Background

Mr. Nerdlinger's SF2 purist review identified that our architecture differs from SF2's authentic model:

| Aspect | Our Implementation | SF2 Authentic |
|--------|-------------------|---------------|
| Equipment slots | 4 typed (weapon, ring_1, ring_2, accessory) | 4 generic slots |
| Inventory slots | 4 separate slots | N/A (same 4 slots) |
| Total capacity | 8 effective slots | 4 slots total |
| Item placement | Items go in designated slot types | Any item in any slot |
| Equip state | Implicit (in equipment array) | Explicit `is_equipped` flag |

### Why We're Keeping Typed Slots

**Platform Mission Over Purist Authenticity:**

After review by Chief O'Brien (Engineering) and Modro (Mod Architecture), the consensus is that our current architecture better serves the platform mission:

1. **Broader mod support**: Typed slots enable Fire Emblem, D&D, Diablo-style equipment systems out of the box
2. **Refactoring cost**: 22-32 hours with medium-high risk to achieve SF2 authenticity
3. **Configuration solution**: Mods wanting SF2-authentic 4-slot behavior can set `inventory_config.slots_per_character = 0`
4. **Save compatibility**: Current saves would break with architectural change
5. **Working system**: Phases 4.2.1-4.2.4 are already implemented and tested

**Moddability Scores:**
- Current (typed slots): 7/10 - strong for most tactical RPGs
- SF2-only (generic slots): 5/10 - perfect for SF2, awkward for everything else
- Hybrid (future): 9/10 - would support both paradigms

### SF2-Authentic Mode (Future Enhancement)

For mods requiring true SF2 inventory behavior, a future phase may add:
- `item_system_mode: "unified"` option in mod.json
- `UnifiedInventoryManager` with generic slots and equip flags
- `ItemSystemAdapter` to abstract the difference from game systems

This is documented but not blocking for current implementation.

### Achieving SF2 Feel With Current Architecture

Mods wanting constrained SF2-style inventory can configure:
```json
{
  "inventory_config": {
    "slots_per_character": 0
  }
}
```

This gives 4 effective slots (equipment only), closer to SF2's tactical scarcity.

---

## 1. Overview & SF Authenticity

The equipment system brings Shining Force's iconic gear progression to life while improving upon the original's limitations. In Shining Force, equipment wasn't just stat padding - it was a core part of tactical identity. A SDMN with a Sword of Darkness became a different unit than one wielding a Bronze Lance. Rings provided build customization that made each playthrough unique.

**What We're Honoring:**
- **Ring-focused customization**: SF's signature dual-ring system allowed players to craft character builds (e.g., Power Ring + Speed Ring for a balanced fighter, double Protect Rings for a tank)
- **Class-restricted equipment**: Not every character could wield every weapon - this created meaningful choices and emphasized class roles
- **Cursed items**: The risk/reward of powerful cursed gear (Sword of Darkness, Demon Rod) added tactical depth
- **Limited inventory**: The 4-item-per-character constraint forced resource management decisions

**What We're Improving:**
- **No durability grind**: The original games didn't have durability/repair mechanics - we're keeping that streamlined design
- **Flexible uncursing**: Modders can implement church services, consumable items, or custom solutions - we provide the infrastructure
- **Platform-first design**: Every restriction, slot type, and cursed behavior is data-driven and mod-extensible

**What We're Avoiding:**
- The original games' lack of inventory sorting/filtering - our UI will support modern QoL
- Hardcoded weapon/ring types - everything flows through mod registries
- Menu-diving tedium - equip/unequip should be quick and intuitive

---

## 2. Architecture Overview

The equipment system follows the established Sparkling Farce pattern: resources define data, CharacterSaveData persists state, and runtime components (Unit/UnitStats) cache references for combat efficiency.

```
+----------------------+    +------------------+
| EquipmentSlotRegistry|    |    ItemData      |  (Resource - definition)
| (data-driven slots)  |    |  attack_power    |
| from mod.json        |    |  is_cursed       |
+----------+-----------+    |  equipment_slot  |
           |                +--------+---------+
           | defines valid slots     |
           v                         | registered in
                    +------------------+
                    |   ModRegistry    |  (item type + id lookup)
                    +--------+---------+
                             |
                             | referenced by ID in
                             v
+------------------+    +------------------+    +------------------+
| CharacterSaveData|    |  EquipmentManager|    |       Unit       |
| equipped_items   |--->|  equip/unequip   |--->|  cached_equipment|
| inventory        |    |  can_equip       |    |  weapon_attack   |
+------------------+    |  validation hook |    |  weapon_range    |
                        +--------+---------+    +--------+---------+
                                 |                       |
                        emits signals                    | passes stats to
                                 v                       v
                        +------------------+    +------------------+
                        |    PartyManager  |    | CombatCalculator |
                        |  (persistence)   |    | (damage formulas)|
                        +------------------+    +------------------+
```

**Data Flow:**

1. **At Game Load**: CharacterSaveData contains `equipped_items` as slot-to-ID mappings and `inventory` as an array of item IDs
2. **At Battle Start**: Unit loads CharacterSaveData, resolves item IDs to ItemData via ModRegistry, caches references in `cached_equipment`
3. **During Combat**: CombatCalculator calls `Unit.get_weapon_attack_power()` etc., which returns cached weapon stats
4. **On Equip/Unequip**: EquipmentManager validates, updates CharacterSaveData, signals Unit to refresh cache
5. **On Save**: CharacterSaveData serializes equipped item IDs (not full ItemData objects)

---

## 3. Equipment Slot Definitions

Characters have **four equipment slots** that define their combat capabilities and tactical role:

### WEAPON Slot
- **Purpose**: Primary damage source and attack range determination
- **Examples**: Bronze Sword (melee, +5 ATK), Power Spear (melee, +12 ATK, +2 DEF), Dark Bow (ranged, range 2, +8 ATK)
- **Class Restrictions**: Enforced via `ClassData.equippable_weapon_types`
- **Range Impact**: Weapon's `attack_range` property determines melee (1) vs ranged (2+) combat
- **Empty Slot Behavior**: Character can still attack with base stats (unarmed strike) but at reduced effectiveness
  - **Unarmed Damage Formula**: `STR + 0` (no weapon attack bonus) - matches SF2 where unarmed attacks deal ~1-5 damage
  - **Unarmed Hit Rate**: Base 70% (no weapon accuracy bonus)
  - **Unarmed Range**: Always 1 (melee only)

### RING_1 and RING_2 Slots
- **Purpose**: Primary stat customization and build crafting
- **Examples**:
  - **Power Ring**: +3 STR (offensive builds)
  - **Protect Ring**: +3 DEF (defensive builds)
  - **Speed Ring**: +3 AGI (turn order manipulation)
  - **Mobility Ring**: +1 movement range (positioning advantage)
  - **White Ring**: Immunity to status effects (support protection)
- **Class Restrictions**: Typically unrestricted (SF tradition), but modders can limit if desired
- **Stacking**: Both ring slots can hold the same ring type (e.g., double Power Ring for +6 STR total)
- **Empty Slot Behavior**: No penalty, rings are pure bonuses

### ACCESSORY Slot
- **Purpose**: Unique utility items and special effects
- **Examples**:
  - **Sword of Light**: Special weapon granting "Bolt" ability in battle
  - **Pegasus Wing**: Consumable promotion item
  - **Medical Herb**: Healing item kept equipped for quick access
  - **Charm of Renewal**: Auto-revive on death (1-time use)
- **Class Restrictions**: Varies by item (some are class-specific, others universal)

---

## 4. EquipmentSlotRegistry (Data-Driven Slots)

**Per Modro's review:** Equipment slots are fully data-driven, allowing total conversion mods to define entirely different slot layouts.

Create new file: `core/registries/equipment_slot_registry.gd`

```gdscript
class_name EquipmentSlotRegistry
extends RefCounted

## Data-driven equipment slot registry
## Allows mods to define custom slot layouts via mod.json
##
## Default SF-style layout: WEAPON, RING_1, RING_2, ACCESSORY
## Total conversion can replace with: HEAD, BODY, MAIN_HAND, OFF_HAND, etc.

const DEFAULT_SLOTS: Array[Dictionary] = [
    {"id": "weapon", "display_name": "Weapon", "accepts_types": ["weapon"]},
    {"id": "ring_1", "display_name": "Ring 1", "accepts_types": ["ring"]},
    {"id": "ring_2", "display_name": "Ring 2", "accepts_types": ["ring"]},
    {"id": "accessory", "display_name": "Accessory", "accepts_types": ["accessory"]}
]

var _slots: Array[Dictionary] = []
var _slot_source_mod: String = ""

## Register a complete slot layout from a mod
## Higher priority mods completely replace lower priority layouts
func register_slot_layout(mod_id: String, slots: Array[Dictionary]) -> void:
    _slots = slots.duplicate(true)
    _slot_source_mod = mod_id
    print("EquipmentSlotRegistry: Slot layout registered from mod '%s'" % mod_id)

## Get the active slot layout
func get_slots() -> Array[Dictionary]:
    return _slots if not _slots.is_empty() else DEFAULT_SLOTS

## Get slot count
func get_slot_count() -> int:
    return get_slots().size()

## Get slot by ID
func get_slot(slot_id: String) -> Dictionary:
    for slot: Dictionary in get_slots():
        if slot.get("id", "") == slot_id:
            return slot
    return {}

## Check if a slot ID is valid
func is_valid_slot(slot_id: String) -> bool:
    return not get_slot(slot_id).is_empty()

## Check if an item type can go in a slot
func slot_accepts_type(slot_id: String, item_type: String) -> bool:
    var slot: Dictionary = get_slot(slot_id)
    if slot.is_empty():
        return false
    var accepts: Array = slot.get("accepts_types", [])
    return item_type in accepts

## Get display name for a slot
func get_slot_display_name(slot_id: String) -> String:
    var slot: Dictionary = get_slot(slot_id)
    return slot.get("display_name", slot_id.capitalize())

## Get all slot IDs
func get_slot_ids() -> Array[String]:
    var ids: Array[String] = []
    for slot: Dictionary in get_slots():
        if "id" in slot:
            ids.append(slot.id)
    return ids

## Get slots that accept a specific type (for UI dropdowns)
func get_slots_for_type(item_type: String) -> Array[String]:
    var matching: Array[String] = []
    for slot: Dictionary in get_slots():
        var accepts: Array = slot.get("accepts_types", [])
        if item_type in accepts:
            matching.append(slot.get("id", ""))
    return matching
```

### Default SF-Style Slot Constants (Convenience)

For code that needs quick access to default slot IDs:

```gdscript
# core/systems/equipment_slot.gd - Convenience constants for default layout
class_name EquipmentSlot
extends RefCounted

## Default slot IDs (SF-style layout)
## Use these for base game code; mods may have different slot IDs
const WEAPON: String = "weapon"
const RING_1: String = "ring_1"
const RING_2: String = "ring_2"
const ACCESSORY: String = "accessory"

## Check if slot ID matches a ring slot in default layout
static func is_default_ring_slot(slot_id: String) -> bool:
    return slot_id == RING_1 or slot_id == RING_2
```

---

## 5. ItemData Modifications

Add the following properties to `core/resources/item_data.gd`:

```gdscript
@export_group("Equipment Slot")
## Which slot type this item occupies when equipped
## Uses String (not enum) to support mod-defined slot types
## Validated against EquipmentSlotRegistry at runtime
@export var equipment_slot: String = "weapon"

@export_group("Curse Properties")
## If true, item cannot be unequipped through normal means
@export var is_cursed: bool = false

@export_group("Uncurse Requirements")
## Item IDs that can remove this curse (e.g., "purify_scroll", "uncurse_potion")
## Empty array means only church service can remove curse
@export var uncurse_items: Array[String] = []
```

**Removed Properties** (per Captain's decision):
- Remove `durability: int` field entirely

**Why String instead of Enum?** (Per Modro's review)
Using `@export_enum()` would hardcode slot types into the editor UI. With a String validated against `EquipmentSlotRegistry`, mods can define custom slot types like "helmet", "implant", or "mount" without editing core code.

**New helper methods:**

```gdscript
## Check if this item can have its curse removed by a specific item
func can_uncurse_with(uncurse_item_id: String) -> bool:
    if not is_cursed:
        return false
    return uncurse_item_id in uncurse_items

## Get valid slots this item can be equipped to
## Returns array because some items (rings) can go in multiple slots
func get_valid_slots() -> Array[String]:
    return ModLoader.equipment_slot_registry.get_slots_for_type(equipment_slot)

## Validate equipment_slot against registry
func validate_equipment_slot() -> bool:
    var valid_slots: Array[String] = get_valid_slots()
    if valid_slots.is_empty():
        push_warning("ItemData '%s': equipment_slot '%s' not accepted by any slot" % [item_name, equipment_slot])
        return false
    return true
```

---

## 6. Cursed Item Mechanics

Cursed items are a classic SF risk/reward mechanic: powerful gear with a drawback.

### How Cursing Works

**Equipping Behavior**:
1. When a cursed item is equipped, it occupies its designated slot normally
2. The item provides its full stat bonuses (cursed items are typically powerful)
3. The character receives a visual indicator (darkened portrait, status icon)
4. **Lock-in**: The cursed item cannot be unequipped through normal means

### How Uncursing Works

The platform supports **two uncursing methods** - modders can implement either, both, or add custom solutions:

**Method 1: NPC Service (Church/Priest)**
- Player interacts with church NPC → Dialog offers "Purification" service → Fee paid → Curse removed
- Service cost, availability, and dialog are all data-driven

**Method 2: Consumable Item (Purify Scroll, etc.)**
- Special consumable `ItemData` with `effect` pointing to an "uncurse" `AbilityData`
- Player uses Purify Scroll from inventory → Character selection → Curse removed → Scroll consumed

**Curse State Tracking:**
- Curse state is tracked per-instance in `CharacterSaveData.equipped_items` with a `curse_broken: bool` flag
- When curse is broken, item remains equipped but can now be unequipped normally

---

## 7. Inventory Model

**Per Modro's review:** Inventory size is configurable via mod.json, not hardcoded.

### Inventory Configuration

Create new file: `core/systems/inventory_config.gd`

```gdscript
class_name InventoryConfig
extends RefCounted

## Default SF-style inventory (4 slots per character)
const DEFAULT_SLOTS_PER_CHARACTER: int = 4
const DEFAULT_ALLOW_DUPLICATES: bool = true

var slots_per_character: int = DEFAULT_SLOTS_PER_CHARACTER
var allow_duplicates: bool = DEFAULT_ALLOW_DUPLICATES
var _source_mod: String = ""

## Load inventory config from mod manifest
func load_from_manifest(mod_id: String, config: Dictionary) -> void:
    if "slots_per_character" in config:
        slots_per_character = config.slots_per_character
    if "allow_duplicates" in config:
        allow_duplicates = config.allow_duplicates
    _source_mod = mod_id
    print("InventoryConfig: Loaded from mod '%s' (%d slots)" % [mod_id, slots_per_character])

## Get max inventory size
func get_max_slots() -> int:
    return slots_per_character
```

### Core Design

**Per-Character Inventory**:
- Each character has **configurable inventory slots** (default: 4, SF-authentic)
- Inventory stored in `CharacterSaveData` as: `inventory: Array[String]` (item IDs)
- Example: `["healing_seed", "healing_seed", "medical_herb", "antidote"]`

**Duplicate Items**:
- **Allowed by default**: A character can carry multiple copies of the same item
- **No Stacking UI**: Each item occupies one slot, even if identical (true to SF design)
- **Use Order**: First matching item ID in array is consumed when used

**Item Reference Model** (Mod-Safe):
- Inventory stores **item IDs** (strings), not direct `ItemData` references
- At runtime, resolve IDs via `ModLoader.registry.get_resource("item", item_id)`
- This allows mods to override item definitions without breaking saves

### Example Inventory States

**Early-Game Fighter**:
```gdscript
equipped_items = [
    {slot: "weapon", item_id: "bronze_sword"},
    {slot: "ring_1", item_id: "power_ring"},
    {slot: "ring_2", item_id: ""},  # Empty slot
    {slot: "accessory", item_id: ""}
]
inventory = ["healing_seed", "healing_seed", "antidote", ""]  # 1 empty slot
```

---

## 8. CharacterSaveData Changes

Update `core/resources/character_save_data.gd`:

```gdscript
## Equipped items by slot
## Format: [{slot: String, mod_id: String, item_id: String, curse_broken: bool}]
## Slots: "weapon", "ring_1", "ring_2", "accessory"
@export var equipped_items: Array[Dictionary] = []

## Inventory - items the character is carrying but not equipped
## Format: Array of item IDs (duplicates allowed)
## Example: ["healing_herb", "healing_herb", "antidote", "power_ring"]
@export var inventory: Array[String] = []
```

**Why `mod_id` in equipped_items?** (Per Commander Claudius's review)

The `mod_id` field tracks which mod provided each equipped item. This enables safe handling when mods are uninstalled:
- On save load, validate that the item's source mod is still active
- If mod is missing, gracefully unequip the item to inventory (or drop if inventory full)
- Prevents crashes from references to items that no longer exist

---

## 9. Class Restriction Rules

### Enforcement Mechanism

**Class-Level Restrictions** (`ClassData`):
```gdscript
@export var equippable_weapon_types: Array[String] = []
@export var equippable_armor_types: Array[String] = []  # Used for rings/accessories
```

**Restriction Check Flow**:
1. Player attempts to equip `ItemData` with `equipment_type = "axe"`
2. System checks `character.current_class.equippable_weapon_types`
3. If `"axe"` is in the array → allow equip
4. If not → show error message: "Max cannot equip this weapon type"

### Class Restriction Examples

| Class | Weapon Types | Notes |
|-------|--------------|-------|
| SDMN | sword, lance | Standard melee fighter |
| ACHR | bow, crossbow | Ranged specialist |
| MAGE | staff, rod | Magic user |
| HERO | sword, lance, great_sword | Protagonist flexibility |

### Promotion Impact

When a character promotes, their `current_class` changes, which **updates their equipment restrictions**. If promoted class loses access to currently equipped weapon type, item is auto-unequipped to inventory.

**Inventory-Full Edge Case** (Per Commander Claudius's review):

If a character promotes and their weapon must be auto-unequipped but inventory is full:
1. **Primary**: Move item to Caravan storage (if available and accessible)
2. **Fallback**: Create temporary overflow slot (UI warns player)
3. **Never**: Block promotion - this would be poor UX

**Note**: This is an intentional improvement over SF2, which left invalid equipment equipped but unusable. Our approach provides clearer feedback to players.

---

## 10. EquipmentManager API

**Per Modro's review:** EquipmentManager includes signals for mod reactivity and a custom validation hook.

Create new file: `core/systems/equipment_manager.gd`

```gdscript
class_name EquipmentManager
extends Node

## Singleton for equipment operations
## Registered as autoload for signal access

# ============================================================================
# SIGNALS (Per Modro's review - mods can react to equipment changes)
# ============================================================================

## Emitted when an item is successfully equipped
signal item_equipped(character_uid: String, slot_id: String, item_id: String, old_item_id: String)

## Emitted when an item is unequipped
signal item_unequipped(character_uid: String, slot_id: String, item_id: String)

## Emitted when a curse is applied (item equipped)
signal curse_applied(character_uid: String, slot_id: String, item_id: String)

## Emitted when a curse is removed
signal curse_removed(character_uid: String, slot_id: String, item_id: String)

## Emitted before equip for custom validation
## Mods connect to this and can set result.can_equip = false with a reason
signal custom_equip_validation(context: Dictionary, result: Dictionary)

## Emitted before equip (can be cancelled by setting context.cancel = true)
signal pre_equip(context: Dictionary)

## Emitted after successful equip
signal post_equip(context: Dictionary)

# ============================================================================
# SIGNAL EMISSION ORDER (Per Commander Claudius's review)
# ============================================================================
# When equip_item() is called, signals emit in this order:
# 1. pre_equip(context) - mods can set context.cancel = true to abort
# 2. custom_equip_validation(context, result) - mods can set result.can_equip = false
# 3. [internal equip logic]
# 4. item_equipped(uid, slot, item_id, old_item_id)
# 5. curse_applied(uid, slot, item_id) - only if item.is_cursed
# 6. post_equip(context)
#
# IMPORTANT: Mods should NOT emit equipment signals from signal handlers
# to avoid infinite loops. The context.cancel mechanism is the safe way
# to prevent equips from within a pre_equip handler.
# ============================================================================

# ============================================================================
# PUBLIC API
# ============================================================================

## Equip an item to a character's slot
## Returns: {success: bool, error: String, unequipped_item_id: String}
func equip_item(
    save_data: CharacterSaveData,
    slot_id: String,
    item_id: String,
    unit: Node2D = null
) -> Dictionary:
    # Build context for signals
    var context: Dictionary = {
        "save_data": save_data,
        "slot_id": slot_id,
        "item_id": item_id,
        "unit": unit,
        "cancel": false,
        "cancel_reason": ""
    }

    # Emit pre_equip - mods can cancel
    pre_equip.emit(context)
    if context.cancel:
        return {success = false, error = context.cancel_reason, unequipped_item_id = ""}

    # Validate and perform equip...
    var old_item_id: String = _get_equipped_item_id(save_data, slot_id)

    # ... equip logic here ...

    # Emit signals on success
    item_equipped.emit(save_data.character_uid, slot_id, item_id, old_item_id)
    post_equip.emit(context)

    var item: ItemData = ModLoader.registry.get_resource("item", item_id)
    if item and item.is_cursed:
        curse_applied.emit(save_data.character_uid, slot_id, item_id)

    return {success = true, error = "", unequipped_item_id = old_item_id}

## Unequip an item from a slot (convenience wrapper)
func unequip_item(
    save_data: CharacterSaveData,
    slot_id: String,
    unit: Node2D = null
) -> Dictionary:
    return equip_item(save_data, slot_id, "", unit)

## Check if a character can equip an item in a specific slot
## Returns: {can_equip: bool, reason: String}
func can_equip(
    save_data: CharacterSaveData,
    slot_id: String,
    item_id: String
) -> Dictionary:
    var result: Dictionary = {can_equip = true, reason = ""}

    # Built-in class restriction check
    var class_result: Dictionary = _check_class_restrictions(save_data, item_id)
    if not class_result.can_equip:
        return class_result

    # Built-in slot type check
    var slot_result: Dictionary = _check_slot_accepts_item(slot_id, item_id)
    if not slot_result.can_equip:
        return slot_result

    # Custom validation hook - mods can add level requirements, quest prereqs, etc.
    var context: Dictionary = {
        "save_data": save_data,
        "slot_id": slot_id,
        "item_id": item_id,
        "item_data": ModLoader.registry.get_resource("item", item_id)
    }
    custom_equip_validation.emit(context, result)

    return result

## Remove curse using any valid method
## method: "church", "item", or custom mod-defined methods
func attempt_uncurse(
    save_data: CharacterSaveData,
    slot_id: String,
    method: String,
    context: Dictionary = {}
) -> Dictionary:
    # ... uncurse logic ...

    # On success:
    curse_removed.emit(save_data.character_uid, slot_id, item_id)
    return {success = true, error = ""}

## Get all equipped items as ItemData references
## Returns: {slot_id: ItemData or null}
func get_equipped_items(save_data: CharacterSaveData) -> Dictionary:
    pass

## Calculate total stat bonus from all equipped items
func get_total_equipment_bonus(save_data: CharacterSaveData, stat_name: String) -> int:
    pass
```

### Custom Validation Hook Example

Mods can connect to `custom_equip_validation` to add requirements:

```gdscript
# In a mod's autoload script
func _ready() -> void:
    EquipmentManager.custom_equip_validation.connect(_on_custom_validation)

func _on_custom_validation(context: Dictionary, result: Dictionary) -> void:
    var item: ItemData = context.item_data
    var save_data: CharacterSaveData = context.save_data

    # Example: Level requirement
    if "min_level" in item.get_meta_list():
        var min_level: int = item.get_meta("min_level")
        if save_data.level < min_level:
            result.can_equip = false
            result.reason = "Requires level %d" % min_level
            return

    # Example: Quest prerequisite
    if "requires_quest" in item.get_meta_list():
        var quest_id: String = item.get_meta("requires_quest")
        if not QuestManager.is_complete(quest_id):
            result.can_equip = false
            result.reason = "Requires completing '%s'" % quest_id
```

---

## 11. UnitStats Integration

Add to `core/components/unit_stats.gd`:

```gdscript
## Cached equipped weapon (for combat calculations)
var cached_weapon: ItemData = null

## Cached equipment by slot (for stat bonuses)
var cached_equipment: Dictionary = {}  # {slot: ItemData}

## Equipment stat bonuses
var equipment_strength_bonus: int = 0
var equipment_defense_bonus: int = 0
# ... other stat bonuses ...

## Load and cache equipment from CharacterSaveData
func load_equipment_from_save(save_data: CharacterSaveData) -> void:
    pass

## Get weapon attack power (0 if no weapon equipped)
func get_weapon_attack_power() -> int:
    if cached_weapon:
        return cached_weapon.attack_power
    return 0

## Get weapon attack range (1 = melee if no weapon)
func get_weapon_range() -> int:
    if cached_weapon:
        return cached_weapon.attack_range
    return 1

## Get effective strength (base + equipment + buffs)
func get_effective_strength() -> int:
    return maxi(0, strength + equipment_strength_bonus)
```

---

## 12. CombatCalculator Updates

Update `core/systems/combat_calculator.gd`:

```gdscript
## Calculate physical attack damage with weapon
## Formula: (Attacker STR + Weapon ATK - Defender DEF) * variance
static func calculate_physical_damage(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
    var attack_power: int = attacker_stats.get_effective_strength()
    attack_power += attacker_stats.get_weapon_attack_power()

    var defense_power: int = defender_stats.get_effective_defense()
    var base_damage: int = attack_power - defense_power

    var variance: float = randf_range(0.9, 1.1)
    return maxi(int(base_damage * variance), 1)

## Calculate hit chance with weapon accuracy
static func calculate_hit_chance(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
    var base_hit: int = attacker_stats.get_weapon_hit_rate()
    var hit_modifier: int = (attacker_stats.get_effective_agility() - defender_stats.get_effective_agility()) * 2
    return clampi(base_hit + hit_modifier, 10, 99)

## Check if attacker can reach target with their weapon
static func can_attack_at_range(attacker_stats: UnitStats, distance: int) -> bool:
    return attacker_stats.get_weapon_range() >= distance
```

---

## 13. Editor Integration

### item_editor.gd Changes

- **Remove**: Durability UI elements
- **Add**: Equipment slot dropdown (WEAPON, RING, ACCESSORY)
- **Add**: Curse properties section (is_cursed checkbox, uncurse_items list)

### character_editor.gd Changes

- **Add**: Equipment preview section showing starting equipment by slot
- **Add**: Validation warnings for invalid equipment assignments

---

## 14. Example Equipment Definitions

### Bronze Sword (Basic Weapon)
```tres
item_name = "Bronze Sword"
item_type = WEAPON
equipment_type = "sword"
equipment_slot = "weapon"
attack_power = 5
attack_range = 1
hit_rate = 90
critical_rate = 5
strength_modifier = 1
buy_price = 200
sell_price = 100
description = "A standard bronze blade. Reliable and affordable."
```

### Power Ring (Stat Boost)
```tres
item_name = "Power Ring"
item_type = ARMOR
equipment_type = "ring"
equipment_slot = "ring"
strength_modifier = 3
buy_price = 1000
sell_price = 500
description = "Increases strength. Favored by warriors."
```

### Sword of Darkness (Cursed Weapon)
```tres
item_name = "Sword of Darkness"
item_type = WEAPON
equipment_type = "sword"
equipment_slot = "weapon"
is_cursed = true
uncurse_items = ["purify_scroll", "holy_water"]
attack_power = 18
attack_range = 1
strength_modifier = 5
agility_modifier = -3
luck_modifier = -2
buy_price = 5000
sell_price = 2500
description = "A blade infused with dark power. Immense strength, but at a cost..."
```

### Medical Herb (Consumable)
```tres
item_name = "Medical Herb"
item_type = CONSUMABLE
usable_in_battle = true
usable_on_field = true
effect = <AbilityData: heal_effect>
buy_price = 50
sell_price = 25
description = "Restores 30 HP. Can be used in battle or on the field."
```

---

## 15. Mod.json Extensions

**Per Modro's review:** The following mod.json schema extensions support equipment customization:

```json
{
  "mod_id": "my_total_conversion",
  "name": "Space Force Tactics",
  "load_priority": 9000,

  "equipment_slot_layout": [
    {"id": "weapon_main", "display_name": "Main Weapon", "accepts_types": ["weapon", "laser"]},
    {"id": "weapon_off", "display_name": "Off-Hand", "accepts_types": ["shield", "weapon"]},
    {"id": "helmet", "display_name": "Helmet", "accepts_types": ["helmet"]},
    {"id": "armor", "display_name": "Body Armor", "accepts_types": ["armor"]},
    {"id": "accessory_1", "display_name": "Implant 1", "accepts_types": ["implant"]},
    {"id": "accessory_2", "display_name": "Implant 2", "accepts_types": ["implant"]}
  ],

  "inventory_config": {
    "slots_per_character": 6,
    "allow_duplicates": true
  },

  "custom_types": {
    "weapon_types": ["laser", "plasma", "railgun"],
    "armor_types": ["helmet", "armor", "implant", "shield"]
  }
}
```

### Schema Details

| Field | Type | Description |
|-------|------|-------------|
| `equipment_slot_layout` | Array[Dictionary] | Replaces default slot layout entirely. Each entry has `id`, `display_name`, `accepts_types`. |
| `inventory_config.slots_per_character` | int | Inventory slots per character (default: 4) |
| `inventory_config.allow_duplicates` | bool | Whether duplicate items are allowed (default: true) |
| `custom_types.weapon_types` | Array[String] | Additional weapon types to register |
| `custom_types.armor_types` | Array[String] | Additional armor/ring/accessory types to register |

### Priority Behavior

- `equipment_slot_layout`: Highest priority mod's layout replaces all others
- `inventory_config`: Highest priority mod's config wins
- `custom_types`: Merged from all mods (additive)

---

## 16. Implementation Phases

### Phase 4.2.1: Core Data Structures & Registries ✅ COMPLETE
1. ✅ Create `core/registries/equipment_slot_registry.gd` (data-driven slots)
2. ✅ Create `core/systems/equipment_slot.gd` (convenience constants)
3. ✅ Create `core/systems/inventory_config.gd` (configurable inventory)
4. ✅ Modify `ItemData` to add `equipment_slot` (String), `is_cursed`, `uncurse_items`
5. ✅ Remove `durability` field from `ItemData`
6. ✅ Update `CharacterSaveData` equipped_items format and add inventory array
7. ✅ Update `ModLoader` to read `equipment_slot_layout` and `inventory_config` from mod.json

**Status**: Verified by Lt. Claudbrain (December 5, 2025)

### Phase 4.2.2: EquipmentManager with Signals ✅ COMPLETE
1. ✅ Create `core/systems/equipment_manager.gd` as autoload
2. ✅ Implement signals: `item_equipped`, `item_unequipped`, `curse_applied`, `curse_removed`
3. ✅ Implement `pre_equip`, `post_equip`, `custom_equip_validation` hooks
4. ✅ Implement `equip_item()`, `unequip_item()`, `can_equip()`
5. ✅ Implement `attempt_uncurse()` with method parameter
6. ✅ Add class equipment restriction validation

**Status**: Verified by Lt. Claudbrain (December 5, 2025)

### Phase 4.2.3: UnitStats Equipment Cache ✅ COMPLETE
1. ✅ Add equipment cache fields to `UnitStats`
2. ✅ Implement `load_equipment_from_save()`
3. ✅ Add weapon stat accessor methods
4. ✅ Add `refresh_equipment_cache()` to `Unit`

**Status**: Verified by Lt. Claudbrain (December 5, 2025)

### Phase 4.2.4: CombatCalculator Updates ✅ COMPLETE
1. ✅ Update `calculate_physical_damage()` to include weapon attack power
2. ✅ Update `calculate_hit_chance()` to use weapon hit rate
3. ✅ Update `calculate_crit_chance()` to include weapon crit bonus
4. ✅ Add `can_attack_at_range()` method

**Status**: Verified by Lt. Claudbrain (December 5, 2025)

### Phase 4.2.5: Editor Integration 🔲 NEEDS VERIFICATION
1. Update `item_editor.gd` - remove durability, add equipment slot and curse UI
2. Update `character_editor.gd` - add equipment preview

**Tests**: Manual editor workflow testing

### Phase 4.2.6: Inventory UI 🔲 READY FOR IMPLEMENTATION
1. Create basic inventory display scene
2. Implement equip/unequip from inventory
3. Add visual feedback for cursed items
4. Implement consumable item usage (uncurse items)

**Tests**: Manual inventory workflow testing

---

## 17. Out of Scope (Future Phases)

- **Shop System**: Separate sprint due to NPC interaction, currency, and unique inventory rules
- **Durability/Repair**: Removed per Captain's decision
- **Caravan Storage**: Will use same inventory model, implemented with Caravan system
