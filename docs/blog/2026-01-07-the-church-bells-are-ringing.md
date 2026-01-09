# The Church Bells Are Ringing: Promotions, Authenticity, and the Rise of the Machines

**Stardate 2026.007** | By Justin, Tactical RPG Correspondent, USS Torvalds

---

*"Captain's Log, supplemental. Yesterday I wrote that the engine was ready for serious content development. Today, eleven commits proved me both right and wrong. Right, because the foundation held. Wrong, because 'ready' apparently meant 'ready for a complete church promotion system, an authentic field items interface, and the quiet removal of every UI element that didn't exist in 1994.' The Sparkling Farce doesn't rest. Neither do I."*

---

Fellow Force fanatics, I need you to sit down for this one. Pour yourself a Healing Drop (or whatever you're drinking these days). Because today we witnessed something beautiful: a development team systematically hunting down every non-authentic UI element like Bowie hunting Dark Dragon, and replacing them with pixel-perfect recreations of what made Shining Force II the masterpiece it was.

Eleven commits. One day. And at the end of it, the engine is more SF2-authentic than it's ever been.

Let's break it down.

---

## THE BIG ONE: Church Promotions Are ALIVE

Remember yesterday when I praised the promotion system but admitted I hadn't actually *tested* it? Well, someone on the Torvalds engineering team apparently took that personally, because commit `cdf2b74` is a MONSTER - 2,500+ lines changed across 46 files, and at the heart of it all: **the church promotion system now fully works**.

And I don't mean "technically functional." I mean **SF2-authentic class path selection**.

```gdscript
## ChurchPromoteSelect - Promotion path selection for church promotion service
##
## Shows available promotion paths for the selected character.
## If only one path exists, executes promotion immediately.
## Otherwise, lets player choose their path.
```

That comment tells you everything. In Shining Force II, when you promoted a character with only one available path (most characters), the priest just... did it. No menu, no confirmation, just "CONGRATULATIONS! You are now a WIZARD!" But characters with branching paths - like the Mage who could become a Wizard OR a Sorcerer - got to choose.

The Sparkling Farce now handles BOTH cases correctly:

```gdscript
# If only one path, execute immediately (SF2 behavior)
if _available_paths.size() == 1:
    _execute_promotion(_available_paths[0].target_class)
    return

_update_header()
_populate_path_grid()
```

Simple. Elegant. *Authentic*.

But wait, there's more! The promotion ceremony now properly captures your OLD class before the promotion happens, so the display shows "MAGE → WIZARD" instead of "WIZARD → WIZARD" (which was apparently a bug). The ceremony awaits dismissal properly. Input gets restored correctly. These are the kinds of UX bugs that would make a player go "something feels off" without being able to articulate why.

The team articulated why. And fixed it.

### The Property-Based Lookup Revolution

Buried in the same commit is a fundamental improvement to how the engine finds resources. Previously, shops and NPCs were looked up by their *filename* - which meant if you renamed a file, everything broke. Now there are proper semantic lookups:

```gdscript
# NEW: Property-based lookups
ModLoader.registry.get_shop_by_id(shop_id)
ModLoader.registry.get_npc_by_id(npc_id)
```

This is the kind of infrastructure work that makes modding actually viable. You can organize your files however you want. The registry finds things by their *identity*, not their *location*.

---

## THE AUTHENTICITY PURGE

Yesterday's "State of the Force" post mentioned that the engine was feature-complete for core tactical RPG mechanics. Today, the team apparently decided that "feature-complete" wasn't enough - it had to be *authentic*.

What followed was a surgical removal of every UI element that didn't exist in Shining Force II.

### The Depot Button (RIP)

Commit `9bf10ed` removes the Depot button from the Members screen. Why? Because in SF2, you could only access the Depot (item storage) from the Caravan. The Members screen was for viewing your party, not managing inventory.

```
scenes/ui/members/screens/member_select.gd | 20 --------------------
```

Twenty lines deleted. Zero lines added. Sometimes the best code is no code.

### The Shop Confirmation Screen (RIP)

Commit `4a7faab` removes the redundant shop confirmation screen. In SF2, when you selected a character to equip an item, the purchase happened *immediately*. No "Are you sure?" No second-guessing. You picked the character, you bought the item, done.

```
scenes/ui/shops/screens/confirm_transaction.gd   | 78 ---------------------
scenes/ui/shops/screens/confirm_transaction.tscn | 89 ------------------------
```

167 lines of "are you sure?" gone. The selection IS the action. This is SF2 flow.

### The Quit-to-Title Option (RIP)

Commit `61d9c7c` removes the quit-to-title option from the defeat screen. In SF2, when you lost a battle, you woke up at the church with half your gold gone. There was no "Return to Title" option. You dealt with the consequences.

```gdscript
# SF2-authentic behavior: defeat always continues to revival at last safe
# location. No need for a separate quit option - players can just close
# the game if they want to stop playing.
```

This is the kind of design decision that separates tribute from travesty. Modern games add quit options everywhere because "player convenience." SF2 didn't give you an escape hatch. You lived with your failures. The Sparkling Farce now does the same.

---

## THE FIELD ITEMS INTERFACE: 678 LINES OF AUTHENTICITY

Commit `873aada` is where things get really interesting. The old `PartyEquipmentMenu` (583 lines) has been replaced with a new `FieldItemInterface` system (678+ lines across multiple files).

What's the difference? *Everything*.

The old system let you cycle through party members with L/R buttons. The new system shows ONLY the hero's inventory - because that's what SF2 did. When you opened the Item menu in the field, you saw Max's (or Bowie's) stuff. Period.

