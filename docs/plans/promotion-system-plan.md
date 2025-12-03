# Promotion System Implementation Plan

**Phase:** 4.1 (Core SF Mechanics)
**Priority:** CRITICAL
**Status:** Core Complete (Phase 4.1)
**Created:** 2025-12-02
**Completed:** 2025-12-02
**Contributors:** Commander Claudius, Lt. Ears, Lt. Claudbrain, Lt. Clauderina (UI)

---

## Implementation Status

### Completed (Phase 4.1)
- [x] PromotionManager autoload singleton
- [x] ClassData extensions (special_promotion_class, special_promotion_item)
- [x] CharacterSaveData extensions (cumulative_level, promotion_count, class tracking)
- [x] ExperienceConfig extensions (promotion bonuses, level reset toggle)
- [x] ExperienceManager integration (promotion eligibility check on level-up)
- [x] PromotionCeremony UI (full-screen transformation with fanfare)
- [x] Unit tests (26 passing tests)

### Remaining (Phase 4.2)
- [ ] PartyManager persistence for promoted classes
- [ ] Unit.apply_promotion() method
- [ ] Battle/menu UI trigger for promotion
- [ ] Audio asset: promotion_fanfare.wav/ogg

---

## Executive Summary

The promotion system is THE signature Shining Force mechanic - class advancement with visual transformation, stat preservation, and strategic depth. This plan synthesizes senior staff analysis to deliver a system that is:

- **Simple** enough for reliable Phase 4 delivery
- **Flexible** enough for comprehensive mod support
- **Authentic** to the Shining Force feel while avoiding historical design flaws

---

## Design Decisions

### 1. Stat Handling: SF2 Model (100% Preservation)

- Level resets to 1 upon promotion
- All current stats carry over completely (no SF1-style 85% bug)
- Promoted classes have better growth rates
- Optional: configurable flat stat bonuses on promotion

### 2. Delayed Promotion: SF3-Style (No Penalty)

- Promote at minimum level without anxiety
- No hidden "wait until 20" optimal strategy
- Promoted classes simply have better growth rates
- Mods can add milestone bonuses if desired

### 3. Branching Paths: Core Feature

- Support standard promotion + item-gated special promotion
- SF2 reference: Knight → Paladin (standard) OR → Pegasus Knight (with item)
- Two paths per class maximum (SF-appropriate complexity)

### 4. Architecture: New PromotionManager Autoload

- Dedicated singleton for promotion orchestration
- Separate from ExperienceManager (distinct domain)
- Signals for UI integration and mod hooks

---

## Existing Infrastructure

| Component | Location | Status |
|-----------|----------|--------|
| `ClassData.promotion_class` | `core/resources/class_data.gd:49` | Exists |
| `ClassData.promotion_level` | `core/resources/class_data.gd:51` | Exists (default 10) |
| `ExperienceManager.unit_promoted` | `core/systems/experience_manager.gd:40` | Signal defined, not wired |
| Editor plugin for promotion | `addons/sparkling_editor/ui/class_editor.gd` | Exists |

---

## Implementation Phases

### Phase 4.1: Core PromotionManager

**New File:** `core/systems/promotion_manager.gd`

**Signals:**
```gdscript
signal promotion_available(unit: Node2D)
signal promotion_started(unit: Node2D, old_class: ClassData, new_class: ClassData)
signal promotion_completed(unit: Node2D, old_class: ClassData, new_class: ClassData, stat_changes: Dictionary)
signal promotion_cancelled(unit: Node2D)
```

**Core Methods:**
```gdscript
func can_promote(unit: Node2D) -> bool
func get_available_promotions(unit: Node2D) -> Array[ClassData]
func has_item_for_special_promotion(unit: Node2D) -> bool
func execute_promotion(unit: Node2D, target_class: ClassData) -> Dictionary
```

### Phase 4.2: ClassData Extensions

**Add to `core/resources/class_data.gd`:**
```gdscript
@export_group("Special Promotion")
@export var special_promotion_class: ClassData
@export var special_promotion_item: ItemData
```

### Phase 4.3: CharacterSaveData Extensions

**Add to `core/resources/character_save_data.gd`:**
```gdscript
@export_group("Promotion Tracking")
@export var cumulative_level: int = 1
@export var promotion_count: int = 0
@export var current_class_mod_id: String = ""
@export var current_class_resource_id: String = ""
```

### Phase 4.4: ExperienceConfig Extensions

