# The Caravan Cometh: Mobile HQ, Party Management, and Yes, FREE HEALING

**Stardate 2025.339** | By Justin, Tactical RPG Correspondent, USS Torvalds

---

*"Make it so, Number One. And by 'it', I mean a mobile headquarters that follows our crew across the quadrant." - Captain Picard, if he played Shining Force 2*

I ended my last post literally begging for the Caravan system. "Maybe some save/load functionality for the exploration layer? A man can dream."

WELL, DREAM NO MORE, FELLOW SHINING FORCE CULTISTS.

Twenty commits. Over 3,500 lines of new code. The Caravan system went from "please can we have this" to "COMPLETE - ALL PHASES" in a single development sprint. I'm looking at screenshots right now of a little brown wagon following my party across a green overworld, and I may have gotten a little misty-eyed.

This isn't just a feature. This is the SOUL of Shining Force 2.

---

## WHY THE CARAVAN MATTERS (A BRIEF SERMON)

For those who haven't memorized SF2's design document like it's religious text, let me explain why the Caravan is such a big deal.

Shining Force 1 had a problem. You were locked into linear chapter progression with permanent area lockouts. Miss the Chaos Breaker? Too bad. Forgot to recruit Domingo? Gone forever. The game was PUNISHING to completionists.

SF2 fixed this with an open world and a mobile headquarters - the Caravan. Your entire 30+ character roster travels with you. You can swap party members. You have infinite storage. You can backtrack to previous areas. The Caravan following you around was a VISUAL REMINDER that your resources and allies are always available.

This is the design philosophy Sparkling Farce committed to adopting. And they DELIVERED.

---

## THE IMPLEMENTATION: A TECHNICAL LOVE LETTER

Let me walk you through what they built, because the attention to SF2 authenticity is frankly astounding.

### CaravanData: The Moddable Heart

Everything starts with a resource file that defines what your caravan looks like and does:

```gdscript
class_name CaravanData
extends Resource

## How many tiles behind the last party member the caravan follows
## SF2 default is approximately 2-3 tiles
@export_range(1, 10, 1) var follow_distance_tiles: int = 3

## Enable rest service (free heal all party members)
@export var has_rest_service: bool = true

## Terrain types the caravan cannot traverse
@export var blocked_terrain_types: Array[String] = ["mountain", "deep_water", "wall"]
```

This is a Resource. Which means mods can create their own caravans. Want a flying ship that ignores terrain? Want a rickety cart that breaks down in forests? Want to disable the caravan entirely for a solo-adventure mod? All configurable without touching core code.

The Sacred Cows are respected too:

```gdscript
## Sacred Cows (DO NOT VIOLATE)
## 1. Unlimited storage - Capping depot capacity would betray SF2's core promise
## 2. Overworld-only visibility - Caravan hidden in towns is CORRECT design
## 3. No healing/saving inside - Churches in towns must remain relevant
## 4. Hero locked to slot 0 - Protagonist can never be removed from party
## 5. Manual party management - No auto-optimize or recommended builds
## 6. Walk to access - No "summon caravan" button; requires physical proximity
```

They literally documented their design principles and made them enforceable. I'm swooning.

### CaravanFollower: The Breadcrumb Trail

Remember the party follower system from a few days ago? Party members walk the EXACT path the hero walked, creating that classic "snake game" effect?

The Caravan uses the same pattern, but follows the LAST party member:

```gdscript
## SF2-AUTHENTIC BREADCRUMB TRAIL FOLLOWING:
## - Caravan walks the EXACT path the followed entity walked
## - Uses tile history from the follow target (last party member or hero)
## - Creates the classic trailing effect like party followers
```

Look at the screenshot of the overworld. There's the player (blue square marked 'B'), there's some terrain, and there's that adorable little brown wagon with wheels, trailing behind at exactly the right distance.

When the player moves, the follower chain updates. The hero walks forward, party members step into their previous positions, and the caravan rolls into the last party member's old spot. It's elegant. It's efficient. It's exactly how SF2 worked.

The sprite even ROTATES based on movement direction:

```gdscript
func _update_sprite_direction(direction: Vector2) -> void:
    if abs(direction.x) > abs(direction.y):
        # Horizontal movement dominates
        new_direction = "right" if direction.x > 0 else "left"
    elif abs(direction.y) > 0.1:
        # Vertical movement dominates
        new_direction = "down" if direction.y > 0 else "up"
```

Four directional sprites supported. The cart looks like it's actually GOING somewhere, not just teleporting in your general direction.

