extends Control

## Test scene for PartyEquipmentMenu and CaravanDepotPanel
##
## Provides a full test environment for inventory management:
## - Sets up a party with multiple characters
## - Populates inventories and depot with test items
## - Allows testing transfers, equip/unequip, depot operations
##
## Run this scene directly to test inventory management.

const PartyEquipmentMenuScene: PackedScene = preload("res://scenes/ui/party_equipment_menu.tscn")
const CaravanDepotPanelScene: PackedScene = preload("res://scenes/ui/caravan_depot_panel.tscn")
const MONOGRAM_FONT: Font = preload("res://assets/fonts/monogram.ttf")

var _party_menu: Control = null
var _depot_panel: Control = null
var _status_label: Label = null
var _instructions_label: Label = null


func _ready() -> void:
	# Wait for autoloads
	if not ModLoader.is_node_ready():
		await ModLoader.ready

	# Diagnostic viewport information
	print("=== VIEWPORT DIAGNOSTIC ===")
	print("Viewport visible rect: ", get_viewport().get_visible_rect().size)
	print("Window size: ", DisplayServer.window_get_size())
	print("Root size: ", get_tree().root.size)
	print("Content scale factor: ", get_tree().root.content_scale_factor)
	print("Content scale mode: ", get_tree().root.content_scale_mode)
	print("Content scale aspect: ", get_tree().root.content_scale_aspect)
	print("===========================")

	_build_ui()
	_setup_test_party()
	_setup_test_items()

	_update_status("Ready! Press I to open Party Inventory, D to open Depot")


func _build_ui() -> void:
	# Dark background
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.2, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Status bar at top - sized for 640x360 viewport
	var status_container: PanelContainer = PanelContainer.new()
	status_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status_container.offset_bottom = 20

	var status_style: StyleBoxFlat = StyleBoxFlat.new()
	status_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	status_style.content_margin_left = 4
	status_style.content_margin_right = 4
	status_style.content_margin_top = 2
	status_style.content_margin_bottom = 2
	status_container.add_theme_stylebox_override("panel", status_style)
	add_child(status_container)

	_status_label = Label.new()
	_status_label.add_theme_font_override("font", MONOGRAM_FONT)
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.text = "Initializing..."
	status_container.add_child(_status_label)

	# Instructions in center
	_instructions_label = Label.new()
	_instructions_label.set_anchors_preset(Control.PRESET_CENTER)
	_instructions_label.add_theme_font_override("font", MONOGRAM_FONT)
	_instructions_label.add_theme_font_size_override("font_size", 16)
	_instructions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instructions_label.text = """Party Inventory Test Scene

[I] - Open Party Equipment Menu
[D] - Open Caravan Depot
[R] - Reset test data
[Q] - Quit

Party: Max, Maggie, Warrioso
Each character has test items.
Depot has additional items to retrieve."""
	add_child(_instructions_label)

	# Create menu instances (hidden initially)
	_party_menu = PartyEquipmentMenuScene.instantiate()
	_party_menu.visible = false
	_party_menu.close_requested.connect(_on_party_menu_close)
	_party_menu.depot_requested.connect(_on_depot_requested)
	_party_menu.item_transferred.connect(_on_item_transferred)
	add_child(_party_menu)

	_depot_panel = CaravanDepotPanelScene.instantiate()
	_depot_panel.visible = false
	_depot_panel.close_requested.connect(_on_depot_close)
	_depot_panel.item_taken.connect(_on_item_taken)
	add_child(_depot_panel)


func _setup_test_party() -> void:
	# Load test characters
	var characters_to_load: Array[String] = ["max", "maggie", "warrioso"]
	var loaded_characters: Array[CharacterData] = []

	for char_id: String in characters_to_load:
		var char_data: CharacterData = ModLoader.registry.get_resource("character", char_id) as CharacterData
		if char_data:
			loaded_characters.append(char_data)
			print("Loaded character: ", char_data.character_name)
		else:
			print("Could not load character: ", char_id)

	if loaded_characters.is_empty():
		push_error("No test characters could be loaded!")
		return

	# Set up party
	PartyManager.set_party(loaded_characters)
	print("Party set with %d members" % PartyManager.get_party_size())


func _setup_test_items() -> void:
	# Add items to each party member's inventory
	for character: CharacterData in PartyManager.party_members:
		var uid: String = character.character_uid
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(uid)
		if not save_data:
			continue

		# Clear existing inventory
		save_data.inventory.clear()

		# Add different items per character
		match character.character_name.to_lower():
			"max":
				save_data.inventory.append("example_sword")
				save_data.inventory.append("power_ring")
			"maggie":
				save_data.inventory.append("cursed_blade")
				save_data.inventory.append("power_ring")
			"warrioso":
				save_data.inventory.append("example_sword")

		print("Set up inventory for %s: %s" % [character.character_name, save_data.inventory])

	# Clear and populate depot
	StorageManager.reset()
	StorageManager.add_to_depot("example_sword")
	StorageManager.add_to_depot("example_sword")
	StorageManager.add_to_depot("power_ring")
	StorageManager.add_to_depot("power_ring")
	StorageManager.add_to_depot("power_ring")

	# Try to add any other available items from registry
	var all_items: Array[Resource] = ModLoader.registry.get_all_resources("item")
	var added_count: int = 0
	for item_res: Resource in all_items:
		var item: ItemData = item_res as ItemData
		if item and added_count < 5:
			var item_id: String = item.resource_path.get_file().get_basename()
			if item_id != "example_sword" and item_id != "power_ring" and item_id != "cursed_blade":
				StorageManager.add_to_depot(item_id)
				added_count += 1

	print("Depot populated with %d items" % StorageManager.get_depot_size())


func _update_status(text: String) -> void:
	if _status_label:
		_status_label.text = text


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey

		# Only process if no menu is open
		if _party_menu.visible or _depot_panel.visible:
			return

		match key_event.keycode:
			KEY_I:
				_open_party_menu()
			KEY_D:
				_open_depot()
			KEY_R:
				_reset_test_data()
			KEY_Q:
				get_tree().quit()


func _open_party_menu() -> void:
	_party_menu.refresh()
	_party_menu.visible = true
	_instructions_label.visible = false
	_update_status("Party Equipment Menu - Tab to switch characters, Give to... to transfer items")


func _open_depot() -> void:
	_depot_panel.refresh()
	_depot_panel.visible = true
	_instructions_label.visible = false
	_update_status("Caravan Depot - Select item and Take to add to character inventory")


func _reset_test_data() -> void:
	_setup_test_items()
	_update_status("Test data reset! Press I or D to open menus.")


func _on_party_menu_close() -> void:
	_party_menu.visible = false
	_instructions_label.visible = true
	_update_status("Party menu closed. Press I to reopen, D for Depot")


func _on_depot_requested() -> void:
	_party_menu.visible = false
	_open_depot()


func _on_depot_close() -> void:
	_depot_panel.visible = false
	_instructions_label.visible = true
	_update_status("Depot closed. Press D to reopen, I for Party menu")


func _on_item_transferred(from_uid: String, to_uid: String, item_id: String) -> void:
	_update_status("Transferred %s from %s to %s" % [item_id, from_uid, to_uid])


func _on_item_taken(item_id: String, character_uid: String) -> void:
	_update_status("Took %s from depot for %s" % [item_id, character_uid])
