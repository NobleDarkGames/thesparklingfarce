## Battle Flow Integration Test
##
## Tests the complete battle flow from start to victory.
## Uses controlled combat to ensure predictable outcomes.
##
## Validates:
## - Battle initialization and setup
## - Turn order calculation
## - Combat execution and damage application
## - Victory condition triggering
## - All relevant signals firing correctly
extends Node2D

const UnitScript: GDScript = preload("res://core/components/unit.gd")

# Test state tracking
var _test_complete: bool = false
var _turn_count: int = 0
var _max_turns: int = 20

# Event tracking for validation
var _events_recorded: Array[String] = []
var _expected_events: Array[String] = [
	"battle_started",
	"turn_started",
	"combat_occurred",
	"battle_victory"
]

# Units
var _player_unit: Unit
var _enemy_unit: Unit


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("BATTLE FLOW INTEGRATION TEST")
	print("=".repeat(60) + "\n")

	# Create minimal TileMapLayer for GridManager
	var tilemap_layer: TileMapLayer = TileMapLayer.new()
	var tileset: TileSet = TileSet.new()
	tilemap_layer.tile_set = tileset
	add_child(tilemap_layer)

	# Setup minimal grid
	var grid_resource: Grid = Grid.new()
	grid_resource.grid_size = Vector2i(10, 10)
	grid_resource.cell_size = 32
	GridManager.setup_grid(grid_resource, tilemap_layer)

	# Create test characters
	# Hero: Very strong to guarantee quick victory (high STR, high DEF)
	var player_character: CharacterData = _create_character("TestHero", 50, 10, 30, 20, 15)
	player_character.is_hero = true  # Required for TurnManager battle end detection
	# Goblin: Weak enemy that will die quickly (low HP, low DEF)
	var enemy_character: CharacterData = _create_character("TestGoblin", 10, 5, 5, 2, 5)

	# Load AI behavior for enemy (new data-driven system)
	var aggressive_ai: AIBehaviorData = load("res://mods/_base_game/data/ai_behaviors/aggressive_melee.tres")
	if not aggressive_ai:
		# Fallback: create minimal aggressive behavior for testing
		aggressive_ai = AIBehaviorData.new()
		aggressive_ai.display_name = "Test Aggressive"
		aggressive_ai.behavior_mode = "aggressive"

	# Load AI behavior for player (also aggressive - will attack)
	var player_ai: AIBehaviorData = aggressive_ai

	# Spawn units adjacent so combat can happen immediately
	_player_unit = _spawn_unit(player_character, Vector2i(3, 5), "player", player_ai)
	_enemy_unit = _spawn_unit(enemy_character, Vector2i(4, 5), "enemy", aggressive_ai)

	# Setup BattleManager
	BattleManager.setup(self, self)
	BattleManager.player_units = [_player_unit]
	BattleManager.enemy_units = [_enemy_unit]
	BattleManager.all_units = [_player_unit, _enemy_unit]

	# Connect signals for tracking
	TurnManager.enemy_turn_started.connect(_on_enemy_turn_started)
	TurnManager.player_turn_started.connect(_on_player_turn_started)
	TurnManager.unit_turn_ended.connect(_on_unit_turn_ended)
	TurnManager.battle_ended.connect(_on_battle_ended)
	BattleManager.combat_resolved.connect(_on_combat_resolved)

	# Record battle start event
	_record_event("battle_started")

	# Start battle
	var all_units: Array[Unit] = [_player_unit, _enemy_unit]
	TurnManager.start_battle(all_units)


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
	basic_class.display_name = "Warrior"
	basic_class.movement_type = ClassData.MovementType.WALKING
	basic_class.movement_range = 4

	character.character_class = basic_class
	return character


func _spawn_unit(character: CharacterData, cell: Vector2i, p_faction: String, p_ai_behavior: AIBehaviorData) -> Unit:
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")
	var unit: Unit = unit_scene.instantiate() as Unit
	unit.initialize(character, p_faction, p_ai_behavior)
	unit.grid_position = cell
	unit.position = Vector2(cell.x * 32, cell.y * 32)
	add_child(unit)
	# Register with GridManager for pathfinding and occupation checks
	GridManager.set_cell_occupied(cell, unit)
	return unit


