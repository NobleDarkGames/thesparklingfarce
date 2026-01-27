extends Node

## CaravanController - Autoload singleton for Caravan lifecycle management
##
## Manages the SF2-style mobile headquarters (Caravan) that follows the party
## on overworld maps. Coordinates spawning/despawning based on map type,
## provides the main menu interface, and tracks position for save/load.
##
## SF2 Authenticity:
## - Caravan visible only on overworld maps (MapMetadata.caravan_visible)
## - Follows last party member using breadcrumb trail pattern
## - Provides Party Management, Item Storage, Rest & Heal, Exit
## - No healing inside in towns - that's what churches are for
##
## Usage:
##   # Caravan spawns automatically on maps with caravan_visible = true
##   # Player walks near caravan to interact
##   CaravanController.open_menu()  # Opens caravan main menu
##   CaravanController.close_menu()

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when caravan spawns on a map
signal caravan_spawned(position: Vector2)

## Emitted when caravan despawns (entering town, battle, etc.)
signal caravan_despawned()

## Emitted when caravan menu opens
signal menu_opened()

## Emitted when caravan menu closes
signal menu_closed()

## Emitted when player enters caravan interaction range
signal player_in_range()

## Emitted when player exits caravan interaction range
signal player_out_of_range()

## Emitted when rest/heal service is used
signal party_healed()

## Emitted when player attempts to access caravan but it's not available
signal access_denied(reason: String)

# =============================================================================
# PRELOADS
# =============================================================================

const CaravanDataScript = preload("res://core/resources/caravan_data.gd")
const CaravanFollowerScript = preload("res://core/components/caravan_follower.gd")

# =============================================================================
# CONFIGURATION
# =============================================================================

## Default caravan data ID to use if no mod specifies one
const DEFAULT_CARAVAN_ID: String = "default_caravan"

## Whether the caravan system is enabled (mods can disable)
var enabled: bool = true

## Currently active caravan configuration
var current_config: CaravanData = null

# =============================================================================
# RUNTIME STATE
# =============================================================================

## The spawned caravan node (if any)
var _caravan_instance: CaravanFollower = null

## Reference to hero for following
var _hero: HeroController = null

## Reference to last party follower (caravan follows this)
var _last_follower: PartyFollower = null

## Current map metadata
var _current_map: MapMetadata = null

## Whether caravan menu is open
var _menu_open: bool = false

## Whether player is in interaction range
var _player_in_range: bool = false

## Saved caravan grid position (for map transitions)
var _saved_grid_position: Vector2i = Vector2i.ZERO

## Whether we have a saved position (for restoring after battles)
var _has_saved_position: bool = false

## Whether the system is initialized
var _initialized: bool = false

## Custom services registered by mods
var _custom_services: Dictionary = {}

# =============================================================================
# UI STATE
# =============================================================================

## Persistent UI layer for caravan menus
var _ui_layer: CanvasLayer = null

## The main caravan menu instance
var _main_menu: CaravanMainMenu = null

## The party management panel instance
var _party_panel: PartyManagementPanel = null

## Saved pause state before opening menu (to restore correctly on close)
var _previous_pause_state: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	call_deferred("_initialize")


func _exit_tree() -> void:
	if _ui_layer and is_instance_valid(_ui_layer):
		_ui_layer.queue_free()
		_ui_layer = null


func _initialize() -> void:
	if _initialized:
		return

	_setup_ui()
	_load_caravan_config()

	# Connect to scene changes
	_safe_connect(SceneManager, "scene_transition_completed", _on_scene_changed)
	_safe_connect(SceneManager, "scene_transition_started", _on_scene_transition_started)

	# Connect to battle state changes
	_safe_connect(BattleManager, "battle_started", _on_battle_started)
	_safe_connect(BattleManager, "battle_ended", _on_battle_ended)

	_initialized = true


## Safely connect a signal if it exists and isn't already connected
func _safe_connect(target: Object, signal_name: String, callback: Callable) -> void:
	if not target:
		return
	if not target.has_signal(signal_name):
		return
	var sig: Signal = target.get(signal_name)
	if not sig.is_connected(callback):
		sig.connect(callback)


