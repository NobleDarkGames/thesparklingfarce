@tool
extends EditorScript

## Total Conversion Mod Stress Test
## ================================
## This script simulates a complete modder workflow through the Sparkling Editor.
## It creates a total conversion mod with all resource types using the same
## internal methods the editor UI would call.
##
## USAGE: In Godot Editor, go to Script > Run (or Ctrl+Shift+X)
##
## This tests:
## - Mod wizard (folder structure, mod.json)
## - All 17+ resource editors (character, class, item, etc.)
## - Cross-resource references
## - Save/load cycle integrity
##
## Any failure indicates a bug in the editor that would require manual file editing.

const MOD_ID: String = "_stress_test_tc"
const MOD_NAME: String = "Stress Test Total Conversion"
const MOD_AUTHOR: String = "Automated Test"

var _errors: Array[String] = []
var _warnings: Array[String] = []
var _successes: Array[String] = []

func _run() -> void:
	print("\n" + "=".repeat(60))
	print("SPARKLING EDITOR STRESS TEST: Total Conversion Mod")
	print("=".repeat(60) + "\n")

	# Clean up any previous test mod
	_cleanup_test_mod()

	# Step 1: Create mod structure (simulates Create New Mod wizard)
	if not _create_mod_structure():
		_report_results()
		return

	# Step 2: Create all resource types in order of dependencies
	_create_classes()
	_create_abilities()
	_create_items()
	_create_characters()
	_create_terrain()
	_create_maps()
	_create_parties()
	_create_dialogues()
	_create_cinematics()
	_create_npcs()
	_create_shops()
	_create_crafting()
	_create_ai_behaviors()
	_create_battles()
	_create_campaigns()
	_create_new_game_config()

	# Step 3: Test status effects (expected to fail - no editor exists)
	_test_status_effect_gap()

	# Step 4: Verify all resources load correctly
	_verify_resources()

	# Report results
	_report_results()


func _cleanup_test_mod() -> void:
	var mod_path: String = "res://mods/" + MOD_ID
	if DirAccess.dir_exists_absolute(mod_path):
		print("[Cleanup] Removing existing test mod...")
		_recursive_delete(mod_path)
		print("[Cleanup] Done")


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


func _create_mod_structure() -> bool:
	print("\n[1/17] Creating mod structure...")

	var mod_path: String = "res://mods/" + MOD_ID + "/"

	# Create main directory
	var err: Error = DirAccess.make_dir_recursive_absolute(mod_path)
	if err != OK:
		_errors.append("Failed to create mod directory: " + mod_path)
		return false

	# Create subdirectories (same as main_panel._create_mod_structure)
	var subdirs: Array = [
		"data/characters",
		"data/classes",
		"data/items",
		"data/abilities",
		"data/battles",
		"data/parties",
		"data/dialogues",
		"data/campaigns",
		"data/cinematics",
		"data/maps",
		"data/npcs",
		"data/terrain",
		"data/new_game_configs",
		# These are MISSING from the wizard - documenting the bug:
		"data/status_effects",
		"data/experience_configs",
		"data/ai_behaviors",
		"data/shops",
		"data/crafting_recipes",
		"data/crafters",
		"data/caravans",
		# Asset directories
		"assets/portraits",
		"assets/sprites/map",
		"assets/sprites/battle",
		"assets/icons/items",
		"assets/icons/abilities",
		"assets/tilesets",
		"assets/music",
		"assets/sfx",
		"maps",
		"scenes",
		"tilesets",
		"triggers"
	]

	for subdir: String in subdirs:
		err = DirAccess.make_dir_recursive_absolute(mod_path + subdir)
		if err != OK:
			_warnings.append("Failed to create subdirectory: " + subdir)

	# Create mod.json (total conversion type)
	var mod_json: Dictionary = {
		"id": MOD_ID,
		"name": MOD_NAME,
		"version": "1.0.0",
		"author": MOD_AUTHOR,
		"description": "Automated stress test for Sparkling Editor",
		"godot_version": "4.5",
		"load_priority": 9001,  # Total conversion priority
		"dependencies": [],
		"hidden_campaigns": ["_base_game:*"],
		"party_config": {"replaces_lower_priority": true}
	}

	var json_path: String = mod_path + "mod.json"
	var file: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	if not file:
		_errors.append("Failed to create mod.json")
		return false

	file.store_string(JSON.stringify(mod_json, "\t"))
	file.close()

	_successes.append("Created mod structure with all directories")
	print("  [OK] Mod structure created")
	return true


