class_name AIBrain
extends Resource

## Abstract base class for AI behavior strategies.
##
## Subclass this to create custom AI behaviors for enemies/neutrals.
## Each AIBrain is CONTENT (stored in mods/) while AIController is ENGINE.
##
## Design Philosophy:
## - Each unit can have a unique AIBrain resource
## - AI brains are stateless (no persistent state between turns)
## - Context dictionary provides all battle state needed for decisions
## - Modders can create custom AI brains without touching engine code

## Called by AIController when it's this unit's turn
## Subclasses MUST override this method
## @param unit: The unit taking its turn
## @param context: Dictionary with battle state (player_units, enemy_units, etc.)
func execute(unit: Node2D, context: Dictionary) -> void:
	push_error("AIBrain.execute() must be overridden by subclass: %s" % get_class())


## Async version of execute - waits for movement animations to complete
## Override this in subclasses for async behavior, or keep execute() for backwards compatibility
func execute_async(unit: Node2D, context: Dictionary) -> void:
	# Default implementation calls the synchronous execute() and waits
	execute(unit, context)

	# Wait for unit movement animation to complete
	await unit.await_movement_completion()


## Helper: Get all player units from context
func get_player_units(context: Dictionary) -> Array[Node2D]:
	if "player_units" in context:
		return context.player_units
	return []


## Helper: Get all enemy units from context
func get_enemy_units(context: Dictionary) -> Array[Node2D]:
	if "enemy_units" in context:
		return context.enemy_units
	return []


## Helper: Get all neutral units from context
func get_neutral_units(context: Dictionary) -> Array[Node2D]:
	if "neutral_units" in context:
		return context.neutral_units
	return []


## Helper: Find nearest target unit to this unit
func find_nearest_target(unit: Node2D, targets: Array[Node2D]) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: int = 9999

	for target in targets:
		if not target.is_alive():
			continue

		var distance: int = GridManager.grid.get_manhattan_distance(
			unit.grid_position,
			target.grid_position
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest = target

	return nearest


## Helper: Check if target is in attack range
## Uses unit's equipped weapon range (min/max) to support ranged weapons and dead zones
func is_in_attack_range(unit: Node2D, target: Node2D) -> bool:
	if not unit or not target:
		return false

	var distance: int = GridManager.grid.get_manhattan_distance(
		unit.grid_position,
		target.grid_position
	)

	# Use unit's weapon range from stats (handles min/max range bands)
	if unit.stats:
		return unit.stats.can_attack_at_distance(distance)

	# Fallback: unarmed melee (range 1 only)
	return distance == 1


## Helper: Move unit toward target position
## Returns true if movement succeeded
func move_toward_target(unit: Node2D, target_position: Vector2i) -> bool:
	if not unit:
		return false

	var unit_class: ClassData = unit.get_current_class()
	if not unit_class:
		return false

	var movement_range: int = unit_class.movement_range
	var movement_type: int = unit_class.movement_type

	# Find path to target (NOTE: target position is likely occupied)
	# Pass unit faction to allow passing through allies
	var path: Array[Vector2i] = GridManager.find_path(
		unit.grid_position,
		target_position,
		movement_type,
		unit.faction
	)

	# If direct path fails (target occupied), find path to nearest adjacent cell
	if path.is_empty():
		var best_adjacent: Vector2i = _find_best_adjacent_cell(unit.grid_position, target_position, movement_type)
		if best_adjacent != Vector2i(-1, -1):
			path = GridManager.find_path(unit.grid_position, best_adjacent, movement_type, unit.faction)

	if path.is_empty():
		return false

	# Trim path to movement range (path includes starting position)
	var max_path_length: int = mini(movement_range + 1, path.size())
	var trimmed_path: Array[Vector2i] = path.slice(0, max_path_length)

	# Get final destination from trimmed path
	var destination: Vector2i = trimmed_path[trimmed_path.size() - 1]

	# Don't "move" if already at destination
	if destination == unit.grid_position:
		return false

	# Move along the full path (animates through each cell)
	unit.move_along_path(trimmed_path)
	return true


## Helper: Find best unoccupied adjacent cell to target
func _find_best_adjacent_cell(from: Vector2i, target: Vector2i, movement_type: int) -> Vector2i:
	var adjacent_cells: Array[Vector2i] = GridManager.grid.get_neighbors(target)
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_distance: int = 9999

	for cell in adjacent_cells:
		# Skip occupied cells
		if GridManager.is_cell_occupied(cell):
			continue

		# Check if walkable
		var terrain_cost: int = GridManager.get_terrain_cost(cell, movement_type)
		if terrain_cost >= GridManager.MAX_TERRAIN_COST:
			continue

		# Find closest to our current position
		var distance: int = GridManager.grid.get_manhattan_distance(from, cell)
		if distance < best_distance:
			best_distance = distance
			best_cell = cell

	return best_cell


## Helper: Attack target unit
## Signals BattleManager to execute the attack
func attack_target(unit: Node2D, target: Node2D) -> void:
	if not unit or not target:
		push_error("AIBrain: Cannot attack with null unit or target")
		return

	# Delegate to BattleManager for actual combat execution
	await BattleManager.execute_ai_attack(unit, target)
