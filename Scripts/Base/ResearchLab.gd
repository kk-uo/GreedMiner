class_name ResearchLab
extends Node2D

## Research lab (style A, code-drawn): a long curved research bench that
## follows the hall wall around the top-left corner (user pick). Along it,
## from the lower end up: a lava smelter pouring onto a curved conveyor belt,
## a power hammer on a gantry over the belt (slams every PRESS_TIME seconds),
## an alchemy station with bubbling flasks, a chip-lab console, and a crystal
## rack at the top end. Copper pipes run along the wall behind it; an anvil
## and the dwarf scientist (LabScientist) stand on the floor in front.
## The node sits at AsteroidHangar.LAB_CENTER (scaled by LAB_SCALE *
## LAYOUT_SCALE); the bench path is built from AsteroidHangar.HALL.
## Presentation only: AsteroidHangar owns the hotspot (contains_local()) and
## BaseMain decides what a click does.

## Bench width (local units) and how far its centre line sits inside the
## hall wall (mock px); the bench runs between BENCH_FROM and BENCH_TO (mock).
const BENCH_WIDTH: float = 58.0
const BENCH_INSET: float = 26.0
const BENCH_FROM := Vector2(176.0, 365.0)
const BENCH_TO := Vector2(475.0, 104.0)
## Seconds per hammer stroke.
const PRESS_TIME: float = 1.6

const LAVA_DARK := Color("5A1A0C")
const LAVA := Color("B83A16")
const LAVA_MID := Color("F06A1E")
const LAVA_HOT := Color("FFB347")
const LAVA_WHITE := Color("FFE7A3")
const IRON := Color("2B2D31")
const IRON_MID := Color("45484E")
const IRON_LIGHT := Color("8E939A")
const STONE_DARK := Color("4A3B2F")
const STONE := Color("6E5D4F")
const BELT := Color("24201C")
const WOOD := Color("8A5A34")

const BRASS: Array[Color] = [Color("7A5A2A"), Color("B88A3E"), Color("E8C27A")]
const COPPER := Color("A8643A")
## Warm worktop so the bench sits in the hall's brown palette.
const TOP_DARK := Color("4E3B2E")
const TOP := Color("6E5642")
const TOP_LIGHT := Color("8C705A")
const COPPER_LIGHT := Color("D99A6A")

var hovered: bool = false:
	set(value):
		hovered = value
		queue_redraw()

var _time: float = 0.0
var _scientist: LabScientist
## Bench centre line, local space, evenly spaced points.
var _path := PackedVector2Array()


func _ready() -> void:
	_path = bench_path_local()
	_scientist = LabScientist.new()
	var at := _frame(0.6)
	_scientist.position = at[0] + at[2] * (BENCH_WIDTH * 0.5 + 26.0)
	_scientist.base_facing = (-at[2]).angle()
	add_child(_scientist)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Hit test in this node's local space: on (or just in front of) the bench.
func contains_local(point: Vector2) -> bool:
	for index in range(_path.size() - 1):
		if Geometry2D.get_closest_point_to_segment(point, _path[index], _path[index + 1]).distance_to(point) <= BENCH_WIDTH * 0.5 + 14.0:
			return true
	return false


## 0..1 position inside the current hammer stroke.
func _stroke() -> float:
	return fposmod(_time, PRESS_TIME) / PRESS_TIME


## Hammer height: 1 = raised (drawn bigger, long shadow), 0 = down on the belt.
static func hammer_lift(k: float) -> float:
	if k < 0.55:
		return 1.0
	if k < 0.62:
		return 1.0 - (k - 0.55) / 0.07
	if k < 0.72:
		return 0.0
	return smoothstep(0.72, 1.0, k)


## Everything below records into one shared batch and is submitted as a
## single draw command per frame.
static var _BATCH := MeshBatch2D.new()
var _pen: Object = self

func _draw() -> void:
	_pen = _BATCH
	_paint()
	_BATCH.flush_to(self)
	_pen = self


