extends Node2D

## Gravity-wave shot of the Knockback module: arc-shaped wavefronts fly from
## the module to the enemy that touched the hull, then burst there into
## violet ripples the size of the knockback splash. World-space, frees itself.
## Load with preload(); no class_name on purpose.

const VIOLET := Color("B69CFF")
const VIOLET_DARK := Color("5B3FD0")
const VIOLET_LIGHT := Color("EEE6FF")
const VOID := Color("120E1C")

const TRAVEL_TIME: float = 0.14
const FRONT_COUNT: int = 4
const FRONT_GAP: float = 0.035
const BURST_TIME: float = 0.42
const RIPPLE_COUNT: int = 3
const RIPPLE_GAP: float = 0.05

var from_point: Vector2
var to_point: Vector2
var burst_radius: float = 64.0

var _age: float = 0.0


static func spawn(parent: Node, from_global: Vector2, to_global: Vector2, radius: float) -> Node2D:
	var wave: Node2D = load("res://Scripts/VFX/GravityWave.gd").new()
	wave.from_point = from_global
	wave.to_point = to_global
	wave.burst_radius = radius
	wave.z_index = 45
	parent.add_child(wave)
	wave.global_position = Vector2.ZERO
	return wave


func _burst_start() -> float:
	return TRAVEL_TIME * 0.7


func _process(delta: float) -> void:
	_age += delta
	if _age > _burst_start() + BURST_TIME + RIPPLE_GAP * RIPPLE_COUNT + 0.05:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	var direction := from_point.direction_to(to_point)
	if direction.length_squared() < 0.0001:
		direction = Vector2.RIGHT
	var normal := direction.orthogonal()

	# Wavefronts: curved arcs bulging toward the target, flying in a train.
	for index in range(FRONT_COUNT):
		var k := (_age - float(index) * FRONT_GAP) / TRAVEL_TIME
		if k < 0.0 or k > 1.15:
			continue
		var travel := clampf(k, 0.0, 1.0)
		var center := from_point.lerp(to_point, 1.0 - pow(1.0 - travel, 2.0))
		var alpha := clampf(1.0 - maxf(k - 0.85, 0.0) / 0.3, 0.0, 1.0) * (1.0 if index == 0 else 0.7)
		var half := lerpf(14.0, 30.0, travel)
		var points := PackedVector2Array()
		for step in range(9):
			var t := float(step) / 8.0 * 2.0 - 1.0
			points.append(center + normal * t * half + direction * (1.0 - t * t) * half * 0.45)
		var width := 5.0 if index == 0 else 3.2
		draw_polyline(points, Color(VIOLET, 0.35 * alpha), width + 4.0)
		draw_polyline(points, Color(VIOLET_LIGHT if index == 0 else VIOLET, alpha), width)

	# Burst at the contact point: a brief dark core and expanding ripples.
	var burst_age := _age - _burst_start()
	if burst_age < 0.0:
		return
	var core := clampf(1.0 - burst_age / 0.12, 0.0, 1.0)
	if core > 0.0:
		draw_circle(to_point, 6.0 + 8.0 * core, Color(VOID, 0.85 * core))
		draw_arc(to_point, 6.0 + 8.0 * core, 0.0, TAU, 32, Color(VIOLET_LIGHT, core), 2.0)
	for index in range(RIPPLE_COUNT):
		var k := (burst_age - float(index) * RIPPLE_GAP) / BURST_TIME
		if k < 0.0 or k >= 1.0:
			continue
		var eased := 1.0 - pow(1.0 - k, 3.0)
		var radius := lerpf(8.0, burst_radius * 1.35, eased)
		var fade := 1.0 - k
		if index == 0:
			draw_circle(to_point, radius, Color(VIOLET, 0.14 * fade))
		draw_arc(to_point, radius, 0.0, TAU, 56, Color(VIOLET, 0.3 * fade), (8.0 if index == 0 else 5.0) * fade + 1.0)
		draw_arc(to_point, radius, 0.0, TAU, 56, Color(VIOLET_LIGHT if index == 0 else VIOLET, 0.9 * fade), (3.0 if index == 0 else 2.0) * fade + 0.6)
