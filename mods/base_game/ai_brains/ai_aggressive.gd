extends "res://core/resources/ai_brain.gd"

class_name AIAggressive

## Aggressive AI: Always moves toward nearest player and attacks
##
## Behavior:
## 1. Find nearest living player unit
## 2. If in attack range, attack immediately
## 3. Otherwise, move as close as possible
## 4. After moving, attack if now in range

func execute(unit: Node2D, context: Dictionary) -> void:
	var player_units: Array[Node2D] = get_player_units(context)

	if player_units.is_empty():
		print("AIAggressive: No player units found, ending turn")
		return

	# Find nearest player
	var target: Node2D = find_nearest_target(unit, player_units)
	if not target:
		print("AIAggressive: No valid target found, ending turn")
		return

	print("AIAggressive: %s targeting %s" % [unit.get_display_name(), target.get_display_name()])

	# If already in attack range, attack immediately
	if is_in_attack_range(unit, target):
		print("AIAggressive: Target in range, attacking")
		attack_target(unit, target)
		return

	# Move toward target
	print("AIAggressive: Moving toward target")
	var moved: bool = move_toward_target(unit, target.grid_position)

	if moved:
		print("AIAggressive: Moved to %s" % unit.grid_position)
	else:
		print("AIAggressive: Could not move closer")

	# Check if now in range after moving
	if is_in_attack_range(unit, target):
		print("AIAggressive: Now in range after movement, attacking")
		attack_target(unit, target)
	else:
		print("AIAggressive: Not in range, turn ends")