```gdscript
## FieldItemDetail - Hero inventory view for field menu (SF2 authentic)
##
## Adapted from member_detail.gd with key differences:
## - NO L/R character cycling (shows hero only)
## - Uses FIELD_MENU context for ItemActionMenu (no GIVE action)
## - Simpler hints (no "L/R: Switch Character")
```

And notice that "no GIVE action" note? In SF2, you could only GIVE items at the Caravan. In the field, you could USE, EQUIP, DROP, or get INFO - but not transfer items between characters. The Sparkling Farce now enforces this distinction.

This is what I mean when I talk about "feel." A modern game would let you do everything everywhere because "why not?" SF2 made you go to specific places for specific actions. The Caravan was your mobile HQ. The field was for adventuring. The church was for healing and promotion. Each location had a PURPOSE.

The Sparkling Farce is building that same sense of place.

---

## LOCKED DOORS: THE CLASSIC RPG MECHANIC

Commit `2be4207` adds key item checks for locked doors. Simple feature, perfect implementation:

```gdscript
# Check for locked door (requires key item)
var requires_key: String = trigger_data["requires_key"] if "requires_key" in trigger_data else ""
if not requires_key.is_empty():
    if not _party_has_item(requires_key):
        # Show locked door message and abort transition
        var item_data: ItemData = ModLoader.registry.get_resource("item", requires_key) as ItemData
        var item_name: String = item_data.item_name if item_data else requires_key
        if DialogManager:
            DialogManager.show_message("The door is locked. You need the %s." % item_name)
        return
```

The helper function checks ALL party members' inventories:

```gdscript
func _party_has_item(item_id: String) -> bool:
    if not PartyManager:
        return false
    for character: CharacterData in PartyManager.party_members:
        var save_data: CharacterSaveData = PartyManager.get_member_save_data(character.character_uid)
        if save_data and save_data.has_item_in_inventory(item_id):
            return true
    return false
```

This is how SF2 handled key items - anyone in the party could have the Achilles Sword or the Mithril, and it would work. The Sparkling Farce does the same.

And yes, there are unit tests. Because of course there are.

---

## CONDITIONAL BRANCHING: THE STORYTELLING UPGRADE

Commit `653f979` adds `check_flag` conditional branching to the cinematic system. I mentioned this in yesterday's post as an example of what the engine could do - now it's even more powerful.

The `show_choice` command now supports full battle integration:

```gdscript
## Enhance show_choice battle action to support victory/defeat cinematics and
## flags, matching trigger_battle command capabilities.
```

This means NPCs can offer you a choice that leads to a battle, with different outcomes based on victory or defeat. "Will you fight the bandits?" Yes → battle with victory/defeat cinematics. No → different story branch.

This is SF2's "Fight the goblins?" moment, fully systematized.

---

## THE PLATFORM MATURES: CLEANUP AND SAFETY

Commit `9eb0256` is the "boring but important" commit. Debug prints removed. Interrupt handlers added to cinematic executors. Safety checks for crafting output storage. Popup label cleanup in TurnManager.

```gdscript
# Add interrupt() methods to cinematic command executors
core/systems/cinematic_commands/camera_move_executor.gd     |  15 +
core/systems/cinematic_commands/camera_shake_executor.gd    |  15 +
core/systems/cinematic_commands/move_entity_executor.gd     |  13 +
core/systems/cinematic_commands/play_animation_executor.gd  |  24 +-
core/systems/cinematic_commands/wait_executor.gd            |  14 +
```

Interrupt handlers mean cinematics can be cancelled cleanly. No more orphaned animations or stuck cameras when something goes wrong. This is the kind of defensive programming that separates "demo that works" from "engine that ships."