## Call a method on an object if it exists
func _safe_call(target: Object, method_name: String, args: Array = []) -> void:
	if target and target.has_method(method_name):
		target.callv(method_name, args)


func _load_caravan_config() -> void:
	if not ModLoader:
		push_warning("CaravanController: ModLoader not available")
		return

	# Check mod manifests for caravan configuration (highest priority wins)
	var caravan_data_id: String = DEFAULT_CARAVAN_ID
	var caravan_enabled: bool = true

	# Iterate mods in priority order (highest first) to find overrides
	var manifests: Array = ModLoader.get_mods_by_priority_descending()
	for manifest: ModManifest in manifests:
		if manifest.caravan_config.is_empty():
			continue

		# Check if mod disables caravan entirely
		if "enabled" in manifest.caravan_config:
			caravan_enabled = DictUtils.get_bool(manifest.caravan_config, "enabled", true)
			if not caravan_enabled:
				break  # Highest priority mod disabled it

		# Check for caravan_data_id override
		if "caravan_data_id" in manifest.caravan_config:
			caravan_data_id = DictUtils.get_string(manifest.caravan_config, "caravan_data_id", "")

		# Register custom services
		if "custom_services" in manifest.caravan_config:
			var services_val: Variant = manifest.caravan_config.get("custom_services")
			if services_val is Dictionary:
				var services: Dictionary = services_val
				for service_id: String in services.keys():
					var service_val: Variant = services.get(service_id)
					if service_val is Dictionary:
						_register_custom_service(service_id, service_val, manifest.mod_directory)

	# Apply enabled state
	enabled = caravan_enabled
	if not enabled:
		return

	# Load the caravan data resource
	var caravan_res: Resource = ModLoader.registry.get_resource("caravan", caravan_data_id)
	var caravan: CaravanData = caravan_res if caravan_res is CaravanData else null
	if caravan and caravan.get_script() == CaravanDataScript:
		current_config = caravan
	else:
		# Fallback to default if specified ID not found
		var fallback_res: Resource = ModLoader.registry.get_resource("caravan", DEFAULT_CARAVAN_ID)
		caravan = fallback_res if fallback_res is CaravanData else null
		if caravan and caravan.get_script() == CaravanDataScript:
			current_config = caravan
		else:
			# Create default config if none found
			current_config = CaravanDataScript.new()
			current_config.caravan_id = DEFAULT_CARAVAN_ID
			current_config.display_name = "Caravan"
			current_config.follow_distance_tiles = 3
			push_warning("CaravanController: No caravan config found, using defaults")


## Register a custom service from mod configuration
func _register_custom_service(service_id: String, service_data: Dictionary, mod_dir: String) -> void:
	if "scene_path" not in service_data:
		push_warning("CaravanController: Custom service '%s' missing scene_path" % service_id)
		return

	var scene_path: String = mod_dir.path_join(DictUtils.get_string(service_data, "scene_path", ""))
	var display_name: String = DictUtils.get_string(service_data, "display_name", service_id.capitalize())

	_custom_services[service_id] = {
		"scene_path": scene_path,
		"display_name": display_name
	}


func _setup_ui() -> void:
	# Create persistent UI layer (survives scene changes)
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "CaravanUILayer"
	_ui_layer.layer = 15  # Above most game content
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS  # Works while paused
	get_tree().root.call_deferred("add_child", _ui_layer)

	# Create main menu
	_main_menu = CaravanMainMenu.new()
	_main_menu.name = "CaravanMainMenu"
	_main_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_menu.process_mode = Node.PROCESS_MODE_ALWAYS  # Works while paused
	_main_menu.visible = false
	_ui_layer.call_deferred("add_child", _main_menu)

	# Create party management panel
	_party_panel = PartyManagementPanel.new()
	_party_panel.name = "PartyManagementPanel"
	_party_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_party_panel.process_mode = Node.PROCESS_MODE_ALWAYS  # Works while paused
	_party_panel.visible = false
	_ui_layer.call_deferred("add_child", _party_panel)

	# Connect menu signals (deferred to ensure menu is ready)
	call_deferred("_connect_menu_signals")


