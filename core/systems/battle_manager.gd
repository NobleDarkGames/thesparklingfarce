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

const UnitUtils: GDScript = preload("res://core/utils/unit_utils.gd")

## Signals for battle events
signal battle_started(battle_data: Resource)
signal battle_ended(victory: bool)
signal unit_spawned(unit: Node2D)
signal combat_resolved(attacker: Node2D, defender: Node2D, damage: int, hit: bool, crit: bool)

## Current battle data (loaded from mods/)
var current_battle_data: Resource = null

## Battle state - delegates to TurnManager as single source of truth
## This prevents desync bugs between BattleManager and TurnManager
var battle_active: bool:
	get:
		return TurnManager.battle_active
	set(value):
		push_warning("BattleManager.battle_active should not be set directly - use TurnManager")

## Unit tracking
var all_units: Array[Node2D] = []
var player_units: Array[Node2D] = []
var enemy_units: Array[Node2D] = []
var neutral_units: Array[Node2D] = []

## Scene references (set by battle scene)
var battle_scene_root: Node = null
var map_instance: Node2D = null
var units_parent: Node2D = null

## Default scene paths (fallbacks if no mod override exists)
## Total conversion mods can override these via mod.json "scenes" section
const DEFAULT_UNIT_SCENE: String = "res://scenes/unit.tscn"
const DEFAULT_COMBAT_ANIM_SCENE: String = "res://scenes/ui/combat_animation_scene.tscn"
const DEFAULT_LEVEL_UP_SCENE: String = "res://scenes/ui/level_up_celebration.tscn"
const DEFAULT_VICTORY_SCREEN_SCENE: String = "res://scenes/ui/victory_screen.tscn"
const DEFAULT_DEFEAT_SCREEN_SCENE: String = "res://scenes/ui/defeat_screen.tscn"
const DEFAULT_COMBAT_RESULTS_SCENE: String = "res://scenes/ui/combat_results_panel.tscn"

## Cached scene references (loaded lazily with mod override support)
## Cleared when mods reload to pick up new overrides
var _unit_scene: PackedScene = null
var _combat_anim_scene: PackedScene = null
var _level_up_scene: PackedScene = null
var _victory_screen_scene: PackedScene = null
var _defeat_screen_scene: PackedScene = null
var _combat_results_scene: PackedScene = null

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

## Combat actions queue for combat results panel (e.g., "Max hit with CHAOS BREAKER for 12 damage!")
var _pending_combat_actions: Array[Dictionary] = []


## Initialize battle manager with scene references
func setup(battle_scene: Node, units_container: Node2D) -> void:
	battle_scene_root = battle_scene
	units_parent = units_container


## Clear cached scenes (called when mods reload to pick up new overrides)
func clear_scene_cache() -> void:
	_unit_scene = null
	_combat_anim_scene = null
	_level_up_scene = null
	_victory_screen_scene = null
	_defeat_screen_scene = null
	_combat_results_scene = null


# =============================================================================
# Scene Getters (Lazy Loading with Mod Override Support)
# =============================================================================

## Get the unit scene (allows mods to provide custom unit visuals)
func _get_unit_scene() -> PackedScene:
	if _unit_scene == null:
		_unit_scene = ModLoader.get_scene_or_fallback("unit_scene", DEFAULT_UNIT_SCENE)
	return _unit_scene


## Get the combat animation scene (allows mods to provide custom combat UI)
func _get_combat_anim_scene() -> PackedScene:
	if _combat_anim_scene == null:
		_combat_anim_scene = ModLoader.get_scene_or_fallback("combat_anim_scene", DEFAULT_COMBAT_ANIM_SCENE)
	return _combat_anim_scene


## Get the level-up celebration scene
func _get_level_up_scene() -> PackedScene:
	if _level_up_scene == null:
		_level_up_scene = ModLoader.get_scene_or_fallback("level_up_scene", DEFAULT_LEVEL_UP_SCENE)
	return _level_up_scene


## Get the victory screen scene
func _get_victory_screen_scene() -> PackedScene:
	if _victory_screen_scene == null:
		_victory_screen_scene = ModLoader.get_scene_or_fallback("victory_screen_scene", DEFAULT_VICTORY_SCREEN_SCENE)
	return _victory_screen_scene


## Get the defeat screen scene
func _get_defeat_screen_scene() -> PackedScene:
	if _defeat_screen_scene == null:
		_defeat_screen_scene = ModLoader.get_scene_or_fallback("defeat_screen_scene", DEFAULT_DEFEAT_SCREEN_SCENE)
	return _defeat_screen_scene


## Get the combat results panel scene
func _get_combat_results_scene() -> PackedScene:
	if _combat_results_scene == null:
		_combat_results_scene = ModLoader.get_scene_or_fallback("combat_results_scene", DEFAULT_COMBAT_RESULTS_SCENE)
	return _combat_results_scene


