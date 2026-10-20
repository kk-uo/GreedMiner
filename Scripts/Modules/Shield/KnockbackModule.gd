class_name KnockbackModule
extends ShieldModule

## Reactive hull defense. Activation is requested only by BasicEnemy at its
## authoritative pre-attack point; this module never scans proximity by frame.

@export_group("Knockback")
@export_range(0.0, 1000.0, 1.0) var trigger_range: float = 64.0
@export_range(0.0, 1000.0, 1.0) var splash_radius: float = 64.0
@export_range(0.0, 1000.0, 1.0) var knockback_distance: float = 100.0
@export_range(0.0, 10000.0, 1.0) var knockback_damage: float = 25.0
@export_range(0.0, 60.0, 0.1) var cooldown: float = 2.0

var _cooldown_remaining: float = 0.0

const GravityWave := preload("res://Scripts/VFX/GravityWave.gd")
const VIOLET := Color("B69CFF")
const VIOLET_DARK := Color("5B3FD0")
const VIOLET_LIGHT := Color("EEE6FF")
const VOID := Color("120E1C")
## Idle gravity ripple period around the module (seconds).
const IDLE_RIPPLE_PERIOD: float = 1.4

var _anim_time: float = 0.0
var _ring_spin: float = 0.0
## Seconds since the last activation (drives the core flash / ring spin-up).
var _fire_age: float = 99.0


func get_chip_module_kind() -> StringName:
	return &"knockback"


func get_research_target_id() -> StringName:
	return &"knockback_module"


func get_effective_damage() -> float:
	return get_modified_explosion_damage(calculate_chip_stat(&"shockwave_damage", knockback_damage))


func get_effective_frequency() -> float:
	return calculate_chip_stat(&"knockback_frequency", 0.0 if cooldown <= 0.0 else 1.0 / cooldown)


func get_effective_cooldown() -> float:
	var frequency := get_effective_frequency()
	return 0.0 if frequency <= 0.0 else 1.0 / frequency


func get_effective_trigger_range() -> float:
	return calculate_chip_stat(&"trigger_range", trigger_range)


func get_effective_splash_radius() -> float:
	return calculate_chip_stat(&"splash_radius", splash_radius)


func _process(delta: float) -> void:
	if module_active:
		_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	_anim_time += delta
	_fire_age += delta
	var ready := 1.0 if _cooldown_remaining <= 0.0 else 0.35
	_ring_spin += delta * (0.8 * ready + 9.0 * clampf(1.0 - _fire_age / 0.5, 0.0, 1.0))
	queue_redraw()


## Returns true only when this module successfully activates and the caller
## must cancel the pending enemy attack before damage is applied.
func try_interrupt_attack(trigger_enemy: BasicEnemy, ship: Ship) -> bool:
	if not module_active or _cooldown_remaining > 0.0:
		return false
	if not _is_eligible_enemy(trigger_enemy) or not is_instance_valid(ship):
		return false
	var hull_distance := ship.get_distance_to_hull(
		trigger_enemy.global_position,
		trigger_enemy.get_collision_radius()
	)
	if hull_distance > get_effective_trigger_range():
		return false

	_activate(trigger_enemy, ship)
	_cooldown_remaining = get_effective_cooldown()
	return true


func _activate(trigger_enemy: BasicEnemy, ship: Ship) -> void:
	_play_gravity_wave(trigger_enemy.global_position)
	var affected: Dictionary = {}
	for enemy in _query_overlapping_enemies(trigger_enemy.global_position):
		if _is_eligible_enemy(enemy):
			affected[enemy.get_instance_id()] = enemy
	# The triggering collider must always be included, even before the next
	# physics synchronization point.
	affected[trigger_enemy.get_instance_id()] = trigger_enemy

	for value in affected.values():
		var enemy := value as BasicEnemy
		if not is_instance_valid(enemy) or enemy.is_dying():
			continue
		# This finalized module stat is exact effect damage; armor continues to
		# apply normally to every caller that does not request this bypass.
		enemy.take_damage(get_effective_damage(), true)
		if is_instance_valid(enemy) and not enemy.is_dying():
			_knock_enemy_away(enemy, ship)


## Circle-overlap query uses real physics shapes rather than center distance.
func _query_overlapping_enemies(center: Vector2) -> Array[BasicEnemy]:
	var result: Array[BasicEnemy] = []
	if not is_inside_tree():
		return result
	var circle := CircleShape2D.new()
	circle.radius = get_effective_splash_radius()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, center)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 256):
		var enemy := hit.get("collider") as BasicEnemy
		if enemy != null:
			result.append(enemy)
	return result


