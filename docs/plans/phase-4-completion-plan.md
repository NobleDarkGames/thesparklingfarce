# Phase 4 Completion Plan

**Author:** Lt. Claudbrain, USS Torvalds
**Date:** 2025-12-11
**Status:** Planning Document for Captain Review
**Current Phase:** Phase 4 - Core Mechanics (Equipment, Magic, Items)

---

## Executive Summary

This document details the remaining Phase 4 tasks with implementation specifics for each. Each task is self-contained so the Captain can review and comment individually before implementation proceeds.

**Completed Phase 4 Work:**
- Phase 4.1: Promotion System (Complete)
- Phase 4.2: Equipment System (Complete)
- Phase 4.3: Item Effect Execution (Complete - 2025-12-12)
- Phase 4.4: Caravan System (Complete)
- Phase 4.5: Campaign Progression (Complete)
- Spell System S1-S3 (Complete - spells work in battle)
- Floating Damage/XP Numbers (Complete - 2025-12-12, SF-authentic via CombatAnimationScene)

**Remaining Tasks (Priority Order):**
1. Spell Progression (S4) - Level-based unlocks, AoE spells
2. Retreat/Resurrection System
3. Level-Up Screen UI
4. Victory/Defeat Screens with Rewards
5. Field Menu Phase 2: Egress/Detox field magic
6. Field Menu Phase 3: Search system & hidden items
7. Field Menu Phase 4: Mod extension support
8. Phase 2.5.1 Mod Extensibility Improvements

---

## Task 1: Item Effect Execution (USE Action) ✅ COMPLETE

**Completed:** 2025-12-12

### Implementation Status
- ✅ ItemMenu displays inventory with smart defaults and descriptions
- ✅ Full target selection system (`SELECTING_ITEM_TARGET` state)
- ✅ `_apply_item_effect()` handles HEAL and ATTACK effects
- ✅ `_consume_item_from_inventory()` removes items after use
- ✅ `_award_item_use_xp()` gives SF-authentic XP for item usage
- ✅ Visual feedback via CombatAnimationScene
- ✅ Field menu USE action in `member_detail.gd`

### Remaining (Low Priority)
- SUPPORT/DEBUFF/SPECIAL item effects have placeholder warnings (depends on status effect system)

### Original Plan (for reference)

1. **Battle Item Use Flow Verification:**
   - InputManager receives item_selected signal from ItemMenu
   - Target selection for items that need targets (healing others)
   - BattleManager._on_item_use_requested() executes effect

2. **Item Targeting System:**
   - Single-target healing items (Healing Herb -> select ally)
   - Self-only items (Antidote on self when poisoned)
   - Currently items default to self-targeting; need target selection

3. **Visual Feedback:**
   - Flash effect on heal (exists but needs verification)
   - Item consumption confirmation message
   - MP/HP bar updates after item use

### Files to Modify
| File | Purpose |
|------|---------|
| `core/systems/input_manager.gd` | Add SELECTING_ITEM_TARGET state |
| `core/systems/battle_manager.gd` | Verify item targeting flow |
| `scenes/ui/item_menu.gd` | Verify target selection integration |

### Key Implementation Steps
1. Add `SELECTING_ITEM_TARGET` state to InputManager (if not present)
2. Wire item selection -> target selection -> execution flow
3. Test with healing_herb.tres on injured ally
4. Add floating number for heal amount (ties to Task 4)
5. Manual testing in battle

### Complexity Estimate
**Simple** - Infrastructure exists, needs wiring and testing

### Dependencies
- None (can proceed immediately)

---

## Task 2: Spell Progression (S4) - Level-Based Unlocks

### Current State
- `ClassData.class_abilities` holds spell arrays
- `ClassData.ability_unlock_levels` dictionary exists: `{"blaze_2": 8}`
- `ClassData.get_unlocked_class_abilities(level)` method implemented
- `ClassData.is_ability_unlocked(ability_id, level)` method exists
- SpellMenu currently shows ALL class abilities regardless of level

### What Needs Implementation

1. **SpellMenu Level Filtering:**
   - Filter displayed spells by character's current level
   - Grey out or hide spells above current level

