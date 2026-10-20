extends Node

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL " + message)
	else:
		print("PASS " + message)

func _ready() -> void:
	var cfg := load("res://Resources/Waves/FrozenPlanetWaves.tres") as PlanetWaveConfig
	check(cfg != null and cfg.get_total_waves() == 10 and cfg.get_validation_errors().is_empty(), "valid ten-wave config")
	if cfg == null:
		get_tree().quit(1)
		return
	var expected := [[10,2,0,0],[14,4,0,0],[14,6,1,0],[16,7,2,0],[17,7,2,1],[18,8,2,2],[20,8,3,2],[22,9,3,2],[23,9,4,2],[12,5,2,1]]
	var ids := [&"snow_monster", &"big_snow_monster", &"sled_car_snow_monster", &"snow_monster_wizard"]
	var packs := {2:[0.4,6],4:[0.4,8],6:[0.5,8],8:[0.35,10],9:[0.3,10]}
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var total := 0
	var totals := [0, 0, 0, 0]
	for index in range(10):
		var wave := cfg.waves[index]
		var plan := WaveSpawnPlanner.build_plan(wave, cfg.special_spawn_rules, rng)
		check(plan.validation_errors.is_empty(), "wave %d plan" % (index + 1))
		check(plan.total_spawn_budget == wave.get_total_spawn_budget(), "wave %d budget follows quota" % (index + 1))
		for k in range(4):
			check(plan.get_planned_count(ids[k]) == expected[index][k], "wave %d %s" % [index+1, ids[k]])
			total += plan.get_planned_count(ids[k])
			totals[k] += plan.get_planned_count(ids[k])
		var wave_number := index + 1
		check(plan.get_planned_count(&"mega_monster") == (1 if wave_number == 10 else 0), "wave %d boss quota" % wave_number)
		if packs.has(wave_number):
			check(plan.timed_requests.size() == 1 and plan.timed_requests[0].spawn_count == packs[wave_number][1] and is_equal_approx(plan.timed_requests[0].trigger_phase_fraction, packs[wave_number][0]) and not plan.timed_requests[0].with_flag_bearer, "wave %d fixed pack" % wave_number)
		else:
			check(plan.timed_requests.is_empty(), "wave %d no extra pack" % wave_number)
	check(totals == [166, 65, 19, 10], "per-type totals match V3")
	check(total == 260, "total 260 regular enemies")
	check(total + totals[2] * 4 + 1 == 337, "maximum total includes sled children and boss")
	# The player's saved loadout may already fill every allowed mining slot.
	# Use a temporary minimal layout so this test is independent of progression.
	var saved_loadout := ShipLoadout.installed_modules.duplicate(true)
	ShipLoadout.installed_modules.clear()
	ShipLoadout.install_module(1, 1, "res://Scenes/Modules/Energy/energy_module.tscn")
	var ship := preload("res://Scenes/Ship/ship.tscn").instantiate() as Ship
	add_child(ship)
	await get_tree().process_frame
	var mining_scene := load("res://Scenes/Modules/Mining/mining_module.tscn") as PackedScene
	check(ship.install_module(mining_scene, Ship.ModuleType.Mining, 0, 0), "install mining module")
	var drill := ship._module_instances.get(Vector2i(0, 0)) as MiningModule
	check(drill != null and drill.mining_enabled, "mining initially active")
	ship.set_combat_frozen(true)
	check(drill != null and not drill.can_process() and not ship._all_modules_active, "freeze suspends module processing")
	ship.set_combat_frozen(false)
	check(drill != null and drill.can_process() and drill.mining_enabled and ship._all_modules_active, "freeze restores module state")
	ShipLoadout.installed_modules = saved_loadout
	var battle := preload("res://Scenes/Battle/BattleMain.tscn").instantiate()
	var manager := battle.get_node("WaveManager") as WaveManager
	manager.auto_start = false
	manager.wave_config = cfg
	add_child(battle)
	await get_tree().process_frame
	check(manager.start_wave_system(), "battle accepts Frozen config")
	manager.set_process(false)
	manager._current_wave_index = 1
	manager._begin_wave()
	manager._update_spawning(7.9)
	check(manager.get_executed_special_events().is_empty(), "wave 2 pack not early")
	manager._update_spawning(0.11)
	check(manager.get_executed_special_events().size() == 1 and manager.get_executed_special_events()[0].event_id == &"frozen_w2_snow_pack", "wave 2 pack fires at 40 percent")
	for index in range(10):
		manager._update_spawning(2.0)
	check(manager.get_executed_special_events().size() == 1, "fixed pack fires exactly once")
	manager.stop_wave_system(&"test")
	var enemies := battle.get_node("Enemies")
	for enemy in enemies.get_children():
		enemy.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	manager._current_wave_index = 9
	manager._state = WaveManager.State.CLEARING
	manager._scheduled_spawn_count = 0
	manager._scheduled_spawned_count = 0
	var big := EnemyCatalog.instantiate_enemy(&"big_snow_monster") as FrozenEnemy
	enemies.add_child(big)
	big.set_physics_process(false)
	var sled := EnemyCatalog.instantiate_enemy(&"sled_car_snow_monster") as FrozenEnemy
	enemies.add_child(sled)
	sled.set_physics_process(false)
	var boss := EnemyCatalog.instantiate_enemy(&"mega_monster") as FrozenEnemy
	enemies.add_child(boss)
	boss.set_physics_process(false)
	sled._die()
	sled._die()
	await get_tree().process_frame
	await get_tree().process_frame
	var children := []
	for enemy in enemies.get_children():
		if enemy is BasicEnemy and enemy.enemy_id == &"snow_monster":
			children.append(enemy)
	check(children.size() == 4 and boss._cry_time < 0.0 and not manager.is_completed(), "split children block clear and enrage; no duplicate split")
	for enemy in children:
		enemy.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(boss._cry_time < 0.0 and big._cry_time < 0.0, "boss does not cry while other enemies remain")
	big.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(boss._cry_time >= 0.0 and not manager.is_completed(), "final enrage starts when only the boss is left")
	for planet in ["Rocky", "Verdant", "Volcanic"]:
		var other := load("res://Resources/Waves/%sPlanetWaves.tres" % planet) as PlanetWaveConfig
		check(other != null and other.get_validation_errors().is_empty(), "%s config remains valid" % planet)
	print("Frozen wave tests: %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)
