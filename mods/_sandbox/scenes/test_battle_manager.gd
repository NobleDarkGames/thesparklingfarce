## Simple test for BattleManager and CombatCalculator
##
## Based on the working test_unit.tscn pattern.
## Tests the new Week 3 systems with minimal complexity.
extends Node2D

const UnitScene: PackedScene = preload("res://scenes/unit.tscn")

var _player_unit: Node2D = null
var _enemy_unit: Node2D = null


func _ready() -> void:
	print("\n========================================")
	print("TEST: BattleManager & CombatCalculator")
	print("========================================\n")

	# Initialize GridManager (basic setup)
	var grid_resource: Grid = Grid.new()
	grid_resource.grid_size = Vector2i(20, 11)
	grid_resource.cell_size = 32
	GridManager.setup_grid(grid_resource, $Map/GroundLayer)

	# Generate visual grid
	_generate_visual_grid()

	# Create test characters
	var hero_data: CharacterData = _create_character("Hero", 15, 10, 8, 7, 6, 5, 4)
	var goblin_data: CharacterData = _create_character("Goblin", 12, 5, 6, 4, 5, 3, 3)

	# Spawn units directly (simple approach)
	_player_unit = UnitScene.instantiate()
	_player_unit.initialize(hero_data, "player", "")
	_player_unit.grid_position = Vector2i(3, 5)
	_player_unit.position = GridManager.cell_to_world(Vector2i(3, 5))
	$Units.add_child(_player_unit)

	_enemy_unit = UnitScene.instantiate()
	_enemy_unit.initialize(goblin_data, "enemy", "aggressive")
	_enemy_unit.grid_position = Vector2i(10, 5)
	_enemy_unit.position = GridManager.cell_to_world(Vector2i(10, 5))
	$Units.add_child(_enemy_unit)

	print("Units spawned:")
	print("  - %s at %s (cyan square)" % [_player_unit.get_display_name(), _player_unit.grid_position])
	print("  - %s at %s (red square)" % [_enemy_unit.get_display_name(), _enemy_unit.grid_position])

	# Setup BattleManager (just for combat resolution)
	BattleManager.setup(self, $Units)
	BattleManager.all_units = [_player_unit, _enemy_unit]
	BattleManager.player_units = [_player_unit]
	BattleManager.enemy_units = [_enemy_unit]

	print("\nBattleManager initialized")
	print("\nControls:")
	print("  SPACE: Attack enemy (tests CombatCalculator)")
	print("  ESC: Quit")
	print("\nPress SPACE to test combat!")


func _generate_visual_grid() -> void:
	var grid_visual: Node2D = Node2D.new()
	grid_visual.name = "GridVisual"
	$Map.add_child(grid_visual)

	for x: int in range(20):
		for y: int in range(11):
			var cell_rect: ColorRect = ColorRect.new()
			cell_rect.size = Vector2(32, 32)
			cell_rect.position = Vector2(x * 32, y * 32)

			if (x + y) % 2 == 0:
				cell_rect.color = Color(0.3, 0.4, 0.3)
			else:
				cell_rect.color = Color(0.4, 0.5, 0.4)

			cell_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid_visual.add_child(cell_rect)


func _create_character(name: String, hp: int, mp: int, str_val: int, def_val: int, agi: int, int_val: int, luk: int) -> CharacterData:
	var character: CharacterData = CharacterData.new()
	character.character_name = name

	var basic_class: ClassData = ClassData.new()
	basic_class.display_name = "Warrior"
	basic_class.movement_range = 4
	basic_class.movement_type = 0

	character.character_class = basic_class
	character.base_hp = hp
	character.base_mp = mp
	character.base_strength = str_val
	character.base_defense = def_val
	character.base_agility = agi
	character.base_intelligence = int_val
	character.base_luck = luk
	character.starting_level = 1

	return character


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

	# Test combat with SPACE
	if event.is_action_pressed("ui_accept"):
		_test_combat()


func _test_combat() -> void:
	if not _player_unit or not _enemy_unit:
		return

	if not _player_unit.is_alive() or not _enemy_unit.is_alive():
		print("\nBattle Over! Press R to restart or ESC to quit")
		return

	print("\n--- Testing Combat ---")
	print("%s attacks %s!" % [_player_unit.get_display_name(), _enemy_unit.get_display_name()])

	# Use CombatCalculator directly
	var attacker_stats: UnitStats = _player_unit.stats
	var defender_stats: UnitStats = _enemy_unit.stats

	var hit_chance: int = CombatCalculator.calculate_hit_chance(attacker_stats, defender_stats)
	var hit: bool = CombatCalculator.roll_hit(hit_chance)

	print("  Hit chance: %d%%" % hit_chance)

	if not hit:
		print("  → MISS!")
		return

	var damage: int = CombatCalculator.calculate_physical_damage(attacker_stats, defender_stats)
	var crit_chance: int = CombatCalculator.calculate_crit_chance(attacker_stats, defender_stats)
	var crit: bool = CombatCalculator.roll_crit(crit_chance)

	if crit:
		damage *= 2
		print("  → CRITICAL HIT!")

	print("  → HIT! %d damage" % damage)

	# Apply damage
	defender_stats.current_hp -= damage
	defender_stats.current_hp = maxi(0, defender_stats.current_hp)

	print("  %s: %d/%d HP" % [
		_enemy_unit.get_display_name(),
		defender_stats.current_hp,
		defender_stats.max_hp
	])

	# Check death
	if defender_stats.current_hp <= 0:
		print("\n🎉 %s defeated! Victory!" % _enemy_unit.get_display_name())
		_enemy_unit.modulate = Color(1, 1, 1, 0.3)  # Fade out

	print("\n(Press SPACE again to attack)")
