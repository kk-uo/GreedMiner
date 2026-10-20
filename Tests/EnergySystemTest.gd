extends Node

## Runs against a throwaway save, never the player's real progression.
const TestSave := preload("res://Tests/TestSave.gd")

## Headless integration checks for Energy Module v0.1.

const SHIP_SCENE: PackedScene = preload("res://Scenes/Ship/ship.tscn")
const ENERGY_SCENE: PackedScene = preload("res://Scenes/Modules/Energy/energy_module.tscn")
const MACHINE_GUN_SCENE: PackedScene = preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn")
const DWARF_CANNON_SCENE: PackedScene = preload("res://Scenes/Modules/Weapons/DwarfCannon/dwarf_cannon.tscn")
const LASER_SCENE: PackedScene = preload("res://Scenes/Modules/Weapons/Laser/laser.tscn")
const CHAINSAW_SCENE: PackedScene = preload("res://Scenes/Modules/Weapons/Chainsaw/chainsaw.tscn")
const MINING_SCENE: PackedScene = preload("res://Scenes/Modules/Mining/mining_module.tscn")

var _failures: Array[String] = []
var _saved_weapon_unlocks: Dictionary


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("energy_system_test")
	_saved_weapon_unlocks = WeaponUnlockManager.unlocked_weapon_ids.duplicate(true)
	for weapon_id in [&"machine_gun", &"dwarf_cannon", &"laser", &"chainsaw"]:
		WeaponUnlockManager.unlocked_weapon_ids[String(weapon_id)] = true
	ShipLoadout.installed_modules.clear()
	# This test exercises two-module energy aggregation, so explicitly grant the
	# separate one-time Laboratory permission without spending real save data.
	ResearchManager.progress.levels["energy_install_slot_unlock"] = 1
	ResearchManager.progress.levels["energy_core_1"] = 0
	ResearchManager.progress.levels["ship_power_1"] = 0

	var ship := SHIP_SCENE.instantiate() as Ship
	ship.assembly_mode = true
	add_child(ship)
	await get_tree().process_frame

	_expect_equal(ship.total_power_capacity, 4, "one Energy Module supplies 4 power before research")
	# Energy Core I (+1 Power per Energy Module); the rest of this test runs
	# with it researched.
	ResearchManager.progress.levels["energy_core_1"] = 1
	ResearchManager.research_level_changed.emit(&"energy_core_1", 1)
	_expect_equal(ship.total_power_capacity, 5, "Energy Core I raises one Energy Module to 5 power")
	_expect_equal(ship.total_expansion_capacity, 0, "expansion capacity remains zero")
	_expect_true(ShipLoadout.has_module(1, 1), "starting Energy Module occupies the center cell")

	var removed_last := ship.remove_module(1, 1)
	_expect_false(removed_last, "final Energy Module cannot be removed")
	_expect_true(ShipLoadout.has_module(1, 1), "rejected removal preserves the Energy Module")

	_expect_true(
		ship.install_module(ENERGY_SCENE, Ship.ModuleType.Energy, 2, 2),
		"second Energy Module can be installed"
	)
	_expect_equal(ship.total_power_capacity, 10, "two Energy Modules supply 10 power")

	_expect_true(ship.remove_module(2, 2), "unneeded second Energy Module can be removed")
	_expect_equal(ship.total_power_capacity, 5, "power returns to 5 after valid removal")

	_expect_true(
		ship.install_module(MACHINE_GUN_SCENE, Ship.ModuleType.Weapon, 0, 0),
		"Machine Gun installation succeeds"
	)
	_expect_equal(ship.total_power_consumption, 1, "one weapon consumes 1 power")

	_expect_true(
		ship.install_module(DWARF_CANNON_SCENE, Ship.ModuleType.Weapon, 0, 1),
		"second weapon installation succeeds"
	)
	_expect_true(
		ship.install_module(MINING_SCENE, Ship.ModuleType.Mining, 0, 2),
		"Mining Module installation succeeds"
	)
	_expect_equal(
		ship.total_power_consumption,
		4,
		"two weapons and one Mining Module consume 4 power"
	)
	_expect_equal(ship.available_power, 1, "module load remains separate from five-unit capacity")

	_expect_true(
		ship.install_module(LASER_SCENE, Ship.ModuleType.Weapon, 1, 0),
		"fifth unit of module load fits one Energy Module"
	)
	_expect_equal(ship.total_power_consumption, 5, "current load consumes 5 power")
	_expect_equal(ship.available_power, 0, "fully powered example has zero available power")

	var overloaded_install := ship.install_module(
		CHAINSAW_SCENE,
		Ship.ModuleType.Weapon,
		1,
		2
	)
	_expect_false(overloaded_install, "installation beyond capacity is rejected")
	_expect_equal(ship.last_module_error.begins_with("Insufficient Power"), true, "rejection explains insufficient power")
	_expect_false(ShipLoadout.has_module(1, 2), "rejected install leaves the cell unchanged")

	var energy_path_before_replacement := ShipLoadout.get_module(1, 1)
	var rejected_replacement := ship.replace_module(
		LASER_SCENE,
		Ship.ModuleType.Weapon,
		1,
		1
	)
	_expect_false(rejected_replacement, "replacement cannot remove the final Energy Module")
	_expect_equal(
		ShipLoadout.get_module(1, 1),
		energy_path_before_replacement,
		"rejected replacement preserves the original Energy Module"
	)
	_expect_equal(ship.total_power_capacity, 5, "rejected replacement preserves capacity")

	_expect_true(
		ship.install_module(ENERGY_SCENE, Ship.ModuleType.Energy, 2, 2),
		"second Energy Module restores spare capacity"
	)
	_expect_true(
		ship.install_module(CHAINSAW_SCENE, Ship.ModuleType.Weapon, 1, 2),
		"sixth unit of module load fits with two Energy Modules"
	)
	_expect_equal(ship.total_power_consumption, 6, "current load consumes 6 power")

	var unsafe_energy_removal := ship.remove_module(2, 2)
	_expect_false(unsafe_energy_removal, "Energy Module removal cannot cause a power deficit")
	_expect_true(ShipLoadout.has_module(2, 2), "rejected Energy removal preserves loadout")

	var expected_snapshot := ship.get_energy_snapshot().duplicate(true)
	ship.queue_free()
	await get_tree().process_frame

	var restored_ship := SHIP_SCENE.instantiate() as Ship
	restored_ship.assembly_mode = true
	add_child(restored_ship)
	await get_tree().process_frame
	_expect_equal(
		restored_ship.get_energy_snapshot(),
		expected_snapshot,
		"energy totals survive ship scene reconstruction"
	)
	_expect_equal(restored_ship.total_expansion_capacity, 0, "restored expansion capacity remains zero")

	restored_ship.queue_free()
	ShipLoadout.installed_modules.clear()
	WeaponUnlockManager.unlocked_weapon_ids = _saved_weapon_unlocks
	await get_tree().process_frame

	if _failures.is_empty():
		print("ENERGY_SYSTEM_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("ENERGY_SYSTEM_TEST: " + failure)
		print("ENERGY_SYSTEM_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _expect_true(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)


func _expect_false(value: bool, description: String) -> void:
	if value:
		_failures.append(description)


func _expect_equal(actual: Variant, expected: Variant, description: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])
