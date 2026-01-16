## ExperienceManager Integration Test
##
## Tests the ExperienceManager autoload functionality:
## - Combat XP awards (damage, kills, formation)
## - Support XP awards (healing, buffs, debuffs)
## - Level-up mechanics (stat increases, ability learning)
## - Configuration handling
## - Signal emissions
class_name TestExperienceManager
extends GdUnitTestSuite

const GridSetupScript = preload("res://tests/fixtures/grid_setup.gd")
const TEST_MOD_ID: String = "_test_experience_manager"

# Test data
var _player_unit: Unit
var _enemy_unit: Unit
var _ally_unit: Unit
var _units_container: Node2D
var _grid_setup: GridSetup

# Signal tracking
var _xp_gained_events: Array[Dictionary] = []
var _level_up_events: Array[Dictionary] = []
var _ability_learned_events: Array[Dictionary] = []

# Resources to clean up (for test_level_up_can_learn_abilities which creates custom resources)
var _created_characters: Array[CharacterData] = []
var _created_classes: Array[ClassData] = []
var _created_abilities: Array[AbilityData] = []
var _original_config: ExperienceConfig = null


func before() -> void:
	_xp_gained_events.clear()
	_level_up_events.clear()
	_ability_learned_events.clear()

	# Store original config to restore later
	_original_config = ExperienceManager.config

	# Create units container
	_units_container = Node2D.new()
	add_child(_units_container)

	# Setup grid using fixture
	_grid_setup = GridSetupScript.new()
	_grid_setup.create_grid(_units_container)

	# Connect signals
	ExperienceManager.unit_gained_xp.connect(_on_unit_gained_xp)
	ExperienceManager.unit_leveled_up.connect(_on_unit_leveled_up)
	ExperienceManager.unit_learned_ability.connect(_on_unit_learned_ability)


func after() -> void:
	# Disconnect signals
	if ExperienceManager.unit_gained_xp.is_connected(_on_unit_gained_xp):
		ExperienceManager.unit_gained_xp.disconnect(_on_unit_gained_xp)
	if ExperienceManager.unit_leveled_up.is_connected(_on_unit_leveled_up):
		ExperienceManager.unit_leveled_up.disconnect(_on_unit_leveled_up)
	if ExperienceManager.unit_learned_ability.is_connected(_on_unit_learned_ability):
		ExperienceManager.unit_learned_ability.disconnect(_on_unit_learned_ability)

	# Restore original config
	ExperienceManager.config = _original_config

	# Clean up units
	_cleanup_units()

	# Clean up grid
	_grid_setup.cleanup()
	_grid_setup = null

	# Clean up container
	if _units_container and is_instance_valid(_units_container):
		_units_container.queue_free()
		_units_container = null

	# Clean up resources (for test_level_up_can_learn_abilities custom resources)
	_created_characters.clear()
	_created_classes.clear()
	_created_abilities.clear()


func before_test() -> void:
	_xp_gained_events.clear()
	_level_up_events.clear()
	_ability_learned_events.clear()

	# Reset to default config for each test
	var test_config: ExperienceConfig = ExperienceConfig.new()
	ExperienceManager.set_config(test_config)

	# Invalidate cached party level
	ExperienceManager.invalidate_party_level_cache()


# =============================================================================
# TEST: Combat XP - Damage
# =============================================================================

func test_combat_xp_awarded_for_damage() -> void:
	var player_char: CharacterData = CharacterFactory.create_combatant("Hero", 50, 10, 15, 10, 10, 1)
	var enemy_char: CharacterData = CharacterFactory.create_combatant("Goblin", 30, 0, 8, 5, 5, 1)

	_player_unit = UnitFactory.spawn_unit(player_char, Vector2i(5, 5), "player", _units_container)
	_enemy_unit = UnitFactory.spawn_unit(enemy_char, Vector2i(6, 5), "enemy", _units_container)

	var initial_xp: int = _player_unit.stats.current_xp

	# Award combat XP for dealing 10 damage
	ExperienceManager.award_combat_xp(_player_unit, _enemy_unit, 10, false)

	assert_int(_player_unit.stats.current_xp).is_greater(initial_xp)
	assert_int(_xp_gained_events.size()).is_equal(1)
	assert_str(_xp_gained_events[0].source).is_equal("damage")


