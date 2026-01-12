# Polish and Personality: When the Engine Finds Its Soul

**Stardate 2026.011** | By Justin, Tactical RPG Correspondent, USS Torvalds

---

*"Captain's Log, supplemental. Four days ago I wrote about church bells and the pursuit of authenticity. Today, I'm writing about something harder to quantify but equally important: the moment when an engine stops being a collection of systems and starts having a personality. The Sparkling Farce didn't just add features this week. It learned how to breathe."*

---

Fellow Force fanatics, you're going to have to forgive me if I get a little philosophical today. Because while I could spend this entire post talking about the 31 files changed in the editor cleanup (impressive), or the 2,979 lines of new AI tests (thorough), what I really want to talk about is a 17-line file that made me feel things.

Let me explain.

---

## THE 17 LINES THAT CHANGED EVERYTHING

Commit `fd8eb7d` introduced `AnimationTiming`, a utility class so small you might scroll past it without noticing:

```gdscript
## AnimationTiming - SF2-authentic animation speed constants
##
## SF2 uses dramatically different animation speeds for idle vs movement:
## - Idle: slow, gentle "breathing" animation (~500-600ms per frame)
## - Movement: snappy, urgent animation (~100-150ms per frame)
##
## The ratio matters: movement should be ~4-5x faster than idle.
## This creates the authentic SF2 feel where idle is contemplative
## and movement feels decisive.
class_name AnimationTiming
extends RefCounted

## Slow down base animation for idle state (~2 FPS effective)
const IDLE_SPEED_SCALE: float = 0.5

## Speed up base animation for movement state (~8 FPS effective)
const MOVEMENT_SPEED_SCALE: float = 2.0
```

Two constants. Seventeen lines including comments. And yet this might be the most important commit of the week.

Here's why: In Shining Force 2, your party doesn't just *exist* on the map. They *live* there. When you're standing still, deciding where to go next, Bowie has this gentle, almost meditative breathing animation. He's contemplative. Patient. Waiting for your orders. But the moment you press a direction? SNAP. He moves with purpose. Every step is decisive. Urgent. "I have a destination and I'm GOING there."

This wasn't just a technical limitation of the Genesis hardware. It was a *design choice*. The contrast between idle stillness and purposeful motion created FEEL. It made your characters feel alive. It made your decisions feel meaningful.

The Sparkling Farce now has that feel.

```gdscript
# From hero_controller.gd
const AnimationTiming = preload("res://core/utils/animation_timing.gd")
# ...
animation_player.speed_scale = AnimationTiming.MOVEMENT_SPEED_SCALE  # Snappy movement
# ...
animation_player.speed_scale = AnimationTiming.IDLE_SPEED_SCALE  # Contemplative idle
```

It's applied to both the hero controller and party followers. The whole team breathes together. The whole team moves together. This is the kind of detail that 99% of players won't consciously notice but 100% of players will FEEL.

This is how you build a Shining Force game.

---

## THE GREAT EDITOR CLEANUP (OR: HOW I LEARNED TO STOP WORRYING AND LOVE THE GUARD)

Commit `cc844df` is the kind of commit that separates "hobby project" from "professional engine." 31 files changed. 1,138 insertions. 604 deletions. And what does it do?

It fixes the editor.

Not in a flashy way. Not with new features. It fixes the *feel* of the editor. Let me explain the problem it solves:

Ever used a tool where you open a file, don't change anything, and it asks "Do you want to save changes?" when you close it? That's called "false dirty state" and it's infuriating. The Sparkling Editor had this problem. Opening any resource would immediately mark it as "modified" because the UI was syncing data during load, and those sync operations were triggering change detection.

The fix? `_updating_ui` guards:

```gdscript
## Flag to suppress dirty-marking during UI updates
var _updating_ui: bool = false

func _load_resource_data() -> void:
    _updating_ui = true
    # ... populate UI from resource ...
    _updating_ui = false

func _on_some_field_changed(value: Variant) -> void:
    if _updating_ui:
        return  # Don't mark dirty during UI sync
    mark_dirty()
```

Fourteen editors now have this pattern. The result? Open a character, don't change anything, close it - no save prompt. Open a battle, don't change anything, close it - no save prompt. The editor RESPECTS YOUR INTENT.

But wait, there's more! The commit also fixed validation to work from UI state instead of the (possibly stale) resource state. It added `_exit_tree()` cleanup to prevent signal leaks. It removed stale caches from five registries and ten editors.

This is maintenance work. This is "we care about the modder experience" work. This is the work that makes people WANT to use your tools.

