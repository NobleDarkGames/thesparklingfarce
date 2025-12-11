# Sprite Picker Components Implementation Plan

**Status:** Planning Complete
**Author:** Ed (Editor Plugin Specialist)
**UX Review:** Clauderina
**Created:** December 10, 2025
**Target Integration:** Character Editor Appearance Section

---

## Executive Summary

This document specifies the implementation of three visual texture/sprite picker components for The Sparkling Farce editor. These components enable modders to select and configure character appearance assets without manually editing file paths or creating SpriteFrames resources.

The design follows the universal translator principle: a common protocol (TexturePickerBase) with specialized modules (Portrait, BattleSprite, MapSpritesheet) that handle format-specific validation and preview rendering.

---

## Component Hierarchy

```
TexturePickerBase (HBoxContainer)
    Abstract base providing:
    - Mod-aware file browsing
    - Path validation infrastructure
    - Preview panel with styling
    - EditorFileDialog integration
    - Signal architecture
    |
    +-- PortraitPicker
    |       Static image, flexible dimensions
    |       Soft validation (aspect ratio warnings)
    |
    +-- BattleSpritePicker
    |       Static image, grid-constrained
    |       Size validation (32x32 or 64x64)
    |
    +-- MapSpritesheetPicker
            Animated spritesheet with SpriteFrames generation
            Strict validation (64x128 layout)
            Animated preview with playback
```

---

## File Structure

```
addons/sparkling_editor/ui/components/
    texture_picker_base.gd        # Abstract base class (HBoxContainer)
    texture_picker_base.tscn      # Optional: scene version for visual editing
    portrait_picker.gd            # Extends TexturePickerBase
    battle_sprite_picker.gd       # Extends TexturePickerBase
    map_spritesheet_picker.gd     # Extends TexturePickerBase
    map_spritesheet_picker.tscn   # Scene with AnimatedSprite2D preview
```

---

## Shared Base Class: TexturePickerBase

### Class Definition

```gdscript
@tool
class_name TexturePickerBase
extends HBoxContainer

## Base class for texture/sprite picker components.
## Provides mod-aware file browsing, validation infrastructure, and preview panels.
## Subclasses override validation and preview behavior for specific asset types.
```

### Signals

```gdscript
## Emitted when a texture is selected (path may be empty on load failure)
signal texture_selected(path: String, texture: Texture2D)

## Emitted when the texture is cleared (user clicked Clear or set empty path)
signal texture_cleared()

## Emitted when validation state changes
## is_valid: Whether the current texture passes validation
## message: Human-readable validation message (empty if valid with no warnings)
signal validation_changed(is_valid: bool, message: String)
```

### Exported Configuration Properties

```gdscript
## Label text displayed before the picker controls
@export var label_text: String = "Texture:"

## Minimum width for the label (for alignment across multiple pickers)
@export var label_min_width: float = 120.0

## Placeholder text shown in the path LineEdit when empty
@export var placeholder_text: String = "res://mods/<mod>/assets/..."

## Size of the preview panel (content area, not including padding)
@export var preview_size: Vector2 = Vector2(48, 48)

## File type filters for the browse dialog
@export var file_filters: PackedStringArray = ["*.png ; PNG", "*.webp ; WebP"]

## Default subdirectory within mod folder for browse dialog
## e.g., "assets/portraits/" opens to res://mods/<active_mod>/assets/portraits/
@export var default_browse_subpath: String = "assets/"

## Whether this picker allows clearing (showing Clear button)
@export var allow_clear: bool = true

## Tooltip text for the browse button
@export var browse_tooltip: String = "Browse for texture file"
```

### Internal State

```gdscript
## Currently selected texture path (empty string if none)
var _current_path: String = ""

## Currently loaded texture (null if none or load failed)
var _current_texture: Texture2D = null

## Whether current selection passes validation
var _is_valid: bool = false

## Current validation message (empty if valid with no warnings)
var _validation_message: String = ""
```

### UI Components (created in _setup_ui)

```gdscript
var _label: Label
var _preview_panel: PanelContainer
var _preview_control: Control          # TextureRect or AnimatedSprite2D (subclass chooses)
var _path_edit: LineEdit
var _browse_button: Button
var _clear_button: Button
var _validation_icon: TextureRect      # Green checkmark or red X or yellow warning
var _file_dialog: EditorFileDialog
```

### Public API Methods

