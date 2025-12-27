extends Node

## GameEventBus - Central event broadcasting system for mod hooks
##
## Provides pre-event and post-event signals that mods can connect to
## for intercepting, modifying, or extending game behavior.
##
## Event Flow:
##   1. Game system emits pre_event (mods can modify/cancel)
##   2. Game system performs action
##   3. Game system emits post_event (mods can react)
##
## Cancellation:
##   Pre-event handlers can set event_cancelled = true to prevent the action.
##   The game system is responsible for checking this flag.
##
## Usage (game systems):
##   GameEventBus.emit_pre_attack(attacker, defender, weapon)
##   if GameEventBus.event_cancelled:
##       return  # Mod cancelled the attack
##   # perform attack
##   GameEventBus.emit_post_attack(attacker, defender, damage)
##
## Usage (mods):
##   func _ready():
##       GameEventBus.pre_attack.connect(_on_pre_attack)
##
##   func _on_pre_attack(attacker: Node, defender: Node, weapon: Resource):
##       if defender.has_shield_of_protection:
##           GameEventBus.cancel_event()  # Prevent the attack

# ============================================================================
# CANCELLATION STATE
# ============================================================================

## Set to true by mods to cancel the current event
## Game systems must check this after emitting pre-events
var event_cancelled: bool = false

## Optional reason for cancellation (for logging/feedback)
var cancellation_reason: String = ""


# ============================================================================
# PRE-EVENT SIGNALS (mods can modify or cancel)
# ============================================================================

## Before a unit attacks another
## @param attacker: The attacking unit node
## @param defender: The defending unit node
## @param weapon: The weapon resource being used (may be null for unarmed)
signal pre_attack(attacker: Node, defender: Node, weapon: Resource)

## Before damage is applied to a unit
## @param target: The unit receiving damage
## @param damage: The calculated damage amount (can be modified via context)
## @param source: What caused the damage (attacker node, ability, trap, etc.) - may be null
## @param context: Dictionary with additional info (can modify "final_damage")
signal pre_damage(target: Node, damage: int, source: Object, context: Dictionary)

## Before a unit moves to a new position
## @param unit: The unit attempting to move
## @param from_pos: Current grid position
## @param to_pos: Target grid position
## @param path: Array of positions along the path
signal pre_move(unit: Node, from_pos: Vector2i, to_pos: Vector2i, path: Array)

## Before an ability/spell is cast
## @param caster: The unit casting the ability
## @param ability: The AbilityData resource
## @param targets: Array of target nodes
signal pre_ability_cast(caster: Node, ability: Resource, targets: Array)

## Before an item is used
## @param user: The unit using the item
## @param item: The ItemData resource
## @param target: The target of the item (may be self or another unit)
signal pre_item_use(user: Node, item: Resource, target: Node)

## Before a battle begins
## @param battle_data: The BattleData resource for the upcoming battle
signal pre_battle_start(battle_data: Resource)

## Before a unit's turn begins
## @param unit: The unit whose turn is starting
signal pre_turn_start(unit: Node)

## Before a level-up is applied
## @param unit: The unit leveling up
## @param new_level: The level they're reaching
## @param stat_gains: Dictionary of stat increases (can be modified)
signal pre_level_up(unit: Node, new_level: int, stat_gains: Dictionary)

## Before a shop transaction
## @param transaction_type: "buy" or "sell"
## @param item: The ItemData being traded
## @param price: The price in gold
## @param buyer: Who is buying (player unit or shop) - may be null
## @param seller: Who is selling (shop or player unit) - may be null
signal pre_shop_transaction(transaction_type: String, item: Resource, price: int, buyer: Object, seller: Object)

## Before saving the game
## @param save_data: The SaveData about to be written (can be modified)
## @param slot_number: The save slot
signal pre_save(save_data: Resource, slot_number: int)


# ============================================================================
# POST-EVENT SIGNALS (mods can react, cannot cancel)
# ============================================================================

## After an attack resolves
## @param attacker: The attacking unit
## @param defender: The defending unit
## @param result: Dictionary with attack outcome (hit, crit, damage, etc.)
signal post_attack(attacker: Node, defender: Node, result: Dictionary)

## After damage is applied
## @param target: The unit that received damage
## @param damage: The actual damage dealt
## @param source: What caused the damage - may be null
## @param remaining_hp: Target's HP after damage
signal post_damage(target: Node, damage: int, source: Object, remaining_hp: int)

## After a unit dies
## @param unit: The unit that died
## @param killer: What killed them (may be null for environmental)
signal post_death(unit: Node, killer: Object)