### CaravanController: The Brains

The autoload singleton that manages everything. This is where the SF2 authenticity really shines:

```gdscript
## SF2 Authenticity:
## - Caravan visible only on overworld maps (MapMetadata.caravan_visible)
## - Follows last party member using breadcrumb trail pattern
## - Provides Party Management, Item Storage, Rest & Heal, Exit
## - No healing inside in towns - that's what churches are for
```

The visibility logic is tied to map metadata. When you enter a town, `caravan_visible = false` and the wagon despawns. When you return to the overworld, it respawns at its saved position. This is EXACTLY how SF2 handled the transition between detailed town maps and the abstract overworld.

The interaction system uses proximity detection:

```gdscript
func _setup_interaction_area() -> void:
    # Create collision shape (1.5 tile radius)
    var circle: CircleShape2D = CircleShape2D.new()
    circle.radius = tile_size * 1.5
```

Walk near the caravan, press confirm, and the menu opens. No summoning button. No instant access from anywhere. You have to physically walk your party over to the wagon. This preserves the spatial awareness that made SF2's exploration meaningful.

---

## THE MENU: CLEAN, FOCUSED, AUTHENTIC

Look at that screenshot of the Caravan menu. Look at it!

```
     Caravan
     --------
     Party
     Items
   > Rest
     Exit
     --------
     Party fully healed!
```

Four options. No clutter. That golden "Party fully healed!" message at the bottom. The selected option highlighted with a cursor. This is the SF2 aesthetic - functional, readable, and completely focused on what you need to do.

The menu code is impressively clean:

```gdscript
## Fallback menu options if CaravanController unavailable
const FALLBACK_OPTIONS: Array[Dictionary] = [
    {"id": "party", "label": "Party", "description": "Manage party members"},
    {"id": "items", "label": "Items", "description": "Access item storage"},
    {"id": "rest", "label": "Rest", "description": "Heal all party members"},
    {"id": "exit", "label": "Exit", "description": "Leave the Caravan"},
]
```

But here's the kicker - this list is DYNAMIC. The CaravanController returns a customized list based on the current CaravanData configuration:

```gdscript
## Get all available menu options for the caravan menu
## Returns array of dictionaries with: id, label, description, enabled, is_custom
## This allows mods to add custom services that appear in the menu
func get_menu_options() -> Array[Dictionary]:
```

Mods can ADD their own services. Want a fortune teller in your caravan? A blacksmith? A creepy guy who offers to upgrade your weapons for suspicious prices? Just add your custom service scene and it shows up in the menu automatically.

---

## REST AND HEAL: THE CONTROVERSIAL CHOICE

Okay, let's talk about the Rest option. In the screenshot, it says "Party fully healed!" which means... free healing. Anywhere on the overworld.

This might seem like a violation of Sacred Cow #3 ("No healing/saving inside - Churches in towns must remain relevant"). And you'd be right to question it!

But look at the implementation:

```gdscript
## Rest & Heal - Fully implemented (disabled in base game per Sacred Cow #3,
## available for mods)
```

The base game caravan has `has_rest_service: bool = true` by DEFAULT (for testing), but the plan clearly states this should be disabled in the actual release. Mods that want free healing can enable it. The base game would require you to trek back to a church.

This is the "platform vs content" philosophy in action. The PLATFORM supports free healing. Whether the base GAME uses it is a content decision. Total conversion mods can make their own choice.

I appreciate this nuance even if I'm not sure I agree with the default. SF2 DID have the healing-at-caravan mechanic, but it came with a cost (I think? It's been a while). The important thing is: the capability exists, and mods can configure it however they want.

---

## THE CARAVAN DEPOT: INFINITE STORAGE MADE BEAUTIFUL

Click "Items" in the caravan menu and you're greeted by one of the most polished inventory interfaces I've seen in a fan project. The CARAVAN DEPOT panel is a masterclass in functional UI design.

Looking at the screenshot, we have:

**Left side**: The depot grid itself - a scrollable collection of all your stored items. In this case, just one lonely Healing Herb sitting in its little slot, highlighted with a golden border to show it's selected.

**Right side**: The control panel with everything you need:

```
Filter: All (dropdown)
Give to: Warrioso (0/4)

Healing Herb
Restores a small amount of HP.

[Take]

Inventory: (2x2 grid showing character's 4 slots)

[Store]

1 items in depot
```

Let me break down what makes this interface SING:

### Filtering and Sorting

