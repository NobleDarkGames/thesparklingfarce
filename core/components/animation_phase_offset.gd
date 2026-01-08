class_name AnimationPhaseOffset
extends Node

## Component that applies phase offset to AnimatedSprite2D animations.
## Attach as a child of a node containing an AnimatedSprite2D to desynchronize
## its animation playback from other sprites using the same animation.
##
## This creates the classic 16-bit era effect where idle animations, torches,
## and other repeating animations don't all change frames at the same time,
## resulting in a more natural, living world appearance.
##
## Usage:
##   1. Add this node as a child of any Node2D with an AnimatedSprite2D
##   2. Configure the offset_type to control desynchronization behavior
##   3. Optionally set target_sprite if auto-detection doesn't work
##
## The offset is applied once when the node enters the scene tree.
## For deterministic behavior (save/load consistency), use "position_based".

## The AnimatedSprite2D to apply offset to. If null, auto-detects from parent/siblings.
@export var target_sprite: AnimatedSprite2D = null

## The type of offset to apply. Uses AnimationOffsetRegistry types.
@export_enum("none", "random", "clustered", "position_based", "instance_id") var offset_type: String = "random"

## Optional: Specific animation to offset. Empty string means current/default animation.
@export var target_animation: String = ""

## If true, reapplies offset when animation changes
@export var track_animation_changes: bool = false

# Internal tracking
var _last_animation: String = ""
var _offset_applied: bool = false


func _ready() -> void:
	# Find the sprite if not explicitly set
	if target_sprite == null:
		target_sprite = _find_animated_sprite()

	if target_sprite == null:
		push_warning("AnimationPhaseOffset: No AnimatedSprite2D found. Assign target_sprite or ensure parent has one.")
		return

	# Wait a frame to ensure the sprite is fully initialized
	await get_tree().process_frame

	# Validate after await - node or sprite may have been freed
	if not is_instance_valid(self) or not is_instance_valid(target_sprite):
		return

	_apply_phase_offset()

	# Optionally track animation changes
	if track_animation_changes and target_sprite != null:
		target_sprite.animation_changed.connect(_on_animation_changed)


func _find_animated_sprite() -> AnimatedSprite2D:
	# Check parent first
	var parent: Node = get_parent()
	if parent is AnimatedSprite2D:
		return parent as AnimatedSprite2D

	# Check siblings
	if parent != null:
		for sibling: Node in parent.get_children():
			if sibling is AnimatedSprite2D:
				return sibling as AnimatedSprite2D

	# Check parent's direct child named "Sprite" or similar
	if parent != null:
		var sprite_node: Node = parent.get_node_or_null("AnimatedSprite2D")
		if sprite_node is AnimatedSprite2D:
			return sprite_node as AnimatedSprite2D
		sprite_node = parent.get_node_or_null("Sprite")
		if sprite_node is AnimatedSprite2D:
			return sprite_node as AnimatedSprite2D

	return null


func _apply_phase_offset() -> void:
	if target_sprite == null:
		return

	var sprite_frames: SpriteFrames = target_sprite.sprite_frames
	if sprite_frames == null:
		return

	# Determine which animation to offset
	var anim_name: String = target_animation if not target_animation.is_empty() else target_sprite.animation
	if anim_name.is_empty() or not sprite_frames.has_animation(anim_name):
		return

	var frame_count: int = sprite_frames.get_frame_count(anim_name)
	if frame_count <= 1:
		# No point offsetting single-frame animations
		return

	# Calculate offset using the registry's static method
	var method: AnimationOffsetRegistry.OffsetMethod = _get_offset_method()
	var position: Vector2 = _get_world_position()
	var inst_id: int = target_sprite.get_instance_id()

	var offset_ratio: float = AnimationOffsetRegistry.calculate_offset(method, position, inst_id)

	# Apply offset to the sprite's frame
	var offset_frame: int = int(offset_ratio * float(frame_count)) % frame_count
	target_sprite.frame = offset_frame

	_last_animation = anim_name
	_offset_applied = true


func _get_offset_method() -> AnimationOffsetRegistry.OffsetMethod:
	# Map the export string to the enum
	match offset_type:
		"none":
			return AnimationOffsetRegistry.OffsetMethod.NONE
		"random":
			return AnimationOffsetRegistry.OffsetMethod.RANDOM
		"clustered":
			return AnimationOffsetRegistry.OffsetMethod.CLUSTERED
		"position_based":
			return AnimationOffsetRegistry.OffsetMethod.POSITION_BASED
		"instance_id":
			return AnimationOffsetRegistry.OffsetMethod.INSTANCE_ID
		_:
			# Try to look up in registry if available
			if Engine.has_singleton("ModLoader"):
				var mod_loader: Node = Engine.get_singleton("ModLoader")
				if mod_loader.has_method("get_animation_offset_registry"):
					var registry: AnimationOffsetRegistry = mod_loader.get_animation_offset_registry()
					return registry.get_offset_method(offset_type)
			return AnimationOffsetRegistry.OffsetMethod.RANDOM


func _get_world_position() -> Vector2:
	# Get global position for position-based offset
	if target_sprite != null:
		return target_sprite.global_position

	var parent: Node = get_parent()
	if parent is Node2D:
		return parent.global_position

	return Vector2.ZERO


func _exit_tree() -> void:
	# Disconnect signal to prevent callbacks after removal
	if track_animation_changes and is_instance_valid(target_sprite):
		if target_sprite.animation_changed.is_connected(_on_animation_changed):
			target_sprite.animation_changed.disconnect(_on_animation_changed)


func _on_animation_changed() -> void:
	if not track_animation_changes:
		return

	var current_anim: String = target_sprite.animation
	if current_anim != _last_animation:
		_apply_phase_offset()


## Manually trigger offset reapplication (useful after teleporting units)
func reapply_offset() -> void:
	_apply_phase_offset()


## Apply offset to an AnimatedSprite2D without needing a component instance.
## Utility function for one-off offset applications.
static func apply_offset_to_sprite(
	sprite: AnimatedSprite2D,
	method: AnimationOffsetRegistry.OffsetMethod = AnimationOffsetRegistry.OffsetMethod.RANDOM,
	animation_name: String = ""
) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	var anim_name: String = animation_name if not animation_name.is_empty() else sprite.animation
	if anim_name.is_empty() or not sprite.sprite_frames.has_animation(anim_name):
		return

	var frame_count: int = sprite.sprite_frames.get_frame_count(anim_name)
	if frame_count <= 1:
		return

	var offset_ratio: float = AnimationOffsetRegistry.calculate_offset(
		method,
		sprite.global_position,
		sprite.get_instance_id()
	)

	sprite.frame = int(offset_ratio * float(frame_count)) % frame_count
