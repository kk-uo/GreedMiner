extends Node

## Runs against a throwaway save, never the player's real progression.
const TestSave := preload("res://Tests/TestSave.gd")

## Red Rock (kamikaze) and Goblin Engineer (dynamite): both explode on death
## and damage every enemy and the ship in explosion_radius; chains; clicks.

const BATTLE_SCENE: PackedScene = preload("res://Scenes/Battle/BattleMain.tscn")
const RED_ROCK: PackedScene = preload("res://Scenes/Enemies/red_rock.tscn")
const ENGINEER: PackedScene = preload("res://Scenes/Enemies/goblin_engineer.tscn")
const GOBLIN: PackedScene = preload("res://Scenes/Enemies/goblin.tscn")
const ELITE: PackedScene = preload("res://Scenes/Enemies/elite_goblin.tscn")

var _failures: Array[String] = []
var battle: Node2D
var ship: Ship
var enemies: Node2D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("explosive_enemy_test")
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

	_test_stats()
	await _test_red_rock_kamikaze()
	await _test_click_pop_hurts_crowd()
	await _test_chain_reaction()
	await _test_engineer_dynamite()

	battle.queue_free()
	ShipLoadout.installed_modules.clear()
	await get_tree().process_frame
	if _failures.is_empty():
		print("EXPLOSIVE_ENEMY_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("EXPLOSIVE_ENEMY_TEST: " + failure)
		print("EXPLOSIVE_ENEMY_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _test_stats() -> void:
	for entry in [[RED_ROCK, &"red_rock", 10.0, 0], [ENGINEER, &"goblin_engineer", 100.0, 1]]:
		var e := (entry[0] as PackedScene).instantiate() as BasicEnemy
		_expect_equal(e.enemy_id, entry[1], "id")
		_expect_equal(e.max_health, 50.0, "%s HP 50" % entry[1])
		_expect_equal(e.move_speed, 75.0, "%s speed 75" % entry[1])
		_expect_equal(e.attack_damage, 20.0, "%s damage 20" % entry[1])
		_expect_equal(e.attack_interval, 1.0, "%s interval 1" % entry[1])
		_expect_equal(e.attack_range, entry[2], "%s range" % entry[1])
		_expect_equal(e.damage_reduction, 0.0, "%s DR 0" % entry[1])
		_expect_equal(int(e.attack_type), entry[3], "%s attack type" % entry[1])
		_expect_equal(int(e.enemy_tier), int(BasicEnemy.EnemyTier.COMMON), "%s is common" % entry[1])
		_expect_equal(e.reward_ore, 1.0, "%s 1 ore" % entry[1])
		_expect_equal(float(e.get("explosion_damage")), 20.0, "%s explodes for 20" % entry[1])
		_expect_true(EnemyCatalog.get_enemy_scene(entry[1]) != null, "%s registered in EnemyCatalog" % entry[1])
		e.free()


## Runs at the ship, lights its fuse at the hull, explodes: ship -20, a goblin
## next to it dies, no ore for a self-destruct.
func _test_red_rock_kamikaze() -> void:
	var hp_before := ship.current_hp
	var ore_before := ResourceManager.mission_ore
	var rock := _spawn(RED_ROCK, Vector2(0.0, -260.0))
	var buddy := _spawn(GOBLIN, Vector2(0.0, -420.0))
	buddy.move_speed = 0.0
	var lit := false
	var deadline := Time.get_ticks_msec() + 6000
	while is_instance_valid(rock) and not rock.is_dying() and Time.get_ticks_msec() < deadline:
		if rock.call("is_fuse_lit"):
			lit = true
			buddy.global_position = rock.global_position + Vector2(30.0, 0.0)
		await get_tree().physics_frame
	_expect_true(lit, "red rock lights its fuse at the hull")
	await get_tree().create_timer(0.2).timeout
	_expect_equal(ship.current_hp, hp_before - 20.0, "kamikaze blast deals 20 to the ship")
	_expect_true(not is_instance_valid(buddy) or buddy.is_dying(), "the blast also kills a goblin beside it")
	_expect_true(ResourceManager.mission_ore - ore_before <= 1.0 + 0.01, "self-destruct pays no ore (only the goblin's 1)")
	ship.current_hp = ship.max_hp


## Popping a red rock with 8 clicks blows up the crowd around it, but not
## enemies outside the radius or the faraway ship.
func _test_click_pop_hurts_crowd() -> void:
	var hp_before := ship.current_hp
	var rock := _spawn(RED_ROCK, Vector2(500.0, 0.0))
	rock.move_speed = 0.0
	var near := _spawn(GOBLIN, Vector2(540.0, 0.0))
	var elite := _spawn(ELITE, Vector2(500.0, 50.0))
	var far := _spawn(GOBLIN, Vector2(700.0, 0.0))
	for unit in [near, elite, far]:
		unit.move_speed = 0.0
	await get_tree().physics_frame
	var ore_before := ResourceManager.mission_ore
	for index in range(BasicEnemy.CLICKS_TO_POP):
		rock.register_click()
	await get_tree().create_timer(0.2).timeout
	_expect_true(not is_instance_valid(near) or near.is_dying(), "popped rock kills a goblin within the radius")
	_expect_true(is_instance_valid(elite) and elite.get_current_health() < elite.max_health, "popped rock damages an elite within the radius")
	_expect_true(is_instance_valid(far) and is_equal_approx(far.get_current_health(), far.max_health), "goblin outside the radius is untouched")
	_expect_equal(ship.current_hp, hp_before, "far-away blast does not hurt the ship")
	# Red Rock pays 1 ore; its goblin victim pays 0 under the current table.
	_expect_true(ResourceManager.mission_ore - ore_before >= 1.0 - 0.01, "popped rock pays ore")
	for unit in [elite, far]:
		if is_instance_valid(unit):
			unit.queue_free()


func _test_chain_reaction() -> void:
	var a := _spawn(RED_ROCK, Vector2(-500.0, 0.0))
	var b := _spawn(RED_ROCK, Vector2(-450.0, 0.0))
	var c := _spawn(ENGINEER, Vector2(-400.0, 0.0))
	for unit in [a, b, c]:
		unit.move_speed = 0.0
		unit.set("max_health", 20.0)
		unit.set("_current_health", 20.0)
	await get_tree().physics_frame
	a.take_damage(1000.0)
	await get_tree().create_timer(0.4).timeout
	_expect_true(not is_instance_valid(b) or b.is_dying(), "a red rock caught in a blast explodes too")
	_expect_true(not is_instance_valid(c) or c.is_dying(), "the chain carries on to an engineer")


## Walks to 100 range and lobs dynamite that hits the hull for 20.
func _test_engineer_dynamite() -> void:
	ship.current_hp = ship.max_hp
	var engineer := _spawn(ENGINEER, Vector2(0.0, 300.0))
	var deadline := Time.get_ticks_msec() + 7000
	while ship.current_hp >= ship.max_hp and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	_expect_equal(ship.current_hp, ship.max_hp - 20.0, "one dynamite hit deals 20")
	var gap: float = engineer.global_position.distance_to(engineer._get_nearest_ship_boundary_world(ship, engineer.global_position))
	_expect_true(gap > 85.0 and gap <= 101.0, "engineer throws from ~100 range (%.0f)" % gap)
	# Killed next to a goblin, the engineer's death blast hurts it.
	var buddy := _spawn(GOBLIN, Vector2.ZERO)
	buddy.move_speed = 0.0
	buddy.global_position = engineer.global_position + Vector2(25.0, 0.0)
	var hp_now := ship.current_hp
	engineer.take_damage(1000.0)
	await get_tree().create_timer(0.3).timeout
	_expect_true(not is_instance_valid(buddy) or buddy.is_dying(), "engineer death blast kills a goblin beside it")
	_expect_true(ship.current_hp >= hp_now - 20.0, "death blast never hits the ship more than once")


func _spawn(scene: PackedScene, offset: Vector2) -> BasicEnemy:
	var enemy := scene.instantiate() as BasicEnemy
	enemy.target_ship = ship
	enemies.add_child(enemy)
	enemy.global_position = ship.to_global(Ship.SHIP_SIZE * 0.5) + offset
	return enemy


func _expect_true(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)


func _expect_equal(actual: Variant, expected: Variant, description: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])
