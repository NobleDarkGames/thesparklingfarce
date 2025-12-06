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

# =============================================================================
# PRELOADS
# =============================================================================

const CaravanDataScript: GDScript = preload("res://core/resources/caravan_data.gd")
const CaravanFollowerScript: GDScript = preload("res://core/components/caravan_follower.gd")
const CaravanMainMenuScript: GDScript = preload("res://scenes/ui/caravan_main_menu.gd")
const PartyManagementPanelScript: GDScript = preload("res://scenes/ui/party_management_panel.gd")

# =============================================================================
# CONFIGURATION
# =============================================================================

## Default caravan data ID to use if no mod specifies one
const DEFAULT_CARAVAN_ID: String = "default_caravan"

## Whether the caravan system is enabled (mods can disable)
var enabled: bool = true

## Currently active caravan configuration (CaravanData resource)
var current_config: Resource = null

# =============================================================================
# RUNTIME STATE
# =============================================================================

## The spawned caravan node (if any)
var _caravan_instance: Node2D = null

## Reference to hero for following
var _hero: Node2D = null

## Reference to last party follower (caravan follows this)
var _last_follower: Node2D = null

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

# =============================================================================
# UI STATE
# =============================================================================

## Persistent UI layer for caravan menus
var _ui_layer: CanvasLayer = null

## The main caravan menu instance
var _main_menu: Control = null

## The party management panel instance
var _party_panel: Control = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Defer initialization to ensure other autoloads are ready
	call_deferred("_initialize")


func _input(event: InputEvent) -> void:
	# Handle caravan interaction when player is in range
	if not _player_in_range or not is_spawned():
		return

	if _menu_open:
		return  # Menu handles its own input

	if event.is_action_pressed("sf_confirm"):
		open_menu()
		get_viewport().set_input_as_handled()


func _initialize() -> void:
	if _initialized:
		return

	# Create UI layer and menu
	_setup_ui()

	# Load caravan configuration from mods
	_load_caravan_config()

	# Connect to scene changes
	if SceneManager:
		if SceneManager.has_signal("scene_transition_completed"):
			SceneManager.scene_transition_completed.connect(_on_scene_changed)
		if SceneManager.has_signal("scene_transition_started"):
			SceneManager.scene_transition_started.connect(_on_scene_transition_started)

	# Connect to battle state changes
	if BattleManager:
		if BattleManager.has_signal("battle_started"):
			BattleManager.battle_started.connect(_on_battle_started)
		if BattleManager.has_signal("battle_ended"):
			BattleManager.battle_ended.connect(_on_battle_ended)

	_initialized = true


func _load_caravan_config() -> void:
	if not ModLoader:
		push_warning("CaravanController: ModLoader not available")
		return

	# Try to load caravan config from registry
	var caravan: Resource = ModLoader.registry.get_resource("caravan", DEFAULT_CARAVAN_ID)
	if caravan and caravan.get_script() == CaravanDataScript:
		current_config = caravan
	else:
		# Create default config if none found
		current_config = CaravanDataScript.new()
		current_config.caravan_id = DEFAULT_CARAVAN_ID
		current_config.display_name = "Caravan"
		current_config.follow_distance_tiles = 3
		push_warning("CaravanController: No caravan config found, using defaults")


func _setup_ui() -> void:
	# Create persistent UI layer (survives scene changes)
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "CaravanUILayer"
	_ui_layer.layer = 15  # Above most game content
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS  # Works while paused
	get_tree().root.call_deferred("add_child", _ui_layer)

	# Create main menu
	_main_menu = Control.new()
	_main_menu.set_script(CaravanMainMenuScript)
	_main_menu.name = "CaravanMainMenu"
	_main_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_menu.process_mode = Node.PROCESS_MODE_ALWAYS  # Works while paused
	_main_menu.visible = false
	_ui_layer.call_deferred("add_child", _main_menu)

	# Create party management panel
	_party_panel = Control.new()
	_party_panel.set_script(PartyManagementPanelScript)
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

	if _main_menu.has_signal("close_requested"):
		_main_menu.close_requested.connect(_on_menu_close_requested)
	if _main_menu.has_signal("party_requested"):
		_main_menu.party_requested.connect(_on_party_requested)
	if _main_menu.has_signal("items_requested"):
		_main_menu.items_requested.connect(_on_items_requested)
	if _main_menu.has_signal("rest_requested"):
		_main_menu.rest_requested.connect(_on_rest_requested)

	# Connect party panel signals
	if _party_panel:
		if _party_panel.has_signal("close_requested"):
			_party_panel.close_requested.connect(_on_party_panel_closed)


func _on_menu_close_requested() -> void:
	close_menu()


func _on_party_requested() -> void:
	# Hide main menu and show party panel
	if _main_menu and _main_menu.has_method("hide_menu"):
		_main_menu.hide_menu()

	if _party_panel and _party_panel.has_method("show_panel"):
		_party_panel.show_panel()


func _on_party_panel_closed() -> void:
	# Hide party panel and return to main menu
	if _party_panel and _party_panel.has_method("hide_panel"):
		_party_panel.hide_panel()

	if _main_menu and _main_menu.has_method("show_menu"):
		_main_menu.show_menu()


func _on_items_requested() -> void:
	# Open depot via ExplorationUIManager
	if ExplorationUIManager:
		ExplorationUIManager.open_depot(true)  # true = from caravan interaction
	close_menu()


func _on_rest_requested() -> void:
	rest_and_heal()
	# Show brief confirmation before closing
	if _main_menu and _main_menu.has_method("show_message"):
		_main_menu.show_message("Party fully healed!")
		# Delay close to let user see message
		await get_tree().create_timer(1.0).timeout
	close_menu()


