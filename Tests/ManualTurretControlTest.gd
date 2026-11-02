extends Node

const TestSave := preload("res://Tests/TestSave.gd")
const SHIP_SCENE := preload("res://Scenes/Ship/ship.tscn")
const ENERGY_SCENE := preload("res://Scenes/Modules/Energy/energy_module.tscn")
const MACHINE_GUN_SCENE := preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn")
const MANUAL_TURRET_CONTROLLER := preload("res://Scripts/Battle/ManualTurretController.gd")
const RANGE_INDICATOR := preload("res://Scripts/Battle/TurretRangeIndicator.gd")

var _failed := false
var _range_bonus: float = 0.0


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
	var range_indicator := RANGE_INDICATOR.new() as RANGE_INDICATOR
	add_child(range_indicator)
	controller.set_range_indicator(range_indicator)
	controller.activate_weapon_control(first)
	_check(first.is_manual_control_active(), "first turret enters manual mode")
	_check(range_indicator.visible and range_indicator.target == first, "manual selection also shows the turret range")
	_check(is_equal_approx(range_indicator.radius, first.get_modified_attack_range(float(first.get("attack_range")))), "manual range uses the effective turret range")
	_range_bonus = 0.25
	first.add_artifact_range_bonus(Callable(self, "_get_range_bonus"))
	controller._process(0.0)
	_check(is_equal_approx(range_indicator.radius, float(first.get("attack_range")) * 1.25), "visible range updates with live artifact bonuses")
	first.remove_artifact_range_bonus(Callable(self, "_get_range_bonus"))
	_range_bonus = 0.0
	controller.activate_weapon_control(second)
	_check(not first.is_manual_control_active() and second.is_manual_control_active(), "switching releases the previous turret")
	_check(range_indicator.visible and range_indicator.target == second, "range indicator follows the newly selected turret")
	controller.activate_weapon_control(second)
	_check(not second.is_manual_control_active(), "clicking the same turret toggles manual mode off")
	_check(not range_indicator.visible, "toggling manual mode off hides the range")
	controller.activate_weapon_control(first)
	controller.deactivate_manual_control()
	_check(not first.is_manual_control_active(), "battle end can restore automatic mode")
	_check(not range_indicator.visible, "battle end hides the range")
	range_indicator.queue_free()
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


func _get_range_bonus() -> float:
	return _range_bonus
