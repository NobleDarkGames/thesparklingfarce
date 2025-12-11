# Blaze It: The Magic Has Finally Arrived

**Stardate 2025.345** | By Justin, Tactical RPG Correspondent, USS Torvalds

---

*"Computer, end simulation. I need a minute."*

*"Unable to comply. The magic system has been implemented. There is no escaping this moment."*

Fellow Shining Force devotees, this is not a drill. Sit down. Pour yourself something strong. Call your friends who still have their Genesis cartridges. Because what I'm about to tell you is the kind of news that makes a grown fanboy tear up:

**Magic works.**

Not "magic is planned." Not "magic framework is in place." Fully functional, class-based, MP-consuming, damage-dealing, ally-healing, target-selecting MAGIC. The kind that made Anri worth training. The kind that made Kazin your secret weapon against armored knights. The kind that made you curse when Sarah ran out of MP on floor 3 of the Ancient Tower.

Nine commits since my last transmission. Let's break down what just happened.

---

## THE CLASS-BASED SPELL SYSTEM (Commit 8e1ba1c)

This is the big one. Commit `8e1ba1c` implements what I'll call the SF2-authentic approach to magic: your spells come from your CLASS, not from your character.

### Why This Matters More Than You Think

In many modern RPGs, characters learn spells individually through skill trees, quest rewards, or equipment. It's flexible, sure, but it dilutes class identity. Your mage feels like your warrior with some fire added on.

Shining Force 2 didn't do this. A MAGE learned Blaze. A PRIEST learned Heal. Period. The class defined your spell list, and your level determined which tiers you'd unlocked. This created tactical clarity: you KNEW what each unit brought to the fight.

The Sparkling Farce nails this:

```gdscript
## Active spells/abilities granted by this class (PRIMARY spell source)
## Characters get their spells from their class, not individually
## Example: MAGE class has [blaze_1, blaze_2, blaze_3, blaze_4]
@export var class_abilities: Array[AbilityData] = []

## Level requirements for each ability {"ability_id": level_required}
## Abilities not in this dict are available at level 1
## Example: {"blaze_2": 8, "blaze_3": 16, "blaze_4": 24}
@export var ability_unlock_levels: Dictionary = {}
```

Character spells are calculated as: `ClassData.class_abilities + CharacterData.unique_abilities`

That `unique_abilities` array? That's for your Yogurts and Domingos - characters with spells that break class conventions. It's an escape hatch for the exceptions without compromising the core design.

### The Level Unlock System

This is where I started nodding along like a happy bobblehead:

```gdscript
## Get all class abilities unlocked at a given level
func get_unlocked_class_abilities(level: int) -> Array[AbilityData]:
    var unlocked: Array[AbilityData] = []
    for ability: AbilityData in class_abilities:
        if ability == null:
            continue
        var unlock_level: int = 1
        if ability.ability_id in ability_unlock_levels:
            unlock_level = ability_unlock_levels[ability.ability_id]
        if level >= unlock_level:
            unlocked.append(ability)
    return unlocked
```

Your Mage starts with Blaze 1. At level 8, Blaze 2 appears. Level 16, Blaze 3. Level 24, Blaze 4. Exactly like SF2. No skill points to allocate. No "choose your path" decisions. Your class IS your path. The only choice is whether to use it wisely.

---

## THE SPELL MENU (Also in 8e1ba1c)

476 lines of pure tactical interface goodness in `spell_menu.gd`. Let me highlight what they got right:

### MP Cost Display With Color Coding

```gdscript
const COLOR_MP: Color = Color(0.4, 0.7, 1.0, 1.0)  ## Blue for MP cost
const COLOR_MP_INSUFFICIENT: Color = Color(1.0, 0.4, 0.4, 1.0)  ## Red for insufficient MP
```

Can you cast it? Blue number. Can't afford it? Red number. Instant visual communication, exactly like the originals.

### Smart Default Selection

```gdscript
## Smart default selection based on spell availability
func _select_smart_default() -> void:
    # Select first castable spell
    for i in range(_abilities.size()):
        if _is_spell_castable(i):
            selected_index = i
            return
    # Fallback to first slot (even if not castable, for visual consistency)
    selected_index = 0
```

The cursor starts on the first spell you can ACTUALLY CAST. Not the first spell in the list. Not the one you used last time. The first one your current MP supports. This is the kind of micro-UX decision that separates "we played Shining Force" from "we read about Shining Force on Wikipedia."

### The Description Panel

