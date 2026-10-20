class_name DemonVisual
extends RefCounted

## Presentation-only drawing for the Volcanic Planet demons (art option A,
## "crimson demons"). Top-down, local +X faces the ship, flat style A like the
## goblins: dark rim + base + lit top-left facet, one hard shadow. Yellow eyes
## and orange fire are the accents. Gameplay scripts only pass animation
## amounts in.
##
## - Demon: pitchfork in the right hand, thrusts it forward on attack.
## - Hellhunter: long hound with black back spines and a spiked collar; speed
##   streaks while running, snaps its head forward to bite.
## - Big Demon: huge brute with ram horns; raises both fists (they grow, as if
##   closer to the camera) and slams them down with two shockwaves.
## - Imp: small bat-winged hoverer; a fireball grows in its hand, then is thrown.

## Seconds an attack pose (thrust, bite, slam, throw follow-through) lasts.
const ATTACK_POSE_TIME: float = 0.4
## Seconds before a hit in which the Demon pulls its fork back / the Big Demon
## raises its fists.
const WINDUP_TIME: float = 0.45
## Seconds before a throw in which the Imp's fireball grows.
const CHARGE_TIME: float = 0.6
## Seconds the Big Demon's slam shockwaves last.
const SLAM_WAVE_TIME: float = 0.45

const DEMON_SCALE: float = 0.9
const HOUND_SCALE: float = 0.9

const SKIN: Array[Color] = [Color("7A1A1C"), Color("C8352B"), Color("EE6A4C")]
const HORN: Array[Color] = [Color("1E1514"), Color("3A2A27"), Color("64504A")]
const WING: Array[Color] = [Color("4A0F12"), Color("8E2324"), Color("B53A33")]
const IRON: Array[Color] = [Color("4A4E53"), Color("8A9097"), Color("C9CED3")]
const WOOD: Array[Color] = [Color("3B2A1E"), Color("6B4A32"), Color("8A5A34")]
const EYE := Color("FFD23F")
const EYE_CORE := Color("FFF6D8")
const FIRE_DARK := Color("C2410C")
const FIRE := Color("FF8A2A")
const FIRE_LIGHT := Color("FFE08A")
const SPIKE := Color("C9CED3")

const DEMON_HORN := [Vector2(1, -5), Vector2(4, -8), Vector2(8, -11.5), Vector2(14, -12), Vector2(9, -7.5), Vector2(5, -3.5)]
const BIG_HORN := [Vector2(5, -6), Vector2(2, -11), Vector2(2, -16), Vector2(6, -19.5), Vector2(12, -17.5), Vector2(7, -15), Vector2(6, -11), Vector2(9, -6)]
const IMP_HORN := [Vector2(3, -3), Vector2(5.5, -6), Vector2(8, -6.5), Vector2(5, -2.5)]
const IMP_WING := [Vector2(-2, -4), Vector2(-4, -12), Vector2(-8, -19), Vector2(-9.5, -14), Vector2(-13, -15.5),
	Vector2(-11, -10), Vector2(-14, -9), Vector2(-7, -4)]

## Everything is recorded into this shared batch and submitted to the
## CanvasItem as a single triangle array.
static var _PEN := MeshBatch2D.new()


## 0..1 pose strength for a pose timer counting down from ATTACK_POSE_TIME:
## snaps in fast, then eases back.
static func attack_amount(time_left: float) -> float:
	if time_left <= 0.0:
		return 0.0
	var progress: float = 1.0 - time_left / ATTACK_POSE_TIME
	if progress < 0.2:
		return progress / 0.2
	return 1.0 - ease((progress - 0.2) / 0.8, 0.6)


## 0..1 build-up during the last `duration` seconds before the attack timer fires.
static func windup_amount(is_attacking: bool, pose_time_left: float, timer: Timer, duration: float) -> float:
	if not is_attacking or pose_time_left > 0.0 or timer == null or timer.is_stopped():
		return 0.0
	return clampf(1.0 - timer.time_left / duration, 0.0, 1.0)


# ==========================================
# Demon
# ==========================================

