# The Great Leveling Up: When an Engine Grows Thirteen Features in One Day

**Stardate 2025.341** | By Justin, Tactical RPG Correspondent, USS Torvalds

---

*"Captain, sensors are detecting an unusual amount of commit activity in the Sparkling Farce repository. It appears to be... evolving rapidly." - Lt. Commander Data, if he worked in game development*

Hold onto your Mithril Maces, Force fans. I went to sleep last night with a basic tactical RPG engine, and woke up to find the dev team had apparently discovered time dilation. Twelve commits in a single day. TWELVE. And not "fixed typo" commits either - we're talking fundamental system overhauls, entire new features, and the kind of polish that makes you wonder if they've been doing nothing but mainlining coffee and channeling the spirit of Camelot Software Planning.

Let me break down what happened, because this is the kind of day that separates "promising engine" from "legitimate Shining Force successor platform."

---

## THE HEALER'S LAMENT: XP CATCH-UP MECHANICS

*Finally. FINALLY.*

If you've played Shining Force 2 to completion, you know The Problem. Karna joins at level 1. Sarah's been healing your party since Galam. By the time you're at Creed's Mansion, your frontline fighters are level 20+ while your healers are still languishing in the low teens because - wait for it - *healing doesn't give meaningful XP*.

The original games had a dirty secret: the optimal strategy was often to have your healers deal chip damage with their laughable attack stats just to gain experience. That's... not great game design.

Today's commit introduces something inspired by the Shining Force Cheats and Leveling (CL) mod that the community created to address exactly this problem:

```gdscript
# Apply catch-up multiplier for underleveled supporters
# Healers who fall behind earn bonus XP when supporting higher-level allies
if config.support_catch_up_rate > 0.0:
    var reference_level: int = supporter.stats.level
    if target != null and target.stats != null:
        # Use target's level as reference (healer supporting higher-level ally)
        reference_level = target.stats.level
    else:
        # Use party average for buffs/debuffs without specific target
        reference_level = int(_get_party_average_level())

    var level_gap: int = reference_level - supporter.stats.level
    if level_gap > 0:
        # Supporter is behind: bonus XP (+15% per level, capped at +100%)
        var catch_up_mult: float = 1.0 + clampf(level_gap * config.support_catch_up_rate, 0.0, 1.0)
        base_xp = int(base_xp * catch_up_mult)
```

The math is elegant: your level 10 healer healing your level 18 knight gets +100% bonus XP (8 levels times 15%, capped at double). But it's not just for healing - formation XP (the bonus you get for standing near an ally who kills something) ALSO uses catch-up mechanics now:

```gdscript
# Apply catch-up multiplier: underleveled allies earn more, overleveled earn less
if config.formation_catch_up_rate > 0.0:
    var level_gap: int = int(avg_level) - ally.stats.level
    # Clamp multiplier: -50% (5 levels ahead) to +150% (10 levels behind)
    var catch_up_mult: float = 1.0 + clampf(
        level_gap * config.formation_catch_up_rate,
        -0.5,
        1.5
    )
    ally_xp = int(ally_xp * catch_up_mult)
```

This is a *philosophy* change, not just a numbers tweak. The original Shining Force punished you for using healers. This engine rewards you. Your underleveled Karna equivalent standing behind your tank when they get a kill? She's earning bonus XP just for being tactical. Your overleveled Max who's already crushing it? He gets less formation XP, encouraging you to spread out your powerhouses instead of death-balling.

And the UI now shows you exactly what's happening - color-coded XP notifications:
- **Yellow**: Combat XP (kills, damage)
- **Blue**: Formation XP (tactical positioning)
- **Green**: Support XP (healing, buffs, debuffs)

You can actually SEE the strategy working. Chef's kiss.

---

## MAYOR CHUCK AND THE ART OF CONDITIONAL DIALOG

Deep in the sandbox mod, a new NPC has emerged. His name is Mayor Chuck, and he has two things to say:

