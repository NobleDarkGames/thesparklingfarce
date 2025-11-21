## BattleManager - High-level battle orchestration system
##
## Responsibilities:
## - Load BattleData from mods/ (content)
## - Instantiate map scenes
## - Spawn units at correct positions
## - Initialize GridManager, TurnManager, InputManager
## - Monitor victory/defeat conditions
## - Handle battle end (rewards, dialogue)
##
## IMPORTANT: This is ENGINE CODE (mechanics).
## BattleData, CharacterData, map scenes come from mods/ (content).
extends Node

## Signals for battle events
signal battle_started(battle_data: Resource)
signal battle_ended(victory: bool)
signal unit_spawned(unit: Node2D)
signal combat_resolved(attacker: Node2D, defender: Node2D, damage: int, hit: bool, crit: bool)

## Current battle data (loaded from mods/)
var current_battle_data: Resource = null

## Battle state
var battle_active: bool = false

## Unit tracking
var all_units: Array[Node2D] = []
var player_units: Array[Node2D] = []
var enemy_units: Array[Node2D] = []
var neutral_units: Array[Node2D] = []

## Scene references (set by battle scene)
var battle_scene_root: Node = null
var map_instance: Node2D = null
var units_parent: Node2D = null

## Unit scene template (preload for instantiation)
const UNIT_SCENE: PackedScene = preload("res://scenes/unit.tscn")

## Combat animation scene (preload for combat displays)
const COMBAT_ANIM_SCENE: PackedScene = preload("res://scenes/ui/combat_animation_scene.tscn")

## Current combat animation instance
var combat_anim_instance: CombatAnimationScene = null


## Initialize battle manager with scene references
func setup(battle_scene: Node, units_container: Node2D) -> void:
	battle_scene_root = battle_scene
	units_parent = units_container

	print("BattleManager: Setup complete")


## Start a battle from BattleData resource (loaded from mods/)
func start_battle(battle_data: Resource) -> void:
	if not battle_data:
		push_error("BattleManager: Cannot start battle with null BattleData")
		return

	# Validate BattleData has required properties
	if not _validate_battle_data(battle_data):
		push_error("BattleManager: BattleData validation failed")
		return

	current_battle_data = battle_data
	battle_active = true

	print("\n========================================")
	print("BattleManager: Starting battle - %s" % battle_data.battle_name)
	print("========================================\n")

	# 1. Load map scene (content from mods/)
	_load_map_scene()

	# 2. Initialize GridManager with map
	_initialize_grid()

	# 3. Spawn units from BattleData
	_spawn_all_units()

	# 4. Initialize TurnManager with all units
	TurnManager.start_battle(all_units)

	# 5. Connect signals for battle flow
	_connect_signals()

	# 6. Show pre-battle dialogue (TODO: Phase 4)
	# if battle_data.pre_battle_dialogue:
	#     await _show_dialogue(battle_data.pre_battle_dialogue)

	battle_started.emit(battle_data)

	print("BattleManager: Battle initialized successfully")


## Validate BattleData has required properties
func _validate_battle_data(data: Resource) -> bool:
	# Use BattleData's built-in validation if available
	if data.has_method("validate"):
		return data.validate()

	# Fallback: basic validation
	if data.get("battle_name") == null or data.battle_name.is_empty():
		push_error("BattleManager: BattleData missing battle_name")
		return false

	if data.get("map_scene") == null or data.map_scene == null:
		push_error("BattleManager: BattleData missing map_scene")
		return false

	return true


## Load and instantiate map scene from BattleData
func _load_map_scene() -> void:
	if current_battle_data.get("map_scene") == null:
		push_warning("BattleManager: No map_scene in BattleData, using default")
		return

	var map_scene: PackedScene = current_battle_data.map_scene
	if not map_scene:
		push_warning("BattleManager: map_scene is null")
		return

	map_instance = map_scene.instantiate()
	if battle_scene_root:
		battle_scene_root.add_child(map_instance)
		print("BattleManager: Map scene loaded")
	else:
		push_error("BattleManager: battle_scene_root not set, cannot add map")


