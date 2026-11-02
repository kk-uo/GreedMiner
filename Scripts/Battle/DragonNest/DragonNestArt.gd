class_name DragonNestArt
extends RefCounted

## Static painter for Dragon Nest creatures (red dragon set, art direction A).
## Everything is drawn into a MeshBatch2D in a local frame that faces +x, then
## flushed once per frame by the caller. Top-down, three-tone blocks, glowing
## eyes - the same language as the other planets' enemies.

const BODY: Array[Color] = [Color("5E1714"), Color("9E2A22"), Color("D5503A")]
const PLATE: Array[Color] = [Color("7A4A16"), Color("C98A2B"), Color("F2C65A")]
const WING: Array[Color] = [Color("3F0F0E"), Color("6E1C19"), Color("9A3227")]
const BONE := Color("E0A070")
const HORN: Array[Color] = [Color("8C7B63"), Color("D9CBB0"), Color("F5EEDC")]
const EYE := Color("FFD84A")
const SPIKE := Color("F2C65A")
const BREATH := Color("FF8A2A")
const KOB: Array[Color] = [Color("7A3A1E"), Color("B4572C"), Color("E08A4C")]
const KOB_GEAR: Array[Color] = [Color("4A3426"), Color("7A5A40"), Color("A8835C")]
const KOB_LIGHT := Color("FFC84A")
const LIZ: Array[Color] = [Color("4A2A1E"), Color("7A4630"), Color("B06A44")]
const LIZ_GEM := Color("FF5A3A")
const HOLE := Color(0.06, 0.04, 0.035, 0.85)
const SHADOW := Color(0.0, 0.0, 0.0, 0.24)

const HEAD_K := {&"great": 1.3, &"ancient": 1.45, &"wyrm": 1.7}
const SPAN := {&"great": 1.0, &"ancient": 1.15, &"wyrm": 0.55}
const TAIL := {&"great": 1.3, &"ancient": 1.45, &"wyrm": 1.0}
const NECK := {&"great": 0.45, &"ancient": 0.5, &"wyrm": 0.18}

## When its alpha is > 0 every fill uses this colour (hit flash, silhouettes).
static var mono := Color(0, 0, 0, 0)
static var _base := Transform2D.IDENTITY


static func begin(pen: MeshBatch2D, xf: Transform2D) -> void:
	_base = xf
	pen._xf = xf


static func _push(pen: MeshBatch2D, local: Transform2D) -> void:
	pen._xf = _base * local


static func _pop(pen: MeshBatch2D) -> void:
	pen._xf = _base


static func _c(color: Color) -> Color:
	return Color(mono.r, mono.g, mono.b, mono.a * color.a) if mono.a > 0.0 else color


static func _poly(pen: MeshBatch2D, points: PackedVector2Array, color: Color) -> void:
	pen.draw_colored_polygon(points, _c(color))


static func _line(pen: MeshBatch2D, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var col := _c(color)
	pen.draw_line(a, b, col, width)
	pen.draw_circle(a, width * 0.5, col)
	pen.draw_circle(b, width * 0.5, col)


static func _circle(pen: MeshBatch2D, p: Vector2, r: float, color: Color) -> void:
	pen.draw_circle(p, r, _c(color))


static func ellipse(center: Vector2, rx: float, ry: float, n: int = 12, rot: float = 0.0, seed_value: int = 0, jag: float = 0.0) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var points := PackedVector2Array()
	for i in range(n):
		var a := TAU * float(i) / float(n) + rot
		var k := 1.0 - jag * rng.randf()
		points.append(center + Vector2(cos(a) * rx * k, sin(a) * ry * k))
	return points


static func _scaled(points: PackedVector2Array, center: Vector2, k: float, offset: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in range(points.size()):
		out[i] = center + (points[i] - center) * k + offset
	return out


## Dark block, base block nudged up-left, small highlight block.
static func layered(pen: MeshBatch2D, points: PackedVector2Array, cols: Array, center: Vector2, size: float) -> void:
	var o := Vector2.ONE * size * -0.06
	_poly(pen, points, cols[0])
	_poly(pen, _scaled(points, center, 0.9, o), cols[1])
	_poly(pen, _scaled(points, center, 0.5, o * 2.6), cols[2])


static func glow_eye(pen: MeshBatch2D, p: Vector2, r: float, color: Color) -> void:
	if mono.a > 0.0:
		_circle(pen, p, r, color)
		return
	pen.draw_circle(p, r * 2.4, Color(color, 0.18))
	pen.draw_circle(p, r * 1.5, Color(color, 0.35))
	pen.draw_circle(p, r, color)
	pen.draw_circle(p + Vector2(r * 0.25, -r * 0.3), r * 0.4, Color(1, 1, 1, 0.85))


## Spine and both edges of a tapering tail that trails behind the body (-x).
static func _tail(R: float, length: float, w0: float, wave: float, phase: float, n: int = 14) -> Array:
	var spine := PackedVector2Array()
	for i in range(n + 1):
		var t := float(i) / float(n)
		spine.append(Vector2(-0.42 * R - t * length * R, sin(t * 2.6 + phase) * wave * R * t))
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(spine.size()):
		var t := float(i) / float(n)
		var w := w0 * R * pow(1.0 - t, 0.9) + 0.012 * R
		var d: Vector2 = (spine[i + 1] - spine[i]) if i < n else (spine[i] - spine[i - 1])
		var normal := d.normalized().orthogonal()
		left.append(spine[i] + normal * w)
		right.append(spine[i] - normal * w)
	return [spine, left, right]


static func _strip(pen: MeshBatch2D, left: PackedVector2Array, right: PackedVector2Array, color: Color, offset: Vector2 = Vector2.ZERO) -> void:
	for i in range(left.size() - 1):
		_poly(pen, PackedVector2Array([left[i] + offset, left[i + 1] + offset, right[i + 1] + offset, right[i] + offset]), color)


static func _quad_bezier(a: Vector2, ctrl: Vector2, b: Vector2, out: PackedVector2Array, steps: int = 5) -> void:
	for s in range(1, steps + 1):
		var t := float(s) / float(steps)
		out.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))


