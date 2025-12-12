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
signal hero_died_in_battle()  ## SF2: Hero death triggers immediate battle exit

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


func _ready() -> void:
	# Detect headless mode for automated testing (skips visual delays)
	is_headless = DisplayServer.get_name() == "headless"


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


## Start a new turn cycle
func start_new_turn_cycle() -> void:
	turn_number += 1
	turn_cycle_started.emit(turn_number)

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

	# Process terrain effects BEFORE unit.start_turn() (damage happens at turn start)
	var unit_died: bool = await _process_terrain_effects(unit)
	if unit_died:
		# Unit died from terrain damage - skip their turn
		unit_turn_ended.emit(unit)
		advance_to_next_unit()
		return

	unit.start_turn()

	if unit.is_player_unit():
		# Player unit - wait for player input
		player_turn_started.emit(unit)
		# InputManager will handle from here
	else:
		# Enemy/AI unit - emit signal and await visual setup completion
		enemy_turn_started.emit(unit)

		# Wait for camera pan to complete (signal handlers start the camera movement)
		if battle_camera:
			await battle_camera.movement_completed

		# Now delegate to AIController
		await AIController.process_enemy_turn(unit)


## End the current unit's turn
func end_unit_turn(unit: Node2D) -> void:
	if unit != active_unit:
		push_warning("TurnManager: Trying to end turn for non-active unit")
		return

	unit.end_turn()
	unit_turn_ended.emit(unit)

	active_unit = null

	# Check battle end conditions
	if _check_battle_end():
		return

	# Advance to next unit
	advance_to_next_unit()


## Advance to the next unit in queue
## Now async to allow for turn transition delay
func advance_to_next_unit() -> void:
	# Add delay before starting next unit's turn
	# This allows camera pans, animations, and UI updates to complete
	# Skip in headless mode for faster automated testing
	if turn_transition_delay > 0 and not is_headless:
		await get_tree().create_timer(turn_transition_delay).timeout

	if turn_queue.is_empty():
		# Turn cycle complete, start new cycle
		start_new_turn_cycle()
	else:
		# Get next unit
		var next_unit: Node2D = turn_queue.pop_front()
		start_unit_turn(next_unit)


## Check if battle has ended (victory or defeat)
func _check_battle_end() -> bool:
	if not battle_active:
		return true

	# Count living units by faction and track hero status
	var player_count: int = 0
	var enemy_count: int = 0
	var hero_alive: bool = false

	for unit in all_units:
		if not unit.is_alive():
			continue

		if unit.is_player_unit():
			player_count += 1
			# Check if this unit is the hero
			if unit.character_data and unit.character_data.is_hero:
				hero_alive = true
		elif unit.is_enemy_unit():
			enemy_count += 1

	# SF2-authentic: Hero death = immediate defeat (regardless of party composition)
	if not hero_alive:
		active_unit = null
		turn_queue.clear()
		hero_died_in_battle.emit()
		return true

	# Victory: all enemies dead
	if enemy_count == 0:
		_end_battle(true)
		return true

	return false


## End the battle
func _end_battle(victory: bool) -> void:
	battle_active = false
	active_unit = null
	turn_queue.clear()

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


## Process terrain effects for a unit at the start of their turn
## Returns true if the unit died from terrain damage
func _process_terrain_effects(unit: Node2D) -> bool:
	if not unit or not unit.is_alive():
		return false

	# Get terrain at unit's position
	var terrain: TerrainData = GridManager.get_terrain_at_cell(unit.grid_position)
	if terrain == null:
		return false

	# Flying units are immune to ground-based terrain damage
	var unit_class: ClassData = unit.get_current_class()
	if unit_class:
		var movement_type: int = unit_class.movement_type
		if movement_type == ClassData.MovementType.FLYING:
			return false  # Flying units ignore terrain DoT

	# Apply terrain damage
	if terrain.damage_per_turn > 0:
		# Show damage popup (if available and not headless)
		if not is_headless:
			_show_terrain_damage_popup(unit, terrain.damage_per_turn, terrain.display_name)

		# Apply the damage
		if unit.has_method("take_damage"):
			unit.take_damage(terrain.damage_per_turn)
		elif unit.stats:
			unit.stats.current_hp -= terrain.damage_per_turn
			unit.stats.current_hp = maxi(0, unit.stats.current_hp)

		# Check if unit died
		if unit.has_method("is_dead"):
			if unit.is_dead():
				return true
		elif unit.stats and unit.stats.current_hp <= 0:
			return true

	# NOTE: healing_per_turn is DEFERRED per Commander Claudius's simplifications
	# The field exists in TerrainData but we don't process it yet

	return false


## Show a damage popup for terrain effects
func _show_terrain_damage_popup(unit: Node2D, damage: int, terrain_name: String) -> void:
	# Create a simple damage label at unit position
	# This is a basic implementation - can be enhanced with GameJuice later
	var label: Label = Label.new()
	label.text = "-%d (%s)" % [damage, terrain_name]
	label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # Red
	label.add_theme_font_size_override("font_size", 16)
	label.position = unit.position + Vector2(0, -20)
	label.z_index = 100

	# Add to scene tree
	if unit.get_parent():
		unit.get_parent().add_child(label)

		# Animate and remove
		var tween: Tween = label.create_tween()
		tween.tween_property(label, "position:y", label.position.y - 30, 0.8)
		tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
		tween.tween_callback(label.queue_free)


## Clear battle state (call when exiting battle)
func clear_battle() -> void:
	all_units.clear()
	turn_queue.clear()
	active_unit = null
	turn_number = 0
	battle_active = false