## Initialize GridManager with map's tilemap
func _initialize_grid() -> void:
	if not map_instance:
		push_error("BattleManager: Cannot initialize grid without map_instance")
		return

	# Find TileMapLayer in map scene
	var tilemap: TileMapLayer = _find_tilemap_in_scene(map_instance)
	if not tilemap:
		push_warning("BattleManager: No TileMapLayer found in map scene")

	# Look for Grid resource in map scene (should be exported on map script or node)
	var grid: Resource = _find_grid_in_scene(map_instance)

	if not grid:
		push_error("BattleManager: Map scene must provide a Grid resource")
		return

	# Setup GridManager with grid from map
	GridManager.setup_grid(grid, tilemap)
	print("BattleManager: Grid initialized from map (%d x %d)" % [grid.grid_size.x, grid.grid_size.y])


## Find TileMapLayer in scene tree
func _find_tilemap_in_scene(node: Node) -> TileMapLayer:
	if node is TileMapLayer:
		return node

	for child in node.get_children():
		var result: TileMapLayer = _find_tilemap_in_scene(child)
		if result:
			return result

	return null


## Find Grid resource in map scene
## Map scenes should export a Grid resource (e.g., on root node script)
func _find_grid_in_scene(node: Node) -> Resource:
	# Check if the root node has a "grid" property
	if node.get("grid") != null:
		return node.grid

	# Check if any script attached to the node exports a grid
	if node.get_script():
		var script_vars: Array = node.get_script().get_script_property_list()
		for prop: Dictionary in script_vars:
			if prop.name == "grid" and prop.type == TYPE_OBJECT:
				return node.get(prop.name)

	# Fallback: create default grid based on tilemap size if available
	var tilemap: TileMapLayer = _find_tilemap_in_scene(node)
	if tilemap:
		return _create_grid_from_tilemap(tilemap)

	return null


## Create a Grid resource from TileMapLayer dimensions (fallback)
func _create_grid_from_tilemap(tilemap: TileMapLayer) -> Resource:
	var grid: Grid = Grid.new()

	# Get used rectangle of tilemap
	var used_rect: Rect2i = tilemap.get_used_rect()

	grid.grid_size = used_rect.size
	grid.cell_size = 32  # Default, could read from tilemap.tile_set

	print("BattleManager: Created grid from tilemap size: %s" % grid.grid_size)

	return grid


## Spawn all units from BattleData
func _spawn_all_units() -> void:
	# TODO Phase 4: Spawn player units from saved party
	# For now, test scenes spawn player units manually

	# Spawn enemy units
	if current_battle_data.get("enemies") != null:
		enemy_units = _spawn_units(current_battle_data.enemies, "enemy")

	# Spawn neutral units
	if current_battle_data.get("neutrals") != null:
		neutral_units = _spawn_units(current_battle_data.neutrals, "neutral")

	# Combine all units
	all_units.clear()
	all_units.append_array(player_units)
	all_units.append_array(enemy_units)
	all_units.append_array(neutral_units)

	print("BattleManager: Units spawned - %d player, %d enemy, %d neutral" % [
		player_units.size(),
		enemy_units.size(),
		neutral_units.size()
	])