static func wing_points(R: float, side: float, span: float) -> Dictionary:
	var sh := Vector2(0.18 * R, 0.22 * R * side)
	var el := Vector2(0.05 * R, (0.22 + 0.55 * span) * R * side)
	var wr := Vector2(-0.12 * R, (0.22 + 1.0 * span) * R * side)
	var tips := [Vector2(-0.55 * R, (0.22 + 1.25 * span) * R * side), Vector2(-0.85 * R, (0.22 + 0.95 * span) * R * side),
		Vector2(-0.95 * R, (0.22 + 0.55 * span) * R * side), Vector2(-0.75 * R, (0.25 + 0.18 * span) * R * side)]
	return {"shoulder": sh, "elbow": el, "wrist": wr, "tips": tips, "root": Vector2(-0.38 * R, 0.16 * R * side)}


static func _wing(pen: MeshBatch2D, R: float, side: float, span: float, tattered: bool, seed_value: int) -> void:
	var w := wing_points(R, side, span)
	var sh: Vector2 = w["shoulder"]
	var el: Vector2 = w["elbow"]
	var wr: Vector2 = w["wrist"]
	var tips: Array = w["tips"]
	var root: Vector2 = w["root"]
	var regal := tattered
	# trailing edge: deep scallops between the fingers
	var edge := PackedVector2Array([tips[0]])
	for i in range(1, tips.size()):
		var a: Vector2 = tips[i - 1]
		var b: Vector2 = tips[i]
		var m := (a + b) * 0.5
		_quad_bezier(a, m + (wr - m) * 0.42, b, edge)
	var last: Vector2 = tips[tips.size() - 1]
	_quad_bezier(last, (last + root) * 0.5 + (wr - (last + root) * 0.5) * 0.2, root, edge)
	var outline := PackedVector2Array([sh, el, wr])
	outline.append_array(edge)
	_poly(pen, outline, WING[0])
	# membrane panels: lit toward the fingers, darker near the body
	for i in range(1, tips.size()):
		var a: Vector2 = tips[i - 1]
		var b: Vector2 = tips[i]
		var m := (a + b) * 0.5
		var panel := PackedVector2Array([wr, wr + (a - wr) * 0.86, wr + (m - wr) * 0.58, wr + (b - wr) * 0.86])
		_poly(pen, panel, Color(WING[1] if i % 2 == 1 else WING[2], 0.92))
		_poly(pen, PackedVector2Array([wr, wr + (a - wr) * 0.45, wr + (m - wr) * 0.3, wr + (b - wr) * 0.45]), Color(WING[2].lightened(0.12), 0.55))
		# thin veins fanning out between the fingers
		_line(pen, wr + (m - wr) * 0.15, wr + (m - wr) * 0.5, Color(WING[0], 0.7), maxf(1.0, R * 0.012))
	_poly(pen, PackedVector2Array([sh, el, wr, root]), Color(WING[0], 0.55))
	# glowing rim along the trailing edge (gold on the Ancient Dragon)
	var rim := Color("F2C14A") if regal else Color("D9502E")
	for i in range(edge.size() - 1):
		_line(pen, edge[i], edge[i + 1], Color(rim, 0.85), maxf(1.0, R * (0.022 if regal else 0.016)))
	if tattered:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for k in range(4):
			var i := rng.randi_range(1, tips.size() - 1)
			var p: Vector2 = (tips[i - 1] as Vector2).lerp(tips[i], rng.randf_range(0.3, 0.7))
			p = p + (wr - p) * 0.3
			var rr := R * rng.randf_range(0.05, 0.1)
			_poly(pen, ellipse(p, rr, rr * 0.7, 6, rng.randf(), seed_value + k, 0.3), HOLE)
	# bones
	var bw := maxf(1.2, R * 0.035)
	_line(pen, sh, el, BONE, bw * 1.7)
	_line(pen, el, wr, BONE, bw * 1.5)
	for tip in tips:
		_line(pen, wr, tip, BONE, bw)
	_circle(pen, wr, bw * 1.4, BONE)
	_circle(pen, el, bw * 1.2, BONE)
	# spikes along the leading edge of the arm
	var lead := [[sh, el], [el, wr]]
	for seg in lead:
		var p0: Vector2 = seg[0]
		var p1: Vector2 = seg[1]
		var out := (p1 - p0).orthogonal().normalized()
		if out.x < 0.0:
			out = -out
		for k in range(3):
			var q := p0.lerp(p1, 0.2 + 0.3 * float(k))
			var dir := (p1 - p0).normalized()
			_poly(pen, PackedVector2Array([q - dir * R * 0.025, q + out * R * 0.07 + dir * R * 0.03, q + dir * R * 0.03]), HORN[1])
	# hooked claws on every finger tip and a big thumb claw at the wrist
	var claw := Color("F2C14A") if regal else HORN[2]
	for tip in tips:
		var t: Vector2 = tip
		var d := (t - wr).normalized()
		var n := d.orthogonal()
		_poly(pen, PackedVector2Array([t + n * R * 0.02, t + d * R * 0.09 + n * R * 0.03 * side, t - n * R * 0.02]), claw)
	_poly(pen, PackedVector2Array([wr + Vector2(R * 0.02, 0), wr + Vector2(R * 0.14, R * 0.04 * side), wr + Vector2(R * 0.03, R * 0.06 * side)]), claw)


## Local position of a wing's wrist after the wing is swung by rot_deg.
static func wing_wrist(R: float, kind: StringName, side: float, rot_deg: float) -> Vector2:
	var w := wing_points(R, side, float(SPAN[kind]))
	var pivot: Vector2 = w["shoulder"]
	return pivot + ((w["wrist"] as Vector2) - pivot).rotated(deg_to_rad(-side * rot_deg))


## Distance from the body centre to the snout tip.
static func head_reach(R: float, kind: StringName) -> float:
	var hk: float = HEAD_K[kind]
	return (0.5 + float(NECK[kind]) + 0.1 * hk + 0.2 * hk * 1.55) * R


static func head_centre(R: float, kind: StringName, lunge: float = 0.0) -> Vector2:
	var hk: float = HEAD_K[kind]
	return Vector2(0.5 * R + float(NECK[kind]) * R + 0.1 * R * hk + lunge * R, 0.0)


