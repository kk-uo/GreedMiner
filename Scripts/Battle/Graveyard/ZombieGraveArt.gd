extends RefCounted

## Fresh graves left by dead zombies (prototype: six looks, picked at random).
## Drawn around the grave origin, face to the bottom of the screen, shadow to
## the lower right, same palette as GraveyardTombstones.
## Load with preload(); no class_name on purpose.

const VARIANTS: int = 6
const DARK := Color("4A4F4A")
const STONE := Color("7F877C")
const LIT := Color("A9B1A3")
const ENGRAVE := Color("2A3328")
const DIRT := Color("3A3128")
const DIRT_FRESH := Color("4A3C2E")
const DIRT_LIGHT := Color("5A4A38")
const HOLE := Color("15110E")
const WOOD: Array[Color] = [Color("3B2A1E"), Color("5E4330"), Color("7E5C40")]
const ROPE := Color("B59A6A")
const Z_SKIN: Array[Color] = [Color("3E4656"), Color("5D6779"), Color("8790A3")]
const BONE: Array[Color] = [Color("B9B5AC"), Color("F2F0EA"), Color("FFFFFF")]
const BONE_HOLE := Color("1A1620")
const SOUL := Color("B49CFF")
const SOUL_CORE := Color("EEE6FF")
const SHADOW := Color(0, 0, 0, 0.28)


static func draw(c: Object, variant: int, time: float = 0.0) -> void:
	_mound(c, variant)
	match variant:
		0: _wood_cross(c)
		1: _pushed_slab(c)
		2: _reaching_hand(c, time)
		3: _coffin(c)
		4: _skull_cairn(c, time)
		_: _broken_slab(c, time)


## Fresh, lumpy dirt mound every variant stands on.
static func _mound(c: Object, variant: int) -> void:
	var mound := PackedVector2Array()
	for k in range(14):
		var a := TAU * float(k) / 14.0
		var lump := 1.0 + 0.12 * sin(a * 4.0 + float(variant))
		mound.append(Vector2(cos(a) * 13.0, 8.0 + sin(a) * 7.5) * lump)
	c.draw_colored_polygon(Palette.offset_points(mound, Vector2(2.0, 2.0)), SHADOW)
	c.draw_colored_polygon(mound, DIRT)
	var top := PackedVector2Array()
	for p in mound:
		top.append(Vector2(p.x * 0.78 - 1.5, (p.y - 8.0) * 0.6 + 6.5))
	c.draw_colored_polygon(top, DIRT_FRESH)
	for k in range(4):
		c.draw_circle(Vector2(-9.0 + 6.0 * float(k), 4.0 + float((k * 5 + variant) % 4)), 1.6, DIRT_LIGHT)


static func _wood_cross(c: Object) -> void:
	var tilt := Transform2D(0.12, Vector2(0, 4))
	c.draw_colored_polygon(Palette.offset_points(tilt * PackedVector2Array([Vector2(-2, -26), Vector2(2, -26), Vector2(2, 0), Vector2(-2, 0)]), Vector2(5, 3)), SHADOW)
	c.draw_colored_polygon(tilt * PackedVector2Array([Vector2(-2.6, -27), Vector2(2.6, -27), Vector2(2.6, 0), Vector2(-2.6, 0)]), WOOD[0])
	c.draw_colored_polygon(tilt * PackedVector2Array([Vector2(-2.6, -27), Vector2(1.0, -27), Vector2(1.0, 0), Vector2(-2.6, 0)]), WOOD[1])
	c.draw_colored_polygon(tilt * PackedVector2Array([Vector2(-10, -20), Vector2(10, -20), Vector2(10, -15.5), Vector2(-10, -15.5)]), WOOD[0])
	c.draw_colored_polygon(tilt * PackedVector2Array([Vector2(-10, -20), Vector2(10, -20), Vector2(10, -18.3), Vector2(-10, -18.3)]), WOOD[2])
	# Rope lashing where the beams cross.
	c.draw_line(tilt * Vector2(-3.4, -20.5), tilt * Vector2(3.4, -15), ROPE, 1.3)
	c.draw_line(tilt * Vector2(3.4, -20.5), tilt * Vector2(-3.4, -15), ROPE, 1.3)