func _is_eligible_enemy(enemy: BasicEnemy) -> bool:
	return (
		enemy != null
		and is_instance_valid(enemy)
		and not enemy.is_dying()
		and enemy.enemy_tier != BasicEnemy.EnemyTier.BOSS
		and enemy.enemy_tier in [
			BasicEnemy.EnemyTier.COMMON,
			BasicEnemy.EnemyTier.LARGE,
		]
	)


func _knock_enemy_away(enemy: BasicEnemy, ship: Ship) -> void:
	var ship_center := ship.to_global(Ship.SHIP_SIZE * 0.5)
	var direction := ship_center.direction_to(enemy.global_position)
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	var destination := enemy.global_position + direction * knockback_distance
	var battlefield := ship.get_parent().get_node_or_null("Battlefield") as Battlefield
	if battlefield != null:
		var bounds := battlefield.get_world_bounds()
		var radius := enemy.get_collision_radius()
		destination.x = clampf(destination.x, bounds.position.x + radius, bounds.end.x - radius)
		destination.y = clampf(destination.y, bounds.position.y + radius, bounds.end.y - radius)
	enemy.global_position = _collision_safe_destination(enemy, destination)


## Sweeps toward the requested point in short steps and stops before a solid
## PhysicsBody2D. Other enemies are Areas and intentionally do not block the
## radial displacement; the battlefield bounds are applied by the caller.
func _collision_safe_destination(enemy: BasicEnemy, destination: Vector2) -> Vector2:
	var collision := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null or not enemy.is_inside_tree():
		return destination
	var start := enemy.global_position
	var distance := start.distance_to(destination)
	var steps := maxi(1, ceili(distance / 10.0))
	var last_clear := start
	for index in range(1, steps + 1):
		var candidate := start.lerp(destination, float(index) / float(steps))
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = collision.shape
		query.transform = Transform2D(enemy.global_rotation, candidate)
		query.collision_mask = 0xFFFFFFFF
		query.collide_with_areas = false
		query.collide_with_bodies = true
		if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			break
		last_clear = candidate
	return last_clear


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


# ==========================================
# Visuals: gravity core with gyroscope rings, gravity-wave shot
# ==========================================

func _play_gravity_wave(target: Vector2) -> void:
	_fire_age = 0.0
	if not is_inside_tree():
		return
	var host := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	GravityWave.spawn(host, global_position, target, get_effective_splash_radius())


func _draw() -> void:
	var shadow := Palette.local_shadow_offset(self)
	var ready := _cooldown_remaining <= 0.0
	var flash := clampf(1.0 - _fire_age / 0.3, 0.0, 1.0)

	# Faint idle gravity ripples while the module is ready.
	if ready:
		for index in range(2):
			var k := fposmod(_anim_time / IDLE_RIPPLE_PERIOD + float(index) * 0.5, 1.0)
			draw_arc(Vector2.ZERO, lerpf(16.0, 36.0, k), 0.0, TAU, 40, Color(VIOLET, 0.35 * (1.0 - k)), 1.4)

	var plate := Rect2(-22.0, -22.0, 44.0, 44.0)
	Palette.draw_rounded_rect(self, Rect2(plate.position + shadow * 0.6, plate.size), 6.0, Palette.SHADOW_COLOR)
	Palette.draw_rounded_rect(self, plate, 6.0, Palette.SHIP_PART_EDGE)
	Palette.draw_rounded_rect(self, Rect2(-22.0, -22.0, 42.0, 41.0), 6.0, Palette.SHIP_PART)

	draw_circle(shadow * 0.3, 18.0, Color(0.0, 0.0, 0.0, 0.22))
	draw_circle(Vector2.ZERO, 18.0, Palette.MECH)
	draw_circle(Vector2(-1.0, -1.0), 16.0, Palette.MECH_LIGHT)

	# Three gyroscope rings around the core; dimmer while recharging.
	var ring_color := VIOLET.lerp(VIOLET_LIGHT, flash)
	ring_color.a = 1.0 if ready else 0.45
	for index in range(3):
		_draw_ellipse(14.5, 5.8, _ring_spin * (1.0 + 0.25 * float(index)) + TAU * float(index) / 6.0, ring_color, 1.5)

	# Gravity core.
	draw_circle(Vector2.ZERO, 7.5 + 2.5 * flash, Color(VIOLET_DARK, 1.0))
	draw_circle(Vector2.ZERO, 6.0 + 1.5 * flash, VOID)
	draw_circle(Vector2(-2.0, -2.0), 1.6, VIOLET_LIGHT)
	if flash > 0.0:
		draw_circle(Vector2.ZERO, 12.0 + 10.0 * (1.0 - flash), Color(VIOLET, 0.35 * flash))


func _draw_ellipse(rx: float, ry: float, angle: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in range(33):
		var t := TAU * float(index) / 32.0
		points.append(Vector2(cos(t) * rx, sin(t) * ry).rotated(angle))
	draw_polyline(points, color, width, true)
