# Shining Force 2 Class System Reference

This document serves as the authoritative reference for Shining Force 2's class progression mechanics. It informs the design of The Sparkling Farce's own class system.

---

## 1. Class Hierarchy

### Promotion Requirements

- **Minimum Level**: 20 (promotion available at any level from 20 onward)
- **Special Promotions**: Require specific items in addition to level requirement
- **Level Reset**: Upon promotion, character level resets to 1 but stats carry over

### Complete Class Tree

| Base Class | Standard Promotion | Special Promotion | Special Item Required |
|------------|-------------------|-------------------|----------------------|
| Warrior | Gladiator | Baron | Warrior Pride |
| Knight | Paladin | Pegasus Knight | Pegasus Wing |
| Archer | Sniper | Brass Gunner | Silver Tank |
| Mage | Wizard | Sorcerer | Secret Book |
| Priest | Vicar | Master Monk | Vigor Ball |
| Monk | Master Monk | - | - |
| Birdman | Sky Warrior | - | - |
| Werewolf | Wolf Baron | - | - |
| Phoenix | Phoenix | - | - |
| Vampire | - | - | - |
| Robot | - | - | - |
| Tortoise | Monster | - | - |
| Golem | - | - | - |

### Pre-Promoted and Unique Classes

| Class | Character(s) | Notes |
|-------|--------------|-------|
| Hero | Bowie | Protagonist; promotes from SDMN |
| SDMN (Swordsman) | Bowie | Starting class |
| Ninja | Slade | Unique to character |
| Red Baron | Jaro | Unique flying knight |

---

## 2. Stat Growth System

### Growth Curve Types

Shining Force 2 uses five distinct growth curve patterns that determine how stats are distributed across a character's leveling progression.

| Curve Type | Levels 1-10 | Levels 11-20 | Levels 21-30 |
|------------|-------------|--------------|--------------|
| Linear | 33.3% | 33.3% | 33.3% |
| Early | 50% | 30% | 20% |
| Middle | 20% | 60% | 20% |
| Late | 20% | 30% | 50% |
| Early+Late | 40% | 20% | 40% |

### Growth Formula

```
Per-Level Gain = (Projected Stat - Base Stat) * Curve Percentage / Number of Levels in Range
```

**Example**: A character with base ATK 10, projected ATK 40, using Early curve:
- Levels 1-10: (40 - 10) * 0.50 / 10 = 1.5 ATK per level
- Levels 11-20: (40 - 10) * 0.30 / 10 = 0.9 ATK per level
- Levels 21-30: (40 - 10) * 0.20 / 10 = 0.6 ATK per level

### Post-Level 30 Growth

After level 30, stat gains become probabilistic:
- **50% chance**: +1 to stat
- **50% chance**: +2 to stat
- **Average**: +1.5 per level

This ensures continued but diminishing returns for extended grinding.

---

## 3. Combat Mechanics by Class

### Counterattack Rates

Counterattack chance is determined by promotion tier, not individual character.

| Tier | Rate | Classes |
|------|------|---------|
| Unpromoted | 1/32 (3.125%) | All base classes |
| Standard Promoted | 1/16 (6.25%) | Gladiator, Paladin, Sniper, Wizard, Vicar, Sky Warrior |
| Elite | 1/8 (12.5%) | Hero, Master Monk, Wolf Baron, Ninja, Red Baron |

### Critical Hit Rates

| Type | Rate | Damage Multiplier | Classes |
|------|------|-------------------|---------|
| Standard | 1/16 (6.25%) | 125% | Most promoted classes |
| Enhanced | 1/8 (12.5%) | 150% | Baron, Ninja |

### Double Attack Rates

| Type | Rate | Classes |
|------|------|---------|
| Standard | 1/32 (3.125%) | Most classes |
| Enhanced | 1/16 (6.25%) | Ninja, Slade |

### Attack Range Types

| Range Type | Tiles | Classes |
|------------|-------|---------|
| Melee | 1 | Warriors, Knights, Monks, Werewolves |
| Ranged | 2 | Archers, Mages (spells only) |
| Flexible | 1-2 | Brass Gunner, some equipped weapons |

---

## 4. Magic System

### Offensive Spells

| Spell | Level 1 | Level 2 | Level 3 | Level 4 |
|-------|---------|---------|---------|---------|
| **Blaze** | | | | |
| MP Cost | 2 | 5 | 8 | 12 |
| Damage | 6-8 | 12-16 | 18-24 | 24-32 |
| Targets | 1 | 1 | 3 | 5 |
| **Freeze** | | | | |
| MP Cost | 3 | 7 | 10 | 14 |
| Damage | 8-12 | 16-22 | 24-32 | 32-42 |
| Targets | 1 | 2 | 3 | 3 |
| **Bolt** | | | | |
| MP Cost | 8 | 15 | 20 | 28 |
| Damage | 18-24 | 28-36 | 38-48 | 50-62 |
| Targets | 1 | 1 | 2 | 3 |
| **Blast** | | | | |
| MP Cost | 6 | 12 | 18 | 24 |
| Damage | 12-18 | 22-28 | 32-40 | 42-52 |
| Targets | 2 | 3 | 4 | 5 |

