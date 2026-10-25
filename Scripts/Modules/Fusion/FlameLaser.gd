class_name FlameLaser
extends FusionWeapon

## Single-target ramping beam. Five damage ticks make the next tick double:
## 0.5 s at the default 10 ticks/s, proportionally sooner with fire-rate buffs.
@export_range(0.01, 10.0, 0.01) var doubling_interval: float = 0.5
@export_range(1.0, 100000.0, 1.0) var maximum_tick_damage: float = 500.0

const MAX_TICKS_PER_FRAME: int = 64
var _charged_target: BasicEnemy
var _hits_on_target: int = 0
var _doublings: int = 0
var _last_fire_rate: float = 0.0


func _process(delta: float) -> void:
	_visual_rotation = fmod(_visual_rotation + delta * 8.0, TAU)
	queue_redraw()
	if assembly_mode:
		_reset_charge()
		_deactivate()
		return

	var effective_range := get_modified_attack_range(attack_range)
	var aim_position: Vector2
	var manual := is_manual_control_active()
	if manual:
		aim_position = get_manual_aim_world_position()
		if not has_valid_manual_aim(_turret.global_position):
			_reset_charge()
			_deactivate()
			return
	else:
		current_target = keep_or_find_target(current_target, _muzzle.global_position, effective_range, delta)
		if not is_instance_valid(current_target):
			_reset_charge()
			_deactivate()
			return
		aim_position = current_target.get_target_point(global_position)

	rotate_turret_toward(_turret, aim_position, rotation_speed, delta)
	if manual:
		current_target = _find_manual_target(effective_range)
	if current_target != _charged_target:
		_reset_charge()
		_charged_target = current_target
	if get_aim_error(_turret, aim_position) > maxf(deg_to_rad(aim_tolerance), 0.001):
		if _beam != null:
			_beam.hide()
		return

	_update_target_beam(effective_range)
	if not is_instance_valid(current_target) or current_target.is_dying():
		return

	var rate := get_fire_rate()
	if rate <= 0.0:
		return
	if _last_fire_rate > 0.0 and not is_equal_approx(rate, _last_fire_rate):
		_cooldown *= _last_fire_rate / rate
	_last_fire_rate = rate
	_cooldown -= delta
	var ticks := 0
	while _cooldown <= 0.0 and is_instance_valid(current_target) and not current_target.is_dying():
		fire()
		_cooldown += 1.0 / rate
		ticks += 1
		if ticks >= MAX_TICKS_PER_FRAME:
			# Prevent a stalled frame from creating an unbounded damage backlog.
			_cooldown = 1.0 / rate
			break


func fire() -> void:
	if not is_instance_valid(current_target) or current_target.is_dying():
		return
	_play_attack_sound()
	if _sound != null:
		# The searing hum climbs as the damage doubles.
		_sound.pitch_scale = 1.0 + 0.07 * float(mini(_doublings, 8))
	var base := maxf(get_damage(), 0.0)
	var tick_damage := minf(base * pow(2.0, mini(_doublings, 30)), maximum_tick_damage)
	current_target.take_damage(tick_damage, false, true, self)
	_hits_on_target += 1
	var hits_per_double := maxi(roundi(doubling_interval / maxf(attack_interval, 0.001)), 1)
	if _hits_on_target % hits_per_double == 0:
		_doublings = mini(_doublings + 1, 30)


func _reset_charge() -> void:
	_charged_target = null
	_hits_on_target = 0
	_doublings = 0
	_cooldown = 0.0
	_last_fire_rate = 0.0


func _update_target_beam(effective_range: float) -> void:
	if _beam == null:
		return
	_beam.width = get_modified_projectile_range(beam_width)
	var visible_length := effective_range
	if is_instance_valid(current_target) and not current_target.is_dying():
		visible_length = minf(_muzzle.global_position.distance_to(current_target.get_target_point(global_position)), effective_range)
	_beam.points = PackedVector2Array([Vector2.ZERO, Vector2(visible_length, 0.0)])
	_beam.show()


## Manual aim chooses the nearest enemy touched by this narrow beam. Other
## enemies along the same line receive no damage and cannot advance the ramp.
func _find_manual_target(effective_range: float) -> BasicEnemy:
	var width := get_modified_projectile_range(beam_width)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(effective_range, width)
	var direction := Vector2.RIGHT.rotated(_muzzle.global_rotation)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(_muzzle.global_rotation, _muzzle.global_position + direction * effective_range * 0.5)
	query.collision_mask = 1
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var nearest: BasicEnemy
	var nearest_distance := INF
	for result in get_world_2d().direct_space_state.intersect_shape(query, 256):
		var enemy := result.get("collider") as BasicEnemy
		if enemy == null or enemy.is_dying() or not enemy.is_in_group(&"enemies"):
			continue
		var distance := _muzzle.global_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest
