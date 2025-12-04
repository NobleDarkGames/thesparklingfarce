extends "res://core/resources/ai_brain.gd"

class_name AIStationary

## Stationary AI: Never moves, only attacks if enemy is adjacent
##
## Behavior:
## 1. Check all adjacent cells for player units
## 2. If player found in attack range, attack
## 3. Otherwise, end turn without moving

## Override execute_async for proper async behavior
## Note: We override execute_async directly instead of execute() to avoid
## storing state in instance variables (Resources can be shared between units)
func execute_async(unit: Node2D, context: Dictionary) -> void:
	var player_units: Array[Node2D] = get_player_units(context)

	if player_units.is_empty():
		return

	# Get delay settings from context
	var delays: Dictionary = context.get("ai_delays", {})
	var delay_before_attack: float = delays.get("before_attack", 0.3)

	# Check if any player is in attack range
	for player in player_units:
		if not player.is_alive():
			continue

		if is_in_attack_range(unit, player):
			# Brief pause before initiating attack (gives player time to see enemy decision)
			if delay_before_attack > 0:
				await unit.get_tree().create_timer(delay_before_attack).timeout

			await attack_target(unit, player)
			return