func _connect_menu_signals() -> void:
	if not _main_menu:
		return

	_safe_connect(_main_menu, "close_requested", _on_menu_close_requested)
	_safe_connect(_main_menu, "party_requested", _on_party_requested)
	_safe_connect(_main_menu, "items_requested", _on_items_requested)
	_safe_connect(_main_menu, "rest_requested", _on_rest_requested)
	_safe_connect(_main_menu, "custom_service_requested", _on_custom_service_requested)

	_safe_connect(_party_panel, "close_requested", _on_party_panel_closed)


func _on_menu_close_requested() -> void:
	close_menu()


func _on_party_requested() -> void:
	_safe_call(_main_menu, "hide_menu")
	_safe_call(_party_panel, "show_panel")


func _on_party_panel_closed() -> void:
	_safe_call(_party_panel, "hide_panel")
	_safe_call(_main_menu, "show_menu")


func _on_items_requested() -> void:
	# Open depot via ExplorationUIManager
	if ExplorationUIManager:
		ExplorationUIManager.open_depot(true)  # true = from caravan interaction
	close_menu()


func _on_rest_requested() -> void:
	rest_and_heal()
	if _main_menu and _main_menu.has_method("show_message"):
		_main_menu.show_message("Party fully healed!")
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(_main_menu):
			return
	close_menu()


func _on_custom_service_requested(service_id: String, scene_path: String) -> void:
	if scene_path.is_empty():
		push_warning("CaravanController: Custom service '%s' has no scene_path" % service_id)
		return

	if not ResourceLoader.exists(scene_path):
		push_error("CaravanController: Custom service scene not found: %s" % scene_path)
		return

	var loaded: Resource = load(scene_path)
	var scene: PackedScene = loaded if loaded is PackedScene else null
	if not scene:
		push_error("CaravanController: Failed to load custom service scene: %s" % scene_path)
		return

	var instantiated: Node = scene.instantiate()
	var instance: Control = instantiated if instantiated is Control else null
	if not instance:
		push_error("CaravanController: Custom service scene is not a Control: %s" % scene_path)
		instantiated.queue_free()
		return

	_safe_call(_main_menu, "hide_menu")

	instance.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_layer.add_child(instance)

	# Connect close signal if available
	var close_callback: Callable = func() -> void:
		instance.queue_free()
		_safe_call(_main_menu, "show_menu")

	if instance.has_signal("close_requested"):
		instance.close_requested.connect(close_callback)
	elif instance.has_signal("closed"):
		instance.closed.connect(close_callback)


## Show a brief floating notification when caravan access is denied
func _show_access_denied_notification(message: String) -> void:
	if not _ui_layer:
		return

	# Create a simple floating label notification
	var notification: Label = Label.new()
	notification.text = message
	notification.add_theme_font_override("font", preload("res://assets/fonts/monogram.ttf"))
	notification.add_theme_font_size_override("font_size", 16)
	notification.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4, 1.0))
	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notification.position.y = 60  # Below typical UI elements

	_ui_layer.add_child(notification)

	# Animate fade out and rise
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	tween.tween_property(notification, "position:y", notification.position.y - 20, 1.5).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(notification.queue_free)


# =============================================================================
# SCENE CHANGE HANDLING
# =============================================================================

func _on_scene_transition_started(_from_scene: String, _to_scene: String) -> void:
	# Close menu if open to prevent stale state after scene change
	# Don't restore pause state - let scene transition handle it
	if _menu_open:
		_menu_open = false
		_safe_call(_main_menu, "hide_menu")
		menu_closed.emit()
	
	# Save position before transition if we have a caravan
	if _caravan_instance:
		_save_caravan_position()


func _on_scene_changed(scene_path: String) -> void:
	# Wait a frame for scene to settle
	await get_tree().process_frame

	if not enabled:
		_despawn_caravan()
		return

	# Check if caravan is unlocked via GameState flag
	# (set by NewGameConfigData.caravan_unlocked or story progression)
	if GameState and not GameState.has_flag("caravan_unlocked"):
		_despawn_caravan()
		return

	# Try to get current map metadata
	_current_map = _get_current_map_metadata()

	if _current_map and _current_map.caravan_visible:
		_spawn_caravan()
	else:
		_despawn_caravan()


