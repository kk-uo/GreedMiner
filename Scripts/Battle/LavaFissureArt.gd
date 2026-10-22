extends RefCounted

## Big lightning-shaped lava rifts for the Volcanic Planet (user pick:
## template C "fault rift"): a long wide jagged rift made by midpoint
## displacement (big and small kinks, straight segments, sharp turns - no
## smooth wiggles) with short side cracks like a ladder. Width swells and
## pinches and tapers to points. Layers: soft glow, charred crust, dark lava,
## lava, hot streak, bright core. Battlefield bakes it (LavaFissureLayer).
## Load with preload(); no class_name on purpose.

const CRUST := Color("1A1210")
const CRUST_EDGE := Color("2E2420")
const LAVA_DEEP := Color("8E1F0A")
const LAVA := Color("E2541A")
const LAVA_HOT := Color("FF9A3A")
const LAVA_CORE := Color("FFE08A")


## Returns {branches: [{points, widths}], emerge: PackedVector2Array}.
## Returns {branches: [{points, widths}], emerge: PackedVector2Array}
## (emerge = wide spots where enemies can climb out).
static func generate_rift(rng: RandomNumberGenerator, origin: Vector2, angle: float, scale_factor: float = 1.0) -> Dictionary:
	var branches: Array = []
	var length := rng.randf_range(700.0, 900.0) * scale_factor
	var trunk := _bolt(rng, branches, origin, angle, length, 54.0 * scale_factor, 0, 0.35)
	# Short side cracks, alternating sides, like a ladder.
	var count := 7
	for index in range(count):
		var k := (float(index) + 0.8) / float(count + 1)
		var at: int = int(k * float(trunk["points"].size() - 1))
		var side := 1.0 if index % 2 == 0 else -1.0
		var a := angle + side * (PI * 0.5 + rng.randf_range(-0.35, 0.35))
		_bolt(rng, branches, trunk["points"][at], a, rng.randf_range(70.0, 150.0) * scale_factor, trunk["widths"][at] * 0.45, 0, 0.6, true)
	var emerge := PackedVector2Array()
	var pts: PackedVector2Array = trunk["points"]
	var widths: PackedFloat32Array = trunk["widths"]
	for index in range(2, pts.size() - 2, 3):
		if widths[index] >= 26.0 * scale_factor:
			emerge.append(pts[index])
	return {"branches": branches, "emerge": emerge}


## A jagged bolt by midpoint displacement (like real lightning): big kinks
## and small kinks, all straight segments with sharp turns. The width swells
## and pinches along the way and tapers to a point; `full_start` keeps the
## start wide (arms leaving a pool). depth > 0 adds forks.
static func _bolt(rng: RandomNumberGenerator, branches: Array, start: Vector2, heading: float, length: float, max_width: float, depth: int, fork_chance: float, full_start: bool = false) -> Dictionary:
	var end := start + Vector2.RIGHT.rotated(heading) * length
	var points := PackedVector2Array([start, end])
	var rough := 0.22
	for level in range(4):
		var next := PackedVector2Array([points[0]])
		for index in range(points.size() - 1):
			var a := points[index]
			var b := points[index + 1]
			var normal := (b - a).orthogonal().normalized()
			var mid := a.lerp(b, rng.randf_range(0.4, 0.6)) + normal * rng.randf_range(-1.0, 1.0) * a.distance_to(b) * rough
			next.append(mid)
			next.append(b)
		points = next
		rough *= 0.92
	var widths := PackedFloat32Array()
	var swell_phase := rng.randf() * TAU
	for index in range(points.size()):
		var t := float(index) / float(points.size() - 1)
		var profile := pow(sin(PI * clampf(t, 0.0, 1.0)), 0.55) if not full_start else pow(1.0 - t, 0.7)
		var swell := 0.75 + 0.25 * sin(t * 9.0 + swell_phase) + 0.12 * sin(t * 23.0 + swell_phase * 2.0)
		widths.append(maxf(max_width * profile * swell, 1.2))
	var branch := {"points": points, "widths": widths}
	branches.append(branch)
	if depth > 0:
		var forks := rng.randi_range(2, 4) if depth >= 2 else rng.randi_range(1, 2)
		for f in range(forks):
			if rng.randf() > fork_chance and depth < 2:
				continue
			var at := rng.randi_range(int(points.size() * 0.2), int(points.size() * 0.7))
			var dir := heading + (1.0 if f % 2 == 0 else -1.0) * rng.randf_range(0.4, 0.9)
			_bolt(rng, branches, points[at], dir, length * rng.randf_range(0.28, 0.45), widths[at] * 0.55, depth - 1, fork_chance, true)
	return branch


# ------------------------------------------------------------------ drawing

## Static layers (baked once), flat like the rest of the art: a charred
## rim, then even lava bands (no glow halo or gradient streaks).
static func draw_static(c: Object, fissure: Dictionary) -> void:
	var branches: Array = fissure["branches"]
	# Each layer over all branches so the joints merge.
	for branch in branches:
		_strip(c, branch, 7.0, 1.0, CRUST)
	for branch in branches:
		_strip(c, branch, 0.0, 1.0, LAVA_DEEP)
	for branch in branches:
		_strip(c, branch, -1.0, 0.8, LAVA)


## One flat lighter band down the middle. Phase 0 holds the whole band and
## phase 1 is empty, so the layer pulses evenly instead of in patches.
static func draw_core(c: Object, fissure: Dictionary, phase: int) -> void:
	if phase != 0:
		return
	for branch in fissure["branches"]:
		_strip(c, branch, -3.0, 0.42, LAVA_HOT)


## One polyline as quads + joint discs: width * k + extra. phase >= 0 keeps
## only every other group of 4 segments (for the alternating pulse).
static func _strip(c: Object, branch: Dictionary, extra: float, k: float, color: Color, shift: Vector2 = Vector2.ZERO, phase: int = -1) -> void:
	var pts: PackedVector2Array = branch["points"]
	var widths: PackedFloat32Array = branch["widths"]
	for index in range(pts.size() - 1):
		var a := pts[index] + shift
		var b := pts[index + 1] + shift
		var wa := widths[index] * k + extra
		var wb := widths[index + 1] * k + extra
		if wa <= 0.3 and wb <= 0.3:
			continue
		if phase >= 0 and (index / 4) % 2 != phase:
			continue
		var col := color
		var n := (b - a).orthogonal().normalized()
		c.draw_colored_polygon(PackedVector2Array([a + n * wa * 0.5, b + n * wb * 0.5, b - n * wb * 0.5, a - n * wa * 0.5]), col)
		if wb > 0.6:
			c.draw_circle(b, wb * 0.5, col)
