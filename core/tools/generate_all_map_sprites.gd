@tool
extends SceneTree

## Batch tool to generate SpriteFrames for all map spritesheets.
## Run with: godot --headless --script res://core/tools/generate_all_map_sprites.gd

const FRAME_SIZE: Vector2i = Vector2i(32, 32)
const FRAME_COUNT: int = 2
const ANIMATION_FPS: float = 4.0

const DIRECTIONS: Dictionary = {
	"walk_down": 0,
	"walk_left": 1,
	"walk_right": 2,
	"walk_up": 3,
}

## Spritesheets to process (input path -> output path)
const SPRITESHEETS: Dictionary = {
	"res://mods/_sandbox/assets/sprites/map/hero_spritesheet.png": "res://mods/_sandbox/data/sprite_frames/hero_map.tres",
	"res://mods/_sandbox/assets/sprites/map/warrior_spritesheet.png": "res://mods/_sandbox/data/sprite_frames/warrior_map.tres",
	"res://mods/_sandbox/assets/sprites/map/mage_spritesheet.png": "res://mods/_sandbox/data/sprite_frames/mage_map.tres",
	"res://mods/_sandbox/assets/sprites/map/archer_spritesheet.png": "res://mods/_sandbox/data/sprite_frames/archer_map.tres",
	"res://mods/_sandbox/assets/sprites/map/healer_spritesheet.png": "res://mods/_sandbox/data/sprite_frames/healer_map.tres",
	"res://mods/_sandbox/assets/sprites/map/knight_spritesheet.png": "res://mods/_sandbox/data/sprite_frames/knight_map.tres",
	"res://mods/_sandbox/assets/sprites/map/goblin_spritesheet.png": "res://mods/_sandbox/data/sprite_frames/goblin_map.tres",
	"res://mods/_sandbox/assets/sprites/map/skeleton_spritesheet.png": "res://mods/_sandbox/data/sprite_frames/skeleton_map.tres",
	"res://mods/_sandbox/assets/sprites/map/boss_spritesheet.png": "res://mods/_sandbox/data/sprite_frames/boss_map.tres",
}


func _init() -> void:
	print("=== Generating Map SpriteFrames ===")

	# Ensure output directory exists
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://mods/_sandbox/data/sprite_frames"))

	var success_count: int = 0
	var fail_count: int = 0

	for spritesheet_path: String in SPRITESHEETS:
		var output_path: String = SPRITESHEETS[spritesheet_path]
		if _generate_sprite_frames(spritesheet_path, output_path):
			success_count += 1
		else:
			fail_count += 1

	print("=== Complete: %d succeeded, %d failed ===" % [success_count, fail_count])
	quit(0 if fail_count == 0 else 1)


func _generate_sprite_frames(spritesheet_path: String, output_path: String) -> bool:
	print("Processing: %s" % spritesheet_path.get_file())

	var texture: Texture2D = load(spritesheet_path)
	if texture == null:
		push_error("  Failed to load: %s" % spritesheet_path)
		return false

	var sprite_frames: SpriteFrames = SpriteFrames.new()

	if sprite_frames.has_animation("default"):
		sprite_frames.remove_animation("default")

	# Walk animations (2 frames, looping)
	for dir_name: String in DIRECTIONS:
		var row: int = DIRECTIONS[dir_name]
		var anim_name: String = "walk_" + dir_name.replace("walk_", "")
		_add_animation(sprite_frames, texture, anim_name, row, FRAME_COUNT, true)

	# Idle animations (first frame only, looping)
	for dir_name: String in DIRECTIONS:
		var row: int = DIRECTIONS[dir_name]
		var anim_name: String = "idle_" + dir_name.replace("walk_", "")
		_add_animation(sprite_frames, texture, anim_name, row, 1, true)

	var error: Error = ResourceSaver.save(sprite_frames, output_path)
	if error != OK:
		push_error("  Failed to save: %s" % output_path)
		return false

	print("  Created: %s" % output_path.get_file())
	return true


func _add_animation(sprite_frames: SpriteFrames, texture: Texture2D, anim_name: String, row: int, frame_count: int, loop: bool) -> void:
	sprite_frames.add_animation(anim_name)
	sprite_frames.set_animation_speed(anim_name, ANIMATION_FPS)
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
