extends "res://scenes/ui/caravan/screens/caravan_screen_base.gd"

## CharSelect - Select a character for depot operations
##
## Used for both:
## - TAKE mode: "Who receives this item?" -> Execute transfer and return
## - STORE mode: "Whose inventory?" -> Push to char_inventory screen

## Colors matching project standards
const COLOR_NORMAL: Color = Color(0.8, 0.8, 0.8, 1.0)
const COLOR_SELECTED: Color = Color(1.0, 1.0, 0.3, 1.0)
const COLOR_DISABLED: Color = Color(0.4, 0.4, 0.4, 1.0)
const COLOR_SUCCESS: Color = Color(0.4, 1.0, 0.4, 1.0)
const COLOR_ERROR: Color = Color(1.0, 0.4, 0.4, 1.0)
const COLOR_WARNING: Color = Color(1.0, 0.8, 0.3, 1.0)

## Character button references
var char_buttons: Array[Button] = []

## Currently selected character UID
var selected_uid: String = ""

## UID of character with pending "can't equip" warning (click again to confirm)
var _pending_warning_uid: String = ""

@onready var header_label: Label = %HeaderLabel
@onready var item_label: Label = %ItemLabel
@onready var char_grid: GridContainer = %CharacterGrid
@onready var confirm_button: Button = %ConfirmButton
@onready var back_button: Button = %BackButton
@onready var result_label: Label = %ResultLabel


func _on_initialized() -> void:
	# Set header based on mode
	if context and context.is_take_mode():
		header_label.text = "WHO RECEIVES THIS?"
		var item_data: ItemData = get_item_data(context.selected_depot_item_id)
		if item_data:
			item_label.text = item_data.item_name.to_upper()
		else:
			item_label.text = context.selected_depot_item_id
		item_label.visible = true
	elif context and context.is_store_mode():
		header_label.text = "WHOSE INVENTORY?"
		item_label.visible = false
	else:
		header_label.text = "SELECT CHARACTER"
		item_label.visible = false

	_populate_character_grid()

	# Connect buttons
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)

	confirm_button.disabled = true
	result_label.text = ""


func _populate_character_grid() -> void:
	# Clear existing
	for child: Node in char_grid.get_children():
		child.queue_free()
	char_buttons.clear()

	if not PartyManager:
		return

	var max_slots: int = get_max_inventory_slots()

	for character: CharacterData in PartyManager.party_members:
		var uid: String = character.character_uid
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(uid)
		var slots_used: int = save_data.inventory.size() if save_data else 0

		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(140, 50)
		button.focus_mode = Control.FOCUS_ALL

		# Format: Name (slots)
		button.text = "%s\n(%d/%d)" % [character.character_name, slots_used, max_slots]

		# Disable if inventory full (for TAKE mode) or empty (for STORE mode)
		var should_disable: bool = false
		if context and context.is_take_mode():
			should_disable = slots_used >= max_slots
			if should_disable:
				button.text = "%s\nFULL" % character.character_name
		elif context and context.is_store_mode():
			should_disable = slots_used == 0
			if should_disable:
				button.text = "%s\nEMPTY" % character.character_name

		button.disabled = should_disable
		if should_disable:
			button.add_theme_color_override("font_color", COLOR_DISABLED)

		char_grid.add_child(button)
		char_buttons.append(button)

		button.pressed.connect(_on_char_pressed.bind(uid, button))
		button.focus_entered.connect(_on_char_focus_entered.bind(uid))

	# Handle no characters
	if char_buttons.is_empty():
		var label: Label = Label.new()
		label.text = "No party members!"
		label.add_theme_color_override("font_color", COLOR_DISABLED)
		char_grid.add_child(label)
		return

	# Focus first enabled button
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	_focus_first_enabled()


func _focus_first_enabled() -> void:
	for btn: Button in char_buttons:
		if is_instance_valid(btn) and not btn.disabled:
			btn.grab_focus()
			return


func _on_char_focus_entered(uid: String) -> void:
	play_sfx("cursor_move")


