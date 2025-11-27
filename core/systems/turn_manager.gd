## TurnManager - AGI-based turn queue system (Shining Force style)
##
## Manages individual turn order where player and enemy units are intermixed
## based on their agility stats. No separate phases - one unit acts at a time.
extends Node

## Headless mode detection - skips visual delays for automated testing
## Cached at startup for performance
var is_headless: bool = false

# Turn priority calculation constants (Shining Force II formula)
const AGI_VARIANCE_MIN: float = 0.875
const AGI_VARIANCE_MAX: float = 1.125
const AGI_OFFSET_MIN: int = -1
const AGI_OFFSET_MAX: int = 1

## Signals for turn events
signal turn_cycle_started(turn_number: int)
signal player_turn_started(unit: Node2D)
signal enemy_turn_started(unit: Node2D)
signal unit_turn_ended(unit: Node2D)
signal battle_ended(victory: bool)

## All units participating in battle (player + enemy + neutral)
var all_units: Array[Node2D] = []

## Current turn queue (sorted by AGI priority)
var turn_queue: Array[Node2D] = []

## Currently active unit
var active_unit: Node2D = null

## Overall turn counter
var turn_number: int = 0

## Battle state
var battle_active: bool = false

## Victory/defeat conditions (from BattleData)
var victory_condition: int = -1
var defeat_condition: int = -1

## Turn transition delay (allows camera pan, animations, stats panels to settle)
## This delay occurs AFTER unit_turn_ended and BEFORE next unit's turn starts
@export var turn_transition_delay: float = 0.6  # Slightly longer than camera movement_duration

## Reference to camera for awaiting visual transitions
var battle_camera: Camera2D = null

## Timing tracking for debug
var _timing_start_ms: int = 0


## Get elapsed time since battle start (for debug timing)
func _get_elapsed_time() -> String:
	var elapsed_ms: int = Time.get_ticks_msec() - _timing_start_ms
	return "[T+%.3fs]" % (elapsed_ms / 1000.0)


## Initialize battle with all units
func start_battle(units: Array[Node2D]) -> void:
	if units.is_empty():
		push_error("TurnManager: Cannot start battle with no units")
		return

	all_units = units
	turn_number = 0
	battle_active = true
	_timing_start_ms = Time.get_ticks_msec()

	print("\n=== Battle Started ===")
	print("Total units: %d" % all_units.size())

	# Start first turn cycle
	start_new_turn_cycle()


## Calculate turn priority for a unit (Shining Force II formula)
## Returns: AGI * Random(0.875 to 1.125) + Random(-1, 0, 1)
func calculate_turn_priority(unit: Node2D) -> float:
	if not unit.has_method("get_stats_summary"):
		push_warning("TurnManager: Unit missing stats")
		return 0.0

	var base_agi: float = unit.stats.agility if unit.stats else 5.0

	# Randomize AGI: 87.5% to 112.5% of base value
	var random_mult: float = randf_range(AGI_VARIANCE_MIN, AGI_VARIANCE_MAX)

	# Add small random offset: -1, 0, or +1
	var random_offset: float = float(randi_range(AGI_OFFSET_MIN, AGI_OFFSET_MAX))

	var priority: float = (base_agi * random_mult) + random_offset

	return priority


## Calculate turn order for all living units
func calculate_turn_order() -> void:
	turn_queue.clear()

	# Calculate priority for each living unit
	for unit in all_units:
		if not unit.is_alive():
			continue

		var priority: float = calculate_turn_priority(unit)
		unit.turn_priority = priority
		turn_queue.append(unit)

	# Sort by priority (highest first)
	turn_queue.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.turn_priority > b.turn_priority)

	# Debug output
	print("\n--- Turn Order Calculated ---")
	for i in range(turn_queue.size()):
		var unit: Node2D = turn_queue[i]
		var faction: String = "???"
		if unit.has_method("is_player_unit"):
			faction = "PLAYER" if unit.is_player_unit() else "ENEMY"
		print("  %d. %s (%s) - AGI %.1f → Priority %.2f" % [
			i + 1,
			unit.get_display_name(),
			faction,
			unit.stats.agility if unit.stats else 0,
			unit.turn_priority
		])


## Start a new turn cycle
func start_new_turn_cycle() -> void:
	turn_number += 1
	turn_cycle_started.emit(turn_number)

	print("\n========== TURN %d ==========" % turn_number)

	# Reset all unit visuals (remove dimming from previous round)
	for unit in all_units:
		if unit.is_alive() and unit.has_method("reset_acted_visual"):
			unit.reset_acted_visual()

	# Recalculate turn order with new AGI randomization
	calculate_turn_order()

	# Check if battle is over before starting turns
	if _check_battle_end():
		return

	# Start first unit's turn
	if not turn_queue.is_empty():
		var first_unit: Node2D = turn_queue.pop_front()
		start_unit_turn(first_unit)
	else:
		push_error("TurnManager: Turn queue is empty after calculation")
		battle_active = false


