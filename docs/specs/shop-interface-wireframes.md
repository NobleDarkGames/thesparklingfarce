# Shop Interface Wireframes

**Companion Document to**: shop-interface-ux-specification.md
**Author**: Lt. Clauderina
**Date**: 2025-12-07

---

## Wireframe 1: BUY MODE - Initial State

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                          WEAPON SHOP OF GUARDIANA                          ┃
┃                    "Welcome! Looking for quality weapons?"                 ┃
┃                                                         GOLD: 1520G         ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                                                             ┃
┃  ┌─────────────────┐  ┌────────────────────┐  ┌─────────────────────────┐ ┃
┃  │ ITEMS           │  │                    │  │ WHO EQUIPS IT?          │ ┃
┃  ├─────────────────┤  │  BRONZE SWORD      │  ├─────────────────────────┤ ┃
┃  │ >BRONZE SWORD   │  │  AT  5      RG  1  │  │ ┌─────────┬───────────┐ │ ┃
┃  │  150G [FOCUS]   │  │                    │  │ │   MAX   │   TAO     │ │ ┃
┃  │                 │  │  BUY: 150G         │  │ │ (ready) │ (cannot)  │ │ ┃
┃  │  BRONZE SPEAR   │  │                    │  │ └─────────┴───────────┘ │ ┃
┃  │  200G           │  │                    │  │ ┌─────────┬───────────┐ │ ┃
┃  │                 │  │                    │  │ │  LUKE   │   GONG    │ │ ┃
┃  │  WOODEN STAFF   │  │                    │  │ │ (ready) │ (cannot)  │ │ ┃
┃  │  50G            │  │                    │  │ └─────────┴───────────┘ │ ┃
┃  │                 │  │                    │  │ ┌─────────┬───────────┐ │ ┃
┃  │  HEALING HERB   │  │                    │  │ │  HANS   │  LOWE     │ │ ┃
┃  │  10G            │  │                    │  │ │ (ready) │ (cannot)  │ │ ┃
┃  │                 │  │                    │  │ └─────────┴───────────┘ │ ┃
┃  │  HEALING SEED   │  │                    │  │                         │ ┃
┃  │  30G            │  │                    │  │ ┌─────────────────────┐ │ ┃
┃  │                 │  │                    │  │ │ STORE IN CARAVAN    │ │ ┃
┃  │                 │  │                    │  │ └─────────────────────┘ │ ┃
┃  └─────────────────┘  └────────────────────┘  └─────────────────────────┘ ┃
┃                                                                             ┃
┃              ┌────────┐  ┌──────┐  ┌───────┐  ┌──────┐                    ┃
┃              │  BUY   │  │ SELL │  │ DEALS │  │ EXIT │                    ┃
┃              └────────┘  └──────┘  └───────┘  └──────┘                    ┃
┃              └─active─┘                                                    ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

