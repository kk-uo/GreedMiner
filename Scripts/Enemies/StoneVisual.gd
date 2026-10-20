class_name StoneVisual
extends RefCounted

## Presentation-only drawing for the grey stone enemies (Rock Golem, Little Rock).
##
## Every enemy picks one of two body variants at random:
## - BOULDER: wide boulder shoulders, tiny sunken head, two huge fists, a purple crack.
## - CRYSTAL: a pile of rounded boulders with a purple crystal cluster on the back.
## The Rock Titan boss (draw_titan) uses the same chunks at TITAN_DRAW_SCALE.
## Each stone chunk is flat style A: dark base, mid inner, light top-left facet
## (+ optional highlight edge). Eyes, cracks and crystals use the purple accent.
## Local +X faces the ship. No gameplay code depends on this file.

enum Variant { BOULDER, CRYSTAL }

const VARIANT_COUNT: int = 2

## Seconds a slam / lunge pose lasts after an attack lands.
const ATTACK_POSE_TIME: float = 0.45

static var _golem_cache: Dictionary = {}
static var _rock_cache: Dictionary = {}


## Random visual variant for a newly spawned enemy.
static func random_variant() -> int:
	return randi() % VARIANT_COUNT


## 0..1 pose strength for an attack timer counting down from ATTACK_POSE_TIME:
## snaps in fast (impact), then eases back.
static func attack_amount(time_left: float) -> float:
	if time_left <= 0.0:
		return 0.0
	var progress: float = 1.0 - time_left / ATTACK_POSE_TIME
	if progress < 0.18:
		return progress / 0.18
	return 1.0 - ease((progress - 0.18) / 0.82, 0.6)


# ==========================================
# Rock Golem
# ==========================================

## swing: -1..1 walk cycle (fists alternate), slam: 0..1 (both fists smash forward).
static func draw_golem(canvas: CanvasItem, variant: int, facing: float, swing: float, slam: float, flash: bool) -> void:
	var geo := _golem_geometry(variant)
	var shadow: Vector2 = Palette.SHADOW_OFFSET * 1.2
	var fist_forward_l: float = swing * 6.0 + slam * 9.0
	var fist_forward_r: float = -swing * 5.0 + slam * 9.0

	if variant == Variant.BOULDER:
		var fist_y: float = lerpf(22.0, 9.0, slam)
		var fist_l := Vector2(22.0 + fist_forward_l, -fist_y)
		var fist_r := Vector2(22.0 + fist_forward_r, fist_y)
		var shoulder_y: float = lerpf(27.0, 20.0, slam)
		var arm_l := PackedVector2Array([
			Vector2(4.0, -24.0), Vector2(14.0, -shoulder_y), fist_l + Vector2(-2.0, -6.0),
			fist_l + Vector2(-4.0, 5.0), Vector2(6.0, -15.0),
		])
		var arm_r := PackedVector2Array([
			Vector2(4.0, 24.0), Vector2(14.0, shoulder_y), fist_r + Vector2(-2.0, 6.0),
			fist_r + Vector2(-4.0, -5.0), Vector2(6.0, 15.0),
		])
		var placed: Array = [
			[geo["hump"], geo["hump"]["pos"]],
			[geo["body"], geo["body"]["pos"]],
			[geo["head"], geo["head"]["pos"]],
			[geo["fist_l"], fist_l],
			[geo["fist_r"], fist_r],
		]
		# Shadow pass.
		_draw_flat(canvas, arm_l, facing, shadow, Palette.SHADOW_COLOR)
		_draw_flat(canvas, arm_r, facing, shadow, Palette.SHADOW_COLOR)
		for entry in placed:
			_draw_chunk_shadow(canvas, entry[0], entry[1], facing, shadow)
		# Body pass (back to front).
		_draw_chunk(canvas, geo["hump"], geo["hump"]["pos"], facing, flash)
		_draw_limb(canvas, arm_l, facing, flash)
		_draw_limb(canvas, arm_r, facing, flash)
		_draw_chunk(canvas, geo["body"], geo["body"]["pos"], facing, flash)
		_draw_chunk(canvas, geo["head"], geo["head"]["pos"], facing, flash)
		_draw_chunk(canvas, geo["fist_l"], fist_l, facing, flash)
		_draw_chunk(canvas, geo["fist_r"], fist_r, facing, flash)
		canvas.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE)
		if not flash:
			for fist in [fist_l, fist_r]:
				var knuckle: Vector2 = fist
				canvas.draw_line(knuckle + Vector2(5.0, -4.0), knuckle + Vector2(7.0, 4.0), Palette.STONE_DEEP, 1.6)
			_draw_crack(canvas, geo["crack"], 2.4)
			_draw_eye(canvas, Vector2(16.5, -3.0), 1.9)
			_draw_eye(canvas, Vector2(16.5, 3.0), 1.9)
	else:
		var fist_y: float = lerpf(21.0, 9.0, slam)
		var fore_y: float = lerpf(24.0, 17.0, slam)
		var parts: Array = [
			[geo["core"], geo["core"]["pos"]],
			[geo["shoulder_l"], geo["shoulder_l"]["pos"]],
			[geo["shoulder_r"], geo["shoulder_r"]["pos"]],
			[geo["fore_l"], Vector2(10.0 + fist_forward_l * 0.5, -fore_y)],
			[geo["fore_r"], Vector2(10.0 + fist_forward_r * 0.5, fore_y)],
			[geo["fist_l"], Vector2(21.0 + fist_forward_l, -fist_y)],
			[geo["fist_r"], Vector2(21.0 + fist_forward_r, fist_y)],
			[geo["head"], geo["head"]["pos"]],
		]
		for entry in parts:
			_draw_chunk_shadow(canvas, entry[0], entry[1], facing, shadow)
		for entry in parts:
			_draw_chunk(canvas, entry[0], entry[1], facing, flash)
		canvas.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE)
		if not flash:
			canvas.draw_circle(Vector2(-13.0, 0.0), 10.0, Color(Palette.ENEMY_EYE, 0.14))
			for crystal in geo["crystals"]:
				canvas.draw_colored_polygon(crystal[0], Palette.ENEMY_EYE_DEEP)
				canvas.draw_colored_polygon(crystal[1], Palette.ENEMY_EYE)
			_draw_eye(canvas, Vector2(14.0, -2.8), 1.7)
			_draw_eye(canvas, Vector2(14.0, 2.8), 1.7)

	if slam > 0.05 and not flash:
		_draw_dust(canvas, Vector2(37.0, 0.0), slam)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ==========================================
