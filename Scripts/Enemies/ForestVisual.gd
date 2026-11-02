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


# ------------------------------------------------------------ walking tree

const TREE_ART := preload("res://Scripts/Battle/Forest/ForestArt.gd")
const ROOT_DARK := Color("3A2A1E")
const ROOT_MID := Color("5A4130")
const ROOT_LIGHT := Color("7A5A42")
const SOCKET := Color("17200F")
const TREE_EYE := Color("FFD36A")
const TREE_EYE_HOT := Color("FFF2B0")


## Cached meshes of one walking tree's crown (built once per treant): the
## exact crown of the tree it rose from (same seed / radius as ForestArt in
## the chunk renderer), and a flat white copy for the hit flash.
static func build_tree_crown(radius: float, seed: int, giant: bool) -> Dictionary:
	var crown := MeshBatch2D.new()
	var white := MeshBatch2D.new()
	var lobes := 9 if giant else 7
	if giant:
		TREE_ART.giant_oak(crown, Vector2.ZERO, radius, seed, false)
	else:
		TREE_ART.canopy(crown, Vector2.ZERO, radius, seed, TREE_ART.OAK if seed % 3 != 0 else TREE_ART.OAK_DEEP, 7, false)
	var flat: Array[Color] = [Palette.HIT_FLASH, Palette.HIT_FLASH, Palette.HIT_FLASH]
	TREE_ART.canopy(white, Vector2.ZERO, radius, seed, flat, lobes, false)
	return {"crown": crown.build(), "white": white.build(), "radius": radius}


## Far ordinary treants reuse nine low-variation crowns while emerging.
## The exact source-tree crown is only built if one comes near the ship.
static var _shared_distant_crowns: Dictionary = {}


static func shared_distant_crown(seed_value: int, giant: bool = false) -> Dictionary:
	var variant := posmod(seed_value, 9)
	var key := variant + (9 if giant else 0)
	if not _shared_distant_crowns.has(key):
		_shared_distant_crowns[key] = build_tree_crown(46.0 if giant else 40.0, variant, giant)
	return _shared_distant_crowns[key]


## The treant IS a tree that walks (user design): the tree's own crown seen
## from above, root legs stepping out under its rim, and glowing eyes in
## dark hollows of the leaves. `rise` 0..1 while tearing out of the ground:
## the crown first shudders in place exactly like the tree, then the roots rip
## free and the eyes open. `size` scales the crown (big treants swell while
## rising). Draws into `canvas` in its local space; the crown never rotates.
## Normally every treant is drawn by ForestTreantBatch (MultiMesh); this is
## the individual fallback. Legs and eyes are baked into one triangle array
## each (MeshBatch2D.flush_to), so a treant costs 3 draw commands, not ~30.
## `legs` false skips the roots entirely (distant trees).
static var _scratch := MeshBatch2D.new()


static func draw_walking_tree(canvas: CanvasItem, crown: Dictionary, facing: float, step: float, flash: bool, rise: float, time: float, size: float = 1.0, draw_crown: bool = true, legs: bool = true) -> void:
	var r: float = float(crown["radius"]) * size
	var k := size
	var shudder := clampf(rise / 0.45, 0.0, 1.0)
	var tear := clampf((rise - 0.45) / 0.55, 0.0, 1.0)
	tear = 1.0 - pow(1.0 - tear, 3.0)
	var shake := Vector2.ZERO
	if rise < 0.45:
		shake = Vector2(sin(time * 61.0), cos(time * 47.0)) * 2.2 * shudder
	var hop := sin(PI * tear) * 0.12 if rise < 1.0 else 0.0
	if tear > 0.0 and legs:
		_scratch.clear()
		walking_legs(_scratch, r, facing, step, tear, flash, false)
		_scratch.flush_to(canvas)
	# Crown: the tree itself.
	canvas.draw_set_transform(shake - Vector2(0, r * hop * 0.25), 0.0, Vector2.ONE * k * (1.0 + hop * 0.15))
	var mesh: ArrayMesh = crown["white"] if flash else crown["crown"]
	if draw_crown and mesh != null:
		canvas.draw_mesh(mesh, null)
	canvas.draw_set_transform(shake - Vector2(0, r * hop * 0.25), 0.0, Vector2.ONE)
	if flash or tear <= 0.0:
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	_scratch.clear()
	walking_eyes(_scratch, r, facing, tear, 0.8 + 0.2 * sin(time * 3.0), false)
	_scratch.flush_to(canvas)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Four root legs under the rim, stepping in pairs. `canvas` is a CanvasItem
