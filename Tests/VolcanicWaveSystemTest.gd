extends Node

## Runs against a throwaway save, never the player's real progression.
const TestSave := preload("res://Tests/TestSave.gd")

## Headless validation for Volcanic fixed quotas, deterministic packs, shared
## budgets, formation safety, Demon Lord scheduling, and reserved-boss fallback.

const BATTLE_SCENE: PackedScene = preload("res://Scenes/Battle/BattleMain.tscn")
const VOLCANIC_CONFIG: PlanetWaveConfig = preload("res://Resources/Waves/VolcanicPlanetWaves.tres")
const VERDANT_CONFIG: PlanetWaveConfig = preload("res://Resources/Waves/VerdantPlanetWaves.tres")
const DEMON_SCENE: PackedScene = preload("res://Scenes/Enemies/demon.tscn")
const HELLHUNTER_SCENE: PackedScene = preload("res://Scenes/Enemies/hellhunter.tscn")

const EXPECTED_COUNTS: Array[Array] = [
	[14, 4, 0, 0], [22, 8, 0, 0], [22, 9, 6, 2],
	[24, 11, 7, 3], [24, 11, 9, 4], [25, 13, 11, 5],
	[29, 15, 12, 7], [29, 17, 14, 9], [30, 19, 17, 12],
	[34, 21, 21, 14], [82, 28, 16, 5],
]
const EXPECTED_TOTALS: Array[int] = [18, 30, 39, 45, 48, 54, 63, 69, 78, 90, 131]
const EXPECTED_BUDGETS: Array[int] = [22, 38, 62, 75, 84, 98, 118, 136, 162, 188, 245]
const EXPECTED_EVENTS: Array[Dictionary] = [
	{"wave": 2, "fraction": 0.40, "enemy": &"hellhunter", "size": 6},
	{"wave": 3, "fraction": 0.50, "enemy": &"demon", "size": 6},
	{"wave": 4, "fraction": 0.35, "enemy": &"hellhunter", "size": 8},
	{"wave": 5, "fraction": 0.60, "enemy": &"demon", "size": 8},
	{"wave": 6, "fraction": 0.45, "enemy": &"hellhunter", "size": 10},
	{"wave": 7, "fraction": 0.55, "enemy": &"demon", "size": 9},
	{"wave": 8, "fraction": 0.30, "enemy": &"hellhunter", "size": 10},
	{"wave": 8, "fraction": 0.70, "enemy": &"demon", "size": 9},
	{"wave": 9, "fraction": 0.30, "enemy": &"hellhunter", "size": 10},
	{"wave": 9, "fraction": 0.65, "enemy": &"demon", "size": 9},
	{"wave": 10, "fraction": 0.25, "enemy": &"hellhunter", "size": 10},
	{"wave": 10, "fraction": 0.50, "enemy": &"demon", "size": 10},
	{"wave": 10, "fraction": 0.75, "enemy": &"hellhunter", "size": 10},
]

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("volcanic_wave_system_test")
	ShipLoadout.installed_modules.clear()
	_test_configuration_and_plans()
	await _test_formation_safety()
	await _test_deterministic_runtime_event()
	await _test_missing_boss_state()
	ShipLoadout.installed_modules.clear()
	_finish()


