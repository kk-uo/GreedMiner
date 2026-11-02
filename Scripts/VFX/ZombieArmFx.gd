extends Node2D

## Zombie Arm presentation (Claude sync 91). Load with preload(); no
## class_name on purpose.
## mode &"launch": a green ectoplasm puff where the arm leaves the turret.
## mode &"hit": a ghostly hand snaps shut on the target, ooze splatters and a
## few flesh/bone bits fly off.
## mode &"fade": the arm crumbles at the end of its range.

const SKIN_DARK := Color("55733F")
const SKIN := Color("7FA05F")
const OOZE := Color("B9F06A")
const GLOW := Color("9BD45A")
const BONE := Color("EDE3C8")

var mode: StringName = &"hit"
var facing: float = 0.0
var _age: float = 0.0
var _life: float = 0.5
var _bits: Array = []  # {p, v, r, c}


func _ready() -> void:
	z_index = 6
	_life = {&"launch": 0.35, &"hit": 0.55, &"fade": 0.4}.get(mode, 0.5)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count: int = {&"launch": 6, &"hit": 11, &"fade": 7}.get(mode, 6)
	for k in range(count):
		var a := facing + rng.randf_range(-PI, PI) if mode != &"launch" else facing + rng.randf_range(-0.9, 0.9)
		var speed := rng.randf_range(50.0, 150.0) if mode == &"hit" else rng.randf_range(20.0, 60.0)
		var color := OOZE
		if mode == &"hit" and k % 4 == 0:
			color = BONE
		elif mode == &"fade" or k % 3 == 1:
			color = SKIN
		_bits.append({"p": Vector2.ZERO, "v": Vector2.from_angle(a) * speed, "r": rng.randf_range(1.4, 3.2), "c": color})


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	for bit in _bits:
		bit["v"] = (bit["v"] as Vector2) * pow(0.04, delta) + Vector2(0, 90.0 * delta)
		bit["p"] = (bit["p"] as Vector2) + (bit["v"] as Vector2) * delta
	queue_redraw()


func _draw() -> void:
	var k := clampf(_age / _life, 0.0, 1.0)
	var fade := 1.0 - k
	match mode:
		&"launch":
			draw_circle(Vector2.ZERO, 6.0 + 12.0 * k, Color(GLOW, 0.35 * fade))
			draw_arc(Vector2.ZERO, 4.0 + 16.0 * k, 0.0, TAU, 20, Color(OOZE, 0.7 * fade), 2.0)
		&"hit":
			draw_circle(Vector2.ZERO, 8.0 + 16.0 * k, Color(GLOW, 0.28 * fade))
			_draw_grab(clampf(k * 3.0, 0.0, 1.0), fade)
			# Ooze splat ring.
			for n in range(7):
				var a := TAU * float(n) / 7.0 + 0.4
				var d := Vector2.from_angle(a) * (6.0 + 14.0 * k)
				draw_circle(d, 2.6 * fade + 0.6, Color(OOZE, 0.85 * fade))
		&"fade":
			draw_circle(Vector2.ZERO, 5.0 + 6.0 * k, Color(GLOW, 0.25 * fade))
	for bit in _bits:
		draw_circle(bit["p"], (bit["r"] as float) * (0.5 + 0.5 * fade), Color(bit["c"] as Color, fade))


## A big translucent hand that closes from open claws to a fist.
func _draw_grab(close: float, fade: float) -> void:
	draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * (1.25 - 0.2 * close))
	var alpha := 0.75 * fade
	draw_circle(Vector2(-4, 0), 7.5, Color(SKIN_DARK, alpha))
	draw_circle(Vector2(-4, 0), 5.5, Color(SKIN, alpha))
	for spec in [[-0.9, 1.0], [-0.32, 1.0], [0.32, -1.0], [0.9, -1.0]]:
		var a: float = spec[0] * (1.0 - 0.75 * close)
		var bend: float = spec[1] * (0.4 + 1.4 * close)
		var base := Vector2(-4, 0) + Vector2.from_angle(a) * 5.0
		var mid := base + Vector2.from_angle(a) * 6.0
		var tip := mid + Vector2.from_angle(a + bend) * 5.0
		draw_polyline(PackedVector2Array([base, mid, tip]), Color(SKIN_DARK, alpha), 3.6)
		draw_polyline(PackedVector2Array([base, mid, tip]), Color(SKIN, alpha), 2.2)
		draw_circle(tip, 1.1, Color("E8DDAA", alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
