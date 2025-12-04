extends "res://core/resources/ai_brain.gd"

class_name AIAggressive

## Aggressive AI: Always moves toward nearest player and attacks
##
## Behavior:
## 1. Find nearest living player unit
## 2. If in attack range, attack immediately
## 3. Otherwise, move as close as possible
## 4. After moving, attack if now in range

## Override execute_async for proper async behavior with movement and attacks
## Note: We override execute_async directly instead of execute() to avoid
## storing state in instance variables (Resources can be shared between units)
func execute_async(unit: Node2D, context: Dictionary) -> void:
	var player_units: Array[Node2D] = get_player_units(context)

	if player_units.is_empty():
		return

	# Find nearest player
	var target: Node2D = find_nearest_target(unit, player_units)
	if not target:
		return

	# Get delay settings from context
	var delays: Dictionary = context.get("ai_delays", {})
	var delay_after_movement: float = delays.get("after_movement", 0.5)
	var delay_before_attack: float = delays.get("before_attack", 0.3)

	# If already in attack range, attack immediately
	if is_in_attack_range(unit, target):
		if delay_before_attack > 0:
			await unit.get_tree().create_timer(delay_before_attack).timeout
		await attack_target(unit, target)
		return

	# Move toward target
	var moved: bool = move_toward_target(unit, target.grid_position)

	# Wait for movement animation to complete using the proper public interface
	if moved:
		await unit.await_movement_completion()

		# Add delay after movement completes before attacking
		if delay_after_movement > 0:
			await unit.get_tree().create_timer(delay_after_movement).timeout

	# Check if now in range after moving
	if is_in_attack_range(unit, target):
		if delay_before_attack > 0:
			await unit.get_tree().create_timer(delay_before_attack).timeout
		await attack_target(unit, target)