## A full dragon facing +x. opts: wing_rot (deg, swings wings forward),
## flap (deg amplitude), lunge (head shift in R), mouth (0..1 fire glow),
## shadow (bool), shadow_offset (Vector2, local), eyes_shut (bool).
static func dragon(pen: MeshBatch2D, R: float, kind: StringName, t: float, opts: Dictionary = {}) -> void:
	var hk: float = HEAD_K[kind]
	var span: float = SPAN[kind]
	var tail_len: float = TAIL[kind]
	var nl: float = NECK[kind]
	var lunge: float = float(opts.get("lunge", 0.0))
	var flap_amp: float = float(opts.get("flap", 0.0))
	var wing_rot: float = float(opts.get("wing_rot", 0.0)) + sin(t * float(opts.get("flap_speed", 7.0))) * flap_amp
	if bool(opts.get("shadow", true)) and mono.a <= 0.0:
		var so: Vector2 = opts.get("shadow_offset", Vector2(-0.2 * R, 0.12 * R))
		pen.draw_colored_polygon(ellipse(so, 1.4 * R * (span * 0.8 + 0.3), 0.75 * R * (span + 0.2), 18), SHADOW)
	# tail
	var tail := _tail(R, tail_len, 0.17, 0.32, 0.8 + sin(t * 1.7) * 0.5)
	_strip(pen, tail[1], tail[2], BODY[0])
	var tail2 := _tail(R, tail_len * 0.98, 0.11, 0.32, 0.8 + sin(t * 1.7) * 0.5)
	_strip(pen, tail2[1], tail2[2], BODY[1], Vector2(-1.0, -1.5))
	var spine: PackedVector2Array = tail[0]
	var tip := spine[spine.size() - 1]
	var ang := (tip - spine[spine.size() - 3]).angle()
	var sp := R * 0.16
	_poly(pen, PackedVector2Array([tip + Vector2.from_angle(ang) * sp * 1.6, tip + Vector2.from_angle(ang + 2.2) * sp,
		tip - Vector2.from_angle(ang) * sp * 0.2, tip + Vector2.from_angle(ang - 2.2) * sp]), PLATE[1] if kind != &"wyrm" else BODY[1])
	# legs
	for leg in [[0.32, 0.3, 55.0], [0.32, -0.3, -55.0], [-0.3, 0.28, 120.0], [-0.3, -0.28, -120.0]]:
		var a := deg_to_rad(float(leg[2]))
		var p0 := Vector2(float(leg[0]) * R, float(leg[1]) * R)
		var p1 := p0 + Vector2.from_angle(a) * 0.2 * R
		_line(pen, p0, p1, BODY[0], 0.15 * R)
		_circle(pen, p1, 0.08 * R, BODY[1])
		var fwd := 0.0 if float(leg[0]) > 0.0 else PI
		for cl in [-0.6, 0.0, 0.6]:
			_circle(pen, p1 + Vector2.from_angle(fwd + cl) * 0.09 * R, 0.025 * R, HORN[2])
	# wings
	for side in [1.0, -1.0]:
		var pivot := Vector2(0.18 * R, 0.22 * R * side)
		var rot := deg_to_rad(-side * wing_rot)
		_push(pen, Transform2D(0.0, pivot) * Transform2D(rot, Vector2.ZERO) * Transform2D(0.0, -pivot))
		_wing(pen, R, side, span, kind == &"ancient", 3 + int(side))
		_pop(pen)
	# body
	var body := ellipse(Vector2.ZERO, 0.58 * R, 0.38 * R, 12, 0.1, 5, 0.04)
	layered(pen, body, BODY, Vector2.ZERO, R)
	var n := 6 if kind != &"wyrm" else 4
	for i in range(n):
		var x := 0.42 * R - float(i) * (0.8 * R / float(n))
		var w := 0.07 * R * (1.2 - float(i) / float(n) * 0.4)
		_poly(pen, PackedVector2Array([Vector2(x + w * 1.4, 0), Vector2(x - w * 0.6, -w), Vector2(x - w * 1.2, 0), Vector2(x - w * 0.6, w)]), SPIKE)
	for i in range(1, spine.size() - 2, 2):
		var w := 0.045 * R * (1.0 - float(i / 2) / 7.0)
		var p := spine[i]
		_poly(pen, PackedVector2Array([p + Vector2(w * 1.5, 0), p + Vector2(-w * 0.7, -w), p + Vector2(-w * 0.7, w)]), Color(SPIKE, 0.9))
	if kind == &"ancient":
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		for k in range(14):
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf())
			var cp := Vector2(cos(a) * d * 0.45 * R, sin(a) * d * 0.3 * R)
			_circle(pen, cp, 0.035 * R, Color("F2C65A"))
			_circle(pen, cp - Vector2.ONE * 0.008 * R, 0.018 * R, Color("FFF1B0"))
		_line(pen, Vector2(-0.25, -0.22) * R, Vector2(0.05, -0.05) * R, BODY[0], 0.03 * R)
		_line(pen, Vector2(-0.1, 0.25) * R, Vector2(0.15, 0.08) * R, BODY[0], 0.03 * R)
		var glow := 0.5 + 0.5 * sin(t * 2.2)
		pen.draw_circle(Vector2(0.25 * R, 0), 0.12 * R, _c(Color(BREATH, 0.22 + 0.15 * glow)))
		_circle(pen, Vector2(0.25 * R, 0), 0.06 * R, EYE)
	# neck + head
	var hr := 0.2 * R * hk
	var hx := 0.5 * R + nl * R + 0.1 * R * hk + lunge * R
	var neck := PackedVector2Array([Vector2(0.4 * R, -0.17 * R), Vector2(hx - 0.1 * R, -0.1 * R * hk), Vector2(hx - 0.1 * R, 0.1 * R * hk), Vector2(0.4 * R, 0.17 * R)])
	_poly(pen, neck, BODY[0])
	_poly(pen, _scaled(neck, Vector2.ZERO, 1.0, Vector2(-1.0, -1.5)), BODY[1])
	var horns := [[-0.7, 0.75, 1.35, 0.55]]
	if kind == &"ancient":
		horns = [[-0.7, 0.75, 1.5, 0.6], [-0.2, 0.85, 1.05, 0.95], [-0.95, 0.4, 0.95, 0.3]]
	elif kind == &"wyrm":
		horns = [[-0.6, 0.65, 0.7, 0.45]]
	for horn in horns:
		for sd in [1.0, -1.0]:
			var base := Vector2(hx + float(horn[0]) * hr, float(horn[1]) * hr * sd)
			var htip := base + Vector2(-float(horn[2]) * hr, float(horn[3]) * hr * sd)
			var mid := (base + htip) * 0.5 + Vector2(0, 0.25 * hr * sd)
			var a0 := base + Vector2(0.18 * hr, -0.12 * hr * sd)
			_poly(pen, PackedVector2Array([a0, mid, htip, base + Vector2(-0.12 * hr, 0.15 * hr * sd)]), HORN[0])
			_poly(pen, PackedVector2Array([a0, mid, htip]), HORN[1])
	var skull := PackedVector2Array()
	for uv in [[-0.9, -0.75], [0.3, -0.85], [1.25, -0.42], [1.55, -0.18], [1.55, 0.18], [1.25, 0.42], [0.3, 0.85], [-0.9, 0.75], [-1.1, 0.0]]:
		skull.append(Vector2(hx + float(uv[0]) * hr, float(uv[1]) * hr))
	layered(pen, skull, BODY, Vector2(hx, 0), hr * 2.0)
	_poly(pen, PackedVector2Array([Vector2(hx + hr * 1.5, 0), Vector2(hx + hr * 0.2, -hr * 0.16), Vector2(hx - hr * 0.4, 0), Vector2(hx + hr * 0.2, hr * 0.16)]), PLATE[1])
	_circle(pen, Vector2(hx + hr * 1.3, -hr * 0.2), hr * 0.06, Color("1a0d0b"))
	_circle(pen, Vector2(hx + hr * 1.3, hr * 0.2), hr * 0.06, Color("1a0d0b"))
	for sd in [1.0, -1.0]:
		_poly(pen, PackedVector2Array([Vector2(hx - hr * 0.2, hr * 0.8 * sd), Vector2(hx - hr * 0.9, hr * 1.15 * sd), Vector2(hx - hr * 0.8, hr * 0.6 * sd)]), PLATE[0])
	var er := hr * (0.17 if kind != &"wyrm" else 0.24)
	var shut: bool = bool(opts.get("eyes_shut", false))
	for sd in [1.0, -1.0]:
		_circle(pen, Vector2(hx + hr * 0.35, hr * 0.48 * sd), er * 1.25, Color("160a08"))
		if shut:
			_line(pen, Vector2(hx + hr * 0.2, hr * 0.48 * sd), Vector2(hx + hr * 0.55, hr * 0.5 * sd), Color("2a0d0b"), er * 0.5)
		else:
			glow_eye(pen, Vector2(hx + hr * 0.4, hr * 0.48 * sd), er, opts.get("eye", EYE))
	if kind == &"ancient":
		_ancient_regalia(pen, hx, hr, R, t)
	var mouth: float = float(opts.get("mouth", 0.0))
	if mouth > 0.0 and mono.a <= 0.0:
		var m := Vector2(hx + hr * 1.6, 0)
		pen.draw_circle(m, hr * (0.6 + 0.9 * mouth), Color(BREATH, 0.12 + 0.18 * mouth))
		pen.draw_circle(m, hr * (0.3 + 0.45 * mouth), Color(BREATH, 0.35 + 0.35 * mouth))
		pen.draw_circle(m, hr * (0.12 + 0.2 * mouth), Color("FFE07A"))


