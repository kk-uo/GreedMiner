class_name DragonEnemy
extends RangedEnemy

signal guardian_state_changed(state_name: String)

enum GuardianState { ACTIVE, SLEEPING, AWAKENING, AWAKENED, ENRAGED }

@export var guardian_mode: bool = false
@export_range(0.1, 10.0, 0.1) var awakening_duration: float = 2.0
@export_range(0.0, 1000.0, 1.0) var awakening_projectile_damage: float = 25.0
@export_range(0.0, 1.0, 0.01) var guardian_damage_reduction: float = 0.5

var guardian_state: GuardianState = GuardianState.ACTIVE
var _awakening_left: float = 0.0
var _base_move_speed: float = 0.0
var _base_attack_interval: float = 0.0
var _greed: int = 0
var _enrage_applied: bool = false
var _animation_time: float = 0.0
var _active_collision_layer: int = 0
var _active_monitorable: bool = true

# ------------------------------------------------------------ air moves (Claude sync 94)
## Wave Young / Greater Dragons only (not guardians, hatchlings or the Ancient
## Dragon): they dive in from the sky at speed, flare their wings and roar
## once they reach the fight, then circle-strafe the ship instead of hovering.
## Young Dragons swoop-dash now and then; every FAN_EVERY-th Greater Dragon
## attack is a telegraphed 3-fireball fan. A scheduled Greater Dragon brings
## two Young Dragon escorts that fly in formation until the roar.
enum AirState { NONE, DIVE_IN, FLARE, FIGHT }
const AIR_DIVE_BOOST: float = 2.6
const AIR_DIVE_MIN_TIME: float = 0.9
const AIR_DIVE_LIFT: float = 150.0
const AIR_ESCORT_OFFSETS: Array[Vector2] = [Vector2(-150.0, 150.0), Vector2(-150.0, -150.0)]
const AIR_FAN_EVERY: int = 4
const AIR_FAN_SPREAD: float = 0.32
const AIR_FAN_DAMAGE: float = 0.6
const AIR_FAN_WINDUP: float = 0.6
var _air_state: AirState = AirState.NONE
var _air_time: float = 0.0
var _air_altitude: float = 0.0
var _air_flare_left: float = 0.0
var _air_roar: float = 0.0
var _air_orbit_sign: float = 1.0
var _air_orbit_flip_left: float = 6.0
var _air_swoop_cd: float = 4.0
var _air_swoop_left: float = 0.0
var _air_trail: Array = []  # afterimages: [global position, facing, age]
var _air_trail_tick: float = 0.0
var _air_attack_count: int = 0
var _air_fan_windup: float = 0.0
var _air_leader: Variant = null
var _air_escort_slot: int = 0
var _air_shake_tween: Tween


func _ready() -> void:
	_base_move_speed = move_speed
	_base_attack_interval = attack_interval
	_active_collision_layer = collision_layer
	_active_monitorable = monitorable
	super()
	if guardian_mode:
		damage_reduction = guardian_damage_reduction
		guardian_state = GuardianState.SLEEPING
		# Sleeping hoard guardians are scenery until treasure excavation starts:
		# weapons cannot lock them and stray projectiles cannot collide with them.
		remove_from_group("enemies")
		collision_layer = 0
		monitorable = false
		_stop_attacking()
		guardian_state_changed.emit("SLEEPING")
	if _uses_air_moves():
		_air_orbit_sign = 1.0 if randf() < 0.5 else -1.0
		_air_orbit_flip_left = randf_range(5.0, 9.0)
		_air_swoop_cd = randf_range(2.5, 5.0)
		if has_meta("dragon_nest_hatchling"):
			_air_state = AirState.FIGHT
		else:
			_air_state = AirState.DIVE_IN
			_air_altitude = 1.0
		if enemy_id == &"greater_dragon" and StringName(get_meta("spawn_origin", &"scheduled")) == &"scheduled":
			_air_spawn_escorts.call_deferred()


func _physics_process(delta: float) -> void:
	_animation_time += delta
	if guardian_mode and guardian_state == GuardianState.SLEEPING:
		_stop_attacking()
		queue_redraw()
		return
	if guardian_mode and guardian_state == GuardianState.AWAKENING:
		_stop_attacking()
		_awakening_left = maxf(_awakening_left - delta, 0.0)
		queue_redraw()
		if _awakening_left <= 0.0:
			_fire_awakening_projectile()
			guardian_state = GuardianState.ENRAGED if _enrage_applied else GuardianState.AWAKENED
			guardian_state_changed.emit("ENRAGED" if _enrage_applied else "AWAKENED")
		return
	if _uses_air_moves():
		_air_update_trail(delta)
		_air_roar = maxf(_air_roar - delta * 1.3, 0.0)
		if _air_update_entrance(delta):
			queue_redraw()
			return
	super(delta)
	if _uses_air_moves():
		_air_fight(delta)


