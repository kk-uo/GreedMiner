extends Node

## Runs against a throwaway save, never the player's real progression.
const TestSave := preload("res://Tests/TestSave.gd")

## Headless integration coverage for editable wave data and split descendants.

const BATTLE_SCENE: PackedScene = preload("res://Scenes/Battle/BattleMain.tscn")
const ROCKY_CONFIG: PlanetWaveConfig = preload("res://Resources/Waves/RockyPlanetWaves.tres")
const LITTLE_SCENE: PackedScene = preload("res://Scenes/Enemies/little_rock.tscn")
const GOLEM_SCENE: PackedScene = preload("res://Scenes/Enemies/rock_golem.tscn")
const TITAN_SCENE: PackedScene = preload("res://Scenes/Enemies/rock_titan.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("wave_system_test")
	ShipLoadout.installed_modules.clear()
	_test_default_resource()
	await _test_next_wave_starts_after_spawning()
	await _test_rocky_inter_wave_gap()
	await _test_golem_descendants()
	await _test_titan_descendants_and_final_completion()
	await _test_cancellation_stops_pending_spawns()

	ShipLoadout.installed_modules.clear()
	if _failures.is_empty():
		print("WAVE_SYSTEM_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("WAVE_SYSTEM_TEST: " + failure)
		print("WAVE_SYSTEM_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _test_default_resource() -> void:
	_expect_equal(ROCKY_CONFIG.get_total_waves(), 7, "Rocky config contains 7 waves")
	_expect_equal(ROCKY_CONFIG.inter_wave_delay, 7.0, "Rocky waits seven seconds between waves")
	_expect_true(ROCKY_CONFIG.get_validation_errors().is_empty(), "Rocky config validates")
	# [Little Rock, Golem, Titan, interval, Red Rock]. Red Rocks replace
	# 1 in 10 Little Rocks (floor) on the first eight waves.
	var expected := [
		[10, 1, 0, 1.5, 1], [10, 1, 0, 1.5, 1], [12, 2, 0, 1.3, 1],
		[17, 3, 0, 1.3, 1], [18, 3, 0, 1.0, 2], [20, 4, 0, 1.0, 2],
		[8, 1, 1, 1.5, 0],
	]
	for index in range(ROCKY_CONFIG.waves.size()):
		var wave := ROCKY_CONFIG.waves[index]
		_expect_equal(wave.wave_number, index + 1, "wave number %d" % (index + 1))
		_expect_equal(_entry_count(wave, &"little_rock"), expected[index][0], "wave %d Little Rocks" % (index + 1))
		_expect_equal(_entry_count(wave, &"rock_golem"), expected[index][1], "wave %d Rock Golems" % (index + 1))
		_expect_equal(_entry_count(wave, &"rock_titan"), expected[index][2], "wave %d Rock Titans" % (index + 1))
		_expect_equal(maxi(_entry_count(wave, &"red_rock"), 0), expected[index][4], "wave %d Red Rocks" % (index + 1))
		_expect_equal(wave.spawn_interval, expected[index][3], "wave %d interval" % (index + 1))
		_expect_equal(wave.preparation_duration, 0.0, "wave %d has no preparation delay" % (index + 1))

	_expect_equal(_first_enemy_wave(&"rock_golem"), 1, "Rock Golem first appears on wave 1")
	_expect_equal(_first_enemy_wave(&"rock_titan"), 7, "Rock Titan first appears on wave 7")
	var boss_wave := ROCKY_CONFIG.waves[6]
	_expect_true(boss_wave.boss_wave, "wave 7 is marked as boss wave")
	var titan_entry := _find_entry(boss_wave, &"rock_titan")
	_expect_true(titan_entry != null and titan_entry.spawn_first, "Rock Titan is scheduled first")
	_expect_true(titan_entry != null and titan_entry.is_boss, "Rock Titan is boss tracked")


func _test_next_wave_starts_after_spawning() -> void:
	var first_wave := WaveDefinition.new()
	first_wave.wave_number = 1
	first_wave.preparation_duration = 0.0
	first_wave.spawn_interval = 0.05
	first_wave.enemy_entries = [_entry(&"little_rock", LITTLE_SCENE, 1)]
	var second_wave := WaveDefinition.new()
	second_wave.wave_number = 2
	second_wave.preparation_duration = 0.0
	second_wave.spawn_interval = 0.05
	second_wave.enemy_entries = [_entry(&"little_rock", LITTLE_SCENE, 1)]
	var config := PlanetWaveConfig.new()
	config.planet_id = &"continuous_wave_test"
	config.display_name = "Continuous Wave Test"
	config.waves = [first_wave, second_wave]

	var battle: Node = await _create_battle(config)
	var manager := battle.get_node("WaveManager") as WaveManager
	var enemies := battle.get_node("Enemies")
	_expect_true(await _wait_until(func() -> bool: return manager.get_current_wave_number() == 2), "wave 2 starts after wave 1 finishes spawning")
	_expect_true(await _wait_until(func() -> bool: return manager.get_alive_enemy_count() == 2), "wave 1 can remain alive while wave 2 spawns")
	_expect_false(manager.is_completed(), "overlapping living waves do not complete the planet")
	_kill_all(enemies)
	_expect_true(await _wait_until(func() -> bool: return manager.is_completed()), "final completion waits for all overlapping enemies")
	_cleanup_battle(battle)
	await get_tree().process_frame


func _test_rocky_inter_wave_gap() -> void:
	var first_wave := WaveDefinition.new()
	first_wave.wave_number = 1
	first_wave.spawn_interval = 0.05
	first_wave.enemy_entries = [_entry(&"little_rock", LITTLE_SCENE, 1)]
	var second_wave := WaveDefinition.new()
	second_wave.wave_number = 2
	second_wave.spawn_interval = 0.05
	second_wave.enemy_entries = [_entry(&"little_rock", LITTLE_SCENE, 1)]
	var config := PlanetWaveConfig.new()
	config.planet_id = &"rocky_gap_test"
	config.inter_wave_delay = ROCKY_CONFIG.inter_wave_delay
	config.waves = [first_wave, second_wave]
	var battle: Node = await _create_battle(config)
	var manager := battle.get_node("WaveManager") as WaveManager
	_expect_true(await _wait_until(func() -> bool: return manager._state == WaveManager.State.PREPARING), "Rocky enters preparation after wave 1 spawning")
	_expect_equal(manager.get_scheduled_spawned_count(), 1, "no wave 2 enemies spawn during the gap")
	manager.set_process(false)
	var remaining := manager._preparation_time_left
	_expect_true(remaining > 6.0 and remaining <= 7.0, "full seven-second gap starts after wave 1")
	manager._update_preparation(remaining - 0.1)
	_expect_equal(manager._state, WaveManager.State.PREPARING, "wave 2 does not start before seven seconds")
	manager._update_preparation(0.2)
	_expect_equal(manager._state, WaveManager.State.SPAWNING, "wave 2 starts once the gap expires")
	manager.set_process(true)
	_cleanup_battle(battle)
	await get_tree().process_frame


func _test_golem_descendants() -> void:
	var config := _single_wave_config(_entry(&"rock_golem", GOLEM_SCENE, 1))
	var battle: Node = await _create_battle(config)
	var manager := battle.get_node("WaveManager") as WaveManager
	var enemies := battle.get_node("Enemies")
	_expect_true(await _wait_until(func() -> bool: return manager.get_scheduled_spawned_count() == 1), "Golem wave spawns")
	var golem := _first_enemy(enemies, RockGolem)
	_expect_true(golem != null, "runtime wave uses configured Golem scene")
	if golem != null:
		golem.take_damage(10000.0)
		await _wait_frames(3)
		_expect_equal(manager.get_alive_enemy_count(), 2, "two split Little Rocks are tracked")
		_expect_false(manager.is_completed(), "wave does not complete while split enemies live")
		_kill_all(enemies)
		_expect_true(await _wait_until(func() -> bool: return manager.is_completed()), "wave completes after descendants die")
	_cleanup_battle(battle)
	await get_tree().process_frame


func _test_titan_descendants_and_final_completion() -> void:
	var titan_entry := _entry(&"rock_titan", TITAN_SCENE, 1)
	titan_entry.spawn_first = true
	titan_entry.is_boss = true
	var config := _single_wave_config(titan_entry, true)
	var battle: Node = await _create_battle(config)
	var manager := battle.get_node("WaveManager") as WaveManager
	var enemies := battle.get_node("Enemies")
	_expect_true(await _wait_until(func() -> bool: return manager.get_scheduled_spawned_count() == 1), "Titan boss spawns")
	var titan := _first_enemy(enemies, RockTitan)
	_expect_true(titan != null, "boss wave's first enemy is Rock Titan")
	if titan != null:
		_expect_equal(titan.max_health, 2000.0, "Titan HP is 2000")
		_expect_equal(titan.move_speed, 10.0, "Titan speed remains 10")
		_expect_equal(titan.attack_damage, 20.0, "Titan damage remains 20")
		_expect_equal(titan.attack_range, 50.0, "Titan attack range is 50")
		titan.take_damage(10000.0)
		await _wait_frames(3)
		_expect_equal(manager.get_alive_enemy_count(), 4, "four split Golems are tracked")
		_expect_false(manager.is_completed(), "boss death alone does not finish the wave")
		_kill_type(enemies, RockGolem)
		await _wait_frames(3)
		_expect_equal(manager.get_alive_enemy_count(), 8, "Golem descendants split into eight Little Rocks")
		_expect_false(manager.is_completed(), "second-generation descendants block completion")
		_kill_all(enemies)
		_expect_true(await _wait_until(func() -> bool: return manager.is_completed()), "final wave completes after all descendants")
		_expect_equal(manager.get_current_wave_number(), 1, "no wave 2 starts after one-wave final victory")
	_cleanup_battle(battle)
	await get_tree().process_frame


func _test_cancellation_stops_pending_spawns() -> void:
	var config := _single_wave_config(_entry(&"little_rock", LITTLE_SCENE, 5))
	config.waves[0].spawn_interval = 0.2
	var battle: Node = await _create_battle(config)
	var manager := battle.get_node("WaveManager") as WaveManager
	_expect_true(await _wait_until(func() -> bool: return manager.get_scheduled_spawned_count() >= 1), "cancellation test starts spawning")
	manager.stop_wave_system(&"test_evacuation")
	var spawned_when_stopped := manager.get_scheduled_spawned_count()
	await get_tree().create_timer(0.45).timeout
	_expect_equal(manager.get_scheduled_spawned_count(), spawned_when_stopped, "stopping cancels pending spawns")
	_expect_false(manager.is_completed(), "stopping does not emit victory state")
	_cleanup_battle(battle)
	await get_tree().process_frame


func _single_wave_config(entry: EnemySpawnEntry, boss_wave: bool = false) -> PlanetWaveConfig:
	var wave := WaveDefinition.new()
	wave.wave_number = 1
	wave.preparation_duration = 0.0
	wave.spawn_interval = 0.05
	wave.boss_wave = boss_wave
	wave.enemy_entries = [entry]
	var config := PlanetWaveConfig.new()
	config.planet_id = &"wave_test"
	config.display_name = "Wave Test"
	config.waves = [wave]
	return config


func _entry(id: StringName, scene: PackedScene, count: int) -> EnemySpawnEntry:
	var entry := EnemySpawnEntry.new()
	entry.enemy_id = id
	entry.enemy_scene = scene
	entry.spawn_count = count
	return entry


func _create_battle(config: PlanetWaveConfig) -> Node:
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("WaveManager") as WaveManager
	manager.auto_start = false
	manager.wave_config = config
	add_child(battle)
	await get_tree().process_frame
	manager.start_wave_system()
	return battle


func _cleanup_battle(battle: Node) -> void:
	if is_instance_valid(battle):
		battle.queue_free()


func _wait_until(condition: Callable, maximum_frames: int = 180) -> bool:
	for _frame in range(maximum_frames):
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().process_frame


func _kill_all(container: Node) -> void:
	for child in container.get_children():
		var enemy := child as BasicEnemy
		if enemy != null and not enemy.is_dying():
			enemy.take_damage(10000.0)


func _kill_type(container: Node, enemy_type: Variant) -> void:
	for child in container.get_children():
		if is_instance_of(child, enemy_type):
			(child as BasicEnemy).take_damage(10000.0)


func _first_enemy(container: Node, enemy_type: Variant) -> BasicEnemy:
	for child in container.get_children():
		if is_instance_of(child, enemy_type) and not (child as BasicEnemy).is_dying():
			return child as BasicEnemy
	return null


func _entry_count(wave: WaveDefinition, id: StringName) -> int:
	var entry := _find_entry(wave, id)
	return entry.spawn_count if entry != null else -1


func _find_entry(wave: WaveDefinition, id: StringName) -> EnemySpawnEntry:
	for entry in wave.enemy_entries:
		if entry != null and entry.enemy_id == id:
			return entry
	return null


func _first_enemy_wave(id: StringName) -> int:
	for wave in ROCKY_CONFIG.waves:
		if _entry_count(wave, id) > 0:
			return wave.wave_number
	return 0


func _expect_true(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)


func _expect_false(value: bool, description: String) -> void:
	if value:
		_failures.append(description)


func _expect_equal(actual: Variant, expected: Variant, description: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])
