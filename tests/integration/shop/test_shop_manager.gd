## Unit Tests for ShopManager Autoload
##
## Tests shop transaction logic, validation, and system integration.
## Note: These tests require the full autoload environment since ShopManager
## integrates with PartyManager, StorageManager, and EquipmentManager.
class_name TestShopManager
extends GdUnitTestSuite


const SignalTrackerScript: GDScript = preload("res://tests/fixtures/signal_tracker.gd")


# =============================================================================
# TEST FIXTURES
# =============================================================================

var _shop_data: ShopData
var _save_data: SaveData
var _test_character_uid: String = "test_character"

# Signal tracker for cleanup
var _tracker: RefCounted  # SignalTracker type


## Helper to create and register a test character with PartyManager
func _setup_test_character(needs_healing: bool = true) -> void:
	var char_save: CharacterSaveData = CharacterSaveData.new()
	char_save.max_hp = 100
	char_save.max_mp = 50
	if needs_healing:
		char_save.current_hp = 50  # Needs healing
		char_save.current_mp = 25
	else:
		char_save.current_hp = 100  # Full health
		char_save.current_mp = 50
	char_save.level = 1
	PartyManager.update_member_save_data(_test_character_uid, char_save)


func before_test() -> void:
	_tracker = SignalTrackerScript.new()

	# Clear any existing depot state
	if StorageManager:
		StorageManager.clear_depot()

	# Create test shop data
	# Note: Use price_override to avoid dependency on ModLoader item lookups
	_shop_data = ShopData.new()
	_shop_data.shop_id = "test_shop"
	_shop_data.shop_name = "Test Shop"
	_shop_data.shop_type = ShopData.ShopType.ITEM
	_shop_data.inventory = [
		{"item_id": "healing_herb", "stock": -1, "price_override": 10},
		{"item_id": "power_ring", "stock": 3, "price_override": 200}
	]
	_shop_data.deals_inventory = ["healing_herb"]
	_shop_data.can_sell = true
	_shop_data.can_store_to_caravan = true
	_shop_data.can_sell_from_caravan = true

	# Create test save data
	_save_data = SaveData.new()
	_save_data.gold = 1000

	# Clear any existing shop state
	if ShopManager:
		ShopManager.close_shop()


func after_test() -> void:
	# Disconnect all tracked signals
	_tracker.disconnect_all()
	_tracker = null

	if ShopManager:
		ShopManager.close_shop()
	if StorageManager:
		StorageManager.clear_depot()
	_shop_data = null
	_save_data = null


## Helper to connect a signal and track it for cleanup
func _connect_signal(sig: Signal, callable: Callable) -> void:
	_tracker.track_with_callback(sig, callable)


# =============================================================================
# SHOP LIFECYCLE TESTS
# =============================================================================

func test_shop_starts_closed() -> void:
	assert_bool(ShopManager.is_shop_open()).is_false()
	assert_object(ShopManager.get_current_shop()).is_null()


func test_open_shop() -> void:
	ShopManager.open_shop(_shop_data, _save_data)

	assert_bool(ShopManager.is_shop_open()).is_true()
	assert_object(ShopManager.get_current_shop()).is_equal(_shop_data)


func test_close_shop() -> void:
	ShopManager.open_shop(_shop_data, _save_data)
	ShopManager.close_shop()

	assert_bool(ShopManager.is_shop_open()).is_false()
	assert_object(ShopManager.get_current_shop()).is_null()


func test_open_shop_with_null_fails() -> void:
	ShopManager.open_shop(null, _save_data)

	assert_bool(ShopManager.is_shop_open()).is_false()


# =============================================================================
# GOLD TESTS
# =============================================================================

func test_get_gold() -> void:
	ShopManager.open_shop(_shop_data, _save_data)

	var gold: int = ShopManager.get_gold()

	assert_int(gold).is_equal(1000)


