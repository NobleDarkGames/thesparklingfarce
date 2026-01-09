@tool
class_name ResourcePickerWidget
extends EditorWidgetBase

## Unified picker for all resource types in the cinematic editor
## Consolidates 7 duplicated picker implementations into one reusable widget
##
## Usage:
##   var picker: ResourcePickerWidget = ResourcePickerWidget.new(ResourcePickerWidget.ResourceType.SPEAKER)
##   picker.set_context(context)
##   picker.set_value("max")  # Select character with ID "max"
##   picker.value_changed.connect(_on_speaker_changed)
##   add_child(picker)

enum ResourceType {
	SPEAKER,    # Characters + NPCs combined (handles npc: prefix)
	SHOP,
	BATTLE,
	CINEMATIC,
	MAP,
	SCENE,
	ACTOR
}

## The type of resource this picker displays
var resource_type: ResourceType = ResourceType.SPEAKER

## Whether to allow selecting "(None)"
var allow_none: bool = true

## Label shown for the none option
var none_label: String = "(None)"

var _option_button: OptionButton
var _current_value: String = ""


func _init(p_resource_type: ResourceType = ResourceType.SPEAKER) -> void:
	resource_type = p_resource_type


func _ready() -> void:
	_setup_ui()
	if _context:
		refresh()


func _setup_ui() -> void:
	_option_button = OptionButton.new()
	_option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option_button.item_selected.connect(_on_item_selected)
	add_child(_option_button)


## Override: Set context and refresh the dropdown
func set_context(context: EditorWidgetContext) -> void:
	super.set_context(context)
	if is_inside_tree():
		refresh()


## Override: Set the current value and update selection
func set_value(value: Variant) -> void:
	_current_value = str(value) if value != null else ""
	_select_current_value()


## Override: Get the current value
func get_value() -> Variant:
	return _current_value


## Override: Rebuild the dropdown from context
func refresh() -> void:
	if not _option_button:
		return
	
	_option_button.clear()
	
	# Add none option if allowed
	if allow_none:
		_option_button.add_item(none_label, 0)
		_option_button.set_item_metadata(0, {"type": "none", "id": ""})
	
	# Populate based on resource type
	match resource_type:
		ResourceType.SPEAKER:
			_populate_speakers()
		ResourceType.SHOP:
			_populate_shops()
		ResourceType.BATTLE:
			_populate_battles()
		ResourceType.CINEMATIC:
			_populate_cinematics()
		ResourceType.MAP:
			_populate_maps()
		ResourceType.SCENE:
			_populate_scenes()
		ResourceType.ACTOR:
			_populate_actors()
	
	# Restore selection
	_select_current_value()


# =============================================================================
# Population Methods
# =============================================================================

## Populate with characters first, then NPCs with "(NPC)" suffix
func _populate_speakers() -> void:
	if not _context:
		return
	
	var item_idx: int = _option_button.item_count
	
	# Add characters first
	for char_res: Resource in _context.characters:
		if not char_res:
			continue
		
		var display_name: String = SparklingEditorUtils.get_resource_display_name_with_mod(char_res, "character_name")
		var char_uid: String = _get_character_uid(char_res)
		
		_option_button.add_item(display_name, item_idx)
		_option_button.set_item_metadata(item_idx, {"type": "character", "id": char_uid})
		item_idx += 1
	
	# Add NPCs with visual distinction
	for npc_res: Resource in _context.npcs:
		if not npc_res:
			continue
		
		var display_name: String = ""
		var npc_id: String = ""
		
		# Get display name with fallbacks
		if "npc_name" in npc_res and not str(npc_res.get("npc_name")).is_empty():
			display_name = str(npc_res.get("npc_name"))
		if "npc_id" in npc_res:
			npc_id = str(npc_res.get("npc_id"))
		
		# Fallback to filename
		if display_name.is_empty():
			display_name = npc_res.resource_path.get_file().get_basename()
		if npc_id.is_empty():
			npc_id = npc_res.resource_path.get_file().get_basename()
		
		# Get source mod prefix
		var mod_prefix: String = _get_mod_display_prefix(npc_res)
		var full_display: String = "%s%s (NPC)" % [mod_prefix, display_name]
		
		_option_button.add_item(full_display, item_idx)
		_option_button.set_item_metadata(item_idx, {"type": "npc", "id": npc_id})
		item_idx += 1


