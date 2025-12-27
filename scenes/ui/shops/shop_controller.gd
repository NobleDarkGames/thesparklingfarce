extends CanvasLayer

## ShopController - Main controller for multi-screen shop system
##
## Manages screen stack, shared context, and coordinates with ShopManager.
## Implements the pay-per-placement model for consumable bulk purchases.
##
## Key Responsibilities:
## - Screen transitions and navigation stack
## - ShopContext lifecycle management
## - Queue panel visibility and updates
## - Gold display (real-time updates)

# Preload dependencies to avoid load order issues with autoloads
const ShopContextClass: GDScript = preload("res://scenes/ui/shops/shop_context.gd")

signal shop_closed()

## Shared context across all screens
var context: RefCounted = null  # Actually ShopContext, but typed as RefCounted for load order

## Currently active screen instance
var current_screen: Control = null

## Current screen name (for history tracking)
var current_screen_name: String = ""

## Screen scene cache (lazy loaded)
var _screen_scenes: Dictionary = {}

## Screen names mapped to scene paths
const SCREEN_PATHS: Dictionary = {
	# Note: greeting removed - cinematics handle shop greetings via DialogManager
	"action_select": "res://scenes/ui/shops/screens/action_select.tscn",
	"item_browser": "res://scenes/ui/shops/screens/item_browser.tscn",
	"char_select": "res://scenes/ui/shops/screens/char_select.tscn",
	"placement_mode": "res://scenes/ui/shops/screens/placement_mode.tscn",
	"sell_char_select": "res://scenes/ui/shops/screens/sell_char_select.tscn",
	"sell_inventory": "res://scenes/ui/shops/screens/sell_inventory.tscn",
	"sell_confirm": "res://scenes/ui/shops/screens/sell_confirm.tscn",
	"confirm_transaction": "res://scenes/ui/shops/screens/confirm_transaction.tscn",
	"transaction_result": "res://scenes/ui/shops/screens/transaction_result.tscn",
	# Church screens
	"church_action_select": "res://scenes/ui/shops/screens/church_action_select.tscn",
	"church_char_select": "res://scenes/ui/shops/screens/church_char_select.tscn",
	"church_slot_select": "res://scenes/ui/shops/screens/church_slot_select.tscn",
	# Crafter screens
	"crafter_action_select": "res://scenes/ui/shops/screens/crafter_action_select.tscn",
	"crafter_recipe_browser": "res://scenes/ui/shops/screens/crafter_recipe_browser.tscn",
	"crafter_confirm": "res://scenes/ui/shops/screens/crafter_confirm.tscn",
}

## Node references
@onready var screen_container: Control = %ScreenContainer
@onready var queue_panel: Control = %QueuePanel
@onready var gold_label: Label = %GoldLabel
@onready var shop_name_label: Label = %ShopNameLabel
@onready var input_blocker: ColorRect = %InputBlocker


func _ready() -> void:
	context = ShopContextClass.new()
	hide()

	# Connect to ShopManager signals
	if ShopManager:
		ShopManager.shop_opened.connect(_on_shop_manager_opened)
		ShopManager.shop_closed.connect(_on_shop_manager_closed)
		ShopManager.gold_changed.connect(_on_gold_changed)


func _exit_tree() -> void:
	# Clean up ShopManager signal connections to prevent stale references
	if ShopManager:
		if ShopManager.shop_opened.is_connected(_on_shop_manager_opened):
			ShopManager.shop_opened.disconnect(_on_shop_manager_opened)
		if ShopManager.shop_closed.is_connected(_on_shop_manager_closed):
			ShopManager.shop_closed.disconnect(_on_shop_manager_closed)
		if ShopManager.gold_changed.is_connected(_on_gold_changed):
			ShopManager.gold_changed.disconnect(_on_gold_changed)


## Called when ShopManager opens a shop
func _on_shop_manager_opened(shop_data: ShopData) -> void:
	var save_data: SaveData = null
	if SaveManager and SaveManager.current_save:
		save_data = SaveManager.current_save

	open_shop(shop_data, save_data)


## Called when ShopManager closes the shop
func _on_shop_manager_closed() -> void:
	close_shop()


