## DEBUG: Defensive AI Role Behavior Test
##
## Tests the defensive role AI to understand why units might move
## away from players instead of toward them.
##
## Scenario similar to "Battle of Noobs":
## - 3 player units (spawned together)
## - 1 defensive role enemy (ROUS style)
## - 1 aggressive role ally (for VIP detection)
extends Node2D

const UnitScript: GDScript = preload("res://core/components/unit.gd")
const UnitUtils: GDScript = preload("res://core/utils/unit_utils.gd")

var _test_complete: bool = false
var _turn_count: int = 0
var _max_turns: int = 5


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("DEFENSIVE AI DEBUG TEST")
	print("=".repeat(60))

	# Create minimal TileMapLayer for GridManager
	var tilemap_layer: TileMapLayer = TileMapLayer.new()
	var tileset: TileSet = TileSet.new()
	tilemap_layer.tile_set = tileset
	add_child(tilemap_layer)

	# Setup larger grid (similar to battle map)
	var grid_resource: Grid = Grid.new()
	grid_resource.grid_size = Vector2i(20, 20)
	grid_resource.cell_size = 32
	GridManager.setup_grid(grid_resource, tilemap_layer)

	# Load AI behaviors
	var aggressive_ai: AIBehaviorData = load("res://mods/_base_game/data/ai_behaviors/aggressive_melee.tres")
	var defensive_ai: AIBehaviorData = load("res://mods/_base_game/data/ai_behaviors/defensive_tank.tres")

	if not aggressive_ai or not defensive_ai:
		push_error("Failed to load AI behaviors!")
		get_tree().quit()
		return

	print("\nLoaded AI Behaviors:")
	print("  Aggressive: role=%s, mode=%s" % [aggressive_ai.get_effective_role(), aggressive_ai.get_effective_mode()])
	print("  Defensive: role=%s, mode=%s, alert_range=%d, engagement_range=%d" % [
		defensive_ai.get_effective_role(),
		defensive_ai.get_effective_mode(),
		defensive_ai.alert_range,
		defensive_ai.engagement_range
	])

	# Create characters
	var hero_character: CharacterData = _create_character("Hero", 30, 10, 12, 10, 8, true)
	var mage_character: CharacterData = _create_character("Mage", 20, 20, 8, 6, 7, false)
	var warrior_character: CharacterData = _create_character("Warrior", 25, 5, 14, 12, 6, false)

	var defender_character: CharacterData = _create_character("Defender", 40, 5, 10, 15, 4, false)
	var attacker_character: CharacterData = _create_character("Attacker", 25, 5, 12, 8, 6, false)

	# Mark attacker as a "boss" so defender sees it as VIP
	attacker_character.is_boss = true
	attacker_character.ai_threat_modifier = 2.0

	# Position setup similar to Battle of Noobs:
	# Players spawn around (14, 12)
	# Defender (defensive role) at (17, 18) - far from players
	# Attacker (aggressive role, boss) at (15, 16) - between defender and players

	print("\nUnit Positions:")
	print("  Player spawn area: around (14, 12)")
	print("  Defensive enemy: (17, 18) - should protect Attacker")
	print("  Aggressive enemy (boss): (15, 16) - VIP for defender")

	# Spawn units
	var hero: Node2D = _spawn_unit(hero_character, Vector2i(14, 12), "player", null)
	var mage: Node2D = _spawn_unit(mage_character, Vector2i(15, 13), "player", null)
	var warrior: Node2D = _spawn_unit(warrior_character, Vector2i(13, 13), "player", null)

	var defender: Node2D = _spawn_unit(defender_character, Vector2i(17, 18), "enemy", defensive_ai)
	var attacker: Node2D = _spawn_unit(attacker_character, Vector2i(15, 16), "enemy", aggressive_ai)

	# Print distances
	var def_to_hero: int = GridManager.grid.get_manhattan_distance(Vector2i(17, 18), Vector2i(14, 12))
	var def_to_attacker: int = GridManager.grid.get_manhattan_distance(Vector2i(17, 18), Vector2i(15, 16))
	var attacker_to_hero: int = GridManager.grid.get_manhattan_distance(Vector2i(15, 16), Vector2i(14, 12))

	print("\nDistances:")
	print("  Defender to Hero: %d tiles" % def_to_hero)
	print("  Defender to Attacker (VIP): %d tiles" % def_to_attacker)
	print("  Attacker to Hero: %d tiles" % attacker_to_hero)

	# Setup BattleManager
	BattleManager.setup(self, self)
	BattleManager.player_units = [hero, mage, warrior]
	BattleManager.enemy_units = [defender, attacker]
	BattleManager.all_units = [hero, mage, warrior, defender, attacker]

	# Connect signals
	TurnManager.enemy_turn_started.connect(_on_enemy_turn_started)
	TurnManager.player_turn_started.connect(_on_player_turn_started)
	TurnManager.unit_turn_ended.connect(_on_unit_turn_ended)
	TurnManager.battle_ended.connect(_on_battle_ended)
	BattleManager.combat_resolved.connect(_on_combat_resolved)

	print("\n" + "=".repeat(60))
	print("STARTING BATTLE - Watch defender behavior")
	print("=".repeat(60) + "\n")

	# Start battle
	TurnManager.start_battle(BattleManager.all_units)


