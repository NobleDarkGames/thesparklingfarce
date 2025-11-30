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

## Level-up celebration scene
const LEVEL_UP_SCENE: PackedScene = preload("res://scenes/ui/level_up_celebration.tscn")

## Victory/Defeat screens
const VICTORY_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/victory_screen.tscn")
const DEFEAT_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/defeat_screen.tscn")

## Combat results panel (shows XP gains after combat)
const COMBAT_RESULTS_SCENE: PackedScene = preload("res://scenes/ui/combat_results_panel.tscn")

## Timing constants for battle pacing (Shining Force-style)
const BATTLEFIELD_SETTLE_DELAY: float = 1.2  ## Pause after combat to let player read results
const RETURN_TO_MAP_DELAY: float = 2.0  ## Pause before transitioning back to map
const DEATH_FADE_DURATION: float = 0.5  ## How long unit fade-out takes on death

## Current combat animation instance
var combat_anim_instance: CombatAnimationScene = null

## Level-up queue for handling multiple level-ups in sequence
var _pending_level_ups: Array[Dictionary] = []
var _showing_level_up: bool = false

## XP entries queue for combat results panel
var _pending_xp_entries: Array[Dictionary] = []


## Initialize battle manager with scene references
func setup(battle_scene: Node, units_container: Node2D) -> void:
	battle_scene_root = battle_scene
	units_parent = units_container


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

	print("[FLOW] === BATTLE START: %s ===" % battle_data.battle_name)

	# 0. Set active mod for audio system
	_initialize_audio()

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


## Initialize audio system with mod path from battle data
func _initialize_audio() -> void:
	# Extract mod path from battle data resource path
	# Example: "res://mods/_sandbox/data/battles/battle_name.tres"
	var battle_path: String = current_battle_data.resource_path

	# Extract mod directory (format: res://mods/<mod_name>/)
	var mod_path: String = "res://mods/_sandbox"  # Default fallback

	if battle_path.begins_with("res://mods/"):
		var path_parts: PackedStringArray = battle_path.split("/")
		if path_parts.size() >= 3:
			# path_parts[0] = "res:"
			# path_parts[1] = ""
			# path_parts[2] = "mods"
			# path_parts[3] = "<mod_name>"
			mod_path = "res://mods/" + path_parts[3]

	AudioManager.set_active_mod(mod_path)

	# Start battle music
	AudioManager.play_music("battle_theme", 1.0)


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

	return grid


## Spawn all units from BattleData
func _spawn_all_units() -> void:
	# Spawn player units from PartyManager
	if not PartyManager.is_empty():
		# Get player spawn point from BattleData or use default
		var player_spawn_point: Vector2i = Vector2i(2, 2)  # Default position
		if current_battle_data.get("player_spawn_position") != null:
			player_spawn_point = current_battle_data.player_spawn_position

		# Get party spawn data from PartyManager
		var party_spawn_data: Array[Dictionary] = PartyManager.get_battle_spawn_data(player_spawn_point)

		# Spawn the party
		player_units = _spawn_units(party_spawn_data, "player")
	else:
		push_warning("BattleManager: No party members in PartyManager, no player units spawned")

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

	print("[FLOW] Units: %d player, %d enemy, %d neutral" % [
		player_units.size(), enemy_units.size(), neutral_units.size()])


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

		# Connect to unit death signal (avoid duplicate connections)
		if unit.has_signal("died"):
			var callback: Callable = _on_unit_died.bind(unit)
			if not unit.died.is_connected(callback):
				unit.died.connect(callback)

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

	# ExperienceManager signals
	if not ExperienceManager.unit_gained_xp.is_connected(_on_unit_gained_xp):
		ExperienceManager.unit_gained_xp.connect(_on_unit_gained_xp)

	if not ExperienceManager.unit_leveled_up.is_connected(_on_unit_leveled_up):
		ExperienceManager.unit_leveled_up.connect(_on_unit_leveled_up)

	if not ExperienceManager.unit_learned_ability.is_connected(_on_unit_learned_ability):
		ExperienceManager.unit_learned_ability.connect(_on_unit_learned_ability)


