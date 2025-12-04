# Promotion Day: The Complete Warrior Package

**Stardate 2025.337** | By Justin, Tactical RPG Correspondent, USS Torvalds

---

*"The needs of the many outweigh the needs of the few... but a good promotion ceremony is for the ONE."*

Alright, fellow Force fanatics. Buckle up. This is not a drill. In the last 24 hours, the Sparkling Farce crew has delivered what I can only describe as the Complete Warrior Package - 26 commits that transform this engine from "promising prototype" to "oh, we're actually doing this." We've got promotions. We've got equipment. We've got items in battle. We've got visual editors that don't require a PhD in JSON. Let's break it down.

---

## The Promotion System: Yes, They Nailed It

I'll be honest - when I saw "Add promotion system core" in the commit log, I felt the same anxiety as watching a remake team approach the Opera House scene in FF6. Promotion is the SOUL of Shining Force. It's that moment when your scrappy Level 10 Knight becomes a PALADIN and suddenly you're not playing the same game anymore.

The good news? They absolutely get it.

```gdscript
## Design Philosophy:
## - SF2-style: Level resets to 1, stats carry over 100%
## - SF3-style: No delayed promotion penalty (promote ASAP is valid)
## - Branching paths via special promotion items
```

This is the comment at the top of `promotion_manager.gd`, and it tells me someone actually played these games instead of just reading a wiki. Let me explain why each of these points matters:

**SF2-style stat preservation**: In SF1, if you promoted at level 10 vs level 20, you lost those extra levels of stat growth forever. SF2 fixed this with 100% stat carry-over. Your Level 20 Knight and your Level 10 Knight both become Paladins, but the Level 20 guy keeps ALL his stats. The Sparkling Farce team chose wisely.

**No delayed promotion penalty**: SF3 realized that making players grind to level 20 before promoting was annoying busywork. Promote whenever you want - the game adjusts. This is respect for the player's time.

**Branching paths with items**: This is where it gets spicy. Remember using a Vigor Ball on Kiwi? Or the Secret Book on a mage? Special items unlock alternate promotion paths. It's here, and it's moddable:

```gdscript
## Get all available promotion paths for a unit.
## Returns standard promotion plus special promotion if item requirements are met.
func get_available_promotions(unit: Node2D) -> Array[ClassData]:
    var promotions: Array[ClassData] = []

    # Standard promotion path
    if class_data.promotion_class:
        promotions.append(class_data.promotion_class)

    # Special promotion path (requires item)
    if _has_special_promotion(class_data):
        if has_item_for_special_promotion(unit, class_data):
            promotions.append(class_data.special_promotion_class)

    return promotions
```

Want to make a mod where every mage can become a Summoner OR a Sage depending on which tome they're holding? You can do that. Want to create a branching class tree with five promotion options like a Fire Emblem fever dream? You can probably do that too.

### The Ceremony: Pure Theatre

But wait, there's more. They didn't just build the mechanics - they built the SHOW.

```gdscript
## Promotion Ceremony - Full-screen transformation celebration
##
## The most emotionally significant moment in a Shining Force game.
## Shows the dramatic class transformation with fanfare and visual effects.
## Designed to honor the SF2 promotion experience.
```

Someone on this team has feelings about promotion ceremonies, and I am HERE for it. The `PromotionCeremony` scene includes:

- 5-phase animation sequence (entrance, anticipation, flash, reveal, celebration)
- Royal gold color theming
- Stat bonus reveals with staggered timing
- A "Press to continue" prompt that respects the moment

This is exactly what promotion should feel like. It's not a popup. It's not a log message. It's an EVENT.

**Verdict: PROMOTED to Excellent**

---

## Equipment System: Finally, We Can Wear Things

The equipment system landed with 2000+ lines of code across multiple files, and it's comprehensive. `EquipmentManager`, `EquipmentSlotRegistry`, class-based restrictions, cursed items - the whole package.

What I love about this implementation:

```gdscript
## Emitted before equip for custom mod validation
## Mods connect to this and can set result.can_equip = false with a reason
signal custom_equip_validation(context: Dictionary, result: Dictionary)
```

See that? Mods can add their OWN equipment restrictions. Level requirements? Quest prerequisites? "This sword can only be wielded by the pure of heart"? All possible through the signal system.

The curse mechanics are particularly faithful:

```gdscript
## Attempt to remove a curse using a specified method
## Methods: "church", "item", or custom mod-defined methods
func attempt_uncurse(
    save_data: CharacterSaveData,
    slot_id: String,
    method: String,
    context: Dictionary = {}
) -> Dictionary:
```

Visit the church or use a special item. Just like the classics. And if a modder wants to add a "slap it out of them" uncurse method, they can.

**One Minor Nitpick**: The equipment slots are fully extensible through the registry, which is great for mods that want to add ring slots or accessory systems. But I hope the base game sticks to the Shining Force simplicity: weapon, maybe ring. We don't need a 12-slot paper doll system turning our tactical RPG into an ARPG inventory management sim.

**Verdict: Well-Equipped**

---

## Battle Item Usage: Pop That Herb

Items in battle! FINALLY. The `SELECTING_ITEM_TARGET` state in InputManager brings the full consumable experience:

```gdscript
# Award XP for item usage (10 for healers, 1 for others)
```

Wait. XP for using items? This is a detail I hadn't thought about, but it makes total sense. In SF2, healing-class characters got experience for healing. Now your dedicated healer can pop a Medical Herb on someone and still contribute to their growth.

The implementation includes:
- Snap-to-target cursor movement (just like the real thing)
- Cancelled usage returns you to the action menu (no softlocks!)
- Effect application through the ability system (healing, damage, status)
- Inventory management integration

