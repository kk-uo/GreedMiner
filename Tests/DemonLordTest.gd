extends Node

## Runs against a throwaway save, never the player's real progression.
const TestSave := preload("res://Tests/TestSave.gd")

## Headless integration coverage for Demon Lord states, summons, QTE timing,
## spatial click priority, teleportation, laser damage and cleanup.

const BATTLE_SCENE: PackedScene = preload("res://Scenes/Battle/BattleMain.tscn")
const BOSS_SCENE: PackedScene = preload("res://Scenes/Enemies/demon_lord.tscn")
const MINING_SCENE: PackedScene = preload("res://Scenes/Modules/Mining/mining_module.tscn")
const VOLCANIC_CONFIG: PlanetWaveConfig = preload("res://Resources/Waves/VolcanicPlanetWaves.tres")

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("demon_lord_test")
	ShipLoadout.installed_modules.clear()
	await _test_stats_summons_and_abilities()
	await _test_spatial_priority_with_mining_qte()
	await _test_teleport_in_crowd()
	ShipLoadout.installed_modules.clear()
	_finish()


## A packed battlefield (late boss wave) must never cancel the half-health
## teleport: other enemies used to block every candidate spot.
func _test_teleport_in_crowd() -> void:
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("WaveManager") as WaveManager
	manager.auto_start = false
	var mining_manager := battle.get_node("MiningQteManager") as MiningQteManager
	mining_manager.auto_trigger = false
	add_child(battle)
	await get_tree().process_frame
	var ship := battle.get_node("Ship") as Ship
	var enemies := battle.get_node("Enemies")
	var battlefield := battle.get_node("Battlefield") as Battlefield
	var boss := BOSS_SCENE.instantiate() as DemonLord
	boss.target_ship = ship
	enemies.add_child(boss)
	var ship_center := ship.to_global(Ship.SHIP_SIZE * 0.5)
	boss.global_position = ship_center + Vector2(500.0, 80.0)
	boss.set_physics_process(false)
	var bounds := battlefield.get_world_bounds()
	var crowd := load("res://Scenes/Enemies/little_rock.tscn") as PackedScene
	var y := bounds.position.y + 30.0
	while y < bounds.end.y:
		var x := bounds.position.x + 30.0
		while x < bounds.end.x:
			var spot := Vector2(x, y)
			if spot.distance_to(boss.global_position) > 120.0 and ship.get_distance_to_hull(spot, 20.0) > 30.0:
				var rock := crowd.instantiate() as BasicEnemy
				enemies.add_child(rock)
				rock.global_position = spot
				rock.set_physics_process(false)
			x += 70.0
		y += 70.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	var old_offset := boss.global_position - ship_center
	boss.take_damage(3333.0, true)
	_expect_equal(boss.teleport_count, 1, "crowded field still teleports")
	_expect_true(old_offset.dot(boss.global_position - ship_center) < 0.0, "crowded teleport crosses to the opposite side")
	_expect_true(bounds.grow(-boss.get_collision_radius()).has_point(boss.global_position), "crowded teleport stays inside map")
	battle.queue_free()
	await get_tree().process_frame