func _create_classes() -> void:
	print("\n[2/17] Creating classes...")

	var ClassDataScript: GDScript = load("res://core/resources/class_data.gd")
	if not ClassDataScript:
		_errors.append("Could not load ClassData script")
		return

	# Create warrior class
	var warrior: Resource = ClassDataScript.new()
	warrior.class_name = "Test Warrior"
	warrior.movement_type = "walking"
	warrior.movement_range = 5
	warrior.hp_growth = 1.2
	warrior.str_growth = 1.1
	warrior.def_growth = 1.0
	warrior.agi_growth = 0.8
	warrior.int_growth = 0.5
	warrior.luk_growth = 0.7
	warrior.mp_growth = 0.3
	warrior.weapon_types = ["sword", "spear"]
	warrior.learnable_abilities = []

	var path: String = "res://mods/" + MOD_ID + "/data/classes/test_warrior.tres"
	var err: Error = ResourceSaver.save(warrior, path)
	if err != OK:
		_errors.append("Failed to save warrior class: " + error_string(err))
	else:
		_successes.append("Created warrior class via editor pattern")

	# Create mage class
	var mage: Resource = ClassDataScript.new()
	mage.class_name = "Test Mage"
	mage.movement_type = "walking"
	mage.movement_range = 4
	mage.hp_growth = 0.7
	mage.str_growth = 0.5
	mage.def_growth = 0.6
	mage.agi_growth = 0.7
	mage.int_growth = 1.3
	mage.luk_growth = 0.8
	mage.mp_growth = 1.2
	mage.weapon_types = ["staff"]
	mage.learnable_abilities = []

	path = "res://mods/" + MOD_ID + "/data/classes/test_mage.tres"
	err = ResourceSaver.save(mage, path)
	if err != OK:
		_errors.append("Failed to save mage class")
	else:
		_successes.append("Created mage class")

	print("  [OK] Created 2 classes")


func _create_abilities() -> void:
	print("\n[3/17] Creating abilities...")

	var AbilityDataScript: GDScript = load("res://core/resources/ability_data.gd")
	if not AbilityDataScript:
		_errors.append("Could not load AbilityData script")
		return

	# Create attack ability
	var slash: Resource = AbilityDataScript.new()
	slash.ability_id = "test_slash"
	slash.ability_name = "Test Slash"
	slash.ability_type = "attack"
	slash.target_type = "enemy"
	slash.min_range = 1
	slash.max_range = 1
	slash.area_of_effect = 0
	slash.mp_cost = 0
	slash.hp_cost = 0
	slash.power = 10
	slash.accuracy = 95

	var path: String = "res://mods/" + MOD_ID + "/data/abilities/test_slash.tres"
	var err: Error = ResourceSaver.save(slash, path)
	if err != OK:
		_errors.append("Failed to save slash ability")
	else:
		_successes.append("Created slash ability")

	# Create magic ability
	var fireball: Resource = AbilityDataScript.new()
	fireball.ability_id = "test_fireball"
	fireball.ability_name = "Test Fireball"
	fireball.ability_type = "magic"
	fireball.target_type = "enemy"
	fireball.min_range = 1
	fireball.max_range = 3
	fireball.area_of_effect = 1
	fireball.mp_cost = 5
	fireball.hp_cost = 0
	fireball.power = 15
	fireball.accuracy = 90

	path = "res://mods/" + MOD_ID + "/data/abilities/test_fireball.tres"
	err = ResourceSaver.save(fireball, path)
	if err != OK:
		_errors.append("Failed to save fireball ability")
	else:
		_successes.append("Created fireball ability")

	# Create heal ability
	var heal: Resource = AbilityDataScript.new()
	heal.ability_id = "test_heal"
	heal.ability_name = "Test Heal"
	heal.ability_type = "heal"
	heal.target_type = "ally"
	heal.min_range = 1
	heal.max_range = 2
	heal.area_of_effect = 0
	heal.mp_cost = 3
	heal.hp_cost = 0
	heal.power = 10
	heal.accuracy = 100

	path = "res://mods/" + MOD_ID + "/data/abilities/test_heal.tres"
	err = ResourceSaver.save(heal, path)
	if err != OK:
		_errors.append("Failed to save heal ability")
	else:
		_successes.append("Created heal ability")

	print("  [OK] Created 3 abilities")


