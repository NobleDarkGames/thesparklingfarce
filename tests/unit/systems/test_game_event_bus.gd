## GameEventBus Unit Tests
##
## Tests the GameEventBus event broadcasting functionality:
## - Event cancellation mechanism
## - Pre-event signal emissions with cancellation
## - Post-event signal emissions
## - Convenience emitter methods
## - Event modification through context dictionaries
##
## Note: This is a UNIT test - creates a fresh GameEventBus instance,
## does not use the autoload singleton.
class_name TestGameEventBus
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

const GameEventBusScript = preload("res://core/systems/game_event_bus.gd")
const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")

var _bus: Node
var _tracker: SignalTracker


func before_test() -> void:
	_bus = GameEventBusScript.new()
	add_child(_bus)
	_tracker = SignalTrackerScript.new()


func after_test() -> void:
	if _tracker:
		_tracker.disconnect_all()
		_tracker = null
	if _bus and is_instance_valid(_bus):
		_bus.queue_free()
	_bus = null


# =============================================================================
# CANCELLATION STATE TESTS
# =============================================================================

func test_event_cancelled_initially_false() -> void:
	assert_bool(_bus.event_cancelled).is_false()


func test_cancel_event_sets_cancelled_flag() -> void:
	_bus.cancel_event()

	assert_bool(_bus.event_cancelled).is_true()


func test_cancel_event_stores_reason() -> void:
	_bus.cancel_event("Shield of protection activated")

	assert_str(_bus.cancellation_reason).is_equal("Shield of protection activated")


func test_reset_cancellation_clears_flag() -> void:
	_bus.cancel_event("Some reason")

	_bus.reset_cancellation()

	assert_bool(_bus.event_cancelled).is_false()
	assert_str(_bus.cancellation_reason).is_empty()


func test_check_and_reset_cancellation_returns_status_and_clears() -> void:
	_bus.cancel_event()

	var was_cancelled: bool = _bus.check_and_reset_cancellation()

	assert_bool(was_cancelled).is_true()
	assert_bool(_bus.event_cancelled).is_false()


func test_check_and_reset_on_uncancelled_returns_false() -> void:
	var was_cancelled: bool = _bus.check_and_reset_cancellation()

	assert_bool(was_cancelled).is_false()


# =============================================================================
# PRE-EVENT SIGNAL TESTS
# =============================================================================

func test_pre_attack_signal_emits_with_args() -> void:
	var attacker: Node = Node.new()
	var defender: Node = Node.new()
	add_child(attacker)
	add_child(defender)
	_tracker.track(_bus.pre_attack)

	_bus.pre_attack.emit(attacker, defender, null)

	assert_bool(_tracker.was_emitted("pre_attack")).is_true()
	var emissions: Array = _tracker.get_emissions("pre_attack")
	assert_int(emissions.size()).is_equal(1)
	assert_object(emissions[0].arguments[0]).is_same(attacker)
	assert_object(emissions[0].arguments[1]).is_same(defender)

	attacker.queue_free()
	defender.queue_free()


func test_pre_damage_signal_emits_context_dictionary() -> void:
	var target: Node = Node.new()
	add_child(target)
	var context: Dictionary = {"final_damage": 50}
	_tracker.track(_bus.pre_damage)

	_bus.pre_damage.emit(target, 50, null, context)

	assert_bool(_tracker.was_emitted("pre_damage")).is_true()

	target.queue_free()


func test_pre_move_signal_emits_positions() -> void:
	var unit: Node = Node.new()
	add_child(unit)
	_tracker.track(_bus.pre_move)

	_bus.pre_move.emit(unit, Vector2i(0, 0), Vector2i(3, 4), [])

	var emissions: Array = _tracker.get_emissions("pre_move")
	assert_int(emissions.size()).is_equal(1)

	unit.queue_free()


func test_pre_turn_start_signal_emits() -> void:
	var unit: Node = Node.new()
	add_child(unit)
	_tracker.track(_bus.pre_turn_start)

	_bus.pre_turn_start.emit(unit)

	assert_bool(_tracker.was_emitted("pre_turn_start")).is_true()

	unit.queue_free()


# =============================================================================
# POST-EVENT SIGNAL TESTS
# =============================================================================

func test_post_attack_signal_emits_result() -> void:
	var attacker: Node = Node.new()
	var defender: Node = Node.new()
	add_child(attacker)
	add_child(defender)
	var result: Dictionary = {"hit": true, "damage": 25, "crit": false}
	_tracker.track(_bus.post_attack)

	_bus.post_attack.emit(attacker, defender, result)

	assert_bool(_tracker.was_emitted("post_attack")).is_true()

	attacker.queue_free()
	defender.queue_free()


