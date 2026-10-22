extends Node

const SAVE := preload("res://Tests/TestSave.gd")
const BATTLE := preload("res://Scenes/Battle/BattleMain.tscn")
const CONFIG := preload("res://Resources/Waves/GraveyardPlanetWaves.tres")
const FRANK := preload("res://Scenes/Enemies/giant_frank.tscn")
const ZOMBIE := preload("res://Scenes/Enemies/zombie.tscn")
const SKELETON := preload("res://Scenes/Enemies/skeleton.tscn")
var failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _run() -> void:
	SAVE.isolate("graveyard_boss_zombie_death")
	var battle := BATTLE.instantiate()
	battle.get_node("WaveManager").auto_start = false
	battle.get_node("MiningQteManager").auto_trigger = false
	battle.get_node("ShipLaunchController").play_landing_on_ready = false
	add_child(battle)
	await get_tree().process_frame
	var enemies := battle.get_node("Enemies") as Node2D
	var manager := battle.get_node("WaveManager") as WaveManager
	manager.wave_config = CONFIG
	manager._current_wave_index = 9
	manager._state = WaveManager.State.SPAWNING
	manager.set_process(false)
	var boss := FRANK.instantiate() as GiantFrank
	boss.grave_provider_path = NodePath("../../MissingTestGraves")
	boss.grave_warning_time = 0.0
	boss.grave_spawn_time = 0.0
	boss.lightning_strike_time = 0.0
	boss.resurrection_finish_time = 0.0
	enemies.add_child(boss)
	manager._track_boss(boss)
	var zombie_a := ZOMBIE.instantiate() as BasicEnemy
	var zombie_b := ZOMBIE.instantiate() as BasicEnemy
	zombie_b.set_meta("spawn_origin", &"giant_frank_resurrection")
	var skeleton := SKELETON.instantiate() as BasicEnemy
	enemies.add_child(zombie_a)
	enemies.add_child(zombie_b)
	enemies.add_child(skeleton)
	ResourceManager.start_new_mission()
	boss.take_damage(10000.0)
	check(not zombie_a.is_dying() and not zombie_b.is_dying(), "first death must not kill zombies")
	boss._process(0.1)
	boss.take_damage(100000.0)
	check(zombie_a.is_dying() and zombie_b.is_dying(), "final death kills both scheduled and summoned zombies")
	check(not skeleton.is_dying(), "non-zombie enemies survive")
	check(ResourceManager.mission_ore == 802.0, "normal zombie and boss rewards granted once")
	var late_zombie := ZOMBIE.instantiate() as BasicEnemy
	enemies.add_child(late_zombie)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(late_zombie), "later scheduled zombies die too")
	check(ResourceManager.mission_ore == 803.0, "late zombie reward granted once")
	if failures.is_empty():
		print("GRAVEYARD_BOSS_ZOMBIE_DEATH_TEST: PASS")
	else:
		for failure in failures:
			push_error("GRAVEYARD_BOSS_ZOMBIE_DEATH_TEST: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)