# Little Rock
# ==========================================

## step: -1..1 waddle cycle, lunge: 0..1 forward head-butt when an attack lands.
static func draw_little_rock(canvas: CanvasItem, variant: int, facing: float, step: float, lunge: float, flash: bool) -> void:
	var geo := _rock_geometry(variant)
	var shadow: Vector2 = Palette.SHADOW_OFFSET * 0.7
	var angle: float = facing + step * 0.07
	var body_pos: Vector2 = geo["body"]["pos"] + Vector2(lunge * 4.0, 0.0)
	var foot_l: Vector2 = geo["foot_l"]["pos"] + Vector2(step * 2.2, 0.0)
	var foot_r: Vector2 = geo["foot_r"]["pos"] + Vector2(-step * 2.2, 0.0)
	var parts: Array = [[geo["foot_l"], foot_l], [geo["foot_r"], foot_r], [geo["body"], body_pos]]
	for entry in parts:
		_draw_chunk_shadow(canvas, entry[0], entry[1], angle, shadow)
	for entry in parts:
		_draw_chunk(canvas, entry[0], entry[1], angle, flash)

	canvas.draw_set_transform(Vector2(lunge * 4.0, 0.0).rotated(angle), angle, Vector2.ONE)
	if not flash:
		if variant == Variant.BOULDER:
			_draw_eye(canvas, Vector2(6.0, -2.6), 1.5)
			_draw_eye(canvas, Vector2(6.0, 2.6), 1.5)
		else:
			canvas.draw_colored_polygon(geo["crystal"], Palette.ENEMY_EYE)
			_draw_eye(canvas, Vector2(5.5, -2.5), 1.4)
			_draw_eye(canvas, Vector2(5.5, 2.5), 1.4)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ==========================================
# Rock Titan (boss, "mountain colossus")
# ==========================================

