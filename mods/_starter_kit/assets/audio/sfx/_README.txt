Sound Effects
Format: OGG or WAV (short clips work best)

Place sound effect files here. The platform looks for specific filenames.

CURRENTLY PROVIDED (starter kit defaults):
-----------------------------------------
cursor_move.ogg         - Menu cursor movement
menu_hover.ogg          - Mouse hover on menu item
menu_select.ogg         - Menu item selected
menu_cancel.ogg         - Menu cancelled/back
menu_error.ogg          - Invalid action attempted
error.ogg               - General error sound
heal.ogg                - Healing effect
walk.ogg                - Footstep sound
rumble.ogg              - Screen shake/impact

EXPECTED BY PLATFORM (need to provide):
--------------------------------------
UI Sounds:
  ui_select.ogg         - General UI selection
  ui_confirm.ogg        - Confirm action (OK/Accept)
  menu_open.ogg         - Menu opened

Ceremony/Events:
  level_up.ogg          - Character level up fanfare
  ability_learned.ogg   - New ability learned notification
  promotion_fanfare.ogg - Class promotion ceremony

Combat (referenced in code comments):
  attack_hit.ogg        - Physical attack connects
  attack_miss.ogg       - Attack misses
  critical_hit.ogg      - Critical hit lands
  spell_cast.ogg        - Magic spell cast
  item_use.ogg          - Item used in battle

CATEGORIES (for organization):
-----------------------------
AudioManager.SFXCategory.UI       - Menu navigation
AudioManager.SFXCategory.COMBAT   - Battle sounds
AudioManager.SFXCategory.SYSTEM   - Turn changes, notifications
AudioManager.SFXCategory.MOVEMENT - Unit movement
AudioManager.SFXCategory.CEREMONY - Promotions, special events

Higher priority mods can override sounds from lower priority mods.
Mods can add custom sounds referenced by cinematics and abilities.
