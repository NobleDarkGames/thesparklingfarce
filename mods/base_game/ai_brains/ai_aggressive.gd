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

	# If already in attack range, attack (with brief delay for player to see decision)
	if is_in_attack_range(unit, target):
		print("AIAggressive: Target in range, attacking")
		_pending_attack_target = target  # Store for delayed execution
		return

	# Move toward target
	print("AIAggressive: Moving toward target")
	var moved: bool = move_toward_target(unit, target.grid_position)

	if moved:
		print("AIAggressive: Moved to %s" % unit.grid_position)
		# Store the movement tween reference before attacking
		_stored_movement_tween = unit._movement_tween
	else:
		print("AIAggressive: Could not move closer")

	# Check if now in range after moving
	if is_in_attack_range(unit, target):
		print("AIAggressive: Now in range after movement, will attack after movement completes")
		# Don't attack yet - wait for movement first
		_pending_attack_target = target
	else:
		print("AIAggressive: Not in range, turn ends")


# Store tween and pending attack for async execution
var _stored_movement_tween: Tween = null
var _pending_attack_target: Node2D = null


# Override execute_async to wait for movement before attacking
func execute_async(unit: Node2D, context: Dictionary) -> void:
	# Clear previous state
	_stored_movement_tween = null
	_pending_attack_target = null

	# Get delay settings from context
	var delays: Dictionary = context.get("ai_delays", {})
	var delay_after_movement: float = delays.get("after_movement", 0.5)
	var delay_before_attack: float = delays.get("before_attack", 0.3)

	print("DEBUG [TO REMOVE]: AIAggressive execute_async called for %s" % unit.character_data.character_name)  # DEBUG: TO REMOVE

	# Run the synchronous logic
	execute(unit, context)

	# Wait for movement animation if there was one
	if _stored_movement_tween and _stored_movement_tween.is_valid():
		print("DEBUG [TO REMOVE]: Waiting for %s movement animation before attacking" % unit.character_data.character_name)  # DEBUG: TO REMOVE
		await _stored_movement_tween.finished
		print("DEBUG [TO REMOVE]: Movement animation finished for %s" % unit.character_data.character_name)  # DEBUG: TO REMOVE

		# Add delay after movement completes
		if delay_after_movement > 0 and _pending_attack_target:
			await unit.get_tree().create_timer(delay_after_movement).timeout

	# Execute pending attack (either after movement or immediate)
	if _pending_attack_target:
		# Brief pause before initiating attack (gives player time to see enemy decision)
		if delay_before_attack > 0:
			await unit.get_tree().create_timer(delay_before_attack).timeout

		print("AIAggressive: Executing attack")
		await attack_target(unit, _pending_attack_target)
		_pending_attack_target = null
