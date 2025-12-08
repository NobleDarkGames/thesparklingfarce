extends "res://scenes/ui/shops/screens/shop_screen_base.gd"

## PlacementMode - Distribute queued items to characters (PAY-PER-PLACEMENT)

## Colors matching project standards
const COLOR_ERROR: Color = Color(1.0, 0.4, 0.4, 1.0)  # Soft red for errors
##
## This is the core of Captain's Rule #2: "Gold is charged per placement, not upfront."
## - Each click on a character places ONE item and charges ONE item's gold
## - Clicking Caravan places ALL remaining items and charges for all
## - Cancel clears remaining queue (no refund needed - never charged)

signal item_placed(item_id: String, target_uid: String, cost: int)
signal placement_complete(total_placed: int, total_spent: int)
signal placement_cancelled(placed_count: int, cancelled_count: int)

## Tracks how many items placed and gold spent this session
var _placed_count: int = 0
var _total_spent: int = 0

var character_buttons: Array[Button] = []

@onready var current_item_label: Label = %CurrentItemLabel
@onready var remaining_label: Label = %RemainingLabel
@onready var gold_label: Label = %GoldLabel
@onready var cost_per_label: Label = %CostPerLabel
@onready var character_grid: GridContainer = %CharacterGrid
@onready var caravan_button: Button = %CaravanButton
@onready var cancel_button: Button = %CancelButton


func _on_initialized() -> void:
	_placed_count = 0
	_total_spent = 0

	_setup_character_buttons()
	_setup_caravan_button()
	_update_display()

	cancel_button.pressed.connect(_on_cancel_pressed)


func _setup_character_buttons() -> void:
	# Clear existing
	for child in character_grid.get_children():
		child.queue_free()
	character_buttons.clear()

	if not PartyManager:
		return

	for character: CharacterData in PartyManager.party_members:
		var btn: Button = _create_character_button(character)
		character_grid.add_child(btn)
		character_buttons.append(btn)

		var uid: String = character.character_uid
		btn.pressed.connect(_on_character_clicked.bind(uid))


func _create_character_button(character: CharacterData) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(110, 50)  # Compact size for low-res screens
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", 16)  # Monogram requires 16 or 24

	# Get inventory status
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(character.character_uid)
	var slots_used: int = save_data.inventory.size() if save_data else 0
	var slots_max: int = 4  # Default max inventory

	if slots_used >= slots_max:
		btn.disabled = true
		btn.text = "%s\nFULL" % character.character_name
	else:
		# Compact: just name and slots (instructions explain what clicking does)
		btn.text = "%s\n(%d/%d)" % [character.character_name, slots_used, slots_max]

	return btn


func _setup_caravan_button() -> void:
	caravan_button.visible = StorageManager.is_caravan_available()
	if caravan_button.visible:
		_update_caravan_button()
		caravan_button.pressed.connect(_on_caravan_clicked)


func _update_caravan_button() -> void:
	var remaining: int = context.queue.get_total_item_count()
	var total_cost: int = context.queue.get_total_cost()

	if remaining == 0:
		caravan_button.disabled = true
		caravan_button.text = "CARAVAN (empty)"
	elif remaining == 1:
		var first_item: RefCounted = context.queue.get_first_item()
		caravan_button.text = "CARAVAN: 1 → -%dG" % first_item.unit_price
	else:
		caravan_button.text = "CARAVAN: %d → -%dG" % [remaining, total_cost]


func _update_display() -> void:
	var first_item: RefCounted = context.queue.get_first_item()

	if not first_item:
		# Queue empty - placement complete
		_finish_placement()
		return

	var item_data: ItemData = get_item_data(first_item.item_id)
	var item_name: String = item_data.item_name if item_data else first_item.item_id
	var remaining: int = context.queue.get_total_item_count()

	current_item_label.text = "PLACING: %s" % item_name
	remaining_label.text = "(%d left)" % remaining
	gold_label.text = "GOLD: %dG" % get_current_gold()
	cost_per_label.text = "-%dG each" % first_item.unit_price

	_update_caravan_button()
	_refresh_character_buttons()
	update_gold_display()