**Before battle:**
```json
{
    "text": "I'm the friggin mayor over here!"
}
```

**After battle:**
```json
{
    "text": "You enkillinated them???"
}
```

Now look, I'm not going to pretend this is high literature. But it's *important* literature, because it demonstrates the conditional cinematic system actually WORKING. Mayor Chuck's dialog changes based on campaign flags, and this commit finally connected all the pipes:

1. TriggerManager launches a battle from a map trigger
2. TriggerManager now notifies CampaignManager about the battle
3. CampaignManager tracks which campaign node we're on
4. Victory sets the `on_complete_flags` for that node
5. NPCs can check those flags to show different cinematics

The bug was subtle: battles launched from map triggers weren't being tracked by the campaign system, so flags never got set. The fix touched four files across three systems. That's the kind of cross-cutting concern that shows the engine is mature enough to have emergent bugs from system interactions.

Also, they fixed a grid corruption bug where battle grids weren't being cleared, causing NPC positions to calculate wrong after returning from combat. If your NPCs were appearing in weird places post-battle before, that's gone now.

---

## THE EDITOR GROWS UP: COLLAPSIBLE SECTIONS AND TAB REGISTRIES

Remember when I said the Sparkling Editor was "functional but could use polish"? Well, someone took that personally.

**Phase 1-3: The Great Refactor**

The NPC Editor went from 1,959 lines to 944 lines - a 52% reduction. Not by cutting features, but by extracting reusable components:
- `NPCPreviewPanel` - Visual preview of NPC appearance
- `MapPlacementHelper` - "Place on Map" functionality
- `QuickDialogGenerator` - Auto-generate simple dialog cinematics

The Character Editor got undo/redo support. All editors now have a consistent `refresh()` interface. Save confirmations are now green and auto-dismiss. Label widths are standardized at 140px across all editors.

This is the boring but essential work that turns "developer tool" into "creator-friendly tool."

**Phase 4: The Registry Pattern**

But here's where it gets interesting for modders. The new `EditorTabRegistry` means adding custom editor tabs no longer requires modifying `MainPanel`:

```gdscript
## Tab categories for logical grouping
const CATEGORIES: Array[String] = [
    "overview",    # Welcome/info tabs (always first)
    "settings",    # Mod settings, configuration
    "content",     # Characters, classes, items, abilities, terrain
    "battle",      # Parties, battles, maps
    "story",       # Cinematics, campaigns, NPCs
    "mod"          # Mod-provided custom tabs (always last)
]
```

Want to add a "Quests" editor? A "Dialogue Tree" visualizer? A "Balance Calculator"? Register it in the "mod" category and it just... appears. Priority-sorted within categories, dynamically created, automatically refreshed when mods reload.

The same pattern now applies to AI Brains and Tilesets:

```json
// In your mod.json:
{
  "ai_brains": {
    "aggressive": {
      "path": "ai_brains/ai_aggressive.gd",
      "display_name": "Aggressive",
      "description": "Always moves toward and attacks nearest enemy"
    }
  }
}
```

No more hardcoded fallbacks. No more scanning directories at runtime. Mods declare what they provide, the registry tracks it, and the engine uses it. Total conversions can now completely replace the AI behavior system without touching core code.

---

## THE NPC SYSTEM: DIALOG IS CINEMATIC

I saved this one because it's philosophically important. Look at this comment from `npc_node.gd`:

```gdscript
## THE KEY UNIFICATION: Dialog IS a cinematic.
## NPCs don't just show dialog - they trigger full cinematics.
## This allows NPCs to walk around, trigger camera effects, etc.
```

This is the right call. In Shining Force, talking to an NPC often meant more than just a text box - the character might turn to face you, gesture, walk somewhere, trigger a story beat. By making "NPC interaction = cinematic playback," the engine supports everything from simple one-liners to complex scripted sequences.

