## Retreat Behavior Integration Test
##
## Tests that AI units with retreat enabled will flee when HP drops
## below their retreat threshold, moving away from threats.
##
## Validates:
## - Unit at low HP retreats instead of attacking
## - Unit moves AWAY from enemy (increased distance)
## - No combat occurs during retreat
extends Node2D

const UnitScript = preload("res://core/components/unit.gd")

# Test state
var _test_complete: bool = false
var _test_passed: bool = false
var _failure_reason: String = ""

# Units
var _retreater_unit: Unit
var _threat_unit: Unit

# Tracking
var _retreater_start_pos: Vector2i
var _retreater_final_pos: Vector2i
var _initial_distance: int
var _combat_occurred: bool = false

# Resources to clean up
var _tilemap_layer: TileMapLayer
var _tileset: TileSet
var _grid_resource: Grid
var _created_characters: Array[CharacterData] = []
var _created_classes: Array[ClassData] = []
var _created_behaviors: Array[AIBehaviorData] = []


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("RETREAT BEHAVIOR TEST")
	print("=".repeat(60))
	print("Testing: Wounded unit (50% HP) should retreat from threat\n")

	# Create minimal TileMapLayer for GridManager
	_tilemap_layer = TileMapLayer.new()
	_tileset = TileSet.new()
	_tilemap_layer.tile_set = _tileset
	add_child(_tilemap_layer)

	# Setup grid (larger to allow retreat movement)
	_grid_resource = Grid.new()
	_grid_resource.grid_size = Vector2i(20, 15)
	_grid_resource.cell_size = 32
	GridManager.setup_grid(_grid_resource, _tilemap_layer)

	# Create retreater character
	var retreater_character: CharacterData = _create_character("Retreater", 100, 10, 15, 10, 12)

	# Create threat character
	var threat_character: CharacterData = _create_character("Threat", 100, 10, 20, 15, 8)
	threat_character.is_hero = true  # Mark as hero for battle end detection

	# Create a simple retreat-enabled behavior (avoid complex opportunistic logic)
	var retreater_ai: AIBehaviorData = _create_retreat_behavior()

	# Spawn retreater at position (10, 7) - center of map, room to retreat
	_retreater_start_pos = Vector2i(10, 7)
	_retreater_unit = _spawn_unit(retreater_character, _retreater_start_pos, "enemy", retreater_ai)

	# Set HP to 50% (below the 60% retreat threshold)
	_retreater_unit.stats.current_hp = 50  # 50% of 100 HP

	# Spawn threat at position (7, 7) - distance 3, close enough to trigger retreat
	_threat_unit = _spawn_unit(threat_character, Vector2i(7, 7), "player", null)

	# Record initial distance
	_initial_distance = _get_distance(_retreater_unit, _threat_unit)

	print("Setup:")
	print("  Retreater at: %s (HP: %d/%d = %d%%)" % [
		_retreater_start_pos,
		_retreater_unit.stats.current_hp,
		_retreater_unit.stats.max_hp,
		int(100.0 * _retreater_unit.stats.current_hp / _retreater_unit.stats.max_hp)
	])
	print("  Retreat threshold: %d%%" % retreater_ai.retreat_hp_threshold)
	print("  Threat at: %s" % _threat_unit.grid_position)
	print("  Initial distance: %d" % _initial_distance)

	# Setup BattleManager
	BattleManager.setup(self, self)
	BattleManager.player_units = [_threat_unit]
	BattleManager.enemy_units = [_retreater_unit]
	BattleManager.all_units = [_retreater_unit, _threat_unit]

	# Connect to combat signal to detect attacks
	BattleManager.combat_resolved.connect(_on_combat_resolved)

	# Run the AI turn
	print("\nExecuting retreater AI turn...")
	await _execute_retreater_turn()

	# Small delay to ensure all async operations complete
	await get_tree().create_timer(0.1).timeout

	# Validate results
	_validate_behavior()


func _create_character(p_name: String, hp: int, mp: int, str_val: int, def_val: int, agi: int) -> CharacterData:
	var character: CharacterData = CharacterData.new()
	character.character_name = p_name
	character.base_hp = hp
	character.base_mp = mp
	character.base_strength = str_val
	character.base_defense = def_val
	character.base_agility = agi
	character.base_intelligence = 5
	character.base_luck = 5
	character.starting_level = 1

	var basic_class: ClassData = ClassData.new()
	basic_class.display_name = "Scout"
	basic_class.movement_type = ClassData.MovementType.WALKING
	basic_class.movement_range = 5  # Good movement for retreat

	character.character_class = basic_class

	# Track for cleanup
	_created_characters.append(character)
	_created_classes.append(basic_class)

	return character


func _create_retreat_behavior() -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = "test_retreater"
	behavior.display_name = "Test Retreater"
	behavior.role = "aggressive"
	behavior.behavior_mode = "opportunistic"
	behavior.retreat_enabled = true
	behavior.retreat_hp_threshold = 60  # Retreat below 60% HP
	behavior.use_healing_items = false  # Don't try to use items (avoids PartyManager issues)
	behavior.use_attack_items = false

	# Track for cleanup
	_created_behaviors.append(behavior)

	return behavior


