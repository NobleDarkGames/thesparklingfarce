extends Node

## ExplorationUIManager - Autoload singleton for exploration UI
##
## Automatically provides inventory/equipment UI for any exploration scene.
## Map creators don't need to do anything - if there's a hero in the scene
## and we're not in battle, the UI is available.
##
## Features:
## - Press "I" to open Party Equipment Menu
## - Access Caravan Depot from the menu
## - Automatically deactivates during battle
## - Persists UI layer across scene transitions
##
## Usage (automatic - no setup required):
##   # Just add a node to the "hero" group in your map scene
##   # The UI will automatically become available

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when any exploration menu opens
signal menu_opened()

## Emitted when all exploration menus close
signal menu_closed()

# =============================================================================
# PRELOADS
# =============================================================================

const ExplorationUIControllerScript: GDScript = preload("res://core/components/exploration_ui_controller.gd")
const PartyEquipmentMenuScene: PackedScene = preload("res://scenes/ui/party_equipment_menu.tscn")
const CaravanDepotPanelScene: PackedScene = preload("res://scenes/ui/caravan_depot_panel.tscn")

# =============================================================================
# STATE
# =============================================================================

## The persistent UI layer (survives scene transitions)
var _ui_layer: CanvasLayer = null

## The controller that manages menu state
var _controller: Node = null  # ExplorationUIController

## UI panel instances
var _party_menu: Control = null  # PartyEquipmentMenu
var _depot_panel: Control = null  # CaravanDepotPanel

## Currently connected hero (if any)
var _current_hero: Node = null

## Whether the system is active and ready
var _initialized: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Defer initialization to ensure other autoloads are ready
	call_deferred("_initialize")


func _initialize() -> void:
	if _initialized:
		return

	# Create persistent UI layer (added to root, survives scene changes)
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "ExplorationUILayer"
	_ui_layer.layer = 10  # Above game content
	_ui_layer.visible = false  # Hidden until activated
	get_tree().root.call_deferred("add_child", _ui_layer)

	# Create UI panels
	_party_menu = PartyEquipmentMenuScene.instantiate()
	_party_menu.name = "PartyEquipmentMenu"
	_party_menu.visible = false

	_depot_panel = CaravanDepotPanelScene.instantiate()
	_depot_panel.name = "CaravanDepotPanel"
	_depot_panel.visible = false

	# Defer adding children until layer is in tree
	_ui_layer.call_deferred("add_child", _party_menu)
	_ui_layer.call_deferred("add_child", _depot_panel)

	# Create the controller
	_controller = Node.new()
	_controller.set_script(ExplorationUIControllerScript)
	_controller.name = "ExplorationUIController"
	add_child(_controller)

	# Setup controller with panels (deferred to ensure panels are ready)
	call_deferred("_setup_controller")

	# Connect to scene changes
	if SceneManager:
		SceneManager.scene_transition_completed.connect(_on_scene_changed)

	# Connect to battle state changes
	if BattleManager:
		if BattleManager.has_signal("battle_started"):
			BattleManager.battle_started.connect(_on_battle_started)
		if BattleManager.has_signal("battle_ended"):
			BattleManager.battle_ended.connect(_on_battle_ended)

	_initialized = true


func _setup_controller() -> void:
	if _controller and _controller.has_method("setup"):
		_controller.setup(_party_menu, _depot_panel)

		# Forward controller signals
		if _controller.has_signal("menu_opened"):
			_controller.menu_opened.connect(func() -> void: menu_opened.emit())
		if _controller.has_signal("menu_closed"):
			_controller.menu_closed.connect(func() -> void: menu_closed.emit())

# =============================================================================
# SCENE CHANGE HANDLING
# =============================================================================

func _on_scene_changed(_scene_path: String) -> void:
	# Wait a frame for scene to settle
	await get_tree().process_frame
	_try_activate()


func _on_battle_started(_battle_data: Resource) -> void:
	_deactivate()


func _on_battle_ended(_victory: bool) -> void:
	# Wait for scene to potentially change, then try to activate
	await get_tree().process_frame
	_try_activate()

# =============================================================================
# ACTIVATION LOGIC
# =============================================================================

func _try_activate() -> void:
	# Don't activate during battle
	if BattleManager and BattleManager.battle_active:
		_deactivate()
		return

	# Find hero in current scene
	var heroes: Array[Node] = get_tree().get_nodes_in_group("hero")
	if heroes.is_empty():
		_deactivate()
		return

	# Get the first hero
	var hero: Node = heroes[0]

	# Verify it has the ui_controller property (HeroController pattern)
	if not "ui_controller" in hero:
		_deactivate()
		return

	_activate(hero)


func _activate(hero: Node) -> void:
	if _current_hero == hero and _ui_layer.visible:
		return  # Already active for this hero

	_current_hero = hero
	_ui_layer.visible = true

	# Connect hero to our controller
	hero.ui_controller = _controller

	# Ensure menus start hidden but controller is ready
	if _controller and _controller.has_method("close_all_menus"):
		_controller.close_all_menus()


func _deactivate() -> void:
	if _current_hero and "ui_controller" in _current_hero:
		_current_hero.ui_controller = null

	_current_hero = null
	_ui_layer.visible = false

	# Close any open menus
	if _controller and _controller.has_method("close_all_menus"):
		_controller.close_all_menus()

# =============================================================================
# PUBLIC API
# =============================================================================

## Check if exploration UI is currently active
func is_active() -> bool:
	return _ui_layer != null and _ui_layer.visible and _current_hero != null


## Check if a menu is currently blocking input
func is_blocking_input() -> bool:
	if not is_active():
		return false
	if _controller and _controller.has_method("is_blocking_input"):
		return _controller.is_blocking_input()
	return false


## Open the inventory/equipment menu programmatically
func open_inventory() -> void:
	if is_active() and _controller and _controller.has_method("open_inventory"):
		_controller.open_inventory()


## Open the Caravan depot panel programmatically
## @param from_caravan_interaction: true if triggered by interacting with Caravan sprite
func open_depot(from_caravan_interaction: bool = false) -> void:
	if is_active() and _controller and _controller.has_method("open_depot"):
		_controller.open_depot(from_caravan_interaction)


## Close all menus programmatically
func close_all_menus() -> void:
	if _controller and _controller.has_method("close_all_menus"):
		_controller.close_all_menus()


## Get the current UI state name (for debugging)
func get_state_name() -> String:
	if _controller and _controller.has_method("get_state_name"):
		return _controller.get_state_name()
	return "UNKNOWN"