## step: -1..1 walk cycle. windup: 0..1 fork pulled back. thrust: 0..1 stab.
static func draw_demon(canvas: CanvasItem, facing: float, step: float, windup: float, thrust: float, flash: bool) -> void:
	var c := _PEN
	var scale := Vector2.ONE * DEMON_SCALE
	var body := _ngon(Vector2(-3, 0), Vector2(9, 11.5), 12, 0.0)
	var head := _ngon(Vector2(4, 0), Vector2(7, 7), 10, 0.2)
	var dx: float = -4.0 * windup + 9.0 * thrust

	c.draw_set_transform(Palette.SHADOW_OFFSET * 0.8, facing, scale)
	for shape in [body, head]:
		c.draw_colored_polygon(shape, Palette.SHADOW_COLOR)
	c.draw_line(Vector2(-14 + dx, 12), Vector2(15 + dx, 12), Palette.SHADOW_COLOR, 3.0)

	c.draw_set_transform(Vector2.ZERO, facing, scale)
	_tail(c, Vector2(-10, 0), Vector2(-17, 7), Vector2(-23, 2), step * 0.3, 2.4, flash)
	var hand_l := Vector2(3.0 - step * 3.0, -12.5)
	_arm(c, Vector2(-2, -9), hand_l, 3.2, flash)
	_hand(c, hand_l, 2.8, flash)
	_shade(c, body, SKIN, flash)
	_horn(c, DEMON_HORN, 1.0, flash)
	_horn(c, DEMON_HORN, -1.0, flash)
	_shade(c, head, SKIN, flash)
	_eyes(c, Vector2(8.6, 2.6), 1.25, flash)

	# Pitchfork: wooden shaft, iron head with three prongs.
	var hand_r := Vector2(-1.0 + dx, 12.0)
	_arm(c, Vector2(-2, 9), hand_r, 3.2, flash)
	c.draw_line(Vector2(-14 + dx, 12), Vector2(7 + dx, 12), _tone(WOOD[0], flash), 3.2)
	c.draw_line(Vector2(-14 + dx, 12), Vector2(7 + dx, 12), _tone(WOOD[1], flash), 1.8)
	_shade(c, _rect(Vector2(6 + dx, 6.5), Vector2(2.6, 11)), IRON, flash, 0.7)
	for y in [7.2, 12.0, 16.8]:
		var tip: float = (15.5 if y == 12.0 else 14.0) + dx
		c.draw_line(Vector2(8 + dx, y), Vector2(tip, y), _tone(IRON[0], flash), 2.4)
		c.draw_line(Vector2(8 + dx, y), Vector2(tip, y), _tone(IRON[2], flash), 1.0)
		c.draw_colored_polygon(PackedVector2Array([Vector2(tip - 0.5, y - 1.8), Vector2(tip + 3.0, y), Vector2(tip - 0.5, y + 1.8)]), _tone(IRON[1], flash))
	_hand(c, hand_r, 2.9, flash)
	if thrust > 0.3 and not flash:
		var alpha: float = (thrust - 0.3) / 0.7
		for y in [7.2, 12.0, 16.8]:
			c.draw_line(Vector2(9 + dx, y), Vector2(22 + dx, y), Color(1, 1, 1, 0.6 * alpha), 1.1)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.flush_to(canvas)


# ==========================================
# Hellhunter
# ==========================================

