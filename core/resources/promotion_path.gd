class_name PromotionPath
extends Resource

## Represents a single promotion path from one class to another.
##
## A class can have multiple promotion paths, each optionally requiring an item.
## Examples:
##   - Knight -> Paladin (no item)
##   - Knight -> Pegasus Knight (requires Pegasus Wing)
##   - Knight -> Dark Knight (requires Dark Stone)
##
## Class-level settings (promotion_level, promotion_resets_level, consume_promotion_item)
## apply to ALL paths and remain on ClassData.

## The class this path leads to
@export var target_class: ClassData

## Item required to unlock this promotion path (null = always available)
## When set, the player must have this item in inventory to see/choose this path
@export var required_item: ItemData

## Optional custom name for this path (shown in UI when choosing)
## If empty, uses target_class.display_name
@export var path_name: String = ""


## Get the display name for this promotion path
## Returns path_name if set, otherwise target_class.display_name
func get_display_name() -> String:
	if not path_name.is_empty():
		return path_name
	if target_class:
		return target_class.display_name
	return "Unknown"


## Check if this path requires an item
func requires_item() -> bool:
	return required_item != null


## Validate this promotion path
## Returns true if the path is properly configured
func is_valid() -> bool:
	return target_class != null
