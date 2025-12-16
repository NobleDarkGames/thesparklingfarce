# The Priest Makes House Calls: Church Services, NPC Roles, and the Death of Redundancy

**Stardate 2025.348** | By Justin, Tactical RPG Correspondent, USS Torvalds

---

*"Mr. Data, explain to me why the church healer still requires four separate resource files to say 'Welcome, weary traveler.'"*

*"I cannot explain it, Captain. It is... highly illogical."*

*"Make it so that it isn't."*

---

Fellow Shining Force veterans, today's commits brought us something special: the church is finally open for business, death actually means something (temporarily), and modders can now create shop NPCs without wanting to throw their keyboards into the warp core.

Let me break down what landed in the transporter room today.

---

## THE BIG PICTURE: FOUR COMMITS, ONE VISION

Today's work hit four major areas:

1. **Church Services Implementation** - Heal, Revive, and Uncurse are fully functional
2. **NPC Role System** - Creating a shopkeeper went from 4 resources to 1
3. **Death Persistence** - Your fallen units stay fallen until the priest fixes them
4. **Nomenclature Cleanup** - "Granseal" is out, "basegame" is in

Let's dive in.

---

## CHURCH SERVICES: THE TRILOGY IS COMPLETE

For those who remember limping back to Granseal's church after a brutal battle with half your party greyed out in the formation screen, this one's for you.

### The Classic Three Services

The `ShopManager` now has three dedicated church methods:

```gdscript
## Heal a character at a church
func church_heal(character_uid: String) -> Dictionary:
    # Restore HP and MP to max
    save_data.current_hp = save_data.max_hp
    save_data.current_mp = save_data.max_mp

## Revive a fallen character at a church
func church_revive(character_uid: String) -> Dictionary:
    save_data.is_alive = true
    var hp_percent: int = SettingsManager.get_church_revival_hp_percent()
    if hp_percent <= 0:
        save_data.current_hp = 1  # SF2-authentic: revive with 1 HP
    else:
        save_data.current_hp = maxi(1, save_data.max_hp * hp_percent / 100)

## Uncurse an item at a church
func church_uncurse(character_uid: String, slot_id: String) -> Dictionary:
    var uncurse_result: Dictionary = EquipmentManager.attempt_uncurse(save_data, slot_id, "church")
```

### The SF2-Authentic Toggle

Here's where the team showed they understand their audience. Revival has a configurable HP percentage:

```gdscript
"church_revival_hp_percent": 0,  # 0 = 1 HP (SF2-authentic), 1-100 = percentage of max HP
```

Set it to 0, and your freshly revived Kazin stands up with exactly 1 HP, just like the good old days. Want a more forgiving experience? Set it to 50 and they come back at half health.

This is EXACTLY how you handle purist vs. casual preferences. Don't make one group unhappy - give them a toggle. Chef's kiss.

### The UI Flow

The new church screens follow the same pattern as SF2:

1. **Church Action Select** - "Heal / Revive / Uncurse / Leave"
2. **Church Character Select** - Shows only eligible characters (wounded for Heal, dead for Revive, cursed for Uncurse)
3. **Church Slot Select** - For Uncurse, picks which cursed equipment slot

The character select screen is smart about filtering:

```gdscript
func _should_show_character(save_data: CharacterSaveData) -> bool:
    match context.mode:
        ShopContextScript.Mode.HEAL:
            return save_data.is_alive and (save_data.current_hp < save_data.max_hp or save_data.current_mp < save_data.max_mp)
        ShopContextScript.Mode.REVIVE:
            return not save_data.is_alive
        ShopContextScript.Mode.UNCURSE:
            return _has_cursed_equipment(save_data)
```

No more scrolling through your entire roster to find the one dead guy. If they're not dead, they don't show up on the revive list. Simple, clean, exactly right.

**Church Services Grade: A**

---

## DEATH PERSISTENCE: CONSEQUENCES MATTER