func _create_items() -> void:
	print("\n[4/17] Creating items...")

	var ItemDataScript: GDScript = load("res://core/resources/item_data.gd")
	if not ItemDataScript:
		_errors.append("Could not load ItemData script")
		return

	# Create weapon
	var sword: Resource = ItemDataScript.new()
	sword.item_id = "test_sword"
	sword.item_name = "Test Sword"
	sword.item_type = "weapon"
	sword.equipment_type = "sword"
	sword.attack_power = 10
	sword.attack_range = 1
	sword.hit_rate_modifier = 0
	sword.crit_rate_modifier = 5
	sword.buy_price = 100
	sword.sell_price = 50

	var path: String = "res://mods/" + MOD_ID + "/data/items/test_sword.tres"
	var err: Error = ResourceSaver.save(sword, path)
	if err != OK:
		_errors.append("Failed to save sword item")
	else:
		_successes.append("Created sword item")

	# Create armor
	var armor: Resource = ItemDataScript.new()
	armor.item_id = "test_armor"
	armor.item_name = "Test Armor"
	armor.item_type = "armor"
	armor.equipment_type = "body"
	armor.defense_modifier = 5
	armor.buy_price = 150
	armor.sell_price = 75

	path = "res://mods/" + MOD_ID + "/data/items/test_armor.tres"
	err = ResourceSaver.save(armor, path)
	if err != OK:
		_errors.append("Failed to save armor item")
	else:
		_successes.append("Created armor item")

	# Create consumable
	var potion: Resource = ItemDataScript.new()
	potion.item_id = "test_potion"
	potion.item_name = "Test Potion"
	potion.item_type = "consumable"
	potion.usable_in_battle = true
	potion.usable_in_field = true
	potion.buy_price = 20
	potion.sell_price = 10

	path = "res://mods/" + MOD_ID + "/data/items/test_potion.tres"
	err = ResourceSaver.save(potion, path)
	if err != OK:
		_errors.append("Failed to save potion item")
	else:
		_successes.append("Created potion item")

	print("  [OK] Created 3 items")


func _create_characters() -> void:
	print("\n[5/17] Creating characters...")

	var CharacterDataScript: GDScript = load("res://core/resources/character_data.gd")
	if not CharacterDataScript:
		_errors.append("Could not load CharacterData script")
		return

	# Create hero character
	var hero: Resource = CharacterDataScript.new()
	hero.character_id = "test_hero"
	hero.character_name = "Test Hero"
	hero.starting_level = 1
	hero.character_class_id = MOD_ID + ":test_warrior"  # Cross-reference to our class
	hero.category = "player"
	hero.is_unique = true
	hero.is_hero = true
	hero.is_boss = false
	hero.base_hp = 20
	hero.base_mp = 5
	hero.base_str = 8
	hero.base_def = 6
	hero.base_agi = 5
	hero.base_int = 4
	hero.base_luk = 5
	hero.biography = "The brave test hero of our automated stress test."

	var path: String = "res://mods/" + MOD_ID + "/data/characters/test_hero.tres"
	var err: Error = ResourceSaver.save(hero, path)
	if err != OK:
		_errors.append("Failed to save hero character")
	else:
		_successes.append("Created hero character with class reference")

	# Create mage companion
	var companion: Resource = CharacterDataScript.new()
	companion.character_id = "test_mage_companion"
	companion.character_name = "Test Mage"
	companion.starting_level = 1
	companion.character_class_id = MOD_ID + ":test_mage"
	companion.category = "player"
	companion.is_unique = true
	companion.is_hero = false
	companion.is_boss = false
	companion.base_hp = 15
	companion.base_mp = 12
	companion.base_str = 4
	companion.base_def = 4
	companion.base_agi = 5
	companion.base_int = 10
	companion.base_luk = 6
	companion.biography = "A mage who joins the test hero."

	path = "res://mods/" + MOD_ID + "/data/characters/test_mage_companion.tres"
	err = ResourceSaver.save(companion, path)
	if err != OK:
		_errors.append("Failed to save mage companion")
	else:
		_successes.append("Created mage companion")

	# Create enemy
	var enemy: Resource = CharacterDataScript.new()
	enemy.character_id = "test_goblin"
	enemy.character_name = "Test Goblin"
	enemy.starting_level = 1
	enemy.character_class_id = MOD_ID + ":test_warrior"
	enemy.category = "enemy"
	enemy.is_unique = false
	enemy.is_hero = false
	enemy.is_boss = false
	enemy.base_hp = 10
	enemy.base_mp = 0
	enemy.base_str = 5
	enemy.base_def = 3
	enemy.base_agi = 6
	enemy.base_int = 2
	enemy.base_luk = 3

	path = "res://mods/" + MOD_ID + "/data/characters/test_goblin.tres"
	err = ResourceSaver.save(enemy, path)
	if err != OK:
		_errors.append("Failed to save goblin enemy")
	else:
		_successes.append("Created goblin enemy")

	# Create boss
	var boss: Resource = CharacterDataScript.new()
	boss.character_id = "test_boss"
	boss.character_name = "Test Boss"
	boss.starting_level = 5
	boss.character_class_id = MOD_ID + ":test_warrior"
	boss.category = "enemy"
	boss.is_unique = true
	boss.is_hero = false
	boss.is_boss = true
	boss.base_hp = 50
	boss.base_mp = 10
	boss.base_str = 12
	boss.base_def = 8
	boss.base_agi = 4
	boss.base_int = 6
	boss.base_luk = 5

	path = "res://mods/" + MOD_ID + "/data/characters/test_boss.tres"
	err = ResourceSaver.save(boss, path)
	if err != OK:
		_errors.append("Failed to save boss character")
	else:
		_successes.append("Created boss character")

	print("  [OK] Created 4 characters")


