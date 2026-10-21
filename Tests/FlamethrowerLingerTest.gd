extends Node2D

## Flamethrower shots: every visible flame puff is also a hit volume. A shot
## pours puffs for its emit window; each puff flies to the range, hangs in
## place for about LINGER_TIME seconds, then burns out. An enemy touching any
## puff of a shot (flying or hanging) takes that shot's damage once.
const TestSave := preload("res://Tests/TestSave.gd")
const PUFF := "res://Scenes/Modules/Weapons/Flamethrower/flamethrower_projectile.tscn"
const ROCK := "res://Scenes/Enemies/little_rock.tscn"
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)


func _make_enemy(at: Vector2) -> BasicEnemy:
	var enemy := load(ROCK).instantiate() as BasicEnemy
	enemy.max_health = 1000.0
	enemy.position = at
	add_child(enemy)
	return enemy


func _run() -> void:
	TestSave.isolate("flamethrower_linger_test")
	# 1) A single puff stops at the end of its range and still burns newcomers.
	var shot := load(PUFF).instantiate() as FlamethrowerProjectile
	shot.position = Vector2(100, 100)
	shot.direction = Vector2.RIGHT
	shot.speed = 600.0
	shot.max_distance = 30.0
	shot.damage = 5.0
	add_child(shot)
	var enemy := _make_enemy(Vector2(900, 900))
	await get_tree().physics_frame
	enemy.set_physics_process(false)
	for _i in range(15):
		await get_tree().physics_frame
	check(shot.get_puff_count() == 1, "no emit window -> one puff")
	check(shot.is_lingering(), "puff hangs at the end of its range")
	var stop := shot.get_puff_positions()[0]
	check(stop.distance_to(Vector2(100, 100)) > 20.0 and stop.distance_to(Vector2(100, 100)) < 40.0, "puff stops near max distance")
	var before := enemy.get_current_health()
	enemy.global_position = stop
	for _i in range(4):
		await get_tree().physics_frame
	check(shot.get_puff_positions()[0] == stop, "hanging puff does not move")
	check(is_equal_approx(enemy.get_current_health(), before - 5.0), "enemy entering the hanging puff takes one hit")
	for _i in range(6):
		await get_tree().physics_frame
	check(is_equal_approx(enemy.get_current_health(), before - 5.0), "same shot never hits twice")
	await get_tree().create_timer(FlamethrowerProjectile.LINGER_TIME * 1.2).timeout
	await get_tree().physics_frame
	check(not is_instance_valid(shot), "shot burns out after the linger time")
	enemy.queue_free()
	# 2) A shot with an emit window pours many puffs; each visible puff can
	#    hit, but one shot damages an enemy only once.
	var gush := load(PUFF).instantiate() as FlamethrowerProjectile
	gush.position = Vector2(100, 400)
	gush.direction = Vector2.RIGHT
	gush.speed = 300.0
	gush.max_distance = 200.0
	gush.damage = 5.0
	gush.emit_window = 0.2
	add_child(gush)
	var side := _make_enemy(Vector2(900, 900))
	await get_tree().physics_frame
	side.set_physics_process(false)
	for _i in range(20):
		await get_tree().physics_frame
	check(gush.get_puff_count() >= 7 and gush.get_puff_count() <= 11, "emit window pours ~9 puffs (%d)" % gush.get_puff_count())
	# Put the enemy right on the puff farthest from the cone's centre line.
	var far := gush.get_puff_positions()[0]
	for p in gush.get_puff_positions():
		if absf(p.y - 400.0) > absf(far.y - 400.0):
			far = p
	before = side.get_current_health()
	side.global_position = far
	for _i in range(4):
		await get_tree().physics_frame
	check(is_equal_approx(side.get_current_health(), before - 5.0), "touching an outer visible puff deals damage")
	for _i in range(30):
		await get_tree().physics_frame
	check(is_equal_approx(side.get_current_health(), before - 5.0), "one shot damages an enemy once")
	if failures.is_empty():
		print("FLAMETHROWER_LINGER_TEST: PASS")
	else:
		for f in failures:
			push_error("FLAMETHROWER_LINGER_TEST: " + f)
	get_tree().quit(1 if not failures.is_empty() else 0)
