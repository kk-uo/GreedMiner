extends Node2D

const CANNON := preload("res://Scenes/Modules/Weapons/Fusion/siege_cannon.tscn")
const SIEGE := preload("res://Scripts/Modules/Fusion/SiegeCannon.gd")
const ENEMY := preload("res://Scenes/Enemies/little_rock.tscn")
const CLUSTER_HP: float = 10000.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var cluster: Array[BasicEnemy] = []
	for point in [Vector2(100, 100), Vector2(120, 100), Vector2(100, 120)]:
		cluster.append(_enemy_at(point, CLUSTER_HP))
	var isolated := _enemy_at(Vector2(2200, 2200), 5000.0)
	var cannon := CANNON.instantiate() as FusionWeapon
	add_child(cannon)
	cannon.set_process(false)
	if not is_equal_approx(cannon.basic_damage, 80.0):
		_fail("base damage must be 80")
		return
	await get_tree().physics_frame
	var picked: BasicEnemy = SIEGE._densest_target(get_tree().get_nodes_in_group(&"enemies"), cannon.aoe_radius)
	if not cluster.has(picked):
		_fail("dense cluster must beat the far enemy with much higher maximum HP")
		return
	cannon._process(0.01)
	var strikes := _strikes()
	if strikes.size() != 1:
		_fail("one marker must appear on the first ready volley")
		return
	var strike: Node2D = strikes[0]
	if not cluster.any(func(enemy: BasicEnemy) -> bool: return enemy.global_position == strike.global_position):
		_fail("marker must be centered on one enemy in the densest area")
		return
	for enemy in cluster:
		if enemy.get_current_health() != CLUSTER_HP:
			_fail("marking must not deal damage before the shell lands")
			return
	strike._process(cannon.mark_duration)
	if cluster[0].get_current_health() != CLUSTER_HP:
		_fail("telegraph must complete before damage")
		return
	strike._process(cannon.fall_duration)
	var damage := cannon.get_modified_explosion_damage(cannon.get_damage())
	for enemy in cluster:
		if not is_equal_approx(enemy.get_current_health(), CLUSTER_HP - damage):
			_fail("every nearby enemy must take exactly one AOE hit (HP %.1f, expected %.1f, damage %.1f)" % [enemy.get_current_health(), CLUSTER_HP - damage, damage])
			return
	if isolated.get_current_health() != 5000.0:
		_fail("the entire map is targetable, but the explosion stays local")
		return
	await get_tree().process_frame
	cannon._process(4.89)
	if not _strikes().is_empty():
		_fail("no second volley before five seconds")
		return
	cannon._process(0.12)
	if _strikes().size() != 1:
		_fail("second volley must mark a target at five seconds")
		return
	for enemy in cluster:
		enemy.queue_free()
	await get_tree().process_frame
	cannon.fire()
	var far_strike: Node2D = _strikes()[-1]
	if far_strike.global_position != isolated.global_position:
		_fail("an enemy more than 1000 px away must still be targetable")
		return
	far_strike._process(cannon.mark_duration + cannon.fall_duration)
	if not is_equal_approx(isolated.get_current_health(), 5000.0 - damage):
		_fail("a distant marked enemy must take the same falling-shell damage")
		return
	isolated.queue_free()
	await get_tree().process_frame
	cannon.set_manual_control_active(true)
	cannon.set_manual_aim_world_position(Vector2(3000, 3000))
	cannon.fire()
	if _strikes().is_empty() or _strikes()[-1].global_position != Vector2(3000, 3000):
		_fail("manual turret control must still override automatic density targeting")
		return
	print("SIEGE_CANNON_TEST: PASS")
	get_tree().quit(0)


func _enemy_at(point: Vector2, hp: float) -> BasicEnemy:
	var enemy := ENEMY.instantiate() as BasicEnemy
	enemy.max_health = hp
	add_child(enemy)
	enemy.global_position = point
	enemy.set_physics_process(false)
	return enemy


func _strikes() -> Array[Node]:
	var result: Array[Node] = []
	for node in get_tree().get_nodes_in_group(&"siege_airstrikes"):
		if not node.is_queued_for_deletion():
			result.append(node)
	return result


func _fail(message: String) -> void:
	push_error("SIEGE_CANNON_TEST: " + message)
	get_tree().quit(1)
