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
##
## SF2 AUTHENTIC COMBAT SESSIONS:
## Combat now uses a session-based approach where the battle screen stays open
## for the entire combat exchange (Initial -> Double -> Counter), eliminating
## jarring fade transitions between phases.
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

	# TODO: Phase 4 - Show pre-battle dialogue

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

	if not InputManager.item_use_requested.is_connected(_on_item_use_requested):
		InputManager.item_use_requested.connect(_on_item_use_requested)

	if not InputManager.spell_cast_requested.is_connected(_on_spell_cast_requested):
		InputManager.spell_cast_requested.connect(_on_spell_cast_requested)

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
			# InputManager handles spell menu - nothing to do here
			# Spell cast is handled via _on_spell_cast_requested signal
			pass
		"item":
			# InputManager handles item menu - nothing to do here
			# Item use is handled via _on_item_use_requested signal
			pass
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


## Handle item use request from InputManager
func _on_item_use_requested(unit: Node2D, item_id: String, target: Node2D) -> void:
	# Get the item data
	var item: ItemData = ModLoader.registry.get_resource("item", item_id) as ItemData

	if not item:
		push_warning("BattleManager: Item '%s' not found in registry" % item_id)
		InputManager.reset_to_waiting()
		TurnManager.end_unit_turn(unit)
		return

	# Apply the item effect
	var effect_applied: bool = false
	if item.effect and item.effect is AbilityData:
		var ability: AbilityData = item.effect as AbilityData
		effect_applied = await _apply_item_effect(unit, target, item, ability)

	if effect_applied:
		# Consume item from inventory
		_consume_item_from_inventory(unit, item_id)

		# Award XP for item usage (SF-authentic: healers get more XP)
		_award_item_use_xp(unit, target, item)

	# Reset InputManager to waiting state
	InputManager.reset_to_waiting()

	# End unit's turn
	TurnManager.end_unit_turn(unit)


## Apply item effect to target
## Returns true if effect was successfully applied
func _apply_item_effect(user: Node2D, target: Node2D, item: ItemData, ability: AbilityData) -> bool:
	match ability.ability_type:
		AbilityData.AbilityType.HEAL:
			return await _apply_healing_effect(user, target, ability)
		AbilityData.AbilityType.ATTACK:
			return await _apply_damage_effect(user, target, ability)
		AbilityData.AbilityType.SUPPORT:
			# TODO: Implement buff effects
			push_warning("BattleManager: Support effects not yet implemented")
			return false
		AbilityData.AbilityType.DEBUFF:
			# TODO: Implement debuff effects
			push_warning("BattleManager: Debuff effects not yet implemented")
			return false
		AbilityData.AbilityType.SPECIAL:
			# TODO: Implement special effects
			push_warning("BattleManager: Special effects not yet implemented")
			return false
		_:
			push_warning("BattleManager: Unknown ability type")
			return false


## Apply healing effect to target
func _apply_healing_effect(user: Node2D, target: Node2D, ability: AbilityData) -> bool:
	if not target or not target.stats:
		push_warning("BattleManager: Invalid target for healing")
		return false

	var stats: UnitStats = target.stats
	var max_hp: int = stats.max_hp

	# Calculate healing amount
	var heal_amount: int = ability.power

	# Apply healing (cap at max HP)
	stats.current_hp = mini(stats.current_hp + heal_amount, max_hp)

	# Play healing sound
	AudioManager.play_sfx("heal", AudioManager.SFXCategory.COMBAT)

	# TODO: Show healing animation/visual effect
	# For now, just flash the target green briefly
	if not TurnManager.is_headless and target.has_method("flash_color"):
		target.flash_color(Color.GREEN, 0.3)

	# Brief pause for player feedback
	if not TurnManager.is_headless:
		await get_tree().create_timer(0.5).timeout

	return true


## Apply damage effect to target (for offensive items)
func _apply_damage_effect(user: Node2D, target: Node2D, ability: AbilityData) -> bool:
	if not target or not target.stats:
		push_warning("BattleManager: Invalid target for damage")
		return false

	# Calculate damage (simplified - no defense calculation for items)
	var damage: int = ability.power

	# Apply damage
	if target.has_method("take_damage"):
		target.take_damage(damage)
	else:
		target.stats.current_hp -= damage
		target.stats.current_hp = maxi(0, target.stats.current_hp)

	# Play attack sound
	AudioManager.play_sfx("attack_hit", AudioManager.SFXCategory.COMBAT)

	# Brief pause for player feedback
	if not TurnManager.is_headless:
		await get_tree().create_timer(0.5).timeout

	return true


