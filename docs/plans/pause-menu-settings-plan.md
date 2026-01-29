# Pause Menu & Settings Screen Plan

**Status**: Ready for implementation
**Created**: 2026-01-28

## Status Tracking

| Step | Description | Status |
|------|-------------|--------|
| 1 | Wire GameJuice to SettingsManager | Pending |
| 2 | Add `sf_pause` input action to project.godot | Pending |
| 3 | Create PauseMenuManager autoload | Pending |
| 4 | Create pause_menu_controller scene | Pending |
| 5 | Create main_pause_screen | Pending |
| 6 | Create settings_screen with tab system | Pending |
| 7 | Build setting widgets (slider, toggle, option) | Pending |
| 8 | Populate all 4 settings tabs | Pending |
| 9 | Wire ExplorationUIController.PAUSED state | Pending |
| 10 | Add battle context awareness | Pending |
| 11 | Block pause during cinematics | Pending |
| 12 | Add PauseMenuManager to modal input checks | Pending |

---

## Problem Statement

The SettingsManager backend is complete with full persistence to `user://settings.cfg`, but there is no UI for players to change settings. There is also no pause menu. The `ExplorationUIController` already declares a `PAUSED` state but it is not wired to anything. GameJuice has `@export` vars that are not connected to SettingsManager, meaning animation speed changes do not persist across sessions.

---

## Architecture Overview

### Pattern: ExplorationUIManager Model

The PauseMenuManager follows the same autoload-with-persistent-CanvasLayer pattern used by `ExplorationUIManager`. Key characteristics:

- Autoload singleton creates a persistent CanvasLayer added to `get_tree().root`
- CanvasLayer survives scene transitions
- Controller manages screen stack (push/pop like ShopController)
- `process_mode = PROCESS_MODE_WHEN_PAUSED` on all UI nodes
- `get_tree().paused = true` when menu opens, `false` when it closes

### File Structure

```
core/systems/
  pause_menu_manager.gd              (NEW - autoload)

scenes/ui/pause_menu/
  pause_menu_controller.gd           (NEW - extends CanvasLayer)
  pause_menu_controller.tscn         (NEW)
  screens/
    main_pause_screen.gd             (NEW)
    main_pause_screen.tscn           (NEW)
    settings_screen.gd               (NEW)
    settings_screen.tscn             (NEW)
  widgets/
    setting_slider_widget.gd         (NEW - HSlider for volumes/percentages)
    setting_toggle_widget.gd         (NEW - ON/OFF toggle)
    setting_options_widget.gd        (NEW - horizontal discrete choices)
```

---

## Pre-Implementation: GameJuice Wiring (Step 1)

GameJuice currently has `@export` vars not connected to SettingsManager. This must be fixed first so settings persist.

### SettingsManager Changes

Add to `DEFAULTS` dictionary:

```gdscript
"animation_speed": 1.0,
"combat_animation_mode": 0,  # CombatAnimationMode.FULL
"screen_shake_intensity": 1.0,
"animate_stat_bars": true,
"animate_cursor": true,
```

Add getter/setter pairs following the existing pattern.

### GameJuice Changes

```gdscript
func _ready() -> void:
    _load_from_settings()
    SettingsManager.setting_changed.connect(_on_setting_changed)

func _load_from_settings() -> void:
    animation_speed = SettingsManager.get_setting("animation_speed", 1.0)
    combat_animation_mode = SettingsManager.get_setting("combat_animation_mode", 0) as CombatAnimationMode
    screen_shake_intensity = SettingsManager.get_setting("screen_shake_intensity", 1.0)
    animate_stat_bars = SettingsManager.get_setting("animate_stat_bars", true)
    animate_cursor = SettingsManager.get_setting("animate_cursor", true)

func _on_setting_changed(key: String, value: Variant) -> void:
    match key:
        "animation_speed":
            animation_speed = value as float
        "combat_animation_mode":
            combat_animation_mode = value as CombatAnimationMode
        "screen_shake_intensity":
            screen_shake_intensity = value as float
        "animate_stat_bars":
            animate_stat_bars = value as bool
        "animate_cursor":
            animate_cursor = value as bool
```

**Files**: `core/systems/settings_manager.gd`, `core/systems/game_juice.gd`

---

## Input Action (Step 2)

Add `sf_pause` to `project.godot`:
- Key: Escape (physical_keycode 4194305)
- Gamepad: Start button (joypad button 6)

Follows existing `sf_confirm`/`sf_cancel`/`sf_inventory` naming convention.

**File**: `project.godot`

---

## PauseMenuManager Autoload (Step 3)

**File**: `core/systems/pause_menu_manager.gd`