func _paint() -> void:
	if _path.size() < 2:
		return
	var w := BENCH_WIDTH
	_glow_on_floor()
	_draw_pipes()
	# Bench: shadow, stone base, iron top with a lit front lip and seams.
	_pen.draw_colored_polygon(_band(-w * 0.5, w * 0.5 + 6.0, Vector2(8.0, 10.0)), Palette.SHADOW_COLOR)
	_pen.draw_colored_polygon(_band(-w * 0.5, w * 0.5 + 4.0), STONE_DARK)
	_pen.draw_colored_polygon(_band(-w * 0.5 + 3.0, w * 0.5), TOP_DARK)
	_pen.draw_colored_polygon(_band(-w * 0.5 + 6.0, w * 0.5 - 4.0), TOP)
	_pen.draw_polyline(_offset_line(-w * 0.5 + 8.0), TOP_LIGHT, 2.0)
	_pen.draw_polyline(_offset_line(w * 0.5 - 1.5), BRASS[1], 3.0)
	_pen.draw_polyline(_offset_line(w * 0.5 - 3.0), BRASS[2], 1.0)
	var seams := 9
	for k in range(1, seams):
		var f := _frame(float(k) / float(seams))
		_pen.draw_line(f[0] - f[2] * (w * 0.5 - 6.0), f[0] + f[2] * (w * 0.5 - 4.0), IRON, 1.5)
		_pen.draw_circle(f[0] + f[2] * (w * 0.5 - 1.5), 2.0, BRASS[2])

	_draw_curved_belt(0.1, 0.46)
	_draw_bench_smelter(0.06)
	_draw_bench_press(0.3)
	_draw_flasks(0.58)
	_draw_bench_console(0.73)
	_draw_crystal_rack(0.9)
	var anvil := _frame(0.36)
	_draw_anvil(anvil[0] + anvil[2] * (w * 0.5 + 34.0))

	if hovered:
		var outline := _band(-w * 0.5 - 10.0, w * 0.5 + 14.0)
		outline.append(outline[0])
		Palette.draw_hover_outline(_pen, outline, 4.0)


func _draw_console(at: Vector2) -> void:
	Palette.draw_rounded_rect(_pen, Rect2(at, Vector2(44.0, 22.0)), 4.0, ShipHullVisual.FRAME_RIM)
	Palette.draw_rounded_rect(_pen, Rect2(at + Vector2(2.0, 2.0), Vector2(40.0, 18.0)), 3.0, Palette.UI_PANEL)
	var colors := [Palette.ACCENT, Palette.COBALT, Palette.ACCENT, Palette.COBALT]
	for k in range(colors.size()):
		var on := fmod(_time * 1.6 - float(k) * 0.25, 1.6) < 1.0
		Palette.draw_rounded_rect(_pen, Rect2(at + Vector2(5.0 + float(k) * 9.0, 5.0), Vector2(5.0, 3.5)), 1.0, colors[k] if on else Palette.MECH_LIGHT)
	var fill := 4.0 + 28.0 * (0.5 + 0.5 * sin(_time * 1.3))
	Palette.draw_rounded_rect(_pen, Rect2(at + Vector2(5.0, 13.0), Vector2(fill, 4.0)), 1.5, Palette.COBALT)