2. **Level-Up Spell Notifications:**
   - ExperienceManager emits `unit_learned_ability` signal (exists)
   - BattleManager has placeholder handler (needs implementation)
   - Show "Max learned Blaze 2!" notification

3. **AoE Spell Implementation:**
   - AbilityData has `area_of_effect: int` field (exists, unused)
   - Target selection shows AoE preview tiles
   - BattleManager applies damage to all units in AoE

4. **Spell Tier Display:**
   - Show spell levels in SpellMenu (Blaze 1, Blaze 2, etc.)
   - Higher tiers cost more MP, deal more damage

### Files to Modify
| File | Purpose |
|------|---------|
| `scenes/ui/spell_menu.gd` | Filter by level, show spell tiers |
| `core/systems/input_manager.gd` | AoE target preview |
| `core/systems/battle_manager.gd` | AoE damage application |
| `scenes/ui/level_up_celebration.gd` | Add spell learned display |

### Key Implementation Steps
1. Modify SpellMenu to call `class_data.get_unlocked_class_abilities(level)`
2. Add spell tier display in menu (e.g., "Blaze 2 - 4 MP")
3. Implement AoE target preview in GridManager/InputManager
4. Modify `_apply_spell_damage()` to iterate AoE targets
5. Create ability learned notification UI
6. Create test spells: blaze_2.tres, heal_2.tres with unlock levels

### Complexity Estimate
**Medium** - Core exists, AoE adds complexity

### Dependencies
- None directly, but Task 4 (floating numbers) enhances feedback

---

## Task 3: Retreat/Resurrection System

### Current State
- Units die when HP reaches 0 (handled in Unit.take_damage())
- Dead units fade out via BattleManager._on_unit_died()
- No retreat or resurrection mechanics exist
- DefeatScreen offers retry or return to town
- ChurchShop type exists with revive service hook

### What Needs Implementation

**SF2-Authentic Design:**
In Shining Force, defeated units are NOT permanently dead. They can be:
1. **Resurrected at Church** - Pay gold based on level
2. **Retreat automatically** - Unit leaves battle but survives
3. **Hero death = defeat** - If hero dies, battle ends

1. **Unit Death State Machine:**
   - `ALIVE` -> `RETREATED` (HP=0, survives battle)
   - Track retreat status in CharacterSaveData
   - Retreated units excluded from party until healed

2. **Church Resurrection Service:**
   - ShopData.shop_type == CHURCH already supported
   - `revive_base_cost` field exists in ShopData
   - Cost formula: `revive_base_cost * unit_level`
   - Resurrect sets HP to 1, clears retreat flag

3. **Battle Integration:**
   - Dead player units marked as "retreated" not "dead"
   - Retreated units removed from turn order
   - Victory/Defeat still based on hero status

4. **Post-Battle Restoration:**
   - Retreated units need healing before next battle
   - Church or items can restore them

### Files to Create
| File | Purpose |
|------|---------|
| `core/systems/resurrection_manager.gd` | Manage retreat/revive state |

### Files to Modify
| File | Purpose |
|------|---------|
| `core/resources/character_save_data.gd` | Add `is_retreated: bool` |
| `core/components/unit.gd` | Mark retreat on death instead of permanent |
| `core/systems/battle_manager.gd` | Handle retreat state |
| `scenes/ui/shops/screens/church_services_screen.gd` | Implement revive UI |
| `core/systems/shop_manager.gd` | Add revive transaction |

### Key Implementation Steps
1. Add `is_retreated: bool` to CharacterSaveData
2. Modify Unit.take_damage() to set retreat flag
3. Modify TurnManager to skip retreated units
4. Add Church "Revive" service screen
5. Implement revive cost calculation
6. Add revive sound/animation
7. Test full flow: unit dies -> church revive -> rejoin battle

### Complexity Estimate
**Medium** - Touches multiple systems but clear design

### Dependencies
- Church shop UI (exists)
- CharacterSaveData persistence (exists)

---

## Task 4: Floating Damage/XP Numbers ✅ COMPLETE (SF-Authentic)

**Completed:** 2025-12-12