## The Ancient Dragon is a king: gold-capped horns, a gold collar of plates
## and gems round its neck, and a spiked crown on its brow.
static func _ancient_regalia(pen: MeshBatch2D, hx: float, hr: float, R: float, t: float) -> void:
	var gold: Array[Color] = [Color("8A5A12"), Color("D99A26"), Color("FFD86A")]
	# collar where the neck meets the body
	var cx := 0.55 * R
	for i in range(9):
		var y := (float(i) - 4.0) * 0.045 * R
		var p := Vector2(cx + absf(float(i) - 4.0) * -0.01 * R, y)
		_poly(pen, PackedVector2Array([p + Vector2(-0.035 * R, 0), p + Vector2(0, -0.022 * R), p + Vector2(0.035 * R, 0), p + Vector2(0, 0.022 * R)]), gold[1])
	_circle(pen, Vector2(cx + 0.02 * R, 0), 0.03 * R, Color("E0304A"))
	# gold caps on the main horns
	for sd in [1.0, -1.0]:
		var base := Vector2(hx - 0.7 * hr, 0.75 * hr * sd)
		var tip := base + Vector2(-1.5 * hr, 0.6 * hr * sd)
		var cap := base.lerp(tip, 0.72)
		_poly(pen, PackedVector2Array([cap + Vector2(0, -0.12 * hr), tip, cap + Vector2(0.05 * hr, 0.12 * hr)]), gold[1])
		_line(pen, base.lerp(tip, 0.45) + Vector2(0, -0.12 * hr), base.lerp(tip, 0.45) + Vector2(0, 0.14 * hr), gold[2], 0.06 * hr)
	# the crown, sitting on the brow between the horns
	var c := Vector2(hx - 0.35 * hr, 0.0)
	var cr := 0.62 * hr
	var shine := 0.5 + 0.5 * sin(t * 2.0)
	if mono.a <= 0.0:
		pen.draw_circle(c, cr * 1.5, Color(1.0, 0.85, 0.4, 0.10 + 0.08 * shine))
	var spikes := PackedVector2Array()
	for i in range(14):
		var a := TAU * float(i) / 14.0
		spikes.append(c + Vector2.from_angle(a) * (cr * 1.32 if i % 2 == 0 else cr * 0.92))
	_poly(pen, spikes, gold[0])
	_poly(pen, _scaled(spikes, c, 0.86, Vector2(-0.04, -0.05) * cr), gold[1])
	_circle(pen, c, cr * 0.78, gold[0])
	_circle(pen, c - Vector2.ONE * cr * 0.06, cr * 0.66, gold[1])
	_circle(pen, c - Vector2.ONE * cr * 0.12, cr * 0.42, gold[2])
	for i in range(7):
		var a := TAU * float(i) / 7.0 + 0.2
		var g := c + Vector2.from_angle(a) * cr * 1.18
		_circle(pen, g, cr * 0.11, [Color("E0304A"), Color("4FD18A"), Color("5BA8F0")][i % 3])
	_circle(pen, c + Vector2(cr * 0.1, 0), cr * 0.22, Color("E0304A"))
	_circle(pen, c + Vector2(cr * 0.04, -cr * 0.06), cr * 0.08, Color(1, 1, 1, 0.8))


