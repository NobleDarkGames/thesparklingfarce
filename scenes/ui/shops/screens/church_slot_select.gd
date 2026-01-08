extends "res://scenes/ui/shops/screens/shop_screen_base.gd"

## ChurchSlotSelect - Slot selection for uncurse service
##
## Shows cursed equipment slots for the selected character.
## Selecting a slot performs the uncurse service.

## Colors matching project standards
const COLOR_DISABLED: Color = Color(0.4, 0.4, 0.4, 1.0)
const COLOR_NORMAL: Color = Color(0.8, 0.8, 0.8, 1.0)
const COLOR_SELECTED: Color = Color(1.0, 1.0, 0.3, 1.0)

var slot_buttons: Array[Button] = []
var selected_index: int = 0

@onready var header_label: Label = %HeaderLabel
@onready var slot_grid: GridContainer = %SlotGrid
@onready var back_button: Button = %BackButton


func _on_initialized() -> void:
	_update_header()
	_populate_slot_grid()

	back_button.pressed.connect(_on_back_pressed)

	await get_tree().process_frame
	if slot_buttons.size() > 0:
		slot_buttons[0].grab_focus()
		selected_index = 0
	else:
		back_button.grab_focus()


func _update_header() -> void:
	var character_uid: String = context.selected_destination
	var character: CharacterData = _get_character_data(character_uid)
	var name: String = character.character_name if character else "Character"
	header_label.text = "WHICH ITEM TO UNCURSE?\n(%s)" % name


func _get_character_data(character_uid: String) -> CharacterData:
	if not PartyManager:
		return null
	for character: CharacterData in PartyManager.party_members:
		if character.character_uid == character_uid:
			return character
	return null


func _populate_slot_grid() -> void:
	# Clear existing
	for child: Node in slot_grid.get_children():
		child.queue_free()
	slot_buttons.clear()

	var character_uid: String = context.selected_destination
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(character_uid)
	if not save_data:
		return

	var cost: int = context.shop.uncurse_base_cost
	var can_afford: bool = _get_gold() >= cost

	for entry: Dictionary in save_data.equipped_items:
		var slot: String = DictUtils.get_string(entry, "slot", "")
		if slot.is_empty():
			continue
		if not EquipmentManager.is_slot_cursed(save_data, slot):
			continue

		var item_id: String = DictUtils.get_string(entry, "item_id", "")
		var item: ItemData = ModLoader.registry.get_item(item_id)
		var item_name: String = item.item_name if item else item_id

		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(200, 50)
		button.focus_mode = Control.FOCUS_ALL
		button.text = "%s\n%s - %d G" % [slot.capitalize(), item_name, cost]

		if not can_afford:
			button.disabled = true
			button.add_theme_color_override("font_color", COLOR_DISABLED)

		slot_grid.add_child(button)
		slot_buttons.append(button)

		button.pressed.connect(_on_slot_selected.bind(slot))
		button.focus_entered.connect(_on_button_focus_entered.bind(button))
		button.focus_exited.connect(_on_button_focus_exited.bind(button))
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))


func _get_gold() -> int:
	if context and context.save_data:
		return context.save_data.gold
	return 0


func _on_slot_selected(slot_id: String) -> void:
	var character_uid: String = context.selected_destination
	var result: Dictionary = ShopManager.church_uncurse(character_uid, slot_id)

	if result.get("success", false):
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(character_uid)
		var item_id: String = EquipmentManager.get_equipped_item_id(save_data, slot_id) if save_data else ""
		var item: ItemData = ModLoader.registry.get_item(item_id) if item_id else null
		var item_name: String = item.item_name if item else "the item"

		context.last_result = {
			"success": true,
			"message": "The curse has been lifted from %s!" % item_name,
			"gold_spent": result.get("cost", 0)
		}
		push_screen("transaction_result")
	else:
		context.last_result = {
			"success": false,
			"message": result.get("error", "Uncurse failed")
		}
		push_screen("transaction_result")


func _on_button_focus_entered(btn: Button) -> void:
	selected_index = slot_buttons.find(btn)
	_update_all_colors()


func _on_button_focus_exited(btn: Button) -> void:
	_update_all_colors()


func _on_button_mouse_entered(btn: Button) -> void:
	btn.grab_focus()


func _update_all_colors() -> void:
	for i: int in range(slot_buttons.size()):
		var btn: Button = slot_buttons[i]
		if btn.disabled:
			continue
		if i == selected_index and btn.has_focus():
			btn.add_theme_color_override("font_color", COLOR_SELECTED)
		else:
			btn.add_theme_color_override("font_color", COLOR_NORMAL)


func _on_back_pressed() -> void:
	go_back()


func _on_screen_exit() -> void:
	if is_instance_valid(back_button) and back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.disconnect(_on_back_pressed)
	slot_buttons.clear()