## Consume item from unit's inventory
func _consume_item_from_inventory(unit: Node2D, item_id: String) -> void:
	if not unit.character_data:
		push_warning("BattleManager: Unit has no character_data, cannot consume item")
		return

	# Get character's save data from PartyManager
	var char_uid: String = unit.character_data.character_uid
	if PartyManager.has_method("remove_item_from_member"):
		var removed: bool = PartyManager.remove_item_from_member(char_uid, item_id)
		if not removed:
			push_warning("BattleManager: Failed to remove item from inventory")
	else:
		push_warning("BattleManager: PartyManager.remove_item_from_member() not available")


## Award XP for item usage (SF-authentic)
## Healers get 10 XP, non-healers get 1 XP
func _award_item_use_xp(user: Node2D, target: Node2D, item: ItemData) -> void:
	if not user or not user.character_data:
		return

	# Check if user is a "healer" class (has healing abilities naturally)
	var is_healer: bool = false
	var class_data: ClassData = user.get_current_class()
	if class_data:
		# Check if class has any heal-type abilities
		if class_data.has_method("get_abilities"):
			var abilities: Array = class_data.get_abilities()
			for ability_res: Resource in abilities:
				if ability_res is AbilityData and (ability_res as AbilityData).ability_type == AbilityData.AbilityType.HEAL:
					is_healer = true
					break

	# Award XP based on whether user is a healer
	var xp_amount: int = 10 if is_healer else 1

	# Award through ExperienceManager (using support XP for item usage)
	ExperienceManager.award_support_xp(user, "item_use", target, xp_amount)


# =============================================================================
# SPELL CASTING SYSTEM
# =============================================================================

## Handle spell cast request from InputManager
func _on_spell_cast_requested(caster: Node2D, ability_id: String, target: Node2D) -> void:
	# Get the ability data from registry
	var ability: AbilityData = ModLoader.registry.get_resource("ability", ability_id) as AbilityData

	if not ability:
		push_warning("BattleManager: Ability '%s' not found in registry" % ability_id)
		InputManager.reset_to_waiting()
		TurnManager.end_unit_turn(caster)
		return

	# Check and deduct MP cost
	if not caster.stats:
		push_error("BattleManager: Caster has no stats")
		InputManager.reset_to_waiting()
		TurnManager.end_unit_turn(caster)
		return

	if caster.stats.current_mp < ability.mp_cost:
		push_warning("BattleManager: Insufficient MP for spell '%s'" % ability_id)
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		InputManager.reset_to_waiting()
		TurnManager.end_unit_turn(caster)
		return

	# Deduct MP cost
	caster.stats.current_mp -= ability.mp_cost

	# Refresh stats panel to show updated MP
	InputManager.refresh_stats_panel()

	# Apply the spell effect based on type
	var effect_applied: bool = false
	match ability.ability_type:
		AbilityData.AbilityType.HEAL:
			effect_applied = await _apply_spell_heal(caster, target, ability)
		AbilityData.AbilityType.ATTACK:
			effect_applied = await _apply_spell_damage(caster, target, ability)
		AbilityData.AbilityType.SUPPORT:
			# TODO: Implement buff effects
			push_warning("BattleManager: Support spell effects not yet implemented")
			effect_applied = false
		AbilityData.AbilityType.DEBUFF:
			# TODO: Implement debuff effects
			push_warning("BattleManager: Debuff spell effects not yet implemented")
			effect_applied = false
		AbilityData.AbilityType.STATUS:
			# TODO: Implement status effects
			push_warning("BattleManager: Status spell effects not yet implemented")
			effect_applied = false
		_:
			push_warning("BattleManager: Unknown spell type")
			effect_applied = false

	if effect_applied:
		# Award XP for spell casting (SF2-authentic: casters get XP for casting)
		_award_spell_xp(caster, target, ability)

	# Reset InputManager to waiting state
	InputManager.reset_to_waiting()

	# End caster's turn
	TurnManager.end_unit_turn(caster)