NOTES:
- "BRONZE SWORD" has blue border [FOCUS] - keyboard/gamepad focus
- TAO and GONG buttons greyed (can't equip swords)
- MAX, LUKE, HANS buttons white (can equip)
- BUY mode button has blue underline/highlight (active mode)
- No BUY action button visible yet (no destination selected)
```

---

## Wireframe 2: BUY MODE - Character Selected

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                          WEAPON SHOP OF GUARDIANA                          ┃
┃                    "Welcome! Looking for quality weapons?"                 ┃
┃                                                         GOLD: 1520G         ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                                                             ┃
┃  ┌─────────────────┐  ┌────────────────────┐  ┌─────────────────────────┐ ┃
┃  │ ITEMS           │  │                    │  │ WHO EQUIPS IT?          │ ┃
┃  ├─────────────────┤  │  BRONZE SWORD      │  ├─────────────────────────┤ ┃
┃  │ >BRONZE SWORD   │  │  AT  5      RG  1  │  │ ┌─────────┬───────────┐ │ ┃
┃  │  150G           │  │                    │  │ │ ░░MAX░░ │   TAO     │ │ ┃
┃  │                 │  │  BUY: 150G         │  │ │░SELECT░│ (cannot)  │ │ ┃
┃  │  BRONZE SPEAR   │  │                    │  │ └─────────┴───────────┘ │ ┃
┃  │  200G           │  │ ┌────────────────┐ │  │ ┌─────────┬───────────┐ │ ┃
┃  │                 │  │ │ MAX'S CURRENT: │ │  │ │  LUKE   │   GONG    │ │ ┃
┃  │  WOODEN STAFF   │  │ │ WOODEN SWORD   │ │  │ │ (ready) │ (cannot)  │ │ ┃
┃  │  50G            │  │ │ AT  3   RG  1  │ │  │ └─────────┴───────────┘ │ ┃
┃  │                 │  │ │                │ │  │ ┌─────────┬───────────┐ │ ┃
┃  │  HEALING HERB   │  │ │ CHANGE: AT +2  │ │  │ │  HANS   │  LOWE     │ │ ┃
┃  │  10G            │  │ │        (green) │ │  │ │ (ready) │ (cannot)  │ │ ┃
┃  │                 │  │ └────────────────┘ │  │ └─────────┴───────────┘ │ ┃
┃  │  HEALING SEED   │  │                    │  │                         │ ┃
┃  │  30G            │  │                    │  │ ┌─────────────────────┐ │ ┃
┃  │                 │  │                    │  │ │ STORE IN CARAVAN    │ │ ┃
┃  │                 │  │                    │  │ └─────────────────────┘ │ ┃
┃  └─────────────────┘  └────────────────────┘  └─────────────────────────┘ ┃
┃                                                                             ┃
┃   ┌─────────────┐    ┌────────┐  ┌──────┐  ┌───────┐  ┌──────┐           ┃
┃   │BUY FOR 150G │    │  BUY   │  │ SELL │  │ DEALS │  │ EXIT │           ┃
┃   └─────────────┘    └────────┘  └──────┘  └───────┘  └──────┘           ┃
┃   └──ENABLED────┘    └─active─┘                                           ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

NOTES:
- MAX button has blue background fill [SELECTED] - purchase destination
- BUY action button appeared at bottom-left (was hidden before)
- BUY action button shows total price "BUY FOR 150G"
- Stat comparison panel appeared showing current vs new weapon
- "AT +2" in green text (positive change)
- User can now click "BUY FOR 150G" OR press Enter to execute purchase
```

---

## Wireframe 3: BUY MODE - Consumable with Quantity

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                          ITEM SHOP OF ALTERONE                             ┃
┃                      "Herbs and seeds for your journey!"                   ┃
┃                                                         GOLD: 1520G         ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                                                             ┃
┃  ┌─────────────────┐  ┌────────────────────┐  ┌─────────────────────────┐ ┃
┃  │ ITEMS           │  │                    │  │ WHO RECEIVES IT?        │ ┃
┃  ├─────────────────┤  │  HEALING HERB      │  ├─────────────────────────┤ ┃
┃  │  MEDICAL HERB   │  │                    │  │ ┌─────────┬───────────┐ │ ┃
┃  │  10G            │  │  Restores 20 HP    │  │ │   MAX   │   TAO     │ │ ┃
┃  │                 │  │                    │  │ │ (ready) │ (ready)   │ │ ┃
┃  │ >HEALING HERB   │  │  BUY: 10G          │  │ └─────────┴───────────┘ │ ┃
┃  │  10G [FOCUS]    │  │                    │  │ ┌─────────┬───────────┐ │ ┃
┃  │                 │  │ ┌────────────────┐ │  │ │  LUKE   │   GONG    │ │ ┃
┃  │  HEALING SEED   │  │ │ QUANTITY: [5▲▼]│ │  │ │░SELECT░│ (ready)   │ │ ┃
┃  │  30G            │  │ └────────────────┘ │  │ └─────────┴───────────┘ │ ┃
┃  │                 │  │                    │  │ ┌─────────┬───────────┐ │ ┃
┃  │  ANGEL WING     │  │  TOTAL: 50G        │  │ │  HANS   │  LOWE     │ │ ┃
┃  │  70G            │  │                    │  │ │ (ready) │ (ready)   │ │ ┃
┃  │                 │  │                    │  │ └─────────┴───────────┘ │ ┃
┃  │  ANTIDOTE       │  │                    │  │                         │ ┃
┃  │  20G            │  │                    │  │ ┌─────────────────────┐ │ ┃
┃  │                 │  │                    │  │ │ STORE IN CARAVAN    │ │ ┃
┃  │                 │  │                    │  │ └─────────────────────┘ │ ┃
┃  └─────────────────┘  └────────────────────┘  └─────────────────────────┘ ┃
┃                                                                             ┃
┃   ┌──────────────┐    ┌────────┐  ┌──────┐  ┌───────┐  ┌──────┐          ┃
┃   │ BUY FOR 50G  │    │  BUY   │  │ SELL │  │ DEALS │  │ EXIT │          ┃
┃   └──────────────┘    └────────┘  └──────┘  └───────┘  └──────┘          ┃
┃   └───ENABLED────┘    └─active─┘                                          ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

NOTES:
- Quantity selector appeared (only for consumables)
- SpinBox shows "5" - user adjusted from default 1
- "TOTAL: 50G" shows in details panel (5 × 10G)
- BUY action button shows total "BUY FOR 50G"
- LUKE selected as destination (blue background)
- All characters enabled (consumables can go to anyone)
- Purchase will add 5 herbs to Luke's inventory
```

---

## Wireframe 4: SELL MODE - Step 1 (Select Character)

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                          WEAPON SHOP OF GUARDIANA                          ┃
┃                    "Welcome! Looking for quality weapons?"                 ┃
┃                                                         GOLD: 1520G         ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                                                             ┃
┃  ┌─────────────────┐  ┌────────────────────┐  ┌─────────────────────────┐ ┃
┃  │ ITEMS           │  │                    │  │ WHOSE INVENTORY?        │ ┃
┃  ├─────────────────┤  │                    │  ├─────────────────────────┤ ┃
┃  │                 │  │                    │  │ ┌─────────┬───────────┐ │ ┃
┃  │                 │  │                    │  │ │   MAX   │   TAO     │ │ ┃
┃  │                 │  │                    │  │ │         │ [FOCUS]   │ │ ┃
┃  │                 │  │                    │  │ └─────────┴───────────┘ │ ┃
┃  │                 │  │                    │  │ ┌─────────┬───────────┐ │ ┃
┃  │                 │  │                    │  │ │  LUKE   │   GONG    │ │ ┃
┃  │  ← SELECT       │  │                    │  │ │         │           │ │ ┃
┃  │    CHARACTER    │  │                    │  │ └─────────┴───────────┘ │ ┃
┃  │                 │  │                    │  │ ┌─────────┬───────────┐ │ ┃
┃  │                 │  │                    │  │ │  HANS   │  LOWE     │ │ ┃
┃  │                 │  │                    │  │ │         │           │ │ ┃
┃  │                 │  │                    │  │ └─────────┴───────────┘ │ ┃
┃  │                 │  │                    │  │                         │ ┃
┃  │                 │  │                    │  │ ┌─────────────────────┐ │ ┃
┃  │                 │  │                    │  │ │ (Caravan hidden in  │ │ ┃
┃  │                 │  │                    │  │ │  sell mode)         │ │ ┃
┃  └─────────────────┘  └────────────────────┘  └─────────────────────────┘ ┃
┃                                                                             ┃
┃                       ┌────────┐  ┌──────┐  ┌───────┐  ┌──────┐           ┃
┃                       │  BUY   │  │ SELL │  │ DEALS │  │ EXIT │           ┃
┃                       └────────┘  └──────┘  └───────┘  └──────┘           ┃
┃                                   └active─┘                                ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

NOTES:
- User clicked SELL button to enter sell mode
- SELL mode button now has active highlight
- Item list empty with instruction "← SELECT CHARACTER"
- Right column header changed to "WHOSE INVENTORY?"
- TAO has keyboard focus (blue border)
- Caravan button hidden (can't sell from Caravan storage)
- BUY action button hidden (not in buy mode)
- Details panel empty (no item selected yet)
```

---

## Wireframe 5: SELL MODE - Step 2 (Select Item)

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                          WEAPON SHOP OF GUARDIANA                          ┃
┃                    "Welcome! Looking for quality weapons?"                 ┃
┃                                                         GOLD: 1520G         ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                                                             ┃
┃  ┌─────────────────┐  ┌────────────────────┐  ┌─────────────────────────┐ ┃
┃  │ TAO'S INVENTORY │  │                    │  │ TAO'S INVENTORY         │ ┃
┃  ├─────────────────┤  │  WOODEN ROD        │  ├─────────────────────────┤ ┃
┃  │ >WOODEN ROD     │  │  AT  3      RG  2  │  │                         │ ┃
┃  │  [EQUIPPED]     │  │                    │  │  (Character panel       │ ┃
┃  │  sell: 15G      │  │  SELL FOR: 15G     │  │   hidden after          │ ┃
┃  │  [FOCUS]        │  │                    │  │   selection)            │ ┃
┃  │                 │  │                    │  │                         │ ┃
┃  │  HEALING HERB   │  │                    │  │                         │ ┃
┃  │  sell: 7G       │  │                    │  │                         │ ┃
┃  │                 │  │                    │  │                         │ ┃
┃  │  HEALING HERB   │  │                    │  │                         │ ┃
┃  │  sell: 7G       │  │                    │  │                         │ ┃
┃  │                 │  │                    │  │                         │ ┃
┃  │  HEALING SEED   │  │                    │  │                         │ ┃
┃  │  sell: 22G      │  │                    │  │                         │ ┃
┃  │                 │  │                    │  │                         │ ┃
┃  │                 │  │                    │  │                         │ ┃
┃  │                 │  │                    │  │                         │ ┃
┃  └─────────────────┘  └────────────────────┘  └─────────────────────────┘ ┃
┃                                                                             ┃
┃   ┌──────────────┐    ┌────────┐  ┌──────┐  ┌───────┐  ┌──────┐          ┃
┃   │ SELL FOR 15G │    │  BUY   │  │ SELL │  │ DEALS │  │ EXIT │          ┃
┃   └──────────────┘    └────────┘  └──────┘  └───────┘  └──────┘          ┃
┃   └───ENABLED────┘                └active─┘                                ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

NOTES:
- User selected TAO in previous step
- Left column now shows "TAO'S INVENTORY"
- Right column header also shows "TAO'S INVENTORY"
- Character grid HIDDEN (no longer needed)
- Item list populated with TAO's sellable items
- WOODEN ROD selected (has focus)
- [EQUIPPED] indicator shows it's currently equipped
- Sell prices shown (75% of buy price)
- SELL action button appeared at bottom-left
- SELL action button shows "SELL FOR 15G"
- Details panel shows item stats and sell price
```

---

## Wireframe 6: DEALS MODE

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                          WEAPON SHOP OF GUARDIANA                          ┃
┃                 "Special deals for valued customers today!"                ┃
┃                                                         GOLD: 1520G         ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                                                             ┃
┃  ┌─────────────────┐  ┌────────────────────┐  ┌─────────────────────────┐ ┃
┃  │ SPECIAL DEALS!  │  │                    │  │ WHO EQUIPS IT?          │ ┃
┃  ├─────────────────┤  │  BRONZE SWORD      │  ├─────────────────────────┤ ┃
┃  │ >BRONZE SWORD   │  │  AT  5      RG  1  │  │ ┌─────────┬───────────┐ │ ┃
┃  │  [s]200G[/s]    │  │                    │  │ │   MAX   │   TAO     │ │ ┃
┃  │  150G [FOCUS]   │  │  BUY: 150G         │  │ │ (ready) │ (cannot)  │ │ ┃
┃  │  [SAVE 50G!]    │  │  (25% OFF!)        │  │ └─────────┴───────────┘ │ ┃
┃  │                 │  │                    │  │ ┌─────────┬───────────┐ │ ┃
┃  │  STEEL SWORD    │  │                    │  │ │  LUKE   │   GONG    │ │ ┃
┃  │  [s]500G[/s]    │  │                    │  │ │ (ready) │ (cannot)  │ ┃
┃  │  400G           │  │                    │  │ └─────────┴───────────┘ │ ┃
┃  │  [SAVE 100G!]   │  │                    │  │ ┌─────────┬───────────┐ │ ┃
┃  │                 │  │                    │  │ │  HANS   │  LOWE     │ ┃
┃  │  POWER RING     │  │                    │  │ │ (ready) │ (cannot)  │ │ ┃
┃  │  [s]1000G[/s]   │  │                    │  │ └─────────┴───────────┘ │ ┃
┃  │  800G           │  │                    │  │                         │ ┃
┃  │  [SAVE 200G!]   │  │                    │  │ ┌─────────────────────┐ │ ┃
┃  │                 │  │                    │  │ │ STORE IN CARAVAN    │ │ ┃
┃  │                 │  │                    │  │ └─────────────────────┘ │ ┃
┃  └─────────────────┘  └────────────────────┘  └─────────────────────────┘ ┃
┃                                                                             ┃
┃                       ┌────────┐  ┌──────┐  ┌───────┐  ┌──────┐           ┃
┃                       │  BUY   │  │ SELL │  │ DEALS │  │ EXIT │           ┃
┃                       └────────┘  └──────┘  └───────┘  └──────┘           ┃
┃                                             └active──┘                     ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

NOTES:
- User clicked DEALS button to enter deals mode
- DEALS mode button now has active highlight
- Greeting text changed to mention "special deals"
- Item list shows deal items with strikethrough original prices
- "[s]200G[/s]" renders as strikethrough in RichTextLabel (or custom rendering)
- "150G" shown as actual deal price
- "[SAVE 50G!]" text in gold/yellow color for emphasis
- Details panel shows deal price: "BUY: 150G (25% OFF!)"
- Flow identical to BUY mode from here (select character → confirm)
- DEALS button has active mode indicator
```

---

## Wireframe 7: Focus Flow Diagram

```
                         KEYBOARD/GAMEPAD NAVIGATION MAP

┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│     LEFT COLUMN              CENTER COLUMN          RIGHT COLUMN            │
│                                                                             │
│   ┌──[Item 1]──┐                               ┌──[Character 1]──┐         │
│   │    ↕↔       │ ←────────→ [Quantity]  ←──→  │    ↕↔           │         │
│   ├──[Item 2]──┤            (if consumable)    ├──[Character 2]──┤         │
│   │    ↕↔       │ ←──────────────────────────→ │    ↕↔           │         │
│   ├──[Item 3]──┤                               ├──[Character 3]──┤         │
│   │    ↕↔       │ ←──────────────────────────→ │    ↕↔           │         │
│   ├──[Item 4]──┤                               ├──[Character 4]──┤         │
│   │    ↕        │ ←──────────────────────────→ │    ↕            │         │
│   └─────────────┘                               │    ↓            │         │
│                                                 └──[Caravan]──────┘         │
│                                                       ↓                      │
│                                                       ↓                      │
│                  BOTTOM ROW (MODE/ACTION BUTTONS)    ↓                      │
│                                                      ↓                       │
│   ┌──[BUY Action]──┬──[BUY Mode]──┬──[SELL]──┬──[DEALS]──┬──[EXIT]──┐     │
│   │       ↔        │      ↔       │    ↔     │     ↔     │          │     │
│   └────────────────┴──────────────┴──────────┴───────────┴──────────┘     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

LEGEND:
  ↕    = Vertical navigation (Up/Down arrows)
  ↔    = Horizontal navigation (Left/Right arrows)
  ←──→ = Cross-section navigation between columns
  [X]  = Focusable element

KEY INTERACTIONS:
1. START: Focus begins on first item in item list
2. UP/DOWN: Navigate within same column
3. LEFT/RIGHT: Move between columns (item ↔ quantity ↔ character)
4. DOWN from last character: Move to Caravan button
5. DOWN from Caravan: Move to mode buttons
6. UP from mode buttons: Move back to Caravan
7. ENTER on character: Highlight as selection, enable BUY/SELL action button
8. ENTER on BUY/SELL action: Execute transaction
9. ESCAPE anywhere: Close shop (with confirmation?)
```

---

## Wireframe 8: Visual State Examples (Single Button)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        BUTTON VISUAL STATES                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  NORMAL (Default):                                                          │
│  ┌─────────────┐                                                            │
│  │     MAX     │  ← White text, no border, dark background                  │
│  └─────────────┘                                                            │
│                                                                             │
│  HOVER (Mouse over):                                                        │
│  ┌─────────────┐                                                            │
│  │     MAX     │  ← Gold/yellow text, no border                             │
│  └─────────────┘                                                            │
│                                                                             │
│  FOCUS (Keyboard/gamepad selection):                                        │
│  ┏━━━━━━━━━━━━━┓                                                            │
│  ┃     MAX     ┃  ← Light blue text, BLUE BORDER (2px)                      │
│  ┗━━━━━━━━━━━━━┛                                                            │
│                                                                             │
│  SELECTED (Chosen as purchase destination):                                 │
│  ┌─────────────┐                                                            │
│  │░░░░ MAX ░░░░│  ← White text, BLUE BACKGROUND FILL                        │
│  └─────────────┘                                                            │
│                                                                             │
│  DISABLED (Cannot equip / Cannot afford):                                   │
│  ┌─────────────┐                                                            │
│  │     MAX     │  ← Dark grey text, dimmed, no interaction                  │
│  └─────────────┘                                                            │
│                                                                             │
│  SELECTED + FOCUS (Rare - when navigating back to selected):               │
│  ┏━━━━━━━━━━━━━┓                                                            │
│  ┃░░░░ MAX ░░░░┃  ← White text, BLUE BG + LIGHTER BLUE BORDER               │
│  ┗━━━━━━━━━━━━━┛                                                            │
│                                                                             │
│  ACTIVE MODE (For mode selector buttons):                                  │
│  ┌─────────────┐                                                            │
│  │     BUY     │  ← White text, bottom border or highlight indicator        │
│  └─────┬───────┘                                                            │
│        └──▲── (visual indicator below button)                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

COLOR PALETTE:
- Normal text:        #FFFFFF (white)
- Hover text:         #FFE680 (gold)
- Focus text:         #80CCFF (light blue)
- Focus border:       #3D7ACC (medium blue)
- Selected bg:        #4D80CC (medium-bright blue)
- Disabled text:      #666666 (dark grey)
- Background:         #0A0A0F (very dark blue-black)
- Panel background:   #18182A (dark blue)
- Positive change:    #66FF66 (green)
- Negative change:    #FF6666 (red)
- Can't afford:       #FF4444 (bright red)
```

---

## Wireframe 9: Responsive Behavior (Window Resize)

```
MINIMUM SUPPORTED RESOLUTION: 1280x720

┌────────────────────────────────────────────┐
│  1280x720 (Minimum)                        │
│  ┌──────────────────────────────────────┐  │
│  │ Left:    140px (Items)               │  │
│  │ Center:  200px (Details)             │  │
│  │ Right:   180px (Characters)          │  │
│  │ Gaps:    6px between columns         │  │
│  │ Margins: 8px all sides               │  │
│  └──────────────────────────────────────┘  │
│                                            │
│  Characters: 2-column grid                 │
│  Buttons: 80px wide, 28px tall             │
│  Font: 16px body, 24px headers             │
└────────────────────────────────────────────┘

FULL HD: 1920x1080

┌───────────────────────────────────────────────────────┐
│  1920x1080 (Full HD)                                  │
│  ┌─────────────────────────────────────────────────┐  │
│  │ Left:    240px (Items - more space)             │  │
│  │ Center:  340px (Details - larger comparison)    │  │
│  │ Right:   300px (Characters - 3 columns?)        │  │
│  │ Gaps:    12px between columns                   │  │
│  │ Margins: 16px all sides                         │  │
│  └─────────────────────────────────────────────────┘  │
│                                                       │
│  Characters: Could upgrade to 3-column grid          │
│  Buttons: Scale up to 100px wide, 32px tall          │
│  Font: Could scale to 18px body, 28px headers        │
│  OR: Keep same sizes, add more breathing room        │
└───────────────────────────────────────────────────────┘

RECOMMENDATION:
- Use size_flags_horizontal = 3 for columns (expand and fill)
- Set custom_minimum_size on columns to enforce minimums
- Use MarginContainer theme constants for consistent spacing
- Let Godot's anchor system handle window resize gracefully
- Test on Steam Deck resolution (1280x800) and 4K (3840x2160)
```

---

## Wireframe 10: Error States and Edge Cases

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                          WEAPON SHOP OF GUARDIANA                          ┃
┃                    "Welcome! Looking for quality weapons?"                 ┃
┃                                                       GOLD: 50G (LOW!)      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃  EDGE CASE 1: CAN'T AFFORD ITEM                                            ┃
┃  ┌─────────────────┐  ┌────────────────────┐  ┌─────────────────────────┐ ┃
┃  │ ITEMS           │  │                    │  │ WHO EQUIPS IT?          │ ┃
┃  ├─────────────────┤  │  BRONZE SWORD      │  ├─────────────────────────┤ ┃
┃  │ >BRONZE SWORD   │  │  AT  5      RG  1  │  │ ┌─────────┬───────────┐ │ ┃
┃  │  150G [FOCUS]   │  │                    │  │ │ ░░MAX░░ │   TAO     │ │ ┃
┃  │                 │  │  BUY: 150G         │  │ │░SELECT░│ (cannot)  │ │ ┃
┃  │  BRONZE SPEAR   │  │  ┌──────────────┐  │  │ └─────────┴───────────┘ │ ┃
┃  │  200G           │  │  │ NOT ENOUGH   │  │  │ ┌─────────┬───────────┐ │ ┃
┃  │                 │  │  │ GOLD!        │  │  │ │  LUKE   │   GONG    │ │ ┃
┃  │  WOODEN STAFF   │  │  │ (NEED 100G   │  │  │ │ (ready) │ (cannot)  │ │ ┃
┃  │  50G            │  │  │  MORE)       │  │  │ └─────────┴───────────┘ │ ┃
┃  │                 │  │  └──────────────┘  │  │                         │ ┃
┃  │                 │  │                    │  │ ┌─────────────────────┐ │ ┃
┃  │                 │  │                    │  │ │ STORE IN CARAVAN    │ │ ┃
┃  └─────────────────┘  └────────────────────┘  └─────────────────────────┘ ┃
┃                                                                             ┃
┃   ┌─────────────┐    ┌────────┐  ┌──────┐  ┌───────┐  ┌──────┐           ┃
┃   │     BUY     │    │  BUY   │  │ SELL │  │ DEALS │  │ EXIT │           ┃
┃   └─────────────┘    └────────┘  └──────┘  └───────┘  └──────┘           ┃
┃   └───DISABLED──┘    └─active─┘                                           ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃  EDGE CASE 2: EMPTY SHOP INVENTORY                                         ┃
┃  ┌─────────────────┐  ┌────────────────────┐  ┌─────────────────────────┐ ┃
┃  │ ITEMS           │  │                    │  │                         │ ┃
┃  ├─────────────────┤  │                    │  │                         │ ┃
┃  │                 │  │   (No item         │  │  (Character panel       │ ┃
┃  │  NO ITEMS       │  │    selected)       │  │   hidden when no        │ ┃
┃  │  AVAILABLE      │  │                    │  │   items)                │ ┃
┃  │                 │  │                    │  │                         │ ┃
┃  │  (Check back    │  │                    │  │                         │ ┃
┃  │   later!)       │  │                    │  │                         │ ┃
┃  │                 │  │                    │  │                         │ ┃
┃  └─────────────────┘  └────────────────────┘  └─────────────────────────┘ ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃  EDGE CASE 3: CHARACTER INVENTORY FULL (Warning before purchase)           ┃
┃  ┌─────────────────┐  ┌────────────────────┐  ┌─────────────────────────┐ ┃
┃  │ ITEMS           │  │                    │  │ WHO EQUIPS IT?          │ ┃
┃  ├─────────────────┤  │  BRONZE SWORD      │  ├─────────────────────────┤ ┃
┃  │ >BRONZE SWORD   │  │  AT  5      RG  1  │  │ ┌─────────┬───────────┐ │ ┃
┃  │  150G           │  │                    │  │ │ ░░MAX░░ │   TAO     │ │ ┃
┃  │                 │  │  BUY: 150G         │  │ │░SELECT░│ (cannot)  │ │ ┃
┃  │                 │  │  ┌──────────────┐  │  │ │ (8/8)  │           │ │ ┃
┃  │                 │  │  │ MAX'S        │  │  │ └─────────┴───────────┘ │ ┃
┃  │                 │  │  │ INVENTORY    │  │  │                         │ ┃
┃  │                 │  │  │ IS FULL!     │  │  │ ┌─────────────────────┐ │ ┃
┃  │                 │  │  │              │  │  │ │ STORE IN CARAVAN    │ │ ┃
┃  │                 │  │  │ Equip now or │  │  │ │ (Recommended!)      │ │ ┃
┃  │                 │  │  │ store in     │  │  │ └─────────────────────┘ │ ┃
┃  │                 │  │  │ Caravan?     │  │  │                         │ ┃
┃  │                 │  │  └──────────────┘  │  │                         │ ┃
┃  └─────────────────┘  └────────────────────┘  └─────────────────────────┘ ┃
┃                                                                             ┃
┃   ┌──────────────┐    ┌────────┐  ┌──────┐  ┌───────┐  ┌──────┐          ┃
┃   │ BUY & EQUIP  │    │  BUY   │  │ SELL │  │ DEALS │  │ EXIT │          ┃
┃   └──────────────┘    └────────┘  └──────┘  └───────┘  └──────┘          ┃
┃   └───(Auto-     )    └─active─┘                                          ┃
┃       equip!                                                               ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃  EDGE CASE 4: NO ONE CAN EQUIP THIS ITEM                                   ┃
┃  ┌─────────────────┐  ┌────────────────────┐  ┌─────────────────────────┐ ┃
┃  │ ITEMS           │  │                    │  │ WHO EQUIPS IT?          │ ┃
┃  ├─────────────────┤  │  CHAOS BREAKER     │  ├─────────────────────────┤ ┃
┃  │ >CHAOS BREAKER  │  │  AT  45     RG  1  │  │ ┌─────────┬───────────┐ │ ┃
┃  │  5000G [FOCUS]  │  │  (Dark Knight Only)│  │ │   MAX   │   TAO     │ │ ┃
┃  │                 │  │                    │  │ │(cannot) │ (cannot)  │ │ ┃
┃  │                 │  │  BUY: 5000G        │  │ └─────────┴───────────┘ │ ┃
┃  │                 │  │                    │  │ ┌─────────┬───────────┐ │ ┃
┃  │                 │  │ ┌──────────────┐   │  │ │  LUKE   │   GONG    │ │ ┃
┃  │                 │  │ │ No one in    │   │  │ │(cannot) │ (cannot)  │ │ ┃
┃  │                 │  │ │ your party   │   │  │ └─────────┴───────────┘ │ ┃
┃  │                 │  │ │ can equip    │   │  │                         │ ┃
┃  │                 │  │ │ this weapon. │   │  │ ┌─────────────────────┐ │ ┃
┃  │                 │  │ │              │   │  │ │ STORE IN CARAVAN    │ ┃
┃  │                 │  │ │ Store for    │   │  │ │ (Only option)       │ │ ┃
┃  │                 │  │ │ later?       │   │  │ └─────────────────────┘ │ ┃
┃  │                 │  │ └──────────────┘   │  │                         │ ┃
┃  └─────────────────┘  └────────────────────┘  └─────────────────────────┘ ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

---

## Implementation Priority: Critical Path First

Based on Captain Obvious's request for COMPREHENSIVE shop UX, implement in this order:

### Phase 1: CRITICAL FIXES (Must work before anything else)
1. PanelContainer `mouse_filter = PASS` fix → Buttons must click!
2. Separate BUY action from BUY mode button → Clear purpose
3. Character button click debugging → Solve signal mystery
4. Selection state visual → Users must see what's selected

### Phase 2: NAVIGATION (Keyboard/gamepad parity)
5. Focus mode + focus neighbors → Full keyboard support
6. ScrollContainer keyboard handling → Can navigate long lists
7. Global input for cancel → Escape closes shop
8. Test complete flow with gamepad → Xbox controller test

### Phase 3: MODE IMPROVEMENTS (Make sell work, polish deals)
9. Sell mode two-step flow → Character selection → Item list
10. Active mode visual indicator → Users know current mode
11. Deals mode strikethrough → Visual pricing clarity

### Phase 4: QUALITY OF LIFE (Polish the experience)
12. Stat comparison panel → Equipment decisions easier
13. Quantity selector focus → Bulk buying smoother
14. Edge case handling → Empty shops, no gold, full inventory
15. Visual polish → Colors, spacing, alignment perfect

---

**End of Wireframes Document**

*These wireframes are ASCII approximations. Actual implementation will use Godot's UI nodes with the Monogram font and proper pixel-perfect rendering.*

— Lt. Clauderina, USS Torvalds