func _on_battle_started(_battle_data: BattleData) -> void:
	# Save position before battle
	if _caravan_instance:
		_save_caravan_position()
	_despawn_caravan()


func _on_battle_ended(_victory: bool) -> void:
	# Wait for scene to potentially change, then try to spawn
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for safety

	# CRIT-004: Validate state after double await - scene may have changed
	if not is_inside_tree():
		return

	# Check if caravan is unlocked
	if GameState and not GameState.has_flag("caravan_unlocked"):
		return

	_current_map = _get_current_map_metadata()
	if _current_map and _current_map.caravan_visible:
		_spawn_caravan()


# =============================================================================
# SPAWN/DESPAWN
# =============================================================================

func _spawn_caravan() -> void:
	if _caravan_instance:
		return  # Already spawned

	if not current_config:
		push_error("CaravanController: Cannot spawn caravan without config")
		return

	# Find hero in scene
	_hero = _find_hero()
	if not _hero:
		push_warning("CaravanController: No hero found, cannot spawn caravan")
		return

	# Find the last party follower (caravan follows this, or hero if no followers)
	_last_follower = _find_last_follower()

	# Create caravan instance (CharacterBody2D for physics-based following)
	_caravan_instance = CharacterBody2D.new()
	_caravan_instance.name = "Caravan"
	_caravan_instance.set_script(CaravanFollowerScript)

	# Get parent node (same level as hero)
	var parent: Node = _hero.get_parent()
	if not parent:
		push_error("CaravanController: Hero has no parent")
		_caravan_instance.queue_free()
		_caravan_instance = null
		return

	parent.add_child(_caravan_instance)

	# Initialize the caravan follower
	var follow_target: Node2D = _last_follower if _last_follower else _hero
	var follow_distance: int = current_config.follow_distance_tiles if current_config else 3

	_caravan_instance.initialize(follow_target, follow_distance, current_config)

	# Restore saved position if available
	if _has_saved_position:
		_caravan_instance.set_grid_position(_saved_grid_position)
		_has_saved_position = false

	# Setup interaction area (for visual feedback/prompt display)
	_setup_interaction_area()

	# Connect to hero's interaction signal (unified with NPC interaction)
	_connect_hero_interaction()

	caravan_spawned.emit(_caravan_instance.global_position)


func _despawn_caravan() -> void:
	if not _caravan_instance:
		return

	# Save position before despawn
	_save_caravan_position()

	# Disconnect from hero's interaction signal
	_disconnect_hero_interaction()

	_caravan_instance.queue_free()
	_caravan_instance = null
	_player_in_range = false

	caravan_despawned.emit()


func _save_caravan_position() -> void:
	# MED-007: Use is_instance_valid for proper null check
	if is_instance_valid(_caravan_instance):
		_saved_grid_position = _caravan_instance.get_grid_position()
		_has_saved_position = true


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _find_hero() -> HeroController:
	var heroes: Array[Node] = get_tree().get_nodes_in_group("hero")
	if heroes.is_empty():
		return null
	return heroes[0] as HeroController


func _find_last_follower() -> PartyFollower:
	# Find party followers in scene
	var followers: Array[Node] = get_tree().get_nodes_in_group("party_follower")
	if followers.is_empty():
		return null

	# Find the one with highest formation_index
	var last: PartyFollower = null
	var max_index: int = -1

	for follower: Node in followers:
		var party_follower: PartyFollower = follower as PartyFollower
		if party_follower:
			if party_follower.formation_index > max_index:
				max_index = party_follower.formation_index
				last = party_follower

	return last


func _get_current_map_metadata() -> MapMetadata:
	# Try to get map metadata from the registry via current scene
	if not ModLoader:
		return null

	# Get current scene path
	var current_scene: Node = get_tree().current_scene
	if not current_scene:
		return null

	# Look for a MapMetadata resource that matches this scene
	var all_maps: Array[Resource] = ModLoader.registry.get_all_resources("map")
	for map_meta: MapMetadata in all_maps:
		if map_meta and map_meta.scene_path == current_scene.scene_file_path:
			return map_meta

	return null