### Implementation Status
The SF-authentic approach is **already implemented** in `CombatAnimationScene`:

- ✅ `_show_damage_number()` - Floating numbers with tween animation (50px rise, fade out)
- ✅ `_show_heal_number()` - Green healing numbers with "+" prefix
- ✅ Critical hit styling (48px yellow vs 32px white for normal)
- ✅ Miss text display in gray
- ✅ XP panel with staggered entry animation
- ✅ Skip mode: `CombatResultsPanel` shows combat text + XP on map

### Design Note
The original plan envisioned numbers floating on the **tactical map sprites** (modern Fire Emblem style). The current implementation uses the **SF2-authentic approach** where damage displays in the combat animation overlay. This is the correct behavior for Shining Force authenticity.

### Future Enhancement (Optional)
If desired, tactical map floating numbers could be added as a **polish feature** for skip mode, but this is not required for SF-authentic gameplay.

### Original Plan (for reference)

---

## Task 5: Level-Up Screen UI

### Current State
- `LevelUpCelebration` scene exists in `/scenes/ui/level_up_celebration.gd`
- Shows basic level up with stat increases
- Triggered by ExperienceManager.unit_leveled_up signal
- BattleManager queues and displays sequentially

### What Needs Implementation

**Polish Items:**
1. Show before/after stats comparison
2. Animate stat increases (count up effect)
3. Show new abilities learned (ties to Task 2)
4. SF2-authentic fanfare timing
5. Portrait display for the leveled unit

### Files to Modify
| File | Purpose |
|------|---------|
| `scenes/ui/level_up_celebration.gd` | Enhanced stat display |
| `scenes/ui/level_up_celebration.tscn` | Layout for before/after |

### Key Implementation Steps
1. Add before/after columns for stats
2. Animate stat numbers counting up
3. Add unit portrait (if available)
4. Add "Learned [Ability]!" section
5. Polish timing to match SF2 feel

### Complexity Estimate
**Simple** - UI polish on existing foundation

### Dependencies
- Task 2 (spell progression) for ability learned display

---

## Task 6: Victory/Defeat Screens with Rewards

### Current State
- `VictoryScreen` shows "VICTORY!" and gold earned
- `DefeatScreen` offers Retry or Return options
- Gold earning not calculated (hardcoded 0)
- No item drops or battle rewards

### What Needs Implementation

1. **Gold Reward Calculation:**
   - Sum gold from defeated enemies
   - EnemyData or CharacterData needs `gold_reward` field
   - Display breakdown on victory screen

2. **Item Drops (Optional Enhancement):**
   - Enemies can drop items on defeat
   - Add `drop_items: Array[String]` to enemy spawn data
   - Show dropped items on victory screen

3. **Experience Summary:**
   - Show total XP gained during battle
   - List units that leveled up

4. **SF2-Authentic Defeat Handling:**
   - Half gold penalty on defeat
   - Return to last church/save point
   - Show gold lost amount

### Files to Modify
| File | Purpose |
|------|---------|
| `scenes/ui/victory_screen.gd` | Gold calculation, item display |
| `scenes/ui/victory_screen.tscn` | Layout for rewards |
| `scenes/ui/defeat_screen.gd` | Gold penalty display |
| `core/resources/character_data.gd` | Add `gold_reward: int` |
| `core/systems/battle_manager.gd` | Calculate rewards |

### Key Implementation Steps
1. Add `gold_reward` to CharacterData (for enemies)
2. Calculate gold total from defeated enemies
3. Update victory screen to show breakdown
4. Implement gold penalty on defeat
5. (Optional) Add item drop system
6. Test full victory/defeat flows

### Complexity Estimate
**Simple to Medium** - Depends on item drop scope

### Dependencies
- None for basic gold rewards

---

## Task 7: Field Menu Phase 2 - Egress/Detox Magic

### Current State
- Field menu shows Item, Magic, Search, Member
- Magic option appears but shows "No field magic available"
- AbilityData has no `usable_on_field` flag
- No Egress or Detox spells exist

### What Needs Implementation

