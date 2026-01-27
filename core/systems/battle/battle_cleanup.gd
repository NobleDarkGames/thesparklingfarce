## Handles cleanup of battle state when a battle ends.
##
## This class is responsible for:
## - Freeing combat animation instances
## - Freeing unit nodes (signal connections are cleaned up automatically by queue_free)
## - Clearing unit tracking arrays
## - Freeing map instances
## - Clearing TurnManager and GridManager state
##
## Extracted from BattleManager to improve modularity and testability.
class_name BattleCleanup
extends RefCounted


## Context holding all references needed for battle cleanup.
## Passed to cleanup methods to avoid tight coupling with BattleManager.
class CleanupContext:
	## Combat animation instance to free
	var combat_anim_instance: CombatAnimationScene = null
	## All units in the battle (to be freed)
	var all_units: Array[Unit] = []
	## Player units array to clear
	var player_units: Array[Unit] = []
	## Enemy units array to clear
	var enemy_units: Array[Unit] = []
	## Neutral units array to clear
	var neutral_units: Array[Unit] = []
	## Map instance to free
	var map_instance: Node2D = null


## Perform full battle cleanup using the provided context.
## This frees nodes and clears all battle state.
## @param context: CleanupContext containing all references to clean up
## @return Dictionary with cleanup results (for testing/debugging)
static func execute(context: CleanupContext) -> Dictionary:
	var result: Dictionary = {
		"units_freed": 0,
		"combat_anim_freed": false,
		"map_freed": false
	}

	# Clean up combat animation instance
	if context.combat_anim_instance and is_instance_valid(context.combat_anim_instance):
		context.combat_anim_instance.queue_free()
		result.combat_anim_freed = true

	# Free all units
	# Note: We intentionally do NOT attempt to manually disconnect death signals here.
	# GDScript bound callables are not comparable by value - two separately created
	# bound callables (even with identical bindings) are different objects, so
	# is_connected() would always return false. Since queue_free() automatically
	# cleans up all signal connections when the node is freed, manual disconnection
	# is both broken and unnecessary.
	for unit_node: Unit in context.all_units:
		if is_instance_valid(unit_node):
			unit_node.queue_free()
			result.units_freed += 1

	# Clear unit arrays (these are references to the actual arrays in BattleManager)
	context.all_units.clear()
	context.player_units.clear()
	context.enemy_units.clear()
	context.neutral_units.clear()

	# Free map instance
	if context.map_instance and is_instance_valid(context.map_instance):
		context.map_instance.queue_free()
		result.map_freed = true

	# Clear manager state
	TurnManager.clear_battle()
	GridManager.clear_grid()

	return result