## Titan geometry is authored in the same units as the golem and drawn this much larger.
## At 1.5 the titan is about 1.6x as wide as the 3x3 ship.
const TITAN_DRAW_SCALE: float = 1.5
## Approximate on-screen radius at TITAN_DRAW_SCALE (death burst, hit tests).
const TITAN_VISUAL_RADIUS: float = 165.0
## How far a hit brightens the titan toward HIT_TINT_COLOR (instead of pure white).
const TITAN_HIT_TINT: float = 0.32
const HIT_TINT_COLOR := Color("EEE6FA")
## Seconds the slam shockwave and dust stay visible.
const TITAN_SLAM_TIME: float = 0.7

static var _titan_cache: Dictionary = {}


## A walking mountain: a huge back with a purple crystal ridge, a head sunk under
## a heavy brow, fists bigger than a whole golem.
## swing: -1..1 slow walk cycle, slam: 0..1 two-fist smash (use titan_slam_amount),
## time: seconds, only drives the crystal glow pulse.
static func draw_titan(canvas: CanvasItem, facing: float, swing: float, slam: float, flash: bool, time: float = 0.0) -> void:
	var geo := _titan_geometry()
	var size: float = TITAN_DRAW_SCALE
	var angle: float = facing + swing * 0.025
	var shadow: Vector2 = Palette.SHADOW_OFFSET * 2.2
	# The boss is hit almost constantly, so instead of a pure-white flash it
	# only brightens slightly toward a pale lilac and keeps all its details.
	var tint: float = TITAN_HIT_TINT if flash else 0.0

	var fist_y: float = lerpf(84.0, 58.0, slam)
	var fist_l := Vector2(80.0 + swing * 10.0 + slam * 16.0, -fist_y)
	var fist_r := Vector2(80.0 - swing * 10.0 + slam * 16.0, fist_y)
	var elbow_out: float = 18.0 * (1.0 - slam * 0.5)
	var arm_l := Vector2(lerpf(4.0, fist_l.x, 0.45), lerpf(-72.0, fist_l.y, 0.45) - elbow_out)
	var arm_r := Vector2(lerpf(4.0, fist_r.x, 0.45), lerpf(72.0, fist_r.y, 0.45) + elbow_out)

	var parts: Array = [
		[geo["back"], geo["back"]["pos"]],
		[geo["arm_l"], arm_l], [geo["arm_r"], arm_r],
		[geo["shoulder_l"], geo["shoulder_l"]["pos"]], [geo["shoulder_r"], geo["shoulder_r"]["pos"]],
		[geo["head"], geo["head"]["pos"]], [geo["brow"], geo["brow"]["pos"]],
		[geo["fist_l"], fist_l], [geo["fist_r"], fist_r],
	]
	for entry in parts:
		_draw_chunk_shadow(canvas, entry[0], entry[1], angle, shadow, size)

	# Back, arms and shoulders first; the crystal ridge sits on the back.
	for index in range(5):
		_draw_chunk(canvas, parts[index][0], parts[index][1], angle, false, size, tint)
	canvas.draw_set_transform(Vector2.ZERO, angle, Vector2.ONE * size)
	var pulse: float = 0.5 + 0.5 * sin(time * 2.2)
	canvas.draw_circle(Vector2(-42.0, 0.0), 46.0, Color(Palette.ENEMY_EYE, 0.08 + 0.08 * pulse))
	for crystal in geo["crystals"]:
		canvas.draw_colored_polygon(crystal[0], Palette.ENEMY_EYE_DEEP)
		canvas.draw_colored_polygon(crystal[1], Palette.ENEMY_EYE)
	for crack in geo["cracks"]:
		_draw_crack(canvas, crack, 3.2)
	# Head under the brow, then the fists on top.
	for index in range(5, parts.size()):
		_draw_chunk(canvas, parts[index][0], parts[index][1], angle, false, size, tint)
	canvas.draw_set_transform(Vector2.ZERO, angle, Vector2.ONE * size)
	for fist in [fist_l, fist_r]:
		var front: Vector2 = fist
		for knuckle in [-12.0, 0.0, 12.0]:
			canvas.draw_line(front + Vector2(20.0, knuckle - 4.0), front + Vector2(24.0, knuckle + 4.0), Palette.STONE_DEEP, 2.6)
	_draw_eye(canvas, Vector2(57.0, -8.0), 4.0)
	_draw_eye(canvas, Vector2(57.0, 8.0), 4.0)

	if slam > 0.02:
		_draw_titan_shockwave(canvas, Vector2((fist_l.x + fist_r.x) * 0.5 + 34.0, 0.0), slam)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 0..1 slam pose for a timer counting down from TITAN_SLAM_TIME.