## time drives the gallop; running adds speed streaks; bite: 0..1 head snap.
static func draw_hellhunter(canvas: CanvasItem, facing: float, time: float, running: bool, bite: float, flash: bool) -> void:
	var c := _PEN
	var scale := Vector2.ONE * HOUND_SCALE
	var gait: float = sin(time * TAU * (3.4 if running else 0.8)) * (1.0 if running else 0.25)
	var body := _ngon(Vector2(-4, 0), Vector2(12.5, 6.5), 14, 0.0)
	var chest := _ngon(Vector2(5, 0), Vector2(7, 7.2), 10, 0.0)
	var snap: float = 5.0 * bite
	var head := _ngon(Vector2(12.5 + snap, 0), Vector2(5.6, 5.2), 10, 0.0)
	var snout := _ngon(Vector2(18 + snap, 0), Vector2(3.8, 3.1), 8, 0.0)

	c.draw_set_transform(Palette.SHADOW_OFFSET * 0.7, facing, scale)
	for shape in [body, chest, head, snout]:
		c.draw_colored_polygon(shape, Palette.SHADOW_COLOR)

	c.draw_set_transform(Vector2.ZERO, facing, scale)
	if running and not flash:
		for index in range(3):
			var y: float = [-6.0, 1.5, 7.0][index]
			var length: float = 14.0 + 8.0 * (0.5 + 0.5 * sin(time * 23.0 + float(index) * 2.1))
			c.draw_line(Vector2(-22, y), Vector2(-22 - length, y), Color(Palette.ACCENT_LIGHT, 0.45), 1.6)
	# Tail with a flame at its tip.
	var sway: float = sin(time * (12.0 if running else 3.0)) * 0.22
	var tail_tip := _tail(c, Vector2(-15, 0), Vector2(-21, -4), Vector2(-27, -1), sway, 2.6, flash)
	if not flash:
		var flicker: float = 1.0 + 0.25 * sin(time * 31.0)
		c.draw_circle(tail_tip, 3.4 * flicker, Color(FIRE, 0.35))
		c.draw_colored_polygon(_place(PackedVector2Array([Vector2(1, -2.6), Vector2(-6 * flicker, 0), Vector2(1, 2.6)]), tail_tip, sway), FIRE)
		c.draw_colored_polygon(_place(PackedVector2Array([Vector2(0.5, -1.2), Vector2(-3.5 * flicker, 0), Vector2(0.5, 1.2)]), tail_tip, sway), FIRE_LIGHT)
	# Paws: diagonal pairs move together.
	for paw in [[Vector2(-12, -6.8), 1.0], [Vector2(-12, 6.8), -1.0], [Vector2(7, -7.2), -1.0], [Vector2(7, 7.2), 1.0]]:
		var at: Vector2 = paw[0] + Vector2(4.0 * gait * float(paw[1]), 0.0)
		_shade(c, _ngon(at, Vector2(3.6, 2.4), 8, 0.0), SKIN, flash)
	_shade(c, body, SKIN, flash)
	_shade(c, chest, SKIN, flash)
	# Black spines along the back.
	for index in range(5):
		var x: float = -13.0 + 4.0 * float(index)
		var length: float = 4.5 + float(index) * 0.4
		c.draw_colored_polygon(PackedVector2Array([Vector2(x + 1.6, -1.6), Vector2(x + 1.6, 1.6), Vector2(x - length, 0)]), _tone(HORN[0], flash))
		c.draw_colored_polygon(PackedVector2Array([Vector2(x + 1.0, -0.9), Vector2(x + 1.0, 0.4), Vector2(x - length * 0.65, 0)]), _tone(HORN[2], flash))
	# Spiked collar.
	if not flash:
		c.draw_arc(Vector2(7.5, 0), 6.6, PI * 0.6, PI * 1.4, 10, HORN[1], 1.8)
		for angle in [-60.0, -30.0, 0.0, 30.0, 60.0]:
			c.draw_circle(Vector2(7.5, 0) + Vector2.LEFT.rotated(deg_to_rad(angle)) * 6.6, 0.9, SPIKE)
	# Ears, head, snout.
	var ear := PackedVector2Array([Vector2(9.5 + snap, -3.4), Vector2(6 + snap, -7.4), Vector2(11.6 + snap, -5)])
	_fill(c, ear, HORN[1], flash)
	_fill(c, _mirror(ear), HORN[1], flash)
	_shade(c, head, SKIN, flash)
	_shade(c, snout, SKIN, flash)
	_fill(c, _ngon(Vector2(21.6 + snap, 0), Vector2(1.3, 1.6), 6, 0.0), Color("120E0D"), flash)
	_eyes(c, Vector2(14.6 + snap, 2.4), 1.1, flash)
	if bite > 0.3 and not flash:
		var alpha: float = (bite - 0.3) / 0.7
		for side in [-1.0, 1.0]:
			c.draw_arc(Vector2(21 + snap, side * 1.5), 4.5, -PI * 0.45, PI * 0.45, 7, Color(1, 1, 1, 0.75 * alpha), 1.2)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.flush_to(canvas)


# ==========================================
# Big Demon
# ==========================================