### Sorcerer Summon Spells

Sorcerers replace their entire spell list upon promotion. All previously learned spells are permanently lost.

| Summon | MP Cost | Damage | Targets | Element |
|--------|---------|--------|---------|---------|
| Dao | 8 | 20-28 | 3 | Earth |
| Apollo | 12 | 30-40 | 3 | Fire |
| Neptune | 16 | 40-52 | 3 | Water |
| Atlas | 20 | 50-65 | All enemies | Non-elemental |

### Healing Spells

| Spell | Level 1 | Level 2 | Level 3 | Level 4 |
|-------|---------|---------|---------|---------|
| **Heal** | | | | |
| MP Cost | 3 | 6 | 10 | 15 |
| HP Restored | 15 | 25 | Full | Full + Status |
| Targets | 1 | 1 | 1 | 1 |
| **Aura** | | | | |
| MP Cost | 7 | 11 | 16 | 22 |
| HP Restored | 15 | 20 | 30 | Full |
| Targets | Allies in range | Allies in range | Allies in range | Allies in range |

### Support Spells

| Spell | MP Cost | Effect | Duration/Notes |
|-------|---------|--------|----------------|
| Boost | 5/8/12/16 | +15/+20/+25/+30 AGI | 3 turns |
| Attack | 5/8/12/16 | +15/+20/+25/+30 ATK | 3 turns |
| Slow | 4/7/10 | -15/-25/-35 AGI | 3 turns |
| Muddle | 6/10/15 | Confusion | Until hit or battle end |
| Egress | 8 | Escape battle | Returns to last town |
| Dispel | 5/8/12 | Remove buffs | Single target |
| Desoul | 8/12 | Instant death | Low accuracy |

---

## 5. Movement Types

| Type | Description | Terrain Interaction |
|------|-------------|---------------------|
| Walking | Standard ground movement | Full terrain penalties and bonuses |
| Mounted | Cavalry/centaur movement | Reduced forest penalty, no mountain access |
| Flying | Airborne units | Ignores terrain movement costs, loses terrain defense |
| Floating | Hovering units | Ignores terrain costs, retains terrain defense bonuses |
| Swimming | Aquatic units | Water traversal, cannot cross land obstacles |

**Critical Insight**: Float is mechanically superior to Flying. Both ignore terrain movement penalties, but Float retains defensive terrain bonuses while Flying does not.

---

## 6. Terrain System

### Defense Bonuses

| Terrain | Defense Bonus |
|---------|---------------|
| Path/Road | 0% |
| Even Ground (Grass) | 15% |
| Forest | 30% |
| Mountains | 30% |
| Overgrowth | 30% |
| Water (shallow) | 0% |
| Fortress/Building | 30% |

### Movement Costs by Type

| Terrain | Walking | Mounted | Flying | Floating |
|---------|---------|---------|--------|----------|
| Path | 1 | 1 | 1 | 1 |
| Grass | 1 | 1 | 1 | 1 |
| Forest | 2 | 3 | 1 | 1 |
| Mountains | 3 | Impassable | 1 | 1 |
| Water (shallow) | 2 | 2 | 1 | 1 |
| Water (deep) | Impassable | Impassable | 1 | 1 |
| Lava | Impassable | Impassable | 1 | Impassable |

---

## 7. Weapon Restrictions by Class

| Class | Swords | Spears | Axes | Staves | Bows | Knuckles | Daggers | Katanas |
|-------|--------|--------|------|--------|------|----------|---------|---------|
| SDMN/Hero | Yes | - | - | - | - | - | - | - |
| Warrior/Gladiator/Baron | Yes | - | Yes | - | - | - | - | - |
| Knight/Paladin/Pegasus Knight | Yes | Yes | - | - | - | - | - | - |
| Archer/Sniper | - | - | - | - | Yes | - | - | - |
| Brass Gunner | - | - | - | - | Yes | - | - | - |
| Mage/Wizard/Sorcerer | - | - | - | Yes | - | - | - | - |
| Priest/Vicar | - | - | - | Yes | - | - | - | - |
| Monk/Master Monk | - | - | - | - | - | Yes | - | - |
| Ninja | - | - | - | - | - | - | Yes | Yes |
| Werewolf/Wolf Baron | - | - | - | - | - | Yes | - | - |
| Birdman/Sky Warrior | - | Yes | - | - | - | - | - | - |

---

## 8. Weaknesses and Resistances

### Flying Unit Vulnerability