**SF2-Authentic Field Magic:**
Only TWO spells work in the field menu:
- **Egress**: Teleport party to last town (escape dungeon)
- **Detox**: Cure poison status (not yet implemented)

1. **AbilityData Extension:**
   - Add `usable_on_field: bool = false`
   - Only Egress and Detox get this flag

2. **FieldMagicMenu Implementation:**
   - Caster selection (who has Egress/Detox)
   - Spell selection from that character
   - MP cost display and checking

3. **Egress Implementation:**
   - Store last town position in GameState
   - Fade out, teleport party, fade in
   - Play Egress sound effect

4. **Detox Implementation:**
   - Requires status effect system (not yet implemented)
   - Can defer until status effects exist

### Files to Create
| File | Purpose |
|------|---------|
| `scenes/ui/field_magic_menu.gd` | Caster/spell selection |
| `scenes/ui/field_magic_menu.tscn` | Menu scene |
| `mods/_base_game/data/abilities/egress.tres` | Egress spell |
| `mods/_base_game/data/abilities/detox.tres` | Detox spell |

### Files to Modify
| File | Purpose |
|------|---------|
| `core/resources/ability_data.gd` | Add `usable_on_field` |
| `scenes/ui/exploration_field_menu.gd` | Wire magic option |
| `core/systems/game_state.gd` | Track last town for Egress |

### Key Implementation Steps
1. Add `usable_on_field` to AbilityData
2. Create Egress ability with `usable_on_field: true`
3. Create FieldMagicMenu with caster selection
4. Implement Egress teleport via SceneManager
5. Track last town entry point in GameState
6. Defer Detox until status effects exist

### Complexity Estimate
**Medium** - New menu + teleport logic

### Dependencies
- Field menu Phase 1 (Complete)
- Status effects (for Detox - can defer)

---

## Task 8: Field Menu Phase 3 - Search System & Hidden Items

### Current State
- Search option shows "Nothing unusual here" placeholder
- No hidden item data structure exists
- No tile description system

### What Needs Implementation

1. **Hidden Item Data Structure:**
   - Per-map hidden items in MapMetadata or separate resource
   - Position, item_id, flag to track if found

2. **Search Execution:**
   - Check hero position against hidden items
   - One-time collection via GameState flags
   - Display found item via DialogManager

3. **Tile Descriptions:**
   - Optional flavor text for terrain
   - "You see a sturdy stone wall."
   - Stored in TerrainData or MapMetadata

### Files to Create
| File | Purpose |
|------|---------|
| `core/resources/hidden_item_data.gd` | Hidden item definition |

### Files to Modify
| File | Purpose |
|------|---------|
| `core/resources/map_metadata.gd` | Add hidden_items array |
| `scenes/ui/exploration_field_menu.gd` | Implement search logic |
| `core/templates/map_template.gd` | Load hidden items |

### Key Implementation Steps
1. Create HiddenItemData resource class
2. Add `hidden_items: Array[HiddenItemData]` to MapMetadata
3. Implement search check in ExplorationFieldMenu
4. Show result via DialogManager
5. Mark found with GameState flag
6. Add Editor support in MapMetadataEditor

### Complexity Estimate
**Medium** - New data structure and editor support

### Dependencies
- Field menu Phase 1 (Complete)
- DialogManager (Complete)

---

## Task 9: Field Menu Phase 4 - Mod Extension Support

### Current State
- Field menu has 4 hardcoded options
- No mod extension mechanism
- Plan exists in exploration-field-menu-plan.md

### What Needs Implementation

