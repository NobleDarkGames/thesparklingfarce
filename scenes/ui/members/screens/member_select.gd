extends "res://scenes/ui/members/screens/members_screen_base.gd"

## MemberSelect - Entry screen for Members interface
##
## Shows a grid of party members. Select one to view their details.
## Based on Caravan's char_select.gd but simplified (no TAKE/STORE modes).

## Colors matching project standards
const COLOR_NORMAL: Color = Color(0.8, 0.8, 0.8, 1.0)
const COLOR_SELECTED: Color = Color(1.0, 1.0, 0.3, 1.0)
const COLOR_DISABLED: Color = Color(0.4, 0.4, 0.4, 1.0)

## Character button references
var char_buttons: Array[Button] = []

## Currently focused button index
var focused_index: int = 0

@onready var header_label: Label = %HeaderLabel
@onready var char_grid: GridContainer = %CharacterGrid
@onready var depot_button: Button = %DepotButton
@onready var back_button: Button = %BackButton
@onready var info_label: Label = %InfoLabel


func _on_initialized() -> void:
	header_label.text = "MEMBERS"

	_populate_character_grid()

	# Connect buttons
	depot_button.pressed.connect(_on_depot_pressed)
	back_button.pressed.connect(_on_back_pressed)

	# Focus navigation for depot/back buttons
	depot_button.focus_entered.connect(_on_depot_focus_entered)
	back_button.focus_entered.connect(_on_back_focus_entered)


func _populate_character_grid() -> void:
	# Clear existing
	for child: Node in char_grid.get_children():
		child.queue_free()
	char_buttons.clear()

	if not PartyManager:
		return

	var max_slots: int = get_max_inventory_slots()

	for i: int in range(PartyManager.party_members.size()):
		var character: CharacterData = PartyManager.party_members[i]
		var uid: String = character.character_uid
		var save_data: CharacterSaveData = get_character_save_data(uid)
		var slots_used: int = save_data.inventory.size() if save_data else 0
		var current_hp: int = save_data.current_hp if save_data else 0
		var max_hp: int = save_data.max_hp if save_data else 1

		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(140, 60)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", 16)

		# Format: Name, inventory count, HP
		button.text = "%s\n(%d/%d items)\nHP: %d/%d" % [
			character.character_name,
			slots_used, max_slots,
			current_hp, max_hp
		]

		char_grid.add_child(button)
		char_buttons.append(button)

		var captured_index: int = i
		button.pressed.connect(_on_char_pressed.bind(captured_index))
		button.focus_entered.connect(_on_char_focus_entered.bind(captured_index))

	# Handle no characters
	if char_buttons.is_empty():
		var label: Label = Label.new()
		label.text = "No party members!"
		label.add_theme_color_override("font_color", COLOR_DISABLED)
		char_grid.add_child(label)
		return

	# Focus first button
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	if char_buttons.size() > 0 and is_instance_valid(char_buttons[0]):
		char_buttons[0].grab_focus()
		focused_index = 0


func _on_char_focus_entered(index: int) -> void:
	focused_index = index
	_update_info_for_character(index)
	play_sfx("cursor_move")


func _on_char_pressed(index: int) -> void:
	# Set the current member in context and go to detail screen
	if context:
		context.current_member_index = index

	play_sfx("menu_select")
	push_screen("member_detail")


func _update_info_for_character(index: int) -> void:
	if index < 0 or index >= PartyManager.party_members.size():
		info_label.text = ""
		return

	var character: CharacterData = PartyManager.party_members[index]
	var save_data: CharacterSaveData = get_character_save_data(character.character_uid)

	if save_data:
		var class_data: ClassData = save_data.get_current_class(character)
		var class_display: String = class_data.display_name if class_data else save_data.fallback_class_name
		info_label.text = "Lv%d %s" % [save_data.level, class_display]
	else:
		info_label.text = ""


func _on_depot_focus_entered() -> void:
	info_label.text = "Access Caravan Depot"
	play_sfx("cursor_move")


func _on_back_focus_entered() -> void:
	info_label.text = "Close Members menu"
	play_sfx("cursor_move")


func _on_depot_pressed() -> void:
	# Go to depot browser (reuses Caravan's screen)
	if context:
		context.set_browse_mode()
	play_sfx("menu_select")
	push_screen("depot_browser")


func _on_back_pressed() -> void:
	go_back()


func _on_screen_exit() -> void:
	if is_instance_valid(depot_button) and depot_button.pressed.is_connected(_on_depot_pressed):
		depot_button.pressed.disconnect(_on_depot_pressed)
	if is_instance_valid(back_button) and back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.disconnect(_on_back_pressed)

	for i: int in range(char_buttons.size()):
		var btn: Button = char_buttons[i]
		if not is_instance_valid(btn):
			continue
		if btn.pressed.is_connected(_on_char_pressed):
			btn.pressed.disconnect(_on_char_pressed.bind(i))
		if btn.focus_entered.is_connected(_on_char_focus_entered):
			btn.focus_entered.disconnect(_on_char_focus_entered.bind(i))