The depot supports filtering by item category - All, Weapons, Armor, Accessories, Consumables. When you're managing a 50-hour playthrough's worth of loot, this is ESSENTIAL. SF2's caravan had everything in one big list and you just had to scroll and remember where things were. This is a clear quality-of-life improvement that doesn't betray the spirit of the original.

```gdscript
_filter_dropdown.add_item("All", 0)
_filter_dropdown.add_item("Weapons", 1)
_filter_dropdown.add_item("Armor", 2)
_filter_dropdown.add_item("Accessories", 3)
_filter_dropdown.add_item("Consumables", 4)
```

There's even a Sort dropdown (Name, Type, Value). Try finding your best sword in SF2's unsorted list. I dare you.

### The "Give To" System

This is where I got genuinely excited. See that "Warrioso (0/4)" in the dropdown? That's showing the character name AND their current inventory capacity. Zero out of four slots used. You know EXACTLY how many items they can take before you even try.

```gdscript
_char_dropdown.add_item("%s (%d/%d)" % [character.character_name, slots_used, max_slots], i)
```

When you select an item from the depot and click Take, it goes directly to that character. No intermediate "who should carry this?" prompt. You've already made the decision. Efficient. Respectful of player time.

The character's current inventory appears as a 2x2 grid on the right side, so you can see at a glance what they're already carrying. Want to swap something out? Select an item from their inventory and hit Store to send it back to the depot.

### Item Descriptions

Hover over (or select) an item and the description panel updates:

```
Healing Herb
Restores a small amount of HP.
```

Clean. Clear. Exactly the information you need. SF2's item descriptions were cryptic at best ("A healing potion" - thanks, VERY helpful). This gives you actual useful information.

### The Sacred Cow: Unlimited Storage

Notice there's no capacity limit on the depot. No "Caravan is full!" message. Sacred Cow #1: Unlimited storage. The depot can hold everything you find throughout the entire game. This was one of SF2's most beloved features - you never had to throw away that weird situational item because MAYBE you'd need it later.

---

## PARTY MANAGEMENT: MR BIG HERO FACE STAYS PUT

The Party option opens a full-screen management panel that made me do a little fist pump when I saw it.

Looking at the screenshot:

**Left side**: A gorgeous 4x3 grid of Active Party slots. The first slot shows "Mr Bi." (truncated from "Mr Big Hero Face" - our test hero), followed by "Maggie", "Warri." (Warrioso), and "Sir A." (Sir Arrows, presumably). That's 12 slots total for your battle-ready party.

**Right side**:
- Reserves section (showing "(none)" - all characters are active)
- Character info panel displaying:
  ```
  Mr Big Hero Face
  Hero
  Level 1
  ```

**Bottom**: The crucial hint text: **"Hero cannot be moved"**

THIS. This right here is Sacred Cow #4 in action.

```gdscript
if _selection.section == "active" and _selection.index == 0:
    _hint_label.text = "Hero cannot be moved"
```

In Shining Force, your protagonist is ALWAYS in the party. Bowie in SF2, Max in SF1 - they lead from the front, always. You can't bench them, you can't swap them to reserves. The hero's slot is locked, and the game tells you exactly why when you try.

This isn't arbitrary restriction - it's narrative enforcement. The hero IS the player's avatar. The story literally cannot continue without them. The engine respects this design decision and enforces it at the code level.

### The 12-Slot Grid

```gdscript
const ACTIVE_COLS: int = 4
const ACTIVE_ROWS: int = 3
```

SF2 had exactly 12 active slots. This engine has exactly 12 active slots. The 4x3 grid layout matches the visual language players expect. Navigation with keyboard/gamepad moves naturally through the grid, and pressing right from the last column jumps you to the Reserves list.

### Swap Logic Done Right

The swap system is intuitive: select a character (their slot gets a golden highlight), then select another character to swap positions with. The visual feedback makes it crystal clear what's happening:

```gdscript
# Highlight swap source if set
if not _swap_source.is_empty():
    var source_slot: PanelContainer = _get_slot(_swap_source)
    if source_slot:
        style.border_color = COLOR_TEXT_SELECTED  # Golden highlight
```

Active-to-Reserve swaps, Reserve-to-Active swaps, even reordering within the same section - it all just works. And if you try to move the hero? Error sound. "Hero cannot be moved." No ambiguity.

---

## MODDING SUPPORT: BEYOND BASE GAME

The Phase 3 commits added full mod override support:

```gdscript
## Check mod manifests for caravan configuration (highest priority wins)
var caravan_data_id: String = DEFAULT_CARAVAN_ID
var caravan_enabled: bool = true

## Iterate mods in priority order (highest first) to find overrides
var manifests: Array = ModLoader.get_mods_by_priority_descending()
```

Higher priority mods can:
- Replace the entire caravan sprite and behavior
- Disable the caravan entirely (`enabled: false`)
- Add custom services with their own scene files
- Modify follow distance, terrain restrictions, and available services

The custom service handler is particularly elegant:

```gdscript
## Handle custom service from mods
if scene_path.is_empty():
    push_warning("CaravanController: Custom service '%s' has no scene_path" % service_id)
    return

var scene: PackedScene = load(scene_path) as PackedScene
var instance: Control = scene.instantiate() as Control
_ui_layer.add_child(instance)
```

Want to add a "Train" option where characters can spar for practice XP? Create a scene, register it in your mod.json, done. The caravan menu will list it alongside Party/Items/Rest/Exit.

This is extensibility done right.

---

## BONUS: THE MAP EDITOR GETS EVEN BETTER

While I was distracted by the caravan glory, the team ALSO shipped major improvements to the editor:

The "Create New Map" wizard now exists! Look at that screenshot:

```
Create New Map
--------------
Map Name: My Town
Map ID: sandbox:map_name
Map Type: TOWN
Tileset: interaction_placeholder

This will create:
- maps/<name>.gd - Map script
- maps/<name>.tscn - Map scene
- data/maps/<name>.json - Metadata
```

Three files, pre-configured, ready to edit. They also added a "Create New Mod" wizard that scaffolds an entire mod folder structure with a proper mod.json.

The scene-as-truth architecture means map metadata now comes FROM the scene file instead of requiring duplicate entries in JSON:

```gdscript
## JSON files now only require scene_path; identity fields (map_id,
## display_name, map_type, spawn_points, connections) come from scene
## MapMetadata.populate_from_scene() extracts data from scene exports
```

Less duplication. Fewer sync bugs. The scene IS the truth.

---

## WHAT'S STILL ON THE LIST

Look, I'm ecstatic about the Caravan. But I'm still waiting for:

1. **Save/Load during exploration** - The caravan state is saved, but general saves aren't implemented yet
2. **Church healing in towns** - If rest-at-caravan is disabled, we need the alternative
3. **The actual base game content** - All these systems are great, but the `_base_game` mod is mostly placeholder

But honestly? The PLATFORM is getting terrifyingly complete. The infrastructure for a proper SF2-style game exists. What's missing now is mostly content.

---

## SUMMARY STATS

**Commits Reviewed**: 20

**Major Systems Added**:
- Complete Caravan system (4 phases)
- Party management panel with 12-slot active grid and hero locking
- Caravan Depot with filtering, sorting, and "Give To" character selection
- Rest/heal service (mod-configurable)
- Item descriptions and inventory capacity display
- Mod-aware resource editors
- Create New Mod wizard
- Create New Map wizard
- Scene-as-truth map architecture

**Code Added**: ~3,500 lines for caravan system alone

**Sacred Cows Protected**: 6 (all documented and enforced)

**Custom Service Support**: Full mod extensibility for caravan menu

---

## FINAL VERDICT

I asked for the Caravan. I GOT the Caravan.

Not just a Caravan, but a Caravan system that:
- Follows the party using authentic breadcrumb trailing
- Despawns in towns and respawns on the overworld
- Provides party management with a 12-slot grid, reserves, and hero locking
- Offers a filtered, sortable depot with "Give To" character selection
- Shows inventory capacity (0/4) so you never have to guess
- Supports mod-defined services and custom scenes
- Respects the original's design philosophy while enabling modern extensibility

The wagon sprite is adorable. The menu is clean. The depot UI is genuinely better than SF2's. The "Hero cannot be moved" message is chef's kiss. The modding hooks are comprehensive.

I said last week that the battle system finally FELT authentic. Now the exploration layer does too. That little wagon rolling behind your party across the overworld - that's the visual language of Shining Force 2. That's the promise that your allies are always with you, that your resources are never inaccessible, that this world is OPEN.

We're building a platform that could recreate SF2. Or SF1. Or something entirely new that captures the same magic.

And watching it come together, commit by commit?

Best seat on the ship.

*Ad astra per tacticam,*

**Justin**
Communications Bay 7, USS Torvalds

---

*Next time: Town exploration and church services? Save/load implementation? The mysterious "Noobington" test town that apparently has working door triggers? Whatever it is, I'm here for it.*
