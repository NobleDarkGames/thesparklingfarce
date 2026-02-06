# Tutorial 4: Abilities and Magic

> **Prerequisite:** Complete [Tutorial 3: Items and Equipment](03-items-and-equipment.md) first.

This tutorial covers creating abilities (spells and skills) for your characters. Abilities are the core of tactical combat, handling everything from attack magic to healing to status effects.

## What Are Abilities?

Abilities represent any active skill a unit can use in battle:

- **Attack spells** (Blaze, Bolt, Freeze)
- **Healing magic** (Heal, Aura)
- **Buffs and debuffs** (Attack Up, Slow)
- **Status effects** (Sleep, Poison, Muddle)
- **Special skills** (Counter, Summon)

Characters learn abilities through their **class**. A Mage class might grant Blaze at level 1, Blaze 2 at level 8, and Blaze 3 at level 16. Consumable items can also trigger abilities when used.

## Ability Types

The platform supports nine ability types:

| Type | Purpose | Example |
|------|---------|---------|
| Attack | Deals damage | Blaze, Bolt |
| Heal | Restores HP | Heal, Aura |
| Support | Buffs allies | Attack Up, Boost |
| Debuff | Weakens enemies | Slow, Dispel |
| Status | Applies status effects | Sleep, Muddle |
| Summon | Summons units or effects | Phoenix, Dao |
| Counter | Reactive abilities | Counterattack |
| Special | Unique effects | Egress |
| Custom | Mod-defined types | (your creation) |

The type affects AI behavior and UI presentation. An AI healer prioritizes Heal-type abilities on wounded allies; Attack-type abilities target enemies.

## Creating an Ability

### Open the Ability Editor

1. In the Sparkling Editor, click **Content** in the category bar
2. Click the **Abilities** tab

### Create a New Ability

1. Click the **New** button above the ability list
2. A new ability named "New Ability" appears

### Basic Information

- **Ability Name**: Display name shown in battle menus (e.g., "Blaze", "Heal")
- **Ability ID**: Auto-generated from the name. Used in scripts and class ability assignments.
- **Description**: Tooltip text explaining what the ability does

### Type and Targeting

- **Ability Type**: Select from the types above. Affects AI priority and UI grouping.
- **Target Type**: Determines who/what you can select as a target

| Target Type | Selection | Range Used? | Notes |
|-------------|-----------|-------------|-------|
| Single Enemy | Pick one enemy | Yes | Must click an enemy within range |
| Single Ally | Pick one ally | Yes | Must click an ally within range |
| Self | No selection | No | Automatically targets caster |
| All Enemies | No selection | **No** | Affects ALL enemies on battlefield |
| All Allies | No selection | **No** | Affects ALL allies on battlefield |
| Area | Pick a cell | Yes | Can target empty ground; hits any unit in AoE |

**Important:** "All Enemies" and "All Allies" ignore range entirely. They affect every unit of that faction on the map, regardless of distance from the caster. Use these for battlefield-wide effects like mass buffs or ultimate attacks.

---

## Understanding Range and Area of Effect

Range and AoE are separate systems that work together:

- **Range** controls WHERE you can click to select a target
- **AoE** controls WHO gets hit around that target

### Range (Min/Max)

Range limits which cells you can select as targets. Distance is calculated as Manhattan distance (count tiles horizontally + vertically, no diagonals).

- **Min Range**: Closest selectable tile
  - 0 = can target self/adjacent
  - 1 = must be at least 1 tile away
  - 2+ = creates a "dead zone" near the caster

- **Max Range**: Farthest selectable tile
  - Typical melee: 1-2
  - Typical ranged magic: 3-5

**Range only applies to Single Enemy, Single Ally, and Area target types.** Self ignores range (always targets caster). All Enemies/All Allies ignore range entirely.

### Area of Effect (AoE)

AoE determines the splash radius around your selected target. It expands the effect without changing where you can click.

- **AoE 0**: Single target only—exactly what you clicked
- **AoE 1**: 3x3 diamond (center + 4 adjacent tiles)
- **AoE 2**: 5x5 diamond (13 tiles total)

AoE uses Manhattan distance from the center. A unit is hit if its distance from the center is ≤ the AoE value.

### How Target Type + AoE Interact

| Target Type | AoE 0 | AoE 1+ |
|-------------|-------|--------|
| Single Enemy | Hits one enemy | Hits enemies near that enemy |
| Single Ally | Heals one ally | Heals allies near that ally |
| Self | Affects caster only | Affects caster + nearby units |
| All Enemies | All enemies (no splash needed) | Same—already hits all |
| All Allies | All allies (no splash needed) | Same—already hits all |
| Area | Hits unit on clicked cell | Hits all units in radius (both factions) |

**Key insight:** When you use Single Enemy with AoE > 0, you still click on one enemy (within range), but the effect splashes to hit other enemies near that target. Allies in the splash zone are NOT hit—the target type filters who takes damage.

The **Area** target type is different: it lets you target empty cells and hits BOTH allies and enemies in the splash radius. Use this for hazard effects or abilities where friendly fire is intended.

### Practical Examples