## Sleeping dragon curled in a ring on its throne, head resting in the middle.
static func coiled(pen: MeshBatch2D, Rc: float, t: float, eyes_open: bool = false) -> void:
	if mono.a <= 0.0:
		pen.draw_colored_polygon(ellipse(Vector2(Rc * 0.06, Rc * 0.1), Rc * 0.95, Rc * 0.9, 18), Color(0, 0, 0, 0.32))
	var n := 30
	var th0 := -2.3
	var th1 := 2.75
	var breathe := 1.0 + sin(t * 1.6) * 0.025
	var spine: Array = []
	for i in range(n + 1):
		var tt := float(i) / float(n)
		var th := th0 + tt * (th1 - th0)
		var r := Rc * (0.56 - 0.1 * tt) * breathe
		spine.append([Vector2(cos(th), sin(th)) * r, tt, th])
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var left2 := PackedVector2Array()
	var right2 := PackedVector2Array()
	for s in spine:
		var w := Rc * 0.3 * pow(1.0 - float(s[1]), 0.8) + Rc * 0.035
		var nv := Vector2(cos(float(s[2])), sin(float(s[2])))
		left.append((s[0] as Vector2) + nv * w)
		right.append((s[0] as Vector2) - nv * w)
		left2.append((s[0] as Vector2) + nv * w * 0.8)
		right2.append((s[0] as Vector2) - nv * w * 0.8)
	_strip(pen, left, right, BODY[0])
	_strip(pen, left2, right2, BODY[1], Vector2(-Rc * 0.025, -Rc * 0.035))
	# folded wings along the outside of the coil
	for rng_ in [[0.04, 0.4], [0.3, 0.62]]:
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for s in spine:
			var tt := float(s[1])
			if tt < float(rng_[0]) or tt > float(rng_[1]):
				continue
			var u := (tt - float(rng_[0])) / (float(rng_[1]) - float(rng_[0]))
			var w := Rc * 0.3 * pow(1.0 - tt, 0.8) + Rc * 0.035
			var bulge := Rc * (0.04 + 0.1 * sin(u * PI)) * (1.0 + 0.2 * sin(u * 9.0))
			var nv := Vector2(cos(float(s[2])), sin(float(s[2])))
			outer.append((s[0] as Vector2) + nv * (w * 0.8 + bulge))
			inner.append((s[0] as Vector2) - nv * w * 0.15)
		for i in range(outer.size() - 1):
			_poly(pen, PackedVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]]), WING[1])
		for i in range(outer.size() - 1):
			_line(pen, outer[i], outer[i + 1], BONE, Rc * 0.035)
		for j in range(1, outer.size() - 1, 3):
			_line(pen, inner[j], outer[j], Color(BONE, 0.8), Rc * 0.02)
	for i in range(6, spine.size(), 2):
		var p: Vector2 = spine[i][0]
		var th := float(spine[i][2])
		var w := Rc * 0.06 * (1.0 - float(spine[i][1]) * 0.8)
		var tv := Vector2(-sin(th), cos(th))
		var nv := Vector2(cos(th), sin(th))
		_poly(pen, PackedVector2Array([p + tv * w * 1.4, p + nv * w * 0.6, p - tv * w * 0.7, p - nv * w * 0.6]), SPIKE)
	var last: Array = spine[spine.size() - 1]
	var lp: Vector2 = last[0]
	var lth := float(last[2])
	var ltv := Vector2(-sin(lth), cos(lth))
	var lnv := Vector2(cos(lth), sin(lth))
	_poly(pen, PackedVector2Array([lp + ltv * Rc * 0.2, lp + lnv * Rc * 0.1, lp - ltv * Rc * 0.02, lp - lnv * Rc * 0.1]), PLATE[1])
	# neck into the middle, head resting there
	var p0: Vector2 = spine[0][0]
	var hc := Vector2(Rc * 0.02, Rc * 0.02)
	var hd := (hc - p0).angle() + 0.5
	var hr := Rc * 0.27
	var dirv := Vector2.from_angle(hd)
	_line(pen, p0, hc - dirv * hr * 0.6, BODY[0], Rc * 0.34)
	_line(pen, p0, hc - dirv * hr * 0.6, BODY[1], Rc * 0.24)
	var hp := func(u: float, v: float) -> Vector2:
		return hc + (Vector2(u, v) * hr).rotated(hd)
	for sd in [1.0, -1.0]:
		_poly(pen, PackedVector2Array([hp.call(-0.6, 0.6 * sd), hp.call(-1.5, 0.95 * sd), hp.call(-0.85, 0.3 * sd)]), HORN[1])
	var head := PackedVector2Array()
	for uv in [[-0.9, -0.75], [0.3, -0.85], [1.25, -0.42], [1.55, -0.18], [1.55, 0.18], [1.25, 0.42], [0.3, 0.85], [-0.9, 0.75], [-1.1, 0.0]]:
		head.append(hp.call(float(uv[0]), float(uv[1])))
	_poly(pen, head, BODY[0])
	_poly(pen, _scaled(head, Vector2.ZERO, 1.0, Vector2(-hr * 0.08, -hr * 0.1)), BODY[1])
	_poly(pen, PackedVector2Array([hp.call(1.5, 0), hp.call(0.2, -0.16), hp.call(-0.4, 0), hp.call(0.2, 0.16)]), PLATE[1])
	for sd in [1.0, -1.0]:
		var a: Vector2 = hp.call(0.2, 0.42 * sd)
		var b: Vector2 = hp.call(0.6, 0.5 * sd)
		if eyes_open:
			glow_eye(pen, (a + b) * 0.5, hr * 0.16, EYE)
		else:
			_line(pen, a, b, Color("2a0d0b"), hr * 0.11)
	if mono.a <= 0.0 and not eyes_open:
		var nose: Vector2 = hp.call(1.75, 0)
		for k in range(3):
			var phase := fmod(t * 0.6 + float(k) / 3.0, 1.0)
			pen.draw_circle(nose + dirv * phase * hr * 1.4 + Vector2(0, -phase * 10.0), hr * (0.12 + phase * 0.2), Color(0.81, 0.78, 0.72, 0.4 * (1.0 - phase)))


