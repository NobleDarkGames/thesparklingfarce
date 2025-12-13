# Sprite Field Consolidation - In Progress

## Problem Statement

CharacterData currently has TWO separate sprite fields:
- `battle_sprite: Texture2D` - Static sprite for tactical battle grid
- `map_sprite_frames: SpriteFrames` - Animated sprite for map exploration

**This is wrong.** Shining Force 2 used the SAME animated spritesheet for both map exploration AND battle grid movement. Only combat ATTACK animations were separate.

## Approved Solution

Consolidate to single field:
- `sprite_frames: SpriteFrames` - Used for ALL movement (map + battle grid)
- Keep `combat_animation_data` - For attack/spell animations (unchanged)

---

## Phase 0: Core Fallback Assets (COMPLETE)

**Goal**: Establish reliable fallback art in `core/` so modders can create characters without art, tests don't depend on mod assets, and the platform guarantees something always renders.

### 0.1 Create Folder Structure

```
core/assets/defaults/
├── sprites/
│   ├── default_character_spritesheet.png   # 64x128, 4 directions x 2 frames
│   └── default_battle_sprite.png           # 64x64
├── portraits/
│   ├── default_character_portrait.png      # Hero-style for playable characters
│   └── default_npc_portrait.png            # Already exists, move here
├── icons/
│   └── items/
│       ├── default_weapon.png              # 16x16
│       ├── default_armor.png
│       ├── default_accessory.png
│       └── default_consumable.png
└── default_npc_sprite.png                  # Already exists (consider moving to sprites/)
```

### 0.2 Copy Assets from _sandbox

Source files to copy (not move - _sandbox keeps its copies):
| Destination | Source |
|-------------|--------|
| `sprites/default_character_spritesheet.png` | `_sandbox/assets/sprites/map/hero_spritesheet.png` |
| `sprites/default_battle_sprite.png` | `_sandbox/assets/sprites/battle/hero.png` |
| `portraits/default_character_portrait.png` | `_sandbox/assets/portraits/hero.png` |
| `icons/items/default_weapon.png` | `_sandbox/assets/icons/items/sword.png` |
| `icons/items/default_armor.png` | `_sandbox/assets/icons/items/armor.png` |
| `icons/items/default_accessory.png` | `_sandbox/assets/icons/items/ring.png` |
| `icons/items/default_consumable.png` | `_sandbox/assets/icons/items/potion.png` |

### 0.3 Update Code to Use Real Sprites Instead of ColorRects

**File**: `core/components/unit.gd`

Current `_create_placeholder_sprite_frames()` creates a white 24x24 square. Update to:
1. Load `res://core/assets/defaults/sprites/default_character_spritesheet.png`
2. Create proper SpriteFrames with idle_down/walk_down animations from the spritesheet
3. Remove `_create_placeholder_texture()` method (no longer needed)

**Other files to check** for ColorRect fallbacks:
- Character/item preview components in the editor
- Any UI that displays character sprites

### 0.4 Testing (DONE)

- ✅ All 76 unit tests pass
- ✅ AI integration tests pass
- ✅ Battle flow integration tests pass

### Files Changed in Phase 0

- Created `core/assets/defaults/sprites/` with `default_character_spritesheet.png`, `default_battle_sprite.png`, `default_npc_sprite.png`
- Created `core/assets/defaults/portraits/` with `default_character_portrait.png`, `default_npc_portrait.png`
- Created `core/assets/defaults/icons/items/` with `default_weapon.png`, `default_armor.png`, `default_accessory.png`, `default_consumable.png`
- Updated `core/components/unit.gd` - `_create_placeholder_sprite_frames()` now loads real spritesheet
- Updated `scenes/map_exploration/map_test_playable.gd` - replaced ColorRect fallbacks with AnimatedSprite2D using defaults

---

## Progress (COMPLETE)

### Completed
1. **Phase 0: Core Fallback Assets** - DONE
   - Created `core/assets/defaults/` structure with sprites, portraits, icons
   - All placeholder code uses real SpriteFrames instead of ColorRects

2. **Phase 1: CharacterData** - DONE
   - Consolidated to single `sprite_frames` field
   - Added `get_display_texture()` helper

3. **Phase 2: Unit Scene/Script** - DONE
   - `scenes/unit.tscn` uses `AnimatedSprite2D`
   - `_create_placeholder_sprite_frames()` loads default spritesheet
   - `_set_acted_visual()` updated to use `sprite_frames`

4. **Phase 3: Map exploration files** - DONE
   - `scenes/map_exploration/map_test_playable.gd` - updated
   - `core/templates/map_template.gd` - updated
   - `mods/_base_game/maps/templates/map_template.gd` - updated

5. **Phase 4: UI/presentation** - DONE
   - `scenes/ui/promotion_ceremony.gd` - uses `get_display_texture()`
   - `core/resources/npc_data.gd` - uses `get_display_texture()`

6. **Phase 5: Character Editor** - DONE
   - Consolidated sprite pickers to single `_sprite_frames_picker`

7. **Phase 6: Migrate .tres data files** - DONE
   - All sandbox character files updated to use `sprite_frames`

8. **Phase 7: Testing** - DONE
   - All 76 unit tests pass
   - AI integration tests pass
   - Battle flow integration tests pass

---

## All Files Modified

### Core
- `core/resources/character_data.gd` - Consolidated sprite fields
- `core/components/unit.gd` - Updated visual handling and placeholders
- `core/resources/npc_data.gd` - Uses `get_display_texture()`
- `core/templates/map_template.gd` - Uses `sprite_frames` with AnimatedSprite2D
- `core/assets/defaults/` - New fallback assets folder

### Scenes
- `scenes/unit.tscn` - Uses AnimatedSprite2D
- `scenes/map_exploration/map_test_playable.gd` - Updated sprite handling
- `scenes/ui/promotion_ceremony.gd` - Uses `get_display_texture()`

### Mods
- `mods/_base_game/maps/templates/map_template.gd` - Updated sprite handling
- `mods/_sandbox/data/characters/*.tres` - Migrated to `sprite_frames`
- `mods/_sandbox/data/sprite_frames/*.tres` - Updated paths
- `mods/_sandbox/data/npcs/*.tres` - Updated paths

### Editor
- `addons/sparkling_editor/ui/character_editor.gd` - Consolidated sprite pickers

## Captain's Concern (RESOLVED)

The Captain's concern about ColorRect fallbacks has been addressed by implementing Phase 0 (Core Fallback Assets). All fallbacks now use actual SpriteFrames from `core/assets/defaults/` instead of ColorRects.

## Key Search Patterns

To find remaining references:
```bash
grep -r "battle_sprite" --include="*.gd" --include="*.tres"
grep -r "map_sprite_frames" --include="*.gd" --include="*.tres"
grep -r "_create_placeholder" --include="*.gd"
```