static func titan_slam_amount(time_left: float) -> float:
	if time_left <= 0.0:
		return 0.0
	var progress: float = 1.0 - time_left / TITAN_SLAM_TIME
	if progress < 0.15:
		return progress / 0.15
	return 1.0 - ease((progress - 0.15) / 0.85, 0.5)


## Expanding hexagonal dust ring plus puffs where the fists hit.
static func _draw_titan_shockwave(canvas: CanvasItem, origin: Vector2, amount: float) -> void:
	var radius: float = lerpf(70.0, 26.0, amount)
	var ring := Palette.offset_points(Palette.regular_polygon(6, radius, 0.3), origin)
	ring.append(ring[0])
	canvas.draw_polyline(ring, Color(Palette.STONE_DUST, 0.7 * amount), 5.0)
	var color := Color(Palette.STONE_DUST, 0.85 * amount)
	for puff in [[Vector2(-6.0, -40.0), 9.0], [Vector2(6.0, -16.0), 11.0], [Vector2(6.0, 16.0), 11.0], [Vector2(-6.0, 40.0), 9.0]]:
		var center: Vector2 = origin + (puff[0] as Vector2) * (1.0 + (1.0 - amount) * 0.8)
		var hexagon := Palette.regular_polygon(6, puff[1] * (0.5 + 0.5 * amount), 0.3)
		canvas.draw_colored_polygon(Palette.offset_points(hexagon, center), color)


static func _titan_geometry() -> Dictionary:
	if not _titan_cache.is_empty():
		return _titan_cache
	var geo: Dictionary = {}
	geo["back"] = _chunk(_ngon(Vector2(-34.0, 0.0), Vector2(62.0, 84.0), 10, 0.15, 0.08, 101))
	geo["shoulder_l"] = _chunk(_ngon(Vector2(4.0, -72.0), Vector2(40.0, 34.0), 8, 0.3, 0.08, 102))
	geo["shoulder_r"] = _chunk(_ngon(Vector2(4.0, 72.0), Vector2(40.0, 34.0), 8, 0.1, 0.08, 103))
	geo["arm_l"] = _chunk(_ngon(Vector2(38.0, -96.0), Vector2(24.0, 22.0), 7, 0.2, 0.08, 104), 0.0, false)
	geo["arm_r"] = _chunk(_ngon(Vector2(38.0, 96.0), Vector2(24.0, 22.0), 7, 0.5, 0.08, 105), 0.0, false)
	geo["fist_l"] = _chunk(_block_fist(Vector2(80.0, -84.0), 36.0, false))
	geo["fist_r"] = _chunk(_block_fist(Vector2(80.0, 84.0), 36.0, true))
	geo["head"] = _chunk(_ngon(Vector2(46.0, 0.0), Vector2(20.0, 21.0), 7, 0.0, 0.05, 108), 0.1, false)
	geo["brow"] = _chunk(PackedVector2Array([
		Vector2(26.0, -25.0), Vector2(46.0, -20.0), Vector2(50.0, 0.0), Vector2(46.0, 20.0), Vector2(26.0, 25.0),
	]), 0.05)
	var crystals: Array = []
	for spec in [
		[Vector2(-74.0, -10.0), 30.0, -2.3], [Vector2(-78.0, 12.0), 24.0, 2.5], [Vector2(-58.0, -16.0), 20.0, -1.8],
		[Vector2(-52.0, 14.0), 28.0, 1.95], [Vector2(-36.0, -12.0), 16.0, -1.5], [Vector2(-30.0, 10.0), 14.0, 1.4],
		[Vector2(-86.0, 0.0), 16.0, 3.1],
	]:
		crystals.append(_crystal(spec[0], spec[1], spec[2], 6.0))
	geo["crystals"] = crystals
	geo["cracks"] = [
		PackedVector2Array([Vector2(-8.0, -48.0), Vector2(-20.0, -30.0), Vector2(-10.0, -14.0), Vector2(-22.0, 6.0)]),
		PackedVector2Array([Vector2(-6.0, 46.0), Vector2(-18.0, 34.0), Vector2(-12.0, 22.0)]),
	]
	_titan_cache = geo
	return geo