func _test_stats_summons_and_abilities() -> void:
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("WaveManager") as WaveManager
	manager.auto_start = false
	var mining_manager := battle.get_node("MiningQteManager") as MiningQteManager
	mining_manager.auto_trigger = false
	add_child(battle)
	await get_tree().process_frame
	var ship := battle.get_node("Ship") as Ship
	# A new ship only has 50 HP, exactly one 50-damage laser; give it enough
	# hull to survive every laser this test fires (heal cannot revive it).
	ship.max_hp = 1000.0
	ship.current_hp = 1000.0
	var enemies := battle.get_node("Enemies")
	var battlefield := battle.get_node("Battlefield") as Battlefield
	var boss := BOSS_SCENE.instantiate() as DemonLord
	boss.target_ship = ship
	enemies.add_child(boss)
	boss.global_position = ship.to_global(Ship.SHIP_SIZE * 0.5) + Vector2(500.0, 80.0)
	boss.set_physics_process(false)
	await get_tree().physics_frame

	_expect_equal(boss.enemy_id, &"demon_lord", "enemy ID")
	_expect_near(boss.max_health, 6666.0, "HP")
	_expect_near(boss.move_speed, 10.0, "move speed")
	_expect_near(boss.attack_damage, 20.0, "melee damage")
	_expect_near(boss.attack_interval, 1.0, "attack interval")
	_expect_near(boss.attack_range, 10.0, "attack range")
	_expect_near(boss.damage_reduction, 0.5, "base damage reduction is 0.5")
	_expect_equal(boss.attack_type, BasicEnemy.AttackType.MELEE, "melee attack type")
	_expect_equal(boss.enemy_tier, BasicEnemy.EnemyTier.BOSS, "boss tier")
	_expect_near(boss.reward_ore, 666.0, "boss reward")
	_expect_near(boss.normal_laser_interval, 30.0, "normal charge interval")
	_expect_near(boss.normal_charge_duration, 4.0, "normal charge duration")
	_expect_equal(boss.normal_required_clicks, 10, "normal click requirement")
	_expect_near(boss.special_charge_duration, 5.0, "special charge duration")
	_expect_equal(boss.special_clicks_per_part, 2, "special clicks per part")
	_expect_near(boss.recovery_duration, 2.0, "recovery duration")
	_expect_near(boss.laser_damage, 50.0, "laser damage")

	var wave11 := VOLCANIC_CONFIG.waves[10]
	_expect_equal(_entry_count(wave11, &"demon_lord"), 1, "Wave 11 schedules one Demon Lord")
	_expect_equal(_non_boss_count(wave11), 131, "Wave 11 keeps 131 scheduled non-boss enemies")
	_expect_equal(_campaign_non_boss_count(), 665, "Volcanic keeps 665 scheduled non-boss enemies")
	_expect_equal(_campaign_non_boss_count() + _boss_count(wave11), 666, "scheduled campaign total is 666")
	_expect_false(wave11.boss_summons_consume_wave_quota, "summons are explicitly outside fixed quota")

	var scheduled_before := manager.get_scheduled_spawn_count()
	boss.summoning_circle_delay = 0.01
	_expect_true(boss.force_start_summoning(), "summoning starts from NORMAL")
	boss._physics_process(0.02)
	await get_tree().physics_frame
	_expect_equal(boss.summons_created_count, 6, "exactly six Hellhunters are summoned")
	_expect_equal(boss.get_active_summon_count(), 6, "six summons remain active")
	_expect_equal(manager.get_scheduled_spawn_count(), scheduled_before, "summons consume no scheduled wave quota")
	var summoned: Array[BasicEnemy] = []
	for child in enemies.get_children():
		if child is BasicEnemy and child.get_meta("demon_lord_summon", false):
			summoned.append(child as BasicEnemy)
	_expect_equal(summoned.size(), 6, "all summons carry extra-enemy metadata")
	for first in range(summoned.size()):
		_expect_true(summoned[first] is Hellhunter, "summoned enemy reuses Hellhunter behavior")
		_expect_true(battlefield.get_world_bounds().has_point(summoned[first].global_position), "summon stays in map bounds")
		for second in range(first + 1, summoned.size()):
			_expect_true(summoned[first].global_position.distance_to(summoned[second].global_position) >= 25.0, "summoned collision bodies do not overlap")
	_expect_true(manager.get_alive_enemy_count() >= 7, "WaveManager tracks boss summons for wave clearing")

	boss.minimum_valid_click_interval = 0.0
	_expect_true(boss.start_normal_charge(), "normal charge starts")
	_expect_equal(boss.boss_state, DemonLord.BossState.NORMAL_CHARGING, "normal charging state")
	_expect_near(boss.get_qte_time_left(), 4.0, "normal QTE starts with four seconds")
	_expect_near(boss.damage_reduction, 1.0, "normal charge makes the boss invulnerable")
	_expect_true(boss.is_invulnerable(), "normal charge reports invulnerability")
	var hp_charging := boss.get_current_health()
	boss.take_damage(500.0)
	boss.take_damage(500.0, true)
	_expect_near(boss.get_current_health(), hp_charging, "no damage (even armour-piercing) while charging")
	for click in range(10):
		_expect_true(boss.route_qte_click(boss.global_position), "normal QTE reserves boss body click %d" % click)
	_expect_equal(boss.normal_click_count, 10, "ten valid clicks counted")
	_expect_equal(boss.boss_state, DemonLord.BossState.RECOVERY, "normal success enters recovery")
	_expect_near(boss.damage_reduction, 0.5, "normal success restores reduction")
	_expect_near(boss.get_qte_time_left(), 0.0, "completed QTE removes interaction timer")
	_expect_false(boss.route_qte_click(boss.global_position), "completed QTE removes reserved click region")
	boss._physics_process(2.01)
	_expect_equal(boss.boss_state, DemonLord.BossState.NORMAL, "recovery lasts two seconds")

	var hp_before := ship.current_hp
	_expect_true(boss.start_normal_charge(), "second normal charge starts")
	boss._physics_process(4.01)
	_expect_equal(boss.lasers_fired_count, 1, "failed normal QTE fires one laser")
	_expect_near(ship.current_hp, hp_before - 50.0, "failed normal QTE deals exactly 50 ship damage")
	_expect_equal(boss.boss_state, DemonLord.BossState.FIRING_LASER, "failure enters laser state")
	_expect_near(boss.damage_reduction, 0.5, "failed QTE restores reduction")
	_expect_false(boss.route_qte_click(boss.global_position), "timeout immediately removes QTE click region")
	boss._physics_process(boss.laser_visual_duration + 0.01)
	_expect_equal(boss.boss_state, DemonLord.BossState.RECOVERY, "laser enters recovery")
	ship.heal(1000.0)
	boss._physics_process(2.01)

	boss.set("_normal_laser_cooldown_left", 0.01)
	boss._physics_process(0.02)
	_expect_equal(boss.boss_state, DemonLord.BossState.NORMAL_CHARGING, "configured interval triggers normal charge")
	boss._physics_process(4.01)
	boss._physics_process(boss.laser_visual_duration + 0.01)
	boss._physics_process(2.01)
	ship.heal(1000.0)

	var ship_center := ship.to_global(Ship.SHIP_SIZE * 0.5)
	var old_position := boss.global_position
	var old_offset := old_position - ship_center
	boss.take_damage(3333.0, true)
	_expect_equal(boss.teleport_count, 1, "half-health teleport triggers once")
	var new_offset := boss.global_position - ship_center
	_expect_true(old_offset.dot(new_offset) < 0.0, "teleport crosses to opposite side of ship")
	_expect_true(battlefield.get_world_bounds().grow(-boss.get_collision_radius()).has_point(boss.global_position), "teleport destination is inside map")
	boss._physics_process(0.0)
	_expect_equal(boss.boss_state, DemonLord.BossState.SPECIAL_CHARGING, "teleport immediately starts special charge")
	_expect_near(boss.get_qte_time_left(), 5.0, "special QTE starts with five seconds")
	_expect_near(boss.damage_reduction, 1.0, "special charge makes the boss invulnerable")
	boss.take_damage(100.0)
	_expect_equal(boss.teleport_count, 1, "half-health phase never repeats")

	var total_before := boss.get_special_total_clicks()
	_expect_true(boss.route_qte_click(boss.global_position), "wrong body location remains reserved")
	_expect_equal(boss.get_special_total_clicks(), total_before, "wrong body location advances no part")
	var head_world := boss.get_body_part_world_position(DemonLord.BodyPart.HEAD)
	for click in range(4):
		boss.route_qte_click(head_world)
	_expect_equal(int(boss.special_part_clicks[DemonLord.BodyPart.HEAD]), 2, "completed head cannot receive extra progress")
	_expect_equal(boss.get_special_total_clicks(), 2, "extra head click does not advance another part")
	for part in DemonLord.BODY_PARTS:
		if part == DemonLord.BodyPart.HEAD:
			continue
		for click in range(2):
			boss.route_qte_click(boss.get_body_part_world_position(part))
	_expect_true(boss.is_special_qte_complete(), "all five independent body parts complete")
	_expect_equal(boss.get_special_total_clicks(), 10, "special QTE requires ten valid clicks")
	_expect_equal(boss.boss_state, DemonLord.BossState.RECOVERY, "special success enters recovery")
	_expect_near(boss.damage_reduction, 0.5, "special success restores reduction")
	boss._physics_process(2.01)
	ship.heal(1000.0)

	_expect_false(boss.start_special_charge(false), "special phase cannot repeat on the same boss")
	var failure_boss := BOSS_SCENE.instantiate() as DemonLord
	failure_boss.target_ship = ship
	enemies.add_child(failure_boss)
	failure_boss.global_position = ship_center + Vector2(-450.0, 60.0)
	failure_boss.set_physics_process(false)
	_expect_true(failure_boss.start_special_charge(false), "fresh boss special failure test starts")
	var lasers_before := failure_boss.lasers_fired_count
	hp_before = ship.current_hp
	failure_boss._physics_process(5.01)
	_expect_equal(failure_boss.lasers_fired_count, lasers_before + 1, "failed special QTE fires one laser")
	_expect_near(ship.current_hp, hp_before - 50.0, "failed special QTE deals exactly 50 ship damage")
	failure_boss._physics_process(failure_boss.laser_visual_duration + 0.01)
	_expect_equal(failure_boss.boss_state, DemonLord.BossState.RECOVERY, "special failure enters recovery")
	failure_boss._physics_process(2.01)
	failure_boss.queue_free()

	# Boss death removes regions immediately and grants its reward once.
	_expect_true(boss.start_normal_charge(), "death cleanup starts from an active QTE")
	var ore_before := ResourceManager.mission_ore
	boss.take_damage(100000.0, true)
	_expect_equal(boss.boss_state, DemonLord.BossState.NORMAL_CHARGING, "lethal hit is blocked while charging (invulnerable)")
	boss._die()
	_expect_equal(boss.boss_state, DemonLord.BossState.DEAD, "death cancels QTE state")
	_expect_false(boss.is_in_group("boss_qte_targets"), "death removes priority router registration")
	_expect_near(ResourceManager.mission_ore, ore_before + 666.0, "boss reward is granted exactly once")
	boss.take_damage(100000.0, true)
	_expect_near(ResourceManager.mission_ore, ore_before + 666.0, "duplicate damage cannot grant reward twice")

	battle.queue_free()
	await get_tree().process_frame


