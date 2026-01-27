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


## Distribute battle rewards (gold, items, characters) to the player.
## Emits pre_battle_rewards signal before distribution (mods can modify rewards).
## Emits post_battle_rewards signal after distribution.
## Returns Dictionary with {gold: int, items: Array[String], characters: Array[CharacterData]} of actual rewards given.
static func distribute(battle_data: BattleData) -> Dictionary:
	var rewards: Dictionary = {"gold": 0, "items": [], "characters": []}

	if not battle_data:
		return rewards

	# Read rewards from battle data (direct property access - these are @export vars)
	rewards.gold = battle_data.gold_reward

	# Collect item IDs from item_rewards array
	for item: ItemData in battle_data.item_rewards:
		if item and item.item_id:
			rewards.items.append(item.item_id)

	# Collect character rewards
	for character: CharacterData in battle_data.character_rewards:
		if character:
			rewards.characters.append(character)

	# Allow mods to modify rewards before distribution
	GameEventBus.pre_battle_rewards.emit(battle_data, rewards)

	# Distribute gold
	if rewards.gold > 0:
		SaveManager.add_current_gold(rewards.gold)

	# Distribute items to depot
	if not rewards.items.is_empty() and SaveManager.current_save:
		for item_id: String in rewards.items:
			SaveManager.current_save.depot_items.append(item_id)

	# Add characters to party (use character_uid lookup to avoid reference equality issues)
	for character: CharacterData in rewards.characters:
		if character and PartyManager:
			# Check if character already in party by looking up their save data
			var existing_save: CharacterSaveData = PartyManager.get_member_save_data(character.character_uid)
			if existing_save == null:
				PartyManager.add_member(character, true)

	# Notify mods that rewards were distributed
	GameEventBus.post_battle_rewards.emit(battle_data, rewards)

	return rewards
