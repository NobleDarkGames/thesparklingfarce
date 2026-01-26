@tool
class_name ConditionalCinematicsRowFactory
extends RefCounted

## Shared row factory and data extractor for conditional cinematics
##
## This component provides reusable factory and extractor functions for the
## conditional cinematics pattern used in DynamicRowList. Both NPCEditor and
## InteractableEditor use this to manage flag-based cinematic conditions.
##
## Usage with DynamicRowList:
##   conditionals_list.row_factory = ConditionalCinematicsRowFactory.create_row
##   conditionals_list.data_extractor = ConditionalCinematicsRowFactory.extract_data
##
## Data Format (input/output):
##   {
##     "flags_and": ["flag1", "flag2"],  # ALL must be set (AND logic)
##     "flags_or": ["flagA", "flagB"],   # At least one must be set (OR logic)
##     "negate": false,                   # Invert the condition
##     "cinematic_id": "my_cinematic"     # Cinematic to trigger
##   }
##
## Serialized Format (for saving):
##   {
##     "flags": ["flag1", "flag2"],      # AND flags (renamed from flags_and)
##     "any_flags": ["flagA", "flagB"],  # OR flags (renamed from flags_or)
##     "negate": true,                   # Only present if true
##     "cinematic_id": "my_cinematic"
##   }


## Create the UI for a conditional cinematic row
## This is the row_factory for DynamicRowList
static func create_row(data: Dictionary, row: HBoxContainer) -> void:
	var flags_and: Array = data.get("flags_and", [])
	var flags_or: Array = data.get("flags_or", [])
	var negate: bool = data.get("negate", false)
	var cinematic_id: String = data.get("cinematic_id", "")

	# Create a panel for visual grouping
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.2, 0.5)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.3, 0.3, 0.4, 0.8)
	panel_style.set_content_margin_all(6)
	panel_style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(panel)

	var panel_content: VBoxContainer = VBoxContainer.new()
	panel_content.name = "PanelContent"
	panel_content.add_theme_constant_override("separation", 4)
	panel.add_child(panel_content)

	# Row 1: AND flags (all must be true)
	var and_row: HBoxContainer = HBoxContainer.new()
	and_row.add_theme_constant_override("separation", 4)
	panel_content.add_child(and_row)

	var and_label: Label = Label.new()
	and_label.text = "ALL of:"
	and_label.tooltip_text = "All these flags must be set (AND logic)"
	and_label.custom_minimum_size.x = 55
	and_row.add_child(and_label)

	var and_flags_edit: LineEdit = LineEdit.new()
	and_flags_edit.name = "AndFlagsEdit"
	and_flags_edit.placeholder_text = "flag1, flag2, flag3 (comma-separated)"
	and_flags_edit.text = ", ".join(flags_and) if not flags_and.is_empty() else ""
	and_flags_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	and_flags_edit.tooltip_text = "Enter flag names separated by commas. ALL must be set for condition to match."
	and_row.add_child(and_flags_edit)

	# Row 2: OR flags (at least one must be true)
	var or_row: HBoxContainer = HBoxContainer.new()
	or_row.add_theme_constant_override("separation", 4)
	panel_content.add_child(or_row)

	var or_label: Label = Label.new()
	or_label.text = "ANY of:"
	or_label.tooltip_text = "At least one of these flags must be set (OR logic)"
	or_label.custom_minimum_size.x = 55
	or_row.add_child(or_label)

	var or_flags_edit: LineEdit = LineEdit.new()
	or_flags_edit.name = "OrFlagsEdit"
	or_flags_edit.placeholder_text = "flagA, flagB (at least one)"
	or_flags_edit.text = ", ".join(flags_or) if not flags_or.is_empty() else ""
	or_flags_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	or_flags_edit.tooltip_text = "Enter flag names separated by commas. At least ONE must be set for condition to match."
	or_row.add_child(or_flags_edit)

	# Row 3: Cinematic picker and controls
	var cinematic_row: HBoxContainer = HBoxContainer.new()
	cinematic_row.add_theme_constant_override("separation", 4)
	panel_content.add_child(cinematic_row)

	var negate_check: CheckBox = CheckBox.new()
	negate_check.name = "NegateCheck"
	negate_check.text = "NOT"
	negate_check.tooltip_text = "Invert the condition (trigger when flags are NOT matched)"
	negate_check.button_pressed = negate
	cinematic_row.add_child(negate_check)

	var arrow: Label = Label.new()
	arrow.text = "->"
	cinematic_row.add_child(arrow)

	var cinematic_picker: ResourcePicker = ResourcePicker.new()
	cinematic_picker.name = "CinematicPicker"
	cinematic_picker.resource_type = "cinematic"
	cinematic_picker.allow_none = true
	cinematic_picker.none_text = "(None)"
	cinematic_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cinematic_picker.tooltip_text = "The cinematic to play when this condition is met"
	cinematic_row.add_child(cinematic_picker)

	# Set initial value if provided (deferred to ensure picker is ready)
	if not cinematic_id.is_empty():
		cinematic_picker.call_deferred("select_by_id", "", cinematic_id)