## Start a battle from BattleData resource (loaded from mods/)
## NOTE: This method is currently UNUSED. The production battle flow uses
## battle_loader.gd which calls setup() + _connect_signals() directly for
## more control over scene structure. This method remains for potential
## future use or alternative battle entry points.
func start_battle(battle_data: Resource) -> void:
	if not battle_data:
		push_error("BattleManager: Cannot start battle with null BattleData")
		return

	# Validate BattleData has required properties
	if not _validate_battle_data(battle_data):
		push_error("BattleManager: BattleData validation failed")
		return

	current_battle_data = battle_data
	# Note: battle_active is now a proxy to TurnManager.battle_active

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

	for child: Node in node.get_children():
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
		var unit: Node2D = _get_unit_scene().instantiate()

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

		# Register with GridManager for pathfinding and occupation checks
		GridManager.set_cell_occupied(grid_pos, unit)

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

	if not TurnManager.hero_died_in_battle.is_connected(_on_hero_died_in_battle):
		TurnManager.hero_died_in_battle.connect(_on_hero_died_in_battle)

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
	# Check for action modifiers from status effects (confusion, berserk, etc.)
	var actual_target: Node2D = _check_action_modifiers(unit, target)

	# Execute the attack on the actual target
	_execute_attack(unit, actual_target)


## Check if any status effects modify the unit's action target
## Uses data-driven StatusEffectData from ModLoader.status_effect_registry
## Falls back to legacy hardcoded confusion handling if effect not in registry
## @param unit: The acting unit
## @param intended_target: The player/AI's intended target
## @return: The actual target after any modifications
func _check_action_modifiers(unit: Node2D, intended_target: Node2D) -> Node2D:
	if not unit or not unit.stats:
		return intended_target

	var stats: RefCounted = unit.stats

	for effect_state: Dictionary in stats.status_effects:
		var effect_type: String = effect_state.get("type", "")

		# Look up effect data from registry
		var effect_data: StatusEffectData = ModLoader.status_effect_registry.get_effect(effect_type)

		if effect_data:
			# Data-driven action modifier
			if effect_data.action_modifier == StatusEffectData.ActionModifier.NONE:
				continue

			# Check if modifier triggers this action
			if randi_range(1, 100) > effect_data.action_modifier_chance:
				continue  # Modifier didn't trigger this time

			match effect_data.action_modifier:
				StatusEffectData.ActionModifier.RANDOM_TARGET:
					var random_target: Node2D = _get_random_unit_except_self(unit)
					return random_target

				StatusEffectData.ActionModifier.ATTACK_ALLIES:
					var ally_target: Node2D = _get_random_ally(unit)
					if ally_target:
						return ally_target

				StatusEffectData.ActionModifier.CANNOT_USE_MAGIC, StatusEffectData.ActionModifier.CANNOT_USE_ITEMS:
					# These modifiers are checked elsewhere (spell/item menus)
					pass

		else:
			# Legacy fallback for hardcoded effects not yet in registry
			if effect_type == "confusion":
				var confusion_roll: int = randi_range(1, 100)
				if confusion_roll <= 50:
					# Confused! Attack a random unit (friend or foe, including self)
					var random_target: Node2D = _get_random_confusion_target(unit)
					return random_target

	return intended_target


## Get a random target for a confused unit (any living unit on the battlefield, including self)
func _get_random_confusion_target(confused_unit: Node2D) -> Node2D:
	var valid_targets: Array[Node2D] = []

	for unit: Node2D in all_units:
		if unit.is_alive():
			valid_targets.append(unit)

	if valid_targets.is_empty():
		return confused_unit  # Fallback to self if somehow no targets

	return valid_targets[randi() % valid_targets.size()]


## Get a random unit except the specified one (for RANDOM_TARGET modifier)
func _get_random_unit_except_self(acting_unit: Node2D) -> Node2D:
	var valid_targets: Array[Node2D] = []

	for unit: Node2D in all_units:
		if unit.is_alive() and unit != acting_unit:
			valid_targets.append(unit)

	if valid_targets.is_empty():
		return acting_unit  # Fallback to self if somehow no other targets

	return valid_targets[randi() % valid_targets.size()]


## Get a random ally of the unit (for ATTACK_ALLIES modifier like berserk/charm)
func _get_random_ally(acting_unit: Node2D) -> Node2D:
	var allies: Array[Node2D] = []

	for unit: Node2D in all_units:
		if unit.is_alive() and unit != acting_unit and unit.faction == acting_unit.faction:
			allies.append(unit)

	if allies.is_empty():
		return acting_unit  # Fallback to self if no other allies

	return allies[randi() % allies.size()]


## Execute Stay action (end turn)
func _execute_stay(unit: Node2D) -> void:

	# Reset InputManager to waiting state
	InputManager.reset_to_waiting()

	# End unit's turn
	TurnManager.end_unit_turn(unit)


