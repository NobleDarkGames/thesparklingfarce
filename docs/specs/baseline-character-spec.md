# Baseline Character Specification

## Purpose

This document defines **"Ensign Average"** - a theoretical baseline character representing the 50th percentile across all stats. This is NOT intended as a playable character, but as a **scaling reference point** for designing actual characters.

Actual characters should be designed relative to this baseline:
- Warriors: STR/DEF **above** baseline, INT **below**
- Mages: INT **above** baseline, STR/DEF **below**
- Rogues: AGI **above** baseline, DEF **below**

---

## Baseline Starting Stats (Level 1, Unpromoted)

| Stat | Value | Rationale |
|------|-------|-----------|
| HP   | 12    | SF2 Bowie reference |
| MP   | 8     | Jack-of-all-trades can use some magic |
| STR  | 5     | True average |
| DEF  | 5     | True average |
| AGI  | 5     | True average |
| INT  | 5     | True average |
| LUK  | 5     | True average |

**Note:** CharacterData editor defaults (HP=10, MP=5) are lower than this baseline for convenience. Actual characters should be designed using these baseline values as reference.

---

## Baseline Growth Rates

Using the spec's recommended rates for "With Promotion System" (see `stat-growth-system.md`).

### Pre-Promotion Class: "Recruit"

| Stat | Growth Rate | Expected/Level | Notes |
|------|-------------|----------------|-------|
| HP   | 100         | 1.05           | Guaranteed +1, 5% lucky bonus |
| MP   | 60          | 0.65           | Moderate magic growth |
| STR  | 80          | 0.85           | Solid but not specialized |
| DEF  | 80          | 0.85           | Solid but not specialized |
| AGI  | 70          | 0.75           | Decent speed |
| INT  | 70          | 0.75           | Decent magic |
| LUK  | 50          | 0.55           | Slowest growing stat |

### Post-Promotion Class: "Veteran" (growth x 1.5)

| Stat | Growth Rate | Expected/Level | Notes |
|------|-------------|----------------|-------|
| HP   | 150         | 1.55           | +1 guaranteed, 50% for +2 |
| MP   | 90          | 0.95           | Near guaranteed +1 |
| STR  | 120         | 1.25           | +1 guaranteed, 20% for +2 |
| DEF  | 120         | 1.25           | +1 guaranteed, 20% for +2 |
| AGI  | 105         | 1.10           | +1 guaranteed, 5% for +2 |
| INT  | 105         | 1.10           | +1 guaranteed, 5% for +2 |
| LUK  | 75          | 0.80           | Still slowest |

---

## Promotion Bonuses (One-Time)

Using midpoint of spec ranges:

| Stat | Bonus | Spec Range |
|------|-------|------------|
| HP   | +30   | 20-40 |
| MP   | +15   | (inferred) |
| STR  | +22   | 15-30 |
| DEF  | +22   | 15-30 |
| AGI  | +15   | 10-20 |
| INT  | +15   | 10-20 |
| LUK  | +10   | (inferred) |

---

## Expected Stat Progression

### Key Milestones

| Level | HP | MP | STR | DEF | AGI | INT | LUK |
|-------|----|----|-----|-----|-----|-----|-----|
| **1 (start)**        | 12 | 8  | 5   | 5   | 5   | 5   | 5   |
| **10 (pre-promo)**   | 21 | 14 | 13  | 13  | 12  | 12  | 10  |
| **20 (promote)**     | 32 | 20 | 22  | 22  | 19  | 19  | 15  |
| **1P (post-promo)**  | 62 | 35 | 44  | 44  | 34  | 34  | 25  |
| **15P (mid-game)**   | 85 | 49 | 63  | 63  | 51  | 51  | 37  |
| **30P (endgame)**    | 107| 63 | 80  | 80  | 66  | 66  | 49  |

*"P" = Promoted level*

### Scaling Multipliers (Start to Endgame)

| Stat | Multiplier | SF2 Reference |
|------|------------|---------------|
| HP   | ~9x        | 9x (Bowie) |
| STR  | ~16x       | 17x (Bowie) |
| DEF  | ~16x       | 23x (Bowie) |
| AGI  | ~13x       | 15x (Bowie) |

The baseline achieves SF2-authentic scaling.

---

## Class Differentiation Guidelines

Use these multipliers against baseline growth rates:

| Archetype | HP | MP | STR | DEF | AGI | INT | LUK |
|-----------|----|----|-----|-----|-----|-----|-----|
| **Baseline** | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
| Warrior   | 1.2 | 0.5 | 1.3 | 1.3 | 0.85| 0.5 | 1.0 |
| Knight    | 1.3 | 0.4 | 1.2 | 1.4 | 0.7 | 0.4 | 0.9 |
| Mage      | 0.8 | 1.7 | 0.6 | 0.6 | 1.0 | 1.5 | 1.0 |
| Archer    | 0.9 | 0.6 | 1.2 | 0.8 | 1.4 | 0.7 | 1.3 |
| Healer    | 0.9 | 1.5 | 0.5 | 0.7 | 1.1 | 1.3 | 1.2 |
| Thief     | 0.85| 0.7 | 1.0 | 0.7 | 1.5 | 0.8 | 1.5 |

---

## Implementation Reference

For ClassData resources, the baseline values are:

```gdscript
# Pre-Promotion "Recruit" baseline
hp_growth = 100
mp_growth = 60
strength_growth = 80
defense_growth = 80
agility_growth = 70
intelligence_growth = 70
luck_growth = 50

# Post-Promotion "Veteran" baseline
hp_growth = 150
mp_growth = 90
strength_growth = 120
defense_growth = 120
agility_growth = 105
intelligence_growth = 105
luck_growth = 75
```

---

## References

- `docs/specs/stat-growth-system.md` - Growth rate formula and SF2 data
- `core/resources/class_data.gd` - ClassData implementation
- `core/systems/promotion_manager.gd` - Promotion system
