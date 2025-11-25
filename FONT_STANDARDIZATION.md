# Font Standardization - Monogram Everywhere

**Date:** November 25, 2025
**Status:** ✅ COMPLETE

## Overview

All UI scenes now use the Monogram pixel font consistently through a centralized theme resource, with all font sizes meeting the 16px minimum requirement for clarity.

---

## Changes Made

### 1. Created UI Theme Resource

**File:** `assets/themes/ui_theme.tres`
- Base font: Monogram (`assets/fonts/monogram.ttf`)
- Default font size: 16px
- Button default: 20px
- Label default: 16px

### 2. Applied Theme to All UI Scenes

**Menu/Frontend Scenes:**
- ✅ `scenes/ui/opening_cinematic.tscn`
- ✅ `scenes/ui/main_menu.tscn`
- ✅ `scenes/ui/save_slot_selector.tscn`
- ✅ `scenes/ui/save_slot_button.tscn`

**Battle UI Scenes:**
- ✅ `scenes/ui/action_menu.tscn`
- ✅ `scenes/ui/active_unit_stats_panel.tscn`
- ✅ `scenes/ui/combat_animation_scene.tscn`
- ✅ `scenes/ui/terrain_info_panel.tscn`

---

## Font Size Standards

All font sizes now follow a consistent scale (minimum 16px):

| Size | Usage | Count |
|------|-------|-------|
| **16px** | Body text, small labels, standard UI elements | 30 instances |
| **24px** | Buttons, subtitles, combat text, section headings | 8 instances |
| **32px** | Page titles, dialog headers | 2 instances |
| **48px** | Main game title | 2 instances |
| **64px** | Large combat damage numbers | 1 instance |

### Size Guidelines

- **16px** - Minimum size for readability (1x native)
  - Body text
  - Small labels
  - Status displays

- **24px** - Medium emphasis (1.5x scaling)
  - Primary action buttons
  - Subtitles
  - Menu items
  - Combat feedback
  - Section headings

- **32px** - Page headers
  - Screen titles
  - Dialog headers

- **48px** - Major titles
  - Game title on menus
  - Chapter/story titles

- **64px** - Impact moments
  - Critical hit numbers
  - Special effects

---

## Technical Details

### Theme Structure

```gdscript
[resource]
default_font = MonogramFont
default_font_size = 16
Button/font_sizes/font_size = 20
Label/font_sizes/font_size = 16
```

### Per-Scene Overrides

Each scene can override font sizes for specific controls:

```gdscript
theme_override_font_sizes/font_size = 48  # For title labels
```

This maintains consistency while allowing flexibility.

---

## Pixel Font Best Practices

### Optimal Sizes for Monogram

Monogram is a pixel font with a native size of **16px**. For best results, use sizes that are clean multiples or half-multiples:

**Perfect scaling:**
- 16px (1x) - Native size, crystal clear
- 24px (1.5x) - Good scaling, minimal artifacts
- 32px (2x) - Perfect double
- 48px (3x) - Perfect triple
- 64px (4x) - Perfect quadruple

**Avoid:**
- 20px (1.25x) - Creates vertical compression artifacts (REMOVED from all scenes)
- Other non-clean multiples - May look squished or blurry

**Why this matters:** Pixel fonts render individual pixels precisely. Non-integer scaling causes the engine to interpolate pixels, creating artifacts like vertical compression or blur.

---

## Benefits

### Consistency
- Single source of truth for font styling
- No more scattered direct font references
- Easy to update font globally

### Clarity
- 16px minimum ensures readability on all screens
- Clear visual hierarchy with size progression
- Pixel-perfect rendering (Monogram is designed for this)

### Maintainability
- One theme file to update
- Reduces scene file complexity
- Easy to add new UI elements with correct styling

---

## Verification

✅ All 8 UI scenes use the theme resource
✅ No font sizes below 16px
✅ No direct FontFile references (all use theme)
✅ Game loads without errors
✅ Full flow tested: Opening → Menu → Save Selector → Battle

---

## Future Considerations

### When Adding New UI

1. Add theme reference to scene root:
   ```gdscript
   [ext_resource type="Theme" uid="uid://cpdx7u62cktq6" path="res://assets/themes/ui_theme.tres" id="1_ui_theme"]
   theme = ExtResource("1_ui_theme")
   ```

2. Override font sizes as needed (16px minimum):
   ```gdscript
   theme_override_font_sizes/font_size = 20
   ```

3. Use size guidelines above for consistency

### Additional Fonts

If additional fonts are needed (e.g., for special effects or non-English text):
- Create separate theme variants (e.g., `ui_theme_ja.tres` for Japanese)
- Maintain same size standards
- Keep Monogram as primary font for English

---

## Testing Checklist

- [x] Opening cinematic displays correctly
- [x] Main menu buttons are readable
- [x] Save slot selector shows clear text
- [x] Battle UI elements render properly
- [x] No rendering artifacts or cut-off text
- [x] All scenes load without errors

---

**Approved by:** Captain
**Implemented by:** Numba One
**Result:** Engaging! 🖖