func test_combat_xp_kill_bonus() -> void:
	var player_char: CharacterData = CharacterFactory.create_combatant("Hero", 50, 10, 15, 10, 10, 1)
	var enemy_char: CharacterData = CharacterFactory.create_combatant("Goblin", 30, 0, 8, 5, 5, 1)

	_player_unit = UnitFactory.spawn_unit(player_char, Vector2i(5, 5), "player", _units_container)
	_enemy_unit = UnitFactory.spawn_unit(enemy_char, Vector2i(6, 5), "enemy", _units_container)

	# Award XP for damage without kill
	ExperienceManager.award_combat_xp(_player_unit, _enemy_unit, 10, false)
	var xp_without_kill: int = _xp_gained_events[0].amount

	# Reset
	_xp_gained_events.clear()
	_player_unit.stats.current_xp = 0

	# Award XP for same damage WITH kill
	ExperienceManager.award_combat_xp(_player_unit, _enemy_unit, 10, true)
	var xp_with_kill: int = _xp_gained_events[0].amount

	# Kill bonus should make XP higher
	assert_int(xp_with_kill).is_greater(xp_without_kill)
	assert_str(_xp_gained_events[0].source).is_equal("kill")


func test_combat_xp_only_awarded_to_player_faction() -> void:
	var player_char: CharacterData = CharacterFactory.create_combatant("Hero", 50, 10, 15, 10, 10, 1)
	var enemy_char: CharacterData = CharacterFactory.create_combatant("Orc", 40, 0, 12, 8, 6, 1)

	_player_unit = UnitFactory.spawn_unit(player_char, Vector2i(5, 5), "player", _units_container)
	_enemy_unit = UnitFactory.spawn_unit(enemy_char, Vector2i(6, 5), "enemy", _units_container)

	var initial_enemy_xp: int = _enemy_unit.stats.current_xp

	# Enemy attacks player - enemy should NOT gain XP
	ExperienceManager.award_combat_xp(_enemy_unit, _player_unit, 10, false)

	assert_int(_enemy_unit.stats.current_xp).is_equal(initial_enemy_xp)
	assert_int(_xp_gained_events.size()).is_equal(0)


func test_combat_xp_handles_null_units() -> void:
	var player_char: CharacterData = CharacterFactory.create_combatant("Hero", 50, 10, 15, 10, 10, 1)
	_player_unit = UnitFactory.spawn_unit(player_char, Vector2i(5, 5), "player", _units_container)

	# Should not crash with null units
	ExperienceManager.award_combat_xp(null, _player_unit, 10, false)
	ExperienceManager.award_combat_xp(_player_unit, null, 10, false)
	ExperienceManager.award_combat_xp(null, null, 10, false)

	# No XP should be awarded
	assert_int(_xp_gained_events.size()).is_equal(0)


# =============================================================================
# TEST: Combat XP - Formation
# =============================================================================

func test_formation_xp_awarded_to_nearby_allies() -> void:
	var player_char: CharacterData = CharacterFactory.create_combatant("Hero", 50, 10, 15, 10, 10, 1)
	var ally_char: CharacterData = CharacterFactory.create_combatant("Ally", 45, 5, 12, 8, 8, 1)
	var enemy_char: CharacterData = CharacterFactory.create_combatant("Goblin", 30, 0, 8, 5, 5, 1)

	_player_unit = UnitFactory.spawn_unit(player_char, Vector2i(5, 5), "player", _units_container)
	_ally_unit = UnitFactory.spawn_unit(ally_char, Vector2i(6, 6), "player", _units_container)  # Within formation radius (3)
	_enemy_unit = UnitFactory.spawn_unit(enemy_char, Vector2i(8, 5), "enemy", _units_container)

	# Setup TurnManager with units for formation calculation
	TurnManager.all_units = [_player_unit, _ally_unit, _enemy_unit]

	# Award combat XP
	ExperienceManager.award_combat_xp(_player_unit, _enemy_unit, 15, false)

	# Should have 2 events: damage XP for attacker, formation XP for ally
	assert_int(_xp_gained_events.size()).is_equal(2)

	# Find the formation XP event
	var formation_event: Dictionary = {}
	for event: Dictionary in _xp_gained_events:
		if event.source == "formation":
			formation_event = event
			break

	assert_bool(formation_event.is_empty()).is_false()
	assert_object(formation_event.unit).is_same(_ally_unit)