func _test_configuration_and_plans() -> void:
	_expect_true(VOLCANIC_CONFIG.get_validation_errors().is_empty(), "Volcanic configuration validates")
	_expect_equal(VOLCANIC_CONFIG.planet_id, &"volcanic_planet", "Lava uses the existing Volcanic identity")
	_expect_equal(VOLCANIC_CONFIG.get_total_waves(), 11, "Volcanic has eleven waves")
	var first_ten_count := 0
	var campaign_non_boss_count := 0
	var first_ten_budget := 0
	for index in range(11):
		var wave := VOLCANIC_CONFIG.waves[index]
		_expect_equal(wave.wave_number, index + 1, "wave number %d" % (index + 1))
		_expect_equal(_entry_count(wave, &"demon"), EXPECTED_COUNTS[index][0], "wave %d Demon quota" % (index + 1))
		_expect_equal(_entry_count(wave, &"hellhunter"), EXPECTED_COUNTS[index][1], "wave %d Hellhunter quota" % (index + 1))
		_expect_equal(_entry_count(wave, &"imp"), EXPECTED_COUNTS[index][2], "wave %d Imp quota" % (index + 1))
		_expect_equal(_entry_count(wave, &"big_demon"), EXPECTED_COUNTS[index][3], "wave %d Big Demon quota" % (index + 1))
		var expected_with_boss := EXPECTED_TOTALS[index] + (1 if index == 10 else 0)
		_expect_equal(wave.get_total_spawn_count(), expected_with_boss, "wave %d exact scheduled total" % (index + 1))
		_expect_equal(wave.get_total_spawn_budget(), EXPECTED_BUDGETS[index], "wave %d shared budget" % (index + 1))
		_expect_true(wave.batch_spawning_enabled, "wave %d uses manageable batches" % (index + 1))
		_expect_true(wave.get_spawn_batch_size() > 1, "wave %d batch contains multiple enemies" % (index + 1))
		if index < 10:
			_expect_near(wave.preparation_duration, VERDANT_CONFIG.waves[index].preparation_duration, "wave %d preserves preparation duration" % (index + 1))
			_expect_near(wave.spawn_interval, VERDANT_CONFIG.waves[index].spawn_interval, "wave %d preserves spawn interval" % (index + 1))
			_expect_near(wave.get_effective_spawn_phase_duration(), VERDANT_CONFIG.waves[index].get_effective_spawn_phase_duration(), "wave %d preserves active spawn duration" % (index + 1))
			first_ten_count += wave.get_total_spawn_count()
			first_ten_budget += wave.get_total_spawn_budget()
		campaign_non_boss_count += _non_boss_count(wave)

		var rng := RandomNumberGenerator.new()
		rng.seed = 7000 + index
		var plan := WaveSpawnPlanner.build_plan(wave, VOLCANIC_CONFIG.special_spawn_rules, rng)
		_expect_true(plan.validation_errors.is_empty(), "wave %d plan validates" % (index + 1))
		_expect_equal(plan.total_spawn_count, wave.get_total_spawn_count(), "wave %d plan preserves quota" % (index + 1))
		_expect_equal(plan.total_spawn_budget, wave.get_total_spawn_budget(), "wave %d plan preserves budget" % (index + 1))
		_verify_wave_events_and_shared_quota(wave, plan)

	_expect_equal(first_ten_count, 534, "waves 1-10 total exactly 534")
	_expect_equal(first_ten_budget, 983, "waves 1-10 budget remains internally consistent")
	_expect_equal(_non_boss_count(VOLCANIC_CONFIG.waves[10]), 131, "wave 11 has 131 non-boss enemies")
	_expect_equal(campaign_non_boss_count, 665, "campaign has 665 non-boss enemies")
	_expect_equal(VOLCANIC_CONFIG.waves[10].get_total_spawn_count(), 132, "wave 11 schedules 131 enemies plus Demon Lord")
	_expect_equal(campaign_non_boss_count + 1, 666, "campaign has exactly 666 scheduled enemies including Demon Lord")

	var boss_wave := VOLCANIC_CONFIG.waves[10]
	_expect_true(boss_wave.boss_wave, "wave 11 is marked as a boss wave")
	_expect_false(boss_wave.has_missing_reserved_boss(), "wave 11 has its authored boss")
	_expect_equal(_entry_count(boss_wave, &"demon_lord"), 1, "wave 11 contains one Demon Lord")
	_expect_false(boss_wave.boss_summons_consume_wave_quota, "Demon Lord summons are explicitly extra")
	var boss_entries := 0
	for entry in boss_wave.enemy_entries:
		if entry.is_boss:
			boss_entries += entry.spawn_count
			_expect_equal(entry.enemy_id, &"demon_lord", "Demon Lord drives the boss HUD")
	_expect_equal(boss_entries, 1, "exactly one boss is scheduled")


