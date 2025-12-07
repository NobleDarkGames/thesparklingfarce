extends CanvasLayer
## DebugConsole - Quake-style dropdown debug console for developer testing
##
## Provides namespaced commands for manipulating game state:
##   hero.*      - Player/hero commands (gold, level, items)
##   party.*     - Party management (XP, add/remove members)
##   campaign.*  - Story flags and progression
##   battle.*    - Battle testing utilities
##   debug.*     - System commands (clear, FPS, reload mods)
##   help        - Show available commands
##
## Mod Extension API:
##   DebugConsole.register_command(name, callback, help_text, mod_id)
##   DebugConsole.unregister_mod_commands(mod_id)

# =============================================================================
# CONSTANTS
# =============================================================================

## BBCode color tags for output formatting
const COLOR_SUCCESS: String = "[color=#66E680]"
const COLOR_ERROR: String = "[color=#FF6666]"
const COLOR_INFO: String = "[color=#80D9FF]"
const COLOR_COMMAND: String = "[color=#B3B3D9]"
const COLOR_END: String = "[/color]"

## Animation timing
const SLIDE_DURATION: float = 0.2

## Console height as percentage of screen (0.4 = 40%)
const CONSOLE_HEIGHT_PERCENT: float = 0.4

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var panel: Panel = $Panel
@onready var output_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/ScrollContainer/OutputLabel
@onready var input_line: LineEdit = $Panel/MarginContainer/VBoxContainer/InputContainer/InputLine

# =============================================================================
# STATE
# =============================================================================

## Whether the console is currently visible
var is_open: bool = false

## Command history for up/down navigation
var command_history: Array[String] = []
var history_index: int = -1

## Mod-registered commands: {command_name: {callback: Callable, help: String, mod_id: String}}
var mod_commands: Dictionary = {}

## Active tween for slide animation
var _slide_tween: Tween = null


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Initialize panel styling
	_setup_panel_style()

	# Connect input signals
	input_line.text_submitted.connect(_on_input_submitted)

	# Start hidden (panel starts offscreen)
	panel.visible = false

	# Print welcome message when console first opens
	_print_info("Debug Console ready. Type 'help' for available commands.")


func _setup_panel_style() -> void:
	# Create a StyleBoxFlat for the dark semi-transparent background
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.4, 1.0)
	panel.add_theme_stylebox_override("panel", style)


func _input(event: InputEvent) -> void:
	# Toggle console with multiple key options (must check in _input to catch before game)
	if event is InputEventKey and event.pressed:
		var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if key in [KEY_F12, KEY_QUOTELEFT, KEY_F1]:
			_toggle_console()
			get_viewport().set_input_as_handled()
			return

	# When console is open, block ALL input from reaching game systems
	# The LineEdit handles its own input via _gui_input which we don't interfere with
	if is_open:
		if event is InputEventKey and event.pressed:
			# ESC closes console (takes priority over LineEdit)
			if event.keycode == KEY_ESCAPE:
				_close_console()
				get_viewport().set_input_as_handled()
				return

			# Command history navigation (Up/Down arrows)
			# Only intercept if LineEdit has focus (otherwise let normal navigation work)
			if input_line and input_line.has_focus():
				if event.keycode == KEY_UP:
					_navigate_history(-1)
					get_viewport().set_input_as_handled()
					return
				elif event.keycode == KEY_DOWN:
					_navigate_history(1)
					get_viewport().set_input_as_handled()
					return

		# Block mouse input from reaching game world
		if event is InputEventMouseButton or event is InputEventMouseMotion:
			get_viewport().set_input_as_handled()
			return

		# CRITICAL: Do NOT block keyboard events here!
		# Keyboard events must flow through to _gui_input so LineEdit can receive them.
		# Game systems should use _unhandled_input() which won't receive events
		# that the LineEdit consumes.


## Block game input from _unhandled_input when console is open
## This catches any keyboard events that LineEdit didn't consume (like mapped actions)
func _unhandled_input(event: InputEvent) -> void:
	if is_open:
		# Console is open - block ALL unhandled input from reaching game systems
		# This prevents game actions (sf_inventory, sf_confirm, etc.) from triggering
		# while still allowing LineEdit to receive text input via _gui_input
		get_viewport().set_input_as_handled()


# =============================================================================
# CONSOLE VISIBILITY
# =============================================================================

func _toggle_console() -> void:
	if is_open:
		_close_console()
	else:
		_open_console()


