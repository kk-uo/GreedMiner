extends Node2D

const TEST_SAVE := preload("res://Tests/TestSave.gd")
const BATTLE := preload("res://Scenes/Battle/BattleMain.tscn")
const FRANK := preload("res://Scenes/Enemies/giant_frank.tscn")
var failures: Array[String] = []

class GraveProvider extends Node2D:
	var points: Array[Vector2] = []
	func get_grave_emerge_points() -> Array[Vector2]:
		return points
	func get_world_bounds() -> Rect2:
		return Rect2(0, 0, 3200, 2200)

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	TEST_SAVE.isolate("giant_frank")
	var battle := BATTLE.instantiate()
	battle.get_node("WaveManager").auto_start = false
	battle.get_node("MiningQteManager").auto_trigger = false
	battle.get_node("ShipLaunchController").play_landing_on_ready = false
	add_child(battle)
	await get_tree().process_frame
	var enemies := battle.get_node("Enemies") as Node2D
	var manager := battle.get_node("WaveManager") as WaveManager
	var provider := GraveProvider.new()
	provider.name = "TestGraves"
	battle.add_child(provider)
	for count in [5, 8, 0]:
		provider.points.clear()
		for i in count:
			provider.points.append(Vector2(300 + i * 60, 300))
		var boss := FRANK.instantiate() as GiantFrank
		boss.grave_provider_path = NodePath("../../TestGraves")
		boss.target_ship = battle.get_node("Ship")
		boss.grave_warning_time = 0.0
		boss.grave_spawn_time = 0.0
		boss.lightning_strike_time = 0.0
		boss.resurrection_finish_time = 0.0
		enemies.add_child(boss)
		boss.global_position = Vector2(1000, 600)
		var events: Array[String] = []
		boss.zombies_summoned.connect(func(n: int): events.append("summon:%d" % n))
		boss.lightning_struck.connect(func(_p: Vector2): events.append("lightning"))
		ResourceManager.start_new_mission()
		check(boss.max_health == 10000 and boss.move_speed == 10 and boss.damage_reduction == 0, "initial stats")
		boss.take_damage(10000)
		boss.take_damage(10000)
		check(boss.phase == GiantFrank.Phase.FIRST_DEATH and ResourceManager.mission_ore == 0, "first death is not final or rewarded")
		check(manager.get_alive_enemy_count() == 1, "boss remains tracked during resurrection")
		boss._process(0.1)
		check(events == ["summon:%d" % count, "lightning"], "one event and one zombie per grave: %d" % count)
		check(manager.get_alive_enemy_count() == count + 1, "summoned zombies tracked")
		check(boss.get_current_health() == 5000 and boss.move_speed == 20 and boss.damage_reduction == 0.5, "revived stats")
		boss.take_damage(100)
		check(boss.get_current_health() == 4950, "phase two reduction")
		boss.take_damage(100000)
		check(ResourceManager.mission_ore == 800 and boss.phase == GiantFrank.Phase.FINAL_DEATH, "final reward once")
		boss.take_damage(100000)
		check(ResourceManager.mission_ore == 800, "duplicate final damage gives no reward")
		for enemy in enemies.get_children():
			enemy.queue_free()
		await get_tree().process_frame
	if failures.is_empty():
		print("GIANT_FRANK_TEST: PASS")
	else:
		for failure in failures:
			push_error("GIANT_FRANK_TEST: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)
