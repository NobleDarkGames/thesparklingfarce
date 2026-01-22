## Handles distribution of battle rewards (gold and items) to the player.
##
## This class is responsible for:
## - Reading rewards from BattleData
## - Emitting pre/post signals for mod hooks
## - Distributing gold via SaveManager
## - Adding items to the depot
##
## Extracted from BattleManager to improve modularity and testability.
class_name BattleRewardsDistributor
extends RefCounted


## Distribute battle rewards (gold and items) to the player.
## Emits pre_battle_rewards signal before distribution (mods can modify rewards).
## Emits post_battle_rewards signal after distribution.
## Returns Dictionary with {gold: int, items: Array[String]} of actual rewards given.
static func distribute(battle_data: BattleData) -> Dictionary:
	var rewards: Dictionary = {"gold": 0, "items": []}

	if not battle_data:
		return rewards

	# Read rewards from battle data
	rewards.gold = battle_data.gold_reward if "gold_reward" in battle_data else 0

	# Collect item IDs from item_rewards array
	if "item_rewards" in battle_data and battle_data.item_rewards:
		for item: ItemData in battle_data.item_rewards:
			if item and item.item_id:
				rewards.items.append(item.item_id)

	# Allow mods to modify rewards before distribution
	GameEventBus.pre_battle_rewards.emit(battle_data, rewards)

	# Distribute gold
	if rewards.gold > 0:
		SaveManager.add_current_gold(rewards.gold)

	# Distribute items to depot
	if not rewards.items.is_empty() and SaveManager.current_save:
		for item_id: String in rewards.items:
			SaveManager.current_save.depot_items.append(item_id)

	# Notify mods that rewards were distributed
	GameEventBus.post_battle_rewards.emit(battle_data, rewards)

	return rewards
