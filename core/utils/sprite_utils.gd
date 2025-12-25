class_name SpriteUtils
extends RefCounted

## Utility functions for sprite and texture operations


## Extract a static texture from SpriteFrames (first frame of walk_down or fallback)
## SF2-authentic: walk_down is the primary animation (no separate idle)
## @param frames: SpriteFrames resource to extract from
## @return: First frame texture, or null if no frames available
static func extract_texture_from_sprite_frames(frames: SpriteFrames) -> Texture2D:
	if frames == null:
		return null

	# SF2-authentic: walk_down is the primary animation
	if frames.has_animation("walk_down") and frames.get_frame_count("walk_down") > 0:
		return frames.get_frame_texture("walk_down", 0)

	# Fallback: any animation's first frame
	for anim_name: String in frames.get_animation_names():
		if frames.get_frame_count(anim_name) > 0:
			return frames.get_frame_texture(anim_name, 0)

	return null
