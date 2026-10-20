extends Node

## Runs against a throwaway save, never the player's real progression.
const TestSave := preload("res://Tests/TestSave.gd")

## Headless gameplay coverage for the first Volcanic (Lava) Planet enemies.

const SHIP_SCENE := preload("res://Scenes/Ship/ship.tscn")
const DEMON_SCENE := preload("res://Scenes/Enemies/demon.tscn")
const HELLHUNTER_SCENE := preload("res://Scenes/Enemies/hellhunter.tscn")
const BIG_DEMON_SCENE := preload("res://Scenes/Enemies/big_demon.tscn")
const IMP_SCENE := preload("res://Scenes/Enemies/imp.tscn")
const FIREBALL_SCENE := preload("res://Scenes/Enemies/fireball_projectile.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("lava_enemy_test")
	ShipLoadout.installed_modules.clear()
	ResourceManager.start_new_mission()
	var ship := SHIP_SCENE.instantiate() as Ship
	ship.assembly_mode = true
	add_child(ship)
	ship.global_position = Vector2(500.0, 350.0)
	await get_tree().process_frame

	var demon := await _create_enemy(DEMON_SCENE, ship) as Demon
	var hellhunter := await _create_enemy(HELLHUNTER_SCENE, ship) as Hellhunter
	var big_demon := await _create_enemy(BIG_DEMON_SCENE, ship) as BigDemon
	var imp := await _create_enemy(IMP_SCENE, ship) as Imp
	# Keep the four placeholders separated when this test scene is run visibly.
	var ship_center := ship.to_global(Ship.SHIP_SIZE * 0.5)
	demon.global_position = ship_center + Vector2(600.0, -180.0)
	hellhunter.global_position = ship_center + Vector2(600.0, -60.0)
	big_demon.global_position = ship_center + Vector2(600.0, 80.0)
	imp.global_position = ship_center + Vector2(600.0, 200.0)
	_test_stats(demon, hellhunter, big_demon, imp)
	_test_catalog()
	await _test_melee_attack(ship)
	await _test_imp_fireball(ship)
	await _test_rewards(demon, hellhunter, big_demon, imp)

	ship.queue_free()
	ShipLoadout.installed_modules.clear()
	await get_tree().process_frame
	_finish()


func _create_enemy(scene: PackedScene, ship: Ship) -> BasicEnemy:
	var enemy := scene.instantiate() as BasicEnemy
	if enemy == null:
		_failures.append("Enemy scene does not inherit BasicEnemy")
		return null
	enemy.target_ship = ship
	add_child(enemy)
	enemy.global_position = ship.to_global(Ship.SHIP_SIZE * 0.5) + Vector2(600.0, 0.0)
	await get_tree().process_frame
	return enemy


func _test_stats(demon: Demon, hellhunter: Hellhunter, big_demon: BigDemon, imp: Imp) -> void:
	var cases: Array[Array] = [
		[demon, &"demon", 100.0, 40.0, 10.0, 10.0, 1.0, 1, 1, 3, BasicEnemy.EnemyTier.COMMON],
		[hellhunter, &"hellhunter", 120.0, 70.0, 10.0, 10.0, 1.0, 1, 1, 1, BasicEnemy.EnemyTier.COMMON],
		[big_demon, &"big_demon", 400.0, 40.0, 20.0, 25.0, 1.0, 8, 3, 1, BasicEnemy.EnemyTier.LARGE],
		[imp, &"imp", 35.0, 40.0, 5.0, 150.0, 5.0, 1, 3, 3, BasicEnemy.EnemyTier.COMMON],
	]
	for entry in cases:
		var enemy := entry[0] as BasicEnemy
		_expect_true(enemy != null, "%s scene instantiates" % entry[1])
		if enemy == null:
			continue
		_expect_equal(enemy.enemy_id, entry[1], "%s stable ID" % entry[1])
		_expect_equal(enemy.max_health, entry[2], "%s HP" % entry[1])
		_expect_equal(enemy.move_speed, entry[3], "%s speed" % entry[1])
		_expect_equal(enemy.attack_damage, entry[4], "%s damage" % entry[1])
		_expect_equal(enemy.attack_range, entry[5], "%s range" % entry[1])
		_expect_equal(enemy.attack_interval, entry[6], "%s interval" % entry[1])
		_expect_equal(enemy.reward_ore, float(entry[7]), "%s reward" % entry[1])
		_expect_equal(enemy.minimum_spawn_wave, entry[8], "%s minimum wave" % entry[1])
		_expect_equal(enemy.spawn_patterns, entry[9], "%s spawn patterns" % entry[1])
		_expect_equal(enemy.enemy_tier, entry[10], "%s tier" % entry[1])
		_expect_equal(enemy.spawn_map_id, &"volcanic_planet", "%s uses current Volcanic Planet ID" % entry[1])
		_expect_equal(enemy.damage_reduction, 0.0, "%s has no damage reduction" % entry[1])
	_expect_equal(imp.attack_type, BasicEnemy.AttackType.RANGED, "Imp uses ranged attack type")
	_expect_true(hellhunter.move_speed > demon.move_speed, "Hellhunter is faster than Demon")
	_expect_true(big_demon.get_collision_radius() > demon.get_collision_radius(), "Big Demon has a larger body")


func _test_catalog() -> void:
	for enemy_id in [&"demon", &"hellhunter", &"big_demon", &"imp"]:
		var enemy := EnemyCatalog.instantiate_enemy(enemy_id)
		_expect_true(enemy != null, "EnemyCatalog registers %s" % enemy_id)
		if enemy != null:
			enemy.free()
	_expect_true(EnemyCatalog.get_enemy_scene(&"lmp") == null, "misspelled lmp ID is not registered")


func _test_melee_attack(ship: Ship) -> void:
	var demon := await _create_enemy(DEMON_SCENE, ship) as Demon
	demon.global_position = ship.to_global(Vector2(Ship.SHIP_SIZE.x + 5.0, Ship.SHIP_SIZE.y * 0.5))
	var hp_before := ship.current_hp
	await get_tree().create_timer(1.1).timeout
	_expect_near(ship.current_hp, hp_before - 10.0, "Demon melee attack deals 10 damage")
	demon.queue_free()
	await get_tree().process_frame


func _test_imp_fireball(ship: Ship) -> void:
	var imp := await _create_enemy(IMP_SCENE, ship) as Imp
	imp.global_position = ship.to_global(Vector2(Ship.SHIP_SIZE.x + 190.0, Ship.SHIP_SIZE.y * 0.5))
	var hp_before := ship.current_hp
	_expect_near(ship.current_hp, hp_before, "Imp does not apply direct melee damage")
	imp._perform_attack(ship)
	_expect_true(get_tree().get_nodes_in_group("hostile_projectiles").size() > 0, "Imp spawns a hostile fireball")
	await get_tree().create_timer(0.8).timeout
	_expect_near(ship.current_hp, hp_before - 5.0, "Imp fireball damages the ship once")
	imp.queue_free()
	await get_tree().process_frame

	var projectile := FIREBALL_SCENE.instantiate() as FireballProjectile
	projectile.maximum_lifetime = 0.05
	projectile.target_ship = ship
	projectile.global_position = ship.global_position + Vector2(900.0, 0.0)
	add_child(projectile)
	await get_tree().create_timer(0.12).timeout
	_expect_false(is_instance_valid(projectile), "Fireball cleans itself up after its lifetime")


func _test_rewards(demon: Demon, hellhunter: Hellhunter, big_demon: BigDemon, imp: Imp) -> void:
	ResourceManager.start_new_mission()
	for enemy in [demon, hellhunter, big_demon, imp]:
		if is_instance_valid(enemy):
			enemy.take_damage(10000.0)
	await get_tree().process_frame
	_expect_near(ResourceManager.mission_ore, 11.0, "Volcanic enemy rewards total 11 Ore")


func _finish() -> void:
	if _failures.is_empty():
		print("LAVA_ENEMY_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("LAVA_ENEMY_TEST: " + failure)
		print("LAVA_ENEMY_TEST: FAIL (%d failures)" % _failures.size())
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