func _open_console() -> void:
	if is_open:
		return

	is_open = true

	# Calculate target height (40% of viewport)
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	var target_height: float = viewport_height * CONSOLE_HEIGHT_PERCENT

	# Position panel above screen, then slide down
	panel.offset_top = -target_height
	panel.offset_bottom = 0
	panel.visible = true

	# Kill any existing tween
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()

	# Animate slide down
	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(panel, "offset_top", 0.0, SLIDE_DURATION)
	_slide_tween.parallel().tween_property(panel, "offset_bottom", target_height, SLIDE_DURATION)

	# Focus input after animation
	await _slide_tween.finished
	input_line.grab_focus()


func _close_console() -> void:
	if not is_open:
		return

	is_open = false

	# Get current height for slide-up animation
	var current_height: float = panel.offset_bottom

	# Kill any existing tween
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()

	# Animate slide up
	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.set_ease(Tween.EASE_IN)
	_slide_tween.tween_property(panel, "offset_top", -current_height, SLIDE_DURATION)
	_slide_tween.parallel().tween_property(panel, "offset_bottom", 0.0, SLIDE_DURATION)

	# Hide panel after animation
	await _slide_tween.finished
	panel.visible = false

	# Release focus
	input_line.release_focus()


# =============================================================================
# INPUT HANDLING
# =============================================================================

func _on_input_submitted(text: String) -> void:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return

	# Add to history
	if command_history.is_empty() or command_history[-1] != trimmed:
		command_history.append(trimmed)
	history_index = -1

	# Echo the command
	_print_command(trimmed)

	# Clear input
	input_line.clear()

	# Execute
	_execute_command(trimmed)

	# Re-grab focus after command execution (in case something stole it)
	input_line.grab_focus()


func _navigate_history(direction: int) -> void:
	if command_history.is_empty():
		return

	if history_index == -1:
		# Starting fresh navigation
		if direction < 0:
			history_index = command_history.size() - 1
		else:
			return  # Can't go forward from no history
	else:
		history_index += direction
		history_index = clampi(history_index, 0, command_history.size() - 1)

	input_line.text = command_history[history_index]
	input_line.caret_column = input_line.text.length()


# =============================================================================
# COMMAND PARSING
# =============================================================================

## Tokenize input, preserving quoted strings
func _tokenize(text: String) -> Array[String]:
	var tokens: Array[String] = []
	var current: String = ""
	var in_quotes: bool = false
	var quote_char: String = ""

	for i: int in range(text.length()):
		var c: String = text[i]
		if not in_quotes and (c == '"' or c == "'"):
			in_quotes = true
			quote_char = c
		elif in_quotes and c == quote_char:
			in_quotes = false
			quote_char = ""
		elif not in_quotes and c == " ":
			if not current.is_empty():
				tokens.append(current)
				current = ""
		else:
			current += c

	if not current.is_empty():
		tokens.append(current)

	return tokens


## Convert string argument to appropriate type
func _convert_arg(arg: String) -> Variant:
	var lower: String = arg.to_lower()
	if lower == "true":
		return true
	if lower == "false":
		return false
	if arg.is_valid_int():
		return arg.to_int()
	if arg.is_valid_float():
		return arg.to_float()
	return arg


## Execute a command string
func _execute_command(raw_input: String) -> void:
	var tokens: Array[String] = _tokenize(raw_input)
	if tokens.is_empty():
		return

	var full_command: String = tokens[0].to_lower()
	var args: Array = []
	for i: int in range(1, tokens.size()):
		args.append(_convert_arg(tokens[i]))

	# Split cmd_namespace.command
	var parts: PackedStringArray = full_command.split(".", true, 1)
	var cmd_namespace: String = parts[0] if parts.size() == 2 else ""
	var command: String = parts[1] if parts.size() == 2 else parts[0]

	# Priority 1: Core commands (match statement)
	match cmd_namespace:
		"hero":
			_execute_hero_command(command, args)
			return
		"party":
			_execute_party_command(command, args)
			return
		"campaign":
			_execute_campaign_command(command, args)
			return
		"battle":
			_execute_battle_command(command, args)
			return
		"debug":
			_execute_debug_command(command, args)
			return
		"":
			if command == "help":
				_print_help()
				return
			if command == "clear":
				_cmd_clear()
				return

	# Priority 2: Mod-registered commands
	if full_command in mod_commands:
		var cmd_data: Dictionary = mod_commands[full_command]
		var result: String = cmd_data.callback.call(args)
		_print_line(result)
		return

	_print_error("Unknown command: %s. Type 'help' for available commands." % full_command)


