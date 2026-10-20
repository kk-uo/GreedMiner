extends Node2D

## Dwarven mine tracks on the rock rim around the hold, with ore carts (most
## with a dwarf riding in them) rolling along. No closed loop and no mirror
## symmetry: each layout mixes rim tracks with spurs that run down a timber
## ramp onto the hall floor and end at a buffer stop. A couple of dwarves sit
## on the trestle edge swinging their legs.
##
## Performance: the tracks themselves (sleepers, rails, trestles, mouths) are
## drawn once on this node; carts, lantern flicker and the sitting dwarves are
## drawn every frame on a small child layer.
##
## AsteroidHangar adds it as a child scaled by LAYOUT_SCALE (mock coords).
## Load with preload(); no class_name on purpose.

const RAIL := Color("6A6E75")
const RAIL_DARK := Color("2B2D31")
const SLEEPER := Color("5A3E28")
const PLANK := Color("7A5638")
const PLANK_DARK := Color("3B2A1E")
const CART := Color("2B2D31")
const CART_IN := Color("45484E")
const CART_RIM := Color("9A6E46")
const LANTERN := Color("FFD23F")
const SHADOW := Color(0.0, 0.0, 0.0, 0.3)
const BRIDGE_SHADOW := Vector2(9.0, 13.0)
const TUNICS: Array[Color] = [Color("7A5A3A"), Color("3F5A78"), Color("8A3B2E"), Color("4F6B4A"), Color("6B4F7A")]

## Which LAYOUTS entry is used.
@export var layout: int = 0

## Track: control points (mock, smoothed), "bridges" (raised trestle spans as
## length fractions), "ramps" (spans that slope down to the floor: the shadow
## shrinks to nothing), "start"/"end" = &"mouth" or &"buffer", cart timing and
## loads ({ore, rider, back_ore}). "sitters": dwarves sitting on the trestle
## edge, [fraction, side (+1/-1)].
const LAYOUTS := [
	# A: "Down to the Warehouse" - the top trestle runs from the left mouth
	# across the rim and ramps down the right side to a floor siding by the
	# star map; a left wall track; a short spur from the lower left into the
	# hall beside the lab.
	{
		"tracks": [
			{"points": [Vector2(18, 196), Vector2(96, 150), Vector2(300, 98), Vector2(520, 78), Vector2(760, 80), Vector2(960, 96), Vector2(1110, 132), Vector2(1172, 196), Vector2(1150, 290), Vector2(1092, 352), Vector2(1078, 418)],
				"bridges": [[0.0, 0.8]], "ramps": [[0.8, 0.9]], "start": &"mouth", "end": &"buffer", "trip": 8.0, "wait": 3.0,
				"carts": [{"ore": "gold", "rider": true, "back_ore": "empty"}], "sitters": [[0.22, -1.0], [0.47, -1.0]]},
			{"points": [Vector2(70, -20), Vector2(40, 60), Vector2(26, 160), Vector2(30, 300), Vector2(34, 380)],
				"bridges": [], "ramps": [], "start": &"mouth", "end": &"mouth", "trip": 6.0, "wait": 5.0, "carts": [{"ore": "stone"}]},
			{"points": [Vector2(40, 470), Vector2(92, 446), Vector2(150, 420), Vector2(206, 404)],
				"bridges": [], "ramps": [[0.35, 0.8]], "start": &"mouth", "end": &"buffer", "trip": 4.0, "wait": 4.0,
				"carts": [{"ore": "crystal", "rider": true}]},
		],
		"mouths": [[Vector2(18, 196), Vector2(1, -0.5)], [Vector2(70, -20), Vector2(-0.3, 1)], [Vector2(34, 380), Vector2(0, -1)], [Vector2(40, 470), Vector2(1, -0.4)]],
	},
	# B (in use): a trestle from the right mouth crosses most of the top and
	# dives into the rock at a high mouth; a right wall track drops onto the
	# floor next to the Warehouse.
	{
		"tracks": [
			{"points": [Vector2(1262, 186), Vector2(1150, 130), Vector2(960, 92), Vector2(720, 78), Vector2(500, 76), Vector2(360, 60), Vector2(300, 18)],
				"bridges": [[0.0, 0.92]], "ramps": [], "start": &"mouth", "end": &"mouth", "trip": 7.5, "wait": 3.0,
				"carts": [{"ore": "gold", "rider": true, "back_ore": "empty"}], "sitters": [[0.3, -1.0], [0.62, -1.0]]},
			{"points": [Vector2(1250, 330), Vector2(1238, 420), Vector2(1180, 470), Vector2(1110, 470), Vector2(1088, 460)],
				"bridges": [], "ramps": [[0.45, 0.85]], "start": &"mouth", "end": &"buffer", "trip": 5.0, "wait": 4.0,
				"carts": [{"ore": "crystal", "rider": true}]},
		],
		"mouths": [[Vector2(1262, 186), Vector2(-1, -0.4)], [Vector2(300, 18), Vector2(0.4, 1)], [Vector2(1250, 330), Vector2(0, 1)]],
	},
	# C: "One long line" - a single winding trestle starts high on the left,
	# runs along the top, swings down the right rim and ramps onto the floor
	# below the star map; a short stub on the lower left ends at a buffer on
	# the rim (a parked cart).
	{
		"tracks": [
			{"points": [Vector2(120, 30), Vector2(180, 92), Vector2(330, 100), Vector2(470, 70), Vector2(640, 86), Vector2(800, 70), Vector2(960, 98), Vector2(1100, 120), Vector2(1190, 190), Vector2(1196, 300), Vector2(1150, 380), Vector2(1100, 400), Vector2(1040, 392)],
				"bridges": [[0.0, 0.84]], "ramps": [[0.84, 0.94]], "start": &"mouth", "end": &"buffer", "trip": 10.0, "wait": 3.5,
				"carts": [{"ore": "gold", "rider": true, "back_ore": "empty"}, {"ore": "stone", "rider": true, "delay": 0.5}], "sitters": [[0.18, -1.0], [0.4, 1.0], [0.56, -1.0]]},
			{"points": [Vector2(24, 560), Vector2(80, 590), Vector2(150, 640), Vector2(230, 668)],
				"bridges": [], "ramps": [], "start": &"mouth", "end": &"buffer", "trip": 4.0, "wait": 6.0,
				"carts": [{"ore": "crystal"}]},
		],
		"mouths": [[Vector2(120, 30), Vector2(0.4, 1)], [Vector2(24, 560), Vector2(1, 0.4)]],
	},
]