func take_damage(damage: float, ignore_damage_reduction: bool = false, count_for_artifact: bool = true, source_weapon: WeaponModule = null) -> void:
	if guardian_mode and guardian_state == GuardianState.SLEEPING:
		return
	super(damage, ignore_damage_reduction, count_for_artifact, source_weapon)


func wake_guardian() -> bool:
	if not guardian_mode or guardian_state != GuardianState.SLEEPING or _is_dying:
		return false
	guardian_state = GuardianState.AWAKENING
	_awakening_left = awakening_duration
	collision_layer = _active_collision_layer
	monitorable = _active_monitorable
	add_to_group("enemies")
	guardian_state_changed.emit("AWAKENING")
	queue_redraw()
	return true


func enrage_guardian() -> bool:
	if not guardian_mode or _enrage_applied or _is_dying:
		return false
	_enrage_applied = true
	_apply_guardian_modifiers()
	if guardian_state == GuardianState.AWAKENED:
		guardian_state = GuardianState.ENRAGED
		guardian_state_changed.emit("ENRAGED")
	return true


func apply_greed(greed: int) -> void:
	_greed = clampi(greed, 0, DragonNestRules.MAX_GREED)
	_apply_guardian_modifiers()


func _apply_guardian_modifiers() -> void:
	move_speed = _base_move_speed * (DragonNestRules.guardian_move_multiplier(_greed) if guardian_mode else 1.0)
	var enrage_multiplier := 0.8 if _enrage_applied else 1.0
	attack_interval = _base_attack_interval * DragonNestRules.attack_interval_multiplier(_greed) * enrage_multiplier
	if is_instance_valid(attack_timer):
		attack_timer.wait_time = attack_interval


func _uses_air_moves() -> bool:
	return not guardian_mode and enemy_id in [&"young_dragon", &"greater_dragon"]


func is_air_entrance_playing() -> bool:
	return _air_state == AirState.DIVE_IN or _air_state == AirState.FLARE


## Dev/test helper: land immediately (no dive, no roar).
func skip_air_entrance() -> void:
	if is_air_entrance_playing():
		_air_state = AirState.FIGHT
		_air_altitude = 0.0


## Returns true while the entrance owns the frame (no base movement/attacks).
func _air_update_entrance(delta: float) -> bool:
	if _air_fan_windup > 0.0:
		_air_fan_windup -= delta
		if _air_fan_windup <= 0.0:
			_air_fire_fan()
	if _air_state == AirState.FLARE:
		_stop_attacking()
		_air_flare_left -= delta
		if _air_flare_left <= 0.0:
			_air_state = AirState.FIGHT
		return true
	if _air_state != AirState.DIVE_IN:
		return false
	_stop_attacking()
	_air_time += delta
	if not is_instance_valid(target_ship) or not target_ship is Ship:
		return true
	var ship := target_ship as Ship
	# Escorts hold formation on their leader until it roars.
	if is_instance_valid(_air_leader) and (_air_leader as DragonEnemy)._air_state == AirState.DIVE_IN:
		var leader := _air_leader as DragonEnemy
		var forward := Vector2.from_angle(leader._facing)
		var offset: Vector2 = AIR_ESCORT_OFFSETS[_air_escort_slot % AIR_ESCORT_OFFSETS.size()]
		var slot := leader.global_position + forward * offset.x + forward.orthogonal() * offset.y
		global_position = global_position.lerp(slot, clampf(delta * 5.0, 0.0, 1.0))
		_facing = leader._facing
		_air_altitude = leader._air_altitude
		_air_add_afterimage(delta)
		return true
	if is_instance_valid(_air_leader):
		# The leader just flared: roar with it.
		_air_begin_flare()
		return true
	var goal := _get_nearest_ship_boundary_world(ship, global_position)
	var distance := global_position.distance_to(goal)
	var stop_distance := attack_range + 120.0
	var distance_alt := clampf((distance - stop_distance) / 420.0, 0.0, 1.0)
	var time_alt := clampf(1.0 - _air_time / AIR_DIVE_MIN_TIME, 0.0, 1.0)
	_air_altitude = maxf(distance_alt, time_alt)
	var direction := global_position.direction_to(goal)
	if direction != Vector2.ZERO:
		_facing = direction.angle()
	if distance > stop_distance:
		var speed := get_effective_move_speed() * (1.6 + AIR_DIVE_BOOST * sqrt(distance_alt))
		global_position += direction * minf(speed * delta, distance - stop_distance)
		_air_add_afterimage(delta)
	if (_air_altitude <= 0.0 and distance <= stop_distance + 1.0) or _air_time > 7.0:
		_air_begin_flare()
	return true


