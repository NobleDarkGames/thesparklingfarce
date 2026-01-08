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

const CaravanInterfaceScene: PackedScene = preload("res://scenes/ui/caravan/caravan_interface.tscn")
const ExplorationFieldMenuScene: PackedScene = preload("res://scenes/ui/exploration_field_menu.tscn")
const MembersInterfaceScene: PackedScene = preload("res://scenes/ui/members/members_interface.tscn")
const FieldItemsInterfaceScene: PackedScene = preload("res://scenes/ui/field_items/field_item_interface.tscn")

# =============================================================================
# STATE
# =============================================================================

## The persistent UI layer (survives scene transitions)
var _ui_layer: CanvasLayer = null

## The controller that manages menu state
var _controller: ExplorationUIController = null

## UI panel instances
var _caravan_interface: CanvasLayer = null  # CaravanInterfaceController (is a CanvasLayer)
var _field_menu: ExplorationFieldMenu = null
var _members_interface: CanvasLayer = null  # MembersInterfaceController (is a CanvasLayer)
var _field_items_interface: CanvasLayer = null  # FieldItemInterfaceController (is a CanvasLayer)

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

	# CaravanInterfaceController is a CanvasLayer that manages its own visibility
	_caravan_interface = CaravanInterfaceScene.instantiate()
	_caravan_interface.name = "CaravanInterface"
	# It starts hidden by default via its _ready()

	_field_menu = ExplorationFieldMenuScene.instantiate()
	_field_menu.name = "ExplorationFieldMenu"
	_field_menu.visible = false

	# MembersInterfaceController is a CanvasLayer that manages its own visibility
	_members_interface = MembersInterfaceScene.instantiate()
	_members_interface.name = "MembersInterface"
	# It starts hidden by default via its _ready()

	# FieldItemsInterfaceController is a CanvasLayer for field menu Item option
	_field_items_interface = FieldItemsInterfaceScene.instantiate()
	_field_items_interface.name = "FieldItemsInterface"
	# It starts hidden by default via its _ready()

	# Defer adding children until layer is in tree
	_ui_layer.call_deferred("add_child", _field_menu)
	# CanvasLayer-based interfaces are added to root
	get_tree().root.call_deferred("add_child", _caravan_interface)
	get_tree().root.call_deferred("add_child", _members_interface)
	get_tree().root.call_deferred("add_child", _field_items_interface)

	# Create the controller
	_controller = ExplorationUIController.new()
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

	# CRITICAL: Connect to MapTemplate signal IMMEDIATELY (same frame as _initialize)
	# This must happen before call_deferred to avoid missing the hero_ready signal
	_connect_to_map_template()

	# Attempt activation for scene already loaded (handles editor play
	# and edge cases where scene loads before signal connection)
	call_deferred("_initial_activation")


func _initial_activation() -> void:
	# Signal connection already happened in _initialize()
	# This is now just a fallback retry loop for edge cases

	# Fallback: short retry loop for edge cases (editor play, custom scenes)
	var max_attempts: int = 3
	for attempt: int in range(max_attempts):
		await get_tree().process_frame
		_try_activate()
		if _current_hero:
			# HIGH-001: Remove debug print in production
			return

	# Not finding a hero immediately is OK - the signal will handle it when ready
	# Only warn if this is clearly an exploration scene that should have a hero
	if get_tree().current_scene and get_tree().current_scene.has_signal("hero_ready"):
		push_warning("[ExplorationUIManager] MapTemplate detected but hero not ready yet - waiting for signal")


func _setup_controller() -> void:
	if _controller and _controller.has_method("setup"):
		# Pass null for deprecated party_equipment_menu (replaced by field_items_interface)
		_controller.setup(null, _caravan_interface, _field_menu, _members_interface, _field_items_interface)

		# Forward controller signals
		if _controller.has_signal("menu_opened"):
			_controller.menu_opened.connect(func() -> void: menu_opened.emit())
		if _controller.has_signal("menu_closed"):
			_controller.menu_closed.connect(func() -> void: menu_closed.emit())

# =============================================================================
# SCENE CHANGE HANDLING
# =============================================================================

func _on_scene_changed(_scene_path: String) -> void:
	# Try to connect to MapTemplate's hero_ready signal (the proper way)
	# This guarantees we activate only when the hero is fully initialized
	_connect_to_map_template()

	# Fallback: short retry loop for scenes that don't use MapTemplate
	# or for edge cases (editor play, custom map scripts)
	var max_attempts: int = 3
	for attempt: int in range(max_attempts):
		await get_tree().process_frame
		_try_activate()
		if _current_hero:
			return
	# If still no hero after retries, that's ok - might be a non-exploration scene


## Connect to MapTemplate's hero_ready signal if present in the scene.
## This is the proper initialization path - signal fires when hero is fully ready.
func _connect_to_map_template() -> void:
	# Find any MapTemplate in the current scene
	var root: Node = get_tree().current_scene
	if not root:
		return

	# Check if root itself is a MapTemplate or find one in children
	var map_templates: Array[Node] = []
	if root.has_signal("hero_ready"):
		map_templates.append(root)
	else:
		# Search immediate children (map templates are usually root or direct child)
		for child: Node in root.get_children():
			if child.has_signal("hero_ready"):
				map_templates.append(child)

	# Connect to each map template found
	for map_template: Node in map_templates:
		if not map_template.hero_ready.is_connected(_on_hero_ready):
			map_template.hero_ready.connect(_on_hero_ready)


## Called when MapTemplate signals that the hero is ready.
## This is the guaranteed-safe activation path.
func _on_hero_ready(hero_node: Node) -> void:
	if hero_node and "ui_controller" in hero_node:
		_activate(hero_node)
		# HIGH-001: Remove debug print in production


func _on_battle_started(_battle_data: BattleData) -> void:
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

## Get the UI controller for hero input handling.
## Called by HeroController when it's ready (Pull Pattern).
## Returns null if not yet initialized - caller should retry.
func get_controller() -> ExplorationUIController:
	return _controller


## Register a hero that has pulled the controller.
## This tracks the hero for menu systems without relying on signal timing.
func register_hero(hero: Node) -> void:
	if hero and "ui_controller" in hero:
		_current_hero = hero
		_ui_layer.visible = true


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