var _tracks: Array = []
var _mouths: Array = []
var _paths: Array = []
var _time: float = 0.0
var _live: Node2D


func _ready() -> void:
	var chosen: Dictionary = LAYOUTS[clampi(layout, 0, LAYOUTS.size() - 1)]
	_tracks = chosen["tracks"]
	_mouths = chosen["mouths"]
	for track in _tracks:
		_paths.append(_sample(track["points"]))
	_live = Node2D.new()
	_live.name = "Carts"
	_live.draw.connect(_draw_live)
	add_child(_live)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_live.queue_redraw()


## Catmull-Rom through the control points -> dense polyline + cumulative lengths.
func _sample(control: Array) -> Dictionary:
	var points := PackedVector2Array()
	for index in range(control.size() - 1):
		var p0: Vector2 = control[maxi(index - 1, 0)]
		var p1: Vector2 = control[index]
		var p2: Vector2 = control[index + 1]
		var p3: Vector2 = control[mini(index + 2, control.size() - 1)]
		for step in range(12):
			var t := float(step) / 12.0
			var t2 := t * t
			var t3 := t2 * t
			points.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	points.append(control[control.size() - 1])
	var lengths := PackedFloat32Array([0.0])
	for index in range(1, points.size()):
		lengths.append(lengths[index - 1] + points[index].distance_to(points[index - 1]))
	return {"points": points, "lengths": lengths, "length": lengths[lengths.size() - 1]}


## Point and heading at distance `d` along a sampled path (binary search).
func _at(path: Dictionary, d: float) -> Array:
	var points: PackedVector2Array = path["points"]
	var lengths: PackedFloat32Array = path["lengths"]
	d = clampf(d, 0.0, path["length"])
	var index := clampi(lengths.bsearch(d), 1, points.size() - 1)
	var span := maxf(lengths[index] - lengths[index - 1], 0.001)
	var k := (d - lengths[index - 1]) / span
	return [points[index - 1].lerp(points[index], k), (points[index] - points[index - 1]).normalized()]


## Sub-polyline between two length fractions.
func _slice(path: Dictionary, from: float, to: float) -> PackedVector2Array:
	var points: PackedVector2Array = path["points"]
	var lengths: PackedFloat32Array = path["lengths"]
	var a: float = from * path["length"]
	var b: float = to * path["length"]
	var result := PackedVector2Array([_at(path, a)[0]])
	for index in range(points.size()):
		if lengths[index] > a and lengths[index] < b:
			result.append(points[index])
	result.append(_at(path, b)[0])
	return result


