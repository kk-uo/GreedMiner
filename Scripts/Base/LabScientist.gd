class_name LabScientist
extends Node2D

## Dwarf scientist idling at the research lab door (style A, code-drawn).
##
## White lab coat, white beard, orange-rimmed goggles. Cycles at random through
## small idle acts: reading a blueprint, tinkering a gadget with a wrench
## (sparks), looking around, and the gadget going "poof" (black smoke).

enum Act { BLUEPRINT, TINKER, LOOK, POOF }

## Direction the scientist faces when idle (radians).
var base_facing: float = 0.0

var _act: Act = Act.BLUEPRINT
var _act_time: float = 0.0
var _act_length: float = 3.0
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()

const COAT := Color("F2EAD9")
const COAT_SHADE := Color("C2B7A3")
const BLUEPRINT := Color("2F4A5E")


func _ready() -> void:
	_rng.randomize()
	scale = Vector2.ONE * 1.6
	_start(Act.BLUEPRINT)


func _process(delta: float) -> void:
	_time += delta
	_act_time += delta
	if _act_time >= _act_length:
		_next_act()
	queue_redraw()


func _next_act() -> void:
	# Mostly calm acts; the "poof" only ever follows tinkering.
	match _act:
		Act.TINKER:
			_start(Act.POOF if _rng.randf() < 0.45 else Act.BLUEPRINT)
		_:
			var roll := _rng.randf()
			_start(Act.TINKER if roll < 0.35 else (Act.LOOK if roll < 0.65 else Act.BLUEPRINT))


func _start(act: Act) -> void:
	_act = act
	_act_time = 0.0
	match act:
		Act.BLUEPRINT: _act_length = _rng.randf_range(2.5, 4.0)
		Act.TINKER: _act_length = _rng.randf_range(1.8, 2.6)
		Act.LOOK: _act_length = 1.8
		Act.POOF: _act_length = 1.2


## Everything below records into one shared batch and is submitted as a
## single draw command per frame.
static var _BATCH := MeshBatch2D.new()
var _pen: Object = self

func _draw() -> void:
	_pen = _BATCH
	_paint()
	_BATCH.flush_to(self)
	_pen = self


