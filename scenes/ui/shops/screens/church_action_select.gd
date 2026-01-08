extends "res://scenes/ui/shops/screens/shop_screen_base.gd"

## ChurchActionSelect - Main menu screen for church services
##
## Displays available services: Heal, Revive, Uncurse, Exit
## Uses ActionMenu-style patterns for consistent UI behavior.

## Colors matching ActionMenu standard
const COLOR_NORMAL: Color = Color(0.8, 0.8, 0.8, 1.0)
const COLOR_SELECTED: Color = Color(1.0, 1.0, 0.3, 1.0)  # Bright yellow (project standard)
const COLOR_DISABLED: Color = Color(0.4, 0.4, 0.4, 1.0)

## Menu items array for keyboard navigation
var menu_items: Array[Button] = []
var selected_index: int = 0

@onready var heal_button: Button = %HealButton
@onready var revive_button: Button = %ReviveButton
@onready var uncurse_button: Button = %UncurseButton
@onready var promote_button: Button = %PromoteButton
@onready var exit_button: Button = %ExitButton


func _on_initialized() -> void:
	# Build menu items array
	menu_items.clear()
	menu_items.append(heal_button)
	menu_items.append(revive_button)
	menu_items.append(uncurse_button)
	menu_items.append(promote_button)
	menu_items.append(exit_button)

	# Connect button signals
	heal_button.pressed.connect(_on_heal_pressed)
	revive_button.pressed.connect(_on_revive_pressed)
	uncurse_button.pressed.connect(_on_uncurse_pressed)
	promote_button.pressed.connect(_on_promote_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	# Connect focus signals for visual feedback
	for btn: Button in menu_items:
		btn.focus_entered.connect(_on_button_focus_entered.bind(btn))
		btn.focus_exited.connect(_on_button_focus_exited.bind(btn))
		btn.mouse_entered.connect(_on_button_mouse_entered.bind(btn))

	# Initialize colors
	_update_all_colors()

	# Grab focus on first button (with validity check after await)
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	if menu_items.size() > 0 and is_instance_valid(menu_items[0]):
		menu_items[0].grab_focus()
		selected_index = 0


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


func _on_button_focus_exited(btn: Button) -> void:
	_update_all_colors()


func _on_button_mouse_entered(btn: Button) -> void:
	btn.grab_focus()


func _update_all_colors() -> void:
	for i: int in range(menu_items.size()):
		var btn: Button = menu_items[i]
		if i == selected_index and btn.has_focus():
			btn.add_theme_color_override("font_color", COLOR_SELECTED)
			btn.add_theme_color_override("font_hover_color", COLOR_SELECTED)
			btn.add_theme_color_override("font_focus_color", COLOR_SELECTED)
		else:
			btn.add_theme_color_override("font_color", COLOR_NORMAL)
			btn.add_theme_color_override("font_hover_color", COLOR_SELECTED)
			btn.add_theme_color_override("font_focus_color", COLOR_SELECTED)


func _on_heal_pressed() -> void:
	context.mode = ShopContextScript.Mode.HEAL
	push_screen("church_char_select")


func _on_revive_pressed() -> void:
	context.mode = ShopContextScript.Mode.REVIVE
	push_screen("church_char_select")


func _on_uncurse_pressed() -> void:
	context.mode = ShopContextScript.Mode.UNCURSE
	push_screen("church_char_select")


func _on_promote_pressed() -> void:
	context.mode = ShopContextScript.Mode.PROMOTION
	push_screen("church_char_select")


func _on_exit_pressed() -> void:
	_do_exit()


## Override back behavior - same as exit
func _on_back_requested() -> void:
	_do_exit()


func _do_exit() -> void:
	# Just close - farewells are handled by the cinematic system
	close_shop()


## Clean up signal connections when exiting screen
func _on_screen_exit() -> void:
	# Disconnect button signals to prevent stale references
	if is_instance_valid(heal_button) and heal_button.pressed.is_connected(_on_heal_pressed):
		heal_button.pressed.disconnect(_on_heal_pressed)
	if is_instance_valid(revive_button) and revive_button.pressed.is_connected(_on_revive_pressed):
		revive_button.pressed.disconnect(_on_revive_pressed)
	if is_instance_valid(uncurse_button) and uncurse_button.pressed.is_connected(_on_uncurse_pressed):
		uncurse_button.pressed.disconnect(_on_uncurse_pressed)
	if is_instance_valid(promote_button) and promote_button.pressed.is_connected(_on_promote_pressed):
		promote_button.pressed.disconnect(_on_promote_pressed)
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
