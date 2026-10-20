extends Node2D

## Demon death: it burns away to ash. Two styles at random:
## - BURN: a flare of flame, the charred body glows with ember cracks and
##   shrinks into a smouldering ash heap; embers and ash flakes drift up.
## - BLOW: it turns to a grey ash silhouette at once, which crumbles and is
##   blown away sideways in a stream of flakes, leaving a faint ash smear.
## Lingering embers flicker in the heap, then everything fades.
## One batched draw per frame. Presentation only.
## Load with preload(); no class_name on purpose.

const LIFE: float = 3.4
const CHAR := Color("1E1514")
const ASH := Color("5A5452")
const ASH_LIGHT := Color("8E8784")
const EMBER := Color("FF8A2A")
const EMBER_HOT := Color("FFE08A")
const FIRE_DARK := Color("C2410C")
const SKIN_DARK := Color("7A1A1C")

static var _BATCH := MeshBatch2D.new()

var size: float = 1.0
## -1 random, 0 BURN, 1 BLOW.
var forced_style: int = -1
var _style: int = 0
var _age: float = 0.0
var _wind := Vector2.RIGHT
var _flakes: Array = []
var _body := PackedVector2Array()
var _heap := PackedVector2Array()
var _rng := RandomNumberGenerator.new()


static func spawn(parent: Node, at: Vector2, scale_factor: float = 1.0) -> Node2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var node: Node2D = load("res://Scripts/VFX/AshDeath.gd").new()
	node.set("size", scale_factor)
	parent.add_child(node)
	node.global_position = at
	return node


func _ready() -> void:
	z_index = 1
	_rng.randomize()
	_style = forced_style if forced_style >= 0 else _rng.randi_range(0, 1)
	_wind = Vector2.RIGHT.rotated(_rng.randf_range(-0.6, 0.6) + (PI if _rng.randf() < 0.5 else 0.0))
	for p in range(12):
		var a := TAU * float(p) / 12.0
		_body.append(Vector2(cos(a), sin(a) * 0.85) * _rng.randf_range(0.8, 1.1))
		_heap.append(Vector2(cos(a), sin(a) * 0.75) * _rng.randf_range(0.75, 1.1))
	for k in range(int(22.0 * size)):
		var start := Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf() * 9.0 * size
		_flakes.append({
			"start": start, "delay": _rng.randf_range(0.0, 0.9) if _style == 0 else _rng.randf_range(0.05, 0.7),
			"life": _rng.randf_range(1.0, 1.8), "drift": _rng.randf_range(0.6, 1.4), "phase": _rng.randf() * TAU,
			"ember": _rng.randf() < 0.35, "r": _rng.randf_range(0.8, 1.8) * size,
		})


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var c := _BATCH
	var fade := 1.0 - smoothstep(LIFE - 1.0, LIFE, _age)
	var r0 := 10.0 * size
	if _style == 0:
		_draw_burn(c, r0, fade)
	else:
		_draw_blow(c, r0, fade)
	# Ash flakes and embers drifting up (and downwind).
	for flake in _flakes:
		var t := (_age - float(flake["delay"])) / float(flake["life"])
		if t <= 0.0 or t >= 1.0:
			continue
		var drift := Vector2(sin(_age * 3.0 + float(flake["phase"])) * 3.0, -26.0 * t * float(flake["drift"]) * sqrt(size))
		if _style == 1:
			drift += _wind * 40.0 * t * float(flake["drift"]) * sqrt(size)
		var p: Vector2 = flake["start"] + drift
		var alpha := sin(PI * t)
		if flake["ember"]:
			c.draw_circle(p, float(flake["r"]) * 1.8, Color(EMBER, 0.25 * alpha))
			c.draw_circle(p, float(flake["r"]) * 0.7, Color(EMBER_HOT, alpha))
		else:
			var spin := _age * 4.0 + float(flake["phase"])
			var d := Vector2.RIGHT.rotated(spin) * float(flake["r"]) * 1.2
			c.draw_colored_polygon(PackedVector2Array([p - d, p + Vector2(-d.y, d.x) * 0.6, p + d, p - Vector2(-d.y, d.x) * 0.6]), Color(ASH_LIGHT, 0.85 * alpha))
	c.flush_to(self)