func _create_character(p_name: String, hp: int, mp: int, str_val: int, def_val: int, agi: int, is_hero: bool) -> CharacterData:
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
	character.is_hero = is_hero

	var basic_class: ClassData = ClassData.new()
	basic_class.display_name = "Fighter"
	basic_class.movement_type = ClassData.MovementType.WALKING
	basic_class.movement_range = 4

	character.character_class = basic_class
	return character


func _spawn_unit(character: CharacterData, cell: Vector2i, p_faction: String, p_ai_behavior: AIBehaviorData) -> Node2D:
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")
	var unit: Node2D = unit_scene.instantiate()
	unit.initialize(character, p_faction, p_ai_behavior)
	unit.grid_position = cell
	unit.position = Vector2(cell.x * 32, cell.y * 32)
	add_child(unit)
	# Register with GridManager (critical for AI pathfinding/occupation checks)
	GridManager.set_cell_occupied(cell, unit)
	return unit


func _on_player_turn_started(unit: Node2D) -> void:
	print("\n[PLAYER TURN] %s at %s" % [UnitUtils.get_display_name(unit), unit.grid_position])
	# Auto-end player turn
	await get_tree().create_timer(0.1).timeout
	TurnManager.end_unit_turn(unit)


func _on_enemy_turn_started(unit: Node2D) -> void:
	var ai_name: String = "None"
	if unit.ai_behavior:
		ai_name = "%s (role=%s)" % [unit.ai_behavior.display_name, unit.ai_behavior.get_effective_role()]
	print("\n[ENEMY TURN] %s at %s | AI: %s" % [UnitUtils.get_display_name(unit), unit.grid_position, ai_name])


func _on_unit_turn_ended(unit: Node2D) -> void:
	print("  -> Turn ended: %s now at %s" % [UnitUtils.get_display_name(unit), unit.grid_position])
	_turn_count += 1


func _on_combat_resolved(attacker: Node2D, defender: Node2D, damage: int, hit: bool, crit: bool) -> void:
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
	print("\n" + "=".repeat(60))
	print("BATTLE ENDED: %s" % ("Victory" if victory else "Defeat"))
	print("=".repeat(60))
	_test_complete = true
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func _process(_delta: float) -> void:
	if _turn_count > _max_turns * 5 and not _test_complete:
		print("\n" + "=".repeat(60))
		print("MAX TURNS REACHED - Test complete")
		print("=".repeat(60))
		_test_complete = true
		get_tree().quit()