## Spawn units from array of dictionaries
## Format: [{character: CharacterData, position: Vector2i, ai_brain: AIBrain}, ...]
func _spawn_units(unit_data: Array, faction: String) -> Array[Node2D]:
	var units: Array[Node2D] = []

	for data: Variant in unit_data:
		# Validate data structure
		if not data is Dictionary:
			push_warning("BattleManager: Invalid unit data (not a Dictionary)")
			continue

		if not "character" in data or not "position" in data:
			push_warning("BattleManager: Unit data missing character or position")
			continue

		var character_data: Resource = data.character
		var grid_pos: Vector2i = data.position
		var ai_brain: Resource = data.get("ai_brain", null)

		# Instantiate unit
		var unit: Node2D = UNIT_SCENE.instantiate()

		# Initialize unit with character data, faction, and AI brain
		if unit.has_method("initialize"):
			unit.initialize(character_data, faction, ai_brain)
		else:
			push_error("BattleManager: Unit scene missing initialize() method")
			unit.queue_free()
			continue

		# Position unit on grid
		unit.grid_position = grid_pos
		unit.position = GridManager.cell_to_world(grid_pos)

		# Add to scene
		if units_parent:
			units_parent.add_child(unit)
		else:
			push_error("BattleManager: units_parent not set")
			unit.queue_free()
			continue

		# Connect to unit death signal
		if unit.has_signal("died"):
			unit.died.connect(_on_unit_died.bind(unit))

		units.append(unit)
		unit_spawned.emit(unit)

	return units


## Connect signals for battle flow
func _connect_signals() -> void:
	# TurnManager signals
	if not TurnManager.battle_ended.is_connected(_on_battle_ended):
		TurnManager.battle_ended.connect(_on_battle_ended)

	# InputManager signals
	if not InputManager.action_selected.is_connected(_on_action_selected):
		InputManager.action_selected.connect(_on_action_selected)

	if not InputManager.target_selected.is_connected(_on_target_selected):
		InputManager.target_selected.connect(_on_target_selected)

	print("BattleManager: Signals connected")


## Handle action selection from InputManager
func _on_action_selected(unit: Node2D, action: String) -> void:
	print("BattleManager: Action selected - %s by %s" % [action, unit.get_display_name()])

	match action:
		"attack":
			# InputManager will handle targeting
			pass
		"magic":
			# TODO: Phase 4
			push_warning("BattleManager: Magic not yet implemented")
		"item":
			# TODO: Phase 4
			push_warning("BattleManager: Items not yet implemented")
		"stay":
			# End turn immediately
			_execute_stay(unit)


## Handle target selection from InputManager
func _on_target_selected(unit: Node2D, target: Node2D) -> void:
	print("BattleManager: Target selected - %s targets %s" % [
		unit.get_display_name(),
		target.get_display_name()
	])

	# Execute the queued action
	_execute_attack(unit, target)


## Execute Stay action (end turn)
func _execute_stay(unit: Node2D) -> void:
	print("BattleManager: %s chose Stay" % unit.get_display_name())

	# Reset InputManager to waiting state
	InputManager.reset_to_waiting()

	# End unit's turn
	TurnManager.end_unit_turn(unit)


## Execute attack from AI (called by AIBrain)
## This is the public API for AI brains to trigger attacks
func execute_ai_attack(attacker: Node2D, defender: Node2D) -> void:
	_execute_attack(attacker, defender)


## Execute Attack action
func _execute_attack(attacker: Node2D, defender: Node2D) -> void:
	print("\nBattleManager: Executing attack - %s -> %s" % [
		attacker.get_display_name(),
		defender.get_display_name()
	])

	# Get stats
	var attacker_stats: UnitStats = attacker.stats
	var defender_stats: UnitStats = defender.stats

	# Calculate hit chance
	var hit_chance: int = CombatCalculator.calculate_hit_chance(attacker_stats, defender_stats)

	# Roll to hit
	var was_miss: bool = not CombatCalculator.roll_hit(hit_chance)

	var damage: int = 0
	var was_critical: bool = false

	if not was_miss:
		# Calculate damage
		damage = CombatCalculator.calculate_physical_damage(attacker_stats, defender_stats)

		# Check for critical hit
		var crit_chance: int = CombatCalculator.calculate_crit_chance(attacker_stats, defender_stats)
		was_critical = CombatCalculator.roll_crit(crit_chance)

		if was_critical:
			damage *= 2
			print("  → CRITICAL HIT!")

		print("  → HIT! %d damage (%d%% hit chance)" % [damage, hit_chance])
	else:
		print("  → MISS! (%d%% chance)" % hit_chance)

	# Show combat animation
	await _show_combat_animation(attacker, defender, damage, was_critical, was_miss)

	# Apply damage after animation (if hit)
	if not was_miss:
		if defender.has_method("take_damage"):
			defender.take_damage(damage)
		else:
			# Fallback: apply damage directly
			defender_stats.current_hp -= damage
			defender_stats.current_hp = maxi(0, defender_stats.current_hp)

	# Emit combat result signal
	combat_resolved.emit(attacker, defender, damage, not was_miss, was_critical)

	# TODO: Counterattack (Phase 4)

	# Reset InputManager to waiting state ONLY if this unit is still the active unit
	# (prevents race condition where next turn has already started during the await)
	if TurnManager.active_unit == attacker:
		InputManager.reset_to_waiting()

	# End attacker's turn
	TurnManager.end_unit_turn(attacker)