```gdscript
## Set the texture by path. Loads texture, validates, updates preview.
## Emits texture_selected if load succeeds, validation_changed always.
func set_texture_path(path: String) -> void

## Get the currently selected path (empty string if none)
func get_texture_path() -> String

## Get the currently loaded texture (null if none or invalid)
func get_texture() -> Texture2D

## Check if current selection is valid (passes validation)
func is_valid() -> bool

## Get the current validation message
func get_validation_message() -> String

## Clear the current selection. Emits texture_cleared.
func clear() -> void

## Force revalidation of current texture (useful after external changes)
func revalidate() -> void
```

### Virtual Methods (Override in Subclasses)

```gdscript
## Validate the loaded texture. Override to implement type-specific validation.
## Returns Dictionary: { "valid": bool, "message": String, "severity": String }
## severity: "error" (red), "warning" (yellow), "info" (blue), "success" (green)
func _validate_texture(path: String, texture: Texture2D) -> Dictionary:
    # Base implementation: just check file exists
    if texture == null:
        return { "valid": false, "message": "File not found", "severity": "error" }
    return { "valid": true, "message": "", "severity": "success" }

## Create the preview control. Override to use AnimatedSprite2D instead of TextureRect.
## Called once during _setup_ui().
func _create_preview_control() -> Control:
    var rect: TextureRect = TextureRect.new()
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    rect.custom_minimum_size = preview_size
    return rect

## Update the preview display. Override for animated previews.
## Called after texture is loaded and validated.
func _update_preview(texture: Texture2D) -> void:
    if _preview_control is TextureRect:
        (_preview_control as TextureRect).texture = texture

## Clear the preview display. Override for animated previews.
func _clear_preview() -> void:
    if _preview_control is TextureRect:
        (_preview_control as TextureRect).texture = null
```

### UI Layout (ASCII Art)

```
+------------------------------------------------------------------------------+
| [Label: 120px] [Preview] [Path LineEdit: expand_fill] [Browse] [Clear] [Val] |
+------------------------------------------------------------------------------+

Detailed breakdown:
+--------+----------+----------------------------------------+--------+-------+-----+
| Label  | Preview  | Path LineEdit                          | Browse | Clear | Val |
| 120px  | 56x56    | SIZE_EXPAND_FILL                       | 60px   | 60px  | 24px|
| fixed  | Panel    | placeholder: res://mods/<mod>/assets/  |  Btn   | Btn   |Icon |
+--------+----------+----------------------------------------+--------+-------+-----+

Preview Panel styling:
- PanelContainer with 4px padding
- StyleBoxFlat: dark background (#1e1e26), subtle border (#3a3a46), rounded corners (4px)
- Contains TextureRect or AnimatedSprite2D

Validation Icon states:
- Green checkmark: EditorIcons/StatusSuccess (valid, no warnings)
- Yellow warning: EditorIcons/StatusWarning (valid with warnings)
- Red X: EditorIcons/StatusError (invalid)
- Gray circle: EditorIcons/StatusNone (no file selected)
```

---

## Picker Type Specifications

### 1. PortraitPicker

**Purpose:** Select character portrait images for dialog boxes and character info screens.

**Asset Requirements:**
- Format: PNG or WebP
- Dimensions: Flexible (no strict requirements)
- Recommended: 64x64 to 256x256, aspect ratio between 1:2 and 2:1

**Configuration:**
```gdscript
func _init() -> void:
    label_text = "Portrait:"
    placeholder_text = "res://mods/<mod>/assets/portraits/..."
    preview_size = Vector2(64, 64)
    default_browse_subpath = "assets/portraits/"
```

**Validation Rules:**

| Check | Result | Severity | Message |
|-------|--------|----------|---------|
| File not found | Invalid | Error | "File not found" |
| Aspect ratio < 0.5 or > 2.0 | Valid | Warning | "Unusual aspect ratio (X.X:1)" |
| Dimensions < 16x16 | Valid | Warning | "Very small image (WxH)" |
| Dimensions > 512x512 | Valid | Info | "Large image may affect performance" |
| All checks pass | Valid | Success | "" (empty) |

**Preview:** Static TextureRect with STRETCH_KEEP_ASPECT_CENTERED

---

### 2. BattleSpritePicker

**Purpose:** Select static sprite images for the tactical battle grid.

**Asset Requirements:**
- Format: PNG or WebP
- Dimensions: 32x32 or 64x64 (standard grid sizes)
- Transparency: Alpha channel supported