```gdscript
## Update description label based on selected spell
func _update_description() -> void:
    match ability.ability_type:
        AbilityData.AbilityType.HEAL:
            desc = "Heals: %d HP" % ability.power
        AbilityData.AbilityType.ATTACK:
            desc = "Damage: %d" % ability.power
        ...
    # Add range info if not self-only
    if ability.target_type != AbilityData.TargetType.SELF:
        if ability.min_range == ability.max_range:
            desc += " (Range: %d)" % ability.max_range
        else:
            desc += " (Range: %d-%d)" % [ability.min_range, ability.max_range]
    ...
    # Show warning if not castable
    if not _is_spell_castable(selected_index):
        desc += "\n[Not enough MP]"
```

Damage estimate. Range info. Insufficient MP warning. All in one compact panel. Your Mage with 4 MP hovering over Blaze 3 will see exactly why they can't cast it.

---

## SPELL TARGETING VISUALIZATION (Commit 7867761)

Here's where things get REALLY good for tactics nerds.

```gdscript
## Show spell targeting range highlights
## Shows full spell range first (all cells in min/max range), then overlays valid targets
func _show_spell_targeting_range(valid_targets: Array[Vector2i]) -> void:
    # Determine base color based on spell type
    var range_color: int = GridManager.HIGHLIGHT_GREEN  # Default for heals/support

    match selected_spell_data.ability_type:
        AbilityData.AbilityType.ATTACK, AbilityData.AbilityType.DEBUFF:
            range_color = GridManager.HIGHLIGHT_RED
        AbilityData.AbilityType.HEAL, AbilityData.AbilityType.SUPPORT:
            range_color = GridManager.HIGHLIGHT_GREEN
        _:
            range_color = GridManager.HIGHLIGHT_BLUE

    # Step 1: Show full spell range (all cells from min_range to max_range)
    var all_cells_in_range: Array[Vector2i] = GridManager.get_cells_in_range_band(
        active_unit.grid_position,
        selected_spell_data.min_range,
        selected_spell_data.max_range
    )

    # Highlight the full range first
    GridManager.highlight_cells(all_cells_in_range, range_color, false)  # No pulse for range

    # Step 2: Overlay valid targets in YELLOW for emphasis
    if not valid_targets.is_empty():
        GridManager.highlight_cells(valid_targets, GridManager.HIGHLIGHT_YELLOW, true)  # Pulse for targets
```

RED for attack spells. GREEN for heals. YELLOW PULSING for valid targets WITHIN that range.

This is better than SF2.

There, I said it. I'm allowed to say it because I've played SF2 approximately nine thousand times. The original didn't show you spell range visually - you had to know it from the manual or trial and error. This implementation gives you full tactical information while maintaining the aesthetic spirit.

You want to cast Blaze 2 on that cluster of goblins? You'll see the red diamond of death zones around your mage, with the goblins themselves pulsing yellow to confirm they're valid targets. No guessing. No "wait, was Blaze 2 range 2 or range 3?"

---

## THE COMBAT ACTION DISPLAY (Commit e18830c)

Combat results now tell you what HAPPENED, not just the XP aftermath:

```gdscript
## Queue a combat action to be shown (e.g., "Max hit with CHAOS BREAKER for 12 damage!")
func add_combat_action(action_text: String, is_critical: bool = false, is_miss: bool = false) -> void:
```

You'll see:
- "Max hit with CHAOS BREAKER for 12 damage!"
- "Max struck again for 8 damage!" (double attacks)
- "Goblin countered for 5 damage!" (counter attacks)
- "Maggie cast BLAZE 1 for 20 damage!" (spell attacks)
- Orange-highlighted "CRITICAL damage" when applicable
- Gray "missed!" for those heartbreaking whiffs

This is storytelling through UI. Each combat exchange becomes a mini-narrative, and the results panel now captures the drama.

---

## ANIMATED MAP SPRITES (Commit db6a21e)

Over 4,000 lines added in this commit, and it's all about bringing your characters to life on the overworld.

### The Spritesheet Format

```gdscript
## Spritesheets must be exactly 64x128 pixels with the following layout:
##   +-------+-------+
##   | down1 | down2 |  Row 0: walk_down (2 frames)
##   +-------+-------+
##   | left1 | left2 |  Row 1: walk_left (2 frames)
##   +-------+-------+
##   | right1| right2|  Row 2: walk_right (2 frames)
##   +-------+-------+
##   | up1   | up2   |  Row 3: walk_up (2 frames)
##   +-------+-------+
##   Each cell: 32x32 pixels
```

Simple. Standardized. Exactly the kind of format that makes modders' lives easier.

### The Editor Integration

This is where I got excited for modders. The new `MapSpritesheetPicker` component:

1. Lets you browse your mod's asset folder for spritesheets
2. Validates that your image is the correct 64x128 format
3. Shows an **animated preview** in the editor so you can see your walk cycle
4. Automatically generates the SpriteFrames resource