Here's the feature that ties it all together. Previously, death in battle was... temporary in a weird way. Units died, battles ended, and then... what happened to that death state?

Now we have proper persistence:

```gdscript
## Persist unit death to CharacterSaveData (for player units only)
func _persist_unit_death(unit: Node2D) -> void:
    if not unit or unit.faction != "player":
        return

    var save_data: CharacterSaveData = PartyManager.get_member_save_data(char_uid)
    if save_data:
        save_data.is_alive = false
        print("[BattleManager] Unit '%s' died - is_alive set to false" % unit.get_display_name())
```

And after victory, surviving units get their HP/MP synced:

```gdscript
## Called after victory to persist current state
func _sync_surviving_units_to_save_data() -> void:
    for unit: Node2D in player_units:
        if not is_instance_valid(unit) or not unit.is_alive:
            continue
        # Sync HP/MP to save data
```

This creates the classic SF2 loop: Battle -> Some units die -> Victory -> Walk to church -> Pay gold -> Get them back -> Repeat.

The death matters. The church matters. The gold cost matters. It's not just "everyone's fine at the end of battle."

**Death Persistence Grade: A**

---

## NPC ROLE SYSTEM: MODDER QUALITY OF LIFE

Okay, this one is for the modders in the audience, and it's a doozy.

### The Old Way (Pain)

To create a simple shopkeeper NPC who says "Welcome!" and opens a shop, you needed:

1. **NPCData** - The NPC itself
2. **CinematicData (Greeting)** - "Welcome to my shop!"
3. **CinematicData (Interaction)** - The flow that opens the shop
4. **ShopData** - The actual shop (which also referenced the NPC back...)

Four resources. Bidirectional references. Pain.

### The New Way (Joy)

```gdscript
enum NPCRole {
    NONE,           ## Standard NPC - uses manual cinematic configuration
    SHOPKEEPER,     ## Opens a weapon or item shop
    PRIEST,         ## Opens a church (healing, revival, etc.)
    INNKEEPER,      ## Opens an inn (rest/save)
    CARAVAN_DEPOT   ## Opens the caravan storage interface
}

@export var npc_role: NPCRole = NPCRole.NONE
@export var shop_id: String = ""
@export_multiline var greeting_text: String = ""
@export_multiline var farewell_text: String = ""
```

That's it. Set `npc_role = PRIEST`, set `shop_id = "basegame_church"`, optionally customize greeting/farewell text, and you're done. ONE resource.

### The Magic: Auto-Generated Cinematics

The CinematicsManager now generates cinematics at runtime for Quick Setup NPCs:

```gdscript
## Auto-cinematic IDs have format: __auto__{npc_id}_{shop_id}
func _generate_auto_cinematic(cinematic_id: String) -> CinematicData:
    # Build the cinematic based on the NPC's role
    match npc_data.npc_role:
        NPCData.NPCRole.SHOPKEEPER, NPCData.NPCRole.PRIEST, NPCData.NPCRole.INNKEEPER:
            # Standard flow: greeting -> shop -> farewell
            cinematic.add_dialog_line(speaker_name, greeting)
            cinematic.add_open_shop(shop_id)
            cinematic.add_dialog_line(speaker_name, farewell)
```

The system even provides role-appropriate defaults:

- **Shopkeeper**: "Welcome to my shop!" / "Come again!"
- **Priest**: "Welcome, weary traveler. How may I serve you?" / "May light guide your path..."
- **Innkeeper**: "Welcome, traveler. Looking for a place to rest?" / "Rest well!"

### The Cleanup: No More Bidirectional Hell

The old system had shops pointing to NPCs AND NPCs pointing to shops. Recipe for desync bugs. Now it's unidirectional:

```gdscript
# OLD (removed)
# ShopData.npc_id -> NPCData
# NPCData.interaction_cinematic -> opens shop

# NEW
# NPCData.shop_id -> ShopData
# NPCData.npc_role -> determines behavior
```

NPC owns the relationship. Shop doesn't need to know who's selling its wares.