## Apply healing spell effect
func _apply_spell_heal(caster: Node2D, target: Node2D, ability: AbilityData) -> bool:
	if not target or not target.stats:
		push_warning("BattleManager: Invalid target for healing spell")
		return false

	var stats: UnitStats = target.stats
	var max_hp: int = stats.max_hp

	# Calculate healing amount using CombatCalculator
	var heal_amount: int = CombatCalculator.calculate_healing(caster.stats, ability)

	# Apply healing (cap at max HP)
	var old_hp: int = stats.current_hp
	stats.current_hp = mini(stats.current_hp + heal_amount, max_hp)
	var actual_heal: int = stats.current_hp - old_hp

	# Play healing sound
	AudioManager.play_sfx("heal", AudioManager.SFXCategory.COMBAT)

	# Visual feedback (flash green)
	if not TurnManager.is_headless and target.has_method("flash_color"):
		target.flash_color(Color.GREEN, 0.3)

	# Brief pause for player feedback
	if not TurnManager.is_headless:
		await get_tree().create_timer(0.5).timeout

	return true


## Apply damage spell effect via combat screen
func _apply_spell_damage(caster: Node2D, target: Node2D, ability: AbilityData) -> bool:
	if not target or not target.stats:
		push_warning("BattleManager: Invalid target for damage spell")
		return false

	# Calculate magic damage using CombatCalculator
	var damage: int = CombatCalculator.calculate_magic_damage(caster.stats, target.stats, ability)

	# Build spell combat phase (spells cannot be countered or trigger double attacks)
	var phases: Array[CombatPhase] = []
	var spell_phase: CombatPhase = CombatPhase.create_spell_attack(caster, target, damage)
	phases.append(spell_phase)

	# Debug output for spell combat
	print("[BattleManager] Spell combat: %s casts %s on %s for %d damage" % [
		caster.get_display_name(),
		ability.ability_name,
		target.get_display_name(),
		damage
	])

	# Execute combat session (shows combat screen, applies damage, handles death)
	await _execute_combat_session(caster, target, phases)

	return true


## Award XP for spell casting (SF2-authentic)
## Healing spells award XP based on amount healed
## Damage spells award XP based on damage dealt
func _award_spell_xp(caster: Node2D, target: Node2D, ability: AbilityData) -> void:
	if not caster or not caster.character_data:
		return

	# Calculate XP based on spell type
	var xp_amount: int = 0
	var xp_source: String = "spell_cast"

	match ability.ability_type:
		AbilityData.AbilityType.HEAL:
			# Healers get XP for healing (SF2-authentic)
			xp_amount = 10
			xp_source = "heal_spell"
		AbilityData.AbilityType.ATTACK:
			# Damage spells award XP based on enemy level differential
			if target and target.stats:
				var caster_level: int = caster.stats.level if caster.stats else 1
				var target_level: int = target.stats.level if target.stats else 1
				xp_amount = CombatCalculator.calculate_experience_gain(caster_level, target_level, 8)
				xp_source = "attack_spell"
		_:
			xp_amount = 5
			xp_source = "spell_cast"

	if xp_amount > 0:
		ExperienceManager.award_support_xp(caster, xp_source, target, xp_amount)


## Execute attack from AI (called by AIBrain)
## This is the public API for AI brains to trigger attacks
func execute_ai_attack(attacker: Node2D, defender: Node2D) -> void:
	await _execute_attack(attacker, defender)


# =============================================================================
# SF2 AUTHENTIC COMBAT SESSION SYSTEM
# =============================================================================

## Execute Attack action using the new session-based combat system
## SF-AUTHENTIC: All phases (initial, double, counter) execute in a SINGLE
## battle screen session - one fade in, one fade out, no jarring transitions.
func _execute_attack(attacker: Node2D, defender: Node2D) -> void:
	# Build the complete combat sequence BEFORE opening the battle screen
	var phases: Array[CombatPhase] = _build_combat_sequence(attacker, defender)

	# Debug output for combat sequence
	print("[BattleManager] Combat sequence built with %d phases:" % phases.size())
	for phase: CombatPhase in phases:
		print("  - %s" % phase.get_description())

	# Execute the combat session (single fade-in, all phases, single fade-out)
	await _execute_combat_session(attacker, defender, phases)

	# Reset InputManager to waiting state ONLY if this unit is still the active unit
	if TurnManager.active_unit == attacker:
		InputManager.reset_to_waiting()

	# End attacker's turn
	TurnManager.end_unit_turn(attacker)