func _air_begin_flare() -> void:
	_air_state = AirState.FLARE
	_air_altitude = 0.0
	_air_flare_left = 0.95 if enemy_id == &"greater_dragon" else 0.6
	_air_roar = 1.0
	if enemy_id == &"greater_dragon":
		_air_shake(7.0, 0.4)


## In range: circle the ship (keeping ~85 % of attack range), now and then
## reverse; Young Dragons swoop-dash along the circle.
func _air_fight(delta: float) -> void:
	if _air_state != AirState.FIGHT or not _is_attacking or is_instance_valid(_mining_target):
		return
	if not is_instance_valid(target_ship) or not target_ship is Ship or _air_fan_windup > 0.0:
		return
	var ship := target_ship as Ship
	var center := ship.to_global(Ship.SHIP_SIZE * 0.5)
	var goal := _get_nearest_ship_boundary_world(ship, global_position)
	var distance := global_position.distance_to(goal)
	var inward := global_position.direction_to(center)
	var speed := get_effective_move_speed()
	_air_swoop_cd -= delta
	if _air_swoop_left > 0.0:
		_air_swoop_left -= delta
		speed *= 4.0
		_air_add_afterimage(delta)
	elif enemy_id == &"young_dragon" and _air_swoop_cd <= 0.0:
		_air_swoop_left = 0.45
		_air_swoop_cd = randf_range(4.5, 7.0)
	_air_orbit_flip_left -= delta
	if _air_orbit_flip_left <= 0.0 and _air_swoop_left <= 0.0:
		_air_orbit_sign = -_air_orbit_sign
		_air_orbit_flip_left = randf_range(5.0, 9.0)
	var radial := clampf(distance - attack_range * 0.85, -40.0, 40.0) * 1.5
	global_position += (inward.orthogonal() * _air_orbit_sign * speed + inward * radial) * delta


func _perform_attack(ship: Ship) -> void:
	if enemy_id == &"greater_dragon" and _uses_air_moves() and _air_state == AirState.FIGHT:
		_air_attack_count += 1
		if _air_attack_count % AIR_FAN_EVERY == 0:
			_air_fan_windup = AIR_FAN_WINDUP
			return
	super(ship)


func _air_fire_fan() -> void:
	if not is_instance_valid(target_ship) or not target_ship is Ship or projectile_scene == null or _is_dying:
		return
	var ship := target_ship as Ship
	var aim := global_position.direction_to(ship.to_global(Ship.SHIP_SIZE * 0.5))
	var spawn_parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	for k in [-1.0, 0.0, 1.0]:
		var projectile := projectile_scene.instantiate() as HostileProjectile
		if projectile == null:
			continue
		var direction := aim.rotated(k * AIR_FAN_SPREAD)
		projectile.direction = direction
		projectile.speed = projectile_speed
		projectile.damage = attack_damage * AIR_FAN_DAMAGE
		projectile.target_ship = ship
		spawn_parent.add_child(projectile)
		projectile.global_position = global_position + direction * projectile_spawn_offset
	_air_roar = maxf(_air_roar, 0.5)


func _air_spawn_escorts() -> void:
	if not is_inside_tree() or _is_dying or get_parent() == null:
		return
	var scene := EnemyCatalog.get_enemy_scene(&"young_dragon")
	if scene == null:
		return
	var forward := Vector2.RIGHT
	if is_instance_valid(target_ship) and target_ship is Ship:
		forward = global_position.direction_to((target_ship as Ship).to_global(Ship.SHIP_SIZE * 0.5))
	_facing = forward.angle()
	for slot in range(AIR_ESCORT_OFFSETS.size()):
		var escort := scene.instantiate() as DragonEnemy
		if escort == null:
			continue
		escort.target_ship = target_ship
		escort.set_meta("dragon_nest_escort", true)
		escort.set_meta("spawn_origin", &"dragon_nest_escort")
		escort._air_leader = self
		escort._air_escort_slot = slot
		get_parent().add_child(escort)
		var offset: Vector2 = AIR_ESCORT_OFFSETS[slot]
		escort.global_position = global_position + forward * offset.x + forward.orthogonal() * offset.y
		escort.apply_greed(_greed)