# ==========================================
# Static layer (drawn once)
# ==========================================

## Baked once into a single mesh: thousands of sleepers and planks would
## otherwise be thousands of draw commands every frame.
var _mesh: ArrayMesh
var _pen: Object

func _draw() -> void:
	if _mesh == null:
		var batch := MeshBatch2D.new()
		_pen = batch
		_paint()
		_pen = null
		_mesh = batch.build()
	if _mesh != null:
		draw_mesh(_mesh, null)


func _paint() -> void:
	# Trestle and ramp shadows first so every track draws over them.
	for index in range(_tracks.size()):
		var path: Dictionary = _paths[index]
		for span in _tracks[index]["bridges"]:
			_pen.draw_polyline(Palette.offset_points(_slice(path, span[0], span[1]), BRIDGE_SHADOW), SHADOW, 24.0)
		for span in _tracks[index]["ramps"]:
			# The ramp descends: its shadow closes in on the track toward the floor.
			var steps := 10
			for k in range(steps):
				var a: float = lerpf(span[0], span[1], float(k) / float(steps))
				var b: float = lerpf(span[0], span[1], float(k + 1) / float(steps))
				var drop := 1.0 - (float(k) + 0.5) / float(steps)
				_pen.draw_polyline(Palette.offset_points(_slice(path, a, b), BRIDGE_SHADOW * drop), SHADOW, 22.0)
	for index in range(_tracks.size()):
		_draw_track(index)
	for mouth in _mouths:
		_draw_mouth_frame(mouth[0], (mouth[1] as Vector2).normalized())


func _draw_track(index: int) -> void:
	var track: Dictionary = _tracks[index]
	var path: Dictionary = _paths[index]
	var points: PackedVector2Array = path["points"]
	for span in track["bridges"] + track["ramps"]:
		var part := _slice(path, span[0], span[1])
		_pen.draw_polyline(part, PLANK_DARK, 24.0)
		_pen.draw_polyline(part, PLANK, 19.0)
		_ties(path, span[0], span[1], 7.0, 10.0, PLANK_DARK, 1.6)
	# Lantern posts along the trestles (the glow flickers on the live layer).
	for post in _lantern_posts(index):
		_pen.draw_circle(post, 3.2, PLANK_DARK)
		_pen.draw_circle(post, 2.2, LANTERN)
	# Sleepers, then the two rails.
	_ties(path, 0.0, 1.0, 9.0, 8.0, SLEEPER, 3.0)
	for offset in [-4.0, 4.0]:
		var rail := PackedVector2Array()
		for p in range(points.size()):
			var direction := (points[mini(p + 1, points.size() - 1)] - points[maxi(p - 1, 0)]).normalized()
			rail.append(points[p] + Vector2(-direction.y, direction.x) * offset)
		_pen.draw_polyline(rail, RAIL_DARK, 2.6)
		_pen.draw_polyline(rail, RAIL, 1.4)
	if track["end"] == &"buffer":
		var end: Array = _at(path, path["length"])
		_draw_buffer(end[0], end[1])


func _lantern_posts(index: int) -> Array:
	var path: Dictionary = _paths[index]
	var posts := []
	for span in _tracks[index]["bridges"]:
		var length: float = path["length"] * (span[1] - span[0])
		var count := int(length / 150.0)
		for k in range(1, count + 1):
			var at: Array = _at(path, path["length"] * span[0] + length * float(k) / float(count + 1))
			posts.append(at[0] + Vector2(-at[1].y, at[1].x) * 13.0)
	return posts


func _ties(path: Dictionary, from: float, to: float, spacing: float, half: float, color: Color, width: float) -> void:
	var d: float = from * path["length"]
	var end: float = to * path["length"]
	while d < end:
		var at: Array = _at(path, d)
		var side := Vector2(-at[1].y, at[1].x) * half
		_pen.draw_line(at[0] - side, at[0] + side, color, width)
		d += spacing


## Timber buffer stop at the end of a floor siding.
func _draw_buffer(at: Vector2, direction: Vector2) -> void:
	var side := Vector2(-direction.y, direction.x)
	var block := at + direction * 6.0
	var beam := PackedVector2Array([block - side * 11.0 - direction * 3.0, block + side * 11.0 - direction * 3.0, block + side * 11.0 + direction * 4.0, block - side * 11.0 + direction * 4.0])
	_pen.draw_colored_polygon(Palette.offset_points(beam, Vector2(3.0, 4.0)), SHADOW)
	_pen.draw_colored_polygon(beam, PLANK_DARK)
	_pen.draw_line(block - side * 9.0, block + side * 9.0, Palette.ACCENT, 2.0)
	for s in [-1.0, 1.0]:
		_pen.draw_circle(block + side * 7.0 * s - direction * 3.0, 2.0, RAIL)