func _verify_wave_events_and_shared_quota(wave: WaveDefinition, plan: WaveSpawnPlan) -> void:
	var expected_for_wave: Array[Dictionary] = []
	for expected in EXPECTED_EVENTS:
		if int(expected["wave"]) == wave.wave_number:
			expected_for_wave.append(expected)
	_expect_equal(plan.timed_requests.size(), expected_for_wave.size(), "wave %d deterministic event count" % wave.wave_number)
	_expect_equal(plan.special_events.size(), expected_for_wave.size(), "wave %d event metadata count" % wave.wave_number)
	var reserved_by_enemy := {}
	for event_index in range(expected_for_wave.size()):
		var expected := expected_for_wave[event_index]
		var request := plan.timed_requests[event_index]
		_expect_equal(request.entry.enemy_id, expected["enemy"], "wave %d pack enemy" % wave.wave_number)
		_expect_equal(request.spawn_count, expected["size"], "wave %d pack size" % wave.wave_number)
		_expect_near(request.trigger_phase_fraction, float(expected["fraction"]), "wave %d pack trigger fraction" % wave.wave_number)
		_expect_true(request.is_formation(), "wave %d pack uses formation" % wave.wave_number)
		_expect_false(request.with_flag_bearer, "wave %d pack has no Goblin flag bearer" % wave.wave_number)
		_expect_true(request.direction in WaveSpawnPlanner.CARDINAL_DIRECTIONS, "wave %d pack selects a cardinal direction" % wave.wave_number)
		var key := String(request.entry.enemy_id)
		reserved_by_enemy[key] = int(reserved_by_enemy.get(key, 0)) + request.spawn_count
	for enemy_id in [&"demon", &"hellhunter", &"imp", &"big_demon"]:
		var ordinary := _request_count(plan.requests, enemy_id)
		var reserved := int(reserved_by_enemy.get(String(enemy_id), 0))
		_expect_equal(ordinary + reserved, _entry_count(wave, enemy_id), "wave %d %s pack shares quota" % [wave.wave_number, enemy_id])


func _test_formation_safety() -> void:
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("WaveManager") as WaveManager
	manager.auto_start = false
	add_child(battle)
	await get_tree().process_frame
	var spawner := battle.get_node("EnemySpawner") as EnemySpawner
	for direction in WaveSpawnPlanner.CARDINAL_DIRECTIONS:
		for spec in [[DEMON_SCENE, 10, 32.0], [HELLHUNTER_SCENE, 10, 30.0]]:
			var spawned := spawner.spawn_formation(spec[0] as PackedScene, int(spec[1]), direction, float(spec[2]), false)
			_expect_equal(spawned.size(), 10, "lava formation spawns complete pack")
			for first_index in range(spawned.size()):
				for second_index in range(first_index + 1, spawned.size()):
					_expect_true(spawned[first_index].global_position.distance_to(spawned[second_index].global_position) >= float(spec[2]) - 0.1, "lava pack bodies keep configured spacing")
			for enemy in spawned:
				enemy.queue_free()
	battle.queue_free()
	await get_tree().process_frame


