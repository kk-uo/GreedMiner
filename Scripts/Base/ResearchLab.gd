class_name ResearchLab
extends Node2D

## Research lab in the top-left of the hold (style A, code-drawn): an open
## dwarven forge line on an iron slab. A lava smelter on the left pours into a
## conveyor belt that runs the length of the slab; over the middle of the belt
## an automatic power hammer on a gantry slams down every PRESS_TIME seconds
## (impact ring + sparks); the belt leaves through a hatch on the right. An
## anvil and a hammer sit on the ground in front, and the dwarf scientist
## (LabScientist) idles next to it. Presentation only: AsteroidHangar owns the
## hotspot and BaseMain decides what a click does.

## Local design size of the slab; the node is scaled by AsteroidHangar.
const SIZE := Vector2(208.0, 128.0)
const CHAMFER: float = 16.0
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

## Conveyor (local x range and y) and the hammer position on it.
const BELT_FROM: float = -46.0
const BELT_TO: float = 104.0
const BELT_Y: float = -12.0
const PRESS_AT := Vector2(8.0, -12.0)
const SMELTER_AT := Vector2(-70.0, -14.0)
const ANVIL_AT := Vector2(60.0, 92.0)

var hovered: bool = false:
	set(value):
		hovered = value
		queue_redraw()

var _time: float = 0.0
var _scientist: LabScientist


func _ready() -> void:
	_scientist = LabScientist.new()
	_scientist.position = Vector2(-20.0, SIZE.y * 0.5 + 22.0)
	_scientist.base_facing = deg_to_rad(-70.0)
	add_child(_scientist)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Local-space rectangle used for hit testing.
static func get_hit_rect() -> Rect2:
	return Rect2(-SIZE * 0.5, SIZE).grow(8.0)


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
	var w := SIZE.x
	var h := SIZE.y
	# Iron slab.
	_pen.draw_colored_polygon(_octagon(w, h, CHAMFER, Vector2(8.0, 10.0)), Palette.SHADOW_COLOR)
	_pen.draw_colored_polygon(_octagon(w, h, CHAMFER), ShipHullVisual.FRAME_RIM)
	_pen.draw_colored_polygon(_octagon(w - 6.0, h - 6.0, CHAMFER - 2.0, Vector2(1.5, 1.5)), ShipHullVisual.FRAME_IRON)
	# Hazard stripe along the front edge.
	for k in range(9):
		var x := -w * 0.5 + 26.0 + float(k) * 18.0
		_pen.draw_colored_polygon(PackedVector2Array([Vector2(x, h * 0.5 - 9.0), Vector2(x + 8.0, h * 0.5 - 9.0), Vector2(x + 4.0, h * 0.5 - 4.0), Vector2(x - 4.0, h * 0.5 - 4.0)]), Color(Palette.GOLD, 0.55))

	_draw_smelter()
	_draw_console(Vector2(-92.0, 14.0))
	_draw_belt()
	_draw_exit_hatch()
	_draw_press()
	_draw_anvil(ANVIL_AT)

	if hovered:
		var outline := _octagon(w + 22.0, h + 22.0, CHAMFER + 6.0)
		outline.append(outline[0])
		_pen.draw_polyline(outline, Palette.ACCENT, 4.0)


