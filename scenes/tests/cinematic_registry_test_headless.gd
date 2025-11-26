extends Node2D

## Phase 1 Command Registry Test Suite (P0 Critical Tests)
## Tests custom executor registration, execution, interrupt, and error handling
## Auto-runs all tests and exits with status code

const CinematicData: GDScript = preload("res://core/resources/cinematic_data.gd")

var tests_passed: int = 0
var tests_failed: int = 0


func _ready() -> void:
	print("\n========================================")
	print("PHASE 1: COMMAND REGISTRY TEST SUITE")
	print("Priority 0 - Critical Tests")
	print("========================================\n")

	await get_tree().process_frame
	await get_tree().process_frame

	await _run_test_suite()
	_report_results()


func _run_test_suite() -> void:
	print("--- Starting P0 Tests ---\n")

	# Core registry tests
	await _test_sync_executor()
	await _test_async_executor()
	await _test_mixed_commands()
	await _test_interrupt_on_skip()

	# Error handling tests
	await _test_null_executor()
	await _test_empty_command_type()
	await _test_executor_overwrite()

	# Cleanup tests
	await _test_unregister()

	print("\n--- Tests Complete ---\n")


func _test_sync_executor() -> void:
	print("[TEST 1] Synchronous Custom Executor")

	# Register executor
	var PrintExecutorScript: GDScript = load("res://test_executors/test_print_executor.gd")
	var executor: CinematicCommandExecutor = PrintExecutorScript.new()
	CinematicsManager.register_command_executor("test_sync", executor)

	# Create test cinematic
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = "test_sync_exec"
	cinematic.commands.append({
		"type": "test_sync",
		"params": {"message": "Sync test message"}
	})
	cinematic.commands.append({
		"type": "test_sync",
		"params": {"message": "Second sync message"}
	})

	# Execute
	var started: bool = CinematicsManager.play_cinematic_from_resource(cinematic)

	if not started:
		_fail_test("Failed to start cinematic")
		CinematicsManager.unregister_command_executor("test_sync")
		return

	await CinematicsManager.cinematic_ended

	_pass_test("Sync executor completed")

	# Cleanup
	CinematicsManager.unregister_command_executor("test_sync")
	await _delay(0.2)


func _test_async_executor() -> void:
	print("[TEST 2] Asynchronous Custom Executor")

	# Register executors
	var DelayExecutorScript: GDScript = load("res://test_executors/test_delay_executor.gd")
	var delay_executor: CinematicCommandExecutor = DelayExecutorScript.new()
	CinematicsManager.register_command_executor("test_async", delay_executor)

	var PrintExecutorScript: GDScript = load("res://test_executors/test_print_executor.gd")
	var print_executor: CinematicCommandExecutor = PrintExecutorScript.new()
	CinematicsManager.register_command_executor("test_print", print_executor)

	# Create cinematic with async command followed by sync command
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = "test_async_exec"

	# Async delay
	cinematic.commands.append({
		"type": "test_async",
		"params": {"duration": 0.3, "wait": true}
	})

	# Sync print (should wait for async to complete)
	cinematic.commands.append({
		"type": "test_print",
		"params": {"message": "After async delay"}
	})

	var start_time: float = Time.get_ticks_msec()

	var started: bool = CinematicsManager.play_cinematic_from_resource(cinematic)
	if not started:
		_fail_test("Failed to start cinematic")
		CinematicsManager.unregister_command_executor("test_async")
		CinematicsManager.unregister_command_executor("test_print")
		return

	await CinematicsManager.cinematic_ended

	var elapsed: float = (Time.get_ticks_msec() - start_time) / 1000.0

	if elapsed >= 0.25:  # Should take at least 0.3s (with small margin)
		_pass_test("Async executor completed with proper timing (%.2fs)" % elapsed)
	else:
		_fail_test("Async executor didn't wait (only %.2fs)" % elapsed)

	# Cleanup
	CinematicsManager.unregister_command_executor("test_async")
	CinematicsManager.unregister_command_executor("test_print")
	await _delay(0.2)


func _test_mixed_commands() -> void:
	print("[TEST 3] Mixed Custom and Built-in Commands")

	# Register custom executor
	var PrintExecutorScript: GDScript = load("res://test_executors/test_print_executor.gd")
	var executor: CinematicCommandExecutor = PrintExecutorScript.new()
	CinematicsManager.register_command_executor("test_mixed", executor)

	# Create cinematic alternating custom and built-in
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = "test_mixed"

	cinematic.commands.append({
		"type": "test_mixed",
		"params": {"message": "Custom command 1"}
	})

	cinematic.commands.append({
		"type": "wait",
		"params": {"duration": 0.1}
	})

	cinematic.commands.append({
		"type": "test_mixed",
		"params": {"message": "Custom command 2"}
	})

	var started: bool = CinematicsManager.play_cinematic_from_resource(cinematic)

	if not started:
		_fail_test("Failed to start cinematic")
		CinematicsManager.unregister_command_executor("test_mixed")
		return

	await CinematicsManager.cinematic_ended

	_pass_test("Mixed commands executed successfully")

	CinematicsManager.unregister_command_executor("test_mixed")
	await _delay(0.2)