## step: -1..1 walk; windup: 0..1 fists raised; slam: 0..1 fists down;
## wave_age: seconds since the last slam landed (< 0 = no shockwave).
static func draw_big_demon(canvas: CanvasItem, facing: float, step: float, windup: float, slam: float, wave_age: float, flash: bool) -> void:
	var c := _PEN
	var body := _ngon(Vector2(-7, 0), Vector2(18, 21), 16, 0.0)
	var head := _ngon(Vector2(10, 0), Vector2(9.5, 9.5), 12, 0.0)
	var fists: Array[Vector2] = []
	var fist_scale: float = lerpf(lerpf(1.0, 1.35, windup), 0.95, slam)
	for side in [-1.0, 1.0]:
		var idle := Vector2(12.0 + step * 3.0 * side, 28.0 * side)
		var raised := Vector2(4.0, 24.0 * side)
		var down := Vector2(22.0, 18.0 * side)
		fists.append(idle.lerp(raised, windup).lerp(down, slam))

	c.draw_set_transform(Palette.SHADOW_OFFSET, facing, Vector2.ONE)
	for shape in [body, head]:
		c.draw_colored_polygon(shape, Palette.SHADOW_COLOR)
	for side in [-1.0, 1.0]:
		c.draw_colored_polygon(_ngon(Vector2(-1, 20 * side), Vector2(9.5, 8.5), 10, 0.0), Palette.SHADOW_COLOR)
	for fist in fists:
		# Raised fists cast their shadow further away.
		c.draw_circle(fist + Palette.SHADOW_OFFSET * (fist_scale - 1.0) * 3.0, 6.8 * fist_scale, Palette.SHADOW_COLOR)

	c.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE)
	if wave_age >= 0.0 and wave_age < SLAM_WAVE_TIME and not flash:
		var k: float = wave_age / SLAM_WAVE_TIME
		var fade: float = 1.0 - k
		for side in [-1.0, 1.0]:
			var at := Vector2(29.0, 18.0 * side)
			for crack in [-2.5, -1.9, 1.9, 2.5, PI]:
				var direction := Vector2.RIGHT.rotated(float(crack) * side)
				c.draw_polyline(PackedVector2Array([at, at + direction * 6.0 + direction.orthogonal() * 1.5, at + direction * 13.0]), Color(HORN[0], 0.9 * fade), 1.4)
			var radius: float = lerpf(5.0, 24.0, 1.0 - pow(1.0 - k, 2.0))
			c.draw_arc(at, radius, 0.0, TAU, 28, Color(1, 1, 1, 0.85 * fade), 2.4 * fade + 0.6)
	_tail(c, Vector2(-22, 0), Vector2(-32, 9), Vector2(-40, 3), step * 0.2, 4.0, flash)
	for side in [-1.0, 1.0]:
		_shade(c, _ngon(Vector2(-1, 20 * side), Vector2(9.5, 8.5), 10, 0.0), SKIN, flash)
	_shade(c, body, SKIN, flash)
	if not flash:
		c.draw_polyline(_arc_points(Vector2(-6, 0), 12.0, PI * 0.72, PI * 1.28, 8), SKIN[0], 1.2)
		c.draw_polyline(_arc_points(Vector2(-12, 0), 9.0, PI * 0.75, PI * 1.25, 6), SKIN[0], 1.2)
	for index in range(2):
		var side: float = -1.0 if index == 0 else 1.0
		_arm(c, Vector2(-1, 20 * side), fists[index], 7.0, flash)
	_horn(c, BIG_HORN, 1.0, flash)
	_horn(c, BIG_HORN, -1.0, flash)
	_shade(c, head, SKIN, flash)
	if not flash:
		c.draw_polyline(PackedVector2Array([Vector2(13, -5), Vector2(17, -2.5), Vector2(13, -1)]), SKIN[0], 1.0)
		c.draw_polyline(PackedVector2Array([Vector2(13, 5), Vector2(17, 2.5), Vector2(13, 1)]), SKIN[0], 1.0)
	_eyes(c, Vector2(15.5, 3.6), 1.6, flash)
	for fist in fists:
		_shade(c, _ngon(fist, Vector2(6.8, 6.4) * fist_scale, 12, 0.0), SKIN, flash)
		if not flash:
			for y in [-2.5, 1.0]:
				c.draw_line(fist + Vector2(-3, y) * fist_scale, fist + Vector2(3, y) * fist_scale, SKIN[0], 0.9)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.flush_to(canvas)


# ==========================================
# Imp
# ==========================================

