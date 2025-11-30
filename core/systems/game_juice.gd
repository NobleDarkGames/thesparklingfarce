## GameJuice - Centralized game feel settings and utilities
##
## Controls animation speed multipliers, screen shake intensity, and other
## "juice" settings that make the game feel polished and responsive.
## All settings are modder-friendly with exported variables.
##
## Usage:
##   var duration: float = GameJuice.get_adjusted_duration(0.4)
##   if GameJuice.should_skip_combat_animation():
##       # Skip to damage application
##   GameJuice.screen_shake_requested.emit(6.0, 0.3)

extends Node

## Emitted when screen shake is requested (intensity, duration)
signal screen_shake_requested(intensity: float, duration: float)

## Combat animation display modes
enum CombatAnimationMode {
	FULL,      ## Show full combat animation with all effects
	FAST,      ## Play at 2x speed
	MAP_ONLY,  ## Skip animation entirely, show damage on map
}

## General animation speed multiplier (1.0 = normal, 2.0 = 2x speed)
## Affects UI animations, HP bars, menu transitions, etc.
@export var animation_speed: float = 1.0

## Combat-specific animation mode
@export var combat_animation_mode: CombatAnimationMode = CombatAnimationMode.FULL

## Screen shake intensity multiplier (0.0 = disabled, 1.0 = normal)
@export var screen_shake_intensity: float = 1.0

## Whether HP/MP bars animate smoothly or change instantly
@export var animate_stat_bars: bool = true

## Cursor bob animation enabled
@export var animate_cursor: bool = true


## Get duration adjusted by animation speed setting
## Returns near-instant (0.01) if speed is 0 or negative
func get_adjusted_duration(base_duration: float) -> float:
	if animation_speed <= 0.0:
		return 0.01  # Near-instant, avoids division issues
	return base_duration / animation_speed


## Get combat animation speed multiplier based on mode
func get_combat_speed_multiplier() -> float:
	match combat_animation_mode:
		CombatAnimationMode.FULL:
			return 1.0
		CombatAnimationMode.FAST:
			return 2.0
		CombatAnimationMode.MAP_ONLY:
			return 0.0
	return 1.0


## Check if combat animations should be skipped entirely
func should_skip_combat_animation() -> bool:
	return combat_animation_mode == CombatAnimationMode.MAP_ONLY


## Request screen shake (respects intensity setting)
## Emits screen_shake_requested signal for camera controllers to handle
func request_screen_shake(base_intensity: float, duration: float) -> void:
	if screen_shake_intensity <= 0.0:
		return  # Shake disabled

	var adjusted_intensity: float = base_intensity * screen_shake_intensity
	screen_shake_requested.emit(adjusted_intensity, duration)


## Create a tween with duration adjusted by animation speed
## Convenience method for common pattern
func create_adjusted_tween(node: Node, base_duration: float) -> Dictionary:
	var tween: Tween = node.create_tween()
	var duration: float = get_adjusted_duration(base_duration)
	return {"tween": tween, "duration": duration}
