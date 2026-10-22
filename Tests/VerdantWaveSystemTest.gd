extends Node

## Runs against a throwaway save, never the player's real progression.
const TestSave := preload("res://Tests/TestSave.gd")

## Headless validation for Verdant fixed quotas, budgets, packs and boss reserve.

const BATTLE_SCENE: PackedScene = preload("res://Scenes/Battle/BattleMain.tscn")
const ROCKY_CONFIG: PlanetWaveConfig = preload("res://Resources/Waves/RockyPlanetWaves.tres")
const VERDANT_CONFIG: PlanetWaveConfig = preload("res://Resources/Waves/VerdantPlanetWaves.tres")
const GOBLIN_SCENE: PackedScene = preload("res://Scenes/Enemies/goblin.tscn")
const CHARIOT_SCENE: PackedScene = preload("res://Scenes/Enemies/goblin_giant_chariot.tscn")

## [Goblin, Hunter, Elite, Goblin Engineer]. Engineers replace 1 in 20
## Goblins (floor), so totals are unchanged and budgets grow by 2 each.
const EXPECTED_COUNTS: Array[Array] = [
	[30, 6, 2, 1], [33, 8, 3, 1],
	[32, 10, 5, 1], [34, 12, 7, 1], [37, 15, 10, 1], [38, 17, 12, 2],
	[39, 20, 17, 2], [48, 20, 20, 2],
]
const EXPECTED_TOTALS: Array[int] = [39, 45, 48, 54, 63, 69, 78, 90]
const EXPECTED_BUDGETS: Array[int] = [55, 67, 80, 96, 120, 138, 170, 194]
const EXPECTED_DIRECTION_MODES: Array[int] = [0, 0, 1, 0, 0, 1, 1, 1]

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("verdant_wave_system_test")
	ShipLoadout.installed_modules.clear()
	_test_configuration()
	_test_forced_goblin_pack()
	_test_directional_plans()
	_test_boss_direction_restriction()
	_test_pack_probability()
	await _test_cluster_positions()
	await _test_runtime_directional_positions()
	await _test_army_batch_runtime()
	await _test_pending_boss_transition()
	ShipLoadout.installed_modules.clear()
	_finish()


func _test_configuration() -> void:
	_expect_true(VERDANT_CONFIG.get_validation_errors().is_empty(), "Verdant configuration validates")
	_expect_equal(VERDANT_CONFIG.get_total_waves(), 9, "Verdant has nine wave slots")
	var total_count := 0
	var total_budget := 0
	var original_phase_durations := [19.5, 22.5, 24.0, 23.4, 27.3, 23.0, 26.0, 15.0]
	for index in range(8):
		var wave := VERDANT_CONFIG.waves[index]
		_expect_equal(wave.wave_number, index + 1, "Verdant wave number")
		_expect_equal(_entry_count(wave, &"goblin"), EXPECTED_COUNTS[index][0], "wave %d Goblins" % (index + 1))
		_expect_equal(_entry_count(wave, &"goblin_hunter"), EXPECTED_COUNTS[index][1], "wave %d Hunters" % (index + 1))
		_expect_equal(_entry_count(wave, &"elite_goblin"), EXPECTED_COUNTS[index][2], "wave %d Elites" % (index + 1))
		_expect_equal(maxi(_entry_count(wave, &"goblin_engineer"), 0), EXPECTED_COUNTS[index][3], "wave %d Goblin Engineers" % (index + 1))
		_expect_equal(wave.get_total_spawn_count(), EXPECTED_TOTALS[index], "wave %d total" % (index + 1))
		_expect_equal(wave.get_total_spawn_budget(), EXPECTED_BUDGETS[index], "wave %d shared budget" % (index + 1))
		_expect_equal(wave.spawn_direction_mode, EXPECTED_DIRECTION_MODES[index], "wave %d direction mode" % (index + 1))
		_expect_equal(wave.directional_batch_formation, index in [2, 5, 6, 7], "wave %d army formation setting" % (index + 1))
		_expect_near(wave.get_effective_spawn_phase_duration(), original_phase_durations[index], "wave %d preserves its original spawn duration" % (index + 1))
		_expect_true(wave.batch_spawning_enabled, "Verdant wave %d uses batching" % (index + 1))
		_expect_true(wave.get_spawn_batch_size() > 1, "Verdant wave %d batch contains multiple enemies" % (index + 1))
		total_count += wave.get_total_spawn_count()
		total_budget += wave.get_total_spawn_budget()
	_expect_equal(total_count, 486, "waves 1-8 total exact quota")
	_expect_equal(total_budget, 920, "waves 1-8 total shared budget")
	_expect_false(VERDANT_CONFIG.waves[7].boss_wave, "wave 8 Goblin Army is not a boss wave")
	var pending := VERDANT_CONFIG.waves[8]
	_expect_true(pending.boss_wave, "wave 11 is the boss wave")
	_expect_false(pending.configuration_pending, "wave 11 is no longer pending")
	_expect_equal(pending.enemy_entries.size(), 2, "wave 11 has boss and escort entries")
	var boss_entry: EnemySpawnEntry = null
	for entry in pending.enemy_entries:
		if entry != null and entry.is_boss:
			boss_entry = entry
	if boss_entry != null:
		_expect_equal(boss_entry.enemy_id, &"goblin_giant_chariot", "wave 11 boss is the Goblin Giant Chariot")
		_expect_equal(boss_entry.spawn_count, 1, "one chariot")
		_expect_true(boss_entry.is_boss and boss_entry.spawn_first, "chariot drives the boss HUD")
	else:
		_expect_true(false, "wave 11 has a boss entry")
	_expect_equal(_entry_count(pending, &"goblin"), 10, "wave 11 schedules ten regular Goblin escorts")
	_expect_equal(pending.get_total_spawn_count(), 11, "wave 11 fixed quota is boss plus ten escorts")
	_expect_equal(pending.get_total_spawn_budget(), 60, "wave 11 budget includes boss and escorts")
	_expect_equal(pending.spawn_direction_mode, WaveDefinition.SpawnDirectionMode.RESTRICTED_DIRECTIONS, "wave 11 uses restricted directions")
	_expect_equal(pending.get_allowed_direction_vectors(), [Vector2.LEFT, Vector2.RIGHT], "wave 11 allows only left and right")
	# Rocky's shortened wave list still validates under the extended schema.
	_expect_true(ROCKY_CONFIG.get_validation_errors().is_empty(), "Rocky configuration still validates")
	_expect_equal(ROCKY_CONFIG.get_total_waves(), 7, "Rocky has seven waves")