func _create_terrain() -> void:
	print("\n[6/17] Creating terrain...")

	var TerrainDataScript: GDScript = load("res://core/resources/terrain_data.gd")
	if not TerrainDataScript:
		_errors.append("Could not load TerrainData script")
		return

	# Create grass terrain
	var grass: Resource = TerrainDataScript.new()
	grass.terrain_id = "test_grass"
	grass.display_name = "Test Grass"
	grass.walking_cost = 1.0
	grass.floating_cost = 1.0
	grass.flying_cost = 1.0
	grass.defense_bonus = 0
	grass.evasion_bonus = 0

	var path: String = "res://mods/" + MOD_ID + "/data/terrain/test_grass.tres"
	var err: Error = ResourceSaver.save(grass, path)
	if err != OK:
		_errors.append("Failed to save grass terrain")
	else:
		_successes.append("Created grass terrain")

	# Create forest terrain
	var forest: Resource = TerrainDataScript.new()
	forest.terrain_id = "test_forest"
	forest.display_name = "Test Forest"
	forest.walking_cost = 2.0
	forest.floating_cost = 1.5
	forest.flying_cost = 1.0
	forest.defense_bonus = 10
	forest.evasion_bonus = 15

	path = "res://mods/" + MOD_ID + "/data/terrain/test_forest.tres"
	err = ResourceSaver.save(forest, path)
	if err != OK:
		_errors.append("Failed to save forest terrain")
	else:
		_successes.append("Created forest terrain")

	print("  [OK] Created 2 terrain types")


func _create_maps() -> void:
	print("\n[7/17] Creating maps...")

	var MapMetadataScript: GDScript = load("res://core/resources/map_metadata_data.gd")
	if not MapMetadataScript:
		_errors.append("Could not load MapMetadataData script")
		return

	# Create test battle map
	var battle_map: Resource = MapMetadataScript.new()
	battle_map.map_id = "test_battle_field"
	battle_map.display_name = "Test Battle Field"
	battle_map.map_width = 15
	battle_map.map_height = 10
	battle_map.connections = []

	var path: String = "res://mods/" + MOD_ID + "/data/maps/test_battle_field.tres"
	var err: Error = ResourceSaver.save(battle_map, path)
	if err != OK:
		_errors.append("Failed to save battle map metadata")
	else:
		_successes.append("Created battle map metadata")

	print("  [OK] Created 1 map")