func _draw_smelter() -> void:
	var c := SMELTER_AT
	var r := 17.0
	_pen.draw_circle(c + Vector2(3, 4), r + 6.0, Palette.SHADOW_COLOR)
	_pen.draw_circle(c, r + 6.0, STONE_DARK)
	_pen.draw_circle(c + Vector2(-1, -1), r + 3.0, STONE)
	_pen.draw_circle(c, r * 2.0, Color(LAVA_MID, 0.08))
	_pen.draw_circle(c, r, LAVA)
	_pen.draw_circle(c, r * (0.62 + 0.16 * (0.5 + 0.5 * sin(_time * 3.5))), LAVA_MID)
	_pen.draw_circle(c + Vector2(-r * 0.3, -r * 0.25), r * 0.3, Color(LAVA_WHITE, 0.55 + 0.4 * sin(_time * 5.0)))
	# Spout pouring onto the start of the belt.
	var from := c + Vector2(r + 2.0, 2.0)
	var to := Vector2(BELT_FROM + 6.0, BELT_Y)
	_pen.draw_line(from, to, LAVA_DARK, 7.0)
	_pen.draw_line(from, to, LAVA_MID, 4.0)
	var flow := fposmod(_time * 30.0, 8.0)
	var direction := (to - from).normalized()
	var d := flow
	while d < from.distance_to(to):
		_pen.draw_line(from + direction * d, from + direction * minf(d + 3.0, from.distance_to(to)), LAVA_WHITE, 1.4)
		d += 8.0


func _draw_console(at: Vector2) -> void:
	Palette.draw_rounded_rect(_pen, Rect2(at, Vector2(44.0, 22.0)), 4.0, ShipHullVisual.FRAME_RIM)
	Palette.draw_rounded_rect(_pen, Rect2(at + Vector2(2.0, 2.0), Vector2(40.0, 18.0)), 3.0, Palette.UI_PANEL)
	var colors := [Palette.ACCENT, Palette.COBALT, Palette.ACCENT, Palette.COBALT]
	for k in range(colors.size()):
		var on := fmod(_time * 1.6 - float(k) * 0.25, 1.6) < 1.0
		Palette.draw_rounded_rect(_pen, Rect2(at + Vector2(5.0 + float(k) * 9.0, 5.0), Vector2(5.0, 3.5)), 1.0, colors[k] if on else Palette.MECH_LIGHT)
	var fill := 4.0 + 28.0 * (0.5 + 0.5 * sin(_time * 1.3))
	Palette.draw_rounded_rect(_pen, Rect2(at + Vector2(5.0, 13.0), Vector2(fill, 4.0)), 1.5, Palette.COBALT)


func _draw_belt() -> void:
	var rect := Rect2(BELT_FROM, BELT_Y - 8.0, BELT_TO - BELT_FROM, 16.0)
	Palette.draw_rounded_rect(_pen, rect, 4.0, IRON)
	Palette.draw_rounded_rect(_pen, rect.grow(-2.0), 3.0, BELT)
	# Moving cleats.
	var shift := fposmod(_time * 24.0, 8.0)
	var x := rect.position.x + 4.0 + shift
	while x < rect.end.x - 4.0:
		_pen.draw_line(Vector2(x, BELT_Y - 5.0), Vector2(x, BELT_Y + 5.0), IRON_MID, 3.0)
		x += 8.0
	for end_x in [rect.position.x + 5.0, rect.end.x - 5.0]:
		_pen.draw_circle(Vector2(end_x, BELT_Y), 7.0, IRON_MID)
		_pen.draw_circle(Vector2(end_x, BELT_Y), 2.5, IRON)
	# The belt glows where the hammer just struck.
	var k := _stroke()
	if k > 0.6 and k < 0.95:
		var heat := 1.0 - (k - 0.6) / 0.35
		_pen.draw_circle(PRESS_AT, 14.0, Color(LAVA_MID, 0.35 * heat))
		Palette.draw_rounded_rect(_pen, Rect2(PRESS_AT - Vector2(9.0, 5.0), Vector2(18.0, 10.0)), 2.0, Color(LAVA_HOT, 0.8 * heat))


func _draw_exit_hatch() -> void:
	var at := Vector2(BELT_TO - 10.0, BELT_Y)
	Palette.draw_rounded_rect(_pen, Rect2(at - Vector2(8.0, 16.0), Vector2(16.0, 32.0)), 3.0, ShipHullVisual.FRAME_RIM)
	Palette.draw_rounded_rect(_pen, Rect2(at - Vector2(5.0, 11.0), Vector2(10.0, 22.0)), 2.0, Color("0E0B09"))
	var blink := fmod(_time, 1.2) < 0.6
	_pen.draw_circle(at + Vector2(0.0, -20.0), 2.6, Palette.ACCENT if blink else Palette.MECH_LIGHT)


