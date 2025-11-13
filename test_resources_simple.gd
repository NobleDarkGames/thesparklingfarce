extends Node

## Simple test script for validating basic Resource loading
## This runs as a regular scene

var test_passed: int = 0
var test_failed: int = 0


func _ready() -> void:
	print("============================================================")
	print("The Sparkling Farce - Simple Resource Test")
	print("============================================================")

	_test_templates()

	print("============================================================")
	print("Test Results:")
	print("  Passed: ", test_passed)
	print("  Failed: ", test_failed)
	print("============================================================")

	if test_failed > 0:
		print("FAIL: Some tests failed!")
	else:
		print("SUCCESS: All tests passed!")

	get_tree().quit()


func _test_templates() -> void:
	print("\n[TEST] Loading Template Resources")

	# Test loading class templates
	var warrior_class: Resource = load("res://templates/warrior_class_template.tres")
	_assert(warrior_class != null, "Warrior class template should load")
	if warrior_class:
		_assert("display_name" in warrior_class, "Warrior class should have display_name property")
		print("  ✓ Warrior class loaded: ", warrior_class.get("display_name"))

	var mage_class: Resource = load("res://templates/mage_class_template.tres")
	_assert(mage_class != null, "Mage class template should load")
	if mage_class:
		print("  ✓ Mage class loaded: ", mage_class.get("display_name"))

	var archer_class: Resource = load("res://templates/archer_class_template.tres")
	_assert(archer_class != null, "Archer class template should load")
	if archer_class:
		print("  ✓ Archer class loaded: ", archer_class.get("display_name"))

	# Test loading item template
	var sword: Resource = load("res://templates/sword_item_template.tres")
	_assert(sword != null, "Sword item template should load")
	if sword:
		_assert("item_name" in sword, "Sword should have item_name property")
		print("  ✓ Sword loaded: ", sword.get("item_name"))

	# Test loading ability templates
	var heal: Resource = load("res://templates/healing_ability_template.tres")
	_assert(heal != null, "Healing ability template should load")
	if heal:
		print("  ✓ Heal ability loaded: ", heal.get("ability_name"))

	var attack: Resource = load("res://templates/attack_ability_template.tres")
	_assert(attack != null, "Attack ability template should load")
	if attack:
		print("  ✓ Attack ability loaded: ", attack.get("ability_name"))

	print("\n  All template resources loaded successfully!")


func _assert(condition: bool, message: String) -> void:
	if condition:
		test_passed += 1
	else:
		test_failed += 1
		print("  ✗ FAIL: ", message)
