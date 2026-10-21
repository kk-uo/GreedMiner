extends Node
const SAVE := preload("res://Tests/TestSave.gd")
const CONFIG := preload("res://Resources/Waves/GraveyardPlanetWaves.tres")
const BATTLE := preload("res://Scenes/Battle/BattleMain.tscn")
var failures: Array[String] = []

func check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	SAVE.isolate("graveyard_wave")
	check(CONFIG.get_total_waves() == 10 and CONFIG.get_validation_errors().is_empty(), "valid ten waves")
	var totals := {}
	var expected_counts := [
		[27, 4, 0, 0], [44, 7, 0, 0], [51, 10, 4, 0],
		[58, 12, 5, 0], [60, 12, 6, 2], [64, 14, 8, 3],
		[73, 16, 10, 4], [83, 16, 11, 5], [93, 19, 13, 6],
		[16, 3, 3, 2],
	]
	var type_ids := [&"skeleton", &"zombie", &"werewolf", &"vampire"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for wave in CONFIG.waves:
		for entry in wave.enemy_entries:
			totals[entry.enemy_id] = int(totals.get(entry.enemy_id, 0)) + entry.spawn_count
		var plan := WaveSpawnPlanner.build_plan(wave, CONFIG.special_spawn_rules, rng)
		check(plan.validation_errors.is_empty(), "plan validation wave %d" % wave.wave_number)
		check(plan.total_spawn_count == wave.get_total_spawn_count(), "quota preservation wave %d" % wave.wave_number)
		check(plan.total_spawn_budget == wave.get_total_spawn_budget(), "budget counted once wave %d" % wave.wave_number)
		check(is_equal_approx(wave.spawn_phase_duration, 60.0) and is_equal_approx(wave.spawn_interval, 1.0), "unchanged timing wave %d" % wave.wave_number)
		for index in range(type_ids.size()):
			check(plan.get_planned_count(type_ids[index]) == expected_counts[wave.wave_number - 1][index], "quota wave %d: %s" % [wave.wave_number, type_ids[index]])
		var expected: Dictionary = {2: [8, 0.4], 4: [10, 0.4], 6: [12, 0.5], 8: [12, 0.35], 9: [15, 0.3]}
		if expected.has(wave.wave_number):
			check(plan.timed_requests.size() == 1 and plan.timed_requests[0].spawn_count == expected[wave.wave_number][0] and is_equal_approx(plan.timed_requests[0].trigger_phase_fraction, expected[wave.wave_number][1]), "pack schedule wave %d" % wave.wave_number)
			if plan.timed_requests.size() == 1:
				check(is_equal_approx(plan.timed_requests[0].formation_spacing, 26.0), "dense non-overlapping formation spacing wave %d" % wave.wave_number)
	check(totals.get(&"skeleton") == 569 and totals.get(&"zombie") == 113 and totals.get(&"werewolf") == 60 and totals.get(&"vampire") == 22 and totals.get(&"giant_frank") == 1, "exact totals")
	var battle := BATTLE.instantiate()
	battle.get_node("WaveManager").auto_start = false
	battle.get_node("MiningQteManager").auto_trigger = false
	battle.get_node("ShipLaunchController").play_landing_on_ready = false
	add_child(battle)
	await get_tree().process_frame
	var field := battle.get_node("Battlefield") as Battlefield
	field.planet_theme = &"graveyard"
	field.generate(4242)
	var manager := battle.get_node("WaveManager") as WaveManager
	manager.wave_config = CONFIG
	manager._current_wave_index = 8
	manager._spawn_phase_elapsed = 30.0
	var weather := battle.get_node("WeatherManager") as WeatherManager
	var grave_count := GraveSummoner.points(field).size()
	var budget_before_weather := manager.get_scheduled_spawn_budget()
	var spent_before_weather := manager.get_spent_spawn_budget()
	manager._update_graveyard_weather(CONFIG.waves[8])
	check(weather.blood_moon_active, "wave 9 blood moon overlaps lightning")
	check(manager.extra_weather_spawned == 0, "skeletons wait for the blackout")
	await get_tree().create_timer(0.7).timeout
	check(manager.extra_weather_spawned > 0 and manager.get_alive_enemy_count() == manager.extra_weather_spawned, "weather extras tracked")
	check(manager.extra_weather_spawned >= grave_count and manager.extra_weather_spawned <= grave_count * 3, "lightning spawns 1-3 skeletons per valid grave (%d for %d graves)" % [manager.extra_weather_spawned, grave_count])
	check(manager.get_scheduled_spawn_budget() == budget_before_weather and manager.get_spent_spawn_budget() == spent_before_weather, "weather summons do not consume wave budget")
	var enemy := battle.get_node("Enemies").get_child(0) as BasicEnemy
	check(is_equal_approx(enemy.get_effective_move_speed(), enemy.move_speed + 10.0), "new enemy receives speed bonus")
	var extras := manager.extra_weather_spawned
	manager._update_graveyard_weather(CONFIG.waves[8])
	check(manager.extra_weather_spawned == extras, "lightning event does not duplicate")
	manager._spawn_phase_elapsed = 50.0
	manager._update_graveyard_weather(CONFIG.waves[8])
	check(not weather.blood_moon_active and is_equal_approx(enemy.get_effective_move_speed(), enemy.move_speed), "blood moon removed")
	for child in battle.get_node("Enemies").get_children():
		child.queue_free()
	await get_tree().process_frame
	check(CONFIG.advance_on_wave_clear, "graveyard advances after clearing")
	check(manager.start_wave_system(), "graveyard wave system starts")
	manager.set_process(false)
	for _tick in range(31):
		manager._update_spawning(1.0)
	check(manager.get_current_wave_number() == 1, "wave stays at 1 while enemies survive")
	check(manager._state == WaveManager.State.CLEARING, "wave enters clearing before 60 seconds")
	check(manager.get_scheduled_spawned_count() == 31, "all first-wave enemies spawned")
	await get_tree().process_frame
	check(manager.get_current_wave_number() == 1, "deferred clear does not skip living enemies")
	for child in battle.get_node("Enemies").get_children():
		child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(manager.get_current_wave_number() == 2, "wave 2 starts as soon as wave 1 enemies are gone")
	manager.set_process(false)
	for _tick in range(10):
		manager._update_spawning(1.0)
	for child in battle.get_node("Enemies").get_children():
		child.queue_free()
	await get_tree().process_frame
	check(manager.get_current_wave_number() == 2 and not manager._timed_spawn_requests.is_empty(), "pending formation prevents an early wave advance")
	if failures.is_empty():
		print("GRAVEYARD_WAVE_TEST: PASS")
	else:
		for failure in failures:
			push_error("GRAVEYARD_WAVE_TEST: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)