## Build the complete combat sequence by pre-calculating all phases
## Order: Initial Attack -> Double Attack (if any) -> Counter (if any)
func _build_combat_sequence(attacker: Node2D, defender: Node2D) -> Array[CombatPhase]:
	var phases: Array[CombatPhase] = []

	# Get terrain bonuses for defender's position
	var terrain_defense: int = 0
	var terrain_evasion: int = 0
	var defender_terrain: TerrainData = GridManager.get_terrain_at_cell(defender.grid_position)
	if defender_terrain:
		terrain_defense = defender_terrain.defense_bonus
		terrain_evasion = defender_terrain.evasion_bonus

	# =========================================================================
	# PHASE 1: Initial Attack
	# =========================================================================
	var initial_phase: CombatPhase = _calculate_attack_phase(
		attacker, defender, terrain_defense, terrain_evasion, false, false
	)
	phases.append(initial_phase)

	# Track defender HP for death checks (we'll simulate damage for phase building)
	var simulated_defender_hp: int = defender.stats.current_hp
	var defender_would_die: bool = false

	if not initial_phase.was_miss and initial_phase.damage > 0:
		simulated_defender_hp -= initial_phase.damage
		defender_would_die = simulated_defender_hp <= 0

	# =========================================================================
	# PHASE 2: Double Attack (if applicable and defender still alive)
	# =========================================================================
	if not initial_phase.was_miss and not defender_would_die:
		var should_double_attack: bool = _check_double_attack(attacker)
		if should_double_attack:
			var double_phase: CombatPhase = _calculate_attack_phase(
				attacker, defender, terrain_defense, terrain_evasion, false, true
			)
			phases.append(double_phase)

			# Update simulated HP
			if not double_phase.was_miss and double_phase.damage > 0:
				simulated_defender_hp -= double_phase.damage
				defender_would_die = simulated_defender_hp <= 0

	# =========================================================================
	# PHASE 3: Counter Attack (if defender survives and can counter)
	# =========================================================================
	if not defender_would_die:
		# Get terrain bonuses for attacker's position (they're the counter target)
		var attacker_terrain_defense: int = 0
		var attacker_terrain_evasion: int = 0
		var attacker_terrain: TerrainData = GridManager.get_terrain_at_cell(attacker.grid_position)
		if attacker_terrain:
			attacker_terrain_defense = attacker_terrain.defense_bonus
			attacker_terrain_evasion = attacker_terrain.evasion_bonus

		# Check if counter is possible
		var counter_possible: bool = _can_counterattack(attacker, defender)

		if counter_possible:
			# Calculate counter attack (defender attacks attacker, 75% damage)
			var counter_phase: CombatPhase = _calculate_counter_phase(
				defender, attacker, attacker_terrain_defense, attacker_terrain_evasion
			)
			if counter_phase:
				phases.append(counter_phase)

	return phases


## Calculate a single attack phase (initial or double attack)
func _calculate_attack_phase(
	attacker: Node2D,
	defender: Node2D,
	terrain_defense: int,
	terrain_evasion: int,
	is_counter: bool,
	is_double: bool
) -> CombatPhase:
	var attacker_stats: UnitStats = attacker.stats
	var defender_stats: UnitStats = defender.stats

	# Calculate hit chance
	var hit_chance: int = CombatCalculator.calculate_hit_chance_with_terrain(
		attacker_stats, defender_stats, terrain_evasion
	)
	var was_miss: bool = not CombatCalculator.roll_hit(hit_chance)

	var damage: int = 0
	var was_critical: bool = false

	if not was_miss:
		# Calculate damage
		damage = CombatCalculator.calculate_physical_damage_with_terrain(
			attacker_stats, defender_stats, terrain_defense
		)

		# Check for critical hit
		var crit_chance: int = CombatCalculator.calculate_crit_chance(attacker_stats, defender_stats)
		was_critical = CombatCalculator.roll_crit(crit_chance)

		if was_critical:
			damage *= 2

	# Create appropriate phase type
	if is_double:
		return CombatPhase.create_double_attack(attacker, defender, damage, was_critical, was_miss)
	else:
		return CombatPhase.create_initial_attack(attacker, defender, damage, was_critical, was_miss)


