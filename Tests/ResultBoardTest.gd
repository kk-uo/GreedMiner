extends Node

## BattleStats tallies (kills per enemy type and weapon, ore by source,
## artifacts) and the victory flow: banner beat, then the result board.
const TestSave := preload("res://Tests/TestSave.gd")
const BATTLE_SCENE := preload("res://Scenes/Battle/BattleMain.tscn")
const VERDANT := preload("res://Resources/Waves/VerdantPlanetWaves.tres")
const GOBLIN := preload("res://Scenes/Enemies/goblin.tscn")
const MACHINE_GUN_SCENE := preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn")
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("result_board_test")
	ShipLoadout.installed_modules.clear()
	ResourceManager.start_new_mission()
	var battle := BATTLE_SCENE.instantiate()
	(battle.get_node("WaveManager") as WaveManager).auto_start = false
	add_child(battle)
	await get_tree().process_frame
	var stats := battle.get_node_or_null("BattleStats") as BattleStats
	_check(stats != null, "battle owns a BattleStats node")
	if stats == null:
		_finish()
		return
	# Ore sources.
	ResourceManager.add_mission_ore(40.0, &"drill")
	ResourceManager.add_mission_ore(10.0, &"crystal")
	ResourceManager.add_mission_ore(5.0)
	_check(is_equal_approx(float(stats.ore_by_source.get(&"drill", 0.0)), 40.0), "drill ore is tallied")
	_check(is_equal_approx(float(stats.ore_by_source.get(&"crystal", 0.0)), 10.0), "crystal ore is tallied")
	_check(is_equal_approx(float(stats.ore_by_source.get(&"other", 0.0)), 5.0), "unlabelled ore counts as other")
	_check(is_equal_approx(stats.total_ore(), 55.0), "total ore adds every source")
	# Kills: two goblins die, one credited to a weapon.
	var ship := battle.get_node("Ship") as Ship
	ship.install_module(MACHINE_GUN_SCENE, Ship.ModuleType.Weapon, 0, 0)
	await get_tree().process_frame
	var weapon: WeaponModule = null
	for module in ship.installed_modules.get_children():
		if module is WeaponModule:
			weapon = module
	var enemies := battle.get_node("Enemies")
	for i in range(2):
		var goblin := GOBLIN.instantiate() as BasicEnemy
		goblin.global_position = Vector2(2000 + i * 50, 2000)
		enemies.add_child(goblin)
	await get_tree().process_frame
	var goblins := enemies.get_children().filter(func(n: Node) -> bool: return n is BasicEnemy)
	(goblins[0] as BasicEnemy).take_damage(99999.0, false, true, weapon)
	(goblins[1] as BasicEnemy).take_damage(99999.0)
	await get_tree().process_frame
	_check(int(stats.kills.get(&"goblin", {}).get("count", 0)) == 2, "two goblin kills are counted under their enemy id")
	_check(stats.total_kills() == 2, "total kills")
	_check(int(stats.weapon_kills.get(&"machine_gun", 0)) == 1, "only the credited kill counts for the machine gun")
	_check(stats.best_weapon() == &"machine_gun", "best weapon is the machine gun")
	# Victory: the board waits for the beat (slow motion + banner), then shows.
	battle._on_planet_completed(VERDANT)
	_check(stats.frozen, "stats freeze when the battle ends")
	await get_tree().create_timer(1.0, true, false, true).timeout
	_check(battle.get_node_or_null("ResultLayer") == null, "no board during the end beat")
	await get_tree().create_timer(3.4, true, false, true).timeout
	var board := battle.get_node_or_null("ResultLayer/ResultBoard") as ResultBoard
	_check(board != null and board.is_victory(), "victory result board appears after the beat")
	_check(is_equal_approx(Engine.time_scale, 1.0), "time scale restored")
	if board != null:
		board.skip_animation()
		var button := board.get_return_button()
		_check(button != null and button.is_visible_in_tree(), "board has a Return to Base button")
		_check(board.return_requested.is_connected(Callable(battle, "_on_completion_return_to_base_pressed")), "board returns through the completion handler")
	battle.queue_free()
	await get_tree().process_frame
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("RESULT_BOARD_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("RESULT_BOARD_TEST: " + failure)
		print("RESULT_BOARD_TEST: FAIL (%d failures)" % failures.size())
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
