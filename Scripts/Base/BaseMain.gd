
extends Node2D

## Controls the ship assembly interface in BaseMain.

const MACHINE_GUN_SCENE: PackedScene = preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn")
const DWARF_CANNON_SCENE: PackedScene = preload("res://Scenes/Modules/Weapons/DwarfCannon/dwarf_cannon.tscn")
const LASER_SCENE: PackedScene = preload("res://Scenes/Modules/Weapons/Laser/laser.tscn")
const CHAINSAW_SCENE: PackedScene = preload("res://Scenes/Modules/Weapons/Chainsaw/chainsaw.tscn")
const MINING_MODULE_SCENE: PackedScene = preload("res://Scenes/Modules/Mining/mining_module.tscn")

const PLANET_SELECT_SCENE_PATH: String = "res://Scenes/PlanetSelection/planet_select.tscn"

const POPUP_MARGIN: float = 8.0
const POPUP_CELL_GAP: float = 10.0


@onready var ship: Ship = $Ship
@onready var ui_root: ScaledUIRoot = $BaseUI/UIRoot
@onready var module_popup: PanelContainer = $BaseUI/UIRoot/ModulePopup

@onready var machine_gun_option: Button = $BaseUI/UIRoot/ModulePopup/VBoxContainer/MachineGunOption
@onready var dwarf_cannon_option: Button = $BaseUI/UIRoot/ModulePopup/VBoxContainer/DwarfCannonOption
@onready var laser_option: Button = $BaseUI/UIRoot/ModulePopup/VBoxContainer/LaserOption
@onready var chainsaw_option: Button = $BaseUI/UIRoot/ModulePopup/VBoxContainer/ChainsawOption
@onready var mining_module_option: Button = $BaseUI/UIRoot/ModulePopup/VBoxContainer/MiningModuleOption
@onready var empty_option: Button = $BaseUI/UIRoot/ModulePopup/VBoxContainer/EmptyOption

@onready var launch_battle_button: Button = $BaseUI/UIRoot/LaunchBattleButton


var _selected_row: int = -1
var _selected_column: int = -1


func _ready() -> void:
	module_popup.hide()

	# Connect ship selection signals.
	_connect_once(ship.cell_selected, _on_ship_cell_selected)
	_connect_once(ship.cell_deselected, _on_ship_cell_deselected)

	# Connect module selection buttons.
	_connect_once(machine_gun_option.pressed, _on_machine_gun_option_pressed)
	_connect_once(dwarf_cannon_option.pressed, _on_dwarf_cannon_option_pressed)
	_connect_once(laser_option.pressed, _on_laser_option_pressed)
	_connect_once(chainsaw_option.pressed, _on_chainsaw_option_pressed)
	_connect_once(mining_module_option.pressed, _on_mining_module_selected)
	_connect_once(empty_option.pressed, _on_empty_option_pressed)

	# Connect the launch mission button.
	_connect_once(launch_battle_button.pressed, _on_launch_battle_button_pressed)

	# Keep an open popup correctly positioned after a browser resize.
	_connect_once(get_viewport().size_changed, _on_viewport_size_changed)


## Connects a signal only if it is not already connected.
func _connect_once(source_signal: Signal, callback: Callable) -> void:
	if not source_signal.is_connected(callback):
		source_signal.connect(callback)


## Opens the module menu beside the selected grid cell.
func _on_ship_cell_selected(row: int, column: int) -> void:
	_selected_row = row
	_selected_column = column

	module_popup.show()
	module_popup.reset_size()

	call_deferred("_position_module_popup")


## Closes the menu when the ship clears its selection.
func _on_ship_cell_deselected() -> void:
	_selected_row = -1
	_selected_column = -1

	module_popup.hide()


