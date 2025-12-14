# Rise of the Machines: Sparkling Farce AI Gets Seriously Smart

**Stardate 2025.347** | By Justin, Tactical RPG Correspondent, USS Torvalds

---

*"Number One, run a diagnostic on the enemy AI subsystems."*

*"Captain, I've completed my analysis. Recommend we sit down. The results are... comprehensive."*

---

Fellow Shining Force veterans, the captain has asked me to deliver a full tactical assessment of The Sparkling Farce's AI system. Not just a "this commit looks good" review, but a deep dive comparison against the classics and the fan wishlist that Lt. Ears compiled in her intelligence report.

So I cleared my schedule, re-read Ears' 900-line report, fired up SF1 and SF2 for research purposes (I swear), and went through every line of the new AI codebase.

My verdict? I'll save you the suspense: **The Sparkling Farce is aiming for what fans have wanted for 30 years, and it's mostly hitting the target.**

Let me show you why.

---

## THE BENCHMARK: WHAT FANS ACTUALLY WANT

Before I praise or criticize anything, let's establish what we're measuring against. Lt. Ears' report distilled decades of forum complaints into seven core wishlist items:

1. **Context-Aware Support AI** - Healers heal the right target with the right spell
2. **Dynamic Threat Assessment** - No obsessive protagonist targeting
3. **Proactive Engagement** - No "sitting there like idiots"
4. **Full Ability Utilization** - Use spells, items, and status effects
5. **Unpredictable Tactics** - Variation without randomness
6. **Strategic Retreat** - Fall back when wounded, regroup when outnumbered
7. **Difficulty via Intelligence** - Not just stat inflation

The report also established three tiers:
- **Minimum Acceptable:** SF2's aggressive movement + smart heal AI
- **Community Expectation:** SF2 + full ability usage + better targeting
- **Platform Differentiator:** All of the above + retreat + role-based behaviors

So how does Sparkling Farce stack up?

---

## ITEM 1: CONTEXT-AWARE SUPPORT AI - VERDICT: NAILED IT

This is the Dark Priest problem. For 30 years, fans have watched enemy healers walk past their bleeding boss to smack a player unit with their staff. It wasn't a design choice - it was the AI being too dumb to realize "I have Heal. Ally is hurt. Maybe I should Heal."

The Sparkling Farce solves this with a dedicated Support role:

```gdscript
## Execute based on ROLE first (what the AI prioritizes)
match role:
    "support":
        # Support role: prioritize healing allies before attacking
        var healed: bool = await _execute_support_role(unit, context, behavior)
        if healed:
            return  # Successfully healed, turn done
        # No healing needed/possible - fall through to mode-based attack
```

The key insight: Support AI checks for healing opportunities BEFORE considering attacks. Not "should I heal or attack?" but "is anyone hurt? Yes? Then heal. No? Then attack."

### The Smart Heal Target Selection

But it gets better. The `_find_best_heal_target` function doesn't just pick the most wounded ally - it calculates a priority score:

```gdscript
## Most wounded gets highest priority
var hp_percent: float = float(ally.stats.current_hp) / float(ally.stats.max_hp)
score += (1.0 - hp_percent) * 100.0

## Boss/leader priority
if prioritize_boss:
    score += float(ally.stats.max_hp) * 0.1

## Proximity bonus (prefer closer allies)
var dist: int = GridManager.grid.get_manhattan_distance(unit.grid_position, ally.grid_position)
score += (20 - dist) * 2.0
```

A wounded boss gets higher priority than a slightly-more-wounded grunt. A nearby wounded ally beats a distant wounded ally. This is the kind of logic that fans have begged for since 1994.

### MP Conservation

And they didn't stop there. The `conserve_mp_on_heals` flag does exactly what fans wanted:

```gdscript
## Prefer abilities that won't overheal too much
var overheal: int = maxi(0, power - missing_hp)
var efficiency: float = 1.0 - (float(overheal) / float(power + 1))
score += efficiency * 50.0

## If conserving MP, prefer cheaper spells
if conserve_mp:
    score -= mp_cost * 2.0
```

No more "Dark Priest wastes Heal 4 on an ally missing 8 HP." The AI will use Heal 1 when Heal 1 is appropriate.

**Fan Wishlist Grade: A+**

---

## ITEM 2: DYNAMIC THREAT ASSESSMENT - VERDICT: SOLID FOUNDATION

The classic SF1 complaint: enemies obsessively target Max (or Domingo, who had compounding priority flags). Meanwhile, your wounded healer stands two tiles away completely safe.

Sparkling Farce addresses this with configurable threat weights:

```gdscript
threat_weights = {
    "wounded_target": 1.5,  # Higher = prioritize finishing wounded
    "damage_dealer": 1.0,
    "healer": 1.2,          # Slightly prioritize enemy healers
    "proximity": 0.8
}
```

And critically:

```gdscript
## If true, avoids disproportionately targeting the hero/protagonist
@export var ignore_protagonist_priority: bool = true
```

That flag defaults to TRUE. No special protagonist priority. Your Max-equivalent isn't automatically the AI's obsession.

### What's Working

The `_find_best_target` function calculates threat scores dynamically:

```gdscript
## Wounded target priority
var hp_percent: float = float(target.stats.current_hp) / float(target.stats.max_hp)
score += (1.0 - hp_percent) * wounded_weight * 100.0

## Proximity bonus
var dist: int = GridManager.grid.get_manhattan_distance(unit.grid_position, target.grid_position)
score += (20 - dist) * proximity_weight * 5.0
```

This means a wounded unit IS a more attractive target than a healthy one. Enemies will try to finish what they started instead of randomly switching targets.

### What's Missing

Here's where I put on my critical hat: the threat assessment doesn't yet evaluate class type. The `damage_dealer` and `healer` weights exist in the preset files, but I don't see code that actually detects "this unit is a healer" or "this unit deals high damage."

The infrastructure is there - the threat_weights dictionary is extensible, and modders can add any keys they want. But right now, `wounded_target` and `proximity` are doing all the heavy lifting.

**Fan Wishlist Grade: B+** (Solid foundation, needs class-aware targeting)

---

## ITEM 3: PROACTIVE ENGAGEMENT - VERDICT: EXCELLENT

Fans HATED SF1's static enemies. You could pick off entire formations with archers because enemies were programmed to "hold position" even when being murdered.

SF2 fixed this with aggressive AI that "moves freely and tries to attack the Shining Force directly." The community loved it.

Sparkling Farce goes further with a dual-range engagement system:

```gdscript
## Maximum distance at which unit becomes "alert" to enemies
@export_range(0, 20) var alert_range: int = 8

## Distance at which unit actively engages enemies
@export_range(0, 20) var engagement_range: int = 5
```