func _draw_press() -> void:
	var c := PRESS_AT
	# Gantry: two posts and a crossbeam.
	for x in [-26.0, 18.0]:
		Palette.draw_rounded_rect(_pen, Rect2(c + Vector2(x, -34.0), Vector2(10.0, 62.0)), 3.0, ShipHullVisual.POD_BAND)
	Palette.draw_rounded_rect(_pen, Rect2(c + Vector2(-30.0, -38.0), Vector2(58.0, 12.0)), 3.0, ShipHullVisual.FRAME_IRON)
	Palette.draw_rounded_rect(_pen, Rect2(c + Vector2(-28.0, -37.0), Vector2(54.0, 5.0)), 2.0, ShipHullVisual.FRAME_RIM)
	Palette.draw_rounded_rect(_pen, Rect2(c + Vector2(-28.0, 26.0), Vector2(54.0, 5.0)), 2.0, Palette.ACCENT)

	var k := _stroke()
	var lift := hammer_lift(k)
	var scale_k := lerpf(0.97, 1.22, lift)
	var head := Vector2(34.0, 30.0) * scale_k
	var shadow := lerpf(3.0, 14.0, lift)
	_pen.draw_rect(Rect2(c - head * 0.5 + Vector2(shadow, shadow * 1.25), head), Color(0, 0, 0, 0.3))
	var rect := Rect2(c - head * 0.5, head)
	Palette.draw_rounded_rect(_pen, rect, 5.0, IRON)
	Palette.draw_rounded_rect(_pen, Rect2(rect.position + Vector2(3.0, 3.0), rect.size - Vector2(6.0, 8.0)), 4.0, IRON_MID)
	Palette.draw_rounded_rect(_pen, Rect2(rect.position + Vector2(5.0, 5.0), Vector2(head.x * 0.45, head.y * 0.22)), 2.0, Color(IRON_LIGHT, 0.6))
	Palette.draw_rounded_rect(_pen, Rect2(c - head * 0.18, head * 0.36), 3.0, IRON)
	_pen.draw_circle(c, minf(head.x, head.y) * 0.1, Palette.ACCENT)
	_pen.draw_rect(Rect2(rect.position.x + 2.0, rect.end.y - 6.0, rect.size.x - 4.0, 3.0), Color(Palette.GOLD, 0.85))

	# Impact: expanding ring and a burst of sparks.
	if k >= 0.6 and k < 0.82:
		var t := (k - 0.6) / 0.22
		_pen.draw_arc(c, lerpf(16.0, 34.0, t), 0.0, TAU, 32, Color(LAVA_WHITE, 0.9 * (1.0 - t)), 3.0 * (1.0 - t) + 0.5)
		for index in range(8):
			var a := TAU * float(index) / 8.0 + 0.3
			var dir := Vector2(cos(a), sin(a) * 0.8)
			_pen.draw_line(c + dir * lerpf(16.0, 22.0, t), c + dir * lerpf(22.0, 34.0, t), Color(LAVA_HOT if index % 2 == 0 else LAVA_WHITE, 1.0 - t), 2.0)


## Anvil on the ground in front of the slab, with a hammer leaning on it.
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


static func _octagon(w: float, h: float, c: float, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	return Palette.offset_points(PackedVector2Array([
		Vector2(-w / 2 + c, -h / 2), Vector2(w / 2 - c, -h / 2), Vector2(w / 2, -h / 2 + c),
		Vector2(w / 2, h / 2 - c), Vector2(w / 2 - c, h / 2), Vector2(-w / 2 + c, h / 2),
		Vector2(-w / 2, h / 2 - c), Vector2(-w / 2, -h / 2 + c),
	]), offset)