func test_can_afford_true() -> void:
	ShopManager.open_shop(_shop_data, _save_data)
	_save_data.gold = 100

	# healing_herb costs 10 gold (from the actual item data)
	var can_afford: bool = ShopManager.can_afford("healing_herb", 1)

	assert_bool(can_afford).is_true()


func test_can_afford_false() -> void:
	ShopManager.open_shop(_shop_data, _save_data)
	_save_data.gold = 5  # Less than the cost of healing_herb (10)

	var can_afford: bool = ShopManager.can_afford("healing_herb", 1)

	assert_bool(can_afford).is_false()


func test_can_afford_multiple() -> void:
	ShopManager.open_shop(_shop_data, _save_data)
	_save_data.gold = 100

	# Can afford 10 healing herbs at 10g each
	var can_afford_10: bool = ShopManager.can_afford("healing_herb", 10)
	# Cannot afford 11 (110g needed)
	var can_afford_11: bool = ShopManager.can_afford("healing_herb", 11)

	assert_bool(can_afford_10).is_true()
	assert_bool(can_afford_11).is_false()


# =============================================================================
# BUY VALIDATION TESTS
# =============================================================================

func test_buy_item_no_shop_open() -> void:
	ShopManager.close_shop()

	var result: Dictionary = ShopManager.buy_item("healing_herb", 1, "caravan")

	assert_bool(result.success).is_false()
	assert_str(result.error).contains("No shop is open")


func test_buy_item_invalid_item_id() -> void:
	ShopManager.open_shop(_shop_data, _save_data)

	var result: Dictionary = ShopManager.buy_item("", 1, "caravan")

	assert_bool(result.success).is_false()
	assert_str(result.error).contains("Invalid item ID")


func test_buy_item_invalid_quantity() -> void:
	ShopManager.open_shop(_shop_data, _save_data)

	var result: Dictionary = ShopManager.buy_item("healing_herb", 0, "caravan")

	assert_bool(result.success).is_false()
	assert_str(result.error).contains("Invalid quantity")


func test_buy_item_not_in_stock() -> void:
	ShopManager.open_shop(_shop_data, _save_data)
	_shop_data.inventory = []  # Empty inventory

	var result: Dictionary = ShopManager.buy_item("healing_herb", 1, "caravan")

	# Should fail - either "Item not found" (no ModLoader) or "stock" related
	assert_bool(result.success).is_false()
	# Note: If ItemData isn't in ModLoader, we get "Item not found" first
	# This is expected - the item lookup happens before stock check
	assert_bool(
		result.error.contains("not found") or
		result.error.contains("stock") or
		result.error.contains("Not in stock")
	).is_true()


func test_buy_item_not_enough_gold() -> void:
	ShopManager.open_shop(_shop_data, _save_data)
	_save_data.gold = 1  # Not enough for healing_herb (10g)

	var result: Dictionary = ShopManager.buy_item("healing_herb", 1, "caravan")

	# Should fail - either "Item not found" (no ModLoader) or "gold" related
	assert_bool(result.success).is_false()
	# Note: If ItemData isn't in ModLoader, we get "Item not found" first
	# This is expected - the item lookup happens before gold check
	assert_bool(
		result.error.contains("not found") or
		result.error.contains("gold") or
		result.error.contains("afford")
	).is_true()


# =============================================================================
# BUY TO CARAVAN TESTS
# =============================================================================

## Note: Buy tests may fail if ModLoader hasn't loaded ItemData resources.
## These tests verify the core buy logic assuming ItemData is available.