## Anvil on the ground in front of the bench, with a hammer leaning on it.
func _draw_anvil(at: Vector2) -> void:
	var shape := [Vector2(-24, -9), Vector2(14, -9), Vector2(30, -3), Vector2(14, 3), Vector2(14, 9), Vector2(-24, 9)]
	var shadow := PackedVector2Array()
	var body := PackedVector2Array()
	for point in shape:
		shadow.append(at + point + Vector2(4.0, 6.0))
		body.append(at + point)
	_pen.draw_colored_polygon(shadow, Palette.SHADOW_COLOR)
	_pen.draw_colored_polygon(body, IRON)
	_pen.draw_colored_polygon(PackedVector2Array([at + Vector2(-22, -7), at + Vector2(13, -7), at + Vector2(26, -3), at + Vector2(13, 1), at + Vector2(-22, 1)]), IRON_MID)
	_pen.draw_colored_polygon(PackedVector2Array([at + Vector2(-21, -6), at + Vector2(4, -6), at + Vector2(1, -3), at + Vector2(-21, -3)]), Color(IRON_LIGHT, 0.7))
	_pen.draw_rect(Rect2(at + Vector2(-9.0, 3.0), Vector2(12.0, 10.0)), IRON)
	# Hammer leaning against it.
	_pen.draw_set_transform(at + Vector2(38.0, 6.0), deg_to_rad(-35.0), Vector2.ONE)
	_pen.draw_rect(Rect2(-1.8, -2.0, 3.6, 24.0), WOOD)
	Palette.draw_rounded_rect(_pen, Rect2(-8.0, -9.0, 16.0, 9.0), 1.5, IRON)
	Palette.draw_rounded_rect(_pen, Rect2(-7.0, -8.0, 14.0, 5.0), 1.0, IRON_LIGHT)
	_pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ==========================================
# Bench geometry
# ==========================================

## The bench centre line in mock coordinates: the hall outline pushed in by
## BENCH_INSET (rounded joins), from BENCH_FROM to BENCH_TO, smoothed and
## resampled every 4 mock px.
static func bench_path_mock() -> PackedVector2Array:
	var insets := Geometry2D.offset_polygon(PackedVector2Array(AsteroidHangar.HALL), -BENCH_INSET, Geometry2D.JOIN_ROUND)
	if insets.is_empty():
		return PackedVector2Array()
	var ring: PackedVector2Array = insets[0]
	var start := _nearest_index(ring, BENCH_FROM)
	var end := _nearest_index(ring, BENCH_TO)
	var raw := PackedVector2Array()
	# Walk the shorter way round from start to end.
	var forward := (end - start + ring.size()) % ring.size()
	var step := 1 if forward <= ring.size() / 2 else -1
	var index := start
	raw.append(ring[index])
	while index != end:
		index = (index + step + ring.size()) % ring.size()
		raw.append(ring[index])
	# Chaikin smoothing, then even spacing.
	for pass_index in range(3):
		var smooth := PackedVector2Array([raw[0]])
		for k in range(raw.size() - 1):
			smooth.append(raw[k].lerp(raw[k + 1], 0.25))
			smooth.append(raw[k].lerp(raw[k + 1], 0.75))
		smooth.append(raw[raw.size() - 1])
		raw = smooth
	var even := PackedVector2Array([raw[0]])
	var carry := 0.0
	for k in range(raw.size() - 1):
		var a := raw[k]
		var b := raw[k + 1]
		var length := a.distance_to(b)
		var t := 4.0 - carry
		while t <= length:
			even.append(a.lerp(b, t / length))
			t += 4.0
		carry = length - (t - 4.0)
	return even


static func _nearest_index(points: PackedVector2Array, target: Vector2) -> int:
	var best := 0
	for index in range(points.size()):
		if points[index].distance_to(target) < points[best].distance_to(target):
			best = index
	return best


## The path in this node's local space (node at LAB_CENTER, scale LAB_SCALE).
static func bench_path_local() -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in bench_path_mock():
		out.append((p - AsteroidHangar.LAB_CENTER) / AsteroidHangar.LAB_SCALE)
	return out


## Mock point in the middle of the bench (hotspot centre for tutorials).
static func center_mock_point() -> Vector2:
	var path := bench_path_mock()
	return path[path.size() / 2] if path.size() > 0 else AsteroidHangar.LAB_CENTER


## Mock point for the "LAB" name tag: in front of the middle of the bench.
static func tag_mock_point() -> Vector2:
	var path := bench_path_mock()
	if path.size() < 2:
		return AsteroidHangar.LAB_CENTER
	var index := path.size() / 2
	var tangent := (path[mini(index + 1, path.size() - 1)] - path[index - 1]).normalized()
	var normal := tangent.orthogonal()
	if normal.dot(Vector2(640.0, 360.0) - path[index]) < 0.0:
		normal = -normal
	return path[index] + normal * 46.0


