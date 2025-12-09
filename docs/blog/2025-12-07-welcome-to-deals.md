# Welcome to Deals! Nine Commits, Two Major Systems, and One Very Busy Weekend

**Stardate 2025.342** | By Justin, Tactical RPG Correspondent, USS Torvalds

---

*"Captain, I'm detecting an anomalous energy signature from the development branch. It appears to be... an entire shop system. And a debug console. And an item action menu. And modal input blocking patterns. All in 48 hours."* - Me, checking the git log this morning

Friends, I've seen some productive weekends in my time aboard the Torvalds, but this one had me doing a double-take worthy of Commander Riker seeing a second Enterprise. Nine commits. NINE. And we're not talking "updated README" commits here - we're talking 5,500+ lines of new code, an entire SF2-authentic shop system, a Quake-style debug console, and the foundation for full item management.

Grab your Medical Herb and settle in. This is going to be a long one.

---

## THE SHOP SYSTEM: "Who equips this?"

Let me tell you about my favorite four words in Shining Force 2. You walk into the Granseal weapon shop. You've got just enough gold for that Steel Sword. You select it, confirm the purchase, and then... "Who equips this?"

That moment of decision. That tactical consideration mid-shopping. Do you give it to Bowie? Is Jaha's attack already capped by his current gear? Wait, can Sarah even USE a Steel Sword?

This is what separates Shining Force's shopping from the generic "select item, item goes into bottomless inventory" approach that most RPGs use. And guess what? The Sparkling Farce engine now nails it.

### ShopData: The Foundation

```gdscript
class_name ShopData
extends Resource

enum ShopType {
    WEAPON,     ## Sells weapons (swords, bows, axes)
    ITEM,       ## Sells consumables and accessories
    CHURCH,     ## Healing, revival, promotion, uncursing services
    CRAFTER,    ## Mithril forge / special crafting
    SPECIAL     ## Custom shop types defined by mods
}

@export var shop_id: String = ""
@export var shop_name: String = ""
@export var inventory: Array[Dictionary] = []
@export var deals_inventory: Array[String] = []
@export_range(0.1, 2.0, 0.05) var buy_multiplier: float = 1.0
@export_range(0.1, 1.0, 0.05) var deals_discount: float = 0.75
```

Look at that deals system! In SF2, you'd occasionally find shops with special "Deals" that offered discounted items. It was a small thing, but it made you feel clever for checking. That's preserved here - modders can define special deals with a configurable discount multiplier.

But here's where it gets really interesting for total conversion mods: notice those `required_flags` and `forbidden_flags` exports? A shop can be gated behind story progression. The Arms Dealer in Ribble won't sell you the good stuff until you've proven yourself. The church in Hassan might refuse service if you've been consorting with devils. It's all possible without writing custom code.

### ShopManager: Where The Magic Happens

The ShopManager autoload is over 700 lines of carefully considered transaction logic. Let me highlight the parts that made me genuinely happy:

```gdscript
## Get eligible characters for receiving an item (considering item type)
## For equipment: returns characters who can equip it
## For consumables: returns characters with inventory space
func get_eligible_characters_for_item(item_id: String) -> Array[Dictionary]:
    var item_data: ItemData = _get_item_data(item_id)
    if not item_data:
        return []

    # Equipment needs class/slot checking
    if item_data.is_equippable():
        return get_characters_who_can_equip(item_id)

    # Consumables just need inventory space
    return get_characters_with_inventory_room()
```

THIS IS CORRECT. In SF2, when you bought a Steel Sword, you'd see only the characters who could actually equip it. When you bought a Medical Herb, you'd see everyone with inventory space. The engine now handles this distinction automatically. No more "give Domingo the Battle Axe and wonder why he can't use it" moments (unless you do it on purpose, you monster).

### The Multi-Screen Architecture

The shop UI isn't just a dialog box - it's a full multi-screen system with its own controller:

```gdscript
const SCREEN_PATHS: Dictionary = {
    "action_select": "res://scenes/ui/shops/screens/action_select.tscn",
    "item_browser": "res://scenes/ui/shops/screens/item_browser.tscn",
    "char_select": "res://scenes/ui/shops/screens/char_select.tscn",
    "placement_mode": "res://scenes/ui/shops/screens/placement_mode.tscn",
    "sell_char_select": "res://scenes/ui/shops/screens/sell_char_select.tscn",
    "sell_inventory": "res://scenes/ui/shops/screens/sell_inventory.tscn",
    "sell_confirm": "res://scenes/ui/shops/screens/sell_confirm.tscn",
    "confirm_transaction": "res://scenes/ui/shops/screens/confirm_transaction.tscn",
    "transaction_result": "res://scenes/ui/shops/screens/transaction_result.tscn",
}
```

