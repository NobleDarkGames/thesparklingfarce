extends "res://core/resources/ai_brain.gd"

class_name AIStationary

## Stationary AI: Never moves, only attacks if enemy is adjacent
##
## Behavior:
## 1. Check all adjacent cells for player units
## 2. If player found in attack range, attack
## 3. Otherwise, end turn without moving

func execute(unit: Node2D, context: Dictionary) -> void:
	var player_units: Array[Node2D] = get_player_units(context)

	if player_units.is_empty():
		print("AIStationary: No player units found, ending turn")
		return

	print("AIStationary: %s checking for adjacent targets" % unit.get_display_name())

	# Check if any player is in attack range
	for player in player_units:
		if not player.is_alive():
			continue

		if is_in_attack_range(unit, player):
			print("AIStationary: Found target in range: %s" % player.get_display_name())
			_pending_attack_target = player  # Store for delayed execution
			return

	# No targets in range, end turn without moving
	print("AIStationary: No targets in range, staying in place")


# Store pending attack for async execution
var _pending_attack_target: Node2D = null


# Override execute_async to await attack
func execute_async(unit: Node2D, context: Dictionary) -> void:
	# Clear previous state
	_pending_attack_target = null

	# Get delay settings from context
	var delays: Dictionary = context.get("ai_delays", {})
	var delay_before_attack: float = delays.get("before_attack", 0.3)

	# Run the synchronous logic
	execute(unit, context)

	# Execute pending attack if target was found
	if _pending_attack_target:
		# Brief pause before initiating attack (gives player time to see enemy decision)
		if delay_before_attack > 0:
			await unit.get_tree().create_timer(delay_before_attack).timeout

		print("AIStationary: Executing attack")
		await attack_target(unit, _pending_attack_target)
		_pending_attack_target = null