func _record_event(event_name: String) -> void:
	_events_recorded.append(event_name)
	print("[EVENT] %s" % event_name)


func _on_player_turn_started(unit: Unit) -> void:
	_record_event("turn_started")
	print("\n[PLAYER TURN] %s at %s" % [unit.get_display_name(), unit.grid_position])
	print("  Stats: %s" % unit.get_stats_summary())

	# For integration testing: manually invoke the AI for player units
	# TurnManager doesn't auto-invoke AI for player faction
	if unit.ai_behavior:
		print("  -> Invoking AI behavior for player unit (test automation)")

		# Swap player/enemy in context so AI targets enemies, not allies
		var context: Dictionary = {
			"player_units": BattleManager.enemy_units,
			"enemy_units": BattleManager.player_units,
			"neutral_units": BattleManager.neutral_units,
			"turn_number": TurnManager.turn_number,
			"ai_delays": {"after_movement": 0.0, "before_attack": 0.0}
		}

		# Use ConfigurableAIBrain to interpret the behavior data
		var ConfigurableAIBrainScript: GDScript = load("res://core/systems/ai/configurable_ai_brain.gd")
		var brain: AIBrain = ConfigurableAIBrainScript.get_instance()
		await brain.execute_with_behavior(unit, context, unit.ai_behavior)

		# End turn if not already ended by combat
		if TurnManager.active_unit == unit:
			TurnManager.end_unit_turn(unit)
	else:
		print("  -> No AI behavior, ending turn")
		await get_tree().create_timer(0.1).timeout
		TurnManager.end_unit_turn(unit)


func _on_enemy_turn_started(unit: Unit) -> void:
	_record_event("turn_started")
	print("\n[ENEMY TURN] %s at %s" % [unit.get_display_name(), unit.grid_position])
	print("  Stats: %s" % unit.get_stats_summary())
	# AIController will handle the turn


func _on_unit_turn_ended(unit: Unit) -> void:
	print("  -> Turn ended for %s" % unit.get_display_name())


func _on_combat_resolved(attacker: Unit, defender: Unit, damage: int, hit: bool, crit: bool) -> void:
	_record_event("combat_occurred")
	var hit_str: String = "HIT" if hit else "MISS"
	var crit_str: String = " (CRIT!)" if crit else ""
	print("  [COMBAT] %s attacks %s: %s for %d damage%s" % [
		attacker.get_display_name(),
		defender.get_display_name(),
		hit_str,
		damage,
		crit_str
	])


func _on_battle_ended(victory: bool) -> void:
	if victory:
		_record_event("battle_victory")
		print("\n[VICTORY] Player won the battle!")
	else:
		_record_event("battle_defeat")
		print("\n[DEFEAT] Player lost the battle!")

	_test_complete = true
	await get_tree().create_timer(0.2).timeout
	_print_test_results()
	get_tree().quit(0 if _validate_events() else 1)


func _validate_events() -> bool:
	var all_found: bool = true
	for expected in _expected_events:
		if expected not in _events_recorded:
			print("[FAIL] Missing expected event: %s" % expected)
			all_found = false

	return all_found


func _print_test_results() -> void:
	print("\n" + "=".repeat(60))
	print("INTEGRATION TEST RESULTS")
	print("=".repeat(60))

	print("\nEvents recorded:")
	for event in _events_recorded:
		print("  - %s" % event)

	print("\nEvent validation:")
	for expected in _expected_events:
		var status: String = "[OK]" if expected in _events_recorded else "[MISSING]"
		print("  %s %s" % [status, expected])

	print("\n" + "=".repeat(60))
	if _validate_events():
		print("INTEGRATION TEST PASSED!")
	else:
		print("INTEGRATION TEST FAILED!")
	print("=".repeat(60) + "\n")


func _process(_delta: float) -> void:
	# Safety: quit after max turns
	if TurnManager.turn_number > _max_turns and not _test_complete:
		print("\n[TIMEOUT] Max turns (%d) reached without battle resolution" % _max_turns)
		_test_complete = true
		_print_test_results()
		get_tree().quit(1)