## After a unit moves
## @param unit: The unit that moved
## @param from_pos: Where they were
## @param to_pos: Where they are now
signal post_move(unit: Node, from_pos: Vector2i, to_pos: Vector2i)

## After an ability/spell resolves
## @param caster: The unit that cast
## @param ability: The ability used
## @param targets: Array of targets
## @param results: Array of result dictionaries
signal post_ability_cast(caster: Node, ability: Resource, targets: Array, results: Array)

## After an item is used
## @param user: The unit that used the item
## @param item: The item used
## @param target: The target
## @param result: Dictionary with usage outcome
signal post_item_use(user: Node, item: Resource, target: Node, result: Dictionary)

## After a battle ends
## @param battle_data: The battle that ended
## @param victory: Whether the player won
## @param stats: Dictionary with battle statistics
signal post_battle_end(battle_data: Resource, victory: bool, stats: Dictionary)

## Before battle rewards are distributed (mods can modify rewards)
## @param battle_data: The completed battle
## @param rewards: Dictionary with {gold: int, items: Array[String]} - can be modified
signal pre_battle_rewards(battle_data: Resource, rewards: Dictionary)

## After battle rewards are distributed
## @param battle_data: The completed battle
## @param rewards: Dictionary with {gold: int, items: Array[String]} - final values
signal post_battle_rewards(battle_data: Resource, rewards: Dictionary)

## After a unit's turn ends
## @param unit: The unit whose turn ended
signal post_turn_end(unit: Node)

## After a level-up is applied
## @param unit: The unit that leveled up
## @param new_level: Their new level
## @param stat_gains: Dictionary of actual stat increases applied
signal post_level_up(unit: Node, new_level: int, stat_gains: Dictionary)

## After a shop transaction completes
## @param transaction_type: "buy" or "sell"
## @param item: The item traded
## @param price: The price paid
signal post_shop_transaction(transaction_type: String, item: Resource, price: int)

## After loading a save
## @param save_data: The loaded SaveData
## @param slot_number: The save slot
signal post_load(save_data: Resource, slot_number: int)


# ============================================================================
# CANCELLATION API
# ============================================================================

## Cancel the current event (call from pre-event handlers)
## @param reason: Optional reason for cancellation (for logging)
func cancel_event(reason: String = "") -> void:
	event_cancelled = true
	cancellation_reason = reason


## Check if event was cancelled and reset for next event
## Game systems should call this after emitting pre-events
## @return: true if event was cancelled
func check_and_reset_cancellation() -> bool:
	var was_cancelled: bool = event_cancelled
	event_cancelled = false
	cancellation_reason = ""
	return was_cancelled


## Reset cancellation state (call before emitting pre-events)
func reset_cancellation() -> void:
	event_cancelled = false
	cancellation_reason = ""


# ============================================================================
# CONVENIENCE EMITTERS (optional - systems can emit directly)
# ============================================================================

## Emit pre-attack and check for cancellation
## @return: true if attack should proceed, false if cancelled
func emit_pre_attack(attacker: Node, defender: Node, weapon: Resource) -> bool:
	reset_cancellation()
	pre_attack.emit(attacker, defender, weapon)
	return not check_and_reset_cancellation()


## Emit pre-damage with modifiable context
## @return: The final damage after mod modifications (or -1 if cancelled)
func emit_pre_damage(target: Node, damage: int, source: Object) -> int:
	reset_cancellation()
	var context: Dictionary = {"final_damage": damage}
	pre_damage.emit(target, damage, source, context)
	if check_and_reset_cancellation():
		return -1  # Cancelled
	return context.get("final_damage", damage)


## Emit pre-move and check for cancellation
## @return: true if move should proceed, false if cancelled
func emit_pre_move(unit: Node, from_pos: Vector2i, to_pos: Vector2i, path: Array) -> bool:
	reset_cancellation()
	pre_move.emit(unit, from_pos, to_pos, path)
	return not check_and_reset_cancellation()


## Emit pre-ability-cast and check for cancellation
## @return: true if cast should proceed, false if cancelled
func emit_pre_ability_cast(caster: Node, ability: Resource, targets: Array) -> bool:
	reset_cancellation()
	pre_ability_cast.emit(caster, ability, targets)
	return not check_and_reset_cancellation()


## Emit pre-level-up with modifiable stat gains
## @return: The (potentially modified) stat gains dictionary
func emit_pre_level_up(unit: Node, new_level: int, stat_gains: Dictionary) -> Dictionary:
	reset_cancellation()
	pre_level_up.emit(unit, new_level, stat_gains)
	# Even if "cancelled", return the stat gains (cancellation = skip animation, not skip levelup)
	return stat_gains
