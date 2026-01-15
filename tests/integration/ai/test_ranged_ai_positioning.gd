## Ranged AI Positioning Integration Test
##
## Tests that AI units with ranged weapons (bows) properly position themselves
## within their weapon's attack range band, avoiding the dead zone.
##
## Validates:
## - Archers don't walk into melee range when they have a ranged weapon
## - AI moves to valid attack position (min_range <= distance <= max_range)
## - AI attacks after positioning correctly
extends Node2D

const UnitScript = preload("res://core/components/unit.gd")

# Test state
var _test_complete: bool = false
var _test_passed: bool = false
var _failure_reason: String = ""

# Units
var _archer_unit: Unit
var _target_unit: Unit

# Tracking
var _archer_start_pos: Vector2i
var _archer_final_pos: Vector2i
var _combat_occurred: bool = false

# Resources to clean up
var _tilemap_layer: TileMapLayer
var _tileset: TileSet
var _grid_resource: Grid
var _created_characters: Array[CharacterData] = []
var _created_classes: Array[ClassData] = []
var _created_behaviors: Array[AIBehaviorData] = []
var _created_items: Array[ItemData] = []


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("RANGED AI POSITIONING TEST")
	print("=".repeat(60))
	print("Testing: Archer with bow (range 2-4) should NOT walk to melee range\n")

	# Create minimal TileMapLayer for GridManager
	_tilemap_layer = TileMapLayer.new()
	_tileset = TileSet.new()
	_tilemap_layer.tile_set = _tileset
	add_child(_tilemap_layer)

	# Setup grid (larger to allow movement testing)
	_grid_resource = Grid.new()
	_grid_resource.grid_size = Vector2i(15, 10)
	_grid_resource.cell_size = 32
	GridManager.setup_grid(_grid_resource, _tilemap_layer)

	# Create archer character
	var archer_character: CharacterData = _create_character("TestArcher", 30, 10, 15, 10, 12)

	# Create target character (tanky so it survives)
	var target_character: CharacterData = _create_character("TestTarget", 100, 10, 10, 20, 5)
	target_character.is_hero = true  # Mark as hero for battle end detection

	# Create opportunistic archer AI behavior inline for test isolation
	var archer_ai: AIBehaviorData = _create_archer_behavior()

	# Spawn archer at position (2, 5) - will need to move to attack
	_archer_start_pos = Vector2i(2, 5)
	_archer_unit = _spawn_unit(archer_character, _archer_start_pos, "enemy", archer_ai)

	# Create and equip a BOW with range 2-4 (dead zone at distance 1)
	var bow: ItemData = ItemData.new()
	bow.item_name = "Test Bow"
	bow.item_type = ItemData.ItemType.WEAPON
	bow.attack_power = 10
	bow.min_attack_range = 2  # Cannot attack at distance 1
	bow.max_attack_range = 4  # Can attack at distances 2, 3, 4
	bow.hit_rate = 90
	bow.critical_rate = 5
	_archer_unit.stats.cached_weapon = bow
	_created_items.append(bow)

	# Spawn target at position (8, 5) - distance of 6 from archer
	# Archer must move closer but should stop at distance 2-4, not 1
	_target_unit = _spawn_unit(target_character, Vector2i(8, 5), "player", null)

	print("Setup:")
	print("  Archer at: %s with bow (range 2-4)" % _archer_start_pos)
	print("  Target at: %s" % _target_unit.grid_position)
	print("  Initial distance: %d" % _get_distance(_archer_unit, _target_unit))
	print("  Archer movement range: %d" % _archer_unit.get_current_class().movement_range)

	# Setup BattleManager
	BattleManager.setup(self, self)
	BattleManager.player_units = [_target_unit]
	BattleManager.enemy_units = [_archer_unit]
	BattleManager.all_units = [_archer_unit, _target_unit]

	# Connect to combat signal to track attacks
	BattleManager.combat_resolved.connect(_on_combat_resolved)

	# Run the AI turn
	print("\nExecuting archer AI turn...")
	await _execute_archer_turn()

	# Validate results
	_validate_positioning()


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
	basic_class.display_name = "Archer"
	basic_class.movement_type = ClassData.MovementType.WALKING
	basic_class.movement_range = 5  # Good movement to reach target

	character.character_class = basic_class

	# Track for cleanup
	_created_characters.append(character)
	_created_classes.append(basic_class)

	return character


func _create_archer_behavior() -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = "test_opportunistic_archer"
	behavior.display_name = "Test Archer AI"
	behavior.role = "aggressive"
	behavior.behavior_mode = "opportunistic"
	behavior.retreat_enabled = true
	behavior.retreat_hp_threshold = 40
	behavior.threat_weights = {"wounded_target": 1.5, "proximity": 0.5}

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


