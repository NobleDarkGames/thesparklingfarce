## TurnManager Integration Test
##
## Tests the TurnManager autoload functionality:
## - Battle initialization and state
## - Turn order calculation (AGI-based)
## - Turn cycle management
## - Victory/defeat condition detection
## - Signal emissions
class_name TestTurnManager
extends GdUnitTestSuite


# Test data
var _player_unit: Unit
var _enemy_unit: Unit
var _hero_unit: Unit
var _units_container: Node2D
var _tilemap_layer: TileMapLayer
var _tileset: TileSet
var _grid_resource: Grid

# Signal tracking
var _turn_cycle_events: Array[int] = []
var _player_turn_events: Array[Unit] = []
var _enemy_turn_events: Array[Unit] = []
var _unit_turn_ended_events: Array[Unit] = []
var _battle_ended_events: Array[bool] = []
var _hero_died_events: int = 0

# Resources to clean up
var _created_characters: Array[CharacterData] = []
var _created_classes: Array[ClassData] = []


func before() -> void:
	# Clear signal tracking
	_turn_cycle_events.clear()
	_player_turn_events.clear()
	_enemy_turn_events.clear()
	_unit_turn_ended_events.clear()
	_battle_ended_events.clear()
	_hero_died_events = 0

	# Create units container
	_units_container = Node2D.new()
	add_child(_units_container)

	# Create minimal TileMapLayer for GridManager
	_tilemap_layer = TileMapLayer.new()
	_tileset = TileSet.new()
	_tilemap_layer.tile_set = _tileset
	_units_container.add_child(_tilemap_layer)

	# Setup grid
	_grid_resource = Grid.new()
	_grid_resource.grid_size = Vector2i(20, 15)
	_grid_resource.cell_size = 32
	GridManager.setup_grid(_grid_resource, _tilemap_layer)

	# Connect signals
	TurnManager.turn_cycle_started.connect(_on_turn_cycle_started)
	TurnManager.player_turn_started.connect(_on_player_turn_started)
	TurnManager.enemy_turn_started.connect(_on_enemy_turn_started)
	TurnManager.unit_turn_ended.connect(_on_unit_turn_ended)
	TurnManager.battle_ended.connect(_on_battle_ended)
	TurnManager.hero_died_in_battle.connect(_on_hero_died)


func after() -> void:
	# Disconnect signals
	if TurnManager.turn_cycle_started.is_connected(_on_turn_cycle_started):
		TurnManager.turn_cycle_started.disconnect(_on_turn_cycle_started)
	if TurnManager.player_turn_started.is_connected(_on_player_turn_started):
		TurnManager.player_turn_started.disconnect(_on_player_turn_started)
	if TurnManager.enemy_turn_started.is_connected(_on_enemy_turn_started):
		TurnManager.enemy_turn_started.disconnect(_on_enemy_turn_started)
	if TurnManager.unit_turn_ended.is_connected(_on_unit_turn_ended):
		TurnManager.unit_turn_ended.disconnect(_on_unit_turn_ended)
	if TurnManager.battle_ended.is_connected(_on_battle_ended):
		TurnManager.battle_ended.disconnect(_on_battle_ended)
	if TurnManager.hero_died_in_battle.is_connected(_on_hero_died):
		TurnManager.hero_died_in_battle.disconnect(_on_hero_died)

	# Clear TurnManager state
	TurnManager.clear_battle()

	# Clean up units
	_cleanup_units()

	# Clean up tilemap
	if _tilemap_layer and is_instance_valid(_tilemap_layer):
		_tilemap_layer.queue_free()
		_tilemap_layer = null
	_tileset = null
	_grid_resource = null

	# Clean up container
	if _units_container and is_instance_valid(_units_container):
		_units_container.queue_free()
		_units_container = null

	# Clean up resources
	_created_characters.clear()
	_created_classes.clear()


