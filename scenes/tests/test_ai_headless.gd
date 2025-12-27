## AUTOMATED HEADLESS TEST
##
## Purpose: Automated AI regression testing without UI
## This runs AI turns automatically without requiring player input.
## Used for quick validation that battle systems work correctly.
##
## Note: For manual interactive testing, use mods/_sandbox/scenes/test_xp_system.tscn
extends Node2D

const UnitScript: GDScript = preload("res://core/components/unit.gd")
const UnitUtils: GDScript = preload("res://core/utils/unit_utils.gd")

var _test_complete: bool = false
var _turn_count: int = 0
var _max_turns: int = 10


func _ready() -> void:
	print("\n=== AI Headless Test Starting ===\n")

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
	var player_character: CharacterData = _create_character("Hero", 20, 10, 10, 8, 7)
	player_character.is_hero = true  # Required for TurnManager battle end detection
	var enemy_character: CharacterData = _create_character("Goblin", 15, 5, 8, 6, 6)

	# Load AI behavior (new data-driven system)
	var aggressive_ai: AIBehaviorData = load("res://mods/_base_game/data/ai_behaviors/aggressive_melee.tres")
	if not aggressive_ai:
		# Fallback: create minimal aggressive behavior for testing
		aggressive_ai = AIBehaviorData.new()
		aggressive_ai.display_name = "Test Aggressive"
		aggressive_ai.behavior_mode = "aggressive"

	# Spawn units
	var player_unit: Unit = _spawn_unit(player_character, Vector2i(2, 5), "player", null)
	var enemy_unit: Unit = _spawn_unit(enemy_character, Vector2i(7, 5), "enemy", aggressive_ai)

	# Setup BattleManager
	BattleManager.setup(self, self)
	BattleManager.player_units = [player_unit]
	BattleManager.enemy_units = [enemy_unit]
	BattleManager.all_units = [player_unit, enemy_unit]

	# Connect signals
	TurnManager.enemy_turn_started.connect(_on_enemy_turn_started)
	TurnManager.player_turn_started.connect(_on_player_turn_started)
	TurnManager.unit_turn_ended.connect(_on_unit_turn_ended)
	TurnManager.battle_ended.connect(_on_battle_ended)
	BattleManager.combat_resolved.connect(_on_combat_resolved)

	# Start battle
	var all_units: Array[Unit] = [player_unit, enemy_unit]
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
	var unit: Unit = unit_scene.instantiate()
	unit.initialize(character, p_faction, p_ai_behavior)
	unit.grid_position = cell
	unit.position = Vector2(cell.x * 32, cell.y * 32)
	add_child(unit)
	# Register with GridManager (critical for AI pathfinding/occupation checks)
	GridManager.set_cell_occupied(cell, unit)
	return unit


func _on_player_turn_started(unit: Unit) -> void:
	print("\n[PLAYER TURN] %s at %s" % [UnitUtils.get_display_name(unit), unit.grid_position])
	print("  Stats: %s" % unit.get_stats_summary())

	# Auto-end player turn (we're testing AI, not player input)
	await get_tree().create_timer(0.1).timeout
	print("  -> Ending player turn automatically")
	TurnManager.end_unit_turn(unit)


func _on_enemy_turn_started(unit: Unit) -> void:
	print("\n[ENEMY TURN] %s at %s" % [UnitUtils.get_display_name(unit), unit.grid_position])
	print("  Stats: %s" % unit.get_stats_summary())
	# AIController will handle the turn


func _on_unit_turn_ended(unit: Unit) -> void:
	print("  -> Turn ended for %s" % UnitUtils.get_display_name(unit))


func _on_combat_resolved(attacker: Unit, defender: Unit, damage: int, hit: bool, crit: bool) -> void:
	var hit_str: String = "HIT" if hit else "MISS"
	var crit_str: String = " (CRIT!)" if crit else ""
	print("  [COMBAT] %s attacks %s: %s for %d damage%s" % [
		UnitUtils.get_display_name(attacker),
		UnitUtils.get_display_name(defender),
		hit_str,
		damage,
		crit_str
	])


func _on_battle_ended(victory: bool) -> void:
	print("\n=== BATTLE ENDED ===")
	if victory:
		print("RESULT: Player Victory!")
	else:
		print("RESULT: Player Defeat!")

	_test_complete = true
	await get_tree().create_timer(0.5).timeout
	print("\n=== AI Test Complete ===")
	get_tree().quit()


func _process(_delta: float) -> void:
	# Safety: quit after max turns
	if TurnManager.turn_number > _max_turns and not _test_complete:
		print("\n=== MAX TURNS REACHED ===")
		print("Test ran for %d turns without completion" % _max_turns)
		_test_complete = true
		get_tree().quit()
