extends "res://scenes/ui/shops/screens/shop_screen_base.gd"

## ChurchSaveConfirm - Save game slot selection screen
##
## Displays 3 save slots with metadata preview.
## Confirms overwrite for occupied slots.
## SF-style "Record your adventure" at the church.

## Menu items array for keyboard navigation
var menu_items: Array[Button] = []
var selected_index: int = 0

## Confirmation state
var _awaiting_confirmation: bool = false
var _pending_slot: int = -1

@onready var title_label: Label = %TitleLabel
@onready var slot_1_button: Button = %Slot1Button
@onready var slot_2_button: Button = %Slot2Button
@onready var slot_3_button: Button = %Slot3Button
@onready var back_button: Button = %BackButton
@onready var info_label: Label = %InfoLabel
@onready var confirm_panel: PanelContainer = %ConfirmPanel
@onready var confirm_label: Label = %ConfirmLabel
@onready var confirm_yes_button: Button = %ConfirmYesButton
@onready var confirm_no_button: Button = %ConfirmNoButton


func _on_initialized() -> void:
	# Build menu items array
	menu_items.clear()
	menu_items.append(slot_1_button)
	menu_items.append(slot_2_button)
	menu_items.append(slot_3_button)
	menu_items.append(back_button)

	# Connect slot button signals
	slot_1_button.pressed.connect(_on_slot_pressed.bind(1))
	slot_2_button.pressed.connect(_on_slot_pressed.bind(2))
	slot_3_button.pressed.connect(_on_slot_pressed.bind(3))
	back_button.pressed.connect(_on_back_pressed)

	# Connect confirmation buttons
	confirm_yes_button.pressed.connect(_on_confirm_yes)
	confirm_no_button.pressed.connect(_on_confirm_no)

	# Connect focus signals for visual feedback
	for btn: Button in menu_items:
		btn.focus_entered.connect(_on_button_focus_entered.bind(btn))
		btn.focus_exited.connect(_on_button_focus_exited.bind(btn))
		btn.mouse_entered.connect(_on_button_mouse_entered.bind(btn))

	# Hide confirmation panel initially
	confirm_panel.visible = false

	# Refresh slot display
	_refresh_slot_display()

	# Initialize colors
	_update_all_colors()

	# Grab focus on first button
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	if menu_items.size() > 0 and is_instance_valid(menu_items[0]):
		menu_items[0].grab_focus()
		selected_index = 0