Each screen is its own scene with its own logic. The `push_screen` / `pop_screen` navigation maintains a history stack so players can navigate back naturally. This is exactly how SF2's menus felt - layered, navigable, never leaving you stranded.

### Church Services: Healing, Revival, and Exorcism

Oh, and churches are shops too:

```gdscript
func church_heal(character_uid: String) -> Dictionary:
    if not current_shop:
        return {success = false, error = "No shop is open", cost = 0}

    if current_shop.shop_type != ShopData.ShopType.CHURCH:
        return {success = false, error = "Not a church", cost = 0}

    var cost: int = current_shop.heal_cost
    # ...
```

Full support for healing, revival (with level-scaled costs!), and uncursing. The Granseal church experience is now available to modders out of the box.

### QoL Improvements Over SF2

Now, I'm a purist, but I'm not a masochist. The engine includes some quality-of-life improvements:

1. **Sell from Caravan**: In SF2, you had to retrieve items from Caravan storage before selling them. Here, shops can optionally allow direct Caravan sales. The `can_sell_from_caravan` flag defaults to true but can be disabled for authentic-experience mods.

2. **Stat Comparison**: `get_stat_comparison(character_uid, item_id)` returns a dictionary showing exactly how the new equipment compares to current gear. No more mental math trying to remember if +5 ATK is better than what Peter already has.

---

## THE DEBUG CONSOLE: POWER TO THE PEOPLE

Here's where my inner power user started salivating. Hit F1, F12, or tilde, and down slides a Quake-style debug console:

```gdscript
const COLOR_SUCCESS: String = "[color=#66E680]"
const COLOR_ERROR: String = "[color=#FF6666]"
const COLOR_INFO: String = "[color=#80D9FF]"
const COLOR_COMMAND: String = "[color=#B3B3D9]"
```

BBCode colored output. Command history with Up/Down navigation. Quote-aware argument parsing. And commands organized into logical namespaces:

- **hero.*** - give_gold, set_level, heal, give_item
- **party.*** - grant_xp, add, remove, list, heal_all
- **campaign.*** - set_flag, clear_flag, list_flags, trigger
- **battle.*** - win, lose, spawn, kill
- **debug.*** - clear, fps, reload_mods, scene, shop, list_shops

Let me show you why this matters for development and testing:

```
> debug.create_test_save
Created test save with 1000 gold
Note: This save is in-memory only and will not persist

> debug.list_shops
=== Available Shops (4) ===
  granseal_weapon_shop - Granseal Weapon Shop [WEAPON]
  granseal_item_shop - Granseal Item Shop [ITEM]
  granseal_church - Granseal Church [CHURCH]
  noobington_item_shop - Noobington Item Shop [ITEM]

> debug.shop noobington_item_shop
Opened shop: Noobington Item Shop
```

You can test shops without having to navigate to them in-game. You can give yourself items to test equipment interactions. You can set campaign flags to test conditional content. This is developer-experience design at its finest.

### The Mod Extension API

And it's extensible! Mods can register their own commands:

```gdscript
## Register a command from a mod
func register_command(command_name: String, callback: Callable, help_text: String, mod_id: String = "") -> void:
    var name_lower: String = command_name.to_lower()
    if name_lower in mod_commands:
        push_warning("DebugConsole: Command '%s' overridden by mod '%s'" % [command_name, mod_id])
    mod_commands[name_lower] = {
        "callback": callback,
        "help": help_text,
        "mod_id": mod_id
    }
```

A weather mod could add `weather.set sunny`. A quest mod could add `quest.complete main_story_1`. The help system automatically lists mod commands separately, so players know what came from where.

---

## ITEM ACTION MENUS: Use/Equip/Give/Drop/Info

Phase 1 of the Item Management Workflow landed, and it's exactly what you'd expect from an SF-faithful implementation:

```gdscript
enum ActionType {
    USE,    # Consumables with usable_on_field/usable_in_battle
    EQUIP,  # Equippable items (exploration only by default)
    GIVE,   # Transfer to another party member
    DROP,   # Discard item (if can_be_dropped is true)
    INFO    # Always available
}
```

