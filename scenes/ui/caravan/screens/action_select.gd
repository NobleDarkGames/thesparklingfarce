extends "res://scenes/ui/caravan/screens/caravan_screen_base.gd"

## ActionSelect - Main menu screen for caravan depot
##
## Displays available actions: Take (from depot), Store (to depot), Exit
## Matches SF2's GIVE/GET pattern with modern navigation.

## Menu items array for keyboard navigation
var menu_items: Array[Button] = []
var selected_index: int = 0

@onready var take_button: Button = %TakeButton
@onready var store_button: Button = %StoreButton
@onready var exit_button: Button = %ExitButton
@onready var description_label: Label = %DescriptionLabel


func _on_initialized() -> void:
	# Build menu items array
	menu_items.clear()
	menu_items.append(take_button)
	menu_items.append(store_button)
	menu_items.append(exit_button)

	# Connect button signals
	take_button.pressed.connect(_on_take_pressed)
	store_button.pressed.connect(_on_store_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	# Connect focus signals for visual feedback
	for btn: Button in menu_items:
		btn.focus_entered.connect(_on_button_focus_entered.bind(btn))
		btn.focus_exited.connect(_on_button_focus_exited.bind(btn))
		btn.mouse_entered.connect(_on_button_mouse_entered.bind(btn))

	# Initialize colors
	_update_all_colors()

	# Update description for first item
	_update_description(0)

	# Disable store if no party members
	if not PartyManager or PartyManager.party_members.is_empty():
		store_button.disabled = true

	# Disable take if depot is empty
	if get_depot_size() == 0:
		take_button.disabled = true

	# Grab focus on first enabled button
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	_focus_first_enabled()


func _focus_first_enabled() -> void:
	for i: int in range(menu_items.size()):
		var btn: Button = menu_items[i]
		if is_instance_valid(btn) and not btn.disabled:
			btn.grab_focus()
			selected_index = i
			return
	# Fallback to exit if everything else is disabled
	if is_instance_valid(exit_button):
		exit_button.grab_focus()
		selected_index = menu_items.find(exit_button)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Keyboard navigation
	if event.is_action_pressed("ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()


func _move_selection(delta: int) -> void:
	if menu_items.is_empty():
		return

	var new_index: int = selected_index
	var attempts: int = 0

	# Find next non-disabled button
	while attempts < menu_items.size():
		new_index += delta
		# Wrap around
		if new_index < 0:
			new_index = menu_items.size() - 1
		elif new_index >= menu_items.size():
			new_index = 0

		var btn: Button = menu_items[new_index]
		if not btn.disabled:
			break
		attempts += 1

	if new_index != selected_index:
		selected_index = new_index
		menu_items[selected_index].grab_focus()


func _on_button_focus_entered(btn: Button) -> void:
	selected_index = menu_items.find(btn)
	_update_all_colors()
	_update_description(selected_index)
	play_sfx("cursor_move")


func _on_button_focus_exited(_btn: Button) -> void:
	_update_all_colors()


func _on_button_mouse_entered(btn: Button) -> void:
	if not btn.disabled:
		btn.grab_focus()


func _update_all_colors() -> void:
	for i: int in range(menu_items.size()):
		var btn: Button = menu_items[i]
		if btn.disabled:
			btn.add_theme_color_override("font_color", UIColors.MENU_DISABLED)
			btn.add_theme_color_override("font_hover_color", UIColors.MENU_DISABLED)
			btn.add_theme_color_override("font_focus_color", UIColors.MENU_DISABLED)
		elif i == selected_index and btn.has_focus():
			btn.add_theme_color_override("font_color", UIColors.MENU_SELECTED)
			btn.add_theme_color_override("font_hover_color", UIColors.MENU_SELECTED)
			btn.add_theme_color_override("font_focus_color", UIColors.MENU_SELECTED)
		else:
			btn.add_theme_color_override("font_color", UIColors.MENU_NORMAL)
			btn.add_theme_color_override("font_hover_color", UIColors.MENU_SELECTED)
			btn.add_theme_color_override("font_focus_color", UIColors.MENU_SELECTED)


func _update_description(index: int) -> void:
	if not description_label:
		return

	match index:
		0:  # Take
			var count: int = get_depot_size()
			if count == 0:
				description_label.text = "Depot is empty"
			else:
				description_label.text = "Take items from depot (%d stored)" % count
		1:  # Store
			if not PartyManager or PartyManager.party_members.is_empty():
				description_label.text = "No party members"
			else:
				description_label.text = "Store items in depot"
		2:  # Exit
			description_label.text = "Close the depot"
		_:
			description_label.text = ""


func _on_take_pressed() -> void:
	if context:
		context.set_take_mode()
	play_sfx("menu_select")
	push_screen("depot_browser")


func _on_store_pressed() -> void:
	if context:
		context.set_store_mode()
	play_sfx("menu_select")
	push_screen("char_select")


func _on_exit_pressed() -> void:
	_do_exit()


## Override back behavior - same as exit
func _on_back_requested() -> void:
	_do_exit()


func _do_exit() -> void:
	play_sfx("menu_cancel")
	close_interface()


## Clean up signal connections when exiting screen
func _on_screen_exit() -> void:
	# Disconnect button signals to prevent stale references
	if is_instance_valid(take_button) and take_button.pressed.is_connected(_on_take_pressed):
		take_button.pressed.disconnect(_on_take_pressed)
	if is_instance_valid(store_button) and store_button.pressed.is_connected(_on_store_pressed):
		store_button.pressed.disconnect(_on_store_pressed)
	if is_instance_valid(exit_button) and exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.disconnect(_on_exit_pressed)

	# Disconnect focus/mouse signals
	for btn: Button in menu_items:
		if not is_instance_valid(btn):
			continue
		if btn.focus_entered.is_connected(_on_button_focus_entered):
			btn.focus_entered.disconnect(_on_button_focus_entered)
		if btn.focus_exited.is_connected(_on_button_focus_exited):
			btn.focus_exited.disconnect(_on_button_focus_exited)
		if btn.mouse_entered.is_connected(_on_button_mouse_entered):
			btn.mouse_entered.disconnect(_on_button_mouse_entered)
