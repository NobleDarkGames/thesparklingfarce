extends Node

## Test script for Save System (Phase 1)
##
## Tests:
## 1. Create new SaveData
## 2. Save to slot 1
## 3. Load from slot 1
## 4. Verify data integrity
## 5. Test copy slot
## 6. Test delete slot
## 7. Test metadata system

func _ready() -> void:
	var separator: String = "============================================================"
	print("\n" + separator)
	print("SAVE SYSTEM TEST - PHASE 1")
	print(separator + "\n")

	# Run tests
	await get_tree().create_timer(0.5).timeout
	_test_basic_save_load()

	await get_tree().create_timer(0.5).timeout
	_test_party_integration()

	await get_tree().create_timer(0.5).timeout
	_test_slot_operations()

	await get_tree().create_timer(0.5).timeout
	_test_metadata()

	var separator2: String = "============================================================"
	print("\n" + separator2)
	print("SAVE SYSTEM TEST COMPLETE")
	print(separator2 + "\n")

	# Print final slot status
	SaveManager.print_all_slots()


# ============================================================================
# TEST 1: Basic Save/Load
# ============================================================================

func _test_basic_save_load() -> void:
	print("\n--- TEST 1: Basic Save/Load ---\n")

	# Create save data
	var save_data: SaveData = SaveData.new()
	save_data.slot_number = 1
	save_data.created_timestamp = Time.get_unix_time_from_system()
	save_data.last_played_timestamp = save_data.created_timestamp
	save_data.playtime_seconds = 1234  # 00:20:34
	save_data.game_version = "0.1.0"
	save_data.current_location = "test_location"
	save_data.gold = 500

	# Add active mods
	for manifest: ModManifest in ModLoader.loaded_mods:
		save_data.active_mods.append({
			"mod_id": manifest.mod_id,
			"version": manifest.version
		})

	# Add story flags
	save_data.story_flags["test_flag"] = true
	save_data.story_flags["prologue_complete"] = true

	# Add completed battles
	save_data.completed_battles.append("battle_test_1")

	print("✓ Created SaveData:")
	print("  Location: %s" % save_data.current_location)
	print("  Gold: %d" % save_data.gold)
	print("  Playtime: %s" % save_data._format_playtime())
	print("  Active mods: %d" % save_data.active_mods.size())

	# Validate
	if not save_data.validate():
		print("✗ SaveData validation FAILED")
		return

	print("✓ SaveData validation passed")

	# Save to slot 1
	print("\n✓ Saving to slot 1...")
	var save_success: bool = SaveManager.save_to_slot(1, save_data)

	if not save_success:
		print("✗ Save FAILED")
		return

	print("✓ Save successful")

	# Load from slot 1
	print("\n✓ Loading from slot 1...")
	var loaded_save: SaveData = SaveManager.load_from_slot(1)

	if not loaded_save:
		print("✗ Load FAILED")
		return

	print("✓ Load successful")

	# Verify data
	print("\n✓ Verifying loaded data...")
	var verification_passed: bool = true

	if loaded_save.current_location != save_data.current_location:
		print("✗ Location mismatch: %s != %s" % [loaded_save.current_location, save_data.current_location])
		verification_passed = false

	if loaded_save.gold != save_data.gold:
		print("✗ Gold mismatch: %d != %d" % [loaded_save.gold, save_data.gold])
		verification_passed = false

	if loaded_save.playtime_seconds != save_data.playtime_seconds:
		print("✗ Playtime mismatch: %d != %d" % [loaded_save.playtime_seconds, save_data.playtime_seconds])
		verification_passed = false

	if not "test_flag" in loaded_save.story_flags or not loaded_save.story_flags.test_flag:
		print("✗ Story flag missing or incorrect")
		verification_passed = false

	if not loaded_save.completed_battles.has("battle_test_1"):
		print("✗ Completed battle missing")
		verification_passed = false

	if verification_passed:
		print("✓ All data verified successfully!")
	else:
		print("✗ Data verification FAILED")


# ============================================================================
# TEST 2: Party Integration
# ============================================================================

