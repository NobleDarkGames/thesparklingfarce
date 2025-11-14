# Shining Force Cursor & Movement Path System

## Research Findings

### Cursor Behavior

1. **Cursor appears** when unit's turn starts
2. **Cursor starts at active character's position**
3. **Arrow keys** move cursor cell-by-cell within movement range
4. **Cursor visually distinct** - typically a colored rectangle/highlight
5. **Cursor cannot move outside** the flashing movement range

### Path Preview

1. **Path draws dynamically** from character to cursor position
2. **Path updates in real-time** as cursor moves
3. **Path shows shortest route** using pathfinding (A*)
4. **Visual indication** - typically arrows/lines showing direction
5. **Path only shown for valid destinations** within movement range

### Movement Confirmation Flow

1. Unit's turn starts → Cursor appears at unit position
2. Player moves cursor with arrow keys (or clicks destination)
3. **Path preview updates** to show route to cursor
4. Player presses confirm (A/C button or click)
5. Unit walks along the path
6. **Camera follows unit** during movement
7. Action menu appears at destination

### Fire Emblem Style (Similar System)

- Blue area = walkable range
- Path drawn with directional arrows
- Auto-tiling creates curves and smooth visuals
- AStar pathfinding calculates optimal route
- Path cached and reused for actual movement

## Implementation Requirements

### 1. Grid Cursor (Visual)
```gdscript
# Create cursor sprite/ColorRect
# Position at current_cursor_position
# Update every time cursor moves
# Blink/pulse animation optional
```

### 2. Path Preview System
```gdscript
# When cursor moves:
#   - Calculate path from unit to cursor using GridManager.find_path()
#   - Draw path visuals (ColorRect chain or Line2D)
#   - Update path every time cursor position changes
#   - Clear path when invalid destination
```

### 3. Movement Animation
```gdscript
# When movement confirmed:
#   - Use calculated path
#   - Tween unit position cell-by-cell
#   - Camera follows unit (already working)
#   - Wait for animation complete
#   - Then show action menu
```

### 4. Input Flow Changes
```gdscript
# Arrow keys:
#   - Move cursor (not unit directly)
#   - Clamp cursor to walkable cells
#   - Update path preview
#
# Confirm (Enter/Click):
#   - Move unit along previewed path
#   - Animate movement
#   - Show action menu
#
# Cancel (B/ESC):
#   - Reset cursor to unit start position
#   - Clear path preview
```

## Visual Design

### Cursor
- **Size**: 32x32 (one cell)
- **Color**: Yellow/white bright color
- **Style**: Semi-transparent overlay
- **Animation**: Optional pulse/blink

### Path Preview
- **Style**: Colored rectangles or line segments
- **Color**: Yellow/gold (distinct from movement range blue)
- **Opacity**: Semi-transparent (0.5-0.7)
- **Arrow indicators**: Optional directional arrows on path tiles

## Implementation Order

1. **Create cursor visual** - ColorRect or Sprite2D
2. **Add cursor to InputManager** - track cursor_position
3. **Arrow key movement** - update cursor position, clamp to walkable cells
4. **Path calculation** - use GridManager.find_path() on cursor move
5. **Path visualization** - draw ColorRect chain along path
6. **Movement animation** - tween unit along path with camera follow
7. **Polish** - add cursor blink, path arrows, smooth transitions
