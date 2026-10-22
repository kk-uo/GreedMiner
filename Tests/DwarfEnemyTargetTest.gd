extends Node2D

const DWARF := preload("res://Scripts/Mining/DwarfMiner.gd")
const ENEMY := preload("res://Scenes/Enemies/basic_enemy.tscn")
var failures: Array[String] = []
var deaths := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var dwarf := DWARF.new()
	add_child(dwarf)
	dwarf.set_physics_process(false)
	dwarf.died.connect(func(_worker): deaths += 1)
	var enemy := ENEMY.instantiate() as BasicEnemy
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.attack_type = BasicEnemy.AttackType.MELEE
	enemy.enemy_tier = BasicEnemy.EnemyTier.COMMON
	_check(enemy.mining_target_range == 200.0, "default detection radius is 200 pixels")
	dwarf.global_position = Vector2.ZERO
	enemy.global_position = Vector2(213, 0)
	dwarf.state = DWARF.State.MINING
	_check(enemy._find_targetable_dwarf() == null, "worker outside 200 pixels from enemy body not targeted")
	enemy.global_position = Vector2(100, 0)
	_check(enemy._find_targetable_dwarf() == dwarf, "mining dwarf targeted nearby")
	dwarf.state = DWARF.State.OUTBOUND
	_check(enemy._find_targetable_dwarf() == null, "outbound dwarf protected")
	dwarf.take_damage(10)
	_check(dwarf.hp == dwarf.max_hp, "outbound dwarf takes no damage")
	dwarf.state = DWARF.State.RETURNING
	dwarf.ore = 0.0
	_check(enemy._find_targetable_dwarf() == null, "empty returning dwarf protected")
	dwarf.ore = 30.0
	_check(enemy._find_targetable_dwarf() == dwarf, "ore carrying dwarf targeted")
	enemy.enemy_tier = BasicEnemy.EnemyTier.BOSS
	_check(enemy._find_targetable_dwarf() == null, "boss target behavior unchanged")
	enemy.enemy_tier = BasicEnemy.EnemyTier.COMMON
	enemy.attack_type = BasicEnemy.AttackType.RANGED
	_check(enemy._find_targetable_dwarf() == null, "ranged target behavior unchanged")
	enemy.attack_type = BasicEnemy.AttackType.MELEE
	dwarf.state = DWARF.State.MINING
	dwarf.ore = 0.0
	enemy.global_position = Vector2(10, 0)
	enemy._mining_target = dwarf
	enemy._is_attacking = true
	enemy._on_attack_timer_timeout()
	_check(is_equal_approx(dwarf.hp, dwarf.max_hp - enemy.attack_damage), "enemy attack damages mining dwarf")
	var crystal := preload("res://Scripts/Battle/RockyCrystal.gd").new()
	crystal.configure_ore(&"amber", 2.0)
	add_child(crystal)
	dwarf.crystal = crystal
	dwarf._facing = 0.0
	var target_pos: Vector2 = dwarf.get_enemy_target_position()
	_check(is_equal_approx(target_pos.distance_to(dwarf.global_position), 44.0), "mining target matches visible offset")
	enemy.global_position = target_pos + Vector2(10, 0)
	var previous_hp: float = dwarf.hp
	enemy._on_attack_timer_timeout()
	_check(is_equal_approx(dwarf.hp, previous_hp - enemy.attack_damage), "attack hits displayed worker position")
	var golem := preload("res://Scenes/Enemies/rock_golem.tscn").instantiate() as BasicEnemy
	add_child(golem)
	golem.set_physics_process(false)
	golem.global_position = target_pos + Vector2(35, 0)
	var ship := Ship.new()
	ship.current_hp = ship.max_hp
	golem.target_ship = ship
	golem._physics_process(0.016)
	_check(golem._mining_target == dwarf and golem._is_attacking, "large melee enemy starts attacking the worker at body contact range")
	previous_hp = dwarf.hp
	golem._on_attack_timer_timeout()
	_check(is_equal_approx(dwarf.hp, previous_hp - golem.attack_damage), "large melee enemy hits when its body is beside the worker")
	ship.free()
	var weather := WeatherManager.new()
	weather.name = "WeatherManager"
	add_child(weather)
	weather.blood_moon_active = true
	var enemies := Node2D.new()
	enemies.name = "Enemies"
	add_child(enemies)
	var vampire := preload("res://Scenes/Enemies/vampire.tscn").instantiate() as BasicEnemy
	enemies.add_child(vampire)
	vampire.set_physics_process(false)
	vampire.global_position = target_pos + Vector2(30, 0)
	vampire._mining_target = dwarf
	vampire._is_attacking = true
	previous_hp = dwarf.hp
	vampire._on_attack_timer_timeout()
	_check(is_equal_approx(dwarf.hp, previous_hp - vampire.attack_damage), "vampire attacks mining dwarf during blood moon")
	var explosion := preload("res://Scripts/VFX/EnemyExplosion.gd").new()
	explosion.damage = 5.0
	explosion.radius = 20.0
	explosion.damage_enemies = false
	explosion.hurt_ship = false
	add_child(explosion)
	explosion.global_position = target_pos
	previous_hp = dwarf.hp
	explosion._apply_damage()
	_check(is_equal_approx(dwarf.hp, previous_hp - 5.0), "enemy explosion damages mining dwarf")
	explosion.queue_free()
	dwarf.take_damage(1000.0)
	_check(deaths == 1 and dwarf.is_queued_for_deletion(), "mining dwarf dies normally")
	if failures.is_empty():
		print("DWARF_ENEMY_TARGET_TEST: PASS")
		get_tree().quit(0)
	else:
		for message in failures:
			push_error("DWARF_ENEMY_TARGET_TEST: " + message)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
