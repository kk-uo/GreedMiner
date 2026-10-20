extends RefCounted

## Presentation-only drawing for the Demon Lord (Volcanic Planet boss, art
## option L-A "forehead eye"). Top-down, +X faces the ship, flat style A.
## Deep crimson skin, obsidian pauldrons with gold trim, a black cape, crescent
## horns, a gold circlet and a red third eye in the forehead that fires the
## laser. Hooves stick out under the cape (they are QTE weak points).
## Load with preload(); no class_name on purpose.
##
## All model geometry is in model units; MODEL_SCALE turns them into pixels.
## WEAK_POINTS are the model-unit centres of head, hands and hooves; DemonLord
## derives its clickable body-part offsets from them.

const MODEL_SCALE: float = 2.25

const SKIN: Array[Color] = [Color("5E1014"), Color("A82A26"), Color("D9503E")]
const OBSIDIAN: Array[Color] = [Color("120D0D"), Color("2A2222"), Color("4A3E3C")]
const GOLD: Array[Color] = [Color("8A6420"), Color("C99A3A"), Color("F0D27A")]
const CAPE: Array[Color] = [Color("1E0E12"), Color("3A1820"), Color("5A2A32")]
const HORN: Array[Color] = [Color("1E1514"), Color("3A2A27"), Color("64504A")]
const HOOF: Array[Color] = [Color("0E0A0A"), Color("241B1A"), Color("4A3E3C")]
const EYE := Color("FFD23F")
const GEM := Color("FF2E3A")
const LASER_GLOW := Color("FF4A1C")
const LASER := Color("FF8A2A")
const LASER_CORE := Color("FFF2C2")
const RAGE := Color("FF3D2A")

## Model-unit centres: head, left hand, right hand, left hoof, right hoof.
const HEAD := Vector2(13, 0)
const HAND := Vector2(14, 32)
const HOOF_AT := Vector2(-29, 23)
## Third-eye centre (laser origin) in model units.
const GEM_AT := Vector2(24, 0)

const CAPE_TOP := [Vector2(-2, -27), Vector2(-24, -32), Vector2(-38, -29), Vector2(-44, -22), Vector2(-40, -16),
	Vector2(-49, -9), Vector2(-43, -4), Vector2(-51, 0)]
const HORN_SHAPE := [Vector2(10, -9), Vector2(11, -16), Vector2(15, -23), Vector2(22, -28), Vector2(31, -28),
	Vector2(24, -24), Vector2(19, -19), Vector2(17, -11)]

static var _PEN := MeshBatch2D.new()


## Laser origin in node-local pixels for a given facing.
static func gem_position(facing: float) -> Vector2:
	return (GEM_AT * MODEL_SCALE).rotated(facing)