static func _pushed_slab(c: Object) -> void:
	# A slab shoved up out of the soil at an angle, cracked, clods on top.
	var xf := Transform2D(-0.22, Vector2(1, 2))
	c.draw_colored_polygon(Palette.offset_points(xf * PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(8, -16), Vector2(-8, -16)]), Vector2(5, 3)), SHADOW)
	var slab := PackedVector2Array([Vector2(-8, 1), Vector2(-8, -11)])
	for k in range(9):
		slab.append(Vector2(-8.0 * cos(PI * float(k) / 8.0), -11.0 - 8.0 * sin(PI * float(k) / 8.0)))
	slab.append(Vector2(8, 1))
	c.draw_colored_polygon(xf * slab, DARK)
	c.draw_colored_polygon(xf * _scaled(slab, Vector2(-1.2, -6), 0.82), STONE)
	c.draw_arc(xf * Vector2(-1.2, -11), 5.0, PI * 1.1 - 0.22, PI * 1.6 - 0.22, 6, LIT, 1.6)
	c.draw_polyline(xf * PackedVector2Array([Vector2(2, -19), Vector2(-1, -13), Vector2(3, -9), Vector2(0, -3)]), ENGRAVE, 1.4)
	for p in [Vector2(-5, -17), Vector2(3, -18.5), Vector2(-9, 2), Vector2(9, 3)]:
		c.draw_circle(xf * p, 2.0, DIRT_LIGHT)
	# The dirt it tore open.
	c.draw_colored_polygon(PackedVector2Array([Vector2(-10, 3), Vector2(10, 1), Vector2(8, 6), Vector2(-8, 7)]), HOLE)


static func _reaching_hand(c: Object, time: float) -> void:
	c.draw_colored_polygon(PackedVector2Array([Vector2(-5, 4), Vector2(6, 3), Vector2(5, 9), Vector2(-4, 9)]), HOLE)
	# A small rounded marker behind the hand.
	c.draw_colored_polygon(PackedVector2Array([Vector2(-11, -2), Vector2(-11, -10), Vector2(-8, -14), Vector2(-3, -14), Vector2(0, -10), Vector2(0, -2)]), DARK)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-10.5, -2), Vector2(-10.5, -9.5), Vector2(-8, -13), Vector2(-4, -13), Vector2(-2, -10), Vector2(-2, -2)]), STONE)
	c.draw_line(Vector2(-8.5, -8), Vector2(-4, -8), ENGRAVE, 1.2)
	# The hand, fingers curling slowly.
	var curl := 0.5 + 0.5 * sin(time * 1.6)
	var wrist := Vector2(1, 6)
	var palm := Vector2(3, -6)
	c.draw_line(wrist + Vector2(1.5, 1.5), palm + Vector2(4, 2), SHADOW, 4.4)
	c.draw_line(wrist, palm, Z_SKIN[0], 4.6)
	c.draw_line(wrist, palm, Z_SKIN[1], 3.2)
	c.draw_circle(palm, 3.0, Z_SKIN[1])
	for f in range(4):
		var a := -PI * 0.5 + (float(f) - 1.5) * 0.42
		var knuckle := palm + Vector2.RIGHT.rotated(a) * 3.0
		var tip := knuckle + Vector2.RIGHT.rotated(a + curl * 0.9) * 3.6
		c.draw_line(knuckle, tip, Z_SKIN[1], 1.6)
		c.draw_circle(tip, 0.8, Z_SKIN[2])
	c.draw_line(palm + Vector2(-2.5, 0.5), palm + Vector2(-4.5, -2.0), Z_SKIN[1], 1.6)
	c.draw_line(wrist + Vector2(-2.2, 0), wrist + Vector2(2.2, 0), Color("4A3A5C"), 2.0)


static func _coffin(c: Object) -> void:
	# Coffin lid sticking out of the ground at an angle.
	var xf := Transform2D(0.35, Vector2(-1, 3))
	var lid := PackedVector2Array([Vector2(-4, 2), Vector2(-6.5, -10), Vector2(-4, -24), Vector2(4, -24), Vector2(6.5, -10), Vector2(4, 2)])
	c.draw_colored_polygon(Palette.offset_points(xf * lid, Vector2(5, 3)), SHADOW)
	c.draw_colored_polygon(xf * lid, WOOD[0])
	c.draw_colored_polygon(xf * _scaled(lid, Vector2(-1, -11), 0.82), WOOD[1])
	c.draw_line(xf * Vector2(-3.5, -20), xf * Vector2(-4.8, -11), WOOD[2], 1.4)
	c.draw_rect(Rect2(xf * Vector2(-0.8, -19), Vector2(1.6, 9)), Color("8A8F96"))
	c.draw_line(xf * Vector2(-3, -15.5), xf * Vector2(3, -15.5), Color("8A8F96"), 1.6)
	for p in [Vector2(-5, -10), Vector2(5, -10), Vector2(-3, -22), Vector2(3, -22)]:
		c.draw_circle(xf * p, 0.9, Color("C9CED3"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-9, 3), Vector2(8, 1), Vector2(9, 6), Vector2(-7, 7)]), HOLE)