func before_test() -> void:
	_turn_cycle_events.clear()
	_player_turn_events.clear()
	_enemy_turn_events.clear()
	_unit_turn_ended_events.clear()
	_battle_ended_events.clear()
	_hero_died_events = 0

	# Clear any existing battle state
	TurnManager.clear_battle()


# =============================================================================
# TEST: Battle Initialization
# =============================================================================

func test_start_battle_initializes_state() -> void:
	var player_char: CharacterData = _create_character("Hero", 50, 10, 15, 10, 10, true)
	var enemy_char: CharacterData = _create_character("Goblin", 30, 0, 8, 5, 5, false)

	_player_unit = _spawn_unit(player_char, Vector2i(5, 5), "player", null)
	_enemy_unit = _spawn_unit(enemy_char, Vector2i(6, 5), "enemy", null)

	var all_units: Array[Unit] = [_player_unit, _enemy_unit]
	TurnManager.start_battle(all_units)

	assert_bool(TurnManager.is_battle_active()).is_true()
	assert_int(TurnManager.turn_number).is_equal(1)
	assert_int(TurnManager.all_units.size()).is_equal(2)


func test_start_battle_emits_turn_cycle_signal() -> void:
	var player_char: CharacterData = _create_character("Hero", 50, 10, 15, 10, 10, true)
	var enemy_char: CharacterData = _create_character("Goblin", 30, 0, 8, 5, 5, false)

	_player_unit = _spawn_unit(player_char, Vector2i(5, 5), "player", null)
	_enemy_unit = _spawn_unit(enemy_char, Vector2i(6, 5), "enemy", null)

	var all_units: Array[Unit] = [_player_unit, _enemy_unit]
	TurnManager.start_battle(all_units)

	assert_int(_turn_cycle_events.size()).is_equal(1)
	assert_int(_turn_cycle_events[0]).is_equal(1)


func test_start_battle_with_no_units_fails() -> void:
	var empty_units: Array[Unit] = []

	# Should not crash, just log error
	TurnManager.start_battle(empty_units)

	assert_bool(TurnManager.is_battle_active()).is_false()


# =============================================================================
# TEST: Turn Order Calculation
# =============================================================================

func test_turn_priority_based_on_agility() -> void:
	# Create two characters with different agility
	var fast_char: CharacterData = _create_character("FastHero", 50, 10, 15, 10, 20, true)  # AGI 20
	var slow_char: CharacterData = _create_character("SlowGoblin", 30, 0, 8, 5, 5, false)   # AGI 5

	var fast_unit: Unit = _spawn_unit(fast_char, Vector2i(5, 5), "player", null)
	var slow_unit: Unit = _spawn_unit(slow_char, Vector2i(6, 5), "enemy", null)

	# Calculate priorities multiple times to account for randomness
	var fast_priorities: Array[float] = []
	var slow_priorities: Array[float] = []

	for i: int in range(10):
		fast_priorities.append(TurnManager.calculate_turn_priority(fast_unit))
		slow_priorities.append(TurnManager.calculate_turn_priority(slow_unit))

	# Average priority of fast unit should be higher than slow unit
	var fast_avg: float = 0.0
	var slow_avg: float = 0.0
	for i: int in range(10):
		fast_avg += fast_priorities[i]
		slow_avg += slow_priorities[i]
	fast_avg /= 10.0
	slow_avg /= 10.0

	assert_float(fast_avg).is_greater(slow_avg)

	# Clean up test units
	if fast_unit and is_instance_valid(fast_unit):
		GridManager.set_cell_occupied(fast_unit.grid_position, null)
		fast_unit.queue_free()
	if slow_unit and is_instance_valid(slow_unit):
		GridManager.set_cell_occupied(slow_unit.grid_position, null)
		slow_unit.queue_free()


