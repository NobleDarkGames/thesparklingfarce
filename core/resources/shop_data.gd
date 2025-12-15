class_name ShopData
extends Resource

## ShopData - Configuration resource for in-game shops
##
## Defines shop inventory, pricing rules, and behavior. Shops are physical NPCs
## in the game world that characters interact with to buy/sell items.
##
## SF2-Authentic Features:
## - "Who equips this?" flow preserved
## - Caravan storage accessible from shops
## - Deals system for discounted items
## - Class-restricted equipment filtering
##
## Mod Extensibility:
## - Custom shop types via ShopType enum
## - Price multipliers for economy balancing
## - Flag-based availability gating
## - Custom inventory definitions
##
## Usage:
##   Place .tres files in mods/<mod_id>/data/shops/
##   Auto-discovered by ModLoader and registered in ModRegistry

enum ShopType {
	WEAPON,     ## Sells weapons (swords, bows, axes)
	ITEM,       ## Sells consumables and accessories
	CHURCH,     ## Healing, revival, promotion, uncursing services
	CRAFTER,    ## Mithril forge / special crafting (wraps CrafterData)
	SPECIAL     ## Custom shop types defined by mods
}

# ============================================================================
# IDENTITY
# ============================================================================

## Unique identifier for this shop (e.g., "my_mod_weapon_shop")
@export var shop_id: String = ""

## Display name shown in UI (e.g., "Weapon Shop")
@export var shop_name: String = ""

## Type of shop - affects available menu options
@export var shop_type: ShopType = ShopType.ITEM

# ============================================================================
# PRESENTATION
# ============================================================================

@export_group("Presentation")

## Greeting text when entering shop
## Example: "Welcome to the weapon shop!"
@export var greeting_text: String = "Welcome!"

## Farewell text when exiting shop
## Example: "Come again!"
@export var farewell_text: String = "Come again!"

# ============================================================================
# INVENTORY
# ============================================================================

@export_group("Inventory")

## Main shop inventory
## Format: Array of {item_id: String, stock: int, price_override: int}
##   - item_id: ID of the item to sell (links to ItemData)
##   - stock: Number available (-1 = infinite, 0 = sold out)
##   - price_override: Custom buy price (-1 = use ItemData.buy_price)
##
## Example: [{"item_id": "bronze_sword", "stock": -1, "price_override": -1}]
@export var inventory: Array[Dictionary] = []

## Items available in the "Deals" menu (discounted items)
## Format: Array of item IDs (uses deals_discount multiplier for pricing)
@export var deals_inventory: Array[String] = []

# ============================================================================
# ECONOMY
# ============================================================================

@export_group("Economy")

## Multiplier applied to ItemData.buy_price (1.0 = normal, 0.9 = 10% discount)
@export_range(0.1, 2.0, 0.05) var buy_multiplier: float = 1.0

## Multiplier applied to ItemData.sell_price (1.0 = normal, typically 50% of buy)
@export_range(0.1, 2.0, 0.05) var sell_multiplier: float = 1.0

## Discount applied to deals_inventory items (0.75 = 25% off)
@export_range(0.1, 1.0, 0.05) var deals_discount: float = 0.75

# ============================================================================
# AVAILABILITY
# ============================================================================

@export_group("Availability")

## Story flags required for this shop to be open/available
## All flags must be set for shop to be accessible
@export var required_flags: Array[String] = []

## Story flags that prevent this shop from being available
## If any of these flags are set, shop is inaccessible
@export var forbidden_flags: Array[String] = []

# ============================================================================
# FEATURES
# ============================================================================

@export_group("Features")

## Whether this shop has a Sell option
@export var can_sell: bool = true

## Whether items can be stored in Caravan from this shop
## SF2-authentic: Always true
@export var can_store_to_caravan: bool = true

## Whether items can be sold directly from Caravan storage
## QoL improvement over SF2 (which didn't allow this)
@export var can_sell_from_caravan: bool = true

## Whether this shop has active deals to show
## Computed from deals_inventory but can be used as visual indicator
@export var has_deals: bool = false

# ============================================================================
# CHURCH SERVICES (for ShopType.CHURCH)
# ============================================================================

@export_group("Church Services")

## Cost to fully heal a character (0 = free)
@export var heal_cost: int = 0

## Base cost to revive a character (may scale with level)
@export var revive_base_cost: int = 200

## Cost multiplier per character level for revival
@export_range(0.0, 10.0, 0.5) var revive_level_multiplier: float = 10.0

## Base cost to uncurse an item
@export var uncurse_base_cost: int = 500

# ============================================================================
# CRAFTER INTEGRATION (for ShopType.CRAFTER)
# ============================================================================

@export_group("Crafter Integration")

## CrafterData resource ID to use for this shop
## Links to existing CrafterData for forging services
@export var crafter_id: String = ""

# ============================================================================
# VALIDATION
# ============================================================================