func _refresh_character_buttons() -> void:
	if not PartyManager:
		return

	var idx: int = 0
	for character: CharacterData in PartyManager.party_members:
		if idx >= character_buttons.size():
			break

		var btn: Button = character_buttons[idx]
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(character.character_uid)
		var slots_used: int = save_data.inventory.size() if save_data else 0
		var slots_max: int = 4

		if slots_used >= slots_max:
			btn.disabled = true
			btn.text = "%s\nFULL" % character.character_name
		else:
			btn.disabled = false
			btn.text = "%s\n(%d/%d)" % [character.character_name, slots_used, slots_max]

		idx += 1


func _on_character_clicked(character_uid: String) -> void:
	var first_item: RefCounted = context.queue.get_first_item()
	if not first_item:
		return

	# Execute single purchase via ShopManager
	var result: Dictionary = ShopManager.buy_item(
		first_item.item_id,
		1,
		character_uid
	)

	if result.success:
		# Remove from queue (already charged by ShopManager)
		context.queue.remove_one(first_item.item_id)

		_placed_count += 1
		_total_spent += first_item.unit_price

		item_placed.emit(first_item.item_id, character_uid, first_item.unit_price)

		_update_display()
	else:
		_show_error("Could not place item: %s" % result.error)


func _on_caravan_clicked() -> void:
	# Place ALL remaining items to Caravan
	var items_to_place: Array[RefCounted] = context.queue.get_all_items().duplicate()

	for queued: RefCounted in items_to_place:
		for i: int in range(queued.quantity):
			var result: Dictionary = ShopManager.buy_item(
				queued.item_id,
				1,
				"caravan"
			)

			if result.success:
				_placed_count += 1
				_total_spent += queued.unit_price
				item_placed.emit(queued.item_id, "caravan", queued.unit_price)

	# Clear queue (all items placed)
	context.queue.clear()

	_update_display()  # Will trigger _finish_placement since queue is empty


func _on_cancel_pressed() -> void:
	var remaining: int = context.queue.get_total_item_count()

	if remaining > 0:
		# Show confirmation dialog
		var dialog: ConfirmationDialog = ConfirmationDialog.new()
		dialog.dialog_text = "Cancel placement?\n\n%d items placed (%dG spent)\n%d items will return to shop" % [
			_placed_count, _total_spent, remaining
		]
		dialog.confirmed.connect(func() -> void:
			_do_cancel()
			dialog.queue_free()
		)
		dialog.canceled.connect(func() -> void: dialog.queue_free())
		add_child(dialog)
		dialog.popup_centered()
	else:
		_finish_placement()


func _do_cancel() -> void:
	var cancelled_count: int = context.queue.get_total_item_count()
	context.queue.clear()

	placement_cancelled.emit(_placed_count, cancelled_count)

	# Store result for display
	context.set_result("placement_cancelled", {
		"placed_count": _placed_count,
		"cancelled_count": cancelled_count,
		"total_spent": _total_spent
	})

	replace_with("transaction_result")


func _finish_placement() -> void:
	placement_complete.emit(_placed_count, _total_spent)

	context.set_result("placement_complete", {
		"placed_count": _placed_count,
		"total_spent": _total_spent
	})

	replace_with("transaction_result")


func _show_error(message: String) -> void:
	# Brief error feedback
	var label: Label = Label.new()
	label.text = message
	label.add_theme_color_override("font_color", COLOR_ERROR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Position at bottom
	label.anchor_top = 0.9
	label.anchor_bottom = 1.0
	label.anchor_left = 0
	label.anchor_right = 1.0

	add_child(label)

	var tween: Tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(label.queue_free)


## Override back behavior - show cancel confirmation
func _on_back_requested() -> void:
	_on_cancel_pressed()
