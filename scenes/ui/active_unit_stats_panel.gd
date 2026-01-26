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
var _current_unit: Unit = null


func _ready() -> void:
	# Start hidden
	visible = false
	modulate.a = 0.0


## Update a stat label with color indicating buff/debuff status
func _update_stat_label(label: Label, base: int, effective: int) -> void:
	label.text = str(effective)
	if effective > base:
		label.add_theme_color_override("font_color", Color.LIME_GREEN)
	elif effective < base:
		label.add_theme_color_override("font_color", Color.INDIAN_RED)
	else:
		label.remove_theme_color_override("font_color")


## Display stats for the given unit.
func show_unit_stats(unit: Unit) -> void:
	UIUtils.kill_tween(_current_tween)
	_current_tween = null

	if not unit or not unit.stats:
		visible = false
		_current_unit = null
		return

	_current_unit = unit

	# Update name
	unit_name_label.text = unit.character_data.character_name

	# Update class and level (use stats.class_data for promoted characters)
	class_label.text = unit.stats.class_data.display_name if unit.stats.class_data else "Unknown"
	level_label.text = "Lv %d" % unit.stats.level

	# Show faction (ALLY or ENEMY)
	if unit.is_player_unit():
		faction_label.text = "ALLY"
		faction_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))  # Light blue
	else:
		faction_label.text = "ENEMY"
		faction_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))  # Light red

	# Update HP (set immediately on first display)
	var effective_max_hp: int = unit.stats.get_effective_max_hp()
	hp_bar.max_value = effective_max_hp
	hp_bar.value = unit.stats.current_hp
	hp_value.text = "%d/%d" % [unit.stats.current_hp, effective_max_hp]

	# Update MP (set immediately on first display)
	var effective_max_mp: int = unit.stats.get_effective_max_mp()
	mp_bar.max_value = effective_max_mp
	mp_bar.value = unit.stats.current_mp
	mp_value.text = "%d/%d" % [unit.stats.current_mp, effective_max_mp]

	# Update combat stats (with color for buffs/debuffs)
	_update_stat_label(str_value, unit.stats.strength, unit.stats.get_effective_strength())
	_update_stat_label(def_value, unit.stats.defense, unit.stats.get_effective_defense())
	_update_stat_label(agi_value, unit.stats.agility, unit.stats.get_effective_agility())
	_update_stat_label(int_value, unit.stats.intelligence, unit.stats.get_effective_intelligence())
	_update_stat_label(luk_value, unit.stats.luck, unit.stats.get_effective_luck())

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
		UIUtils.kill_tween(_hp_tween)
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
		UIUtils.kill_tween(_mp_tween)
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
	update_hp(stats.current_hp, stats.get_effective_max_hp(), true)
	update_mp(stats.current_mp, stats.get_effective_max_mp(), true)

	# Update level (might have changed)
	level_label.text = "Lv %d" % stats.level

	# Update combat stats (with color for buffs/debuffs)
	_update_stat_label(str_value, stats.strength, stats.get_effective_strength())
	_update_stat_label(def_value, stats.defense, stats.get_effective_defense())
	_update_stat_label(agi_value, stats.agility, stats.get_effective_agility())
	_update_stat_label(int_value, stats.intelligence, stats.get_effective_intelligence())
	_update_stat_label(luk_value, stats.luck, stats.get_effective_luck())


## Hide the stats panel with animation.
func hide_stats() -> void:
	UIUtils.kill_tween(_current_tween)
	_current_tween = null

	# If already hidden, don't animate
	if not visible:
		return

	_current_unit = null
	_current_tween = create_tween()
	_current_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_current_tween.tween_callback(func() -> void: visible = false)
