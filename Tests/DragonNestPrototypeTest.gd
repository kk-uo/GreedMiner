extends Node

var failures: Array[String] = []


func _ready() -> void:
	ResourceManager.start_new_mission()
	await get_tree().process_frame
	_test_rules_and_waves()
	_test_enemy_stats()
	await _test_guardian_and_hoard()
	await _test_boss_segments_and_qtes()
	if failures.is_empty():
		print("DRAGON_NEST_PROTOTYPE_TEST: PASS")
		get_tree().quit(0)
	else:
		for message in failures:
			push_error("DRAGON_NEST_PROTOTYPE_TEST: " + message)
		print("DRAGON_NEST_PROTOTYPE_TEST: FAIL (%d)" % failures.size())
		get_tree().quit(1)


func _test_rules_and_waves() -> void:
	check(DragonNestRules.scheduled_total() == 154, "rule quota total is 154 (Claude sync 94: denser fodder)")
	check(DragonNestRules.treasure_reward_total() == 2500, "treasure reward total is 2500")
	check(DragonNestRules.HOARDS.size() == 3, "three hoards configured")
	check(is_equal_approx(DragonNestRules.attack_interval_multiplier(15), 0.8), "wrath cooldown is 20% total reduction")
	var config := load("res://Resources/Waves/DragonNestPlanetWaves.tres") as PlanetWaveConfig
	check(config != null, "wave resource loads")
	if config == null:
		return
	check(config.get_validation_errors().is_empty(), "wave resource validates: %s" % [config.get_validation_errors()])
	check(config.waves.size() == 11, "wave resource has 11 waves")
	var totals := {&"kobold": 0, &"nest_lizard": 0, &"young_dragon": 0, &"greater_dragon": 0}
	var scheduled := 0
	for index in range(10):
		for entry in config.waves[index].enemy_entries:
			totals[entry.enemy_id] = int(totals.get(entry.enemy_id, 0)) + entry.spawn_count
			scheduled += entry.spawn_count
	check(scheduled == 154, "waves 1-10 schedule exactly 154 enemies")
	check(totals == {&"kobold": 97, &"nest_lizard": 46, &"young_dragon": 5, &"greater_dragon": 6}, "per-type quotas are exact: %s" % totals)
	var boss_entries := config.waves[10].enemy_entries
	check(boss_entries.size() == 1 and boss_entries[0].enemy_id == &"ancient_dragon" and boss_entries[0].spawn_count == 1 and boss_entries[0].is_boss, "wave 11 contains one tracked Ancient Dragon")


func _test_enemy_stats() -> void:
	_test_enemy(&"kobold", 120.0, 65.0, 5.0, 1.0, 10.0, BasicEnemy.AttackType.MELEE, BasicEnemy.MovementType.WALK, BasicEnemy.EnemyTier.COMMON)
	_test_enemy(&"nest_lizard", 400.0, 45.0, 8.0, 1.0, 10.0, BasicEnemy.AttackType.MELEE, BasicEnemy.MovementType.WALK, BasicEnemy.EnemyTier.COMMON)
	_test_enemy(&"young_dragon", 7500.0, 50.0, 20.0, 2.0, 220.0, BasicEnemy.AttackType.RANGED, BasicEnemy.MovementType.FLYING, BasicEnemy.EnemyTier.LARGE)
	_test_enemy(&"greater_dragon", 15000.0, 35.0, 35.0, 3.0, 260.0, BasicEnemy.AttackType.RANGED, BasicEnemy.MovementType.FLYING, BasicEnemy.EnemyTier.LARGE)
	_test_enemy(&"ancient_dragon", 150000.0, 12.0, 20.0, 3.0, 200.0, BasicEnemy.AttackType.RANGED, BasicEnemy.MovementType.FLYING, BasicEnemy.EnemyTier.BOSS)


func _test_enemy(id: StringName, hp: float, speed: float, damage: float, interval: float, range_value: float, type: int, movement: int, tier: int) -> void:
	var enemy := EnemyCatalog.instantiate_enemy(id)
	check(enemy != null, "%s scene instantiates" % id)
	if enemy == null:
		return
	check(is_equal_approx(enemy.max_health, hp), "%s HP" % id)
	check(is_equal_approx(enemy.move_speed, speed), "%s speed" % id)
	check(is_equal_approx(enemy.attack_damage, damage), "%s damage" % id)
	check(is_equal_approx(enemy.attack_interval, interval), "%s interval" % id)
	check(is_equal_approx(enemy.attack_range, range_value), "%s range" % id)
	check(enemy.attack_type == type and enemy.movement_type == movement and enemy.enemy_tier == tier, "%s attack, movement, and tier types" % id)
	if enemy is RangedEnemy:
		check((enemy as RangedEnemy).projectile_scene != null, "%s has hostile projectile" % id)
	enemy.free()


func _test_guardian_and_hoard() -> void:
	var guardian := EnemyCatalog.instantiate_enemy(&"young_dragon") as DragonEnemy
	guardian.guardian_mode = true
	add_child(guardian)
	await get_tree().process_frame
	check(guardian.guardian_state == DragonEnemy.GuardianState.SLEEPING, "guardian starts sleeping")
	check(is_equal_approx(guardian.damage_reduction, 0.5), "guardian has 50 percent damage reduction")
	check(not guardian.is_in_group("enemies") and guardian.collision_layer == 0, "sleeping guardian cannot be targeted or hit")
	var sleeping_health := guardian.get_current_health()
	guardian.take_damage(100.0)
	check(guardian.guardian_state == DragonEnemy.GuardianState.SLEEPING and is_equal_approx(guardian.get_current_health(), sleeping_health), "attacking sleeping guardian neither damages nor wakes it")
	check(guardian.wake_guardian(), "treasure excavation wakes sleeping guardian")
	check(guardian.guardian_state == DragonEnemy.GuardianState.AWAKENING and guardian.is_in_group("enemies") and guardian.collision_layer != 0, "waking guardian becomes a weapon target")
	var awake_health := guardian.get_current_health()
	guardian.take_damage(100.0)
	check(is_equal_approx(awake_health - guardian.get_current_health(), 50.0), "awake guardian applies 50 percent damage reduction")
	guardian.apply_greed(15)
	guardian.enrage_guardian()
	var interval := guardian.attack_interval
	guardian.apply_greed(15)
	guardian.enrage_guardian()
	check(is_equal_approx(interval, 2.0 * 0.8 * 0.8) and is_equal_approx(guardian.attack_interval, interval), "guardian greed/enrage modifiers do not stack")
	guardian.queue_free()

	var hoard := DragonHoard.new()
	hoard.reward_per_success = 100
	add_child(hoard)
	var reward := [0]
	hoard.steal_succeeded.connect(func(_h: DragonHoard, amount: int) -> void: reward[0] += amount)
	check(hoard.begin_attempt(), "treasure attempt starts")
	check(not hoard.begin_attempt(), "duplicate treasure attempt is blocked")
	for _click in range(hoard.required_clicks):
		hoard.route_click(hoard.global_position + DragonHoard.TARGET_OFFSETS[hoard._target_index])
	check(hoard.successful_steals == 1 and reward[0] == 100, "successful QTE grants exactly one reward")
	check(not hoard.attempt_active, "treasure QTE cleans up after success")
	for _steal in range(4):
		check(hoard.begin_attempt(), "next treasure attempt starts")
		for _click in range(hoard.required_clicks):
			hoard.route_click(hoard.global_position + DragonHoard.TARGET_OFFSETS[hoard._target_index])
	check(hoard.is_depleted() and hoard.successful_steals == 5 and reward[0] == 500, "hoard depletes after five successes without duplicate rewards")
	check(not hoard.begin_attempt(), "depleted hoard cannot restart")
	hoard.queue_free()
	await get_tree().process_frame


