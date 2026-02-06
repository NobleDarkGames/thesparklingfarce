## Status Effect Manager Integration Tests
##
## Tests status effect application, duration expiration, stat modifiers,
## and effect refresh behavior on UnitStats.
class_name TestStatusEffectManager
extends GdUnitTestSuite


const TEST_MOD_ID: String = "_test_status_effects"


# =============================================================================
# TEST LIFECYCLE
# =============================================================================

func after_test() -> void:
	# Clean up any registered test status effects
	ModLoader.status_effect_registry.unregister_mod(TEST_MOD_ID)


# =============================================================================
# TEST FIXTURES
# =============================================================================

func _create_unit_stats() -> UnitStats:
	var stats: UnitStats = UnitStats.new()
	stats.max_hp = 50
	stats.current_hp = 50
	stats.max_mp = 20
	stats.current_mp = 20
	stats.strength = 10
	stats.defense = 10
	stats.agility = 10
	stats.intelligence = 10
	stats.luck = 5
	stats.level = 1
	return stats


func _register_status_effect(
	effect_id: String,
	stat_modifiers: Dictionary = {},
	damage_per_turn: int = 0
) -> StatusEffectData:
	var effect: StatusEffectData = StatusEffectData.new()
	effect.effect_id = effect_id
	effect.display_name = effect_id.capitalize()
	# Populate the typed Dictionary[String, int] entry-by-entry since Godot 4.5
	# rejects direct assignment from an untyped Dictionary literal.
	for key: String in stat_modifiers:
		var value: int = stat_modifiers[key] as int
		effect.stat_modifiers[key] = value
	effect.damage_per_turn = damage_per_turn
	ModLoader.status_effect_registry.register_effect(effect, TEST_MOD_ID)
	return effect


# =============================================================================
# TEST: APPLYING STATUS EFFECTS
# =============================================================================

func test_apply_status_effect_adds_to_unit() -> void:
	var stats: UnitStats = _create_unit_stats()

	stats.add_status_effect("poison", 3, 5)

	assert_int(stats.status_effects.size()).is_equal(1)
	assert_bool(stats.has_status_effect("poison")).is_true()


func test_apply_multiple_different_effects() -> void:
	var stats: UnitStats = _create_unit_stats()

	stats.add_status_effect("poison", 3, 5)
	stats.add_status_effect("attack_up", 2)
	stats.add_status_effect("defense_down", 4)

	assert_int(stats.status_effects.size()).is_equal(3)
	assert_bool(stats.has_status_effect("poison")).is_true()
	assert_bool(stats.has_status_effect("attack_up")).is_true()
	assert_bool(stats.has_status_effect("defense_down")).is_true()


func test_applied_effect_has_correct_duration() -> void:
	var stats: UnitStats = _create_unit_stats()

	stats.add_status_effect("test_effect", 5, 10)

	var effect: Dictionary = stats.status_effects[0]
	assert_int(effect.get("duration", 0)).is_equal(5)
	assert_int(effect.get("potency", 0)).is_equal(10)


# =============================================================================
# TEST: STATUS EFFECT EXPIRATION
# =============================================================================

func test_status_effect_expires_after_duration() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.add_status_effect("buff", 2)  # 2 turn duration

	# Process turn 1 - duration decrements to 1
	stats.process_status_effects()
	assert_bool(stats.has_status_effect("buff")).is_true()

	# Process turn 2 - duration decrements to 0, removed
	stats.process_status_effects()
	assert_bool(stats.has_status_effect("buff")).is_false()


func test_status_effect_duration_one_expires_immediately() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.add_status_effect("short_buff", 1)

	# Process turn - effect should expire
	stats.process_status_effects()

	assert_bool(stats.has_status_effect("short_buff")).is_false()
	assert_int(stats.status_effects.size()).is_equal(0)


func test_multiple_effects_expire_independently() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.add_status_effect("short", 1)
	stats.add_status_effect("medium", 2)
	stats.add_status_effect("long", 3)

	# After 1 turn: short expires
	stats.process_status_effects()
	assert_bool(stats.has_status_effect("short")).is_false()
	assert_bool(stats.has_status_effect("medium")).is_true()
	assert_bool(stats.has_status_effect("long")).is_true()

	# After 2 turns: medium expires
	stats.process_status_effects()
	assert_bool(stats.has_status_effect("medium")).is_false()
	assert_bool(stats.has_status_effect("long")).is_true()

	# After 3 turns: long expires
	stats.process_status_effects()
	assert_bool(stats.has_status_effect("long")).is_false()
	assert_int(stats.status_effects.size()).is_equal(0)


# =============================================================================
# TEST: STAT MODIFIERS FROM STATUS EFFECTS
# =============================================================================

func test_stat_modifier_strength_buff_applies() -> void:
	_register_status_effect("strength_up", {"strength": 5})
	var stats: UnitStats = _create_unit_stats()

	stats.add_status_effect("strength_up", 3)

	assert_int(stats.get_effective_strength()).is_equal(15)  # Base 10 + 5


func test_stat_modifier_defense_debuff_applies() -> void:
	_register_status_effect("defense_down", {"defense": -3})
	var stats: UnitStats = _create_unit_stats()

	stats.add_status_effect("defense_down", 3)

	assert_int(stats.get_effective_defense()).is_equal(7)  # Base 10 - 3


