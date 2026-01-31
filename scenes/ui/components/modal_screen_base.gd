extends Control

## ModalScreenBase - Shared base class for modal UI screens (Shops, Caravan, etc.)
##
## Provides common functionality for screen-based modal UI systems:
## - Controller/context reference management
## - Navigation helpers (push_screen, go_back, replace_with)
## - Input blocking to prevent game control leakage
## - Standard back button behavior
##
## Subclasses (ShopScreenBase, CaravanScreenBase) add domain-specific helpers.

## Reference to the owning controller (manages screen stack)
var controller: Node = null

## Reference to the shared context (stores session state)
var context: RefCounted = null

# =============================================================================
# LIFECYCLE
# =============================================================================

## Called by controller when screen is instantiated
## Subclasses should override _on_initialized() for setup
func initialize(p_controller: Node, p_context: RefCounted) -> void:
	controller = p_controller
	context = p_context
	_on_initialized()


## Override in subclasses for initialization logic
func _on_initialized() -> void:
	pass


## Called when screen is about to be removed
## Override for cleanup if needed
func _on_screen_exit() -> void:
	pass

# =============================================================================
# NAVIGATION HELPERS
# =============================================================================

## Navigate to a new screen (pushes current to history)
func push_screen(screen_name: String) -> void:
	if controller and controller.has_method("push_screen"):
		controller.push_screen(screen_name)


## Go back to the previous screen
func go_back() -> void:
	if controller and controller.has_method("pop_screen"):
		controller.pop_screen()


## Replace current screen without adding to history
func replace_with(screen_name: String) -> void:
	if controller and controller.has_method("replace_screen"):
		controller.replace_screen(screen_name)


## Close the entire modal interface - override in subclasses for specific method name
func _close_interface() -> void:
	if controller and controller.has_method("close_interface"):
		controller.close_interface()
	elif controller and controller.has_method("close_shop"):
		controller.close_shop()

# =============================================================================
# INPUT HANDLING
# =============================================================================

## Handle input - subclasses can override for specific behavior
func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Default: B/Cancel goes back
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel"):
		_on_back_requested()
		get_viewport().set_input_as_handled()


## Capture ALL unhandled input to prevent leaking to game controls
## This ensures movement keys, action buttons, etc. don't control the player
func _unhandled_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


## Override to handle back button behavior
## Default behavior is go_back()
func _on_back_requested() -> void:
	go_back()

# =============================================================================
# AUDIO HELPERS
# =============================================================================

## Play UI sound effect (common pattern across modal screens)
func play_sfx(sfx_name: String) -> void:
	if AudioManager:
		AudioManager.play_sfx(sfx_name, AudioManager.SFXCategory.UI)

# =============================================================================
# UI HELPERS
# =============================================================================

## Show result message with success/error styling
## Subclasses must have a result_label: Label node
func _show_result_on_label(label: Label, message: String, success: bool) -> void:
	label.text = message
	if success:
		label.add_theme_color_override("font_color", UIColors.RESULT_SUCCESS)
		if not message.is_empty():
			play_sfx("menu_confirm")
	else:
		label.add_theme_color_override("font_color", UIColors.RESULT_ERROR)
		if not message.is_empty():
			play_sfx("menu_error")


## Show warning message with warning styling
func _show_warning_on_label(label: Label, message: String) -> void:
	label.text = message
	label.add_theme_color_override("font_color", UIColors.RESULT_WARNING)
	play_sfx("menu_error")


## Focus first enabled button in a list of buttons
func _focus_first_in_list(buttons: Array[Button]) -> void:
	for btn: Button in buttons:
		if is_instance_valid(btn) and not btn.disabled:
			btn.grab_focus()
			return


## Clear all children from a container (for grid repopulation)
func _clear_container(container: Control) -> void:
	for child: Node in container.get_children():
		child.queue_free()

# =============================================================================
# CHARACTER LOOKUP
# =============================================================================

## Look up CharacterData by UID from party
func get_character_by_uid(uid: String) -> CharacterData:
	if not PartyManager:
		return null
	for character: CharacterData in PartyManager.party_members:
		if character.character_uid == uid:
			return character
	return null