## Open shop with given ShopData
func open_shop(shop_data: ShopData, save_data: SaveData) -> void:
	context.initialize(shop_data, save_data)

	# Set shop name
	shop_name_label.text = shop_data.shop_name

	update_gold_display()
	show_queue_panel(false)
	show()

	# Start with appropriate action select based on shop type
	if shop_data.shop_type == ShopData.ShopType.CHURCH:
		push_screen("church_action_select")
	elif shop_data.shop_type == ShopData.ShopType.CRAFTER:
		push_screen("crafter_action_select")
	else:
		push_screen("action_select")


## Update gold display (call after any transaction)
func update_gold_display() -> void:
	var gold: int = context.get_current_gold()
	gold_label.text = "GOLD: %dG" % gold


## Close shop and clean up
func close_shop() -> void:
	_clear_current_screen()
	context.cleanup()
	hide()
	shop_closed.emit()

	# CRITICAL: Tell ShopManager we're closed so is_shop_open() returns false
	# This must happen AFTER our cleanup to avoid re-entrancy from _on_shop_manager_closed
	if ShopManager and ShopManager.is_shop_open():
		ShopManager.close_shop()


## Navigate to a new screen (adds current to history)
func push_screen(screen_name: String) -> void:
	if not current_screen_name.is_empty():
		context.push_to_history(current_screen_name)
	_transition_to_screen(screen_name)


## Go back to previous screen
func pop_screen() -> void:
	var previous: String = context.pop_from_history()
	if previous.is_empty():
		# At root - close shop
		ShopManager.close_shop()
	else:
		_transition_to_screen(previous)


## Replace current screen without adding to history
func replace_screen(screen_name: String) -> void:
	_transition_to_screen(screen_name)


## Show/hide the queue panel
func show_queue_panel(p_visible: bool) -> void:
	if not queue_panel:
		return

	queue_panel.visible = p_visible
	if p_visible and context and context.queue:
		_refresh_queue_panel()


## Refresh queue panel contents
func _refresh_queue_panel() -> void:
	if queue_panel and queue_panel.has_method("refresh"):
		queue_panel.refresh(context.queue, context.get_current_gold())


## Internal screen transition
func _transition_to_screen(screen_name: String) -> void:
	_clear_current_screen()

	# Load screen scene
	var scene: PackedScene = _get_screen_scene(screen_name)
	if not scene:
		push_error("ShopController: Failed to load screen '%s'" % screen_name)
		return

	# Instantiate and add to container
	current_screen = scene.instantiate()
	current_screen_name = screen_name

	# Add to tree FIRST so @onready vars are available
	screen_container.add_child(current_screen)

	# THEN initialize (now @onready vars are set)
	if current_screen.has_method("initialize"):
		current_screen.initialize(self, context)

	# Update queue panel visibility based on screen type
	var show_queue: bool = screen_name in ["item_browser", "placement_mode", "sell_inventory"]
	show_queue_panel(show_queue and context.queue and not context.queue.is_empty())


## Get cached scene or load it
func _get_screen_scene(screen_name: String) -> PackedScene:
	# Return cached if available
	if screen_name in _screen_scenes:
		var cached: Variant = _screen_scenes[screen_name]
		return cached if cached is PackedScene else null

	# Check if path exists
	if screen_name not in SCREEN_PATHS:
		push_error("ShopController: Unknown screen name '%s'" % screen_name)
		return null

	var path: String = DictUtils.get_string(SCREEN_PATHS, screen_name, "")

	# Check if file exists before loading
	if not ResourceLoader.exists(path):
		push_error("ShopController: Screen scene not found at '%s'" % path)
		return null

	# Load and cache
	var loaded: Resource = load(path)
	var scene: PackedScene = loaded if loaded is PackedScene else null
	if scene:
		_screen_scenes[screen_name] = scene
	return scene


## Clear the current screen
func _clear_current_screen() -> void:
	if current_screen:
		# Notify screen it's being removed
		if current_screen.has_method("_on_screen_exit"):
			current_screen._on_screen_exit()
		current_screen.queue_free()
		current_screen = null
	current_screen_name = ""


## Handle gold changes from ShopManager
func _on_gold_changed(_old_amount: int, _new_amount: int) -> void:
	update_gold_display()
	if queue_panel and queue_panel.visible:
		_refresh_queue_panel()


## Block input during transitions (future use)
func _set_input_blocked(blocked: bool) -> void:
	if input_blocker:
		input_blocker.visible = blocked
