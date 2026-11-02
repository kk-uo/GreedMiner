extends Node2D

## Presentation (Claude sync 97): a child of one bullet/shell that shows which
## magic artifact shaped it. Reads the projectile's `direction` and
## `projectile_range`; when the projectile is freed it leaves an impact burst.
## Load with preload(); no class_name on purpose.
##   &"amplifier"  violet arcs crackling round the shot
##   &"fast"       cyan speed streaks behind it
##   &"slow"       a ticking amber clock ring and drifting sand grains
##   &"heavy"      red-hot core, smoke trail; heavy shock ring on impact
##   &"magnify"    a glass lens rim with a travelling glint
##   &"treant"     (empowered shot) green glow and a trail of leaves

const BURST := preload("res://Scripts/VFX/ArtifactBurstFx.gd")
const HISTORY: int = 9

var kind: StringName = &"fast"
var _t: float = 0.0
var _history: Array = []  # [global position, age]
var _tick: float = 0.0
var _seed: float = 0.0


func _ready() -> void:
	_seed = randf() * 100.0
	z_index = -1 if kind in [&"slow", &"heavy", &"treant", &"fast"] else 1
	var host := get_parent()
	if host != null:
		host.tree_exiting.connect(_on_host_exiting, CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	_t += delta
	for item in _history:
		item[1] = float(item[1]) + delta
	_tick -= delta
	if _tick <= 0.0 and kind in [&"slow", &"heavy", &"treant"]:
		_tick = 0.035
		_history.push_front([global_position, 0.0])
		if _history.size() > HISTORY:
			_history.pop_back()
	queue_redraw()


func _radius() -> float:
	var host := get_parent()
	var r: Variant = host.get("projectile_range") if host != null else null
	return maxf(float(r) if r != null else 4.0, 2.0)


func _dir() -> Vector2:
	var host := get_parent()
	var d: Variant = host.get("direction") if host != null else null
	return (d as Vector2).normalized() if d is Vector2 and (d as Vector2) != Vector2.ZERO else Vector2.RIGHT


func _draw() -> void:
	var r := _radius()
	var d := _dir()
	var side := d.orthogonal()
	match kind:
		&"fast":
			draw_circle(Vector2.ZERO, r * 1.7, Color(0.5, 0.9, 1.0, 0.22))
			for k: float in [-1.0, 0.0, 1.0]:
				var start := -d * r * 1.4 + side * k * r * 0.8
				var length := r * 3.0 + 16.0 + 6.0 * sin(_t * 30.0 + k * 2.0)
				draw_line(start, start - d * length, Color(0.75, 0.95, 1.0, 0.55 - absf(k) * 0.15), 1.6)
		&"slow":
			for item in _history:
				var age := float(item[1])
				var p := to_local(item[0]) + Vector2(sin(age * 9.0 + _seed) * 3.0, age * 14.0)
				draw_circle(p, maxf(r * 0.35 * (1.0 - age * 2.0), 0.6), Color(0.95, 0.75, 0.35, 0.8 * (1.0 - age * 2.5)))
			var ring := r * 2.3
			draw_arc(Vector2.ZERO, ring, 0.0, TAU, 20, Color(1.0, 0.78, 0.38, 0.45), 1.4)
			for k in range(4):
				var a := TAU * float(k) / 4.0
				draw_line(Vector2.from_angle(a) * ring * 0.8, Vector2.from_angle(a) * ring, Color(1.0, 0.85, 0.5, 0.6), 1.2)
			draw_line(Vector2.ZERO, Vector2.from_angle(_t * 2.5) * ring * 0.75, Color(1.0, 0.9, 0.6, 0.75), 1.4)
		&"heavy":
			for item in _history:
				var age := float(item[1])
				draw_circle(to_local(item[0]), r * (0.7 + age * 3.0), Color(0.18, 0.16, 0.16, 0.35 * (1.0 - age * 3.0)))
			draw_circle(Vector2.ZERO, r * 1.9, Color(1.0, 0.35, 0.1, 0.22))
			draw_circle(d * r * 0.5, r * 0.7, Color(1.0, 0.55, 0.2, 0.55))
		&"magnify":
			var lens := r * 2.1
			draw_arc(Vector2.ZERO, lens, 0.0, TAU, 28, Color(0.85, 0.95, 1.0, 0.5), 1.6)
			draw_arc(Vector2.ZERO, lens, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, 0.85), 2.4)
			var g := Vector2.from_angle(_t * 4.0 + _seed) * lens
			draw_line(g - Vector2(3, 0), g + Vector2(3, 0), Color.WHITE, 1.4)
			draw_line(g - Vector2(0, 3), g + Vector2(0, 3), Color.WHITE, 1.4)
		&"amplifier":
			draw_circle(Vector2.ZERO, r * 2.2 + 4.0, Color(0.7, 0.45, 1.0, 0.18))
			var frame := int(_t * 20.0)
			for k in range(3):
				var h := fposmod(sin(float(frame * 3 + k) * 12.9898 + _seed) * 43758.5453, 1.0)
				var a0 := TAU * (float(k) / 3.0 + h * 0.3)
				var pts := PackedVector2Array()
				for n in range(4):
					var a := a0 + float(n) * 0.45
					var jitter := 1.0 + 0.35 * sin(float(frame + n * 5 + k) * 7.1)
					pts.append(Vector2.from_angle(a) * (r * 2.2 + 5.0) * jitter)
				draw_polyline(pts, Color(0.85, 0.7, 1.0, 0.85), 1.3)
		&"treant":
			draw_circle(Vector2.ZERO, r * 2.4 + 4.0, Color(0.45, 0.9, 0.35, 0.25))
			draw_circle(Vector2.ZERO, r * 1.3, Color(0.7, 1.0, 0.55, 0.35))
			for i in range(_history.size()):
				var item: Array = _history[i]
				var age := float(item[1])
				if i % 2 == 1:
					continue
				var p := to_local(item[0]) + side * sin(age * 10.0 + float(i)) * 4.0
				_leaf(p, r * 0.9 + 2.0, age * 8.0 + float(i), Color(0.4, 0.8, 0.3, 0.9 * (1.0 - age * 3.0)))


func _leaf(p: Vector2, size: float, spin: float, color: Color) -> void:
	var a := Vector2.from_angle(spin) * size
	var b := a.orthogonal() * 0.45
	draw_colored_polygon(PackedVector2Array([p - a, p + b, p + a, p - b]), color)


func _on_host_exiting() -> void:
	var host := get_parent()
	if host == null or not host.is_queued_for_deletion() or kind in [&"fast", &"slow", &"magnify"]:
		return
	var parent := host.get_parent()
	if parent == null or not parent.is_inside_tree():
		return
	var fx := BURST.new()
	fx.kind = kind
	fx.size = _radius()
	parent.add_child.call_deferred(fx)
	fx.set_deferred("global_position", global_position)