# ==========================================
# Geometry (built once per variant)
# ==========================================

static func _golem_geometry(variant: int) -> Dictionary:
	if _golem_cache.has(variant):
		return _golem_cache[variant]
	var geo: Dictionary = {}
	if variant == Variant.BOULDER:
		geo["hump"] = _chunk(_ngon(Vector2(-15.0, 0.0), Vector2(9.0, 13.0), 7, 0.2, 0.1, 5))
		geo["body"] = _chunk(_ngon(Vector2(-2.0, 0.0), Vector2(19.0, 27.0), 8, PI / 8.0, 0.06, 3))
		geo["head"] = _chunk(_ngon(Vector2(13.0, 0.0), Vector2(7.0, 8.0), 6, 0.0, 0.05, 11), 0.1, false)
		geo["fist_l"] = _chunk(_block_fist(Vector2(22.0, -22.0), 10.5, false))
		geo["fist_r"] = _chunk(_block_fist(Vector2(22.0, 22.0), 10.5, true))
		geo["crack"] = PackedVector2Array([Vector2(-12.0, -9.0), Vector2(-6.0, -4.0), Vector2(-9.0, 3.0), Vector2(-3.0, 9.0)])
	else:
		geo["core"] = _chunk(_ngon(Vector2(-6.0, 0.0), Vector2(14.0, 15.0), 9, 0.0, 0.05, 33))
		geo["shoulder_l"] = _chunk(_ngon(Vector2(-2.0, -15.0), Vector2(12.0, 12.0), 9, 0.2, 0.05, 31))
		geo["shoulder_r"] = _chunk(_ngon(Vector2(-2.0, 15.0), Vector2(12.0, 12.0), 9, 0.5, 0.05, 32))
		geo["fore_l"] = _chunk(_ngon(Vector2(10.0, -24.0), Vector2(6.0, 6.0), 8, 0.0, 0.05, 36), 0.0, false)
		geo["fore_r"] = _chunk(_ngon(Vector2(10.0, 24.0), Vector2(6.0, 6.0), 8, 0.0, 0.05, 37), 0.0, false)
		geo["fist_l"] = _chunk(_slab_fist(Vector2(21.0, -21.0), 10.0, false))
		geo["fist_r"] = _chunk(_slab_fist(Vector2(21.0, 21.0), 10.0, true))
		geo["head"] = _chunk(_ngon(Vector2(10.0, 0.0), Vector2(7.0, 7.0), 8, 0.2, 0.04, 38), 0.1, false)
		var crystals: Array = []
		for spec in [[Vector2(-14.0, -3.0), 13.0, 3.6], [Vector2(-12.0, 4.0), 10.0, 2.6], [Vector2(-17.0, 2.0), 9.0, 3.1]]:
			crystals.append(_crystal(spec[0], spec[1], spec[2]))
		geo["crystals"] = crystals
	_golem_cache[variant] = geo
	return geo


static func _rock_geometry(variant: int) -> Dictionary:
	if _rock_cache.has(variant):
		return _rock_cache[variant]
	var geo: Dictionary = {}
	if variant == Variant.BOULDER:
		geo["body"] = _chunk(_ngon(Vector2.ZERO, Vector2(11.0, 10.0), 7, 0.3, 0.1, 21))
		geo["foot_l"] = _chunk(_ngon(Vector2(-2.0, -10.0), Vector2(3.4, 3.0), 5, 0.0, 0.0, 1), 0.0, false)
		geo["foot_r"] = _chunk(_ngon(Vector2(-2.0, 10.0), Vector2(3.4, 3.0), 5, 0.0, 0.0, 2), 0.0, false)
	else:
		geo["body"] = _chunk(_ngon(Vector2.ZERO, Vector2(10.5, 10.5), 9, 0.2, 0.06, 41))
		geo["foot_l"] = _chunk(_ngon(Vector2(-1.0, -10.0), Vector2(3.2, 3.0), 7, 0.0, 0.0, 1), 0.0, false)
		geo["foot_r"] = _chunk(_ngon(Vector2(-1.0, 10.0), Vector2(3.2, 3.0), 7, 0.0, 0.0, 2), 0.0, false)
		geo["crystal"] = PackedVector2Array([Vector2(-6.0, -2.0), Vector2(-13.0, -1.0), Vector2(-6.0, 3.0)])
	_rock_cache[variant] = geo
	return geo


