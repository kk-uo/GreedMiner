extends Node

## Runs against a throwaway save, never the player's real progression.
const TestSave := preload("res://Tests/TestSave.gd")

## Headless gameplay checks for the three independently instantiable Verdant enemies.

const SHIP_SCENE: PackedScene = preload("res://Scenes/Ship/ship.tscn")
const GOBLIN_SCENE: PackedScene = preload("res://Scenes/Enemies/goblin.tscn")
const HUNTER_SCENE: PackedScene = preload("res://Scenes/Enemies/goblin_hunter.tscn")
const ELITE_SCENE: PackedScene = preload("res://Scenes/Enemies/elite_goblin.tscn")
const HUNTER_PROJECTILE_SCENE: PackedScene = preload("res://Scenes/Enemies/goblin_hunter_projectile.tscn")
const MACHINE_GUN_PROJECTILE_SCENE: PackedScene = preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun_projectile.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("verdant_enemy_test")
	ShipLoadout.installed_modules.clear()
	var ship := SHIP_SCENE.instantiate() as Ship
	ship.assembly_mode = true
	add_child(ship)
	await get_tree().process_frame
	ship.global_position = Vector2(400.0, 300.0)

	var goblin := await _create_enemy(GOBLIN_SCENE, ship) as Goblin
	var hunter := await _create_enemy(HUNTER_SCENE, ship) as GoblinHunter
	var elite := await _create_enemy(ELITE_SCENE, ship) as EliteGoblin
	hunter.global_position += Vector2(0.0, 300.0)
	elite.global_position += Vector2(0.0, -300.0)
	_test_stats(goblin, hunter, elite)
	await _test_existing_weapon_projectile(goblin)

	# Percentage reduction is evaluated through the shared damage pipeline.
	elite.take_damage(50.0)
	_expect_near(elite.get_current_health(), 160.0, "Elite prevents exactly 20 percent of incoming damage")

	# Each enemy can die through the same base implementation.
	goblin.take_damage(50.0)
	hunter.take_damage(20.0)
	elite.take_damage(1000.0)
	await get_tree().process_frame
	_expect_false(is_instance_valid(goblin), "Goblin dies and is removed")
	_expect_false(is_instance_valid(hunter), "Goblin Hunter dies and is removed")
	_expect_false(is_instance_valid(elite), "Elite Goblin dies and is removed")

	await _test_melee_attack(ship)
	await _test_hunter_projectile(ship)
	await _test_projectile_lifetime(ship)
	await _test_hunter_chase(ship)

	ship.queue_free()
	ShipLoadout.installed_modules.clear()
	await get_tree().process_frame
	_finish()


func _create_enemy(enemy_scene: PackedScene, ship: Ship) -> BasicEnemy:
	var enemy := enemy_scene.instantiate() as BasicEnemy
	if enemy == null:
		_failures.append("Enemy scene does not inherit BasicEnemy")
		return null
	enemy.target_ship = ship
	add_child(enemy)
	enemy.global_position = ship.to_global(Ship.SHIP_SIZE * 0.5) + Vector2(500.0, 0.0)
	await get_tree().process_frame
	return enemy


func _test_stats(goblin: Goblin, hunter: GoblinHunter, elite: EliteGoblin) -> void:
	_expect_true(goblin != null and hunter != null and elite != null, "all enemy scenes instantiate")
	if goblin != null:
		_expect_equal(goblin.enemy_id, &"goblin", "Goblin ID")
		_expect_equal(goblin.max_health, 20.0, "Goblin HP")
		_expect_equal(goblin.reward_ore, 0.0, "Goblin reward")
		_expect_true(GoblinVisual.COMMON_SCALE >= 0.8 and GoblinVisual.COMMON_SCALE <= 0.85, "Goblin drawn 15-20 percent smaller")
		_expect_equal(goblin._get_visual_radius(), 10.0, "Goblin visual radius shrunk from 12 to 10")
		_expect_equal(goblin.move_speed, 40.0, "Goblin speed")
		_expect_equal(goblin.attack_damage, 5.0, "Goblin damage")
		_expect_equal(goblin.attack_interval, 1.0, "Goblin interval")
		_expect_equal(goblin.attack_range, 10.0, "Goblin range")
		_expect_equal(goblin.enemy_tier, BasicEnemy.EnemyTier.COMMON, "Goblin tier")
	if hunter != null:
		_expect_equal(hunter.enemy_id, &"goblin_hunter", "Hunter ID")
		_expect_equal(hunter.max_health, 20.0, "Hunter HP")
		_expect_equal(hunter.move_speed, 50.0, "Hunter speed")
		_expect_equal(hunter.attack_damage, 5.0, "Hunter damage")
		_expect_equal(hunter.attack_interval, 1.0, "Hunter interval")
		_expect_equal(hunter.attack_range, 100.0, "Hunter range")
		_expect_equal(hunter.reward_ore, 0.0, "Hunter reward")
		_expect_equal(hunter.attack_type, BasicEnemy.AttackType.RANGED, "Hunter attack type")
	if elite != null:
		_expect_equal(elite.enemy_id, &"elite_goblin", "Elite ID")
		_expect_equal(elite.max_health, 200.0, "Elite HP")
		_expect_equal(elite.move_speed, 25.0, "Elite speed")
		_expect_equal(elite.attack_damage, 10.0, "Elite damage")
		_expect_equal(elite.attack_interval, 1.0, "Elite interval")
		_expect_equal(elite.attack_range, 10.0, "Elite range")
		_expect_equal(elite.damage_reduction, 0.2, "Elite damage reduction")
		_expect_equal(elite.enemy_tier, BasicEnemy.EnemyTier.LARGE, "Elite tier")
		_expect_equal(elite.reward_ore, 5.0, "Elite reward")