## Handle item use request from InputManager
## SF2-AUTHENTIC: Uses the full battle overlay screen, same as attacks
func _on_item_use_requested(unit: Node2D, item_id: String, target: Node2D) -> void:
	# Face the target before using item (SF2-authentic)
	if target and target != unit and unit.has_method("face_toward"):
		unit.face_toward(target.grid_position)

	# Get the item data
	var item: ItemData = ModLoader.registry.get_resource("item", item_id) as ItemData

	if not item:
		push_warning("BattleManager: Item '%s' not found in registry" % item_id)
		InputManager.reset_to_waiting()
		TurnManager.end_unit_turn(unit)
		return

	if not item.effect or not item.effect is AbilityData:
		push_warning("BattleManager: Item '%s' has no effect ability" % item_id)
		InputManager.reset_to_waiting()
		TurnManager.end_unit_turn(unit)
		return

	var ability: AbilityData = item.effect as AbilityData

	# Build combat phases based on ability type
	var phases: Array[CombatPhase] = []

	match ability.ability_type:
		AbilityData.AbilityType.HEAL:
			var heal_phase: CombatPhase = CombatPhase.create_item_heal(
				unit,
				target,
				ability.potency,
				item.item_name
			)
			phases.append(heal_phase)
		AbilityData.AbilityType.ATTACK:
			# Damage items - TODO: Could use SPELL_ATTACK or create ITEM_ATTACK type
			var damage_phase: CombatPhase = CombatPhase.create_spell_attack(
				unit,
				target,
				ability.potency,
				item.item_name
			)
			phases.append(damage_phase)
		AbilityData.AbilityType.SPECIAL:
			# Handle special items like Angel Wing (Egress effect)
			if ability.ability_id == "egress":
				# Consume the item first
				_consume_item_from_inventory(unit, item_id)
				# Execute battle exit
				await _execute_battle_exit(unit, BattleExitReason.ANGEL_WING)
				return  # Early return - battle is over
			else:
				push_warning("BattleManager: Unknown SPECIAL item ability: %s" % ability.ability_id)
				InputManager.reset_to_waiting()
				TurnManager.end_unit_turn(unit)
				return
		_:
			push_warning("BattleManager: Item ability type '%s' not yet supported" % ability.ability_type)
			InputManager.reset_to_waiting()
			TurnManager.end_unit_turn(unit)
			return

	if phases.is_empty():
		push_warning("BattleManager: Could not create combat phase for item '%s'" % item_id)
		InputManager.reset_to_waiting()
		TurnManager.end_unit_turn(unit)
		return

	# Consume item from inventory BEFORE the animation
	_consume_item_from_inventory(unit, item_id)

	# Execute the combat session (shows full battle overlay, applies effect)
	await _execute_combat_session(unit, target, phases)

	# Award XP for item usage AFTER the combat session (SF-authentic: healers get XP)
	_award_item_use_xp(unit, target, item)

	# Reset InputManager to waiting state
	InputManager.reset_to_waiting()

	# End unit's turn
	TurnManager.end_unit_turn(unit)


## Build display message for item use
func _build_item_use_message(user: Node2D, target: Node2D, item: ItemData, result: Dictionary) -> String:
	var user_name: String = UnitUtils.get_display_name(user, "???")
	var target_name: String = UnitUtils.get_display_name(target, "???")
	var item_name: String = item.item_name if item else "item"

	var amount: int = result.get("amount", 0)
	var effect_type: String = result.get("effect_type", "unknown")

	# Build message based on effect type
	match effect_type:
		"heal":
			if user == target:
				return "%s used %s - Recovered %d HP!" % [user_name, item_name, amount]
			else:
				return "%s used %s on %s - Recovered %d HP!" % [user_name, item_name, target_name, amount]
		"damage":
			return "%s used %s on %s - %d damage!" % [user_name, item_name, target_name, amount]
		_:
			return "%s used %s!" % [user_name, item_name]


## Apply item effect to target
## Returns Dictionary with: { success: bool, effect_type: String, amount: int }
func _apply_item_effect(user: Node2D, target: Node2D, item: ItemData, ability: AbilityData) -> Dictionary:
	match ability.ability_type:
		AbilityData.AbilityType.HEAL:
			return await _apply_healing_effect(user, target, ability)
		AbilityData.AbilityType.ATTACK:
			return await _apply_damage_effect(user, target, ability)
		AbilityData.AbilityType.SUPPORT:
			# TODO: Implement buff effects
			push_warning("BattleManager: Support effects not yet implemented")
			return {"success": false, "effect_type": "support", "amount": 0}
		AbilityData.AbilityType.DEBUFF:
			# TODO: Implement debuff effects
			push_warning("BattleManager: Debuff effects not yet implemented")
			return {"success": false, "effect_type": "debuff", "amount": 0}
		AbilityData.AbilityType.SPECIAL:
			# TODO: Implement special effects
			push_warning("BattleManager: Special effects not yet implemented")
			return {"success": false, "effect_type": "special", "amount": 0}
		_:
			push_warning("BattleManager: Unknown ability type")
			return {"success": false, "effect_type": "unknown", "amount": 0}


## Apply healing effect to target
## Returns Dictionary with: { success: bool, effect_type: "heal", amount: int }
func _apply_healing_effect(user: Node2D, target: Node2D, ability: AbilityData) -> Dictionary:
	if not target or not target.stats:
		push_warning("BattleManager: Invalid target for healing")
		return {"success": false, "effect_type": "heal", "amount": 0}

	var stats: UnitStats = target.stats
	var max_hp: int = stats.max_hp

	# Calculate healing amount
	var heal_amount: int = ability.potency

	# Track actual healing (may be less if near max HP)
	var old_hp: int = stats.current_hp
	stats.current_hp = mini(stats.current_hp + heal_amount, max_hp)
	var actual_heal: int = stats.current_hp - old_hp

	# Play healing sound
	AudioManager.play_sfx("heal", AudioManager.SFXCategory.COMBAT)

	# Visual feedback - flash the target green briefly
	if not TurnManager.is_headless and target.has_method("flash_color"):
		target.flash_color(Color.GREEN, 0.3)

	# Brief pause for player feedback
	if not TurnManager.is_headless:
		await get_tree().create_timer(0.5).timeout

	return {"success": true, "effect_type": "heal", "amount": actual_heal}


