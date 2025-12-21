# The Great AI Purge: 1,560 Lines of Hubris Meet the Airlock

**Stardate 2025.354** | By Justin, Tactical RPG Correspondent, USS Torvalds

---

*"Captain, long-range sensors are detecting a massive debris field ahead."*

*"On screen, Mr. Data. What are we looking at?"*

*"Approximately 1,560 lines of orphaned code, sir. An AIRoleRegistry, an AIRoleBehavior base class, 744 lines of tests... and what appears to be a complete plugin system that was never activated."*

*"Never activated? You mean someone built all that and then..."*

*"Affirmative, Captain. The architectural equivalent of building a warp core for a shuttlecraft. Impressive engineering, catastrophically over-scoped."*

*"Helm, adjust course. We have debris to avoid."*

---

Fellow Force fanatics, pull up a chair and pour yourself something strong. Today we witness one of the most satisfying moments in software development: the Great Purge. Over 1,560 lines of AI infrastructure code have been ejected into the cold vacuum of `git history`, and the engine is LIGHTER for it.

But this cleanup story comes with a bonus: **battle dialogues finally work**. The pre-battle cutscenes, victory celebrations, and defeat lamentations that make Shining Force battles feel like *events* rather than just combat encounters? They're live. Let's dig in.

---

## THE AI OVER-ENGINEERING POSTMORTEM

Here's what got deleted across two commits:

| Component | Lines | What It Was |
|-----------|-------|-------------|
| AIRoleRegistry | 342 | Plugin registry for custom AI role scripts |
| AIRoleBehavior | 308 | Abstract base class for role behaviors |
| test_ai_role_registry.gd | 744 | Tests for the registry |
| AI behavior inheritance | ~160 | Base behavior chains with get_effective_*() methods |

**Total: ~1,560 lines of code that was never used.**

### What The System Was Designed To Do

The original vision was ambitious. Modders would define custom AI roles in their `mod.json`:

```json
{
  "ai_roles": {
    "hacking": {
      "display_name": "Hacking",
      "description": "Prioritizes disabling enemy systems",
      "script_path": "ai_roles/hacking_role.gd"
    }
  }
}
```

Then they'd write a custom `AIRoleBehavior` subclass that implemented target evaluation, action selection, and movement logic. The registry would load these scripts dynamically, cache instances with LRU eviction, handle hot-reloading when mods changed...

It was a beautiful system. It was also **completely unnecessary**.

### Why Data-Driven Won

Here's the reality of tactical RPG AI: it's not that complicated. Shining Force 2's enemies don't run neural networks. They follow simple rules:

1. **Healers heal** when allies are wounded
2. **Attackers attack** the nearest/weakest/most threatening enemy
3. **Defenders protect** high-value units
4. **Everyone retreats** when near death (sometimes)

The `AIBehaviorData` resource handles all of this with ~30 configurable fields:

```gdscript
## The unit's tactical role - determines primary combat behavior
## Built-in roles: "support", "aggressive", "defensive", "tactical"
@export var role: String = "aggressive"

## Behavior mode - how the AI executes its role
## Built-in modes: "aggressive", "cautious", "opportunistic"
@export var behavior_mode: String = "aggressive"

## Weights for target selection. Higher weights = higher priority.
@export var threat_weights: Dictionary = {}

## HP percentage below which the unit will try to retreat/seek healing
@export_range(0, 100) var retreat_hp_threshold: int = 30
```

Want a healer who prioritizes the boss? Set `role: "support"` and `prioritize_boss_heals: true`. Want a berserker who never retreats? Set `retreat_enabled: false`. Want a Dark Priest who becomes aggressive at low health? Use behavior phases:

```gdscript
@export var behavior_phases: Array[Dictionary] = [
    {"trigger": "hp_below", "value": 25, "changes": {"role": "aggressive", "retreat_enabled": false}}
]
```

**No custom scripts required.** The `ConfigurableAIBrain` interprets this data with simple match statements:

```gdscript
match role:
    "support":
        var healed: bool = await _execute_support_role(unit, context, behavior)
        if healed:
            return  # Successfully healed, turn done
    "defensive":
        await _execute_defensive_role(unit, context, behavior)
        return
    "tactical":
        var debuffed: bool = await _execute_tactical_role(unit, context, behavior)
        if debuffed:
            return
    # "aggressive" is the default
```

Per the commit message, this data-driven approach covers "95% of SF-style tactical RPG AI needs." And that remaining 5%? Script extensibility can be added later *if demand emerges*. YAGNI in action.

### The Inheritance Chain That Nobody Needed

The second AI commit (286a40d) removed another layer of complexity: behavior inheritance. The idea was that behaviors could have a `base_behavior` that provided defaults, and child behaviors would inherit and override:

```gdscript
## Get effective role (this behavior's value or inherited from base)
func get_effective_role() -> String:
    if not role.is_empty():
        return role
    if base_behavior:
        return base_behavior.get_effective_role()
    return "aggressive"
```