func test_formation_xp_not_awarded_to_distant_allies() -> void:
	var player_char: CharacterData = CharacterFactory.create_combatant("Hero", 50, 10, 15, 10, 10, 1)
	var ally_char: CharacterData = CharacterFactory.create_combatant("Ally", 45, 5, 12, 8, 8, 1)
	var enemy_char: CharacterData = CharacterFactory.create_combatant("Goblin", 30, 0, 8, 5, 5, 1)

	_player_unit = UnitFactory.spawn_unit(player_char, Vector2i(5, 5), "player", _units_container)
	_ally_unit = UnitFactory.spawn_unit(ally_char, Vector2i(12, 5), "player", _units_container)  # Too far (distance 7)
	_enemy_unit = UnitFactory.spawn_unit(enemy_char, Vector2i(6, 5), "enemy", _units_container)

	# Setup TurnManager with units for formation calculation
	TurnManager.all_units = [_player_unit, _ally_unit, _enemy_unit]

	# Award combat XP
	ExperienceManager.award_combat_xp(_player_unit, _enemy_unit, 15, false)

	# Should only have 1 event: damage XP for attacker (no formation for distant ally)
	assert_int(_xp_gained_events.size()).is_equal(1)
	assert_str(_xp_gained_events[0].source).is_equal("damage")


# =============================================================================
# TEST: Support XP
# =============================================================================

func test_support_xp_for_healing() -> void:
	var healer_char: CharacterData = CharacterFactory.create_combatant("Healer", 40, 30, 8, 8, 10, 1)
	var ally_char: CharacterData = CharacterFactory.create_combatant("Ally", 50, 5, 15, 10, 8, 1)

	_player_unit = UnitFactory.spawn_unit(healer_char, Vector2i(5, 5), "player", _units_container)
	_ally_unit = UnitFactory.spawn_unit(ally_char, Vector2i(6, 5), "player", _units_container)
	_ally_unit.stats.current_hp = 25  # Half health

	var initial_xp: int = _player_unit.stats.current_xp

	# Award support XP for healing 20 HP
	ExperienceManager.award_support_xp(_player_unit, "heal", _ally_unit, 20)

	assert_int(_player_unit.stats.current_xp).is_greater(initial_xp)
	assert_int(_xp_gained_events.size()).is_equal(1)
	assert_str(_xp_gained_events[0].source).is_equal("heal")


func test_support_xp_for_buff() -> void:
	var buffer_char: CharacterData = CharacterFactory.create_combatant("Buffer", 40, 30, 8, 8, 10, 1)
	var ally_char: CharacterData = CharacterFactory.create_combatant("Ally", 50, 5, 15, 10, 8, 1)

	_player_unit = UnitFactory.spawn_unit(buffer_char, Vector2i(5, 5), "player", _units_container)
	_ally_unit = UnitFactory.spawn_unit(ally_char, Vector2i(6, 5), "player", _units_container)

	var initial_xp: int = _player_unit.stats.current_xp

	# Award support XP for buffing
	ExperienceManager.award_support_xp(_player_unit, "buff", _ally_unit, 0)

	assert_int(_player_unit.stats.current_xp).is_greater(initial_xp)
	assert_int(_xp_gained_events.size()).is_equal(1)
	assert_str(_xp_gained_events[0].source).is_equal("buff")


func test_support_xp_for_debuff() -> void:
	var debuffer_char: CharacterData = CharacterFactory.create_combatant("Debuffer", 40, 30, 8, 8, 10, 1)
	var enemy_char: CharacterData = CharacterFactory.create_combatant("Enemy", 50, 5, 15, 10, 8, 1)

	_player_unit = UnitFactory.spawn_unit(debuffer_char, Vector2i(5, 5), "player", _units_container)
	_enemy_unit = UnitFactory.spawn_unit(enemy_char, Vector2i(6, 5), "enemy", _units_container)

	var initial_xp: int = _player_unit.stats.current_xp

	# Award support XP for debuffing
	ExperienceManager.award_support_xp(_player_unit, "debuff", _enemy_unit, 0)

	assert_int(_player_unit.stats.current_xp).is_greater(initial_xp)
	assert_int(_xp_gained_events.size()).is_equal(1)
	assert_str(_xp_gained_events[0].source).is_equal("debuff")