func _test_forced_goblin_pack() -> void:
	var forced := (VERDANT_CONFIG.special_spawn_rules[0].duplicate(true) as SpecialSpawnEventRule)
	forced.trigger_chance = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 314159
	var wave := VERDANT_CONFIG.waves[0]
	var plan := WaveSpawnPlanner.build_plan(wave, [forced], rng)
	_expect_true(plan.validation_errors.is_empty(), "forced pack plan validates")
	_expect_equal(plan.total_spawn_count, wave.get_total_spawn_count(), "pack adds no enemies")
	_expect_equal(plan.total_spawn_budget, wave.get_total_spawn_budget(), "pack adds no budget")
	_expect_equal(plan.get_planned_count(&"goblin"), 30, "pack preserves Goblin quota")
	_expect_equal(plan.special_events.size(), 1, "maximum one pack event")
	if not plan.special_events.is_empty():
		var event := plan.special_events[0]
		var size := int(event["group_size"])
		var direction := event["direction"] as Vector2
		_expect_true(size >= 6 and size <= 10, "pack size is 6-10")
		_expect_true(direction in WaveSpawnPlanner.CARDINAL_DIRECTIONS, "pack uses one cardinal direction")
		_expect_equal(int(event["pattern"]), WaveDefinition.SpawnPattern.FORMATION, "pack uses the organized formation")
	var cluster_requests := 0
	for request in plan.requests:
		if request.special_event_id == &"goblin_pack":
			cluster_requests += 1
			_expect_equal(request.direction, plan.special_events[0]["direction"], "entire pack shares direction")
	_expect_equal(cluster_requests, 1, "pack is one atomic formation request")


func _test_directional_plans() -> void:
	for wave_index in [2, 5, 6, 7]:
		var wave := VERDANT_CONFIG.waves[wave_index]
		var forced := VERDANT_CONFIG.special_spawn_rules[0].duplicate(true) as SpecialSpawnEventRule
		forced.trigger_chance = 1.0
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + wave_index
		var plan := WaveSpawnPlanner.build_plan(wave, [forced], rng)
		_expect_true(plan.selected_direction in WaveSpawnPlanner.CARDINAL_DIRECTIONS, "wave %d selects one cardinal edge" % wave.wave_number)
		for request in plan.requests:
			_expect_equal(request.direction, plan.selected_direction, "wave %d keeps one direction for all requests" % wave.wave_number)

	for wave_index in [0, 1, 3, 4]:
		var wave := VERDANT_CONFIG.waves[wave_index]
		var rng := RandomNumberGenerator.new()
		rng.seed = 10000 + wave_index
		var plan := WaveSpawnPlanner.build_plan(wave, [], rng)
		_expect_equal(plan.selected_direction, Vector2.ZERO, "normal wave %d has no locked edge" % wave.wave_number)
		for request in plan.requests:
			_expect_equal(request.direction, Vector2.ZERO, "normal wave %d preserves spawner pattern" % wave.wave_number)


