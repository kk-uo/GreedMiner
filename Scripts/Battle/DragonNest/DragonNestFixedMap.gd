class_name DragonNestFixedMap
extends Node2D

## The Dragon Nest lair: an old dwarven king's hall
## taken by red dragons. Octagonal flagstone plaza with the landing rune ring,
## a "sea of gold" carpeting the floor around it, three treasure mountains
## with stone thrones (the hoards draw their own gold), lava forge channels
## with bridges, and a huge dragon tunnel in each side wall where the Ancient
## Dragon appears. Baked once into a single mesh; only the lava shimmer and
## steam are redrawn each frame.
## Local frame: the node sits on the ship centre.
## The hall layout (plaza, rivers, castles, tunnels) is fixed; the loose gold,
## gems, treasure and old remains (knights, ribcages, statue head, blocks,
## swords, chests, scorches, claw marks) are scattered from a per-battle seed
## and the four corner set pieces swap corners (Claude sync 90). Phase two of
## the Ancient Dragon makes the hall rage (set_raging): red light, glowing
## cracks, boiling gold rivers and drifting embers.

const STONE: Array[Color] = [Color("3A3C34"), Color("585A4E"), Color("7A7C6C"), Color("9A9C8A")]
const GOLD: Array[Color] = [Color("8A5A12"), Color("C98A1E"), Color("F2C14A"), Color("FFE9A0")]
const FLOOR := Color("2A211D")
## The channels run with molten gold (the dragons melt their loot down).
const LAVA := Color("F2B53A")
const PLAZA_RADIUS := 470.0
const LAVA_X := 760.0
const STEAM_VENTS: Array[Vector2] = [Vector2(-330, -120), Vector2(380, 80), Vector2(-60, 380)]
## Braziers relative to the treasure corner piece.
const BRAZIER_OFFSETS: Array[Vector2] = [Vector2(-100, -100), Vector2(110, 100)]
const ROCKS: Array[Vector2] = [Vector2(-640, -40), Vector2(-250, -460), Vector2(240, -470), Vector2(650, -20), Vector2(-200, 470), Vector2(180, 480)]

var ship_center: Vector2
var hoard_positions: Array[Vector2] = []
var entrance_position: Vector2
var _mesh: ArrayMesh
## Floor and the gold rivers; the flowing ripples go between this and _mesh
## (bridges and everything else sit on top of the rivers).
var _mesh_under: ArrayMesh
## Per river: sampled points, cumulative length, total length.
var _river_paths: Array[Dictionary] = []
var _rivers: Array[PackedVector2Array] = []
var _time: float = 0.0
var _wait: float = 0.0
var _seed: int = DragonNestRules.MAP_SEED
## Fire braziers beside the treasure corner (wherever it landed).
var _braziers: Array[Vector2] = []
## Old remains / loot picked for this battle: [kind, position, rotation, scale].
var _props: Array = []
## Phase-two rage (0..1) and its glowing floor cracks.
var rage: float = 0.0
var _cracks: Array[PackedVector2Array] = []
var _rage_tween: Tween


func configure(center: Vector2, treasures: Array[Vector2], entrance: Vector2, lair_seed: int = DragonNestRules.MAP_SEED) -> void:
	_seed = lair_seed
	ship_center = center
	hoard_positions = treasures.duplicate()
	entrance_position = entrance
	global_position = center
	_rivers.clear()
	for sd in [-1.0, 1.0]:
		var river := PackedVector2Array()
		for i in range(25):
			var y := -1200.0 + float(i) * 100.0
			river.append(Vector2(sd * LAVA_X + sd * 40.0 * sin(float(i) * 0.7) + sd * 30.0 * sin(y / 170.0), y))
		_rivers.append(river)
	_mesh = _bake()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_wait -= delta
	if _wait <= 0.0:
		_wait = 1.0 / 20.0
		queue_redraw()


func _draw() -> void:
	if _mesh_under != null:
		draw_mesh(_mesh_under, null)
	_draw_river_flow()
	if _mesh != null:
		draw_mesh(_mesh, null)
	# brazier flames (bottom-right corner)
	_draw_rage_under()
	for b in _braziers:
		var flick := sin(_time * 11.0 + b.x) * 0.15
		draw_circle(b, 46.0 * (1.0 + rage * 0.6), Color(1.0, 0.55, 0.15, 0.10 + 0.04 * sin(_time * 5.0 + b.y) + 0.08 * rage))
		for k in range(3):
			var h := (26.0 + 8.0 * sin(_time * 9.0 + float(k) * 2.1 + b.x)) * (1.0 + rage * 0.7)
			var base := b + Vector2((float(k) - 1.0) * 7.0, 2.0)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-7, 0), base + Vector2(sin(_time * 7.0 + k) * 4.0, -h * (1.0 + flick)), base + Vector2(7, 0)]), Color("E2572A", 0.9))
			draw_colored_polygon(PackedVector2Array([base + Vector2(-3.5, 0), base + Vector2(0, -h * 0.55), base + Vector2(3.5, 0)]), Color("FFD23F", 0.95))
	for vent in STEAM_VENTS:
		for k in range(3):
			var phase := fmod(_time * 0.35 + float(k) / 3.0, 1.0)
			draw_circle(vent + Vector2(phase * 14.0, -phase * 46.0), 14.0 + phase * 22.0, Color(0.91, 0.86, 0.78, 0.16 * (1.0 - phase)))
	_draw_rage_over()


## Molten gold drifting downstream: soft lighter swells and darker eddies
## that slide along each river (no hard lines), plus a slow warm glow.
func _draw_river_flow() -> void:
	for path in _river_paths:
		var points: PackedVector2Array = path["points"]
		var lengths: PackedFloat32Array = path["lengths"]
		var total: float = path["total"]
		for i in range(0, points.size(), 6):
			var glow := 0.07 + 0.04 * sin(_time * 1.5 + float(i) * 0.3)
			draw_circle(points[i], 64.0, Color(1.0, 0.78, 0.3, glow))
		var count := int(total / 70.0)
		for k in range(count):
			var dist := fmod(float(k) * 70.0 + _time * (26.0 + float(k % 3) * 6.0), total)
			var index := lengths.bsearch(dist)
			index = clampi(index, 1, points.size() - 1)
			var a := points[index - 1]
			var b := points[index]
			var span := maxf(lengths[index] - lengths[index - 1], 0.001)
			var at := a.lerp(b, clampf((dist - lengths[index - 1]) / span, 0.0, 1.0))
			var heading := (b - a).angle()
			var wobble := sin(_time * 1.3 + float(k) * 1.7)
			var side := Vector2.from_angle(heading + PI * 0.5) * wobble * 4.0
			if k % 2 == 0:
				draw_colored_polygon(_ripple(at + side, heading, 24.0 + 6.0 * wobble, 6.0), Color(1.0, 0.86, 0.48, 0.45))
				draw_colored_polygon(_ripple(at + side - Vector2(2, 2), heading, 11.0, 3.0), Color(1.0, 0.95, 0.75, 0.35))
			else:
				draw_colored_polygon(_ripple(at - side, heading, 20.0, 5.0), Color(0.62, 0.38, 0.08, 0.35))


func _ripple(c: Vector2, heading: float, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(10):
		var a := TAU * float(i) / 10.0
		points.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(heading))
	return points