## Apply damage effect to target (for offensive items)
## Returns Dictionary with: { success: bool, effect_type: "damage", amount: int }
func _apply_damage_effect(user: Node2D, target: Node2D, ability: AbilityData) -> Dictionary:
	if not target or not target.stats:
		push_warning("BattleManager: Invalid target for damage")
		return {"success": false, "effect_type": "damage", "amount": 0}

	# Calculate damage (simplified - no defense calculation for items)
	var damage: int = ability.potency

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

	return {"success": true, "effect_type": "damage", "amount": damage}


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
func _on_spell_cast_requested(caster: Node2D, ability: AbilityData, target: Node2D) -> void:
	# Face the target before casting (SF2-authentic)
	if target and target != caster and caster.has_method("face_toward"):
		caster.face_toward(target.grid_position)

	# Validate ability
	if not ability:
		push_warning("BattleManager: Received null ability for spell cast")
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
		push_warning("BattleManager: Insufficient MP for spell '%s'" % ability.ability_id)
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		InputManager.reset_to_waiting()
		TurnManager.end_unit_turn(caster)
		return

	# Deduct MP cost
	caster.stats.current_mp -= ability.mp_cost

	# Refresh stats panel to show updated MP
	InputManager.refresh_stats_panel()

	# Get all targets (single target or AoE)
	var targets: Array[Node2D] = _get_spell_targets(caster, target, ability)

	if targets.is_empty():
		push_warning("BattleManager: No valid targets for spell '%s'" % ability.ability_id)
		InputManager.reset_to_waiting()
		TurnManager.end_unit_turn(caster)
		return

	# Apply the spell effect to all targets
	var any_effect_applied: bool = false
	for spell_target: Node2D in targets:
		var effect_applied: bool = false

		match ability.ability_type:
			AbilityData.AbilityType.HEAL:
				effect_applied = await _apply_spell_heal(caster, spell_target, ability)
			AbilityData.AbilityType.ATTACK:
				effect_applied = await _apply_spell_damage(caster, spell_target, ability)
			AbilityData.AbilityType.SUPPORT:
				# TODO: Implement buff effects
				push_warning("BattleManager: Support spell effects not yet implemented")
				effect_applied = false
			AbilityData.AbilityType.DEBUFF:
				# TODO: Implement debuff effects
				push_warning("BattleManager: Debuff spell effects not yet implemented")
				effect_applied = false
			AbilityData.AbilityType.STATUS:
				effect_applied = await _apply_spell_status(caster, spell_target, ability)
			AbilityData.AbilityType.SPECIAL:
				# Handle special abilities like Egress
				if ability.ability_id == "egress":
					# Guard: Verify we have somewhere to return to before exiting
					var safe_location: String = GameState.get_last_safe_location()
					if safe_location.is_empty():
						push_error("BattleManager: Cannot cast Egress - no safe location set!")
						# Refund MP since spell couldn't execute
						var stats: Node = caster.get_node_or_null("Stats")
						if stats and "current_mp" in stats:
							stats.current_mp += ability.mp_cost
						InputManager.refresh_stats_panel()
						InputManager.reset_to_waiting()
						TurnManager.end_unit_turn(caster)
						return
					# Egress exits battle immediately - no per-target loop needed
					await _execute_battle_exit(caster, BattleExitReason.EGRESS)
					return  # Early return - battle is over, don't continue loop
				else:
					push_warning("BattleManager: Unknown SPECIAL ability: %s" % ability.ability_id)
					effect_applied = false
			_:
				push_warning("BattleManager: Unknown spell type: %s" % ability.ability_type)
				effect_applied = false

		if effect_applied:
			# Award XP for each target hit (SF2-authentic: casters get XP per target)
			_award_spell_xp(caster, spell_target, ability)
			any_effect_applied = true

	# Reset InputManager to waiting state
	InputManager.reset_to_waiting()

	# End caster's turn
	TurnManager.end_unit_turn(caster)


## Get all targets for a spell (handles single-target and AoE)
## Returns array of valid targets based on spell's area_of_effect and target_type
func _get_spell_targets(caster: Node2D, center_target: Node2D, ability: AbilityData) -> Array[Node2D]:
	var targets: Array[Node2D] = []

	# Single target (no AoE)
	if ability.area_of_effect <= 0:
		if center_target and center_target.is_alive():
			targets.append(center_target)
		return targets

	# AoE - find all units in radius around the center target
	var center_cell: Vector2i = center_target.grid_position

	# Get all cells in AoE radius (Manhattan distance for SF-style grid)
	for dx: int in range(-ability.area_of_effect, ability.area_of_effect + 1):
		for dy: int in range(-ability.area_of_effect, ability.area_of_effect + 1):
			var manhattan_dist: int = absi(dx) + absi(dy)
			if manhattan_dist <= ability.area_of_effect:
				var cell: Vector2i = center_cell + Vector2i(dx, dy)
				if GridManager.is_within_bounds(cell):
					var unit: Node2D = GridManager.get_unit_at_cell(cell)
					if unit and unit.is_alive() and _is_valid_spell_target(caster, unit, ability):
						targets.append(unit)

	return targets


## Check if a unit is a valid target for a spell (based on target_type)
func _is_valid_spell_target(caster: Node2D, target: Node2D, ability: AbilityData) -> bool:
	if not target or not target.is_alive():
		return false

	match ability.target_type:
		AbilityData.TargetType.SELF:
			return target == caster
		AbilityData.TargetType.SINGLE_ALLY, AbilityData.TargetType.ALL_ALLIES:
			return target.faction == caster.faction
		AbilityData.TargetType.SINGLE_ENEMY, AbilityData.TargetType.ALL_ENEMIES:
			return target.faction != caster.faction
		AbilityData.TargetType.AREA:
			# Area spells can hit anyone (damage enemies, heal allies based on spell type)
			if ability.ability_type == AbilityData.AbilityType.HEAL:
				return target.faction == caster.faction
			elif ability.ability_type == AbilityData.AbilityType.ATTACK:
				return target.faction != caster.faction
			else:
				return true  # Other types: allow all
		_:
			return true