func test_stat_modifier_multiple_stats_apply() -> void:
	_register_status_effect("battle_stance", {"strength": 3, "defense": -2, "agility": 2})
	var stats: UnitStats = _create_unit_stats()

	stats.add_status_effect("battle_stance", 3)

	assert_int(stats.get_effective_strength()).is_equal(13)  # Base 10 + 3
	assert_int(stats.get_effective_defense()).is_equal(8)    # Base 10 - 2
	assert_int(stats.get_effective_agility()).is_equal(12)   # Base 10 + 2


func test_stat_modifiers_stack_from_multiple_effects() -> void:
	_register_status_effect("might", {"strength": 3})
	_register_status_effect("rage", {"strength": 2})
	var stats: UnitStats = _create_unit_stats()

	stats.add_status_effect("might", 3)
	stats.add_status_effect("rage", 3)

	assert_int(stats.get_effective_strength()).is_equal(15)  # Base 10 + 3 + 2


func test_stat_modifier_clamps_to_zero() -> void:
	_register_status_effect("weaken", {"strength": -15})
	var stats: UnitStats = _create_unit_stats()

	stats.add_status_effect("weaken", 3)

	# Should clamp to 0, not go negative (base 10 - 15 = -5 -> 0)
	assert_int(stats.get_effective_strength()).is_equal(0)


# =============================================================================
# TEST: REMOVING EFFECTS RESTORES STATS
# =============================================================================

func test_remove_effect_restores_stats() -> void:
	_register_status_effect("power_up", {"strength": 5})
	var stats: UnitStats = _create_unit_stats()

	stats.add_status_effect("power_up", 3)
	assert_int(stats.get_effective_strength()).is_equal(15)

	stats.remove_status_effect("power_up")
	assert_int(stats.get_effective_strength()).is_equal(10)  # Back to base


func test_effect_expiration_restores_stats() -> void:
	_register_status_effect("temp_boost", {"defense": 4})
	var stats: UnitStats = _create_unit_stats()

	stats.add_status_effect("temp_boost", 1)  # 1 turn
	assert_int(stats.get_effective_defense()).is_equal(14)

	# Effect expires after processing
	stats.process_status_effects()
	assert_int(stats.get_effective_defense()).is_equal(10)  # Back to base


func test_remove_one_effect_preserves_others() -> void:
	_register_status_effect("buff_a", {"strength": 3})
	_register_status_effect("buff_b", {"defense": 2})
	var stats: UnitStats = _create_unit_stats()

	stats.add_status_effect("buff_a", 3)
	stats.add_status_effect("buff_b", 3)
	assert_int(stats.get_effective_strength()).is_equal(13)
	assert_int(stats.get_effective_defense()).is_equal(12)

	stats.remove_status_effect("buff_a")

	assert_int(stats.get_effective_strength()).is_equal(10)  # Restored
	assert_int(stats.get_effective_defense()).is_equal(12)   # Still buffed


# =============================================================================
# TEST: SAME EFFECT REFRESHES DURATION (NO STACKING)
# =============================================================================

func test_same_effect_refreshes_duration_not_stacks() -> void:
	var stats: UnitStats = _create_unit_stats()

	stats.add_status_effect("poison", 2, 5)
	stats.add_status_effect("poison", 4, 5)  # Same effect, longer duration

	# Should still be only one poison effect
	assert_int(stats.status_effects.size()).is_equal(1)

	# Duration should be the longer one (4)
	var effect: Dictionary = stats.status_effects[0]
	assert_int(effect.get("duration", 0)).is_equal(4)


func test_same_effect_takes_higher_potency() -> void:
	var stats: UnitStats = _create_unit_stats()

	stats.add_status_effect("poison", 3, 5)
	stats.add_status_effect("poison", 2, 10)  # Lower duration but higher potency

	assert_int(stats.status_effects.size()).is_equal(1)

	var effect: Dictionary = stats.status_effects[0]
	# Takes max of both duration and potency
	assert_int(effect.get("duration", 0)).is_equal(3)
	assert_int(effect.get("potency", 0)).is_equal(10)


func test_same_effect_does_not_stack_stat_modifiers() -> void:
	_register_status_effect("power", {"strength": 5})
	var stats: UnitStats = _create_unit_stats()

	stats.add_status_effect("power", 3)
	stats.add_status_effect("power", 3)  # Apply same effect again

	# Should NOT double the strength bonus
	assert_int(stats.get_effective_strength()).is_equal(15)  # Base 10 + 5, not + 10


# =============================================================================
# TEST: POISON AND REGEN (DAMAGE/HEAL OVER TIME)
# =============================================================================

func test_poison_deals_damage_on_process() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.current_hp = 50

	stats.add_status_effect("poison", 3, 5)  # 5 damage per turn
	stats.process_status_effects()

	assert_int(stats.current_hp).is_equal(45)  # 50 - 5


func test_regen_heals_on_process() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.current_hp = 30

	stats.add_status_effect("regen", 3, 8)  # 8 heal per turn
	stats.process_status_effects()

	assert_int(stats.current_hp).is_equal(38)  # 30 + 8


func test_regen_does_not_exceed_max_hp() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.max_hp = 50
	stats.current_hp = 48

	stats.add_status_effect("regen", 3, 10)  # Would heal to 58, should cap at 50
	stats.process_status_effects()

	assert_int(stats.current_hp).is_equal(50)


func test_poison_can_kill_unit() -> void:
	var stats: UnitStats = _create_unit_stats()
	stats.current_hp = 3

	stats.add_status_effect("poison", 3, 5)  # 5 damage, HP is only 3
	var alive: bool = stats.process_status_effects()

	assert_bool(alive).is_false()
	assert_int(stats.current_hp).is_less_equal(0)