# =============================================================================
# HERO COMMANDS
# =============================================================================

func _execute_hero_command(command: String, args: Array) -> void:
	match command:
		"give_gold":
			_cmd_hero_give_gold(args)
		"set_level":
			_cmd_hero_set_level(args)
		"heal":
			_cmd_hero_heal(args)
		"give_item":
			_cmd_hero_give_item(args)
		_:
			_print_error("Unknown hero command: %s" % command)


func _cmd_hero_give_gold(args: Array) -> void:
	if args.is_empty() or not args[0] is int:
		_print_error("Usage: hero.give_gold <amount>")
		return

	var amount: int = args[0]
	# PartyManager doesn't have gold tracking yet - stub implementation
	_print_info("[STUB] Would add %d gold (PartyManager.gold not implemented)" % amount)


func _cmd_hero_set_level(args: Array) -> void:
	if args.is_empty() or not args[0] is int:
		_print_error("Usage: hero.set_level <level>")
		return

	var level: int = args[0]
	var hero: CharacterData = PartyManager.get_hero()
	if not hero:
		_print_error("No hero found in party")
		return

	# Setting level directly isn't straightforward - stub for now
	_print_info("[STUB] Would set hero level to %d (direct level set not implemented)" % level)


func _cmd_hero_heal(args: Array) -> void:
	var hero: CharacterData = PartyManager.get_hero()
	if not hero:
		_print_error("No hero found in party")
		return

	# Get save data to access current HP
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(hero.character_uid)
	if save_data:
		save_data.current_hp = save_data.max_hp
		save_data.current_mp = save_data.max_mp
		_print_success("Hero fully healed (HP: %d, MP: %d)" % [save_data.max_hp, save_data.max_mp])
	else:
		_print_info("[STUB] Hero heal - no save data available")


func _cmd_hero_give_item(args: Array) -> void:
	if args.is_empty():
		_print_error("Usage: hero.give_item <item_id> [count]")
		return

	var item_id: String = str(args[0])
	var count: int = args[1] if args.size() > 1 and args[1] is int else 1

	# Verify item exists
	if not ModLoader.registry.has_resource("item", item_id):
		_print_error("Item not found: %s" % item_id)
		return

	var hero: CharacterData = PartyManager.get_hero()
	if not hero:
		_print_error("No hero found in party")
		return

	var added: int = 0
	for i: int in range(count):
		if PartyManager.add_item_to_member(hero.character_uid, item_id):
			added += 1
		else:
			break

	if added > 0:
		_print_success("Added %d x %s to hero inventory" % [added, item_id])
	else:
		_print_error("Could not add item (inventory full?)")


# =============================================================================
# PARTY COMMANDS
# =============================================================================

func _execute_party_command(command: String, args: Array) -> void:
	match command:
		"grant_xp":
			_cmd_party_grant_xp(args)
		"add":
			_cmd_party_add(args)
		"remove":
			_cmd_party_remove(args)
		"list":
			_cmd_party_list(args)
		"heal_all":
			_cmd_party_heal_all(args)
		_:
			_print_error("Unknown party command: %s" % command)


func _cmd_party_grant_xp(args: Array) -> void:
	if args.size() < 2:
		_print_error("Usage: party.grant_xp <name> <amount>")
		return

	var name_arg: String = str(args[0])
	var amount: int = args[1] if args[1] is int else 0

	if amount <= 0:
		_print_error("XP amount must be positive")
		return

	# Find character by name
	var found: CharacterData = null
	for member: CharacterData in PartyManager.party_members:
		if member.character_name.to_lower() == name_arg.to_lower():
			found = member
			break

	if not found:
		_print_error("Character not found: %s" % name_arg)
		return

	# Grant XP through save data
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(found.character_uid)
	if save_data:
		save_data.current_xp += amount
		_print_success("Granted %d XP to %s (total: %d)" % [amount, found.character_name, save_data.current_xp])
	else:
		_print_info("[STUB] Would grant %d XP to %s" % [amount, found.character_name])


