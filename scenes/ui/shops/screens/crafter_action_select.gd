extends "res://scenes/ui/shops/screens/shop_screen_base.gd"

## CrafterActionSelect - Main menu screen for crafter services
##
## Displays available actions: Forge and Exit
## Uses ActionMenu-style patterns for consistent UI behavior.

# Game Juice: Hover brightness boost
const HOVER_BRIGHTNESS: float = 1.1
const HOVER_TWEEN_DURATION: float = 0.1

## Menu items array for keyboard navigation
var menu_items: Array[Button] = []
var selected_index: int = 0

@onready var forge_button: Button = %ForgeButton
@onready var exit_button: Button = %ExitButton


func _on_initialized() -> void:
	# Build menu items array
	menu_items.clear()
	menu_items.append(forge_button)
	menu_items.append(exit_button)

	# Connect button signals
	forge_button.pressed.connect(_on_forge_pressed)
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
	_tween_button_brightness(btn, HOVER_BRIGHTNESS)


func _on_button_focus_exited(btn: Button) -> void:
	_update_all_colors()
	_tween_button_brightness(btn, 1.0)


func _on_button_mouse_entered(btn: Button) -> void:
	btn.grab_focus()


## Tween button modulate brightness for hover feedback
func _tween_button_brightness(btn: Button, brightness: float) -> void:
	if not is_instance_valid(btn):
		return
	var duration: float = GameJuice.get_adjusted_duration(HOVER_TWEEN_DURATION)
	var tween: Tween = btn.create_tween()
	tween.tween_property(btn, "modulate", Color(brightness, brightness, brightness), duration)


func _update_all_colors() -> void:
	for i: int in range(menu_items.size()):
		var btn: Button = menu_items[i]
		if i == selected_index and btn.has_focus():
			btn.add_theme_color_override("font_color", UIColors.MENU_SELECTED)
			btn.add_theme_color_override("font_hover_color", UIColors.MENU_SELECTED)
			btn.add_theme_color_override("font_focus_color", UIColors.MENU_SELECTED)
		else:
			btn.add_theme_color_override("font_color", UIColors.MENU_NORMAL)
			btn.add_theme_color_override("font_hover_color", UIColors.MENU_SELECTED)
			btn.add_theme_color_override("font_focus_color", UIColors.MENU_SELECTED)


func _on_forge_pressed() -> void:
	context.mode = ShopContextScript.Mode.CRAFT
	push_screen("crafter_recipe_browser")


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
	if is_instance_valid(forge_button) and forge_button.pressed.is_connected(_on_forge_pressed):
		forge_button.pressed.disconnect(_on_forge_pressed)
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
