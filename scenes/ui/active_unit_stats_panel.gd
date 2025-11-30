## ActiveUnitStatsPanel - Displays stats for the active unit during their turn
##
## Shows unit name, HP/MP bars, and combat stats in a panel at the top-right
## of the screen. Animates in when a unit's turn starts and out when it ends.
## HP/MP bars animate smoothly when values change.
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

## Animation settings
const BAR_TWEEN_DURATION: float = 0.4

## Tween references (to prevent conflicts)
var _current_tween: Tween = null
var _hp_tween: Tween = null
var _mp_tween: Tween = null

## Cached reference to current unit for updates
var _current_unit: Node2D = null


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
		_current_unit = null
		return

	_current_unit = unit

	# Update name
	unit_name_label.text = unit.character_data.character_name

	# Update class and level
	class_label.text = unit.character_data.character_class.display_name if unit.character_data.character_class else "Unknown"
	level_label.text = "Lv %d" % unit.stats.level

	# Show faction (ALLY or ENEMY)
	if unit.is_player_unit():
		faction_label.text = "ALLY"
		faction_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))  # Light blue
	else:
		faction_label.text = "ENEMY"
		faction_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))  # Light red

	# Update HP (set immediately on first display)
	hp_bar.max_value = unit.stats.max_hp
	hp_bar.value = unit.stats.current_hp
	hp_value.text = "%d/%d" % [unit.stats.current_hp, unit.stats.max_hp]

	# Update MP (set immediately on first display)
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


## Update HP display with optional animation
## animate: If true, smoothly tween to new value; if false, set immediately
func update_hp(new_hp: int, max_hp: int, animate: bool = true) -> void:
	hp_bar.max_value = max_hp
	hp_value.text = "%d/%d" % [new_hp, max_hp]

	if animate and GameJuice.animate_stat_bars:
		# Kill existing HP tween
		if _hp_tween and _hp_tween.is_valid():
			_hp_tween.kill()

		var duration: float = GameJuice.get_adjusted_duration(BAR_TWEEN_DURATION)
		_hp_tween = create_tween()
		_hp_tween.tween_property(hp_bar, "value", float(new_hp), duration)
		_hp_tween.set_ease(Tween.EASE_OUT)
		_hp_tween.set_trans(Tween.TRANS_CUBIC)
	else:
		hp_bar.value = new_hp


## Update MP display with optional animation
## animate: If true, smoothly tween to new value; if false, set immediately
func update_mp(new_mp: int, max_mp: int, animate: bool = true) -> void:
	mp_bar.max_value = max_mp
	mp_value.text = "%d/%d" % [new_mp, max_mp]

	if animate and GameJuice.animate_stat_bars:
		# Kill existing MP tween
		if _mp_tween and _mp_tween.is_valid():
			_mp_tween.kill()

		var duration: float = GameJuice.get_adjusted_duration(BAR_TWEEN_DURATION)
		_mp_tween = create_tween()
		_mp_tween.tween_property(mp_bar, "value", float(new_mp), duration)
		_mp_tween.set_ease(Tween.EASE_OUT)
		_mp_tween.set_trans(Tween.TRANS_CUBIC)
	else:
		mp_bar.value = new_mp


## Refresh all stats from current unit (useful after combat)
func refresh_stats() -> void:
	if not _current_unit or not _current_unit.stats:
		return

	var stats: UnitStats = _current_unit.stats

	# Animate HP/MP changes
	update_hp(stats.current_hp, stats.max_hp, true)
	update_mp(stats.current_mp, stats.max_mp, true)

	# Update level (might have changed)
	level_label.text = "Lv %d" % stats.level

	# Update combat stats
	str_value.text = str(stats.strength)
	def_value.text = str(stats.defense)
	agi_value.text = str(stats.agility)
	int_value.text = str(stats.intelligence)
	luk_value.text = str(stats.luck)


## Hide the stats panel with animation.
func hide_stats() -> void:
	# Kill any existing tween to prevent conflicts
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null

	# If already hidden, don't animate
	if not visible:
		return

	_current_unit = null
	_current_tween = create_tween()
	_current_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_current_tween.tween_callback(func() -> void: visible = false)