func _cmd_party_add(args: Array) -> void:
	if args.is_empty():
		_print_error("Usage: party.add <character_id>")
		return

	var char_id: String = str(args[0])

	# Look up character in registry
	var character: CharacterData = ModLoader.registry.get_resource("character", char_id) as CharacterData
	if not character:
		_print_error("Character not found in registry: %s" % char_id)
		return

	if PartyManager.add_member(character):
		_print_success("Added %s to party" % character.character_name)
	else:
		_print_error("Failed to add %s to party" % character.character_name)


func _cmd_party_remove(args: Array) -> void:
	if args.is_empty():
		_print_error("Usage: party.remove <name>")
		return

	var name_arg: String = str(args[0])

	# Find character by name
	var found: CharacterData = null
	for member: CharacterData in PartyManager.party_members:
		if member.character_name.to_lower() == name_arg.to_lower():
			found = member
			break

	if not found:
		_print_error("Character not found in party: %s" % name_arg)
		return

	if PartyManager.remove_member(found):
		_print_success("Removed %s from party" % found.character_name)
	else:
		_print_error("Cannot remove %s (hero cannot be removed)" % found.character_name)


func _cmd_party_list(args: Array) -> void:
	if PartyManager.is_empty():
		_print_info("Party is empty")
		return

	_print_info("=== Party Members (%d) ===" % PartyManager.get_party_size())
	for i: int in range(PartyManager.party_members.size()):
		var member: CharacterData = PartyManager.party_members[i]
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(member.character_uid)
		var level_str: String = ""
		if save_data:
			level_str = " Lv.%d" % save_data.level
		var hero_marker: String = " [HERO]" if member.is_hero else ""
		_print_line("  %d. %s%s%s" % [i + 1, member.character_name, level_str, hero_marker])


func _cmd_party_heal_all(args: Array) -> void:
	if PartyManager.is_empty():
		_print_error("Party is empty")
		return

	var healed: int = 0
	for member: CharacterData in PartyManager.party_members:
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(member.character_uid)
		if save_data:
			save_data.current_hp = save_data.max_hp
			save_data.current_mp = save_data.max_mp
			healed += 1

	_print_success("Healed %d party members" % healed)


# =============================================================================
# CAMPAIGN COMMANDS
# =============================================================================

func _execute_campaign_command(command: String, args: Array) -> void:
	match command:
		"set_flag":
			_cmd_campaign_set_flag(args)
		"clear_flag":
			_cmd_campaign_clear_flag(args)
		"list_flags":
			_cmd_campaign_list_flags(args)
		"trigger":
			_cmd_campaign_trigger(args)
		_:
			_print_error("Unknown campaign command: %s" % command)


func _cmd_campaign_set_flag(args: Array) -> void:
	if args.is_empty():
		_print_error("Usage: campaign.set_flag <name> [value]")
		return

	var flag_name: String = str(args[0])
	var value: bool = true
	if args.size() > 1:
		value = bool(args[1]) if args[1] is bool else true

	GameState.set_flag(flag_name, value)
	_print_success("Set flag '%s' = %s" % [flag_name, str(value)])


func _cmd_campaign_clear_flag(args: Array) -> void:
	if args.is_empty():
		_print_error("Usage: campaign.clear_flag <name>")
		return

	var flag_name: String = str(args[0])
	GameState.clear_flag(flag_name)
	_print_success("Cleared flag '%s'" % flag_name)


func _cmd_campaign_list_flags(args: Array) -> void:
	if GameState.story_flags.is_empty():
		_print_info("No story flags set")
		return

	_print_info("=== Story Flags (%d) ===" % GameState.story_flags.size())
	var flag_names: Array = GameState.story_flags.keys()
	flag_names.sort()
	for flag_name: String in flag_names:
		var value: bool = GameState.story_flags[flag_name]
		var color: String = COLOR_SUCCESS if value else COLOR_ERROR
		_print_line("  %s%s%s = %s" % [color, flag_name, COLOR_END, str(value)])


func _cmd_campaign_trigger(args: Array) -> void:
	if args.is_empty():
		_print_error("Usage: campaign.trigger <trigger_id>")
		return

	var trigger_id: String = str(args[0])

	# TriggerManager exists but manual trigger firing may not be exposed
	if TriggerManager.has_method("fire_trigger"):
		TriggerManager.fire_trigger(trigger_id)
		_print_success("Fired trigger: %s" % trigger_id)
	else:
		_print_info("[STUB] Would fire trigger: %s (TriggerManager.fire_trigger not available)" % trigger_id)


# =============================================================================
# BATTLE COMMANDS
# =============================================================================

