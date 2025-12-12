# The Dark Priest Problem: AI Gets Smart, Mods Get Safe

**Stardate 2025.345** | By Justin, Tactical RPG Correspondent, USS Torvalds

---

*"Captain, sensors indicate a massive influx of code to the main deflector dish."*

*"How massive?"*

*"Over 14,000 lines, sir. And they appear to be... intelligent."*

---

Fellow Shining Force veterans, gather round. Today I come bearing news of a commit that has been 30 years in the making. Not literally, of course - the Torvalds crew has been at this for weeks - but spiritually? This fix has haunted us since 1994.

You know the moment. You're deep in a battle. Your party is wounded. The enemy has a healer. You think "great, at least they'll waste their turn healing nobody." But no. That Dark Priest walks RIGHT PAST his bleeding ally and smacks your mage in the face. Then you realize: Shining Force's healers were programmed to prioritize attacking over healing.

Commit `e22e2d0` fixes this. Forever. For everyone. And the way it does it is beautiful.

---

## THE DARK PRIEST PROBLEM: A 30-YEAR-OLD BUG

Let me be absolutely clear about what made this infuriating in the original games:

1. Enemy healers had access to Heal spells
2. Enemy units would get wounded in battle
3. The healer would look at their options
4. They would choose to attack your units instead of healing allies
5. Your units would die while enemy healers acted like paladins

This wasn't a design choice. This was the AI being too simple to realize "hey, I have a Heal spell and my boss is at 15 HP." The SF1/SF2 AI essentially ran: "Can I attack? Attack. Otherwise, move toward enemies."

Fans have complained about this for three decades. Modders have tried to fix it. And now, finally, The Sparkling Farce has a proper solution.

---

## THE SOLUTION: DATA-DRIVEN AI BEHAVIOR

The key insight here is brilliant: instead of hardcoding AI behavior in scripts, make it configurable through data files.

```gdscript
## Data-driven AI behavior configuration for configurable enemy AI.
##
## This resource defines HOW a unit behaves in combat without requiring
## custom GDScript. Modders can create diverse behaviors purely through
## the editor by adjusting these parameters.
```

The new `AIBehaviorData` resource is 355 lines of pure tactical goodness. Here are the highlights:

### Roles and Modes

```gdscript
## The unit's tactical role - validated against AIRoleRegistry
## Default roles: "support", "aggressive", "defensive", "tactical"
@export var role: String = ""

## Behavior mode - validated against AIModeRegistry
## Default modes: "aggressive", "cautious", "opportunistic"
@export var behavior_mode: String = ""
```

Role determines WHAT the AI prioritizes (healing allies vs dealing damage). Mode determines HOW it executes (charging in vs hanging back). A Support role with Cautious mode gives you a healer who hangs back and focuses on keeping allies alive. An Aggressive role with Aggressive mode gives you the classic "run at player and die" goblin.

### The Smart Healer Preset

Let me show you what a properly-configured enemy healer looks like:

```
behavior_id = "smart_healer"
display_name = "Smart Healer"
role = "support"
behavior_mode = "cautious"
threat_weights = {
  "wounded_target": 0.5,
  "damage_dealer": 0.8,
  "healer": 0.3,
  "proximity": 1.2
}
retreat_hp_threshold = 50
conserve_mp_on_heals = true
prioritize_boss_heals = true
```

Let me translate what this means in practice:

1. **Support role**: The AI will check for wounded allies FIRST, before considering attacks
2. **Cautious mode**: It won't charge in - it prefers to stay at range
3. **Retreat threshold 50%**: If the healer drops below half HP, it runs away
4. **Conserve MP on heals**: Uses Heal 1 if the target only needs Heal 1's worth of HP
5. **Prioritize boss heals**: Heals the boss before random mooks

This is EXACTLY how enemy healers should behave. They're valuable support units, not expendable attackers.

---

## THE CONFIGURABLE AI BRAIN

The real magic happens in `ConfigurableAIBrain`, which interprets these behavior files at runtime:

```gdscript
## Execute support role: heal wounded allies, fall back to attack if none need healing
## Returns true if a healing action was performed
func _execute_support_role(unit: Node2D, context: Dictionary, behavior: AIBehaviorData) -> bool:
    # Get allied units (same faction)
    var allies: Array[Node2D] = _get_allied_units(unit, context)

    # Find wounded allies
    var wounded_allies: Array[Node2D] = _find_wounded_allies(allies, behavior)

    if wounded_allies.is_empty():
        return false  # No one to heal

    # Get unit's healing abilities
    var healing_abilities: Array[Dictionary] = _get_unit_healing_abilities(unit)

    if healing_abilities.is_empty():
        return false  # No healing abilities available

    # Find best target to heal
    var heal_target: Node2D = _find_best_heal_target(unit, wounded_allies, behavior)
```

The flow is perfect:
1. Check for wounded allies
2. If someone's hurt, try to heal them
3. If healing succeeds, turn done
4. Only if nobody needs healing does the healer consider attacking

And crucially: the healer will MOVE to get in range of wounded allies before trying to heal. No more "ally is 3 tiles away so I'll just attack" nonsense.

---

## BUT WAIT, THERE'S MORE: MOD SYSTEM HARDENING

While the AI work is the star of the show, the mod system received a massive security and stability upgrade across two commits (`12954ac` and `64993d7`). This is the boring but critical work that prevents mods from breaking your game.

### Circular Dependency Detection

```gdscript
# Check for circular dependencies before proceeding
var resolved_mods: Array[ModManifest] = _topological_sort_with_cycle_detection(discovered_mods)
if resolved_mods.is_empty() and not discovered_mods.is_empty():
    push_error("ModLoader: Cannot proceed due to circular dependencies - no mods loaded")
    return
```

Mod A depends on Mod B. Mod B depends on Mod C. Mod C depends on Mod A. Previously? Infinite loop. Now? Clean error message, game continues with valid mods.

### Mod ID Sanitization

```gdscript
## Reserved mod IDs that cannot be used (security + system reserved)
const RESERVED_MOD_IDS: Array[String] = [
    "core", "engine", "godot", "system", "base", "default", "null", "none",
    "res", "user", "uid", "tmp", "temp", "root", "admin"
]
```

No more mod named "core" overwriting engine files. No path traversal attacks with "../../../" in mod IDs. This is the kind of security work that protects players who install mods from untrusted sources.

### Atomic Save Files

```gdscript
# Phase 2B - Save System Hardening:
# - Implement atomic file writes (temp->backup->rename pattern)
```

Your save file doesn't get corrupted if the game crashes during save. It writes to a temp file, backs up the old file, then renames. If anything goes wrong mid-write, your old save is still there.

### The RandomManager

This one's for the speedrunners and replay enthusiasts:

```gdscript
## RNG INSTANCES (separate to prevent cross-contamination)

## Combat RNG - Used for damage variance, hit rolls, critical hit rolls
var combat_rng: RandomNumberGenerator = RandomNumberGenerator.new()

## AI RNG - Used for AI decision making, target selection
var ai_rng: RandomNumberGenerator = RandomNumberGenerator.new()

## World RNG - Used for procedural content, random events, loot drops
var world_rng: RandomNumberGenerator = RandomNumberGenerator.new()
```

Three separate random number generators with exportable seeds. What does this mean? If you export your seeds and share them with a friend, you'll both experience the exact same "random" battle outcomes. Same crits. Same misses. Same AI decisions.

This is HUGE for:
- Tool-assisted speedruns with RNG manipulation
- Replay validation (was that crit real or hacked?)
- Debugging ("why did my run diverge?")
- Streaming ("here's my seed, try to beat my time")

---

## TOTAL CONVERSION SUPPORT: CUSTOM COMBAT FORMULAS

This is where my inner modder started salivating. The new `CombatFormulaBase` class lets total conversion mods replace the ENTIRE COMBAT SYSTEM:

```gdscript
## Calculate physical attack damage
## Override this to change the core damage formula
## Default: (STR + Weapon ATK - DEF) * variance, min 1
func calculate_physical_damage(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
    # Default implementation...

## Calculate hit chance (percentage 0-100)
## Override to implement custom accuracy mechanics
func calculate_hit_chance(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
    # Default implementation...
```

Want to make a sci-fi mod with energy shields and armor penetration? Override `calculate_physical_damage`. Want a super-lethal mode where crits always kill? Override `calculate_crit_chance`. The framework supports your vision without breaking the base game.

---

## THE GAME EVENT BUS: MOD HOOKS EVERYWHERE

This is the infrastructure that makes advanced modding possible:

```gdscript
## Before a unit attacks another
signal pre_attack(attacker: Node, defender: Node, weapon: Resource)

## After an attack resolves
signal post_attack(attacker: Node, defender: Node, result: Dictionary)

## Cancel the current event (call from pre-event handlers)
func cancel_event(reason: String = "") -> void:
    event_cancelled = true
    cancellation_reason = reason
```

Mods can now:
1. Hook into any game event (attacks, movements, level-ups, shop transactions)
2. Modify the event parameters (adjust damage, change stat gains)
3. CANCEL events entirely ("Shield of Protection blocks the attack!")
4. React after events ("Play special animation on crit!")

The pre/post pattern is elegant. Pre-events let mods intervene. Post-events let mods react. Game systems check `event_cancelled` after pre-events and skip the action if a mod vetoed it.

---

## WHAT'S NOT IN THESE COMMITS

A few notable absences I want to call out:

1. **No AOE AI yet**: The smart healer will heal one target. Group heals aren't implemented.
2. **Defensive/Tactical roles are stubs**: Support and Aggressive work. Defensive ("bodyguard the boss") and Tactical ("use debuffs strategically") are marked TODO.
3. **Phase transitions are data-only**: You can define "at 25% HP, become berserk" but the berserk behavior isn't implemented yet.

These are clearly "coming soon" - the framework is there, the implementations aren't.

---

## THE VERDICTS

**AI Behavior System: 5/5 Force Swords**

This is the correct solution to enemy AI. Data-driven, mod-extensible, and it actually solves the Dark Priest problem. Enemy healers will heal. Enemy tanks will tank. Enemy mages will cast. And modders can create entirely new tactical archetypes without writing code.

**Mod System Hardening: 4.5/5 Mithril Shields**

Critical security work that will protect players from malicious mods and protect saves from corruption. The only reason it's not 5/5 is that some features (like full namespace conflict resolution) are still in "permissive" mode. But the foundation is rock-solid.

**Total Conversion Support: 4/5 Chaos Breakers**

Custom combat formulas and the event bus open up incredible modding possibilities. The deduction is because custom AI roles can define script paths but those scripts need to follow a specific interface that isn't well-documented yet. Power users will figure it out; casual modders might struggle.

---

## THE BIG PICTURE

Remember when I said magic made The Sparkling Farce "a complete tactical RPG framework"? That was true for PLAYERS. These commits make it a complete framework for MODDERS.

You can now:
- Create enemies with sophisticated AI behavior using only data files
- Override any game event for custom mod effects
- Replace the combat formula entirely for total conversions
- Trust that your save files won't corrupt
- Share deterministic seeds for replays and speedruns

The engine is maturing from "playable Shining Force homage" to "legitimate modding platform." And as someone who has strong opinions about how Shining Force games should work, I'm thrilled to see that modders will have the tools to implement their own visions - whether that's a faithful SF2 remake or something completely new.

*Next time: Will the Defensive role get its bodyguard behavior? Will we see the first community-made AI preset? Or will the next commit be about something completely unexpected? Stay tuned, fellow Force members.*

---

*Justin is a civilian consultant aboard the USS Torvalds who spent an embarrassing amount of time in 1994 deliberately getting Dark Priests to waste turns attacking instead of healing. He's pleased that future generations won't have to endure such tactical nonsense.*
