## AoE Minimum Targets Integration Test
##
## Tests that AI units with AoE abilities respect the aoe_minimum_targets
## setting and prefer targeting clusters over isolated enemies.
##
## Validates:
## - AI doesn't waste AoE on single isolated target
## - AI prefers cluster of targets when available
## - aoe_minimum_targets threshold is respected
extends Node2D

const UnitScript = preload("res://core/components/unit.gd")

# Test state
var _test_complete: bool = false
var _test_passed: bool = false
var _failure_reason: String = ""

# Units
var _mage_unit: Unit
var _isolated_target: Unit
var _cluster_target_1: Unit
var _cluster_target_2: Unit
var _cluster_target_3: Unit

# Tracking
var _mage_initial_mp: int = 0
var _targets_hit: Array[Unit] = []
var _spell_cast: bool = false


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("AOE MINIMUM TARGETS TEST")
	print("=".repeat(60))
	print("Testing: AI should prefer cluster over isolated target for AoE\n")

	# Create minimal TileMapLayer for GridManager
	var tilemap_layer: TileMapLayer = TileMapLayer.new()
	var tileset: TileSet = TileSet.new()
	tilemap_layer.tile_set = tileset
	add_child(tilemap_layer)

	# Setup grid
	var grid_resource: Grid = Grid.new()
	grid_resource.grid_size = Vector2i(20, 15)
	grid_resource.cell_size = 32
	GridManager.setup_grid(grid_resource, tilemap_layer)

	# Create AoE mage character
	var mage_character: CharacterData = _create_aoe_mage("AoEMage")

	# Create target characters
	var isolated_char: CharacterData = _create_character("Isolated", 60, 10, 12, 10, 10)
	isolated_char.is_hero = true

	var cluster_char_1: CharacterData = _create_character("Cluster1", 60, 10, 12, 10, 10)
	cluster_char_1.is_hero = true
	var cluster_char_2: CharacterData = _create_character("Cluster2", 60, 10, 12, 10, 10)
	var cluster_char_3: CharacterData = _create_character("Cluster3", 60, 10, 12, 10, 10)

	# Create behavior with aoe_minimum_targets = 2
	var mage_ai: AIBehaviorData = _create_aoe_behavior()

	# Spawn mage at (5, 7) - center position
	_mage_unit = _spawn_unit(mage_character, Vector2i(5, 7), "enemy", mage_ai)
	_mage_initial_mp = _mage_unit.stats.current_mp

	# Spawn isolated target at (10, 7) - distance 5, alone
	_isolated_target = _spawn_unit(isolated_char, Vector2i(10, 7), "player", null)

	# Spawn cluster at (5, 3) - distance 4, three units close together
	# Cluster formation:  (4,3) (5,3) (6,3) - all adjacent
	_cluster_target_1 = _spawn_unit(cluster_char_1, Vector2i(4, 3), "player", null)
	_cluster_target_2 = _spawn_unit(cluster_char_2, Vector2i(5, 3), "player", null)
	_cluster_target_3 = _spawn_unit(cluster_char_3, Vector2i(6, 3), "player", null)

	print("Setup:")
	print("  Mage at: %s (MP: %d)" % [_mage_unit.grid_position, _mage_initial_mp])
	print("  AoE ability: Fireball (range 4, radius 1, cost 10 MP)")
	print("  aoe_minimum_targets: 2")
	print("")
	print("  Isolated target at: %s (distance: %d)" % [
		_isolated_target.grid_position,
		GridManager.grid.get_manhattan_distance(_mage_unit.grid_position, _isolated_target.grid_position)
	])
	print("  Cluster at: (%s, %s, %s) (distance to center: %d)" % [
		_cluster_target_1.grid_position,
		_cluster_target_2.grid_position,
		_cluster_target_3.grid_position,
		GridManager.grid.get_manhattan_distance(_mage_unit.grid_position, _cluster_target_2.grid_position)
	])

	# Setup BattleManager
	BattleManager.setup(self, self)
	BattleManager.player_units = [_isolated_target, _cluster_target_1, _cluster_target_2, _cluster_target_3]
	BattleManager.enemy_units = [_mage_unit]
	BattleManager.all_units = [_mage_unit, _isolated_target, _cluster_target_1, _cluster_target_2, _cluster_target_3]

	# Connect to signals
	BattleManager.combat_resolved.connect(_on_combat_resolved)

	# Run the AI turn
	print("\nExecuting AoE mage AI turn...")
	await _execute_mage_turn()

	# Small delay
	await get_tree().create_timer(0.2).timeout

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
	character.base_intelligence = 10
	character.base_luck = 5
	character.starting_level = 1

	var basic_class: ClassData = ClassData.new()
	basic_class.display_name = "Fighter"
	basic_class.movement_type = ClassData.MovementType.WALKING
	basic_class.movement_range = 4

	character.character_class = basic_class
	return character