func _test_deterministic_runtime_event() -> void:
	var entry := EnemySpawnEntry.new()
	entry.enemy_id = &"demon"
	entry.enemy_scene = DEMON_SCENE
	entry.spawn_count = 6
	var wave := WaveDefinition.new()
	wave.wave_number = 1
	wave.spawn_interval = 0.02
	wave.spawn_phase_duration = 0.2
	wave.batch_spawning_enabled = true
	wave.enemy_entries = [entry]
	var rule := SpecialSpawnEventRule.new()
	rule.event_id = &"runtime_fixed_pack"
	rule.enemy_id = &"demon"
	rule.trigger_mode = SpecialSpawnEventRule.TriggerMode.FIXED_PHASE_FRACTION
	rule.exact_wave = 1
	rule.trigger_phase_fraction = 0.5
	rule.fixed_group_size = 6
	rule.pattern = SpecialSpawnEventRule.Pattern.FORMATION
	rule.with_flag_bearer = false
	var config := PlanetWaveConfig.new()
	config.planet_id = &"volcanic_runtime_test"
	config.waves = [wave]
	config.special_spawn_rules = [rule]

	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("WaveManager") as WaveManager
	manager.auto_start = false
	manager.wave_config = config
	add_child(battle)
	await get_tree().process_frame
	_expect_true(manager.start_wave_system(), "deterministic runtime event starts")
	_expect_true(await _wait_until(func() -> bool: return manager.get_executed_special_events().size() == 1, 120), "fixed pack executes")
	await _wait_frames(20)
	var events := manager.get_executed_special_events()
	_expect_equal(events.size(), 1, "fixed pack executes exactly once")
	if not events.is_empty():
		_expect_near(float(events[0]["scheduled_fraction"]), 0.5, "fixed pack keeps scheduled fraction")
		_expect_true(float(events[0]["actual_fraction"]) >= 0.5, "fixed pack does not execute early")
	_expect_equal(manager.get_scheduled_spawn_count(), 6, "runtime schedule has shared six-enemy quota")
	_expect_equal(manager.get_scheduled_spawned_count(), 6, "runtime event consumes quota once")
	battle.queue_free()
	await get_tree().process_frame


func _test_missing_boss_state() -> void:
	var entry := EnemySpawnEntry.new()
	entry.enemy_id = &"demon"
	entry.enemy_scene = DEMON_SCENE
	entry.spawn_count = 1
	var wave := WaveDefinition.new()
	wave.wave_number = 11
	wave.spawn_interval = 0.01
	wave.spawn_phase_duration = 0.01
	wave.batch_spawning_enabled = true
	wave.boss_wave = true
	wave.reserved_boss_count = 1
	wave.reserved_boss_enemy_id = &"volcanic_boss_pending"
	wave.boss_summons_consume_wave_quota = true
	wave.missing_boss_message = "Test reserved boss."
	wave.enemy_entries = [entry]
	var config := PlanetWaveConfig.new()
	config.planet_id = &"volcanic_missing_boss_test"
	config.waves = [wave]

	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("WaveManager") as WaveManager
	manager.auto_start = false
	manager.wave_config = config
	add_child(battle)
	await get_tree().process_frame
	_expect_true(manager.start_wave_system(), "missing-boss wave starts regular quota")
	_expect_true(await _wait_until(func() -> bool: return manager.is_configuration_blocked(), 120), "missing future boss creates explicit blocked state")
	_expect_equal(manager.get_scheduled_spawn_count(), 1, "reserved boss is not silently added to the spawn queue")
	_expect_equal(manager.get_scheduled_spawned_count(), 1, "regular quota completes before boss block")
	battle.queue_free()
	await get_tree().process_frame


func _entry_count(wave: WaveDefinition, enemy_id: StringName) -> int:
	for entry in wave.enemy_entries:
		if entry != null and entry.enemy_id == enemy_id:
			return entry.spawn_count
	return -1


func _non_boss_count(wave: WaveDefinition) -> int:
	var total := 0
	for entry in wave.enemy_entries:
		if entry != null and not entry.is_boss:
			total += entry.spawn_count
	return total


func _request_count(requests: Array[WaveSpawnRequest], enemy_id: StringName) -> int:
	var total := 0
	for request in requests:
		if request.entry != null and request.entry.enemy_id == enemy_id:
			total += request.spawn_count
	return total


func _wait_until(condition: Callable, maximum_frames: int) -> bool:
	for _frame in range(maximum_frames):
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("VOLCANIC_WAVE_SYSTEM_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("VOLCANIC_WAVE_SYSTEM_TEST: " + failure)
		print("VOLCANIC_WAVE_SYSTEM_TEST: FAIL (%d failures)" % _failures.size())
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


func _expect_near(actual: float, expected: float, description: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])

