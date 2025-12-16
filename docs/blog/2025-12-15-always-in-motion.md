# Always in Motion: SF2 Walks, Wizards, and the Joy of Not Scrolling

**Stardate 2025.349** | By Justin, Tactical RPG Correspondent, USS Torvalds

---

*"Mr. La Forge, why are these sprites standing still on the tactical display?"*

*"They're supposed to be at rest, Captain."*

*"In Shining Force 2, nothing is ever truly at rest. The march forward animation plays even when standing. It represents the eternal vigilance of the warrior spirit."*

*"...Captain, did you stay up all night playing Genesis ROMs again?"*

*"Make it so that these sprites never stop moving, Geordi."*

---

Fellow tacticians, today's transmission from engineering brings us a substantial batch of commits that touch everything from how sprites animate to how modders navigate the editor. Some of this is flashy (bouncy sprites!), some of this is unsexy but necessary (type safety cleanup), and some of this removes more code than it adds (always a good day).

Let's break down what the USS Torvalds crew delivered.

---

## THE HEADLINE: SF2-AUTHENTIC WALK ANIMATIONS

This one hit me right in the nostalgia cortex. Remember how in Shining Force 2, your party members on the battle map would do that little two-frame bounce even when standing still? Bowie, Chester, Jaha -- they were always slightly animated, giving the battlefield this subtle sense of life?

**That's back. Or rather, that's HERE.**

The commit message says it all:

> In Shining Force 2, map sprites continuously animate their walk cycle even when stationary. This removes separate idle animations in favor of walk_down/up/left/right that play continuously.

### The Old Way (Wrong)

Previously, units had two animation categories:
- `idle_down`, `idle_left`, etc. - Static or slow-animating poses for when standing still
- `walk_down`, `walk_left`, etc. - Animation for when actually moving

When a unit stopped moving, the code would switch to idle and **stop the animation**:

```gdscript
# OLD CODE (removed)
elif character_data.sprite_frames.has_animation("walk_down"):
    sprite.animation = "walk_down"
    sprite.stop()  # Don't animate walk when idle
```

That `sprite.stop()` is a crime against Shining Force aesthetics. In SF2, sprites were ALWAYS animating. It gave the map this constant subtle energy.

### The New Way (Correct)

Now it's beautifully simple:

```gdscript
# SF2-authentic: walk animation plays continuously (even when stationary)
if character_data.sprite_frames.has_animation("walk_down"):
    sprite.animation = "walk_down"
    sprite.play()
```

No separate idle animations. No stopping. Just perpetual motion, exactly like the Genesis original.

### Placeholder Sprites Follow Suit

Even the auto-generated placeholder sprites got the memo:

```gdscript
# OLD
var directions: Array[String] = ["idle_down", "idle_left", "idle_right", "idle_up"]

# NEW - SF2-authentic: only walk animations (no separate idle)
var directions: Array[String] = ["walk_down", "walk_left", "walk_right", "walk_up"]
```

The entire `"idle"` animation alias was removed. Gone. Deleted. As it should be.

### Why This Matters

This isn't just about accuracy to SF2. It's about **feel**. Static sprites feel like placeholders. Animated sprites feel like characters. When your army is deployed on the grid and everyone's doing their little bounce, the game feels ALIVE. It's one of those small details that separates "pretty good" from "this is definitely a Shining Force game."

**SF2 Animation Authenticity: 5/5 Mithril Maces**

---

## EDITOR UX: TWO-TIER TAB NAVIGATION

Okay, this one is for the modders, and it's a game-changer for workflow.

The Sparkling Editor has been accumulating tabs like the Enterprise accumulates strange energy beings. Characters, Classes, Abilities, Items, Maps, Terrain, Battles, AI Behaviors, NPCs, Cinematics, Campaigns, Shops, Mod Settings, New Game Configs, Party Templates, Save Slots, Overview...

That's **sixteen tabs**. On a standard monitor, that means horizontal scrolling. On a laptop? Pain.

### The Solution: Category Grouping

Now there's a primary category bar that filters which tabs you see:

| Category | Tabs |
|----------|------|
| **Content** | Characters, Classes, Abilities, Items |
| **Battles** | Maps, Terrain, Battles, AI Behaviors |
| **Story** | NPCs, Cinematics, Campaigns, Shops |
| **System** | Overview, Mod Settings, New Game Configs, Party Templates, Save Slots |