## time drives hovering and wing flaps; charge: 0..1 fireball growing in the
## hand; follow: 0..1 empty-handed throw follow-through.
static func draw_imp(canvas: CanvasItem, facing: float, time: float, charge: float, follow: float, flash: bool) -> void:
	var c := _PEN
	var bob := Vector2(0.0, sin(time * 5.0) * 1.6)
	var flap: float = 0.55 + 0.45 * (0.5 + 0.5 * sin(time * TAU * 3.0))
	var body := _ngon(Vector2(-1.5, 0), Vector2(5.2, 6.0), 10, 0.0)
	var head := _ngon(Vector2(3.5, 0), Vector2(4.8, 4.6), 10, 0.0)

	# Flying: a small shadow far below.
	c.draw_set_transform(Palette.SHADOW_OFFSET * 1.8, facing, Vector2.ONE * 0.85)
	for shape in [body, head]:
		c.draw_colored_polygon(shape, Palette.SHADOW_COLOR)
	for side in [-1.0, 1.0]:
		c.draw_colored_polygon(_wing(side, flap), Palette.SHADOW_COLOR)

	c.draw_set_transform(bob, facing, Vector2.ONE)
	c.draw_polyline(_bezier(Vector2(-6, 0), Vector2(-11, 4), Vector2(-15, 1), 6), _tone(SKIN[0], flash), 1.5)
	_fill(c, PackedVector2Array([Vector2(-14, -0.8), Vector2(-18, 0.6), Vector2(-15, 3)]), SKIN[0], flash)
	for side in [-1.0, 1.0]:
		var wing := _wing(side, flap)
		_fill(c, wing, WING[0], flash)
		_fill(c, _shrink(wing, 0.86), WING[1], flash)
		if not flash:
			for bone in [2, 4, 6]:
				c.draw_line(wing[0], wing[bone], WING[0], 0.9)
	_shade(c, body, SKIN, flash)
	_hand(c, Vector2(2, -6.2), 1.9, flash)
	_horn(c, IMP_HORN, 1.0, flash)
	_horn(c, IMP_HORN, -1.0, flash)
	_shade(c, head, SKIN, flash)
	_eyes(c, Vector2(6.6, 1.9), 1.0, flash)
	# Throwing hand with the fireball.
	var hand := Vector2(4.5, 7.0)
	if follow > 0.0:
		hand = hand.lerp(Vector2(9.0, 5.0), follow)
	else:
		hand = hand.lerp(Vector2(2.0, 8.0), charge)
	_arm(c, Vector2(-0.5, 5), hand, 2.4, flash)
	_hand(c, hand, 1.9, flash)
	if follow <= 0.0 and not flash:
		var flicker: float = 1.0 + 0.12 * sin(time * 29.0)
		var radius: float = lerpf(1.3, 3.8, charge) * flicker
		var ball := hand + Vector2(2.5, 0.0)
		c.draw_circle(ball, radius * 1.9, Color(FIRE, 0.25))
		c.draw_circle(ball, radius * 1.15, FIRE_DARK)
		c.draw_circle(ball, radius, FIRE)
		c.draw_circle(ball + Vector2(-0.3, -0.3) * radius, radius * 0.5, FIRE_LIGHT)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.flush_to(canvas)


## Fireball in flight (local origin = ball), with a flickering flame tail.
static func draw_fireball(canvas: CanvasItem, direction: Vector2, time: float = 0.0) -> void:
	var c := _PEN
	var flicker: float = 1.0 + 0.15 * sin(time * 37.0)
	c.draw_set_transform(Vector2.ZERO, direction.angle(), Vector2.ONE)
	c.draw_circle(Vector2.ZERO, 10.0 * flicker, Color(FIRE, 0.22))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-3, -5.5), Vector2(-22 * flicker, 0), Vector2(-3, 5.5)]), Color(FIRE, 0.55))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-2, -3.2), Vector2(-13 * flicker, 0), Vector2(-2, 3.2)]), Color(FIRE_LIGHT, 0.75))
	c.draw_circle(Vector2.ZERO, 6.2, FIRE_DARK)
	c.draw_circle(Vector2.ZERO, 5.0, FIRE)
	c.draw_circle(Vector2(-1.2, -1.2), 2.5, FIRE_LIGHT)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.flush_to(canvas)


# ==========================================
# Helpers
# ==========================================