**Simplified Approach (per Modro's review):**
- Parse `field_menu_options` from mod.json
- No registry - just iterate loaded mods
- Scene-based only (no callbacks)

1. **ModManifest Extension:**
   - Add `field_menu_options: Dictionary` property
   - Parse from mod.json during load

2. **ExplorationFieldMenu Integration:**
   - Build options list including mod options
   - Position options (start, end, after_X)
   - Total conversion support (`_replace_all`)

### Files to Modify
| File | Purpose |
|------|---------|
| `core/mod_system/mod_manifest.gd` | Parse field_menu_options |
| `scenes/ui/exploration_field_menu.gd` | Build dynamic options |

### mod.json Format
```json
{
  "field_menu_options": {
    "bestiary": {
      "label": "Bestiary",
      "scene_path": "scenes/ui/bestiary.tscn",
      "position": "end"
    }
  }
}
```

### Key Implementation Steps
1. Add `field_menu_options: Dictionary` to ModManifest
2. Parse in ModManifest._parse_json()
3. Implement `_build_menu_options()` in ExplorationFieldMenu
4. Support position options: start, end, after_item, etc.
5. Support `_replace_all: true` for total conversions
6. Test with _sandbox mod adding custom option

### Complexity Estimate
**Simple** - ~70 lines per plan

### Dependencies
- Field menu Phase 1 (Complete)

---

## Task 10: Phase 2.5.1 Mod Extensibility Improvements

### Current State
Per `/docs/plans/phase-2.5.1-mod-extensibility-plan.md`:
- Status: COMPLETE (December 1, 2025)
- All four improvements implemented

**What Was Implemented:**
1. Trigger Type Registry & Discovery (Complete)
2. String-Based Trigger Types (Complete)
3. Namespaced Story Flags (Complete)
4. TileSet Resolution (Complete)

### Remaining Work
Documentation only:
- Update MOD_SYSTEM.md with new capabilities
- Create example mod demonstrating all 4 improvements
- Modder-facing documentation

### Complexity Estimate
**Simple** - Documentation only

### Dependencies
- None (implementation complete)

---

## Implementation Priority Matrix

| Task | Priority | Effort | Impact | Status |
|------|----------|--------|--------|--------|
| ~~1. Item Effects~~ | ~~High~~ | ~~Simple~~ | ~~High~~ | ✅ COMPLETE |
| ~~4. Floating Numbers~~ | ~~Medium~~ | ~~Simple~~ | ~~High~~ | ✅ COMPLETE |
| 1. Spell Progression | High | Medium | High | Next |
| 2. Retreat/Resurrect | High | Medium | High | Pending |
| 3. Victory/Defeat | Medium | Simple | Medium | Pending |
| 4. Level-Up UI | Low | Simple | Low | Pending |
| 5. Field Magic | Medium | Medium | Medium | Pending |
| 6. Search System | Low | Medium | Low | Pending |
| 7. Field Mod Ext | Low | Simple | Low | Pending |
| 8. Mod Docs | Low | Simple | Low | Pending |

---

## Total Estimated Effort (Remaining)

| Category | Tasks | Hours |
|----------|-------|-------|
| Simple | 3, 4, 7, 8 | 8-12 |
| Medium | 1, 2, 5, 6 | 16-24 |
| **Total** | | **24-36 hours** |

---

## Testing Strategy

### Unit Tests Required
- ~~Item effect application (heal, damage)~~ ✅ Verified manually
- Spell level filtering
- Retreat state transitions
- Hidden item discovery

### Integration Tests Required
- ~~Full battle with item use~~ ✅ Verified manually (healing herb)
- Level up with new spell notification
- Church resurrection flow
- Field menu magic casting

### Manual Testing Checklist
- [ ] Use Healing Herb on injured ally in battle
- [ ] Cast Blaze on enemy, see floating damage
- [ ] Level up and learn new spell
- [ ] Win battle, see gold earned
- [ ] Lose battle, see gold penalty
- [ ] Unit dies, resurrect at church
- [ ] Cast Egress in dungeon, return to town
- [ ] Search tile, find hidden item
- [ ] Add mod with custom field menu option

---

## Open Questions for Captain Review

1. **Item Drop System Scope:**
   - Basic implementation (enemies drop fixed items)?
   - Or defer to Phase 5 with loot tables?

2. **Status Effects Priority:**
   - Detox requires poison status effect
   - Implement status effects now or defer?

3. **Floating Number Style:**
   - Classic SF2 (simple rising numbers)?
   - Or modern polish (particle effects)?

4. **Retreat vs Permadeath Option:**
   - Make retreat default (SF-authentic)?
   - Or configurable in NewGameConfigData?

---

**Plan Submitted:** 2025-12-11
**Awaiting Captain Review**

*Make it so.*