**NPC Role System Grade: A+**

---

## THE NAMING CLEANUP: GOODBYE GRANSEAL

This one might seem minor, but it matters for the platform philosophy.

### The Problem

The base game templates were named things like:
- `granseal_church.tres`
- `granseal_item_shop.tres`
- `granseal_weapon_shop.tres`

"Granseal" is a Shining Force location. This engine is supposed to be a platform for ANY tactical RPG, not just SF fan games.

### The Solution

Simple rename:
- `basegame_church.tres`
- `basegame_item_shop.tres`
- `basegame_weapon_shop.tres`

The content is neutral. The naming is neutral. Mods can define their own `granseal_church` or `ribble_church` or `myoriginaltown_church`. The base game templates are just templates.

This is the right call for a modding platform. Don't bake franchise-specific names into your core content.

**Naming Cleanup Grade: A**

---

## HOW THIS COMPARES TO SHINING FORCE

Let's talk about how the original games handled this stuff.

### Church Services

SF2's church was perfect. You walked in, talked to the priest, picked your service, picked your character. The UI was clean, the costs were clear, the flow was obvious.

Sparkling Farce nails this. Same flow, same clarity. The configurable revival HP is a smart addition that SF2 didn't have (you always came back at 1 HP).

### Death Persistence

SF1/SF2 tracked death at the party level. If Gort died in Battle 5, he stayed dead until you paid the priest. Sparkling Farce does the same thing, and importantly, it syncs HP/MP for survivors too.

### Shopkeeper Creation

In the original games, shops were just... there. You didn't think about how the developers set them up. But for a modding platform, ease of content creation is crucial.

Going from 4 resources to 1 resource is a 75% reduction in setup work. That's the difference between "I'll add a shop to my mod" and "ugh, I have to create four different files just for one NPC."

---

## WHAT'S STILL COOKING

A few things I noticed aren't quite there yet:

### Caravan Depot Integration

The CARAVAN_DEPOT role exists but has a warning in the code:

```gdscript
NPCData.NPCRole.CARAVAN_DEPOT:
    push_warning("CinematicsManager: CARAVAN_DEPOT auto-cinematic - caravan interface integration pending")
```

The role is defined, but the actual caravan interface opening isn't wired up. Coming soon, presumably.

### Inn Services

INNKEEPER is defined as a role, but there's no corresponding inn service implementation in ShopManager. We have heal/revive/uncurse for churches, but no rest/save for inns. Yet.

### Cost Display in Selection

The character select buttons show the cost, but I'd love to see a running gold total somewhere. "You have 1,234 gold. This will cost 200 gold. Confirm?" That's a minor UX thing though.

---

## THE JUSTIN RATING

### Church Services: 5/5 Angel Rings
Everything SF2 did, plus a configurable revival HP toggle. The filtering on character selection is smart design. No complaints.

### Death Persistence: 5/5 Dark Swords
Death matters now. The loop is complete. This is how a tactical RPG should work.

### NPC Role System: 5/5 Mithril Maces
This is what a modding platform should provide. Complex behavior from simple configuration. The 4-to-1 resource reduction is huge for modder productivity.

### Overall Day's Work: 5/5 Chaos Breakers
This was a focused, coherent set of commits that all work together. Church services needed death persistence to matter. Death persistence needed church services to resolve. NPC roles made church NPCs easy to create. The naming cleanup keeps the platform neutral.

It's not flashy - no new combat mechanics or AI behaviors - but it's the kind of infrastructure that makes everything else work. The USS Torvalds crew should be proud of this one.

---

*Next time on the Sparkling Farce Development Log: Will we see Inn services join the party? Will the Caravan Depot get its integration? Or will we finally see that Tactical AI role implemented? Stay tuned, and may light guide your path.*

---

*Justin is a civilian consultant aboard the USS Torvalds who definitely didn't spend his lunch break calculating the optimal revival gold cost per level. (It's 200 + 10*level. He checked.)*