func _air_add_afterimage(delta: float) -> void:
	_air_trail_tick -= delta
	if _air_trail_tick > 0.0:
		return
	_air_trail_tick = 0.07
	_air_trail.push_front([global_position, _facing, 0.0, _air_altitude])
	if _air_trail.size() > 4:
		_air_trail.pop_back()


func _air_update_trail(delta: float) -> void:
	for item in _air_trail:
		item[2] = float(item[2]) + delta
	while not _air_trail.is_empty() and float(_air_trail[_air_trail.size() - 1][2]) > 0.32:
		_air_trail.pop_back()


func _air_shake(amount: float, duration: float) -> void:
	if not is_instance_valid(target_ship) or not target_ship is Ship:
		return
	var camera: Camera2D = (target_ship as Ship).world_camera
	if camera == null:
		return
	if _air_shake_tween != null and _air_shake_tween.is_valid():
		_air_shake_tween.kill()
	_air_shake_tween = camera.create_tween()
	var steps: int = maxi(int(duration / 0.03), 2)
	for step in range(steps):
		var strength := amount * (1.0 - float(step) / float(steps))
		_air_shake_tween.tween_property(camera, "offset", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.03)
	_air_shake_tween.tween_property(camera, "offset", Vector2.ZERO, 0.03)


func _fire_awakening_projectile() -> void:
	if not is_instance_valid(target_ship):
		return
	var normal_damage := attack_damage
	attack_damage = awakening_projectile_damage
	_perform_attack(target_ship as Ship)
	attack_damage = normal_damage


var _pen := MeshBatch2D.new()


## Painted size (DragonNestArt units): young dragons are big-headed wyrmlings.
func art_radius() -> float:
	return 64.0 if enemy_id == &"greater_dragon" else 40.0


func art_kind() -> StringName:
	return &"great" if enemy_id == &"greater_dragon" else &"wyrm"


func _get_visual_radius() -> float:
	return 70.0 if enemy_id == &"greater_dragon" else 45.0


func get_target_point(_from_world: Vector2) -> Vector2:
	return global_position + Vector2.RIGHT.rotated(_facing) * (art_radius() * 0.35)