func _bake() -> ArrayMesh:
	var pen := MeshBatch2D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = DragonNestRules.MAP_SEED
	pen.draw_rect(Rect2(-2200, -1500, 4400, 3000), FLOOR)
	for k in range(110):
		var p := Vector2(rng.randf_range(-2000, 2000), rng.randf_range(-1300, 1300))
		pen.draw_colored_polygon(DragonNestArt.ellipse(p, rng.randf_range(80, 200), rng.randf_range(60, 150), 7, rng.randf(), k, 0.3), [Color("251D19"), Color("30261F"), Color("2D231E"), Color("352A23")][k % 4])
	for river in _rivers:
		_lava_river(pen, river, 34.0)
	_river_paths.clear()
	for river in _rivers:
		var dense := PackedVector2Array()
		for i in range(river.size() - 1):
			for k in range(6):
				dense.append(river[i].lerp(river[i + 1], float(k) / 6.0))
		dense.append(river[river.size() - 1])
		var lengths := PackedFloat32Array([0.0])
		for i in range(1, dense.size()):
			lengths.append(lengths[i - 1] + dense[i - 1].distance_to(dense[i]))
		_river_paths.append({"points": dense, "lengths": lengths, "total": lengths[lengths.size() - 1]})
	_mesh_under = pen.build()
	pen = MeshBatch2D.new()
	_hall_floor(pen)
	_pick_props()
	_scatter_treasure(pen)
	for sd in [-1.0, 1.0]:
		_bridge(pen, Vector2(sd * LAVA_X, 0.0), 90.0, 150.0)
	_draw_props(pen, [&"scorch", &"claw"])
	_draw_props(pen, [&"statue", &"block", &"ribcage", &"knight"])
	_corner_pieces(pen)
	for i in range(ROCKS.size()):
		_stalagmite(pen, ROCKS[i], 1.2, i)
	for p in [Vector2(-900, 300), Vector2(-980, -200), Vector2(930, -330), Vector2(1000, 240), Vector2(-300, -700), Vector2(320, 700), Vector2(-700, 700), Vector2(700, -700), Vector2(-1200, 520), Vector2(1220, -520)]:
		_stalagmite(pen, p, 1.6, int(p.x + p.y))
	for vent in STEAM_VENTS:
		pen.draw_circle(vent, 10.0, Color("141110"))
	_draw_props(pen, [&"sword", &"chest", &"crown", &"goblet"])
	# thrones on their daises, behind each hoard (the hoard draws its own gold)
	for index in range(hoard_positions.size()):
		var h := hoard_positions[index] - ship_center
		var away := h.angle()
		var scale_value: float = [0.85, 0.95, 1.2][mini(index, 2)]
		var pile := float(DragonNestRules.HOARDS[mini(index, DragonNestRules.HOARDS.size() - 1)].get("pile", 90.0))
		_throne(pen, h + Vector2.from_angle(away) * DragonNestRules.throne_offset(pile), away + PI, scale_value, index == 2)
	_cave_walls(pen, rng)
	for sd in [-1.0, 1.0]:
		_castle(pen, sd)
	pen.draw_set_transform(Vector2.ZERO)
	return pen.build()


# ------------------------------------------------------------------ pieces