The NPCNode is also editor-smart:
- Color-coded circles in the editor (red = no data, yellow = no cinematic, cyan = ready)
- Auto-snaps to grid
- Auto-creates collision shape and CinematicActor child
- "Quick Dialog" feature generates cinematic JSON from plain text

For modders who just want a villager who says "Welcome to our town!", the workflow is: create NPC, type dialog, place on map. For modders who want elaborate story sequences, the full cinematic system is available. Same tool, different depth.

---

## COLLAPSIBLE SECTIONS: THE LITTLE THINGS

I want to call out a small UI component that exemplifies good engine design:

```gdscript
@tool
extends VBoxContainer
class_name CollapseSection

## Usage:
##   var section: CollapseSection = CollapseSection.new()
##   section.title = "Equipment"
##   section.add_content_child(my_widget)
##   parent.add_child(section)
```

It's a collapsible section. Click the header, content toggles. Arrow indicator shows state. Simple text `[+]`/`[-]` markers for cross-platform compatibility.

Why does this matter? Because the Battle Editor now uses it:

```
[+] Neutral Forces (click to expand)
[-] Enemy Forces
    [Unit placement widgets...]
```

Neutral forces start collapsed because they're rarely used. Equipment sections in Character Editor can collapse when you're just adjusting stats. Less visual noise, same full functionality.

This is the kind of UX detail that Shining Force's 16-bit interface couldn't have, but that we should ABSOLUTELY have in a modern creation tool.

---

## THE PARTY EDITOR SPLITS

Speaking of UX, the old Party Editor tried to do two things:
1. Design party templates (what characters are in which starting formation)
2. Edit runtime save slots (modify your actual saved game)

These are fundamentally different workflows. Template editing is design-time; save slot editing is runtime debugging. Today's commit splits them:

- `party_template_editor.gd` - Create/edit PartyData .tres files
- `save_slot_editor.gd` - Modify saved game state

Both have scroll containers now. Both show mod attribution `[mod_id]` on character dropdowns. Both are separate tabs in the editor.

Separation of concerns isn't just for code architecture - it's for user interface too.

---

## 133 NEW TESTS

Almost buried in the "fix test failures" commit is this line:

> Add 133 new gdUnit4 tests covering recent commits

One hundred and thirty-three tests. For XP catch-up mechanics. For campaign battle node lookup. For EditorTabRegistry tab management. For ModRegistry NPC patterns.

This is how you build an engine that modders can trust. When someone creates a total conversion and pushes the XP system in weird ways, these tests catch regressions. When someone extends the editor with custom tabs, the registry behavior is verified.

Also they fixed a mod ID mismatch where `_base_game/mod.json` said `"base_game"` (no underscore) but the folder was `_base_game`. That kind of subtle inconsistency can cause hours of debugging. Now it's caught and fixed.

---

## THE VERDICT

**Thumbs way, WAY up.**

This wasn't a day of incremental progress - this was a day of "the engine is now ready for actual content creation." The XP system rewards good play without punishing healer users. The editor is now genuinely pleasant to use. The NPC system enables everything from simple shopkeepers to story-critical characters. The registry pattern means mods can extend everything without forking.

**What absolutely nails it:**
- XP catch-up mechanics inspired by community solutions to real problems
- Editor component extraction reducing complexity
- Registry patterns enabling true mod extensibility
- 133 tests ensuring reliability

**What I'm excited about next:**
- Terrain-aware AI (using those registries!)
- Quest systems (using the cinematic/flag infrastructure!)
- More conditional NPC behaviors

The engine is approaching the point where building actual game content becomes the bottleneck, not building systems. That's exactly where you want to be.

I'm going to go create some NPCs. For... testing purposes. Definitely not because "Quick Dialog" is surprisingly fun to use.

*Engage at maximum modding capacity,*

**Justin**
Communications Bay 7, USS Torvalds

---

*Next time: With AI Brains now moddable, maybe it's time to see if we can make enemies that DON'T walk into walls. Revolutionary concept, I know.*