func _draw() -> void:
	var sleeping := guardian_mode and guardian_state == GuardianState.SLEEPING
	var warning := guardian_mode and guardian_state == GuardianState.AWAKENING
	var pulse := sin(_animation_time * (12.0 if warning else 5.0))
	DragonNestArt.mono = Palette.HIT_FLASH if _is_flashing() else Color(0, 0, 0, 0)
	if sleeping or warning:
		# Curled up asleep on its throne; eyes snap open while waking.
		var coil_radius := 74.0 if enemy_id == &"greater_dragon" else 46.0
		DragonNestArt.begin(_pen, Transform2D(_facing, Vector2.ZERO))
		DragonNestArt.coiled(_pen, coil_radius, _animation_time, warning)
		DragonNestArt.mono = Color(0, 0, 0, 0)
		_pen.flush_to(self)
		if sleeping:
			for i in range(3):
				var phase := fmod(_animation_time * 0.45 + float(i) / 3.0, 1.0)
				draw_string(ThemeDB.fallback_font, Vector2(coil_radius * 0.3 + phase * 22.0, -coil_radius - phase * 30.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 + phase * 10), Color(0.79, 0.84, 0.91, 1.0 - phase))
		else:
			draw_arc(Vector2.ZERO, coil_radius + 12.0 + pulse * 3.0, 0.0, TAU, 40, Color("ffcf58"), 3.0)
		return
	var R := art_radius()
	var flash := DragonNestArt.mono
	var alt := _air_altitude
	var scale_k := 1.0 + 0.55 * alt
	var lift := Vector2(0.0, -AIR_DIVE_LIFT * alt)
	var flare := _air_state == AirState.FLARE
	var flap_speed := 6.0 if enemy_id == &"greater_dragon" else 9.0
	var opts := {"flap": 16.0, "flap_speed": flap_speed}
	if alt > 0.0:
		# High in the sky: wings swept back, a small far shadow on the ground.
		opts = {"flap": 6.0, "flap_speed": flap_speed * 0.6, "wing_rot": -0.35 * alt, "shadow": false}
		DragonNestArt.begin(_pen, Transform2D.IDENTITY)
		_pen.draw_colored_polygon(DragonNestArt.ellipse(Vector2.ZERO, R * (1.3 - 0.5 * alt), R * (0.7 - 0.28 * alt), 18), Color(0, 0, 0, 0.28 * (1.0 - 0.55 * alt)))
	elif flare:
		# Wings thrown wide, rearing back, jaws open.
		opts = {"flap": 4.0, "flap_speed": 22.0, "wing_rot": 0.5 * _air_roar, "lunge": -0.18 * _air_roar}
	# Afterimages of the dive / swoop.
	for item in _air_trail:
		var fade := 1.0 - float(item[2]) / 0.32
		var item_alt := float(item[3])
		var item_k := 1.0 + 0.55 * item_alt
		DragonNestArt.mono = Color(1.0, 0.72, 0.38, 0.22 * fade)
		DragonNestArt.begin(_pen, Transform2D(float(item[1]), Vector2.ONE * item_k, 0.0, to_local(item[0]) + Vector2(0.0, -AIR_DIVE_LIFT * item_alt)))
		DragonNestArt.dragon(_pen, R, art_kind(), _animation_time, {"flap": 6.0, "shadow": false})
	DragonNestArt.mono = flash
	var mouth := clampf(1.0 - attack_timer.time_left / 0.6, 0.0, 1.0) if _is_attacking and is_instance_valid(attack_timer) else 0.0
	if flare or _air_fan_windup > 0.0:
		mouth = 1.0
	opts["mouth"] = mouth
	if alt <= 0.0:
		# Flying: the ground shadow sits down-right of the body.
		opts["shadow_offset"] = (Vector2(14.0, 22.0) * R / 40.0).rotated(-_facing) + Vector2(-0.2 * R, 0.0)
	DragonNestArt.begin(_pen, Transform2D(_facing, Vector2.ONE * scale_k, 0.0, lift))
	DragonNestArt.dragon(_pen, R, art_kind(), _animation_time, opts)
	DragonNestArt.mono = Color(0, 0, 0, 0)
	_pen.flush_to(self)
	_air_draw_fx(R)
	if guardian_state == GuardianState.ENRAGED:
		draw_arc(Vector2.ZERO, R * 0.75, 0.0, TAU, 32, Color("ff5b36", 0.85), 2.5)



## Roar shockwaves on landing and the Greater Dragon's fan wind-up glow.
func _air_draw_fx(R: float) -> void:
	var mouth := Vector2.from_angle(_facing) * R * 0.95
	if _air_roar > 0.0:
		var k := 1.0 - _air_roar
		for n in range(2):
			var ring := clampf(k * 1.3 - float(n) * 0.25, 0.0, 1.0)
			if ring <= 0.0 or ring >= 1.0:
				continue
			draw_arc(mouth, R * (0.4 + 2.2 * ring), 0.0, TAU, 40, Color(1.0, 0.82, 0.5, 0.5 * (1.0 - ring)), 6.0 * (1.0 - ring) + 1.5)
		if _air_state == AirState.FLARE:
			for n in range(7):
				var a := _facing + (float(n) - 3.0) * 0.22
				var d := Vector2.from_angle(a)
				draw_line(mouth + d * R * (0.4 + 0.6 * k), mouth + d * R * (0.8 + 1.2 * k), Color(1.0, 0.9, 0.7, 0.55 * _air_roar), 2.0)
	if _air_fan_windup > 0.0:
		var k2 := 1.0 - _air_fan_windup / AIR_FAN_WINDUP
		draw_circle(mouth, R * (0.18 + 0.22 * k2), Color(1.0, 0.55, 0.15, 0.35 + 0.4 * k2))
		draw_circle(mouth, R * (0.08 + 0.1 * k2), Color(1.0, 0.95, 0.7, 0.9))
		for k in [-1.0, 0.0, 1.0]:
			var d := Vector2.from_angle(_facing + k * AIR_FAN_SPREAD)
			draw_line(mouth + d * R * 0.3, mouth + d * R * (0.3 + 2.4 * k2), Color(1.0, 0.45, 0.12, 0.3 * k2), 8.0)
