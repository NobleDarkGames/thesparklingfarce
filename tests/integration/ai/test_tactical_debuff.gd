## Tactical Debuff Usage Integration Test
##
## Tests that tactical AI units prioritize casting debuffs on
## high-threat targets instead of just attacking.
##
## Validates:
## - Tactical mage casts debuff when available
## - MP is consumed for the spell
## - Mage doesn't just spam basic attacks
extends Node2D

const UnitScript = preload("res://core/components/unit.gd")

# Test state
var _test_complete: bool = false
var _test_passed: bool = false
var _failure_reason: String = ""

# Units
var _mage_unit: Unit
var _target_unit: Unit

# Tracking
var _mage_initial_mp: int = 0
var _spell_cast: bool = false
var _combat_occurred: bool = false


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("TACTICAL DEBUFF USAGE TEST")
	print("=".repeat(60))
	print("Testing: Tactical mage should cast debuff on target instead of attacking\n")

	# Create minimal TileMapLayer for GridManager
	var tilemap_layer: TileMapLayer = TileMapLayer.new()
	var tileset: TileSet = TileSet.new()
	tilemap_layer.tile_set = tileset
	add_child(tilemap_layer)

	# Setup grid
	var grid_resource: Grid = Grid.new()
	grid_resource.grid_size = Vector2i(15, 10)
	grid_resource.cell_size = 32
	GridManager.setup_grid(grid_resource, tilemap_layer)

	# Create tactical mage character with debuff ability
	var mage_character: CharacterData = _create_tactical_mage("TacticalMage")

	# Create target character (high threat - damage dealer)
	var target_character: CharacterData = _create_character("DamageDealer", 80, 10, 25, 10, 12)
	target_character.is_hero = true

	# Create tactical behavior
	var mage_ai: AIBehaviorData = _create_tactical_behavior()

	# Spawn mage at (5, 5)
	_mage_unit = _spawn_unit(mage_character, Vector2i(5, 5), "enemy", mage_ai)
	_mage_initial_mp = _mage_unit.stats.current_mp

	# Spawn target at (7, 5) - distance 2, within debuff range
	_target_unit = _spawn_unit(target_character, Vector2i(7, 5), "player", null)

	print("Setup:")
	print("  Mage at: %s (MP: %d)" % [_mage_unit.grid_position, _mage_initial_mp])
	print("  Target at: %s (high-threat damage dealer)" % _target_unit.grid_position)
	print("  Distance: %d (within debuff range)" % GridManager.grid.get_manhattan_distance(
		_mage_unit.grid_position, _target_unit.grid_position
	))

	# Setup BattleManager
	BattleManager.setup(self, self)
	BattleManager.player_units = [_target_unit]
	BattleManager.enemy_units = [_mage_unit]
	BattleManager.all_units = [_mage_unit, _target_unit]

	# Connect to combat signal
	BattleManager.combat_resolved.connect(_on_combat_resolved)

	# Run the AI turn
	print("\nExecuting tactical mage AI turn...")
	await _execute_mage_turn()

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
	character.base_intelligence = 15
	character.base_luck = 5
	character.starting_level = 1

	var basic_class: ClassData = ClassData.new()
	basic_class.display_name = "Fighter"
	basic_class.movement_type = ClassData.MovementType.WALKING
	basic_class.movement_range = 4

	character.character_class = basic_class
	return character


