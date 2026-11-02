extends Node

var failures: Array[String] = []


func _ready() -> void:
	ResourceManager.start_new_mission()
	ResourceManager.set_current_expedition_planet(DragonNestRules.PLANET_ID)
	var scene := load("res://Scenes/Battle/BattleMain.tscn") as PackedScene
	var battle := scene.instantiate()
	add_child(battle)
	for _frame in range(4):
		await get_tree().process_frame

	var field := battle.get_node("Battlefield") as Battlefield
	var waves := battle.get_node("WaveManager") as WaveManager
	var enemies := battle.get_node("Enemies") as Node2D
	var controller := battle.get_node_or_null("DragonNestController") as DragonNestController
	check(field.planet_theme == DragonNestRules.THEME_ID, "BattleMain applies Dragon Nest theme")
	check(field.get_map_seed() == DragonNestRules.MAP_SEED, "fixed map uses deterministic seed")
	check(waves.wave_config.planet_id == DragonNestRules.PLANET_ID, "BattleMain applies Dragon Nest waves")
	check(controller != null, "Dragon Nest controller is attached")
	if controller != null:
		check(controller.hoards.size() == 3, "runtime creates three hoards")
		check(controller.guardians.size() == 3, "runtime creates three guardians")
		check(controller.get_live_guardian_count() == 3, "all guardians begin alive")
		check(enemies.get_child_count() == 0, "optional guardians are outside scheduled enemy container")
		check(controller.developer_jump_suppresses_progress(11) and not controller.developer_jump_suppresses_progress(1), "direct boss/wave skips suppress permanent completion but full Wave 1 runs do not")
		var ship_center := controller.ship.to_global(Ship.SHIP_SIZE * 0.5)
		for hoard in controller.hoards:
			check(hoard.global_position.distance_to(ship_center) < 550.0, "stationary ship can reach fixed hoard %s in the visible playtest layout" % hoard.hoard_id)
		var gates := controller.get_gate_positions()
		check(gates.size() == 2 and gates[0].x < ship_center.x - 700.0 and gates[1].x > ship_center.x + 700.0, "Ancient Dragon tunnels are in the left and right walls")
		check(controller.get_entrance_position() == gates[1], "Ancient Dragon first comes out of the right tunnel")
		for gate in gates:
			check(field.get_world_bounds().has_point(gate), "boss tunnel anchor is inside the world")
		for guardian in controller.guardians:
			var hoard := controller.hoards[controller.guardians.find(guardian)]
			check(guardian.global_position.distance_to(hoard.global_position + ship_center.direction_to(hoard.global_position) * DragonNestRules.throne_offset(hoard.pile_radius)) < 1.0, "guardian sleeps on the throne behind its hoard")
		var first := controller.hoards[0]
		var first_guardian := controller.get_guardian_for_hoard(first)
		check(is_equal_approx(first_guardian.damage_reduction, 0.5), "runtime guardian has 50 percent damage reduction")
		check(not first_guardian.is_in_group("enemies") and first_guardian.collision_layer == 0, "sleeping runtime guardian is not targetable")
		var sleeping_health := first_guardian.get_current_health()
		first_guardian.take_damage(100.0)
		check(first_guardian.guardian_state == DragonEnemy.GuardianState.SLEEPING and is_equal_approx(first_guardian.get_current_health(), sleeping_health), "weapon damage cannot wake or hurt sleeping runtime guardian")
		check(first.begin_attempt(), "runtime treasure attempt starts")
		check(first_guardian.guardian_state == DragonEnemy.GuardianState.AWAKENING and first_guardian.is_in_group("enemies"), "first excavation attempt wakes and activates linked guardian")
		first.cancel_attempt()
		check(is_zero_approx(ResourceManager.mission_ore) and controller.greed == 0, "failed attempt grants no Ore or Greed")

		var boss := controller.developer_spawn_enemy(&"ancient_dragon") as AncientDragon
		await get_tree().process_frame
		check(boss != null and controller.boss == boss, "developer boss spawn is tracked by controller")
		if boss != null:
			check(boss.lair_mode and boss.boss_state == AncientDragon.BossState.ENTRANCE, "boss plays its entrance in the tunnel")
			check(not boss.is_damage_unlocked(), "boss cannot be damaged during the entrance")
			check(boss.global_position.distance_to(controller.get_gate_positions()[1]) < 1.0, "boss is anchored in the right tunnel")
			boss.skip_entrance()
			check(boss.boss_state == AncientDragon.BossState.GROUND_COMBAT, "boss fights after landing")
			var anchor := boss.global_position
			for _i in range(30):
				boss._physics_process(0.1)
			check(boss.global_position.distance_to(anchor) < 1.0, "lair boss never walks out of its tunnel")
			var target := boss.get_target_point(ship_center)
			check(target.distance_to(ship_center) < 560.0, "weapons aim at the boss head/chest, within normal weapon reach")
			controller.set_greed(15)
			check(boss.greed == 15 and is_equal_approx(boss.attack_interval, 2.4), "live boss reads Greed changes")
			var summoned := boss.spawn_reinforcements()
			check(summoned == 2 and boss.get_active_summon_count() == 2, "wrath reinforcement event spawns up to cap")
			check(waves.get_spawn_accounting()["extra_boss_spawned"] == 2, "boss summons are tracked separately from scheduled quota")
			check(boss.spawn_reinforcements() == 0, "reinforcement cap rejects excess summons")
			boss.current_segment = 7
			check(boss._start_wingstorm(), "middle-stage Wingstorm can start")
			boss._resolve_wingstorm()
			check(not controller.ship.are_weapon_attacks_enabled(), "Wingstorm temporarily disrupts weapons")
			boss._update_weapon_disruption(boss.wingstorm_disruption_duration + 0.1)
			check(controller.ship.are_weapon_attacks_enabled(), "Wingstorm weapon disruption recovers")
			boss.current_segment = 4
			boss._enter_ground_combat()
			boss._summon_after_landing = true
			boss._finish_landing()
			check(boss.boss_state == AncientDragon.BossState.RELOCATE, "reinforcement break sends the boss to the other tunnel")
			for _i in range(80):
				boss._physics_process(0.1)
			check(boss.boss_state == AncientDragon.BossState.GROUND_COMBAT and boss.global_position.distance_to(controller.get_gate_positions()[0]) < 1.0, "boss lands in the left tunnel after relocating")
			# Claude sync 93: every tunnel change ends with a smoke breath that
			# blinds the turrets for 3 s: they keep firing but cannot hold a lock.
			check(boss.smoke_breaths == 1, "the tunnel change ends with a smoke breath")
			check(controller.ship.are_weapon_attacks_enabled(), "smoke no longer stops the ship's weapons")
			check(boss.is_ship_blinded(), "smoke blinds the ship's turrets")
			for weapon in controller.ship.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is WeaponModule):
				check((weapon as WeaponModule).target_lock_suppressed, "blinded turret cannot hold a target lock")
			boss._update_smoke_blind(AncientDragon.SMOKE_BLIND + 0.1)
			check(not boss.is_ship_blinded(), "turrets can lock again after the smoke")
			for weapon in controller.ship.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is WeaponModule):
				check(not (weapon as WeaponModule).target_lock_suppressed, "turret lock restored after the smoke")
			# Phase two at half health: unstolen eggs hatch, then fire wyrms.
			var hatch_before := enemies.get_children().filter(func(n: Node) -> bool: return n.has_meta("dragon_nest_hatchling")).size()
			boss.segments_broken = AncientDragon.PHASE_TWO_BREAKS
			boss._finish_landing()
			check(boss.phase_two and boss.boss_state == AncientDragon.BossState.PHASE_TRANSITION, "half health starts phase two")
			var hatched := enemies.get_children().filter(func(n: Node) -> bool: return n.has_meta("dragon_nest_hatchling")).size() - hatch_before
			check(hatched == 3, "every hoard egg left unstolen hatches into a dragon (%d)" % hatched)
			check(controller.hatch_remaining_eggs() == 0, "an egg hatches only once")
			boss.skip_phase_transition()
			check(boss._fire_cooldown_left <= AncientDragon.PHASE_TWO_FIRE_BREATH_COOLDOWN * DragonNestRules.attack_interval_multiplier(boss.greed) + 0.01, "phase two breathes fire more often")
			# Phase two: the smoke breath itself brings three fire wyrms.
			check(boss.start_fire_eyes(), "phase two can summon fire wyrms")
			check(boss.boss_state == AncientDragon.BossState.SMOKE_BREATH, "the wyrm summon is a smoke breath")
			for _i in range(20):
				boss._physics_process(0.1)
			var wyrms := enemies.get_children().filter(func(n: Node) -> bool: return n is BasicEnemy and (n as BasicEnemy).enemy_id == &"fire_wyrm").size()
			check(wyrms == AncientDragon.FIRE_WYRM_COUNT, "smoke breath summons three fire wyrms (%d)" % wyrms)
			check(boss.is_ship_blinded() and controller.ship.are_weapon_attacks_enabled(), "wyrms arrive while the turrets are blinded but still firing")
			# Probe: a blinded turret drops the boss for the nearest enemy.
			var probe := WeaponModule.new()
			probe.target_lock_suppressed = true
			add_child(probe)
			var nearest := probe.find_nearest_enemy_in_range(ship_center, 2000.0)
			check(probe.keep_or_find_target(boss, ship_center, 2000.0) == nearest and nearest != boss, "blinded turret re-picks the nearest enemy instead of keeping the boss")
			probe.target_lock_suppressed = false
			check(probe.keep_or_find_target(boss, ship_center, 2000.0) == boss, "unblinded turret keeps its boss lock")
			probe.free()
			# The pack never grows past FIRE_WYRM_MAX_ALIVE.
			boss.spawn_fire_wyrms()
			boss.spawn_fire_wyrms()
			wyrms = enemies.get_children().filter(func(n: Node) -> bool: return n is BasicEnemy and (n as BasicEnemy).enemy_id == &"fire_wyrm").size()
			check(wyrms == AncientDragon.FIRE_WYRM_MAX_ALIVE, "fire wyrm pack is capped (%d)" % wyrms)

	remove_child(battle)
	battle.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("DRAGON_NEST_BATTLE_RUNTIME_TEST: PASS")
		_finish.call_deferred(0)
	else:
		for message in failures:
			push_error("DRAGON_NEST_BATTLE_RUNTIME_TEST: " + message)
		print("DRAGON_NEST_BATTLE_RUNTIME_TEST: FAIL (%d)" % failures.size())
		_finish.call_deferred(1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish(exit_code: int) -> void:
	await get_tree().process_frame
	get_tree().quit(exit_code)