func _spawn_unit(character: CharacterData, cell: Vector2i, p_faction: String, p_ai_behavior: AIBehaviorData) -> Unit:
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")
	var unit: Unit = unit_scene.instantiate() as Unit
	unit.initialize(character, p_faction, p_ai_behavior)
	unit.grid_position = cell
	unit.position = Vector2(cell.x * 32, cell.y * 32)
	add_child(unit)
	GridManager.set_cell_occupied(cell, unit)
	return unit


func _get_distance(unit_a: Unit, unit_b: Unit) -> int:
	return GridManager.grid.get_manhattan_distance(unit_a.grid_position, unit_b.grid_position)


func _execute_retreater_turn() -> void:
	# Calculate HP percent for context
	var hp_percent: float = 100.0 * _retreater_unit.stats.current_hp / _retreater_unit.stats.max_hp

	var context: Dictionary = {
		"player_units": BattleManager.player_units,
		"enemy_units": BattleManager.enemy_units,
		"neutral_units": [],
		"turn_number": 1,
		"unit_hp_percent": hp_percent,
		"ai_delays": {"after_movement": 0.0, "before_attack": 0.0}
	}

	var ConfigurableAIBrainScript: GDScript = load("res://core/systems/ai/configurable_ai_brain.gd")
	var brain: AIBrain = ConfigurableAIBrainScript.get_instance()
	await brain.execute_with_behavior(_retreater_unit, context, _retreater_unit.ai_behavior)

	# Wait for movement to complete (with timeout to avoid hangs)
	var wait_start: float = Time.get_ticks_msec()
	while _retreater_unit.is_moving() and (Time.get_ticks_msec() - wait_start) < 3000:
		await get_tree().process_frame

	# Record final position
	_retreater_final_pos = _retreater_unit.grid_position


func _on_combat_resolved(attacker: Unit, _defender: Unit, _damage: int, _hit: bool, _crit: bool) -> void:
	if attacker == _retreater_unit:
		_combat_occurred = true
		print("  [COMBAT] Retreater ATTACKED (this should NOT happen during retreat!)")


func _validate_behavior() -> void:
	if _test_complete:
		return

	print("\nResults:")
	print("  Retreater moved from %s to %s" % [_retreater_start_pos, _retreater_final_pos])

	var final_distance: int = _get_distance(_retreater_unit, _threat_unit)
	var distance_change: int = final_distance - _initial_distance

	print("  Distance to threat: %d -> %d (change: %+d)" % [_initial_distance, final_distance, distance_change])
	print("  Combat occurred: %s" % _combat_occurred)

	print("\nValidation:")

	if _combat_occurred:
		_test_passed = false
		_failure_reason = "Retreater attacked instead of fleeing"
		print("  [FAIL] %s" % _failure_reason)
	elif _retreater_final_pos == _retreater_start_pos:
		_test_passed = false
		_failure_reason = "Retreater did not move at all"
		print("  [FAIL] %s" % _failure_reason)
	elif distance_change <= 0:
		_test_passed = false
		_failure_reason = "Retreater moved toward threat or stayed same distance (change: %+d)" % distance_change
		print("  [FAIL] %s" % _failure_reason)
	else:
		print("  [OK] Retreater did not attack")
		print("  [OK] Retreater moved away from threat (+%d distance)" % distance_change)
		_test_passed = true

	_test_complete = true
	_print_results()


func _print_results() -> void:
	print("\n" + "=".repeat(60))
	if _test_passed:
		print("RETREAT BEHAVIOR TEST PASSED!")
		print("Wounded unit correctly retreated instead of engaging.")
	else:
		print("RETREAT BEHAVIOR TEST FAILED!")
		print("Reason: %s" % _failure_reason)
	print("=".repeat(60) + "\n")

	# Cleanup before quitting
	_cleanup_units()
	_cleanup_tilemap()
	_cleanup_resources()

	get_tree().quit(0 if _test_passed else 1)


func _cleanup_units() -> void:
	if _retreater_unit and is_instance_valid(_retreater_unit):
		GridManager.set_cell_occupied(_retreater_unit.grid_position, null)
		_retreater_unit.queue_free()
		_retreater_unit = null
	if _threat_unit and is_instance_valid(_threat_unit):
		GridManager.set_cell_occupied(_threat_unit.grid_position, null)
		_threat_unit.queue_free()
		_threat_unit = null


func _cleanup_tilemap() -> void:
	if _tilemap_layer and is_instance_valid(_tilemap_layer):
		_tilemap_layer.queue_free()
		_tilemap_layer = null
	_tileset = null
	_grid_resource = null


func _cleanup_resources() -> void:
	# Clear tracked resources (RefCounted will handle cleanup)
	_created_characters.clear()
	_created_classes.clear()
	_created_behaviors.clear()


func _process(_delta: float) -> void:
	# Safety timeout
	pass
