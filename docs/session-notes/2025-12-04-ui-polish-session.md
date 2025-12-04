# UI Polish Session - 2025-12-04

## Completed Work (Committed: 7b3e8a6)

### Main Menu (`mods/_base_game/scenes/ui/main_menu.gd` & `.tscn`)
- Title fade-in with scale "punch" effect (TRANS_BACK easing)
- Staggered button slide-in animations from left
- Button hover scale (1.08x) and focus scale (1.05x) effects
- **Full-screen ambient sparkle effect** using CPUParticles2D
  - 8 particles, 1.5s lifetime
  - Dynamically positioned at screen center
  - emission_rect_extents covers full viewport
  - Subtle starfield effect that doesn't distract

### Save Slot Selector (`mods/_base_game/scenes/ui/save_slot_selector.gd`)
- Title fade-in animation
- Staggered slot button slide-in from left
- Back button fade-in from below
- Button hover/focus scale effects
- **Important**: Added `await get_tree().process_frame` before capturing positions for animations (fixes layout timing issue)

### Action Menu (`scenes/ui/action_menu.gd`)
- Slide-in animation on show (from right, with TRANS_BACK)
- Slide-out animation on hide (optional)
- Selection pulse effect (1.1x scale bounce) on navigation
- Stores original position to handle animations correctly

### Battle UI Panels
- **Terrain Info Panel** (`scenes/ui/terrain_info_panel.gd`): Slide-down entrance, integrates with GameJuice
- **Combat Forecast Panel** (`scenes/ui/combat_forecast_panel.gd`): Slide-in from right, integrates with GameJuice

## Key Learnings

1. **CPUParticles2D positioning**: Node2D nodes don't respect Control anchors. Use a Control wrapper or set position dynamically via script.

2. **z_index pitfalls**: Setting `z_index = -1` on particles put them behind the Background ColorRect. Remove z_index for particles that should be visible.

3. **Pixel font scaling**: Scaling pixel fonts (like Monogram) causes distortion. Alpha pulse or sparkles are better alternatives to scale-based animations for pixel art.

4. **Layout timing**: When animating Control nodes, wait for `await get_tree().process_frame` before capturing positions, as layout containers need a frame to calculate final positions.

## Assets Created
- `assets/ui/sparkle_star.png` - 16x16 pixel 4-point star sprite (white, transparent background)

## Not Yet Implemented (Future Polish)
- UI sound effects (needs audio assets)
- Hit sparks in combat (needs particle assets)
- More elaborate title screen art
- Accessibility options for reduced motion

## Files Modified
- `mods/_base_game/scenes/ui/main_menu.gd`
- `mods/_base_game/scenes/ui/main_menu.tscn`
- `mods/_base_game/scenes/ui/save_slot_selector.gd`
- `scenes/ui/action_menu.gd`
- `scenes/ui/combat_forecast_panel.gd`
- `scenes/ui/terrain_info_panel.gd`
- `assets/ui/sparkle_star.png` (new)
