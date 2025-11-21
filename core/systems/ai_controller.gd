extends Node

## AIController - Executes AI decisions for enemy/neutral units
##
## This is ENGINE CODE - AI brains themselves are CONTENT (in mods/).
## Responsibilities:
## - Called by TurnManager when enemy/neutral unit's turn starts
## - Builds context dictionary with battle state
## - Delegates decision-making to unit's AIBrain resource
## - Handles turn completion after AI executes

## Called by TurnManager when enemy/neutral unit's turn starts
func process_enemy_turn(unit: Node2D) -> void:
	if not unit:
		push_error("AIController: Cannot process turn for null unit")
		return

	if not unit.is_alive():
		# Dead units don't act, end turn immediately
		print("AIController: Unit %s is dead, ending turn" % unit.get_display_name())
		TurnManager.end_unit_turn(unit)
		return

	print("\nAIController: Processing turn for %s" % unit.get_display_name())

	# Build context for AI decision-making
	var context: Dictionary = _build_ai_context()

	# Execute AI brain if available
	if unit.ai_brain:
		print("AIController: Using AI brain: %s" % unit.ai_brain.get_class())
		unit.ai_brain.execute(unit, context)
	else:
		# No AI brain assigned - log warning
		push_warning("AIController: Unit %s has no ai_brain assigned, ending turn" % unit.get_display_name())

	# AI execution is synchronous for Phase 3
	# Phase 4 may add async animations requiring await

	# Small delay for visibility during testing
	await get_tree().create_timer(0.3).timeout

	# End turn (only if not already ended by BattleManager during attack)
	# This handles cases where AI doesn't attack (movement only, or stationary with no targets)
	if TurnManager.active_unit == unit:
		print("AIController: Ending turn for %s" % unit.get_display_name())
		TurnManager.end_unit_turn(unit)


## Build context dictionary with current battle state
func _build_ai_context() -> Dictionary:
	return {
		"player_units": BattleManager.player_units,
		"enemy_units": BattleManager.enemy_units,
		"neutral_units": BattleManager.neutral_units,
		"turn_number": TurnManager.turn_number,
	}