func test_calculate_turn_order_sorts_by_priority() -> void:
	var player_char: CharacterData = _create_character("Hero", 50, 10, 15, 10, 15, true)
	var enemy_char: CharacterData = _create_character("Goblin", 30, 0, 8, 5, 10, false)

	_player_unit = _spawn_unit(player_char, Vector2i(5, 5), "player", null)
	_enemy_unit = _spawn_unit(enemy_char, Vector2i(6, 5), "enemy", null)

	TurnManager.all_units = [_player_unit, _enemy_unit]
	TurnManager.calculate_turn_order()

	# Should have 2 units in queue
	assert_int(TurnManager.turn_queue.size()).is_equal(2)

	# First unit should have higher priority
	var first: Unit = TurnManager.turn_queue[0]
	var second: Unit = TurnManager.turn_queue[1]
	assert_float(first.turn_priority).is_greater_equal(second.turn_priority)


func test_dead_units_excluded_from_turn_order() -> void:
	var player_char: CharacterData = _create_character("Hero", 50, 10, 15, 10, 15, true)
	var dead_char: CharacterData = _create_character("DeadGoblin", 30, 0, 8, 5, 10, false)

	_player_unit = _spawn_unit(player_char, Vector2i(5, 5), "player", null)
	_enemy_unit = _spawn_unit(dead_char, Vector2i(6, 5), "enemy", null)

	# Kill the enemy
	_enemy_unit.stats.current_hp = 0

	TurnManager.all_units = [_player_unit, _enemy_unit]
	TurnManager.calculate_turn_order()

	# Only living unit should be in queue
	assert_int(TurnManager.turn_queue.size()).is_equal(1)
	assert_object(TurnManager.turn_queue[0]).is_same(_player_unit)


# =============================================================================
# TEST: Active Unit Management
# =============================================================================

func test_get_active_unit_returns_current() -> void:
	var player_char: CharacterData = _create_character("Hero", 50, 10, 15, 10, 10, true)
	_player_unit = _spawn_unit(player_char, Vector2i(5, 5), "player", null)

	TurnManager.active_unit = _player_unit

	assert_object(TurnManager.get_active_unit()).is_same(_player_unit)


func test_is_player_turn_returns_correct_value() -> void:
	var player_char: CharacterData = _create_character("Hero", 50, 10, 15, 10, 10, true)
	var enemy_char: CharacterData = _create_character("Goblin", 30, 0, 8, 5, 5, false)

	_player_unit = _spawn_unit(player_char, Vector2i(5, 5), "player", null)
	_enemy_unit = _spawn_unit(enemy_char, Vector2i(6, 5), "enemy", null)

	# No active unit
	TurnManager.active_unit = null
	assert_bool(TurnManager.is_player_turn()).is_false()

	# Player unit active
	TurnManager.active_unit = _player_unit
	assert_bool(TurnManager.is_player_turn()).is_true()

	# Enemy unit active
	TurnManager.active_unit = _enemy_unit
	assert_bool(TurnManager.is_player_turn()).is_false()


# =============================================================================
# TEST: Query Functions
# =============================================================================

func test_is_battle_active() -> void:
	assert_bool(TurnManager.is_battle_active()).is_false()

	TurnManager.battle_active = true
	assert_bool(TurnManager.is_battle_active()).is_true()

	TurnManager.battle_active = false
	assert_bool(TurnManager.is_battle_active()).is_false()


func test_get_turn_number() -> void:
	assert_int(TurnManager.get_turn_number()).is_equal(0)

	TurnManager.turn_number = 5
	assert_int(TurnManager.get_turn_number()).is_equal(5)


func test_get_remaining_turn_queue() -> void:
	var player_char: CharacterData = _create_character("Hero", 50, 10, 15, 10, 10, true)
	var enemy_char: CharacterData = _create_character("Goblin", 30, 0, 8, 5, 5, false)

	_player_unit = _spawn_unit(player_char, Vector2i(5, 5), "player", null)
	_enemy_unit = _spawn_unit(enemy_char, Vector2i(6, 5), "enemy", null)

	TurnManager.turn_queue = [_player_unit, _enemy_unit]

	var remaining: Array[Unit] = TurnManager.get_remaining_turn_queue()

	assert_int(remaining.size()).is_equal(2)
	# Should be a duplicate, not the original
	remaining.clear()
	assert_int(TurnManager.turn_queue.size()).is_equal(2)