static func _skull_cairn(c: Object, time: float) -> void:
	var stones := [Vector2(-7, 2), Vector2(0, 3), Vector2(7, 2), Vector2(-4, -3), Vector2(4, -3), Vector2(0, -7)]
	for index in range(stones.size()):
		var p: Vector2 = stones[index]
		c.draw_circle(p + Vector2(1.5, 1.5), 4.4, SHADOW)
		c.draw_circle(p, 4.4, DARK)
		c.draw_circle(p + Vector2(-0.6, -0.6), 3.5, STONE if index % 2 == 0 else LIT.darkened(0.15))
	var skull := Vector2(0, -13)
	c.draw_circle(skull + Vector2(1.2, 1.5), 5.5, SHADOW)
	c.draw_circle(skull, 5.6, BONE[0])
	c.draw_circle(skull, 5.0, BONE[1])
	c.draw_circle(skull + Vector2(-1.6, -1.8), 2.2, BONE[2])
	c.draw_rect(Rect2(skull + Vector2(-2.6, 3.0), Vector2(5.2, 3.0)), BONE[1])
	var glow := 0.6 + 0.4 * sin(time * 2.2)
	for s in [-1.0, 1.0]:
		var e := skull + Vector2(s * 2.0, 0.8)
		c.draw_circle(e, 1.5, BONE_HOLE)
		c.draw_circle(e, 2.6, Color(SOUL, 0.25 * glow))
		c.draw_circle(e, 0.7, Color(SOUL_CORE, glow))


static func _broken_slab(c: Object, time: float) -> void:
	# Lower half of a snapped slab; the top lies in the dirt beside it,
	# a lilac candle burning on the stump.
	c.draw_colored_polygon(PackedVector2Array([Vector2(-6, 2), Vector2(10, 2), Vector2(14, 6), Vector2(-2, 6)]), SHADOW)
	var stump := PackedVector2Array([Vector2(-8, 2), Vector2(-8, -10), Vector2(-3, -7), Vector2(1, -12), Vector2(5, -8), Vector2(8, -11), Vector2(8, 2)])
	c.draw_colored_polygon(stump, DARK)
	c.draw_colored_polygon(_scaled(stump, Vector2(-1, -4), 0.84), STONE)
	c.draw_line(Vector2(-5, -3), Vector2(3, -3), ENGRAVE, 1.3)
	var top := Transform2D(1.25, Vector2(-14, 5))
	var piece := PackedVector2Array([Vector2(-8, 0), Vector2(-8, -4)])
	for k in range(7):
		piece.append(Vector2(-8.0 * cos(PI * float(k) / 6.0), -4.0 - 6.0 * sin(PI * float(k) / 6.0)))
	piece.append(Vector2(8, 0))
	c.draw_colored_polygon(Palette.offset_points(top * piece, Vector2(1.5, 1.5)), SHADOW)
	c.draw_colored_polygon(top * piece, DARK)
	c.draw_colored_polygon(top * _scaled(piece, Vector2(0, -4), 0.8), LIT.darkened(0.1))
	# Candle.
	var base := Vector2(4.5, -9)
	c.draw_rect(Rect2(base + Vector2(-1.5, -6), Vector2(3, 6)), Color("D9D2C2"))
	c.draw_rect(Rect2(base + Vector2(-1.5, -6), Vector2(1.2, 6)), Color("F2EDE2"))
	var flicker := 0.85 + 0.15 * sin(time * 9.0) + 0.08 * sin(time * 23.0)
	var flame := base + Vector2(0, -8.0)
	c.draw_circle(flame, 5.0 * flicker, Color(SOUL, 0.2))
	c.draw_colored_polygon(PackedVector2Array([flame + Vector2(-1.6, 1.4), flame + Vector2(0, -3.6 * flicker), flame + Vector2(1.6, 1.4)]), SOUL)
	c.draw_circle(flame + Vector2(0, 0.6), 1.0, SOUL_CORE)


static func _scaled(points: PackedVector2Array, pivot: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(pivot + (p - pivot) * k)
	return out
