extends Node2D

## Optional brief leaves and soil burst for a rising treant. No persistent
## hole, dark disk or crack is drawn after the tree leaves its origin.
## Load with preload(); no class_name on purpose.

const LIFE: float = 0.75
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