static func _wing(side: float, flap: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in IMP_WING:
		var p: Vector2 = point
		# Flapping folds the wing toward the body (shorter sideways reach).
		points.append(Vector2(p.x, -p.y * side * flap))
	return points


static func _tail(c: Object, from: Vector2, control: Vector2, to: Vector2, sway: float, width: float, flash: bool) -> Vector2:
	var points := _place(_bezier(Vector2.ZERO, control - from, to - from, 7), from, sway)
	c.draw_polyline(points, _tone(SKIN[0], flash), width)
	var tip: Vector2 = points[points.size() - 1]
	var direction: Vector2 = (tip - points[points.size() - 2]).normalized()
	var side := direction.orthogonal()
	_fill(c, PackedVector2Array([tip + side * 2.6, tip + direction * 4.0, tip - side * 2.6]), SKIN[0], flash)
	return tip


static func _horn(c: Object, shape: Array, side: float, flash: bool) -> void:
	var points := PackedVector2Array()
	for point in shape:
		points.append(Vector2(point.x, point.y * side))
	_fill(c, points, HORN[0], flash)
	if not flash:
		c.draw_colored_polygon(_shrink(points, 0.72), HORN[1])
		var lit := PackedVector2Array([points[0], points[1], points[2]])
		c.draw_polyline(lit, HORN[2], 1.0)


static func _eyes(c: Object, at: Vector2, radius: float, flash: bool) -> void:
	for side in [-1.0, 1.0]:
		var center := Vector2(at.x, at.y * side)
		if not flash:
			c.draw_circle(center, radius * 2.0, Color(EYE, 0.25))
		c.draw_circle(center, radius, Palette.HIT_FLASH if flash else EYE)
		if not flash:
			c.draw_circle(center + Vector2(-0.3, -0.3), radius * 0.45, EYE_CORE)


static func _arm(c: Object, shoulder: Vector2, hand: Vector2, width: float, flash: bool) -> void:
	c.draw_line(shoulder, hand, _tone(SKIN[0], flash), width + 1.4)
	if not flash:
		c.draw_line(shoulder, hand, SKIN[1], width)


static func _hand(c: Object, center: Vector2, radius: float, flash: bool) -> void:
	c.draw_circle(center, radius + 0.7, _tone(SKIN[0], flash))
	if not flash:
		c.draw_circle(center, radius, SKIN[1])
		c.draw_circle(center + Vector2(-0.4, -0.4) * radius, radius * 0.45, SKIN[2])


static func _tone(color: Color, flash: bool) -> Color:
	return Palette.HIT_FLASH if flash else color


static func _fill(c: Object, points: PackedVector2Array, color: Color, flash: bool) -> void:
	c.draw_colored_polygon(points, _tone(color, flash))


static func _shade(c: Object, points: PackedVector2Array, tones: Array[Color], flash: bool, inset: float = 0.82) -> void:
	if points.size() < 3:
		return
	if flash:
		c.draw_colored_polygon(points, Palette.HIT_FLASH)
		return
	c.draw_colored_polygon(points, tones[0])
	var inner := _shrink(points, inset)
	c.draw_colored_polygon(inner, tones[1])
	var center := _centroid(inner)
	var reach: float = 0.0
	for point in inner:
		reach = maxf(reach, point.distance_to(center))
	var normal := Vector2(0.707, 0.707)
	var facet := _clip(inner, normal, normal.dot(center) - reach * 0.2)
	if facet.size() >= 3:
		c.draw_colored_polygon(facet, tones[2])


static func _rect(position: Vector2, size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([position, position + Vector2(size.x, 0), position + size, position + Vector2(0, size.y)])


static func _mirror(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(Vector2(point.x, -point.y))
	return result


static func _bezier(a: Vector2, b: Vector2, d: Vector2, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(steps + 1):
		var t: float = float(index) / float(steps)
		points.append(a.lerp(b, t).lerp(b.lerp(d, t), t))
	return points


static func _arc_points(center: Vector2, radius: float, from: float, to: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(steps + 1):
		points.append(center + Vector2.RIGHT.rotated(lerpf(from, to, float(index) / float(steps))) * radius)
	return points


static func _ngon(center: Vector2, radius: Vector2, sides: int, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(sides):
		var angle: float = rotation + TAU * float(index) / float(sides)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points


static func _place(points: PackedVector2Array, origin: Vector2, angle: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(origin + point.rotated(angle))
	return result


static func _shrink(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var center := _centroid(points)
	var result := PackedVector2Array()
	for point in points:
		result.append(center + (point - center) * amount + Vector2(-0.5, -0.7) * amount)
	return result


static func _centroid(points: PackedVector2Array) -> Vector2:
	var total := Vector2.ZERO
	for point in points:
		total += point
	return total / float(maxi(points.size(), 1))


## Keeps the part of a convex polygon where normal.dot(p) <= limit.
static func _clip(points: PackedVector2Array, normal: Vector2, limit: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var count := points.size()
	for index in range(count):
		var a: Vector2 = points[index]
		var b: Vector2 = points[(index + 1) % count]
		var da: float = normal.dot(a) - limit
		var db: float = normal.dot(b) - limit
		if da <= 0.0:
			result.append(a)
		if (da <= 0.0) != (db <= 0.0):
			result.append(a.lerp(b, da / (da - db)))
	return result