The action menu is context-sensitive. In exploration, you can Use, Equip, Give, Drop, or Info. In battle, Give is disabled. Items with `can_be_dropped = false` (like plot-critical key items) won't show the Drop option.

```gdscript
# From ItemData
@export var can_be_dropped: bool = true
@export var confirm_on_drop: bool = false
```

That `confirm_on_drop` flag? For when you want players to really think before tossing something. "Are you SURE you want to drop the Mithril? You cannot get another one." Classic.

---

## THE MODAL INPUT BLOCKING SAGA

I need to talk about this because it's the kind of invisible work that makes or breaks a game feel.

The problem: Godot's `_unhandled_input()` only blocks events that flow through the input event system. But the HeroController uses `Input.is_action_pressed()` for movement - direct polling that bypasses the event system entirely. Result? You could walk around WHILE the shop menu was open.

The solution required a documented pattern in the platform spec:

```gdscript
## In HeroController:
if _is_modal_ui_active():
    return

func _is_modal_ui_active() -> bool:
    if ShopManager and ShopManager.is_shop_open():
        return true
    if DialogManager and DialogManager.is_dialog_active():
        return true
    if DebugConsole and DebugConsole.is_open:
        return true
    # ... etc
```

Any system that polls input state directly must check for active modal UIs. It's defensive programming, but necessary. The fix touched hero movement, the debug console itself, the caravan controller, and the map template - everywhere that polls input.

This is the kind of thing that seems obvious in hindsight but can cause hours of "why is my character moving during dialog??" debugging if you don't establish the pattern early.

---

## EDITOR IMPROVEMENTS: The Unsung Heroes

Lost in the flashy shop system is a significant batch of editor enhancements:

- **base_resource_editor.gd** got shared functionality extracted
- **item_editor.gd** has better property handling
- **party_editor.gd** and **party_template_editor.gd** refactored for consistency
- **shop_editor.gd** - 964 lines of Shop Editor goodness

Modders can now create and configure shops entirely within the Sparkling Editor. Inventory management, pricing multipliers, flag conditions, church service costs - all editable through a proper UI rather than hand-editing .tres files.

---

## NEW AGENT: BURT MACKLIN, TRIBBLE HUNTER

I couldn't end without mentioning the new agent definition: `burt-macklin-tribble-hunter.md`. Preventative debugging. Finding problems before they become problems.

If that's not the most Star Trek approach to development tooling, I don't know what is. (For those who don't get the reference: Tribbles are the cute, rapidly-multiplying fuzzy creatures that caused chaos on the Enterprise. Bugs, in other words.)

---

## THE VERDICT

**Enthusiastic thumbs up with minor caveats.**

### What Absolutely Nails It:
- Shop system captures the SF2 experience perfectly
- "Who equips this?" flow is exactly right
- Debug console is a massive productivity multiplier
- Modal input blocking establishes critical patterns
- Item action menu sets foundation for complete item management

### What Still Needs Work:
- Some shop screens are still marked with TODO comments
- `battle.spawn` is stubbed
- Level-setting is stubbed ("Would set hero level to X")
- Church services have TODO notes for health system integration

### Minor Nitpicks:
- 1000+ line files (debug_console.gd, shop_editor.gd) could potentially be split
- Shop screen paths are hardcoded rather than using the registry pattern

### What I'm Excited About Next:
- Phase 2 of Item Management (Give/Drop flows)
- Church services fully connected to health/death systems
- Crafter integration for Mithril forging

---

This weekend was a inflection point. The engine went from "has tactical battles and exploration" to "has the complete RPG economic loop." You can buy stuff. You can sell stuff. You can test stuff without playing through the whole game. You can manage your inventory.

We're not building an engine anymore. We're building a *platform*.

The Shining Force we deserve is getting closer. And the shop system? It would make Creed proud. (The dwarf blacksmith, not the band. Please don't associate Creed the band with Shining Force. That would be wrong.)

*Live long and keep shopping,*

**Justin**
Communications Bay 7, USS Torvalds

---

*Next time: Item management Phase 2, or "The Great Giving." Will Give flow preserve the classic "select character, select item slot" pattern? Will Drop confirmations prevent accidental Mithril loss? Will I stop making Star Trek references? (No.)*