func _setup_interaction_area() -> void:
	if not _caravan_instance:
		return

	var area: Area2D = _caravan_instance.get_node_or_null("InteractionArea") as Area2D
	if area:
		_safe_connect(area, "body_entered", _on_body_entered_range)
		_safe_connect(area, "body_exited", _on_body_exited_range)


func _on_body_entered_range(body: Node2D) -> void:
	if body.is_in_group("hero"):
		_player_in_range = true
		player_in_range.emit()


func _on_body_exited_range(body: Node2D) -> void:
	if body.is_in_group("hero"):
		_player_in_range = false
		player_out_of_range.emit()


## Connect to hero's interaction_requested signal for unified NPC-style interaction
func _connect_hero_interaction() -> void:
	_safe_connect(_hero, "interaction_requested", _on_hero_interaction_requested)


## Disconnect from hero's interaction signal (called on despawn)
func _disconnect_hero_interaction() -> void:
	if not _hero or not _hero.has_signal("interaction_requested"):
		return
	if _hero.interaction_requested.is_connected(_on_hero_interaction_requested):
		_hero.interaction_requested.disconnect(_on_hero_interaction_requested)


## Handle hero interaction - check if player is trying to interact with caravan
func _on_hero_interaction_requested(interaction_position: Vector2i) -> void:
	if not is_spawned() or _menu_open:
		return

	var caravan_grid_pos: Vector2i = get_grid_position()
	var hero_grid_pos: Vector2i = _hero.grid_position if _hero else Vector2i.ZERO

	# Allow interaction if facing caravan OR standing on same tile (overlap from following)
	var facing_caravan: bool = (interaction_position == caravan_grid_pos)
	var standing_on_caravan: bool = (hero_grid_pos == caravan_grid_pos)

	if facing_caravan or standing_on_caravan:
		open_menu()


# =============================================================================
# PUBLIC API
# =============================================================================

## Check if caravan is currently spawned
func is_spawned() -> bool:
	return is_instance_valid(_caravan_instance)


## Check if player is in interaction range
func is_player_in_range() -> bool:
	return _player_in_range


## Check if caravan menu is open
func is_menu_open() -> bool:
	return _menu_open


## Get the caravan instance (for direct access if needed)
func get_caravan_instance() -> CaravanFollower:
	return _caravan_instance


## Get caravan world position
func get_position() -> Vector2:
	if _caravan_instance:
		return _caravan_instance.global_position
	return Vector2.ZERO


## Get caravan grid position
func get_grid_position() -> Vector2i:
	if _caravan_instance:
		return _caravan_instance.get_grid_position()
	return _saved_grid_position


## Get all available menu options for the caravan menu
## Returns array of dictionaries with: id, label, description, enabled, is_custom
func get_menu_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []

	# Built-in services (order matters for SF2-authentic feel)
	if current_config:
		if current_config.has_party_management:
			options.append(_make_menu_option("party", "Party", "Manage party members"))
		if current_config.has_item_storage:
			options.append(_make_menu_option("items", "Items", "Access item storage"))
		if current_config.has_rest_service:
			options.append(_make_menu_option("rest", "Rest", "Heal all party members"))
		if current_config.has_shop_service:
			options.append(_make_menu_option("shop", "Shop", "Buy and sell items"))
		if current_config.has_promotion_service:
			options.append(_make_menu_option("promotion", "Promote", "Promote characters"))

	# Custom services from mods
	for service_id: String in _custom_services.keys():
		var service: Dictionary = _custom_services[service_id]
		options.append({
			"id": service_id,
			"label": service.get("display_name", service_id),
			"description": service.get("description", "Custom service"),
			"enabled": true,
			"is_custom": true,
			"scene_path": service.get("scene_path", "")
		})

	options.append(_make_menu_option("exit", "Exit", "Leave the Caravan"))

	return options