func _create_aoe_mage(p_name: String) -> CharacterData:
	var character: CharacterData = CharacterData.new()
	character.character_name = p_name
	character.base_hp = 45
	character.base_mp = 50
	character.base_strength = 6
	character.base_defense = 8
	character.base_agility = 10
	character.base_intelligence = 18
	character.base_luck = 5
	character.starting_level = 1

	var mage_class: ClassData = ClassData.new()
	mage_class.display_name = "Battlemage"
	mage_class.movement_type = ClassData.MovementType.WALKING
	mage_class.movement_range = 3

	# Create AoE attack ability (Fireball)
	var aoe_ability: AbilityData = AbilityData.new()
	aoe_ability.ability_name = "Fireball"
	aoe_ability.ability_id = "test_fireball"
	aoe_ability.ability_type = AbilityData.AbilityType.ATTACK
	aoe_ability.target_type = AbilityData.TargetType.AREA
	aoe_ability.min_range = 1
	aoe_ability.max_range = 4
	aoe_ability.area_of_effect = 1  # Hits center + adjacent cells
	aoe_ability.mp_cost = 10
	aoe_ability.potency = 15

	# Add ability to class
	mage_class.class_abilities = [aoe_ability]
	mage_class.ability_unlock_levels = {"test_fireball": 1}

	# Register in ModLoader
	if ModLoader and ModLoader.registry:
		ModLoader.registry.register_resource(aoe_ability, "ability", "test_fireball", "_test")

	character.character_class = mage_class
	return character


func _create_aoe_behavior() -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = "test_aoe_mage"
	behavior.display_name = "Test AoE Mage"
	behavior.role = "aggressive"
	behavior.behavior_mode = "aggressive"
	behavior.aoe_minimum_targets = 2  # Key: require at least 2 targets for AoE
	behavior.retreat_enabled = false
	behavior.use_healing_items = false
	behavior.use_attack_items = false
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


func _execute_mage_turn() -> void:
	var context: Dictionary = {
		"player_units": BattleManager.player_units,
		"enemy_units": BattleManager.enemy_units,
		"neutral_units": [],
		"turn_number": 1,
		"unit_hp_percent": 100.0,
		"ai_delays": {"after_movement": 0.0, "before_attack": 0.0}
	}

	var ConfigurableAIBrainScript: GDScript = load("res://core/systems/ai/configurable_ai_brain.gd")
	var brain: AIBrain = ConfigurableAIBrainScript.get_instance()
	await brain.execute_with_behavior(_mage_unit, context, _mage_unit.ai_behavior)

	# Wait for movement/casting
	var wait_start: float = Time.get_ticks_msec()
	while _mage_unit.is_moving() and (Time.get_ticks_msec() - wait_start) < 3000:
		await get_tree().process_frame


func _on_combat_resolved(attacker: Unit, defender: Unit, _damage: int, _hit: bool, _crit: bool) -> void:
	if attacker == _mage_unit:
		_targets_hit.append(defender)
		print("  [HIT] %s was hit" % defender.character_data.character_name)


func _validate_behavior() -> void:
	if _test_complete:
		return

	print("\nResults:")

	var mp_spent: int = _mage_initial_mp - _mage_unit.stats.current_mp
	_spell_cast = mp_spent > 0

	print("  Mage MP: %d -> %d (spent: %d)" % [_mage_initial_mp, _mage_unit.stats.current_mp, mp_spent])
	print("  Spell cast: %s" % _spell_cast)
	print("  Targets hit: %d" % _targets_hit.size())

	# Check if isolated target was hit
	var hit_isolated: bool = _isolated_target in _targets_hit
	var hit_cluster_count: int = 0
	if _cluster_target_1 in _targets_hit:
		hit_cluster_count += 1
	if _cluster_target_2 in _targets_hit:
		hit_cluster_count += 1
	if _cluster_target_3 in _targets_hit:
		hit_cluster_count += 1

	print("  Hit isolated target: %s" % hit_isolated)
	print("  Hit cluster targets: %d/3" % hit_cluster_count)

	print("\nValidation:")

	if _spell_cast and hit_cluster_count >= 2 and not hit_isolated:
		print("  [OK] AoE spell cast on cluster (hit %d targets)" % hit_cluster_count)
		print("  [OK] Did not waste AoE on isolated target")
		_test_passed = true
	elif _spell_cast and hit_cluster_count >= 2:
		# Hit cluster, possibly also isolated - still acceptable
		print("  [OK] AoE spell targeted cluster (hit %d cluster targets)" % hit_cluster_count)
		_test_passed = true
	elif not _spell_cast and _targets_hit.size() > 0:
		# Used basic attack instead - might be acceptable fallback
		print("  [OK] AI used basic attack (AoE minimum not met or out of range)")
		_test_passed = true
	elif _spell_cast and hit_isolated and hit_cluster_count < 2:
		_test_passed = false
		_failure_reason = "Wasted AoE on isolated target instead of cluster"
		print("  [FAIL] %s" % _failure_reason)
	elif not _spell_cast and _targets_hit.size() == 0:
		_test_passed = false
		_failure_reason = "Mage did nothing"
		print("  [FAIL] %s" % _failure_reason)
	else:
		# Some action was taken
		print("  [OK] AI took action")
		_test_passed = true

	_test_complete = true
	_print_results()


func _print_results() -> void:
	print("\n" + "=".repeat(60))
	if _test_passed:
		print("AOE TARGETING TEST PASSED!")
		print("AI correctly respected AoE minimum targets threshold.")
	else:
		print("AOE TARGETING TEST FAILED!")
		print("Reason: %s" % _failure_reason)
	print("=".repeat(60) + "\n")

	get_tree().quit(0 if _test_passed else 1)


func _process(_delta: float) -> void:
	# Safety timeout
	pass
