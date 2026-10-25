extends Node2D

const ENEMY := preload("res://Scenes/Enemies/little_rock.tscn")
const KNOCKBACK_WAVE := preload("res://Scripts/Modules/Fusion/FusionKnockbackWave.gd")
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var normal := _make_enemy(Vector2(100.0, 0.0), BasicEnemy.EnemyTier.COMMON)
	var boss := _make_enemy(Vector2(100.0, 30.0), BasicEnemy.EnemyTier.BOSS)
	var wave := KNOCKBACK_WAVE.new()
	wave.direction = Vector2.RIGHT
	wave.speed = 0.0
	wave.maximum_distance = 1000.0
	wave.wave_length = 100.0
	wave.initial_damage = 15.0
	wave.damage_per_second = 1.0
	wave.knockback_distance = 200.0
	add_child(wave)
	wave.global_position = Vector2(100.0, 0.0)
	wave.arm_from_current_position()
	await get_tree().create_timer(0.2).timeout
	_check(is_equal_approx(normal.get_current_health(), 185.0), "ordinary enemy takes exactly one initial 15-damage hit")
	_check(is_equal_approx(boss.get_current_health(), 185.0), "boss takes the initial hit")
	_check(normal.global_position.x >= 299.0, "ordinary enemy is pushed 200 px forward")
	_check(is_equal_approx(boss.global_position.x, 100.0), "boss is immune to knockback")
	await get_tree().create_timer(1.0).timeout
	_check(is_equal_approx(normal.get_current_health(), 184.0), "knocked-away enemy takes 1 damage after one second")
	_check(is_equal_approx(boss.get_current_health(), 184.0), "boss takes subsequent 1-damage tick")
	wave.queue_free()
	normal.queue_free()
	boss.queue_free()
	if failures.is_empty():
		print("FUSION_KNOCKBACK_WAVE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("FUSION_KNOCKBACK_WAVE_TEST: " + failure)
		get_tree().quit(1)


func _make_enemy(at: Vector2, tier: int) -> BasicEnemy:
	var enemy := ENEMY.instantiate() as BasicEnemy
	enemy.max_health = 200.0
	enemy.move_speed = 0.0
	enemy.enemy_tier = tier
	add_child(enemy)
	enemy.global_position = at
	return enemy


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