func _test_spatial_priority_with_mining_qte() -> void:
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("WaveManager") as WaveManager
	manager.auto_start = false
	var mining_manager := battle.get_node("MiningQteManager") as MiningQteManager
	mining_manager.auto_trigger = false
	add_child(battle)
	await get_tree().process_frame
	var ship := battle.get_node("Ship") as Ship
	var mining := MINING_SCENE.instantiate() as MiningModule
	ship.installed_modules.add_child(mining)
	mining.position = ship.get_cell_center(0, 0)
	mining.set_mining_enabled(true)
	await get_tree().process_frame
	var event := mining_manager.try_start_event(MiningQteEvent.TYPE_ORE_BURST, mining) as OreBurstEvent
	_expect_true(event != null, "mining QTE can start alongside boss system")
	if event == null:
		battle.queue_free()
		await get_tree().process_frame
		return
	event.activate()

	var boss := BOSS_SCENE.instantiate() as DemonLord
	boss.target_ship = ship
	battle.get_node("Enemies").add_child(boss)
	boss.set_physics_process(false)
	boss.minimum_valid_click_interval = 0.0
	boss.global_position = mining.global_position
	_expect_true(boss.start_normal_charge(), "Boss QTE active during mining QTE")
	ship.world_camera.zoom = Vector2(1.5, 1.5)
	await _click_world(battle, mining.global_position)
	_expect_equal(boss.normal_click_count, 1, "Boss region receives overlapping click first")
	_expect_equal(event.valid_clicks, 0, "overlapping click never double-activates mining QTE")

	boss.global_position += Vector2(220.0, 0.0)
	await _click_world(battle, mining.global_position)
	_expect_equal(boss.normal_click_count, 1, "outside click does not reach Boss QTE")
	_expect_equal(event.valid_clicks, 1, "mining QTE remains usable outside Boss region")
	_expect_true(mining_manager.is_event_active(), "mining QTE remains active during Boss charge")
	_expect_false(get_tree().paused, "Boss QTE does not pause simulation")
	_expect_near(Engine.time_scale, 1.0, "Boss QTE does not alter time scale")
	_expect_true(ship.are_weapon_attacks_enabled(), "weapons remain enabled during Boss QTE")

	boss._physics_process(4.01)
	_expect_false(boss.is_boss_qte_active(), "timeout clears priority region")
	battle.queue_free()
	await get_tree().process_frame