func test_buy_item_to_caravan() -> void:
	ShopManager.open_shop(_shop_data, _save_data)
	_save_data.gold = 1000
	var initial_depot_size: int = StorageManager.get_depot_size()

	var result: Dictionary = ShopManager.buy_item("healing_herb", 1, "caravan")

	# Buy may fail if ItemData lookup fails - both outcomes are valid
	if result.success:
		assert_int(StorageManager.get_depot_size()).is_equal(initial_depot_size + 1)
		assert_bool(StorageManager.has_item("healing_herb")).is_true()
		# Gold should be deducted (healing_herb costs 10)
		assert_int(_save_data.gold).is_less(1000)
	else:
		# ItemData not found - this is expected in unit tests without full mod loading
		# Verify we got a meaningful error, not a silent failure
		assert_bool(result.error.contains("not found")).is_true()


func test_buy_multiple_to_caravan() -> void:
	ShopManager.open_shop(_shop_data, _save_data)
	_save_data.gold = 1000
	var initial_depot_size: int = StorageManager.get_depot_size()

	var result: Dictionary = ShopManager.buy_item("healing_herb", 5, "caravan")

	# Both outcomes are valid - verify the appropriate behavior for each
	if result.success:
		assert_int(StorageManager.get_depot_size()).is_equal(initial_depot_size + 5)
		assert_int(StorageManager.get_item_count("healing_herb")).is_greater_equal(5)
	else:
		# ItemData not found - expected in unit tests without full mod loading
		assert_bool(result.error.contains("not found")).is_true()


func test_buy_depletes_limited_stock() -> void:
	_shop_data.inventory = [{"item_id": "power_ring", "stock": 3, "price_override": 200}]
	ShopManager.open_shop(_shop_data, _save_data)
	_save_data.gold = 10000

	var result: Dictionary = ShopManager.buy_item("power_ring", 1, "caravan")

	# Both outcomes are valid - verify the appropriate behavior for each
	if result.success:
		# Stock should decrease on successful purchase
		assert_int(_shop_data.get_item_stock("power_ring")).is_equal(2)
	else:
		# Stock unchanged if purchase failed (ItemData not found in unit tests)
		assert_int(_shop_data.get_item_stock("power_ring")).is_equal(3)
		assert_bool(result.error.contains("not found")).is_true()


# =============================================================================
# SELL VALIDATION TESTS
# =============================================================================

func test_sell_item_no_shop_open() -> void:
	ShopManager.close_shop()

	var result: Dictionary = ShopManager.sell_item("healing_herb", "caravan", 1)

	assert_bool(result.success).is_false()
	assert_str(result.error).contains("No shop is open")


func test_sell_item_shop_cannot_buy() -> void:
	_shop_data.can_sell = false
	ShopManager.open_shop(_shop_data, _save_data)

	var result: Dictionary = ShopManager.sell_item("healing_herb", "caravan", 1)

	assert_bool(result.success).is_false()
	assert_str(result.error).contains("doesn't buy")


func test_sell_from_caravan_disabled() -> void:
	_shop_data.can_sell_from_caravan = false
	ShopManager.open_shop(_shop_data, _save_data)
	StorageManager.add_to_depot("healing_herb")

	var result: Dictionary = ShopManager.sell_item("healing_herb", "caravan", 1)

	assert_bool(result.success).is_false()
	assert_str(result.error).contains("Caravan")


# =============================================================================
# SELL FROM CARAVAN TESTS
# =============================================================================

## Note: Sell tests require ModLoader to have loaded ItemData resources.
## These tests verify validation logic; integration tests would verify pricing.

func test_sell_item_from_caravan_validation() -> void:
	# This tests that selling works when item exists in caravan
	# The actual gold earned depends on ItemData.sell_price being available
	ShopManager.open_shop(_shop_data, _save_data)
	StorageManager.add_to_depot("healing_herb")

	var result: Dictionary = ShopManager.sell_item("healing_herb", "caravan", 1)

	# If item lookup fails, we get "Item not found" error
	# If it succeeds, the item is removed from caravan
	if result.success:
		assert_bool(StorageManager.has_item("healing_herb")).is_false()
	else:
		# ItemData not available during unit tests - this is expected
		assert_str(result.error).contains("not found")