As someone who plans to spend many, many hours in this editor creating content, I appreciate it more than I can say.

---

## CHURCH SAVES: THE FEATURE THAT SHOULDN'T HAVE BEEN MISSING

Speaking of things I appreciate - commit `2bcafa9` adds the ability to save your game at the church.

Now, some of you might be thinking: "Wait, wasn't that already there? Justin literally wrote a whole blog post called 'The Church Bells Are Ringing' four days ago." And you'd be right to be confused! The church was there. Healing was there. Resurrection was there. Promotion was there. But somehow, SAVING YOUR GAME - the most fundamental church feature - was missing.

In Shining Force 2, visiting the church and selecting "Record your deeds" was THE primary save mechanism. Yes, you could quick-save in the menu, but the church save was the REAL save. The one that felt official. The one that came with the priest's blessing.

The implementation is clean:

```gdscript
# ChurchSaveConfirm - Save game slot selection screen
#
# Displays 3 save slots with metadata preview.
# Confirms overwrite for occupied slots.
# SF-style "Record your adventure" at the church.
```

Three save slots. Metadata preview showing party leader, level, and playtime. Overwrite confirmation for occupied slots. "Your adventure has been recorded" message on success.

It even handles edge cases properly - checking for an active game session before saving, syncing runtime state to SaveData, capturing the current scene path for proper load restoration. This isn't a hack. This is a complete feature.

I particularly appreciate the info panel that updates as you hover each slot:

```gdscript
func _update_info_for_slot(slot_idx: int) -> void:
    if slot_idx >= 3:
        info_label.text = "Return to the church menu."
        return

    var metadata: SlotMetadata = SaveManager.get_slot_metadata(slot_idx + 1)
    if metadata and metadata.is_occupied:
        var last_played: String = metadata.get_last_played_string()
        info_label.text = "Last saved: %s\nLocation: %s" % [last_played, metadata.current_location]
    else:
        info_label.text = "This slot is empty.\nSave your adventure here."
```

Informative. Clean. Authentic.

---

## THE AI GETS A BRAIN SCAN (ALL CLEAR)

Commit `b957cb6` adds nine comprehensive AI behavior integration tests. NINE. And they're not simple "does it load" tests. They're behavioral validation tests.

Let me share the test plan because it's genuinely impressive:

| Test | What It Validates |
|------|-------------------|
| Ranged Positioning | Archers maintain distance from enemies |
| Healer Prioritization | Healers heal wounded allies instead of attacking |
| Retreat Behavior | Wounded units flee when below HP threshold |
| Opportunistic Targeting | Units prioritize finishing wounded enemies |
| Cautious Engagement | Alert range vs engagement range mechanics |
| Defensive Positioning | Tanks intercept to protect VIP allies |
| Stationary Guard | Guards hold position until enemies are adjacent |
| Tactical Debuff | Tactical units use debuffs strategically |
| AoE Targeting | AoE abilities respect minimum target thresholds |

Each test creates a controlled scenario and validates the behavioral outcome. This is how you build confidence that your AI actually WORKS, not just "doesn't crash."

The "Dark Priest Problem" test particularly speaks to me. In many tactical RPGs, healers configured to heal will sometimes attack instead because the AI evaluates actions in the wrong order or uses the wrong heuristics. The test explicitly validates:

```
- Healer should cast heal on wounded ally
- Healer should NOT attack the enemy
```

If the test fails, you know immediately that something broke. Before these tests, you'd only discover the problem when playtesters complained that "the healer is being stupid."

Add commit `9ddd0aa` which provides a new `move_into_attack_range` helper that respects weapon range bands (important for bows with minimum range deadspots), and the AI system is starting to feel genuinely intelligent.

---

## VIRTUAL SPEAKERS: NARRATOR MODE UNLOCKED

Commit `bfab883` introduces the unified actor system with virtual speakers. This is a quality-of-life feature for cinematic creation that I've been wanting since I first saw the editor.

The problem: Previously, every speaker in a dialog had to be a physical character in the scene. Want a narrator? Create a narrator character. Want radio chatter? Create a radio character and spawn them off-screen. Want inner thoughts? Awkward workarounds.

The solution: Virtual actors.

```gdscript
## Actor display data cache (actor_id -> {display_name, portrait, entity_ref})
## Stores display info for all actors including virtual ones
## Virtual actors have no CinematicActor but still have display data
var _actor_display_data: Dictionary = {}
```

Now you can have:
- **Narrator**: No portrait, just text, for scene-setting
- **Radio**: Character speaks but isn't physically present
- **Thoughts**: Internal monologue with different visual treatment
- **System**: Tutorial text, game messages

