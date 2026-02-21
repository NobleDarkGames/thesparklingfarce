class_name VictoryScreen
extends CanvasLayer

## Victory Screen - Displays battle victory results
##
## Shows "VICTORY!", gold earned, items received, and characters recruited.
## Per Commander Claudius: SF didn't show per-unit XP breakdown (XP was shown during battle).

signal result_dismissed

## Animation constants
const FADE_IN_DURATION: float = 0.5
const TITLE_FLASH_COLOR: Color = Color(1.6, 1.6, 0.8, 1.0)  # Golden brightness flash
const GOLD_REVEAL_DELAY: float = 0.5
const REWARD_LINE_DELAY: float = 0.3
const VICTORY_SLIDE_DURATION: float = 0.4
const VICTORY_SLIDE_OFFSET: float = -200.0

## UI References
@onready var background: ColorRect = $Background
@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var title_label: Label = $CenterContainer/Panel/MarginContainer/VBox/TitleLabel
@onready var gold_label: Label = $CenterContainer/Panel/MarginContainer/VBox/GoldLabel
@onready var continue_label: Label = $CenterContainer/Panel/MarginContainer/VBox/ContinueLabel
@onready var vbox: VBoxContainer = $CenterContainer/Panel/MarginContainer/VBox

## Dynamic reward labels (created at runtime)
var _reward_labels: Array[Label] = []

## State
var _can_dismiss: bool = false
var _blink_tween: Tween = null


func _ready() -> void:
	# Start hidden
	background.modulate.a = 0.0
	panel.modulate.a = 0.0
	gold_label.visible = false
	continue_label.visible = false

	# Set layer above everything else
	layer = 100


## Show the victory screen with full rewards
## @param rewards: Dictionary with {gold: int, items: Array[String], characters: Array[CharacterData]}
func show_victory(rewards: Dictionary) -> void:
	_can_dismiss = false

	# Clear any previous dynamic labels
	_clear_reward_labels()

	# Play victory fanfare
	AudioManager.play_music("victory_fanfare", 0.8)

	# Set title
	title_label.text = "VICTORY!"
	title_label.add_theme_color_override("font_color", Color.GOLD)

	# Extract rewards
	var gold_earned: int = rewards.get("gold", 0)
	var items: Array = rewards.get("items", [])
	var characters: Array = rewards.get("characters", [])

	# Set gold (hidden initially)
	if gold_earned > 0:
		gold_label.text = "Gold Earned: %d G" % gold_earned
	else:
		gold_label.text = "Battle Complete!"

	# Offset title for slide-in animation
	title_label.position.x = VICTORY_SLIDE_OFFSET

	# Fade in background
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(background, "modulate:a", 0.8, FADE_IN_DURATION)
	tween.tween_property(panel, "modulate:a", 1.0, FADE_IN_DURATION)
	await tween.finished
	if not is_instance_valid(self):
		return

	# Slide title in with overshoot
	var slide_duration: float = GameJuice.get_adjusted_duration(VICTORY_SLIDE_DURATION)
	var slide_tween: Tween = create_tween()
	slide_tween.tween_property(title_label, "position:x", 0.0, slide_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await slide_tween.finished
	if not is_instance_valid(self):
		return

	# Animate title bounce
	await _animate_title_bounce()
	if not is_instance_valid(self):
		return

	# Reveal gold - store tree reference before await to prevent race condition
	var tree: SceneTree = get_tree()
	if tree:
		await tree.create_timer(GOLD_REVEAL_DELAY).timeout
	if not is_instance_valid(self):
		return
	gold_label.visible = true
	gold_label.modulate.a = 0.0
	var gold_tween: Tween = create_tween()
	gold_tween.tween_property(gold_label, "modulate:a", 1.0, 0.3)
	AudioManager.play_sfx("gold_earned", AudioManager.SFXCategory.UI)
	await gold_tween.finished
	if not is_instance_valid(self):
		return

	# Reveal items (if any)
	if not items.is_empty():
		await _reveal_items(items)
		if not is_instance_valid(self):
			return

	# Reveal characters (if any)
	if not characters.is_empty():
		await _reveal_characters(characters)
		if not is_instance_valid(self):
			return

	# Show continue prompt - store tree reference before await
	var tree2: SceneTree = get_tree()
	if tree2:
		await tree2.create_timer(0.3).timeout
	if not is_instance_valid(self):
		return
	continue_label.visible = true
	_animate_continue_blink()
	_can_dismiss = true


## Reveal item rewards with animation
func _reveal_items(items: Array) -> void:
	# Count item occurrences for display
	var item_counts: Dictionary = {}
	for item_id: String in items:
		if item_id in item_counts:
			item_counts[item_id] += 1
		else:
			item_counts[item_id] = 1

	for item_id: String in item_counts.keys():
		var count: int = item_counts[item_id]
		var item_data: ItemData = ModLoader.registry.get_resource("item", item_id) as ItemData
		var item_name: String = item_data.item_name if item_data else item_id

		var text: String = "Received: %s" % item_name
		if count > 1:
			text = "Received: %s x%d" % [item_name, count]

		AudioManager.play_sfx("item_acquired", AudioManager.SFXCategory.UI)
		await _add_reward_line(text, Color(0.6, 0.9, 1.0))  # Light blue for items


## Reveal character rewards with animation
func _reveal_characters(characters: Array) -> void:
	for character: CharacterData in characters:
		if character:
			var text: String = "%s joined the force!" % character.character_name
			await _add_reward_line(text, Color(0.5, 1.0, 0.5))  # Light green for recruits


## Add a reward line with fade-in animation
func _add_reward_line(text: String, color: Color) -> void:
	await get_tree().create_timer(REWARD_LINE_DELAY).timeout
	if not is_instance_valid(self):
		return

	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIUtils.apply_monogram_style(label, 24)
	label.add_theme_color_override("font_color", color)
	label.modulate.a = 0.0

	# Insert before continue label
	var continue_idx: int = continue_label.get_index()
	vbox.add_child(label)
	vbox.move_child(label, continue_idx)
	_reward_labels.append(label)

	# Fade in
	var tween: Tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	AudioManager.play_sfx("ui_confirm", AudioManager.SFXCategory.UI)
	await tween.finished


## Clear dynamic reward labels
func _clear_reward_labels() -> void:
	for label: Label in _reward_labels:
		if is_instance_valid(label):
			label.queue_free()
	_reward_labels.clear()


func _animate_title_bounce() -> void:
	# Brightness flash (pixel-perfect, no scaling)
	var tween: Tween = create_tween()
	tween.tween_property(title_label, "modulate", TITLE_FLASH_COLOR, 0.15)
	tween.tween_property(title_label, "modulate", Color.WHITE, 0.2)
	await tween.finished


func _animate_continue_blink() -> void:
	_blink_tween = UIUtils.start_blink_tween(continue_label, _blink_tween)


func _input(event: InputEvent) -> void:
	# Block ALL inputs while this modal popup is visible
	# This prevents clicks/keys from passing through to the battle map
	get_viewport().set_input_as_handled()

	if not _can_dismiss:
		return

	if event.is_action_pressed("sf_confirm") or event.is_action_pressed("sf_cancel"):
		AudioManager.play_sfx("ui_confirm", AudioManager.SFXCategory.UI)
		_dismiss()


func _dismiss() -> void:
	_can_dismiss = false

	UIUtils.kill_tween(_blink_tween)
	_blink_tween = null

	# Fade out
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(background, "modulate:a", 0.0, 0.3)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	await tween.finished

	result_dismissed.emit()
