extends Node

const ENEMY_SCENE := preload("res://Scenes/Enemies/little_rock.tscn")
const PROJECTILE_SCENE := preload("res://Scenes/Modules/Weapons/Fusion/fusion_projectile.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var machine_gun := ModuleCatalog.get_scene(&"knockback_machine_gun").instantiate() as FusionWeapon
	var laser := ModuleCatalog.get_scene(&"knockback_laser").instantiate() as FusionWeapon
	_check(is_equal_approx(machine_gun.attack_interval, 0.2), "machine gun fires every 0.2 seconds")
	_check(is_equal_approx(laser.attack_interval, 5.0), "laser fires every 5 seconds")
	_check(is_equal_approx(machine_gun.knockback_distance, 20.0), "machine gun knockback is 20 px")
	_check(is_equal_approx(laser.knockback_distance, 40.0), "laser knockback is 40 px")
	_check(machine_gun.knockback_once_per_projectile, "machine gun limits each bullet to one knockback")
	_check(laser.attack_kind == FusionWeapon.AttackKind.WAVE, "laser remains a travelling wave")
	machine_gun.free()
	laser.free()

	var first := ENEMY_SCENE.instantiate() as BasicEnemy
	var second := ENEMY_SCENE.instantiate() as BasicEnemy
	add_child(first)
	add_child(second)
	first.global_position = Vector2(100.0, 100.0)
	second.global_position = Vector2(200.0, 100.0)
	var bullet := PROJECTILE_SCENE.instantiate() as FusionProjectile
	add_child(bullet)
	bullet.global_position = Vector2(0.0, 100.0)
	bullet.direction = Vector2.RIGHT
	bullet.knockback_distance = 20.0
	bullet.knockback_once_per_projectile = true
	bullet._finish_impact(first, true)
	_check(is_equal_approx(first.global_position.x, 120.0), "first enemy is pushed 20 px")
	bullet._finish_impact(second, true)
	_check(is_equal_approx(second.global_position.x, 200.0), "same piercing bullet does not push a second enemy")
	bullet.queue_free()
	first.queue_free()
	second.queue_free()
	await get_tree().process_frame

	var wave_first := ENEMY_SCENE.instantiate() as BasicEnemy
	var wave_second := ENEMY_SCENE.instantiate() as BasicEnemy
	add_child(wave_first)
	add_child(wave_second)
	wave_first.global_position = Vector2(100.0, 200.0)
	wave_second.global_position = Vector2(200.0, 200.0)
	var wave := FusionKnockbackWave.new()
	add_child(wave)
	wave.knockback_distance = 40.0
	wave._apply_initial_hit(wave_first, Vector2.RIGHT)
	wave._apply_initial_hit(wave_second, Vector2.RIGHT)
	_check(is_equal_approx(wave_first.global_position.x, 140.0), "laser pushes its first contacted enemy")
	_check(is_equal_approx(wave_second.global_position.x, 240.0), "laser also pushes its second contacted enemy")
	wave.queue_free()
	wave_first.queue_free()
	wave_second.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("KNOCKBACK_FUSION_BALANCE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("KNOCKBACK_FUSION_BALANCE_TEST: " + failure)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
