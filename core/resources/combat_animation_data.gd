class_name CombatAnimationData
extends Resource

## Defines visual appearance and animations for a character in combat animation screen.
## This resource allows characters to have custom battle sprites and animations.
## If not assigned to a character, the system will use placeholder graphics.

## Static sprite option (simplest - single image for character)
@export var battle_sprite: Texture2D

## Animated sprite option (advanced - full sprite sheet with animations)
@export var battle_sprite_frames: SpriteFrames

## Animation state names (only used if battle_sprite_frames is set)
@export var idle_animation: String = "idle"
@export var attack_animation: String = "attack"
@export var hurt_animation: String = "hurt"
@export var critical_animation: String = "critical"
@export var death_animation: String = "death"

## Visual adjustments
@export var sprite_scale: float = 3.0  ## Battle sprites are typically larger than map sprites
@export var sprite_offset: Vector2 = Vector2.ZERO  ## Fine-tune positioning if needed

## Animation phase offset settings (classic 16-bit desync effect)
## Controls how this character's idle animation is offset from others
@export_enum("none", "random", "clustered", "position_based", "instance_id") var animation_offset_type: String = "random"

## Optional weapon overlay (for showing equipped weapon separately)
@export var weapon_sprite: Texture2D
@export var weapon_offset: Vector2 = Vector2.ZERO
