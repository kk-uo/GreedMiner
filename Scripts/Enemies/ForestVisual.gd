class_name ForestVisual
extends RefCounted

## Tree Planet enemies (user pick: treant style A "Kingdom Rush ent",
## recoloured green + brown). Top-down, facing +x, same flat 3-tone style as
## the other enemies; batched through one MeshBatch2D per draw.
## - treant / big_treant: a bulky bark body, a leafy crown on its back and
##   shoulders, two thick arms with knotted fists, root feet, a carved face
##   with a mossy leaf beard and amber eyes. big = same, 30/17 bigger.
## - fairy: a glowing leaf sprite with flapping translucent wings.
## The ground bursting open when a treant rises is ForestEmergeFx.

const BARK: Array[Color] = [Color("4A3424"), Color("6E4E34"), Color("94704C")]
const BARK_LIGHT: Array[Color] = [Color("6A5038"), Color("8E6E4E"), Color("B4946E")]
const LEAF: Array[Color] = [Color("2C4A2A"), Color("3C6234"), Color("5C8A48")]
const MOSS: Array[Color] = [Color("3E5A2A"), Color("5A7E3A"), Color("7EA452")]
const EYE := Color("FFD36A")
const FAIRY: Array[Color] = [Color("6AA84A"), Color("A7D889"), Color("EFF9C8")]
const FAIRY_GLOW := Color("B8F07A")
const WING := Color("E6FFD0")
const SHADOW := Color(0, 0, 0, 0.28)
## Drawn size of a big treant relative to a normal one (collision 30 / 17).
const BIG_SCALE: float = 30.0 / 17.0

static var _PEN := MeshBatch2D.new()
static var _flash: bool = false


static func _t(color: Color) -> Color:
	return Palette.HIT_FLASH if _flash else color