func _draw_mouth_frame(at: Vector2, out: Vector2) -> void:
	var side := Vector2(-out.y, out.x)
	var back := at - out * 6.0
	var frame := PackedVector2Array([back - side * 18.0 - out * 14.0, back + side * 18.0 - out * 14.0, back + side * 18.0 + out * 10.0, back - side * 18.0 + out * 10.0])
	_pen.draw_colored_polygon(Palette.offset_points(frame, Vector2(4.0, 5.0)), SHADOW)
	_pen.draw_colored_polygon(frame, PLANK_DARK)
	var hole := PackedVector2Array([back - side * 12.0 - out * 12.0, back + side * 12.0 - out * 12.0, back + side * 12.0 + out * 7.0, back - side * 12.0 + out * 7.0])
	_pen.draw_colored_polygon(hole, Color("0E0B09"))
	_pen.draw_line(back - side * 19.0 + out * 10.0, back + side * 19.0 + out * 10.0, PLANK, 4.0)


# ==========================================
# Live layer (every frame): lantern glow, carts, sitting dwarves
# ==========================================

## Live layer: recorded into one batch and submitted as a single command.
static var _LIVE_BATCH := MeshBatch2D.new()

func _draw_live() -> void:
	var c := _LIVE_BATCH
	for index in range(_tracks.size()):
		var k := 0
		for post in _lantern_posts_cached(index):
			c.draw_circle(post, 9.0, Color(LANTERN, 0.10 + 0.05 * sin(_time * 2.0 + float(k))))
			k += 1
	for mouth in _mouths:
		var out: Vector2 = (mouth[1] as Vector2).normalized()
		var side := Vector2(-out.y, out.x)
		var back: Vector2 = (mouth[0] as Vector2) - out * 6.0
		for s in [-1.0, 1.0]:
			var lamp: Vector2 = back + side * 16.0 * s + out * 14.0
			var flicker := 0.75 + 0.25 * sin(_time * 7.0 + s * 2.0)
			c.draw_circle(lamp, 8.0, Color(Palette.ACCENT, 0.16 * flicker))
			c.draw_circle(lamp, 2.8, Color(Palette.ACCENT, flicker))
	for index in range(_tracks.size()):
		_draw_sitters(index)
		_draw_carts(index)
	_LIVE_BATCH.flush_to(_live)


var _post_cache: Dictionary = {}

func _lantern_posts_cached(index: int) -> Array:
	if not _post_cache.has(index):
		_post_cache[index] = _lantern_posts(index)
	return _post_cache[index]


func _draw_carts(index: int) -> void:
	var track: Dictionary = _tracks[index]
	var path: Dictionary = _paths[index]
	var trip: float = track["trip"]
	var wait: float = track["wait"]
	var period := (trip + wait) * 2.0
	var buffer_end: bool = track["end"] == &"buffer"
	var cart_number := 0
	for cart in track["carts"]:
		cart_number += 1
		var phase := fposmod(_time + float(cart.get("delay", 0.0)) * period, period)
		var forward := phase < trip + wait
		var local := phase if forward else phase - (trip + wait)
		var d: float
		if local > trip:
			# Waiting: inside the far mouth, or parked visibly at a buffer stop.
			if forward and buffer_end:
				d = path["length"] - 14.0
			else:
				continue
		else:
			var k := local / trip
			k = k * k * (3.0 - 2.0 * k) * 0.8 + k * 0.2  # ease in and out
			d = (k if forward else 1.0 - k) * path["length"]
			if forward and buffer_end:
				d = minf(d, path["length"] - 14.0)
		# Hidden while still inside a mouth.
		if (d < 10.0 and track["start"] == &"mouth") or (d > path["length"] - 10.0 and track["end"] == &"mouth"):
			continue
		var at: Array = _at(path, d)
		var ore := String(cart.get("ore", "gold")) if forward else String(cart.get("back_ore", cart.get("ore", "gold")))
		_draw_cart(at[0], at[1] * (1.0 if forward else -1.0), ore, bool(cart.get("rider", false)), TUNICS[(index * 2 + cart_number) % TUNICS.size()])


