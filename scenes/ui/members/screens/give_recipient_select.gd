extends "res://scenes/ui/members/screens/members_screen_base.gd"

## GiveRecipientSelect - Select a character to receive an item
##
## 95% reuse from Caravan's char_select.gd
## Used for GIVE mode: character A's item -> character B
## Shows "can't equip" warning with double-click to confirm pattern

## Character button references
var char_buttons: Array[Button] = []

## Currently selected character UID
var selected_uid: String = ""

## UID of character with pending "can't equip" warning (click again to confirm)
var _pending_warning_uid: String = ""

## Source character UID (who is giving)
var _source_uid: String = ""

## Item being given
var _item_id: String = ""

@onready var header_label: Label = %HeaderLabel
@onready var item_label: Label = %ItemLabel
@onready var char_grid: GridContainer = %CharacterGrid
@onready var back_button: Button = %BackButton
@onready var result_label: Label = %ResultLabel


func _on_initialized() -> void:
	# Get give mode data from context
	if context:
		_source_uid = context.source_character_uid
		_item_id = context.selected_give_item_id

	# Set header
	header_label.text = "WHO RECEIVES THIS?"

	# Show item name
	var item_data: ItemData = get_item_data(_item_id)
	if item_data:
		item_label.text = item_data.item_name.to_upper()
	else:
		item_label.text = _item_id
	item_label.visible = true

	_populate_character_grid()

	# Connect back button
	back_button.pressed.connect(_on_back_pressed)

	result_label.text = ""


func _populate_character_grid() -> void:
	_clear_container(char_grid)
	char_buttons.clear()

	if not PartyManager:
		return

	var max_slots: int = get_max_inventory_slots()

	for character: CharacterData in PartyManager.party_members:
		var uid: String = character.character_uid

		# Skip the source character (can't give to yourself)
		if uid == _source_uid:
			continue

		var save_data: CharacterSaveData = get_character_save_data(uid)
		var slots_used: int = save_data.inventory.size() if save_data else 0

		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(140, 50)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", 16)

		# Format: Name (slots)
		button.text = "%s\n(%d/%d)" % [character.character_name, slots_used, max_slots]

		# Disable if inventory full
		var should_disable: bool = slots_used >= max_slots
		if should_disable:
			button.text = "%s\nFULL" % character.character_name

		button.disabled = should_disable
		if should_disable:
			button.add_theme_color_override("font_color", UIColors.MENU_DISABLED)

		char_grid.add_child(button)
		char_buttons.append(button)

		button.pressed.connect(_on_char_pressed.bind(uid, button))
		button.focus_entered.connect(_on_char_focus_entered.bind(uid))

	# Handle no valid recipients
	if char_buttons.is_empty():
		var label: Label = Label.new()
		label.text = "No one to give to!"
		label.add_theme_color_override("font_color", UIColors.MENU_DISABLED)
		char_grid.add_child(label)
		return

	# Focus first enabled button
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	_focus_first_enabled()


func _focus_first_enabled() -> void:
	_focus_first_in_list(char_buttons)


func _on_char_focus_entered(uid: String) -> void:
	play_sfx("cursor_move")


func _on_char_pressed(uid: String, button: Button) -> void:
	selected_uid = uid

	# Clear previous selection highlight
	for btn: Button in char_buttons:
		if not btn.disabled:
			btn.add_theme_color_override("font_color", UIColors.MENU_NORMAL)

	# Highlight selected
	button.add_theme_color_override("font_color", UIColors.MENU_SELECTED)

	# Check if this is confirming a previous warning
	if _pending_warning_uid == uid:
		# User confirmed despite warning - proceed
		_pending_warning_uid = ""
		result_label.text = ""
		_execute_give()
		return

	# Clear any previous warning for different character
	if not _pending_warning_uid.is_empty() and _pending_warning_uid != uid:
		_pending_warning_uid = ""
		result_label.text = ""

	# Check equipment compatibility for equippable items
	var item_data: ItemData = get_item_data(_item_id)
	if item_data and item_data.is_equippable():
		if not can_character_equip(uid, _item_id):
			# Show warning - character can't equip this
			var char_data: CharacterData = get_character_data(uid)
			var char_name: String = char_data.character_name if char_data else uid
			_show_warning("%s can't equip this! Select again to give anyway." % char_name)
			_pending_warning_uid = uid
			return

	# No warning needed - execute immediately (SF2 authentic: instant transfer!)
	_pending_warning_uid = ""
	_execute_give()


func _execute_give() -> void:
	## Execute the give operation (character -> character)
	if _item_id.is_empty() or _source_uid.is_empty() or selected_uid.is_empty():
		_show_result("Missing data for transfer!", false)
		return

	# Execute the transfer
	var result: Dictionary = transfer_item_between_members(_source_uid, selected_uid, _item_id)

	if result.get("success", false):
		# Success!
		var item_data: ItemData = get_item_data(_item_id)
		var item_name: String = item_data.item_name if item_data else _item_id
		var recipient: CharacterData = get_character_data(selected_uid)
		var recipient_name: String = recipient.character_name if recipient else selected_uid

		_show_result("%s received %s!" % [recipient_name, item_name], true)

		# Clear context state
		if context:
			context.source_character_uid = ""
			context.selected_give_item_id = ""
			context.set_browse_mode()

		# Wait briefly then go back to member_detail
		await get_tree().create_timer(0.8).timeout
		if is_instance_valid(self):
			go_back()
	else:
		_show_result(result.get("error", "Transfer failed!"), false)


func _show_result(message: String, success: bool) -> void:
	_show_result_on_label(result_label, message, success)


func _show_warning(message: String) -> void:
	_show_warning_on_label(result_label, message)


func _on_back_pressed() -> void:
	# Clear give mode on cancel
	if context:
		context.source_character_uid = ""
		context.selected_give_item_id = ""
		context.set_browse_mode()
	go_back()


func _on_screen_exit() -> void:
	if is_instance_valid(back_button) and back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.disconnect(_on_back_pressed)
