## Unit Tests for ShopData Resource
##
## Tests ShopData validation, pricing calculations, and utility methods.
class_name TestShopData
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

var _shop: ShopData


func before_test() -> void:
	_shop = ShopData.new()
	_shop.shop_id = "test_shop"
	_shop.shop_name = "Test Shop"
	_shop.shop_type = ShopData.ShopType.ITEM


func after_test() -> void:
	if _shop:
		_shop = null


# =============================================================================
# VALIDATION TESTS
# =============================================================================

func test_validation_requires_shop_id() -> void:
	_shop.shop_id = ""

	var result: bool = _shop.validate()

	assert_bool(result).is_false()


func test_validation_requires_shop_name() -> void:
	_shop.shop_name = ""

	var result: bool = _shop.validate()

	assert_bool(result).is_false()


func test_validation_passes_with_required_fields() -> void:
	var result: bool = _shop.validate()

	assert_bool(result).is_true()


func test_validation_inventory_entry_requires_item_id() -> void:
	_shop.inventory = [{"stock": -1, "price_override": -1}]

	var result: bool = _shop.validate()

	assert_bool(result).is_false()


func test_validation_inventory_entry_with_empty_item_id_fails() -> void:
	_shop.inventory = [{"item_id": "", "stock": -1, "price_override": -1}]

	var result: bool = _shop.validate()

	assert_bool(result).is_false()


func test_validation_valid_inventory_passes() -> void:
	_shop.inventory = [
		{"item_id": "healing_herb", "stock": -1, "price_override": -1},
		{"item_id": "bronze_sword", "stock": 5, "price_override": 100}
	]

	var result: bool = _shop.validate()

	assert_bool(result).is_true()


# =============================================================================
# STOCK TESTS
# =============================================================================

func test_has_item_in_stock_infinite() -> void:
	_shop.inventory = [{"item_id": "healing_herb", "stock": -1, "price_override": -1}]

	var result: bool = _shop.has_item_in_stock("healing_herb")

	assert_bool(result).is_true()


func test_has_item_in_stock_positive() -> void:
	_shop.inventory = [{"item_id": "healing_herb", "stock": 5, "price_override": -1}]

	var result: bool = _shop.has_item_in_stock("healing_herb")

	assert_bool(result).is_true()


func test_has_item_in_stock_sold_out() -> void:
	_shop.inventory = [{"item_id": "healing_herb", "stock": 0, "price_override": -1}]

	var result: bool = _shop.has_item_in_stock("healing_herb")

	assert_bool(result).is_false()


func test_has_item_in_stock_not_in_inventory() -> void:
	_shop.inventory = [{"item_id": "other_item", "stock": -1, "price_override": -1}]

	var result: bool = _shop.has_item_in_stock("healing_herb")

	assert_bool(result).is_false()


func test_get_item_stock_infinite() -> void:
	_shop.inventory = [{"item_id": "healing_herb", "stock": -1, "price_override": -1}]

	var stock: int = _shop.get_item_stock("healing_herb")

	assert_int(stock).is_equal(-1)


func test_get_item_stock_limited() -> void:
	_shop.inventory = [{"item_id": "healing_herb", "stock": 5, "price_override": -1}]

	var stock: int = _shop.get_item_stock("healing_herb")

	assert_int(stock).is_equal(5)


func test_get_item_stock_not_in_inventory() -> void:
	_shop.inventory = []

	var stock: int = _shop.get_item_stock("healing_herb")

	assert_int(stock).is_equal(0)


func test_decrement_stock_infinite() -> void:
	_shop.inventory = [{"item_id": "healing_herb", "stock": -1, "price_override": -1}]

	var result: bool = _shop.decrement_stock("healing_herb", 100)

	assert_bool(result).is_true()
	assert_int(_shop.get_item_stock("healing_herb")).is_equal(-1)  # Still infinite


func test_decrement_stock_success() -> void:
	_shop.inventory = [{"item_id": "healing_herb", "stock": 5, "price_override": -1}]

	var result: bool = _shop.decrement_stock("healing_herb", 2)

	assert_bool(result).is_true()
	assert_int(_shop.get_item_stock("healing_herb")).is_equal(3)


func test_decrement_stock_insufficient() -> void:
	_shop.inventory = [{"item_id": "healing_herb", "stock": 2, "price_override": -1}]

	var result: bool = _shop.decrement_stock("healing_herb", 5)

	assert_bool(result).is_false()
	assert_int(_shop.get_item_stock("healing_herb")).is_equal(2)  # Unchanged


func test_decrement_stock_not_found() -> void:
	_shop.inventory = []

	var result: bool = _shop.decrement_stock("healing_herb", 1)

	assert_bool(result).is_false()


# =============================================================================
# AVAILABILITY TESTS (Flag-based)
# =============================================================================

func test_is_available_no_flags() -> void:
	_shop.required_flags = []
	_shop.forbidden_flags = []

	var result: bool = _shop.is_available({})

	assert_bool(result).is_true()


func test_is_available_required_flag_set() -> void:
	_shop.required_flags = ["shop_unlocked"]

	var result: bool = _shop.is_available({"shop_unlocked": true})

	assert_bool(result).is_true()