func _draw_burn(c: Object, r0: float, fade: float) -> void:
	# Flame flare.
	if _age < 0.5:
		var t := _age / 0.5
		for p in range(6):
			var a := TAU * float(p) / 6.0 + _age * 3.0
			var tip := Vector2(cos(a), sin(a)) * r0 * 0.6 + Vector2(0, -r0 * 1.4 * (1.0 - t))
			c.draw_colored_polygon(PackedVector2Array([Vector2(cos(a + 0.6), sin(a + 0.6)) * r0 * 0.7, tip, Vector2(cos(a - 0.6), sin(a - 0.6)) * r0 * 0.7]), Color(FIRE_DARK, 0.8 * (1.0 - t)))
		c.draw_circle(Vector2.ZERO, r0 * lerpf(1.2, 1.8, t), Color(EMBER, 0.35 * (1.0 - t)))
	# Charred body shrinking into the heap, ember cracks glowing.
	var shrink := 1.0 - smoothstep(0.1, 1.1, _age)
	var heap_grow := smoothstep(0.5, 1.2, _age)
	if heap_grow > 0.0:
		_draw_heap(c, r0, fade * heap_grow)
	if shrink > 0.0:
		var body_color := SKIN_DARK.lerp(CHAR, smoothstep(0.0, 0.5, _age))
		var xf := Transform2D(0.0, Vector2.ONE * r0 * lerpf(0.4, 1.0, shrink), 0.0, Vector2.ZERO)
		c.draw_colored_polygon(xf * _body, body_color)
		for p in range(5):
			var a := TAU * float(p) / 5.0 + 0.5
			c.draw_line(xf * Vector2.ZERO, xf * (Vector2(cos(a), sin(a)) * 0.8), Color(EMBER, 0.9 * shrink), 1.4)


func _draw_blow(c: Object, r0: float, fade: float) -> void:
	# Grey ash statue that crumbles away downwind.
	var crumble := smoothstep(0.15, 1.0, _age)
	c.draw_colored_polygon(Transform2D(_wind.angle(), Vector2(r0 * 2.2, r0 * 0.7) * smoothstep(0.2, 1.0, _age), 0.0, _wind * r0 * 1.4 * crumble) * _heap, Color(ASH, 0.35 * fade))
	if crumble < 1.0:
		var xf := Transform2D(0.0, Vector2.ONE * r0 * (1.0 - 0.3 * crumble), 0.0, _wind * r0 * 0.5 * crumble)
		c.draw_colored_polygon(xf * _body, Color(ASH, 1.0 - crumble))
		c.draw_colored_polygon(Transform2D(0.0, Vector2.ONE * r0 * 0.6 * (1.0 - 0.3 * crumble), 0.0, Vector2(-r0 * 0.15, -r0 * 0.15) + _wind * r0 * 0.5 * crumble) * _body, Color(ASH_LIGHT, 1.0 - crumble))
		# Two last glowing eyes that wink out.
		if _age < 0.4:
			for side in [-1.0, 1.0]:
				c.draw_circle(Vector2(r0 * 0.4, side * r0 * 0.25), r0 * 0.12, Color(EMBER_HOT, 1.0 - _age / 0.4))
	_draw_heap(c, r0 * 0.6, fade * smoothstep(0.3, 1.0, _age))


## Smouldering ash heap with embers flickering in it.
func _draw_heap(c: Object, r0: float, alpha: float) -> void:
	var xf := Transform2D(0.0, Vector2.ONE * r0 * 0.9, 0.0, Vector2.ZERO)
	c.draw_colored_polygon(xf * _heap, Color(CHAR, 0.85 * alpha))
	c.draw_colored_polygon(Transform2D(0.0, Vector2.ONE * r0 * 0.6, 0.0, Vector2(-r0 * 0.15, -r0 * 0.15)) * _heap, Color(ASH, alpha))
	for k in range(4):
		var a := float(k) * 1.9 + 0.3
		var glow := maxf(sin(_age * 5.0 + float(k) * 1.3), 0.0)
		c.draw_circle(Vector2(cos(a), sin(a) * 0.7) * r0 * 0.45, r0 * 0.09, Color(EMBER, glow * alpha))