## Apply healing spell effect via combat screen
## SF2-AUTHENTIC: Uses the same battle overlay as attacks and item heals
func _apply_spell_heal(caster: Node2D, target: Node2D, ability: AbilityData) -> bool:
	if not target or not target.stats:
		push_warning("BattleManager: Invalid target for healing spell")
		return false

	# Calculate healing amount using CombatCalculator
	var heal_amount: int = CombatCalculator.calculate_healing(caster.stats, ability)

	# Build spell heal combat phase
	var phases: Array[CombatPhase] = []
	var heal_phase: CombatPhase = CombatPhase.create_spell_heal(caster, target, heal_amount, ability.ability_name)
	phases.append(heal_phase)

	# Execute combat session (shows combat screen, applies healing)
	await _execute_combat_session(caster, target, phases)

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
	var spell_phase: CombatPhase = CombatPhase.create_spell_attack(caster, target, damage, ability.ability_name)
	phases.append(spell_phase)

	# Execute combat session (shows combat screen, applies damage, handles death)
	await _execute_combat_session(caster, target, phases)

	return true


## Apply status effect spell to target
## Handles both applying status effects and removing them (cure spells)
## Returns true if any effect was applied/removed
func _apply_spell_status(caster: Node2D, target: Node2D, ability: AbilityData) -> bool:
	if not target or not target.stats:
		push_warning("BattleManager: Invalid target for status spell")
		return false

	if ability.status_effects.is_empty():
		push_warning("BattleManager: Status spell '%s' has no status_effects defined" % ability.ability_name)
		return false

	# Roll against effect_chance to determine resistance
	var roll: int = randi_range(1, 100)
	var chance: int = ability.effect_chance
	var was_resisted: bool = roll > chance

	# Get the primary status effect name for display
	var primary_effect: String = ability.status_effects[0] if ability.status_effects.size() > 0 else "status"
	# Clean up effect name for display (remove "remove_" prefix if present)
	var display_effect: String = primary_effect
	if display_effect.begins_with("remove_"):
		display_effect = "Cured " + display_effect.substr(7)

	# Build spell status combat phase
	var phases: Array[CombatPhase] = []
	var status_phase: CombatPhase = CombatPhase.create_spell_status(
		caster, target,
		ability.ability_name,
		display_effect,
		was_resisted
	)
	phases.append(status_phase)

	# Execute combat session (shows combat screen with status effect result)
	await _execute_combat_session(caster, target, phases)

	# If resisted, we're done
	if was_resisted:
		return false

	# Apply each status effect after combat animation
	var any_effect_applied: bool = false
	for effect: String in ability.status_effects:
		if effect.begins_with("remove_"):
			# This is a cure effect - remove the status
			var status_to_remove: String = effect.substr(7)  # Strip "remove_" prefix
			if target.has_status_effect(status_to_remove):
				target.remove_status_effect(status_to_remove)
				any_effect_applied = true
		else:
			# Apply the status effect
			target.add_status_effect(effect, ability.effect_duration, ability.potency)
			any_effect_applied = true

	return any_effect_applied


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
	# Face the target before attacking (SF2-authentic) - handled in _execute_attack
	await _execute_attack(attacker, defender)


## Execute spell cast from AI (called by AIBrain)
## This is the public API for AI brains to cast spells
## @param caster: The unit casting the spell
## @param ability_id: The ability ID to cast
## @param target: The target unit for the spell
## @return: True if spell was cast successfully
func execute_ai_spell(caster: Node2D, ability_id: String, target: Node2D) -> bool:
	# Face the target before casting (SF2-authentic)
	if target and target != caster and caster.has_method("face_toward"):
		caster.face_toward(target.grid_position)

	# Get the ability data from registry
	var ability: AbilityData = ModLoader.registry.get_resource("ability", ability_id) as AbilityData

	if not ability:
		push_warning("BattleManager: AI spell '%s' not found in registry" % ability_id)
		return false

	if not caster or not caster.stats:
		push_warning("BattleManager: AI spell caster invalid")
		return false

	if not target or not target.is_alive():
		push_warning("BattleManager: AI spell target invalid")
		return false

	# Check MP cost
	if caster.stats.current_mp < ability.mp_cost:
		return false

	# Deduct MP
	caster.stats.current_mp -= ability.mp_cost

	# Get all targets (handles AoE)
	var targets: Array[Node2D] = _get_spell_targets(caster, target, ability)

	if targets.is_empty():
		# Refund MP if no valid targets
		caster.stats.current_mp += ability.mp_cost
		return false

	# Apply the spell effect to all targets
	var any_effect_applied: bool = false
	for spell_target: Node2D in targets:
		var effect_applied: bool = false

		match ability.ability_type:
			AbilityData.AbilityType.HEAL:
				effect_applied = await _apply_spell_heal(caster, spell_target, ability)
			AbilityData.AbilityType.ATTACK:
				effect_applied = await _apply_spell_damage(caster, spell_target, ability)
			_:
				push_warning("BattleManager: AI spell type '%s' not yet supported" % ability.ability_type)

		if effect_applied:
			any_effect_applied = true
			_award_spell_xp(caster, spell_target, ability)

	return any_effect_applied


