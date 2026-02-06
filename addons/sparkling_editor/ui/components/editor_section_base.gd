@tool
class_name EditorSectionBase
extends RefCounted

## Base class for extractable editor sections
## Provides a pattern for moving large sections from resource editors into separate files

signal data_changed()

## Callable to mark the parent editor as dirty
var _mark_dirty: Callable

## Callable to get the current resource being edited
var _get_resource: Callable

## The CollapseSection control for this section (if using collapsible UI)
var section_root: CollapseSection


func _init(mark_dirty: Callable, get_resource: Callable) -> void:
	_mark_dirty = mark_dirty
	_get_resource = get_resource


## Build the UI for this section. Override in child classes.
## @param parent: The parent container to add UI elements to
func build_ui(parent: Control) -> void:
	push_error("EditorSectionBase.build_ui() must be overridden")


## Load data from the resource into the UI. Override in child classes.
func load_data() -> void:
	push_error("EditorSectionBase.load_data() must be overridden")


## Save data from the UI back to the resource. Override in child classes.
func save_data() -> void:
	push_error("EditorSectionBase.save_data() must be overridden")


## Helper to mark the parent editor dirty (triggers unsaved changes warning)
func mark_dirty() -> void:
	if _mark_dirty.is_valid():
		_mark_dirty.call()
	data_changed.emit()


## Helper to get the current resource
func get_resource() -> Resource:
	if _get_resource.is_valid():
		return _get_resource.call()
	return null


## Create a collapsible section with the given title
func create_collapse_section(title: String, start_collapsed: bool = true) -> CollapseSection:
	section_root = CollapseSection.new()
	section_root.title = title
	section_root.start_collapsed = start_collapsed
	return section_root


## Get the content container from the section root
func get_content_container() -> VBoxContainer:
	if section_root:
		return section_root.get_content_container()
	return null