Responsibilities:
- Listen for `sf_pause` input
- Instantiate persistent CanvasLayer controller
- Manage `get_tree().paused` state
- Block pause during cinematics, dialog, debug console, shops

```gdscript
func _can_open_pause() -> bool:
    if CinematicsManager and CinematicsManager.is_cinematic_active():
        return false
    if DialogManager and DialogManager.is_dialog_active():
        return false
    if DebugConsole and DebugConsole.is_open:
        return false
    if ShopManager and ShopManager.is_shop_open():
        return false
    return not _is_open
```

Register in `project.godot` autoload section after `SettingsManager`.

---

## Pause Menu Controller (Step 4)

**File**: `scenes/ui/pause_menu/pause_menu_controller.gd`

Follows `ShopController` pattern: CanvasLayer with screen stack, `push_screen()`/`pop_screen()` navigation.

The `.tscn` contains:
- CanvasLayer (layer 20, above all other UI)
- ColorRect `InputBlocker` (full rect, semi-transparent black, mouse_filter STOP)
- Control `ScreenContainer` (full rect)
- All nodes: `process_mode = PROCESS_MODE_WHEN_PAUSED`

When `pop_screen()` pops past root, emits `pause_closed` signal.

---

## Main Pause Screen (Step 5)

**File**: `scenes/ui/pause_menu/screens/main_pause_screen.gd`

### Menu Options

| Option | Action | Availability |
|--------|--------|-------------|
| Resume | Close pause menu | Always |
| Settings | Push settings screen | Always |
| Save | Open save slot selector | Disabled during battle |
| Load | Open save slot selector (load mode) | Always |
| Quit to Title | SFConfirmationDialog, then goto main menu | Always |

### Visual Style (matching existing menus)

```gdscript
const PANEL_BG: Color = Color(0.1, 0.1, 0.15, 0.95)
const PANEL_BORDER: Color = Color(0.5, 0.5, 0.6, 1.0)
const PANEL_BORDER_WIDTH: int = 2
const CONTENT_MARGIN: int = 8
const TEXT_NORMAL: Color = Color(0.85, 0.85, 0.85)
const TEXT_SELECTED: Color = Color(1.0, 0.95, 0.4)
const TEXT_DISABLED: Color = Color(0.4, 0.4, 0.4)
const CURSOR_CHAR: String = ">"
const FONT_SIZE: int = 16
```

### Input

- Up/Down: Navigate menu
- Confirm/sf_confirm: Select option
- Cancel/sf_cancel/sf_pause: Resume (close menu)
- Audio feedback on every interaction

### Context Awareness

```gdscript
func _is_save_enabled() -> bool:
    return not BattleManager.battle_active
```

**Critical**: `SFConfirmationDialog` instance must have `process_mode = PROCESS_MODE_WHEN_PAUSED`.

---

## Settings Screen (Step 6)

**File**: `scenes/ui/pause_menu/screens/settings_screen.gd`

### Tab Navigation

Four tabs: **Audio** | **Display** | **Gameplay** | **Accessibility**

- Tab switching: L1/R1 shoulder buttons (gamepad) or Q/E keys (keyboard)
- New input actions: `sf_tab_left`, `sf_tab_right`
- Within tab: Up/Down navigate rows, Left/Right adjust values
- Cancel/sf_cancel: Go back to main pause screen

### Audio Tab

| Label | Widget | Key | Range |
|-------|--------|-----|-------|
| Master Volume | Slider | `master_volume` | 0-100% |
| Music Volume | Slider | `music_volume` | 0-100% |
| SFX Volume | Slider | `sfx_volume` | 0-100% |

### Display Tab

| Label | Widget | Key | Values |
|-------|--------|-----|--------|
| Fullscreen | Toggle | `fullscreen` | ON / OFF |
| VSync | Toggle | `vsync` | ON / OFF |
| Window Scale | Options | `window_scale` | 1x / 2x / 3x / 4x |

### Gameplay Tab

| Label | Widget | Key | Values |
|-------|--------|-----|--------|
| Text Speed | Options | `text_speed` | Slow (0.5) / Normal (1.0) / Fast (2.0) |
| Combat Animations | Options | `combat_animation_mode` | Full / Fast / Map Only |
| Battle Animations | Toggle | `battle_animations` | ON / OFF |
| Auto-End Turn | Toggle | `auto_end_turn` | ON / OFF |
| Attack Confirmation | Toggle | `confirm_attacks` | ON / OFF |
| Church Revival HP | Slider | `church_revival_hp_percent` | 0-100% (show "1 HP" at 0%) |

### Accessibility Tab