func _click_world(battle: Node2D, world_point: Vector2) -> void:
	var screen := battle.get_global_transform_with_canvas() * battle.to_local(world_point)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	press.global_position = screen
	get_viewport().push_input(press, true)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	get_viewport().push_input(release, true)
	await get_tree().process_frame


func _entry_count(wave: WaveDefinition, enemy_id: StringName) -> int:
	for entry in wave.enemy_entries:
		if entry != null and entry.enemy_id == enemy_id:
			return entry.spawn_count
	return 0


func _non_boss_count(wave: WaveDefinition) -> int:
	var total := 0
	for entry in wave.enemy_entries:
		if entry != null and not entry.is_boss:
			total += entry.spawn_count
	return total


func _boss_count(wave: WaveDefinition) -> int:
	var total := 0
	for entry in wave.enemy_entries:
		if entry != null and entry.is_boss:
			total += entry.spawn_count
	return total


func _campaign_non_boss_count() -> int:
	var total := 0
	for wave in VOLCANIC_CONFIG.waves:
		total += _non_boss_count(wave)
	return total


func _finish() -> void:
	if _failures.is_empty():
		print("DEMON_LORD_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("DEMON_LORD_TEST: " + failure)
		print("DEMON_LORD_TEST: FAIL (%d failures)" % _failures.size())
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