func _execute_battle_command(command: String, args: Array) -> void:
	match command:
		"win":
			_cmd_battle_win(args)
		"lose":
			_cmd_battle_lose(args)
		"spawn":
			_cmd_battle_spawn(args)
		"kill":
			_cmd_battle_kill(args)
		_:
			_print_error("Unknown battle command: %s" % command)


func _cmd_battle_win(args: Array) -> void:
	if not BattleManager.battle_active:
		_print_error("No battle is currently active")
		return

	# Force victory by killing all enemies
	for enemy: Node2D in BattleManager.enemy_units:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			var hp: int = enemy.stats.current_hp if enemy.stats else 9999
			enemy.take_damage(hp)

	_print_success("Battle forced to victory")


func _cmd_battle_lose(args: Array) -> void:
	if not BattleManager.battle_active:
		_print_error("No battle is currently active")
		return

	# Force defeat by killing all player units
	for unit: Node2D in BattleManager.player_units:
		if is_instance_valid(unit) and unit.has_method("take_damage"):
			var hp: int = unit.stats.current_hp if unit.stats else 9999
			unit.take_damage(hp)

	_print_success("Battle forced to defeat")


func _cmd_battle_spawn(args: Array) -> void:
	if args.size() < 3:
		_print_error("Usage: battle.spawn <unit_id> <x> <y>")
		return

	if not BattleManager.battle_active:
		_print_error("No battle is currently active")
		return

	_print_info("[STUB] Would spawn unit '%s' at (%d, %d)" % [str(args[0]), args[1], args[2]])


func _cmd_battle_kill(args: Array) -> void:
	if args.is_empty():
		_print_error("Usage: battle.kill <name>")
		return

	if not BattleManager.battle_active:
		_print_error("No battle is currently active")
		return

	var name_arg: String = str(args[0]).to_lower()

	# Search all units for matching name
	for unit: Node2D in BattleManager.all_units:
		if not is_instance_valid(unit):
			continue
		var unit_name: String = ""
		if unit.has_method("get_display_name"):
			unit_name = unit.get_display_name().to_lower()
		elif "character_data" in unit and unit.character_data:
			unit_name = unit.character_data.character_name.to_lower()

		if unit_name == name_arg:
			if unit.has_method("take_damage"):
				var hp: int = unit.stats.current_hp if unit.stats else 9999
				unit.take_damage(hp)
				_print_success("Killed unit: %s" % name_arg)
				return

	_print_error("Unit not found: %s" % name_arg)


# =============================================================================
# DEBUG COMMANDS
# =============================================================================

func _execute_debug_command(command: String, args: Array) -> void:
	match command:
		"clear":
			_cmd_clear()
		"fps":
			_cmd_debug_fps(args)
		"reload_mods":
			_cmd_debug_reload_mods(args)
		"scene":
			_cmd_debug_scene(args)
		_:
			_print_error("Unknown debug command: %s" % command)


func _cmd_clear() -> void:
	output_label.clear()


func _cmd_debug_fps(args: Array) -> void:
	if args.is_empty() or not args[0] is int:
		_print_error("Usage: debug.fps <value>")
		return

	var fps: int = args[0]
	Engine.max_fps = fps
	_print_success("Set max FPS to %d" % fps)


func _cmd_debug_reload_mods(args: Array) -> void:
	_print_info("Reloading mods...")
	ModLoader.reload_mods()
	_print_success("Mods reloaded")


func _cmd_debug_scene(args: Array) -> void:
	if args.is_empty():
		_print_error("Usage: debug.scene <path>")
		return

	var scene_path: String = str(args[0])

	# Ensure path starts with res://
	if not scene_path.begins_with("res://"):
		scene_path = "res://" + scene_path

	# Ensure path ends with .tscn
	if not scene_path.ends_with(".tscn"):
		scene_path += ".tscn"

	if not ResourceLoader.exists(scene_path):
		_print_error("Scene not found: %s" % scene_path)
		return

	_print_info("Changing to scene: %s" % scene_path)
	get_tree().change_scene_to_file(scene_path)


# =============================================================================
# HELP SYSTEM
# =============================================================================