## Obstacles for the base crew (mock): circles along the bench.
static func obstacle_circles_mock() -> Array:
	var result := []
	var path := bench_path_mock()
	for index in range(0, path.size(), 8):
		result.append([path[index], BENCH_WIDTH * AsteroidHangar.LAB_SCALE * 0.5 + 10.0])
	return result


## [point, tangent, floor normal] at fraction f (0..1) along the bench.
func _frame(f: float) -> Array:
	var count := _path.size()
	var i := clampi(int(round(f * float(count - 1))), 0, count - 1)
	var a := _path[maxi(i - 1, 0)]
	var b := _path[mini(i + 1, count - 1)]
	var tangent := (b - a).normalized()
	var normal := tangent.orthogonal()
	var hall_center := (Vector2(640.0, 360.0) - AsteroidHangar.LAB_CENTER) / AsteroidHangar.LAB_SCALE
	if normal.dot(hall_center - _path[i]) < 0.0:
		normal = -normal
	return [_path[i], tangent, normal]


## Polygon of the strip between offsets `inner` and `outer` (toward the floor).
func _band(inner: float, outer: float, shift: Vector2 = Vector2.ZERO, from_f: float = 0.0, to_f: float = 1.0) -> PackedVector2Array:
	var front := PackedVector2Array()
	var back := PackedVector2Array()
	var count := _path.size()
	var first := int(from_f * float(count - 1))
	var last := int(to_f * float(count - 1))
	for i in range(first, last + 1):
		var f := _frame(float(i) / float(count - 1))
		back.append(f[0] + f[2] * inner + shift)
		front.append(f[0] + f[2] * outer + shift)
	front.reverse()
	back.append_array(front)
	return back


func _offset_line(offset: float, from_f: float = 0.0, to_f: float = 1.0) -> PackedVector2Array:
	var line := PackedVector2Array()
	var count := _path.size()
	for i in range(int(from_f * float(count - 1)), int(to_f * float(count - 1)) + 1):
		var f := _frame(float(i) / float(count - 1))
		line.append(f[0] + f[2] * offset)
	return line


# ==========================================
# Stations
# ==========================================

func _glow_on_floor() -> void:
	var f := _frame(0.08)
	for k in range(4):
		_pen.draw_circle(f[0] + f[2] * 40.0, 110.0 - 22.0 * float(k), Color(LAVA_MID, 0.045))


## Copper pipes along the wall behind the bench, with brackets.
func _draw_pipes() -> void:
	var w := BENCH_WIDTH
	for k in range(2):
		var line := _offset_line(-w * 0.5 - 5.0 - float(k) * 7.0)
		_pen.draw_polyline(line, COPPER, 4.0)
		_pen.draw_polyline(Palette.offset_points(line, Vector2(-0.8, -0.8)), COPPER_LIGHT, 1.2)
	for k in range(1, 12):
		var f := _frame(float(k) / 12.0)
		_pen.draw_line(f[0] - f[2] * (w * 0.5 + 2.0), f[0] - f[2] * (w * 0.5 + 16.0), IRON, 3.0)


func _draw_curved_belt(from_f: float, to_f: float) -> void:
	_pen.draw_colored_polygon(_band(-11.0, 11.0, Vector2.ZERO, from_f, to_f), IRON)
	_pen.draw_colored_polygon(_band(-8.0, 8.0, Vector2.ZERO, from_f, to_f), BELT)
	var count := _path.size()
	var first := int(from_f * float(count - 1))
	var last := int(to_f * float(count - 1))
	var shift := int(_time * 6.0) % 2
	for i in range(first + shift, last, 2):
		var f := _frame(float(i) / float(count - 1))
		_pen.draw_line(f[0] - f[2] * 6.0, f[0] + f[2] * 6.0, IRON_MID, 2.0)
	# Glowing ingots riding toward the hammer, cooled ones after it.
	for k in range(4):
		var u := fposmod(_time * 0.06 + float(k) * 0.25, 1.0)
		var f := _frame(lerpf(from_f, to_f, u))
		var hot := u < 0.55
		_pen.draw_set_transform(f[0], f[1].angle(), Vector2.ONE)
		Palette.draw_rounded_rect(_pen, Rect2(-7, -4, 14, 8), 2.0, LAVA_MID if hot else Palette.GOLD)
		Palette.draw_rounded_rect(_pen, Rect2(-6, -3.5, 7, 3), 1.0, LAVA_WHITE if hot else Palette.GOLD_LIGHT)
		_pen.draw_set_transform(Vector2.ZERO)