func _create_tactical_mage(p_name: String) -> CharacterData:
	var character: CharacterData = CharacterData.new()
	character.character_name = p_name
	character.base_hp = 50
	character.base_mp = 40
	character.base_strength = 8
	character.base_defense = 8
	character.base_agility = 10
	character.base_intelligence = 20
	character.base_luck = 5
	character.starting_level = 1

	# Create mage class with debuff ability
	var mage_class: ClassData = ClassData.new()
	mage_class.display_name = "Tactician"
	mage_class.movement_type = ClassData.MovementType.WALKING
	mage_class.movement_range = 3

	# Create debuff ability (Weaken - reduces target's attack)
	var debuff_ability: AbilityData = AbilityData.new()
	debuff_ability.ability_name = "Weaken"
	debuff_ability.ability_id = "test_weaken"
	debuff_ability.ability_type = AbilityData.AbilityType.DEBUFF
	debuff_ability.target_type = AbilityData.TargetType.SINGLE_ENEMY
	debuff_ability.min_range = 1
	debuff_ability.max_range = 3
	debuff_ability.mp_cost = 8
	debuff_ability.potency = 5  # Reduces stat by 5

	# Add ability to class
	mage_class.class_abilities = [debuff_ability]
	mage_class.ability_unlock_levels = {"test_weaken": 1}

	# Register in ModLoader so execute_ai_spell can find it
	if ModLoader and ModLoader.registry:
		ModLoader.registry.register_resource(debuff_ability, "ability", "test_weaken", "_test")

	character.character_class = mage_class
	return character


func _create_tactical_behavior() -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = "test_tactical"
	behavior.display_name = "Test Tactical"
	behavior.role = "tactical"  # Key: tactical role prioritizes debuffs
	behavior.behavior_mode = "cautious"
	behavior.use_status_effects = true
	behavior.retreat_enabled = false
	behavior.use_healing_items = false
	behavior.use_attack_items = false
	# High weight for damage dealers (our target)
	behavior.threat_weights = {
		"damage_dealer": 2.0,
		"high_attack": 1.5
	}
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

	# Wait for any movement/casting to complete
	var wait_start: float = Time.get_ticks_msec()
	while _mage_unit.is_moving() and (Time.get_ticks_msec() - wait_start) < 3000:
		await get_tree().process_frame


func _on_combat_resolved(attacker: Unit, _defender: Unit, _damage: int, _hit: bool, _crit: bool) -> void:
	if attacker == _mage_unit:
		_combat_occurred = true
		print("  [COMBAT] Mage used basic attack (not ideal for tactical role)")


func _validate_behavior() -> void:
	if _test_complete:
		return

	print("\nResults:")

	var mp_spent: int = _mage_initial_mp - _mage_unit.stats.current_mp
	print("  Mage MP: %d -> %d (spent: %d)" % [_mage_initial_mp, _mage_unit.stats.current_mp, mp_spent])
	print("  Basic attack occurred: %s" % _combat_occurred)

	# Check if MP was spent (indicating spell was cast)
	_spell_cast = mp_spent > 0

	print("\nValidation:")

	if _spell_cast and not _combat_occurred:
		print("  [OK] Mage cast a spell (spent %d MP)" % mp_spent)
		print("  [OK] Did not resort to basic attack")
		_test_passed = true
	elif _spell_cast and _combat_occurred:
		# Cast spell AND attacked - could happen if debuff failed or had extra action
		print("  [OK] Mage cast a spell (spent %d MP)" % mp_spent)
		print("  [WARN] Also used basic attack (unusual but not failure)")
		_test_passed = true
	elif not _spell_cast and _combat_occurred:
		_test_passed = false
		_failure_reason = "Mage used basic attack instead of casting debuff"
		print("  [FAIL] %s" % _failure_reason)
	else:
		_test_passed = false
		_failure_reason = "Mage did nothing (no spell cast, no attack)"
		print("  [FAIL] %s" % _failure_reason)

	_test_complete = true
	_print_results()


func _print_results() -> void:
	print("\n" + "=".repeat(60))
	if _test_passed:
		print("TACTICAL DEBUFF TEST PASSED!")
		print("Tactical mage correctly prioritized debuff over basic attack.")
	else:
		print("TACTICAL DEBUFF TEST FAILED!")
		print("Reason: %s" % _failure_reason)
	print("=".repeat(60) + "\n")

	get_tree().quit(0 if _test_passed else 1)


func _process(_delta: float) -> void:
	# Safety timeout
	pass
