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

## Animation settings
const SLIDE_OFFSET: float = 20.0
const ANIMATION_DURATION: float = 0.15

var _current_tween: Tween = null
var _original_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Start hidden
	visible = false
	modulate.a = 0.0
	# Store original position once ready
	call_deferred("_store_original_position")


func _store_original_position() -> void:
	_original_position = position


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

	# Get terrain bonuses for defender's position
	var terrain_defense: int = 0
	var terrain_evasion: int = 0
	var defender_terrain: TerrainData = GridManager.get_terrain_at_cell(defender.grid_position)
	if defender_terrain:
		terrain_defense = defender_terrain.defense_bonus
		terrain_evasion = defender_terrain.evasion_bonus

	# Calculate combat stats (with terrain bonuses)
	var hit_chance: int = CombatCalculator.calculate_hit_chance_with_terrain(
		attacker.stats, defender.stats, terrain_evasion
	)
	var damage: int = CombatCalculator.calculate_physical_damage_with_terrain(
		attacker.stats, defender.stats, terrain_defense
	)
	var crit_chance: int = CombatCalculator.calculate_crit_chance(attacker.stats, defender.stats)

	# Calculate defender's counter chance (depends on range)
	var counter_chance: int = _calculate_counter_chance_for_forecast(attacker, defender)

	# Update labels with terrain bonus indicators
	target_name_label.text = defender.get_display_name()

	# Show hit chance with terrain evasion indicator
	if terrain_evasion > 0:
		hit_label.text = "Hit: %d%% (-%d terrain)" % [hit_chance, terrain_evasion]
	else:
		hit_label.text = "Hit: %d%%" % hit_chance

	# Show damage with terrain defense indicator
	if terrain_defense > 0:
		damage_label.text = "Dmg: ~%d (+%d DEF terrain)" % [damage, terrain_defense]
	else:
		damage_label.text = "Dmg: ~%d" % damage

	crit_label.text = "Crit: %d%%" % crit_chance

	# Show counter chance (0% if out of range, otherwise class-based rate)
	if counter_chance > 0:
		counter_label.text = "Counter: %d%%" % counter_chance
		counter_label.visible = true
	else:
		counter_label.text = "Counter: --"
		counter_label.visible = true

	# Setup for animation - slide in from right
	visible = true
	modulate.a = 0.0
	position = _original_position + Vector2(SLIDE_OFFSET, 0)

	# Animate in with slide + fade
	var duration: float = GameJuice.get_adjusted_duration(ANIMATION_DURATION)
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	_current_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(self, "modulate:a", 1.0, duration)
	_current_tween.tween_property(self, "position", _original_position, duration)


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

	var duration: float = GameJuice.get_adjusted_duration(ANIMATION_DURATION * 0.7)
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	_current_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_current_tween.tween_property(self, "modulate:a", 0.0, duration)
	_current_tween.tween_property(self, "position:x", _original_position.x + SLIDE_OFFSET, duration)
	_current_tween.chain().tween_callback(func() -> void:
		visible = false
		position = _original_position
	)
