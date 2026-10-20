extends Node2D

## Lit dynamite lobbed by a Goblin Engineer. Flies in an arc to the point on
## the hull it was aimed at, then explodes: damage to the ship only (a small
## ship-only EnemyExplosion), the thrower's friends are not hurt by it.

const EXPLOSION := preload("res://Scripts/VFX/EnemyExplosion.gd")

var target_ship: Node2D
var damage: float = 20.0
var flight_time: float = 0.7
var arc_height: float = 46.0
var blast_radius: float = 26.0

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _age: float = 0.0
var _spin_speed: float = 0.0


## from/to in world space.
func launch(from: Vector2, to: Vector2) -> void:
	_from = from
	_to = to
	global_position = from
	_spin_speed = randf_range(9.0, 13.0) * (1.0 if randf() < 0.5 else -1.0)


func _process(delta: float) -> void:
	_age += delta
	var k: float = clampf(_age / maxf(flight_time, 0.01), 0.0, 1.0)
	global_position = _from.lerp(_to, k)
	if k >= 1.0:
		_explode()
		return
	queue_redraw()


func _explode() -> void:
	set_process(false)
	var parent := get_parent()
	var blast := EXPLOSION.spawn(parent, global_position, blast_radius, damage, target_ship, null, false)
	if blast == null and is_instance_valid(target_ship) and target_ship is Ship:
		(target_ship as Ship).take_damage(damage)
	queue_free()


func _draw() -> void:
	var k: float = clampf(_age / maxf(flight_time, 0.01), 0.0, 1.0)
	var height: float = sin(k * PI) * arc_height
	# Drawn raised above its ground position; the shadow stays on the ground.
	draw_set_transform(Vector2(0.0, -height), 0.0, Vector2.ONE)
	GoblinVisual.draw_dynamite(self, _age * _spin_speed, Palette.SHADOW_OFFSET * 0.6 + Vector2(0.0, height), _age)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