func _paint() -> void:
	var t := _act_time / _act_length
	var bob := sin(_time * 2.2) * 0.4
	var head_turn := 0.0
	if _act == Act.LOOK:
		head_turn = -deg_to_rad(55.0) * sin(PI * clampf(t, 0.0, 1.0))
	if _act == Act.POOF:
		bob -= 3.0 * maxf(0.0, 1.0 - t * 3.0)
	if _act == Act.TINKER:
		bob += sin(_time * 18.0) * 0.4

	_pen.draw_set_transform(Vector2(4.0, 5.0), 0.0, Vector2.ONE)
	_pen.draw_circle(Vector2.ZERO, 9.0, Palette.SHADOW_COLOR)

	_pen.draw_set_transform(Vector2(0.0, bob), base_facing, Vector2.ONE)
	_pen.draw_colored_polygon(_coat(8.5, Vector2.ZERO), COAT_SHADE)
	_pen.draw_colored_polygon(_coat(7.6, Vector2(-0.8, -1.0)), COAT)
	_pen.draw_rect(Rect2(-2.0, -8.5, 4.0, 17.0), Palette.MECH)

	if _act == Act.BLUEPRINT or _act == Act.LOOK:
		_pen.draw_line(Vector2(2, 5), Vector2(8, 5), Palette.SHIP_BODY, 3.5)
		_pen.draw_set_transform(Vector2(0.0, bob) + Vector2(13, 2).rotated(base_facing), base_facing + deg_to_rad(8.0), Vector2.ONE)
		Palette.draw_rounded_rect(_pen, Rect2(-5, -7, 10, 14), 1.5, Palette.MECH)
		Palette.draw_rounded_rect(_pen, Rect2(-4, -6, 8, 12), 1.0, BLUEPRINT)
		for line_y in [-3.5, -0.5, 2.5]:
			_pen.draw_line(Vector2(-2.5, line_y), Vector2(2.5, line_y), Palette.COBALT_LIGHT, 0.8)
		_pen.draw_set_transform(Vector2(0.0, bob), base_facing, Vector2.ONE)
	else:
		# Gadget on the ground in front, wrench in hand.
		Palette.draw_rounded_rect(_pen, Rect2(12, -5, 10, 10), 2.0, Palette.MECH)
		Palette.draw_rounded_rect(_pen, Rect2(14, -3, 6, 6), 1.0, Palette.MECH_LIGHT)
		var blink := 1.0 if fmod(_time * 6.0, 1.0) < 0.5 else 0.4
		_pen.draw_circle(Vector2(17, 0), 1.6, Color(Palette.ACCENT, blink))
		var wiggle := sin(_time * 14.0) * 0.12 if _act == Act.TINKER else 0.0
		var hand := Vector2(10, 3)
		var tip := hand + Vector2(6, -2).rotated(wiggle)
		_pen.draw_line(Vector2(2, 5), hand, Palette.SHIP_BODY, 3.5)
		_pen.draw_line(hand - Vector2(1, 0), tip, Palette.UI_MUTED, 2.2)
		_pen.draw_arc(tip, 2.0, 0.0, TAU, 12, Palette.UI_MUTED, 1.5)
		if _act == Act.TINKER and fmod(_time * 7.0, 1.0) < 0.6:
			for spark in [Vector3(19, -7, 1.4), Vector3(23, -3, 1.1), Vector3(21, -9.5, 0.9)]:
				var c := Vector2(spark.x, spark.y)
				var r: float = spark.z
				_pen.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.6), c + Vector2(r * 0.5, 0), c + Vector2(0, r * 1.6), c + Vector2(-r * 0.5, 0)]), Palette.GOLD)

	_pen.draw_colored_polygon(PackedVector2Array([Vector2(3, -4.5), Vector2(11, 0), Vector2(3, 4.5)]), Palette.SHIP_BODY)

	# Head (turns on its own while looking around).
	_pen.draw_set_transform(Vector2(0.0, bob), base_facing + head_turn, Vector2.ONE)
	_pen.draw_circle(Vector2(-0.5, 0), 6.0, Palette.SHIP_BODY)
	_pen.draw_circle(Vector2(-1.5, -1), 4.4, Color.WHITE)
	for gy in [-2.6, 2.6]:
		_pen.draw_circle(Vector2(3.2, gy), 2.2, Palette.UI_PANEL)
		_pen.draw_arc(Vector2(3.2, gy), 2.2, 0.0, TAU, 12, Palette.ACCENT, 1.0)

	if _act == Act.POOF:
		_pen.draw_set_transform(Vector2(0.0, bob), base_facing, Vector2.ONE)
		var grow := clampf(t * 1.6, 0.0, 1.0)
		var fade := 1.0 - clampf((t - 0.5) * 2.0, 0.0, 1.0)
		var puffs := [Vector3(19, -6, 4.0), Vector3(23, -11, 5.5), Vector3(17, -14, 4.5)]
		for k in range(puffs.size()):
			var p: Vector3 = puffs[k]
			var center := Vector2(p.x, p.y - 6.0 * t)
			var r := p.z * (0.5 + 0.7 * grow)
			_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(6, r, float(k)), center), Color(ThrusterFX.SMOKE, 0.75 * fade))
			_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(6, r * 0.5, float(k)), center + Vector2(-r * 0.22, -r * 0.28)), Color(ThrusterFX.SMOKE_LIGHT, 0.75 * fade))
		if t < 0.3:
			var c := Vector2(17, 0)
			_pen.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -4.5), c + Vector2(1, -1), c + Vector2(4.5, 0), c + Vector2(1, 1),
				c + Vector2(0, 4.5), c + Vector2(-1, 1), c + Vector2(-4.5, 0), c + Vector2(-1, -1),
			]), Palette.GOLD)
	_pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _coat(radius: float, offset: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in range(7):
		var a := TAU * float(k) / 7.0 + 0.45
		points.append(offset + Vector2(cos(a), sin(a)) * radius)
	return points
