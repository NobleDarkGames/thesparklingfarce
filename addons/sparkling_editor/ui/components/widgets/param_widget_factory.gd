@tool
class_name ParamWidgetFactory
extends RefCounted

## Factory for creating parameter editor widgets based on param type
## Maps param definition types to the appropriate widget class
##
## This is the critical integration point between the widget system and the
## cinematic editor. It translates param_def dictionaries from command schemas
## into concrete widget instances.
##
## Usage:
##   var widget: EditorWidgetBase = ParamWidgetFactory.create_widget("character", param_def, context)
##   if widget:
##       widget.set_value(current_value)
##       widget.value_changed.connect(_on_param_changed)
##       container.add_child(widget)
##   else:
##       # Fall back to legacy handling for unsupported types
##       _create_fallback_widget(param_type, param_def)
##
## Supported Types:
##   - Primitives: string, text, float, int, bool, enum, vector2
##   - Resources: character, speaker, shop, battle, cinematic, map, map_id, scene, scene_id, actor
##   - Composite: choices, command_array
##
## Unsupported (returns null):
##   - Complex: path, variant


## All supported param types for quick lookup
const SUPPORTED_TYPES: Array[String] = [
	"string", "text", "float", "int", "bool", "enum", "vector2",
	"character", "speaker", "shop", "battle", "cinematic",
	"map", "map_id", "scene", "scene_id", "actor",
	"music", "sfx",
	"choices", "command_array"
]

## Complex types that need special handling (still unsupported)
const COMPLEX_TYPES: Array[String] = [
	"path", "variant"
]


## Create a widget for the given parameter type
## Returns null if type is not supported (caller should provide fallback)
##
## Parameters:
##   param_type: The type string from the param definition (e.g., "character", "float")
##   param_def: The full parameter definition dictionary with hints, min/max, options, etc.
##   context: The EditorWidgetContext providing access to game resources
##
## Returns:
##   A configured EditorWidgetBase instance, or null if type is unsupported
static func create_widget(
	param_type: String,
	param_def: Dictionary,
	context: EditorWidgetContext
) -> EditorWidgetBase:
	var widget: EditorWidgetBase = null
	
	match param_type:
		# =================================================================
		# Primitive Types
		# =================================================================
		"string":
			var w: StringEditorWidget = StringEditorWidget.new()
			if "hint" in param_def:
				w.placeholder_text = str(param_def.get("hint"))
			widget = w
		
		"text":
			var w: TextEditorWidget = TextEditorWidget.new()
			if "hint" in param_def:
				w.placeholder_text = str(param_def.get("hint"))
			widget = w
		
		"float":
			var min_val: float = float(param_def.get("min", 0.0))
			var max_val: float = float(param_def.get("max", 100.0))
			var step_val: float = float(param_def.get("step", 0.1))
			var w: NumberEditorWidget = NumberEditorWidget.new(min_val, max_val, step_val)
			widget = w
		
		"int":
			var min_val: float = float(param_def.get("min", 0))
			var max_val: float = float(param_def.get("max", 100))
			# Force step to 1 for integers
			var w: NumberEditorWidget = NumberEditorWidget.new(min_val, max_val, 1.0)
			widget = w
		
		"bool":
			var w: BoolEditorWidget = BoolEditorWidget.new()
			widget = w
		
		"enum":
			var options_raw: Variant = param_def.get("options", [])
			var options: Array[String] = []
			if options_raw is Array:
				for opt: Variant in options_raw:
					options.append(str(opt))
			var w: EnumPickerWidget = EnumPickerWidget.new(options)
			widget = w
		
		"vector2":
			var min_val: float = float(param_def.get("min", -10000.0))
			var max_val: float = float(param_def.get("max", 10000.0))
			var w: Vector2EditorWidget = Vector2EditorWidget.new(min_val, max_val)
			widget = w
		
		# =================================================================
		# Resource Types
		# =================================================================
		"character", "speaker":
			var w: ResourcePickerWidget = ResourcePickerWidget.new(
				ResourcePickerWidget.ResourceType.SPEAKER
			)
			widget = w
		
		"shop":
			var w: ResourcePickerWidget = ResourcePickerWidget.new(
				ResourcePickerWidget.ResourceType.SHOP
			)
			widget = w
		
		"battle":
			var w: ResourcePickerWidget = ResourcePickerWidget.new(
				ResourcePickerWidget.ResourceType.BATTLE
			)
			widget = w
		
		"cinematic":
			var w: ResourcePickerWidget = ResourcePickerWidget.new(
				ResourcePickerWidget.ResourceType.CINEMATIC
			)
			widget = w
		
		"map", "map_id":
			var w: ResourcePickerWidget = ResourcePickerWidget.new(
				ResourcePickerWidget.ResourceType.MAP
			)
			widget = w
		
		"scene", "scene_id":
			var w: ResourcePickerWidget = ResourcePickerWidget.new(
				ResourcePickerWidget.ResourceType.SCENE
			)
			widget = w
		
		"actor":
			var w: ResourcePickerWidget = ResourcePickerWidget.new(
				ResourcePickerWidget.ResourceType.ACTOR
			)
			widget = w

		# =================================================================
		# Audio Types
		# =================================================================
		"music":
			var w: MusicPickerWidget = MusicPickerWidget.new(
				MusicPickerWidget.AudioType.MUSIC
			)
			widget = w

		"sfx":
			var w: MusicPickerWidget = MusicPickerWidget.new(
				MusicPickerWidget.AudioType.SFX
			)
			widget = w

		# =================================================================
		# Composite Types
		# =================================================================
		"choices":
			var w: ChoicesEditorWidget = ChoicesEditorWidget.new()
			widget = w
		
		"command_array":
			var w: CommandArrayWidget = CommandArrayWidget.new()
			# Note: param_name should be set by caller for accent color
			widget = w
		
		# =================================================================
		# Complex Types - Return null for fallback handling
		# =================================================================
		"path", "variant":
			# These still require special handling
			return null
		
		_:
			# Unknown type - log warning and return null
			push_warning("ParamWidgetFactory: Unknown param type '%s'" % param_type)
			return null
	
	# Set context on the created widget
	if widget and context:
		widget.set_context(context)
	
	return widget


## Check if a param type is supported by this factory
##
## Parameters:
##   param_type: The type string to check
##
## Returns:
##   true if create_widget() will return a widget for this type
static func is_type_supported(param_type: String) -> bool:
	return param_type in SUPPORTED_TYPES


## Get list of all supported param types
##
## Returns:
##   Array of type strings that this factory can create widgets for
static func get_supported_types() -> Array[String]:
	return SUPPORTED_TYPES.duplicate()


## Get list of complex types that need special handling
## These return null from create_widget() and require fallback logic
##
## Returns:
##   Array of type strings that are known but unsupported
static func get_complex_types() -> Array[String]:
	return COMPLEX_TYPES.duplicate()


## Check if a param type is a known complex type
## Complex types are recognized but not yet supported (Phase 4)
##
## Parameters:
##   param_type: The type string to check
##
## Returns:
##   true if this is a known complex type awaiting implementation
static func is_complex_type(param_type: String) -> bool:
	return param_type in COMPLEX_TYPES