## Set pieces in the four corners of the hall: a giant dragon skull sunk in
## gold, a golden dragon statue, a clutch of dragon eggs, and fire braziers
## by a stack of treasure chests.
func _corner_pieces(pen: MeshBatch2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 31
	var corners: Array[Vector2] = [Vector2(-1000, -660), Vector2(1000, -660), Vector2(-1000, 660), Vector2(1000, 660)]
	# Shuffle which piece sits in which corner, and nudge each a little.
	for i in range(corners.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := corners[i]
		corners[i] = corners[j]
		corners[j] = swap
	var jitter := func() -> Vector2: return Vector2(rng.randf_range(-45.0, 45.0), rng.randf_range(-35.0, 35.0))
	_giant_skull(pen, corners[0] + jitter.call(), deg_to_rad(rng.randf_range(-10.0, 50.0)))
	_gold_statue(pen, corners[1] + jitter.call())
	_egg_clutch(pen, corners[2] + jitter.call())
	_treasure_corner(pen, corners[3] + jitter.call())


func _giant_skull(pen: MeshBatch2D, c: Vector2, rot: float) -> void:
	DragonNestArt.gold_mound(pen, c + Vector2(-40, 50), 90.0, 4401, 2)
	DragonNestArt.gold_mound(pen, c + Vector2(80, -30), 60.0, 4402, 1)
	var bone := Color("D8CDB4")
	var bone_dark := Color("A89C82")
	pen.draw_set_transform(c, rot)
	pen.draw_colored_polygon(DragonNestArt.ellipse(Vector2(14, 18), 150, 70, 20), Color(0, 0, 0, 0.35))
	# horns sweeping back
	for sd in [-1.0, 1.0]:
		pen.draw_colored_polygon(PackedVector2Array([Vector2(-30, sd * 40), Vector2(-150, sd * 95), Vector2(-175, sd * 80), Vector2(-60, sd * 22)]), bone_dark)
		pen.draw_colored_polygon(PackedVector2Array([Vector2(-30, sd * 40), Vector2(-150, sd * 95), Vector2(-90, sd * 40)]), bone)
	# cranium and long snout
	var skull := PackedVector2Array([Vector2(-80, -50), Vector2(10, -62), Vector2(70, -40), Vector2(150, -24), Vector2(178, 0), Vector2(150, 24), Vector2(70, 40), Vector2(10, 62), Vector2(-80, 50), Vector2(-100, 0)])
	pen.draw_colored_polygon(skull, bone_dark)
	var lit := PackedVector2Array()
	for p in skull:
		lit.append(p * 0.88 + Vector2(-6, -6))
	pen.draw_colored_polygon(lit, bone)
	# eye sockets with gold coins glinting inside
	for sd in [-1.0, 1.0]:
		pen.draw_colored_polygon(DragonNestArt.ellipse(Vector2(20, sd * 30), 24, 16, 12), Color("1a1410"))
		pen.draw_circle(Vector2(24, sd * 30), 6.0, Color("F2C14A"))
		pen.draw_circle(Vector2(22, sd * 28), 2.4, Color("FFE9A0"))
	# nostrils, brow ridge, teeth
	pen.draw_circle(Vector2(155, -9), 5.0, Color("1a1410"))
	pen.draw_circle(Vector2(155, 9), 5.0, Color("1a1410"))
	pen.draw_line(Vector2(-60, 0), Vector2(120, 0), bone_dark, 6.0)
	for k in range(7):
		var x := 60.0 + k * 15.0
		for sd in [-1.0, 1.0]:
			pen.draw_colored_polygon(PackedVector2Array([Vector2(x, sd * (40.0 - k * 2.4)), Vector2(x + 6, sd * (52.0 - k * 2.4)), Vector2(x + 10, sd * (38.0 - k * 2.4))]), Color("F2EAD9"))
	pen.draw_set_transform(Vector2.ZERO)
	# a sword stuck in its skull
	_sword(pen, c + Vector2(-20, -10).rotated(rot), rot - 0.9)


func _gold_statue(pen: MeshBatch2D, c: Vector2) -> void:
	# round pedestal with steps
	pen.draw_circle(c + Vector2(10, 14), 120.0, Color(0, 0, 0, 0.35))
	pen.draw_circle(c, 120.0, STONE[0])
	pen.draw_circle(c, 108.0, STONE[1])
	pen.draw_circle(c, 92.0, STONE[2])
	for i in range(12):
		var a := TAU * float(i) / 12.0
		pen.draw_circle(c + Vector2.from_angle(a) * 114.0, 6.0, STONE[3])
	DragonNestArt.gold_mound(pen, c + Vector2(-70, 80), 50.0, 4411, 1)
	# a rearing golden dragon cast in metal: dark gold pass, then lit gold
	DragonNestArt.mono = Color("8A5A12")
	DragonNestArt.begin(pen, Transform2D(deg_to_rad(125.0), c + Vector2(4, 4)))
	DragonNestArt.dragon(pen, 48.0, &"great", 0.0, {"shadow": false, "wing_rot": 25.0})
	DragonNestArt.mono = Color("E0A832")
	DragonNestArt.begin(pen, Transform2D(deg_to_rad(125.0), c))
	DragonNestArt.dragon(pen, 46.0, &"great", 0.0, {"shadow": false, "wing_rot": 25.0})
	DragonNestArt.mono = Color("FFE08A", 0.55)
	DragonNestArt.begin(pen, Transform2D(deg_to_rad(125.0), Vector2.ONE * 0.55, 0.0, c - Vector2(6, 6)))
	DragonNestArt.dragon(pen, 46.0, &"great", 0.0, {"shadow": false, "wing_rot": 25.0})
	DragonNestArt.mono = Color(0, 0, 0, 0)
	pen._xf = Transform2D.IDENTITY
	# ruby eyes
	pen.draw_circle(c + Vector2.from_angle(deg_to_rad(125.0)) * 62.0 + Vector2(6, 2), 3.0, Color("E0304A"))


func _egg_clutch(pen: MeshBatch2D, c: Vector2) -> void:
	pen.draw_colored_polygon(DragonNestArt.ellipse(c + Vector2(8, 12), 130, 100, 20), Color(0, 0, 0, 0.35))
	pen.draw_colored_polygon(DragonNestArt.ellipse(c, 130, 100, 18, 0.0, 9, 0.12), Color("3A2A1C"))
	pen.draw_colored_polygon(DragonNestArt.ellipse(c, 108, 80, 16, 0.2, 10, 0.1), Color("241A12"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# woven branches and bones round the rim
	for k in range(30):
		var a := TAU * float(k) / 30.0
		var p0 := c + Vector2(cos(a) * 112.0, sin(a) * 86.0)
		var p1 := c + Vector2(cos(a + 0.5) * 128.0, sin(a + 0.5) * 98.0)
		pen.draw_line(p0, p1, Color("6A4A30") if k % 4 else Color("CFC3A6"), 6.0 if k % 4 else 5.0)
	DragonNestArt.gold_mound(pen, c + Vector2(10, 20), 60.0, 4421, 0)
	for e in [[Vector2(-40, -20), 22.0], [Vector2(24, -34), 20.0], [Vector2(46, 18), 24.0], [Vector2(-16, 34), 21.0], [Vector2(-60, 30), 18.0]]:
		DragonNestArt.egg(pen, c + (e[0] as Vector2), float(e[1]))
	# one already hatched: broken shell halves
	var hatched := c + Vector2(70, -50)
	pen.draw_colored_polygon(PackedVector2Array([hatched + Vector2(-16, 0), hatched + Vector2(-10, -14), hatched + Vector2(-4, -6), hatched + Vector2(2, -15), hatched + Vector2(8, -4), hatched + Vector2(16, 0), hatched + Vector2(0, 12)]), Color("A82A1E"))
	pen.draw_colored_polygon(DragonNestArt.ellipse(hatched + Vector2(0, 2), 9, 6, 10), Color("1a1210"))


func _treasure_corner(pen: MeshBatch2D, c: Vector2) -> void:
	DragonNestArt.gold_mound(pen, c + Vector2(30, 10), 100.0, 4431, 4)
	_chest(pen, c + Vector2(-80, -60), deg_to_rad(-15.0), 1.6)
	_chest(pen, c + Vector2(-110, 10), deg_to_rad(12.0), 1.4)
	_chest(pen, c + Vector2(70, -90), deg_to_rad(25.0), 1.3)
	_braziers.clear()
	for offset in BRAZIER_OFFSETS:
		_braziers.append(c + offset)
	for b in _braziers:
		pen.draw_circle(b + Vector2(5, 7), 26.0, Color(0, 0, 0, 0.35))
		pen.draw_circle(b, 26.0, STONE[0])
		pen.draw_circle(b, 21.0, Color("2a2620"))
		pen.draw_circle(b, 15.0, Color("8A3A1A"))
	# a tattered war banner on a pole
	var pole := c + Vector2(-30, 110)
	pen.draw_line(pole, pole + Vector2(-70, -40), Color("5A3420"), 6.0)
	pen.draw_colored_polygon(PackedVector2Array([pole + Vector2(-60, -34), pole + Vector2(-20, -70), pole + Vector2(0, -50), pole + Vector2(-16, -36), pole + Vector2(-8, -20), pole + Vector2(-40, -14)]), Color("9E2A22"))
	pen.draw_circle(pole + Vector2(-26, -42), 6.0, Color("F2C14A"))


## Coins strewn all over the floor and dozens of small irregular gold heaps
## (with gems, goblets, crowns, swords, shields...) - not one big oval.
func _scatter_treasure(pen: MeshBatch2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 7
	var blocked: Array = [[Vector2.ZERO, 215.0]]
	for hoard in hoard_positions:
		blocked.append([hoard - ship_center, 150.0])
	for prop in _props:
		if float(prop[4]) > 0.0:
			blocked.append([prop[1], float(prop[4])])
	var free := func(p: Vector2, r: float) -> bool:
		if absf(p.x) > 930.0 - r or absf(p.y) > 860.0 - r:
			return false
		if absf(absf(p.x) - LAVA_X) < 75.0 + r:
			return false
		for b in blocked:
			if p.distance_to(b[0]) < float(b[1]) + r:
				return false
		return true
	# loose coins everywhere, thinner on the swept plaza
	for i in range(3200):
		var p := Vector2(rng.randf_range(-930, 930), rng.randf_range(-860, 860))
		var on_plaza := maxf(absf(p.x), absf(p.y)) + minf(absf(p.x), absf(p.y)) * 0.41 < PLAZA_RADIUS
		if (on_plaza and rng.randf() < 0.8) or not free.call(p, 0.0):
			continue
		DragonNestArt.coin(pen, p, rng.randf_range(1.8, 3.6), rng)
	# heaps: bigger ones off the plaza, little ones on it
	var placed := 0
	for attempt in range(900):
		if placed >= 40:
			break
		var p := Vector2(rng.randf_range(-920, 920), rng.randf_range(-850, 850))
		var on_plaza := maxf(absf(p.x), absf(p.y)) + minf(absf(p.x), absf(p.y)) * 0.41 < PLAZA_RADIUS
		var r := rng.randf_range(24.0, 40.0) if on_plaza else rng.randf_range(48.0, 105.0)
		if not free.call(p, r):
			continue
		DragonNestArt.gold_mound(pen, p, r, 1000 + attempt, 1 + int(r / 28.0))
		blocked.append([p, r * 1.15])
		placed += 1


## Picks this battle's remains and loot: [kind, pos, rot, scale, keep_clear].
## Kept off the landing pad, the hoards, the gold rivers and each other.
const PROP_COUNTS := {
	&"statue": Vector2i(1, 1), &"block": Vector2i(2, 3), &"ribcage": Vector2i(1, 2),
	&"knight": Vector2i(2, 4), &"sword": Vector2i(2, 4), &"chest": Vector2i(2, 3),
	&"crown": Vector2i(1, 1), &"goblet": Vector2i(1, 2), &"scorch": Vector2i(3, 5),
	&"claw": Vector2i(3, 5),
}
const PROP_CLEAR := {
	&"statue": 95.0, &"block": 60.0, &"ribcage": 70.0, &"knight": 55.0, &"sword": 28.0,
	&"chest": 40.0, &"crown": 24.0, &"goblet": 22.0, &"scorch": 0.0, &"claw": 0.0,
}
const CROWN_GEMS: Array[Color] = [Color("4FD18A"), Color("E04A4A"), Color("4FA8E8"), Color("C46AE0")]


func _pick_props() -> void:
	_props.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 13
	var taken: Array = [[Vector2.ZERO, 230.0]]
	for hoard in hoard_positions:
		taken.append([hoard - ship_center, 170.0])
	for kind in [&"statue", &"ribcage", &"block", &"knight", &"chest", &"sword", &"crown", &"goblet", &"scorch", &"claw"]:
		var span: Vector2i = PROP_COUNTS[kind]
		var count := rng.randi_range(span.x, span.y)
		var clear: float = PROP_CLEAR[kind]
		for n in range(count):
			for attempt in range(60):
				var p := Vector2(rng.randf_range(-900.0, 900.0), rng.randf_range(-830.0, 830.0))
				if absf(absf(p.x) - LAVA_X) < 80.0 + clear:
					continue
				var ok := true
				for t in taken:
					if p.distance_to(t[0]) < float(t[1]) + clear:
						ok = false
						break
				if not ok:
					continue
				var scale_value := rng.randf_range(0.9, 1.25)
				_props.append([kind, p, rng.randf() * TAU, scale_value, clear])
				if clear > 0.0:
					taken.append([p, clear])
				break


func _draw_props(pen: MeshBatch2D, kinds: Array) -> void:
	for prop in _props:
		if not kinds.has(prop[0]):
			continue
		var p: Vector2 = prop[1]
		var rot: float = prop[2]
		var k: float = prop[3]
		match prop[0]:
			&"scorch": _scorch(pen, p, 60.0 + 30.0 * (k - 0.9) / 0.35, int(p.x * 7.0 + p.y))
			&"claw": _claw_marks(pen, p, rot, 1.2 + 0.4 * (k - 0.9))
			&"statue": _statue_head(pen, p, rot, 1.05 * k)
			&"block": _stone_block(pen, p, rot, Vector2(70.0, 55.0) * k * (1.0 + 0.6 * fposmod(p.x, 1.0)))
			&"ribcage": _ribcage(pen, p, rot, k)
			&"knight": _knight(pen, p, rot, 0.9 * k)
			&"sword": _sword(pen, p, rot)
			&"chest": _chest(pen, p, rot * 0.25, 1.1 * k)
			&"crown": _crown(pen, p, rot * 0.2, 1.2 * k, CROWN_GEMS[int(absf(p.x)) % CROWN_GEMS.size()])
			&"goblet": _goblet(pen, p, 1.1 * k)


## Phase two: the hall rages. Glowing cracks spread from the landing pad.
func set_raging(on: bool) -> void:
	if on and _cracks.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed + 99
		for i in range(11):
			var a := TAU * float(i) / 11.0 + rng.randf_range(-0.2, 0.2)
			var crack := PackedVector2Array()
			var p := Vector2.from_angle(a) * rng.randf_range(250.0, 300.0)
			crack.append(p)
			var heading := a
			for step in range(rng.randi_range(5, 9)):
				heading += rng.randf_range(-0.5, 0.5)
				p += Vector2.from_angle(heading) * rng.randf_range(45.0, 85.0)
				crack.append(p)
			_cracks.append(crack)
	if _rage_tween != null and _rage_tween.is_valid():
		_rage_tween.kill()
	_rage_tween = create_tween()
	_rage_tween.tween_property(self, "rage", 1.0 if on else 0.0, 2.5).set_trans(Tween.TRANS_SINE)


## Under the props: boiling gold in the rivers and glowing cracks.
func _draw_rage_under() -> void:
	if rage <= 0.01:
		return
	var pulse := 0.75 + 0.25 * sin(_time * 3.0)
	for i in range(_cracks.size()):
		var crack := _cracks[i]
		var grow := clampf(rage * 1.3 - float(i % 4) * 0.08, 0.0, 1.0)
		var shown := maxi(2, int(float(crack.size()) * grow))
		var part := crack.slice(0, shown)
		draw_polyline(part, Color(1.0, 0.35, 0.08, 0.35 * rage * pulse), 14.0)
		draw_polyline(part, Color(1.0, 0.55, 0.15, 0.85 * rage), 5.0)
		draw_polyline(part, Color(1.0, 0.9, 0.55, 0.9 * rage * pulse), 1.8)
	for path in _river_paths:
		var points: PackedVector2Array = path["points"]
		for k in range(16):
			var idx := int(fposmod(float(k) * 37.0 + floor(_time * 1.5 + float(k) * 0.37) * 13.0, float(points.size())))
			var life := fposmod(_time * 1.5 + float(k) * 0.37, 1.0)
			var bp := points[idx] + Vector2(sin(float(k) * 2.3) * 14.0, 0.0)
			draw_circle(bp, 4.0 + 9.0 * life, Color(1.0, 0.8, 0.35, 0.7 * (1.0 - life) * rage))
			draw_arc(bp, 4.0 + 9.0 * life, 0.0, TAU, 12, Color(1.0, 0.95, 0.7, 0.6 * (1.0 - life) * rage), 1.5)


## Over everything in the hall: red light and rising embers.
func _draw_rage_over() -> void:
	if rage <= 0.01:
		return
	draw_rect(Rect2(-2200, -1500, 4400, 3000), Color(0.75, 0.12, 0.04, 0.13 * rage))
	for k in range(46):
		var seed := float(k) * 13.37
		var life := fposmod(_time * (0.18 + fposmod(seed, 0.12)) + fposmod(seed * 0.071, 1.0), 1.0)
		var base := Vector2(fposmod(seed * 97.0, 2000.0) - 1000.0, fposmod(seed * 61.0, 1700.0) - 850.0)
		var p := base + Vector2(sin(_time * 1.3 + seed) * 18.0, -life * 160.0)
		draw_circle(p, 2.6 * (1.0 - life) + 0.8, Color(1.0, 0.6 + 0.3 * fposmod(seed, 1.0), 0.2, 0.85 * (1.0 - life) * rage))


## A ring castle on each side of the hall (side -1 left, +1 right): a round
## curtain wall studded with towers around a courtyard full of gold and a
## burnt-out keep. The Ancient Dragon perches on the breached front wall,
## its body and tail sprawled over the castle.
const CASTLE_X := 1190.0
const CASTLE_R := 340.0

func _castle(pen: MeshBatch2D, side: float) -> void:
	var c := Vector2(side * CASTLE_X, 0.0)
	var r_out := CASTLE_R
	var r_in := CASTLE_R - 74.0
	var front := 0.0 if side < 0.0 else PI
	var rng := RandomNumberGenerator.new()
	rng.seed = 91 + int(side)
	# shadow and courtyard
	pen.draw_circle(c + Vector2(-16, 22), r_out + 10.0, Color(0, 0, 0, 0.42))
	pen.draw_circle(c, r_in, Color("2B221C"))
	for ring in range(4):
		var rr := r_in * (0.95 - ring * 0.2)
		for k in range(int(rr / 18.0)):
			var a := TAU * float(k) / float(int(rr / 18.0)) + ring * 0.3
			var p := c + Vector2.from_angle(a) * rr
			pen.draw_colored_polygon(PackedVector2Array([p + Vector2(-14, -11).rotated(a), p + Vector2(14, -11).rotated(a), p + Vector2(14, 11).rotated(a), p + Vector2(-14, 11).rotated(a)]), [Color("362C25"), Color("3F342B"), Color("332A23")][k % 3])
	# treasure piled in the courtyard
	for k in range(7):
		var a := rng.randf() * TAU
		var d := r_in * rng.randf_range(0.45, 0.82)
		DragonNestArt.gold_mound(pen, c + Vector2.from_angle(a) * d, rng.randf_range(40.0, 70.0), 500 + k + int(side) * 50, 2)
	# the burnt-out keep in the middle
	pen.draw_circle(c + Vector2(-10, 14), 112.0, Color(0, 0, 0, 0.4))
	pen.draw_circle(c, 108.0, STONE[0])
	pen.draw_circle(c, 92.0, STONE[1])
	for i in range(14):
		var a := TAU * float(i) / 14.0
		var p := c + Vector2.from_angle(a) * 100.0
		var t := Vector2.from_angle(a + PI * 0.5) * 9.0
		var n := Vector2.from_angle(a) * 9.0
		pen.draw_colored_polygon(PackedVector2Array([p - t - n, p + t - n, p + t + n, p - t + n]), STONE[3] if i % 2 == 0 else STONE[2])
	pen.draw_circle(c, 74.0, Color("15100d"))
	for i in range(5):
		var a := 0.5 + i * 1.25
		pen.draw_line(c + Vector2.from_angle(a) * 66.0, c + Vector2.from_angle(a + 2.4) * 40.0, Color("2E2018"), 10.0)
	pen.draw_circle(c + Vector2(8, 6), 26.0, Color(1.0, 0.45, 0.12, 0.25))
	pen.draw_circle(c + Vector2(8, 6), 12.0, Color("FF8A2A"))
	# the round curtain wall (breached where the dragon sits)
	var steps := 72
	for i in range(steps):
		var a0 := TAU * float(i) / float(steps)
		var a1 := TAU * float(i + 1) / float(steps)
		if absf(wrapf(a0 - front, -PI, PI)) < 0.32:
			continue
		var o0 := Vector2.from_angle(a0)
		var o1 := Vector2.from_angle(a1)
		pen.draw_colored_polygon(PackedVector2Array([c + o0 * r_in, c + o0 * r_out, c + o1 * r_out, c + o1 * r_in]), STONE[0])
		pen.draw_colored_polygon(PackedVector2Array([c + o0 * (r_in + 14.0), c + o0 * (r_out - 14.0), c + o1 * (r_out - 14.0), c + o1 * (r_in + 14.0)]), STONE[1] if i % 2 == 0 else Color("4F5146"))
		if i % 2 == 0:
			for rr in [r_out - 6.0, r_in + 6.0]:
				var m: Vector2 = c + Vector2.from_angle((a0 + a1) * 0.5) * float(rr)
				pen.draw_circle(m, 7.0, STONE[3] if float(rr) > r_in + 20.0 else STONE[2])
	# rubble spilling out of the breach
	for k in range(22):
		var a := front + rng.randf_range(-0.42, 0.42)
		var p := c + Vector2.from_angle(a) * rng.randf_range(r_in - 20.0, r_out + 90.0)
		var rr := rng.randf_range(8.0, 22.0)
		pen.draw_colored_polygon(DragonNestArt.ellipse(p + Vector2(3, 4), rr, rr * 0.8, 6, rng.randf(), k, 0.25), Color(0, 0, 0, 0.3))
		pen.draw_colored_polygon(DragonNestArt.ellipse(p, rr, rr * 0.8, 6, rng.randf(), k, 0.25), STONE[1])
		pen.draw_colored_polygon(DragonNestArt.ellipse(p - Vector2(2, 2), rr * 0.55, rr * 0.45, 6, rng.randf(), k + 1, 0.25), STONE[2])
	# towers around the ring (two flank the breach, one roof has fallen in)
	for i in range(8):
		var a := front + PI / 8.0 + TAU * float(i) / 8.0
		_tower(pen, Transform2D.IDENTITY, c + Vector2.from_angle(a) * (r_out - 34.0), 70.0 if i % 2 == 0 else 60.0, i == 3)
	# claw gouges over the wall where the dragon climbed in
	for k in range(3):
		var a := front + (k - 1) * 0.55
		var p := c + Vector2.from_angle(a) * (r_out - 37.0)
		for line_i in range(3):
			var o := Vector2.from_angle(a + PI * 0.5) * (line_i - 1) * 9.0
			pen.draw_line(p + o - Vector2.from_angle(a) * 26.0, p + o + Vector2.from_angle(a) * 26.0, Color(0.07, 0.05, 0.04, 0.85), 4.0)


func _tower(pen: MeshBatch2D, xf: Transform2D, c: Vector2, r: float, collapsed: bool) -> void:
	pen._xf = xf
	pen.draw_circle(c + Vector2(-14, 16), r * 1.02, Color(0, 0, 0, 0.35))
	pen.draw_circle(c, r, STONE[0])
	pen.draw_circle(c, r * 0.9, STONE[1])
	for i in range(16):
		var a := TAU * float(i) / 16.0
		var p := c + Vector2.from_angle(a) * r * 0.95
		var t := Vector2.from_angle(a + PI * 0.5) * 9.0
		var n := Vector2.from_angle(a) * 8.0
		pen.draw_colored_polygon(PackedVector2Array([p - t - n, p + t - n, p + t + n, p - t + n]), STONE[3] if i % 2 == 0 else STONE[2])
	if collapsed:
		# roof fell in: scorched floor, charred beams and rubble
		pen.draw_circle(c, r * 0.78, Color("1a1512"))
		for i in range(4):
			var a := 0.4 + i * 1.3
			pen.draw_line(c + Vector2.from_angle(a) * r * 0.7, c + Vector2.from_angle(a + 2.2) * r * 0.5, Color("2E2018"), 9.0)
		for i in range(7):
			var p := c + Vector2.from_angle(i * 0.9) * r * 0.45
			pen.draw_colored_polygon(DragonNestArt.ellipse(p, 14, 11, 6, i, i, 0.25), STONE[1])
	else:
		# conical slate roof, lit from the top-left
		var slate: Array[Color] = [Color("5A1E1A"), Color("7A2A22"), Color("943528")]
		for i in range(20):
			var a0 := TAU * float(i) / 20.0
			var a1 := TAU * float(i + 1) / 20.0
			var lit := cos(a0 + PI * 0.75)
			var col: Color = slate[2] if lit > 0.4 else (slate[1] if lit > -0.3 else slate[0])
			pen.draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a0) * r * 0.82, c + Vector2.from_angle(a1) * r * 0.82]), col)
		pen.draw_arc(c, r * 0.55, 0.0, TAU, 24, Color(0, 0, 0, 0.18), 2.0)
		pen.draw_circle(c, 7.0, Color("D9A441"))
		# a tattered banner on the spire
		pen.draw_colored_polygon(PackedVector2Array([c, c + Vector2(-46, -10), c + Vector2(-38, 0), c + Vector2(-48, 10), c + Vector2(0, 6)]), Color("9E2A22"))
		pen.draw_circle(c + Vector2(-20, 0), 4.0, Color("F2C14A"))
	pen._xf = Transform2D.IDENTITY


func _lava_river(pen: MeshBatch2D, points: PackedVector2Array, width: float) -> void:
	for pass_ in [[width * 3.2, Color(1.0, 0.8, 0.3, 0.09)], [width * 1.5, Color("2A1C0C")], [width, Color("9A6414")], [width * 0.66, Color("D99A26")], [width * 0.4, LAVA]]:
		var w: float = pass_[0]
		for i in range(points.size() - 1):
			pen.draw_line(points[i], points[i + 1], pass_[1], w)
		for p in points:
			pen.draw_circle(p, w * 0.5, pass_[1])


func _sparkle(pen: MeshBatch2D, p: Vector2, k: float) -> void:
	pen.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -k), p + Vector2(k * 0.22, -k * 0.22), p + Vector2(k, 0), p + Vector2(k * 0.22, k * 0.22),
		p + Vector2(0, k), p + Vector2(-k * 0.22, k * 0.22), p + Vector2(-k, 0), p + Vector2(-k * 0.22, -k * 0.22)]), Color("FFF6CF"))