## Handle action selection from InputManager
func _on_action_selected(unit: Node2D, action: String) -> void:

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
	# Execute the queued action
	_execute_attack(unit, target)


## Execute Stay action (end turn)
func _execute_stay(unit: Node2D) -> void:

	# Reset InputManager to waiting state
	InputManager.reset_to_waiting()

	# End unit's turn
	TurnManager.end_unit_turn(unit)


## Execute attack from AI (called by AIBrain)
## This is the public API for AI brains to trigger attacks
func execute_ai_attack(attacker: Node2D, defender: Node2D) -> void:
	await _execute_attack(attacker, defender)


## Execute Attack action
func _execute_attack(attacker: Node2D, defender: Node2D) -> void:

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
			AudioManager.play_sfx("attack_critical", AudioManager.SFXCategory.COMBAT)
		else:
			AudioManager.play_sfx("attack_hit", AudioManager.SFXCategory.COMBAT)
	else:
		AudioManager.play_sfx("attack_miss", AudioManager.SFXCategory.COMBAT)

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

	# Award XP for combat (damage dealt and kill bonus)
	if not was_miss and damage > 0:
		# Check if defender died from the attack
		var got_kill: bool = false
		if defender.has_method("is_dead"):
			got_kill = defender.is_dead()
		elif defender.stats:
			got_kill = defender.stats.current_hp <= 0

		# Award combat XP to attacker and nearby allies
		ExperienceManager.award_combat_xp(attacker, defender, damage, got_kill)

		# Show combat results panel with XP gains
		await _show_combat_results()

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
	# Skip combat animation entirely in headless mode for faster automated testing
	if TurnManager.is_headless:
		return

	# Skip combat animation if GameJuice is set to MAP_ONLY mode
	if GameJuice.should_skip_combat_animation():
		return
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

	# Set animation speed from GameJuice settings
	combat_anim_instance.set_speed_multiplier(GameJuice.get_combat_speed_multiplier())

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

	# Battlefield "settle" period - give player time to see the result before next action
	# This visual breathing room is critical for Shining Force-style pacing
	await get_tree().create_timer(BATTLEFIELD_SETTLE_DELAY).timeout


## Handle unit death - called when unit.died signal is emitted
func _on_unit_died(unit: Node2D) -> void:

	# Visual feedback (fade out) - skip in headless mode
	if "modulate" in unit and not TurnManager.is_headless:
		var tween: Tween = create_tween()
		tween.tween_property(unit, "modulate:a", 0.0, DEATH_FADE_DURATION)
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

	# Call our death handler directly (Unit.take_damage already emits died signal)
	_on_unit_died(unit)


## Handle battle end
func _on_battle_ended(victory: bool) -> void:
	battle_active = false

	if victory:
		print("[FLOW] === BATTLE VICTORY ===")
		GameState.increment_campaign_data("battles_won")
	else:
		print("[FLOW] === BATTLE DEFEAT ===")

	battle_ended.emit(victory)

	# Wait for any pending level-up celebrations to finish before showing result screen
	# This prevents the victory/defeat screen from overlapping with level-up popups
	await _wait_for_level_ups()

	# Show result screen (skip in headless mode)
	var should_retry: bool = false
	if not TurnManager.is_headless:
		if victory:
			should_retry = await _show_victory_screen()
		else:
			should_retry = await _show_defeat_screen()

	# Handle retry request
	if should_retry:
		# TODO: Implement battle retry (reload current battle data)
		return

	# Return to map after battle (if we came from a map trigger)
	if GameState.has_return_data():
		# Set battle outcome in transition context
		var context: RefCounted = GameState.get_transition_context()
		if context:
			# Access enum via the context's script
			var TransitionContextScript: GDScript = context.get_script()
			if victory:
				context.battle_outcome = TransitionContextScript.BattleOutcome.VICTORY
			else:
				context.battle_outcome = TransitionContextScript.BattleOutcome.DEFEAT

			# Store completed battle ID for one-shot tracking
			if current_battle_data and current_battle_data.get("battle_id"):
				context.completed_battle_id = current_battle_data.battle_id

		TriggerManager.return_to_map()