## Calculate a counter attack phase (75% damage)
func _calculate_counter_phase(
	counter_attacker: Node2D,
	counter_target: Node2D,
	terrain_defense: int,
	terrain_evasion: int
) -> CombatPhase:
	var attacker_stats: UnitStats = counter_attacker.stats
	var target_stats: UnitStats = counter_target.stats

	# Calculate hit chance
	var hit_chance: int = CombatCalculator.calculate_hit_chance_with_terrain(
		attacker_stats, target_stats, terrain_evasion
	)
	var was_miss: bool = not CombatCalculator.roll_hit(hit_chance)

	var damage: int = 0
	var was_critical: bool = false

	if not was_miss:
		# Calculate base damage then apply counter multiplier (75%)
		var base_damage: int = CombatCalculator.calculate_physical_damage_with_terrain(
			attacker_stats, target_stats, terrain_defense
		)
		damage = int(base_damage * CombatCalculator.COUNTER_DAMAGE_MULTIPLIER)
		damage = maxi(damage, 1)  # Minimum 1 damage

		# Counters can still crit
		var crit_chance: int = CombatCalculator.calculate_crit_chance(attacker_stats, target_stats)
		was_critical = CombatCalculator.roll_crit(crit_chance)

		if was_critical:
			damage *= 2

	return CombatPhase.create_counter_attack(counter_attacker, counter_target, damage, was_critical, was_miss)


## Check if defender can counterattack
## Now properly handles dead zones: a bow (min=2, max=3) CANNOT counter at distance 1
func _can_counterattack(original_attacker: Node2D, original_defender: Node2D) -> bool:
	# Check if defender would still be alive (this is called after simulating damage)
	# The actual HP check happens in _build_combat_sequence

	# Get weapon ranges (now with min/max for dead zone support)
	var defender_min_range: int = _get_unit_weapon_min_range(original_defender)
	var defender_max_range: int = _get_unit_weapon_max_range(original_defender)

	# Calculate attack distance
	var attack_distance: int = GridManager.get_distance(
		original_attacker.grid_position,
		original_defender.grid_position
	)

	# Check if defender's weapon can reach (must be within range band)
	# This properly handles dead zones - a bow cannot counter adjacent attackers
	if attack_distance < defender_min_range or attack_distance > defender_max_range:
		return false

	# Roll for counter using class rate (with range band support)
	var counter_result: Dictionary = CombatCalculator.check_counterattack_with_range_band(
		original_defender.stats,
		defender_min_range,
		defender_max_range,
		attack_distance,
		true  # Assume alive (we check this in _build_combat_sequence)
	)

	return counter_result.will_counter


