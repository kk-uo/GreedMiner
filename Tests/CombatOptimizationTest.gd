extends Node2D

const SAVE := preload("res://Tests/TestSave.gd")
const ENEMY := preload("res://Scenes/Enemies/little_rock.tscn")
const BULLET := preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun_projectile.tscn")
const CANNON := preload("res://Scenes/Modules/Weapons/DwarfCannon/dwarf_cannon_projectile.tscn")
const SAW := preload("res://Scenes/Modules/Weapons/Chainsaw/chainsaw.tscn")
var errors: Array[String] = []

class CountingWeapon extends WeaponModule:
	var scans: int = 0
	func find_nearest_enemy_in_range(_origin: Vector2, _range: float) -> BasicEnemy:
		scans += 1
		return null

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

func _settle_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame

func _run() -> void:
	SAVE.isolate("combat_optimization")
	var a := _enemy_at(Vector2(400, 400))
	var b := _enemy_at(Vector2(410, 400))
	_check(not a.monitoring and a.monitorable and a.collision_mask == 0 and a.collision_layer == 1, "enemies are passive detectable targets")
	await _settle_physics()
	var bullet := BULLET.instantiate() as MachineGunProjectile
	bullet.position = a.position
	bullet.speed = 0.0
	_check(bullet.collision_layer == 0 and bullet.collision_mask == 1 and not bullet.monitorable, "bullet only scans target layer")
	add_child(bullet)
	await _settle_physics()
	_check(is_equal_approx(a.get_current_health() + b.get_current_health(), 1995.0), "actual physics bullet overlap deals one five-damage hit")
	var a_before := a.get_current_health()
	var b_before := b.get_current_health()
	var shell := CANNON.instantiate() as DwarfCannonProjectile
	shell.position = a.position
	shell.speed = 0.0
	shell.damage = 7.0
	shell.explosion_radius = 30.0
	add_child(shell)
	await _settle_physics()
	_check(is_equal_approx(a.get_current_health(), a_before - 7.0) and is_equal_approx(b.get_current_health(), b_before - 7.0), "actual physics cannon hit damages both passive targets once")
	var saw := SAW.instantiate() as Chainsaw
	saw.assembly_mode = true
	saw.position = a.position
	add_child(saw)
	saw.set_process(false)
	saw.set_physics_process(false)
	await _settle_physics()
	a_before = a.get_current_health()
	b_before = b.get_current_health()
	saw.assembly_mode = false
	saw.fire()
	_check(is_equal_approx(a.get_current_health(), a_before - saw.get_damage()) and is_equal_approx(b.get_current_health(), b_before - saw.get_damage()), "chainsaw shape overlaps still damage passive targets")
	var scanners: Array[CountingWeapon] = []
	for index in range(8):
		var scanner := CountingWeapon.new()
		add_child(scanner)
		scanners.append(scanner)
	var largest_later_batch := 0
	for frame in range(120):
		var scans_this_frame := 0
		for scanner in scanners:
			var previous := scanner.scans
			scanner.keep_or_find_target(null, Vector2.ZERO, 200.0, 1.0 / 60.0)
			scans_this_frame += scanner.scans - previous
		if frame > 0:
			largest_later_batch = maxi(largest_later_batch, scans_this_frame)
	for scanner in scanners:
		_check(scanner.scans >= 8 and scanner.scans <= 11, "empty turret scans about five times per second")
	_check(largest_later_batch < scanners.size(), "empty turret scans are staggered across frames")
	var weapon := scanners[0]
	var scan_before := weapon.scans
	for frame in range(60):
		weapon.keep_or_find_target(null, Vector2.ZERO, 200.0, 0.0)
	_check(weapon.scans == scan_before, "zero simulation time does not run extra group scans")
	for frame in range(60):
		_check(weapon.keep_or_find_target(a, a.global_position, 200.0, 1.0 / 60.0) == a, "live locked target remains immediately available")
	_check(weapon.scans == scan_before, "locked target needs no full group scans")
	var targeting := WeaponModule.new()
	add_child(targeting)
	_check(targeting.keep_or_find_target(null, a.global_position, 200.0, 1.0 / 60.0) == a, "first acquisition stays immediate")
	_check(targeting.keep_or_find_target(b, a.global_position, 200.0, 1.0 / 60.0) == b, "valid target stays locked even with a nearer enemy")
	a.position = Vector2(900, 400)
	var replacement: BasicEnemy
	for frame in range(13):
		replacement = targeting.keep_or_find_target(a, Vector2(400, 400), 200.0, 1.0 / 60.0)
		if replacement != null:
			break
	_check(replacement == b, "out-of-range target is replaced within one search interval")
	a.free()
	_check(weapon.keep_or_find_target(a, Vector2.ZERO, 200.0) == null, "freed target reference is handled safely")
	var clear_guard := WaveManager.new()
	clear_guard._state = WaveManager.State.CLEARING
	clear_guard.set_pending_external_spawns(&"test_storm", 3)
	clear_guard._evaluate_wave_clear()
	_check(not clear_guard.is_completed() and clear_guard.get_remaining_enemy_count() == 3, "pending external spawns prevent premature final clear")
	clear_guard.free()
	if errors.is_empty():
		print("COMBAT_OPTIMIZATION_TEST: PASS")
		get_tree().quit(0)
	else:
		for error in errors:
			push_error("COMBAT_OPTIMIZATION_TEST: " + error)
		get_tree().quit(1)