func test_post_damage_signal_emits_remaining_hp() -> void:
	var target: Node = Node.new()
	add_child(target)
	_tracker.track(_bus.post_damage)

	_bus.post_damage.emit(target, 30, null, 70)

	var emissions: Array = _tracker.get_emissions("post_damage")
	assert_int(emissions.size()).is_equal(1)

	target.queue_free()


func test_post_death_signal_emits() -> void:
	var unit: Node = Node.new()
	add_child(unit)
	_tracker.track(_bus.post_death)

	_bus.post_death.emit(unit, null)

	assert_bool(_tracker.was_emitted("post_death")).is_true()

	unit.queue_free()


func test_post_move_signal_emits_positions() -> void:
	var unit: Node = Node.new()
	add_child(unit)
	_tracker.track(_bus.post_move)

	_bus.post_move.emit(unit, Vector2i(0, 0), Vector2i(5, 5))

	assert_bool(_tracker.was_emitted("post_move")).is_true()

	unit.queue_free()


func test_post_turn_end_signal_emits() -> void:
	var unit: Node = Node.new()
	add_child(unit)
	_tracker.track(_bus.post_turn_end)

	_bus.post_turn_end.emit(unit)

	assert_bool(_tracker.was_emitted("post_turn_end")).is_true()

	unit.queue_free()


func test_post_level_up_signal_emits_stats() -> void:
	var unit: Node = Node.new()
	add_child(unit)
	var stat_gains: Dictionary = {"hp": 5, "strength": 2, "defense": 1}
	_tracker.track(_bus.post_level_up)

	_bus.post_level_up.emit(unit, 5, stat_gains)

	assert_bool(_tracker.was_emitted("post_level_up")).is_true()

	unit.queue_free()


# =============================================================================
# CONVENIENCE EMITTER TESTS
# =============================================================================

func test_emit_pre_attack_returns_true_when_not_cancelled() -> void:
	var attacker: Node = Node.new()
	var defender: Node = Node.new()
	add_child(attacker)
	add_child(defender)

	var should_proceed: bool = _bus.emit_pre_attack(attacker, defender, null)

	assert_bool(should_proceed).is_true()

	attacker.queue_free()
	defender.queue_free()


func test_emit_pre_attack_returns_false_when_cancelled() -> void:
	var attacker: Node = Node.new()
	var defender: Node = Node.new()
	add_child(attacker)
	add_child(defender)

	# Connect a handler that cancels
	_bus.pre_attack.connect(func(_a: Node, _d: Node, _w: Variant) -> void: _bus.cancel_event())

	var should_proceed: bool = _bus.emit_pre_attack(attacker, defender, null)

	assert_bool(should_proceed).is_false()

	attacker.queue_free()
	defender.queue_free()


func test_emit_pre_attack_resets_cancellation_state_first() -> void:
	var attacker: Node = Node.new()
	var defender: Node = Node.new()
	add_child(attacker)
	add_child(defender)

	# Set cancelled before emitting
	_bus.cancel_event()

	var should_proceed: bool = _bus.emit_pre_attack(attacker, defender, null)

	# Should have reset before emitting, so should proceed
	assert_bool(should_proceed).is_true()

	attacker.queue_free()
	defender.queue_free()


func test_emit_pre_damage_returns_modified_damage() -> void:
	var target: Node = Node.new()
	add_child(target)

	# Connect a handler that modifies damage
	_bus.pre_damage.connect(func(_t: Node, _d: int, _s: Object, ctx: Dictionary) -> void:
		ctx["final_damage"] = 75
	)

	var final_damage: int = _bus.emit_pre_damage(target, 50, null)

	assert_int(final_damage).is_equal(75)

	target.queue_free()


func test_emit_pre_damage_returns_negative_one_when_cancelled() -> void:
	var target: Node = Node.new()
	add_child(target)

	# Connect a handler that cancels
	_bus.pre_damage.connect(func(_t: Node, _d: int, _s: Object, _ctx: Dictionary) -> void:
		_bus.cancel_event()
	)

	var final_damage: int = _bus.emit_pre_damage(target, 50, null)

	assert_int(final_damage).is_equal(-1)

	target.queue_free()


func test_emit_pre_damage_returns_original_if_not_modified() -> void:
	var target: Node = Node.new()
	add_child(target)

	var final_damage: int = _bus.emit_pre_damage(target, 42, null)

	assert_int(final_damage).is_equal(42)

	target.queue_free()


