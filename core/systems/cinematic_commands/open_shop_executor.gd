## OpenShopExecutor - Opens a shop interface during a cinematic
##
## This command pauses the cinematic while the shop UI is open.
## The cinematic resumes when the player closes the shop.
##
## Parameters:
##   shop_id: String - The ID of the ShopData resource to open
##
## Usage in cinematic JSON:
##   {"type": "open_shop", "params": {"shop_id": "noobington_item_shop"}}
##
## Common pattern: Shop NPC greeting followed by shop:
##   1. dialog_line: "Welcome to my shop!"
##   2. open_shop: "noobington_item_shop"
##   3. dialog_line: "Come back anytime!"
extends CinematicCommandExecutor

var _manager: Node = null


func execute(command: Dictionary, manager: Node) -> bool:
	_manager = manager
	var params: Dictionary = command.get("params", {})
	var shop_id: String = params.get("shop_id", "")

	if shop_id.is_empty():
		push_error("OpenShopExecutor: shop_id is required")
		return true  # Complete immediately on error

	# Look up the shop in ModRegistry by shop_id property (not filename)
	var shop_data: ShopData = ModLoader.registry.get_shop_by_id(shop_id)
	if not shop_data:
		push_error("OpenShopExecutor: Shop with shop_id '%s' not found in ModRegistry" % shop_id)
		return true  # Complete immediately on error

	# Validate the shop
	if not shop_data.validate():
		push_error("OpenShopExecutor: Shop '%s' validation failed" % shop_id)
		return true

	# Get current SaveData for gold access
	var save_data: SaveData = null
	if SaveManager and "current_save" in SaveManager:
		save_data = SaveManager.current_save

	# Open the shop
	ShopManager.open_shop(shop_data, save_data)

	# Connect to shop_closed signal to know when to resume
	if not ShopManager.shop_closed.is_connected(_on_shop_closed):
		ShopManager.shop_closed.connect(_on_shop_closed)

	# CRITICAL: Change state to WAITING_FOR_COMMAND to properly block cinematic execution
	# This prevents _process() timer logic from clearing wait state and continuing
	# (Same pattern as DialogExecutor using WAITING_FOR_DIALOG)
	manager.current_state = manager.State.WAITING_FOR_COMMAND

	# Return false = async operation, cinematic waits for us
	return false


func _on_shop_closed() -> void:
	# Disconnect to avoid duplicate connections on future shops
	if ShopManager.shop_closed.is_connected(_on_shop_closed):
		ShopManager.shop_closed.disconnect(_on_shop_closed)

	# Restore cinematic state and signal completion
	CinematicCommandExecutor.complete_async_command(_manager, true)
	_manager = null


func interrupt() -> void:
	# If cinematic is skipped while shop is open, close the shop
	if ShopManager.is_shop_open():
		ShopManager.close_shop()

	# Clean up signal connection
	if ShopManager.shop_closed.is_connected(_on_shop_closed):
		ShopManager.shop_closed.disconnect(_on_shop_closed)

	_manager = null
