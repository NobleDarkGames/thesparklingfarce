@tool
class_name EditorWidgetBase
extends MarginContainer

## Base class for all editor widgets
## Extends MarginContainer so children automatically fill the widget.
## Defines the signal-based communication pattern for widget value changes.
##
## All widgets emit value_changed when their value changes, allowing parent
## editors to react uniformly regardless of widget type.
##
## Usage:
##   class_name MyWidget
##   extends EditorWidgetBase
##
##   func set_value(value: Variant) -> void:
##       _my_internal_value = value
##       _update_ui()
##
##   func get_value() -> Variant:
##       return _my_internal_value

## Emitted when the widget's value changes
## The new_value type depends on the specific widget implementation
signal value_changed(new_value: Variant)

var _context: EditorWidgetContext


func _init() -> void:
	# Default to expanding horizontally - most widgets need this
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# MarginContainer naturally sizes to its content, no anchors needed


## Set the context for this widget
## Subclasses should override to call refresh() after storing context
func set_context(context: EditorWidgetContext) -> void:
	_context = context


## Get the current context
func get_context() -> EditorWidgetContext:
	return _context


## Set the widget's value (virtual - override in subclasses)
## Should update internal state and UI without emitting value_changed
func set_value(value: Variant) -> void:
	push_warning("EditorWidgetBase.set_value() called but not overridden")
	pass


## Get the widget's current value (virtual - override in subclasses)
func get_value() -> Variant:
	push_warning("EditorWidgetBase.get_value() called but not overridden")
	return null


## Rebuild UI from current state (virtual - override in subclasses)
## Called after context changes or when external refresh is needed
func refresh() -> void:
	pass