## Kobold miner-thief: candle helmet, pickaxe, a sack of stolen coins.
static func kobold(pen: MeshBatch2D, R: float, t: float) -> void:
	var step := sin(t * 12.0)
	if mono.a <= 0.0:
		pen.draw_colored_polygon(ellipse(Vector2(-0.05 * R, 0.1 * R), 0.85 * R, 0.7 * R, 14), SHADOW)
	var tail := _tail(R * 1.2, 0.9, 0.16, 0.5, 2.0 + step * 0.4, 10)
	_strip(pen, tail[1], tail[2], KOB[0])
	for sd in [1.0, -1.0]:
		var f := Vector2(0.05 * R + step * sd * 0.12 * R, 0.32 * R * sd)
		_line(pen, Vector2(-0.05 * R, 0.2 * R * sd), f, KOB[0], 0.14 * R)
	var sack := ellipse(Vector2(-0.45 * R, -0.05 * R), 0.38 * R, 0.34 * R, 9, 0.3, 4, 0.1)
	layered(pen, sack, KOB_GEAR, Vector2(-0.45 * R, -0.05 * R), R)
	_line(pen, Vector2(-0.2 * R, -0.25 * R), Vector2(-0.3 * R, 0.25 * R), Color("2a1d14"), 0.06 * R)
	_circle(pen, Vector2(-0.55 * R, -0.18 * R), 0.07 * R, Color("F2C65A"))
	_circle(pen, Vector2(-0.35 * R, -0.28 * R), 0.06 * R, Color("F2C65A"))
	_line(pen, Vector2(0.1 * R, 0.32 * R), Vector2(0.45 * R, 0.5 * R), KOB[0], 0.13 * R)
	_line(pen, Vector2(0.1 * R, -0.32 * R), Vector2(0.45 * R, -0.45 * R), KOB[0], 0.13 * R)
	_line(pen, Vector2(0.45 * R, -0.45 * R), Vector2(0.75 * R, 0.55 * R), Color("6A4A30"), 0.07 * R)
	_poly(pen, PackedVector2Array([Vector2(0.72, 0.55) * R, Vector2(1.05, 0.35) * R, Vector2(0.98, 0.5) * R, Vector2(0.75, 0.62) * R, Vector2(0.5, 0.78) * R, Vector2(0.55, 0.62) * R]), Color("B9B4AA"))
	layered(pen, ellipse(Vector2.ZERO, 0.38 * R, 0.42 * R, 9, 0.0, 2, 0.05), KOB, Vector2.ZERO, R)
	var hx := 0.45 * R
	var hr := 0.4 * R
	for sd in [1.0, -1.0]:
		_poly(pen, PackedVector2Array([Vector2(hx - hr * 0.3, hr * 0.6 * sd), Vector2(hx - hr * 1.3, hr * 1.25 * sd), Vector2(hx - hr * 0.8, hr * 0.4 * sd)]), KOB[2])
	var head := PackedVector2Array()
	for uv in [[-0.8, -0.8], [0.4, -0.7], [1.35, -0.25], [1.4, 0.25], [0.4, 0.7], [-0.8, 0.8], [-1.0, 0.0]]:
		head.append(Vector2(hx + float(uv[0]) * hr, float(uv[1]) * hr))
	layered(pen, head, KOB, Vector2(hx, 0), hr * 2.0)
	for sd in [1.0, -1.0]:
		glow_eye(pen, Vector2(hx + hr * 0.45, hr * 0.42 * sd), hr * 0.17, EYE)
	_circle(pen, Vector2(hx - hr * 0.2, 0), hr * 0.5, KOB_GEAR[1])
	_circle(pen, Vector2(hx - hr * 0.25, -hr * 0.05), hr * 0.32, KOB_GEAR[2])
	var cx := hx - hr * 0.25
	var flicker := 1.0 + sin(t * 23.0) * 0.12
	if mono.a <= 0.0:
		pen.draw_circle(Vector2(cx, 0), hr * 0.95 * flicker, Color(KOB_LIGHT, 0.13))
	_circle(pen, Vector2(cx, 0), hr * 0.2, Color("F5EEDC"))
	_poly(pen, PackedVector2Array([Vector2(cx + hr * 0.05, -hr * 0.12), Vector2(cx - hr * 0.55 * flicker, 0), Vector2(cx + hr * 0.05, hr * 0.12)]), Color("FF8A2A"))
	_poly(pen, PackedVector2Array([Vector2(cx + hr * 0.02, -hr * 0.07), Vector2(cx - hr * 0.35 * flicker, 0), Vector2(cx + hr * 0.02, hr * 0.07)]), Color("FFE070"))


## Lair lizard: low splayed quadruped with glowing fire-blisters on its back.
static func lizard(pen: MeshBatch2D, R: float, t: float) -> void:
	var step := sin(t * 9.0)
	if mono.a <= 0.0:
		pen.draw_colored_polygon(ellipse(Vector2(-0.3 * R, 0.1 * R), 1.3 * R, 0.6 * R, 16), SHADOW)
	var tail := _tail(R, 1.5, 0.16, 0.45, 1.2 + step * 0.35)
	_strip(pen, tail[1], tail[2], LIZ[0])
	var tail2 := _tail(R, 1.45, 0.1, 0.45, 1.2 + step * 0.35)
	_strip(pen, tail2[1], tail2[2], LIZ[1], Vector2(-1, -1))
	var legs := [[0.3, 0.25, 0.25, 0.4, 1.0], [0.3, -0.25, 0.25, -0.4, -1.0], [-0.35, 0.25, -0.15, 0.42, -1.0], [-0.35, -0.25, -0.15, -0.42, 1.0]]
	for leg in legs:
		var swing := step * float(leg[4]) * 0.12
		var a := Vector2(float(leg[0]) * R, float(leg[1]) * R)
		var k := a + Vector2(float(leg[2]) * R * 0.4 + 0.04 * R + swing * R, float(leg[3]) * R * 0.75)
		var f := k + Vector2((0.14 if float(leg[0]) > 0.0 else -0.1) * R + swing * R, (0.05 if float(leg[3]) > 0.0 else -0.05) * R)
		_line(pen, a, k, LIZ[0], 0.17 * R)
		_line(pen, k, f, LIZ[0], 0.13 * R)
		_circle(pen, k, 0.07 * R, LIZ[1])
		var fw := 0.0 if float(leg[0]) > 0.0 else PI
		for cl in [-0.6, 0.0, 0.6]:
			_circle(pen, f + Vector2.from_angle(fw + cl) * 0.08 * R, 0.025 * R, HORN[2])
	layered(pen, ellipse(Vector2.ZERO, 0.6 * R, 0.3 * R, 12, 0.0, 8, 0.03), LIZ, Vector2.ZERO, R)
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	for i in range(5):
		var x := 0.38 * R - float(i) * 0.18 * R
		if mono.a <= 0.0:
			pen.draw_circle(Vector2(x, 0), 0.1 * R * (1.0 + 0.2 * pulse), Color(LIZ_GEM, 0.25))
		_circle(pen, Vector2(x, 0), 0.05 * R, LIZ_GEM)
	var hx := 0.75 * R
	var hr := 0.2 * R
	var head := PackedVector2Array()
	for uv in [[-1.2, -0.8], [0.6, -0.7], [1.6, -0.2], [1.6, 0.2], [0.6, 0.7], [-1.2, 0.8]]:
		head.append(Vector2(hx + float(uv[0]) * hr, float(uv[1]) * hr))
	layered(pen, head, LIZ, Vector2(hx, 0), hr * 2.0)
	for sd in [1.0, -1.0]:
		glow_eye(pen, Vector2(hx + hr * 0.3, hr * 0.55 * sd), hr * 0.2, EYE)
	if fmod(t, 1.6) < 0.35:
		var tg := Color("E0506A")
		_line(pen, Vector2(hx + hr * 1.6, 0), Vector2(hx + hr * 2.3, 0), tg, hr * 0.12)
		_line(pen, Vector2(hx + hr * 2.3, 0), Vector2(hx + hr * 2.6, hr * 0.2), tg, hr * 0.09)
		_line(pen, Vector2(hx + hr * 2.3, 0), Vector2(hx + hr * 2.6, -hr * 0.2), tg, hr * 0.09)