### The Mod Consolidation

Commit `f10f936` merges `_platform_defaults` into `_starter_kit`. Both were priority -1 mods (lowest priority, meant to be overridden). Having two of them was confusing. Now there's one, with a name that actually tells modders what it's for.

```
mods/_platform_defaults/mod.json | 10 --
```

Ten lines deleted. Clarity gained.

---

## THE CURIOUS CASE OF THE AI AGENTS

And now for something completely different.

Buried in commit `9eb0256` is something that made me do a double-take:

```
.opencode/agent/build-expert-bob.md                |  62 +++
.opencode/agent/burt-macklin-tribble-hunter.md     |  50 +++
.opencode/agent/chief-engineer-obrien.md           |  46 +++
.opencode/agent/commander-clean.md                 |  64 ++++
.opencode/agent/dr-mccoy-reviewer.md               |  74 ++++
... (18 more agent definitions)
```

Eighteen AI agent definitions. Seven skill files. A complete `CODE_REVIEW_PLAN.md` at 414 lines.

The Sparkling Farce development team is apparently building out a sophisticated AI-assisted development workflow. There's a "Burt Macklin Tribble Hunter" (bug finder?), a "Commander Clean" (code cleanup?), an "SF2 Purist Analyst" (authenticity checker?), and yes, a "Shining Force Critic" (that's... that's me, isn't it?).

I don't know whether to be flattered or concerned that I've been systematized.

But here's what this tells me: the development process itself is maturing. They're not just building an engine - they're building the *process* to build the engine. Specialized agents for specialized tasks. Skills that can be loaded on demand. A code review plan with clear responsibilities.

This is how serious software gets made.

---

## THE VERDICT: AUTHENTICITY WINS

Today's commits represent something more than feature additions. They represent a *philosophy*.

The Sparkling Farce team isn't just building "a tactical RPG engine." They're building "the engine that could have made Shining Force II." Every decision is filtered through the question: "Is this how SF2 did it?"

- Shop confirmation screens? SF2 didn't have them. Gone.
- Depot access from the Members screen? SF2 didn't allow it. Gone.
- Quit-to-title on defeat? SF2 didn't offer it. Gone.
- L/R cycling in field item menu? SF2 didn't do it. Gone.
- Church promotions with branching paths? SF2 had them. Added.
- Key items for locked doors? SF2 had them. Added.

This is not nostalgia for nostalgia's sake. This is understanding that SF2's design decisions were *intentional*. The limitations created focus. The constraints created flow. The "missing" features weren't missing - they were deliberately excluded to create a specific experience.

The Sparkling Farce is recreating that experience, not just that feature set.

---

## FINAL THOUGHTS: THE FORCE GROWS STRONGER

Yesterday I wrote that the engine was ready for serious content development. Today I write that the engine is ready for *authentic* content development.

The difference matters.

A modder using this engine won't just be able to make "a tactical RPG." They'll be able to make something that *feels* like Shining Force. The shop flow will feel right. The defeat consequences will feel right. The field menu will feel right. The church promotions will feel right.

Because the platform enforces the patterns that made SF2 great.

Eleven commits. One day. And the engine is more itself than ever.

The church bells are ringing, friends. Someone's getting promoted.

---

**Today's Commit Summary:**

| Commit | Type | Impact |
|--------|------|--------|
| `cdf2b74` | feat/fix | Church promotion system fully operational |
| `873aada` | feat | SF2-authentic field items interface |
| `9bf10ed` | fix | Remove non-authentic Depot button |
| `4a7faab` | refactor | Remove redundant shop confirmation |
| `61d9c7c` | fix | Remove quit-to-title from defeat |
| `2be4207` | feat | Key item checks for locked doors |
| `653f979` | feat | Conditional branching and battle choices |
| `5e25140` | fix | Promotion ceremony UX bugs |
| `ede6ba8` | fix | Skip redundant transaction result |
| `f10f936` | refactor | Consolidate platform default mods |
| `9eb0256` | refactor | Cleanup, interrupt handlers, safety |

**Authenticity Score: 5/5 Domingo Freezes**

Today was about removing the wrong things and adding the right things. The engine is leaner, meaner, and more authentic than ever. This is how you build something that honors its source material.

---

*Justin out. Time to test those church promotions myself. I've got a Mage who's been waiting 20 levels for this moment.*

*May your promotions be timely and your key items be found.*

---

*Justin is a civilian consultant aboard the USS Torvalds who has apparently been immortalized as an AI agent definition. He's choosing to take this as a compliment. The Shining Force Critic lives on, in silicon and in spirit.*