| Damage Source | Effect on Flying Units |
|---------------|------------------------|
| Wind magic | +50% damage |
| Arrow weapons | +25% damage |

### Class Resistances

| Class | Fire | Ice | Lightning | Wind | Physical |
|-------|------|-----|-----------|------|----------|
| Mage/Wizard | 25% | 25% | 25% | 0% | 0% |
| Sorcerer | 25% | 25% | 25% | 25% | 0% |
| Phoenix | 50% | -25% | 0% | 0% | 0% |
| Golem | 0% | 0% | 50% | 0% | 25% |
| Robot | 0% | 25% | -50% | 0% | 25% |

*Positive values indicate resistance (damage reduction); negative values indicate weakness.*

### Status Effects

| Status | Effect | Cure |
|--------|--------|------|
| Poison | Lose 2 HP per turn | Antidote, Heal 4 |
| Sleep | Skip turns until damaged | Damage, battle end |
| Confusion | Random action targets | Damage, Dispel, battle end |
| Silence | Cannot cast spells | Dispel, battle end |
| Slow | -50% movement | Dispel, 3 turns |

---

## 9. Special Promotion Items

### Item Details and Trade-offs

| Item | Grants Class | Found | Trade-off Analysis |
|------|--------------|-------|-------------------|
| **Vigor Ball** | Master Monk | Creed's Mansion | +Higher crit rate, +Counter rate; Standard Vicar has better healing access |
| **Secret Book** | Sorcerer | Ancient Tower | +Summon magic, +AoE damage; -Loses ALL previous spells permanently |
| **Pegasus Wing** | Pegasus Knight | Pacalon | +Flying movement; -Lower defense than Paladin, weak to arrows |
| **Warrior Pride** | Baron | Moun | +Enhanced crits (150%), +Counter rate; -Slightly lower raw stats than Gladiator |
| **Silver Tank** | Brass Gunner | Grans Island | +Extended range (1-2), +Special ammo; -Lower mobility than Sniper |

### Strategic Considerations

- **Secret Book**: Most impactful choice; Sorcerer trades versatility for raw power
- **Pegasus Wing**: Mobility vs. durability trade-off
- **Vigor Ball**: Only relevant if promoting Priest; Monks auto-promote to Master Monk
- **Warrior Pride/Silver Tank**: Modest upgrades with minor stat trade-offs

---

## 10. Design Implications for The Sparkling Farce

### Combat Stats as Class Properties

SF2 assigns combat probabilities (crit rate, counter rate, double attack) at the class level rather than per-character. This simplifies balancing and makes class choice meaningful beyond raw stats.

**Implementation Note**: Store combat rates in ClassData resources, not CharacterData.

### Curve-Based Stat Growth

The five-curve system allows designers to create distinct growth feels without complex per-level stat tables:
- Early-focused units feel powerful initially but plateau
- Late-focused units reward investment
- Linear growth provides consistency

**Implementation Note**: Store curve type per stat per class. Calculate gains dynamically using the formula.

### Promotion Branching with Items

Special promotion items create meaningful player choices and reward exploration. The Sorcerer's complete spell replacement is particularly notable as a high-risk, high-reward option.

**Implementation Note**: PromotionData should support both level requirements and optional item requirements.

### Spell Learning by Total Level

Spells are learned at specific total levels (base levels + promoted levels). This means:
- Early promotion = earlier access to higher-tier spells
- Late promotion = higher base stats but delayed spell access

**Implementation Note**: Track cumulative_level separate from current_level.

### Movement Type Distinctions

The Float vs. Flying distinction demonstrates that seemingly similar movement types can have meaningful mechanical differences. Our movement system should support such nuances.

**Implementation Note**: MovementType enum with associated terrain interaction tables.

### Terrain as Defense Modifier

Terrain provides percentage-based defense bonuses, not flat damage reduction. This keeps terrain relevant at all power levels.

**Implementation Note**: Apply terrain bonus as multiplier in damage calculation: `final_damage = raw_damage * (1 - terrain_bonus)`.

---

## Appendix: Quick Reference Tables

### Promotion Level Requirements

| Scenario | Minimum Level | Recommendation |
|----------|---------------|----------------|
| Earliest possible | 20 | Not recommended (lose growth potential) |
| Balanced | 20-25 | Good stat base, still gain promoted growth |
| Maximum stats | Unpromoted 40+ | Diminishing returns after 30 |

### Combat Rate Summary

| Mechanic | Unpromoted | Standard | Elite |
|----------|------------|----------|-------|
| Counter | 3.125% | 6.25% | 12.5% |
| Critical | 6.25% | 6.25% | 12.5%* |
| Double | 3.125% | 3.125% | 6.25%** |

*Baron, Ninja only
**Ninja, Slade only

---

*Document compiled from Shining Force 2 game data analysis. Last updated: 2025-11-30*
