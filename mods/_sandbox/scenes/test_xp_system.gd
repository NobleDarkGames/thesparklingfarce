## XP SYSTEM TEST SCENE
##
## Tests the experience and leveling system with multiple party members.
## Demonstrates:
## - Multiple player units in a party
## - XP gains from combat (damage + kill bonus)
## - Participation XP for nearby allies
## - Level-ups with stat increases
## - Growth rate system
##
## Setup: 3 player units vs 2 enemies (easy kills to test level-ups)
##
## Controls: Same as test_unit.gd
extends "res://mods/_sandbox/scenes/test_unit.gd"

## Override _ready to setup a multi-member party
func _ready() -> void:
	print("\n=== XP SYSTEM TEST SCENE ===")
	print("Setting up party with 3 members...\n")

	# Find layers
	_ground_layer = $Map/GroundLayer
	_highlight_layer = $Map/HighlightLayer

	if not _ground_layer or not _highlight_layer:
		push_error("TestXP: Missing layers")
		return

	# Generate test map
	_generate_test_map()

	# Initialize GridManager
	var grid_resource: Grid = Grid.new()
	grid_resource.grid_size = Vector2i(20, 11)
	grid_resource.cell_size = 32

	GridManager.setup_grid(grid_resource, _ground_layer)
	GridManager.set_highlight_layer(_highlight_layer)

	# Create party members
	var party: Array[Resource] = []

	# Member 1: Ted (Fighter - high STR, low INT)
	var ted: CharacterData = load("res://mods/_base_game/data/characters/character_1763004880.tres")
	if ted:
		party.append(ted)
	else:
		push_warning("Failed to load Ted, creating fallback")
		party.append(_create_test_character("Ted", 15, 10, 8, 7, 6, 5, 4))

	# Member 2: Create a Mage (low STR, high INT)
	var mage: CharacterData = _create_test_character("Mage", 12, 15, 4, 5, 7, 9, 6)
	party.append(mage)

	# Member 3: Create a Healer (balanced, focus on MP)
	var healer: CharacterData = _create_test_character("Healer", 14, 18, 5, 6, 6, 8, 7)
	party.append(healer)

	# Set up PartyManager with our party
	PartyManager.set_party(party)
	print("PartyManager: %d members in party" % PartyManager.get_party_size())

	# Manually spawn party members (in a formation)
	# Note: Later, BattleManager will do this automatically
	var spawn_positions: Array[Vector2i] = [
		Vector2i(2, 4),  # Ted (leader) - front left
		Vector2i(3, 4),  # Mage - front right
		Vector2i(2, 5),  # Healer - back row
	]

	for i in range(party.size()):
		var character: CharacterData = party[i]
		var position: Vector2i = spawn_positions[i]
		var unit: Node2D = _spawn_unit(character, position, "player", null)

		if i == 0:
			_test_unit = unit  # Track first unit as primary test unit

		print("Spawned: %s at %s" % [character.character_name, position])

	# Load enemy character (Goblin)
	var enemy_character: CharacterData = load("res://mods/_base_game/data/characters/character_goblin.tres")
	if not enemy_character:
		enemy_character = _create_test_character("Goblin", 12, 5, 6, 4, 5, 3, 3)

	# Create AI brain for enemies
	var AIAggressiveClass: GDScript = load("res://mods/base_game/ai_brains/ai_aggressive.gd")
	var aggressive_ai: Resource = AIAggressiveClass.new()

	# Spawn 2 weaker enemies (for easy testing)
	_enemy_unit = _spawn_unit(enemy_character, Vector2i(8, 4), "enemy", aggressive_ai)
	var enemy_2: Node2D = _spawn_unit(enemy_character, Vector2i(9, 5), "enemy", aggressive_ai)

	print("\n=== XP Test Scene Ready ===")
	print("Party: 3 members (Ted, Mage, Healer)")
	print("Enemies: 2 Goblins")
	print("\nTEST PLAN:")
	print("1. Attack enemies with Ted (should gain damage XP)")
	print("2. Kill an enemy (should gain kill bonus XP)")
	print("3. Check that Mage/Healer get participation XP (they're within 3 tiles)")
	print("4. Continue fighting until someone levels up")
	print("5. Observe stat increases and console output")
	print("\nStarting battle...\n")

	# Setup action menu UI
	_action_menu = ActionMenuScene.instantiate()
	$UI.add_child(_action_menu)
	InputManager.set_action_menu(_action_menu)

	# Setup grid cursor
	_grid_cursor = GridCursorScene.instantiate()
	$Map.add_child(_grid_cursor)
	InputManager.set_grid_cursor(_grid_cursor)

	# Setup camera
	_camera = $Camera
	_camera.follow_mode = CameraController.FollowMode.CURSOR
	_camera.set_cursor(_grid_cursor)

	# Setup UI panels
	_stats_panel = $UI/HUD/ActiveUnitStatsPanel
	_terrain_panel = $UI/HUD/TerrainInfoPanel

	# Connect panel updates to turn signals
	TurnManager.player_turn_started.connect(_on_player_turn_started)
	TurnManager.enemy_turn_started.connect(_on_enemy_turn_started)
	TurnManager.unit_turn_ended.connect(_on_unit_turn_ended)

	# Setup BattleManager references (for combat resolution)
	BattleManager.setup(self, $Units)

	# Initialize TurnManager with all units
	var all_units: Array[Node2D] = []
	all_units.append_array($Units.get_children())  # Gets all spawned units
	TurnManager.start_battle(all_units)

	print("=== Battle Started ===\n")


## Helper to create test characters with custom stats
func _create_test_character(
	name: String,
	hp: int,
	mp: int,
	strength: int,
	defense: int,
	agility: int,
	intelligence: int,
	luck: int
) -> CharacterData:
	var character: CharacterData = CharacterData.new()
	character.character_name = name
	character.base_hp = hp
	character.base_mp = mp
	character.base_strength = strength
	character.base_defense = defense
	character.base_agility = agility
	character.base_intelligence = intelligence
	character.base_luck = luck
	character.starting_level = 1

	# Create a basic class for the character
	var char_class: ClassData = ClassData.new()
	char_class.class_name = name + " Class"
	char_class.movement_range = 5
	char_class.movement_type = 0  # Walking

	# Set growth rates (higher for fighters, balanced for mages/healers)
	if name == "Ted":
		char_class.hp_growth = 70
		char_class.strength_growth = 60
		char_class.defense_growth = 50
		char_class.agility_growth = 40
		char_class.intelligence_growth = 20
		char_class.luck_growth = 30
	elif name == "Mage":
		char_class.hp_growth = 40
		char_class.strength_growth = 10
		char_class.defense_growth = 30
		char_class.agility_growth = 50
		char_class.intelligence_growth = 80
		char_class.luck_growth = 40
	elif name == "Healer":
		char_class.hp_growth = 50
		char_class.strength_growth = 20
		char_class.defense_growth = 40
		char_class.agility_growth = 45
		char_class.intelligence_growth = 70
		char_class.luck_growth = 50
	else:  # Goblin
		char_class.hp_growth = 50
		char_class.strength_growth = 40
		char_class.defense_growth = 30
		char_class.agility_growth = 35
		char_class.intelligence_growth = 20
		char_class.luck_growth = 25

	character.character_class = char_class

	return character
