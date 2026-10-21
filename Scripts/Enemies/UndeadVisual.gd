class_name UndeadVisual
extends RefCounted

## Presentation for the Graveyard Planet undead (style C "gothic night") and
## the boss Giant Frank (style A "classic Frankenstein"). Top-down, facing
## the ship, flat three-tone shading like DemonVisual. Arms hang at the
## sides and swing with the walk; an attack swipes one arm forward.
## Every shape is recorded into one MeshBatch2D and flushed as a single draw.

const SHADOW := Color(0, 0, 0, 0.28)
const ATTACK_POSE_TIME: float = 0.35

# Style C palettes.
const Z_SKIN: Array[Color] = [Color("3E4656"), Color("5D6779"), Color("8790A3")]
const Z_RAGS: Array[Color] = [Color("2E2438"), Color("4A3A5C"), Color("6B5A80")]
const Z_EYE := Color("C9B8FF")
const BONE: Array[Color] = [Color("B9B5AC"), Color("F2F0EA"), Color("FFFFFF")]
const BONE_SHADOW := Color("8E8A82")
const BONE_HOLE := Color("1A1620")
const SOUL := Color("B49CFF")
const SOUL_CORE := Color("EEE6FF")
const V_SKIN: Array[Color] = [Color("8E8AA0"), Color("CFCADC"), Color("EFECF6")]
const V_CAPE: Array[Color] = [Color("1A1024"), Color("2E1D40"), Color("4A3266")]
const V_LINING := Color("6B1A3A")
const V_HAIR := Color("2A1E3A")
const V_EYE := Color("FF4A7A")
const W_FUR: Array[Color] = [Color("464A56"), Color("7A8090"), Color("B8BECB")]
const W_EYE := Color("7FD8FF")
const SILVER := Color("C9CED3")
const IRON: Array[Color] = [Color("2E2B36"), Color("4E4A5A"), Color("8E8A99")]
# Giant Frank (style A).
const F_SKIN: Array[Color] = [Color("3E6B3A"), Color("5E8F52"), Color("8DBA7A")]
const F_SKIN_DEAD: Array[Color] = [Color("34463A"), Color("4A6050"), Color("6A806E")]
const F_SUIT: Array[Color] = [Color("17171C"), Color("2A2A33"), Color("41414E")]
const F_HAIR: Array[Color] = [Color("0E0E10"), Color("1E1E22"), Color("3A3A42")]
const F_STEEL: Array[Color] = [Color("4A4E53"), Color("8A9097"), Color("C9CED3")]
const F_EYE := Color("FFF2B0")
const ARC := Color("7FD8FF")

static var _PEN := MeshBatch2D.new()
static var _flash: bool = false
## Model scale for the current draw (Giant Frank is drawn at FRANK_SCALE).
static var _scale: float = 1.0
const FRANK_SCALE: float = 2.0


## 0..1 swipe for the attack pose (peaks early, eases back).
static func attack_amount(pose_left: float) -> float:
	if pose_left <= 0.0:
		return 0.0
	var k := 1.0 - pose_left / ATTACK_POSE_TIME
	return sin(PI * clampf(k, 0.0, 1.0))


# ------------------------------------------------------------------ helpers

static func _t(color: Color) -> Color:
	return Palette.HIT_FLASH if _flash else color