## or a MeshBatch2D. `detailed` adds the light streak and root toes.
static func walking_legs(canvas: Object, r: float, facing: float, step: float, tear: float, flash: bool, detailed: bool) -> void:
	var dir := Vector2.RIGHT.rotated(facing)
	for leg in [[0.8, 1.0], [-0.8, -1.0], [2.35, -1.0], [-2.35, 1.0]]:
		var a: float = facing + float(leg[0])
		var phase: float = float(leg[1]) * step
		var out := Vector2.RIGHT.rotated(a)
		var tip := out * r * (0.75 + 0.58 * tear) + dir * r * 0.2 * phase
		var knee := out * r * 0.62 + dir * r * 0.1 * phase
		var w := maxf(3.0, r * 0.14) * (0.6 + 0.4 * tear)
		var n := (tip - knee).normalized().orthogonal()
		canvas.draw_colored_polygon(PackedVector2Array([knee + n * w, tip + n * w * 0.35, tip + out * w * 0.5, tip - n * w * 0.35, knee - n * w]), Palette.HIT_FLASH if flash else ROOT_MID)
		if detailed and not flash:
			canvas.draw_line(knee + n * w * 0.4, tip + n * w * 0.15, ROOT_LIGHT, maxf(1.0, w * 0.35))
			for t in [-0.5, 0.5]:
				canvas.draw_line(tip, tip + out.rotated(t) * w * 1.3, ROOT_DARK, maxf(1.0, w * 0.4))


## Glowing eyes in dark hollows of the leaves. Detailed: two big, a small
## third and two tiny ones with glow and glint; simple: the three main eyes.
static func walking_eyes(canvas: Object, r: float, facing: float, tear: float, glow: float, detailed: bool) -> void:
	var dir := Vector2.RIGHT.rotated(facing)
	var side := dir.orthogonal()
	var eyes := [
		[dir * r * 0.40 + side * r * 0.19, 0.115],
		[dir * r * 0.40 - side * r * 0.19, 0.115],
		[dir * r * 0.64, 0.065],
	]
	if detailed:
		eyes.append([dir * r * 0.08 + side * r * 0.40, 0.05])
		eyes.append([dir * r * 0.08 - side * r * 0.40, 0.05])
	for eye in eyes:
		var at: Vector2 = eye[0]
		var er := maxf(1.6, r * float(eye[1])) * tear
		canvas.draw_circle(at, er * 1.75, SOCKET)
		if detailed:
			canvas.draw_circle(at, er * 1.5, Color(TREE_EYE, 0.22 * glow))
		canvas.draw_circle(at, er, TREE_EYE)
		canvas.draw_circle(at + dir * er * 0.2, er * 0.45, TREE_EYE_HOT)
		if detailed:
			canvas.draw_circle(at - Vector2(er, er) * 0.3, er * 0.25, Color.WHITE)


## Shared meshes for ForestTreantBatch, built at BATCH_RADIUS facing +x with
## the roots fully torn out. Leg poses: 0 standing, 1 / 2 the two steps.
const BATCH_RADIUS: float = 40.0
static var _batch_legs: Array[ArrayMesh] = []
static var _batch_eyes: ArrayMesh


static func batch_legs_mesh(pose: int) -> ArrayMesh:
	if _batch_legs.is_empty():
		for step: float in [0.0, 1.0, -1.0]:
			var legs_batch := MeshBatch2D.new()
			walking_legs(legs_batch, BATCH_RADIUS, 0.0, step, 1.0, false, true)
			_batch_legs.append(legs_batch.build())
	return _batch_legs[clampi(pose, 0, 2)]


static func batch_eyes_mesh() -> ArrayMesh:
	if _batch_eyes == null:
		var eyes_batch := MeshBatch2D.new()
		walking_eyes(eyes_batch, BATCH_RADIUS, 0.0, 1.0, 1.0, true)
		_batch_eyes = eyes_batch.build()
	return _batch_eyes


# ------------------------------------------------------------ boss: saw rig

const RIG_METAL: Array[Color] = [Color("3A3F44"), Color("5B6268"), Color("8A9298")]
const RIG_HAZARD := Color("E0912E")
const RIG_LAMP := Color("FFE2A0")
const RIG_SAP := Color("B8F07A")
const SAW_TOOTH := Color("D9D9CB")
const SAW_DISC := Color("9A9F99")
const SAW_DISC_LIGHT := Color("B9BDB6")
const SAW_HUB := Color("644B39")
## Platform half-axes and where the saw blades sit (local, facing +x).
const RIG_RX: float = 58.0
const RIG_RY: float = 50.0
const RIG_SAW_MOUNT := Vector2(45.0, 47.0)
const RIG_SAW_RADIUS: float = 18.0
const RIG_CROWN_RADIUS: float = 40.0
const RIG_CROWN_SEED: int = 77
## The whole rig is drawn this much bigger (a boss towers over the trees).
const RIG_SCALE: float = 1.6


