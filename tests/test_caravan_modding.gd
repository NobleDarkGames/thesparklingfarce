extends Node

## Test script to verify Caravan Phase 3 modding support
## Run with: godot --headless --path . res://tests/test_caravan_modding.tscn

var tests_passed: int = 0
var tests_failed: int = 0


func _ready() -> void:
	# Wait a frame for autoloads to fully initialize
	await get_tree().process_frame
	await get_tree().process_frame
	_run_tests()


func _run_tests() -> void:
	print("\n" + "=".repeat(60))
	print("CARAVAN PHASE 3 VERIFICATION TESTS")
	print("=".repeat(60) + "\n")

	# Test 1: Verify mod override of caravan data
	test_caravan_data_override()

	# Test 2: Verify rest service status from overridden config
	test_rest_service_enabled()

	# Test 3: Verify caravan_config parsing from mod.json
	test_caravan_config_parsing()

	# Test 4: Verify custom services registration
	test_custom_services_registration()

	# Test 5: Verify caravan can be disabled via mod config
	test_caravan_disable_via_config()

	# Print summary
	print("\n" + "=".repeat(60))
	print("TEST SUMMARY: %d passed, %d failed" % [tests_passed, tests_failed])
	print("=".repeat(60) + "\n")

	# Exit with appropriate code
	if tests_failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func assert_true(condition: bool, message: String) -> bool:
	if condition:
		print("  ✓ PASS: %s" % message)
		tests_passed += 1
		return true
	else:
		print("  ✗ FAIL: %s" % message)
		tests_failed += 1
		return false


func assert_false(condition: bool, message: String) -> bool:
	return assert_true(not condition, message)


func assert_equal(actual: Variant, expected: Variant, message: String) -> bool:
	if actual == expected:
		print("  ✓ PASS: %s (got: %s)" % [message, str(actual)])
		tests_passed += 1
		return true
	else:
		print("  ✗ FAIL: %s (expected: %s, got: %s)" % [message, str(expected), str(actual)])
		tests_failed += 1
		return false


func test_caravan_data_override() -> void:
	print("\n[TEST 1] Caravan Data Override")
	print("-".repeat(40))

	# Check that CaravanController loaded the test_caravan config instead of default
	if not CaravanController:
		print("  ✗ FAIL: CaravanController autoload not available")
		tests_failed += 1
		return

	var config: Resource = CaravanController.current_config
	assert_true(config != null, "CaravanController has a current_config")

	if config:
		# _sandbox mod (priority 100) specifies caravan_data_id: "test_caravan"
		# This should override _base_game's default_caravan (priority 0)
		assert_equal(config.caravan_id, "test_caravan", "Caravan ID is 'test_caravan' (sandbox override)")
		assert_equal(config.display_name, "Test Caravan (Sandbox)", "Display name matches test caravan")
		assert_equal(config.wagon_scale, Vector2(1.5, 1.5), "Wagon scale is 1.5x (sandbox config)")
		assert_equal(config.follow_distance_tiles, 2, "Follow distance is 2 (sandbox config)")


func test_rest_service_enabled() -> void:
	print("\n[TEST 2] Rest Service Enabled via Override")
	print("-".repeat(40))

	if not CaravanController:
		print("  ✗ FAIL: CaravanController autoload not available")
		tests_failed += 1
		return

	var config: Resource = CaravanController.current_config
	if not config:
		print("  ✗ FAIL: No caravan config loaded")
		tests_failed += 1
		return

	# default_caravan has has_rest_service = false
	# test_caravan has has_rest_service = true
	# Since _sandbox overrides with test_caravan, rest should be enabled
	assert_true(config.has_rest_service, "Rest service is ENABLED (test_caravan override)")

	# Also verify default would have it disabled by checking the data directly
	var default_config: Resource = ModLoader.registry.get_resource("caravan", "default_caravan")
	if default_config:
		assert_false(default_config.has_rest_service, "default_caravan has rest service DISABLED (baseline)")