func _test_boss_direction_restriction() -> void:
	var observed := {}
	var boss_wave := VERDANT_CONFIG.waves[8]
	for seed_value in range(1, 65):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var plan := WaveSpawnPlanner.build_plan(boss_wave, [], rng)
		_expect_true(plan.validation_errors.is_empty(), "boss direction plan validates")
		_expect_equal(plan.requests.size(), 11, "boss wave plan includes ten escorts")
		var boss_requests := 0
		for request in plan.requests:
			_expect_true(request.direction == Vector2.LEFT or request.direction == Vector2.RIGHT, "wave 11 requests never use top or bottom")
			if request.entry != null and request.entry.is_boss:
				boss_requests += 1
				var direction := request.direction
				observed[direction] = true
		_expect_equal(boss_requests, 1, "boss wave plan contains exactly one Chariot")
	_expect_true(observed.has(Vector2.LEFT), "boss can select left")
	_expect_true(observed.has(Vector2.RIGHT), "boss can select right")


func _test_pack_probability() -> void:
	var rule := VERDANT_CONFIG.special_spawn_rules[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 271828
	var triggered := 0
	var trials := 4000
	for _trial in range(trials):
		if rule.roll(rng):
			triggered += 1
	var observed := float(triggered) / float(trials)
	_expect_true(observed >= 0.22 and observed <= 0.28, "deterministic sample reflects 25 percent chance")
	_expect_true(rule.is_eligible(1, 52), "pack is eligible from the new wave 1")


func _test_cluster_positions() -> void:
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("WaveManager") as WaveManager
	manager.auto_start = false
	add_child(battle)
	await get_tree().process_frame
	var spawner := battle.get_node("EnemySpawner") as EnemySpawner
	var ship := battle.get_node("Ship") as Ship
	var ship_center := ship.to_global(Ship.SHIP_SIZE * 0.5)
	for direction in WaveSpawnPlanner.CARDINAL_DIRECTIONS:
		var block := spawner.get_directional_formation_positions(direction, 6, 46.0)
		_expect_equal(block.size(), 6, "army batch has six slots")
		var axis := Vector2(-direction.y, direction.x)
		var rows := {}
		var columns := {}
		for point in block:
			_expect_true(battle.get_node("Battlefield").get_world_bounds().grow(-52.0).has_point(point), "army slot is inside battlefield")
			rows[snappedf(point.dot(direction), 0.1)] = true
			columns[snappedf(point.dot(axis), 0.1)] = true
		_expect_equal(rows.size(), 2, "six units form two rows")
		_expect_equal(columns.size(), 3, "six units form three columns")
		for i in range(block.size()):
			for j in range(i):
				_expect_true(block[i].distance_to(block[j]) >= 45.9, "army slots do not overlap")
		for size in [6, 8, 9, 10]:
			var spawned := spawner.spawn_formation(GOBLIN_SCENE, size, direction, 30.0)
			_expect_equal(spawned.size(), size, "formation spawns the complete pack (%d)" % size)
			var flags := 0
			var positions: Array[Vector2] = []
			for enemy in spawned:
				if enemy.get("is_flag_bearer"):
					flags += 1
				var offset := enemy.global_position - ship_center
				_expect_true(offset.dot(direction) > 150.0, "pack (%d) comes from %s" % [size, direction])
				for used in positions:
					_expect_true(enemy.global_position.distance_to(used) >= 29.0, "formation keeps spacing (no overlap)")
				positions.append(enemy.global_position)
			_expect_equal(flags, 1, "exactly one flag bearer in a %d pack" % size)
			# Neat block: every unit sits on the spacing grid around the block centre.
			var side := Vector2(-direction.y, direction.x)
			var lateral_values := {}
			for position in positions:
				lateral_values[snappedf((position - positions[0]).dot(side), 1.0)] = true
			_expect_true(lateral_values.size() <= 5, "units line up in columns")
			for enemy in spawned:
				enemy.queue_free()
	var nine := SpawnFormation.get_rows(9)
	_expect_equal(Array(nine), ["GGG", "GFG", "GGG"], "9-unit preset matches the design")
	battle.queue_free()
	await get_tree().process_frame


func _test_runtime_directional_positions() -> void:
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("WaveManager") as WaveManager
	manager.auto_start = false
	add_child(battle)
	await get_tree().process_frame
	var spawner := battle.get_node("EnemySpawner") as EnemySpawner
	var ship := battle.get_node("Ship") as Ship
	var battlefield := battle.get_node("Battlefield") as Battlefield
	var ship_center := ship.to_global(Ship.SHIP_SIZE * 0.5)
	var chariot_bounds := battlefield.get_world_bounds().grow(-132.0)

	for direction in [Vector2.LEFT, Vector2.RIGHT]:
		var chariot := spawner.spawn_enemy(
			CHARIOT_SCENE,
			WaveDefinition.SpawnPattern.RANDOM,
			0,
			direction
		)
		_expect_true(chariot != null, "Chariot spawns from %s" % direction)
		if chariot != null:
			_expect_true((chariot.global_position - ship_center).dot(direction) > 0.0, "Chariot is on requested side %s" % direction)
			_expect_true(chariot_bounds.has_point(chariot.global_position), "Chariot collision body stays inside battlefield")
			chariot.queue_free()

	# Ordinary single-direction requests use distinct lanes along the edge.
	var lateral_positions: Array[float] = []
	for sequence in range(8):
		var goblin := spawner.spawn_enemy(
			GOBLIN_SCENE,
			WaveDefinition.SpawnPattern.RANDOM,
			sequence,
			Vector2.UP
		)
		_expect_true(goblin != null, "directional Goblin spawns")
		if goblin != null:
			_expect_true((goblin.global_position - ship_center).dot(Vector2.UP) > 0.0, "directional Goblin stays on selected edge")
			for used_x in lateral_positions:
				_expect_true(not is_equal_approx(used_x, goblin.global_position.x), "directional Goblins do not stack at one coordinate")
			lateral_positions.append(goblin.global_position.x)
			goblin.queue_free()
	battle.queue_free()
	await get_tree().process_frame


func _test_army_batch_runtime() -> void:
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("WaveManager") as WaveManager
	manager.auto_start = false
	manager.wave_config = VERDANT_CONFIG.duplicate(true)
	manager.wave_config.special_spawn_rules.clear()
	add_child(battle)
	await get_tree().process_frame
	manager.start_wave_system()
	manager.set_process(false)
	manager._current_wave_index = 2
	manager._begin_wave()
	var wave := manager.wave_config.waves[2]
	manager._update_spawning(0.01)
	var enemies := battle.get_node("Enemies").get_children()
	_expect_equal(enemies.size(), wave.get_spawn_batch_size(), "directional wave spawns one scheduled batch")
	for enemy in enemies:
		_expect_true(enemy.has_meta("formation_spawn_side"), "batch enemy marches as a formation")
		var side: Vector2 = enemy.get_meta("formation_spawn_side")
		var before: Vector2 = enemy.global_position
		enemy._physics_process(0.1)
		var movement: Vector2 = enemy.global_position - before
		_expect_true(movement.dot(-side) > 0.0 and absf(movement.cross(side)) < 0.01, "formation advances parallel toward ship")
	manager._update_spawning(0.1)
	_expect_equal(battle.get_node("Enemies").get_child_count(), enemies.size(), "next batch waits for the original interval")
	battle.queue_free()
	await get_tree().process_frame


func _test_pending_boss_transition() -> void:
	var boss_wave := VERDANT_CONFIG.waves[8].duplicate(true) as WaveDefinition
	# Keep the production quota and behavior, but shorten only this integration
	# test's interval so the complete Wave 11 queue executes quickly.
	boss_wave.spawn_interval = 0.05
	var config := PlanetWaveConfig.new()
	config.planet_id = &"verdant_boss_test"
	config.display_name = "Verdant Boss Test"
	config.waves = [boss_wave]
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("WaveManager") as WaveManager
	manager.auto_start = false
	manager.wave_config = config
	add_child(battle)
	await get_tree().process_frame
	_expect_true(manager.start_wave_system(), "boss wave test starts")
	var found := func() -> bool:
		for child in battle.get_node("Enemies").get_children():
			if child is GoblinGiantChariot:
				return true
		return false
	_expect_true(await _wait_until(found, 240), "wave 11 spawns the Goblin Giant Chariot")
	_expect_true(await _wait_until(func() -> bool: return manager.get_scheduled_spawned_count() == 11, 240), "wave 11 executes its complete fixed quota")
	var regular_goblins := 0
	for child in battle.get_node("Enemies").get_children():
		if child is Goblin:
			regular_goblins += 1
	_expect_equal(regular_goblins, 10, "wave 11 runtime spawns ten regular Goblin escorts")
	_expect_equal(manager.get_current_wave_number(), 9, "boss wave number")
	_expect_false(manager.is_configuration_blocked(), "boss wave is not blocked any more")
	battle.queue_free()
	await get_tree().process_frame


func _entry_count(wave: WaveDefinition, enemy_id: StringName) -> int:
	for entry in wave.enemy_entries:
		if entry != null and entry.enemy_id == enemy_id:
			return entry.spawn_count
	return -1


func _wait_until(condition: Callable, maximum_frames: int = 180) -> bool:
	for _frame in range(maximum_frames):
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()


func _finish() -> void:
	if _failures.is_empty():
		print("VERDANT_WAVE_SYSTEM_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("VERDANT_WAVE_SYSTEM_TEST: " + failure)
		print("VERDANT_WAVE_SYSTEM_TEST: FAIL (%d failures)" % _failures.size())
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