func _print_help() -> void:
	_print_info("=== Debug Console Help ===")
	_print_line("")

	_print_line("%s--- Hero Commands ---%s" % [COLOR_INFO, COLOR_END])
	_print_line("  hero.give_gold <amount>       - Add gold to party")
	_print_line("  hero.set_level <level>        - Set hero level")
	_print_line("  hero.heal                     - Full heal hero")
	_print_line("  hero.give_item <id> [count]   - Add item to inventory")
	_print_line("")

	_print_line("%s--- Party Commands ---%s" % [COLOR_INFO, COLOR_END])
	_print_line("  party.grant_xp <name> <amount> - Grant XP to character")
	_print_line("  party.add <character_id>       - Add character to party")
	_print_line("  party.remove <name>            - Remove from party")
	_print_line("  party.list                     - List party members")
	_print_line("  party.heal_all                 - Full heal entire party")
	_print_line("")

	_print_line("%s--- Campaign Commands ---%s" % [COLOR_INFO, COLOR_END])
	_print_line("  campaign.set_flag <name> [value] - Set story flag")
	_print_line("  campaign.clear_flag <name>       - Remove story flag")
	_print_line("  campaign.list_flags              - Show all flags")
	_print_line("  campaign.trigger <trigger_id>    - Fire a trigger")
	_print_line("")

	_print_line("%s--- Battle Commands ---%s" % [COLOR_INFO, COLOR_END])
	_print_line("  battle.win                    - Instant victory")
	_print_line("  battle.lose                   - Instant defeat")
	_print_line("  battle.spawn <id> <x> <y>     - Spawn unit at position")
	_print_line("  battle.kill <name>            - Kill unit")
	_print_line("")

	_print_line("%s--- Debug Commands ---%s" % [COLOR_INFO, COLOR_END])
	_print_line("  debug.clear                   - Clear console output")
	_print_line("  debug.fps <value>             - Set max FPS")
	_print_line("  debug.reload_mods             - Reload mod registry")
	_print_line("  debug.scene <path>            - Change to scene")
	_print_line("")

	_print_line("%s--- General ---%s" % [COLOR_INFO, COLOR_END])
	_print_line("  help                          - Show this help")
	_print_line("  clear                         - Clear console output")

	# Show mod-registered commands if any
	if not mod_commands.is_empty():
		_print_line("")
		_print_line("%s--- Mod Commands ---%s" % [COLOR_INFO, COLOR_END])
		var cmd_names: Array = mod_commands.keys()
		cmd_names.sort()
		for cmd_name: String in cmd_names:
			var cmd_data: Dictionary = mod_commands[cmd_name]
			var mod_tag: String = " [%s]" % cmd_data.mod_id if cmd_data.mod_id else ""
			_print_line("  %s - %s%s" % [cmd_name, cmd_data.help, mod_tag])


# =============================================================================
# MOD EXTENSION API
# =============================================================================

## Register a command from a mod
## @param command_name: The command name (e.g., "weather" for usage as "weather sunny")
## @param callback: A Callable that takes Array args and returns String result
## @param help_text: Short help description
## @param mod_id: Optional mod identifier for grouping
func register_command(command_name: String, callback: Callable, help_text: String, mod_id: String = "") -> void:
	var name_lower: String = command_name.to_lower()
	if name_lower in mod_commands:
		push_warning("DebugConsole: Command '%s' overridden by mod '%s'" % [command_name, mod_id])
	mod_commands[name_lower] = {
		"callback": callback,
		"help": help_text,
		"mod_id": mod_id
	}


## Unregister all commands from a specific mod (for hot-reload)
## @param mod_id: The mod identifier to remove commands for
func unregister_mod_commands(mod_id: String) -> void:
	var to_remove: Array[String] = []
	for cmd: String in mod_commands:
		if mod_commands[cmd].get("mod_id", "") == mod_id:
			to_remove.append(cmd)
	for cmd: String in to_remove:
		mod_commands.erase(cmd)


# =============================================================================
# OUTPUT HELPERS
# =============================================================================

func _print_line(text: String) -> void:
	output_label.append_text(text + "\n")


func _print_command(text: String) -> void:
	output_label.append_text("%s> %s%s\n" % [COLOR_COMMAND, text, COLOR_END])


func _print_success(text: String) -> void:
	output_label.append_text("%s%s%s\n" % [COLOR_SUCCESS, text, COLOR_END])


func _print_error(text: String) -> void:
	output_label.append_text("%s%s%s\n" % [COLOR_ERROR, text, COLOR_END])


func _print_info(text: String) -> void:
	output_label.append_text("%s%s%s\n" % [COLOR_INFO, text, COLOR_END])
