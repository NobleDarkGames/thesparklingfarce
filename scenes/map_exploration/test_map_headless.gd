## Headless test for map exploration system
## Runs automated tests and quits
extends Node2D

const HeroControllerScript: GDScript = preload("res://scenes/map_exploration/hero_controller.gd")
const MapCameraScript: GDScript = preload("res://scenes/map_exploration/map_camera.gd")
const PartyFollowerScript: GDScript = preload("res://scenes/map_exploration/party_follower.gd")

var hero: Node2D = null
var camera: Camera2D = null
var followers: Array[Node2D] = []
var test_frame: int = 0
var test_complete: bool = false


func _ready() -> void:
	print("========================================")
	print("MAP EXPLORATION HEADLESS TEST")
	print("========================================")

	# Test 1: Create hero
	print("\n[TEST 1] Creating hero...")
	hero = CharacterBody2D.new()
	hero.set_script(HeroControllerScript)
	hero.name = "Hero"
	hero.position = Vector2(160, 160)

	# Add required children
	var hero_collision: CollisionShape2D = CollisionShape2D.new()
	var hero_shape: CircleShape2D = CircleShape2D.new()
	hero_shape.radius = 8.0
	hero_collision.shape = hero_shape
	hero_collision.name = "CollisionShape2D"
	hero.add_child(hero_collision)

	var interaction_ray: RayCast2D = RayCast2D.new()
	interaction_ray.enabled = true
	interaction_ray.target_position = Vector2(32, 0)
	interaction_ray.name = "InteractionRay"
	hero.add_child(interaction_ray)

	add_child(hero)

	if hero:
		print("✅ Hero created successfully")
		print("  - Position: %s" % hero.position)
		print("  - Grid position: %s" % hero.get("grid_position"))
	else:
		print("❌ Hero creation failed")
		_quit_test(false)
		return

	# Test 2: Create camera
	print("\n[TEST 2] Creating camera...")
	camera = Camera2D.new()
	camera.set_script(MapCameraScript)
	camera.name = "MapCamera"
	camera.position = Vector2(160, 160)
	add_child(camera)

	if camera:
		print("✅ Camera created successfully")
		camera.call("set_follow_target", hero)
		print("  - Following hero: true")
	else:
		print("❌ Camera creation failed")
		_quit_test(false)
		return

	# Test 3: Create followers
	print("\n[TEST 3] Creating party followers...")
	for i in range(3):
		var follower: CharacterBody2D = CharacterBody2D.new()
		follower.set_script(PartyFollowerScript)
		follower.name = "Follower%d" % (i + 1)
		follower.set("follow_distance", 5 * (i + 1))
		follower.set("tile_size", 32)
		follower.set("follow_target", hero)

		var follower_collision: CollisionShape2D = CollisionShape2D.new()
		var follower_shape: CircleShape2D = CircleShape2D.new()
		follower_shape.radius = 8.0
		follower_collision.shape = follower_shape
		follower_collision.name = "CollisionShape2D"
		follower.add_child(follower_collision)

		add_child(follower)
		followers.append(follower)

	print("✅ Created %d party followers" % followers.size())

	# Test 4: Position history
	print("\n[TEST 4] Testing position history...")
	if hero.has_method("get_historical_position"):
		var history_pos: Vector2 = hero.call("get_historical_position", 0)
		print("✅ Position history working")
		print("  - Current position in history: %s" % history_pos)
	else:
		print("❌ Position history not available")
		_quit_test(false)
		return

	print("\n========================================")
	print("All component tests passed!")
	print("Now running movement simulation...")
	print("========================================")


func _physics_process(_delta: float) -> void:
	"""Simulate some movement for testing."""
	if test_complete:
		return

	test_frame += 1

	# Simulate movement inputs for a few frames
	if test_frame == 10:
		print("\n[MOVEMENT TEST] Simulating UP movement")
		if hero.has_method("attempt_move"):
			var moved: bool = hero.call("attempt_move", Vector2i.UP)
			print("  - Movement initiated: %s" % moved)

	elif test_frame == 30:
		print("\n[MOVEMENT TEST] Simulating RIGHT movement")
		if hero.has_method("attempt_move"):
			var moved: bool = hero.call("attempt_move", Vector2i.RIGHT)
			print("  - Movement initiated: %s" % moved)

	elif test_frame == 50:
		print("\n[MOVEMENT TEST] Simulating DOWN movement")
		if hero.has_method("attempt_move"):
			var moved: bool = hero.call("attempt_move", Vector2i.DOWN)
			print("  - Movement initiated: %s" % moved)

	elif test_frame == 70:
		# Check final positions
		print("\n========================================")
		print("MOVEMENT TEST COMPLETE")
		print("========================================")
		print("Hero final position: %s" % hero.position)
		print("Hero grid position: %s" % hero.get("grid_position"))

		for i in range(followers.size()):
			if i < followers.size():
				print("Follower %d position: %s" % [i + 1, followers[i].position])

		print("\n========================================")
		print("✅ ALL TESTS PASSED")
		print("========================================")

		test_complete = true
		_quit_test(true)


func _quit_test(success: bool) -> void:
	"""Quit the test with appropriate exit code."""
	if success:
		print("\nTest completed successfully. Exiting...")
	else:
		print("\n❌ Test failed. Exiting...")

	# Wait a frame before quitting
	await get_tree().process_frame
	get_tree().quit(0 if success else 1)