# =============================================================================
# TEST: Victory/Defeat Conditions
# =============================================================================

func test_victory_when_all_enemies_defeated() -> void:
	var player_char: CharacterData = _create_character("Hero", 50, 10, 15, 10, 10, true)
	var enemy_char: CharacterData = _create_character("Goblin", 30, 0, 8, 5, 5, false)

	_player_unit = _spawn_unit(player_char, Vector2i(5, 5), "player", null)
	_enemy_unit = _spawn_unit(enemy_char, Vector2i(6, 5), "enemy", null)

	TurnManager.all_units = [_player_unit, _enemy_unit]
	TurnManager.battle_active = true

	# Kill all enemies
	_enemy_unit.stats.current_hp = 0

	# Check should detect victory
	var result: bool = TurnManager._check_battle_end()

	assert_bool(result).is_true()
	assert_int(_battle_ended_events.size()).is_equal(1)
	assert_bool(_battle_ended_events[0]).is_true()  # Victory


func test_defeat_when_hero_dies() -> void:
	var hero_char: CharacterData = _create_character("Hero", 50, 10, 15, 10, 10, true)
	var enemy_char: CharacterData = _create_character("Goblin", 30, 0, 8, 5, 5, false)

	_hero_unit = _spawn_unit(hero_char, Vector2i(5, 5), "player", null)
	_enemy_unit = _spawn_unit(enemy_char, Vector2i(6, 5), "enemy", null)

	TurnManager.all_units = [_hero_unit, _enemy_unit]
	TurnManager.battle_active = true

	# Kill the hero
	_hero_unit.stats.current_hp = 0

	# Check should detect defeat
	var result: bool = TurnManager._check_battle_end()

	assert_bool(result).is_true()
	assert_int(_hero_died_events).is_equal(1)


func test_no_battle_end_when_both_sides_alive() -> void:
	var hero_char: CharacterData = _create_character("Hero", 50, 10, 15, 10, 10, true)
	var enemy_char: CharacterData = _create_character("Goblin", 30, 0, 8, 5, 5, false)

	_hero_unit = _spawn_unit(hero_char, Vector2i(5, 5), "player", null)
	_enemy_unit = _spawn_unit(enemy_char, Vector2i(6, 5), "enemy", null)

	TurnManager.all_units = [_hero_unit, _enemy_unit]
	TurnManager.battle_active = true

	# Both units alive
	var result: bool = TurnManager._check_battle_end()

	assert_bool(result).is_false()
	assert_int(_battle_ended_events.size()).is_equal(0)
	assert_int(_hero_died_events).is_equal(0)


# =============================================================================
# TEST: Clear Battle
# =============================================================================

func test_clear_battle_resets_state() -> void:
	var player_char: CharacterData = _create_character("Hero", 50, 10, 15, 10, 10, true)
	_player_unit = _spawn_unit(player_char, Vector2i(5, 5), "player", null)

	# Set some state
	TurnManager.all_units = [_player_unit]
	TurnManager.turn_queue = [_player_unit]
	TurnManager.active_unit = _player_unit
	TurnManager.turn_number = 5
	TurnManager.battle_active = true

	# Clear
	TurnManager.clear_battle()

	assert_int(TurnManager.all_units.size()).is_equal(0)
	assert_int(TurnManager.turn_queue.size()).is_equal(0)
	assert_object(TurnManager.active_unit).is_null()
	assert_int(TurnManager.turn_number).is_equal(0)
	assert_bool(TurnManager.battle_active).is_false()


# =============================================================================
# TEST: End Unit Turn
# =============================================================================

