## Debug script to trace attack availability issue
## Run as scene: godot --headless res://tests/debug_attack_check.tscn
extends Node

func _ready() -> void:
	print("=== Attack Check Debug Script ===")
	await get_tree().create_timer(0.1).timeout
	_run_debug()


func _run_debug() -> void:

	# Get the hero character
	var hero: CharacterData = ModLoader.registry.get_resource("character", "character_1763762722") as CharacterData
	if not hero:
		print("ERROR: Could not find hero character!")
		get_tree().quit(1)
		return

	print("Found hero: %s" % hero.character_name)
	print("Hero starting_equipment count: %d" % hero.starting_equipment.size())

	# Check starting equipment
	for item: ItemData in hero.starting_equipment:
		if item:
			print("  - Equipment: %s (type=%d, slot=%s)" % [item.item_name, item.item_type, item.equipment_slot])
			print("    resource_path: %s" % item.resource_path)
			if item.item_type == ItemData.ItemType.WEAPON:
				print("    Weapon: ATK=%d, min_range=%d, max_range=%d" % [item.attack_power, item.min_attack_range, item.max_attack_range])
		else:
			print("  - null item in starting_equipment!")

	# Create a CharacterSaveData and populate it
	var save_data: CharacterSaveData = CharacterSaveData.new()
	save_data.populate_from_character_data(hero)

	print("\nCharacterSaveData equipped_items:")
	for entry: Dictionary in save_data.equipped_items:
		print("  - slot=%s, mod_id=%s, item_id=%s" % [entry.get("slot", ""), entry.get("mod_id", ""), entry.get("item_id", "")])

		# Try to load the item from registry
		var item_id: String = entry.get("item_id", "")
		var loaded_item: ItemData = ModLoader.registry.get_resource("item", item_id) as ItemData
		if loaded_item:
			print("    -> Successfully loaded from registry: %s" % loaded_item.item_name)
		else:
			print("    -> FAILED to load from registry!")
			# Debug: list all items in registry
			var all_items: Array[Resource] = ModLoader.registry.get_all_resources("item")
			print("    Available items in registry (%d total):" % all_items.size())
			for i: int in range(min(10, all_items.size())):
				var it: ItemData = all_items[i] as ItemData
				if it:
					print("      - %s (path: %s)" % [it.item_name, it.resource_path])

	# Create UnitStats and load equipment
	var UnitStatsClass: GDScript = load("res://core/components/unit_stats.gd")
	var stats: RefCounted = UnitStatsClass.new()
	stats.calculate_from_character(hero)

	print("\nAfter calculate_from_character:")
	print("  cached_weapon: %s" % (stats.cached_weapon.item_name if stats.cached_weapon else "null"))

	# Now test load_equipment_from_save
	stats.load_equipment_from_save(save_data)

	print("\nAfter load_equipment_from_save:")
	print("  cached_weapon: %s" % (stats.cached_weapon.item_name if stats.cached_weapon else "null"))
	if stats.cached_weapon:
		print("  min_range: %d" % stats.get_weapon_min_range())
		print("  max_range: %d" % stats.get_weapon_max_range())

	# Now test the full Unit initialization path like battle_loader does
	print("\n=== Testing Unit initialization from save data ===")
	var UnitScene: PackedScene = load("res://scenes/unit.tscn")
	var unit: Node2D = UnitScene.instantiate()
	add_child(unit)

	# This is what battle_loader._spawn_unit() does when p_save_data is provided
	unit.initialize_from_save_data(hero, save_data, "player", null)

	print("Unit initialized:")
	print("  unit.stats: %s" % (unit.stats != null))
	if unit.stats:
		print("  unit.stats.cached_weapon: %s" % (unit.stats.cached_weapon.item_name if unit.stats.cached_weapon else "null"))
		print("  unit.stats.get_weapon_min_range(): %d" % unit.stats.get_weapon_min_range())
		print("  unit.stats.get_weapon_max_range(): %d" % unit.stats.get_weapon_max_range())

	# Clean up
	unit.queue_free()

	print("\n=== Debug Complete ===")
	get_tree().quit(0)