**Configuration:**
```gdscript
const VALID_SIZES: Array[Vector2i] = [Vector2i(32, 32), Vector2i(64, 64)]

func _init() -> void:
    label_text = "Battle Sprite:"
    placeholder_text = "res://mods/<mod>/assets/battle_sprites/..."
    preview_size = Vector2(48, 48)
    default_browse_subpath = "assets/battle_sprites/"
```

**Validation Rules:**

| Check | Result | Severity | Message |
|-------|--------|----------|---------|
| File not found | Invalid | Error | "File not found" |
| Size is 32x32 or 64x64 | Valid | Success | "" |
| Size is square but non-standard | Valid | Warning | "Non-standard size WxH (expected 32x32 or 64x64)" |
| Size is not square | Valid | Warning | "Non-square dimensions WxH (expected square)" |

**Preview:** Static TextureRect with STRETCH_KEEP_ASPECT_CENTERED

---

### 3. MapSpritesheetPicker

**Purpose:** Select and process animated spritesheets for overworld/town exploration.

**Asset Requirements:**
- Format: PNG only (spritesheet)
- Dimensions: Exactly 64x128 pixels (2 columns x 4 rows of 32x32 frames)
- Layout:
  ```
  +-------+-------+
  | down1 | down2 |  Row 0: walk_down
  +-------+-------+
  | left1 | left2 |  Row 1: walk_left
  +-------+-------+
  | right1| right2|  Row 2: walk_right
  +-------+-------+
  | up1   | up2   |  Row 3: walk_up
  +-------+-------+
  Each cell: 32x32 pixels
  ```

**Configuration:**
```gdscript
const FRAME_SIZE: Vector2i = Vector2i(32, 32)
const EXPECTED_COLS: int = 2
const EXPECTED_ROWS: int = 4
const EXPECTED_SIZE: Vector2i = Vector2i(64, 128)

func _init() -> void:
    label_text = "Map Spritesheet:"
    placeholder_text = "res://mods/<mod>/art/sprites/hero_spritesheet.png"
    preview_size = Vector2(64, 64)
    default_browse_subpath = "art/sprites/"
    file_filters = PackedStringArray(["*.png ; PNG Spritesheet"])
```

**Validation Rules:**

| Check | Result | Severity | Message |
|-------|--------|----------|---------|
| File not found | Invalid | Error | "File not found" |
| Size != 64x128 | Invalid | Error | "Invalid size WxH (expected 64x128 for 2-frame walk cycle)" |
| Size is 64x128 | Valid | Success | "Valid spritesheet layout (4 directions, 2 frames each)" |

**Additional Signals:**
```gdscript
## Emitted when SpriteFrames resource is generated
signal sprite_frames_generated(sprite_frames_path: String)

## Emitted if SpriteFrames generation fails
signal sprite_frames_generation_failed(error_message: String)
```

**Additional Public Methods:**
```gdscript
## Generate a SpriteFrames resource from the current spritesheet
## output_path: Where to save the .tres file (e.g., res://mods/_sandbox/data/sprite_frames/hero.tres)
## Returns true on success, false on failure
func generate_sprite_frames(output_path: String) -> bool

## Get the path to the generated SpriteFrames (empty if not generated)
func get_sprite_frames_path() -> String

## Check if SpriteFrames has been generated for current spritesheet
func has_sprite_frames() -> bool

## Set both spritesheet path and generated SpriteFrames path (for loading saved data)
func set_sprite_frames_path(spritesheet_path: String, frames_path: String) -> void
```

**Preview:** AnimatedSprite2D with auto-playing walk_down animation
- Cycles through walk_down frames at 4 FPS (SF-authentic)
- Creates temporary SpriteFrames for preview (not saved)

**UI Layout (Extended):**
```
+------------------------------------------------------------------------------+
| [Label: 120px] [Preview] [Path LineEdit: expand_fill] [Browse] [Clear] [Val] |
+------------------------------------------------------------------------------+
|               [   Generate SpriteFrames   ] [SpriteFrames: path/or/status  ] |
+------------------------------------------------------------------------------+

Second row shown only when spritesheet is valid.
"Generate SpriteFrames" button creates .tres resource.
Status shows path after generation or "Not generated yet".
```

---

## Validation Feedback Design (Clauderina UX Recommendations)

### Visual Indicators

**Validation Icon States:**
1. **No Selection** (Gray)
   - Icon: StatusNone or empty
   - Tooltip: "No file selected"

2. **Valid** (Green)
   - Icon: StatusSuccess (checkmark)
   - Tooltip: Empty or positive message

