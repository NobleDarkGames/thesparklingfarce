# Codebase Audit Findings

**Date:** January 14, 2026
**Auditors:** 6 parallel agents (mr-spec x3, burt-macklin, major-testo, chief-engineer-obrien)

---

## Executive Summary

Architecture is **SOUND**. Documentation had significant drift from reality (now corrected). Several incomplete features and test gaps identified.

---

## Spec Updates Completed

### platform-specification.md
- Removed CampaignManager (doesn't exist - 30 autoloads, not 31)
- Removed `campaigns/` resource type and CampaignData
- Fixed JSON-supported types: `cinematic, map` (removed campaign)
- Fixed debug console keys: `F12 or ~` (removed F1)
- Removed `DebugConsole._is_other_modal_active()` reference
- Added VirtualSpawnHandler to spawnable types
- Added `core/templates/`, `core/tools/`, `core/utils/` to directory structure

### stat-growth-system.md
- Fixed growth rate defaults to match code (hp=100, mp=60, str=80, def=80, agi=70, int=70, luk=50)
- Removed stale TODO

### baseline-character-spec.md
- Added note clarifying CharacterData editor defaults differ from baseline

### Deleted (outdated internal docs)
- multi-screen-shop-architecture.md
- shop-interface-ux-specification.md
- shop-interface-wireframes.md

---

## Critical Code Issues (NOT YET FIXED)

### P0 - Promotion Bonuses Not Implemented
**Location:** `core/resources/experience_config.gd`
**Issue:** ExperienceConfig lacks `promotion_bonus_*` properties. PromotionManager looks for them but they don't exist, so promotions give 0 stat boost.
**SF2 Reference:** Promotions should give immediate one-time bonuses (HP+20-40, ATK+15-30, DEF+15-30, AGI+10-20, INT+10-20)
**Fix:** Add to ExperienceConfig:
```gdscript
@export_group("Promotion Bonuses")
@export var promotion_bonus_hp: int = 30
@export var promotion_bonus_mp: int = 15
@export var promotion_bonus_strength: int = 22
@export var promotion_bonus_defense: int = 22
@export var promotion_bonus_agility: int = 15
@export var promotion_bonus_intelligence: int = 15
@export var promotion_bonus_luck: int = 10
```

### P0 - Buff/Debuff Spells Do Nothing
**Location:** `core/systems/battle_manager.gd` lines 674-680
**Issue:** AbilityType.SUPPORT and AbilityType.DEBUFF cases just push_warning and set effect_applied = false
**Fix:** Implement status effect application using existing StatusEffectData system

### P1 - xp_per_level Config Unused
**Location:** `core/resources/experience_config.gd:104` vs `core/components/unit_stats.gd:28`
**Issue:** ExperienceConfig has `xp_per_level: int = 100` but UnitStats hardcodes `xp_to_next_level: int = 100`
**Fix:** Initialize UnitStats.xp_to_next_level from ExperienceManager.config.xp_per_level

### P1 - BBCode in Regular Label
**Location:** `scenes/ui/shops/screens/char_select.gd` line 170
**Issue:** Uses `[color=green]` BBCode syntax but stat_comparison_label is a regular Label, not RichTextLabel
**Fix:** Change to RichTextLabel or use theme color overrides

---

## Incomplete Features (TODOs in Code)

### Critical
| Feature | Location | Notes |
|---------|----------|-------|
| Buff/Debuff spell effects | battle_manager.gd:674-680 | Support abilities useless |
| Custom trigger system | trigger_manager.gd:511-515 | `_handle_custom_trigger()` is stub |
| Scroll transition | trigger_manager.gd:464-466 | Falls back to fade |

### Moderate
| Feature | Location | Notes |
|---------|----------|-------|
| Unit stats panel in battle | input_manager.gd:844-850 | Press A on unit shows nothing |
| Game menu in battle | input_manager.gd:847-850 | Press A on empty cell |
| AI buff item processing | ai_brain_editor.gd:530-538 | Setting exposed but not processed |
| AI idle turn patience | ai_brain_editor.gd:604-613 | max_idle_turns has no effect |
| Spell animation system | ability_editor.gd:398-400 | Animation fields ignored |
| Dialog box auto-positioning | dialog_box.gd:363-365 | AUTO falls back to BOTTOM |
| Mod field menu options | exploration_field_menu.gd:330-331 | `_add_mod_options()` commented |
| Battle equip setting | item_action_menu.gd:285-286 | Always exploration-only |

### Low
| Feature | Location | Notes |
|---------|----------|-------|
| Legacy tileset registry | mod_loader.gd:103-104 | Migration TODO |
| Editor reference scanning | Multiple editors | Phase 2+ TODOs |

---

## Test Coverage Gaps

### Autoload Coverage Summary
- **Good coverage (8/30):** StorageManager, PromotionManager, ShopManager, DialogManager, CinematicsManager, EditorEventBus, plus AI/Combat
- **Partial coverage (6/30):** SaveManager, TriggerManager, AudioManager, BattleManager, TurnManager, GridManager
- **No coverage (16/30):** SceneManager, ExperienceManager, InputManager, PartyManager, CaravanController, ExplorationUIManager, GameJuice, DebugConsole, RandomManager, SettingsManager, GameEventBus, LocalizationManager, CraftingManager, EquipmentManager (indirect only)

### Critical Untested Systems
| System | Lines | Risk |
|--------|-------|------|
| InputManager | 2,392 | HIGH - all player input |
| SceneManager | 263 | HIGH - scene transitions |
| PartyManager | 864 | HIGH - roster/save data |
| TurnManager | 710 | MEDIUM - battle flow |
| GridManager | 700 | MEDIUM - pathfinding |

### Test Suite Stats
- Total test files: 61
- Total test functions: ~1,350
- Unit tests: 47 files
- Integration tests: 13 files

---

## Bugs Found

| Bug | Location | Severity | Fix |
|-----|----------|----------|-----|
| BBCode in Label | char_select.gd:170 | Medium | Use RichTextLabel |
| Promotion item check always passes | promotion_manager.gd:189-197 | Medium | Fix fallback logic |
| Missing signal cleanup | sell_char_select.gd | Low | Add `_on_screen_exit()` |
| Hardcoded inventory size | placement_mode.gd:71,138 | Low | Use config value |
| Equipment HP clamp asymmetry | unit_stats.gd:143-145 | Low | Intentional? (SF2 style) |

---

## Architecture Assessment

**Status: SOUND**

No circular dependencies or major violations. Consistent patterns throughout:
- Registry pattern for all resource types
- Signal-driven architecture
- Resource-based data (mod-friendly)
- Strict typing enforced

---

## Undocumented Features (May Need User Docs)

1. **Character UID System** - 8-char unique IDs for stable references
2. **VirtualSpawnHandler** - Off-screen actors for narrators/thoughts
3. **Church Services** - HEAL, REVIVE, UNCURSE, PROMOTION, SAVE modes in shop system
4. **Crafter System** - Recipe browser, material transformation
5. **AI Threat Configuration** - ai_threat_modifier, ai_threat_tags on characters
6. **Equipment Bonus System** - Full stat modifier caching in UnitStats
7. **Status Effect System** - 11 effects with behavior types
8. **Text Interpolation** - {player_name}, {char:id}, {flag:name}, {var:key} syntax

---

## Recommended Priority

### Immediate (Before Alpha)
1. Fix promotion bonuses (ExperienceConfig)
2. Fix buff/debuff spells (BattleManager)
3. Fix BBCode bug (char_select.gd)

### High Priority
4. Apply xp_per_level config
5. Add InputManager tests
6. Add PartyManager tests
7. Add SceneManager tests

### Medium Priority
8. Implement spell animation system
9. Complete AI buff item processing
10. Add unit stats panel in battle

---

## Files Changed This Session

### Updated
- docs/specs/platform-specification.md
- docs/specs/stat-growth-system.md
- docs/specs/baseline-character-spec.md
- scenes/battle_loader.gd (removed stale TODO)

### Deleted
- docs/specs/multi-screen-shop-architecture.md
- docs/specs/shop-interface-ux-specification.md
- docs/specs/shop-interface-wireframes.md

### Not Yet Committed
- docs/AUDIT_FINDINGS.md (this file)