Click "Battles" and you only see battle-related tabs. Click "Story" and you're in narrative-land. No more hunting through a mile-wide tab bar.

### The Implementation is Clean

The category system doesn't just hide tabs visually -- it uses TabContainer's built-in `set_tab_hidden()` method:

```gdscript
func _apply_category_filter() -> void:
    for i in range(tab_count):
        var tab_category: String = _get_tab_category_by_control(tab_control)
        var should_show: bool = (tab_category == current_category)
        tab_container.set_tab_hidden(i, not should_show)
```

Hidden tabs still exist and still receive data sync refreshes. When you switch back to a category, your work is exactly where you left it.

### Category Selection Persists

Your last-selected category is saved between sessions:

```gdscript
func _save_last_selected_category(category: String) -> void:
    var settings: Dictionary = _load_editor_settings()
    settings["last_selected_category"] = category
    _save_editor_settings(settings)
```

Open the editor tomorrow, you're right back in the Battles category where you were working. Nice.

### The Mod Category

There's also a "Mods" category that only appears if a mod provides custom editor tabs. Empty categories don't clutter the bar.

**Editor Navigation: 5/5 Vigor Balls**

---

## THE STARTUP FLOW: FROM BOOT TO MENU

Previously, the game's startup was... let's say "loosely coordinated." Now there's a proper `startup.tscn` scene that orchestrates the entire flow:

1. Wait for autoloads to initialize
2. Load and play the opening cinematic
3. Transition to main menu

### The Coordinator Pattern

```gdscript
func _ready() -> void:
    # Wait for autoloads to initialize
    await get_tree().process_frame
    await get_tree().process_frame

    # Connect to cinematic completion BEFORE loading the scene
    CinematicsManager.cinematic_ended.connect(_on_cinematic_ended, CONNECT_ONE_SHOT)

    # Load and start the opening cinematic
    _load_opening_cinematic()
```

The key insight here: **cinematics don't handle their own navigation anymore**. The startup coordinator does. This means a mod can provide a completely custom opening cinematic without worrying about "what scene do I go to when I'm done?" -- the coordinator handles that.

### Mod Overrides Work Properly

```gdscript
func _get_opening_cinematic_path() -> String:
    # Check if a mod provides a custom opening_cinematic scene
    if ModLoader and ModLoader.registry:
        var mod_scene_path: String = ModLoader.registry.get_scene_path(SCENE_ID)
        if not mod_scene_path.is_empty() and ResourceLoader.exists(mod_scene_path):
            return mod_scene_path

    # Fall back to core scene
    return CORE_OPENING_CINEMATIC
```

Mods can override the opening cinematic scene, the main menu scene, or both. The startup coordinator doesn't care who provides what -- it just orchestrates.

### The Core Main Menu

There's now a fallback `main_menu.tscn` in core that's deliberately minimal:

```gdscript
func _on_new_game_pressed() -> void:
    SceneManager.goto_save_slot_selector("new_game")

func _on_load_game_pressed() -> void:
    SceneManager.goto_save_slot_selector("load_game")

func _on_quit_pressed() -> void:
    get_tree().quit()
```

Three buttons. Fade in. Done. If a mod wants something fancier, they can provide their own main menu. But the platform always has a working fallback.

**Startup Flow: 4/5 Healing Seeds** (Solid implementation, loses one point because I want to see that mod override in action!)

---

## TEMPLATE MOD REMOVAL: LESS IS MORE

The `mods/_template/` directory is gone. 969 lines deleted across 25 files.

### What It Had

- Example character, class, ability, item, terrain resources
- Example battle configuration
- Example town map
- A 191-line README explaining everything
- Lots of `.gitkeep` files for empty directories

### Why It's Gone

Because the Sparkling Editor now has a **Create New Mod wizard** that generates all of this automatically, customized to your mod's ID and settings. Why maintain static template files when the editor can generate fresh ones on demand?

This is the right call. Template files go stale. Wizards generate current-spec content.

**Template Removal: 5/5 Dry Stones**

---

## THE UNSEXY BUT NECESSARY: CLEANUP COMMITS

