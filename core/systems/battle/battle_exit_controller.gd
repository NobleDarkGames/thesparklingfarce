## Handles battle exit logic for non-victory scenarios.
##
## This class manages:
## - Egress spell exits (return to safe location, no restoration)
## - Angel Wing item exits (return to safe location, no restoration)
## - Hero death exits (full party restoration, return to safe location)
## - Party wipe exits (full party restoration, return to safe location)
## - Menu quit exits (retreat, no restoration)
##
## The exit flow:
## 1. Mark battle inactive
## 2. Handle party restoration (defeat = full heal, escape = keep current state)
## 3. Set battle outcome to RETREAT
## 4. Determine return location
## 5. Show exit message (for voluntary exits only)
## 6. Emit battle_ended signal
## 7. Clean up battle state
## 8. Transition to safe location (unless external handler)
##
## Extracted from BattleManager to improve modularity and testability.
class_name BattleExitController
extends RefCounted


## Reasons for exiting battle early (not victory/defeat)
enum BattleExitReason {
	EGRESS,      ## Player cast Egress spell
	ANGEL_WING,  ## Player used Angel Wing item
	HERO_DEATH,  ## Hero (is_hero character) died
	PARTY_WIPE,  ## All player units dead
	MENU_QUIT    ## Player quit from game menu
}


## Context holding all references needed for battle exit operations.
## Passed to exit methods to avoid tight coupling with BattleManager.
class ExitContext:
	## Reference to the BattleManager for signals and cleanup
	var battle_manager: Node = null
	## Current battle data (for external handler check)
	var current_battle_data: BattleData = null
	## Player units (for syncing save data)
	var player_units: Array[Unit] = []
	## Battle scene root (for exit message display)
	var battle_scene_root: Node = null
	## SceneTree reference (for timers and scene access)
	var scene_tree: SceneTree = null
	## Callable for end_battle cleanup
	var end_battle_callable: Callable = Callable()
	## Callable for battle_ended signal emission
	var battle_ended_signal: Signal


## UI constants for exit message display
const EXIT_MESSAGE_LAYER: int = 100
const EXIT_MESSAGE_FONT_SIZE: int = 32
const EXIT_MESSAGE_BG_ALPHA: float = 0.7
const EXIT_MESSAGE_DURATION: float = 1.5


## Execute battle exit - revive all party members, return to safe location.
## This handles Egress spell, Angel Wing item, and automatic exits from death.
## @param context: ExitContext containing all required references
## @param initiator: The unit that triggered the exit (for Egress/Angel Wing) or null (for death)
## @param reason: Why we're exiting the battle
static func execute(context: ExitContext, initiator: Unit, reason: BattleExitReason) -> void:
	# Prevent re-entry if already exiting
	if not TurnManager.battle_active:
		return

	# Mark battle as inactive (set on TurnManager directly)
	TurnManager.battle_active = false

	# 1. Handle party restoration based on exit reason (SF2-authentic)
	# DEFEAT scenarios (HERO_DEATH, PARTY_WIPE): Full restoration (HP + MP)
	# ESCAPE scenarios (EGRESS, ANGEL_WING): No restoration (keep current state)
	var is_defeat: bool = reason == BattleExitReason.HERO_DEATH or reason == BattleExitReason.PARTY_WIPE
	_revive_all_party_members(is_defeat)

	# 2. Set battle outcome to RETREAT in transition context
	var transition_context: TransitionContext = GameState.get_transition_context()
	if transition_context:
		transition_context.battle_outcome = TransitionContext.BattleOutcome.RETREAT

	# 3. Determine return location
	var return_path: String = GameState.get_last_safe_location()
	if return_path.is_empty():
		push_warning("BattleExitController: No safe location set, using transition context fallback")
		if transition_context and transition_context.is_valid():
			return_path = transition_context.return_scene_path

	if return_path.is_empty():
		push_error("BattleExitController: Cannot exit battle - no return location available")
		TurnManager.battle_active = true  # Re-enable battle since we can't exit
		return

	# 4. Show brief exit message for voluntary exits (Egress/Angel Wing only)
	# HERO_DEATH uses the full defeat screen shown earlier
	if not TurnManager.is_headless and reason != BattleExitReason.HERO_DEATH:
		await _show_exit_message(context, reason)

	# Post-await validation: battle state may have changed during the message display
	if TurnManager.battle_active:
		# Another system re-activated battle while we were showing the message
		push_warning("BattleExitController: Battle re-activated during exit message, aborting exit")
		return

	if not is_instance_valid(context.battle_manager):
		push_warning("BattleExitController: Battle manager freed during exit message, aborting exit")
		return

	# 5. Check if external code (e.g., trigger_battle command) is handling post-battle transition
	var external_handles_transition: bool = GameState.external_battle_handler

	# 6. Emit battle_ended signal with victory=false (but RETREAT outcome distinguishes from DEFEAT)
	# External handlers (like trigger_battle) listen to this and handle transitions
	context.battle_ended_signal.emit(false)
	GameEventBus.post_battle_end.emit(context.current_battle_data, false, {})

	# 7. Clean up battle state and reset external handler flag
	if context.end_battle_callable.is_valid():
		context.end_battle_callable.call()
	GameState.external_battle_handler = false

	# 8. Transition to safe location ONLY if external code is NOT handling it
	# For trigger_battle cinematics, they handle the on_defeat transition
	if not external_handles_transition:
		await SceneManager.change_scene(return_path)


