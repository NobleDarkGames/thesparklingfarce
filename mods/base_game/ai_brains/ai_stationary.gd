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
			attack_target(unit, player)
			return

	# No targets in range, end turn without moving
	print("AIStationary: No targets in range, staying in place")