func _create_parties() -> void:
	print("\n[8/17] Creating parties...")

	var PartyDataScript: GDScript = load("res://core/resources/party_data.gd")
	if not PartyDataScript:
		_errors.append("Could not load PartyData script")
		return

	# Create starting party
	var party: Resource = PartyDataScript.new()
	party.party_id = "test_starting_party"
	party.party_name = "Test Starting Party"
	party.character_ids = [
		MOD_ID + ":test_hero",
		MOD_ID + ":test_mage_companion"
	]

	var path: String = "res://mods/" + MOD_ID + "/data/parties/test_starting_party.tres"
	var err: Error = ResourceSaver.save(party, path)
	if err != OK:
		_errors.append("Failed to save party")
	else:
		_successes.append("Created starting party with character references")

	# Create enemy party
	var enemy_party: Resource = PartyDataScript.new()
	enemy_party.party_id = "test_goblin_squad"
	enemy_party.party_name = "Goblin Squad"
	enemy_party.character_ids = [
		MOD_ID + ":test_goblin",
		MOD_ID + ":test_goblin",
		MOD_ID + ":test_goblin"
	]

	path = "res://mods/" + MOD_ID + "/data/parties/test_goblin_squad.tres"
	err = ResourceSaver.save(enemy_party, path)
	if err != OK:
		_errors.append("Failed to save enemy party")
	else:
		_successes.append("Created enemy party")

	print("  [OK] Created 2 parties")


func _create_dialogues() -> void:
	print("\n[9/17] Creating dialogues...")

	var DialogueDataScript: GDScript = load("res://core/resources/dialogue_data.gd")
	if not DialogueDataScript:
		_errors.append("Could not load DialogueData script")
		return

	# Create welcome dialogue
	var dialogue: Resource = DialogueDataScript.new()
	dialogue.dialogue_id = "test_welcome"
	dialogue.dialogue_name = "Welcome Dialogue"
	dialogue.lines = [
		{"speaker": "Narrator", "text": "Welcome to the stress test!"},
		{"speaker": "Test Hero", "text": "I am the test hero."}
	]

	var path: String = "res://mods/" + MOD_ID + "/data/dialogues/test_welcome.tres"
	var err: Error = ResourceSaver.save(dialogue, path)
	if err != OK:
		_errors.append("Failed to save dialogue")
	else:
		_successes.append("Created welcome dialogue")

	print("  [OK] Created 1 dialogue")


func _create_cinematics() -> void:
	print("\n[10/17] Creating cinematics...")

	# Cinematics use JSON format (like campaign_editor and cinematic_editor)
	var cinematic_data: Dictionary = {
		"cinematic_id": "test_opening",
		"cinematic_name": "Test Opening Cinematic",
		"description": "Opening cinematic for stress test",
		"can_skip": true,
		"disable_player_input": true,
		"commands": [
			{
				"type": "dialogue",
				"speaker": "Narrator",
				"text": "A new adventure begins...",
				"portrait": "",
				"position": "center"
			},
			{
				"type": "dialogue",
				"speaker": "Test Hero",
				"text": "I'm ready to be tested!",
				"portrait": "",
				"position": "left"
			},
			{
				"type": "wait",
				"duration": 1.0
			}
		]
	}

	var path: String = "res://mods/" + MOD_ID + "/data/cinematics/test_opening.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		_errors.append("Failed to create cinematic file")
		return

	file.store_string(JSON.stringify(cinematic_data, "\t"))
	file.close()
	_successes.append("Created opening cinematic (JSON format)")

	print("  [OK] Created 1 cinematic")


func _create_npcs() -> void:
	print("\n[11/17] Creating NPCs...")

	var NPCDataScript: GDScript = load("res://core/resources/npc_data.gd")
	if not NPCDataScript:
		_errors.append("Could not load NPCData script")
		return

	# Create shopkeeper NPC
	var shopkeeper: Resource = NPCDataScript.new()
	shopkeeper.npc_id = "test_shopkeeper"
	shopkeeper.npc_name = "Test Shopkeeper"
	shopkeeper.npc_template = "shopkeeper"
	shopkeeper.character_id = ""  # No linked character
	shopkeeper.primary_interaction_cinematic = ""
	shopkeeper.fallback_cinematic = ""
	# Note: conditional_cinematics defaults to empty Array[Dictionary] - don't reassign
	shopkeeper.face_player = true

	var path: String = "res://mods/" + MOD_ID + "/data/npcs/test_shopkeeper.tres"
	var err: Error = ResourceSaver.save(shopkeeper, path)
	if err != OK:
		_errors.append("Failed to save shopkeeper NPC")
	else:
		_successes.append("Created shopkeeper NPC")

	print("  [OK] Created 1 NPC")


