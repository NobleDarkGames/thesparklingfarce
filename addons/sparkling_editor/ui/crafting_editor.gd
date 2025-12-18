@tool
extends Control

## Crafting Editor - Combined Crafter and Recipe management
##
## Provides a unified interface for the crafting system with two tabs:
## - Crafters: NPCs/locations that can perform crafting
## - Recipes: What can be crafted and material requirements

# =============================================================================
# SUB-EDITORS
# =============================================================================

var crafter_editor: Control
var recipe_editor: Control
var tab_container: TabContainer


func _ready() -> void:
	name = "CraftingEditor"
	_build_ui()


func _build_ui() -> void:
	# Main layout
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_vbox)

	# Tab container for sub-editors
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(tab_container)

	# Load crafter editor
	var crafter_scene: PackedScene = load("res://addons/sparkling_editor/ui/crafter_editor.tscn")
	if crafter_scene:
		crafter_editor = crafter_scene.instantiate()
		crafter_editor.name = "Crafters"
		tab_container.add_child(crafter_editor)
	else:
		push_error("CraftingEditor: Failed to load crafter_editor.tscn")

	# Load recipe editor
	var recipe_scene: PackedScene = load("res://addons/sparkling_editor/ui/crafting_recipe_editor.tscn")
	if recipe_scene:
		recipe_editor = recipe_scene.instantiate()
		recipe_editor.name = "Recipes"
		tab_container.add_child(recipe_editor)
	else:
		push_error("CraftingEditor: Failed to load crafting_recipe_editor.tscn")


## Refresh both sub-editors
func refresh() -> void:
	if crafter_editor and crafter_editor.has_method("refresh"):
		crafter_editor.refresh()
	if recipe_editor and recipe_editor.has_method("refresh"):
		recipe_editor.refresh()