## Populate from context.shops
func _populate_shops() -> void:
	if not _context:
		return
	
	var item_idx: int = _option_button.item_count
	
	for shop_res: Resource in _context.shops:
		if not shop_res:
			continue
		
		var shop_id: String = ""
		var shop_name: String = ""
		
		if "shop_id" in shop_res:
			shop_id = str(shop_res.get("shop_id"))
		if "shop_name" in shop_res:
			shop_name = str(shop_res.get("shop_name"))
		
		if shop_id.is_empty():
			shop_id = shop_res.resource_path.get_file().get_basename()
		if shop_name.is_empty():
			shop_name = shop_id
		
		var mod_prefix: String = _get_mod_display_prefix(shop_res)
		var display_name: String = "%s%s" % [mod_prefix, shop_name]
		
		_option_button.add_item(display_name, item_idx)
		_option_button.set_item_metadata(item_idx, shop_id)
		item_idx += 1


## Populate from context.battles
func _populate_battles() -> void:
	if not _context:
		return
	
	var item_idx: int = _option_button.item_count
	
	for battle_res: Resource in _context.battles:
		if not battle_res:
			continue
		
		var battle_id: String = ""
		var battle_name: String = ""
		
		if "battle_id" in battle_res:
			battle_id = str(battle_res.get("battle_id"))
		if "battle_name" in battle_res:
			battle_name = str(battle_res.get("battle_name"))
		
		if battle_id.is_empty():
			battle_id = battle_res.resource_path.get_file().get_basename()
		if battle_name.is_empty():
			battle_name = battle_id
		
		var mod_prefix: String = _get_mod_display_prefix(battle_res)
		var display_name: String = "%s%s" % [mod_prefix, battle_name]
		
		_option_button.add_item(display_name, item_idx)
		_option_button.set_item_metadata(item_idx, battle_id)
		item_idx += 1


## Populate from context.cinematics
func _populate_cinematics() -> void:
	if not _context:
		return
	
	var item_idx: int = _option_button.item_count
	
	for entry: Dictionary in _context.cinematics:
		var cinematic_id: String = entry.get("name", "")
		var mod_id: String = entry.get("mod_id", "")
		
		var display_name: String = "[%s] %s" % [mod_id, cinematic_id] if not mod_id.is_empty() else cinematic_id
		
		_option_button.add_item(display_name, item_idx)
		_option_button.set_item_metadata(item_idx, cinematic_id)
		item_idx += 1


## Populate from context.maps
func _populate_maps() -> void:
	if not _context:
		return
	
	var item_idx: int = _option_button.item_count
	
	for map_res: Resource in _context.maps:
		if not map_res:
			continue
		
		var map_id: String = ""
		var map_name: String = ""
		
		if "map_id" in map_res and not str(map_res.get("map_id")).is_empty():
			map_id = str(map_res.get("map_id"))
		else:
			map_id = map_res.resource_path.get_file().get_basename()
		
		if "display_name" in map_res and not str(map_res.get("display_name")).is_empty():
			map_name = str(map_res.get("display_name"))
		else:
			map_name = map_id
		
		var mod_prefix: String = _get_mod_display_prefix(map_res)
		var display_text: String = "%s%s" % [mod_prefix, map_name]
		
		_option_button.add_item(display_text, item_idx)
		_option_button.set_item_metadata(item_idx, map_id)
		item_idx += 1


## Populate from ModLoader.registry.get_scene_ids()
func _populate_scenes() -> void:
	if not ModLoader or not ModLoader.registry:
		return
	
	var item_idx: int = _option_button.item_count
	var scene_ids: Array[String] = ModLoader.registry.get_scene_ids()
	
	for scene_id: String in scene_ids:
		var mod_id: String = ModLoader.registry.get_scene_source(scene_id)
		var display_name: String = "[%s] %s" % [mod_id, scene_id] if not mod_id.is_empty() else scene_id
		
		_option_button.add_item(display_name, item_idx)
		_option_button.set_item_metadata(item_idx, scene_id)
		item_idx += 1


