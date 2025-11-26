extends Node

## Simple registry infrastructure test - Phase 1
## Just verifies the registry methods work without running a full cinematic

func _ready() -> void:
	print("\n=== PHASE 1: Registry Infrastructure Test ===\n")

	# Load test executor
	var TestExecutorScript: GDScript = load("res://test_print_executor.gd")
	if not TestExecutorScript:
		push_error("✗ Failed to load test executor script")
		get_tree().quit(1)
		return

	print("[1] Creating test executor instance...")
	var test_executor: RefCounted = TestExecutorScript.new()
	if not test_executor:
		push_error("✗ Failed to create executor instance")
		get_tree().quit(1)
		return
	print("✓ Test executor created")

	print("\n[2] Registering custom command type...")
	CinematicsManager.register_command_executor("test_command", test_executor)
	print("✓ Custom command registered")

	print("\n[3] Verifying registration...")
	if "test_command" in CinematicsManager._command_executors:
		print("✓ Command found in registry")
	else:
		push_error("✗ Command NOT in registry!")
		get_tree().quit(1)
		return

	print("\n[4] Unregistering command...")
	CinematicsManager.unregister_command_executor("test_command")
	if "test_command" not in CinematicsManager._command_executors:
		print("✓ Command successfully unregistered")
	else:
		push_error("✗ Command still in registry after unregister!")
		get_tree().quit(1)
		return

	print("\n=== Phase 1 Test: PASSED ===")
	print("Registry infrastructure is working correctly!")
	print("✓ CinematicCommandExecutor base class loads")
	print("✓ register_command_executor() works")
	print("✓ unregister_command_executor() works")
	print("✓ Registry dictionary access works")

	print("\nNext steps:")
	print("- Phase 2: Migrate built-in commands to executors")
	print("- Phase 3: Delegate to existing systems")
	print("- Phase 4: Testing and polish")

	get_tree().quit(0)
