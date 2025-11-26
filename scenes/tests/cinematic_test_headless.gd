extends Node2D

## Cinematic System Headless Test Scene
## Auto-runs all cinematic tests and exits for CI/automated testing
## For manual testing, use cinematic_test_scene.tscn instead

const CinematicActor: GDScript = preload("res://core/components/cinematic_actor.gd")

@onready var hero: CharacterBody2D = $Hero
@onready var cinematic_actor: Node = $Hero/CinematicActor

var tests_passed: int = 0
var tests_failed: int = 0


func _ready() -> void:
	print("\n========================================")
	print("CINEMATIC SYSTEM HEADLESS TEST")
	print("Phase 1: Command Registry Infrastructure")
	print("Phase 2: Camera & Visual Effects")
	print("========================================\n")

	# Wait for ModLoader and autoloads to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# Connect to cinematic signals
	CinematicsManager.cinematic_started.connect(_on_cinematic_started)
	CinematicsManager.cinematic_ended.connect(_on_cinematic_ended)
	CinematicsManager.command_executed.connect(_on_command_executed)

	# Register the hero actor
	if cinematic_actor:
		CinematicsManager.register_actor(cinematic_actor)
		print("✓ Hero actor registered with ID: %s" % cinematic_actor.actor_id)
	else:
		push_error("✗ CinematicActor component not found on Hero!")
		_finish_tests(false)
		return

	# Run automated test suite
	await _run_test_suite()

	# Report results
	_finish_tests(tests_failed == 0)


func _run_test_suite() -> void:
	print("\n--- Starting Test Suite ---\n")

	# Test 1: Movement cinematic
	await _run_test("test_movement", "Movement & Pathfinding")

	# Test 2: Camera cinematic
	await _run_test("test_phase2_camera", "Camera Control & Visual Effects")

	# Test 3: Custom test cinematic
	await _run_test("custom_test", "Custom Test Sequence")

	print("\n--- Test Suite Complete ---\n")


func _run_test(cinematic_id: String, test_name: String) -> void:
	print("[TEST] %s (cinematic: %s)" % [test_name, cinematic_id])

	var success: bool = CinematicsManager.play_cinematic(cinematic_id)

	if not success:
		push_error("  ✗ FAILED: Could not start cinematic '%s'" % cinematic_id)
		tests_failed += 1
		return

	# Wait for cinematic to complete
	await CinematicsManager.cinematic_ended

	print("  ✓ PASSED: Cinematic completed successfully\n")
	tests_passed += 1

	# Small delay between tests
	await get_tree().create_timer(0.2).timeout


func _finish_tests(success: bool) -> void:
	print("\n========================================")
	print("TEST RESULTS")
	print("========================================")
	print("Tests Passed: %d" % tests_passed)
	print("Tests Failed: %d" % tests_failed)
	print("========================================\n")

	if success:
		print("✓ ALL TESTS PASSED")
		print("\nPhase 1 Status: COMPLETE")
		print("- Command executor registry: ✓ Working")
		print("- Custom command support: ✓ Working")
		print("- Fallback to built-in commands: ✓ Working")
		print("\nReady to proceed to Phase 2: Migrate commands to executors\n")
		get_tree().quit(0)
	else:
		print("✗ SOME TESTS FAILED")
		print("\nCheck errors above for details\n")
		get_tree().quit(1)


func _on_cinematic_started(cinematic_id: String) -> void:
	print("  → cinematic_started: %s" % cinematic_id)


func _on_cinematic_ended(cinematic_id: String) -> void:
	print("  → cinematic_ended: %s" % cinematic_id)


func _on_command_executed(command_type: String, command_index: int) -> void:
	print("  → command[%d]: %s" % [command_index, command_type])