# ------------------------------------------------------------------ treasure

const GOLD: Array[Color] = [Color("7A4E10"), Color("B07A1A"), Color("D99A26"), Color("F2C14A"), Color("FFE9A0")]
const GEMS: Array[Color] = [Color("E0304A"), Color("4FD18A"), Color("5BA8F0"), Color("B98CFF"), Color("F2F2F2")]


static func coin(pen: MeshBatch2D, p: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	pen.draw_colored_polygon(ellipse(p, r, r * 0.78, 7, rng.randf() * PI), GOLD[2 + rng.randi() % 2])
	if r > 2.6:
		pen.draw_circle(p - Vector2.ONE * r * 0.25, r * 0.35, GOLD[4])


static func sparkle(pen: MeshBatch2D, p: Vector2, k: float) -> void:
	pen.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -k), p + Vector2(k * 0.22, -k * 0.22), p + Vector2(k, 0), p + Vector2(k * 0.22, k * 0.22),
		p + Vector2(0, k), p + Vector2(-k * 0.22, k * 0.22), p + Vector2(-k, 0), p + Vector2(-k * 0.22, -k * 0.22)]), Color("FFF6CF"))


static func gem(pen: MeshBatch2D, p: Vector2, s: float, color: Color) -> void:
	pen.draw_colored_polygon(PackedVector2Array([p + Vector2(1, 2 - s), p + Vector2(s + 1, 2), p + Vector2(1, s + 2), p + Vector2(1 - s, 2)]), Color(0, 0, 0, 0.3))
	pen.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)]), color)
	pen.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p]), Color(1, 1, 1, 0.45))


## An irregular heap of gold: several overlapping lumps (never one clean oval),
## coins spilling off its edges, gems and treasure poking out.
static func gold_mound(pen: MeshBatch2D, c: Vector2, radius: float, seed_value: int, items: int = 2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var lumps: Array = []
	var count := 3 + int(radius / 22.0)
	for i in range(count):
		var a := rng.randf() * TAU
		var d := radius * 0.55 * sqrt(rng.randf()) if i > 0 else 0.0
		var r := radius * rng.randf_range(0.32, 0.55) * (1.25 if i == 0 else 1.0)
		lumps.append([c + Vector2(cos(a), sin(a) * 0.8) * d, r, rng.randi()])
	# shadow, then three tiers lit from the top-left
	for lump in lumps:
		pen.draw_colored_polygon(ellipse((lump[0] as Vector2) + Vector2(5, 7), float(lump[1]) * 1.05, float(lump[1]) * 0.85, 11, 0.0, int(lump[2]), 0.18), Color(0, 0, 0, 0.22))
	for tier in range(3):
		var k: float = [1.0, 0.78, 0.45][tier]
		var o: Vector2 = [Vector2.ZERO, Vector2(-2, -3), Vector2(-5, -7)][tier]
		for lump in lumps:
			var r := float(lump[1])
			pen.draw_colored_polygon(ellipse((lump[0] as Vector2) + o * r / 30.0, r * k, r * k * 0.8, 11, float(int(lump[2]) % 7), int(lump[2]) + tier, 0.22), GOLD[tier + 1] if tier > 0 else GOLD[0])
	# coins on the heap and spilled around it
	for i in range(int(radius * radius / 45.0) + 8):
		var a := rng.randf() * TAU
		var d := radius * pow(rng.randf(), 0.7) * 1.05
		coin(pen, c + Vector2(cos(a), sin(a) * 0.8) * d, rng.randf_range(2.0, 4.0), rng)
	for i in range(int(radius * 0.9) + 6):
		var a := rng.randf() * TAU
		var d := radius * rng.randf_range(0.95, 1.7)
		coin(pen, c + Vector2(cos(a), sin(a) * 0.8) * d, rng.randf_range(1.8, 3.4), rng)
	for i in range(int(radius / 16.0) + 1):
		var a := rng.randf() * TAU
		var d := radius * 0.7 * sqrt(rng.randf())
		gem(pen, c + Vector2(cos(a), sin(a) * 0.8) * d, rng.randf_range(3.0, 5.5), GEMS[rng.randi() % GEMS.size()])
	for i in range(items):
		var a := rng.randf() * TAU
		var d := radius * rng.randf_range(0.15, 0.75)
		treasure(pen, rng.randi() % 8, c + Vector2(cos(a), sin(a) * 0.8) * d, rng.randf() * TAU, rng.randf_range(0.85, 1.2))
	for i in range(int(radius / 30.0) + 1):
		sparkle(pen, c + Vector2.from_angle(rng.randf() * TAU) * radius * 0.5 * rng.randf(), rng.randf_range(3.0, 6.0))
	pen.draw_set_transform(Vector2.ZERO)


## A dragon egg sitting in the middle of a hoard (red, gold scale flecks).
static func egg(pen: MeshBatch2D, c: Vector2, size: float, t: float = 0.0) -> void:
	var glow := 0.5 + 0.5 * sin(t * 1.8)
	pen.draw_circle(c, size * (1.9 + 0.15 * glow), Color(1.0, 0.45, 0.15, 0.10 + 0.06 * glow))
	pen.draw_colored_polygon(ellipse(c + Vector2(4, 6), size * 1.05, size * 0.75, 18), Color(0, 0, 0, 0.35))
	pen.draw_colored_polygon(ellipse(c, size * 1.15, size * 0.92, 18, 0.0, 1, 0.12), GOLD[1])
	pen.draw_colored_polygon(ellipse(c, size * 0.8, size * 1.0, 20, 0.35), Color("6E1612"))
	pen.draw_colored_polygon(ellipse(c - Vector2(size * 0.08, size * 0.1), size * 0.66, size * 0.86, 20, 0.35), Color("A82A1E"))
	pen.draw_colored_polygon(ellipse(c - Vector2(size * 0.2, size * 0.28), size * 0.3, size * 0.42, 14, 0.35), Color("D9502E"))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(size * 13.0)
	for i in range(9):
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * size * 0.65
		var p := c + Vector2(cos(a) * 0.8, sin(a)).rotated(0.35) * d
		pen.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 0), p + Vector2(0, -2.5), p + Vector2(3, 0)]), Color("F2C14A"))
	pen.draw_circle(c - Vector2(size * 0.3, size * 0.45), size * 0.12, Color(1, 1, 1, 0.55))