func _test_party_integration() -> void:
	print("\n--- TEST 2: Party Integration ---\n")

	# Try to load a character from base_game mod
	var hero: Resource = ModLoader.registry.get_resource("character", "hero")

	if not hero or not hero is CharacterData:
		print("⚠ Warning: No 'hero' character in base_game mod, skipping party test")
		return

	print("✓ Loaded hero character: %s" % hero.character_name)

	# Set party
	PartyManager.set_party([hero])
	print("✓ Set party with hero")

	# Export to save
	var party_save_data: Array[CharacterSaveData] = PartyManager.export_to_save()
	print("✓ Exported party: %d members" % party_save_data.size())

	if party_save_data.is_empty():
		print("✗ Party export FAILED - no members")
		return

	# Verify export
	var char_save: CharacterSaveData = party_save_data[0]
	print("  Character: %s" % char_save.fallback_character_name)
	print("  Mod ID: %s" % char_save.character_mod_id)
	print("  Resource ID: %s" % char_save.character_resource_id)
	print("  Level: %d" % char_save.level)

	# Create full save with party
	var save_data: SaveData = SaveData.new()
	save_data.slot_number = 2
	save_data.created_timestamp = Time.get_unix_time_from_system()
	save_data.last_played_timestamp = save_data.created_timestamp
	save_data.current_location = "headquarters"
	save_data.game_version = "0.1.0"
	save_data.party_members = party_save_data

	# Add active mods
	for manifest: ModManifest in ModLoader.loaded_mods:
		save_data.active_mods.append({
			"mod_id": manifest.mod_id,
			"version": manifest.version
		})

	# Save to slot 2
	print("\n✓ Saving party to slot 2...")
	if not SaveManager.save_to_slot(2, save_data):
		print("✗ Save with party FAILED")
		return

	print("✓ Save with party successful")

	# Load and restore party
	print("\n✓ Loading party from slot 2...")
	var loaded_save: SaveData = SaveManager.load_from_slot(2)

	if not loaded_save:
		print("✗ Load FAILED")
		return

	if loaded_save.party_members.is_empty():
		print("✗ Loaded save has no party members")
		return

	print("✓ Loaded save has %d party members" % loaded_save.party_members.size())

	# Import party
	print("\n✓ Importing party into PartyManager...")
	PartyManager.import_from_save(loaded_save.party_members)

	print("✓ Party imported: %d members" % PartyManager.get_party_size())

	if not PartyManager.is_empty():
		var leader: CharacterData = PartyManager.get_leader()
		if leader:
			print("  Leader: %s" % leader.character_name)


# ============================================================================
# TEST 3: Slot Operations
# ============================================================================

func _test_slot_operations() -> void:
	print("\n--- TEST 3: Slot Operations ---\n")

	# Check slot occupation
	print("✓ Checking slot occupation...")
	var slot1_occupied: bool = SaveManager.is_slot_occupied(1)
	var slot2_occupied: bool = SaveManager.is_slot_occupied(2)
	var slot3_occupied: bool = SaveManager.is_slot_occupied(3)

	print("  Slot 1: %s" % ("Occupied" if slot1_occupied else "Empty"))
	print("  Slot 2: %s" % ("Occupied" if slot2_occupied else "Empty"))
	print("  Slot 3: %s" % ("Occupied" if slot3_occupied else "Empty"))

	# Copy slot 1 to slot 3
	if slot1_occupied:
		print("\n✓ Copying slot 1 to slot 3...")
		if SaveManager.copy_slot(1, 3):
			print("✓ Copy successful")

			# Verify copy
			var slot3_data: SaveData = SaveManager.load_from_slot(3)
			if slot3_data:
				print("  Copied save location: %s" % slot3_data.current_location)
				print("  Copied save gold: %d" % slot3_data.gold)
		else:
			print("✗ Copy FAILED")

	# Delete slot 3
	print("\n✓ Deleting slot 3...")
	if SaveManager.delete_slot(3):
		print("✓ Delete successful")

		# Verify deletion
		if not SaveManager.is_slot_occupied(3):
			print("  Slot 3 is now empty")
		else:
			print("✗ Slot 3 still occupied after delete")
	else:
		print("✗ Delete FAILED")


# ============================================================================
# TEST 4: Metadata System
# ============================================================================

func _test_metadata() -> void:
	print("\n--- TEST 4: Metadata System ---\n")

	# Get all metadata
	print("✓ Loading all slot metadata...")
	var all_metadata: Array[SlotMetadata] = SaveManager.get_all_slot_metadata()

	print("✓ Retrieved metadata for %d slots" % all_metadata.size())

	for meta: SlotMetadata in all_metadata:
		print("\nSlot %d:" % meta.slot_number)
		if meta.is_occupied:
			print("  Status: Occupied")
			print("  Leader: %s" % meta.party_leader_name)
			print("  Location: %s" % meta.current_location)
			print("  Level: %d" % meta.average_level)
			print("  Playtime: %s" % meta.get_playtime_string())
			print("  Last Played: %s" % meta.get_last_played_string())
			print("  Mod Mismatch: %s" % ("Yes" if meta.has_mod_mismatch else "No"))
			print("  Display: %s" % meta.get_display_string())
		else:
			print("  Status: Empty")

	# Get specific slot metadata
	print("\n✓ Getting metadata for slot 1...")
	var slot1_meta: SlotMetadata = SaveManager.get_slot_metadata(1)
	print("  %s" % slot1_meta.get_display_string())