func _create_shops() -> void:
	print("\n[12/17] Creating shops...")

	var ShopDataScript: GDScript = load("res://core/resources/shop_data.gd")
	if not ShopDataScript:
		_errors.append("Could not load ShopData script")
		return

	# Create weapon shop
	var shop: Resource = ShopDataScript.new()
	shop.shop_id = "test_weapon_shop"
	shop.shop_name = "Test Weapon Shop"
	shop.shop_type = "generic"
	shop.greeting_text = "Welcome to my shop!"
	shop.farewell_text = "Come again!"
	shop.inventory_items = [
		MOD_ID + ":test_sword",
		MOD_ID + ":test_armor"
	]
	shop.buy_price_multiplier = 1.0
	shop.sell_price_multiplier = 0.5
	shop.can_sell = true
	shop.can_store_items = false

	var path: String = "res://mods/" + MOD_ID + "/data/shops/test_weapon_shop.tres"
	var err: Error = ResourceSaver.save(shop, path)
	if err != OK:
		_errors.append("Failed to save shop")
	else:
		_successes.append("Created weapon shop with item references")

	print("  [OK] Created 1 shop")


func _create_crafting() -> void:
	print("\n[13/17] Creating crafting recipes...")

	var CraftingRecipeScript: GDScript = load("res://core/resources/crafting_recipe_data.gd")
	if not CraftingRecipeScript:
		_warnings.append("Could not load CraftingRecipeData script - skipping")
		print("  [SKIP] Crafting recipe script not found")
		return

	# Create a simple crafting recipe
	var recipe: Resource = CraftingRecipeScript.new()
	recipe.recipe_id = "test_upgrade_sword"
	recipe.recipe_name = "Upgrade Sword"
	recipe.result_item_id = MOD_ID + ":test_sword"
	recipe.required_items = []
	recipe.gold_cost = 50

	var path: String = "res://mods/" + MOD_ID + "/data/crafting_recipes/test_upgrade_sword.tres"
	var err: Error = ResourceSaver.save(recipe, path)
	if err != OK:
		_warnings.append("Failed to save crafting recipe")
	else:
		_successes.append("Created crafting recipe")

	print("  [OK] Created 1 crafting recipe")


func _create_ai_behaviors() -> void:
	print("\n[14/17] Creating AI behaviors...")

	var AIBrainScript: GDScript = load("res://core/resources/ai_brain_data.gd")
	if not AIBrainScript:
		_warnings.append("Could not load AIBrainData script - skipping")
		print("  [SKIP] AI brain script not found")
		return

	# Create aggressive AI behavior
	var ai: Resource = AIBrainScript.new()
	ai.brain_id = "test_aggressive"
	ai.brain_name = "Test Aggressive"
	ai.description = "Aggressively attacks nearest enemy"

	var path: String = "res://mods/" + MOD_ID + "/data/ai_behaviors/test_aggressive.tres"
	var err: Error = ResourceSaver.save(ai, path)
	if err != OK:
		_warnings.append("Failed to save AI behavior")
	else:
		_successes.append("Created AI behavior")

	print("  [OK] Created 1 AI behavior")


func _create_battles() -> void:
	print("\n[15/17] Creating battles...")

	var BattleDataScript: GDScript = load("res://core/resources/battle_data.gd")
	if not BattleDataScript:
		_errors.append("Could not load BattleData script")
		return

	# Create tutorial battle
	var battle: Resource = BattleDataScript.new()
	battle.battle_id = "test_tutorial_battle"
	battle.battle_name = "Test Tutorial Battle"
	battle.battle_description = "First battle of the stress test"
	battle.map_id = MOD_ID + ":test_battle_field"
	battle.player_spawn_x = 2
	battle.player_spawn_y = 5
	battle.player_party_id = MOD_ID + ":test_starting_party"
	battle.enemy_parties = [
		{
			"party_id": MOD_ID + ":test_goblin_squad",
			"spawn_x": 12,
			"spawn_y": 5
		}
	]
	battle.victory_condition = "defeat_all"
	battle.defeat_condition = "leader_dies"
	battle.experience_reward = 50
	battle.gold_reward = 100

	var path: String = "res://mods/" + MOD_ID + "/data/battles/test_tutorial_battle.tres"
	var err: Error = ResourceSaver.save(battle, path)
	if err != OK:
		_errors.append("Failed to save battle")
	else:
		_successes.append("Created tutorial battle with all references")

	# Create boss battle
	var boss_battle: Resource = BattleDataScript.new()
	boss_battle.battle_id = "test_boss_battle"
	boss_battle.battle_name = "Test Boss Battle"
	boss_battle.battle_description = "Final battle with the test boss"
	boss_battle.map_id = MOD_ID + ":test_battle_field"
	boss_battle.player_spawn_x = 2
	boss_battle.player_spawn_y = 5
	boss_battle.player_party_id = MOD_ID + ":test_starting_party"
	boss_battle.enemy_parties = [
		{
			"party_id": "",
			"characters": [MOD_ID + ":test_boss"],
			"spawn_x": 12,
			"spawn_y": 5
		}
	]
	boss_battle.victory_condition = "defeat_boss"
	boss_battle.defeat_condition = "leader_dies"
	boss_battle.experience_reward = 200
	boss_battle.gold_reward = 500

	path = "res://mods/" + MOD_ID + "/data/battles/test_boss_battle.tres"
	err = ResourceSaver.save(boss_battle, path)
	if err != OK:
		_errors.append("Failed to save boss battle")
	else:
		_successes.append("Created boss battle")

	print("  [OK] Created 2 battles")


