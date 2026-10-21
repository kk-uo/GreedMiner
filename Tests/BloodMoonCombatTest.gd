extends Node

const TestSave := preload("res://Tests/TestSave.gd")
const BATTLE := preload("res://Scenes/Battle/BattleMain.tscn")
const SKELETON := preload("res://Scenes/Enemies/skeleton.tscn")
const ZOMBIE := preload("res://Scenes/Enemies/zombie.tscn")
const WEREWOLF := preload("res://Scenes/Enemies/werewolf.tscn")
const VAMPIRE := preload("res://Scenes/Enemies/vampire.tscn")
const FRANK := preload("res://Scenes/Enemies/giant_frank.tscn")
var failures: Array[String] = []


func check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("blood_moon_combat")
	var battle := BATTLE.instantiate()
	battle.get_node("WaveManager").auto_start = false
	battle.get_node("MiningQteManager").auto_trigger = false
	battle.get_node("ShipLaunchController").play_landing_on_ready = false
	add_child(battle)
	await get_tree().process_frame
	var enemies := battle.get_node("Enemies")
	var ship := battle.get_node("Ship") as Ship
	var weather := battle.get_node("WeatherManager") as WeatherManager
	var skeleton := SKELETON.instantiate() as BasicEnemy
	var zombie := ZOMBIE.instantiate() as BasicEnemy
	var wolf := WEREWOLF.instantiate() as BasicEnemy
	var vampire := VAMPIRE.instantiate() as BasicEnemy
	var frank := FRANK.instantiate() as BasicEnemy
	for enemy in [skeleton, zombie, wolf, vampire, frank]:
		enemies.add_child(enemy)
		enemy.set_physics_process(false)
	check(zombie.max_health == 200.0 and wolf.max_health == 350.0, "new enemy HP values")
	vampire.take_damage(20.0)
	check(is_equal_approx(vampire.get_current_health(), 190.0), "vampire keeps normal 50 percent defense")
	weather.set_blood_moon(true)
	weather.set_blood_moon(true)
	wolf.take_damage(100.0)
	check(is_equal_approx(wolf.get_current_health(), 300.0), "blood moon halves ordinary damage exactly once")
	zombie.take_damage(100.0, true)
	check(is_equal_approx(zombie.get_current_health(), 150.0), "blood moon also halves armor-bypassing damage")
	frank.damage_reduction = 0.5
	frank.take_damage(100.0)
	check(is_equal_approx(frank.get_current_health(), 9975.0), "blood moon and existing armor multiply")
	vampire.take_damage(100.0)
	check(is_equal_approx(vampire.get_current_health(), 170.0), "blood moon vampire takes 20 percent damage")
	vampire.take_damage(100.0, true)
	check(is_equal_approx(vampire.get_current_health(), 150.0), "blood moon vampire reduction applies to armor-bypassing damage")
	vampire.target_ship = ship
	vampire._is_attacking = true
	var hp_before := ship.current_hp
	vampire._on_attack_timer_timeout()
	check(is_equal_approx(ship.current_hp, hp_before), "blood moon vampire does not attack")
	weather.set_blood_moon(false)
	vampire.take_damage(20.0)
	check(is_equal_approx(vampire.get_current_health(), 140.0), "vampire returns to normal reduction after blood moon")
	vampire._on_attack_timer_timeout()
	check(is_equal_approx(ship.current_hp, hp_before - vampire.attack_damage), "vampire attacks normally after blood moon")
	wolf.take_damage(100.0)
	check(is_equal_approx(wolf.get_current_health(), 200.0), "ordinary defense returns to normal")
	if failures.is_empty():
		print("BLOOD_MOON_COMBAT_TEST: PASS")
	else:
		for failure in failures:
			push_error("BLOOD_MOON_COMBAT_TEST: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)