# =============================================================================
# SCENE CHANGE HANDLING
# =============================================================================

func _on_scene_transition_started(_from_scene: String, _to_scene: String) -> void:
	# Save position before transition if we have a caravan
	if _caravan_instance:
		_save_caravan_position()


func _on_scene_changed(scene_path: String) -> void:
	# Wait a frame for scene to settle
	await get_tree().process_frame

	if not enabled:
		_despawn_caravan()
		return

	# Try to get current map metadata
	_current_map = _get_current_map_metadata()

	if _current_map and _current_map.caravan_visible:
		_spawn_caravan()
	else:
		_despawn_caravan()


func _on_battle_started(_battle_data: Resource) -> void:
	# Save position before battle
	if _caravan_instance:
		_save_caravan_position()
	_despawn_caravan()


func _on_battle_ended(_victory: bool) -> void:
	# Wait for scene to potentially change, then try to spawn
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for safety

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

	if _caravan_instance.has_method("initialize"):
		_caravan_instance.initialize(follow_target, follow_distance, current_config)

	# Restore saved position if available
	if _has_saved_position:
		if _caravan_instance.has_method("set_grid_position"):
			_caravan_instance.set_grid_position(_saved_grid_position)
		_has_saved_position = false

	# Setup interaction area
	_setup_interaction_area()

	caravan_spawned.emit(_caravan_instance.global_position)


func _despawn_caravan() -> void:
	if not _caravan_instance:
		return

	# Save position before despawn
	_save_caravan_position()

	_caravan_instance.queue_free()
	_caravan_instance = null
	_player_in_range = false

	caravan_despawned.emit()


func _save_caravan_position() -> void:
	if _caravan_instance and _caravan_instance.has_method("get_grid_position"):
		_saved_grid_position = _caravan_instance.get_grid_position()
		_has_saved_position = true


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _find_hero() -> Node2D:
	var heroes: Array[Node] = get_tree().get_nodes_in_group("hero")
	if heroes.is_empty():
		return null
	return heroes[0] as Node2D


func _find_last_follower() -> Node2D:
	# Find party followers in scene
	var followers: Array[Node] = get_tree().get_nodes_in_group("party_follower")
	if followers.is_empty():
		return null

	# Find the one with highest formation_index
	var last: Node2D = null
	var max_index: int = -1

	for follower: Node in followers:
		if "formation_index" in follower:
			var idx: int = follower.formation_index
			if idx > max_index:
				max_index = idx
				last = follower as Node2D

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
	for map_resource: Resource in all_maps:
		var map_meta: MapMetadata = map_resource as MapMetadata
		if map_meta and map_meta.scene_path == current_scene.scene_file_path:
			return map_meta

	return null


func _setup_interaction_area() -> void:
	if not _caravan_instance:
		return

	# Create interaction area if not already present
	var area: Area2D = _caravan_instance.get_node_or_null("InteractionArea") as Area2D
	if area:
		# Already has area, just connect signals
		if not area.body_entered.is_connected(_on_body_entered_range):
			area.body_entered.connect(_on_body_entered_range)
		if not area.body_exited.is_connected(_on_body_exited_range):
			area.body_exited.connect(_on_body_exited_range)


func _on_body_entered_range(body: Node2D) -> void:
	if body.is_in_group("hero"):
		_player_in_range = true
		player_in_range.emit()


func _on_body_exited_range(body: Node2D) -> void:
	if body.is_in_group("hero"):
		_player_in_range = false
		player_out_of_range.emit()


# =============================================================================
# PUBLIC API
# =============================================================================

## Check if caravan is currently spawned
func is_spawned() -> bool:
	return _caravan_instance != null


## Check if player is in interaction range
func is_player_in_range() -> bool:
	return _player_in_range


## Check if caravan menu is open
func is_menu_open() -> bool:
	return _menu_open


## Get the caravan instance (for direct access if needed)
func get_caravan_instance() -> Node2D:
	return _caravan_instance


## Get caravan world position
func get_position() -> Vector2:
	if _caravan_instance:
		return _caravan_instance.global_position
	return Vector2.ZERO


## Get caravan grid position
func get_grid_position() -> Vector2i:
	if _caravan_instance and _caravan_instance.has_method("get_grid_position"):
		return _caravan_instance.get_grid_position()
	return _saved_grid_position


## Open the caravan main menu
func open_menu() -> void:
	if not _current_map or not _current_map.caravan_accessible:
		push_warning("CaravanController: Caravan not accessible on this map")
		return

	if _menu_open:
		return

	_menu_open = true

	# Pause the game tree to stop player movement
	get_tree().paused = true

	# Configure disabled options based on caravan config
	var disabled: Array[String] = []
	if current_config:
		if not current_config.has_rest_service:
			disabled.append("rest")
		if not current_config.has_party_management:
			disabled.append("party")

	# Show the main menu
	if _main_menu:
		if _main_menu.has_method("set_disabled_options"):
			_main_menu.set_disabled_options(disabled)
		if _main_menu.has_method("show_menu"):
			_main_menu.show_menu()

	menu_opened.emit()


## Close the caravan menu
func close_menu() -> void:
	if not _menu_open:
		return

	_menu_open = false

	# Hide the main menu
	if _main_menu and _main_menu.has_method("hide_menu"):
		_main_menu.hide_menu()

	# Unpause the game tree
	get_tree().paused = false

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
		enabled = state.enabled

	if "grid_position" in state:
		var pos: Dictionary = state.grid_position
		_saved_grid_position = Vector2i(pos.get("x", 0), pos.get("y", 0))

	if "has_saved_position" in state:
		_has_saved_position = state.has_saved_position


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
func set_config(config: Resource) -> void:
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