func _test_boss_segments_and_qtes() -> void:
	var boss := EnemyCatalog.instantiate_enemy(&"ancient_dragon") as AncientDragon
	add_child(boss)
	await get_tree().process_frame
	check(boss.current_segment == 10 and is_equal_approx(boss.get_current_health(), 150000.0), "boss starts with ten real 15000 HP segments")
	boss.take_damage(30000.0)
	check(boss.current_segment == 9 and boss.segments_broken == 1, "one high-damage hit breaks only one segment")
	check(is_equal_approx(boss.get_current_health(), 135000.0), "damage cannot spill into locked segment")
	var locked_hp := boss.get_current_health()
	boss.take_damage(1000.0)
	check(is_equal_approx(boss.get_current_health(), locked_hp), "airborne/takeoff damage is rejected")
	boss._begin_dive_qte()
	boss.force_resolve_dive_for_testing(true)
	check(boss.boss_state == AncientDragon.BossState.GROUND_COMBAT, "successful dive unlocks next segment")

	check(boss.force_dive_qte(), "developer dive trigger uses active boss state")
	for part in AncientDragon.DIVE_PARTS:
		for _click in range(boss.clicks_per_part):
			var world := boss.to_global(boss.get_qte_part_local_position(part))
			check(boss.route_qte_click(world), "dive zone consumes its click")
	check(boss.boss_state == AncientDragon.BossState.DIVE_RESOLUTION and boss.get_dive_click_total() == 6, "dive success requires six part-specific clicks")
	boss.force_resolve_dive_for_testing(true)

	check(boss.start_fire_breath(), "fire breath charge starts")
	boss.take_damage(3000.0)
	check(boss.boss_state == AncientDragon.BossState.RECOVERY and boss.fire_breaths_interrupted == 1 and is_zero_approx(boss.fire_breath_damage_taken), "3000 actual damage interrupts breath without ship damage")
	boss._enter_ground_combat()
	check(boss.start_fire_breath(), "second fire breath starts")
	var head := boss.to_global(boss.get_qte_part_local_position(AncientDragon.DivePart.HEAD))
	for _click in range(boss.fire_breath_interrupt_clicks):
		boss.route_qte_click(head)
	check(boss.boss_state == AncientDragon.BossState.RECOVERY and boss.fire_breaths_interrupted == 2, "eight head clicks interrupt breath")
	boss._enter_ground_combat()
	boss._fire_cooldown_left = 0.01
	boss._physics_process(0.02)
	check(boss.boss_state == AncientDragon.BossState.FIRE_BREATH_CHARGE, "Fire Breath activates when its cooldown expires")
	var breath_resolution := [false, 0.0]
	boss.fire_breath_resolved.connect(func(interrupted: bool, damage: float) -> void:
		breath_resolution[0] = interrupted
		breath_resolution[1] = damage)
	boss._resolve_fire_breath(false)
	check(not bool(breath_resolution[0]) and is_equal_approx(float(breath_resolution[1]), 40.0) and boss.boss_state == AncientDragon.BossState.RECOVERY, "failed Fire Breath interruption resolves exactly one 40-base-damage event")

	check(DragonNestRules.summon_profile(0) == {"requested": 1, "cap": 1}, "calm summon profile")
	check(DragonNestRules.summon_profile(10) == {"requested": 1, "cap": 2}, "furious summon profile")
	check(DragonNestRules.summon_profile(15) == {"requested": 2, "cap": 2}, "wrath summon profile")
	boss.queue_free()
	await get_tree().process_frame

	var full_boss := EnemyCatalog.instantiate_enemy(&"ancient_dragon") as AncientDragon
	full_boss.young_dragon_scene = null
	add_child(full_boss)
	await get_tree().process_frame
	for break_number in range(1, 10):
		full_boss.take_damage(50000.0)
		check(full_boss.segments_broken == break_number and full_boss.current_segment == 10 - break_number, "segment break %d triggers exactly one mandatory dive" % break_number)
		check(full_boss.boss_state == AncientDragon.BossState.TAKEOFF, "segment break %d enters takeoff" % break_number)
		full_boss._begin_dive_qte()
		full_boss.force_resolve_dive_for_testing(false)
		# Claude sync 90: half health starts phase two with a 3 s roar during
		# which the boss cannot be damaged.
		if break_number == AncientDragon.PHASE_TWO_BREAKS:
			check(full_boss.phase_two and full_boss.boss_state == AncientDragon.BossState.PHASE_TRANSITION, "segment break 5 starts phase two")
			check(not full_boss.is_damage_unlocked(), "the phase-two roar cannot be damaged")
			full_boss.skip_phase_transition()
		else:
			check(full_boss.phase_two == (break_number > AncientDragon.PHASE_TWO_BREAKS), "phase two only after half health (break %d)" % break_number)
	check(full_boss.dives_failed == 9 and full_boss.boss_state == AncientDragon.BossState.GROUND_COMBAT, "first nine segments produce nine resolving dives")
	check(is_zero_approx(full_boss.total_dive_damage_taken), "damage-taken metric records actual hull loss, not base damage without a ship")
	var ore_before := ResourceManager.mission_ore
	# Keep this headless unit test free of the presentation-only boss finisher;
	# reward and segmented death behavior remain the same.
	full_boss.enemy_tier = BasicEnemy.EnemyTier.LARGE
	full_boss.take_damage(50000.0)
	check(full_boss.boss_state == AncientDragon.BossState.DEAD and full_boss.segments_broken == 9, "tenth segment causes final death without a tenth dive")
	check(is_equal_approx(ResourceManager.mission_ore, ore_before + 4000.0), "final boss reward is granted once")
	full_boss.take_damage(50000.0)
	check(is_equal_approx(ResourceManager.mission_ore, ore_before + 4000.0), "repeated final damage cannot duplicate boss reward")
	await get_tree().process_frame


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