## Populate from context.actor_ids
func _populate_actors() -> void:
	if not _context:
		return
	
	var item_idx: int = _option_button.item_count
	
	for actor_id: String in _context.actor_ids:
		_option_button.add_item(actor_id, item_idx)
		_option_button.set_item_metadata(item_idx, actor_id)
		item_idx += 1


# =============================================================================
# Helper Methods
# =============================================================================

## Get character UID from a character resource with fallbacks
func _get_character_uid(char_res: Resource) -> String:
	var char_uid: String = ""
	
	# Try direct access for CharacterData
	if char_res is CharacterData:
		char_uid = (char_res as CharacterData).character_uid
	
	# Try get() for safe property access
	if char_uid.is_empty() and char_res.get("character_uid") != null:
		char_uid = str(char_res.get("character_uid"))
	
	# Fallback to filename
	if char_uid.is_empty():
		char_uid = char_res.resource_path.get_file().get_basename()
	
	return char_uid


## Get mod display prefix "[mod_id] " or empty string
func _get_mod_display_prefix(resource: Resource) -> String:
	if not ModLoader or not ModLoader.registry:
		return ""
	
	var resource_id: String = resource.resource_path.get_file().get_basename()
	var mod_id: String = ModLoader.registry.get_resource_source(resource_id)
	
	if mod_id.is_empty():
		return ""
	return "[%s] " % mod_id


## Select the item matching _current_value
func _select_current_value() -> void:
	if not _option_button:
		return
	
	if _current_value.is_empty():
		if allow_none:
			_option_button.select(0)
		return
	
	# For SPEAKER type, handle npc: prefix
	if resource_type == ResourceType.SPEAKER:
		_select_speaker_value()
		return
	
	# For other types, match metadata directly
	for i: int in range(_option_button.item_count):
		var metadata: Variant = _option_button.get_item_metadata(i)
		if metadata is String and metadata == _current_value:
			_option_button.select(i)
			return
		elif metadata is Dictionary:
			var meta_dict: Dictionary = metadata
			if meta_dict.get("id", "") == _current_value:
				_option_button.select(i)
				return
	
	# Value not found - select none if allowed
	if allow_none:
		_option_button.select(0)


## Select speaker value, handling npc: prefix
func _select_speaker_value() -> void:
	var is_npc: bool = _is_npc_value(_current_value)
	var search_id: String = _parse_npc_value(_current_value) if is_npc else _current_value
	var search_type: String = "npc" if is_npc else "character"
	
	for i: int in range(_option_button.item_count):
		var metadata: Variant = _option_button.get_item_metadata(i)
		if metadata is Dictionary:
			var meta_dict: Dictionary = metadata
			if meta_dict.get("type", "") == search_type and meta_dict.get("id", "") == search_id:
				_option_button.select(i)
				return
	
	# Value not found - select none if allowed
	if allow_none:
		_option_button.select(0)


## Handle item selection from dropdown
func _on_item_selected(index: int) -> void:
	var metadata: Variant = _option_button.get_item_metadata(index)
	var new_value: String = ""
	
	if metadata is String:
		new_value = metadata
	elif metadata is Dictionary:
		var meta_dict: Dictionary = metadata
		var meta_type: String = meta_dict.get("type", "")
		var meta_id: String = meta_dict.get("id", "")
		
		# TODO: Refactor NPC handling - consider unified speaker registry
		# For now, use npc: prefix to distinguish NPCs from characters
		if meta_type == "npc":
			new_value = _format_npc_value(meta_id)
		elif meta_type == "none":
			new_value = ""
		else:
			new_value = meta_id
	
	_current_value = new_value
	value_changed.emit(new_value)


# =============================================================================
# NPC Prefix Handling
# =============================================================================
# TODO: Refactor NPC handling - consider unified speaker registry
# The npc: prefix is a workaround for distinguishing NPCs from characters
# in the same dropdown. A better solution would be a unified speaker system.

## Check if a value represents an NPC (has npc: prefix)
func _is_npc_value(value: String) -> bool:
	return value.begins_with("npc:")


## Format an NPC ID with the npc: prefix
func _format_npc_value(npc_id: String) -> String:
	return "npc:" + npc_id


## Parse an NPC value to get the raw ID (strips npc: prefix)
func _parse_npc_value(value: String) -> String:
	if value.begins_with("npc:"):
		return value.substr(4)
	return value
