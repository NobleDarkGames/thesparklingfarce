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
func execute(unit: Unit, context: Dictionary) -> void:
	push_error("AIBrain.execute() must be overridden by subclass: %s" % get_class())


## Async version of execute - waits for movement animations to complete
## Override this in subclasses for async behavior, or keep execute() for backwards compatibility
func execute_async(unit: Unit, context: Dictionary) -> void:
	# Default implementation calls the synchronous execute() and waits
	execute(unit, context)

	# Wait for unit movement animation to complete
	await unit.await_movement_completion()


## Helper: Get all player units from context
func get_player_units(context: Dictionary) -> Array[Unit]:
	if "player_units" in context:
		var units_variant: Variant = context.get("player_units")
		if units_variant is Array[Unit]:
			return units_variant
	return []


## Helper: Get all enemy units from context
func get_enemy_units(context: Dictionary) -> Array[Unit]:
	if "enemy_units" in context:
		var units_variant: Variant = context.get("enemy_units")
		if units_variant is Array[Unit]:
			return units_variant
	return []


## Helper: Get all neutral units from context
func get_neutral_units(context: Dictionary) -> Array[Unit]:
	if "neutral_units" in context:
		var units_variant: Variant = context.get("neutral_units")
		if units_variant is Array[Unit]:
			return units_variant
	return []


## Helper: Find nearest target unit to this unit
func find_nearest_target(unit: Unit, targets: Array[Unit]) -> Unit:
	if not GridManager or not GridManager.grid:
		return null

	var nearest: Unit = null
	var nearest_distance: int = 9999

	for target: Unit in targets:
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
func is_in_attack_range(unit: Unit, target: Unit) -> bool:
	if not unit or not target:
		return false
	if not GridManager or not GridManager.grid:
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
func move_toward_target(unit: Unit, target_position: Vector2i) -> bool:
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
	if not GridManager or not GridManager.grid:
		return Vector2i(-1, -1)
	var adjacent_cells: Array[Vector2i] = GridManager.grid.get_neighbors(target)
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_distance: int = 9999

	for cell: Vector2i in adjacent_cells:
		# Skip occupied cells
		if GridManager.is_cell_occupied(cell):
			continue

		# Check if walkable
		var terrain_cost: int = GridManager.get_terrain_cost(cell, movement_type)
		if terrain_cost >= GridManager.MAX_TERRAIN_COST:
			continue

		# Find closest to our current position (grid null check done at function start)
		var distance: int = GridManager.grid.get_manhattan_distance(from, cell)
		if distance < best_distance:
			best_distance = distance
			best_cell = cell

	return best_cell


## Helper: Move unit into attack range of target
## Respects weapon min/max range (avoids dead zones for ranged weapons)
## If behavior is provided and seek_terrain_advantage is true, prefers defensive terrain
## Returns true if movement succeeded
func move_into_attack_range(unit: Unit, target: Unit, behavior: AIBehaviorData = null) -> bool:
	if not unit or not target:
		return false

	var unit_class: ClassData = unit.get_current_class()
	if not unit_class:
		return false

	# Get weapon range band
	var min_range: int = 1
	var max_range: int = 1
	if unit.stats:
		min_range = unit.stats.get_weapon_min_range()
		max_range = unit.stats.get_weapon_max_range()

	var movement_range: int = unit_class.movement_range
	var reachable: Array[Vector2i] = GridManager.get_walkable_cells(
		unit.grid_position, movement_range, unit_class.movement_type, unit.faction
	)

	# Find best cell that puts us in weapon range of target
	var best_cell: Vector2i = unit.grid_position
	var best_score: float = -999.0
	var target_pos: Vector2i = target.grid_position

	for cell: Vector2i in reachable:
		# Skip occupied cells (except our current position)
		if cell != unit.grid_position and GridManager.is_cell_occupied(cell):
			continue

		var dist_to_target: int = GridManager.grid.get_manhattan_distance(cell, target_pos)

		# Check if this cell is within valid attack range
		var in_range: bool = dist_to_target >= min_range and dist_to_target <= max_range

		if in_range:
			# Prefer cells that minimize movement (conserve position)
			var movement_cost: int = GridManager.grid.get_manhattan_distance(unit.grid_position, cell)
			var score: float = 100.0 - movement_cost  # In range, minimize movement

			# For ranged units, slightly prefer staying at max range (safer)
			if max_range > 1:
				score += (dist_to_target - min_range) * 0.5

			# Terrain advantage: prefer cells with defense/evasion bonuses
			if behavior and behavior.seek_terrain_advantage:
				var terrain: TerrainData = GridManager.get_terrain_at_cell(cell)
				if terrain:
					score += terrain.defense_bonus * 2.0
					score += terrain.evasion_bonus * 0.5

			if score > best_score:
				best_score = score
				best_cell = cell
		elif best_score < 0:
			# Not in range yet, but track closest approach
			var dist_to_range: int = dist_to_target - max_range if dist_to_target > max_range else min_range - dist_to_target
			var score: float = -dist_to_range  # Negative score, closer is better
			if score > best_score:
				best_score = score
				best_cell = cell

	# Don't move if already at best position
	if best_cell == unit.grid_position:
		return false

	# Find path to best cell and move
	var path: Array[Vector2i] = GridManager.find_path(
		unit.grid_position, best_cell, unit_class.movement_type, unit.faction
	)

	if path.is_empty():
		return false

	unit.move_along_path(path)
	return true


## Helper: Attack target unit
## Signals BattleManager to execute the attack
func attack_target(unit: Unit, target: Unit) -> void:
	if not unit or not target:
		push_error("AIBrain: Cannot attack with null unit or target")
		return

	# Delegate to BattleManager for actual combat execution
	await BattleManager.execute_ai_attack(unit, target)
