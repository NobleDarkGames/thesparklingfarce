extends Node

## Test script to verify the cinematic command registry infrastructure
## This demonstrates how mods can add custom cinematic commands

# Preload required types
const CinematicData: GDScript = preload("res://core/resources/cinematic_data.gd")
const CinematicCommandExecutorBase: GDScript = preload("res://core/systems/cinematic_command_executor.gd")


func _ready() -> void:
	print("=== Testing Cinematic Command Registry ===")

	# Test 1: Register custom executors
	print("\n[Test 1] Registering custom executors...")

	# Load executor scripts
	var PrintExecutorScript: GDScript = load("res://test_print_executor.gd")
	var DelayExecutorScript: GDScript = load("res://test_delay_executor.gd")

	# Create and register executors
	CinematicsManager.register_command_executor("test_print", PrintExecutorScript.new())
	CinematicsManager.register_command_executor("test_delay", DelayExecutorScript.new())
	print("✓ Executors registered")

	# Test 2: Create a test cinematic with custom commands
	print("\n[Test 2] Creating test cinematic with custom commands...")
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = "test_registry"

	# Add custom commands
	cinematic.commands.append({
		"type": "test_print",
		"params": {
			"message": "Hello from custom command!",
			"wait": false
		}
	})

	cinematic.commands.append({
		"type": "test_delay",
		"params": {
			"duration": 0.5,
			"wait": true
		}
	})

	cinematic.commands.append({
		"type": "test_print",
		"params": {
			"message": "Delay completed! Registry test successful!",
			"wait": false
		}
	})

	print("✓ Test cinematic created with %d commands" % cinematic.commands.size())

	# Test 3: Connect to cinematic signals
	print("\n[Test 3] Connecting to cinematic signals...")
	CinematicsManager.cinematic_started.connect(_on_cinematic_started)
	CinematicsManager.cinematic_ended.connect(_on_cinematic_ended)
	CinematicsManager.command_executed.connect(_on_command_executed)
	print("✓ Signals connected")

	# Test 4: Execute the cinematic
	print("\n[Test 4] Playing test cinematic...")
	var success: bool = CinematicsManager.play_cinematic_from_resource(cinematic)
	if success:
		print("✓ Cinematic started successfully")
	else:
		push_error("✗ Failed to start cinematic")


func _on_cinematic_started(cinematic_id: String) -> void:
	print("→ Signal: cinematic_started(%s)" % cinematic_id)


func _on_cinematic_ended(cinematic_id: String) -> void:
	print("→ Signal: cinematic_ended(%s)" % cinematic_id)
	print("\n=== Registry Test Complete ===")
	print("Phase 1 infrastructure is working correctly!")

	# Cleanup
	CinematicsManager.unregister_command_executor("test_print")
	CinematicsManager.unregister_command_executor("test_delay")

	# Exit after a short delay
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func _on_command_executed(command_type: String, command_index: int) -> void:
	print("→ Signal: command_executed(%s, %d)" % [command_type, command_index])