**Add to `core/resources/experience_config.gd`:**
```gdscript
@export_group("Promotion Stat Bonuses")
@export_range(0, 20) var promotion_bonus_hp: int = 0
@export_range(0, 10) var promotion_bonus_mp: int = 0
@export_range(0, 5) var promotion_bonus_strength: int = 0
# ... etc for all stats

@export_group("Promotion Options")
@export var promotion_resets_level: bool = true
@export var consume_promotion_item: bool = true
```

### Phase 4.5: ExperienceManager Integration

**Modify `core/systems/experience_manager.gd`:**
- Emit `promotion_available` when level threshold reached in `apply_level_up()`

### Phase 4.6: Promotion Ceremony UI

**New Files:**
- `scenes/ui/promotion_ceremony.tscn`
- `scenes/ui/promotion_ceremony.gd`

**Requirements:**
- Full-screen CanvasLayer overlay
- Character sprite transformation animation
- Old Class → New Class display
- Stat change list
- "PROMOTED!" banner
- Fanfare sound effect (CRITICAL)

### Phase 4.7: PartyManager Integration

**Modify `core/systems/party_manager.gd`:**
- Add `apply_promotion()` method
- Update save/load to handle promoted class references

### Phase 4.8: Unit Component Updates

**Modify:**
- `core/components/unit.gd` - add `apply_promotion()` method
- `core/components/unit_stats.gd` - add stat recalculation for promotion

### Phase 4.9: Editor Plugin Updates

**Modify `addons/sparkling_editor/ui/class_editor.gd`:**
- Add UI for `special_promotion_class` dropdown
- Add UI for `special_promotion_item` dropdown

### Phase 4.10: Testing

**New File:** `tests/unit/test_promotion_manager.gd`

**Test Cases:**
1. `can_promote()` returns false before level requirement
2. `can_promote()` returns true at/after level requirement
3. `get_available_promotions()` returns standard path only when no item
4. `get_available_promotions()` returns both paths when item available
5. `execute_promotion()` resets level to 1
6. `execute_promotion()` applies stat bonuses
7. Cumulative level preserved across promotions
8. Equipment unequipped if incompatible with new class
9. Promotion state persists through save/load

---

## Integration Points

| System | Integration |
|--------|-------------|
| **ExperienceManager** | Emits `promotion_available` at level threshold |
| **PromotionManager** | Orchestrates logic, emits signals |
| **BattleManager** | Shows promotion ceremony UI |
| **PartyManager** | Persists promotion state |
| **SaveManager** | No changes (CharacterSaveData handles it) |
| **UnitStats** | Recalculates stats on promotion |
| **ClassData** | Defines promotion paths |
| **ItemData** | Special promotion items |

---

## Mod Extensibility

### Custom Promotion Requirements

For requirements beyond level (story flags, etc.):
- Add `promotion_requirement_flag: String` to ClassData
- If set, character must have flag to promote

### Custom Classes

Mods define classes in `mods/*/data/classes/*.tres` with:
- Custom `promotion_class` references
- Custom `special_promotion_class` + item
- Custom growth rates for promoted classes

---

## Fan Expectations (Non-Negotiable)

Per Lt. Ears fandom intelligence:

1. **Visual transformation animation** - The sprite change is sacred
2. **Triumphant fanfare music** - Audio cue is mandatory
3. **Visible stat improvements** - Show the numbers
4. **Sprite change** - New class = new look
5. **Every character promotes** - No dead-end units

---

## Traps to Avoid

| Trap | Solution |
|------|----------|
| Punish early promotion | SF3-style (no delayed bonuses) |
| Equipment surprise | Validate/warn before confirming |
| No visual payoff | Ceremony UI is mandatory |
| Dead-end characters | Every unit gets promotion path |
| Hidden optimal strategy | Remove or make explicit |

---

## File Summary

**New Files:**
- `core/systems/promotion_manager.gd`
- `scenes/ui/promotion_ceremony.tscn`
- `scenes/ui/promotion_ceremony.gd`
- `tests/unit/test_promotion_manager.gd`

**Modified Files:**
- `core/resources/class_data.gd`
- `core/resources/character_save_data.gd`
- `core/resources/experience_config.gd`
- `core/systems/experience_manager.gd`
- `core/systems/party_manager.gd`
- `core/components/unit.gd`
- `core/components/unit_stats.gd`
- `addons/sparkling_editor/ui/class_editor.gd`
- `project.godot`

---

*"The promotion system is critical to SF identity. Fans will judge The Sparkling Farce primarily on whether promotions feel right."* — Lt. Ears

*Live long and promote often.*