## Extract data from a conditional cinematic row
## This is the data_extractor for DynamicRowList
## Returns the serialized format suitable for saving to resource
static func extract_data(row: HBoxContainer) -> Dictionary:
	var panel: PanelContainer = row.get_node_or_null("Panel") as PanelContainer
	if not panel:
		return {}

	var panel_content: VBoxContainer = panel.get_node_or_null("PanelContent") as VBoxContainer
	if not panel_content:
		return {}

	# Find the UI elements by searching through the panel content
	var and_flags_edit: LineEdit = null
	var or_flags_edit: LineEdit = null
	var negate_check: CheckBox = null
	var cinematic_picker: ResourcePicker = null

	for child: Node in panel_content.get_children():
		if child is HBoxContainer:
			var hbox: HBoxContainer = child as HBoxContainer
			for subchild: Node in hbox.get_children():
				if subchild.name == "AndFlagsEdit":
					and_flags_edit = subchild as LineEdit
				elif subchild.name == "OrFlagsEdit":
					or_flags_edit = subchild as LineEdit
				elif subchild.name == "NegateCheck":
					negate_check = subchild as CheckBox
				elif subchild.name == "CinematicPicker":
					cinematic_picker = subchild as ResourcePicker

	# Get cinematic ID from picker
	var cine_id: String = cinematic_picker.get_selected_resource_id() if cinematic_picker else ""

	# Parse AND flags (comma-separated)
	var and_flags: Array[String] = []
	if and_flags_edit:
		var and_text: String = and_flags_edit.text.strip_edges()
		if not and_text.is_empty():
			for flag: String in and_text.split(","):
				var clean_flag: String = flag.strip_edges()
				if not clean_flag.is_empty():
					and_flags.append(clean_flag)

	# Parse OR flags (comma-separated)
	var or_flags: Array[String] = []
	if or_flags_edit:
		var or_text: String = or_flags_edit.text.strip_edges()
		if not or_text.is_empty():
			for flag: String in or_text.split(","):
				var clean_flag: String = flag.strip_edges()
				if not clean_flag.is_empty():
					or_flags.append(clean_flag)

	# Skip entries with no flags and no cinematic
	if and_flags.is_empty() and or_flags.is_empty() and cine_id.is_empty():
		return {}

	# Build the condition dictionary (serialized format)
	var cond_dict: Dictionary = {"cinematic_id": cine_id}

	# Use "flags" array for AND logic (serialized format)
	if not and_flags.is_empty():
		cond_dict["flags"] = and_flags

	# Use "any_flags" array for OR logic
	if not or_flags.is_empty():
		cond_dict["any_flags"] = or_flags

	if negate_check and negate_check.button_pressed:
		cond_dict["negate"] = true

	return cond_dict


## Refresh all cinematic pickers in conditional rows
## Call this when the cinematic registry changes
static func refresh_pickers_in_list(conditionals_list: DynamicRowList) -> void:
	if not conditionals_list:
		return
	for row: HBoxContainer in conditionals_list.get_all_rows():
		var panel: PanelContainer = row.get_node_or_null("Panel") as PanelContainer
		if panel:
			var content: VBoxContainer = panel.get_child(0) as VBoxContainer
			if content:
				for child: Node in content.get_children():
					if child is HBoxContainer:
						var picker: ResourcePicker = child.get_node_or_null("CinematicPicker") as ResourcePicker
						if picker:
							picker.refresh()


## Parse conditional cinematics from saved resource format into row data format
## Use this when loading data into the DynamicRowList
static func parse_conditionals_for_loading(conditionals: Array[Dictionary]) -> Array[Dictionary]:
	var conditional_data: Array[Dictionary] = []
	for cond: Dictionary in conditionals:
		# Build the AND flags array
		var flags_and: Array = []
		# Legacy single "flag" key gets converted to AND array
		var single_flag: String = cond.get("flag", "")
		if not single_flag.is_empty():
			flags_and.append(single_flag)
		# Add any flags from "flags" array
		var explicit_flags: Array = cond.get("flags", [])
		for flag: String in explicit_flags:
			if not flag.is_empty() and flag not in flags_and:
				flags_and.append(flag)

		# OR flags from "any_flags" array
		var flags_or: Array = cond.get("any_flags", [])

		var negate: bool = cond.get("negate", false)
		var cinematic_id: String = cond.get("cinematic_id", "")

		conditional_data.append({
			"flags_and": flags_and,
			"flags_or": flags_or,
			"negate": negate,
			"cinematic_id": cinematic_id
		})

	return conditional_data


## Check if any conditional has valid flags and cinematic
## Use this for validation
static func has_valid_conditional(conditionals_list: DynamicRowList) -> bool:
	var all_data: Array[Dictionary] = conditionals_list.get_all_data()
	for entry: Dictionary in all_data:
		var cine_id: String = entry.get("cinematic_id", "")
		if cine_id.is_empty():
			continue

		# Check if there are any flags defined (AND or OR)
		var has_and_flags: bool = not entry.get("flags", []).is_empty()
		var has_or_flags: bool = not entry.get("any_flags", []).is_empty()

		if has_and_flags or has_or_flags:
			return true
	return false
