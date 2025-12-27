## CombatFormulaConfig - Configuration for custom combat formulas
##
## This resource allows mods to specify custom combat formula scripts.
## Assign to BattleData.combat_formula_config to use custom combat mechanics.
##
## Total conversion mods can use this to implement completely different
## combat systems (e.g., sci-fi energy shields, mech warfare, etc.)
##
## Example usage in mod:
## 1. Create a script extending CombatFormulaBase
## 2. Create a CombatFormulaConfig.tres resource
## 3. Set formula_script_path to your custom script
## 4. Assign the config to your BattleData resources
@tool
class_name CombatFormulaConfig
extends Resource


## Display name for this formula set (shown in editors)
@export var display_name: String = "Default (Shining Force)"

## Description of the formula behavior
@export_multiline var description: String = "Classic Shining Force combat formulas"

## Path to custom formula script (must extend CombatFormulaBase)
## Leave empty to use default CombatCalculator formulas
@export_file("*.gd") var formula_script_path: String = ""

## Cached formula instance (not saved)
var _formula_instance: CombatFormulaBase = null


## Get or create the formula calculator instance
## Returns null if no custom script is configured (use default CombatCalculator)
func get_formula_calculator() -> CombatFormulaBase:
	# Return cached instance if available
	if _formula_instance != null:
		return _formula_instance

	# No custom script configured - use default formulas
	if formula_script_path.is_empty():
		return null

	# Validate script path exists - use ResourceLoader.exists() for export compatibility
	if not ResourceLoader.exists(formula_script_path):
		push_error("CombatFormulaConfig: Script not found: %s" % formula_script_path)
		return null

	# Load and validate script
	var script: GDScript = load(formula_script_path) as GDScript
	if not script:
		push_error("CombatFormulaConfig: Failed to load script: %s" % formula_script_path)
		return null

	# Instantiate and validate type
	var instance: Variant = script.new()
	if not instance is CombatFormulaBase:
		push_error("CombatFormulaConfig: Script must extend CombatFormulaBase: %s" % formula_script_path)
		return null

	_formula_instance = instance
	return _formula_instance


## Clear cached instance (call when script might have changed)
func clear_cache() -> void:
	_formula_instance = null


## Validate the configuration
func validate() -> Array[String]:
	var errors: Array[String] = []

	if display_name.is_empty():
		errors.append("Display name is required")

	if not formula_script_path.is_empty():
		# Use ResourceLoader.exists() for export compatibility
		if not ResourceLoader.exists(formula_script_path):
			errors.append("Formula script not found: %s" % formula_script_path)
		else:
			var script: GDScript = load(formula_script_path) as GDScript
			if not script:
				errors.append("Failed to load formula script: %s" % formula_script_path)
			else:
				# Try to instantiate to validate it extends CombatFormulaBase
				var instance: Variant = script.new()
				if not instance is CombatFormulaBase:
					errors.append("Formula script must extend CombatFormulaBase: %s" % formula_script_path)

	return errors
