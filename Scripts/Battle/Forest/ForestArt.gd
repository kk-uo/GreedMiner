extends RefCounted

## Tree Planet art (user pick: direction A "ancient grove"). Flat 3-tone
## top-down trees with a hard shadow down-right, drawn into any pen that has
## draw_colored_polygon / draw_circle / draw_line (a CanvasItem or a
## MeshBatch2D for baking). Presentation only.
## Load with preload(); no class_name on purpose.

const SHADOW := Color(0, 0, 0, 0.28)
const SH := Vector2(5, 7)
const OAK: Array[Color] = [Color("2C4A2A"), Color("3C6234"), Color("5C8A48")]
const OAK_DEEP: Array[Color] = [Color("263F26"), Color("335530"), Color("4E7A40")]
const OAK_LIGHT := Color("7FAA5C")
const WILLOW: Array[Color] = [Color("3A5A30"), Color("587E40"), Color("86AA5C")]
const ROOT := Color("4A3A2A")
const ROOT_LIGHT := Color("6A5440")
const TRUNK: Array[Color] = [Color("3A2A1E"), Color("5A4130"), Color("7A5A42")]
const STUMP_TOP := Color("B08A5E")
const RING := Color("8A6A46")
const MOSS := Color("67793F")
## Ground under the canopy (the forest floor between trunks).
const FLOOR := Color("2F3B26")


static func ngon(c: Vector2, r: float, n: int, rot: float = 0.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	for k in range(n):
		var a := rot + TAU * float(k) / float(n)
		p.append(c + Vector2(cos(a), sin(a)) * r)
	return p


static func blob(c: Vector2, r: float, seed: int, sides: int = 12, wob: float = 0.15) -> PackedVector2Array:
	var p := PackedVector2Array()
	var ph := float(seed % 997) * 0.37
	for k in range(sides):
		var a := TAU * float(k) / float(sides)
		var rr := r * (1.0 + wob * sin(a * 3.0 + ph) + wob * 0.6 * sin(a * 5.0 + ph * 1.7))
		p.append(c + Vector2(cos(a), sin(a)) * rr)
	return p


## Round lumpy canopy made of lobes: shadow, dark, mid, light upper-left.
static func canopy(pen: Object, c: Vector2, r: float, seed: int, tones: Array[Color] = OAK, lobes: int = 7, shadow: bool = true) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var parts: Array = [[c, r * 0.72]]
	for k in range(lobes):
		var a := TAU * float(k) / float(lobes) + rng.randf_range(-0.2, 0.2)
		parts.append([c + Vector2(cos(a), sin(a)) * r * 0.5, r * rng.randf_range(0.42, 0.55)])
	if shadow:
		for p in parts:
			pen.draw_colored_polygon(ngon((p[0] as Vector2) + SH * clampf(r / 34.0, 0.6, 2.0), float(p[1]), 10), SHADOW)
	for p in parts:
		pen.draw_colored_polygon(ngon(p[0], float(p[1]), 10), tones[0])
	for p in parts:
		pen.draw_colored_polygon(ngon((p[0] as Vector2) + Vector2(-0.12, -0.16) * float(p[1]), float(p[1]) * 0.8, 10), tones[1])
	for p in parts:
		var q: Vector2 = p[0]
		if (q - c).dot(Vector2(-1, -1)) >= -r * 0.1:
			pen.draw_colored_polygon(ngon(q + Vector2(-0.3, -0.34) * float(p[1]), float(p[1]) * 0.38, 8), tones[2])


## Only the hard shadow of canopy() (for a separate shadow pass).
static func canopy_shadow(pen: Object, c: Vector2, r: float, seed: int, lobes: int = 7) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var off := SH * clampf(r / 34.0, 0.6, 2.0)
	pen.draw_colored_polygon(ngon(c + off, r * 0.72, 10), SHADOW)
	for k in range(lobes):
		var a := TAU * float(k) / float(lobes) + rng.randf_range(-0.2, 0.2)
		pen.draw_colored_polygon(ngon(c + Vector2(cos(a), sin(a)) * r * 0.5 + off, r * rng.randf_range(0.42, 0.55), 10), SHADOW)


## The empty spot a treant tore itself out of: a dark hole and torn roots.
static func spot(pen: Object, c: Vector2, r: float, seed: int) -> void:
	pen.draw_colored_polygon(blob(c, r * 0.62, seed, 12, 0.18), Color("3A2C1E"))
	pen.draw_colored_polygon(blob(c + Vector2(-1.5, -1.5), r * 0.4, seed + 1, 10, 0.2), Color("221810"))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for k in range(5):
		var a := TAU * float(k) / 5.0 + rng.randf_range(-0.3, 0.3)
		var dir := Vector2(cos(a), sin(a))
		pen.draw_line(c + dir * r * 0.4, c + dir * r * rng.randf_range(0.75, 0.95), ROOT, maxf(2.0, r * 0.07))


## A spot the dwarves dug over for good: flattened lighter soil and pebbles.
static func dug(pen: Object, c: Vector2, r: float, seed: int) -> void:
	pen.draw_colored_polygon(blob(c, r * 0.6, seed, 12, 0.15), Color("6A5A40"))
	pen.draw_colored_polygon(blob(c + Vector2(-2, -2), r * 0.42, seed + 2, 10, 0.15), Color("7E6C4E"))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for k in range(4):
		var p := c + Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35)) * r
		pen.draw_colored_polygon(ngon(p, maxf(2.0, r * 0.07), 5, rng.randf()), Color("4E4434"))