## The Tree Planet boss (user pick B): a huge treant riding an open hover
## saw-rig. The crown is its body (world-lit, never rotates) with eyes on the
## rig's front; roots grip a metal deck rimmed with hazard lamps, a ring of
## sap jets keeps it afloat (it bobs), and two branch arms hold the saw
## blades on struts at the sides - the same blades it fires.
## rot: rig heading; rev 0..1 during the saw windup (blades spin up, push
## out, spark); reload 0..1 after a launch (0 = blades just fired, mounts
## empty, they grow back); hover/time animate the bob, jets and blink.
static func draw_saw_rig(canvas: CanvasItem, crown: Dictionary, rot: float, time: float, rev: float, reload: float, flash: bool) -> void:
	var sk := RIG_SCALE
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * sk)
	var dir := Vector2.RIGHT.rotated(rot)
	var bob := sin(time * 2.2) * 0.5 + 0.5
	var lift := 10.0 + 5.0 * bob
	var xf := Transform2D(rot, Vector2.ZERO)
	# --- shadow (world down-right, grows while it floats higher)
	var disc := _ellipse(RIG_RX, RIG_RY, 24)
	canvas.draw_colored_polygon(_xf_points(xf, disc, Vector2(lift * 0.9, lift * 1.2)), SHADOW)
	for s in [-1.0, 1.0]:
		var mount := xf * Vector2(RIG_SAW_MOUNT.x, RIG_SAW_MOUNT.y * s)
		canvas.draw_circle(mount + Vector2(lift * 0.9, lift * 1.2), RIG_SAW_RADIUS, SHADOW)
	# --- sap jets under the rim (pulse; brighter while revving)
	var jet := 0.35 + 0.25 * sin(time * 9.0) + 0.4 * rev
	for k in range(8):
		var a := TAU * k / 8.0 + 0.2
		var at := xf * Vector2(cos(a) * RIG_RX, sin(a) * RIG_RY)
		canvas.draw_circle(at, 7.0 + 4.0 * jet, Color(RIG_SAP, 0.18 + 0.2 * jet))
		canvas.draw_circle(at, 3.5 + 2.0 * jet, Color("F0FFD0", 0.35 + 0.3 * jet))
	# --- deck
	canvas.draw_colored_polygon(_xf_points(xf, disc), _rig(RIG_METAL[0], flash))
	canvas.draw_colored_polygon(_xf_points(xf, _ellipse(RIG_RX - 7.0, RIG_RY - 7.0, 24)), _rig(RIG_METAL[1], flash))
	if not flash:
		canvas.draw_colored_polygon(_xf_points(xf, _ellipse(RIG_RX - 18.0, RIG_RY - 18.0, 20), Vector2(-5, -5)), Color(RIG_METAL[2], 0.25))
		# Deck plates.
		for y in range(-30, 34, 10):
			var half := (RIG_RX - 12.0) * sqrt(maxf(0.0, 1.0 - pow(float(y) / (RIG_RY - 8.0), 2.0)))
			canvas.draw_line(xf * Vector2(-half, y), xf * Vector2(half, y), Color(RIG_METAL[0], 0.55), 1.5)
		# Hazard lamps round the rim (chasing light).
		for k in range(12):
			var a := TAU * k / 12.0
			var on := int(time * 6.0) % 3 == k % 3
			var lamp := RIG_LAMP if on else RIG_HAZARD
			canvas.draw_circle(xf * Vector2(cos(a) * (RIG_RX - 3.5), sin(a) * (RIG_RY - 3.5)), 2.8, lamp)
	# --- saw struts, branch arms and blades
	for s in [-1.0, 1.0]:
		var push := 6.0 * rev
		var mount := xf * Vector2(RIG_SAW_MOUNT.x + push, RIG_SAW_MOUNT.y * s)
		var root := xf * Vector2(8.0, 26.0 * s)
		canvas.draw_line(root, mount, _rig(RIG_METAL[0], flash), 9.0)
		if not flash:
			canvas.draw_line(root, mount, RIG_METAL[2], 3.5)
		# Branch arm gripping the strut.
		var shoulder := xf * Vector2(-2.0, 16.0 * s)
		var hand := root.lerp(mount, 0.7)
		canvas.draw_line(shoulder, hand, _rig(BARK[0], flash), 10.0)
		if not flash:
			canvas.draw_line(shoulder, hand, BARK[1], 6.0)
			for k in range(3):
				var twig := (hand - shoulder).normalized().rotated(0.5 * (k - 1))
				canvas.draw_line(hand, hand + twig * 7.0, BARK[0], 2.5)
		if reload >= 1.0:
			_saw_blade(canvas, mount, RIG_SAW_RADIUS, time * (2.0 + 16.0 * rev) * s, rev, flash)
		elif reload > 0.05:
			_saw_blade(canvas, mount, RIG_SAW_RADIUS * reload, time * 2.0 * s, 0.0, flash)
		else:
			canvas.draw_circle(mount, 6.0, _rig(RIG_METAL[0], flash))
	# --- roots gripping the deck
	if not flash:
		for k in range(7):
			var a := PI * 0.55 + k * 0.42
			var from := xf * Vector2(-6.0, 0.0)
			var to := xf * (Vector2.RIGHT.rotated(a) * 36.0 + Vector2(-6.0, 0.0))
			canvas.draw_line(from, to, BARK[0], 6.0)
			canvas.draw_line(from, to, BARK[1], 3.0)
	# --- the treant's crown (world-lit) and its eyes on the heading side
	var centre := xf * Vector2(-6.0, 0.0)
	canvas.draw_set_transform((centre - Vector2(0, bob * 2.0)) * sk, 0.0, Vector2.ONE * sk)
	var mesh: ArrayMesh = crown["white"] if flash else crown["crown"]
	if mesh != null:
		canvas.draw_mesh(mesh, null)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * sk)
	if flash:
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var side := dir.orthogonal()
	var face := centre - Vector2(0, bob * 2.0) + dir * RIG_CROWN_RADIUS * 0.52
	var blink := fmod(time, 5.1) < 0.14
	var glow := 0.8 + 0.2 * sin(time * 3.0) + 0.4 * rev
	for eye in [[face + side * 8.5, 4.0], [face - side * 8.5, 4.0], [face + dir * 9.0, 2.4]]:
		var at: Vector2 = eye[0]
		var r: float = eye[1]
		canvas.draw_circle(at, r * 1.8, SOCKET)
		if blink:
			canvas.draw_line(at - side * r, at + side * r, TREE_EYE, 1.5)
			continue
		canvas.draw_circle(at, r * 1.6, Color(TREE_EYE, 0.25 * glow))
		canvas.draw_circle(at, r, TREE_EYE if rev < 0.5 else Color("FFB04A"))
		canvas.draw_circle(at + dir * r * 0.25, r * 0.45, TREE_EYE_HOT)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _rig(color: Color, flash: bool) -> Color:
	return Palette.HIT_FLASH if flash else color