func _test_melee_attack(ship: Ship) -> void:
	var goblin := await _create_enemy(GOBLIN_SCENE, ship) as Goblin
	goblin.global_position = ship.to_global(Vector2(Ship.SHIP_SIZE.x + 5.0, Ship.SHIP_SIZE.y * 0.5))
	var hp_before := ship.current_hp
	await get_tree().create_timer(1.1).timeout
	_expect_near(ship.current_hp, hp_before - 5.0, "Goblin attacks once after its one-second interval")
	goblin.queue_free()
	await get_tree().process_frame


func _test_hunter_projectile(ship: Ship) -> void:
	var hunter := await _create_enemy(HUNTER_SCENE, ship) as GoblinHunter
	hunter.global_position = ship.to_global(Vector2(Ship.SHIP_SIZE.x + 90.0, Ship.SHIP_SIZE.y * 0.5))
	var hp_before := ship.current_hp
	await get_tree().create_timer(1.1).timeout
	_expect_near(ship.current_hp, hp_before, "Hunter does not apply direct melee damage when firing")
	await get_tree().create_timer(0.9).timeout
	_expect_near(ship.current_hp, hp_before - 5.0, "Hunter projectile collides and damages the ship once")
	hunter.queue_free()
	await get_tree().process_frame


func _test_existing_weapon_projectile(goblin: Goblin) -> void:
	var projectile := MACHINE_GUN_PROJECTILE_SCENE.instantiate() as MachineGunProjectile
	add_child(projectile)
	projectile.damage = 5.0
	projectile.speed = 0.0
	projectile.global_position = goblin.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect_near(goblin.get_current_health(), 15.0, "existing Machine Gun projectile damages Goblin")


func _test_projectile_lifetime(ship: Ship) -> void:
	var projectile := HUNTER_PROJECTILE_SCENE.instantiate() as GoblinHunterProjectile
	projectile.maximum_lifetime = 0.05
	projectile.target_ship = ship
	projectile.global_position = ship.to_global(Ship.SHIP_SIZE * 0.5) + Vector2(800.0, 0.0)
	add_child(projectile)
	await get_tree().create_timer(0.12).timeout
	_expect_false(is_instance_valid(projectile), "Hunter projectile cleans itself up after its safe lifetime")


func _test_hunter_chase(ship: Ship) -> void:
	var hunter := await _create_enemy(HUNTER_SCENE, ship) as GoblinHunter
	hunter.global_position = ship.to_global(Vector2(Ship.SHIP_SIZE.x + 400.0, Ship.SHIP_SIZE.y * 0.5))
	var before := hunter.global_position.distance_to(ship.to_global(Ship.SHIP_SIZE * 0.5))
	await get_tree().create_timer(0.2).timeout
	var after := hunter.global_position.distance_to(ship.to_global(Ship.SHIP_SIZE * 0.5))
	_expect_true(after < before, "Hunter resumes chasing outside attack range")
	hunter.queue_free()
	await get_tree().process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("VERDANT_ENEMY_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("VERDANT_ENEMY_TEST: " + failure)
		print("VERDANT_ENEMY_TEST: FAIL (%d failures)" % _failures.size())
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
