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

## Additional context data for extensibility
var extra_data: Dictionary = {}

## Battle outcome (set after battle ends)
enum BattleOutcome { NONE, VICTORY, DEFEAT, RETREAT }
var battle_outcome: BattleOutcome = BattleOutcome.NONE

## Battle ID that was just completed (for one-shot tracking)
var completed_battle_id: String = ""


## Create from current game state
## Note: Returns RefCounted (actually TransitionContext) - use type casting if needed
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
		if hero.get("grid_position"):
			context.hero_grid_position = hero.grid_position
		if hero.get("facing"):
			context.hero_facing = hero.facing

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
		"extra_data": extra_data,
		"battle_outcome": battle_outcome,
		"completed_battle_id": completed_battle_id,
	}


## Import from dictionary (for save/load)
static func from_dict(data: Dictionary) -> RefCounted:
	var script: GDScript = load("res://core/resources/transition_context.gd")
	var context: RefCounted = script.new()

	context.return_scene_path = data.get("return_scene_path", "")

	var world_pos: Dictionary = data.get("hero_world_position", {})
	context.hero_world_position = Vector2(world_pos.get("x", 0), world_pos.get("y", 0))

	var grid_pos: Dictionary = data.get("hero_grid_position", {})
	context.hero_grid_position = Vector2i(grid_pos.get("x", 0), grid_pos.get("y", 0))

	context.spawn_point_id = data.get("spawn_point_id", "")
	context.hero_facing = data.get("hero_facing", "down")
	context.extra_data = data.get("extra_data", {})
	context.battle_outcome = data.get("battle_outcome", BattleOutcome.NONE)
	context.completed_battle_id = data.get("completed_battle_id", "")

	return context
