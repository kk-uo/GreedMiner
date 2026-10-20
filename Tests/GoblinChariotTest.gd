extends Node

## Runs against a throwaway save, never the player's real progression.
const TestSave := preload("res://Tests/TestSave.gd")

## Goblin Giant Chariot: stats, throw cycle (count, landing ahead, root,
## stationary throw + pause, cooldown), berserk, death spawn and reward.

const BATTLE_SCENE: PackedScene = preload("res://Scenes/Battle/BattleMain.tscn")
const CHARIOT_SCENE: PackedScene = preload("res://Scenes/Enemies/goblin_giant_chariot.tscn")

var _failures: Array[String] = []
var battle: Node
var ship: Ship
var enemies: Node2D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("goblin_chariot_test")
	ShipLoadout.installed_modules.clear()
	ResourceManager.start_new_mission()
	battle = BATTLE_SCENE.instantiate()
	battle.get_node("WaveManager").auto_start = false
	var qte := battle.get_node_or_null("MiningQteManager")
	if qte != null:
		qte.set("auto_trigger", false)
	add_child(battle)
	await get_tree().process_frame
	ship = battle.get_node("Ship") as Ship
	enemies = battle.get_node("Enemies") as Node2D

	_test_defaults()
	await _test_targeting()
	await _test_close_throw()
	await _test_throw_cycle()
	await _test_berserk()
	await _test_death()

	battle.queue_free()
	ShipLoadout.installed_modules.clear()
	await get_tree().process_frame
	if _failures.is_empty():
		print("GOBLIN_CHARIOT_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("GOBLIN_CHARIOT_TEST: " + failure)
		print("GOBLIN_CHARIOT_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


## Turrets lock on as soon as the boars' snouts are in range (not the centre),
## and the hitbox covers the whole rig so shots at the snouts connect.
func _test_targeting() -> void:
	var chariot := _spawn(Vector2(900.0, 0.0))
	chariot.first_throw_delay = 999.0
	chariot._cooldown_left = 999.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	var forward := Vector2.RIGHT.rotated(chariot._facing)
	var turret := chariot.global_position + forward * (GoblinGiantChariot.FRONT_REACH + 150.0)
	var aim := chariot.get_target_point(turret)
	_expect_true(turret.distance_to(chariot.global_position) > 200.0, "centre is out of a 200 range")
	_expect_true(turret.distance_to(aim) < 200.0, "snouts are inside a 200 range (%.0f)" % turret.distance_to(aim))
	var gun := WeaponModule.new()
	enemies.add_child(gun)
	_expect_true(gun.find_nearest_enemy_in_range(turret, 200.0) == chariot, "turret acquires the chariot by its snouts")
	gun.queue_free()
	var query := PhysicsPointQueryParameters2D.new()
	query.position = aim
	query.collide_with_areas = true
	query.collision_mask = 0xFFFFFFFF
	var hit := false
	for result in chariot.get_world_2d().direct_space_state.intersect_point(query, 16):
		if result["collider"] == chariot:
			hit = true
	_expect_true(hit, "hitbox covers the boars' heads")
	chariot.queue_free()
	await get_tree().physics_frame


## Thrown from close range (just outside the berserk zone), the block lands
## between the chariot and the ship, never on/inside the hull, and walks on.
func _test_close_throw() -> void:
	var chariot := _spawn(Vector2(900.0, 0.0))
	chariot._cooldown_left = 999.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Move it so its front is 220 from the hull.
	var forward := Vector2.RIGHT.rotated(chariot._facing)
	chariot.global_position += forward * (chariot._distance_to_ship() - 220.0)
	_expect_true(absf(chariot._distance_to_ship() - 220.0) < 2.0, "chariot front placed 220 from the hull")
	await get_tree().physics_frame
	chariot.thrown_goblin_root_duration = 0.2
	chariot.throw_flight_time = 0.05
	var thrown: Array = []
	chariot.goblins_thrown.connect(func(list: Array[Goblin]) -> void: thrown.append_array(list))
	chariot._release_goblins()
	thrown.append_array(chariot.thrown_elites)
	_expect_equal(thrown.size(), 11, "close throw still throws 10 + 1")
	for unit in thrown:
		var enemy := unit as BasicEnemy
		var gap: float = enemy.global_position.distance_to(enemy._get_nearest_ship_boundary_world(ship, enemy.global_position))
		_expect_true(not Geometry2D.is_point_in_polygon(ship.to_local(enemy.global_position), PackedVector2Array([Vector2.ZERO, Vector2(Ship.SHIP_SIZE.x, 0.0), Ship.SHIP_SIZE, Vector2(0.0, Ship.SHIP_SIZE.y)])), "close-thrown unit is not inside the ship")
		_expect_true(gap > 20.0, "close-thrown unit lands clear of the hull (%.0f)" % gap)
	var watch := thrown[0] as BasicEnemy
	var start := watch.global_position
	await get_tree().create_timer(0.8).timeout
	_expect_true(is_instance_valid(watch) and watch.global_position.distance_to(start) > 5.0, "close-thrown goblin walks after its root")
	for unit in thrown:
		if is_instance_valid(unit):
			unit.queue_free()
	chariot.queue_free()
	await get_tree().physics_frame


func _spawn(offset: Vector2) -> GoblinGiantChariot:
	var chariot := CHARIOT_SCENE.instantiate() as GoblinGiantChariot
	chariot.target_ship = ship
	enemies.add_child(chariot)
	chariot.global_position = _ship_center() + offset
	return chariot


func _ship_center() -> Vector2:
	return ship.to_global(Ship.SHIP_SIZE * 0.5)


func _test_defaults() -> void:
	var c := CHARIOT_SCENE.instantiate() as GoblinGiantChariot
	_expect_equal(c.max_health, 5000.0, "HP 5000")
	_expect_equal(c.throw_elite_count, 1, "throws 1 elite goblin")
	_expect_true(c.elite_goblin_scene != null, "elite goblin scene assigned")
	_expect_equal(c.move_speed, 10.0, "speed 10")
	_expect_equal(c.attack_damage, 30.0, "contact damage 30")
	_expect_equal(c.attack_interval, 1.0, "interval 1")
	_expect_equal(c.attack_range, 10.0, "range 10")
	_expect_equal(c.damage_reduction, 0.2, "damage reduction 0.2")
	_expect_equal(c.attack_type, BasicEnemy.AttackType.MELEE, "melee")
	_expect_equal(c.enemy_tier, BasicEnemy.EnemyTier.BOSS, "boss tier")
	_expect_equal(c.reward_ore, 500.0, "reward 500")
	_expect_equal(c.throw_goblin_count, 10, "throws 10 goblins")
	_expect_equal(c.throw_distance, 250.0, "throw distance 250")
	_expect_equal(c.thrown_goblin_root_duration, 2.0, "root 2 s")
	_expect_equal(c.throw_cooldown, 8.0, "throw cooldown 8 s")
	_expect_equal(c.throw_animation_duration, 4.0, "throw animation 4 s")
	_expect_equal(c.post_throw_pause, 2.0, "pause 2 s")
	_expect_equal(c.berserk_trigger_distance, 200.0, "berserk at 200")
	_expect_equal(c.berserk_speed_multiplier, 2.0, "berserk speed x2")
	_expect_equal(c.death_spawn_count, 10, "death spawns 10")
	_expect_true(c.goblin_scene != null, "goblin scene assigned")
	c.free()


func _test_throw_cycle() -> void:
	var chariot := _spawn(Vector2(900.0, 0.0))
	# Shorter timings for the test; ratios match the design.
	chariot.first_throw_delay = 0.3
	chariot.throw_animation_duration = 1.0
	chariot.post_throw_pause = 0.5
	chariot.throw_cooldown = 1.2
	chariot._cooldown_left = chariot.first_throw_delay
	var events := {"thrown": [], "starts": []}
	chariot.throw_started.connect(func() -> void: events["starts"].append(Time.get_ticks_msec()))
	chariot.goblins_thrown.connect(func(list: Array[Goblin]) -> void: events["thrown"].append(list))

	await _wait_for(func() -> bool: return chariot.stage == GoblinGiantChariot.Stage.THROWING, 3.0)
	var hold_position := chariot.global_position
	await _wait_for(func() -> bool: return not events["thrown"].is_empty(), 3.0)
	_expect_equal(events["thrown"].size(), 1, "one throw event")
	if events["thrown"].is_empty():
		chariot.queue_free()
		return
	var thrown: Array = events["thrown"][0]
	_expect_equal(thrown.size(), 10, "exactly 10 goblins per throw")
	var forward := (_ship_center() - chariot.global_position).normalized()
	var positions: Array[Vector2] = []
	for goblin in thrown:
		var ahead: float = ((goblin as Goblin).global_position - chariot.global_position).dot(forward)
		_expect_true(ahead > GoblinGiantChariot.FRONT_REACH + 200.0 and ahead < GoblinGiantChariot.FRONT_REACH + 300.0, "goblin lands ~250 ahead of the boars (%.0f)" % ahead)
		_expect_true((goblin as Goblin).is_rooted(), "thrown goblin is rooted")
		for used in positions:
			_expect_true((goblin as Goblin).global_position.distance_to(used) >= 20.0, "thrown goblins land in a spread formation")
		positions.append((goblin as Goblin).global_position)
	_expect_equal(chariot.thrown_elites.size(), 1, "exactly 1 elite goblin per throw")
	for elite in chariot.thrown_elites:
		var elite_ahead: float = (elite.global_position - chariot.global_position).dot(forward)
		_expect_true(elite_ahead > GoblinGiantChariot.FRONT_REACH + 200.0 and elite_ahead < GoblinGiantChariot.FRONT_REACH + 330.0, "elite lands ~250 ahead, leading the block (%.0f)" % elite_ahead)
		_expect_true(elite.is_rooted(), "thrown elite is rooted")
		for used in positions:
			_expect_true(elite.global_position.distance_to(used) >= 26.0, "elite does not overlap the goblin block")

	# Stationary through the rest of the animation and the pause.
	var drift := 0.0
	var deadline := Time.get_ticks_msec() + 3000
	while chariot.stage != GoblinGiantChariot.Stage.ADVANCE and Time.get_ticks_msec() < deadline:
		drift = maxf(drift, chariot.global_position.distance_to(hold_position))
		await get_tree().physics_frame
	_expect_true(drift < 0.01, "chariot does not move while throwing or pausing (%.3f)" % drift)
	var resumed := Time.get_ticks_msec()

	# Thrown goblins stay put for root duration after landing, then move.
	var first := thrown[0] as Goblin
	var landed := first.global_position
	await get_tree().create_timer(1.0).timeout
	_expect_true(first.is_rooted(), "thrown goblin remains rooted during the 2 s landing hold")
	_expect_true(first.global_position.distance_to(landed) < 0.01, "thrown goblin stays in place after landing")
	await get_tree().create_timer(1.2).timeout
	_expect_false(first.is_rooted(), "root ends after 2 s on the ground")
	_expect_true(first.global_position.distance_to(landed) > 1.0, "goblin then uses normal AI")

	# Cooldown: next throw starts cooldown seconds after rolling on.
	_expect_true(events["starts"].size() >= 2, "chariot throws again")
	if events["starts"].size() >= 2:
		var gap := (int(events["starts"][1]) - resumed) / 1000.0
		_expect_true(absf(gap - 1.2) < 0.25, "next throw after the cooldown (%.2f s)" % gap)
	for list in events["thrown"]:
		for goblin in list:
			if is_instance_valid(goblin):
				goblin.queue_free()
	chariot.queue_free()
	await get_tree().process_frame


func _test_berserk() -> void:
	var chariot := _spawn(Vector2(Ship.SHIP_SIZE.x * 0.5 + 160.0, 0.0))
	chariot.first_throw_delay = 0.1
	chariot._cooldown_left = 0.1
	var throws := [0]
	chariot.throw_started.connect(func() -> void: throws[0] += 1)
	var berserks := [0]
	chariot.berserk_started.connect(func() -> void: berserks[0] += 1)
	await get_tree().create_timer(1.0).timeout
	_expect_true(chariot.is_berserk(), "berserk within 200 of the ship")
	_expect_true(chariot._distance_to_ship() <= 200.0, "berserk distance is measured from the front")
	_expect_equal(chariot.move_speed, 20.0, "berserk doubles speed 10 -> 20")
	_expect_equal(throws[0], 0, "no throwing once berserk")
	chariot._enter_berserk()
	_expect_equal(chariot.move_speed, 20.0, "berserk applies only once")
	_expect_equal(berserks[0], 1, "berserk_started emitted once")
	chariot.queue_free()
	await get_tree().process_frame

	# Crossing the threshold during wind-up cancels the pending release.
	var canceling := _spawn(Vector2(900.0, 0.0))
	canceling.first_throw_delay = 0.05
	canceling.throw_animation_duration = 1.0
	canceling._cooldown_left = canceling.first_throw_delay
	var releases := [0]
	canceling.goblins_thrown.connect(func(_goblins: Array[Goblin]) -> void: releases[0] += 1)
	await _wait_for(func() -> bool: return canceling.stage == GoblinGiantChariot.Stage.THROWING, 1.0)
	# Place its front exactly 100 world pixels outside the transformed hull.
	var right_edge := ship.to_global(Vector2(Ship.SHIP_SIZE.x, Ship.SHIP_SIZE.y * 0.5))
	var outward := (ship.to_global(Vector2.RIGHT) - ship.to_global(Vector2.ZERO)).normalized()
	canceling.global_position = right_edge + outward * (GoblinGiantChariot.FRONT_REACH + 100.0)
	_expect_true(canceling._distance_to_ship() < 200.0, "wind-up cancellation setup is inside the trigger distance")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect_true(canceling.is_berserk(), "entering 200px during wind-up cancels throwing")
	_expect_equal(canceling.move_speed, 20.0, "canceled throw transitions directly to double speed")
	await get_tree().create_timer(1.1).timeout
	_expect_equal(releases[0], 0, "no goblins release after the 200px threshold")
	canceling.queue_free()
	await get_tree().process_frame


func _test_death() -> void:
	var chariot := _spawn(Vector2(600.0, 0.0))
	await get_tree().process_frame
	var before := _goblin_count()
	var ore_before := ResourceManager.mission_ore
	var death_position := chariot.global_position
	chariot.take_damage(100000.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var spawned: Array[Goblin] = []
	for child in enemies.get_children():
		if child is Goblin and child.global_position.distance_to(death_position) < 175.0:
			spawned.append(child)
	_expect_equal(_goblin_count() - before, 10, "death spawns 10 goblins")
	for index in range(spawned.size()):
		for other in range(index + 1, spawned.size()):
			_expect_true(spawned[index].global_position.distance_to(spawned[other].global_position) >= 20.0, "death goblins do not overlap")
		_expect_false(spawned[index].is_rooted(), "death goblins act immediately")
	_expect_true(ResourceManager.mission_ore - ore_before >= 500.0, "boss pays 500 ore")
	var wreck: Node2D = null
	for child in enemies.get_children():
		if child.get_script() == GoblinGiantChariot.WRECK_SCRIPT:
			wreck = child
	_expect_true(wreck != null, "defeat spawns the wreck animation")
	if wreck != null:
		_expect_true(wreck.global_position.distance_to(death_position) < 1.0, "wreck sits where the chariot died")
		_expect_equal(wreck.get_child_count(), 11, "9 crew goblins + 2 boars flee")
		_expect_false(wreck.is_in_group("enemies"), "wreck is not a target")


func _goblin_count() -> int:
	var count := 0
	for child in enemies.get_children():
		if child is Goblin and not child.is_queued_for_deletion():
			count += 1
	return count


func _wait_for(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()


func _expect_true(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)


func _expect_false(value: bool, description: String) -> void:
	_expect_true(not value, description)


func _expect_equal(actual: Variant, expected: Variant, description: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])