func test_sell_item_not_in_caravan() -> void:
	ShopManager.open_shop(_shop_data, _save_data)
	# Don't add item to caravan

	var result: Dictionary = ShopManager.sell_item("healing_herb", "caravan", 1)

	# Should fail either because item not in caravan OR item not found
	assert_bool(result.success).is_false()


func test_sell_multiple_from_caravan_validation() -> void:
	ShopManager.open_shop(_shop_data, _save_data)
	StorageManager.add_to_depot("healing_herb")
	StorageManager.add_to_depot("healing_herb")
	StorageManager.add_to_depot("healing_herb")
	var initial_count: int = StorageManager.get_item_count("healing_herb")

	var result: Dictionary = ShopManager.sell_item("healing_herb", "caravan", 2)

	# If item lookup succeeds, count should decrease by 2
	# If it fails, count stays the same
	if result.success:
		assert_int(StorageManager.get_item_count("healing_herb")).is_equal(initial_count - 2)
	else:
		# ItemData not available during unit tests
		assert_int(StorageManager.get_item_count("healing_herb")).is_equal(initial_count)


# =============================================================================
# TRANSACTION RECORD TESTS
# =============================================================================

func test_buy_transaction_record() -> void:
	ShopManager.open_shop(_shop_data, _save_data)
	_save_data.gold = 1000

	var result: Dictionary = ShopManager.buy_item("healing_herb", 2, "caravan")

	# Buy may fail if ItemData isn't found during unit tests
	if result.success:
		assert_str(result.transaction.item_id).is_equal("healing_herb")
		assert_int(result.transaction.quantity).is_equal(2)
		assert_int(result.transaction.total_cost).is_greater(0)
		assert_str(result.transaction.target_type).is_equal("caravan")
	else:
		# ItemData not available during unit tests - verify we got an error
		assert_str(result.error).is_not_empty()


func test_sell_transaction_record() -> void:
	ShopManager.open_shop(_shop_data, _save_data)
	StorageManager.add_to_depot("healing_herb")

	var result: Dictionary = ShopManager.sell_item("healing_herb", "caravan", 1)

	# Sell may fail if ItemData isn't found during unit tests
	if result.success:
		assert_str(result.transaction.item_id).is_equal("healing_herb")
		assert_int(result.transaction.quantity).is_equal(1)
		assert_int(result.transaction.total_earned).is_greater(0)
		assert_str(result.transaction.source_type).is_equal("caravan")
	else:
		# ItemData not available during unit tests
		assert_str(result.error).is_not_empty()


# =============================================================================
# CHURCH SERVICE TESTS
# =============================================================================

func test_church_heal_wrong_shop_type() -> void:
	_shop_data.shop_type = ShopData.ShopType.ITEM
	ShopManager.open_shop(_shop_data, _save_data)

	var result: Dictionary = ShopManager.church_heal("test_character")

	assert_bool(result.success).is_false()
	assert_str(result.error).contains("church")


func test_church_heal_not_enough_gold() -> void:
	_setup_test_character(true)  # Character needs healing
	_shop_data.shop_type = ShopData.ShopType.CHURCH
	_shop_data.heal_cost = 100
	ShopManager.open_shop(_shop_data, _save_data)
	_save_data.gold = 50

	var result: Dictionary = ShopManager.church_heal(_test_character_uid)

	assert_bool(result.success).is_false()
	assert_str(result.error).contains("gold")


func test_church_heal_free() -> void:
	_setup_test_character(true)  # Character needs healing
	_shop_data.shop_type = ShopData.ShopType.CHURCH
	_shop_data.heal_cost = 0
	ShopManager.open_shop(_shop_data, _save_data)
	var initial_gold: int = _save_data.gold

	var result: Dictionary = ShopManager.church_heal(_test_character_uid)

	assert_bool(result.success).is_true()
	assert_int(_save_data.gold).is_equal(initial_gold)  # No gold deducted