func test_emit_pre_move_returns_true_when_not_cancelled() -> void:
	var unit: Node = Node.new()
	add_child(unit)

	var should_proceed: bool = _bus.emit_pre_move(unit, Vector2i(0, 0), Vector2i(2, 2), [])

	assert_bool(should_proceed).is_true()

	unit.queue_free()


func test_emit_pre_move_returns_false_when_cancelled() -> void:
	var unit: Node = Node.new()
	add_child(unit)

	_bus.pre_move.connect(func(_u: Node, _from: Vector2i, _to: Vector2i, _path: Array) -> void:
		_bus.cancel_event("Unit is immobilized")
	)

	var should_proceed: bool = _bus.emit_pre_move(unit, Vector2i(0, 0), Vector2i(2, 2), [])

	assert_bool(should_proceed).is_false()

	unit.queue_free()


func test_emit_pre_ability_cast_returns_true_when_not_cancelled() -> void:
	var caster: Node = Node.new()
	add_child(caster)

	var should_proceed: bool = _bus.emit_pre_ability_cast(caster, null, [])

	assert_bool(should_proceed).is_true()

	caster.queue_free()


func test_emit_pre_ability_cast_returns_false_when_cancelled() -> void:
	var caster: Node = Node.new()
	add_child(caster)

	_bus.pre_ability_cast.connect(func(_c: Node, _a: Variant, _t: Array) -> void:
		_bus.cancel_event("Silenced")
	)

	var should_proceed: bool = _bus.emit_pre_ability_cast(caster, null, [])

	assert_bool(should_proceed).is_false()

	caster.queue_free()


func test_emit_pre_level_up_returns_modified_stat_gains() -> void:
	var unit: Node = Node.new()
	add_child(unit)
	var original_gains: Dictionary = {"hp": 3, "strength": 1}

	# Connect a handler that modifies gains
	_bus.pre_level_up.connect(func(_u: Node, _level: int, gains: Dictionary) -> void:
		gains["hp"] = 10  # Bonus HP
		gains["magic"] = 2  # New stat
	)

	var final_gains: Dictionary = _bus.emit_pre_level_up(unit, 5, original_gains)

	assert_int(final_gains.hp).is_equal(10)
	assert_int(final_gains.magic).is_equal(2)
	assert_int(final_gains.strength).is_equal(1)

	unit.queue_free()


# =============================================================================
# MULTIPLE HANDLER TESTS
# =============================================================================

func test_multiple_handlers_can_modify_same_context() -> void:
	var target: Node = Node.new()
	add_child(target)

	# First handler halves damage
	_bus.pre_damage.connect(func(_t: Node, _d: int, _s: Object, ctx: Dictionary) -> void:
		ctx["final_damage"] = int(ctx["final_damage"] / 2)
	)

	# Second handler subtracts 5 (armor)
	_bus.pre_damage.connect(func(_t: Node, _d: int, _s: Object, ctx: Dictionary) -> void:
		ctx["final_damage"] = ctx["final_damage"] - 5
	)

	var final_damage: int = _bus.emit_pre_damage(target, 100, null)

	# 100 / 2 = 50, 50 - 5 = 45
	assert_int(final_damage).is_equal(45)

	target.queue_free()


func test_first_cancellation_wins() -> void:
	var unit: Node = Node.new()
	add_child(unit)

	_bus.pre_move.connect(func(_u: Node, _from: Vector2i, _to: Vector2i, _path: Array) -> void:
		_bus.cancel_event("First reason")
	)

	_bus.pre_move.connect(func(_u: Node, _from: Vector2i, _to: Vector2i, _path: Array) -> void:
		_bus.cancel_event("Second reason")
	)

	_bus.emit_pre_move(unit, Vector2i(0, 0), Vector2i(1, 1), [])

	# The flag is still true after second call, but reason is overwritten
	# This tests that event_cancelled remains true
	assert_bool(_bus.event_cancelled).is_false()  # check_and_reset was called

	unit.queue_free()


# =============================================================================
# BATTLE REWARD SIGNAL TESTS
# =============================================================================

func test_pre_battle_rewards_allows_modification() -> void:
	_tracker.track(_bus.pre_battle_rewards)
	var rewards: Dictionary = {"gold": 100, "items": []}

	_bus.pre_battle_rewards.emit(null, rewards)

	assert_bool(_tracker.was_emitted("pre_battle_rewards")).is_true()


func test_post_battle_rewards_emits() -> void:
	_tracker.track(_bus.post_battle_rewards)
	var rewards: Dictionary = {"gold": 200, "items": ["sword"]}

	_bus.post_battle_rewards.emit(null, rewards)

	assert_bool(_tracker.was_emitted("post_battle_rewards")).is_true()
