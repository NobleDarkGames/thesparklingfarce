@tool
extends SceneTree

## Tool script to generate SpriteFrames resources from spritesheets.
## Run with: godot --headless --script res://core/tools/generate_map_sprite_frames.gd
##
## Spritesheet layout expected (2 columns x 4 rows, 32x32 frames):
##   Row 0: walk_down  (frame1, frame2)
##   Row 1: walk_left  (frame1, frame2)
##   Row 2: walk_right (frame1, frame2)
##   Row 3: walk_up    (frame1, frame2)

const FRAME_SIZE: Vector2i = Vector2i(32, 32)
const FRAME_COUNT: int = 2
const ANIMATION_FPS: float = 4.0  # SF-authentic slow walk cycle

## Direction row mapping
const DIRECTIONS: Dictionary = {
	"walk_down": 0,
	"walk_left": 1,
	"walk_right": 2,
	"walk_up": 3,
	"idle_down": 0,  # Idle uses first frame of walk
	"idle_left": 1,
	"idle_right": 2,
	"idle_up": 3,
}


func _init() -> void:
	# Get command line arguments for input/output paths
	var args: PackedStringArray = OS.get_cmdline_args()

	var spritesheet_path: String = ""
	var output_path: String = ""

	for i: int in range(args.size()):
		if args[i] == "--spritesheet" and i + 1 < args.size():
			spritesheet_path = args[i + 1]
		elif args[i] == "--output" and i + 1 < args.size():
			output_path = args[i + 1]

	if spritesheet_path.is_empty() or output_path.is_empty():
		print("Usage: godot --headless --script res://core/tools/generate_map_sprite_frames.gd -- --spritesheet <path> --output <path>")
		print("Example: ... --spritesheet res://mods/_sandbox/art/placeholder/sprites/hero_spritesheet.png --output res://mods/_sandbox/data/sprite_frames/hero_map.tres")
		quit(1)
		return

	var success: bool = generate_sprite_frames(spritesheet_path, output_path)
	quit(0 if success else 1)


func generate_sprite_frames(spritesheet_path: String, output_path: String) -> bool:
	print("Generating SpriteFrames from: %s" % spritesheet_path)
	print("Output to: %s" % output_path)

	# Load the spritesheet texture
	var texture: Texture2D = load(spritesheet_path)
	if texture == null:
		push_error("Failed to load spritesheet: %s" % spritesheet_path)
		return false

	# Create SpriteFrames resource
	var sprite_frames: SpriteFrames = SpriteFrames.new()

	# Remove default animation
	if sprite_frames.has_animation("default"):
		sprite_frames.remove_animation("default")

	# Create walk animations (2 frames each, looping)
	for anim_name: String in ["walk_down", "walk_left", "walk_right", "walk_up"]:
		var row: int = DIRECTIONS[anim_name]
		_add_animation(sprite_frames, texture, anim_name, row, FRAME_COUNT, true)

	# Create idle animations (1 frame, looping for consistency)
	for anim_name: String in ["idle_down", "idle_left", "idle_right", "idle_up"]:
		var row: int = DIRECTIONS[anim_name]
		_add_animation(sprite_frames, texture, anim_name, row, 1, true)

	# Ensure output directory exists
	var dir_path: String = output_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	# Save the resource
	var error: Error = ResourceSaver.save(sprite_frames, output_path)
	if error != OK:
		push_error("Failed to save SpriteFrames: %s (error %d)" % [output_path, error])
		return false

	print("Successfully created: %s" % output_path)
	return true


func _add_animation(sprite_frames: SpriteFrames, texture: Texture2D, anim_name: String, row: int, frame_count: int, loop: bool) -> void:
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

	print("  Added animation: %s (%d frames)" % [anim_name, frame_count])