func test_end_unit_turn_emits_signal() -> void:
	var player_char: CharacterData = _create_character("Hero", 50, 10, 15, 10, 10, true)
	_player_unit = _spawn_unit(player_char, Vector2i(5, 5), "player", null)

	TurnManager.active_unit = _player_unit
	TurnManager.battle_active = true
	TurnManager.all_units = [_player_unit]
	TurnManager.turn_queue = []

	# End the turn (will auto-advance which starts new cycle with only player)
	TurnManager.end_unit_turn(_player_unit)

	# Should have emitted unit_turn_ended
	assert_int(_unit_turn_ended_events.size()).is_equal(1)
	assert_object(_unit_turn_ended_events[0]).is_same(_player_unit)


func test_end_wrong_unit_turn_warns() -> void:
	var player_char: CharacterData = _create_character("Hero", 50, 10, 15, 10, 10, true)
	var enemy_char: CharacterData = _create_character("Goblin", 30, 0, 8, 5, 5, false)

	_player_unit = _spawn_unit(player_char, Vector2i(5, 5), "player", null)
	_enemy_unit = _spawn_unit(enemy_char, Vector2i(6, 5), "enemy", null)

	TurnManager.active_unit = _player_unit

	# Try to end enemy's turn when player is active
	TurnManager.end_unit_turn(_enemy_unit)

	# Should not emit signal for wrong unit
	assert_int(_unit_turn_ended_events.size()).is_equal(0)


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_turn_cycle_started(turn_number: int) -> void:
	_turn_cycle_events.append(turn_number)


func _on_player_turn_started(unit: Unit) -> void:
	_player_turn_events.append(unit)


func _on_enemy_turn_started(unit: Unit) -> void:
	_enemy_turn_events.append(unit)


func _on_unit_turn_ended(unit: Unit) -> void:
	_unit_turn_ended_events.append(unit)


func _on_battle_ended(victory: bool) -> void:
	_battle_ended_events.append(victory)


func _on_hero_died() -> void:
	_hero_died_events += 1


# =============================================================================
# TEST FIXTURES
# =============================================================================

func _create_character(p_name: String, hp: int, mp: int, str_val: int, def_val: int, agi: int, is_hero: bool = false) -> CharacterData:
	var character: CharacterData = CharacterData.new()
	character.character_name = p_name
	character.base_hp = hp
	character.base_mp = mp
	character.base_strength = str_val
	character.base_defense = def_val
	character.base_agility = agi
	character.base_intelligence = 10
	character.base_luck = 5
	character.starting_level = 1
	character.is_hero = is_hero

	var basic_class: ClassData = ClassData.new()
	basic_class.display_name = "Warrior"
	basic_class.movement_type = ClassData.MovementType.WALKING
	basic_class.movement_range = 4

	character.character_class = basic_class

	_created_characters.append(character)
	_created_classes.append(basic_class)

	return character


func _spawn_unit(character: CharacterData, cell: Vector2i, p_faction: String, p_ai_behavior: AIBehaviorData) -> Unit:
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")
	var unit: Unit = unit_scene.instantiate() as Unit
	unit.initialize(character, p_faction, p_ai_behavior)
	unit.grid_position = cell
	unit.position = Vector2(cell.x * 32, cell.y * 32)
	_units_container.add_child(unit)
	GridManager.set_cell_occupied(cell, unit)
	return unit


func _cleanup_units() -> void:
	if _player_unit and is_instance_valid(_player_unit):
		GridManager.set_cell_occupied(_player_unit.grid_position, null)
		_player_unit.queue_free()
		_player_unit = null
	if _enemy_unit and is_instance_valid(_enemy_unit):
		GridManager.set_cell_occupied(_enemy_unit.grid_position, null)
		_enemy_unit.queue_free()
		_enemy_unit = null
	if _hero_unit and is_instance_valid(_hero_unit):
		GridManager.set_cell_occupied(_hero_unit.grid_position, null)
		_hero_unit.queue_free()
		_hero_unit = null