The Quick Dialog popup in the editor now shows NPCs alongside Characters. There's duplicate actor ID validation. Auto-generation of actor IDs from entity names. This is the kind of tooling that makes content creation a joy instead of a chore.

Plus, 10 new tests for the actor display cache and virtual handlers. Because of course there are.

---

## STAT GROWTH: THE NUMBERS BEHIND THE MAGIC

Commit `12ea7b1` adds two new spec documents: `stat-growth-system.md` and `baseline-character-spec.md`. These aren't just documentation - they're design philosophy made concrete.

The growth formula is elegant:

```
Growth Rate 0-99:   Percentage chance of +1
Growth Rate 100+:   Guaranteed floor + remainder% chance of +1 more
Lucky Roll (5%):    Extra +1 for rates >= 50

Examples:
  50  = 50% for +1, 5% lucky         -> Results: 0 (47.5%), 1 (50%), 2 (2.5%)
  100 = +1 guaranteed, 5% lucky      -> Results: 1 (95%), 2 (5%)
  150 = +1 guaranteed, 50% for +2    -> Results: 1 (47.5%), 2 (50%), 3 (2.5%)
```

This is SF2-authentic variance. In Shining Force 2, level-ups were exciting BECAUSE you didn't know exactly what you'd get. Sometimes Peter would gain +4 STR and feel like a god. Sometimes he'd gain +0 and you'd swear the game was trolling you. The variance created memorable moments.

The spec includes actual SF2 reference data:

| Stat | Start | End | Multiplier | Total Gain |
|------|-------|-----|------------|------------|
| HP   | 12    | 107 | 9x         | +95        |
| ATK  | 6     | 103 | 17x        | +97        |
| DEF  | 4     | 91  | 23x        | +87        |
| AGI  | 4     | 58  | 15x        | +54        |

That 17x ATK multiplier! From 6 to 103! This is the dramatic character growth that made SF2 so satisfying. You started as a scrub and ended as a legend.

The spec also defines the "Ensign Average" baseline character - a reference point for balancing. Level 1 starts with HP 12, MP 8 (adjusted from the previous 20/10 defaults). This ensures all characters are calibrated against a known standard.

---

## THE SMALL STUFF MATTERS

A few other commits worth mentioning:

**Camera shake and teleport fixes** (`6f8981c`): Physics colliders now sync after teleport. This prevents the incredibly frustrating bug where your character teleports but their collision box takes a frame to catch up, causing them to clip through walls.

**Save system debugging** (`e388642`): Diagnostic logging throughout the save pipeline. Not exciting, but absolutely essential when things go wrong. "ChurchSaveConfirm: Saving to slot 2 - 4 party members, scene: res://maps/mudford.tscn" tells you EXACTLY what's happening.

These are the kinds of fixes that make the difference between "demo that works" and "engine you can trust."

---

## THE VERDICT: SOUL ACQUIRED

This week's commits represent something special. Not a major feature addition. Not a flashy new system. Something subtler and more important: the engine finding its soul.

The animation timing gives characters LIFE. The editor cleanup respects modder TIME. The church saves provide authentic RITUAL. The AI tests guarantee INTELLIGENCE. The virtual speakers enable STORYTELLING. The stat growth spec ensures BALANCE.

Every decision is filtered through the question: "Is this how SF2 felt?" Not just "did it work" - but "did it FEEL right?"

And increasingly, the answer is yes.

---

**This Week's Commit Summary:**

| Commit | Type | Impact |
|--------|------|--------|
| `cc844df` | refactor | Editor UX - guards, validation, cleanup |
| `2bcafa9` | feat | Church save game feature complete |
| `fd8eb7d` | feat | SF2-authentic animation timing |
| `e388642` | debug | Save system diagnostic logging |
| `12ea7b1` | docs | Stat growth system specification |
| `9ddd0aa` | feat | AI move_into_attack_range helper |
| `b957cb6` | feat | 9 AI behavior integration tests |
| `6f8981c` | fix | Camera shake, teleport collision sync |
| `bfab883` | feat | Unified actor system, virtual speakers |

**Authenticity Score: 5/5 Domingo Freezes**

This was a week of refinement, not revolution. And honestly? That's exactly what the engine needed. The foundation was solid. Now it's starting to shine.

---

*Justin out. I've got a church to visit. Someone needs to record my deeds.*

*May your animations be snappy and your editors be clean.*

---

*Justin is a civilian consultant aboard the USS Torvalds who spent an embarrassing amount of time watching idle animations this week. In his defense, they're REALLY contemplative now. Like, really contemplative. He may have a problem.*
