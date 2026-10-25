extends Node

const TestSave := preload("res://Tests/TestSave.gd")
const SHIP_SCENE := preload("res://Scenes/Ship/ship.tscn")
const ENERGY_SCENE := preload("res://Scenes/Modules/Energy/energy_module.tscn")
const MACHINE_GUN_SCENE := preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn")
const MANUAL_TURRET_CONTROLLER := preload("res://Scripts/Battle/ManualTurretController.gd")

var _failed := false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("manual_turret_control")
	_check(not ResearchManager.is_manual_turret_control_unlocked(), "manual control starts locked")
	ShipLoadout.install_module(1, 1, ENERGY_SCENE.resource_path)
	ShipLoadout.install_module(0, 0, MACHINE_GUN_SCENE.resource_path)
	ShipLoadout.install_module(0, 1, MACHINE_GUN_SCENE.resource_path)
	var ship := SHIP_SCENE.instantiate() as Ship
	ship.assembly_mode = false
	add_child(ship)
	await get_tree().process_frame
	var first := ship.get_module_at(0, 0) as WeaponModule
	var second := ship.get_module_at(0, 1) as WeaponModule
	_check(first != null and second != null, "saved ship contains two turrets")
	ResearchManager.progress.levels["ship_manual_turret_control"] = 1
	_check(ResearchManager.is_manual_turret_control_unlocked(), "research exposes battle control")
	var controller = MANUAL_TURRET_CONTROLLER.new()
	controller.configure(ship)
	ship.add_child(controller)
	controller.activate_weapon_control(first)
	_check(first.is_manual_control_active(), "first turret enters manual mode")
	controller.activate_weapon_control(second)
	_check(not first.is_manual_control_active() and second.is_manual_control_active(), "switching releases the previous turret")
	controller.activate_weapon_control(second)
	_check(not second.is_manual_control_active(), "clicking the same turret toggles manual mode off")
	controller.activate_weapon_control(first)
	controller.deactivate_manual_control()
	_check(not first.is_manual_control_active(), "battle end can restore automatic mode")
	ship.queue_free()
	await get_tree().process_frame
	if _failed:
		get_tree().quit(1)
	else:
		print("MANUAL_TURRET_CONTROL_TEST: PASS")
		get_tree().quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("MANUAL_TURRET_CONTROL_TEST: " + message)