func test_caravan_config_parsing() -> void:
	print("\n[TEST 3] Caravan Config Parsing from mod.json")
	print("-".repeat(40))

	if not ModLoader:
		print("  ✗ FAIL: ModLoader autoload not available")
		tests_failed += 1
		return

	# Get the sandbox mod manifest
	var sandbox_manifest: ModManifest = ModLoader.get_mod("sandbox")
	assert_true(sandbox_manifest != null, "Sandbox mod manifest loaded")

	if sandbox_manifest:
		# Verify caravan_config was parsed
		assert_false(sandbox_manifest.caravan_config.is_empty(), "caravan_config is not empty")

		if not sandbox_manifest.caravan_config.is_empty():
			assert_equal(
				sandbox_manifest.caravan_config.get("caravan_data_id", ""),
				"test_caravan",
				"caravan_data_id parsed as 'test_caravan'"
			)


func test_custom_services_registration() -> void:
	print("\n[TEST 4] Custom Services Registration")
	print("-".repeat(40))

	if not CaravanController:
		print("  ✗ FAIL: CaravanController autoload not available")
		tests_failed += 1
		return

	# Note: _sandbox doesn't currently define custom_services, so this tests the mechanism
	# The _custom_services dictionary should exist and be accessible
	var has_custom_services_dict: bool = "_custom_services" in CaravanController
	assert_true(has_custom_services_dict, "_custom_services dictionary exists on CaravanController")

	# Test that the registration method exists
	var has_register_method: bool = CaravanController.has_method("_register_custom_service")
	assert_true(has_register_method, "_register_custom_service method exists")

	# Test manual registration (simulating what a mod would do)
	if has_custom_services_dict:
		var initial_count: int = CaravanController._custom_services.size()

		# Manually test registration
		CaravanController._register_custom_service(
			"test_service",
			{"scene_path": "scenes/test.tscn", "display_name": "Test Service"},
			"res://mods/_sandbox"
		)

		var after_count: int = CaravanController._custom_services.size()
		assert_equal(after_count, initial_count + 1, "Custom service was registered")

		if "test_service" in CaravanController._custom_services:
			var service: Dictionary = CaravanController._custom_services["test_service"]
			assert_equal(service.get("display_name", ""), "Test Service", "Custom service display_name correct")

			# Clean up
			CaravanController._custom_services.erase("test_service")


func test_caravan_disable_via_config() -> void:
	print("\n[TEST 5] Caravan Disable via Config")
	print("-".repeat(40))

	if not CaravanController:
		print("  ✗ FAIL: CaravanController autoload not available")
		tests_failed += 1
		return

	# Test that the enabled property exists and is currently true
	# (since _sandbox doesn't set enabled: false)
	assert_true(CaravanController.enabled, "Caravan is currently enabled")

	# Test the disable() method
	CaravanController.disable()
	assert_false(CaravanController.enabled, "Caravan disabled after calling disable()")

	# Test the enable() method
	CaravanController.enable()
	assert_true(CaravanController.enabled, "Caravan re-enabled after calling enable()")

	# Verify that a mod setting enabled: false would work
	# We'll simulate this by temporarily modifying the config and reloading
	print("  → Testing mod config 'enabled: false' simulation...")

	# Get sandbox manifest and temporarily add enabled: false
	var sandbox_manifest: ModManifest = ModLoader.get_mod("sandbox") if ModLoader else null
	if sandbox_manifest:
		var original_config: Dictionary = sandbox_manifest.caravan_config.duplicate()

		# Simulate enabled: false
		sandbox_manifest.caravan_config["enabled"] = false

		# Reload caravan config
		CaravanController.reload_config()

		assert_false(CaravanController.enabled, "Caravan disabled after reload with enabled: false")

		# Restore original config
		sandbox_manifest.caravan_config = original_config
		CaravanController.reload_config()

		assert_true(CaravanController.enabled, "Caravan re-enabled after restoring config")
	else:
		print("  ⚠ SKIP: Could not get sandbox manifest for simulation test")