| Label | Widget | Key | Values |
|-------|--------|-----|--------|
| Screen Shake | Toggle | `screen_shake` | ON / OFF |
| Flash Effects | Toggle | `flash_effects` | ON / OFF |
| Colorblind Mode | Options | `colorblind_mode` | None / Deut. / Prot. / Trit. |
| Font Scale | Options | `font_scale` | 75% / 100% / 125% / 150% / 200% |

### Application Strategy

Settings apply immediately via SettingsManager setter methods. Auto-save on leaving:

```gdscript
func _on_screen_exit() -> void:
    if SettingsManager.has_unsaved_changes():
        SettingsManager.save_settings()
```

No Apply/Cancel buttons. Modern UX expectation: changes are live.

---

## Setting Widgets (Step 7)

Three reusable widget types, built programmatically (no .tscn files).

### SettingSliderWidget

Visual: row of 20 colored rectangles (filled = value, empty = remaining) + percentage label. Left/right adjusts by step. Retro aesthetic (no Godot HSlider).

### SettingToggleWidget

Visual: `[ON]` or `[OFF]` text. Left/right or confirm toggles. Selected state in yellow.

### SettingOptionsWidget

Visual: `< Slow  [Normal]  Fast >`. Brackets around selected. Left/right cycles options. Gamepad-friendly.

### Common Patterns

All widgets:
- `setup(label_text, ...)` method
- `value_changed` signal
- `set_selected(bool)` for highlight state
- `adjust(direction: int)` for left/right input
- Monogram font 16px via `UIUtils.apply_monogram_style()`
- Yellow when selected, gray when not
- `cursor_move` SFX on value change, no sound at min/max

---

## Integration Points (Steps 9-12)

### ExplorationUIController PAUSED State (Step 9)

`UIState.PAUSED` already exists in the enum. Wire via PauseMenuManager signals:

```gdscript
PauseMenuManager.pause_menu_opened.connect(func(): _set_state(UIState.PAUSED))
PauseMenuManager.pause_menu_closed.connect(func(): _set_state(UIState.EXPLORING))
```

### Battle Context (Step 10)

Save grayed out when `BattleManager.battle_active == true`.

### Cinematic Blocking (Step 11)

Handled in `PauseMenuManager._can_open_pause()`.

### Modal Input Blocking (Step 12)

Add `PauseMenuManager.is_open()` check to:
- `ExplorationUIController.is_blocking_input()`
- `HeroController._is_modal_ui_active()`
- Battle menu coordination (block pause when BattleGameMenu is active)

---

## Scope Exclusions (v1)

| Feature | Reason |
|---------|--------|
| Mod settings UI tab | No demand; API exists for future |
| About/Credits screen | Not requested |
| Input rebinding | Separate feature, significant scope |
| Pause during cinematics | Explicitly blocked |
| Voice volume slider | No voice system exists |
| Reset to Defaults button | `reset_to_defaults()` exists, add later |

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| `get_tree().paused` freezes game systems | All pause UI nodes set `PROCESS_MODE_WHEN_PAUSED` |
| Autoload ordering | PauseMenuManager registered after SettingsManager |
| BattleGameMenu + PauseMenu input conflict | `_can_open_pause()` blocks when battle menu is active |
| ESC key conflicts | No existing `sf_` action uses Escape; checked first in `_input()` |

---

## Testing Checklist

- [ ] ESC opens pause menu during exploration
- [ ] ESC opens pause menu during battle (player turn)
- [ ] ESC closes pause menu (acts as Resume)
- [ ] Game is frozen while pause menu is open
- [ ] All menu audio feedback plays
- [ ] Settings changes apply immediately
- [ ] Settings persist across game restart
- [ ] Save option grayed out during battle
- [ ] Quit to Title shows confirmation dialog
- [ ] Pause blocked during cinematics, dialog, debug console
- [ ] Hero cannot move while pause menu is open
- [ ] GameJuice settings persist via SettingsManager

---

## Key Reference Files

| File | Relevance |
|------|-----------|
| `core/systems/settings_manager.gd` | Backend for all settings |
| `core/systems/game_juice.gd` | Animation settings to wire |
| `core/systems/exploration_ui_manager.gd` | Autoload UI pattern to follow |
| `core/components/exploration_ui_controller.gd` | PAUSED state to wire |
| `scenes/ui/battle_game_menu.gd` | Menu construction pattern reference |
| `scenes/ui/shops/shop_controller.gd` | Screen stack pattern reference |
| `scenes/ui/components/modal_screen_base.gd` | Screen lifecycle pattern |
| `core/utils/ui_colors.gd` | Color constants |