## Positions the popup beside the selected cell.
func _position_module_popup() -> void:
	if not module_popup.visible:
		return

	if not ShipLoadout.is_valid_cell(
		_selected_row,
		_selected_column
	):
		return

	var cell_center_local := ship.get_cell_center(
		_selected_row,
		_selected_column
	)
	var cell_center_world: Vector2 = ship.to_global(
		cell_center_local
	)
	var cell_edge_world: Vector2 = ship.to_global(
		cell_center_local + Vector2(Ship.CELL_SIZE * 0.5, 0.0)
	)
	var canvas_transform := get_viewport().get_canvas_transform()
	var cell_center_screen: Vector2 = canvas_transform * cell_center_world
	var cell_edge_screen: Vector2 = canvas_transform * cell_edge_world
	var cell_center_ui := ui_root.screen_to_ui(cell_center_screen)
	var cell_half_width_ui := (
		cell_center_screen.distance_to(cell_edge_screen)
		/ maxf(ui_root.ui_visual_scale, 0.1)
	)

	var desired_position := Vector2(
		cell_center_ui.x + cell_half_width_ui + POPUP_CELL_GAP,
		cell_center_ui.y - module_popup.size.y * 0.5
	)

	var viewport_size: Vector2 = ui_root.size

	var maximum_position := Vector2(
		maxf(
			POPUP_MARGIN,
			viewport_size.x - module_popup.size.x - POPUP_MARGIN
		),
		maxf(
			POPUP_MARGIN,
			viewport_size.y - module_popup.size.y - POPUP_MARGIN
		)
	)

	module_popup.position = Vector2(
		clampf(
			desired_position.x,
			POPUP_MARGIN,
			maximum_position.x
		),
		clampf(
			desired_position.y,
			POPUP_MARGIN,
			maximum_position.y
		)
	)


## Repositions an open popup after the viewport or browser canvas changes.
func _on_viewport_size_changed() -> void:
	if module_popup.visible:
		call_deferred("_position_module_popup")


## Installs a machine gun in the selected cell.
func _on_machine_gun_option_pressed() -> void:
	_install_selected_module(MACHINE_GUN_SCENE, Ship.ModuleType.Weapon)


## Installs a dwarf cannon in the selected cell.
func _on_dwarf_cannon_option_pressed() -> void:
	_install_selected_module(DWARF_CANNON_SCENE, Ship.ModuleType.Weapon)


## Installs a piercing laser in the selected cell.
func _on_laser_option_pressed() -> void:
	_install_selected_module(LASER_SCENE, Ship.ModuleType.Weapon)


## Installs a chainsaw in the selected cell.
func _on_chainsaw_option_pressed() -> void:
	_install_selected_module(CHAINSAW_SCENE, Ship.ModuleType.Weapon)


## Replaces the selected cell with a requested module scene.
func _install_selected_module(
	module_scene: PackedScene,
	module_type: int
) -> void:
	if not ShipLoadout.is_valid_cell(
		_selected_row,
		_selected_column
	):
		return

	# Remove any existing module.
	ship.remove_module(
		_selected_row,
		_selected_column
	)

	# Install the selected module.
	ship.install_module(
		module_scene,
		module_type,
		_selected_row,
		_selected_column
	)

	module_popup.hide()


## Installs a mining module in the selected cell.
func _on_mining_module_selected() -> void:
	_install_selected_module(
		MINING_MODULE_SCENE,
		Ship.ModuleType.Mining
	)


## Removes the installed module from the selected cell.
func _on_empty_option_pressed() -> void:
	if not ShipLoadout.is_valid_cell(
		_selected_row,
		_selected_column
	):
		return

	ship.remove_module(
		_selected_row,
		_selected_column
	)

	module_popup.hide()


## Opens destination selection with the current ship loadout preserved.
func _on_launch_battle_button_pressed() -> void:
	module_popup.hide()

	# Mission resources reset only after an unlocked planet is deployed.
	get_tree().change_scene_to_file(
		PLANET_SELECT_SCENE_PATH
	)