## Revive all party members (SF2-authentic behavior depends on reason).
## @param full_restoration: If true (defeat), restore HP AND MP. If false (escape), no restoration.
static func _revive_all_party_members(full_restoration: bool) -> void:
	if not full_restoration:
		# EGRESS / ANGEL_WING: No restoration - party keeps current state
		# SF2-AUTHENTIC: Egress exits with whatever HP/MP you had
		return

	# DEFEAT (HERO_DEATH / PARTY_WIPE): Full restoration
	# SF2-AUTHENTIC: On defeat, party wakes up at church fully healed (HP + MP)
	for character: CharacterData in PartyManager.party_members:
		var uid: String = character.character_uid
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(uid)
		if save_data:
			save_data.is_alive = true
			save_data.current_hp = save_data.max_hp
			save_data.current_mp = save_data.max_mp
			# Status effects auto-clear when Units are freed (battle-only, not persisted)


## Sync all surviving player units' HP/MP to their CharacterSaveData after battle.
## Called after victory to persist current state (dead units already marked via _persist_unit_death).
## @param player_units: Array of player units to sync
static func sync_surviving_units_to_save_data(player_units: Array[Unit]) -> void:
	for unit: Unit in player_units:
		if not is_instance_valid(unit):
			continue
		if not unit.is_alive():
			continue
		if not unit.character_data:
			continue
		var char_uid: String = unit.character_data.character_uid
		if char_uid.is_empty():
			continue
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(char_uid)
		if save_data and unit.stats:
			save_data.current_hp = unit.stats.current_hp
			save_data.current_mp = unit.stats.current_mp


## Show a brief exit message for voluntary battle exits (Egress/Angel Wing/Menu Quit).
## @param context: ExitContext for scene tree access
## @param reason: The exit reason to determine message text
static func _show_exit_message(context: ExitContext, reason: BattleExitReason) -> void:
	var message: String = ""
	match reason:
		BattleExitReason.EGRESS:
			message = "Egress!"
		BattleExitReason.ANGEL_WING:
			message = "Angel Wing!"
		BattleExitReason.MENU_QUIT:
			message = "Retreating..."
		_:
			return  # No message for other reasons

	# Create full-screen container for proper centering
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = EXIT_MESSAGE_LAYER

	var background: ColorRect = ColorRect.new()
	background.color = Color(0, 0, 0, EXIT_MESSAGE_BG_ALPHA)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var label: Label = Label.new()
	label.text = message
	label.add_theme_font_override("font", preload("res://assets/fonts/monogram.ttf"))
	label.add_theme_font_size_override("font_size", EXIT_MESSAGE_FONT_SIZE)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(label)

	if context.battle_scene_root:
		context.battle_scene_root.add_child(canvas)
	elif context.scene_tree and context.scene_tree.current_scene:
		context.scene_tree.current_scene.add_child(canvas)
	else:
		# Rare edge case: no valid scene root during transition
		push_warning("BattleExitController: Cannot show exit message - no scene root available")
		canvas.queue_free()
		return

	# Brief pause for player to read message
	if context.scene_tree:
		await context.scene_tree.create_timer(EXIT_MESSAGE_DURATION).timeout

	# HIGH-003: Validate state after await - canvas may be invalid if scene transitioned
	if is_instance_valid(canvas):
		canvas.queue_free()
