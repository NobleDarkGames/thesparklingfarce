extends Node

## ShopManager - Autoload singleton for shop transactions
##
## Handles all buy/sell operations, integrating with existing systems:
## - SaveData.gold for currency
## - PartyManager for character inventory management
## - StorageManager for Caravan depot operations
## - EquipmentManager for equipment validation
##
## SF2-Authentic Features:
## - "Who equips this?" assignment flow
## - Caravan storage from any shop
## - Sell directly from Caravan (QoL improvement)
## - Bulk buying for consumables
## - Equipment class restrictions
##
## Mod Extensibility:
## - custom_transaction_validation signal for mod hooks
## - Price multipliers via ShopData
## - Custom shop types supported
##
## Usage:
##   ShopManager.open_shop(shop_data)
##   ShopManager.buy_item(shop, "bronze_sword", 1, "max")
##   ShopManager.sell_item("healing_seed", "caravan", 1)


# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when a shop is opened
signal shop_opened(shop_data: ShopData)

## Emitted when a shop is closed
signal shop_closed()

## Emitted after a successful purchase
## transaction: {item_id, quantity, total_cost, target_type, target_uid}
signal purchase_completed(transaction: Dictionary)

## Emitted when a purchase fails
## reason: Human-readable error message
signal purchase_failed(reason: String)

## Emitted after a successful sale
## transaction: {item_id, quantity, total_earned, source_type, source_uid}
signal sale_completed(transaction: Dictionary)

## Emitted when a sale fails
signal sale_failed(reason: String)

## Emitted before a transaction for custom mod validation
## Mods connect to this and can set result["allowed"] = false with result["reason"]
## context: {shop: ShopData, item_id: String, quantity: int, operation: "buy"/"sell"}
## result: {allowed: bool, reason: String}
signal custom_transaction_validation(context: Dictionary, result: Dictionary)

## Emitted when gold changes due to shop transaction
signal gold_changed(old_amount: int, new_amount: int)


# ============================================================================
# STATE
# ============================================================================

## Currently open shop (null if no shop is open)
var current_shop: ShopData = null

## Reference to the active SaveData (must be set before transactions)
var _save_data: SaveData = null


# ============================================================================
# RESULT HELPERS
# ============================================================================