# =============================================================================
# SF2 AUTHENTIC COMBAT SESSION SYSTEM
# =============================================================================

## Execute Attack action using the new session-based combat system
## SF-AUTHENTIC: All phases (initial, double, counter) execute in a SINGLE
## battle screen session - one fade in, one fade out, no jarring transitions.
func _execute_attack(attacker: Node2D, defender: Node2D) -> void:
	# Face the target before attacking (SF2-authentic)
	if attacker.has_method("face_toward"):
		attacker.face_toward(defender.grid_position)

	# Build the complete combat sequence BEFORE opening the battle screen
	var phases: Array[CombatPhase] = _build_combat_sequence(attacker, defender)

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


## Get the weapon name for a unit (for display in combat results)
func _get_unit_weapon_name(unit: Node2D) -> String:
	if not unit or not unit.character_data:
		return ""

	# Try to get equipped weapon from save data
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(unit.character_data.character_uid)
	if save_data:
		var weapon: ItemData = EquipmentManager.get_equipped_weapon(save_data)
		if weapon:
			return weapon.item_name

	return ""


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

	# Get weapon name for display
	var weapon_name: String = _get_unit_weapon_name(attacker)

	# Create appropriate phase type
	if is_double:
		return CombatPhase.create_double_attack(attacker, defender, damage, was_critical, was_miss, weapon_name)
	else:
		return CombatPhase.create_initial_attack(attacker, defender, damage, was_critical, was_miss, weapon_name)


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

	# Get weapon name for display
	var weapon_name: String = _get_unit_weapon_name(counter_attacker)

	return CombatPhase.create_counter_attack(counter_attacker, counter_target, damage, was_critical, was_miss, weapon_name)


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
		combat_anim_instance = _get_combat_anim_scene().instantiate()
		battle_scene_root.add_child(combat_anim_instance)
		combat_anim_instance.set_speed_multiplier(GameJuice.get_combat_speed_multiplier())

		# Connect XP handler to feed entries to battle screen
		var xp_handler: Callable = func(unit: Node2D, amount: int, source: String) -> void:
			if combat_anim_instance and is_instance_valid(combat_anim_instance):
				combat_anim_instance.queue_xp_entry(UnitUtils.get_display_name(unit), amount, source)
		ExperienceManager.unit_gained_xp.connect(xp_handler)

		# Connect damage handler to POOL damage (not award XP yet - SF2-authentic)
		var damage_handler: Callable = func(def_unit: Node2D, dmg: int, died: bool) -> void:
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

		# Queue all phases and their combat action text
		for phase: CombatPhase in phases:
			combat_anim_instance.queue_phase(phase)
			# Queue combat action for results display
			combat_anim_instance.queue_combat_action(
				phase.get_result_text(),
				phase.was_critical,
				phase.was_miss
			)

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

			# Queue combat action for results panel
			_pending_combat_actions.append({
				"text": phase.get_result_text(),
				"is_critical": phase.was_critical,
				"is_miss": phase.was_miss
			})

			# Handle healing phases (ITEM_HEAL, SPELL_HEAL)
			if phase.phase_type == CombatPhase.PhaseType.ITEM_HEAL or phase.phase_type == CombatPhase.PhaseType.SPELL_HEAL:
				# Play healing sound
				AudioManager.play_sfx("heal", AudioManager.SFXCategory.COMBAT)

				# Apply healing directly
				if phase.heal_amount > 0 and phase.defender and phase.defender.stats:
					var stats: UnitStats = phase.defender.stats
					stats.current_hp = mini(stats.current_hp + phase.heal_amount, stats.max_hp)

				# Healing doesn't have damage XP pooling - XP is handled separately
				continue

			# Play sound effect (for attack phases)
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
	for i: int in range(phases.size() - 1, -1, -1):
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

	# Get double attack rate from class
	var double_attack_rate: int = class_data.double_attack_rate

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
	# Persist death to CharacterSaveData for player units
	_persist_unit_death(unit)

	# Visual feedback (fade out) - skip in headless mode
	if "modulate" in unit and not TurnManager.is_headless:
		var tween: Tween = create_tween()
		tween.tween_property(unit, "modulate:a", 0.0, DEATH_FADE_DURATION)
		await tween.finished

	# Unit stays in scene but is marked dead
	# TurnManager will skip dead units
	# Note: GridManager already cleared by Unit before emitting signal


## Persist unit death to CharacterSaveData (for player units only)
## This allows church revival to know which characters are dead
func _persist_unit_death(unit: Node2D) -> void:
	# Only persist for player faction
	if not unit or unit.faction != "player":
		return

	# Get character UID
	if not unit.character_data:
		return

	var char_uid: String = unit.character_data.character_uid
	if char_uid.is_empty():
		return

	# Get save data and mark as dead
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(char_uid)
	if save_data:
		save_data.is_alive = false


## Handle unit death (direct call - RARELY NEEDED)
## In most cases, Unit.take_damage() will automatically emit the died signal.
## This is only needed for special cases like instant death effects.
func _handle_unit_death(unit: Node2D) -> void:
	# Check if unit is actually dead
	if unit.has_method("is_dead") and not unit.is_dead():
		return

	# Call our death handler directly (Unit.take_damage already emits died signal)
	_on_unit_died(unit)


