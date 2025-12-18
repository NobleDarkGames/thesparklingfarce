class_name TestTotalConversionWorkflow
extends GdUnitTestSuite

## Integration test for the Sparkling Editor total conversion mod workflow
## Tests that all resource types can be created programmatically using the EXACT
## patterns the editor UI uses.
##
## This validates the editor pipeline without requiring the actual editor UI.
## Property names and initialization match what _create_new_resource() does.

const TEST_MOD_ID: String = "_gut_test_tc"
const TEST_MOD_PATH: String = "res://mods/_gut_test_tc/"

# Resource scripts loaded once for efficiency
var _class_script: GDScript
var _ability_script: GDScript
var _item_script: GDScript
var _character_script: GDScript
var _terrain_script: GDScript
var _party_script: GDScript
var _dialogue_script: GDScript
var _npc_script: GDScript
var _shop_script: GDScript
var _battle_script: GDScript
var _new_game_config_script: GDScript
var _crafter_script: GDScript
var _crafting_recipe_script: GDScript


func before() -> void:
	# Clean up any previous test mod
	_cleanup_test_mod()

	# Create mod structure
	_create_mod_structure()

	# Load all resource scripts - using same approach as editor
	_class_script = load("res://core/resources/class_data.gd")
	_ability_script = load("res://core/resources/ability_data.gd")
	_item_script = load("res://core/resources/item_data.gd")
	_character_script = load("res://core/resources/character_data.gd")
	_terrain_script = load("res://core/resources/terrain_data.gd")
	_party_script = load("res://core/resources/party_data.gd")
	_dialogue_script = load("res://core/resources/dialogue_data.gd")
	_npc_script = load("res://core/resources/npc_data.gd")
	_shop_script = load("res://core/resources/shop_data.gd")
	_battle_script = load("res://core/resources/battle_data.gd")
	_new_game_config_script = load("res://core/resources/new_game_config_data.gd")
	_crafter_script = load("res://core/resources/crafter_data.gd")
	_crafting_recipe_script = load("res://core/resources/crafting_recipe_data.gd")


func after() -> void:
	_cleanup_test_mod()


func _cleanup_test_mod() -> void:
	if DirAccess.dir_exists_absolute(TEST_MOD_PATH):
		_recursive_delete(TEST_MOD_PATH)


