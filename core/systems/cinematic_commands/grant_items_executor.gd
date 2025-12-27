## GrantItemsExecutor - Grants items and gold to the party
##
## Parameters:
##   items: Array[Dictionary] - [{item_id: String, quantity: int (optional, default 1)}]
##   gold: int - Gold amount to grant (default: 0)
##   recipient: String - "hero" (default) or character_uid for specific member
##   show_message: bool - Show "Found X!" messages (default: true)
##   silent: bool - If true, grants without any message (default: false)
##
## SF2-AUTHENTIC BEHAVIOR:
## - Immediate feedback: "Found [item]!"
## - Gold shown as "Found X Gold!"
## - Inventory full: "Inventory full! Item sent to caravan."
## - No caravan: "Could not carry [item]."
class_name GrantItemsExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})

	var items: Array = params.get("items", [])
	var gold_amount: int = params.get("gold", 0)
	var recipient: String = params.get("recipient", "hero")
	var show_message: bool = params.get("show_message", true)
	var silent: bool = params.get("silent", false)

	var messages: Array[String] = []

	# Grant gold first
	if gold_amount > 0:
		var new_total: int = SaveManager.add_current_gold(gold_amount)
		if new_total >= 0 and not silent:
			messages.append("Found %d Gold!" % gold_amount)

	# Determine recipient character
	var recipient_uid: String = _resolve_recipient_uid(recipient)

	# Grant each item
	for item_entry: Variant in items:
		var item_id: String = ""
		var quantity: int = 1

		if item_entry is String:
			item_id = item_entry
		elif item_entry is Dictionary:
			var item_dict: Dictionary = item_entry
			item_id = item_dict.get("item_id", "")
			quantity = item_dict.get("quantity", 1)

		if item_id.is_empty():
			continue

		# Grant the item (possibly multiple times)
		for i: int in range(quantity):
			var result: Dictionary = _grant_single_item(item_id, recipient_uid)
			if not silent:
				messages.append(result.get("message", ""))

	# Show messages if any
	if show_message and not messages.is_empty() and not silent:
		return _show_found_messages(messages, manager)

	return true  # Synchronous completion


## Resolve recipient to character UID
func _resolve_recipient_uid(recipient: String) -> String:
	if recipient == "hero" or recipient.is_empty():
		var hero: CharacterData = PartyManager.get_hero()
		if hero:
			return hero.get_uid()
		push_warning("GrantItemsExecutor: No hero found")
		return ""

	# Assume it's already a character UID
	return recipient


## Grant a single item, handling inventory overflow
## @return: Dictionary with {success: bool, message: String}
func _grant_single_item(item_id: String, recipient_uid: String) -> Dictionary:
	var item_name: String = _get_item_display_name(item_id)

	# Try to add to recipient's inventory
	if not recipient_uid.is_empty():
		var success: bool = PartyManager.add_item_to_member(recipient_uid, item_id)
		if success:
			return {"success": true, "message": "Found %s!" % item_name}

	# Inventory full - try caravan
	if StorageManager.is_caravan_available():
		var caravan_success: bool = StorageManager.add_to_depot(item_id)
		if caravan_success:
			return {
				"success": true,
				"message": "Found %s! (Sent to caravan)" % item_name
			}

	# No room anywhere
	return {
		"success": false,
		"message": "Could not carry %s." % item_name
	}


## Get display name for an item
func _get_item_display_name(item_id: String) -> String:
	if ModLoader and ModLoader.registry:
		var item: ItemData = ModLoader.registry.get_resource("item", item_id) as ItemData
		if item and "item_name" in item:
			return item.item_name
	return item_id


## Show found messages via dialog system
## @return: false (async - waiting for dialog)
func _show_found_messages(messages: Array[String], manager: Node) -> bool:
	# Filter empty messages
	var valid_messages: Array[String] = []
	for msg: String in messages:
		if not msg.is_empty():
			valid_messages.append(msg)

	if valid_messages.is_empty():
		return true  # Nothing to show

	# Combine messages into a single dialog
	var combined_text: String = "\n".join(valid_messages)

	# Use base class helper to show system message
	return CinematicCommandExecutor.show_system_message(combined_text, manager)


## Editor metadata for cinematic editor
func get_editor_metadata() -> Dictionary:
	return {
		"description": "Grant items and/or gold to the party",
		"category": "Rewards",
		"icon": "Heart",
		"has_target": false,
		"params": {
			"items": {
				"type": "array",
				"default": [],
				"hint": "Items to grant: [{item_id: String, quantity: int}]"
			},
			"gold": {
				"type": "int",
				"default": 0,
				"min": 0,
				"max": 99999,
				"hint": "Gold amount to grant"
			},
			"recipient": {
				"type": "string",
				"default": "hero",
				"hint": "Who receives items: 'hero' or character_uid"
			},
			"show_message": {
				"type": "bool",
				"default": true,
				"hint": "Show 'Found X!' messages"
			},
			"silent": {
				"type": "bool",
				"default": false,
				"hint": "Grant without any message or dialog"
			}
		}
	}
