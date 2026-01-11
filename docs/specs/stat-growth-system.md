# Stat Growth System Specification

## Overview

The Sparkling Farce uses an **enhanced Shining Force-style growth system** that balances simplicity for modders with the variance and excitement SF fans expect.

## Growth Rate Formula

```
Growth Rate 0-99:   Percentage chance of +1
Growth Rate 100+:   Guaranteed floor + remainder% chance of +1 more
Lucky Roll (5%):    Extra +1 for rates >= 50

Examples:
  50  = 50% for +1, 5% lucky         → Results: 0 (47.5%), 1 (50%), 2 (2.5%)
  100 = +1 guaranteed, 5% lucky      → Results: 1 (95%), 2 (5%)
  150 = +1 guaranteed, 50% for +2    → Results: 1 (47.5%), 2 (50%), 3 (2.5%)
```

Implementation: `ExperienceManager._calculate_stat_increase()` and `UnitStats._calculate_growth()`

## SF2 Reference Data

### Player Stat Scaling (Bowie, Level 1 → Level 30 Promoted)

| Stat | Start | End | Multiplier | Total Gain |
|------|-------|-----|------------|------------|
| HP   | 12    | 107 | 9x         | +95        |
| ATK  | 6     | 103 | 17x        | +97        |
| DEF  | 4     | 91  | 23x        | +87        |
| AGI  | 4     | 58  | 15x        | +54        |

### Pre-Promotion Growth (Level 1→20, ~19 levels)

| Stat | Gain | Per Level |
|------|------|-----------|
| HP   | +37  | ~2.0      |
| ATK  | +22  | ~1.2      |
| DEF  | +21  | ~1.1      |
| AGI  | +20  | ~1.1      |

### Post-Promotion Growth is MUCH faster
- Promotion provides large stat boost
- Post-promotion growth rates effectively double
- This is how SF2 achieves 17x ATK scaling

### Class Differentiation at Endgame

| Comparison | Ratio |
|------------|-------|
| Warrior ATK vs Mage ATK | 1.5-1.7x |
| Warrior DEF vs Mage DEF | 1.8-2.0x |
| Warrior HP vs Mage HP   | 1.2-1.3x |

### Enemy Scaling

| Stage | Enemy | HP | ATK | DEF |
|-------|-------|-----|-----|-----|
| Early | Goblin | 18 | 22 | 13 |
| Mid   | Dark Knight | 50 | 76 | 48 |
| Late  | Zeon Guard | 130 | 136 | 54 |
| Boss  | Zeon | 500 | 127 | 50 |

Player ATK vs Enemy DEF ratio: ~1.5-2x throughout game (players have advantage)

## Recommended Growth Rates

### Without Promotion (30-level game, ~3-4x scaling)

| Stat | Baseline | Warriors | Mages | Archers |
|------|----------|----------|-------|---------|
| HP   | 120      | 150      | 100   | 110     |
| MP   | 50       | 30       | 100   | 40      |
| STR  | 100      | 130      | 70    | 110     |
| DEF  | 100      | 130      | 60    | 80      |
| AGI  | 80       | 70       | 100   | 120     |
| INT  | 80       | 50       | 130   | 60      |
| LUK  | 50       | 50       | 50    | 70      |

### With Promotion System (SF2-authentic, 10-20x scaling)

**Pre-Promotion (Level 1-20):**
| Stat | Baseline | Warriors | Mages |
|------|----------|----------|-------|
| HP   | 100      | 120      | 80    |
| STR  | 80       | 100      | 50    |
| DEF  | 80       | 100      | 50    |
| AGI  | 70       | 60       | 80    |
| INT  | 70       | 40       | 100   |

**Promotion Bonuses (one-time):**
- HP: +20-40
- ATK/DEF: +15-30
- AGI/INT: +10-20

**Post-Promotion (Level 1-30 promoted):**
- Multiply pre-promotion growth rates by 1.5-2x
- OR use higher base rates (150-200)

## Key Design Principles

1. **Promotion is critical for SF2-authentic scaling** - without it, growth feels flat
2. **Class differentiation**: Warriors should be ~1.5-2x better in physical stats than mages
3. **HP grows fastest** - everyone needs survivability
4. **Lucky rolls (5%)** create memorable "amazing level!" moments
5. **Growth rates > 100** allow guaranteed gains + variance

## Current Defaults (ClassData)

```gdscript
@export_range(0, 200) var hp_growth: int = 80
@export_range(0, 200) var mp_growth: int = 50
@export_range(0, 200) var strength_growth: int = 50
@export_range(0, 200) var defense_growth: int = 50
@export_range(0, 200) var agility_growth: int = 50
@export_range(0, 200) var intelligence_growth: int = 50
@export_range(0, 200) var luck_growth: int = 50
```

**TODO:** Update defaults based on whether promotion system is standard or optional.

## Files Modified

- `core/resources/class_data.gd` - Growth rate exports (0-200 range)
- `core/systems/experience_manager.gd` - `_calculate_stat_increase()` enhanced formula
- `core/components/unit_stats.gd` - `_calculate_growth()` for starting level application

## References

- Shining Force Central forums (stat growth discussions)
- GameFAQs SF2 character guides
- SF2DISASM GitHub repository