Several commits fall into the "janitorial work" category:

### UnitUtils for Safe Property Access

A new utility class that avoids GDScript's `UNSAFE_METHOD_ACCESS` warnings:

```gdscript
static func get_display_name(unit: Variant, fallback: String = "Unknown") -> String:
    if unit == null:
        return fallback
    if unit is Object and unit.has_method("get_display_name"):
        var result: Variant = unit.call("get_display_name")
        return str(result) if result != null else fallback
    return fallback
```

Using `call()` instead of direct method invocation lets the code work with any object that has the right methods, without the linter complaining.

### Type Safety Across 12 Files

Explicit Dictionary casts for JSON parsing, typed arrays, missing return type hints -- the kind of work that makes CI green and future debugging easier.

### SpriteFrames Embedding Fixes

Fixing issues where SpriteFrames were being embedded as SubResource instead of loaded externally. Embedded resources cause file bloat and make version control diffs ugly.

### Cinematic System Cleanup

Opening cinematic stages got simplified. Less code doing the same thing is always better.

**Cleanup Work: Appreciated/Appreciated**

---

## HOW THIS COMPARES TO SHINING FORCE

Let's zoom out and evaluate today's work against the originals.

### Animation Philosophy

SF1 and SF2 both had sprites that were constantly in motion on the battle map. The two-frame walk cycle playing continuously was a deliberate design choice -- it made the game feel more dynamic than static chess pieces would. Sparkling Farce now matches this exactly.

What's interesting is the tooling implication: modders creating sprite sheets only need to create walk animations, not idle+walk. That's potentially 33% less sprite work per character. The engine expects less and delivers more.

### Editor Design

Sonic 2 may have had Debug Mode, but SF1/SF2 were developed with Sega's internal tools -- not something modders ever saw. The Sparkling Editor is building toward something unprecedented for this genre: a complete visual authoring environment for tactical RPG content.

The two-tier tab system shows maturity. This project has grown enough content types that organization matters. That's a good problem to have.

### Startup Sequence

SF2 had that amazing opening with the phoenix and the jewels and Sir Astral's narration. Sparkling Farce now has proper infrastructure for mods to create their own memorable intros, with clean handoff to the main menu.

---

## WHAT'S STILL COOKING

From watching these commits, I see the trajectory:

1. **Polish phase** - Lots of cleanup, type safety, UX improvements
2. **Mod infrastructure** - Scene overrides, startup coordination, editor tools
3. **Authenticity focus** - SF2 animation behavior is being matched precisely

The engine is maturing. Fewer "add major new system" commits, more "make existing systems excellent" commits. That's the sign of a project approaching usability.

---

## THE JUSTIN RATING

### SF2-Authentic Animations: 5/5 Angel Rings
This is the kind of detail that separates fan-made from fan-loved. Sprites that never stop moving feel RIGHT.

### Two-Tier Editor Navigation: 5/5 Mithril Maces
Sixteen tabs reduced to four categories. Laptop modders rejoice. Persistence between sessions is the cherry on top.

### Startup Coordinator: 4/5 Healing Seeds
Clean separation of concerns. Mods can override cinematics without navigation logic. Loses a point only because I want to see a mod actually use this.

### Template Removal: 5/5 Dry Stones
Less maintained code, better tooling. The Create Mod wizard made this possible.

### Cleanup Work: A Grateful Nod
Type safety isn't glamorous, but green CI checks and clean diffs matter.

### Overall Day's Work: 5/5 Chaos Breakers

This batch of commits represents a project that knows what it wants to be. SF2 authenticity in the details, modern tooling for modders, clean architecture under the hood. Every commit today either preserved the original games' magic or made it easier for modders to create new magic.

The USS Torvalds crew should be proud. We're getting closer to something every Shining Force fan MUST have.

---

*Next time on the Sparkling Farce Development Log: What new mod will test the limits of the data-driven AI system? Will someone create a total conversion that rivals the original? Stay tuned, and remember -- in space, no one can hear you miss a 95% hit chance.*

---

*Justin is a civilian consultant aboard the USS Torvalds who may or may not have named all his save files after Shining Force characters. (Slot 1: PETER. Slot 2: KIWI. Slot 3: DOMINGO. He stands by these choices.)*
