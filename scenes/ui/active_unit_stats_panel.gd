## ActiveUnitStatsPanel - Displays stats for the active unit during their turn
##
## Shows unit name, HP/MP bars, and combat stats in a panel at the top-right
## of the screen. Animates in when a unit's turn starts and out when it ends.
class_name ActiveUnitStatsPanel
extends PanelContainer

@onready var unit_name_label: Label = %UnitNameLabel
@onready var class_label: Label = %ClassLabel
@onready var level_label: Label = %LevelLabel
@onready var faction_label: Label = %FactionLabel
@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_value: Label = %HPValue
@onready var mp_bar: ProgressBar = %MPBar
@onready var mp_value: Label = %MPValue
@onready var str_value: Label = %STRValue
@onready var def_value: Label = %DEFValue
@onready var agi_value: Label = %AGIValue
@onready var int_value: Label = %INTValue
@onready var luk_value: Label = %LUKValue

var _current_tween: Tween = null


func _ready() -> void:
	# Start hidden
	visible = false
	modulate.a = 0.0


## Display stats for the given unit.
func show_unit_stats(unit: Node2D) -> void:
	# Kill any existing tween to prevent conflicts
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null

	if not unit or not unit.stats:
		visible = false
		return

	# Update name
	unit_name_label.text = unit.character_data.character_name

	# Update class and level
	class_label.text = unit.character_data.character_class.display_name
	level_label.text = "Lv %d" % unit.stats.level

	# Show faction (ALLY or ENEMY)
	if unit.is_player_unit():
		faction_label.text = "ALLY"
		faction_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))  # Light blue
	else:
		faction_label.text = "ENEMY"
		faction_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))  # Light red

	# Update HP
	hp_bar.max_value = unit.stats.max_hp
	hp_bar.value = unit.stats.current_hp
	hp_value.text = "%d/%d" % [unit.stats.current_hp, unit.stats.max_hp]

	# Update MP
	mp_bar.max_value = unit.stats.max_mp
	mp_bar.value = unit.stats.current_mp
	mp_value.text = "%d/%d" % [unit.stats.current_mp, unit.stats.max_mp]

	# Update combat stats
	str_value.text = str(unit.stats.strength)
	def_value.text = str(unit.stats.defense)
	agi_value.text = str(unit.stats.agility)
	int_value.text = str(unit.stats.intelligence)
	luk_value.text = str(unit.stats.luck)

	# Force visible and animate in
	visible = true
	modulate.a = 0.0
	_current_tween = create_tween()
	_current_tween.tween_property(self, "modulate:a", 1.0, 0.2)


## Hide the stats panel with animation.
func hide_stats() -> void:
	# Kill any existing tween to prevent conflicts
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null

	# If already hidden, don't animate
	if not visible:
		return

	_current_tween = create_tween()
	_current_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_current_tween.tween_callback(func() -> void: visible = false)
