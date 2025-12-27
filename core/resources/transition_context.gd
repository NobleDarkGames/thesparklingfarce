## TransitionContext - Encapsulates data for scene transitions
##
## Stores all context needed when transitioning between scenes,
## particularly for the explore -> battle -> explore loop.
##
## Usage:
##   # Before battle
##   var context = TransitionContext.new()
##   context.return_scene_path = get_tree().current_scene.scene_file_path
##   context.hero_world_position = hero.global_position
##   context.hero_grid_position = hero.grid_position
##   GameState.set_transition_context(context)
##
##   # After battle (in map scene)
##   var context = GameState.get_transition_context()
##   if context:
##       hero.global_position = context.hero_world_position
##       GameState.clear_transition_context()
class_name TransitionContext
extends RefCounted

## Scene to return to after battle/transition
var return_scene_path: String = ""

## Hero's world position (pixels) before transition
var hero_world_position: Vector2 = Vector2.ZERO

## Hero's grid position before transition
var hero_grid_position: Vector2i = Vector2i.ZERO

## Optional spawn point ID to use when returning
var spawn_point_id: String = ""

## Hero's facing direction before transition (for restoration)
var hero_facing: String = "down"

## Caravan grid position before transition (for restoration)
var caravan_grid_position: Vector2i = Vector2i.ZERO

## Whether caravan position should be restored
var has_caravan_position: bool = false

## Additional context data for extensibility
var extra_data: Dictionary = {}

## Battle outcome (set after battle ends)
enum BattleOutcome { NONE, VICTORY, DEFEAT, RETREAT }
var battle_outcome: BattleOutcome = BattleOutcome.NONE

## Battle ID that was just completed (for one-shot tracking)
var completed_battle_id: String = ""


## Create from current game state.
##
## IMPORTANT: GDScript Cyclic Reference Limitation
## This method returns RefCounted instead of TransitionContext because GDScript
## cannot reference a class's own class_name in static method return types.
## The class definition isn't complete when static method signatures are parsed,
## causing a cyclic dependency error if we try to return "TransitionContext".
##
## Callers should either:
##   1. Use duck typing (the returned object has all TransitionContext methods)
##   2. Cast explicitly: var ctx: TransitionContext = from_current_scene(hero) as TransitionContext
##
## This is a known GDScript limitation, not a design flaw.
static func from_current_scene(hero: Node2D) -> RefCounted:
	var script: GDScript = load("res://core/resources/transition_context.gd")
	var context: RefCounted = script.new()

	# Get current scene path
	var tree: SceneTree = Engine.get_main_loop()
	if tree and tree.current_scene:
		context.return_scene_path = tree.current_scene.scene_file_path

	# Get hero position
	if hero:
		context.hero_world_position = hero.global_position
		if "grid_position" in hero:
			var grid_pos: Variant = hero.get("grid_position")
			if grid_pos is Vector2i:
				context.hero_grid_position = grid_pos
		if "facing_direction" in hero:
			var facing_val: Variant = hero.get("facing_direction")
			if facing_val is String:
				context.hero_facing = facing_val

	# Get caravan position if available
	if CaravanController and CaravanController.is_spawned():
		context.caravan_grid_position = CaravanController.get_grid_position()
		context.has_caravan_position = true

	return context


## Check if context has valid return data
func is_valid() -> bool:
	return not return_scene_path.is_empty()


## Store arbitrary extra data
func set_extra(key: String, value: Variant) -> void:
	extra_data[key] = value


## Retrieve extra data
func get_extra(key: String, default: Variant = null) -> Variant:
	return extra_data.get(key, default)


## Export to dictionary (for save/load)
func to_dict() -> Dictionary:
	return {
		"return_scene_path": return_scene_path,
		"hero_world_position": {"x": hero_world_position.x, "y": hero_world_position.y},
		"hero_grid_position": {"x": hero_grid_position.x, "y": hero_grid_position.y},
		"spawn_point_id": spawn_point_id,
		"hero_facing": hero_facing,
		"caravan_grid_position": {"x": caravan_grid_position.x, "y": caravan_grid_position.y},
		"has_caravan_position": has_caravan_position,
		"extra_data": extra_data,
		"battle_outcome": battle_outcome,
		"completed_battle_id": completed_battle_id,
	}


## Import from dictionary (for save/load).
##
## Returns RefCounted due to GDScript cyclic reference limitation.
## See from_current_scene() for detailed explanation.
static func from_dict(data: Dictionary) -> RefCounted:
	var script: GDScript = load("res://core/resources/transition_context.gd")
	var context: RefCounted = script.new()

	context.return_scene_path = DictUtils.get_string(data, "return_scene_path", "")

	var world_pos: Dictionary = DictUtils.get_dict(data, "hero_world_position", {})
	context.hero_world_position = Vector2(DictUtils.get_float(world_pos, "x", 0.0), DictUtils.get_float(world_pos, "y", 0.0))

	var grid_pos: Dictionary = DictUtils.get_dict(data, "hero_grid_position", {})
	context.hero_grid_position = Vector2i(DictUtils.get_int(grid_pos, "x", 0), DictUtils.get_int(grid_pos, "y", 0))

	context.spawn_point_id = DictUtils.get_string(data, "spawn_point_id", "")
	context.hero_facing = DictUtils.get_string(data, "hero_facing", "down")

	var caravan_pos: Dictionary = DictUtils.get_dict(data, "caravan_grid_position", {})
	context.caravan_grid_position = Vector2i(DictUtils.get_int(caravan_pos, "x", 0), DictUtils.get_int(caravan_pos, "y", 0))
	context.has_caravan_position = DictUtils.get_bool(data, "has_caravan_position", false)

	context.extra_data = DictUtils.get_dict(data, "extra_data", {})
	context.battle_outcome = DictUtils.get_int(data, "battle_outcome", BattleOutcome.NONE)
	context.completed_battle_id = DictUtils.get_string(data, "completed_battle_id", "")

	return context
