extends GdUnitTestSuite

## Unit tests for EquipmentTypeRegistry
## Tests subtype-to-category mapping and wildcard matching

const EquipmentTypeRegistryClass = preload("res://core/registries/equipment_type_registry.gd")

var _registry: RefCounted


func before_test() -> void:
	_registry = EquipmentTypeRegistryClass.new()


func after_test() -> void:
	_registry = null


# =============================================================================
# REGISTRATION TESTS
# =============================================================================

func test_register_category() -> void:
	var config: Dictionary = {
		"categories": {
			"weapon": {"display_name": "Weapon"},
			"armor": {"display_name": "Armor"}
		}
	}

	_registry.register_from_config("test_mod", config)

	assert_bool(_registry.is_valid_category("weapon")).is_true()
	assert_bool(_registry.is_valid_category("armor")).is_true()
	assert_bool(_registry.is_valid_category("unknown")).is_false()


func test_register_subtype() -> void:
	var config: Dictionary = {
		"categories": {
			"weapon": {"display_name": "Weapon"}
		},
		"subtypes": {
			"sword": {"category": "weapon", "display_name": "Sword"},
			"axe": {"category": "weapon", "display_name": "Axe"}
		}
	}

	_registry.register_from_config("test_mod", config)

	assert_bool(_registry.is_valid_subtype("sword")).is_true()
	assert_bool(_registry.is_valid_subtype("axe")).is_true()
	assert_bool(_registry.is_valid_subtype("unknown")).is_false()


func test_get_category() -> void:
	var config: Dictionary = {
		"categories": {
			"weapon": {"display_name": "Weapon"}
		},
		"subtypes": {
			"sword": {"category": "weapon", "display_name": "Sword"}
		}
	}

	_registry.register_from_config("test_mod", config)

	assert_str(_registry.get_category("sword")).is_equal("weapon")
	assert_str(_registry.get_category("SWORD")).is_equal("weapon")  # Case insensitive
	assert_str(_registry.get_category("unknown")).is_equal("")


func test_subtype_without_category_rejected() -> void:
	var config: Dictionary = {
		"subtypes": {
			"invalid": {"display_name": "Invalid"}  # Missing category
		}
	}

	_registry.register_from_config("test_mod", config)

	assert_bool(_registry.is_valid_subtype("invalid")).is_false()


func test_replace_all_clears_previous() -> void:
	# First mod registers types
	var config1: Dictionary = {
		"categories": {"weapon": {"display_name": "Weapon"}},
		"subtypes": {"sword": {"category": "weapon"}}
	}
	_registry.register_from_config("mod1", config1)

	assert_bool(_registry.is_valid_subtype("sword")).is_true()

	# Second mod with replace_all
	var config2: Dictionary = {
		"replace_all": true,
		"categories": {"firearm": {"display_name": "Firearm"}},
		"subtypes": {"rifle": {"category": "firearm"}}
	}
	_registry.register_from_config("mod2", config2)

	# Old types should be gone
	assert_bool(_registry.is_valid_subtype("sword")).is_false()
	assert_bool(_registry.is_valid_category("weapon")).is_false()

	# New types should exist
	assert_bool(_registry.is_valid_subtype("rifle")).is_true()
	assert_bool(_registry.is_valid_category("firearm")).is_true()


func test_override_subtype_from_higher_priority_mod() -> void:
	# First mod registers sword in weapon category
	var config1: Dictionary = {
		"categories": {"weapon": {"display_name": "Weapon"}},
		"subtypes": {"sword": {"category": "weapon"}}
	}
	_registry.register_from_config("mod1", config1)

	assert_str(_registry.get_category("sword")).is_equal("weapon")
	assert_str(_registry.get_subtype_source_mod("sword")).is_equal("mod1")

	# Higher priority mod changes sword to melee category
	var config2: Dictionary = {
		"categories": {"melee": {"display_name": "Melee"}},
		"subtypes": {"sword": {"category": "melee"}}
	}
	_registry.register_from_config("mod2", config2)

	# Should use mod2's definition
	assert_str(_registry.get_category("sword")).is_equal("melee")
	assert_str(_registry.get_subtype_source_mod("sword")).is_equal("mod2")