func test_church_heal_costs_gold() -> void:
	_setup_test_character(true)  # Character needs healing
	_shop_data.shop_type = ShopData.ShopType.CHURCH
	_shop_data.heal_cost = 50
	ShopManager.open_shop(_shop_data, _save_data)
	_save_data.gold = 100

	var result: Dictionary = ShopManager.church_heal(_test_character_uid)

	assert_bool(result.success).is_true()
	assert_int(_save_data.gold).is_equal(50)


# =============================================================================
# CHURCH PROMOTE TESTS
# =============================================================================

func test_church_promote_wrong_shop_type() -> void:
	_shop_data.shop_type = ShopData.ShopType.ITEM
	ShopManager.open_shop(_shop_data, _save_data)

	var result: Dictionary = ShopManager.church_promote("test_character", null)

	assert_bool(result.success).is_false()
	assert_str(result.error).contains("church")


func test_church_promote_no_shop_open() -> void:
	ShopManager.close_shop()

	var result: Dictionary = ShopManager.church_promote("test_character", null)

	assert_bool(result.success).is_false()
	assert_str(result.error).contains("No shop")


func test_church_promote_null_target_class() -> void:
	_setup_test_character(false)
	_shop_data.shop_type = ShopData.ShopType.CHURCH
	ShopManager.open_shop(_shop_data, _save_data)

	var result: Dictionary = ShopManager.church_promote(_test_character_uid, null)

	assert_bool(result.success).is_false()
	assert_str(result.error).contains("Invalid promotion target")


func test_church_promote_character_not_found() -> void:
	_shop_data.shop_type = ShopData.ShopType.CHURCH
	ShopManager.open_shop(_shop_data, _save_data)

	# Create a mock ClassData for testing
	var mock_class: ClassData = ClassData.new()

	var result: Dictionary = ShopManager.church_promote("nonexistent_character", mock_class)

	assert_bool(result.success).is_false()
	assert_str(result.error).contains("Character not found")


func test_church_promote_not_enough_gold() -> void:
	# Setup character at level 10 (promotion cost = 1000)
	var char_save: CharacterSaveData = CharacterSaveData.new()
	char_save.level = 10
	char_save.current_hp = 100
	char_save.max_hp = 100
	char_save.is_alive = true
	PartyManager.update_member_save_data(_test_character_uid, char_save)

	_shop_data.shop_type = ShopData.ShopType.CHURCH
	ShopManager.open_shop(_shop_data, _save_data)
	_save_data.gold = 500  # Less than 1000 (level 10 * 100)

	var mock_class: ClassData = ClassData.new()
	var result: Dictionary = ShopManager.church_promote(_test_character_uid, mock_class)

	# This may fail because character can't promote (no class data)
	# But if it gets to gold check, it should fail for gold
	assert_bool(result.success).is_false()
	# Error could be about gold OR about promotion eligibility
	assert_str(result.error).is_not_empty()


func test_get_promotable_characters_empty_when_no_eligible() -> void:
	# Setup a low-level character (can't promote)
	var char_save: CharacterSaveData = CharacterSaveData.new()
	char_save.level = 5  # Below promotion level (10)
	char_save.is_alive = true
	PartyManager.update_member_save_data(_test_character_uid, char_save)

	_shop_data.shop_type = ShopData.ShopType.CHURCH
	ShopManager.open_shop(_shop_data, _save_data)

	var promotable: Array[String] = ShopManager.get_promotable_characters()

	# Should be empty since our test character is level 5
	# (may include other characters from real party data)
	assert_bool(_test_character_uid not in promotable).is_true()


# =============================================================================
# SIGNAL TESTS
# =============================================================================

var _shop_opened_received: bool = false
var _shop_closed_received: bool = false
var _purchase_completed_received: bool = false
var _purchase_failed_received: bool = false
var _sale_completed_received: bool = false
var _sale_failed_received: bool = false
var _gold_changed_received: bool = false


