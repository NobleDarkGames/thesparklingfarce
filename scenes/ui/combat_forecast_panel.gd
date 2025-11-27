## CombatForecastPanel - Shows attack preview during targeting
##
## Displays hit chance, estimated damage, and crit chance when
## hovering over a potential target during attack selection.
class_name CombatForecastPanel
extends PanelContainer

@onready var target_name_label: Label = %TargetNameLabel
@onready var hit_label: Label = %HitLabel
@onready var damage_label: Label = %DamageLabel
@onready var crit_label: Label = %CritLabel

var _current_tween: Tween = null


func _ready() -> void:
	# Start hidden
	visible = false
	modulate.a = 0.0


## Show combat forecast for attacker vs defender
func show_forecast(attacker: Node2D, defender: Node2D) -> void:
	if not attacker or not defender:
		hide_forecast()
		return

	if not attacker.stats or not defender.stats:
		hide_forecast()
		return

	# Kill any existing tween
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null

	# Calculate combat stats
	var hit_chance: int = CombatCalculator.calculate_hit_chance(attacker.stats, defender.stats)
	var damage: int = CombatCalculator.calculate_physical_damage(attacker.stats, defender.stats)
	var crit_chance: int = CombatCalculator.calculate_crit_chance(attacker.stats, defender.stats)

	# Update labels
	target_name_label.text = defender.get_display_name()
	hit_label.text = "Hit: %d%%" % hit_chance
	damage_label.text = "Dmg: ~%d" % damage
	crit_label.text = "Crit: %d%%" % crit_chance

	# Show with fade-in
	visible = true
	modulate.a = 0.0
	_current_tween = create_tween()
	_current_tween.tween_property(self, "modulate:a", 1.0, 0.15)


## Hide the forecast panel
func hide_forecast() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null

	if not visible:
		return

	_current_tween = create_tween()
	_current_tween.tween_property(self, "modulate:a", 0.0, 0.15)
	_current_tween.tween_callback(func() -> void: visible = false)