## Validate that required fields are set
func validate() -> bool:
	if shop_id.is_empty():
		push_error("ShopData: shop_id is required")
		return false

	if shop_name.is_empty():
		push_error("ShopData: shop_name is required")
		return false

	# Validate inventory entries
	for entry: Dictionary in inventory:
		if "item_id" not in entry:
			push_error("ShopData '%s': inventory entry missing item_id" % shop_id)
			return false
		if entry.item_id.is_empty():
			push_error("ShopData '%s': inventory entry has empty item_id" % shop_id)
			return false

	# Check for crafter_id if CRAFTER type
	if shop_type == ShopType.CRAFTER and crafter_id.is_empty():
		push_warning("ShopData '%s': CRAFTER shop has no crafter_id assigned" % shop_id)

	return true


# ============================================================================
# UTILITY METHODS
# ============================================================================

## Get effective buy price for an item in this shop
## @param item_id: ID of the item to price
## @param is_deal: Whether this is from the deals inventory
## @return: Effective price after multipliers, or -1 if item not found and no override
func get_effective_buy_price(item_id: String, is_deal: bool = false) -> int:
	var base_price: int = -1

	# First check for price override in inventory (allows testing without ItemData)
	for entry: Dictionary in inventory:
		if entry.get("item_id", "") == item_id:
			var override: int = entry.get("price_override", -1)
			if override >= 0:
				base_price = override
			break

	# If no override, try to get from ItemData
	if base_price < 0:
		var item_data: ItemData = _get_item_data(item_id)
		if not item_data:
			return -1
		base_price = item_data.buy_price

	# Apply multipliers
	var final_price: float = float(base_price) * buy_multiplier
	if is_deal:
		final_price *= deals_discount

	return int(final_price)


## Get effective sell price for an item at this shop
## @param item_id: ID of the item to price
## @return: Effective sell price after multipliers, or -1 if item not found
func get_effective_sell_price(item_id: String) -> int:
	var item_data: ItemData = _get_item_data(item_id)
	if not item_data:
		return -1

	var base_price: int = item_data.sell_price
	var final_price: float = float(base_price) * sell_multiplier

	return int(final_price)


## Check if this shop has an item in stock
## @param item_id: ID of the item to check
## @return: true if in stock (stock > 0 or stock == -1 for infinite)
func has_item_in_stock(item_id: String) -> bool:
	for entry: Dictionary in inventory:
		if entry.get("item_id", "") == item_id:
			var stock: int = entry.get("stock", -1)
			return stock != 0  # -1 = infinite, >0 = in stock
	return false


## Get the stock count for an item
## @param item_id: ID of the item
## @return: Stock count (-1 = infinite, 0 = sold out, >0 = count)
func get_item_stock(item_id: String) -> int:
	for entry: Dictionary in inventory:
		if entry.get("item_id", "") == item_id:
			return entry.get("stock", -1)
	return 0  # Not in inventory


## Decrement stock for an item (call after purchase)
## @param item_id: ID of the item
## @param quantity: Amount to decrement
## @return: true if successful, false if insufficient stock
func decrement_stock(item_id: String, quantity: int = 1) -> bool:
	for i: int in range(inventory.size()):
		if inventory[i].get("item_id", "") == item_id:
			var current_stock: int = inventory[i].get("stock", -1)
			if current_stock == -1:
				return true  # Infinite stock
			if current_stock < quantity:
				return false  # Insufficient
			inventory[i]["stock"] = current_stock - quantity
			return true
	return false  # Not found


## Check if shop is available based on story flags
## @param current_flags: Dictionary of story flags (from GameState)
## @return: true if all required flags are set and no forbidden flags are set
func is_available(current_flags: Dictionary) -> bool:
	# Check required flags
	for flag: String in required_flags:
		if flag not in current_flags or not current_flags[flag]:
			return false

	# Check forbidden flags
	for flag: String in forbidden_flags:
		if flag in current_flags and current_flags[flag]:
			return false

	return true


## Get all item IDs sold by this shop (for filtering)
## @return: Array of item IDs from inventory
func get_all_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in inventory:
		var item_id: String = entry.get("item_id", "")
		if not item_id.is_empty():
			ids.append(item_id)
	return ids


## Check if this shop has any active deals
## @return: true if deals_inventory has items
func has_active_deals() -> bool:
	return not deals_inventory.is_empty()


## Get revival cost for a character at a given level
## @param level: Character's current level
## @return: Total revival cost
func get_revival_cost(level: int) -> int:
	return revive_base_cost + int(float(level) * revive_level_multiplier)


# ============================================================================
# PRIVATE HELPERS
# ============================================================================

func _get_item_data(item_id: String) -> ItemData:
	if item_id.is_empty():
		return null
	# Use ModLoader autoload (available globally at runtime)
	var mod_loader: Node = Engine.get_main_loop().root.get_node_or_null("/root/ModLoader") if Engine.get_main_loop() else null
	if mod_loader and "registry" in mod_loader:
		return mod_loader.registry.get_resource("item", item_id) as ItemData
	# Fallback for editor preview
	return null
