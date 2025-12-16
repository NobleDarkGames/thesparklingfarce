## InputManagerHelpers - Shared utilities for input handling
##
## Extracted from InputManager to reduce code duplication and improve maintainability.
## Contains:
## - Directional input parsing
## - Grid distance and cell selection utilities
## - Targeting context for unified attack/item/spell targeting
class_name InputManagerHelpers
extends RefCounted


## Targeting mode for unified targeting system
enum TargetingMode {
	ATTACK,  # Physical attack targeting (enemies only)
	ITEM,    # Item use targeting (depends on item effect)
	SPELL,   # Spell casting targeting (depends on spell type)
}


## Context object for unified targeting across attack/item/spell systems
class TargetingContext:
	var mode: TargetingMode = TargetingMode.ATTACK
	var ability_data: AbilityData = null  # null for Attack, item.effect for Item, spell for Spell
	var valid_targets: Array[Vector2i] = []
	var is_ally_targeting: bool = false  # true for heals/buffs, false for attacks/debuffs
	var has_aoe: bool = false  # true if ability has area_of_effect > 0
	var aoe_radius: int = 0  # area_of_effect radius for AoE preview

	func _init(p_mode: TargetingMode = TargetingMode.ATTACK, p_ability: AbilityData = null) -> void:
		mode = p_mode
		ability_data = p_ability
		_configure_from_ability()

	## Configure targeting properties based on ability data
	func _configure_from_ability() -> void:
		if not ability_data:
			# Attack mode - always targets enemies
			is_ally_targeting = false
			has_aoe = false
			aoe_radius = 0
			return

		# Determine ally vs enemy targeting from ability type
		match ability_data.target_type:
			AbilityData.TargetType.SELF, AbilityData.TargetType.SINGLE_ALLY, AbilityData.TargetType.ALL_ALLIES:
				is_ally_targeting = true
			_:
				is_ally_targeting = false

		# AoE configuration
		has_aoe = ability_data.area_of_effect > 0
		aoe_radius = ability_data.area_of_effect if has_aoe else 0


# =============================================================================
# DIRECTIONAL INPUT UTILITIES
# =============================================================================

## Get the direction from a pressed input event
## Returns Vector2i.ZERO if no directional input detected
static func get_pressed_direction(event: InputEvent) -> Vector2i:
	if event.is_action_pressed("ui_up"):
		return Vector2i.UP
	if event.is_action_pressed("ui_down"):
		return Vector2i.DOWN
	if event.is_action_pressed("ui_left"):
		return Vector2i.LEFT
	if event.is_action_pressed("ui_right"):
		return Vector2i.RIGHT
	return Vector2i.ZERO


## Get the direction from a held input (for continuous movement)
## Returns Vector2i.ZERO if no directional input held
static func get_held_direction() -> Vector2i:
	if Input.is_action_pressed("ui_up"):
		return Vector2i.UP
	if Input.is_action_pressed("ui_down"):
		return Vector2i.DOWN
	if Input.is_action_pressed("ui_left"):
		return Vector2i.LEFT
	if Input.is_action_pressed("ui_right"):
		return Vector2i.RIGHT
	return Vector2i.ZERO


# =============================================================================
# GRID DISTANCE AND CELL SELECTION UTILITIES
# =============================================================================

## Calculate Manhattan distance between two grid cells
static func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Get the closest cell to a position from a list of cells
## Returns 'from' if cells array is empty
static func get_closest_cell(from: Vector2i, cells: Array[Vector2i]) -> Vector2i:
	if cells.is_empty():
		return from

	var closest: Vector2i = cells[0]
	var closest_dist: int = manhattan_distance(from, closest)

	for cell in cells:
		var dist: int = manhattan_distance(from, cell)
		if dist < closest_dist:
			closest = cell
			closest_dist = dist

	return closest


## Get the farthest cell from a position (for wrap-around behavior)
## Returns 'from' if cells array is empty
static func get_farthest_cell(from: Vector2i, cells: Array[Vector2i]) -> Vector2i:
	if cells.is_empty():
		return from

	var farthest: Vector2i = cells[0]
	var farthest_dist: int = manhattan_distance(from, farthest)

	for cell in cells:
		var dist: int = manhattan_distance(from, cell)
		if dist > farthest_dist:
			farthest = cell
			farthest_dist = dist

	return farthest


## Get the next valid target in a given direction from current position
## Supports wrap-around: if no target in direction, wraps to farthest in opposite direction
## Returns current_pos if no other valid targets exist
static func get_next_target_in_direction(
	current_pos: Vector2i,
	direction: Vector2i,
	valid_targets: Array[Vector2i]
) -> Vector2i:
	if valid_targets.is_empty():
		return current_pos

	# Filter targets that are in the general direction of the input
	var candidates: Array[Vector2i] = []
	for target_cell in valid_targets:
		if target_cell == current_pos:
			continue  # Skip current target

		var delta: Vector2i = target_cell - current_pos
		var is_valid_direction: bool = false

		match direction:
			Vector2i.UP:
				is_valid_direction = delta.y < 0
			Vector2i.DOWN:
				is_valid_direction = delta.y > 0
			Vector2i.LEFT:
				is_valid_direction = delta.x < 0
			Vector2i.RIGHT:
				is_valid_direction = delta.x > 0

		if is_valid_direction:
			candidates.append(target_cell)

	# If we have candidates in that direction, return the closest one
	if not candidates.is_empty():
		return get_closest_cell(current_pos, candidates)

	# No targets in that direction - wrap around to farthest in opposite direction
	var opposite: Vector2i = -direction
	var wrap_candidates: Array[Vector2i] = []

	for target_cell in valid_targets:
		if target_cell == current_pos:
			continue

		var delta: Vector2i = target_cell - current_pos
		var is_opposite_direction: bool = false

		match opposite:
			Vector2i.UP:
				is_opposite_direction = delta.y < 0
			Vector2i.DOWN:
				is_opposite_direction = delta.y > 0
			Vector2i.LEFT:
				is_opposite_direction = delta.x < 0
			Vector2i.RIGHT:
				is_opposite_direction = delta.x > 0

		if is_opposite_direction:
			wrap_candidates.append(target_cell)

	# Return farthest in opposite direction for wrap-around
	if not wrap_candidates.is_empty():
		return get_farthest_cell(current_pos, wrap_candidates)

	# Fallback: return first other target
	for target_cell in valid_targets:
		if target_cell != current_pos:
			return target_cell

	return current_pos


## Cycle through targets sequentially (for simple up/down or left/right navigation)
## direction_sign: -1 for previous (up/left), +1 for next (down/right)
static func cycle_target(
	current_pos: Vector2i,
	direction_sign: int,
	valid_targets: Array[Vector2i]
) -> Vector2i:
	if valid_targets.is_empty():
		return current_pos

	var current_idx: int = valid_targets.find(current_pos)

	if current_idx == -1:
		# Not on a valid target - snap to first one
		return valid_targets[0]

	# Wrap around to next/previous
	var new_idx: int = wrapi(current_idx + direction_sign, 0, valid_targets.size())
	return valid_targets[new_idx]