## Body model. charge: 0..1 third-eye glow; step: -1..1 walk sway;
## rage: 0..1 enrage aura; recoil: pixels pushed back (QTE break).
static func draw_body(canvas: CanvasItem, facing: float, time: float, step: float, charge: float, rage: float,
		recoil: float, flash: bool) -> void:
	var c := _PEN
	var origin := Vector2(-recoil, 0.0).rotated(facing)
	var scale := Vector2.ONE * MODEL_SCALE
	var body := _ngon(Vector2(-6, 0), Vector2(22, 26), 16, 0.0)
	var head := _ngon(HEAD, Vector2(12.5, 12.5), 12, 0.0)
	var cape := _cape()

	c.draw_set_transform(origin + Palette.SHADOW_OFFSET * 1.4, facing, scale)
	for shape in [cape, body, head]:
		c.draw_colored_polygon(shape, Palette.SHADOW_COLOR)
	for side in [-1.0, 1.0]:
		c.draw_colored_polygon(_ngon(Vector2(-6, 25 * side), Vector2(10, 8.5), 10, 0.0), Palette.SHADOW_COLOR)

	c.draw_set_transform(origin, facing, scale)
	if rage > 0.0 and not flash:
		_rage_aura(c, time, rage)
	_two_tone(c, cape, CAPE, flash)
	# Legs and hooves under the cape edge.
	for side in [-1.0, 1.0]:
		var hoof := Vector2(HOOF_AT.x, HOOF_AT.y * side)
		_limb(c, Vector2(-16, 12 * side), hoof, 6.0, flash)
		_shade(c, _ngon(hoof, Vector2(7.5, 6.5), 10, 0.0), HOOF, flash)
		if not flash:
			c.draw_colored_polygon(PackedVector2Array([hoof + Vector2(-8, -1.6), hoof + Vector2(-1, 0), hoof + Vector2(-8, 1.6)]), Color("4A3B37"))
	var sway: float = step * 1.2
	_shade(c, body, SKIN, flash)
	# Arms to the hands.
	for side in [-1.0, 1.0]:
		_limb(c, Vector2(-2, 26 * side), Vector2(HAND.x + sway * side, HAND.y * side), 6.0, flash)
	# Obsidian chest plate with gold trim and a gem.
	var chest := PackedVector2Array([Vector2(-22, -13), Vector2(0, -16), Vector2(6, 0), Vector2(0, 16), Vector2(-22, 13), Vector2(-26, 0)])
	_fill(c, chest, OBSIDIAN[1], flash)
	if not flash:
		c.draw_colored_polygon(PackedVector2Array([Vector2(-18, -9), Vector2(-4, -11), Vector2(0, -2), Vector2(-20, -2)]), OBSIDIAN[2])
		var trim := chest.duplicate()
		trim.append(chest[0])
		c.draw_polyline(trim, GOLD[1], 1.6)
		c.draw_line(Vector2(-24, 0), Vector2(4, 0), GOLD[0], 1.0)
		c.draw_colored_polygon(PackedVector2Array([Vector2(-12, -4), Vector2(-8, 0), Vector2(-12, 4), Vector2(-16, 0)]), GEM)
	# Pauldrons with spikes.
	for side in [-1.0, 1.0]:
		var at := Vector2(-6, 25 * side)
		_shade(c, _ngon(at, Vector2(10, 8.5), 12, 0.0), OBSIDIAN, flash)
		if not flash:
			c.draw_arc(at, 10.0, 0.0, TAU, 20, GOLD[1], 1.3)
		for x in [-13.0, -6.0, 1.0]:
			_fill(c, PackedVector2Array([Vector2(x - 2.5, 32 * side), Vector2(x + 2.5, 32 * side), Vector2(x, 40 * side)]), OBSIDIAN[2], flash)
	# Hands with claws.
	for side in [-1.0, 1.0]:
		var hand := Vector2(HAND.x + sway * side, HAND.y * side)
		_shade(c, _ngon(hand, Vector2(6.5, 6.5), 10, 0.0), SKIN, flash)
		for dy in [-3.0, 0.0, 3.0]:
			_fill(c, PackedVector2Array([hand + Vector2(5, dy - 1.3), hand + Vector2(11, dy), hand + Vector2(5, dy + 1.3)]), HORN[0], flash)
	# Crescent horns, head, gold circlet.
	for side in [-1.0, 1.0]:
		var horn := PackedVector2Array()
		for point in HORN_SHAPE:
			horn.append(Vector2(point.x, point.y * side))
		_two_tone(c, horn, HORN, flash)
	_shade(c, head, SKIN, flash)
	if not flash:
		c.draw_arc(HEAD, 11.0, PI * 0.62, PI * 1.38, 12, GOLD[1], 2.6)
		for side in [-1.0, 1.0]:
			c.draw_colored_polygon(PackedVector2Array([Vector2(6, 9 * side), Vector2(1, 14 * side), Vector2(9, 11 * side)]), GOLD[2])
		c.draw_colored_polygon(PackedVector2Array([Vector2(2, -3), Vector2(-4, 0), Vector2(2, 3)]), GOLD[2])
		c.draw_line(Vector2(15, -7), Vector2(20, -4), SKIN[0], 1.3)
		c.draw_line(Vector2(15, 7), Vector2(20, 4), SKIN[0], 1.3)
		for side in [-1.0, 1.0]:
			var eye := Vector2(18.5, 4.5 * side)
			c.draw_circle(eye, 3.4, Color(EYE, 0.25))
			c.draw_circle(eye, 1.8, EYE)
	# Third eye: brightens while charging.
	var gem := PackedVector2Array([Vector2(20, 0), Vector2(23.5, -3.6), Vector2(27.5, 0), Vector2(23.5, 3.6)])
	_fill(c, gem, GEM, flash)
	if not flash:
		var glow: float = 0.35 + 0.65 * charge
		c.draw_circle(GEM_AT, 4.0 + 6.0 * charge, Color(LASER_GLOW, 0.3 * glow))
		c.draw_circle(GEM_AT, 2.0 + 2.5 * charge, Color(LASER, 0.7 * glow))
		c.draw_circle(GEM_AT, 0.8 + 1.4 * charge, LASER_CORE)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.flush_to(canvas)