func _draw_cart(at: Vector2, direction: Vector2, ore: String, rider: bool, tunic: Color) -> void:
	var c := _LIVE_BATCH
	c.draw_set_transform(at + Vector2(3.0, 4.0), direction.angle(), Vector2.ONE)
	c.draw_rect(Rect2(-12, -8, 24, 16), SHADOW)
	c.draw_set_transform(at, direction.angle(), Vector2.ONE)
	Palette.draw_rounded_rect(c, Rect2(-12, -8, 24, 16), 3.0, CART)
	Palette.draw_rounded_rect(c, Rect2(-10, -6, 20, 12), 2.0, CART_IN)
	c.draw_rect(Rect2(-13, -9, 3, 18), CART_RIM)
	c.draw_rect(Rect2(10, -9, 3, 18), CART_RIM)
	match ore:
		"empty":
			pass
		"crystal":
			for spot in [Vector2(-6, -2), Vector2(-3, 3)]:
				c.draw_colored_polygon(PackedVector2Array([spot + Vector2(0, -4), spot + Vector2(3, 0), spot + Vector2(0, 3), spot + Vector2(-3, 0)]), Color("5FE6EE"))
		"stone":
			for spot in [Vector2(-6, -2), Vector2(-3, 3)]:
				c.draw_circle(spot, 3.6, Color("6E5D4F"))
				c.draw_circle(spot + Vector2(-1, -1), 1.7, Color("8C7866"))
		_:
			for spot in [Vector2(-6, -2), Vector2(-3, 3)]:
				c.draw_circle(spot, 3.6, Palette.GOLD)
			c.draw_circle(Vector2(-7, -3.5), 1.4, Color("FFF3B0"))
	if rider:
		# A dwarf riding up front: shoulders, beard, helmet and lamp.
		c.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(7, 5.0, PI / 7.0), Vector2(4, 0)), tunic)
		c.draw_colored_polygon(PackedVector2Array([Vector2(6, -2.5), Vector2(11, 0), Vector2(6, 2.5)]), Color("C98B52"))
		c.draw_circle(Vector2(3.6, 0), 3.8, Palette.SHIP_PART)
		c.draw_circle(Vector2(3.0, -0.6), 2.8, Palette.SHIP_BODY)
		c.draw_circle(Vector2(6.0, 0), 1.2, Palette.ACCENT)
	elif ore != "empty":
		for spot in [Vector2(3, -1), Vector2(6, 3)]:
			c.draw_circle(spot, 3.0, Palette.GOLD if ore == "gold" else (Color("6E5D4F") if ore == "stone" else Color("5FE6EE")))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Dwarves sitting on the trestle edge, legs dangling over the side and
## swinging, now and then looking around.
func _draw_sitters(index: int) -> void:
	var c := _LIVE_BATCH
	var path: Dictionary = _paths[index]
	var number := 0
	for sitter in _tracks[index].get("sitters", []):
		number += 1
		var at: Array = _at(path, path["length"] * float(sitter[0]))
		var along: Vector2 = at[1]
		var out := Vector2(-along.y, along.x) * float(sitter[1])
		var seat: Vector2 = (at[0] as Vector2) + out * 11.0
		var swing := sin(_time * 3.0 + float(number) * 1.7)
		var look := sin(_time * 0.7 + float(number)) * 0.6
		var tunic := TUNICS[(index + number * 2) % TUNICS.size()]
		# Legs and boots hanging over the edge.
		for s in [-1.0, 1.0]:
			var hip: Vector2 = seat + along * 2.5 * s
			var boot: Vector2 = hip + out * (6.0 + 1.5 * swing * s) + along * 0.8 * s
			c.draw_line(hip, boot, tunic.darkened(0.25), 2.6)
			c.draw_circle(boot, 1.9, Color("2E2620"))
		var facing := out.angle() + look
		var xf := Transform2D(facing, seat - out * 1.5)
		c.draw_colored_polygon(xf * Palette.regular_polygon(7, 5.0, PI / 7.0), tunic)
		c.draw_colored_polygon(xf * PackedVector2Array([Vector2(2, -2.5), Vector2(7, 0), Vector2(2, 2.5)]), Color("C98B52"))
		c.draw_circle(xf * Vector2(-0.4, 0), 3.8, Palette.SHIP_PART)
		c.draw_circle(xf * Vector2(-1.0, -0.6), 2.8, Palette.SHIP_BODY)
		c.draw_circle(xf * Vector2(2.4, 0), 1.2, Palette.ACCENT)