3. **Valid with Warnings** (Yellow)
   - Icon: StatusWarning (exclamation triangle)
   - Tooltip: Warning message

4. **Invalid** (Red)
   - Icon: StatusError (X)
   - Tooltip: Error message

**LineEdit Border States:**
- Default: Editor theme default
- Invalid: Red border (modulate or theme override)
- Warning: Yellow border (optional, may be too noisy)

### Error/Warning Display

**Inline Tooltip Approach (Primary):**
- Validation messages shown as tooltip on hover over validation icon
- Immediate, non-intrusive feedback
- Works well for single-line messages

**Expanded Detail (On Request):**
- Clicking validation icon shows popup with full details
- Includes suggested fixes
- Example for invalid spritesheet size:
  ```
  ERROR: Invalid spritesheet size

  Current: 128x128
  Expected: 64x128 (2 columns x 4 rows of 32x32 frames)

  Tip: Each frame should be 32x32 pixels.
  Total layout: 2 frames wide, 4 directions tall.
  ```

### Animated Preview Behavior

**Auto-Play (Default):**
- Animation plays automatically when valid spritesheet loaded
- Uses walk_down animation at 4 FPS
- Loops continuously

**Hover Enhancement (Optional Future):**
- Hover over preview cycles through all directions
- Direction indicator label below preview

### Error State Animations

**Subtle Shake on Invalid:**
```gdscript
func _show_validation_error() -> void:
    var tween: Tween = create_tween()
    tween.tween_property(_path_edit, "position:x", _path_edit.position.x + 3, 0.05)
    tween.tween_property(_path_edit, "position:x", _path_edit.position.x - 3, 0.05)
    tween.tween_property(_path_edit, "position:x", _path_edit.position.x, 0.05)
```

**Flash on Clear:**
- Brief flash when clear button pressed
- Confirms action was taken

---

## Integration with Character Editor

### Appearance Section Implementation

The Character Editor's `_create_detail_form()` will add an Appearance section:

```gdscript
## In character_editor.gd

var portrait_picker: PortraitPicker
var battle_sprite_picker: BattleSpritePicker
var map_spritesheet_picker: MapSpritesheetPicker

func _create_detail_form() -> void:
    # ... existing sections ...

    _add_appearance_section()

    # ... button container ...


func _add_appearance_section() -> void:
    var section: VBoxContainer = VBoxContainer.new()

    var section_label: Label = Label.new()
    section_label.text = "Appearance"
    section_label.add_theme_font_size_override("font_size", 16)
    section.add_child(section_label)

    var help_label: Label = Label.new()
    help_label.text = "Visual assets for this character"
    help_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
    help_label.add_theme_font_size_override("font_size", 14)
    section.add_child(help_label)

    # Portrait Picker
    portrait_picker = PortraitPicker.new()
    portrait_picker.texture_selected.connect(_on_portrait_selected)
    portrait_picker.texture_cleared.connect(_on_portrait_cleared)
    section.add_child(portrait_picker)

    # Battle Sprite Picker
    battle_sprite_picker = BattleSpritePicker.new()
    battle_sprite_picker.texture_selected.connect(_on_battle_sprite_selected)
    battle_sprite_picker.texture_cleared.connect(_on_battle_sprite_cleared)
    section.add_child(battle_sprite_picker)

    # Map Spritesheet Picker (with generation)
    map_spritesheet_picker = MapSpritesheetPicker.new()
    map_spritesheet_picker.texture_selected.connect(_on_spritesheet_selected)
    map_spritesheet_picker.sprite_frames_generated.connect(_on_sprite_frames_generated)
    section.add_child(map_spritesheet_picker)

    detail_panel.add_child(section)
```

### Loading Character Data

```gdscript
func _load_resource_data() -> void:
    var character: CharacterData = current_resource as CharacterData
    if not character:
        return

    # ... existing field loading ...

    # Load appearance
    if character.portrait:
        portrait_picker.set_texture_path(character.portrait.resource_path)
    else:
        portrait_picker.clear()

    if character.battle_sprite:
        battle_sprite_picker.set_texture_path(character.battle_sprite.resource_path)
    else:
        battle_sprite_picker.clear()

    if character.map_sprite_frames:
        # MapSpritesheetPicker needs both the SpriteFrames path and ideally the source spritesheet
        # For now, we'll load from SpriteFrames and reconstruct spritesheet path if possible
        _load_map_sprite_from_sprite_frames(character.map_sprite_frames)
    else:
        map_spritesheet_picker.clear()
```