func _refresh_slot_display() -> void:
	var slot_buttons: Array[Button] = [slot_1_button, slot_2_button, slot_3_button]

	for i: int in range(SaveManager.MAX_SLOTS):
		var metadata: SlotMetadata = SaveManager.get_slot_metadata(i + 1)
		var btn: Button = slot_buttons[i]

		if metadata and metadata.is_occupied:
			var playtime: String = metadata.get_playtime_string()
			btn.text = "Slot %d: %s Lv.%d (%s)" % [
				i + 1,
				metadata.party_leader_name,
				metadata.average_level,
				playtime
			]
			btn.add_theme_color_override("font_color", UIColors.MENU_NORMAL)
		else:
			btn.text = "Slot %d: Empty" % (i + 1)
			btn.add_theme_color_override("font_color", UIColors.ITEM_EMPTY)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# If confirmation dialog is open, only handle confirmation input
	if _awaiting_confirmation:
		if event.is_action_pressed("ui_cancel"):
			_on_confirm_no()
			get_viewport().set_input_as_handled()
		return

	# Keyboard navigation
	if event.is_action_pressed("ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _move_selection(delta: int) -> void:
	if menu_items.is_empty():
		return

	selected_index += delta

	# Wrap around
	if selected_index < 0:
		selected_index = menu_items.size() - 1
	elif selected_index >= menu_items.size():
		selected_index = 0

	menu_items[selected_index].grab_focus()


func _on_button_focus_entered(btn: Button) -> void:
	selected_index = menu_items.find(btn)
	_update_all_colors()
	_update_info_for_slot(selected_index)


func _on_button_focus_exited(_btn: Button) -> void:
	_update_all_colors()


func _on_button_mouse_entered(btn: Button) -> void:
	btn.grab_focus()


func _update_all_colors() -> void:
	for i: int in range(menu_items.size()):
		var btn: Button = menu_items[i]
		if i == selected_index and btn.has_focus():
			btn.add_theme_color_override("font_focus_color", UIColors.MENU_SELECTED)
		else:
			btn.add_theme_color_override("font_focus_color", UIColors.MENU_NORMAL)


func _update_info_for_slot(slot_idx: int) -> void:
	if slot_idx >= 3:
		info_label.text = "Return to the church menu."
		return

	var metadata: SlotMetadata = SaveManager.get_slot_metadata(slot_idx + 1)
	if metadata and metadata.is_occupied:
		var last_played: String = metadata.get_last_played_string()
		info_label.text = "Last saved: %s\nLocation: %s" % [last_played, metadata.current_location]
	else:
		info_label.text = "This slot is empty.\nSave your adventure here."


func _on_slot_pressed(slot_number: int) -> void:
	var metadata: SlotMetadata = SaveManager.get_slot_metadata(slot_number)

	if metadata and metadata.is_occupied:
		# Show confirmation dialog for overwrite
		_show_overwrite_confirmation(slot_number, metadata)
	else:
		# Empty slot - save directly
		_execute_save(slot_number)


func _show_overwrite_confirmation(slot_number: int, metadata: SlotMetadata) -> void:
	_awaiting_confirmation = true
	_pending_slot = slot_number

	confirm_label.text = "Overwrite %s (Lv.%d)?" % [
		metadata.party_leader_name,
		metadata.average_level
	]
	confirm_panel.visible = true
	confirm_yes_button.grab_focus()


func _on_confirm_yes() -> void:
	var slot: int = _pending_slot
	_hide_confirmation()
	_execute_save(slot)


func _on_confirm_no() -> void:
	_hide_confirmation()
	# Return focus to the slot button
	if _pending_slot > 0 and _pending_slot <= 3:
		menu_items[_pending_slot - 1].grab_focus()


func _hide_confirmation() -> void:
	_awaiting_confirmation = false
	_pending_slot = -1
	confirm_panel.visible = false


func _execute_save(slot_number: int) -> void:
	# Check if current_save exists
	if not SaveManager.current_save:
		push_error("ChurchSaveConfirm: No current_save set - cannot save")
		info_label.text = "Save error: No active game session."
		return

	# Sync all runtime state to SaveData before saving
	SaveManager.sync_current_save_state()

	# Update location and scene info in save data
	SaveManager.current_save.current_location = "Church"
	# Capture current scene path for loading
	var current_scene: Node = get_tree().current_scene
	if current_scene:
		SaveManager.current_save.current_scene_path = current_scene.scene_file_path

	# Capture player's exact position and facing for respawn
	var hero: Node = get_tree().get_first_node_in_group("hero")
	if hero and hero.has_method("get_grid_position"):
		SaveManager.current_save.player_grid_position = hero.get_grid_position()
		if hero.has_method("get_facing"):
			SaveManager.current_save.player_facing = hero.get_facing()
		elif "facing" in hero:
			SaveManager.current_save.player_facing = hero.facing
	else:
		# Fallback to spawn point system
		SaveManager.current_save.player_grid_position = Vector2i(-1, -1)
		SaveManager.current_save.player_facing = ""

	SaveManager.current_save.current_spawn_point = ""

	# Perform the save
	var success: bool = SaveManager.save_to_slot(slot_number, SaveManager.current_save)

	if success:
		info_label.text = "Your adventure has been recorded."
		# Refresh display to show updated slot
		_refresh_slot_display()
	else:
		info_label.text = "Failed to save. Please try again."

	# Return focus to the saved slot
	if slot_number > 0 and slot_number <= 3:
		menu_items[slot_number - 1].grab_focus()


func _on_back_pressed() -> void:
	go_back()


## Override back behavior
func _on_back_requested() -> void:
	if _awaiting_confirmation:
		_on_confirm_no()
	else:
		_on_back_pressed()


## Clean up signal connections when exiting screen
func _on_screen_exit() -> void:
	# Disconnect slot buttons
	var slot_buttons: Array[Button] = [slot_1_button, slot_2_button, slot_3_button]
	for btn: Button in slot_buttons:
		_disconnect_if_connected(btn, "pressed", _on_slot_pressed)

	_disconnect_if_connected(back_button, "pressed", _on_back_pressed)
	_disconnect_if_connected(confirm_yes_button, "pressed", _on_confirm_yes)
	_disconnect_if_connected(confirm_no_button, "pressed", _on_confirm_no)

	for btn: Button in menu_items:
		if not is_instance_valid(btn):
			continue
		_disconnect_if_connected(btn, "focus_entered", _on_button_focus_entered)
		_disconnect_if_connected(btn, "focus_exited", _on_button_focus_exited)
		_disconnect_if_connected(btn, "mouse_entered", _on_button_mouse_entered)


## Helper to safely disconnect a signal
func _disconnect_if_connected(node: Node, signal_name: String, callable: Callable) -> void:
	if not is_instance_valid(node):
		return
	if node.is_connected(signal_name, callable):
		node.disconnect(signal_name, callable)