static func ngon(c: Vector2, r: Vector2, n: int, rot: float = 0.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	for k in range(n):
		var a := rot + TAU * float(k) / float(n)
		p.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return p


static func _scaled(pts: PackedVector2Array, c: Vector2, k: float) -> PackedVector2Array:
	var o := PackedVector2Array()
	for p in pts:
		o.append(c + (p - c) * k)
	return o


static func _shade(c: Object, pts: PackedVector2Array, tones: Array[Color]) -> void:
	if _flash:
		c.draw_colored_polygon(pts, Palette.HIT_FLASH)
		return
	var mid := Vector2.ZERO
	for p in pts:
		mid += p
	mid /= float(pts.size())
	var size := 0.0
	for p in pts:
		size = maxf(size, p.distance_to(mid))
	c.draw_colored_polygon(pts, tones[0])
	c.draw_colored_polygon(_scaled(pts, mid + Vector2(-0.08, -0.1) * size, 0.8), tones[1])
	c.draw_colored_polygon(_scaled(pts, mid + Vector2(-0.6, -0.6) * size * 0.45, 0.4), tones[2])


## Lobed leaf clump; `facing_back` keeps the light upper-left in WORLD space.
static func _crown(c: Object, at: Vector2, r: float, tones: Array[Color], seed: int, lobes: int, light: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var parts: Array = [[at, r * 0.72]]
	for k in range(lobes):
		var a := TAU * float(k) / float(lobes) + rng.randf_range(-0.2, 0.2)
		parts.append([at + Vector2(cos(a), sin(a)) * r * 0.5, r * rng.randf_range(0.42, 0.55)])
	for p in parts:
		c.draw_colored_polygon(ngon(p[0], Vector2.ONE * float(p[1]), 10), _t(tones[0]))
	if _flash:
		return
	for p in parts:
		c.draw_colored_polygon(ngon((p[0] as Vector2) + light * 0.2 * float(p[1]), Vector2.ONE * float(p[1]) * 0.8, 10), tones[1])
	for p in parts:
		var q: Vector2 = p[0]
		if (q - at).dot(light) >= -r * 0.1:
			c.draw_colored_polygon(ngon(q + light * 0.45 * float(p[1]), Vector2.ONE * float(p[1]) * 0.38, 8), tones[2])


static func _crown_shapes(at: Vector2, r: float, seed: int, lobes: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out: Array = [ngon(at, Vector2.ONE * r * 0.72, 10)]
	for k in range(lobes):
		var a := TAU * float(k) / float(lobes) + rng.randf_range(-0.2, 0.2)
		out.append(ngon(at + Vector2(cos(a), sin(a)) * r * 0.5, Vector2.ONE * r * rng.randf_range(0.42, 0.55), 10))
	return out


## step: -1..1 walk swing; rise: 0..1 while climbing out of the ground
## (smaller, lower), 1 when walking; lift adds to the shadow distance.
static func draw_treant(canvas: CanvasItem, facing: float, step: float, flash: bool, big: bool, rise: float = 1.0) -> void:
	var c := _PEN
	_flash = flash
	var e := 1.0 - pow(1.0 - clampf(rise, 0.0, 1.0), 3.0)
	var s := (BIG_SCALE if big else 1.0) * (0.35 + 0.65 * e)
	# Upper-left light in world space, expressed in the rotated local frame.
	var light := Vector2(-0.6, -0.75).rotated(-facing)
	var body := ngon(Vector2(-2, 0), Vector2(15, 16), 14)
	var crown_shapes := _crown_shapes(Vector2(-9, 0), 14, 21, 8)
	# Shadow: world down-right, a little further while it rises.
	c.draw_set_transform(Palette.SHADOW_OFFSET * 0.55 * s * (0.6 + 0.4 * e), facing, Vector2.ONE * s)
	for shape in [body] + crown_shapes:
		c.draw_colored_polygon(shape, SHADOW)
	c.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * s)
	# Root feet stepping.
	for side in [-1.0, 1.0]:
		_shade(c, ngon(Vector2(-4 + step * 5.0 * side, 14 * side), Vector2(6, 4.5), 8), BARK)
	# Thick arms with knotted fists.
	for side in [-1.0, 1.0]:
		var sh := Vector2(2, 12 * side)
		var fist := Vector2(11 - step * 3.0 * side, 19 * side)
		c.draw_line(sh, fist, _t(BARK[0]), 9.5)
		if not flash:
			c.draw_line(sh, fist, BARK[1], 7.0)
		_shade(c, ngon(fist, Vector2(6.5, 6.5), 9), BARK)
		if not flash:
			for k in range(3):
				c.draw_line(fist + Vector2(3, (k - 1) * 3.0), fist + Vector2(6.5, (k - 1) * 3.2), BARK[0], 1.4)
	_shade(c, body, BARK)
	if not flash:
		for seg in [[Vector2(-12, -8), Vector2(-4, -4), Vector2(2, -9)], [Vector2(-10, 9), Vector2(-2, 5), Vector2(4, 10)]]:
			c.draw_polyline(PackedVector2Array(seg), BARK[0], 1.4)
	# Leafy crown on the back and the shoulders.
	_crown(c, Vector2(-9, 0), 14, LEAF, 21, 8, light)
	for side in [-1.0, 1.0]:
		_crown(c, Vector2(0, 11 * side), 5.5, LEAF, 7, 5, light)
	# Carved face, heavy brow, amber eyes and a mossy leaf beard.
	_shade(c, ngon(Vector2(9, 0), Vector2(6, 9), 10), BARK_LIGHT)
	if not flash:
		c.draw_line(Vector2(10, -6), Vector2(10, 6), BARK[0], 2.4)
		for side in [-1.0, 1.0]:
			var eye := Vector2(11.5, 3.4 * side)
			c.draw_circle(eye, 3.2, Color(EYE, 0.25))
			c.draw_circle(eye, 1.4, EYE)
			c.draw_circle(eye + Vector2(-0.3, -0.3), 0.6, Color.WHITE)
	_crown(c, Vector2(15.5, 0), 6.0, MOSS, 5, 6, light)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.flush_to(canvas)
	_flash = false


static func draw_fairy(canvas: CanvasItem, facing: float, flash: bool, time: float) -> void:
	var c := _PEN
	_flash = flash
	c.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE)
	if not flash:
		c.draw_circle(Vector2.ZERO, 14.0, Color(FAIRY_GLOW, 0.16))
		c.draw_circle(Vector2.ZERO, 9.0, Color(FAIRY_GLOW, 0.14))
	var flap := 0.55 + 0.45 * absf(sin(time * 18.0))
	for side in [-1.0, 1.0]:
		c.draw_colored_polygon(PackedVector2Array([Vector2(-1, 0), Vector2(-9, 9 * side * flap), Vector2(-2, 11 * side * flap), Vector2(3, 3 * side)]), _t(Color(WING, 0.7)))
	_shade(c, ngon(Vector2.ZERO, Vector2(5.5, 5), 10), FAIRY)
	var light := Vector2(-0.6, -0.75).rotated(-facing)
	_crown(c, Vector2(-3, 0), 3.2, LEAF, 2, 5, light)
	if not flash:
		c.draw_circle(Vector2(3, -1.5), 1.0, Color("2A3A20"))
		c.draw_circle(Vector2(3, 1.5), 1.0, Color("2A3A20"))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.flush_to(canvas)
	_flash = false
