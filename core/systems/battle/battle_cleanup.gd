## Handles cleanup of battle state when a battle ends.
##
## This class is responsible for:
## - Disconnecting unit signals to prevent callbacks during cleanup
## - Freeing combat animation instances
## - Clearing unit tracking arrays
## - Freeing map instances
## - Resetting battle data
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
	## All units in the battle (for signal disconnection and freeing)
	var all_units: Array[Unit] = []
	## Player units array to clear
	var player_units: Array[Unit] = []
	## Enemy units array to clear
	var enemy_units: Array[Unit] = []
	## Neutral units array to clear
	var neutral_units: Array[Unit] = []
	## Map instance to free
	var map_instance: Node2D = null
	## Callback to disconnect from unit died signals
	var death_callback: Callable = Callable()


## Perform full battle cleanup using the provided context.
## This disconnects signals, frees nodes, and clears all battle state.
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

	# Disconnect death signals and free units
	for unit_node: Unit in context.all_units:
		if is_instance_valid(unit_node):
			# Disconnect the death signal to prevent callbacks during cleanup
			if unit_node.has_signal("died") and context.death_callback.is_valid():
				var bound_callback: Callable = context.death_callback.bind(unit_node)
				if unit_node.died.is_connected(bound_callback):
					unit_node.died.disconnect(bound_callback)
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
