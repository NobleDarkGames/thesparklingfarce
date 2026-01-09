@tool
class_name MapSpritesheetPicker
extends TexturePickerBase

## Map spritesheet picker component for selecting and processing animated walk cycle sprites.
## Extends TexturePickerBase with spritesheet-specific validation and SpriteFrames generation.
##
## Spritesheets must be exactly 64x128 pixels with the following layout:
##   +-------+-------+
##   | down1 | down2 |  Row 0: walk_down (2 frames)
##   +-------+-------+
##   | left1 | left2 |  Row 1: walk_left (2 frames)
##   +-------+-------+
##   | right1| right2|  Row 2: walk_right (2 frames)
##   +-------+-------+
##   | up1   | up2   |  Row 3: walk_up (2 frames)
##   +-------+-------+
##   Each cell: 32x32 pixels
##
## Usage:
##   var picker: MapSpritesheetPicker = MapSpritesheetPicker.new()
##   picker.texture_selected.connect(_on_spritesheet_selected)
##   picker.sprite_frames_generated.connect(_on_frames_generated)
##   add_child(picker)

# =============================================================================
# CONSTANTS
# =============================================================================

## Size of each animation frame in the spritesheet
const FRAME_SIZE: Vector2i = Vector2i(32, 32)

## Number of columns in the spritesheet (frames per direction)
const EXPECTED_COLS: int = 2

## Number of rows in the spritesheet (number of directions)
const EXPECTED_ROWS: int = 4

## Expected total size of the spritesheet
const EXPECTED_SIZE: Vector2i = Vector2i(64, 128)

## Animation playback speed (Shining Force authentic)
const ANIMATION_FPS: float = 4.0

## Direction row mapping for spritesheet layout (SF2-authentic: walk only, no separate idle)
const DIRECTIONS: Dictionary = {
	"walk_down": 0,
	"walk_left": 1,
	"walk_right": 2,
	"walk_up": 3,
}

# =============================================================================
# ADDITIONAL SIGNALS
# =============================================================================

## Emitted when SpriteFrames resource is successfully generated
signal sprite_frames_generated(sprite_frames: SpriteFrames)

## Emitted if SpriteFrames generation fails
signal sprite_frames_generation_failed(error_message: String)

# =============================================================================
# ADDITIONAL STATE
# =============================================================================

## The generated SpriteFrames resource (null if not generated)
var _generated_sprite_frames: SpriteFrames = null

## The AnimatedSprite2D used for preview (created in _create_preview_control)
var _preview_sprite: AnimatedSprite2D = null

## Path where the SpriteFrames was last saved (empty if not saved)
var _sprite_frames_path: String = ""

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init() -> void:
	super._init()

	# Configure for map spritesheet selection
	label_text = "Map Spritesheet:"
	placeholder_text = "res://mods/<mod>/assets/sprites/map/hero_spritesheet.png"
	preview_size = Vector2(64, 64)
	default_browse_subpath = "assets/sprites/map/"
	file_filters = PackedStringArray(["*.png ; PNG Spritesheet"])


# =============================================================================
# VALIDATION (Override)
# =============================================================================

func _validate_texture(path: String, texture: Texture2D) -> Dictionary:
	## Validate spritesheet texture with strict size requirements.
	## Returns validation result with appropriate severity.

	# ERROR: File not found or not a texture
	if texture == null:
		return {
			"valid": false,
			"message": "File not found",
			"severity": "error"
		}

	var width: int = texture.get_width()
	var height: int = texture.get_height()
	var size: Vector2i = Vector2i(width, height)

	# ERROR: Size must be exactly 64x128
	if size != EXPECTED_SIZE:
		return {
			"valid": false,
			"message": "Invalid size %dx%d (expected 64x128 for 2-frame walk cycle)" % [width, height],
			"severity": "error"
		}

	# SUCCESS: Valid spritesheet layout
	return {
		"valid": true,
		"message": "Valid spritesheet layout (4 directions, 2 frames each)",
		"severity": "success"
	}


# =============================================================================
# PREVIEW CONTROL (Override)
# =============================================================================

func _create_preview_control() -> Control:
	## Create an AnimatedSprite2D for animated preview instead of static TextureRect.

	# Create a container that clips its contents to prevent overflow
	var container: Control = Control.new()
	container.custom_minimum_size = preview_size
	container.clip_contents = true

	# Create the AnimatedSprite2D
	_preview_sprite = AnimatedSprite2D.new()
	_preview_sprite.centered = true
	# Position at center of container
	_preview_sprite.position = preview_size / 2
	# Scale to fill preview area nicely (32px frames in 64px preview = 2x scale)
	_preview_sprite.scale = Vector2(preview_size.x / FRAME_SIZE.x, preview_size.y / FRAME_SIZE.y)
	container.add_child(_preview_sprite)

	return container