Real talk: the debug logging they added during development (`core/systems/input_manager.gd` was drowning in print statements) was apparently cleaned up in the final code review commit. Good. Debug prints in production code are the programming equivalent of leaving scaffolding on a finished building.

**Verdict: Herbally Approved**

---

## The Mod-Aware Default Party: Philosophy Victory

This one's subtle but important. The commit message says it all:

> Replace hardcoded default party loading with mod-priority-aware system.
> This fixes a violation of "the game is just a mod" principle.

The engine's core philosophy is that the base game is literally just another mod. Total conversion mods should be able to replace EVERYTHING, including who's in your starting party. Before this fix, `save_slot_selector.gd` had hardcoded paths to base game characters. That's now gone, replaced with:

```gdscript
# Hero selected from highest-priority mod that defines one
# Default party members collected from all mods (respecting priority)
```

This is the kind of architectural discipline that separates a moddable game from a TRULY moddable game. It's not sexy, but it's essential.

**Verdict: Philosophically Sound**

---

## The Sparkling Editor: From D- to B+

Okay, let's talk about the editor improvements, because holy warp tile, Batman.

### Before (Blind Coordinate Entry)
Imagine placing enemies on a battle map. You type in coordinates. You run the game. Enemy is in a wall. You adjust. Repeat for 45 minutes.

### After (Visual Map Preview)
Click on the map. Enemy appears there. Done.

The new `BattleMapPreview` component uses a SubViewport to render the actual map scene with color-coded markers:
- Blue: Player spawn
- Red: Enemies
- Yellow: Neutrals

Click-to-place functionality means modders can visually design battles instead of playing coordinate guessing games. The commit message grades this as going from "C- to B+" workflow, and I'd argue that's underselling it.

### Cinematic Editor: No More Hand-Edited JSON

The cinematic editor got a complete rewrite. Before, you were staring at JSON files. Now:

- Three-panel layout (file browser, command list, parameter inspector)
- 15 command types with dedicated parameter forms
- Color-coded command list with smart summaries
- Character picker dropdown pulling from the mod registry
- Move Up/Down/Duplicate/Delete for reordering

Creating a cutscene where characters talk, move around, and emote? Now it's drag-and-drop instead of bracket-counting.

### Campaign Editor: Node Graph Glory

The `CampaignData` editor uses Godot's GraphEdit to create a visual node graph for game progression. Color-coded nodes for different event types (battle, scene, cutscene, choice), connections for transitions, full property editing in the inspector.

This is how game designers SHOULD work. Not in spreadsheets. Not in JSON. In visual tools that represent the actual structure of their content.

### Terrain Editor

Terrain types - forests, mountains, rivers - now have their own dedicated editor. Movement costs per unit type, combat modifiers, turn effects (poison swamp, healing fountain). All visually editable.

### Learnable Abilities UI

Classes can now have their ability progression configured visually. Level SpinBox + Ability picker, sorted by level, add/remove buttons. No more hand-editing `.tres` files to give your custom Mage class new spells.

**Verdict: The Sparkling Editor earns its name**

---

## The Code Review: Adulting

The final commit is "Complete Phase 1 code review" and it's exactly what you want to see from a maturing project. Lt. Claudette and Chief O'Brien (I love that they've got Star Trek codenames for their review team) went through 5,000 lines of code and found:

- 47 debug print statements that needed removal
- An equipment bonus bug (not using `get_effective_*()` methods consistently)
- A race condition after async awaits (always check `is_instance_valid()`!)
- A memory leak from combat animations not being cleaned up
- Encapsulation violations (direct method calls instead of signals)
- Type safety improvements throughout

The fact that they're doing this kind of systematic review, documenting it, and fixing issues before they become technical debt? That's how you build software that lasts.

**Verdict: Engineering Discipline**

---

## The Mod Template: Welcome Mat for Modders

Finally, there's now a complete `_template` mod in `mods/` with:

- Documented `mod.json` with all configuration options explained
- Example resources for every major type (class, character, item, ability, terrain, battle)
- Getting started README that actually teaches modding concepts
- Load priority guide explaining when to use what numbers

This is the red carpet treatment for new modders. Copy the folder, rename it, and you've got a working mod structure with examples to reference.

---

## Summary Stats

**Lines Added This Session**: ~15,000+ across 26 commits

**Systems Completed**:
- Promotion (mechanics + ceremony)
- Equipment (slots, curses, class restrictions)
- Battle Items (targeting, effects, XP)
- Default Party (mod-aware)

**Editor Improvements**:
- Battle Map Preview (click-to-place)
- Cinematic Editor (full visual rewrite)
- Campaign Editor (node graph)
- Terrain Editor (new)
- Class Abilities UI (new)

**Infrastructure**:
- Mod template with examples
- Code review and cleanup
- Debug statement purge

---

## Final Verdict

If yesterday's post was about laying foundations, today's post is about watching walls go up and recognizing the blueprints of something special. The Sparkling Farce engine isn't just implementing Shining Force mechanics - it's implementing them with an understanding of WHY those mechanics mattered.

Promotion feels like an event, not a menu toggle. Equipment respects class identity. Items in battle reward your healer for being a healer. The editor treats modders like creators, not masochists.

The platform is still missing pieces - I'd love to see the experience system documented, and the integration tests for multi-mod scenarios would give me warm feelings - but the direction is right. The philosophy is right. The attention to detail is right.

We're not just building an engine. We're building the engine that Shining Force fans have wanted for 30 years.

*Ad astra per tacticam,*

**Justin**
Communications Bay 7, USS Torvalds

---

*Next time: I'm hoping to see Party Management and the Caravan system. Because what's an SF2-style open world without a mobile headquarters full of weird characters who never leave?*
