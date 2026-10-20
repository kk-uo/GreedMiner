extends Node

## Runs against a throwaway save, never the player's real progression.
const TestSave := preload("res://Tests/TestSave.gd")

## Headless integration checks for ship-destruction battle handling.

const BATTLE_SCENE: PackedScene = preload("res://Scenes/Battle/BattleMain.tscn")
const MACHINE_GUN_SCENE: PackedScene = preload(
	"res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn"
)
const BASE_SCENE_PATH: String = "res://Scenes/Base/base_main.tscn"

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("battle_game_over_test")
	ShipLoadout.installed_modules.clear()
	ResourceManager.mission_ore = 12.0
	var stored_ore_before := ResourceManager.stored_ore

	var battle := BATTLE_SCENE.instantiate()
	add_child(battle)
	await get_tree().process_frame

	var ship := battle.get_node("Ship") as Ship
	var game_over_panel := battle.get_node(
		"BattleUI/UIRoot/GameOverPanel"
	) as PanelContainer
	var return_button := battle.get_node(
		"BattleUI/UIRoot/GameOverPanel/VBoxContainer/ReturnToBaseButton"
	) as Button

	_expect_true(
		ship.install_module(MACHINE_GUN_SCENE, Ship.ModuleType.Weapon, 0, 0),
		"test weapon installs before destruction"
	)
	var weapon: WeaponModule = null
	for module in ship.installed_modules.get_children():
		if module is WeaponModule:
			weapon = module as WeaponModule
			break

	_expect_true(weapon != null, "installed weapon instance is available")
	_expect_false(game_over_panel.visible, "Game Over panel starts hidden")
	_expect_true(ship.are_weapon_attacks_enabled(), "weapons begin battle enabled")

	ship.take_damage(ship.max_hp)
	await get_tree().process_frame

	_expect_equal(ship.current_hp, 0.0, "ship reaches zero health")
	_expect_true(game_over_panel.visible, "Game Over panel appears after destruction")
	_expect_false(return_button.disabled, "Return to Base button remains clickable")
	_expect_false(ship.are_weapon_attacks_enabled(), "ship disables all weapon attacks")
	_expect_true(weapon != null and weapon.assembly_mode, "installed weapon enters inactive mode")
	_expect_equal(
		ResourceManager.stored_ore,
		stored_ore_before,
		"destroyed mission ore is not banked automatically"
	)
	_expect_true(ResourceLoader.exists(BASE_SCENE_PATH), "Return to Base target scene exists")
	_expect_true(
		return_button.pressed.is_connected(
			Callable(battle, "_on_return_to_base_pressed")
		),
		"Return to Base button is connected"
	)

	# Keep this test runner alive while BattleMain becomes the current scene so
	# the real button handler and asynchronous scene replacement can be verified.
	battle.reparent(get_tree().root)
	get_tree().current_scene = battle
	return_button.pressed.emit()
	await get_tree().scene_changed
	_expect_equal(
		get_tree().current_scene.scene_file_path,
		BASE_SCENE_PATH,
		"Return to Base button loads the official base scene"
	)

	ShipLoadout.installed_modules.clear()
	await get_tree().process_frame

	if _failures.is_empty():
		print("BATTLE_GAME_OVER_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("BATTLE_GAME_OVER_TEST: " + failure)
		print("BATTLE_GAME_OVER_TEST: FAIL (%d failures)" % _failures.size())
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
