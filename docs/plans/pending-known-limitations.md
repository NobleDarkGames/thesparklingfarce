# Pending Known Limitations

Captured from platform-specification.md review session. These items were identified but deferred for later work.

## Deferred Items

### 1. Dialog Box Auto-Positioning
- **Location**: `dialog_box.gd:363-365`
- **Issue**: AUTO position falls back to BOTTOM instead of smart speaker-based positioning
- **Intended behavior**: Position dialog to avoid covering the speaker
- **Implementation approach**:
  1. Get current speaker's actor from CinematicsManager
  2. Convert actor world position to screen position
  3. If speaker in bottom half → show dialog TOP
  4. If speaker in top half → show dialog BOTTOM
- **Scope**: Moderate - requires CinematicsManager coordination
- **Alternative**: Remove AUTO option, have modders explicitly set TOP/BOTTOM

### 2. Mod Field Menu Options
- **Location**: `exploration_field_menu.gd:330-331`
- **Issue**: `_add_mod_options()` commented out; mods cannot add custom field menu options
- **Scope**: Unknown - needs investigation

### 3. Battle Equip Setting
- **Location**: `item_action_menu.gd:285-286`
- **Issue**: Equipment always exploration-only; cannot equip during battle (SF2 allows it)
- **SF2 Reference**: SF2 allows equipping items during battle from the item menu
- **Scope**: Moderate - UI flow change

### 4. Editor Reference Scanning
- **Location**: Multiple editors
- **Issue**: Phase 2+ TODO for scanning resource references (e.g., find all uses of a character)
- **Scope**: Large - cross-editor feature

### 5. Spell Animation System
- **Location**: `ability_editor.gd:398-400`
- **Issue**: Animation fields ignored; spells have no VFX
- **Planned approach**: Use Godot particle effects (GPUParticles2D), screen shake, flash/tint effects, and projectile motion as default effects. System should be mod-friendly—mods can override default particles with custom sprites/animations per ability.
- **Scope**: Large - significant new system

### 6. Translation Files
- **Location**: `mods/*/translations/`
- **Issue**: LocalizationManager API works but no actual .po/.csv translation files exist; game is English-only
- **Scope**: Content creation + tooling

---

## Completed This Session

| Item | Resolution |
|------|------------|
| AI buff item processing | Implemented - AI can now use buff items on self/allies |
| AI idle turn patience | Removed - not needed, behavior_phases with turn_count trigger covers this |
| Free cursor unit stats panel | Implemented - shows stats when pressing A on other units |
| Battle game menu | Implemented - Map, Speed, Status, Quit options |
| NPC position detection during patrol | Fixed - is_at_grid_position() now uses live position |
| Custom trigger system | Deprecated - existing systems sufficient |
| Scroll transition stub | Removed - no use case |

---

*Last updated: 2026-01-20*
