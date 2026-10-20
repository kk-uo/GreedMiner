extends Node

## Runs against a throwaway save, never the player's real progression.
const TestSave := preload("res://Tests/TestSave.gd")

## After the battle ends (planet completed), every module is paused:
## weapons stop attacking and mining drills stop adding ore.

const BATTLE_SCENE: PackedScene = preload("res://Scenes/Battle/BattleMain.tscn")
const MINING_SCENE_PATH: String = "res://Scenes/Modules/Mining/mining_module.tscn"
const MACHINE_GUN_SCENE_PATH: String = "res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn"

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("battle_end_pause_test")
	ShipLoadout.installed_modules.clear()
	ShipLoadout.install_module(0, 0, MINING_SCENE_PATH)
	ShipLoadout.install_module(0, 2, MACHINE_GUN_SCENE_PATH)
	var battle := BATTLE_SCENE.instantiate()
	battle.get_node("WaveManager").auto_start = false
	add_child(battle)
	await get_tree().process_frame
	var ship := battle.get_node("Ship") as Ship

	var mining: MiningModule = null
	for module in ship.installed_modules.get_children():
		if module is MiningModule:
			mining = module
	_expect_true(mining != null and mining.mining_enabled, "mining runs during the battle")
	_expect_true(ship.are_weapon_attacks_enabled(), "weapons fire during the battle")

	battle._on_planet_completed(null)
	await get_tree().process_frame
	_expect_false(mining != null and mining.mining_enabled, "mining stops when the waves are over")
	_expect_false(ship.are_weapon_attacks_enabled(), "weapons stop when the waves are over")
	var ore_after_end := ResourceManager.mission_ore
	await get_tree().create_timer(2.2).timeout
	_expect_equal(ResourceManager.mission_ore, ore_after_end, "no ore is mined after the battle ended")

	battle.queue_free()
	ShipLoadout.installed_modules.clear()
	await get_tree().process_frame
	if _failures.is_empty():
		print("BATTLE_END_PAUSE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("BATTLE_END_PAUSE_TEST: " + failure)
		print("BATTLE_END_PAUSE_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _expect_true(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)


func _expect_false(value: bool, description: String) -> void:
	_expect_true(not value, description)


func _expect_equal(actual: Variant, expected: Variant, description: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])