## Angular, blocky fist with a flat knuckle face pointing forward (+X).
## mirror flips it for the right hand so both fists lean outward.
static func _block_fist(center: Vector2, size: float, mirror: bool) -> PackedVector2Array:
	var shape: Array[Vector2] = [
		Vector2(-0.9, -0.62), Vector2(-0.45, -0.95), Vector2(0.78, -0.9),
		Vector2(1.02, 0.7), Vector2(0.62, 0.95), Vector2(-0.92, 0.82),
	]
	return _shape_points(shape, center, size, mirror)


## Squarer slab fist for the crystal golem: a chipped stone block.
static func _slab_fist(center: Vector2, size: float, mirror: bool) -> PackedVector2Array:
	var shape: Array[Vector2] = [
		Vector2(-0.88, -0.86), Vector2(0.62, -0.92), Vector2(0.98, -0.5),
		Vector2(0.95, 0.88), Vector2(-0.92, 0.8),
	]
	return _shape_points(shape, center, size, mirror)


static func _shape_points(shape: Array[Vector2], center: Vector2, size: float, mirror: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	for unit in shape:
		var point := Vector2(unit.x, -unit.y if mirror else unit.y)
		points.append(center + point * size)
	if mirror:
		points.reverse()
	return points


## Heavy walk cycle, -1..1: each fist is lifted slowly, swung over, then planted
## and held for a beat before the other one moves.
static func heavy_swing(time: float, cycles_per_second: float) -> float:
	var phase: float = fposmod(time * cycles_per_second, 1.0)
	const HOLD: float = 0.18
	var move: float = 0.5 - HOLD
	if phase < HOLD:
		return -1.0
	if phase < 0.5:
		return -1.0 + 2.0 * smoothstep(0.0, 1.0, (phase - HOLD) / move)
	if phase < 0.5 + HOLD:
		return 1.0
	return 1.0 - 2.0 * smoothstep(0.0, 1.0, (phase - 0.5 - HOLD) / move)


## Irregular n-gon; the seed keeps every enemy of a variant identical.
static func _ngon(center: Vector2, radius: Vector2, sides: int, rotation: float, jitter: float, seed_value: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var points := PackedVector2Array()
	for index in range(sides):
		var angle: float = rotation + TAU * float(index) / float(sides)
		var scale: float = 1.0 + rng.randf_range(-jitter, jitter)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * scale)
	return points


## Precomputes the three flat tones of one stone chunk around its centroid.
static func _chunk(points: PackedVector2Array, light_bias: float = 0.0, highlight: bool = true) -> Dictionary:
	var center := _centroid(points)
	var base := Palette.offset_points(points, -center)
	var inner := PackedVector2Array()
	for point in base:
		inner.append(point * 0.84 + Vector2(-0.8, -1.2))
	var inner_center := _centroid(inner)
	var reach: float = 0.0
	for point in inner:
		reach = maxf(reach, point.distance_to(inner_center))
	var normal := Vector2(0.707, 0.707)
	var facet := _clip(inner, normal, normal.dot(inner_center) - reach * (0.18 + light_bias))
	var edge := PackedVector2Array()
	if highlight and facet.size() >= 3:
		edge = _clip(facet, normal, normal.dot(inner_center) - reach * (0.55 + light_bias))
	return {"pos": center, "base": base, "inner": inner, "facet": facet, "edge": edge}


static func _crystal(base_center: Vector2, length: float, angle: float, width: float = 3.2) -> Array:
	var along := Vector2.RIGHT.rotated(angle)
	var side := Vector2(-along.y, along.x) * width
	var tip: Vector2 = base_center + along * length
	var mid: Vector2 = base_center + along * length * 0.65
	var full := PackedVector2Array([base_center + side, mid + side, tip, mid - side, base_center - side])
	var lit := PackedVector2Array([base_center + side, mid + side, tip, base_center + along * length * 0.6])
	return [full, lit]


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


# ==========================================
# Drawing helpers
# ==========================================

static func _set_chunk_transform(canvas: CanvasItem, center: Vector2, facing: float, offset: Vector2, size: float = 1.0) -> void:
	canvas.draw_set_transform_matrix(Transform2D(facing, Vector2.ONE * size, 0.0, offset + (center * size).rotated(facing)))


static func _draw_chunk_shadow(canvas: CanvasItem, chunk: Dictionary, center: Vector2, facing: float, shadow: Vector2, size: float = 1.0) -> void:
	_set_chunk_transform(canvas, center, facing, shadow, size)
	canvas.draw_colored_polygon(chunk["base"], Palette.SHADOW_COLOR)


## tint 0..1 lightens the stone toward HIT_TINT_COLOR (soft hit feedback).
static func _draw_chunk(canvas: CanvasItem, chunk: Dictionary, center: Vector2, facing: float, flash: bool, size: float = 1.0, tint: float = 0.0) -> void:
	_set_chunk_transform(canvas, center, facing, Vector2.ZERO, size)
	if flash:
		canvas.draw_colored_polygon(chunk["base"], Palette.HIT_FLASH)
		return
	canvas.draw_colored_polygon(chunk["base"], Palette.STONE_DARK.lerp(HIT_TINT_COLOR, tint))
	canvas.draw_colored_polygon(chunk["inner"], Palette.STONE_MID.lerp(HIT_TINT_COLOR, tint))
	var facet: PackedVector2Array = chunk["facet"]
	if facet.size() >= 3:
		canvas.draw_colored_polygon(facet, Palette.STONE_LIGHT.lerp(HIT_TINT_COLOR, tint))
	var edge: PackedVector2Array = chunk["edge"]
	if edge.size() >= 3:
		canvas.draw_colored_polygon(edge, Palette.STONE_HI.lerp(HIT_TINT_COLOR, tint))


## Animated limbs (arms) change shape every frame, so they get two tones only.
static func _draw_limb(canvas: CanvasItem, points: PackedVector2Array, facing: float, flash: bool) -> void:
	canvas.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE)
	points = _hull(points)
	if flash:
		canvas.draw_colored_polygon(points, Palette.HIT_FLASH)
		return
	canvas.draw_colored_polygon(points, Palette.STONE_DARK)
	var center := _centroid(points)
	var inner := PackedVector2Array()
	for point in points:
		inner.append(center + (point - center) * 0.8 + Vector2(-0.8, -1.2))
	canvas.draw_colored_polygon(inner, Palette.STONE_MID)