## Execute the complete combat session with all pre-calculated phases
func _execute_combat_session(
	initial_attacker: Node2D,
	initial_defender: Node2D,
	phases: Array[CombatPhase]
) -> void:
	# Track deaths for skip mode XP and signal emission
	var attacker_died: bool = false
	var defender_died: bool = false

	# SF2-AUTHENTIC: Pool XP by attacker/defender pair, award ONCE per pair
	# (Double attacks should not show separate XP entries)
	var xp_pools: Dictionary = {}  # Key: "attacker_id:defender_id", Value: {attacker, defender, damage, got_kill}

	# =========================================================================
	# FULL ANIMATION MODE: Single battle screen session
	# =========================================================================
	if not TurnManager.is_headless and not GameJuice.should_skip_combat_animation():
		# Hide the battlefield
		_hide_battlefield()

		# Create and setup the combat animation scene
		combat_anim_instance = COMBAT_ANIM_SCENE.instantiate()
		battle_scene_root.add_child(combat_anim_instance)
		combat_anim_instance.set_speed_multiplier(GameJuice.get_combat_speed_multiplier())

		# Connect XP handler to feed entries to battle screen
		var xp_handler: Callable = func(unit: Node2D, amount: int, source: String) -> void:
			print("[BattleManager] Session XP handler: %s +%d %s" % [unit.get_display_name(), amount, source])
			if combat_anim_instance and is_instance_valid(combat_anim_instance):
				combat_anim_instance.queue_xp_entry(unit.get_display_name(), amount, source)
		ExperienceManager.unit_gained_xp.connect(xp_handler)

		# Connect damage handler to POOL damage (not award XP yet - SF2-authentic)
		var damage_handler: Callable = func(def_unit: Node2D, dmg: int, died: bool) -> void:
			print("[BattleManager] Session damage applied: ", dmg, " died=", died)
			# Find which phase this corresponds to
			var current_phase: CombatPhase = _find_current_phase_for_defender(phases, def_unit)
			if current_phase and dmg > 0:
				# Pool damage by attacker/defender pair instead of awarding immediately
				var pool_key: String = "%d:%d" % [current_phase.attacker.get_instance_id(), def_unit.get_instance_id()]
				if pool_key not in xp_pools:
					xp_pools[pool_key] = {
						"attacker": current_phase.attacker,
						"defender": def_unit,
						"total_damage": 0,
						"got_kill": false
					}
				xp_pools[pool_key]["total_damage"] += dmg
				if died:
					xp_pools[pool_key]["got_kill"] = true
				# Track death state
				if def_unit == initial_attacker:
					attacker_died = died
				elif def_unit == initial_defender:
					defender_died = died
		combat_anim_instance.damage_applied.connect(damage_handler)

		# Start the session (fade in ONCE)
		await combat_anim_instance.start_session(initial_attacker, initial_defender)

		# Queue all phases
		for phase: CombatPhase in phases:
			combat_anim_instance.queue_phase(phase)

		# Execute all phases (no fading between them!)
		await combat_anim_instance.execute_all_phases()

		# SF2-AUTHENTIC: Award pooled XP ONCE per attacker/defender pair
		# (This happens after all phases complete, so double attacks show as one XP entry)
		for pool: Dictionary in xp_pools.values():
			ExperienceManager.award_combat_xp(
				pool["attacker"],
				pool["defender"],
				pool["total_damage"],
				pool["got_kill"]
			)

		# Finish session (display XP, fade out ONCE)
		await combat_anim_instance.finish_session()

		# Disconnect handlers
		if ExperienceManager.unit_gained_xp.is_connected(xp_handler):
			ExperienceManager.unit_gained_xp.disconnect(xp_handler)
		if combat_anim_instance and is_instance_valid(combat_anim_instance) and combat_anim_instance.damage_applied.is_connected(damage_handler):
			combat_anim_instance.damage_applied.disconnect(damage_handler)

		# Clean up
		combat_anim_instance.queue_free()
		combat_anim_instance = null

		# Restore battlefield
		_show_battlefield()

		# Battlefield settle delay
		await get_tree().create_timer(BATTLEFIELD_SETTLE_DELAY).timeout

	# =========================================================================
	# SKIP MODE / HEADLESS: Apply damage directly, no animations
	# =========================================================================
	else:
		for phase: CombatPhase in phases:
			# Check if we should skip this phase due to death
			if phase.attacker == initial_attacker and attacker_died:
				continue
			if phase.attacker == initial_defender and defender_died:
				continue
			if phase.defender == initial_attacker and attacker_died:
				continue
			if phase.defender == initial_defender and defender_died:
				continue

			# Play sound effect
			if not phase.was_miss:
				if phase.was_critical:
					AudioManager.play_sfx("attack_critical", AudioManager.SFXCategory.COMBAT)
				else:
					AudioManager.play_sfx("attack_hit", AudioManager.SFXCategory.COMBAT)
			else:
				AudioManager.play_sfx("attack_miss", AudioManager.SFXCategory.COMBAT)

			# Apply damage directly
			if not phase.was_miss and phase.damage > 0:
				if phase.defender.has_method("take_damage"):
					phase.defender.take_damage(phase.damage)
				else:
					phase.defender.stats.current_hp -= phase.damage
					phase.defender.stats.current_hp = maxi(0, phase.defender.stats.current_hp)

				# Check for death
				var died: bool = phase.defender.is_dead() if phase.defender.has_method("is_dead") else phase.defender.stats.current_hp <= 0

				# Update death tracking
				if phase.defender == initial_attacker:
					attacker_died = died
				elif phase.defender == initial_defender:
					defender_died = died

				# SF2-AUTHENTIC: Pool damage instead of awarding XP immediately
				var pool_key: String = "%d:%d" % [phase.attacker.get_instance_id(), phase.defender.get_instance_id()]
				if pool_key not in xp_pools:
					xp_pools[pool_key] = {
						"attacker": phase.attacker,
						"defender": phase.defender,
						"total_damage": 0,
						"got_kill": false
					}
				xp_pools[pool_key]["total_damage"] += phase.damage
				if died:
					xp_pools[pool_key]["got_kill"] = true

			# Emit combat resolved signal
			combat_resolved.emit(phase.attacker, phase.defender, phase.damage, not phase.was_miss, phase.was_critical)

		# SF2-AUTHENTIC: Award pooled XP ONCE per attacker/defender pair
		for pool: Dictionary in xp_pools.values():
			ExperienceManager.award_combat_xp(
				pool["attacker"],
				pool["defender"],
				pool["total_damage"],
				pool["got_kill"]
			)

		# Show combat results panel (skip mode shows XP on map)
		await _show_combat_results()


