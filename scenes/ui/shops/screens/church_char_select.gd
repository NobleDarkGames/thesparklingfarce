extends "res://scenes/ui/shops/screens/shop_screen_base.gd"

## ChurchCharSelect - Character selection for church services
##
## Shows party members filtered by service type:
## - HEAL: wounded members (current_hp < max_hp OR current_mp < max_mp)
## - REVIVE: dead members (is_alive == false)
## - UNCURSE: members with cursed equipment

## Colors matching project standards
const COLOR_DISABLED: Color = Color(0.4, 0.4, 0.4, 1.0)
const COLOR_NORMAL: Color = Color(0.8, 0.8, 0.8, 1.0)
const COLOR_SELECTED: Color = Color(1.0, 1.0, 0.3, 1.0)

var character_buttons: Array[Button] = []
var selected_index: int = 0

@onready var header_label: Label = %HeaderLabel
@onready var character_grid: GridContainer = %CharacterGrid
@onready var back_button: Button = %BackButton
@onready var empty_label: Label = %EmptyLabel


func _on_initialized() -> void:
	_update_header()
	_populate_character_grid()

	back_button.pressed.connect(_on_back_pressed)

	await get_tree().process_frame
	if character_buttons.size() > 0:
		character_buttons[0].grab_focus()
		selected_index = 0
	else:
		back_button.grab_focus()


func _update_header() -> void:
	match context.mode:
		ShopContextScript.Mode.HEAL:
			header_label.text = "WHO SHALL BE HEALED?"
		ShopContextScript.Mode.REVIVE:
			header_label.text = "WHO SHALL BE REVIVED?"
		ShopContextScript.Mode.UNCURSE:
			header_label.text = "WHO BEARS A CURSED ITEM?"
		_:
			header_label.text = "SELECT CHARACTER"


func _populate_character_grid() -> void:
	# Clear existing
	for child: Node in character_grid.get_children():
		child.queue_free()
	character_buttons.clear()

	if not PartyManager:
		return

	var any_valid: bool = false
	for character: CharacterData in PartyManager.party_members:
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(character.character_uid)
		if not save_data:
			continue

		# Check if this character should be shown based on mode
		if not _should_show_character(save_data):
			continue

		var button: Button = _create_character_button(character, save_data)
		character_grid.add_child(button)
		character_buttons.append(button)

		var uid: String = character.character_uid
		button.pressed.connect(_on_character_selected.bind(uid))
		button.focus_entered.connect(_on_button_focus_entered.bind(button))
		button.focus_exited.connect(_on_button_focus_exited.bind(button))
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
		any_valid = true

	# Show empty message if no valid characters
	empty_label.visible = not any_valid
	if not any_valid:
		match context.mode:
			ShopContextScript.Mode.HEAL:
				empty_label.text = "All party members are at full health."
			ShopContextScript.Mode.REVIVE:
				empty_label.text = "No fallen party members."
			ShopContextScript.Mode.UNCURSE:
				empty_label.text = "No one bears cursed equipment."


func _should_show_character(save_data: CharacterSaveData) -> bool:
	match context.mode:
		ShopContextScript.Mode.HEAL:
			# Show if wounded (HP or MP not full)
			return save_data.is_alive and (save_data.current_hp < save_data.max_hp or save_data.current_mp < save_data.max_mp)
		ShopContextScript.Mode.REVIVE:
			# Show if dead
			return not save_data.is_alive
		ShopContextScript.Mode.UNCURSE:
			# Show if has any cursed equipment
			return _has_cursed_equipment(save_data)
		_:
			return false


func _has_cursed_equipment(save_data: CharacterSaveData) -> bool:
	for entry: Dictionary in save_data.equipped_items:
		var slot: String = DictUtils.get_string(entry, "slot", "")
		if not slot.is_empty() and EquipmentManager.is_slot_cursed(save_data, slot):
			return true
	return false


func _get_cursed_slots(save_data: CharacterSaveData) -> Array[String]:
	var cursed: Array[String] = []
	for entry: Dictionary in save_data.equipped_items:
		var slot: String = DictUtils.get_string(entry, "slot", "")
		if not slot.is_empty() and EquipmentManager.is_slot_cursed(save_data, slot):
			cursed.append(slot)
	return cursed