# =============================================================================
# WILDCARD MATCHING TESTS
# =============================================================================

func test_matches_accept_type_direct() -> void:
	var config: Dictionary = {
		"categories": {"weapon": {"display_name": "Weapon"}},
		"subtypes": {"sword": {"category": "weapon"}}
	}
	_registry.register_from_config("test_mod", config)

	# Direct subtype match
	assert_bool(_registry.matches_accept_type("sword", "sword")).is_true()
	assert_bool(_registry.matches_accept_type("SWORD", "sword")).is_true()  # Case insensitive
	assert_bool(_registry.matches_accept_type("sword", "axe")).is_false()


func test_matches_accept_type_category_wildcard() -> void:
	var config: Dictionary = {
		"categories": {"weapon": {"display_name": "Weapon"}},
		"subtypes": {
			"sword": {"category": "weapon"},
			"axe": {"category": "weapon"},
			"bow": {"category": "weapon"}
		}
	}
	_registry.register_from_config("test_mod", config)

	# Category wildcard matches any subtype in that category
	assert_bool(_registry.matches_accept_type("sword", "weapon:*")).is_true()
	assert_bool(_registry.matches_accept_type("axe", "weapon:*")).is_true()
	assert_bool(_registry.matches_accept_type("bow", "weapon:*")).is_true()

	# Category itself matches wildcard
	assert_bool(_registry.matches_accept_type("weapon", "weapon:*")).is_true()


func test_matches_accept_type_wrong_category() -> void:
	var config: Dictionary = {
		"categories": {
			"weapon": {"display_name": "Weapon"},
			"accessory": {"display_name": "Accessory"}
		},
		"subtypes": {
			"sword": {"category": "weapon"},
			"ring": {"category": "accessory"}
		}
	}
	_registry.register_from_config("test_mod", config)

	# Ring is accessory, not weapon
	assert_bool(_registry.matches_accept_type("ring", "weapon:*")).is_false()
	assert_bool(_registry.matches_accept_type("ring", "accessory:*")).is_true()

	# Sword is weapon, not accessory
	assert_bool(_registry.matches_accept_type("sword", "accessory:*")).is_false()
	assert_bool(_registry.matches_accept_type("sword", "weapon:*")).is_true()


func test_matches_accept_type_unregistered_subtype() -> void:
	var config: Dictionary = {
		"categories": {"weapon": {"display_name": "Weapon"}},
		"subtypes": {"sword": {"category": "weapon"}}
	}
	_registry.register_from_config("test_mod", config)

	# Unregistered subtype doesn't match anything except direct
	assert_bool(_registry.matches_accept_type("laser", "weapon:*")).is_false()
	assert_bool(_registry.matches_accept_type("laser", "laser")).is_true()  # Direct match still works


# =============================================================================
# LOOKUP TESTS
# =============================================================================

func test_get_subtypes_for_category() -> void:
	var config: Dictionary = {
		"categories": {
			"weapon": {"display_name": "Weapon"},
			"accessory": {"display_name": "Accessory"}
		},
		"subtypes": {
			"sword": {"category": "weapon"},
			"axe": {"category": "weapon"},
			"ring": {"category": "accessory"}
		}
	}
	_registry.register_from_config("test_mod", config)

	var weapons: Array[String] = _registry.get_subtypes_for_category("weapon")
	assert_int(weapons.size()).is_equal(2)
	assert_bool("sword" in weapons).is_true()
	assert_bool("axe" in weapons).is_true()
	assert_bool("ring" in weapons).is_false()

	var accessories: Array[String] = _registry.get_subtypes_for_category("accessory")
	assert_int(accessories.size()).is_equal(1)
	assert_bool("ring" in accessories).is_true()