static func _ellipse(rx: float, ry: float, n: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	for k in range(n):
		var a := TAU * k / n
		p.append(Vector2(cos(a) * rx, sin(a) * ry))
	return p


static func _xf_points(xf: Transform2D, pts: PackedVector2Array, offset := Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(xf * q + offset)
	return out


## One saw blade (same look as ForestSawProjectile, a little richer).
static func _saw_blade(canvas: CanvasItem, at: Vector2, r: float, spin: float, rev: float, flash: bool) -> void:
	if rev > 0.0 and not flash:
		canvas.draw_circle(at, r + 9.0, Color(1.0, 0.55, 0.25, 0.22 * rev))
	for k in range(12):
		var a := spin + TAU * k / 12.0
		var d := Vector2.RIGHT.rotated(a)
		canvas.draw_colored_polygon(PackedVector2Array([at + d * r * 0.8, at + d.rotated(0.22) * r * 1.18, at + d.rotated(0.3) * r * 0.8]), _rig(SAW_TOOTH, flash))
	canvas.draw_circle(at, r * 0.86, _rig(SAW_DISC, flash))
	if flash:
		return
	canvas.draw_circle(at + Vector2(-1, -1), r * 0.62, SAW_DISC_LIGHT)
	for k in range(4):
		var a := spin + TAU * k / 4.0
		canvas.draw_line(at + Vector2.RIGHT.rotated(a) * r * 0.2, at + Vector2.RIGHT.rotated(a) * r * 0.55, Color("8A8E88"), 2.0)
	canvas.draw_circle(at, r * 0.3, SAW_HUB)
	canvas.draw_circle(at, r * 0.12, Color("3A2A1E"))
	if rev > 0.3:
		for k in range(5):
			var a := spin * 2.0 + k * 1.3
			var p := at + Vector2.RIGHT.rotated(a) * r * 1.15
			canvas.draw_line(p, p + Vector2.RIGHT.rotated(a + 1.2) * 10.0 * rev, RIG_LAMP, 2.0)