## Create a standard menu option dictionary
func _make_menu_option(id: String, label: String, description: String) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"description": description,
		"enabled": true,
		"is_custom": false
	}


## Open the caravan main menu
func open_menu() -> void:
	if not _current_map or not _current_map.caravan_accessible:
		var reason: String = "Caravan not accessible here"
		if AudioManager:
			AudioManager.play_sfx("error", AudioManager.SFXCategory.UI)
		access_denied.emit(reason)
		_show_access_denied_notification(reason)
		return

	if _menu_open:
		return

	_menu_open = true
	_previous_pause_state = get_tree().paused
	get_tree().paused = true

	var disabled: Array[String] = []
	if current_config:
		if not current_config.has_rest_service:
			disabled.append("rest")
		if not current_config.has_party_management:
			disabled.append("party")

	_safe_call(_main_menu, "set_disabled_options", [disabled])
	_safe_call(_main_menu, "show_menu")

	menu_opened.emit()


## Close the caravan menu
func close_menu() -> void:
	if not _menu_open:
		return

	_menu_open = false
	_safe_call(_main_menu, "hide_menu")
	get_tree().paused = _previous_pause_state

	menu_closed.emit()


## Use the rest/heal service (free heal all party)
func rest_and_heal() -> void:
	if not current_config or not current_config.has_rest_service:
		push_warning("CaravanController: Rest service not available")
		return

	if not PartyManager:
		push_warning("CaravanController: PartyManager not available")
		return

	# Restore HP/MP for all party members
	var healed_count: int = 0
	for character: CharacterData in PartyManager.party_members:
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(character.character_uid)
		if save_data:
			save_data.current_hp = save_data.max_hp
			save_data.current_mp = save_data.max_mp
			healed_count += 1

	if healed_count > 0:
		party_healed.emit()
		if AudioManager:
			AudioManager.play_sfx("heal", AudioManager.SFXCategory.UI)


## Check if a specific service is available
func has_service(service_name: String) -> bool:
	if not current_config:
		return false
	return current_config.has_service(service_name)


## Get list of available services
func get_available_services() -> Array[String]:
	if not current_config:
		return []
	return current_config.get_available_services()


# =============================================================================
# SAVE/LOAD INTEGRATION
# =============================================================================

## Export caravan state for save system
func export_state() -> Dictionary:
	return {
		"enabled": enabled,
		"grid_position": {"x": _saved_grid_position.x, "y": _saved_grid_position.y},
		"has_saved_position": _has_saved_position
	}


## Import caravan state from save system
func import_state(state: Dictionary) -> void:
	if "enabled" in state:
		enabled = DictUtils.get_bool(state, "enabled", true)

	if "grid_position" in state:
		var pos_val: Variant = state.get("grid_position")
		if pos_val is Dictionary:
			var pos: Dictionary = pos_val
			var x: int = DictUtils.get_int(pos, "x", 0)
			var y: int = DictUtils.get_int(pos, "y", 0)
			_saved_grid_position = Vector2i(x, y)

	if "has_saved_position" in state:
		_has_saved_position = DictUtils.get_bool(state, "has_saved_position", false)


## Reset to default state (for new game)
func reset() -> void:
	_despawn_caravan()
	enabled = true
	_saved_grid_position = Vector2i.ZERO
	_has_saved_position = false
	_menu_open = false
	_player_in_range = false


# =============================================================================
# MOD CONFIGURATION
# =============================================================================

## Reload caravan configuration (for runtime mod changes)
func reload_config() -> void:
	var was_spawned: bool = is_spawned()
	if was_spawned:
		_save_caravan_position()
		_despawn_caravan()

	_load_caravan_config()

	if was_spawned and _current_map and _current_map.caravan_visible:
		_spawn_caravan()


## Set custom caravan configuration (for testing or special cases)
## @param config: CaravanData resource
func set_config(config: CaravanData) -> void:
	current_config = config
	reload_config()


## Disable the caravan system (for mods that don't want it)
func disable() -> void:
	enabled = false
	_despawn_caravan()


## Enable the caravan system
func enable() -> void:
	enabled = true
	# Will spawn on next scene change if appropriate