## Treasure poking out of the gold. kind: 0 goblet, 1 crown, 2 sword,
## 3 shield, 4 helmet, 5 small chest, 6 candlestick, 7 necklace.
static func treasure(pen: MeshBatch2D, kind: int, c: Vector2, rot: float, k: float) -> void:
	pen.draw_set_transform(c, rot, Vector2.ONE * k)
	match kind:
		0:
			pen.draw_circle(Vector2(2, 3), 7, Color(0, 0, 0, 0.3))
			pen.draw_circle(Vector2.ZERO, 7, Color("B07A1A"))
			pen.draw_circle(Vector2.ZERO, 5, GOLD[3])
			pen.draw_circle(Vector2.ZERO, 3.2, Color("7A1A2A"))
		1:
			var points := PackedVector2Array()
			for i in range(10):
				points.append(Vector2.from_angle(i * PI / 5.0) * (10.0 if i % 2 == 0 else 6.5))
			pen.draw_colored_polygon(points, Color("D9A441"))
			pen.draw_circle(Vector2.ZERO, 5.5, Color("2a1a10"))
			pen.draw_circle(Vector2(6, 0), 2.2, GEMS[0])
			pen.draw_circle(Vector2(-6, 0), 2.2, GEMS[2])
		2:
			pen.draw_colored_polygon(PackedVector2Array([Vector2(4, 2), Vector2(42, 2), Vector2(48, 0), Vector2(42, -2), Vector2(4, -2)]), Color("C9CED6"))
			pen.draw_rect(Rect2(Vector2(4, -2), Vector2(38, 2)), Color("EEF2F6"))
			pen.draw_rect(Rect2(Vector2(0, -7), Vector2(4, 14)), Color("D9A441"))
			pen.draw_rect(Rect2(Vector2(-11, -2), Vector2(11, 4)), Color("5A3420"))
			pen.draw_circle(Vector2(-12, 0), 3.0, GEMS[0])
		3:
			pen.draw_colored_polygon(ellipse(Vector2(2, 3), 13, 15, 16), Color(0, 0, 0, 0.3))
			pen.draw_colored_polygon(ellipse(Vector2.ZERO, 13, 15, 16), Color("8A6A2E"))
			pen.draw_colored_polygon(ellipse(Vector2.ZERO, 10, 12, 16), Color("3F5E8A"))
			pen.draw_rect(Rect2(Vector2(-2, -12), Vector2(4, 24)), Color("D9A441"))
			pen.draw_rect(Rect2(Vector2(-10, -2), Vector2(20, 4)), Color("D9A441"))
		4:
			pen.draw_circle(Vector2(2, 3), 10, Color(0, 0, 0, 0.3))
			pen.draw_circle(Vector2.ZERO, 10, Color("8E8A80"))
			pen.draw_circle(Vector2(-2, -2), 7, Color("B9B4AA"))
			pen.draw_rect(Rect2(Vector2(-1.5, -10), Vector2(3, 20)), Color("5E5A52"))
			pen.draw_colored_polygon(PackedVector2Array([Vector2(-8, -6), Vector2(-18, -12), Vector2(-10, -2)]), Color("E8E0CF"))
			pen.draw_colored_polygon(PackedVector2Array([Vector2(-8, 6), Vector2(-18, 12), Vector2(-10, 2)]), Color("E8E0CF"))
		5:
			pen.draw_rect(Rect2(Vector2(-12, -8) + Vector2(2, 3), Vector2(24, 16)), Color(0, 0, 0, 0.3))
			pen.draw_rect(Rect2(Vector2(-12, -8), Vector2(24, 16)), Color("5A3420"))
			pen.draw_rect(Rect2(Vector2(-10, -6), Vector2(20, 12)), GOLD[2])
			pen.draw_rect(Rect2(Vector2(-12, -14), Vector2(24, 6)), Color("7A4A2C"))
			for x in [-7.0, 5.0]:
				pen.draw_rect(Rect2(Vector2(x, -8), Vector2(3, 16)), Color("D9A441"))
		6:
			pen.draw_circle(Vector2(1, 2), 7, Color(0, 0, 0, 0.3))
			pen.draw_circle(Vector2.ZERO, 7, Color("C9922E"))
			for i in range(3):
				var p := Vector2.from_angle(i * TAU / 3.0) * 6.0
				pen.draw_circle(p, 3.0, Color("EDE3CF"))
		_:
			var chain := PackedVector2Array()
			for i in range(9):
				chain.append(Vector2.from_angle(PI * 0.15 + i * PI * 0.2) * Vector2(14, 10))
			pen.draw_polyline(chain, Color("F2C14A"), 2.0)
			pen.draw_circle(Vector2(0, 10), 4.0, GEMS[1])
	pen.draw_set_transform(Vector2.ZERO)
