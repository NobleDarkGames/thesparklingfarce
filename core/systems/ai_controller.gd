extends Node

## AIController - Executes AI decisions for enemy/neutral units
##
## This is ENGINE CODE - AI behaviors are CONTENT (in mods/).
## Responsibilities:
## - Called by TurnManager when enemy/neutral unit's turn starts
## - Builds context dictionary with battle state
## - Interprets unit's AIBehaviorData using ConfigurableAIBrain
## - Handles turn completion after AI executes

const ConfigurableAIBrainScript = preload("res://core/systems/ai/configurable_ai_brain.gd")
const UnitUtils = preload("res://core/utils/unit_utils.gd")

## Emitted when AI turn processing completes (for test synchronization)
## Emitted BEFORE end_unit_turn so tests can check state while unit is active
signal turn_completed(unit: Unit)

## Configurable delays for enemy actions (in seconds)
@export var delay_before_turn_start: float = 0.5  # Pause before enemy starts thinking
@export var delay_after_movement: float = 0.5      # Pause after moving before attacking
@export var delay_before_attack: float = 0.3       # Brief pause before initiating attack

## Called by TurnManager when enemy/neutral unit's turn starts
func process_enemy_turn(unit: Unit) -> void:
	if not unit:
		push_error("AIController: Cannot process turn for null unit")
		return

	if not unit.is_alive():
		# Dead units don't act, end turn immediately
		turn_completed.emit(unit)
		TurnManager.end_unit_turn(unit)
		return

	# Delay before enemy starts acting (gives player time to see whose turn it is)
	# Skip in headless mode for faster automated testing
	if delay_before_turn_start > 0 and not TurnManager.is_headless:
		await get_tree().create_timer(delay_before_turn_start).timeout
		if not is_instance_valid(unit):
			return

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

	# Execute AI behavior - prefer new AIBehaviorData system
	# Use static method from preloaded script to get singleton instance
	var brain: AIBrain = ConfigurableAIBrainScript.get_instance()

	if unit.ai_behavior:
		# New data-driven system: use ConfigurableAIBrain to interpret AIBehaviorData
		await brain.execute_with_behavior(unit, context, unit.ai_behavior)
	else:
		# No AI behavior assigned - use default aggressive
		push_warning("AIController: Unit %s has no ai_behavior assigned, using default aggressive" % UnitUtils.get_display_name(unit))
		await brain.execute_async(unit, context)

	# Unit may have been freed during AI execution (counterattack kill, scene change)
	if not is_instance_valid(unit):
		return

	# Emit signal BEFORE ending turn (so tests can check state while unit is active)
	turn_completed.emit(unit)

	# End turn (only if not already ended by BattleManager during attack)
	# This handles cases where AI doesn't attack (movement only, or stationary with no targets)
	if TurnManager.active_unit == unit:
		TurnManager.end_unit_turn(unit)


## Build context dictionary with current battle state
func _build_ai_context() -> Dictionary:
	return {
		"player_units": BattleManager.player_units,
		"enemy_units": BattleManager.enemy_units,
		"neutral_units": BattleManager.neutral_units,
		"turn_number": TurnManager.turn_number,
	}
