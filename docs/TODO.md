# The Sparkling Farce - Pending Tasks

This document tracks all pending work items. Verified 2026-01-21.

---

## Release Blocking (Priority: CRITICAL)

2 items remaining before alpha release:

- [ ] Complete modder documentation Tutorial 4 (Abilities and Magic) - Tutorial 3 links to it
- [ ] Replace 23 [PLACEHOLDER] entries across README.md, CONTRIBUTING.md, CODE_OF_CONDUCT.md, CREDITS.md, and .github/

**Estimated effort:** 1-2 days focused work

---

## Test Suite Improvements (Priority: MEDIUM)

### Completed (verified 2026-01-21)
- [x] Phase 5.1: AIBehaviorFactory fixture deployed to 12 AI tests
- [x] Phase 5.2: UnitStatsFactory fixture created and ready
- [x] Phase 5.3: All "_base_game" literals replaced with TEST_MOD_ID constants
- [x] Phase 5.5: Autoload dependencies documented in all 6 fixture files
- [x] Phase 5.6: GridManager integration tests exist (27 tests)
- [x] Phase 5.7: GameState unit tests exist (50+ tests)

### Still Pending
None - test suite improvements complete!

---

## Test Coverage Gaps (Priority: LOW)

High-risk uncovered systems:

1. InputManager (2,392 lines) - Partial coverage (95 tests added)
2. SceneManager (263 lines) - No coverage
3. RandomManager, SettingsManager, CraftingManager - No coverage

---

## Deferred Features (Priority: BACKLOG)

From `docs/plans/pending-known-limitations.md`:

- [ ] Dialog box auto-positioning (avoid portrait overlap)
- [ ] Mod field menu options (position parameter support)
- [ ] Spell animation system enhancements
- [ ] Additional cinematic commands
- [ ] Save slot management improvements
- [ ] Advanced AI behavior patterns

---

## Code Simplification (Priority: COMPLETE)

All batches from `docs/code-simplifier-plan.md` are complete:

- [x] Batches 1.3–4.1: Foundation cleanup (-1,322 lines)
- [x] Batch 4.2: Secondary Editor Files (-16 lines)
- [x] Batch 5.1: Remaining Systems (-128 lines)
- [x] Batch 5.2: Caravan & Members UI (-44 lines)

**Total: -1,510 lines removed**

---

## Recently Completed

Community documentation (2026-01-21):
- [x] CONTRIBUTING.md - Development setup, code standards, PR process
- [x] CODE_OF_CONDUCT.md - Contributor Covenant 2.1
- [x] CREDITS.md - Attribution for libraries, inspirations, contributors
- [x] .github/ISSUE_TEMPLATE/ - Bug report and feature request forms
- [x] .github/PULL_REQUEST_TEMPLATE.md - PR checklist

Test suite orphan fix (2026-01-21):
- [x] test_character_editor_validation.gd - Refactored to mock-based (525 orphans → 0)

Code simplification batches 4.2–5.2 (2026-01-21):
- [x] Batch 4.2: -16 lines (editor helpers)
- [x] Batch 5.1: -128 lines (core system consolidation)
- [x] Batch 5.2: -44 lines (Caravan/Members UI centralization)

Verified fixed (was in old audit findings):
- [x] Buff/Debuff spells - Now implemented via _apply_spell_status()
- [x] BBCode in char_select.gd - Correctly uses RichTextLabel
- [x] xp_per_level config - Properly initialized from ExperienceConfig

Test suite improvements:
- [x] Test polling migration (GdUnit4 v6.0.2+)
- [x] Test suite cleanup phases 1-4
- [x] InputManager basic coverage (95 tests)

---

## Reference Documents

- `docs/untracked/PHASE_STATUS.md` - High-level project status
- `docs/untracked/RELEASE_READINESS_ASSESSMENT.md` - Release criteria details
- `docs/specs/platform-specification.md` - Technical specification