That last point is crucial. In raw Godot, creating SpriteFrames from spritesheets involves tedious manual setup - defining regions, frame counts, animation names. The picker does it FOR you. Drop in a properly-formatted PNG, and boom: walk_up, walk_down, walk_left, walk_right, and their idle variants, ready to go.

### SF-Authentic Animation Speed

```gdscript
## Animation playback speed (Shining Force authentic)
const ANIMATION_FPS: float = 4.0
```

4 FPS. Not buttery smooth. Not choppy garbage. That specific frame rate that FEELS like Shining Force. Your characters will bob along like they did in 1994, and that's exactly right.

---

## THE DEATH FADE FIX (Commit 5c764c0)

Sometimes it's the bugs that tell you how mature a codebase is becoming. This one's interesting:

> "battle_loader.gd wasn't connecting the died signal, so units killed by spells (or any damage) would remain visible on the battlefield"

The spell system was implemented. It WORKED. But dead enemies stayed visible, making it look like Attack was broken (no valid targets when there appeared to be targets everywhere). The fix was two lines:

```gdscript
# In battle_loader.gd
unit.died.connect(_on_unit_died.bind(unit))
```

This is a good sign. When your bugs are "feature works but visual feedback is wrong" rather than "feature crashes the game," you're past the critical infrastructure phase and into polish territory.

---

## THE TEST SPELLS: BLAZE 1 AND HEAL 1

Let's look at what we're working with:

**Blaze 1:**
```
ability_name = "Blaze 1"
ability_type = 0 (ATTACK)
target_type = 0 (ENEMY)
min_range = 1
max_range = 2
mp_cost = 8
power = 12
accuracy = 95
description = "Hurls a small fireball at a single enemy. The basic fire spell taught to novice mages."
```

**Heal 1:**
```
ability_name = "Heal 1"
ability_type = 1 (HEAL)
target_type = 1 (ALLY)
min_range = 0
max_range = 1
mp_cost = 5
power = 15
accuracy = 100
description = "Restores a small amount of HP to one ally. The basic healing spell taught to novice priests."
```

Range 2 on Blaze. Range 1 on Heal (plus self-targeting at range 0). MP costs in the SF2 ballpark. Power values that will matter in the damage formula. This isn't placeholder data - this is thought-through design.

---

## WHAT'S STILL MISSING

I have to keep it real. The spell system is functional but not complete:

1. **Spell-specific animations**: Currently uses the attack animation. Eventually we'll want fire effects for Blaze, sparkles for Heal, that kind of thing.

2. **MP display in the UI**: You can see MP cost in the spell menu, but the unit stats panel doesn't show current MP yet.

3. **AOE spells**: Blaze 2 should hit multiple targets in SF2. The `area_of_effect` property exists in AbilityData but isn't implemented yet.

4. **Spell tiers**: We have Blaze 1 and Heal 1. Where are Blaze 2-4? Aura? Bolt? Freeze? The framework supports them, but the content isn't there yet.

5. **Field spells**: The exploration menu hides "Magic" if nobody knows field spells. But Egress (escape from battle) and Detox (cure poison in field) aren't implemented.

---

## THE VERDICT

This is the commit batch I've been waiting for since I started reviewing this project.

Magic isn't a side feature in Shining Force - it's a core tactical pillar. The mage deciding whether to save MP for the boss or clear trash mobs now. The healer choosing between topping off the wounded knight or waiting for someone to get REALLY hurt. The tension of "I can kill this enemy with Blaze but I'll be out of MP" - these are the decisions that make SF2 battles memorable.

The Sparkling Farce now supports all of this. Class-based spell learning. MP economy. Range-based targeting with visual feedback. Combat results that tell you what happened. And it's all backed by a modding-friendly structure where creating new spells is as simple as dropping a .tres file with the right properties.

Plus animated map sprites. Your heroes now WALK like heroes.

---

## THE RATING

**4.75/5 Domingo Freezes**

We're approaching "Domingo soloing the Kraken" territory. The only thing keeping this from a perfect score is the missing spell tiers and AOE implementation. When I can cast Blaze 3 on a cluster of enemies and watch three of them take damage? That's when we hit five.

But make no mistake: this week marks the moment The Sparkling Farce became a complete tactical RPG framework. Explore. Fight. Cast magic. Level up. The core loop exists. Everything from here is expansion and polish.

*Next time: Will we see Freeze, Bolt, and Aura join the party? Will AOE spells make mages the battlefield-clearing monsters they deserve to be? Or will we get a surprise detour into the retreat/resurrection system? Stay tuned, fellow Force members.*

---

*Justin is a civilian consultant aboard the USS Torvalds who considers "Mage with MP left" the most beautiful phrase in tactical RPG vocabulary. He's currently replaying Shining Force CD just to hear Anri's Blaze sound effect one more time.*