func _draw_bench_smelter(at_f: float) -> void:
	var f := _frame(at_f)
	var c: Vector2 = f[0] - f[2] * 4.0
	var r := 28.0
	_pen.draw_circle(c + Vector2(4, 6), r + 8.0, Palette.SHADOW_COLOR)
	_pen.draw_circle(c, r + 8.0, STONE_DARK)
	_pen.draw_circle(c + Vector2(-1.5, -1.5), r + 4.0, STONE)
	_pen.draw_circle(c, r, LAVA)
	_pen.draw_circle(c, r * (0.62 + 0.16 * (0.5 + 0.5 * sin(_time * 3.5))), LAVA_MID)
	_pen.draw_circle(c + Vector2(-r * 0.3, -r * 0.25), r * 0.3, Color(LAVA_WHITE, 0.55 + 0.4 * sin(_time * 5.0)))
	# Spout onto the start of the belt.
	var to: Vector2 = _frame(0.12)[0]
	_pen.draw_line(c, to, LAVA_DARK, 7.0)
	_pen.draw_line(c, to, LAVA_MID, 4.0)


func _draw_bench_press(at_f: float) -> void:
	var f := _frame(at_f)
	var c: Vector2 = f[0]
	_pen.draw_set_transform(c, f[1].angle() + PI * 0.5, Vector2.ONE)
	# Gantry posts either side of the belt, crossbeam over it.
	for x in [-30.0, 22.0]:
		Palette.draw_rounded_rect(_pen, Rect2(Vector2(x, -26.0), Vector2(9.0, 52.0)), 3.0, ShipHullVisual.POD_BAND)
	Palette.draw_rounded_rect(_pen, Rect2(Vector2(-32.0, -30.0), Vector2(64.0, 10.0)), 3.0, ShipHullVisual.FRAME_IRON)
	var k := _stroke()
	var lift := hammer_lift(k)
	var head := Vector2(36.0, 30.0) * lerpf(0.97, 1.2, lift)
	var shadow := lerpf(3.0, 12.0, lift)
	_pen.draw_rect(Rect2(-head * 0.5 + Vector2(shadow, shadow), head), Color(0, 0, 0, 0.3))
	Palette.draw_rounded_rect(_pen, Rect2(-head * 0.5, head), 5.0, IRON)
	Palette.draw_rounded_rect(_pen, Rect2(-head * 0.5 + Vector2(3, 3), head - Vector2(6, 8)), 4.0, IRON_MID)
	_pen.draw_circle(Vector2.ZERO, 3.0, Palette.ACCENT)
	if k >= 0.6 and k < 0.82:
		var t := (k - 0.6) / 0.22
		_pen.draw_arc(Vector2.ZERO, lerpf(14.0, 30.0, t), 0.0, TAU, 28, Color(LAVA_WHITE, 0.9 * (1.0 - t)), 3.0 * (1.0 - t) + 0.5)
		for index in range(8):
			var a := TAU * float(index) / 8.0 + 0.3
			var dir := Vector2(cos(a), sin(a))
			_pen.draw_line(dir * lerpf(14.0, 20.0, t), dir * lerpf(20.0, 30.0, t), Color(LAVA_HOT if index % 2 == 0 else LAVA_WHITE, 1.0 - t), 2.0)
	_pen.draw_set_transform(Vector2.ZERO)