func _execute_archer_turn() -> void:
	var context: Dictionary = {
		"player_units": BattleManager.player_units,
		"enemy_units": BattleManager.enemy_units,
		"neutral_units": [],
		"turn_number": 1,
		"ai_delays": {"after_movement": 0.0, "before_attack": 0.0}
	}

	var ConfigurableAIBrainScript: GDScript = load("res://core/systems/ai/configurable_ai_brain.gd")
	var brain: AIBrain = ConfigurableAIBrainScript.get_instance()
	await brain.execute_with_behavior(_archer_unit, context, _archer_unit.ai_behavior)

	# Wait for movement to complete
	await _archer_unit.await_movement_completion()

	# Record final position
	_archer_final_pos = _archer_unit.grid_position


func _on_combat_resolved(attacker: Unit, defender: Unit, damage: int, hit: bool, _crit: bool) -> void:
	if attacker == _archer_unit:
		_combat_occurred = true
		_archer_final_pos = _archer_unit.grid_position  # Capture position at combat time
		var hit_str: String = "HIT" if hit else "MISS"
		print("  [COMBAT] Archer attacked from distance %d: %s for %d damage" % [
			_get_distance(_archer_unit, _target_unit),
			hit_str,
			damage
		])
		# Validate immediately after combat
		call_deferred("_validate_positioning")


func _validate_positioning() -> void:
	if _test_complete:
		return  # Already validated

	print("\nResults:")
	print("  Archer moved from %s to %s" % [_archer_start_pos, _archer_final_pos])

	var final_distance: int = _get_distance(_archer_unit, _target_unit)
	print("  Final distance to target: %d" % final_distance)

	var min_range: int = _archer_unit.stats.get_weapon_min_range()
	var max_range: int = _archer_unit.stats.get_weapon_max_range()
	print("  Weapon range: %d-%d" % [min_range, max_range])

	# Check if archer is in valid attack range
	var in_valid_range: bool = final_distance >= min_range and final_distance <= max_range
	var in_dead_zone: bool = final_distance < min_range

	print("\nValidation:")

	if in_dead_zone:
		_test_passed = false
		_failure_reason = "Archer walked into dead zone (distance %d < min_range %d)" % [final_distance, min_range]
		print("  [FAIL] %s" % _failure_reason)
	elif not in_valid_range and final_distance > max_range:
		# Didn't get close enough - might be movement limitation
		_test_passed = false
		_failure_reason = "Archer didn't reach attack range (distance %d > max_range %d)" % [final_distance, max_range]
		print("  [FAIL] %s" % _failure_reason)
	elif in_valid_range:
		print("  [OK] Archer positioned at valid attack distance (%d)" % final_distance)
		if _combat_occurred:
			print("  [OK] Combat occurred - archer attacked from range")
			_test_passed = true
		else:
			_test_passed = false
			_failure_reason = "Archer in range but did not attack"
			print("  [FAIL] %s" % _failure_reason)
	else:
		_test_passed = false
		_failure_reason = "Unexpected positioning state"
		print("  [FAIL] %s" % _failure_reason)

	_test_complete = true
	_print_results()


func _print_results() -> void:
	print("\n" + "=".repeat(60))
	if _test_passed:
		print("RANGED AI POSITIONING TEST PASSED!")
		print("Archer correctly maintained attack distance and did not enter melee range.")
	else:
		print("RANGED AI POSITIONING TEST FAILED!")
		print("Reason: %s" % _failure_reason)
	print("=".repeat(60) + "\n")

	# Cleanup before quitting
	_cleanup_units()
	_cleanup_tilemap()
	_cleanup_resources()

	get_tree().quit(0 if _test_passed else 1)


func _cleanup_units() -> void:
	if _archer_unit and is_instance_valid(_archer_unit):
		GridManager.set_cell_occupied(_archer_unit.grid_position, null)
		_archer_unit.queue_free()
		_archer_unit = null
	if _target_unit and is_instance_valid(_target_unit):
		GridManager.set_cell_occupied(_target_unit.grid_position, null)
		_target_unit.queue_free()
		_target_unit = null


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
	_created_items.clear()


func _process(_delta: float) -> void:
	# Safety timeout
	if not _test_complete:
		await get_tree().create_timer(5.0).timeout
		if not _test_complete:
			print("\n[TIMEOUT] Test did not complete in time")
			_test_passed = false
			_failure_reason = "Test timeout"
			_test_complete = true
			_print_results()