| Ability | Target Type | Min | Max | AoE | How It Works |
|---------|-------------|-----|-----|-----|--------------|
| Heal | Single Ally | 0 | 3 | 0 | Click one ally within 3 tiles; heals only them |
| Blaze | Single Enemy | 1 | 4 | 0 | Click one enemy 1-4 tiles away; damages only them |
| Blaze 2 | Single Enemy | 1 | 4 | 1 | Click one enemy 1-4 tiles away; damages enemies in 3x3 around them |
| Aura | Self | 0 | 0 | 1 | No targeting; heals caster + allies in 3x3 around caster |
| Bolt 4 | All Enemies | — | — | 0 | No targeting; damages every enemy on the battlefield |
| Egress | All Allies | — | — | 0 | No targeting; affects entire party |
| Meteor | Area | 2 | 5 | 2 | Click any cell 2-5 tiles away; damages ALL units in 5x5 (allies too!) |

---

## Cost and Potency

### Cost

- **MP Cost**: Magic points consumed on use. Typical values:
  - 2-5 MP: Basic spells
  - 10-20 MP: Powerful mid-game spells
  - 30+ MP: Ultimate abilities

- **HP Cost**: Health sacrificed to use the ability. Rare; used for dark magic or desperation attacks. Usually 0.

### Potency

- **Potency**: Base effect strength. For damage/healing abilities, this multiplies with caster stats.
  - 10-30: Basic spells
  - 40-60: Mid-tier
  - 80+: Powerful late-game

- **Accuracy**: Base hit chance percentage.
  - 100%: Most spells (always hits)
  - 80-90%: Unreliable debuffs
  - 70%: Risky but powerful effects

---

## Status Effects

Abilities can apply status effects on hit.

### Adding Status Effects

1. In the **Status Effects** section, click **Select Effects...**
2. Check one or more effects from the dropdown
3. Selected effects display next to the button

The dropdown shows all status effects registered by loaded mods. Create custom effects in the **Status Effects** tab under Content.

### Effect Chance

- **Effect Chance**: Probability that the status applies when the ability hits
  - 100%: Guaranteed (e.g., dedicated sleep spell)
  - 30-50%: Unreliable side effect (e.g., attack with chance to poison)

**Example Configurations:**

| Ability | Effects | Chance | Purpose |
|---------|---------|--------|---------|
| Sleep | sleep | 100% | Dedicated sleep spell |
| Poison Strike | poison | 50% | Attack with poison chance |
| Blizzard | freeze | 30% | Damage with freeze side effect |
| Boost | str_up, agi_up | 100% | Multi-buff support spell |

---

## Assigning Abilities to Classes

Characters mainly learn abilities through their class, not individually. This mirrors the Shining Force system where a Mage learns Blaze spells and a Priest learns Heal spells.

### Add Abilities to a Class

1. Open the **Classes** tab
2. Select the class you want to edit
3. Scroll to **Learnable Abilities**
4. Click **Add Ability**
5. Set the **Level** at which the ability unlocks
6. Select the **Ability** from the picker

### Example: Mage Class Setup

| Level | Ability |
|-------|---------|
| 1 | Blaze |
| 8 | Blaze 2 |
| 16 | Blaze 3 |

Characters of this class gain access to each spell when they reach the specified level. A level 10 Mage has Blaze and Blaze 2 available.

### Spell Tiers

Shining Force traditionally uses numbered spell tiers (Blaze 1-4, Heal 1-4). Create each tier as a separate ability with increasing potency, range, area, and MP cost.

**Progression Example:**

| Spell | Potency | Range | AoE | MP |
|-------|---------|-------|-----|-----|
| Blaze | 10 | 1-3 | 0 | 2 |
| Blaze 2 | 18 | 1-4 | 1 | 5 |
| Blaze 3 | 28 | 1-5 | 1 | 10 |
| Blaze 4 | 40 | 1-6 | 2 | 20 |

---

## Assigning Abilities to Items

Consumable items trigger abilities when used. The Healing Herb uses a heal ability; a Power Potion might trigger a strength buff.

### Create a Consumable with an Ability Effect

1. Create the ability first (e.g., "Herb Heal" - Heal type, single ally, potency 15)
2. Open the **Items** tab
3. Create or edit a consumable item
4. Set **Item Type** to **Consumable**
5. Check **Usable in Battle** and/or **Usable on Field**
6. In the **Effect** picker, select your ability

When the player uses the item, the linked ability activates. The item is consumed after use.

### Example Consumables

| Item | Effect Ability | Battle | Field |
|------|----------------|--------|-------|
| Healing Herb | Herb Heal (restores 15 HP) | Yes | Yes |
| Medical Herb | Cure Poison (removes poison) | Yes | Yes |
| Power Wine | Boost STR (applies str_up) | Yes | No |
| Angel Wing | Egress (ends battle) | Yes | No |

---

## Animation and Audio (Stub)

The **Animation & Audio** section exists for future spell visual effects:

- **Animation Name**: Key referencing a spell animation (not yet implemented)

These fields are placeholders. The spell animation system is planned for a future phase.

---

## What You Built

You now understand how to:

- Create abilities with damage, healing, range, and area effects
- Configure MP costs and accuracy
- Apply status effects through abilities
- Assign abilities to classes at specific levels
- Link abilities to consumable items

Abilities form the foundation of tactical combat. Combined with classes and items, they give your characters unique identities and playstyles.

The next step is creating battles where your characters and abilities are put to the test. Status effects are covered in the Status Effects tab under Content - create custom buffs, debuffs, and conditions to expand your ability options.