func _update_preview(texture: Texture2D) -> void:
	## Update the animated preview by creating temporary SpriteFrames.
	## Called after texture is loaded and validated.

	if not _preview_sprite:
		return

	# Clear any existing preview
	_preview_sprite.stop()
	_preview_sprite.sprite_frames = null

	# IMPORTANT: Clear cached generated sprite frames when texture changes
	# This forces regeneration on save with the new spritesheet
	_generated_sprite_frames = null
	_sprite_frames_path = ""

	# Only create preview if texture is valid
	if texture == null or not _is_valid:
		return

	# Create temporary SpriteFrames for preview (not saved to disk)
	var preview_frames: SpriteFrames = _create_sprite_frames_from_texture(texture)
	if preview_frames == null:
		return

	_preview_sprite.sprite_frames = preview_frames

	# Auto-play walk_down animation for preview
	if preview_frames.has_animation("walk_down"):
		_preview_sprite.animation = "walk_down"
		_preview_sprite.play()


func _clear_preview() -> void:
	## Clear the animated preview.

	if _preview_sprite:
		_preview_sprite.stop()
		_preview_sprite.sprite_frames = null

	# Also clear generated sprite frames when selection is cleared
	_generated_sprite_frames = null
	_sprite_frames_path = ""


# =============================================================================
# SPRITEFRAMES GENERATION (Public API)
# =============================================================================

func generate_sprite_frames(output_path: String) -> bool:
	## Generate a SpriteFrames resource from the current spritesheet and save to disk.
	##
	## output_path: Where to save the .tres file
	##              (e.g., res://mods/_sandbox/data/sprite_frames/hero.tres)
	##
	## Returns true on success, false on failure.
	## Emits sprite_frames_generated on success, sprite_frames_generation_failed on failure.

	# Validate current state
	if not _is_valid:
		var error_msg: String = "No valid spritesheet selected"
		sprite_frames_generation_failed.emit(error_msg)
		return false

	if _current_texture == null:
		var error_msg: String = "No texture loaded"
		sprite_frames_generation_failed.emit(error_msg)
		return false

	# Create the SpriteFrames resource
	var sprite_frames: SpriteFrames = _create_sprite_frames_from_texture(_current_texture)
	if sprite_frames == null:
		var error_msg: String = "Failed to create SpriteFrames from texture"
		sprite_frames_generation_failed.emit(error_msg)
		return false

	# Ensure output directory exists
	var dir_path: String = output_path.get_base_dir()
	var global_dir_path: String = ProjectSettings.globalize_path(dir_path)
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(global_dir_path)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		var error_msg: String = "Failed to create directory '%s': %s (error code %d)" % [
			dir_path,
			error_string(dir_error),
			dir_error
		]
		push_error("MapSpritesheetPicker: " + error_msg)
		sprite_frames_generation_failed.emit(error_msg)
		return false

	# Save the resource
	var save_error: Error = ResourceSaver.save(sprite_frames, output_path)
	if save_error != OK:
		var error_msg: String = "Failed to save SpriteFrames: %s (error %d)" % [output_path, save_error]
		sprite_frames_generation_failed.emit(error_msg)
		return false

	# Store the generated resource and path
	_generated_sprite_frames = sprite_frames
	_sprite_frames_path = output_path

	# Emit success signal
	sprite_frames_generated.emit(sprite_frames)
	return true


func get_generated_sprite_frames() -> SpriteFrames:
	## Get the generated SpriteFrames resource.
	## Returns null if no SpriteFrames has been generated.
	return _generated_sprite_frames


func has_generated_sprite_frames() -> bool:
	## Check if SpriteFrames has been generated for current spritesheet.
	return _generated_sprite_frames != null


func get_or_generate_sprite_frames(output_path: String) -> SpriteFrames:
	## Get existing SpriteFrames, or generate and save if a valid spritesheet is selected.
	## This is the recommended method to call when saving - it handles all cases:
	## 1. Already has generated SpriteFrames with path -> returns it
	## 2. Already has generated SpriteFrames without path -> saves to output_path, returns it
	## 3. Valid spritesheet selected but no SpriteFrames -> generates, saves, returns it
	## 4. No valid spritesheet -> returns null
	##
	## output_path: Where to save the .tres file if generation is needed
	## Returns: SpriteFrames resource (loaded from disk for proper ExtResource reference), or null
	
	# Case 1 & 2: Already have SpriteFrames
	if _generated_sprite_frames:
		if _generated_sprite_frames.resource_path.is_empty():
			# Save to disk so it's an ExtResource, not SubResource
			if generate_sprite_frames(output_path):
				return load(output_path) as SpriteFrames
		return _generated_sprite_frames
	
	# Case 3: Valid spritesheet selected, need to generate
	if _is_valid and _current_texture:
		if generate_sprite_frames(output_path):
			return load(output_path) as SpriteFrames
	
	# Case 4: No valid spritesheet
	return null


