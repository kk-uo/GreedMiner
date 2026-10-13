extends Node2D

## Controls the ship assembly interface in BaseMain.

const MACHINE_GUN_SCENE: PackedScene = preload("res://Scenes/machine_gun.tscn")
const BATTLE_SCENE_PATH: String = "res://Scenes/BattleMain.tscn"
const POPUP_MARGIN: float = 8.0
const POPUP_CELL_GAP: float = 10.0

@onready var ship: Ship = $Ship
@onready var module_popup: PanelContainer = $BaseUI/ModulePopup
@onready var machine_gun_option: Button = $BaseUI/ModulePopup/VBoxContainer/MachineGunOption
@onready var empty_option: Button = $BaseUI/ModulePopup/VBoxContainer/EmptyOption
@onready var launch_battle_button: Button = $BaseUI/LaunchBattleButton

var _selected_row: int = -1
var _selected_column: int = -1


func _ready() -> void:
	module_popup.hide()
	_connect_once(ship.cell_selected, _on_ship_cell_selected)
	_connect_once(ship.cell_deselected, _on_ship_cell_deselected)
	_connect_once(machine_gun_option.pressed, _on_machine_gun_option_pressed)
	_connect_once(empty_option.pressed, _on_empty_option_pressed)
	_connect_once(launch_battle_button.pressed, _on_launch_battle_button_pressed)


## Connects a signal only when the same callable is not already connected.
func _connect_once(source_signal: Signal, callback: Callable) -> void:
	if not source_signal.is_connected(callback):
		source_signal.connect(callback)


## Opens the module menu beside the newly selected grid cell.
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


## Positions the popup by the selected cell and clamps it to the viewport.
func _position_module_popup() -> void:
	if not module_popup.visible or not ShipLoadout.is_valid_cell(
		_selected_row,
		_selected_column
	):
		return

	var cell_center: Vector2 = ship.to_global(
		ship.get_cell_center(_selected_row, _selected_column)
	)
	var desired_position := Vector2(
		cell_center.x + Ship.CELL_SIZE * 0.5 + POPUP_CELL_GAP,
		cell_center.y - module_popup.size.y * 0.5
	)
	var viewport_size: Vector2 = get_viewport_rect().size
	var maximum_position := Vector2(
		maxf(POPUP_MARGIN, viewport_size.x - module_popup.size.x - POPUP_MARGIN),
		maxf(POPUP_MARGIN, viewport_size.y - module_popup.size.y - POPUP_MARGIN)
	)

	module_popup.position = Vector2(
		clampf(desired_position.x, POPUP_MARGIN, maximum_position.x),
		clampf(desired_position.y, POPUP_MARGIN, maximum_position.y)
	)


## Replaces the selected cell's contents with a machine gun.
func _on_machine_gun_option_pressed() -> void:
	if not ShipLoadout.is_valid_cell(_selected_row, _selected_column):
		return

	ship.remove_module(_selected_row, _selected_column)
	ship.install_module(
		MACHINE_GUN_SCENE,
		Ship.ModuleType.Weapon,
		_selected_row,
		_selected_column
	)
	module_popup.hide()


## Removes the installed module from the selected cell.
func _on_empty_option_pressed() -> void:
	if not ShipLoadout.is_valid_cell(_selected_row, _selected_column):
		return

	ship.remove_module(_selected_row, _selected_column)
	module_popup.hide()


## Starts combat while preserving the shared ShipLoadout configuration.
func _on_launch_battle_button_pressed() -> void:
	module_popup.hide()
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