## Start a unit's turn
func start_unit_turn(unit: Node2D) -> void:
	if not unit or not unit.is_alive():
		# Skip dead units, get next
		advance_to_next_unit()
		return

	active_unit = unit
	unit.start_turn()

	print("\n%s --- %s's Turn ---" % [_get_elapsed_time(), unit.get_display_name()])

	if unit.is_player_unit():
		# Player unit - wait for player input
		print("%s Emitting player_turn_started signal" % _get_elapsed_time())
		player_turn_started.emit(unit)
		print("%s Waiting for player input..." % _get_elapsed_time())
		# InputManager will handle from here
	else:
		# Enemy/AI unit - emit signal and await visual setup completion
		print("%s Emitting enemy_turn_started signal" % _get_elapsed_time())
		enemy_turn_started.emit(unit)
		print("%s Enemy turn signal emitted, waiting for visual setup..." % _get_elapsed_time())

		# Wait for camera pan to complete (signal handlers start the camera movement)
		if battle_camera:
			print("%s Awaiting camera.movement_completed..." % _get_elapsed_time())
			await battle_camera.movement_completed
			print("%s Camera pan complete, starting AI processing..." % _get_elapsed_time())

		# Now delegate to AIController
		print("%s Delegating to AIController..." % _get_elapsed_time())
		await AIController.process_enemy_turn(unit)
		print("%s AIController returned" % _get_elapsed_time())


## End the current unit's turn
func end_unit_turn(unit: Node2D) -> void:
	if unit != active_unit:
		push_warning("TurnManager: Trying to end turn for non-active unit")
		return

	print("%s %s's turn ended" % [_get_elapsed_time(), unit.get_display_name()])

	unit.end_turn()
	print("%s Emitting unit_turn_ended signal" % _get_elapsed_time())
	unit_turn_ended.emit(unit)
	print("%s unit_turn_ended signal emitted" % _get_elapsed_time())

	active_unit = null

	# Check battle end conditions
	if _check_battle_end():
		return

	# Advance to next unit
	advance_to_next_unit()


## Advance to the next unit in queue
## Now async to allow for turn transition delay
func advance_to_next_unit() -> void:
	print("%s advance_to_next_unit() called" % _get_elapsed_time())

	# Add delay before starting next unit's turn
	# This allows camera pans, animations, and UI updates to complete
	if turn_transition_delay > 0:
		print("%s Waiting %.1fs (turn_transition_delay)..." % [_get_elapsed_time(), turn_transition_delay])
		await get_tree().create_timer(turn_transition_delay).timeout
		print("%s Turn transition delay complete" % _get_elapsed_time())

	if turn_queue.is_empty():
		# Turn cycle complete, start new cycle
		print("%s Turn queue empty, starting new cycle" % _get_elapsed_time())
		start_new_turn_cycle()
	else:
		# Get next unit
		var next_unit: Node2D = turn_queue.pop_front()
		print("%s Starting next unit's turn: %s" % [_get_elapsed_time(), next_unit.get_display_name()])
		start_unit_turn(next_unit)


## Check if battle has ended (victory or defeat)
func _check_battle_end() -> bool:
	if not battle_active:
		return true

	# Count living units by faction
	var player_count: int = 0
	var enemy_count: int = 0

	for unit in all_units:
		if not unit.is_alive():
			continue

		if unit.is_player_unit():
			player_count += 1
		elif unit.is_enemy_unit():
			enemy_count += 1

	# Check defeat (all player units dead)
	if player_count == 0:
		_end_battle(false)
		return true

	# Check victory (all enemy units dead)
	if enemy_count == 0:
		_end_battle(true)
		return true

	return false


## End the battle
func _end_battle(victory: bool) -> void:
	battle_active = false
	active_unit = null
	turn_queue.clear()

	print("\n========== BATTLE END ==========")
	if victory:
		print("VICTORY! All enemies defeated!")
	else:
		print("DEFEAT! All player units lost!")

	battle_ended.emit(victory)


## Get the currently active unit
func get_active_unit() -> Node2D:
	return active_unit


## Check if it's a player unit's turn
func is_player_turn() -> bool:
	return active_unit != null and active_unit.is_player_unit()


## Check if battle is active
func is_battle_active() -> bool:
	return battle_active


## Get remaining units in turn queue
func get_remaining_turn_queue() -> Array[Node2D]:
	return turn_queue.duplicate()


## Get turn number
func get_turn_number() -> int:
	return turn_number


## Clear battle state (call when exiting battle)
func clear_battle() -> void:
	all_units.clear()
	turn_queue.clear()
	active_unit = null
	turn_number = 0
	battle_active = false

	print("TurnManager: Battle cleared")
