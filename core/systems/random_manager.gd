extends Node

## RandomManager - Centralized RNG for deterministic gameplay
##
## Provides seeded random number generation for:
## - Combat calculations (damage variance, hit/crit rolls)
## - AI decision making
## - Procedural content generation
##
## Benefits:
## - Reproducible battles for replays and debugging
## - Separate seeds for different systems (prevents AI affecting combat RNG)
## - Seed export/import for sharing/streaming
##
## Usage:
##   RandomManager.combat_rng.randi_range(0, 100)
##   RandomManager.set_combat_seed(12345)  # For deterministic testing

# ============================================================================
# RNG INSTANCES (separate to prevent cross-contamination)
# ============================================================================

## Combat RNG - Used for damage variance, hit rolls, critical hit rolls
var combat_rng: RandomNumberGenerator = RandomNumberGenerator.new()

## AI RNG - Used for AI decision making, target selection
var ai_rng: RandomNumberGenerator = RandomNumberGenerator.new()

## World RNG - Used for procedural content, random events, loot drops
var world_rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ============================================================================
# SEED TRACKING
# ============================================================================

## Store initial seeds for replay/debugging
var _combat_seed: int = 0
var _ai_seed: int = 0
var _world_seed: int = 0

## Track if seeds were explicitly set (vs random)
var _seeds_are_deterministic: bool = false


func _ready() -> void:
	# Initialize with random seeds by default
	randomize_all_seeds()


# ============================================================================
# SEED MANAGEMENT
# ============================================================================

## Randomize all seeds (default behavior at game start)
func randomize_all_seeds() -> void:
	_combat_seed = randi()
	_ai_seed = randi()
	_world_seed = randi()

	combat_rng.seed = _combat_seed
	ai_rng.seed = _ai_seed
	world_rng.seed = _world_seed

	_seeds_are_deterministic = false


## Set all seeds at once (for deterministic replays)
func set_all_seeds(combat_seed: int, ai_seed: int, world_seed: int) -> void:
	_combat_seed = combat_seed
	_ai_seed = ai_seed
	_world_seed = world_seed

	combat_rng.seed = combat_seed
	ai_rng.seed = ai_seed
	world_rng.seed = world_seed

	_seeds_are_deterministic = true


## Set combat seed only (for testing specific battle outcomes)
func set_combat_seed(seed_value: int) -> void:
	_combat_seed = seed_value
	combat_rng.seed = seed_value
	_seeds_are_deterministic = true


## Set AI seed only (for testing AI behavior)
func set_ai_seed(seed_value: int) -> void:
	_ai_seed = seed_value
	ai_rng.seed = seed_value
	_seeds_are_deterministic = true


## Set world seed only (for reproducible map/event generation)
func set_world_seed(seed_value: int) -> void:
	_world_seed = seed_value
	world_rng.seed = seed_value
	_seeds_are_deterministic = true


## Reset seeds to their initial values (replay from start)
func reset_all_seeds() -> void:
	combat_rng.seed = _combat_seed
	ai_rng.seed = _ai_seed
	world_rng.seed = _world_seed


# ============================================================================
# CONVENIENCE METHODS (combat focused)
# ============================================================================

## Roll for hit (returns true if hit succeeds)
## @param hit_chance: Percentage chance (0-100)
func roll_hit(hit_chance: int) -> bool:
	return combat_rng.randi_range(1, 100) <= hit_chance


## Roll for critical hit (returns true if crit)
## @param crit_chance: Percentage chance (0-100)
func roll_crit(crit_chance: int) -> bool:
	return combat_rng.randi_range(1, 100) <= crit_chance


## Get damage variance multiplier (typically 0.9 to 1.1)
## @param min_mult: Minimum multiplier (default 0.9)
## @param max_mult: Maximum multiplier (default 1.1)
func get_damage_variance(min_mult: float = 0.9, max_mult: float = 1.1) -> float:
	return combat_rng.randf_range(min_mult, max_mult)


## Roll for counter attack
## @param counter_chance: Percentage chance (0-100)
func roll_counter(counter_chance: int) -> bool:
	return combat_rng.randi_range(1, 100) <= counter_chance


## Roll a dice (d6, d20, etc.)
## @param sides: Number of sides on the die
## @param count: Number of dice to roll (default 1)
func roll_dice(sides: int, count: int = 1) -> int:
	var total: int = 0
	for _i: int in range(count):
		total += combat_rng.randi_range(1, sides)
	return total


# ============================================================================
# EXPORT/IMPORT (for saves and replays)
# ============================================================================

## Export seed state for saving
func export_seeds() -> Dictionary:
	return {
		"combat_seed": _combat_seed,
		"ai_seed": _ai_seed,
		"world_seed": _world_seed,
		"deterministic": _seeds_are_deterministic,
		# Also export current RNG state for mid-game saves
		"combat_state": combat_rng.state,
		"ai_state": ai_rng.state,
		"world_state": world_rng.state,
	}


## Import seed state from save
func import_seeds(data: Dictionary) -> void:
	_combat_seed = data["combat_seed"] if ("combat_seed" in data and data["combat_seed"] is int) else randi()
	_ai_seed = data["ai_seed"] if ("ai_seed" in data and data["ai_seed"] is int) else randi()
	_world_seed = data["world_seed"] if ("world_seed" in data and data["world_seed"] is int) else randi()
	_seeds_are_deterministic = data["deterministic"] if ("deterministic" in data and data["deterministic"] is bool) else false

	# Restore RNG state if available (mid-game saves)
	if "combat_state" in data and data["combat_state"] is int:
		combat_rng.state = data["combat_state"]
	else:
		combat_rng.seed = _combat_seed

	if "ai_state" in data and data["ai_state"] is int:
		ai_rng.state = data["ai_state"]
	else:
		ai_rng.seed = _ai_seed

	if "world_state" in data and data["world_state"] is int:
		world_rng.state = data["world_state"]
	else:
		world_rng.seed = _world_seed


## Get debug string showing current seeds
func get_debug_string() -> String:
	return "RandomManager: combat=%d ai=%d world=%d (deterministic=%s)" % [
		_combat_seed, _ai_seed, _world_seed, _seeds_are_deterministic
	]