## Handle battle end (victory only - defeat goes through hero_died_in_battle)
func _on_battle_ended(victory: bool) -> void:
	# Clear the battle grid to avoid polluting GridManager state for non-battle maps
	GridManager.clear_grid()

	# This handler is only for victory now - defeat goes through hero_died_in_battle
	if not victory:
		push_warning("BattleManager: _on_battle_ended(false) should not occur - defeat uses hero_died_in_battle")
		return

	# Sync surviving units' HP/MP to save data (dead units already marked during battle)
	_sync_surviving_units_to_save_data()

	GameState.increment_campaign_data("battles_won")

	# Wait for any pending level-up celebrations to finish before showing result screen
	await _wait_for_level_ups()

	# Show victory screen (skip in headless mode)
	if not TurnManager.is_headless:
		await _show_victory_screen()

	# Emit battle_ended AFTER victory screen is dismissed
	battle_ended.emit(true)

	# Return to map after battle (if we came from a map trigger)
	var context: RefCounted = GameState.get_transition_context()
	if context and context.is_valid():
		var TransitionContextScript: GDScript = context.get_script()
		context.battle_outcome = TransitionContextScript.BattleOutcome.VICTORY

		# Store completed battle ID for one-shot tracking
		if current_battle_data and current_battle_data.get("battle_id"):
			context.completed_battle_id = current_battle_data.battle_id

		TriggerManager.return_to_map()


## Show victory screen and wait for player to dismiss
## Returns false (victory never triggers retry)
func _show_victory_screen() -> bool:
	var gold_earned: int = 0
	# TODO: Calculate gold from defeated enemies

	var victory_screen: CanvasLayer = _get_victory_screen_scene().instantiate()
	battle_scene_root.add_child(victory_screen)

	victory_screen.show_victory(gold_earned)
	await victory_screen.result_dismissed

	victory_screen.queue_free()
	return false


## Show defeat screen (SF2-authentic automatic flow) and wait for player input
## Returns false always (no retry option in SF2-authentic flow)
func _show_defeat_screen() -> bool:
	var defeat_screen: CanvasLayer = _get_defeat_screen_scene().instantiate()
	battle_scene_root.add_child(defeat_screen)

	var player_choice: String = ""  # "continue" or "quit"

	# Connect to SF2-authentic signals
	defeat_screen.continue_requested.connect(func() -> void: player_choice = "continue")
	defeat_screen.quit_requested.connect(func() -> void: player_choice = "quit")

	# Get hero name for SF2-authentic flavor text
	var hero_name: String = "The hero"
	var hero: CharacterData = PartyManager.get_hero()
	if hero:
		hero_name = hero.character_name

	defeat_screen.show_defeat(hero_name)
	await defeat_screen.result_dismissed
	defeat_screen.queue_free()

	# Handle player choice
	if player_choice == "quit":
		# TODO: Implement return to title (Phase 3)
		push_warning("BattleManager: Return to title not yet implemented - retreating instead")

	return false


