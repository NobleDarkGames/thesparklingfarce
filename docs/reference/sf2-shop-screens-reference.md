# SF2 Shop Screen Reference

**Purpose:** Visual reference for authentic SF2 shop UI recreation
**Date:** 2025-12-06
**Author:** Mr. Nerdlinger

---

## Screen 1: Shop Menu (Initial)

```
┌────────────────────────────────────────┐
│                                        │
│     "Welcome to the weapon shop!"      │
│                                        │
│            ┌─────────┐                 │
│            │  BUY    │ ←              │
│            │  SELL   │                 │
│            │  DEALS  │                 │
│            │  EXIT   │                 │
│            └─────────┘                 │
│                                        │
│                                        │
│                                        │
└────────────────────────────────────────┘
```

**SF2 Details:**
- Menu is CENTER-ALIGNED on screen
- Text is white on dark blue background
- Cursor is a small sword icon (or arrow) pointing at selection
- Options appear AFTER the greeting text (2-line delay)
- "DEALS" option only appears in shops that have deals
- Font is SF2's distinctive all-caps pixel font

---

## Screen 2: Buy Menu (Item List)

```
┌────────────────────────────────────────┐
│  WEAPON SHOP - BUY                     │
├────────────────────────────────────────┤
│  ► BRONZE SWORD         200G           │
│    BRONZE LANCE         180G           │
│    MIDDLE SWORD         400G           │
│    STEEL SWORD          480G           │
│    POWER SPEAR          600G           │
│    GREAT AXE            750G           │
│    WOODEN ARROW          30G           │
│                                        │
├────────────────────────────────────────┤
│  AT  5      RG  1                      │
│  YOUR GOLD: 1520G                      │
│                                        │
│  CAN EQUIP:                            │
│  [MAX] [SARAH] [LUKE]                  │
│         (character portraits)          │
└────────────────────────────────────────┘
```

**SF2 Details:**

**Item List Section:**
- Items are LEFT-ALIGNED
- Price is RIGHT-ALIGNED on same line
- Cursor (►) appears to left of item name
- List scrolls if more than 7-8 items
- Sold-out items don't appear (SF2 has infinite stock anyway)

**Info Panel (Bottom):**
- Shows selected item's stats
  - "AT" = Attack power
  - "RG" = Range (1 = melee, 2+ = ranged)
  - "DF" = Defense (for armor)
  - For consumables: "Restores 20 HP" etc.
- "YOUR GOLD" always visible
- Gold turns RED if you can't afford selected item