static func _rage_aura(c: MeshBatch2D, time: float, rage: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(time * 9.0)
	c.draw_colored_polygon(_ngon(Vector2(-8, 0), Vector2(46, 44), 24, 0.0), Color(RAGE, (0.08 + 0.08 * pulse) * rage))
	for index in range(12):
		var angle: float = TAU * float(index) / 12.0
		var flicker: float = 0.5 + 0.5 * sin(time * 13.0 + float(index) * 1.7)
		var base := Vector2(-8, 0) + Vector2(cos(angle) * 44.0, sin(angle) * 42.0)
		var out := Vector2(cos(angle), sin(angle))
		var tip := base + out * (8.0 + 6.0 * flicker)
		var side := out.orthogonal() * 3.0
		c.draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), Color(LASER, (0.35 + 0.45 * flicker) * rage))


## Charge build-up: embers drawn in toward the third eye. local pixels.
static func draw_charge_particles(canvas: CanvasItem, gem: Vector2, time: float, charge: float) -> void:
	var count: int = 16
	for index in range(count):
		var k: float = fposmod(time * 1.6 + float(index) / float(count), 1.0)
		var angle: float = float(index) * 2.399 + floor(time * 1.6 + float(index) / float(count)) * 1.3
		var distance: float = lerpf(70.0, 4.0, k * k)
		var at := gem + Vector2.RIGHT.rotated(angle) * distance
		var alpha: float = minf(k * 3.0, 1.0) * (0.5 + 0.5 * charge)
		canvas.draw_circle(at, 3.4 - 1.6 * k, Color(LASER, alpha))
		canvas.draw_line(at, at + (gem - at).normalized() * -6.0 * (1.0 - k), Color(LASER_CORE, alpha * 0.6), 1.2)


## Red aiming line from the eye to the ship: faint and flickering at first,
## brighter and steadier, then blinking fast in the last half second.
static func draw_sight_line(canvas: CanvasItem, from: Vector2, to: Vector2, progress: float, time_left: float, time: float) -> void:
	var alpha: float
	if time_left < 0.5:
		alpha = 0.95 if fposmod(time * 16.0, 1.0) < 0.5 else 0.15
	else:
		var flicker: float = 0.5 + 0.5 * sin(time * lerpf(9.0, 26.0, progress))
		alpha = lerpf(0.12, 0.7, progress) + flicker * lerpf(0.2, 0.1, progress)
	var width: float = lerpf(1.2, 3.2, progress)
	canvas.draw_line(from, to, Color(RAGE, 0.25 * alpha), width + 4.0)
	canvas.draw_line(from, to, Color(RAGE, alpha), width)
	canvas.draw_line(from, to, Color(1.0, 0.82, 0.76, alpha * 0.6), maxf(width * 0.35, 1.0))


