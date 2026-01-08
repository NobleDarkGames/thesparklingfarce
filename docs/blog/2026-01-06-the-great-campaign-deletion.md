# The Great Campaign Deletion: 4,400 Lines That Had to Die

**Stardate 2026.006** | By Justin, Tactical RPG Correspondent, USS Torvalds

---

*"Personal Log. I've seen some bold moves in my time aboard the Torvalds. Commander Data deleting his own emotion chip. Worf recommending against battle. But Engineering just deleted 4,400 lines of campaign code and... the game is better for it? Sometimes the bravest choice is knowing when to let go."*

---

Fellow Force fanatics, gather round. What happened this week is not just a technical refactor - it is a philosophical statement about what this engine wants to be.

Twenty-three commits. The removal of an entire system. The birth of something simpler and more powerful. Let me tell you about the day the Campaign System met the airlock.

---

## THE ELEPHANT IN THE ROOM: GOODBYE, CAMPAIGN MANAGER

### The Commit That Changed Everything (4c4ebdb)

Let us look at the carnage:

```
42 files changed, 361 insertions(+), 4741 deletions(-)
```

That is a **net reduction of 4,380 lines**. Files that no longer exist:

- `core/systems/campaign_manager.gd` (907 lines)
- `core/systems/campaign_loader.gd` (381 lines)
- `core/resources/campaign_data.gd` (206 lines)
- `core/resources/campaign_node.gd` (227 lines)
- `addons/sparkling_editor/ui/campaign_editor.gd` (1,810 lines)
- `scenes/ui/chapter_transition_ui.gd` (286 lines)
- `tests/unit/campaign/test_campaign_data.gd` (270 lines)

And what replaced it? This elegant simplicity in `NewGameConfigData`:

```gdscript
## Scene path to load when starting a new game
## Example: "res://mods/demo_campaign/scenes/mudford.tscn"
@export_file("*.tscn") var starting_scene_path: String = ""

## Optional spawn point ID within the starting scene
@export var starting_spawn_point: String = ""

## Optional cinematic ID to play before loading the starting scene
## Use for intro cutscenes, story setup, etc.
@export var intro_cinematic_id: String = ""
```

Three fields. That is it. Start scene, spawn point, optional intro cinematic.

### Why This Actually Makes Sense

Here is the dirty secret about Shining Force: it did not have a "campaign system" either. SF1 and SF2 just... loaded the next map. Talked to Max about where to go. The world moved forward through triggers, flags, and simple transitions.

The old campaign system was trying to be Final Fantasy Tactics' mission structure when it should have been Shining Force's organic world progression. It was overengineered for a problem that cinematics and flags already solve better.

---

## THE CINEMATIC COMMAND REVOLUTION

With the campaign system gone, the engine needed a new way to handle battles, choices, and branching storylines. Enter three new cinematic commands that fundamentally change how games can be built.

### show_choice: The Dialog That Does Things (795201f)

This is not just a dialog command - it is a mini-mission briefing system:

```json
{
  "type": "show_choice",
  "params": {
    "choices": [
      {
        "label": "Fight!",
        "action": "battle",
        "value": "goblin_ambush",
        "on_victory_cinematic": "victory_scene",
        "on_victory_flags": ["defeated_goblins"]
      },
      {"label": "Run away", "action": "set_flag", "value": "fled_goblins"},
      {"label": "Never mind", "action": "none", "value": ""}
    ]
  }
}
```

Six different action types: `battle`, `shop`, `cinematic`, `set_flag`, `set_variable`, and `none`. Each choice can chain into a different outcome. This is exactly how SF2's NPCs worked - "Would you like to join the Force?" Yes leads to recruitment, No leads to "Come back when you're ready."

The code handles this elegantly with a clean match statement:

```gdscript
match action:
    "battle":
        _action_battle(choice)
    "set_flag":
        _action_set_flag(value)
    "cinematic":
        _action_cinematic(value)
    "set_variable":
        _action_set_variable(value)
    "shop":
        _action_shop(value)
    "none", "":
        _complete()
```

No inheritance trees. No abstract strategy patterns. Just pattern matching on a string. Sometimes boring code is best code.

### trigger_battle: NPC-Initiated Combat With Consequences (dcc96fc)

Remember how in SF2 you could talk to certain enemies and they would challenge you? How Lemon would offer to duel Peter? This command makes that possible:

```json
{
  "type": "trigger_battle",
  "params": {
    "battle_id": "goblin_ambush",
    "on_victory_cinematic": "victory_scene",
    "on_defeat_cinematic": "defeat_scene",
    "on_victory_flags": ["defeated_goblins"],
    "on_defeat_flags": ["fled_battle"]
  }
}
```

Victory and defeat now properly branch the story. Win, and you see the victory cinematic and get your flags. Lose, and the defeat cinematic plays. The `external_battle_handler` flag tells BattleManager that someone else (the cinematic system) is handling post-battle transitions:

```gdscript
GameState.external_battle_handler = true
TriggerManager.start_battle(battle_id)
```

This is the kind of systems integration that lets content creators build complex narrative moments without writing code.

### check_flag: Conditional Storytelling (653f979)

The cherry on top - true conditional branching in cinematics:

```json
{
  "type": "check_flag",
  "params": {
    "flag": "battle1_victory",
    "if_true": [
      {"type": "dialog_line", "params": {"text": "You've returned victorious!"}}
    ],
    "if_false": [
      {"type": "dialog_line", "params": {"text": "Greetings, newcomer..."}},
      {"type": "show_choice", "params": {"choices": [...]}}
    ]
  }
}
```

The implementation uses queue injection - branch commands get pushed to the front of the command queue:

```gdscript
func inject_commands(commands: Array) -> void:
    # Insert at front (reverse order to maintain sequence)
    for i: int in range(commands.size() - 1, -1, -1):
        var cmd: Variant = commands[i]
        if cmd is Dictionary:
            _command_queue.push_front(cmd)
```

Reverse order insertion to maintain sequence. Simple. Correct. No recursion depth limits. This is how you build a scripting system that can handle arbitrarily complex branching without exploding.

---

## BATTLE PORTRAITS: FINALLY, THE VISUAL PUNCH (d1b6acf)

Shining Force without battle portraits is like Star Trek without the viewscreen. You need that moment when the camera cuts to your hero squaring off against a hulking demon, both sprites filling the screen.

The new system gets the positioning *right*:

```gdscript
# SF2 POSITIONING: Player ALWAYS on RIGHT, Enemy ALWAYS on LEFT
# (regardless of who initiated the attack)
_right_unit = initial_attacker if initial_attacker.is_player_unit() else initial_defender
_left_unit = initial_defender if initial_attacker.is_player_unit() else initial_attacker
```

This is not arbitrary. In SF2, the player's party always appears on the right side with their backs to the camera (you are BEHIND your forces), while enemies face you from the left. It is a subtle but crucial piece of visual language that says "these are YOUR people."

The code handles counter attacks and role swaps without moving the sprites:

```gdscript
func _swap_combatant_roles() -> void:
    # Swap the tracked units (who is attacking/defending this phase)
    var temp: Unit = _current_attacker
    _current_attacker = _current_defender
    _current_defender = temp
    # That's it! Position-based helpers handle the rest
```

No visual teleportation. No jarring sprite swaps. The positions stay fixed, only the attack direction changes. Exactly like the originals.

---

## THE DEMO IN ACTION

Look at how the cloaked figure cinematic now works:

```json
{
  "type": "check_flag",
  "params": {
    "flag": "battle1_victory",
    "if_true": [
      {
        "type": "dialog_line",
        "params": {
          "character_id": "npc:cloaky",
          "text": "Ah, you've returned victorious! I knew you had it in you."
        }
      }
    ],
    "if_false": [
      {
        "type": "dialog_line",
        "params": {
          "character_id": "npc:cloaky",
          "text": "Greetings, {player_name}. Yes, I know all about you!"
        }
      },
      {
        "type": "show_choice",
        "params": {
          "choices": [
            {
              "action": "battle",
              "label": "Battle 1",
              "on_victory_flags": ["battle1_victory"],
              "value": "demo_campaign_battle_1767747082"
            }
          ]
        }
      }
    ]
  }
}
```

First visit: mysterious NPC offers you a battle choice. Win the battle: flag gets set. Return later: NPC recognizes your victory with different dialog.

This is EXACTLY how Shining Force 2's optional content worked. Talk to someone in Ribble before you have the right item? One dialog. Come back after you found it? Different dialog, new options.

No campaign nodes. No state machines. Just flags and conditional commands.

---

## THE LITTLE FIXES THAT MATTER

Beyond the big changes, there is a constellation of quality-of-life fixes:

**Dialog Cancel Handling (4c4ebdb)**: Back out of an NPC choice menu and the game properly cleans up. No more locked input states.

```gdscript
func _on_dialog_cancelled() -> void:
    DialogManager.clear_external_choices()
    CinematicsManager.skip_cinematic()
    _cleanup()
```

**Battle Return Flow**: Win a battle triggered from a cinematic? You return to where you were, not some hardcoded spawn point.

**Green Overlay Fix (0c4f522)**: Battle maps no longer have that weird green tint. Someone left a debug overlay enabled. Classic.

---

## THE VERDICT

This week the Sparkling Farce shed the weight of over-architecture and found its soul.

The campaign system was not bad - it was premature. It solved problems the engine did not have yet while making simple things complicated. "I want this NPC to offer a battle" should not require understanding a directed graph system.

Now it requires writing JSON. Readable, editable, moddable JSON.

**THUMBS UP**: Enthusiastically, emphatically, unreservedly.

The cinematic command system now does what the campaign system tried to do, but:
- It is data-driven (JSON vs. resource trees)
- It is composable (commands can contain commands)
- It is debuggable (you can read the flow in a text editor)
- It is moddable (no GDScript knowledge required for branching stories)

This is what platform development looks like. Sometimes you build the wrong thing first, learn from it, and build the right thing. The Sparkling Farce team just demonstrated they understand this principle.

---

## LOOKING AHEAD

With these pieces in place, the path to a full demo is clearer than ever:

- NPCs can offer battles with branching outcomes
- Story flags can gate content and dialog
- Battle portraits make combat feel epic
- The whole system is JSON-configurable

What is missing? Probably party management integration, more battle types, and the recruitment flow that makes Shining Force special ("Do you want this character to join your force?").

But the foundation is solid. The architecture is sound. And 4,400 lines of code are no longer in the way.

---

*Justin out. Time to test this new battle portrait system and see if my custom hero sprite looks as good as Peter the Phoenix.*

*May your counters always crit and your healers stay out of aggro range.*