This creates THREE behavioral zones:
1. **Beyond Alert Range**: Enemy ignores you (hasn't noticed)
2. **Alert but not Engaged**: Enemy approaches cautiously, repositions
3. **Within Engagement Range**: Enemy commits to attack

### The Bug Fix That Made It Real

The recent commit `5027135` fixed a "dead zone" bug that was ruining cautious AI:

```gdscript
## Determine if we should attack after moving:
## - If enemy is within engagement_range, commit to attack
## - If enemy is only within alert_range, just approach cautiously (no attack)
var should_attack_after_move: bool = distance <= engagement_range

## Move toward the target
var moved: bool = move_toward_target(unit, nearest.grid_position)
if moved:
    await unit.await_movement_completion()

## Attack if we're in engagement mode and now in range
if should_attack_after_move and is_in_attack_range(unit, nearest):
    await attack_target(unit, nearest)
```

Previously, cautious enemies would move but never attack, creating a bizarre "I walked up to you but I'm just going to stand here" situation. Now they move AND attack when appropriate.

### The Stationary Guard Preset

For those who WANT static defenders (they have their place!), there's the `stationary_guard` behavior:

```
alert_range = 3
engagement_range = 1
```

This creates the classic "trap guard" - only attacks adjacent enemies, barely moves. Perfect for temple guardians or treasure room defenders.

**Fan Wishlist Grade: A**

---

## ITEM 4: FULL ABILITY UTILIZATION - VERDICT: FRAMEWORK READY, IMPLEMENTATION PARTIAL

Lt. Ears' report specifically praised the SF2 Maeson mod for making enemies "use Spells much more often, including Status Effect Spells too."

Sparkling Farce has all the configuration options:

```gdscript
@export var use_status_effects: bool = true
@export var preferred_status_effects: Array[String] = []
@export var use_healing_items: bool = true
@export var use_attack_items: bool = true
@export var use_buff_items: bool = false
```

The tactical_mage preset even specifies preferred debuffs:

```
use_status_effects = true
preferred_status_effects = ["silence", "slow", "weaken"]
```

### The Honest Assessment

Here's where I have to be fair: these flags exist, and the Support role's healing works beautifully, but I don't see item usage or status effect logic implemented in `ConfigurableAIBrain` yet.

The `_execute_aggressive`, `_execute_cautious`, and `_execute_opportunistic` functions don't check for item usage. The tactical role is a stub:

```gdscript
"tactical":
    # Tactical role: complex spell usage, debuffs
    # TODO: Implement tactical spell prioritization
    pass
```

This isn't a criticism of the architecture - it's just noting where we are in development. The data layer is complete. The runtime layer for Support healing is complete. Items and status effects need the runtime implementation.

**Fan Wishlist Grade: B** (Data layer is A+, runtime implementation is C for items/debuffs)

---

## ITEM 5: UNPREDICTABLE TACTICS - VERDICT: WELL DESIGNED

Fans wanted variety "through variation, not randomness." Same enemy type shouldn't always act identically, but they also shouldn't make stupid random decisions.

Sparkling Farce handles this through PRESET ASSIGNMENT, not runtime randomness:

```
Battle has 6 Goblin Archers:
- 2 assigned aggressive_melee preset
- 3 assigned defensive_tank preset
- 1 assigned opportunistic_archer preset
```

Each goblin behaves according to its assigned preset. Modders design the variation at encounter creation time, not by rolling dice during combat.

### The Behavior Modes

Three modes create fundamentally different tactical profiles:

**Aggressive Mode:**
```gdscript
# Move toward target and attack
var moved: bool = move_toward_target(unit, target.grid_position)
# Attack if now in range
if is_in_attack_range(unit, target):
    await attack_target(unit, target)
```

**Cautious Mode:**
- Stays within engagement zones
- Approaches but doesn't overcommit
- Attacks targets that come to it

**Opportunistic Mode:**
- Prioritizes wounded targets (2.0x weight in the archer preset!)
- Retreats when HP is low
- Hit-and-run tactics

And the phase system adds even more variation:

```gdscript
behavior_phases = [
    {"trigger": "hp_below", "value": 50, "changes": {"behavior_mode": "aggressive"}},
    {"trigger": "ally_count_below", "value": 2, "changes": {"retreat_enabled": false}}
]
```

A boss that becomes desperate at 50% HP? Built into the data layer.

**Fan Wishlist Grade: A-** (Excellent design, limited by number of implemented modes)

---

## ITEM 6: STRATEGIC RETREAT - VERDICT: IMPLEMENTED AND WORKING

This is the feature fans explicitly said they wanted but "haven't seen" in official games. Fire Emblem enemies don't retreat. Shining Force enemies don't retreat.

Sparkling Farce enemies CAN retreat:

```gdscript
## Retreat behavior: move away from enemies
func _execute_retreat(unit: Node2D, enemies: Array[Node2D], _context: Dictionary) -> void:
    # Find cell furthest from all enemies
    var best_cell: Vector2i = unit.grid_position
    var best_min_dist: int = 0

    for cell: Vector2i in reachable:
        var min_dist: int = 999
        for enemy: Node2D in enemies:
            if enemy.is_alive():
                var dist: int = GridManager.grid.get_manhattan_distance(cell, enemy.grid_position)
                min_dist = mini(min_dist, dist)

        if min_dist > best_min_dist:
            best_min_dist = min_dist
            best_cell = cell
```

The AI finds the cell that maximizes minimum distance from all player units. That's proper "get away from everyone" logic.

### Retreat Triggers

```gdscript
@export_range(0, 100) var retreat_hp_threshold: int = 30
@export var retreat_when_outnumbered: bool = true
@export var seek_healer_when_wounded: bool = true
@export var retreat_enabled: bool = true
```

The opportunistic_archer has a 60% retreat threshold. That archer is going to RUN when wounded, not suicide charge. Finally, intelligent ranged unit behavior!

### What's Not There Yet

I don't see "seek healer" implemented - the flag exists but `_execute_retreat` just moves away from enemies, not toward friendly healers. And "retreat when outnumbered" isn't checked in the current codebase.

But the core "wounded unit falls back" behavior WORKS. That alone puts Sparkling Farce ahead of both SF and Fire Emblem.

**Fan Wishlist Grade: B+** (Core retreat works, advanced features flagged but not implemented)

---

## ITEM 7: DIFFICULTY VIA INTELLIGENCE - VERDICT: ARCHITECTURE SUPPORTS IT

Lt. Ears quoted a fan: "The claimed rebalancing has actually just lowered characters' stats, rather than adding a more impressive AI."

The Sparkling Farce approach is to make AI behavior completely data-driven:

```gdscript
## This resource defines HOW a unit behaves in combat without requiring
## custom GDScript. Modders can create diverse behaviors purely through
## the editor by adjusting these parameters.
```

Modders can create difficulty by assigning smarter AI presets, not by inflating enemy HP. A "Hard Mode" could use the tactical_mage preset for enemy casters while Easy Mode uses aggressive_melee for everyone.

The presets already span a difficulty range:
- **aggressive_melee**: Dumb berserker, no retreat, charges blindly
- **tactical_mage**: Smart positioning, status effects, retreats at 40% HP
- **smart_healer**: Conserves MP, prioritizes boss, retreats at 50% HP

That's meaningful tactical variation, not just "+25% to all stats."

**Fan Wishlist Grade: A** (Architecture is perfect for this)

---

## OVERALL ASSESSMENT: WHERE DOES SPARKLING FARCE LAND?

Let me revisit Lt. Ears' three tiers:

### Minimum Acceptable: SF2's aggressive movement + smart heal AI
**STATUS: ACHIEVED**

Enemies move and engage proactively. Support AI heals intelligently. The Dark Priest problem is solved. We're past the minimum bar.

### Community Expectation: SF2 + full ability usage + better targeting
**STATUS: PARTIALLY ACHIEVED**

Better targeting is there (threat weights, no protagonist priority). Full ability usage is configured in data but not fully implemented in runtime (items, status effects pending).

### Platform Differentiator: All of the above + retreat + role-based behaviors
**STATUS: MOSTLY ACHIEVED**

Role-based behaviors are working (Support is complete, Aggressive/Cautious/Opportunistic modes work). Retreat is implemented. Phase-based behavior changes are supported.

---

## THE COMPARISON CHART

| Feature | SF1 | SF2 | Fire Emblem | Sparkling Farce |
|---------|-----|-----|-------------|-----------------|
| Smart Heal AI | NO | Partial | Partial | **YES** |
| No Protagonist Obsession | NO | NO | Better | **YES** (configurable) |
| Proactive Engagement | NO | YES | YES | **YES** |
| Full Ability Usage | NO | Partial | Partial | **Framework ready** |
| Strategic Retreat | NO | NO | NO | **YES** |
| Configurable Behavior | NO | NO | NO | **YES** |
| Phase Transitions | NO | NO | NO | **YES** |
| Mod-Extensible | NO | Hacks only | NO | **YES** |

That last row is the kicker. Even if Sparkling Farce AI was only "as good as" SF2, the fact that modders can create entirely new AI behaviors through data files would make it the most flexible tactical RPG AI system I've ever seen in a fan project.

---

## WHAT'S STILL MISSING (THE HONEST LIST)

I wouldn't be doing my job if I didn't call out the gaps:

1. **Defensive Role**: Marked TODO. "Bodyguard the boss" behavior isn't implemented.

2. **Tactical Role**: Marked TODO. Complex spell selection and debuff prioritization isn't there yet.

3. **Item Usage**: Flags exist, runtime logic doesn't. Enemies won't use Healing Herbs or attack items.

4. **Class-Aware Targeting**: Threat weights can't detect "this is a healer" or "this is a damage dealer" from unit data.

5. **AoE Optimization**: The `aoe_minimum_targets` flag exists but I don't see AoE spell selection logic.

6. **Seek Healer**: Wounded units can retreat but don't move toward allied healers.

7. **Outnumbered Detection**: Flag exists, logic doesn't.

8. **Turn Order Awareness**: Not implemented. AI can't plan "cast buff now, ally attacks next turn."

---

## THE JUSTIN RATING

I'm going to do something a little different here. Instead of one rating, I'm giving three:

### Architecture Rating: 5/5 Force Swords

The AIBehaviorData resource is beautifully designed. Roles, modes, threat weights, phase transitions, inheritance - it's all there and it's all extensible. This is the kind of system that modders will build incredible things with.

### Implementation Rating: 3.5/5 Mithril Shields

Support role is complete and excellent. Aggressive/Cautious/Opportunistic modes work. Retreat works. But Defensive and Tactical roles are stubs, and several configured flags don't have runtime behavior yet. The foundation is solid, the house is half-built.

### Versus The Classics Rating: 4/5 Chaos Breakers

Against SF1, this is a massacre. No contest. Against SF2, Sparkling Farce wins on configurability, retreat behavior, and smart healing. SF2 might still edge it out on "feel" because it has 30 years of battle-tested tuning, but the potential here is higher.

Against Fire Emblem? Different games, but Sparkling Farce's retreat system is something FE has never had. The threat assessment is comparable. It's a respectable showing.

---

## THE FINAL VERDICT

Is this the AI system that Shining Force fans have wanted for 30 years?

**Almost. And crucially, the remaining gaps are implementation work, not design problems.**

The architecture can support everything on the fan wishlist. The Smart Healer preset already solves the Dark Priest problem. The retreat system gives enemies survival instincts they've never had. The phase transitions enable dynamic boss behavior.

What's left is filling in the gaps: make Defensive AI protect high-value allies, make Tactical AI optimize spell selection, make enemies actually use items. All of these are clearly achievable within the existing framework.

If I'm being brutally honest with my fellow Shining Force diehards: play against this AI, and you'll feel like enemies are thinking. Not perfectly - you'll still find exploits, and some behaviors feel robotic. But you won't watch a healer ignore a dying boss to bonk your mage. You won't see enemies stand still while you snipe them from range.

That alone makes it better than 90% of tactical RPG AI I've played.

*Next time: Will the Defensive role finally get its bodyguard behavior? Will we see enemies popping Healing Herbs? Or will the next commit surprise us with something entirely different? Stay tuned, fellow Force members.*

---

*Justin is a civilian consultant aboard the USS Torvalds who has, at this point, spent more time analyzing fictional enemy AI than is probably healthy. He maintains that understanding why the Dark Priest doesn't heal is a valuable life skill.*