## Create a failed transaction result
func _fail(error: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {success = false, error = error, transaction = {}}
	result.merge(extra)
	return result


## Create a failed church result
func _fail_church(error: String, cost: int = 0) -> Dictionary:
	return {success = false, error = error, cost = cost}


## Create a failed church promotion result
func _fail_promotion(error: String, cost: int = 0) -> Dictionary:
	return {success = false, error = error, cost = cost, stat_changes = {}}


# ============================================================================
# VALIDATION HELPERS
# ============================================================================

## Validate basic buy parameters. Returns error string or empty if valid.
func _validate_buy_basics(item_id: String, quantity: int) -> String:
	if not current_shop:
		return "No shop is open"
	if item_id.is_empty():
		return "Invalid item ID"
	if quantity < 1:
		return "Invalid quantity"
	return ""


## Validate basic sell parameters. Returns error string or empty if valid.
func _validate_sell_basics(item_id: String, quantity: int, source: String) -> String:
	if not current_shop:
		return "No shop is open"
	if not current_shop.can_sell:
		return "This shop doesn't buy items"
	if item_id.is_empty():
		return "Invalid item ID"
	if quantity < 1:
		return "Invalid quantity"
	if source == "caravan" and not current_shop.can_sell_from_caravan:
		return "Cannot sell from Caravan at this shop"
	return ""


## Validate church service is available. Returns error string or empty if valid.
func _validate_church() -> String:
	if not current_shop:
		return "No shop is open"
	if current_shop.shop_type != ShopData.ShopType.CHURCH:
		return "Not a church"
	return ""


## Deduct gold and emit change signal
func _deduct_gold(cost: int) -> void:
	var old_gold: int = _get_gold()
	_set_gold(old_gold - cost)
	gold_changed.emit(old_gold, old_gold - cost)


## Add gold and emit change signal
func _add_gold(amount: int) -> void:
	var old_gold: int = _get_gold()
	_set_gold(old_gold + amount)
	gold_changed.emit(old_gold, old_gold + amount)


# ============================================================================
# SHOP LIFECYCLE
# ============================================================================

## Open a shop for transactions
## @param shop_data: ShopData resource to open
## @param save_data: Current SaveData (for gold access)
func open_shop(shop_data: ShopData, save_data: SaveData = null) -> void:
	if not shop_data:
		push_error("ShopManager: Cannot open null shop")
		return

	if not shop_data.validate():
		push_error("ShopManager: Shop '%s' failed validation" % shop_data.shop_id)
		return

	current_shop = shop_data
	_save_data = save_data
	shop_opened.emit(shop_data)


## Close the current shop
func close_shop() -> void:
	current_shop = null
	shop_closed.emit()


## Check if a shop is currently open
func is_shop_open() -> bool:
	return current_shop != null


## Get the currently open shop
func get_current_shop() -> ShopData:
	return current_shop


# ============================================================================
# BUY OPERATIONS
# ============================================================================

## Buy an item from the current shop
## @param item_id: ID of the item to buy
## @param quantity: Number to buy (1 for equipment, >1 for consumables)
## @param target: "caravan" or character_uid
## @return: Dictionary {success: bool, error: String, transaction: Dictionary}
func buy_item(item_id: String, quantity: int, target: String) -> Dictionary:
	# Basic validation
	var validation_error: String = _validate_buy_basics(item_id, quantity)
	if not validation_error.is_empty():
		purchase_failed.emit(validation_error)
		return _fail(validation_error)

	# Check item exists and is in stock
	var item_data: ItemData = _get_item_data(item_id)
	if not item_data:
		purchase_failed.emit("Item not found: %s" % item_id)
		return _fail("Item not found")

	if not current_shop.has_item_in_stock(item_id):
		purchase_failed.emit("Item out of stock")
		return _fail("Item out of stock")

	# Check stock quantity
	var stock: int = current_shop.get_item_stock(item_id)
	if stock > 0 and stock < quantity:
		var error: String = "Not enough in stock (have %d)" % stock
		purchase_failed.emit(error)
		return _fail("Not enough in stock")

	# Calculate total cost
	var is_deal: bool = item_id in current_shop.deals_inventory
	var unit_price: int = current_shop.get_effective_buy_price(item_id, is_deal)
	var total_cost: int = unit_price * quantity

	# Check gold
	var current_gold: int = _get_gold()
	if current_gold < total_cost:
		var error: String = "Not enough gold (need %d, have %d)" % [total_cost, current_gold]
		purchase_failed.emit(error)
		return _fail("Not enough gold")

	# Custom validation hook
	var validation_context: Dictionary = {
		"shop": current_shop,
		"item_id": item_id,
		"quantity": quantity,
		"target": target,
		"operation": "buy",
		"total_cost": total_cost
	}
	var validation_result: Dictionary = {"allowed": true, "reason": ""}
	custom_transaction_validation.emit(validation_context, validation_result)

	if not validation_result.allowed:
		purchase_failed.emit(validation_result.reason)
		return _fail(validation_result.reason)

	# Character inventory check (applies to both equipment and consumables)
	if target != "caravan":
		var inventory_check: Dictionary = _can_character_receive_item(target, item_id)
		if not inventory_check.success:
			purchase_failed.emit(inventory_check.error)
			return _fail(inventory_check.error)

	# Execute transaction with rollback support
	var add_result: Dictionary = _add_items_with_rollback(target, item_id, quantity)
	if not add_result.success:
		purchase_failed.emit(add_result.error)
		return _fail(add_result.error)

	# Deduct gold and decrement shop stock
	_deduct_gold(total_cost)
	current_shop.decrement_stock(item_id, quantity)

	# Build transaction record
	var transaction: Dictionary = {
		"item_id": item_id,
		"item_name": item_data.item_name,
		"quantity": quantity,
		"unit_price": unit_price,
		"total_cost": total_cost,
		"target_type": "caravan" if target == "caravan" else "character",
		"target_uid": target,
		"is_deal": is_deal
	}

	purchase_completed.emit(transaction)
	return {success = true, error = "", transaction = transaction}


## Buy an item from the Deals menu
## @param item_id: ID of the deal item
## @param quantity: Number to buy
## @param target: "caravan" or character_uid
func buy_deal_item(item_id: String, quantity: int, target: String) -> Dictionary:
	if not current_shop:
		return {success = false, error = "No shop is open", transaction = {}}

	if item_id not in current_shop.deals_inventory:
		return {success = false, error = "Item not in deals", transaction = {}}

	return buy_item(item_id, quantity, target)


# ============================================================================
# SELL OPERATIONS
# ============================================================================

## Sell an item from character inventory or Caravan
## @param item_id: ID of the item to sell
## @param source: "caravan" or character_uid
## @param quantity: Number to sell (must have that many)
## @return: Dictionary {success: bool, error: String, transaction: Dictionary}
func sell_item(item_id: String, source: String, quantity: int = 1) -> Dictionary:
	# Basic validation
	var validation_error: String = _validate_sell_basics(item_id, quantity, source)
	if not validation_error.is_empty():
		sale_failed.emit(validation_error)
		return _fail(validation_error)

	var is_caravan: bool = source == "caravan"

	# Get item data
	var item_data: ItemData = _get_item_data(item_id)
	if not item_data:
		sale_failed.emit("Item not found: %s" % item_id)
		return _fail("Item not found")

	# Check source has the item(s)
	var has_result: Dictionary = _source_has_items(source, item_id, quantity)
	if not has_result.success:
		sale_failed.emit(has_result.error)
		return _fail(has_result.error)

	# Check if selling equipped item
	var is_equipped: bool = false
	if not is_caravan:
		is_equipped = _is_item_equipped(source, item_id)

	# Calculate earnings - use item_data directly since we validated it above
	var unit_price: int = int(float(item_data.sell_price) * current_shop.sell_multiplier)
	if unit_price < 0:
		unit_price = 0  # Minimum sell price is 0 (can't lose gold by selling)
	var total_earned: int = unit_price * quantity

	# Custom validation hook
	var validation_context: Dictionary = {
		"shop": current_shop,
		"item_id": item_id,
		"quantity": quantity,
		"source": source,
		"operation": "sell",
		"total_earned": total_earned,
		"is_equipped": is_equipped
	}
	var validation_result: Dictionary = {"allowed": true, "reason": ""}
	custom_transaction_validation.emit(validation_context, validation_result)

	if not validation_result.allowed:
		sale_failed.emit(validation_result.reason)
		return _fail(validation_result.reason)

	# Execute removal with rollback support
	var remove_result: Dictionary = _remove_items_with_rollback(source, item_id, quantity)
	if not remove_result.success:
		sale_failed.emit(remove_result.error)
		return _fail(remove_result.error)

	# Add gold
	_add_gold(total_earned)

	# Build transaction record
	var transaction: Dictionary = {
		"item_id": item_id,
		"item_name": item_data.item_name,
		"quantity": quantity,
		"unit_price": unit_price,
		"total_earned": total_earned,
		"source_type": "caravan" if is_caravan else "character",
		"source_uid": source,
		"was_equipped": is_equipped
	}

	sale_completed.emit(transaction)
	return {success = true, error = "", transaction = transaction}


# ============================================================================
# QUERY METHODS
# ============================================================================

## Get current gold amount
func get_gold() -> int:
	return _get_gold()


## Check if player can afford an item
## @param item_id: Item to check
## @param quantity: Number of items
## @param is_deal: Whether to use deals pricing
func can_afford(item_id: String, quantity: int = 1, is_deal: bool = false) -> bool:
	if not current_shop:
		return false
	var price: int = current_shop.get_effective_buy_price(item_id, is_deal)
	if price < 0:
		return false
	return _get_gold() >= price * quantity


## Check if a character can equip an item
## @param character_uid: Character to check
## @param item_id: Item to check
func can_character_equip(character_uid: String, item_id: String) -> bool:
	var item_data: ItemData = _get_item_data(item_id)
	if not item_data or not item_data.is_equippable():
		return false

	var save_data: CharacterSaveData = _get_character_save_data(character_uid)
	if not save_data:
		return false

	# Use EquipmentManager for full validation
	var valid_slots: Array[String] = item_data.get_valid_slots()
	if valid_slots.is_empty():
		return false

	# Check if character can equip in at least one valid slot
	for slot_id: String in valid_slots:
		var result: Dictionary = EquipmentManager.can_equip(save_data, slot_id, item_id)
		if result.can_equip:
			return true

	return false


## Get all characters who can equip an item
## @param item_id: Item to check
## @return: Array of {character_uid: String, character_name: String, character_data: CharacterData}
func get_characters_who_can_equip(item_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for character: CharacterData in PartyManager.party_members:
		var uid: String = character.character_uid
		if can_character_equip(uid, item_id):
			result.append({
				"character_uid": uid,
				"character_name": character.character_name,
				"character_data": character
			})

	return result


## Get all party members who have inventory space
## Used for consumable items where anyone can carry the item
## @return: Array of {character_uid: String, character_name: String, character_data: CharacterData}
func get_characters_with_inventory_room() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for character: CharacterData in PartyManager.party_members:
		var uid: String = character.character_uid
		if character_has_inventory_room(uid):
			result.append({
				"character_uid": uid,
				"character_name": character.character_name,
				"character_data": character
			})

	return result


## Get eligible characters for receiving an item (considering item type)
## For equipment: returns characters who can equip it
## For consumables: returns characters with inventory space
## @param item_id: Item to check
## @return: Array of {character_uid: String, character_name: String, character_data: CharacterData}
func get_eligible_characters_for_item(item_id: String) -> Array[Dictionary]:
	var item_data: ItemData = _get_item_data(item_id)
	if not item_data:
		return []

	# Equipment needs class/slot checking
	if item_data.is_equippable():
		return get_characters_who_can_equip(item_id)

	# Consumables just need inventory space
	return get_characters_with_inventory_room()


## Get stat comparison for an item vs current equipment
## @param character_uid: Character to compare for
## @param item_id: Item to compare
## @return: Dictionary of {stat_name: difference} (positive = upgrade)
func get_stat_comparison(character_uid: String, item_id: String) -> Dictionary:
	var comparison: Dictionary = {}
	var item_data: ItemData = _get_item_data(item_id)
	if not item_data:
		return comparison

	var save_data: CharacterSaveData = _get_character_save_data(character_uid)
	if not save_data:
		return comparison

	# Get currently equipped item in the relevant slot
	var valid_slots: Array[String] = item_data.get_valid_slots()
	if valid_slots.is_empty():
		return comparison

	var current_item_id: String = EquipmentManager.get_equipped_item_id(save_data, valid_slots[0])
	var current_item: ItemData = _get_item_data(current_item_id) if not current_item_id.is_empty() else null

	# Compare attack power for weapons
	if item_data.item_type == ItemData.ItemType.WEAPON:
		var new_attack: int = item_data.attack_power
		var old_attack: int = current_item.attack_power if current_item else 0
		comparison["attack"] = new_attack - old_attack

	# Compare stat modifiers
	var stats: Array[String] = ["hp", "mp", "strength", "defense", "agility", "intelligence", "luck"]
	for stat: String in stats:
		var new_mod: int = item_data.get_stat_modifier(stat)
		var old_mod: int = current_item.get_stat_modifier(stat) if current_item else 0
		var diff: int = new_mod - old_mod
		if diff != 0:
			comparison[stat] = diff

	return comparison


## Check if character inventory has room
## @param character_uid: Character to check
## @return: true if character has at least 1 free inventory slot
func character_has_inventory_room(character_uid: String) -> bool:
	var save_data: CharacterSaveData = _get_character_save_data(character_uid)
	if not save_data:
		return false

	var max_slots: int = 4
	if ModLoader and ModLoader.inventory_config:
		max_slots = ModLoader.inventory_config.get_max_slots()

	return save_data.inventory.size() < max_slots


# ============================================================================
# CHURCH SERVICES (for ShopType.CHURCH)
# ============================================================================

## Heal a character at a church
## @param character_uid: Character to heal
## @return: Dictionary {success: bool, error: String, cost: int}
func church_heal(character_uid: String) -> Dictionary:
	var church_error: String = _validate_church()
	if not church_error.is_empty():
		return _fail_church(church_error)

	var save_data: CharacterSaveData = _get_character_save_data(character_uid)
	if not save_data:
		return _fail_church("Character not found")

	# Check if healing is needed
	if save_data.current_hp >= save_data.max_hp and save_data.current_mp >= save_data.max_mp:
		return _fail_church("Character is already at full health")

	var cost: int = current_shop.heal_cost
	if _get_gold() < cost:
		return _fail_church("Not enough gold", cost)

	# Restore HP and MP to max
	save_data.current_hp = save_data.max_hp
	save_data.current_mp = save_data.max_mp
	_deduct_gold(cost)

	return {success = true, error = "", cost = cost}


## Revive a fallen character at a church
## @param character_uid: Character to revive
## @return: Dictionary {success: bool, error: String, cost: int}
func church_revive(character_uid: String) -> Dictionary:
	var church_error: String = _validate_church()
	if not church_error.is_empty():
		return _fail_church(church_error)

	var save_data: CharacterSaveData = _get_character_save_data(character_uid)
	if not save_data:
		return _fail_church("Character not found")

	if save_data.is_alive:
		return _fail_church("Character is not dead")

	var cost: int = current_shop.get_revival_cost(save_data.level)
	if _get_gold() < cost:
		return _fail_church("Not enough gold", cost)

	# Revive with HP based on global setting
	save_data.is_alive = true
	var hp_percent: int = SettingsManager.get_church_revival_hp_percent()
	if hp_percent <= 0:
		save_data.current_hp = 1  # SF2-authentic: revive with 1 HP
	else:
		save_data.current_hp = maxi(1, save_data.max_hp * hp_percent / 100)

	_deduct_gold(cost)
	return {success = true, error = "", cost = cost}


## Uncurse an item at a church
## @param character_uid: Character with cursed item
## @param slot_id: Slot containing cursed item
## @return: Dictionary {success: bool, error: String, cost: int}
func church_uncurse(character_uid: String, slot_id: String) -> Dictionary:
	var church_error: String = _validate_church()
	if not church_error.is_empty():
		return _fail_church(church_error)

	var save_data: CharacterSaveData = _get_character_save_data(character_uid)
	if not save_data:
		return _fail_church("Character not found")

	if not EquipmentManager.is_slot_cursed(save_data, slot_id):
		return _fail_church("Item is not cursed")

	var cost: int = current_shop.uncurse_base_cost
	if _get_gold() < cost:
		return _fail_church("Not enough gold", cost)

	# Use existing EquipmentManager uncurse functionality
	var uncurse_result: Dictionary = EquipmentManager.attempt_uncurse(save_data, slot_id, "church")
	if not uncurse_result.success:
		return _fail_church(uncurse_result.error, cost)

	_deduct_gold(cost)
	return {success = true, error = "", cost = cost}


## Promote a character at a church
## @param character_uid: Character to promote
## @param target_class: ClassData to promote to
## @return: Dictionary {success: bool, error: String, cost: int, stat_changes: Dictionary}
func church_promote(character_uid: String, target_class: ClassData) -> Dictionary:
	var church_error: String = _validate_church()
	if not church_error.is_empty():
		return _fail_promotion(church_error)

	var save_data: CharacterSaveData = _get_character_save_data(character_uid)
	if not save_data:
		return _fail_promotion("Character not found")

	if not target_class:
		return _fail_promotion("Invalid promotion target")

	# Build a Unit for PromotionManager (it needs Unit, not CharacterSaveData)
	var unit: Unit = _build_unit_for_promotion(character_uid, save_data)
	if not unit:
		return _fail_promotion("Failed to build unit for promotion")

	# Check if promotion is valid via PromotionManager
	if not PromotionManager.can_promote(unit):
		unit.queue_free()
		return _fail_promotion("Character cannot promote")

	var available_promotions: Array[ClassData] = PromotionManager.get_available_promotions(unit)
	if target_class not in available_promotions:
		unit.queue_free()
		return _fail_promotion("Invalid promotion path")

	# Calculate cost: level * 100 (SF2-authentic formula)
	var cost: int = _get_promotion_cost(save_data.level)
	if _get_gold() < cost:
		unit.queue_free()
		return _fail_promotion("Not enough gold", cost)

	# Execute promotion
	var stat_changes: Dictionary = PromotionManager.execute_promotion(unit, target_class)
	_deduct_gold(cost)
	unit.queue_free()

	return {success = true, error = "", cost = cost, stat_changes = stat_changes}


## Get characters eligible for promotion
## @return: Array of character_uid strings for promotable characters
func get_promotable_characters() -> Array[String]:
	var result: Array[String] = []

	for character: CharacterData in PartyManager.party_members:
		var uid: String = character.character_uid
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(uid)
		if not save_data:
			continue

		# Must be alive
		if not save_data.is_alive:
			continue

		# Build temporary unit to check promotion eligibility
		var unit: Unit = _build_unit_for_promotion(uid, save_data)
		if not unit:
			continue

		if PromotionManager.can_promote(unit):
			result.append(uid)

		unit.queue_free()

	return result


## LOW-003: Constant for promotion cost formula
const PROMOTION_COST_PER_LEVEL: int = 100

## Calculate promotion cost based on character level
## SF2-authentic: level * 100 gold
func _get_promotion_cost(level: int) -> int:
	return level * PROMOTION_COST_PER_LEVEL


## Build a temporary Unit node for PromotionManager operations
## PromotionManager requires Unit with stats and character_data
## HIGH-007: Caller MUST call unit.queue_free() when done to prevent memory leak
func _build_unit_for_promotion(character_uid: String, save_data: CharacterSaveData) -> Unit:
	# Get CharacterData from PartyManager
	var character_data: CharacterData = null
	for character: CharacterData in PartyManager.party_members:
		if character.character_uid == character_uid:
			character_data = character
			break

	if not character_data:
		return null

	# Create a temporary Unit
	var unit: Unit = Unit.new()
	unit.character_data = character_data

	# Create UnitStats from save data
	var stats: UnitStats = UnitStats.new()
	if not stats:
		# HIGH-007: Ensure unit is freed on error path
		unit.queue_free()
		return null

	stats.level = save_data.level
	stats.current_hp = save_data.current_hp
	stats.max_hp = save_data.max_hp
	stats.current_mp = save_data.current_mp
	stats.max_mp = save_data.max_mp
	stats.strength = save_data.strength
	stats.defense = save_data.defense
	stats.agility = save_data.agility
	stats.intelligence = save_data.intelligence
	stats.luck = save_data.luck

	# Get current class from save data
	stats.class_data = save_data.get_current_class(character_data)

	unit.stats = stats

	return unit


# ============================================================================
# PRIVATE HELPERS - GOLD
# ============================================================================

func _get_gold() -> int:
	# First priority: explicitly set SaveData (passed to open_shop)
	if _save_data:
		return _save_data.gold

	# Fallback: use SaveManager's current active save
	if SaveManager and SaveManager.current_save:
		return SaveManager.current_save.gold

	return 0


func _set_gold(amount: int) -> void:
	# First priority: explicitly set SaveData (passed to open_shop)
	if _save_data:
		_save_data.gold = maxi(0, amount)
		return

	# Fallback: use SaveManager's current active save
	if SaveManager and SaveManager.current_save:
		SaveManager.current_save.gold = maxi(0, amount)


# ============================================================================
# PRIVATE HELPERS - INVENTORY
# ============================================================================

func _get_item_data(item_id: String) -> ItemData:
	if item_id.is_empty():
		return null
	return ModLoader.registry.get_item(item_id)


func _get_character_save_data(character_uid: String) -> CharacterSaveData:
	return PartyManager.get_member_save_data(character_uid)


func _add_to_caravan(item_id: String) -> Dictionary:
	if StorageManager.add_to_depot(item_id):
		return {success = true, error = ""}
	return {success = false, error = "Failed to add to Caravan"}


func _remove_from_caravan(item_id: String) -> Dictionary:
	if StorageManager.remove_from_depot(item_id):
		return {success = true, error = ""}
	return {success = false, error = "Item not in Caravan"}


func _add_to_character(character_uid: String, item_id: String) -> Dictionary:
	if PartyManager.add_item_to_member(character_uid, item_id):
		return {success = true, error = ""}
	return {success = false, error = "Character inventory full"}


func _remove_from_character(character_uid: String, item_id: String) -> Dictionary:
	var save_data: CharacterSaveData = _get_character_save_data(character_uid)
	if not save_data:
		return {success = false, error = "Character not found"}

	# Check if item is equipped (need to unequip first)
	if _is_item_equipped(character_uid, item_id):
		var unequip_result: Dictionary = _unequip_item(character_uid, item_id)
		if not unequip_result.success:
			return unequip_result

	# Remove from inventory
	if PartyManager.remove_item_from_member(character_uid, item_id):
		return {success = true, error = ""}

	return {success = false, error = "Item not in inventory"}


func _can_character_receive_item(character_uid: String, item_id: String) -> Dictionary:
	if not character_has_inventory_room(character_uid):
		return {success = false, error = "Character inventory full"}
	return {success = true, error = ""}


func _source_has_items(source: String, item_id: String, quantity: int) -> Dictionary:
	if source == "caravan":
		var count: int = StorageManager.get_item_count(item_id)
		if count < quantity:
			return {success = false, error = "Not enough items in Caravan (have %d, need %d)" % [count, quantity]}
		return {success = true, error = ""}
	else:
		var save_data: CharacterSaveData = _get_character_save_data(source)
		if not save_data:
			return {success = false, error = "Character not found"}

		var count: int = _count_character_items(save_data, item_id)
		if count < quantity:
			return {success = false, error = "Not enough items (have %d, need %d)" % [count, quantity]}
		return {success = true, error = ""}


func _count_character_items(save_data: CharacterSaveData, item_id: String) -> int:
	var count: int = 0

	# Count in inventory
	for inv_item_id: String in save_data.inventory:
		if inv_item_id == item_id:
			count += 1

	# Count equipped items
	for entry: Dictionary in save_data.equipped_items:
		var entry_item_id: String = DictUtils.get_string(entry, "item_id", "")
		if entry_item_id == item_id:
			count += 1

	return count


func _is_item_equipped(character_uid: String, item_id: String) -> bool:
	var save_data: CharacterSaveData = _get_character_save_data(character_uid)
	if not save_data:
		return false

	for entry: Dictionary in save_data.equipped_items:
		var entry_item_id: String = DictUtils.get_string(entry, "item_id", "")
		if entry_item_id == item_id:
			return true

	return false


func _unequip_item(character_uid: String, item_id: String) -> Dictionary:
	var save_data: CharacterSaveData = _get_character_save_data(character_uid)
	if not save_data:
		return {success = false, error = "Character not found"}

	# Find which slot has this item
	for entry: Dictionary in save_data.equipped_items:
		var entry_item_id: String = DictUtils.get_string(entry, "item_id", "")
		if entry_item_id == item_id:
			var slot_id: String = DictUtils.get_string(entry, "slot", "")
			var result: Dictionary = EquipmentManager.unequip_item(save_data, slot_id)
			if result.success:
				return {success = true, error = ""}
			return {success = false, error = result.error}

	return {success = false, error = "Item not equipped"}


# ============================================================================
# TRANSACTION ROLLBACK HELPERS
# ============================================================================

## Add multiple items to target with automatic rollback on failure
func _add_items_with_rollback(target: String, item_id: String, quantity: int) -> Dictionary:
	var is_caravan: bool = target == "caravan"
	var items_added: int = 0

	for i: int in range(quantity):
		var result: Dictionary
		if is_caravan:
			result = _add_to_caravan(item_id)
		else:
			result = _add_to_character(target, item_id)

		if not result.success:
			# Rollback: remove items already added
			for j: int in range(items_added):
				var rollback_result: Dictionary
				if is_caravan:
					rollback_result = _remove_from_caravan(item_id)
				else:
					rollback_result = _remove_from_character(target, item_id)
				if not rollback_result.success:
					push_error("ShopManager: CRITICAL - Rollback failed during _add_items_with_rollback. Inventory may be corrupted. Target: %s, Item: %s, Rollback error: %s" % [target, item_id, rollback_result.error])
			return result

		items_added += 1

	return {success = true, error = ""}


## Remove multiple items from source with automatic rollback on failure
func _remove_items_with_rollback(source: String, item_id: String, quantity: int) -> Dictionary:
	var is_caravan: bool = source == "caravan"
	var items_removed: int = 0

	for i: int in range(quantity):
		var result: Dictionary
		if is_caravan:
			result = _remove_from_caravan(item_id)
		else:
			result = _remove_from_character(source, item_id)

		if not result.success:
			# Rollback: restore items already removed
			for j: int in range(items_removed):
				var rollback_result: Dictionary
				if is_caravan:
					rollback_result = _add_to_caravan(item_id)
				else:
					rollback_result = _add_to_character(source, item_id)
				if not rollback_result.success:
					push_error("ShopManager: CRITICAL - Rollback failed during _remove_items_with_rollback. Inventory may be corrupted. Source: %s, Item: %s, Rollback error: %s" % [source, item_id, rollback_result.error])
			return result

		items_removed += 1

	return {success = true, error = ""}