## Show combat animation scene
func _show_combat_animation(
	attacker: Node2D,
	defender: Node2D,
	damage: int,
	was_critical: bool,
	was_miss: bool
) -> void:
	# HIDE the battlefield completely (Shining Force style - full screen replacement)
	if map_instance:
		map_instance.visible = false
	if units_parent:
		units_parent.visible = false

	# Also hide any UI elements
	var ui_node: Node = battle_scene_root.get_node_or_null("UI")
	if ui_node:
		ui_node.visible = false

	# Instantiate combat animation scene as full-screen replacement
	# (uses CanvasLayer with layer=100 to appear above everything)
	combat_anim_instance = COMBAT_ANIM_SCENE.instantiate()
	battle_scene_root.add_child(combat_anim_instance)

	# Play combat animation (scene handles its own fade-in)
	combat_anim_instance.play_combat_animation(attacker, defender, damage, was_critical, was_miss)
	await combat_anim_instance.animation_complete

	# Clean up combat animation
	combat_anim_instance.queue_free()
	combat_anim_instance = null

	# RESTORE the battlefield (Shining Force style - return to tactical view)
	if map_instance:
		map_instance.visible = true
	if units_parent:
		units_parent.visible = true
	if ui_node:
		ui_node.visible = true


## Handle unit death - called when unit.died signal is emitted
func _on_unit_died(unit: Node2D) -> void:
	print("BattleManager: Handling death of %s" % unit.get_display_name())

	# Visual feedback (fade out)
	if "modulate" in unit:
		var tween: Tween = create_tween()
		tween.tween_property(unit, "modulate:a", 0.0, 0.5)
		await tween.finished

	# Unit stays in scene but is marked dead
	# TurnManager will skip dead units
	# Note: GridManager already cleared by Unit before emitting signal


## Handle unit death (direct call - RARELY NEEDED)
## In most cases, Unit.take_damage() will automatically emit the died signal.
## This is only needed for special cases like instant death effects.
func _handle_unit_death(unit: Node2D) -> void:
	# Check if unit is actually dead
	if unit.has_method("is_dead") and not unit.is_dead():
		return

	# Manually trigger death if needed (Unit should emit died signal itself normally)
	if unit.has_method("_handle_death"):
		unit._handle_death()  # This will emit died signal
	else:
		# Fallback: call our handler directly
		_on_unit_died(unit)


## Handle battle end
func _on_battle_ended(victory: bool) -> void:
	battle_active = false

	print("\n========================================")
	if victory:
		print("VICTORY!")
	else:
		print("DEFEAT!")
	print("========================================\n")

	battle_ended.emit(victory)

	# TODO: Show victory/defeat dialogue
	# TODO: Award experience/items
	# TODO: Return to overworld


## Clean up battle
func end_battle() -> void:
	battle_active = false

	# Clear units
	for unit in all_units:
		if is_instance_valid(unit):
			unit.queue_free()

	all_units.clear()
	player_units.clear()
	enemy_units.clear()
	neutral_units.clear()

	# Remove map
	if map_instance and is_instance_valid(map_instance):
		map_instance.queue_free()
		map_instance = null

	current_battle_data = null

	print("BattleManager: Battle cleaned up")