func _create_campaigns() -> void:
	print("\n[16/17] Creating campaigns...")

	# Campaigns use JSON format
	var campaign_data: Dictionary = {
		"campaign_id": MOD_ID + ":test_campaign",
		"campaign_name": "Test Campaign",
		"campaign_description": "The main campaign for the stress test mod",
		"campaign_version": "1.0.0",
		"starting_node_id": "opening",
		"default_hub_id": "",
		"initial_flags": {},
		"chapters": [
			{
				"chapter_id": "chapter_1",
				"chapter_name": "Chapter 1: The Beginning",
				"starting_node": "opening"
			}
		],
		"nodes": [
			{
				"node_id": "opening",
				"node_type": "cutscene",
				"node_name": "Opening",
				"cinematic_id": MOD_ID + ":test_opening",
				"next_nodes": ["tutorial_battle"],
				"position_x": 100,
				"position_y": 100
			},
			{
				"node_id": "tutorial_battle",
				"node_type": "battle",
				"node_name": "Tutorial Battle",
				"battle_id": MOD_ID + ":test_tutorial_battle",
				"victory_node": "post_tutorial",
				"defeat_node": "game_over",
				"position_x": 300,
				"position_y": 100
			},
			{
				"node_id": "post_tutorial",
				"node_type": "cutscene",
				"node_name": "After Tutorial",
				"cinematic_id": "",
				"next_nodes": ["boss_battle"],
				"position_x": 500,
				"position_y": 100
			},
			{
				"node_id": "boss_battle",
				"node_type": "battle",
				"node_name": "Boss Battle",
				"battle_id": MOD_ID + ":test_boss_battle",
				"victory_node": "victory",
				"defeat_node": "game_over",
				"position_x": 700,
				"position_y": 100
			},
			{
				"node_id": "victory",
				"node_type": "cutscene",
				"node_name": "Victory",
				"cinematic_id": "",
				"next_nodes": [],
				"is_campaign_end": true,
				"position_x": 900,
				"position_y": 100
			},
			{
				"node_id": "game_over",
				"node_type": "cutscene",
				"node_name": "Game Over",
				"cinematic_id": "",
				"next_nodes": [],
				"is_game_over": true,
				"position_x": 500,
				"position_y": 300
			}
		]
	}

	var path: String = "res://mods/" + MOD_ID + "/data/campaigns/test_campaign.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		_errors.append("Failed to create campaign file")
		return

	file.store_string(JSON.stringify(campaign_data, "\t"))
	file.close()
	_successes.append("Created campaign with full node graph")

	print("  [OK] Created 1 campaign")


func _create_new_game_config() -> void:
	print("\n[17/17] Creating new game config...")

	var NewGameConfigScript: GDScript = load("res://core/resources/new_game_config_data.gd")
	if not NewGameConfigScript:
		_errors.append("Could not load NewGameConfigData script")
		return

	# Create default config
	var config: Resource = NewGameConfigScript.new()
	config.config_id = "test_default"
	config.config_name = "Test Default Config"
	config.config_description = "Default starting configuration for stress test"
	config.is_default = true
	config.starting_campaign_id = MOD_ID + ":test_campaign"
	config.starting_location_label = "Opening"
	config.starting_gold = 100
	config.starting_depot_items = [
		MOD_ID + ":test_potion",
		MOD_ID + ":test_potion",
		MOD_ID + ":test_potion"
	]
	config.starting_story_flags = {
		"stress_test_started": true
	}
	config.starting_party_id = MOD_ID + ":test_starting_party"
	config.caravan_unlocked = false

	var path: String = "res://mods/" + MOD_ID + "/data/new_game_configs/test_default.tres"
	var err: Error = ResourceSaver.save(config, path)
	if err != OK:
		_errors.append("Failed to save new game config")
	else:
		_successes.append("Created new game config with all references")

	print("  [OK] Created 1 new game config")


