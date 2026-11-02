extends Node

var failures: Array[String] = []


func _ready() -> void:
	ResourceManager.start_new_mission()
	ResourceManager.set_current_expedition_planet(DragonNestRules.PLANET_ID)
	var battle := (load("res://Scenes/Battle/BattleMain.tscn") as PackedScene).instantiate()
	add_child(battle)
	for _frame in range(3):
		await get_tree().process_frame
	var ship := battle.get_node("Ship") as Ship
	var waves := battle.get_node("WaveManager") as WaveManager
	var enemies := battle.get_node("Enemies") as Node2D
	ship.set_weapon_attacks_enabled(false)
	waves.stop_wave_system(&"cap_test_setup")
	check(waves.start_wave_system(10), "wave 10 starts directly")
	for _tick in range(16):
		waves._update_spawning(2.1)
	var dragons := _scheduled_dragons(enemies)
	check(dragons.size() == 2, "scheduled Young + Greater Dragon concurrency stops at two")
	# Claude sync 94: the Greater Dragon brings two escorts outside the cap.
	await get_tree().process_frame
	var escorts := enemies.get_children().filter(func(n: Node) -> bool: return n is BasicEnemy and (n as BasicEnemy).enemy_id == &"young_dragon" and bool(n.get_meta("dragon_nest_escort", false)))
	check(escorts.size() == 2, "Greater Dragon arrives with two Young Dragon escorts (%d)" % escorts.size())
	check(waves.get_remaining_enemy_count() > waves.get_alive_enemy_count(), "queued dragon remains pending")
	var planned_before := waves.get_scheduled_spawned_count()
	if not dragons.is_empty():
		dragons[0]._die()
	await get_tree().process_frame
	waves._update_spawning(2.1)
	check(waves.get_scheduled_spawned_count() == planned_before + 1, "queued dragon spawns when a slot opens")
	check(_scheduled_dragons(enemies).size() == 2, "slot refill still respects cap")

	battle.queue_free()
	for _frame in range(3):
		await get_tree().process_frame
	if failures.is_empty():
		print("DRAGON_NEST_WAVE_CAP_TEST: PASS")
		get_tree().quit(0)
	else:
		for message in failures:
			push_error("DRAGON_NEST_WAVE_CAP_TEST: " + message)
		print("DRAGON_NEST_WAVE_CAP_TEST: FAIL (%d)" % failures.size())
		get_tree().quit(1)


func _scheduled_dragons(container: Node2D) -> Array[BasicEnemy]:
	var result: Array[BasicEnemy] = []
	for child in container.get_children():
		var enemy := child as BasicEnemy
		if enemy != null and enemy.enemy_id in [&"young_dragon", &"greater_dragon"] and not bool(enemy.get_meta("dragon_nest_boss_summon", false)) and not bool(enemy.get_meta("dragon_nest_escort", false)):
			result.append(enemy)
	return result


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