func _on_char_pressed(uid: String, button: Button) -> void:
	selected_uid = uid

	# Clear previous selection highlight
	for btn: Button in char_buttons:
		if not btn.disabled:
			btn.add_theme_color_override("font_color", COLOR_NORMAL)

	# Highlight selected
	button.add_theme_color_override("font_color", COLOR_SELECTED)

	# Store in context
	if context:
		context.selected_character_uid = uid

	# SF2 authentic: selection IS confirmation, execute immediately
	if context and context.is_take_mode():
		# Check if this is confirming a previous warning
		if _pending_warning_uid == uid:
			# User confirmed despite warning - proceed
			_pending_warning_uid = ""
			result_label.text = ""
			_execute_take()
			return

		# Clear any previous warning for different character
		if not _pending_warning_uid.is_empty() and _pending_warning_uid != uid:
			_pending_warning_uid = ""
			result_label.text = ""

		# Check equipment compatibility for equippable items
		var item_id: String = context.selected_depot_item_id
		var item_data: ItemData = get_item_data(item_id)
		if item_data and item_data.is_equippable():
			if ShopManager and not ShopManager.can_character_equip(uid, item_id):
				# Show warning - character can't equip this
				var char_data: CharacterData = _get_character_data(uid)
				var char_name: String = char_data.character_name if char_data else uid
				_show_warning("%s can't equip this! Select again to give anyway." % char_name)
				_pending_warning_uid = uid
				return

		# No warning needed - execute immediately
		_pending_warning_uid = ""
		_execute_take()
	elif context and context.is_store_mode():
		_pending_warning_uid = ""
		_go_to_inventory()


func _on_confirm_pressed() -> void:
	if selected_uid.is_empty():
		return

	if context and context.is_take_mode():
		_execute_take()
	elif context and context.is_store_mode():
		_go_to_inventory()


func _execute_take() -> void:
	## Execute the take operation (depot -> character)
	var item_id: String = context.selected_depot_item_id
	if item_id.is_empty():
		_show_result("No item selected!", false)
		return

	# Remove from depot
	if not StorageManager.remove_from_depot(item_id):
		_show_result("Failed to remove from depot!", false)
		return

	# Add to character inventory
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(selected_uid)
	if not save_data:
		# Rollback
		StorageManager.add_to_depot(item_id)
		_show_result("Character not found!", false)
		return

	if not save_data.add_item_to_inventory(item_id):
		# Rollback
		StorageManager.add_to_depot(item_id)
		_show_result("Inventory full!", false)
		return

	# Success!
	var item_data: ItemData = get_item_data(item_id)
	var item_name: String = item_data.item_name if item_data else item_id
	var char_data: CharacterData = _get_character_data(selected_uid)
	var char_name: String = char_data.character_name if char_data else selected_uid

	_show_result("%s received %s!" % [char_name, item_name], true)
	play_sfx("menu_confirm")

	# Clear selection and refresh
	context.selected_depot_item_id = ""

	# Wait briefly then go back to depot browser
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(self):
		go_back()


func _go_to_inventory() -> void:
	## Go to char_inventory screen for store mode
	play_sfx("menu_select")
	push_screen("char_inventory")


func _show_result(message: String, success: bool) -> void:
	result_label.text = message
	if success:
		result_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	else:
		result_label.add_theme_color_override("font_color", COLOR_ERROR)
		play_sfx("menu_error")


func _show_warning(message: String) -> void:
	result_label.text = message
	result_label.add_theme_color_override("font_color", COLOR_WARNING)
	play_sfx("menu_error")


func _get_character_data(uid: String) -> CharacterData:
	if not PartyManager:
		return null
	for character: CharacterData in PartyManager.party_members:
		if character.character_uid == uid:
			return character
	return null


func _on_back_pressed() -> void:
	go_back()


func _on_screen_exit() -> void:
	if is_instance_valid(confirm_button) and confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.disconnect(_on_confirm_pressed)
	if is_instance_valid(back_button) and back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.disconnect(_on_back_pressed)