## Handle unit gaining XP
func _on_unit_gained_xp(unit: Node2D, amount: int, source: String) -> void:

	# Queue XP entry for combat results panel
	_pending_xp_entries.append({
		"unit_name": UnitUtils.get_display_name(unit),
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
	var celebration: CanvasLayer = _get_level_up_scene().instantiate()
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


## Show combat results panel with queued combat actions and XP entries
func _show_combat_results() -> void:
	# Skip in headless mode
	if TurnManager.is_headless:
		_pending_combat_actions.clear()
		_pending_xp_entries.clear()
		return

	# Skip if no entries
	if _pending_combat_actions.is_empty() and _pending_xp_entries.is_empty():
		return

	# Create and populate the results panel
	var results_panel: CanvasLayer = _get_combat_results_scene().instantiate()
	battle_scene_root.add_child(results_panel)

	# Add all queued combat actions first
	for action: Dictionary in _pending_combat_actions:
		results_panel.add_combat_action(action.text, action.is_critical, action.is_miss)

	# Clear the combat actions queue
	_pending_combat_actions.clear()

	# Add all queued XP entries
	for entry: Dictionary in _pending_xp_entries:
		results_panel.add_xp_entry(entry.unit_name, entry.amount, entry.source)

	# Clear the XP queue
	_pending_xp_entries.clear()

	# Show and wait for dismissal
	results_panel.show_results()
	await results_panel.results_dismissed

	results_panel.queue_free()


## Clean up battle
func end_battle() -> void:
	# Note: battle_active proxies to TurnManager - no need to set here

	# Clean up any lingering combat animation
	if combat_anim_instance and is_instance_valid(combat_anim_instance):
		combat_anim_instance.queue_free()
		combat_anim_instance = null

	# Clear units
	for unit: Node2D in all_units:
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


# =============================================================================
# Battle Exit System (Egress, Angel Wing, Hero Death)
# =============================================================================

## Reasons for exiting battle early (not victory/defeat)
enum BattleExitReason {
	EGRESS,      ## Player cast Egress spell
	ANGEL_WING,  ## Player used Angel Wing item
	HERO_DEATH,  ## Hero (is_hero character) died
	PARTY_WIPE   ## All player units dead
}


## Execute battle exit - revive all party members, return to safe location
## This handles Egress spell, Angel Wing item, and automatic exits from death
## @param initiator: The unit that triggered the exit (for Egress/Angel Wing) or null (for death)
## @param reason: Why we're exiting the battle
func _execute_battle_exit(initiator: Node2D, reason: BattleExitReason) -> void:
	# Prevent re-entry if already exiting
	if not battle_active:
		return

	# Mark battle as inactive (set on TurnManager directly)
	TurnManager.battle_active = false

	# 1. Handle party restoration based on exit reason (SF2-authentic)
	# DEFEAT scenarios (HERO_DEATH, PARTY_WIPE): Full restoration (HP + MP)
	# ESCAPE scenarios (EGRESS, ANGEL_WING): No restoration (keep current state)
	var is_defeat: bool = reason == BattleExitReason.HERO_DEATH or reason == BattleExitReason.PARTY_WIPE
	_revive_all_party_members(is_defeat)

	# 2. Set battle outcome to RETREAT in transition context
	var context: RefCounted = GameState.get_transition_context()
	if context:
		# Access the BattleOutcome enum from the TransitionContext script
		var TransitionContextScript: GDScript = context.get_script()
		if TransitionContextScript and "BattleOutcome" in TransitionContextScript:
			context.battle_outcome = TransitionContextScript.BattleOutcome.RETREAT

	# 3. Determine return location
	var return_path: String = GameState.get_last_safe_location()
	if return_path.is_empty():
		push_warning("BattleManager: No safe location set, using transition context fallback")
		if context and context.is_valid():
			return_path = context.return_scene_path

	if return_path.is_empty():
		push_error("BattleManager: Cannot exit battle - no return location available")
		TurnManager.battle_active = true  # Re-enable battle since we can't exit
		return

	# 4. Show brief exit message for voluntary exits (Egress/Angel Wing only)
	# HERO_DEATH uses the full defeat screen shown earlier
	if not TurnManager.is_headless and reason != BattleExitReason.HERO_DEATH:
		await _show_exit_message(reason)

	# 5. Check if CampaignManager is managing this battle
	# If so, let it handle the scene transition via its on_defeat/on_victory branches
	var campaign_handles_transition: bool = CampaignManager and CampaignManager.is_managing_campaign_battle()

	# 6. Emit battle_ended signal with victory=false (but RETREAT outcome distinguishes from DEFEAT)
	# CampaignManager listens to this and will handle the transition if it's a campaign battle
	battle_ended.emit(false)

	# 7. Clean up battle state
	end_battle()

	# 8. Transition to safe location ONLY if CampaignManager is NOT handling it
	# For campaign battles, CampaignManager uses on_defeat target from campaign config
	if not campaign_handles_transition:
		await SceneManager.change_scene(return_path)


## Revive all party members (SF2-authentic behavior depends on reason)
## @param full_restoration: If true (defeat), restore HP AND MP. If false (escape), no restoration.
func _revive_all_party_members(full_restoration: bool) -> void:
	if not full_restoration:
		# EGRESS / ANGEL_WING: No restoration - party keeps current state
		# SF2-AUTHENTIC: Egress exits with whatever HP/MP you had
		return

	# DEFEAT (HERO_DEATH / PARTY_WIPE): Full restoration
	# SF2-AUTHENTIC: On defeat, party wakes up at church fully healed (HP + MP)
	for character: CharacterData in PartyManager.party_members:
		var uid: String = character.character_uid
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(uid)
		if save_data:
			save_data.is_alive = true
			save_data.current_hp = save_data.max_hp
			save_data.current_mp = save_data.max_mp
			# TODO: Clear status ailments when status system is implemented


## Sync all surviving player units' HP/MP to their CharacterSaveData after battle
## Called after victory to persist current state (dead units already marked via _persist_unit_death)
func _sync_surviving_units_to_save_data() -> void:
	for unit: Node2D in player_units:
		if not is_instance_valid(unit) or not unit.is_alive:
			continue
		if not unit.character_data:
			continue
		var char_uid: String = unit.character_data.character_uid
		if char_uid.is_empty():
			continue
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(char_uid)
		if save_data and unit.stats:
			save_data.current_hp = unit.stats.current_hp
			save_data.current_mp = unit.stats.current_mp


## Show a brief exit message for voluntary battle exits (Egress/Angel Wing)
func _show_exit_message(reason: BattleExitReason) -> void:
	var message: String = ""
	match reason:
		BattleExitReason.EGRESS:
			message = "Egress!"
		BattleExitReason.ANGEL_WING:
			message = "Angel Wing!"
		_:
			return  # No message for other reasons

	# Create full-screen container for proper centering
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 100

	var background: ColorRect = ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var label: Label = Label.new()
	label.text = message
	label.add_theme_font_override("font", preload("res://assets/fonts/monogram.ttf"))
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(label)

	if battle_scene_root:
		battle_scene_root.add_child(canvas)
	elif get_tree().current_scene:
		get_tree().current_scene.add_child(canvas)
	else:
		# Rare edge case: no valid scene root during transition
		push_warning("BattleManager: Cannot show exit message - no scene root available")
		canvas.queue_free()
		return

	# Brief pause for player to read message
	await get_tree().create_timer(1.5).timeout

	canvas.queue_free()


## Handle hero death - show defeat screen then exit battle (called from TurnManager signal)
func _on_hero_died_in_battle() -> void:
	# Show SF2-authentic defeat screen first (unless headless)
	if not TurnManager.is_headless:
		await _show_defeat_screen()

	# Now execute battle exit with full party restoration
	await _execute_battle_exit(null, BattleExitReason.HERO_DEATH)