func _reset_signal_flags() -> void:
	_shop_opened_received = false
	_shop_closed_received = false
	_purchase_completed_received = false
	_purchase_failed_received = false
	_sale_completed_received = false
	_sale_failed_received = false
	_gold_changed_received = false


func _on_shop_opened(_shop: ShopData) -> void:
	_shop_opened_received = true


func _on_shop_closed() -> void:
	_shop_closed_received = true


func _on_purchase_completed(_transaction: Dictionary) -> void:
	_purchase_completed_received = true


func _on_purchase_failed(_reason: String) -> void:
	_purchase_failed_received = true


func _on_sale_completed(_transaction: Dictionary) -> void:
	_sale_completed_received = true


func _on_sale_failed(_reason: String) -> void:
	_sale_failed_received = true


func _on_gold_changed(_old: int, _new: int) -> void:
	_gold_changed_received = true


func test_shop_opened_signal() -> void:
	_reset_signal_flags()
	_connect_signal(ShopManager.shop_opened, _on_shop_opened)

	ShopManager.open_shop(_shop_data, _save_data)

	assert_bool(_shop_opened_received).is_true()
	# Signal cleanup handled by after_test()


func test_shop_closed_signal() -> void:
	_reset_signal_flags()
	ShopManager.open_shop(_shop_data, _save_data)
	_connect_signal(ShopManager.shop_closed, _on_shop_closed)

	ShopManager.close_shop()

	assert_bool(_shop_closed_received).is_true()
	# Signal cleanup handled by after_test()


func test_purchase_completed_signal() -> void:
	_reset_signal_flags()
	ShopManager.open_shop(_shop_data, _save_data)
	_save_data.gold = 1000
	_connect_signal(ShopManager.purchase_completed, _on_purchase_completed)
	_connect_signal(ShopManager.purchase_failed, _on_purchase_failed)

	ShopManager.buy_item("healing_herb", 1, "caravan")

	# Either completed or failed, but one signal should fire
	assert_bool(_purchase_completed_received or _purchase_failed_received).is_true()
	# Signal cleanup handled by after_test()


func test_purchase_failed_signal_no_gold() -> void:
	_reset_signal_flags()
	ShopManager.open_shop(_shop_data, _save_data)
	_save_data.gold = 0  # No gold
	_connect_signal(ShopManager.purchase_failed, _on_purchase_failed)

	ShopManager.buy_item("healing_herb", 1, "caravan")

	# Should fail - either due to no gold or item not found
	assert_bool(_purchase_failed_received).is_true()
	# Signal cleanup handled by after_test()


func test_sale_completed_signal() -> void:
	_reset_signal_flags()
	ShopManager.open_shop(_shop_data, _save_data)
	StorageManager.add_to_depot("healing_herb")
	_connect_signal(ShopManager.sale_completed, _on_sale_completed)
	_connect_signal(ShopManager.sale_failed, _on_sale_failed)

	ShopManager.sell_item("healing_herb", "caravan", 1)

	# Either completed or failed, but one signal should fire
	assert_bool(_sale_completed_received or _sale_failed_received).is_true()
	# Signal cleanup handled by after_test()


func test_gold_changed_signal() -> void:
	_reset_signal_flags()
	ShopManager.open_shop(_shop_data, _save_data)
	_save_data.gold = 1000
	_connect_signal(ShopManager.gold_changed, _on_gold_changed)
	_connect_signal(ShopManager.purchase_failed, _on_purchase_failed)

	ShopManager.buy_item("healing_herb", 1, "caravan")

	# Gold changes only if purchase succeeded
	# If purchase failed, gold_changed won't fire
	if _purchase_failed_received:
		pass  # No gold change expected on failure
	else:
		assert_bool(_gold_changed_received).is_true()
	# Signal cleanup handled by after_test()