func get_sprite_frames_path() -> String:
	## Get the path where SpriteFrames was saved.
	## Returns empty string if not saved.
	return _sprite_frames_path


func set_sprite_frames_path(spritesheet_path: String, frames_path: String) -> void:
	## Set both spritesheet path and existing SpriteFrames path.
	## Use this when loading saved data that already has a generated SpriteFrames.

	# Set the spritesheet path (this loads and validates the texture)
	set_texture_path(spritesheet_path)

	# If a frames path is provided, try to load the existing SpriteFrames
	if not frames_path.is_empty() and ResourceLoader.exists(frames_path):
		var loaded: Resource = load(frames_path)
		if loaded is SpriteFrames:
			_generated_sprite_frames = loaded as SpriteFrames
			_sprite_frames_path = frames_path


func set_existing_sprite_frames(sprite_frames: SpriteFrames) -> void:
	## Set an existing SpriteFrames resource directly (e.g., when loading from a SubResource).
	## This preserves the SpriteFrames for saving without requiring regeneration.
	## DEPRECATED: Use load_from_sprite_frames() instead for full UI support.
	if sprite_frames:
		_generated_sprite_frames = sprite_frames


func load_from_sprite_frames(sprite_frames: SpriteFrames) -> void:
	## Load an existing SpriteFrames resource, extracting and displaying its source spritesheet.
	## This is the preferred method for loading saved data - it:
	## 1. Extracts the source spritesheet texture from the SpriteFrames
	## 2. Displays the spritesheet in the picker UI
	## 3. Preserves the SpriteFrames for saving without regeneration
	clear()
	
	if not sprite_frames:
		return
	
	var frames_path: String = sprite_frames.resource_path
	
	# Extract the source spritesheet path from the atlas textures
	var spritesheet_path: String = _extract_spritesheet_path(sprite_frames)
	
	# If we found the source spritesheet, load it into the picker
	if not spritesheet_path.is_empty():
		set_sprite_frames_path(spritesheet_path, frames_path)
	
	# Always store the existing SpriteFrames so it's preserved on save
	# (This must come AFTER set_sprite_frames_path which may clear it)
	_generated_sprite_frames = sprite_frames
	if not frames_path.is_empty():
		_sprite_frames_path = frames_path


func _extract_spritesheet_path(sprite_frames: SpriteFrames) -> String:
	## Extract the source spritesheet texture path from a SpriteFrames resource.
	## Returns empty string if extraction fails.
	if not sprite_frames:
		return ""
	
	for anim_name: String in sprite_frames.get_animation_names():
		if sprite_frames.get_frame_count(anim_name) > 0:
			var frame_texture: Texture2D = sprite_frames.get_frame_texture(anim_name, 0)
			if frame_texture is AtlasTexture:
				var atlas: AtlasTexture = frame_texture as AtlasTexture
				if atlas.atlas and not atlas.atlas.resource_path.is_empty():
					return atlas.atlas.resource_path
	return ""


# =============================================================================
# INTERNAL METHODS
# =============================================================================

func _create_sprite_frames_from_texture(texture: Texture2D) -> SpriteFrames:
	## Create a SpriteFrames resource from a spritesheet texture.
	## Returns null on failure.

	if texture == null:
		return null

	var sprite_frames: SpriteFrames = SpriteFrames.new()

	# Remove default animation
	if sprite_frames.has_animation("default"):
		sprite_frames.remove_animation("default")

	# Create walk animations (2 frames each, looping)
	# SF2-authentic: walk animations play continuously, even when stationary (no separate idle)
	for anim_name: String in ["walk_down", "walk_left", "walk_right", "walk_up"]:
		var row: int = DIRECTIONS[anim_name]
		_add_animation(sprite_frames, texture, anim_name, row, EXPECTED_COLS, true)

	return sprite_frames


func _add_animation(
	sprite_frames: SpriteFrames,
	texture: Texture2D,
	anim_name: String,
	row: int,
	frame_count: int,
	loop: bool
) -> void:
	## Add an animation to the SpriteFrames by extracting frames from the spritesheet.

	sprite_frames.add_animation(anim_name)
	sprite_frames.set_animation_speed(anim_name, ANIMATION_FPS)
	sprite_frames.set_animation_loop(anim_name, loop)

	for frame_idx: int in range(frame_count):
		# Create AtlasTexture for this frame
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(
			frame_idx * FRAME_SIZE.x,  # x position
			row * FRAME_SIZE.y,         # y position
			FRAME_SIZE.x,               # width
			FRAME_SIZE.y                # height
		)

		sprite_frames.add_frame(anim_name, atlas)