func _hall_floor(pen: MeshBatch2D) -> void:
	var R := PLAZA_RADIUS
	pen.draw_colored_polygon(DragonNestArt.ellipse(Vector2.ZERO, R + 30.0, R + 30.0, 8, 0.39), Color("1c1714"))
	pen.draw_colored_polygon(DragonNestArt.ellipse(Vector2.ZERO, R, R, 8, 0.39), Color("3A332C"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var ts := 70.0
	var tones: Array[Color] = [Color("3F3730"), Color("463D35"), Color("4D433A"), Color("41392F")]
	for i in range(-8, 9):
		for j in range(-8, 9):
			var p := Vector2(i, j) * ts
			if maxf(absf(p.x), absf(p.y)) + minf(absf(p.x), absf(p.y)) * 0.41 > R - 20.0:
				continue
			pen.draw_rect(Rect2(p - Vector2.ONE * (ts * 0.5 - 3.0), Vector2.ONE * (ts - 6.0)), tones[rng.randi() % 4])
			if rng.randf() < 0.18:
				var a := p + Vector2(-20, -10)
				var b := a + Vector2(rng.randf_range(10, 30), rng.randf_range(-10, 20))
				pen.draw_line(a, b, Color("221c18"), 2.0)
				pen.draw_line(b, b + Vector2(rng.randf_range(5, 20), rng.randf_range(5, 20)), Color("221c18"), 2.0)
	# landing rune ring
	pen.draw_arc(Vector2.ZERO, 175.0, 0.0, TAU, 64, Color("8A5A22"), 8.0)
	pen.draw_arc(Vector2.ZERO, 160.0, 0.0, TAU, 64, Color("5A3A18"), 3.0)
	for i in range(16):
		var a := TAU * float(i) / 16.0
		var p := Vector2.from_angle(a) * 168.0
		pen.draw_colored_polygon(PackedVector2Array([p + Vector2.from_angle(a) * 7.0, p + Vector2.from_angle(a + PI * 0.5) * 7.0, p - Vector2.from_angle(a) * 7.0, p - Vector2.from_angle(a + PI * 0.5) * 7.0]), Color("E0A040"))


func _bridge(pen: MeshBatch2D, c: Vector2, w: float, length: float) -> void:
	pen.draw_rect(Rect2(c + Vector2(-length * 0.5 + 6.0, -w * 0.5 + 8.0), Vector2(length, w)), Color(0, 0, 0, 0.35))
	pen.draw_rect(Rect2(c + Vector2(-length * 0.5, -w * 0.5), Vector2(length, w)), STONE[1])
	for i in range(int(length / 26.0)):
		pen.draw_rect(Rect2(c + Vector2(-length * 0.5 + 3.0 + i * 26.0, -w * 0.5 + 4.0), Vector2(22.0, w - 8.0)), STONE[2] if i % 2 == 1 else STONE[1])
	pen.draw_rect(Rect2(c + Vector2(-length * 0.5, -w * 0.5 - 5.0), Vector2(length, 7.0)), STONE[0])
	pen.draw_rect(Rect2(c + Vector2(-length * 0.5, w * 0.5 - 2.0), Vector2(length, 7.0)), STONE[0])


func _scorch(pen: MeshBatch2D, c: Vector2, r: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for k in range(5):
		pen.draw_colored_polygon(DragonNestArt.ellipse(c + Vector2(rng.randf_range(-r, r) * 0.4, rng.randf_range(-r, r) * 0.3), r * rng.randf_range(0.5, 1.0), r * rng.randf_range(0.35, 0.7), 9, rng.randf(), seed_value + k, 0.25), Color(0.055, 0.05, 0.04, 0.35))


func _curve(a: Vector2, ctrl: Vector2, b: Vector2, steps: int = 8) -> PackedVector2Array:
	var points := PackedVector2Array([a])
	for s in range(1, steps + 1):
		var t := float(s) / float(steps)
		points.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	return points


func _claw_marks(pen: MeshBatch2D, c: Vector2, rot: float, k: float) -> void:
	pen.draw_set_transform(c, rot, Vector2.ONE * k)
	for i in range(3):
		var y := -12.0 + i * 12.0
		pen.draw_polyline(_curve(Vector2(-40, y), Vector2(0, y - 4.0), Vector2(44, y + 4.0)), Color(0.08, 0.07, 0.06, 0.8), 5.0)
		pen.draw_polyline(_curve(Vector2(-38, y + 2.0), Vector2(0, y - 2.0), Vector2(40, y + 6.0)), Color(0.36, 0.37, 0.32, 0.6), 1.5)
	pen.draw_set_transform(Vector2.ZERO)


func _statue_head(pen: MeshBatch2D, c: Vector2, rot: float, k: float) -> void:
	# A toppled dwarven king statue: giant stone head, braided beard, crown.
	pen.draw_set_transform(c, rot, Vector2.ONE * k)
	pen.draw_colored_polygon(DragonNestArt.ellipse(Vector2(10, 14), 96, 70, 20), Color(0, 0, 0, 0.35))
	pen.draw_colored_polygon(PackedVector2Array([Vector2(10, -46), Vector2(120, -26), Vector2(160, 0), Vector2(120, 26), Vector2(10, 46)]), STONE[1])
	for yy in [-24.0, 0.0, 24.0]:
		pen.draw_colored_polygon(PackedVector2Array([Vector2(60, yy - 9), Vector2(150, yy * 0.5 - 4), Vector2(158, yy * 0.5), Vector2(150, yy * 0.5 + 4), Vector2(60, yy + 9)]), STONE[2])
		pen.draw_rect(Rect2(Vector2(132, yy * 0.55 - 5), Vector2(10, 10)), Color("B08A3A"))
	pen.draw_colored_polygon(DragonNestArt.ellipse(Vector2.ZERO, 62, 58, 20), STONE[1])
	pen.draw_colored_polygon(DragonNestArt.ellipse(Vector2(-6, -6), 50, 46, 20), STONE[2])
	pen.draw_rect(Rect2(Vector2(20, -44), Vector2(18, 88)), Color(STONE[3], 0.6))
	pen.draw_colored_polygon(DragonNestArt.ellipse(Vector2(44, -18), 7, 5, 10), Color("2a2620"))
	pen.draw_colored_polygon(DragonNestArt.ellipse(Vector2(44, 18), 7, 5, 10), Color("2a2620"))
	pen.draw_colored_polygon(PackedVector2Array([Vector2(40, -6), Vector2(62, 0), Vector2(40, 6)]), STONE[3])
	for i in range(7):
		var a := deg_to_rad(110.0 + i * 23.0)
		var p := Vector2.from_angle(a) * 58.0
		pen.draw_colored_polygon(PackedVector2Array([p, p * 1.3, p + Vector2.from_angle(a + 1.4) * 12.0]), Color("B08A3A"))
	pen.draw_circle(Vector2(-50, 0), 7.0, Color("E0304A"))
	pen.draw_polyline(PackedVector2Array([Vector2(-30, -50), Vector2(-10, -20), Vector2(-24, 6), Vector2(-4, 40)]), Color("1d1a16"), 4.0)
	pen.draw_set_transform(Vector2.ZERO)


func _stone_block(pen: MeshBatch2D, c: Vector2, rot: float, size: Vector2) -> void:
	pen.draw_set_transform(c, rot)
	pen.draw_rect(Rect2(-size * 0.5 + Vector2(6, 8), size), Color(0, 0, 0, 0.3))
	pen.draw_rect(Rect2(-size * 0.5, size), STONE[1])
	pen.draw_rect(Rect2(-size * 0.5 + Vector2(10, 10), Vector2(size.x - 20, size.y * 0.38)), STONE[2])
	pen.draw_set_transform(Vector2.ZERO)


func _ribcage(pen: MeshBatch2D, c: Vector2, rot: float, k: float) -> void:
	var bone := Color("CFC3A6")
	pen.draw_set_transform(c, rot, Vector2.ONE * k)
	pen.draw_rect(Rect2(Vector2(-67, 1), Vector2(150, 8)), Color(0, 0, 0, 0.25))
	for i in range(9):
		var x := -60.0 + i * 15.0
		var L := 38.0 - absf(i - 3) * 4.0
		pen.draw_polyline(_curve(Vector2(x, 0), Vector2(x - 8, -L * 0.6), Vector2(x - 16, -L)), bone, 5.0)
		pen.draw_polyline(_curve(Vector2(x, 0), Vector2(x - 8, L * 0.6), Vector2(x - 16, L)), bone, 5.0)
	pen.draw_rect(Rect2(Vector2(-70, -4), Vector2(150, 8)), bone)
	pen.draw_colored_polygon(PackedVector2Array([Vector2(80, -18), Vector2(120, -10), Vector2(140, 0), Vector2(120, 10), Vector2(80, 18), Vector2(72, 0)]), bone)
	pen.draw_circle(Vector2(100, -8), 5.0, Color("1a1410"))
	pen.draw_circle(Vector2(100, 8), 5.0, Color("1a1410"))
	pen.draw_colored_polygon(PackedVector2Array([Vector2(78, -14), Vector2(50, -34), Vector2(70, -10)]), bone)
	pen.draw_colored_polygon(PackedVector2Array([Vector2(78, 14), Vector2(50, 34), Vector2(70, 10)]), bone)
	pen.draw_set_transform(Vector2.ZERO)


func _knight(pen: MeshBatch2D, c: Vector2, rot: float, k: float) -> void:
	# Charred adventurer: breastplate, skull, shield and sword.
	pen.draw_set_transform(c, rot, Vector2.ONE * k)
	pen.draw_colored_polygon(DragonNestArt.ellipse(Vector2(4, 6), 40, 26, 16), Color(0, 0, 0, 0.3))
	pen.draw_colored_polygon(DragonNestArt.ellipse(Vector2.ZERO, 34, 22, 16), Color(0.08, 0.07, 0.06, 0.6))
	pen.draw_rect(Rect2(Vector2(-22, -12), Vector2(26, 24)), Color("6E6A62"))
	pen.draw_rect(Rect2(Vector2(-18, -8), Vector2(18, 10)), Color("9A958A"))
	pen.draw_circle(Vector2(12, 0), 9.0, Color("D8CDB4"))
	pen.draw_circle(Vector2(15, -3), 2.0, Color("2a1d14"))
	pen.draw_circle(Vector2(15, 3), 2.0, Color("2a1d14"))
	pen.draw_colored_polygon(DragonNestArt.ellipse(Vector2(-14, 22), 16, 11, 14), Color("5A6E8A"))
	pen.draw_colored_polygon(DragonNestArt.ellipse(Vector2(-14, 22), 9, 6, 12), Color("D9A441"))
	pen.draw_line(Vector2(-30, -20), Vector2(18, -30), Color("C9CED6"), 3.5)
	pen.draw_rect(Rect2(Vector2(-36, -26), Vector2(6, 12)), Color("D9A441"))
	pen.draw_set_transform(Vector2.ZERO)


func _egg_nest(pen: MeshBatch2D, c: Vector2) -> void:
	pen.draw_colored_polygon(DragonNestArt.ellipse(c + Vector2(3, 5), 40, 32, 18), Color(0, 0, 0, 0.3))
	pen.draw_colored_polygon(DragonNestArt.ellipse(c, 40, 32, 14, 0.0, 3, 0.15), Color("4A3424"))
	pen.draw_colored_polygon(DragonNestArt.ellipse(c, 30, 23, 12, 0.2, 4, 0.1), Color("2E2018"))
	for a in range(16):
		var aa := float(a) / 16.0 * TAU
		pen.draw_line(c + Vector2(cos(aa) * 32, sin(aa) * 26), c + Vector2(cos(aa + 0.5) * 38, sin(aa + 0.5) * 30), Color("6A4A30"), 2.2)
	var eggs := [[Vector2(-10, -6), Color("7A1A14"), Color("C8402A")], [Vector2(9, -7), Color("8A5A12"), Color("E0A030")], [Vector2(0, 8), Color("7A1A14"), Color("C8402A")]]
	for egg in eggs:
		var p: Vector2 = c + (egg[0] as Vector2)
		pen.draw_colored_polygon(DragonNestArt.ellipse(p + Vector2(2, 2), 11, 9, 14, 0.35), Color(0, 0, 0, 0.35))
		pen.draw_colored_polygon(DragonNestArt.ellipse(p, 11, 9, 14, 0.35), egg[1])
		pen.draw_colored_polygon(DragonNestArt.ellipse(p - Vector2(2, 2), 7, 5.5, 12, 0.35), egg[2])
		pen.draw_circle(p - Vector2(4, 3), 2.0, Color(1, 1, 1, 0.5))


func _stalagmite(pen: MeshBatch2D, c: Vector2, k: float, seed_value: int) -> void:
	pen.draw_colored_polygon(DragonNestArt.ellipse(c + Vector2(6, 8) * k, 30 * k, 26 * k, 8, 0.0, seed_value, 0.2), Color(0, 0, 0, 0.35))
	pen.draw_colored_polygon(DragonNestArt.ellipse(c, 30 * k, 26 * k, 8, 0.0, seed_value, 0.2), Color("2A221E"))
	pen.draw_colored_polygon(DragonNestArt.ellipse(c - Vector2(3, 3) * k, 21 * k, 18 * k, 7, 0.0, seed_value + 1, 0.2), Color("45372F"))
	pen.draw_colored_polygon(DragonNestArt.ellipse(c - Vector2(6, 6) * k, 10 * k, 9 * k, 6, 0.0, seed_value + 2, 0.2), Color("6B5446"))


func _sword(pen: MeshBatch2D, c: Vector2, rot: float) -> void:
	pen.draw_set_transform(c, rot)
	pen.draw_colored_polygon(PackedVector2Array([Vector2(6, 5), Vector2(48, 5), Vector2(54, 3), Vector2(48, 1), Vector2(6, 1)]), Color(0, 0, 0, 0.3))
	pen.draw_colored_polygon(PackedVector2Array([Vector2(4, 2), Vector2(46, 2), Vector2(52, 0), Vector2(46, -2), Vector2(4, -2)]), Color("C9CED6"))
	pen.draw_rect(Rect2(Vector2(4, -2), Vector2(42, 2)), Color("EEF2F6"))
	pen.draw_rect(Rect2(Vector2(0, -7), Vector2(4, 14)), Color("D9A441"))
	pen.draw_rect(Rect2(Vector2(-12, -2), Vector2(12, 4)), Color("5A3420"))
	pen.draw_circle(Vector2(-13, 0), 3.0, Color("D9A441"))
	pen.draw_set_transform(Vector2.ZERO)


func _chest(pen: MeshBatch2D, c: Vector2, rot: float, k: float) -> void:
	var w := 34.0 * k
	var h := 24.0 * k
	pen.draw_set_transform(c, rot)
	pen.draw_rect(Rect2(Vector2(-w * 0.5 + 3, -h * 0.5 + 4), Vector2(w, h)), Color(0, 0, 0, 0.3))
	pen.draw_rect(Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)), Color("5A3420"))
	pen.draw_rect(Rect2(Vector2(-w * 0.5 + 3, -h * 0.5 + 3), Vector2(w - 6, h - 6)), GOLD[1])
	for i in range(5):
		pen.draw_circle(Vector2(-w * 0.5 + 7 + i * (w - 14) / 4.0, (float(i % 2) - 0.5) * 5.0 * k), 3.0 * k, GOLD[2])
	pen.draw_rect(Rect2(Vector2(-w * 0.5, -h * 0.5 - 10 * k), Vector2(w, 9 * k)), Color("7A4A2C"))
	pen.draw_rect(Rect2(Vector2(-w * 0.5, -h * 0.5 - 10 * k), Vector2(w, 3 * k)), Color("A8723E"))
	for bx in [-w * 0.3, w * 0.3]:
		pen.draw_rect(Rect2(Vector2(bx - 2.5 * k, -h * 0.5), Vector2(5 * k, h)), Color("D9A441"))
	pen.draw_set_transform(Vector2.ZERO)


func _crown(pen: MeshBatch2D, c: Vector2, rot: float, k: float, gem: Color) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		points.append(c + Vector2.from_angle(rot + i * PI / 5.0) * (10.0 * k if i % 2 == 0 else 6.5 * k))
	var shadow := PackedVector2Array()
	for p in points:
		shadow.append(p + Vector2(2, 3))
	pen.draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
	pen.draw_colored_polygon(points, Color("D9A441"))
	pen.draw_circle(c, 5.5 * k, Color("2a1a10"))
	pen.draw_circle(c + Vector2.from_angle(rot) * 6.0 * k, 2.0 * k, gem)


func _goblet(pen: MeshBatch2D, c: Vector2, k: float) -> void:
	pen.draw_circle(c + Vector2(2, 3), 7 * k, Color(0, 0, 0, 0.3))
	pen.draw_circle(c, 7 * k, Color("B07A1A"))
	pen.draw_circle(c, 5 * k, GOLD[2])
	pen.draw_circle(c, 3.2 * k, Color("7A1A2A"))


func _throne(pen: MeshBatch2D, c: Vector2, facing: float, k: float, royal: bool) -> void:
	# Stone throne on a two-step dais; the seat opens toward the ship.
	pen.draw_set_transform(c, facing, Vector2.ONE * k)
	pen.draw_colored_polygon(DragonNestArt.ellipse(Vector2(6, 8), 74, 74, 8, 0.39), Color(0, 0, 0, 0.3))
	pen.draw_colored_polygon(DragonNestArt.ellipse(Vector2.ZERO, 74, 74, 8, 0.39), STONE[0])
	pen.draw_colored_polygon(DragonNestArt.ellipse(Vector2(-2, -2), 70, 70, 8, 0.39), STONE[1])
	pen.draw_colored_polygon(DragonNestArt.ellipse(Vector2(-4, -4), 54, 54, 8, 0.39), STONE[2])
	if royal:
		pen.draw_rect(Rect2(Vector2(-50, -13), Vector2(128, 26)), Color("7A1E1E"))
		pen.draw_rect(Rect2(Vector2(-50, -10), Vector2(128, 20)), Color("9E2A22"))
	var bx := -46.0
	pen.draw_rect(Rect2(Vector2(bx - 5, -34), Vector2(20, 80)), Color(0, 0, 0, 0.35))
	pen.draw_rect(Rect2(Vector2(bx - 10, -40), Vector2(20, 80)), STONE[1])
	pen.draw_rect(Rect2(Vector2(bx - 6, -36), Vector2(12, 36)), STONE[3])
	for j in range(5):
		var y := -32.0 + j * 16.0
		pen.draw_colored_polygon(PackedVector2Array([Vector2(bx - 10, y - 5), Vector2(bx - 24, y), Vector2(bx - 10, y + 5)]), Color("D9A441") if royal else STONE[2])
	for sd in [-1.0, 1.0]:
		pen.draw_rect(Rect2(Vector2(bx + 8, sd * 30 - 6), Vector2(38, 12)), STONE[1])
		pen.draw_circle(Vector2(bx + 46, sd * 30), 7.0, Color("D9A441") if royal else STONE[3])
	pen.draw_rect(Rect2(Vector2(bx + 8, -24), Vector2(38, 48)), STONE[2])
	if royal:
		pen.draw_rect(Rect2(Vector2(bx + 12, -20), Vector2(30, 40)), Color("7A1E1E"))
		pen.draw_circle(Vector2(bx, 0), 7.0, Color("4FD18A"))
	pen.draw_set_transform(Vector2.ZERO)


func _cave_walls(pen: MeshBatch2D, rng: RandomNumberGenerator) -> void:
	var cols: Array[Color] = [Color("14100e"), Color("2E2420"), Color("4A3A32")]
	for k in range(170):
		var side := k % 4
		var t := rng.randf_range(-1.0, 1.0)
		var p: Vector2
		match side:
			0: p = Vector2(t * 1700.0, -980.0 + rng.randf_range(-260, 60))
			1: p = Vector2(1440.0 + rng.randf_range(-60, 260), t * 1100.0)
			2: p = Vector2(t * 1700.0, 980.0 + rng.randf_range(-60, 260))
			_: p = Vector2(-1440.0 + rng.randf_range(-260, 60), t * 1100.0)
		if (side == 1 or side == 3) and absf(p.y) < 330.0:
			continue
		var rad := rng.randf_range(50.0, 110.0)
		var points := DragonNestArt.ellipse(p, rad, rad * 0.85, 8, rng.randf(), k, 0.2)
		var o := Vector2.ONE * rad * -0.12
		pen.draw_colored_polygon(points, cols[0])
		pen.draw_colored_polygon(_shrunk(points, p, 0.9, o), cols[1])
		pen.draw_colored_polygon(_shrunk(points, p, 0.5, o * 2.6), cols[2])


func _shrunk(points: PackedVector2Array, c: Vector2, k: float, o: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(c + (p - c) * k + o)
	return out
