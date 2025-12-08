extends Control

## ShopScreenBase - Base class for all shop screens
##
## Provides common functionality for screen lifecycle:
## - Access to ShopController and ShopContext
## - Navigation helpers (push_screen, go_back, replace_with)
## - Common UI patterns
##
## Note: class_name removed to avoid load order issues when used as autoload dependency

# Preload ShopContext for Mode enum access
const ShopContextScript: GDScript = preload("res://scenes/ui/shops/shop_context.gd")

## Reference to the owning controller
var controller: Node = null

## Reference to the shared context (actually ShopContext)
var context: RefCounted = null


## Called by controller when screen is instantiated
## Subclasses should override _on_initialized() for setup
func initialize(p_controller: Node, p_context: RefCounted) -> void:
	controller = p_controller
	context = p_context
	_on_initialized()


## Override in subclasses for initialization logic
func _on_initialized() -> void:
	pass


## Navigate to a new screen (pushes current to history)
func push_screen(screen_name: String) -> void:
	if controller:
		controller.push_screen(screen_name)


## Go back to the previous screen
func go_back() -> void:
	if controller:
		controller.pop_screen()


## Replace current screen without adding to history
func replace_with(screen_name: String) -> void:
	if controller:
		controller.replace_screen(screen_name)


## Request the controller to close the shop
func close_shop() -> void:
	if controller:
		controller.close_shop()


## Update the gold display in the controller
func update_gold_display() -> void:
	if controller:
		controller.update_gold_display()


## Show the queue panel in the controller
func show_queue_panel(p_visible: bool) -> void:
	if controller:
		controller.show_queue_panel(p_visible)


## Get item data from context
func get_item_data(item_id: String) -> ItemData:
	if context:
		return context.get_item_data(item_id)
	return null


## Get current gold from context
func get_current_gold() -> int:
	if context:
		return context.get_current_gold()
	return 0


## Get gold available for queueing from context
func get_available_gold() -> int:
	if context:
		return context.get_available_for_queue()
	return 0


## Handle input - subclasses can override for specific behavior
func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Default: B/Cancel goes back (if not at root)
	if event.is_action_pressed("ui_cancel"):
		_on_back_requested()
		get_viewport().set_input_as_handled()


## Capture ALL unhandled input to prevent leaking to game controls
## This ensures movement keys, action buttons, etc. don't control the player
func _unhandled_input(_event: InputEvent) -> void:
	if visible:
		# Block all input from passing through to game controls
		get_viewport().set_input_as_handled()


## Override to handle back button behavior
## Default behavior is go_back()
func _on_back_requested() -> void:
	go_back()


## Called when screen is about to be removed
## Override for cleanup if needed
func _on_screen_exit() -> void:
	pass