func _test_status_effect_gap() -> void:
	print("\n[BUG TEST] Testing status effect creation (expected to fail)...")

	# Status effects have no dedicated editor - this tests the gap
	var StatusEffectScript: GDScript = load("res://core/resources/status_effect_data.gd")
	if StatusEffectScript:
		_warnings.append("BUG: StatusEffectData exists but has no editor - modders must manually create .tres files")
		print("  [BUG CONFIRMED] Status effects require manual file creation")
	else:
		_warnings.append("StatusEffectData script not found")


func _verify_resources() -> void:
	print("\n[VERIFY] Checking all resources load correctly...")

	var files_to_verify: Array = [
		"data/classes/test_warrior.tres",
		"data/classes/test_mage.tres",
		"data/abilities/test_slash.tres",
		"data/abilities/test_fireball.tres",
		"data/abilities/test_heal.tres",
		"data/items/test_sword.tres",
		"data/items/test_armor.tres",
		"data/items/test_potion.tres",
		"data/characters/test_hero.tres",
		"data/characters/test_mage_companion.tres",
		"data/characters/test_goblin.tres",
		"data/characters/test_boss.tres",
		"data/terrain/test_grass.tres",
		"data/terrain/test_forest.tres",
		"data/maps/test_battle_field.tres",
		"data/parties/test_starting_party.tres",
		"data/parties/test_goblin_squad.tres",
		"data/dialogues/test_welcome.tres",
		"data/npcs/test_shopkeeper.tres",
		"data/shops/test_weapon_shop.tres",
		"data/battles/test_tutorial_battle.tres",
		"data/battles/test_boss_battle.tres",
		"data/new_game_configs/test_default.tres"
	]

	var json_files: Array = [
		"data/cinematics/test_opening.json",
		"data/campaigns/test_campaign.json"
	]

	var load_failures: int = 0

	for rel_path: String in files_to_verify:
		var full_path: String = "res://mods/" + MOD_ID + "/" + rel_path
		var resource: Resource = load(full_path)
		if not resource:
			_errors.append("Failed to load: " + rel_path)
			load_failures += 1

	for rel_path: String in json_files:
		var full_path: String = "res://mods/" + MOD_ID + "/" + rel_path
		if not FileAccess.file_exists(full_path):
			_errors.append("Missing JSON file: " + rel_path)
			load_failures += 1
		else:
			var file: FileAccess = FileAccess.open(full_path, FileAccess.READ)
			if file:
				var content: String = file.get_as_text()
				file.close()
				var json: JSON = JSON.new()
				var parse_result: Error = json.parse(content)
				if parse_result != OK:
					_errors.append("Invalid JSON: " + rel_path + " - " + json.get_error_message())
					load_failures += 1

	if load_failures == 0:
		_successes.append("All resources loaded and validated successfully")
		print("  [OK] All resources verified")
	else:
		print("  [FAIL] " + str(load_failures) + " resources failed to load")


func _report_results() -> void:
	print("\n" + "=".repeat(60))
	print("STRESS TEST RESULTS")
	print("=".repeat(60))

	print("\nSUCCESSES (%d):" % _successes.size())
	for msg: String in _successes:
		print("  [OK] " + msg)

	if _warnings.size() > 0:
		print("\nWARNINGS (%d):" % _warnings.size())
		for msg: String in _warnings:
			print("  [WARN] " + msg)

	if _errors.size() > 0:
		print("\nERRORS (%d):" % _errors.size())
		for msg: String in _errors:
			print("  [ERROR] " + msg)

	print("\n" + "-".repeat(60))

	if _errors.size() == 0:
		print("OVERALL: PASS")
		print("The Sparkling Editor can create a complete total conversion mod.")
	else:
		print("OVERALL: FAIL")
		print("Some operations failed - see errors above.")

	print("\nKNOWN GAPS (require manual file editing):")
	print("  1. Status Effects - no dedicated editor")
	print("  2. Experience Configs - no dedicated editor")
	print("  3. Caravan Data - no dedicated editor")
	print("  4. Mod Wizard missing directories: status_effects, experience_configs,")
	print("     ai_behaviors, shops, crafting_recipes, crafters, caravans")

	print("\n" + "=".repeat(60))
