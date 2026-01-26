extends "res://scenes/ui/shops/screens/shop_screen_base.gd"

## SellCharSelect - "Who's selling?" screen for sell mode
##
## Shows party members and Caravan as sources for selling.
## Selecting a source proceeds to sell_inventory screen.

var character_buttons: Array[Button] = []

@onready var header_label: Label = %HeaderLabel
@onready var character_grid: GridContainer = %CharacterGrid
@onready var caravan_button: Button = %CaravanButton
@onready var back_button: Button = %BackButton


func _on_initialized() -> void:
	_populate_character_grid()
	_setup_caravan_button()

	back_button.pressed.connect(_on_back_pressed)

	await get_tree().process_frame
	if character_buttons.size() > 0:
		character_buttons[0].grab_focus()
	elif caravan_button.visible:
		caravan_button.grab_focus()


func _populate_character_grid() -> void:
	# Clear existing
	for child: Node in character_grid.get_children():
		child.queue_free()
	character_buttons.clear()

	if not PartyManager:
		return

	for character: CharacterData in PartyManager.party_members:
		var button: Button = _create_character_button(character)
		character_grid.add_child(button)
		character_buttons.append(button)

		var uid: String = character.character_uid
		button.pressed.connect(_on_character_selected.bind(uid))


func _create_character_button(character: CharacterData) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(140, 50)
	button.focus_mode = Control.FOCUS_ALL

	# Get inventory count
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(character.character_uid)
	var item_count: int = save_data.inventory.size() if save_data else 0

	if item_count == 0:
		button.disabled = true
		button.text = "%s\n(no items)" % character.character_name
	else:
		button.text = "%s\n(%d items)" % [character.character_name, item_count]

	return button


func _setup_caravan_button() -> void:
	caravan_button.visible = context.shop.can_sell_from_caravan and StorageManager.is_caravan_available()
	if caravan_button.visible:
		var item_count: int = StorageManager.get_depot_size()
		if item_count == 0:
			caravan_button.disabled = true
			caravan_button.text = "CARAVAN\n(empty)"
		else:
			caravan_button.text = "CARAVAN\n(%d items)" % item_count

		caravan_button.pressed.connect(_on_caravan_selected)


func _on_character_selected(character_uid: String) -> void:
	context.selling_from_uid = character_uid
	push_screen("sell_inventory")


func _on_caravan_selected() -> void:
	context.selling_from_uid = "caravan"
	push_screen("sell_inventory")


func _on_back_pressed() -> void:
	go_back()


func _on_screen_exit() -> void:
	# Disconnect signals to prevent memory leaks
	if is_instance_valid(back_button) and back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.disconnect(_on_back_pressed)

	if is_instance_valid(caravan_button) and caravan_button.pressed.is_connected(_on_caravan_selected):
		caravan_button.pressed.disconnect(_on_caravan_selected)

	# Character buttons will be freed with the grid, just clear references
	character_buttons.clear()