func test_support_xp_anti_spam_reduces_xp() -> void:
	var healer_char: CharacterData = CharacterFactory.create_combatant("Healer", 40, 30, 8, 8, 10, 1)
	var ally_char: CharacterData = CharacterFactory.create_combatant("Ally", 50, 5, 15, 10, 8, 1)

	_player_unit = UnitFactory.spawn_unit(healer_char, Vector2i(5, 5), "player", _units_container)
	_ally_unit = UnitFactory.spawn_unit(ally_char, Vector2i(6, 5), "player", _units_container)
	_ally_unit.stats.max_hp = 50

	# First heal - full XP
	ExperienceManager.award_support_xp(_player_unit, "heal", _ally_unit, 20)
	var first_heal_xp: int = _xp_gained_events[0].amount

	# Heal 5 more times to hit anti-spam threshold (default 5)
	for i: int in range(5):
		_xp_gained_events.clear()
		ExperienceManager.award_support_xp(_player_unit, "heal", _ally_unit, 20)

	var sixth_heal_xp: int = _xp_gained_events[0].amount

	# Sixth heal should give less XP due to anti-spam
	assert_int(sixth_heal_xp).is_less(first_heal_xp)


func test_support_xp_disabled_when_config_off() -> void:
	var healer_char: CharacterData = CharacterFactory.create_combatant("Healer", 40, 30, 8, 8, 10, 1)
	var ally_char: CharacterData = CharacterFactory.create_combatant("Ally", 50, 5, 15, 10, 8, 1)

	_player_unit = UnitFactory.spawn_unit(healer_char, Vector2i(5, 5), "player", _units_container)
	_ally_unit = UnitFactory.spawn_unit(ally_char, Vector2i(6, 5), "player", _units_container)

	# Disable enhanced support XP
	ExperienceManager.config.enable_enhanced_support_xp = false

	var initial_xp: int = _player_unit.stats.current_xp

	ExperienceManager.award_support_xp(_player_unit, "heal", _ally_unit, 20)

	# No XP should be awarded
	assert_int(_player_unit.stats.current_xp).is_equal(initial_xp)
	assert_int(_xp_gained_events.size()).is_equal(0)


# =============================================================================
# TEST: Level-up
# =============================================================================

func test_level_up_increases_stats() -> void:
	var char_data: CharacterData = CharacterFactory.create_combatant("Hero", 50, 10, 15, 10, 10, 1)
	_player_unit = UnitFactory.spawn_unit(char_data, Vector2i(5, 5), "player", _units_container)

	var old_level: int = _player_unit.stats.level
	var old_max_hp: int = _player_unit.stats.max_hp

	# Apply level-up
	var stat_increases: Dictionary = ExperienceManager.apply_level_up(_player_unit)

	assert_int(_player_unit.stats.level).is_equal(old_level + 1)
	# At least one stat should increase (due to growth rates)
	assert_bool(stat_increases.is_empty()).is_false()
	assert_int(_level_up_events.size()).is_equal(1)


func test_level_up_signal_contains_correct_data() -> void:
	var char_data: CharacterData = CharacterFactory.create_combatant("Hero", 50, 10, 15, 10, 10, 5)
	_player_unit = UnitFactory.spawn_unit(char_data, Vector2i(5, 5), "player", _units_container)

	# Apply level-up
	ExperienceManager.apply_level_up(_player_unit)

	assert_int(_level_up_events.size()).is_equal(1)
	assert_int(_level_up_events[0].old_level).is_equal(5)
	assert_int(_level_up_events[0].new_level).is_equal(6)
	assert_object(_level_up_events[0].unit).is_same(_player_unit)


func test_level_up_handles_null_unit() -> void:
	# Should not crash with null unit
	var result: Dictionary = ExperienceManager.apply_level_up(null)

	assert_bool(result.is_empty()).is_true()
	assert_int(_level_up_events.size()).is_equal(0)


# =============================================================================
# TEST: Ability Learning
# =============================================================================

func test_level_up_can_learn_abilities() -> void:
	# Create character with ability that unlocks at level 2
	var ability: AbilityData = AbilityData.new()
	ability.ability_id = "test_heal"
	ability.ability_name = "Heal"
	ability.ability_type = AbilityData.AbilityType.HEAL
	_created_abilities.append(ability)

	# Register ability
	if ModLoader and ModLoader.registry:
		ModLoader.registry.register_resource(ability, "ability", "test_heal", TEST_MOD_ID)

	var class_data: ClassData = ClassData.new()
	class_data.display_name = "Healer"
	class_data.movement_type = ClassData.MovementType.WALKING
	class_data.movement_range = 4
	class_data.class_abilities = [ability]
	class_data.ability_unlock_levels = {"test_heal": 2}
	_created_classes.append(class_data)

	var char_data: CharacterData = CharacterData.new()
	char_data.character_name = "Healer"
	char_data.base_hp = 40
	char_data.base_mp = 30
	char_data.base_strength = 8
	char_data.base_defense = 8
	char_data.base_agility = 10
	char_data.base_intelligence = 15
	char_data.base_luck = 5
	char_data.starting_level = 1
	char_data.character_class = class_data
	_created_characters.append(char_data)

	_player_unit = UnitFactory.spawn_unit(char_data, Vector2i(5, 5), "player", _units_container)

	# Level up from 1 to 2 - should learn the ability
	ExperienceManager.apply_level_up(_player_unit)

	assert_int(_ability_learned_events.size()).is_equal(1)
	assert_str(_ability_learned_events[0].ability.ability_id).is_equal("test_heal")