## Alchemy: three flasks bubbling in different colours, linked by glass tubes.
func _draw_flasks(at_f: float) -> void:
	var colors := [Palette.COBALT, Color("6BE04A"), Color("C4A0FF")]
	var spots := [-0.035, 0.0, 0.035]
	var prev := Vector2.ZERO
	for k in range(3):
		var f := _frame(at_f + spots[k])
		var p: Vector2 = f[0] + f[2] * 2.0
		var r := 10.5 if k == 1 else 8.5
		if k > 0:
			_pen.draw_line(prev, p, Color(1, 1, 1, 0.35), 2.0)
		_pen.draw_circle(p + Vector2(2, 3), r, Palette.SHADOW_COLOR)
		_pen.draw_circle(p, r, Color(0.85, 0.92, 1.0, 0.55))
		_pen.draw_circle(p + Vector2(0, r * 0.2), r * 0.72, colors[k])
		_pen.draw_circle(p + Vector2(-r * 0.35, -r * 0.35), r * 0.22, Color(1, 1, 1, 0.8))
		var ph := fposmod(_time * 1.2 + float(k) * 0.37, 1.0)
		_pen.draw_circle(p + Vector2(0, -r * ph * 1.6), 1.6 * (1.0 - ph), Color(colors[k].lightened(0.5), 1.0 - ph))
		prev = p


## Chip-lab console: two screens and a row of blinking keys.
func _draw_bench_console(at_f: float) -> void:
	var f := _frame(at_f)
	_pen.draw_set_transform(f[0], f[1].angle(), Vector2.ONE * 1.3)
	Palette.draw_rounded_rect(_pen, Rect2(-30, -16, 60, 28), 4.0, ShipHullVisual.FRAME_RIM)
	for x in [-26.0, 2.0]:
		Palette.draw_rounded_rect(_pen, Rect2(x, -13, 24, 14), 2.0, Palette.UI_PANEL)
		var fill := 4.0 + 16.0 * (0.5 + 0.5 * sin(_time * 1.3 + x))
		Palette.draw_rounded_rect(_pen, Rect2(x + 3, -4, fill, 3), 1.0, Palette.COBALT)
		_pen.draw_line(Vector2(x + 3, -9), Vector2(x + 14, -9), Color(Palette.COBALT_LIGHT, 0.7), 1.0)
	var keys := [Palette.ACCENT, Palette.COBALT, Palette.GOLD, Palette.ACCENT, Palette.COBALT]
	for k in range(keys.size()):
		var on := fmod(_time * 1.6 - float(k) * 0.2, 1.6) < 1.0
		Palette.draw_rounded_rect(_pen, Rect2(-24 + float(k) * 10.0, 4, 7, 4), 1.0, keys[k] if on else Palette.MECH_LIGHT)
	_pen.draw_set_transform(Vector2.ZERO)


## Crystal rack at the top end: blue, gold and red samples on a shelf.
func _draw_crystal_rack(at_f: float) -> void:
	var f := _frame(at_f)
	_pen.draw_set_transform(f[0], f[1].angle(), Vector2.ONE * 1.3)
	Palette.draw_rounded_rect(_pen, Rect2(-34, -12, 68, 22), 3.0, Palette.GOBLIN_WOOD_DARK)
	Palette.draw_rounded_rect(_pen, Rect2(-32, -10, 64, 18), 2.0, WOOD)
	var gems := [Palette.COBALT, Palette.GOLD, Color("E04B42"), Palette.COBALT, Palette.GOLD]
	for k in range(gems.size()):
		var p := Vector2(-24.0 + float(k) * 12.0, -1.0)
		var glow := 0.75 + 0.25 * sin(_time * 2.0 + float(k))
		_pen.draw_circle(p, 7.0, Color(gems[k], 0.15 * glow))
		_pen.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(4, 0), p + Vector2(0, 5), p + Vector2(-4, 0)]), gems[k])
		_pen.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(-4, 0), p + Vector2(0, -1)]), Color(1, 1, 1, 0.55))
	_pen.draw_set_transform(Vector2.ZERO)
