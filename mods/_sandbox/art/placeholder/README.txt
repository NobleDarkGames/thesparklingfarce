PLACEHOLDER ART ASSETS
======================

These are intentionally garish placeholder graphics for development/testing.
They are designed to be OBVIOUSLY temporary so no one mistakes them for final art.

ASSET MANIFEST
==============

sprites/ (32x32) - Tactical Battle Map Sprites
----------------------------------------------
Used for character/unit representation on the tactical grid.

  PLAYER UNITS (Blue tones):
  - hero.png      (#1E90FF) - Main protagonist
  - warrior.png   (#4169E1) - Melee fighter
  - mage.png      (#9370DB) - Magic user
  - archer.png    (#228B22) - Ranged attacker
  - healer.png    (#87CEEB) - Support/healing
  - knight.png    (#4682B4) - Heavy armor

  ENEMY UNITS (Red tones):
  - goblin.png    (#DC143C) - Basic enemy
  - orc.png       (#8B0000) - Strong enemy
  - skeleton.png  (#708090) - Undead enemy
  - dark_mage.png (#4B0082) - Enemy caster
  - boss.png      (#FF1493) - Boss encounter

  NEUTRAL:
  - npc.png       (#32CD32) - Non-combatant


portraits/ (64x64) - Character Portraits
----------------------------------------
Used in dialog boxes, menus, and character info screens.
Same color scheme as sprites, larger size for readability.


items/ (16x16) - Item Icons
---------------------------
Used in inventory, shops, and equipment screens.

  WEAPONS (Orange/brown):
  - sword.png     (#FF8C00) - Standard sword
  - axe.png       (#CD853F) - Battle axe
  - spear.png     (#DEB887) - Polearm
  - bow.png       (#8B4513) - Ranged weapon
  - staff.png     (#9932CC) - Magic staff

  ARMOR (Gray/silver):
  - shield.png    (#C0C0C0) - Defensive gear
  - helmet.png    (#A9A9A9) - Head armor
  - armor.png     (#778899) - Body armor

  CONSUMABLES:
  - potion.png    (#FF69B4) - HP restore
  - herb.png      (#90EE90) - Basic healing
  - antidote.png  (#00CED1) - Status cure

  ACCESSORIES:
  - ring.png      (#FFD700) - Stat boost ring
  - amulet.png    (#E6E6FA) - Magic accessory

  KEY ITEMS:
  - key_item.png  (#FFE4B5) - Quest items


combat/ (64x64) - Combat Animation Sprites
------------------------------------------
Used in the close-up combat animation screen.
These are scaled 3x (to 192x192) during combat display.
Same color scheme as sprites, with "COMBAT" label.


REPLACEMENT GUIDE
=================

When your artist creates real assets:

1. Create replacement PNGs with the SAME FILENAMES
2. Place them in a mod with higher priority than _sandbox
3. Or directly replace these files during development

The garish colors and text labels ensure you'll immediately
notice if any placeholder art accidentally ships.


COLOR REFERENCE
===============

Player units:   Blue spectrum (#1E90FF to #87CEEB)
Enemy units:    Red spectrum (#DC143C to #8B0000)
Boss units:     Hot pink (#FF1493)
Neutral units:  Green (#32CD32)
Weapons:        Orange/brown (#FF8C00 to #8B4513)
Armor:          Gray/silver (#778899 to #C0C0C0)
Consumables:    Pink/green/cyan (various)
Accessories:    Gold/lavender (#FFD700, #E6E6FA)


Generated with ImageMagick 7.x