func _create_character_button(character: CharacterData, save_data: CharacterSaveData) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(180, 60)
	button.focus_mode = Control.FOCUS_ALL

	var cost: int = _get_service_cost(save_data)
	var can_afford: bool = _get_gold() >= cost

	var status_line: String = ""
	match context.mode:
		ShopContextScript.Mode.HEAL:
			status_line = "HP: %d/%d  MP: %d/%d" % [save_data.current_hp, save_data.max_hp, save_data.current_mp, save_data.max_mp]
		ShopContextScript.Mode.REVIVE:
			status_line = "FALLEN"
		ShopContextScript.Mode.UNCURSE:
			var cursed_slots: Array[String] = _get_cursed_slots(save_data)
			status_line = "Cursed: %s" % ", ".join(cursed_slots)

	button.text = "%s\n%s\n%d G" % [character.character_name, status_line, cost]

	if not can_afford:
		button.disabled = true
		button.add_theme_color_override("font_color", COLOR_DISABLED)

	return button


func _get_service_cost(save_data: CharacterSaveData) -> int:
	match context.mode:
		ShopContextScript.Mode.HEAL:
			return context.shop.heal_cost
		ShopContextScript.Mode.REVIVE:
			return context.shop.get_revival_cost(save_data.level)
		ShopContextScript.Mode.UNCURSE:
			return context.shop.uncurse_base_cost
		_:
			return 0


func _get_gold() -> int:
	if context and context.save_data:
		return context.save_data.gold
	return 0


func _on_character_selected(character_uid: String) -> void:
	match context.mode:
		ShopContextScript.Mode.HEAL:
			_perform_heal(character_uid)
		ShopContextScript.Mode.REVIVE:
			_perform_revive(character_uid)
		ShopContextScript.Mode.UNCURSE:
			_start_uncurse(character_uid)


func _perform_heal(character_uid: String) -> void:
	var result: Dictionary = ShopManager.church_heal(character_uid)
	if result.get("success", false):
		context.last_result = {
			"success": true,
			"message": "HP and MP fully restored!",
			"gold_spent": result.get("cost", 0)
		}
		push_screen("transaction_result")
	else:
		# Show error (could push to a result screen or just print)
		print("[ChurchCharSelect] Heal failed: %s" % result.get("error", "Unknown error"))


func _perform_revive(character_uid: String) -> void:
	var result: Dictionary = ShopManager.church_revive(character_uid)
	if result.get("success", false):
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(character_uid)
		var hp_msg: String = "HP: %d" % save_data.current_hp if save_data else "HP restored"
		context.last_result = {
			"success": true,
			"message": "Character has been revived!\n%s" % hp_msg,
			"gold_spent": result.get("cost", 0)
		}
		push_screen("transaction_result")
	else:
		print("[ChurchCharSelect] Revive failed: %s" % result.get("error", "Unknown error"))


func _start_uncurse(character_uid: String) -> void:
	# Store selected character for slot selection
	context.selected_destination = character_uid
	push_screen("church_slot_select")


func _on_button_focus_entered(btn: Button) -> void:
	selected_index = character_buttons.find(btn)
	_update_all_colors()


func _on_button_focus_exited(btn: Button) -> void:
	_update_all_colors()


func _on_button_mouse_entered(btn: Button) -> void:
	btn.grab_focus()


func _update_all_colors() -> void:
	for i: int in range(character_buttons.size()):
		var btn: Button = character_buttons[i]
		if btn.disabled:
			continue
		if i == selected_index and btn.has_focus():
			btn.add_theme_color_override("font_color", COLOR_SELECTED)
		else:
			btn.add_theme_color_override("font_color", COLOR_NORMAL)


func _on_back_pressed() -> void:
	go_back()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Keyboard navigation for grid
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		# Let the grid handle it naturally
		pass
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		# Let the grid handle it naturally
		pass


func _on_screen_exit() -> void:
	# Disconnect signals
	if is_instance_valid(back_button) and back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.disconnect(_on_back_pressed)

	for btn: Button in character_buttons:
		if not is_instance_valid(btn):
			continue
		# Buttons are freed when grid children are freed, so just clear references
	character_buttons.clear()
