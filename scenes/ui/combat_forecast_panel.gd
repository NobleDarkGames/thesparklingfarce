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
@onready var counter_label: Label = %CounterLabel

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

	# Calculate defender's counter chance (depends on range)
	var counter_chance: int = _calculate_counter_chance_for_forecast(attacker, defender)

	# Update labels
	target_name_label.text = defender.get_display_name()
	hit_label.text = "Hit: %d%%" % hit_chance
	damage_label.text = "Dmg: ~%d" % damage
	crit_label.text = "Crit: %d%%" % crit_chance

	# Show counter chance (0% if out of range, otherwise class-based rate)
	if counter_chance > 0:
		counter_label.text = "Counter: %d%%" % counter_chance
		counter_label.visible = true
	else:
		counter_label.text = "Counter: --"
		counter_label.visible = true

	# Show with fade-in
	visible = true
	modulate.a = 0.0
	_current_tween = create_tween()
	_current_tween.tween_property(self, "modulate:a", 1.0, 0.15)


## Calculate defender's counter chance for forecast display
## Returns 0 if defender can't reach attacker (range mismatch)
func _calculate_counter_chance_for_forecast(attacker: Node2D, defender: Node2D) -> int:
	# Get attack distance
	var attack_distance: int = GridManager.get_distance(
		attacker.grid_position,
		defender.grid_position
	)

	# Get defender's weapon range (default 1 for melee)
	var defender_range: int = 1
	if "weapon_range" in defender:
		defender_range = defender.weapon_range
	elif defender.has_method("get_weapon_range"):
		defender_range = defender.get_weapon_range()

	# Check if defender can reach attacker
	if not CombatCalculator.can_counterattack(defender_range, attack_distance):
		return 0  # Out of range, no counter possible

	# Return class-based counter chance
	return CombatCalculator.calculate_counter_chance(defender.stats)


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