### Saving Character Data

```gdscript
func _save_resource_data() -> void:
    var character: CharacterData = current_resource as CharacterData
    if not character:
        return

    # ... existing field saving ...

    # Save appearance
    character.portrait = portrait_picker.get_texture()
    character.battle_sprite = battle_sprite_picker.get_texture()

    # For map sprites, we need the SpriteFrames resource, not the spritesheet
    if map_spritesheet_picker.has_sprite_frames():
        var frames_path: String = map_spritesheet_picker.get_sprite_frames_path()
        if not frames_path.is_empty():
            character.map_sprite_frames = load(frames_path) as SpriteFrames
    else:
        character.map_sprite_frames = null
```

### Signal Handlers

```gdscript
func _on_portrait_selected(path: String, texture: Texture2D) -> void:
    _mark_dirty()

func _on_portrait_cleared() -> void:
    _mark_dirty()

func _on_battle_sprite_selected(path: String, texture: Texture2D) -> void:
    _mark_dirty()

func _on_battle_sprite_cleared() -> void:
    _mark_dirty()

func _on_spritesheet_selected(path: String, texture: Texture2D) -> void:
    _mark_dirty()
    # Optionally auto-generate SpriteFrames when valid spritesheet selected
    # Or wait for user to click Generate button

func _on_sprite_frames_generated(frames_path: String) -> void:
    _mark_dirty()
    _show_success_message("SpriteFrames generated: " + frames_path.get_file())
```

---

## SpriteFrames Generation Implementation

The MapSpritesheetPicker integrates with the existing `generate_map_sprite_frames.gd` tool logic:

```gdscript
## In map_spritesheet_picker.gd

func generate_sprite_frames(output_path: String) -> bool:
    if not _is_valid or _current_texture == null:
        sprite_frames_generation_failed.emit("No valid spritesheet selected")
        return false

    var sprite_frames: SpriteFrames = SpriteFrames.new()

    # Remove default animation
    if sprite_frames.has_animation("default"):
        sprite_frames.remove_animation("default")

    # Create walk animations (2 frames each, looping)
    for anim_name: String in ["walk_down", "walk_left", "walk_right", "walk_up"]:
        var row: int = _get_direction_row(anim_name)
        _add_animation(sprite_frames, _current_texture, anim_name, row, 2, true)

    # Create idle animations (1 frame, looping)
    for anim_name: String in ["idle_down", "idle_left", "idle_right", "idle_up"]:
        var row: int = _get_direction_row(anim_name)
        _add_animation(sprite_frames, _current_texture, anim_name, row, 1, true)

    # Ensure output directory exists
    var dir_path: String = output_path.get_base_dir()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

    # Save the resource
    var error: Error = ResourceSaver.save(sprite_frames, output_path)
    if error != OK:
        sprite_frames_generation_failed.emit("Failed to save: " + error_string(error))
        return false

    _sprite_frames_path = output_path
    sprite_frames_generated.emit(output_path)
    return true


func _get_direction_row(anim_name: String) -> int:
    match anim_name:
        "walk_down", "idle_down": return 0
        "walk_left", "idle_left": return 1
        "walk_right", "idle_right": return 2
        "walk_up", "idle_up": return 3
        _: return 0


func _add_animation(sprite_frames: SpriteFrames, texture: Texture2D, anim_name: String, row: int, frame_count: int, loop: bool) -> void:
    sprite_frames.add_animation(anim_name)
    sprite_frames.set_animation_speed(anim_name, 4.0)  # SF-authentic
    sprite_frames.set_animation_loop(anim_name, loop)

    for frame_idx: int in range(frame_count):
        var atlas: AtlasTexture = AtlasTexture.new()
        atlas.atlas = texture
        atlas.region = Rect2(
            frame_idx * FRAME_SIZE.x,
            row * FRAME_SIZE.y,
            FRAME_SIZE.x,
            FRAME_SIZE.y
        )
        sprite_frames.add_frame(anim_name, atlas)
```

---

## Implementation Phases

### Phase 1: TexturePickerBase (0.5 days)

**Deliverables:**
- `texture_picker_base.gd` with full shared infrastructure
- Mod-aware browse dialog implementation
- Preview panel styling
- Validation icon states
- Signal architecture

**Test Points:**
- Browse button opens to correct mod directory
- Path changes trigger validation
- Clear button works
- Validation icon updates correctly

### Phase 2: PortraitPicker (0.25 days)