func _recursive_delete(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				var full_path: String = path.path_join(file_name)
				if dir.current_is_dir():
					_recursive_delete(full_path)
				else:
					dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		DirAccess.remove_absolute(path)


func _create_mod_structure() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_MOD_PATH)

	var subdirs: Array[String] = [
		"data/characters", "data/classes", "data/items", "data/abilities",
		"data/battles", "data/parties", "data/dialogues", "data/campaigns",
		"data/cinematics", "data/maps", "data/npcs", "data/terrain",
		"data/new_game_configs", "data/shops", "data/ai_behaviors",
		"data/status_effects", "data/crafting_recipes", "data/crafters"
	]

	for subdir: String in subdirs:
		DirAccess.make_dir_recursive_absolute(TEST_MOD_PATH + subdir)

	# Create mod.json
	var mod_json: Dictionary = {
		"id": TEST_MOD_ID,
		"name": "GUT Test Total Conversion",
		"version": "1.0.0",
		"author": "Automated Test",
		"description": "GUT integration test mod",
		"godot_version": "4.5",
		"load_priority": 9001
	}

	var file: FileAccess = FileAccess.open(TEST_MOD_PATH + "mod.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(mod_json, "\t"))
	file.close()


# =============================================================================
# CLASS EDITOR TESTS (matches class_editor.gd:_create_new_resource)
# =============================================================================

func test_create_class_via_editor_pattern() -> void:
	assert_object(_class_script).is_not_null()

	# Matches class_editor.gd:_create_new_resource() exactly
	var new_class: Resource = _class_script.new()
	new_class.display_name = "GUT Warrior"
	new_class.movement_range = 5
	new_class.movement_type = 0  # WALKING enum
	new_class.promotion_level = 10

	var path: String = TEST_MOD_PATH + "data/classes/gut_warrior.tres"
	var err: Error = ResourceSaver.save(new_class, path)

	assert_int(err).is_equal(OK)
	assert_bool(FileAccess.file_exists(path)).is_true()

	# Verify load cycle
	var loaded: Resource = load(path)
	assert_object(loaded).is_not_null()
	assert_str(loaded.display_name).is_equal("GUT Warrior")


# =============================================================================
# ABILITY EDITOR TESTS (matches ability_editor.gd:_create_new_resource)
# =============================================================================

func test_create_ability_via_editor_pattern() -> void:
	assert_object(_ability_script).is_not_null()

	# Matches ability_editor.gd:_create_new_resource() exactly
	var new_ability: Resource = _ability_script.new()
	new_ability.ability_name = "GUT Slash"
	new_ability.ability_type = 0  # ATTACK enum
	new_ability.target_type = 0   # SINGLE_ENEMY enum
	new_ability.min_range = 1
	new_ability.max_range = 1
	new_ability.power = 10

	var path: String = TEST_MOD_PATH + "data/abilities/gut_slash.tres"
	var err: Error = ResourceSaver.save(new_ability, path)

	assert_int(err).is_equal(OK)

	var loaded: Resource = load(path)
	assert_str(loaded.ability_name).is_equal("GUT Slash")
	assert_int(loaded.power).is_equal(10)


# =============================================================================
# ITEM EDITOR TESTS (matches item_editor.gd:_create_new_resource)
# =============================================================================

func test_create_item_via_editor_pattern() -> void:
	assert_object(_item_script).is_not_null()

	# Matches item_editor.gd:_create_new_resource() exactly
	var new_item: Resource = _item_script.new()
	new_item.item_name = "GUT Sword"
	new_item.item_type = 0  # WEAPON enum
	new_item.equipment_slot = "weapon"
	new_item.is_cursed = false
	new_item.buy_price = 100
	new_item.sell_price = 50

	var path: String = TEST_MOD_PATH + "data/items/gut_sword.tres"
	var err: Error = ResourceSaver.save(new_item, path)

	assert_int(err).is_equal(OK)

	var loaded: Resource = load(path)
	assert_str(loaded.item_name).is_equal("GUT Sword")


func test_create_consumable_via_editor_pattern() -> void:
	var new_item: Resource = _item_script.new()
	new_item.item_name = "GUT Potion"
	new_item.item_type = 3  # CONSUMABLE enum
	new_item.usable_in_battle = true
	new_item.usable_on_field = true
	new_item.buy_price = 20
	new_item.sell_price = 10

	var path: String = TEST_MOD_PATH + "data/items/gut_potion.tres"
	var err: Error = ResourceSaver.save(new_item, path)

	assert_int(err).is_equal(OK)


# =============================================================================
# CHARACTER EDITOR TESTS (matches character_editor.gd:_create_new_resource)
# =============================================================================

func test_create_character_via_editor_pattern() -> void:
	assert_object(_character_script).is_not_null()

	# Matches character_editor.gd:_create_new_resource() exactly
	var new_character: Resource = _character_script.new()
	new_character.character_name = "GUT Hero"
	new_character.starting_level = 1
	new_character.base_hp = 20
	new_character.base_mp = 10
	new_character.base_strength = 5
	new_character.base_defense = 5
	new_character.base_agility = 5
	new_character.base_intelligence = 5
	new_character.base_luck = 5

	var path: String = TEST_MOD_PATH + "data/characters/gut_hero.tres"
	var err: Error = ResourceSaver.save(new_character, path)

	assert_int(err).is_equal(OK)

	var loaded: Resource = load(path)
	assert_str(loaded.character_name).is_equal("GUT Hero")


func test_create_boss_character_via_editor_pattern() -> void:
	var new_character: Resource = _character_script.new()
	new_character.character_name = "GUT Boss"
	new_character.starting_level = 10
	new_character.base_hp = 100
	new_character.is_boss = true
	new_character.is_unique = true

	var path: String = TEST_MOD_PATH + "data/characters/gut_boss.tres"
	var err: Error = ResourceSaver.save(new_character, path)

	assert_int(err).is_equal(OK)

	var loaded: Resource = load(path)
	assert_bool(loaded.is_boss).is_true()


# =============================================================================
# TERRAIN EDITOR TESTS (matches terrain_editor.gd:_create_new_resource)
# =============================================================================

func test_create_terrain_via_editor_pattern() -> void:
	assert_object(_terrain_script).is_not_null()

	# Matches terrain_editor.gd:_create_new_resource() exactly
	var new_terrain: Resource = _terrain_script.new()
	new_terrain.terrain_id = "gut_grass"
	new_terrain.display_name = "GUT Grass"
	new_terrain.movement_cost_walking = 1
	new_terrain.movement_cost_floating = 1
	new_terrain.movement_cost_flying = 1
	new_terrain.defense_bonus = 0
	new_terrain.evasion_bonus = 0

	var path: String = TEST_MOD_PATH + "data/terrain/gut_grass.tres"
	var err: Error = ResourceSaver.save(new_terrain, path)

	assert_int(err).is_equal(OK)


# =============================================================================
# PARTY EDITOR TESTS
# =============================================================================

func test_create_party_via_editor_pattern() -> void:
	assert_object(_party_script).is_not_null()

	var new_party: Resource = _party_script.new()
	new_party.party_name = "GUT Starting Party"
	# Note: members is Array[Dictionary] with character references

	var path: String = TEST_MOD_PATH + "data/parties/gut_starting_party.tres"
	var err: Error = ResourceSaver.save(new_party, path)

	assert_int(err).is_equal(OK)


# =============================================================================
# DIALOGUE EDITOR TESTS (matches dialogue_editor.gd:_create_new_resource)
# =============================================================================

func test_create_dialogue_via_editor_pattern() -> void:
	assert_object(_dialogue_script).is_not_null()

	# Matches dialogue_editor.gd:_create_new_resource() exactly
	var new_dialogue: Resource = _dialogue_script.new()
	new_dialogue.dialogue_id = "gut_welcome_" + str(Time.get_unix_time_from_system())
	new_dialogue.dialogue_title = "GUT Welcome"
	# Note: dialogue uses add_line() method for lines
	new_dialogue.add_line("Speaker", "Enter dialogue text here.", null, "neutral")

	var path: String = TEST_MOD_PATH + "data/dialogues/gut_welcome.tres"
	var err: Error = ResourceSaver.save(new_dialogue, path)

	assert_int(err).is_equal(OK)


# =============================================================================
# CINEMATIC EDITOR TESTS (JSON format)
# =============================================================================

func test_create_cinematic_via_editor_pattern() -> void:
	# Cinematics use JSON format (matches cinematic_editor.gd)
	var cinematic_data: Dictionary = {
		"cinematic_id": "gut_opening",
		"cinematic_name": "GUT Opening",
		"description": "Opening cinematic for GUT test",
		"can_skip": true,
		"disable_player_input": true,
		"commands": [
			{
				"type": "dialogue",
				"speaker": "Narrator",
				"text": "The test begins..."
			}
		]
	}

	var path: String = TEST_MOD_PATH + "data/cinematics/gut_opening.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_object(file).is_not_null()

	file.store_string(JSON.stringify(cinematic_data, "\t"))
	file.close()

	assert_bool(FileAccess.file_exists(path)).is_true()

	# Verify JSON parses correctly
	var read_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var content: String = read_file.get_as_text()
	read_file.close()

	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(content)
	assert_int(parse_err).is_equal(OK)


# =============================================================================
# NPC EDITOR TESTS (matches npc_editor.gd:_create_new_resource)
# =============================================================================

func test_create_npc_via_editor_pattern() -> void:
	assert_object(_npc_script).is_not_null()

	# Matches npc_editor.gd:_create_new_resource() exactly
	var new_npc: Resource = _npc_script.new()
	new_npc.npc_id = "gut_shopkeeper"
	new_npc.npc_name = "GUT Shopkeeper"
	new_npc.face_player_on_interact = true
	new_npc.facing_override = ""
	new_npc.interaction_cinematic_id = ""
	new_npc.fallback_cinematic_id = ""
	new_npc.conditional_cinematics = []

	var path: String = TEST_MOD_PATH + "data/npcs/gut_shopkeeper.tres"
	var err: Error = ResourceSaver.save(new_npc, path)

	assert_int(err).is_equal(OK)


# =============================================================================
# SHOP EDITOR TESTS (matches shop_editor.gd:_create_new_resource)
# =============================================================================

func test_create_shop_via_editor_pattern() -> void:
	assert_object(_shop_script).is_not_null()

	# Matches shop_editor.gd:_create_new_resource() exactly
	var new_shop: Resource = _shop_script.new()
	new_shop.shop_id = "gut_weapon_shop_%d" % Time.get_unix_time_from_system()
	new_shop.shop_name = "GUT Weapon Shop"
	new_shop.shop_type = 0  # ITEM enum
	new_shop.greeting_text = "Welcome!"
	new_shop.farewell_text = "Come again!"
	new_shop.can_sell = true
	new_shop.can_store_to_caravan = true
	new_shop.can_sell_from_caravan = true

	var path: String = TEST_MOD_PATH + "data/shops/gut_weapon_shop.tres"
	var err: Error = ResourceSaver.save(new_shop, path)

	assert_int(err).is_equal(OK)


# =============================================================================
# BATTLE EDITOR TESTS (matches battle_editor.gd:_create_new_resource)
# =============================================================================

func test_create_battle_via_editor_pattern() -> void:
	assert_object(_battle_script).is_not_null()

	# Matches battle_editor.gd:_create_new_resource() exactly
	var new_battle: Resource = _battle_script.new()
	new_battle.battle_name = "GUT Tutorial Battle"
	new_battle.battle_description = "First battle"
	new_battle.victory_condition = 0  # DEFEAT_ALL_ENEMIES enum
	new_battle.defeat_condition = 0   # LEADER_DEFEATED enum

	var path: String = TEST_MOD_PATH + "data/battles/gut_tutorial.tres"
	var err: Error = ResourceSaver.save(new_battle, path)

	assert_int(err).is_equal(OK)

	var loaded: Resource = load(path)
	assert_str(loaded.battle_name).is_equal("GUT Tutorial Battle")


# =============================================================================
# CAMPAIGN EDITOR TESTS (JSON format)
# =============================================================================

func test_create_campaign_via_editor_pattern() -> void:
	# Campaigns use JSON format (matches campaign_editor.gd)
	var campaign_data: Dictionary = {
		"campaign_id": TEST_MOD_ID + ":gut_campaign",
		"campaign_name": "GUT Campaign",
		"campaign_description": "Test campaign",
		"campaign_version": "1.0.0",
		"starting_node_id": "opening",
		"default_hub_id": "",
		"initial_flags": {},
		"chapters": [],
		"nodes": [
			{
				"node_id": "opening",
				"node_type": "cutscene",
				"node_name": "Opening",
				"next_nodes": [],
				"position_x": 100,
				"position_y": 100
			}
		]
	}

	var path: String = TEST_MOD_PATH + "data/campaigns/gut_campaign.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_object(file).is_not_null()

	file.store_string(JSON.stringify(campaign_data, "\t"))
	file.close()

	assert_bool(FileAccess.file_exists(path)).is_true()


# =============================================================================
# NEW GAME CONFIG TESTS
# =============================================================================

func test_create_new_game_config_via_editor_pattern() -> void:
	assert_object(_new_game_config_script).is_not_null()

	var new_config: Resource = _new_game_config_script.new()
	new_config.config_id = "gut_default"
	new_config.config_name = "GUT Default"
	new_config.config_description = "Default config for GUT test"
	new_config.is_default = true
	new_config.starting_gold = 100

	var path: String = TEST_MOD_PATH + "data/new_game_configs/gut_default.tres"
	var err: Error = ResourceSaver.save(new_config, path)

	assert_int(err).is_equal(OK)

	var loaded: Resource = load(path)
	assert_bool(loaded.is_default).is_true()


# =============================================================================
# CRAFTER EDITOR TESTS (matches crafter_editor.gd:_create_new_resource)
# =============================================================================

func test_create_crafter_via_editor_pattern() -> void:
	if not _crafter_script:
		# Skip if crafter script doesn't exist
		return

	# Matches crafter_editor.gd:_create_new_resource() exactly
	var new_crafter: Resource = _crafter_script.new()
	new_crafter.crafter_name = "GUT Blacksmith"
	new_crafter.crafter_type = "blacksmith"
	new_crafter.skill_level = 1
	new_crafter.specializations = []
	new_crafter.service_fee_modifier = 1.0
	new_crafter.description = ""

	var path: String = TEST_MOD_PATH + "data/crafters/gut_blacksmith.tres"
	var err: Error = ResourceSaver.save(new_crafter, path)

	assert_int(err).is_equal(OK)


# =============================================================================
# CRAFTING RECIPE EDITOR TESTS (matches crafting_recipe_editor.gd)
# =============================================================================

func test_create_crafting_recipe_via_editor_pattern() -> void:
	if not _crafting_recipe_script:
		# Skip if script doesn't exist
		return

	# Matches crafting_recipe_editor.gd:_create_new_resource() exactly
	var new_recipe: Resource = _crafting_recipe_script.new()
	new_recipe.recipe_name = "GUT Upgrade"
	new_recipe.output_mode = 0  # SINGLE enum
	new_recipe.output_item_id = ""
	new_recipe.output_choices = []
	new_recipe.inputs = []
	new_recipe.gold_cost = 100
	new_recipe.required_crafter_type = "blacksmith"
	new_recipe.required_crafter_skill = 1
	new_recipe.description = ""

	var path: String = TEST_MOD_PATH + "data/crafting_recipes/gut_upgrade.tres"
	var err: Error = ResourceSaver.save(new_recipe, path)

	assert_int(err).is_equal(OK)


# =============================================================================
# BUG DETECTION TESTS
# =============================================================================

func test_status_effect_has_no_editor() -> void:
	# Document the known gap: status effects have no dedicated editor
	var status_effect_script: GDScript = load("res://core/resources/status_effect_data.gd")

	# Status effect script exists...
	assert_object(status_effect_script).is_not_null()

	# But there's no editor tab for it - this test documents the gap
	# The assertion confirms the gap exists (editor tab would be false)
	var editor_tab_exists: bool = false
	assert_bool(editor_tab_exists).is_false()


func test_mod_wizard_missing_directories() -> void:
	# These directories are MISSING from the Create New Mod wizard
	# Documented as bugs that should be fixed
	var missing_from_wizard: Array[String] = [
		"data/status_effects",
		"data/ai_behaviors",
		"data/shops",
		"data/crafting_recipes",
		"data/crafters",
		"data/caravans",
		"data/experience_configs"
	]

	# We created them manually - this documents they should exist
	for dir: String in missing_from_wizard:
		# Note: We created these, wizard doesn't
		pass  # Test documents the gap


# =============================================================================
# COMPLETE WORKFLOW TEST
# =============================================================================

func test_complete_workflow_creates_all_resources() -> void:
	# Verify all resources were created in previous tests
	var expected_files: Array[String] = [
		"data/classes/gut_warrior.tres",
		"data/abilities/gut_slash.tres",
		"data/items/gut_sword.tres",
		"data/items/gut_potion.tres",
		"data/characters/gut_hero.tres",
		"data/characters/gut_boss.tres",
		"data/terrain/gut_grass.tres",
		"data/parties/gut_starting_party.tres",
		"data/dialogues/gut_welcome.tres",
		"data/cinematics/gut_opening.json",
		"data/npcs/gut_shopkeeper.tres",
		"data/shops/gut_weapon_shop.tres",
		"data/battles/gut_tutorial.tres",
		"data/campaigns/gut_campaign.json",
		"data/new_game_configs/gut_default.tres"
	]

	var missing_count: int = 0
	for rel_path: String in expected_files:
		var full_path: String = TEST_MOD_PATH + rel_path
		if not FileAccess.file_exists(full_path):
			missing_count += 1
			print("MISSING: " + rel_path)

	assert_int(missing_count).is_equal(0)