## Helper to find current phase for damage handler
func _find_current_phase_for_defender(phases: Array[CombatPhase], defender: Node2D) -> CombatPhase:
	# Return the most recent phase where this unit is the defender
	# (In practice, the damage_applied signal fires during execute_all_phases,
	#  so we track which phase we're on via the scene's internal state)
	for i in range(phases.size() - 1, -1, -1):
		if phases[i].defender == defender:
			return phases[i]
	return null


## Hide the battlefield for combat animation
func _hide_battlefield() -> void:
	if map_instance:
		map_instance.visible = false
	if units_parent:
		units_parent.visible = false
	var ui_node: Node = battle_scene_root.get_node_or_null("UI")
	if ui_node:
		ui_node.visible = false


## Show the battlefield after combat animation
func _show_battlefield() -> void:
	if map_instance:
		map_instance.visible = true
	if units_parent:
		units_parent.visible = true
	var ui_node: Node = battle_scene_root.get_node_or_null("UI")
	if ui_node:
		ui_node.visible = true


# =============================================================================
# DOUBLE ATTACK SYSTEM
# =============================================================================

## Check if attacker should perform a double attack
## SF2 mechanic: class-based double_attack_rate determines chance
func _check_double_attack(attacker: Node2D) -> bool:
	if attacker == null or not attacker.has_method("get_current_class"):
		return false

	var class_data: ClassData = attacker.get_current_class()
	if class_data == null:
		return false

	# Get double attack rate from class (default 0 if not set)
	var double_attack_rate: int = class_data.double_attack_rate if "double_attack_rate" in class_data else 0

	if double_attack_rate <= 0:
		return false

	# Roll for double attack
	var roll: int = randi_range(1, 100)
	return roll <= double_attack_rate


## Get weapon range for a unit (default 1 for melee)
## DEPRECATED: Use _get_unit_weapon_min_range() and _get_unit_weapon_max_range()
func _get_unit_weapon_range(unit: Node2D) -> int:
	return _get_unit_weapon_max_range(unit)


## Get weapon minimum attack range for a unit (1 for melee, 2+ for ranged with dead zone)
func _get_unit_weapon_min_range(unit: Node2D) -> int:
	if unit.stats and unit.stats.cached_weapon:
		return unit.stats.get_weapon_min_range()
	if "weapon_min_range" in unit:
		return unit.weapon_min_range
	return 1


## Get weapon maximum attack range for a unit (default 1 for melee)
func _get_unit_weapon_max_range(unit: Node2D) -> int:
	if unit.stats and unit.stats.cached_weapon:
		return unit.stats.get_weapon_max_range()
	if "weapon_range" in unit:
		return unit.weapon_range
	if unit.has_method("get_weapon_range"):
		return unit.get_weapon_range()
	return 1


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

	# Clear the battle grid to avoid polluting GridManager state for non-battle maps
	GridManager.clear_grid()

	if victory:
		GameState.increment_campaign_data("battles_won")

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

	# Emit battle_ended AFTER victory/defeat screen is dismissed
	# This ensures CampaignManager doesn't trigger map transition too early
	battle_ended.emit(victory)

	# Handle retry request
	if should_retry:
		# TODO: Implement battle retry (reload current battle data)
		return

	# Return to map after battle (if we came from a map trigger)
	var context: RefCounted = GameState.get_transition_context()
	if context and context.is_valid():
		# Set battle outcome in transition context
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
	pass  # Future: Show ability learned notification


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

	# Clean up any lingering combat animation
	if combat_anim_instance and is_instance_valid(combat_anim_instance):
		combat_anim_instance.queue_free()
		combat_anim_instance = null

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