static func roots(pen: Object, c: Vector2, r: float, n: int, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for k in range(n):
		var a := TAU * float(k) / float(n) + rng.randf_range(-0.25, 0.25)
		var dir := Vector2(cos(a), sin(a))
		var side := dir.orthogonal()
		var bend := rng.randf_range(-0.25, 0.25)
		var p0 := c + dir * r * 0.55
		var p1 := c + dir.rotated(bend * 0.5) * r * 0.95
		var p2 := c + dir.rotated(bend) * r * rng.randf_range(1.04, 1.12)
		var w := r * 0.11
		var root := PackedVector2Array([p0 + side * w, p1 + side * w * 0.55, p2, p1 - side * w * 0.55, p0 - side * w])
		var shade := PackedVector2Array()
		for q in root:
			shade.append(q + SH * 0.5)
		pen.draw_colored_polygon(shade, SHADOW)
		pen.draw_colored_polygon(root, ROOT)
		pen.draw_circle(p2, w * 0.3, ROOT)
		pen.draw_line(p0 - side * w * 0.3, p1 - side * w * 0.2, ROOT_LIGHT, maxf(1.5, w * 0.3))


static func giant_oak(pen: Object, c: Vector2, r: float, seed: int, shadow: bool = true) -> void:
	roots(pen, c, r, 7, seed)
	canopy(pen, c, r, seed, OAK, 9, shadow)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 3
	for i in range(6):
		var p := c + Vector2(rng.randf_range(-0.6, 0.1), rng.randf_range(-0.6, 0.1)) * r
		pen.draw_colored_polygon(ngon(p, r * 0.07, 6, rng.randf()), Color(OAK_LIGHT, 0.8))


static func willow(pen: Object, c: Vector2, r: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var disc := ngon(c, r, 16)
	var shade := PackedVector2Array()
	for q in disc:
		shade.append(q + SH)
	pen.draw_colored_polygon(shade, SHADOW)
	pen.draw_colored_polygon(disc, WILLOW[0])
	for k in range(36):
		var a := TAU * float(k) / 36.0 + rng.randf_range(-0.05, 0.05)
		var dir := Vector2(cos(a), sin(a))
		pen.draw_line(c + dir * r * 0.2, c + dir * r * rng.randf_range(0.75, 1.05), WILLOW[1] if k % 2 == 0 else WILLOW[2], maxf(2.0, r * 0.045))
	pen.draw_circle(c, r * 0.3, WILLOW[1])
	pen.draw_circle(c + Vector2(-0.1, -0.1) * r, r * 0.16, WILLOW[2])


static func bushes(pen: Object, c: Vector2, r: float, seed: int) -> void:
	for k in range(3):
		var p := c + Vector2(cos(k * 2.1 + seed), sin(k * 2.1 + seed)) * r * 0.5
		canopy(pen, p, r * 0.45, seed + k, OAK, 5)


static func stump(pen: Object, c: Vector2, r: float, seed: int) -> void:
	roots(pen, c, r * 1.1, 5, seed)
	var ring := ngon(c, r, 14)
	var shade := PackedVector2Array()
	for q in ring:
		shade.append(q + SH * 0.5)
	pen.draw_colored_polygon(shade, SHADOW)
	pen.draw_colored_polygon(ring, TRUNK[0])
	pen.draw_colored_polygon(ngon(c, r * 0.84, 14), STUMP_TOP)
	for k in range(1, 4):
		pen.draw_arc(c, r * 0.84 * float(k) / 4.0, 0.0, TAU, 20, RING, maxf(1.0, r * 0.06))
	pen.draw_colored_polygon(blob(c + Vector2(r * 0.35, r * 0.3), r * 0.42, seed, 10, 0.2), MOSS)


static func log(pen: Object, c: Vector2, r: float, seed: int) -> void:
	var dir := Vector2.RIGHT.rotated(float(seed % 360) * 0.0174)
	var a := c - dir * r
	var b := c + dir * r
	pen.draw_line(a + SH * 0.6, b + SH * 0.6, SHADOW, r * 0.42)
	pen.draw_line(a, b, TRUNK[0], r * 0.42)
	pen.draw_line(a, b, TRUNK[1], r * 0.3)
	pen.draw_line(a - dir.orthogonal() * r * 0.06, b - dir.orthogonal() * r * 0.06, TRUNK[2], r * 0.08)
	pen.draw_circle(b, r * 0.21, STUMP_TOP)
	for k in range(3):
		pen.draw_colored_polygon(blob(a.lerp(b, 0.2 + 0.25 * k), r * 0.13, seed + k, 8, 0.25), MOSS)