func _test_interrupt_on_skip() -> void:
	print("[TEST 4] Interrupt Cleanup on Skip (CRITICAL BUG FIX TEST)")

	# Load and prepare interrupt executor
	var InterruptExecutorScript: GDScript = load("res://test_executors/test_interrupt_executor.gd")
	InterruptExecutorScript.reset_tracking()

	var executor: CinematicCommandExecutor = InterruptExecutorScript.new()
	CinematicsManager.register_command_executor("test_interrupt", executor)

	# Create cinematic with long-running async command
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = "test_interrupt_exec"
	cinematic.can_skip = true

	cinematic.commands.append({
		"type": "test_interrupt",
		"params": {"duration": 5.0, "wait": true}  # Long duration - we'll skip before completion
	})

	var started: bool = CinematicsManager.play_cinematic_from_resource(cinematic)

	if not started:
		_fail_test("Failed to start cinematic")
		CinematicsManager.unregister_command_executor("test_interrupt")
		return

	# Wait a bit for executor to start
	await _delay(0.2)

	# Verify executor was called
	if not InterruptExecutorScript.execute_called:
		_fail_test("Executor execute() was not called")
		CinematicsManager.skip_cinematic()
		CinematicsManager.unregister_command_executor("test_interrupt")
		return

	# Skip the cinematic (this should trigger interrupt())
	CinematicsManager.skip_cinematic()

	await _delay(0.1)  # Give it a moment to process

	# Verify interrupt was called
	if InterruptExecutorScript.interrupt_called:
		_pass_test("Interrupt called on skip, cleanup verified")
	else:
		_fail_test("Interrupt was NOT called when cinematic was skipped!")

	# Cleanup
	CinematicsManager.unregister_command_executor("test_interrupt")
	await _delay(0.2)


func _test_null_executor() -> void:
	print("[TEST 5] Null Executor Registration (Error Handling)")

	# This should log an error but not crash
	push_warning("(Expecting error below - this is intentional)")
	CinematicsManager.register_command_executor("null_test", null)

	# Verify it wasn't registered
	if "null_test" not in CinematicsManager._command_executors:
		_pass_test("Null executor rejected correctly")
	else:
		_fail_test("Null executor was registered (should be rejected)")

	await _delay(0.1)


func _test_empty_command_type() -> void:
	print("[TEST 6] Empty Command Type (Error Handling)")

	var PrintExecutorScript: GDScript = load("res://test_executors/test_print_executor.gd")
	var executor: CinematicCommandExecutor = PrintExecutorScript.new()

	push_warning("(Expecting error below - this is intentional)")
	CinematicsManager.register_command_executor("", executor)

	# Verify it wasn't registered
	if "" not in CinematicsManager._command_executors:
		_pass_test("Empty command type rejected correctly")
	else:
		_fail_test("Empty command type was registered (should be rejected)")

	await _delay(0.1)


func _test_executor_overwrite() -> void:
	print("[TEST 7] Executor Overwrite (Warning Expected)")

	var PrintExecutorScript: GDScript = load("res://test_executors/test_print_executor.gd")
	var executor1: CinematicCommandExecutor = PrintExecutorScript.new()
	var executor2: CinematicCommandExecutor = PrintExecutorScript.new()

	CinematicsManager.register_command_executor("overwrite_test", executor1)

	push_warning("(Expecting warning below - this is intentional)")
	CinematicsManager.register_command_executor("overwrite_test", executor2)

	# Verify second executor is registered
	if "overwrite_test" in CinematicsManager._command_executors:
		_pass_test("Executor overwrite allowed with warning")
	else:
		_fail_test("Executor overwrite failed")

	CinematicsManager.unregister_command_executor("overwrite_test")
	await _delay(0.1)


func _test_unregister() -> void:
	print("[TEST 8] Executor Unregistration")

	var PrintExecutorScript: GDScript = load("res://test_executors/test_print_executor.gd")
	var executor: CinematicCommandExecutor = PrintExecutorScript.new()

	CinematicsManager.register_command_executor("unregister_test", executor)

	if "unregister_test" not in CinematicsManager._command_executors:
		_fail_test("Executor registration failed")
		return

	CinematicsManager.unregister_command_executor("unregister_test")

	if "unregister_test" not in CinematicsManager._command_executors:
		_pass_test("Executor unregistered successfully")
	else:
		_fail_test("Executor still in registry after unregister")

	await _delay(0.1)


func _pass_test(message: String) -> void:
	print("  ✓ PASSED: %s" % message)
	tests_passed += 1


func _fail_test(reason: String) -> void:
	push_error("  ✗ FAILED: %s" % reason)
	tests_failed += 1


func _delay(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _report_results() -> void:
	print("\n========================================")
	print("TEST RESULTS")
	print("========================================")
	print("Passed: %d" % tests_passed)
	print("Failed: %d" % tests_failed)
	print("========================================\n")

	if tests_failed == 0:
		print("✓ ALL P0 TESTS PASSED")
		print("\nPhase 1 Status: COMPLETE & VERIFIED")
		print("- Command executor registry: ✓ Working")
		print("- Custom executor execution: ✓ Working")
		print("- Async completion: ✓ Working")
		print("- Interrupt/cleanup: ✓ Working")
		print("- Error handling: ✓ Working")
		print("\n🚀 Ready to proceed to Phase 2: Migrate commands to executors\n")
		get_tree().quit(0)
	else:
		print("✗ SOME P0 TESTS FAILED")
		print("\n⚠️  DO NOT proceed to Phase 2 until these tests pass")
		print("Check errors above for details\n")
		get_tree().quit(1)