func test_get_all_categories() -> void:
	var config: Dictionary = {
		"categories": {
			"weapon": {"display_name": "Weapon"},
			"armor": {"display_name": "Armor"},
			"accessory": {"display_name": "Accessory"}
		}
	}
	_registry.register_from_config("test_mod", config)

	var categories: Array[String] = _registry.get_all_categories()
	assert_int(categories.size()).is_equal(3)
	assert_bool("weapon" in categories).is_true()
	assert_bool("armor" in categories).is_true()
	assert_bool("accessory" in categories).is_true()


func test_get_display_names() -> void:
	var config: Dictionary = {
		"categories": {"weapon": {"display_name": "Weapon"}},
		"subtypes": {"sword": {"category": "weapon", "display_name": "Sword"}}
	}
	_registry.register_from_config("test_mod", config)

	assert_str(_registry.get_subtype_display_name("sword")).is_equal("Sword")
	assert_str(_registry.get_category_display_name("weapon")).is_equal("Weapon")

	# Unknown types return capitalized version
	assert_str(_registry.get_subtype_display_name("unknown")).is_equal("Unknown")


func test_get_subtypes_grouped_by_category() -> void:
	var config: Dictionary = {
		"categories": {
			"weapon": {"display_name": "Weapon"},
			"accessory": {"display_name": "Accessory"}
		},
		"subtypes": {
			"sword": {"category": "weapon", "display_name": "Sword"},
			"axe": {"category": "weapon", "display_name": "Axe"},
			"ring": {"category": "accessory", "display_name": "Ring"}
		}
	}
	_registry.register_from_config("test_mod", config)

	var grouped: Dictionary = _registry.get_subtypes_grouped_by_category()

	assert_bool("weapon" in grouped).is_true()
	assert_bool("accessory" in grouped).is_true()
	assert_int(grouped["weapon"].size()).is_equal(2)
	assert_int(grouped["accessory"].size()).is_equal(1)


# =============================================================================
# VALIDATION TESTS
# =============================================================================

func test_validate_equipment_type_valid() -> void:
	var config: Dictionary = {
		"categories": {"weapon": {"display_name": "Weapon"}},
		"subtypes": {"sword": {"category": "weapon"}}
	}
	_registry.register_from_config("test_mod", config)

	var result: Dictionary = _registry.validate_equipment_type("sword")
	assert_bool(result.valid).is_true()
	assert_str(result.warning).is_equal("")


func test_validate_equipment_type_empty() -> void:
	var result: Dictionary = _registry.validate_equipment_type("")
	assert_bool(result.valid).is_true()  # Empty is valid (non-equippable item)


func test_validate_equipment_type_invalid() -> void:
	var config: Dictionary = {
		"categories": {"weapon": {"display_name": "Weapon"}},
		"subtypes": {"sword": {"category": "weapon"}}
	}
	_registry.register_from_config("test_mod", config)

	var result: Dictionary = _registry.validate_equipment_type("laser")
	assert_bool(result.valid).is_false()
	assert_bool(result.warning.length() > 0).is_true()


# =============================================================================
# CLEAR TESTS
# =============================================================================

func test_clear_mod_registrations() -> void:
	var config: Dictionary = {
		"categories": {"weapon": {"display_name": "Weapon"}},
		"subtypes": {"sword": {"category": "weapon"}}
	}
	_registry.register_from_config("test_mod", config)

	assert_bool(_registry.is_valid_subtype("sword")).is_true()
	assert_bool(_registry.is_valid_category("weapon")).is_true()

	_registry.clear_mod_registrations()

	assert_bool(_registry.is_valid_subtype("sword")).is_false()
	assert_bool(_registry.is_valid_category("weapon")).is_false()


func test_get_stats() -> void:
	var config: Dictionary = {
		"categories": {
			"weapon": {"display_name": "Weapon"},
			"accessory": {"display_name": "Accessory"}
		},
		"subtypes": {
			"sword": {"category": "weapon"},
			"axe": {"category": "weapon"},
			"ring": {"category": "accessory"}
		}
	}
	_registry.register_from_config("test_mod", config)

	var stats: Dictionary = _registry.get_stats()
	assert_int(stats.subtype_count).is_equal(3)
	assert_int(stats.category_count).is_equal(2)