## Thick three-layer laser with a flickering core and a flare on impact.
## k: 0..1 over the firing time.
static func draw_laser(canvas: CanvasItem, from: Vector2, to: Vector2, k: float, time: float) -> void:
	var swell: float = sin(PI * clampf(k * 1.4, 0.0, 1.0)) if k < 0.7 else (1.0 - k) / 0.3
	swell = clampf(swell, 0.0, 1.0)
	var flicker: float = 0.85 + 0.15 * sin(time * 60.0)
	var layers := [[60.0, Color(LASER_GLOW, 0.25)], [36.0, Color(LASER_GLOW, 0.6)], [22.0, LASER], [10.0 * flicker, LASER_CORE]]
	for layer in layers:
		var width: float = float(layer[0]) * swell
		if width < 0.5:
			continue
		canvas.draw_line(from, to, layer[1], width)
		canvas.draw_circle(to, width * 0.5, layer[1])
		canvas.draw_circle(from, width * 0.45, layer[1])
	# Impact flare and sparks.
	canvas.draw_circle(to, 30.0 * swell, Color(LASER, 0.45 * swell))
	canvas.draw_circle(to, 15.0 * swell, Color(LASER_CORE, 0.9 * swell))
	var back := (from - to).normalized()
	for index in range(7):
		var angle: float = (float(index) - 3.0) * 0.38 + sin(time * 40.0 + float(index)) * 0.1
		var length: float = (22.0 + 14.0 * fposmod(time * 7.0 + float(index) * 0.37, 1.0)) * swell
		canvas.draw_line(to, to + back.rotated(angle) * length, Color(LASER_CORE, 0.9 * swell), 2.4)


## Summoning circle (pixels, around center). k: 0..1 build-up; fade: 0..1 alpha.
static func draw_summoning_circle(canvas: CanvasItem, center: Vector2, radius: float, k: float, fade: float, time: float) -> void:
	if fade <= 0.01:
		return
	canvas.draw_circle(center, radius + 12.0, Color(LASER_GLOW, 0.14 * fade))
	canvas.draw_circle(center, radius, Color("2A0E0C", 0.6 * fade))
	var draw_in: float = clampf(k / 0.45, 0.0, 1.0)
	var spin: float = time * 0.6
	canvas.draw_arc(center, radius, spin, spin + TAU * draw_in, 48, Color(LASER, fade), 3.0)
	canvas.draw_arc(center, radius - 8.0, -spin, -spin + TAU * draw_in, 40, Color(LASER_GLOW, 0.8 * fade), 1.4)
	for index in range(10):
		var angle: float = spin + TAU * float(index) / 10.0
		if float(index) / 10.0 > draw_in:
			break
		var direction := Vector2.RIGHT.rotated(angle)
		canvas.draw_line(center + direction * (radius + 2.0), center + direction * (radius + 8.0), Color(LASER, fade), 2.0)
	var star_alpha: float = clampf((k - 0.35) / 0.25, 0.0, 1.0) * fade
	if star_alpha > 0.0:
		var star := PackedVector2Array()
		for index in range(6):
			star.append(center + Vector2.UP.rotated(-spin * 0.5 + float(index % 5) * TAU * 2.0 / 5.0) * (radius - 10.0))
		canvas.draw_polyline(star, Color(LASER_CORE, star_alpha), 1.8)
	# Flash right before the hounds climb out.
	if k > 0.85:
		var flash: float = (k - 0.85) / 0.15
		canvas.draw_circle(center, radius * (0.6 + 0.5 * flash), Color(LASER_CORE, 0.55 * flash * fade))


## Fire column for the teleport (pixels, screen-up). k: 0..1 over its life.
static func draw_fire_pillar(canvas: CanvasItem, base: Vector2, k: float, time: float) -> void:
	if k <= 0.0 or k >= 1.0:
		return
	var grow: float = clampf(k / 0.2, 0.0, 1.0)
	var fade: float = clampf((1.0 - k) / 0.4, 0.0, 1.0)
	var height: float = 230.0 * grow
	canvas.draw_circle(base, 70.0 * grow, Color(LASER_GLOW, 0.3 * fade))
	canvas.draw_rect(Rect2(base + Vector2(-42.0, -height), Vector2(84.0, height + 20.0)), Color(LASER, 0.45 * fade))
	canvas.draw_rect(Rect2(base + Vector2(-20.0, -height), Vector2(40.0, height + 14.0)), Color(LASER_CORE, 0.75 * fade))
	for index in range(8):
		var rise: float = fposmod(time * 1.8 + float(index) * 0.13, 1.0)
		var at := base + Vector2(-34.0 + float(index) * 10.0, 16.0 - rise * height * 0.8)
		canvas.draw_circle(at, 3.4 * (1.0 - rise) + 1.0, Color(LASER_CORE, fade))