static func _draw_flat(canvas: CanvasItem, points: PackedVector2Array, facing: float, offset: Vector2, color: Color) -> void:
	canvas.draw_set_transform(offset, facing, Vector2.ONE)
	canvas.draw_colored_polygon(_hull(points), color)


## Animated limb outlines can fold over at extreme poses; their convex hull never does.
static func _hull(points: PackedVector2Array) -> PackedVector2Array:
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.remove_at(hull.size() - 1)
	return hull


static func _draw_eye(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	canvas.draw_circle(center, radius + 1.6, Color(Palette.ENEMY_EYE, 0.35))
	canvas.draw_circle(center, radius, Palette.ENEMY_EYE)
	canvas.draw_circle(center - Vector2.ONE * radius * 0.3, radius * 0.35, Palette.ENEMY_EYE_GLOW)


static func _draw_crack(canvas: CanvasItem, points: PackedVector2Array, width: float) -> void:
	canvas.draw_polyline(points, Color(Palette.ENEMY_EYE, 0.35), width + 2.2)
	canvas.draw_polyline(points, Palette.ENEMY_EYE, width)


## Hexagonal dust puffs in front of the fists while a slam lands.
static func _draw_dust(canvas: CanvasItem, origin: Vector2, amount: float) -> void:
	var color := Color(Palette.STONE_DUST, 0.8 * amount)
	var spread: float = 1.0 + (1.0 - amount) * 0.6
	for puff in [[Vector2(1.0, -12.0), 4.0], [Vector2(4.0, 0.0), 5.0], [Vector2(0.0, 12.0), 3.5]]:
		var center: Vector2 = origin + (puff[0] as Vector2) * spread
		var hexagon := Palette.regular_polygon(6, puff[1] * (0.6 + 0.4 * amount), 0.3)
		canvas.draw_colored_polygon(Palette.offset_points(hexagon, center), color)


# ==========================================
# Red Rock (fast kamikaze pebble)
# ==========================================

const RED_TONES: Array[Color] = [Color("7A2416"), Color("B23C24"), Color("D9623A"), Color("F29A6B")]
const MAGMA := Color("FFB23A")
const MAGMA_GLOW := Color("FFE07A")
static var _red_cache: Dictionary = {}


## Red magma pebble: a jagged red rock with glowing cracks and yellow eyes.
## heat 0..1 makes the cracks and glow pulse (rises while the fuse burns).
static func draw_red_rock(canvas: CanvasItem, facing: float, step: float, heat: float, time: float, flash: bool) -> void:
	if _red_cache.is_empty():
		_red_cache["body"] = _chunk(_ngon(Vector2.ZERO, Vector2(10.5, 9.5), 7, 0.5, 0.16, 77))
		_red_cache["foot_l"] = _chunk(_ngon(Vector2(-2.0, -9.5), Vector2(3.2, 2.8), 5, 0.0, 0.0, 3), 0.0, false)
		_red_cache["foot_r"] = _chunk(_ngon(Vector2(-2.0, 9.5), Vector2(3.2, 2.8), 5, 0.0, 0.0, 4), 0.0, false)
	var shadow: Vector2 = Palette.SHADOW_OFFSET * 0.7
	var angle: float = facing + step * 0.09
	var parts: Array = [
		[_red_cache["foot_l"], _red_cache["foot_l"]["pos"] + Vector2(step * 2.6, 0.0)],
		[_red_cache["foot_r"], _red_cache["foot_r"]["pos"] + Vector2(-step * 2.6, 0.0)],
		[_red_cache["body"], _red_cache["body"]["pos"]],
	]
	var pulse: float = 0.5 + 0.5 * sin(time * lerpf(6.0, 30.0, heat))
	var glow: float = clampf(0.25 + 0.35 * pulse + 0.6 * heat, 0.0, 1.0)
	# Heat haze under the rock.
	if not flash:
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		canvas.draw_circle(Vector2.ZERO, 13.0 + 4.0 * heat, Color(MAGMA, 0.10 + 0.2 * glow))
	for entry in parts:
		_draw_chunk_shadow(canvas, entry[0], entry[1], angle, shadow)
	for entry in parts:
		var chunk: Dictionary = entry[0]
		_set_chunk_transform(canvas, entry[1], angle, Vector2.ZERO)
		if flash:
			canvas.draw_colored_polygon(chunk["base"], Palette.HIT_FLASH)
			continue
		canvas.draw_colored_polygon(chunk["base"], RED_TONES[0])
		canvas.draw_colored_polygon(chunk["inner"], RED_TONES[1])
		if (chunk["facet"] as PackedVector2Array).size() >= 3:
			canvas.draw_colored_polygon(chunk["facet"], RED_TONES[2])
		if (chunk["edge"] as PackedVector2Array).size() >= 3:
			canvas.draw_colored_polygon(chunk["edge"], RED_TONES[3])
	canvas.draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
	if not flash:
		var crack_color := MAGMA.lerp(MAGMA_GLOW, glow)
		for crack in [[Vector2(-7.0, -3.0), Vector2(-2.0, -1.0), Vector2(0.0, -5.0), Vector2(4.0, -6.0)],
				[Vector2(-6.0, 4.0), Vector2(-1.0, 3.0), Vector2(2.0, 6.5)],
				[Vector2(-1.0, -1.0), Vector2(-1.5, 3.0)]]:
			canvas.draw_polyline(PackedVector2Array(crack), Color(MAGMA, 0.35 * glow), 3.4)
			canvas.draw_polyline(PackedVector2Array(crack), crack_color, 1.4)
		for side in [-1.0, 1.0]:
			var eye := Vector2(6.0, side * 2.8)
			canvas.draw_circle(eye, 2.6, Color(MAGMA_GLOW, 0.35))
			canvas.draw_circle(eye, 1.5, MAGMA_GLOW)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