**Deliverables:**
- `portrait_picker.gd` extending TexturePickerBase
- Flexible aspect ratio validation (warnings only)
- Basic integration test

**Test Points:**
- Loads various image sizes
- Shows warnings for unusual aspects
- Preview displays correctly

### Phase 3: BattleSpritePicker (0.25 days)

**Deliverables:**
- `battle_sprite_picker.gd` extending TexturePickerBase
- Size validation for 32x32 and 64x64
- Warning for non-standard sizes

**Test Points:**
- Accepts 32x32 and 64x64 without warnings
- Shows warnings for other sizes
- Preview displays correctly

### Phase 4: MapSpritesheetPicker (1 day)

**Deliverables:**
- `map_spritesheet_picker.gd` extending TexturePickerBase
- `map_spritesheet_picker.tscn` with AnimatedSprite2D preview
- Strict size validation (64x128)
- Animated preview (walk_down cycle)
- SpriteFrames generation integration
- Generate button and status display

**Test Points:**
- Rejects non-64x128 images
- Animated preview plays correctly
- SpriteFrames generation succeeds
- Generated resource loads correctly

### Phase 5: Character Editor Integration (0.5 days)

**Deliverables:**
- Appearance section in character_editor.gd
- Load/save integration for all three asset types
- Dirty tracking integration

**Test Points:**
- All pickers appear in Appearance section
- Loading character populates pickers
- Saving character updates resource
- Unsaved changes warning works

### Phase 6: Testing and Polish (0.5 days)

**Deliverables:**
- Unit tests for validation logic
- Integration tests for editor workflow
- Edge case handling (missing files, corrupt images)
- Accessibility review (keyboard navigation)

---

## Total Estimated Effort

| Phase | Component | Effort |
|-------|-----------|--------|
| 1 | TexturePickerBase | 0.5 days |
| 2 | PortraitPicker | 0.25 days |
| 3 | BattleSpritePicker | 0.25 days |
| 4 | MapSpritesheetPicker | 1.0 days |
| 5 | Character Editor Integration | 0.5 days |
| 6 | Testing and Polish | 0.5 days |
| **Total** | | **3.0 days** |

---

## Future Extensions

This architecture supports future picker types:

1. **CombatAnimationPicker**: Different grid layout for attack/cast/hit frames
2. **ItemIconPicker**: 32x32 strict validation, batch import from icon sheets
3. **TilesetTexturePicker**: Preview individual tiles from tileset images
4. **ParticleTexturePicker**: Animated effect spritesheets

Each would extend TexturePickerBase with specific validation rules and preview behavior.

---

## Open Questions for Clauderina

1. **Auto-generate vs Manual Button:** Should SpriteFrames generate automatically when valid spritesheet is selected, or require explicit button click?
   - **Recommendation:** Manual button. Auto-generation might overwrite existing files unexpectedly.

2. **Preview Click Behavior:** Should clicking the preview open a larger preview modal?
   - **Recommendation:** Yes, especially for portraits. Low priority enhancement.

3. **Drag-and-Drop Support:** Should users be able to drag files from FileSystem dock onto the picker?
   - **Recommendation:** Yes, excellent UX. Medium priority enhancement.

4. **Recent Files List:** Should browse button show recent selections?
   - **Recommendation:** Nice-to-have, low priority.

---

## Appendix A: Editor Icon References

The validation icons use Godot's built-in editor icons:

```gdscript
func _get_editor_icon(name: String) -> Texture2D:
    if Engine.is_editor_hint():
        return EditorInterface.get_editor_theme().get_icon(name, "EditorIcons")
    return null

# Usage:
_validation_icon.texture = _get_editor_icon("StatusSuccess")  # Green check
_validation_icon.texture = _get_editor_icon("StatusWarning")  # Yellow triangle
_validation_icon.texture = _get_editor_icon("StatusError")    # Red X
```

---

## Appendix B: Theme Constants Reference

For consistent styling, use EditorThemeUtils (existing utility class):

```gdscript
# Label width for alignment
const DEFAULT_LABEL_WIDTH: float = 120.0

# Preview panel style
func create_preview_panel_style() -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.12, 0.15)
    style.border_color = Color(0.3, 0.3, 0.35)
    style.set_border_width_all(1)
    style.set_corner_radius_all(4)
    style.set_content_margin_all(4)
    return style
```

---

**Document Version:** 1.0
**Last Updated:** December 10, 2025
**Approved By:** Pending Captain Obvious review