This sounds useful until you realize:

1. You now have to trace through inheritance chains to understand what a behavior actually does
2. Circular inheritance becomes a risk that needs validation
3. The editor needs "(Inherit from base)" dropdown options everywhere
4. Modders need to understand inheritance to use the system

The new approach? **Just set each field explicitly.** It's 10 extra lines per behavior file, but you can read a behavior and immediately know what it does. No inheritance hunting.

### How Shining Force Handled This

Here's the thing: SF1 and SF2 didn't have complex AI systems because they didn't need them. Each enemy type had simple, predictable behaviors:

- Archers stayed at range
- Knights charged in
- Priests healed the most wounded
- Bosses attacked the biggest threat

The predictability was a *feature*. Players could strategize around known patterns. "If I leave Karna wounded, the Dark Smoke will target her instead of Max." Emergent tactics from simple rules.

The Sparkling Farce's data-driven AI is perfectly positioned to replicate this. Four built-in roles, three modes, configurable weights - that's MORE flexibility than the originals had, delivered in a fraction of the code.

**AI Purge: 5/5 Demon Breath spells** (annihilating the unnecessary with extreme prejudice)

---

## BATTLE DIALOGUES: FINALLY, THE DRAMA

Commit 803709c brought something that's been missing: the emotional bookends that make battles memorable.

### The Problem

Battle dialogues were defined in `BattleData` - pre-battle, victory, and defeat. The fields existed. The editor let you assign them. But they never actually *played* because the battle scene was missing the necessary UI components.

It's like having a script for a play but forgetting to build the stage.

### The Fix

The `battle_loader.gd` now instantiates the dialog infrastructure:

```gdscript
# Setup dialog box for pre/post battle dialogue
_dialog_box = DialogBoxScene.instantiate()
_dialog_box.hide()
$UI.add_child(_dialog_box)
DialogManager.dialog_box = _dialog_box

# Setup choice selector for dialogue choices
_choice_selector = ChoiceSelectorScene.instantiate()
_choice_selector.hide()
$UI.add_child(_choice_selector)
```

And then actually uses it:

```gdscript
# Play pre-battle dialogue if configured
if battle_data.pre_battle_dialogue:
    if DialogManager.start_dialog_from_resource(battle_data.pre_battle_dialogue):
        await DialogManager.dialog_ended
```

Victory and defeat dialogues are triggered in `battle_manager.gd` at the appropriate moments - after level-ups for victory, before the game over screen for defeat.

### Why This Matters (A Love Letter to SF2's Storytelling)

Remember the battle at Pacalon? Before the fighting starts, you get the tense confrontation with Zalbard. After victory, Lemon joins your force. That wasn't just combat - it was a *story beat*.

Or Mitula's Shrine, where defeating the enemy meant freeing the seal. The victory dialogue wasn't "You won!" - it was plot progression.

Shining Force understood that battles are more than stat checks. They're chapters in an adventure. The moments before and after the swords clash are where character happens.

The Sparkling Farce can now replicate this:

- **Pre-battle**: Set up the stakes. "The bridge is out! We fight through or we die!"
- **Victory**: Reward and advance. "The villagers are safe. Take this Mithril Sword."
- **Defeat**: Consequence and retry. "They were too strong... but we must try again."

Three fields in `BattleData`. Three moments that transform combat from grinding to storytelling.

### The Cleanup Bonus

There's proper cleanup too:

```gdscript
func _exit_tree() -> void:
    # Clear DialogManager reference to avoid dangling pointer
    if DialogManager.dialog_box == _dialog_box:
        DialogManager.dialog_box = null
```

No dangling references, no memory leaks, no weird state persisting between battles. Clean entry, clean exit.

**Battle Dialogues: 5/5 Shining Force fanfares** (the story can finally be told)

---

## THE BATTLEMAPPREVIEW DELETION: KNOWING WHEN TO FOLD

Also in 803709c: the BattleMapPreview got the airlock.

**700 lines of code**, deleted. The reason? "Had unfixable coordinate mismatch."

### What It Was

An in-editor preview that would render your battle map with unit positions so you could see the layout before testing. Useful in theory.

### Why It Died

Coordinate systems are *hard*. The map preview was trying to replicate what the actual battle scene does, but getting slightly different results. Units were offset. Terrain was misaligned. The preview was actively misleading, showing modders a layout that didn't match what they'd actually get.

A broken tool is worse than no tool. The team made the right call: delete it, preserve the essential battle editor functionality, and move on.

This is a maturity decision. Junior developers would try to fix the coordinate mismatch for weeks. Senior developers recognize when the ROI isn't there. The battle editor still lets you configure everything you need - you just test in-game rather than in-preview.

**BattleMapPreview Removal: 4/5 Mobility Rings** (sometimes the best move is to walk away)

---

## THE RUNNING TOTAL: 5,500 LINES IN 5 DAYS

Let's zoom out. Since December 15th, the codebase has shed approximately:

| Day | Lines Removed | Highlights |
|-----|---------------|------------|
| Dec 15-17 | ~2,000 | Dead code, debug prints, legacy migration |
| Dec 18 | ~1,000 | FormBuilder consolidation, editor cleanup |
| Dec 20 | ~1,560 | AI plugin system, behavior inheritance |
| Dec 20 | ~700 | BattleMapPreview |

**Total: ~5,500 lines of code removed while adding new functionality.**

This is the cleanup arc of a maturing project. The early phases were about making things work. This phase is about making things *right*.

### The Psychology of Code Debt

Every line of unused code is cognitive weight:

- New contributors wonder "should I understand this?"
- Maintainers wonder "is this still needed?"
- The test suite runs slower (744 lines of AI registry tests!)
- The codebase feels bigger and scarier than it is

Deleting code is liberating. The Sparkling Farce is now ~5,500 lines smaller but more capable. That's the dream.

---

## SMALLER COMMITS, STILL IMPORTANT

### Orphaned UID Cleanup (87f72ec)

When Godot resources are deleted, sometimes their `.uid` files stick around like ghosts. This commit exorcised them:

```
Remove .uid files for deleted debug test scripts
```

Also updated the Guntz Forge shop data, because apparently Guntz had outdated inventory. Even the dwarven merchants get code reviews.

### Async Race Condition Guards (c3f54f6)

Carried over from the previous blog post's theme: defensive programming continues. The turn system's async operations are now guarded against re-entry. When things can happen out of order, you build walls.

---

## HOW THIS COMPARES TO SHINING FORCE

### The "Just Enough" Philosophy

Shining Force's AI wasn't sophisticated. It was *sufficient*. Enemies behaved predictably because that's what the game design needed. Complex AI would have made battles frustrating rather than tactical.

The Sparkling Farce's data-driven AI is the same philosophy applied to modding. Give modders enough flexibility to create interesting behaviors, but not so much that they need programming skills. The sweet spot is:

- Support healers who protect the boss
- Aggressive bruisers who chase wounded targets
- Tactical mages who prioritize debuffs
- Defensive knights who bodyguard key units

All achievable through sliders and dropdowns. No GDScript required.

### The Story Integration

SF2 didn't just have battles - it had *moments*. The dialogue before Oddler turns traitor. The celebration after defeating Geshp. The tragedy when Lemon falls.

Battle dialogues enable those moments. A modder can now create a battle where:

1. Pre-battle: The villain monologues about their evil plan
2. Victory: The hero delivers a one-liner and gains an ally
3. Defeat: The party retreats to fight another day (or game over)

This isn't just mechanics - it's storytelling infrastructure.

---

## WHAT'S NEXT

The codebase is lean. The AI is data-driven. The dialogues work. What's left?

From the commit patterns, I'd guess:

1. **Editor polish** - The FormBuilder pattern is spreading; more editors will adopt it
2. **Gameplay testing** - Now that the systems work, time to make sure they *feel* right
3. **Content creation** - The base game mod needs battles, characters, and story

The foundation is solid. Time to build on it.

---

## THE JUSTIN RATING

### AI Plugin System Removal: 5/5 Freeze spells
An entire architectural layer, frozen in time and then shattered. 1,400 lines of code that was never called, never tested in production, never needed. The data-driven approach is simpler, more accessible to modders, and covers the use cases that matter. This is what "ruthless prioritization" looks like.

### AI Behavior Inheritance Removal: 5/5 Atlas Axes
Cutting through complexity with brute force. Inheritance chains are clever; explicit configuration is clear. For a modding platform, clarity wins every time.

### Battle Dialogues: 5/5 Shining Force fanfares
The emotional infrastructure that was always supposed to be there. Pre-battle setup, victory celebration, defeat consequence - these aren't nice-to-haves, they're essential to the genre. Finally working.

### BattleMapPreview Removal: 4/5 Quick Rings
The right call on a broken tool. Loses a point only because a working preview *would* have been useful. But a misleading preview is worse than none.

### Overall Day's Work: 5/5 Chaos Breakers

This commit series represents a philosophical statement: **the Sparkling Farce will be lean, focused, and accessible**. Not bloated with theoretical extensibility. Not cluttered with half-finished features. Not requiring programming skills to use.

1,560 lines of AI infrastructure became 30 configurable fields.
700 lines of broken preview became "just test in-game."
Battle dialogues went from "fields that exist" to "fields that work."

The Force would definitely be proud. This is the kind of discipline that ships products.

---

*Next time on the Sparkling Farce Development Log: Will the cleanup arc continue, or will new features emerge from the leaner codebase? Will someone finally create a battle with dramatic pre-fight dialogue? And most importantly, will the AI actually prioritize wounded healers now? Stay tuned.*

---

*Justin is a civilian consultant aboard the USS Torvalds who once spent two weeks building a "flexible plugin architecture" for a feature that ended up needing three hardcoded options. He's seen this movie before. The ending is always better when you delete the first act.*