## Show victory screen and wait for player to dismiss
## Returns false (victory never triggers retry)
func _show_victory_screen() -> bool:
	var gold_earned: int = 0
	# TODO: Calculate gold from defeated enemies

	var victory_screen: CanvasLayer = VICTORY_SCREEN_SCENE.instantiate()
	battle_scene_root.add_child(victory_screen)

	victory_screen.show_victory(gold_earned)
	await victory_screen.result_dismissed

	victory_screen.queue_free()
	return false


## Show defeat screen and wait for player choice
## Returns true if player chose to retry, false to return to town
func _show_defeat_screen() -> bool:
	var defeat_screen: CanvasLayer = DEFEAT_SCREEN_SCENE.instantiate()
	battle_scene_root.add_child(defeat_screen)

	var retry_chosen: bool = false

	# Connect to specific signals for player choice
	defeat_screen.retry_requested.connect(func() -> void: retry_chosen = true)
	defeat_screen.return_requested.connect(func() -> void: retry_chosen = false)

	defeat_screen.show_defeat()
	await defeat_screen.result_dismissed

	defeat_screen.queue_free()
	return retry_chosen


## Handle unit gaining XP
func _on_unit_gained_xp(unit: Node2D, amount: int, source: String) -> void:

	# Queue XP entry for combat results panel
	_pending_xp_entries.append({
		"unit_name": unit.get_display_name(),
		"amount": amount,
		"source": source
	})


## Handle unit level up
func _on_unit_leveled_up(unit: Node2D, old_level: int, new_level: int, stat_increases: Dictionary) -> void:
	print("[FLOW] LEVEL UP: %s Lv%d -> Lv%d" % [unit.get_display_name(), old_level, new_level])

	# Queue the level-up for display
	_pending_level_ups.append({
		"unit": unit,
		"old_level": old_level,
		"new_level": new_level,
		"stat_increases": stat_increases
	})

	# Process queue if not already showing a level-up
	if not _showing_level_up:
		_process_level_up_queue()


## Process queued level-ups one at a time
func _process_level_up_queue() -> void:
	if _pending_level_ups.is_empty():
		_showing_level_up = false
		return

	_showing_level_up = true
	var data: Dictionary = _pending_level_ups.pop_front()

	# Skip visual in headless mode
	if TurnManager.is_headless:
		_process_level_up_queue()
		return

	# Instantiate and show level-up celebration
	var celebration: CanvasLayer = LEVEL_UP_SCENE.instantiate()
	battle_scene_root.add_child(celebration)

	celebration.show_level_up(data.unit, data.old_level, data.new_level, data.stat_increases)
	await celebration.celebration_dismissed

	celebration.queue_free()

	# Process next in queue
	_process_level_up_queue()


## Wait for all pending level-up celebrations to finish
## Used before showing victory/defeat screens to prevent overlap
func _wait_for_level_ups() -> void:
	while _showing_level_up or not _pending_level_ups.is_empty():
		await get_tree().process_frame


## Handle unit learning ability
func _on_unit_learned_ability(unit: Node2D, ability: Resource) -> void:
	var ability_name: String = ability.ability_name if ability else "Unknown"
	print("[FLOW] %s learned: %s" % [unit.get_display_name(), ability_name])


## Show combat results panel with queued XP entries
func _show_combat_results() -> void:
	# Skip in headless mode
	if TurnManager.is_headless:
		_pending_xp_entries.clear()
		return

	# Skip if no entries
	if _pending_xp_entries.is_empty():
		return

	# Create and populate the results panel
	var results_panel: CanvasLayer = COMBAT_RESULTS_SCENE.instantiate()
	battle_scene_root.add_child(results_panel)

	# Add all queued entries
	for entry: Dictionary in _pending_xp_entries:
		results_panel.add_xp_entry(entry.unit_name, entry.amount, entry.source)

	# Clear the queue
	_pending_xp_entries.clear()

	# Show and wait for dismissal
	results_panel.show_results()
	await results_panel.results_dismissed

	results_panel.queue_free()


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