static func ngon(center: Vector2, radii: Vector2, sides: int, rot: float = 0.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	for k in range(sides):
		var a := rot + TAU * float(k) / float(sides)
		p.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return p


static func _shrink(points: PackedVector2Array, k: float, shift: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= float(points.size())
	var out := PackedVector2Array()
	for p in points:
		out.append(center + (p - center) * k + shift)
	return out


static func _shade(c: Object, points: PackedVector2Array, tones: Array[Color], inset: float = 0.8) -> void:
	if _flash:
		c.draw_colored_polygon(points, Palette.HIT_FLASH)
		return
	c.draw_colored_polygon(points, tones[0])
	c.draw_colored_polygon(_shrink(points, inset), tones[1])
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= float(points.size())
	var size := 0.0
	for p in points:
		size = maxf(size, p.distance_to(center))
	c.draw_colored_polygon(_shrink(points, 0.42, Vector2(-0.6, -0.6) * size * 0.32), tones[2])


static func _limb(c: Object, a: Vector2, b: Vector2, w: float, tones: Array[Color]) -> void:
	c.draw_line(a, b, _t(tones[0]), w + 1.6)
	c.draw_line(a, b, _t(tones[1]), w)


static func _hand(c: Object, at: Vector2, r: float, tones: Array[Color], claws: Color = Color(0, 0, 0, 0), claw_len: float = 0.0, forward: Vector2 = Vector2.RIGHT) -> void:
	if claws.a > 0.0 and not _flash:
		var side := forward.orthogonal()
		for k in [-1.0, 0.0, 1.0]:
			c.draw_line(at, at + forward * (r + claw_len) + side * k * r * 0.7, claws, 1.2)
	c.draw_circle(at, r + 0.8, _t(tones[0]))
	if not _flash:
		c.draw_circle(at, r, tones[1])
		c.draw_circle(at + Vector2(-0.35, -0.35) * r, r * 0.45, tones[2])


static func _eyes(c: Object, at: Vector2, spread: float, r: float, color: Color, core: Color) -> void:
	for side in [-1.0, 1.0]:
		var e := at + Vector2(0, spread * side)
		if not _flash:
			c.draw_circle(e, r * 2.2, Color(color, 0.25))
		c.draw_circle(e, r, _t(color))
		if not _flash:
			c.draw_circle(e + Vector2(-0.2, -0.2) * r, r * 0.45, core)


static func _stitches(c: Object, a: Vector2, b: Vector2, color: Color, count: int, glow: Color = Color(0, 0, 0, 0)) -> void:
	if _flash:
		return
	if glow.a > 0.0:
		c.draw_line(a, b, Color(glow, 0.35), 3.4)
	c.draw_line(a, b, color, 1.0)
	var n := (b - a).normalized().orthogonal() * 1.6
	for k in range(count):
		var p := a.lerp(b, (float(k) + 0.5) / float(count))
		c.draw_line(p - n, p + n, color, 0.9)


static func _spark(c: Object, a: Vector2, b: Vector2, seed: int, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pts := PackedVector2Array([a])
	var n := (b - a).orthogonal().normalized()
	for k in range(1, 6):
		pts.append(a.lerp(b, float(k) / 6.0) + n * rng.randf_range(-3.5, 3.5))
	pts.append(b)
	c.draw_polyline(pts, Color(color, 0.35), 4.0)
	c.draw_polyline(pts, color, 1.6)
	c.draw_polyline(pts, Color(1, 1, 1, 0.9), 0.6)


## Shadow pass: the given silhouettes, offset toward the lower right.
static func _shadow(c: Object, facing: float, shapes: Array) -> void:
	c.draw_set_transform(Palette.SHADOW_OFFSET * 0.8 * _scale, facing, Vector2.ONE * _scale)
	for shape in shapes:
		c.draw_colored_polygon(shape, Palette.SHADOW_COLOR)
	c.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * _scale)


static func _begin(flash: bool) -> Object:
	_flash = flash
	return _PEN


static func _end(canvas: CanvasItem) -> void:
	_PEN.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_PEN.flush_to(canvas)
	_flash = false
	_scale = 1.0


# ------------------------------------------------------------------ zombie (r12)

## step: -1..1 walk swing; attack: 0..1 swipe of the right arm.
static func draw_zombie(canvas: CanvasItem, facing: float, step: float, attack: float, flash: bool, time: float) -> void:
	var c := _begin(flash)
	var sway := sin(time * 2.2) * 0.8
	var body := ngon(Vector2(-3, 0), Vector2(7, 10.5), 12, 0.1)
	var head := ngon(Vector2(4.5, 2.0 + sway * 0.4), Vector2(6.0, 5.8), 10, 0.3)
	_shadow(c, facing, [body, head])
	# Arms hang at the sides, swinging with the shamble; the attack swipes
	# the right arm forward.
	var left_hand := Vector2(2.0 + step * 2.5, -12.5)
	var right_hand := Vector2(2.0 - step * 2.5, 12.5).lerp(Vector2(13, 5), attack)
	_limb(c, Vector2(-2, -8.5), left_hand, 2.8, Z_SKIN)
	_limb(c, Vector2(-2, 8.5), right_hand, 2.8, Z_SKIN)
	_shade(c, body, Z_RAGS)
	if not flash:
		# Torn rags: ragged holes showing grey skin and ribs.
		c.draw_colored_polygon(PackedVector2Array([Vector2(-9, -4), Vector2(-5, -2), Vector2(-7, 0), Vector2(-4, 2), Vector2(-9, 3)]), Z_SKIN[1])
		for k in range(3):
			c.draw_line(Vector2(-8.5 + float(k) * 1.6, -2.2), Vector2(-8.5 + float(k) * 1.6, 1.6), Z_SKIN[0], 0.8)
		c.draw_colored_polygon(PackedVector2Array([Vector2(1, 6), Vector2(-2, 10), Vector2(1.5, 8.8), Vector2(4, 10), Vector2(3.5, 6.5)]), Z_SKIN[1])
	_hand(c, left_hand, 2.2, Z_SKIN)
	_hand(c, right_hand, 2.2, Z_SKIN)
	if not flash:
		# A rusted shackle on the left wrist.
		c.draw_arc(left_hand, 3.2, 0.0, TAU, 10, Color("6A6E78"), 1.2)
	_shade(c, head, Z_SKIN)
	if not flash:
		c.draw_colored_polygon(ngon(Vector2(2.2, 2.0 + sway * 0.4), Vector2(3.2, 4.6), 8, 0.0), Color("1E1A26"))
	_eyes(c, Vector2(8.2, 2.0 + sway * 0.4), 2.3, 1.1, Z_EYE, Color.WHITE)
	_end(canvas)


# ------------------------------------------------------------------ skeleton (r12)

## Simple, pure-white skeleton with only a few bones: the skull in front,
## a spine with three pairs of ribs (no body shell), an arm bone on each
## side swinging, and two feet stepping out under it. Black eye sockets.
## Short sword in the right hand; the attack swipes it forward.
static func draw_skeleton(canvas: CanvasItem, facing: float, step: float, attack: float, flash: bool, _time: float) -> void:
	var c := _begin(flash)
	var skull_at := Vector2(5.5, 0)
	var skull := ngon(skull_at, Vector2(5.2, 4.9), 12)
	var ribs := ngon(Vector2(-2, 0), Vector2(5, 7), 10)
	_shadow(c, facing, [skull, ribs])
	# Feet: one ahead, one behind, swapping each step.
	for side in [-1.0, 1.0]:
		var at := Vector2(9.0 * step * float(side) - 1.5, 3.4 * float(side))
		_shade(c, ngon(at, Vector2(2.6, 1.6), 8), BONE, 0.7)
	# Arms at the sides, swinging opposite to the feet.
	var hand_l := Vector2(1.5 - 3.0 * step, -9.5)
	var hand_r := Vector2(1.5 + 3.0 * step, 9.5).lerp(Vector2(11, 4), attack)
	for pair in [[Vector2(-0.5, -6.0), hand_l], [Vector2(-0.5, 6.0), hand_r]]:
		_rib_bone(c, pair[0], pair[1], 1.5)
	# Short sword.
	var blade := Vector2(1, -0.06).rotated(-0.6 * attack).normalized()
	c.draw_line(hand_r, hand_r + blade * 10.0, _t(IRON[0]), 2.4)
	if not flash:
		c.draw_line(hand_r + blade, hand_r + blade * 10.0, IRON[2], 1.0)
		c.draw_line(hand_r + blade.orthogonal() * 2.0, hand_r - blade.orthogonal() * 2.0, Color("6B4A32"), 1.6)
	for h in [hand_l, hand_r]:
		c.draw_circle(h, 1.8, _t(BONE[0]))
		if not flash:
			c.draw_circle(h, 1.2, BONE[2])
	# Spine and three pairs of ribs - bones only, no shell.
	_rib_bone(c, Vector2(-7, 0), Vector2(2.5, 0), 1.6)
	for k in range(3):
		var x := -4.6 + 2.6 * float(k)
		var w := 6.0 - absf(float(k) - 1.0) * 0.8
		for side in [-1.0, 1.0]:
			_rib_bone(c, Vector2(x + 0.6, 0.8 * float(side)), Vector2(x - 0.6, w * float(side)), 1.3)
	# Skull: dome, black sockets, teeth line.
	_shade(c, skull, BONE, 0.84)
	if not flash:
		for side in [-1.0, 1.0]:
			c.draw_circle(skull_at + Vector2(2.2, 2.2 * float(side)), 1.55, BONE_HOLE)
		c.draw_line(skull_at + Vector2(4.7, -1.7), skull_at + Vector2(4.7, 1.7), BONE_HOLE, 1.0)
	_end(canvas)


static func _rib_bone(c: Object, a: Vector2, b: Vector2, w: float) -> void:
	c.draw_line(a, b, _t(BONE[0]), w + 1.0)
	if not _flash:
		c.draw_line(a, b, BONE[1], w)


# ------------------------------------------------------------------ vampire (r20)

static func draw_vampire(canvas: CanvasItem, facing: float, step: float, attack: float, flash: bool, time: float) -> void:
	var c := _begin(flash)
	var billow := sin(time * 2.0) * 1.2
	var cape := PackedVector2Array([Vector2(4, -11), Vector2(-2, -21 - billow), Vector2(-9, -26 - billow), Vector2(-12, -19), Vector2(-18, -22 - billow), Vector2(-20, -14), Vector2(-26, -14), Vector2(-24, -6), Vector2(-29, -2), Vector2(-24, 0), Vector2(-29, 2), Vector2(-24, 6), Vector2(-26, 14), Vector2(-20, 14), Vector2(-18, 22 + billow), Vector2(-12, 19), Vector2(-9, 26 + billow), Vector2(-2, 21 + billow), Vector2(4, 11)])
	var head := ngon(Vector2(5, 0), Vector2(6.2, 5.8), 12, 0.0)
	_shadow(c, facing, [cape, head])
	c.draw_colored_polygon(cape, _t(V_CAPE[0]))
	if not flash:
		c.draw_colored_polygon(_shrink(cape, 0.86, Vector2(1, 0)), V_LINING)
		c.draw_colored_polygon(_shrink(cape, 0.72, Vector2(-2, 0)), V_CAPE[1])
		for tip in [Vector2(-9, -24), Vector2(-18, -20), Vector2(-25, -13), Vector2(-27, -2), Vector2(-27, 2), Vector2(-25, 13), Vector2(-18, 20), Vector2(-9, 24)]:
			c.draw_line(Vector2(-4, tip.y * 0.25), tip * 0.92, V_CAPE[2], 1.3)
	# Body and the tall pointed collar.
	var body := ngon(Vector2(-2, 0), Vector2(7.5, 10.5), 12, 0.0)
	_shade(c, body, V_CAPE)
	for side in [-1.0, 1.0]:
		var collar := PackedVector2Array([Vector2(2, 2 * side), Vector2(-3, 11 * side), Vector2(-7, 9 * side), Vector2(-3, 4 * side)])
		c.draw_colored_polygon(collar, _t(V_CAPE[0]))
		if not flash:
			c.draw_colored_polygon(_shrink(collar, 0.7), V_LINING)
	# Long-nailed hands at the sides; the attack lunges the right claw forward.
	var hand_l := Vector2(3 + step * 2.0, -12.5)
	var hand_r := Vector2(3 - step * 2.0, 12.5).lerp(Vector2(15, 6), attack)
	_limb(c, Vector2(0, -8), hand_l, 2.6, V_CAPE)
	_limb(c, Vector2(0, 8), hand_r, 2.6, V_CAPE)
	_hand(c, hand_l, 2.2, V_SKIN, Color("2A1A1A"), 3.0)
	_hand(c, hand_r, 2.2, V_SKIN, Color("2A1A1A"), 3.0)
	_shade(c, head, V_SKIN)
	if not flash:
		c.draw_colored_polygon(PackedVector2Array([Vector2(-1, -5.5), Vector2(4, -6.2), Vector2(9, -3.5), Vector2(6.5, 0), Vector2(9, 3.5), Vector2(4, 6.2), Vector2(-1, 5.5), Vector2(-1.5, 0)]), V_HAIR)
	_eyes(c, Vector2(9.4, 0), 2.0, 0.9, V_EYE, Color("FFD6E0"))
	if not flash:
		# A floating candle flame and two bats circling.
		c.draw_circle(Vector2(14, -16), 4.0, Color("FFC861", 0.2))
		c.draw_circle(Vector2(14, -16), 1.4, Color("FFC861"))
		for k in range(2):
			var a := time * 2.5 + PI * float(k)
			var b := Vector2(-6, 0) + Vector2(cos(a) * 26.0, sin(a) * 26.0)
			c.draw_colored_polygon(PackedVector2Array([b + Vector2(0, -1), b + Vector2(-3, -4), b + Vector2(-1.5, 0), b + Vector2(-3, 4), b + Vector2(0, 1), b + Vector2(1.5, 0)]), V_CAPE[0])
	_end(canvas)


# ------------------------------------------------------------------ werewolf (r20)

static func draw_werewolf(canvas: CanvasItem, facing: float, step: float, attack: float, flash: bool, time: float) -> void:
	var c := _begin(flash)
	var back := PackedVector2Array()
	for k in range(18):
		var a := TAU * float(k) / 18.0
		var r := Vector2(13.0, 12.0) * (1.0 if k % 2 == 0 else 0.86)
		back.append(Vector2(-4, 0) + Vector2(cos(a) * r.x, sin(a) * r.y))
	var head := ngon(Vector2(7, 0), Vector2(6.5, 6.2), 10, 0.0)
	_shadow(c, facing, [back, head])
	# Tail.
	c.draw_line(Vector2(-14, 0), Vector2(-24, 3 + step * 3.0), _t(W_FUR[0]), 5.0)
	if not flash:
		c.draw_line(Vector2(-14, 0), Vector2(-24, 3 + step * 3.0), W_FUR[1], 3.0)
	# Clawed arms at the sides; the attack swipes the right claw forward.
	var hand_l := Vector2(4 + step * 3.0, -15.5)
	var hand_r := Vector2(4 - step * 3.0, 15.5).lerp(Vector2(18, 7), attack)
	_limb(c, Vector2(0, -10), hand_l, 3.6, W_FUR)
	_limb(c, Vector2(0, 10), hand_r, 3.6, W_FUR)
	_hand(c, hand_l, 2.8, W_FUR, Color("E6ECF6"), 3.0)
	_hand(c, hand_r, 2.8, W_FUR, Color("E6ECF6"), 3.0, Vector2.RIGHT.lerp(Vector2(0.6, -0.8), attack).normalized())
	_shade(c, back, W_FUR)
	if not flash:
		for k in range(4):
			var x := -12.0 + 4.0 * float(k)
			c.draw_colored_polygon(PackedVector2Array([Vector2(x, -1.5), Vector2(x - 4, 0), Vector2(x, 1.5)]), W_FUR[0])
	# Wolf head: pointed ears, muzzle, broken silver collar.
	for side in [-1.0, 1.0]:
		var ear := PackedVector2Array([Vector2(3, 3.5 * side), Vector2(-1.5, 8.5 * side), Vector2(6, 5.8 * side)])
		c.draw_colored_polygon(ear, _t(W_FUR[0]))
		if not flash:
			c.draw_colored_polygon(_shrink(ear, 0.55), Color("6A5A7A"))
	_shade(c, head, W_FUR)
	var muzzle := PackedVector2Array([Vector2(10, -3.2), Vector2(18, -1.8), Vector2(19, 0), Vector2(18, 1.8), Vector2(10, 3.2)])
	_shade(c, muzzle, W_FUR, 0.75)
	if not flash:
		c.draw_circle(Vector2(18.6, 0), 1.3, Color("141010"))
		c.draw_arc(Vector2(4, 0), 6.6, PI * 0.35, PI * 1.65, 14, SILVER, 1.4)
	_eyes(c, Vector2(10, 0), 2.6, 1.0, W_EYE, Color.WHITE)
	_end(canvas)


# ------------------------------------------------------------------ Giant Frank (r38)

enum FrankState { NORMAL, DOWN, ENRAGED }

## state: NORMAL, DOWN (first death, lying lifeless until the lightning),
## ENRAGED (revived: crackling arcs, glowing stitches and eyes).
## The resurrection bolt itself is FrankResurrectionFx.
static func draw_frank(canvas: CanvasItem, facing: float, step: float, attack: float, flash: bool, time: float, state: int) -> void:
	var c := _begin(flash)
	_scale = FRANK_SCALE
	var down := state == FrankState.DOWN
	var enraged := state == FrankState.ENRAGED
	var skin: Array[Color] = F_SKIN_DEAD if down else F_SKIN
	var glow := ARC if enraged else Color(0, 0, 0, 0)
	if enraged and not flash:
		c.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * _scale)
		c.draw_circle(Vector2(-2, 0), 46.0, Color(ARC, 0.08))
		c.draw_arc(Vector2(-2, 0), 44.0, 0.0, TAU, 40, Color(ARC, 0.4), 2.0)
	var torso := PackedVector2Array([Vector2(10, -20), Vector2(4, -30), Vector2(-8, -33), Vector2(-20, -28), Vector2(-26, -14), Vector2(-27, 0), Vector2(-26, 14), Vector2(-20, 28), Vector2(-8, 33), Vector2(4, 30), Vector2(10, 20), Vector2(12, 0)])
	var head := PackedVector2Array([Vector2(22, -12), Vector2(22, 12), Vector2(19, 15), Vector2(-2, 15), Vector2(-5, 12), Vector2(-5, -12), Vector2(-2, -15), Vector2(19, -15)])
	_shadow(c, facing, [torso, head])
	# Huge arms hanging at the sides (splayed out when he is down); the
	# attack slams the right fist forward.
	var swing := 0.0 if down else step
	var hand_l := Vector2(12 + swing * 6.0, -35) if not down else Vector2(-18, -46)
	var hand_r := (Vector2(12 - swing * 6.0, 35) if not down else Vector2(-18, 46)).lerp(Vector2(32, 14), attack)
	_limb(c, Vector2(-10, -27), hand_l, 8.5, F_SUIT)
	_limb(c, Vector2(-10, 27), hand_r, 8.5, F_SUIT)
	_shade(c, torso, F_SUIT, 0.86)
	if not flash:
		# Lapels.
		c.draw_colored_polygon(PackedVector2Array([Vector2(8, -8), Vector2(-6, -16), Vector2(-4, -6)]), F_SUIT[2])
		c.draw_colored_polygon(PackedVector2Array([Vector2(8, 8), Vector2(-6, 16), Vector2(-4, 6)]), F_SUIT[2])
	# Fists with shackles and broken chain links.
	for hand in [hand_l, hand_r]:
		_hand(c, hand, 6.5, skin)
		if not flash:
			c.draw_arc(hand, 7.4, 0.0, TAU, 16, F_STEEL[1], 2.2)
			var dangle := Vector2(-5, signf(hand.y) * 6.0)
			c.draw_arc(hand + dangle, 2.6, 0.0, TAU, 10, F_STEEL[1], 1.4)
			c.draw_arc(hand + dangle * 1.8, 2.6, 0.0, TAU, 10, F_STEEL[1], 1.4)
	# Neck bolts.
	for side in [-1.0, 1.0]:
		c.draw_rect(Rect2(Vector2(0, 15.5 * side - 1.6), Vector2(4, 3.2)), _t(F_STEEL[1]))
		var bolt := Vector2(2, 17.5 * side)
		c.draw_circle(bolt, 2.6, _t(F_STEEL[0]))
		if not flash:
			c.draw_circle(bolt, 1.8, F_STEEL[2])
		if enraged and not flash:
			_spark(c, bolt, bolt + Vector2(-4, 6 * side), int(time * 12.0) + int(side * 3.0), ARC)
	# Big square head: flat-top black hair from above, the green face in front.
	_shade(c, head, skin, 0.84)
	var top := PackedVector2Array([Vector2(11, -14), Vector2(11, 14), Vector2(-4, 14), Vector2(-4, -14)])
	c.draw_colored_polygon(top, _t(F_HAIR[0]))
	if not flash:
		c.draw_colored_polygon(_shrink(top, 0.84), F_HAIR[1])
		for k in range(4):
			var y := -10.5 + 7.0 * float(k)
			c.draw_line(Vector2(-2, y), Vector2(9, y), F_HAIR[2], 1.2)
		var fringe := PackedVector2Array([Vector2(11, -14)])
		for k in range(7):
			fringe.append(Vector2(14.5 if k % 2 == 0 else 11.0, -14.0 + 4.0 * float(k + 1)))
		fringe.append(Vector2(11, 14))
		fringe.append(Vector2(10, 14))
		fringe.append(Vector2(10, -14))
		c.draw_colored_polygon(fringe, F_HAIR[0])
	_stitches(c, Vector2(16, -11), Vector2(16, 11), Color("1E1A16"), 6, glow)
	if not flash:
		c.draw_line(Vector2(21.5, -9), Vector2(21.5, 9), skin[0], 1.6)
	if down:
		# Eyes shut.
		if not flash:
			for side in [-1.0, 1.0]:
				c.draw_line(Vector2(19.2, 5.2 * side - 1.6), Vector2(19.2, 5.2 * side + 1.6), Color("1E1A16"), 1.2)
	else:
		_eyes(c, Vector2(19.2, 0), 5.2, 1.7, ARC if enraged else F_EYE, Color.WHITE)
	if enraged and not flash:
		_spark(c, Vector2(2, -17.5), Vector2(-14, -30), int(time * 10.0) + 7, ARC)
		_spark(c, Vector2(2, 17.5), Vector2(-14, 30), int(time * 10.0) + 11, ARC)
		_spark(c, Vector2(-20, -28), Vector2(-28, 0), int(time * 10.0) + 17, ARC)
	_end(canvas)