# =============================================================================
# TEST: Configuration
# =============================================================================

func test_set_config_applies_new_config() -> void:
	var custom_config: ExperienceConfig = ExperienceConfig.new()
	custom_config.max_xp_per_action = 25
	custom_config.kill_bonus_multiplier = 1.0

	ExperienceManager.set_config(custom_config)

	assert_int(ExperienceManager.config.max_xp_per_action).is_equal(25)
	assert_float(ExperienceManager.config.kill_bonus_multiplier).is_equal(1.0)


func test_set_config_null_reloads_default() -> void:
	var custom_config: ExperienceConfig = ExperienceConfig.new()
	custom_config.max_xp_per_action = 25

	ExperienceManager.set_config(custom_config)
	assert_int(ExperienceManager.config.max_xp_per_action).is_equal(25)

	# Setting null should reload default
	ExperienceManager.set_config(null)

	# Should be back to default (49)
	assert_int(ExperienceManager.config.max_xp_per_action).is_equal(49)


func test_get_base_xp_from_level_diff() -> void:
	# Same level should give standard XP
	var same_level_xp: int = ExperienceManager.get_base_xp_from_level_diff(0)
	assert_int(same_level_xp).is_equal(50)

	# Fighting much weaker enemy should give less XP
	var weak_enemy_xp: int = ExperienceManager.get_base_xp_from_level_diff(-6)
	assert_int(weak_enemy_xp).is_less(same_level_xp)

	# Fighting enemy 7+ levels below gives 0 XP
	var very_weak_xp: int = ExperienceManager.get_base_xp_from_level_diff(-7)
	assert_int(very_weak_xp).is_equal(0)


func test_invalidate_party_level_cache() -> void:
	# Smoke test: verify cache invalidation is callable without error
	# The cache is internal state; we verify the method completes successfully
	ExperienceManager.invalidate_party_level_cache()

	# Verify ExperienceManager is still functional after cache invalidation
	assert_object(ExperienceManager.config).is_not_null()


# =============================================================================
# TEST: XP Max Level Cap
# =============================================================================

func test_xp_not_awarded_at_max_level() -> void:
	var char_data: CharacterData = CharacterFactory.create_combatant("Hero", 50, 10, 15, 10, 10, 20)  # Max level
	var enemy_char: CharacterData = CharacterFactory.create_combatant("Goblin", 30, 0, 8, 5, 5, 1)

	_player_unit = UnitFactory.spawn_unit(char_data, Vector2i(5, 5), "player", _units_container)
	_enemy_unit = UnitFactory.spawn_unit(enemy_char, Vector2i(6, 5), "enemy", _units_container)

	# Ensure config has max level 20
	ExperienceManager.config.max_level = 20

	var initial_xp: int = _player_unit.stats.current_xp

	ExperienceManager.award_combat_xp(_player_unit, _enemy_unit, 10, true)

	# XP should not increase at max level
	assert_int(_player_unit.stats.current_xp).is_equal(initial_xp)


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_unit_gained_xp(unit: Node2D, amount: int, source: String) -> void:
	_xp_gained_events.append({
		"unit": unit,
		"amount": amount,
		"source": source
	})


func _on_unit_leveled_up(unit: Node2D, old_level: int, new_level: int, stat_increases: Dictionary) -> void:
	_level_up_events.append({
		"unit": unit,
		"old_level": old_level,
		"new_level": new_level,
		"stat_increases": stat_increases
	})


func _on_unit_learned_ability(unit: Node2D, ability: AbilityData) -> void:
	_ability_learned_events.append({
		"unit": unit,
		"ability": ability
	})


func _cleanup_units() -> void:
	UnitFactory.cleanup_unit(_player_unit)
	_player_unit = null
	UnitFactory.cleanup_unit(_enemy_unit)
	_enemy_unit = null
	UnitFactory.cleanup_unit(_ally_unit)
	_ally_unit = null

	# Clean up any registered test resources
	if ModLoader and ModLoader.registry:
		ModLoader.registry.clear_mod_resources(TEST_MOD_ID)
