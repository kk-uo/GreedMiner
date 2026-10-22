extends Node2D

## The ground bursting open where a treant tears itself out (ForestEnemy
## spawns it on emergence): the earth splits with cracks, dirt clods and
## leaves fly out, a hole stays for a few seconds and fades. World space,
## drawn under the enemies. Presentation only.
## Load with preload(); no class_name on purpose.

const LIFE: float = 4.5
const FADE: float = 1.2
const DIRT := Color("3A2C1E")
const HOLE := Color("2A1E14")
const CLOD := Color("5A4632")
const LEAF := Color("5C8A48")

var size: float = 1.0
var _age: float = 0.0
var _bits: Array = []


static func spawn(parent: Node, at: Vector2, scale_factor: float = 1.0) -> Node2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var fx: Node2D = load("res://Scripts/VFX/ForestEmergeFx.gd").new()
	fx.set("size", scale_factor)
	parent.add_child(fx)
	parent.move_child(fx, 0)
	fx.global_position = at
	return fx


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for k in range(12):
		_bits.append({"a": TAU * float(k) / 12.0 + rng.randf_range(-0.2, 0.2), "d": rng.randf_range(0.8, 1.3), "delay": rng.randf_range(0.0, 0.15), "leaf": k % 3 == 0, "rot": rng.randf() * TAU})


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var s := 17.0 * size
	var open := 1.0 - pow(1.0 - clampf(_age / 0.45, 0.0, 1.0), 3.0)
	var alpha := 1.0 - clampf((_age - (LIFE - FADE)) / FADE, 0.0, 1.0)
	draw_colored_polygon(_blob(Vector2.ZERO, s * 1.7 * open, 3), Color(DIRT, alpha))
	draw_colored_polygon(_blob(Vector2(-1, -1), s * 1.15 * open, 7), Color(HOLE, alpha))
	for k in range(7):
		var a := TAU * float(k) / 7.0 + 0.3
		var dir := Vector2(cos(a), sin(a))
		draw_line(dir * s * 1.0 * open, dir * s * 2.4 * open, Color(HOLE, 0.8 * alpha), maxf(1.5, s * 0.12))
	for bit in _bits:
		var t := clampf((_age - float(bit["delay"])) / 0.6, 0.0, 1.0)
		if t <= 0.0 or t >= 1.0:
			continue
		var dir := Vector2.RIGHT.rotated(float(bit["a"]))
		var p := dir * s * (1.2 + 2.6 * float(bit["d"]) * t) + Vector2(0, -sin(PI * t) * s * 1.8)
		if bit["leaf"]:
			var r := float(bit["rot"]) + t * 6.0
			draw_colored_polygon(PackedVector2Array([p + Vector2(4, 0).rotated(r) * size, p + Vector2(0, 2.2).rotated(r) * size, p + Vector2(-4, 0).rotated(r) * size, p + Vector2(0, -2.2).rotated(r) * size]), Color(LEAF, 1.0 - t))
		else:
			draw_circle(p + Vector2(1.5, 2.0), s * 0.2 * (1.0 - 0.4 * t), Color(0, 0, 0, 0.2))
			draw_circle(p, s * 0.2 * (1.0 - 0.4 * t), CLOD)


func _blob(c: Vector2, r: float, seed: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	for k in range(12):
		var a := TAU * float(k) / 12.0
		p.append(c + Vector2(cos(a), sin(a)) * maxf(r, 0.5) * (1.0 + 0.12 * sin(a * 3.0 + seed) + 0.07 * sin(a * 5.0 + seed * 2.0)))
	return p
