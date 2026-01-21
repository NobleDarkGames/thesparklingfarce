# The Sparkling Farce - Pending Tasks

This document tracks all pending work items. Verified 2026-01-20.

---

## Release Blocking (Priority: CRITICAL)

All 6 items still needed before alpha release:

- [ ] Complete modder documentation Tutorial 4 (Abilities and Magic) - Tutorial 3 links to it
- [ ] Replace 8 [PLACEHOLDER] URLs in README.md
- [ ] Create CONTRIBUTING.md
- [ ] Create CODE_OF_CONDUCT.md
- [ ] Create CREDITS.md with attribution documentation
- [ ] Create .github/ISSUE_TEMPLATE/ and .github/PULL_REQUEST_TEMPLATE.md

**Estimated effort:** 4-7 days focused work

---

## Test Suite Improvements (Priority: MEDIUM)

### Completed (verified 2026-01-20)
- [x] Phase 5.1: AIBehaviorFactory fixture deployed to 12 AI tests
- [x] Phase 5.2: UnitStatsFactory fixture created and ready
- [x] Phase 5.3: All "_base_game" literals replaced with TEST_MOD_ID constants

### Still Pending
- [ ] Fix 54 orphan nodes in test_character_editor_validation.gd (use Option A: mock validation logic per docs/plans/test-suite-orphan-fixes.md)
- [ ] Phase 5.5: Document autoload dependencies in fixture files
- [ ] Phase 5.6: Add GridManager integration tests
- [ ] Phase 5.7: Add GameState unit tests

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

## Code Simplification (Priority: BACKLOG)

From `docs/code-simplifier-plan.md` - Remaining batches:

- [ ] Batch 4.2: Secondary Editor Files (8 files, ~5,700 lines)
- [ ] Batch 5.1: Remaining Systems (8 files, ~3,500 lines)
- [ ] Batch 5.2: Caravan & Members UI (12 files, ~2,400 lines)

**Progress:** -1,322 lines across 56 files (Batches 1.3 through 4.1 complete)

---

## Recently Completed

Verified fixed (was in old audit findings):
- [x] Buff/Debuff spells - Now implemented via _apply_spell_status()
- [x] BBCode in char_select.gd - Correctly uses RichTextLabel
- [x] xp_per_level config - Properly initialized from ExperienceConfig

Code simplification batches 1.3-4.1:
- [x] -1,322 lines across 56 files

Test suite improvements:
- [x] Test polling migration (GdUnit4 v6.0.2+)
- [x] Test suite cleanup phases 1-4
- [x] InputManager basic coverage (95 tests)

---

## Reference Documents

- `docs/untracked/PHASE_STATUS.md` - High-level project status
- `docs/untracked/RELEASE_READINESS_ASSESSMENT.md` - Release criteria details
- `docs/specs/platform-specification.md` - Technical specification
