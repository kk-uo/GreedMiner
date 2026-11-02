extends Node

const ENEMY := preload("res://Scenes/Enemies/little_rock.tscn")
const CANNON := preload("res://Scenes/Modules/Weapons/DwarfCannon/dwarf_cannon.tscn")
const LASER := preload("res://Scenes/Modules/Weapons/Laser/laser.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var flying := _spawn_enemy(Vector2(100.0, 0.0), BasicEnemy.MovementType.FLYING)
	var ground := _spawn_enemy(Vector2(300.0, 0.0), BasicEnemy.MovementType.WALK)
	await get_tree().physics_frame

	var cannon := CANNON.instantiate() as DwarfCannon
	add_child(cannon)
	cannon.set_process(false)
	_check(cannon.find_nearest_enemy_in_range(Vector2.ZERO, 500.0) == ground, "ground-only cannon skips a nearer flying enemy")

	var laser := LASER.instantiate() as Laser
	add_child(laser)
	laser.set_process(false)
	_check(laser.find_nearest_enemy_in_range(Vector2.ZERO, 500.0) == flying, "ground-and-air laser can lock the nearer flying enemy")

	var shell := cannon.projectile_scene.instantiate() as DwarfCannonProjectile
	shell.source_weapon = cannon
	add_child(shell)
	shell.set_physics_process(false)
	shell.set_deferred("monitoring", false)
	shell.global_position = flying.global_position
	var flying_hp := flying.get_current_health()
	shell._on_area_entered(flying)
	_check(is_equal_approx(flying.get_current_health(), flying_hp), "ground-only cannonball deals no damage to a flying enemy")
	_check(not shell._has_exploded, "ground-only cannonball passes through a flying enemy")

	shell.global_position = ground.global_position
	var ground_hp := ground.get_current_health()
	shell._on_area_entered(ground)
	await get_tree().process_frame
	_check(ground.get_current_health() < ground_hp, "the same cannonball still explodes on a ground enemy")
	cannon.queue_free()
	laser.queue_free()
	flying.queue_free()
	ground.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("WEAPON_AIR_GROUND_TARGETING_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("WEAPON_AIR_GROUND_TARGETING_TEST: " + failure)
		get_tree().quit(1)


func _spawn_enemy(at: Vector2, movement: BasicEnemy.MovementType) -> BasicEnemy:
	var enemy := ENEMY.instantiate() as BasicEnemy
	enemy.max_health = 1000.0
	enemy.movement_type = movement
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = at
	return enemy


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