## After a broken charge: the eye backfires (burst), stars circle the head
## and smoke rises. k: 0..1 over the recovery.
static func draw_backfire(canvas: CanvasItem, gem: Vector2, head: Vector2, k: float, time: float, recovery: float) -> void:
	var age: float = k * recovery
	if age < 0.35:
		var b: float = age / 0.35
		canvas.draw_circle(gem, lerpf(8.0, 34.0, b), Color(1, 1, 1, 0.85 * (1.0 - b)))
		canvas.draw_arc(gem, lerpf(8.0, 48.0, b), 0.0, TAU, 32, Color(LASER, 1.0 - b), 3.0 * (1.0 - b) + 0.6)
		for index in range(7):
			var direction := Vector2.RIGHT.rotated(TAU * float(index) / 7.0 + 0.3)
			var at := gem + direction * lerpf(6.0, 44.0, b)
			canvas.draw_colored_polygon(PackedVector2Array([at - direction.orthogonal() * 2.5, at + direction * 6.0, at + direction.orthogonal() * 2.5]), Color(GEM, 1.0 - b))
	var fade: float = clampf((1.0 - k) / 0.15, 0.0, 1.0)
	for index in range(3):
		var angle: float = time * 5.0 + TAU * float(index) / 3.0
		var at := head + Vector2(cos(angle) * 22.0, sin(angle) * 9.0) + Vector2(0.0, -6.0)
		_star(canvas, at, 7.0, Color(Palette.GOLD, fade))
	for index in range(4):
		var rise: float = fposmod(time * 0.8 + float(index) * 0.25, 1.0)
		canvas.draw_circle(gem + Vector2(-6.0 + float(index) * 4.0, -rise * 40.0), 5.0 + rise * 8.0, Color("5A4741", 0.5 * (1.0 - rise) * fade))


## After the laser: the eye vents steam while it cools. k: 0..1.
static func draw_cooling(canvas: CanvasItem, gem: Vector2, k: float, time: float) -> void:
	var fade: float = clampf((1.0 - k) / 0.3, 0.0, 1.0)
	for index in range(3):
		var rise: float = fposmod(time * 1.1 + float(index) * 0.33, 1.0)
		canvas.draw_circle(gem + Vector2(-4.0 + float(index) * 4.0, -rise * 34.0), 4.0 + rise * 6.0, Color(Palette.STONE_DUST, 0.55 * (1.0 - rise) * fade))


static func _star(canvas: CanvasItem, at: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(10):
		var r: float = radius if index % 2 == 0 else radius * 0.45
		points.append(at + Vector2.UP.rotated(TAU * float(index) / 10.0) * r)
	canvas.draw_colored_polygon(points, color)


static func _cape() -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in CAPE_TOP:
		points.append(point)
	for index in range(CAPE_TOP.size() - 1, -1, -1):
		var point: Vector2 = CAPE_TOP[index]
		points.append(Vector2(point.x, -point.y))
	return points


static func _limb(c: Object, from: Vector2, to: Vector2, width: float, flash: bool) -> void:
	c.draw_line(from, to, Palette.HIT_FLASH if flash else SKIN[0], width + 3.0)
	if not flash:
		c.draw_line(from, to, SKIN[1], width)


static func _two_tone(c: Object, points: PackedVector2Array, tones: Array[Color], flash: bool) -> void:
	_fill(c, points, tones[0], flash)
	if not flash:
		c.draw_colored_polygon(DemonVisual._shrink(points, 0.8), tones[1])


static func _fill(c: Object, points: PackedVector2Array, color: Color, flash: bool) -> void:
	c.draw_colored_polygon(points, Palette.HIT_FLASH if flash else color)


static func _shade(c: Object, points: PackedVector2Array, tones: Array[Color], flash: bool) -> void:
	DemonVisual._shade(c, points, tones, flash)


static func _ngon(center: Vector2, radius: Vector2, sides: int, rotation: float) -> PackedVector2Array:
	return DemonVisual._ngon(center, radius, sides, rotation)
