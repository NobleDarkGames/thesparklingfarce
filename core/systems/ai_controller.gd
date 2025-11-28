extends Node

## AIController - Executes AI decisions for enemy/neutral units
##
## This is ENGINE CODE - AI brains themselves are CONTENT (in mods/).
## Responsibilities:
## - Called by TurnManager when enemy/neutral unit's turn starts
## - Builds context dictionary with battle state
## - Delegates decision-making to unit's AIBrain resource
## - Handles turn completion after AI executes

## Configurable delays for enemy actions (in seconds)
@export var delay_before_turn_start: float = 0.5  # Pause before enemy starts thinking
@export var delay_after_movement: float = 0.5      # Pause after moving before attacking
@export var delay_before_attack: float = 0.3       # Brief pause before initiating attack

## Called by TurnManager when enemy/neutral unit's turn starts
func process_enemy_turn(unit: Node2D) -> void:
	if not unit:
		push_error("AIController: Cannot process turn for null unit")
		return

	if not unit.is_alive():
		# Dead units don't act, end turn immediately
		print("%s AIController: Unit %s is dead, ending turn" % [TurnManager._get_elapsed_time(), unit.get_display_name()])
		TurnManager.end_unit_turn(unit)
		return

	print("%s AIController: Processing turn for %s" % [TurnManager._get_elapsed_time(), unit.get_display_name()])

	# Delay before enemy starts acting (gives player time to see whose turn it is)
	# Skip in headless mode for faster automated testing
	if delay_before_turn_start > 0 and not TurnManager.is_headless:
		print("%s AIController: Waiting %.1fs before AI processing..." % [TurnManager._get_elapsed_time(), delay_before_turn_start])
		await get_tree().create_timer(delay_before_turn_start).timeout
		print("%s AIController: Pre-turn delay complete" % TurnManager._get_elapsed_time())

	# Build context for AI decision-making
	var context: Dictionary = _build_ai_context()

	# Pass delay settings to AI brain via context (0 in headless mode)
	if TurnManager.is_headless:
		context["ai_delays"] = {
			"after_movement": 0.0,
			"before_attack": 0.0,
		}
	else:
		context["ai_delays"] = {
			"after_movement": delay_after_movement,
			"before_attack": delay_before_attack,
		}

	# Execute AI brain if available
	if unit.ai_brain:
		print("%s AIController: Using AI brain: %s" % [TurnManager._get_elapsed_time(), unit.ai_brain.get_class()])
		await unit.ai_brain.execute_async(unit, context)
		print("%s AIController: AI brain execution complete" % TurnManager._get_elapsed_time())
	else:
		# No AI brain assigned - log warning
		push_warning("AIController: Unit %s has no ai_brain assigned, ending turn" % unit.get_display_name())

	# End turn (only if not already ended by BattleManager during attack)
	# This handles cases where AI doesn't attack (movement only, or stationary with no targets)
	if TurnManager.active_unit == unit:
		print("%s AIController: Ending turn for %s" % [TurnManager._get_elapsed_time(), unit.get_display_name()])
		TurnManager.end_unit_turn(unit)
	else:
		print("%s AIController: Turn already ended (by combat), skipping end_unit_turn" % TurnManager._get_elapsed_time())


## Build context dictionary with current battle state
func _build_ai_context() -> Dictionary:
	return {
		"player_units": BattleManager.player_units,
		"enemy_units": BattleManager.enemy_units,
		"neutral_units": BattleManager.neutral_units,
		"turn_number": TurnManager.turn_number,
	}
