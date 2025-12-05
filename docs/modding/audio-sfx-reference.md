# Sound Effects Reference for Modders

This document lists all sound effect names expected by The Sparkling Farce engine. To add sounds to your mod, place audio files in `mods/{your_mod}/audio/sfx/` with the filenames listed below.

## Supported Formats

- `.ogg` (recommended - best compression/quality balance)
- `.wav` (uncompressed, larger files)
- `.mp3` (supported but not recommended for short SFX)

## Directory Structure

```
mods/{your_mod}/
  audio/
    sfx/
      menu_select.ogg
      cursor_move.ogg
      attack_hit.ogg
      ...
    music/
      battle_theme.ogg
      ...
```

---

## UI Sound Effects

These play during menu navigation and interface interactions.

| Filename | Context | Description |
|----------|---------|-------------|
| `menu_hover` | Focus/hover on pre-game menus | Item hovered or navigated to (main menu, save selector) |
| `menu_select` | Button pressed | Main confirmation sound for menu selections |
| `menu_confirm` | Action confirmed | Confirming an action in battle menus |
| `menu_cancel` | Back/cancel pressed | Backing out of menus, canceling actions |
| `menu_error` | Invalid action | Attempting unavailable actions (grayed out options) |
| `cursor_move` | Navigation | Moving between menu options or grid tiles |
| `cursor_hover` | Mouse hover | Mouse entering a selectable element (battle menus) |
| `ui_select` | Generic select | Stat reveals, option highlighting |
| `ui_confirm` | Generic confirm | Dismissing popups, acknowledging messages |

---

## Combat Sound Effects

These play during battle animations and combat resolution.

| Filename | Context | Description |
|----------|---------|-------------|
| `attack_hit` | Normal hit | Standard attack connecting with target |
| `attack_critical` | Critical hit | Critical/powerful hit landing |
| `attack_miss` | Attack missed | Attack failing to connect |
| `heal` | HP restored | Healing spell or item used |

---

## Progression Sound Effects

These play during character advancement moments.

| Filename | Context | Description |
|----------|---------|-------------|
| `level_up` | Level gained | Character leveling up during/after battle |
| `xp_gain` | XP awarded | Experience points being added (per tick) |
| `ability_learned` | New ability | Character learning a new spell/skill |
| `promotion_fanfare` | Class change | Character being promoted to advanced class |

---

## Movement Sound Effects

These play during unit movement on the tactical grid.

| Filename | Context | Description |
|----------|---------|-------------|
| `cursor_move` | Cursor moved | Moving the selection cursor on battle map |
| `movement_blocked` | Path blocked | Attempting to move to an invalid tile |

---

## Music Tracks

Music files go in `audio/music/` and are referenced by name without extension.

| Filename | Context | Description |
|----------|---------|-------------|
| `victory_fanfare` | Battle won | Plays on the victory screen |

---

## Implementation Notes

### How Audio Loading Works

1. AudioManager looks for files at: `{mod_path}/audio/sfx/{name}.{ext}`
2. Extensions are tried in order: `.ogg`, `.wav`, `.mp3`
3. First matching file wins
4. Missing files fail silently (no crash, just no sound)

### Category System

Sound effects have categories for potential future volume control:

```gdscript
enum SFXCategory {
    UI,        # Menu navigation, cursor movement
    COMBAT,    # Attacks, damage, critical hits
    SYSTEM,    # Turn changes, victory/defeat
    MOVEMENT,  # Unit movement
    CEREMONY,  # Promotion ceremonies, special events
}
```

Currently all categories play at the same volume, but this allows future per-category volume sliders.

### Playing Custom Sounds

If your mod adds new sound effects not in this list, you can play them from custom trigger scripts:

```gdscript
AudioManager.play_sfx("my_custom_sound", AudioManager.SFXCategory.UI)
```

---

## Quick Start Checklist

1. Create `mods/{your_mod}/audio/sfx/` directory
2. Add `.ogg` files named exactly as shown above
3. Godot will auto-import them (creates `.import` files)
4. Test in-game - sounds should play automatically

## Recommended Sound Characteristics

| Type | Duration | Style |
|------|----------|-------|
| Menu clicks | 50-150ms | Short, snappy |
| Cursor moves | 30-100ms | Subtle tick/blip |
| Attack hits | 200-500ms | Impactful, punchy |
| Level up | 1-2 seconds | Triumphant jingle |
| Fanfares | 3-5 seconds | Celebratory melody |