**Can Equip Indicators:**
- Small character portraits (~16x16 pixels)
- ONLY shows characters who can equip (auto-filtered)
- If everyone can equip (rings): Shows "ALL" or many portraits
- If no one can equip: Shows nothing (but shop shouldn't sell it then)

**Color Coding:**
- White text = normal
- Yellow text = selected item name
- Red text = can't afford
- Gray text = (not used in SF2 shops, everything shown is available)

---

## Screen 3: Buy Confirmation

```
┌────────────────────────────────────────┐
│                                        │
│                                        │
│         BUY BRONZE SWORD?              │
│                                        │
│            ┌─────────┐                 │
│            │  YES    │ ←              │
│            │  NO     │                 │
│            └─────────┘                 │
│                                        │
│                                        │
│                                        │
└────────────────────────────────────────┘
```

**SF2 Details:**
- Simple modal dialog, center screen
- Item name in ALL CAPS
- Yes/No confirmation (default cursor on YES)
- Background darkens slightly (overlay effect)

---

## Screen 4: Who Equips Selection

```
┌────────────────────────────────────────┐
│                                        │
│      WHO SHOULD EQUIP IT?              │
│                                        │
│    ┌─────┐  ┌─────┐  ┌─────┐          │
│    │ MAX │  │SARAH│  │LUKE │          │
│    │ ★   │  │     │  │     │          │
│    └─────┘  └─────┘  └─────┘          │
│       ▲                                │
│                                        │
│    ┌──────────────┐                    │
│    │STORE IN      │                    │
│    │CARAVAN       │                    │
│    └──────────────┘                    │
│                                        │
└────────────────────────────────────────┘
```

**SF2 Details:**

**Character Selection:**
- Shows character NAME above portrait
- Portrait is larger (~32x32 pixels)
- Star (★) or highlight indicates cursor position
- ONLY characters who can equip are shown
- For consumables, ALL characters appear (anyone can hold an herb)

**Caravan Option:**
- Always appears at bottom
- Same size box as character options
- Says "STORE IN CARAVAN" or just "CARAVAN"

**Layout:**
- Characters arranged in horizontal row
- Wraps to second row if more than ~4-5 characters
- Cursor can move left/right/down to Caravan option

**What Happens When Full Inventory:**
- If selected character's inventory is full:
  - Screen shows "NO ROOM" message
  - Returns to this selection screen
  - Can choose different character or Caravan
  - Purchase is NOT completed, gold NOT deducted

---

## Screen 5: Sell Menu (Character Selection)

```
┌────────────────────────────────────────┐
│  WEAPON SHOP - SELL                    │
├────────────────────────────────────────┤
│                                        │
│      WHO HAS WHAT TO SELL?             │
│                                        │
│    ┌─────┐  ┌─────┐  ┌─────┐          │
│    │ MAX │  │SARAH│  │LUKE │          │
│    │     │  │     │  │     │          │
│    └─────┘  └─────┘  └─────┘          │
│       ▲                                │
│                                        │
│    ┌─────┐  ┌─────┐  ┌─────┐          │
│    │ KEN │  │ HANS│  │ TAO │          │
│    │     │  │     │  │     │          │
│    └─────┘  └─────┘  └─────┘          │
│                                        │
└────────────────────────────────────────┘
```

**SF2 Details:**
- Shows ALL party members (not filtered by equipment)
- Same portrait layout as buy selection
- After selecting character, moves to next screen

---

## Screen 6: Sell Menu (Item List)

```
┌────────────────────────────────────────┐
│  MAX - SELL                            │
├────────────────────────────────────────┤
│  ► [E] BRONZE SWORD      100G          │
│        HEALING SEED       10G          │
│        MEDICAL HERB       20G          │
│        POWER RING        500G          │
│        (empty)                         │
│        (empty)                         │
│                                        │
├────────────────────────────────────────┤
│  AT  5      RG  1                      │
│  SELL FOR: 100G                        │
│                                        │
└────────────────────────────────────────┘
```

**SF2 Details:**

**Item List:**
- Shows ALL items in character's possession (equipped + inventory)
- `[E]` prefix indicates EQUIPPED item
- Empty slots shown as "(empty)" or grayed out
- Sell price is RIGHT-ALIGNED (always 50% of buy price)

**Info Panel:**
- Shows selected item's stats (same format as buy menu)
- "SELL FOR: ###G" instead of "YOUR GOLD"
- Gold amount is how much you'll GET for selling

**Equipped Item Handling:**
- Can sell equipped items (no protection)
- When sold, item is auto-unequipped first, then sold
- No special warning (this is a pain point - see main plan)

---

## Screen 7: Sell Confirmation

```
┌────────────────────────────────────────┐
│                                        │
│                                        │
│       SELL BRONZE SWORD                │
│       FOR 100G?                        │
│                                        │
│            ┌─────────┐                 │
│            │  YES    │ ←              │
│            │  NO     │                 │
│            └─────────┘                 │
│                                        │
│                                        │
└────────────────────────────────────────┘
```

**SF2 Details:**
- Same layout as buy confirmation
- Shows sell price explicitly
- NO special confirmation for expensive items (design flaw)

---

## Screen 8: Deals Menu

```
┌────────────────────────────────────────┐
│  WEAPON SHOP - DEALS                   │
├────────────────────────────────────────┤
│  ► POWER SPEAR          450G  (600G)   │
│    GREAT SWORD          600G  (800G)   │
│    MIDDLE SWORD         300G  (400G)   │
│                                        │
│                                        │
├────────────────────────────────────────┤
│  AT 12      RG  1      DF +2           │
│  YOUR GOLD: 1520G                      │
│                                        │
│  CAN EQUIP:                            │
│  [MAX] [SARAH] [LUKE]                  │
│         (character portraits)          │
└────────────────────────────────────────┘
```

**SF2 Details:**
- Same layout as BUY menu
- Discounted price shown first (bold or yellow)
- Original price shown in parentheses (grayed or smaller font)
- Discount is typically 25% off
- After selecting item, flow is identical to buy menu (who equips, etc.)

**Discount Indication:**
- Some shops show sale price in YELLOW to indicate deal
- Original price is WHITE or GRAY
- No special "SALE!" banner or icon (minimalist design)

---

## Screen 9: Church Menu (Bonus)

```
┌────────────────────────────────────────┐
│                                        │
│     "May the goddess bless you."       │
│                                        │
│            ┌─────────┐                 │
│            │ HEAL    │ ←              │
│            │ REVIVE  │                 │
│            │ UNCURSE │                 │
│            │ PROMOTE │                 │
│            │ EXIT    │                 │
│            └─────────┘                 │
│                                        │
│                                        │
└────────────────────────────────────────┘
```

**SF2 Details:**
- Churches are NOT shops, but use similar UI
- Services have fixed prices:
  - Heal: Free (or very cheap, like 10G)
  - Revive: ~200G (scales with level)
  - Uncurse: ~500G (varies by item)
  - Promote: Free (but requires level 20+)
- After selecting service, shows character selection (who to apply to)
- Grayed-out options if not applicable (e.g., PROMOTE grayed if no one is level 20)

---

## UI Specifications (Pixel-Perfect Details)

### Fonts
- **Item names:** 8x8 pixel font, all caps, white
- **Prices:** Same font, yellow or white
- **Headers:** Same font, sometimes bold (double-width)
- **Dialog text:** Same font, centered alignment

### Colors (SF2 Palette)
- **Background:** Dark blue (#1a1a3e approximate)
- **Panels:** Slightly lighter blue (#2a2a5e)
- **Borders:** White or light gray, 1-2 pixels thick
- **Text (default):** White (#ffffff)
- **Text (selected):** Yellow (#ffff00)
- **Text (can't afford):** Red (#ff0000)
- **Text (disabled):** Gray (#808080)

### Spacing
- **Item list padding:** 4-6 pixels left margin
- **Line height:** 10-12 pixels between items
- **Panel padding:** 8 pixels on all sides
- **Border thickness:** 2 pixels (outer), 1 pixel (inner dividers)

### Cursor
- **Style:** Small triangle (►) or sword icon
- **Size:** 6x6 pixels
- **Position:** 2-4 pixels to left of item name
- **Animation:** Blinks every 0.5 seconds (optional)

### Layout
- **Screen resolution:** SF2 ran at 320x224 (Genesis)
- **Shop panels:** ~280x180 pixels (most of screen)
- **Info panel height:** ~60 pixels (bottom section)
- **Item list visible:** 7-8 items before scrolling

### Transitions
- **Menu open:** Instant (no fade-in animation)
- **Menu close:** Instant
- **Screen change:** Instant or very fast fade (< 0.1s)
- **Text scroll:** Medium speed, skippable with A button

---

## Sound Effects Reference

### Shop Sounds in SF2

| Action | Sound Effect | Description |
|--------|--------------|-------------|
| Open shop | Door/bell chime | Short, high-pitched |
| Cursor move | Soft tick | Same as menu cursor |
| Select item | Confirm beep | Mid-pitched, decisive |
| Purchase success | Cash register ding | Satisfying, slightly longer |
| Purchase fail | Error buzz | Low, harsh (can't afford) |
| Sell item | Coin clink | Softer than buy sound |
| Exit shop | Door close | Same as open, reversed |
| "No room" | Error buzz | Same as can't afford |

**Audio Note:** SF2 uses Genesis FM synthesis, giving sounds a distinctive "warm" quality. Modern recreation should aim for that retro feel, not realistic cash register samples.

---

## Animation Details

SF2 shops have MINIMAL animation:

**What DOES animate:**
- Cursor blink (on/off every 0.5s)
- Text scroll for dialog (character-by-character)
- Gold counter updates (when buying/selling, increments/decrements)

**What DOESN'T animate:**
- Item list (static, no hover effects)
- Character portraits (static, no idle animations)
- Panel transitions (instant, no slide-in)
- Buttons (no hover state, no press animation)

**Why This Matters:**
SF2's shops feel SNAPPY because there's no animation lag. Modern games often add smooth transitions that FEEL good but SLOW DOWN the flow. For SF-authentic feel, prioritize speed over smoothness.

---

## Comparison to Modern RPG Shops (What NOT to Do)

**Modern Shop UI Tropes to AVOID:**

❌ **Rotating 3D item models** - SF2 shows static icons or text only
❌ **Smooth scrolling lists** - SF2 snaps cursor position instantly
❌ **Hover tooltips** - SF2 shows info in fixed panel, not floating tooltips
❌ **Drag-and-drop item management** - SF2 uses menu navigation only
❌ **"Add to cart" shopping cart system** - SF2 is one item at a time (except consumables, which we're fixing)
❌ **Rich text descriptions with lore** - SF2 has terse stat descriptions
❌ **NPC animations during shopping** - Shopkeeper is static sprite
❌ **Background music change** - Same town music continues in shop
❌ **Screen transitions** - SF2 uses instant panel overlays, not scene changes

**SF2's Aesthetic: Utilitarian, Fast, Clear**

Modern games prioritize "juiciness" (animations, particles, sound layers). SF2 prioritizes SPEED and CLARITY. The player should be able to:
- See all items at a glance
- Know exactly what they can afford
- Complete a transaction in <5 seconds
- Navigate with muscle memory (cursor positions are predictable)

---

## Sparkling Farce Adaptation Notes

**What We Should Match Exactly:**
- Item list layout (name left, price right)
- "Who equips?" character selection flow
- Clean, uncluttered info panel
- Instant cursor movement, no smooth scrolling
- White-on-dark-blue color scheme (or similar contrast)

**What We Can Improve:**
- Add stat comparison arrows in info panel (not in list)
- Show "You have: X" for items you already own
- Highlight "upgrades" vs "sidegrades" vs "downgrades" with subtle color
- Add search/filter bar for shops with >10 items (toggled on/off, not always visible)

**What We Should Modernize:**
- Quantity selector for consumables (slide-in panel, not a new screen)
- "Sell from Caravan" option (same UI, different data source)
- Confirmation tiers (bigger dialog for expensive items)
- Equipped item warnings (add [E] indicator + confirmation)

**The Balance:**
> "At a glance, it should look like SF2. On close inspection, it should feel smoother and less tedious."

---

**End of Reference Document**

**Usage:** When implementing shop UI, compare screenshots/builds against these ASCII diagrams to ensure SF2 authenticity. Deviations should be deliberate improvements, not accidental divergence.
