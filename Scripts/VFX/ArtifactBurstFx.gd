extends Node2D

## One-shot artifact impact / pulse bursts (Claude sync 97). Load with
## preload(); no class_name on purpose.
##   &"heavy"      dark shock ring with flying grit
##   &"amplifier"  violet spark star
##   &"treant"     leaves bursting outward and a "x2" pop
##   &"treant_flash" green flash at a beam/saw turret's muzzle
##   &"fairy"      pink pulse ring + glittering bolts to `targets` (globals)

var kind: StringName = &"heavy"
var size: float = 4.0
var radius: float = 120.0
var targets: Array = []
var _age: float = 0.0
var _life: float = 0.5
var _bits: Array = []  # [pos, vel, rot]


func _ready() -> void:
	z_index = 6
	_life = {&"heavy": 0.55, &"amplifier": 0.3, &"treant": 0.7, &"treant_flash": 0.35, &"fairy": 0.9}.get(kind, 0.5)
	var n: int = {&"heavy": 10, &"amplifier": 0, &"treant": 9, &"treant_flash": 5, &"fairy": 0}.get(kind, 0)
	for k in range(n):
		var a := TAU * float(k) / float(maxi(n, 1)) + randf() * 0.5
		_bits.append([Vector2.ZERO, Vector2.from_angle(a) * randf_range(60.0, 140.0), randf() * TAU])


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	for bit in _bits:
		bit[1] = (bit[1] as Vector2) * pow(0.05, delta)
		bit[0] = (bit[0] as Vector2) + (bit[1] as Vector2) * delta
		bit[2] = float(bit[2]) + delta * 8.0
	queue_redraw()


func _draw() -> void:
	var k := clampf(_age / _life, 0.0, 1.0)
	var fade := 1.0 - k
	match kind:
		&"heavy":
			var r := size * (2.0 + 9.0 * k)
			draw_circle(Vector2.ZERO, r, Color(0.15, 0.13, 0.12, 0.3 * fade))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(1.0, 0.6, 0.3, 0.6 * fade), 3.0 * fade + 1.0)
			for bit in _bits:
				draw_rect(Rect2(bit[0] - Vector2.ONE * 1.5, Vector2.ONE * 3.0), Color(0.35, 0.3, 0.27, fade))
		&"amplifier":
			for n in range(6):
				var a := TAU * float(n) / 6.0
				draw_line(Vector2.from_angle(a) * (size + 4.0) * (0.5 + 2.0 * k), Vector2.from_angle(a) * (size + 4.0) * (1.5 + 3.5 * k), Color(0.85, 0.7, 1.0, fade), 2.0)
			draw_circle(Vector2.ZERO, (size + 4.0) * (1.0 + k), Color(1.0, 0.9, 1.0, 0.6 * fade))
		&"treant", &"treant_flash":
			draw_circle(Vector2.ZERO, size * (1.5 + 5.0 * k), Color(0.5, 0.95, 0.4, 0.3 * fade))
			for bit in _bits:
				var p: Vector2 = bit[0]
				var a := Vector2.from_angle(float(bit[2])) * 4.5
				draw_colored_polygon(PackedVector2Array([p - a, p + a.orthogonal() * 0.45, p + a, p - a.orthogonal() * 0.45]), Color(0.4, 0.8, 0.3, fade))
			if kind == &"treant":
				draw_string(ThemeDB.fallback_font, Vector2(-10, -14 - 16.0 * k), "x2", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.75, 1.0, 0.55, fade))
		&"fairy":
			var ring := radius * clampf(k * 1.6, 0.0, 1.0)
			draw_arc(Vector2.ZERO, ring, 0.0, TAU, 64, Color(1.0, 0.55, 0.85, 0.65 * fade), 4.0 * fade + 1.0)
			draw_circle(Vector2.ZERO, ring, Color(1.0, 0.6, 0.9, 0.08 * fade))
			for target in targets:
				var p := to_local(target)
				var bolt := clampf(k * 2.2, 0.0, 1.0)
				var tip := p * bolt
				var mid := tip * 0.5 + tip.orthogonal().normalized() * sin(_age * 18.0) * 10.0
				draw_polyline(PackedVector2Array([Vector2.ZERO, mid, tip]), Color(1.0, 0.7, 0.95, 0.8 * fade), 2.0)
				if bolt >= 1.0:
					draw_circle(p, 10.0 * fade + 4.0, Color(1.0, 0.5, 0.85, 0.5 * fade))
					for n in range(4):
						var a := float(n) * PI * 0.5 + _age * 6.0
						draw_line(p + Vector2.from_angle(a) * 4.0, p + Vector2.from_angle(a) * (10.0 + 10.0 * k), Color(1.0, 0.9, 1.0, fade), 1.4)
