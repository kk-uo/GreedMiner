extends Node

## Regression test for the throttled target-search interaction introduced in
## 41b5218. A laser that is still turning must retain its valid target so the
## turret continues rotating every physics frame.

const LASER_SCENE := preload("res://Scenes/Modules/Weapons/Laser/laser.tscn")
const ENEMY_SCENE := preload("res://Scenes/Enemies/little_rock.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var laser := LASER_SCENE.instantiate() as Laser
	laser.assembly_mode = false
	add_child(laser)
	laser.set_physics_process(false)

	var enemy := ENEMY_SCENE.instantiate() as BasicEnemy
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = Vector2(0.0, 500.0)

	var turret := laser.get_node("Turret") as Node2D
	var beam := laser.get_node("Turret/Muzzle/Beam") as Line2D
	turret.global_rotation = 0.0
	laser.current_target = enemy

	# At 120 degrees/second, half a second turns exactly 60 degrees toward
	# the target at 90 degrees. The target must remain locked for the next
	# physics frame even though the beam is still hidden.
	laser._physics_process(0.5)
	_expect(laser.current_target == enemy, "laser retains its target while turning")
	_expect(not beam.visible, "beam stays hidden until aligned")
	_expect(is_equal_approx(turret.global_rotation, deg_to_rad(60.0)), "laser rotates continuously at 120 degrees per second")

	# The next quarter-second completes the remaining 30 degrees without
	# waiting for another target-search interval.
	laser._physics_process(0.25)
	_expect(laser.current_target == enemy, "laser still owns the same target after alignment")
	_expect(absf(angle_difference(turret.global_rotation, PI * 0.5)) < 0.001, "laser reaches the target on the next physics step")
	_expect(beam.visible, "beam activates once aligned")

	if _failures.is_empty():
		print("LASER_TRACKING_REGRESSION_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("LASER_TRACKING_REGRESSION_TEST: " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
