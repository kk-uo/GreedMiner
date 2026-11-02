extends Node2D

## Laser Chainsaw is a melee saw (not a beam) with a slightly larger reach
## than the Chainsaw: it hits everything inside its radius, nothing beyond.
const SAVE := preload("res://Tests/TestSave.gd")
const ENEMY := preload("res://Scenes/Enemies/little_rock.tscn")
const SAW := preload("res://Scenes/Modules/Weapons/Chainsaw/chainsaw.tscn")
const LASER_SAW := preload("res://Scenes/Modules/Weapons/Fusion/laser_chainsaw.tscn")

var errors: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	if not condition:
		errors.append(label)


func _enemy_at(point: Vector2) -> BasicEnemy:
	var enemy := ENEMY.instantiate() as BasicEnemy
	enemy.position = point
	enemy.max_health = 1000.0
	enemy.move_speed = 0.0
	enemy.reward_ore = 0.0
	add_child(enemy)
	return enemy


func _run() -> void:
	SAVE.isolate("laser_chainsaw")
	var chainsaw := SAW.instantiate() as Chainsaw
	var weapon := LASER_SAW.instantiate() as FusionWeapon
	_check(weapon.attack_kind == FusionWeapon.AttackKind.SAW, "Laser Chainsaw uses the melee saw attack")
	_check(weapon.attack_range > chainsaw.attack_radius, "Laser Chainsaw reaches further than the Chainsaw")
	_check(weapon.attack_range <= chainsaw.attack_radius * 1.5, "Laser Chainsaw reach stays chainsaw-sized")
	chainsaw.free()
	var near := _enemy_at(Vector2(490, 400))
	var far := _enemy_at(Vector2(560, 400))
	weapon.assembly_mode = true
	weapon.position = Vector2(400, 400)
	add_child(weapon)
	weapon.set_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	var near_before := near.get_current_health()
	var far_before := far.get_current_health()
	weapon.assembly_mode = false
	weapon.fire()
	_check(is_equal_approx(near.get_current_health(), near_before - weapon.get_damage()), "enemy inside the saw radius is cut")
	_check(is_equal_approx(far.get_current_health(), far_before), "enemy beyond the saw radius is untouched")
	_check(weapon.saw_engaged > 0.0, "a hit lights the laser orbits")
	# Five endless spinning beams: a sweep over a far enemy cuts it, an enemy
	# between two beams (36 degrees off) is not touched.
	_check(weapon.saw_beam_count == 5, "Laser Chainsaw fires five beams")
	var laser := (load("res://Scenes/Modules/Weapons/Laser/laser.tscn") as PackedScene).instantiate()
	_check(is_equal_approx(weapon.saw_beam_damage, float(laser.get("basic_damage"))), "a beam sweep deals one base Laser hit")
	laser.free()
	var distant := _enemy_at(Vector2(1400, 400))
	var between := _enemy_at(Vector2(400, 400) + Vector2.from_angle(deg_to_rad(36.0)) * 600.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var distant_before := distant.get_current_health()
	var between_before := between.get_current_health()
	weapon.saw_beam_power = 1.0
	weapon._saw_beam_last_angle = -0.1
	weapon.saw_beam_angle = 0.1
	weapon.fire()
	_check(is_equal_approx(distant.get_current_health(), distant_before - weapon.get_saw_beam_damage()), "a beam sweeping over a far enemy cuts it (endless range)")
	_check(is_equal_approx(between.get_current_health(), between_before), "an enemy between beams is not hit")
	# Beams power up only while an enemy is inside the melee radius (sync 85).
	weapon.saw_beam_power = 0.0
	near.global_position = Vector2(400, 400) + Vector2(600, 0)
	for _i in range(30):
		weapon._process_saw(1.0 / 60.0)
	_check(weapon.saw_beam_power == 0.0, "no laser beams while every enemy is outside the saw radius")
	near.global_position = Vector2(400, 400) + Vector2(60, 0)
	for _i in range(30):
		weapon._process_saw(1.0 / 60.0)
	_check(weapon.saw_beam_power > 0.9, "laser beams fire once an enemy enters the saw radius")
	if errors.is_empty():
		print("LASER_CHAINSAW_TEST: PASS")
	else:
		for e in errors:
			push_error("LASER_CHAINSAW_TEST: " + e)
		print("LASER_CHAINSAW_TEST: FAIL (%d failures)" % errors.size())
	get_tree().quit()