func test_is_available_required_flag_missing() -> void:
	_shop.required_flags = ["shop_unlocked"]

	var result: bool = _shop.is_available({})

	assert_bool(result).is_false()


func test_is_available_required_flag_false() -> void:
	_shop.required_flags = ["shop_unlocked"]

	var result: bool = _shop.is_available({"shop_unlocked": false})

	assert_bool(result).is_false()


func test_is_available_multiple_required_flags() -> void:
	_shop.required_flags = ["flag_a", "flag_b"]

	var result_both: bool = _shop.is_available({"flag_a": true, "flag_b": true})
	var result_one: bool = _shop.is_available({"flag_a": true})

	assert_bool(result_both).is_true()
	assert_bool(result_one).is_false()


func test_is_available_forbidden_flag_not_set() -> void:
	_shop.forbidden_flags = ["shop_closed"]

	var result: bool = _shop.is_available({})

	assert_bool(result).is_true()


func test_is_available_forbidden_flag_set() -> void:
	_shop.forbidden_flags = ["shop_closed"]

	var result: bool = _shop.is_available({"shop_closed": true})

	assert_bool(result).is_false()


func test_is_available_combined_flags() -> void:
	_shop.required_flags = ["unlocked"]
	_shop.forbidden_flags = ["closed"]

	var result_ok: bool = _shop.is_available({"unlocked": true})
	var result_blocked: bool = _shop.is_available({"unlocked": true, "closed": true})

	assert_bool(result_ok).is_true()
	assert_bool(result_blocked).is_false()


# =============================================================================
# UTILITY METHODS
# =============================================================================

func test_get_all_item_ids() -> void:
	_shop.inventory = [
		{"item_id": "healing_herb", "stock": -1, "price_override": -1},
		{"item_id": "bronze_sword", "stock": 5, "price_override": -1},
		{"item_id": "power_ring", "stock": 1, "price_override": -1}
	]

	var ids: Array[String] = _shop.get_all_item_ids()

	assert_int(ids.size()).is_equal(3)
	assert_bool("healing_herb" in ids).is_true()
	assert_bool("bronze_sword" in ids).is_true()
	assert_bool("power_ring" in ids).is_true()


func test_has_active_deals() -> void:
	_shop.deals_inventory = []
	assert_bool(_shop.has_active_deals()).is_false()

	_shop.deals_inventory = ["healing_herb"]
	assert_bool(_shop.has_active_deals()).is_true()


func test_get_revival_cost() -> void:
	_shop.revive_base_cost = 200
	_shop.revive_level_multiplier = 10.0

	var cost_level_1: int = _shop.get_revival_cost(1)
	var cost_level_10: int = _shop.get_revival_cost(10)
	var cost_level_20: int = _shop.get_revival_cost(20)

	assert_int(cost_level_1).is_equal(210)   # 200 + 1*10
	assert_int(cost_level_10).is_equal(300)  # 200 + 10*10
	assert_int(cost_level_20).is_equal(400)  # 200 + 20*10


# =============================================================================
# SHOP TYPE TESTS
# =============================================================================

func test_shop_type_weapon() -> void:
	_shop.shop_type = ShopData.ShopType.WEAPON

	assert_int(_shop.shop_type).is_equal(ShopData.ShopType.WEAPON)


func test_shop_type_item() -> void:
	_shop.shop_type = ShopData.ShopType.ITEM

	assert_int(_shop.shop_type).is_equal(ShopData.ShopType.ITEM)


func test_shop_type_church() -> void:
	_shop.shop_type = ShopData.ShopType.CHURCH

	assert_int(_shop.shop_type).is_equal(ShopData.ShopType.CHURCH)


func test_shop_type_crafter() -> void:
	_shop.shop_type = ShopData.ShopType.CRAFTER

	assert_int(_shop.shop_type).is_equal(ShopData.ShopType.CRAFTER)


func test_shop_type_special() -> void:
	_shop.shop_type = ShopData.ShopType.SPECIAL

	assert_int(_shop.shop_type).is_equal(ShopData.ShopType.SPECIAL)


# =============================================================================
# DEFAULT VALUES
# =============================================================================

func test_default_multipliers() -> void:
	var shop: ShopData = ShopData.new()

	assert_float(shop.buy_multiplier).is_equal(1.0)
	assert_float(shop.sell_multiplier).is_equal(1.0)
	assert_float(shop.deals_discount).is_equal(0.75)


func test_default_features() -> void:
	var shop: ShopData = ShopData.new()

	assert_bool(shop.can_sell).is_true()
	assert_bool(shop.can_store_to_caravan).is_true()
	assert_bool(shop.can_sell_from_caravan).is_true()


func test_default_church_costs() -> void:
	var shop: ShopData = ShopData.new()

	assert_int(shop.heal_cost).is_equal(0)
	assert_int(shop.revive_base_cost).is_equal(200)
	assert_float(shop.revive_level_multiplier).is_equal(10.0)
	assert_int(shop.uncurse_base_cost).is_equal(500)
