extends RefCounted

## Magic Shop art (Claude sync 98, design B "rug stall", no parasol): a
## wandering merchant in a violet hood sits behind a patterned rug of wares,
## his huge travel pack and a lantern behind him, pipe smoke drifting up.
## Drawn by AsteroidHangar in mock coordinates (the canvas transform already
## applies LAYOUT_SCALE). Load with preload(); no class_name on purpose.

## Mock-canvas centre of the stall (inside AsteroidHangar.MAGIC_SHOP_RECT).
const CENTER := Vector2(423.0, 512.0)

const SHADOW := Color(0, 0, 0, 0.28)
const WOOD_D := Color("3B2A1E")
const RUG := Color("8F2A2A")
const RUG_FIELD := Color("2F4D6A")
const RUG_TRIM := Color("C2843A")
const CLOAK_D := Color("2E2240")
const CLOAK := Color("4B3768")
const CLOAK_L := Color("6E54A0")
const PACK := Color("6B4A32")
const CANVAS := Color("E6D3B0")
const LAMP := Color("FFC861")
const EYE := Color("FFD86A")
const WARES := [
	[Vector2(-36, -6), Color("B06BFF")],
	[Vector2(-18, 16), Color("5FD0FF")],
	[Vector2(2, -8), Color("FF6A6A")],
	[Vector2(22, 14), Color("9CC44C")],
	[Vector2(38, -4), Color("FFD23F")],
]


## hovered: warm outline, brighter eyes and wares. guide: pulsing orange ring.
static func draw(canvas: CanvasItem, time: float, hovered: bool, guide: bool = false) -> void:
	var c := CENTER
	var glow := 1.0 if hovered else 0.0
	_rug(canvas, c + Vector2(0, 4))
	for index in range(WARES.size()):
		var ware: Array = WARES[index]
		var at: Vector2 = c + Vector2(0, 4) + (ware[0] as Vector2)
		var color: Color = ware[1]
		var twinkle := 0.5 + 0.5 * sin(time * 2.2 + float(index) * 1.7)
		canvas.draw_circle(at, 6.5 + glow * 1.5, Color(color, 0.16 + 0.12 * twinkle + 0.1 * glow))
		canvas.draw_circle(at + Vector2(1, 1.5), 3.4, SHADOW)
		canvas.draw_circle(at, 3.2, color)
		canvas.draw_circle(at - Vector2(1, 1), 1.0, Color(1, 1, 1, 0.6 + 0.4 * twinkle))
	# A rolled scroll and a dagger lying among the wares.
	canvas.draw_rect(Rect2(c + Vector2(-6, 13), Vector2(14, 5)), CANVAS)
	canvas.draw_rect(Rect2(c + Vector2(10, -14), Vector2(4, 10)), Color("B07A46"))
	_pack(canvas, c + Vector2(0, -26))
	_lantern(canvas, c + Vector2(-22, -56), time)
	_merchant(canvas, c + Vector2(0, -27) + Vector2(0, sin(time * 1.3) * 0.6), time, glow)
	if hovered:
		canvas.draw_rect(Rect2(c + Vector2(-60, -40), Vector2(120, 82)), Color("F4BA62", 0.6), false, 2.0)
	if guide:
		var pulse := 0.5 + 0.5 * sin(time * 5.0)
		canvas.draw_rect(Rect2(c + Vector2(-64, -72), Vector2(128, 118)), Color("F08A24", 0.4 + 0.5 * pulse), false, 3.0)


static func _poly(canvas: CanvasItem, points: Array, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array(points), color)


static func _rug(canvas: CanvasItem, c: Vector2) -> void:
	_poly(canvas, [c + Vector2(-52, -27), c + Vector2(60, -27), c + Vector2(60, 39), c + Vector2(-52, 39)], SHADOW)
	canvas.draw_rect(Rect2(c + Vector2(-56, -30), Vector2(112, 64)), RUG)
	canvas.draw_rect(Rect2(c + Vector2(-52, -26), Vector2(104, 56)), RUG_TRIM, false, 2.0)
	canvas.draw_rect(Rect2(c + Vector2(-46, -20), Vector2(92, 44)), RUG_FIELD)
	for index in range(5):
		var d := c + Vector2(-36.0 + index * 18.0, 2.0)
		_poly(canvas, [d + Vector2(0, -9), d + Vector2(7, 0), d + Vector2(0, 9), d + Vector2(-7, 0)], RUG_TRIM)
		canvas.draw_circle(d, 2.0, RUG)
	for x in range(-54, 58, 6):
		canvas.draw_line(c + Vector2(x, 34), c + Vector2(x, 38), RUG_TRIM, 1.2)
		canvas.draw_line(c + Vector2(x, -30), c + Vector2(x, -34), RUG_TRIM, 1.2)


## The huge travel pack behind him: canvas bag, bedroll, pot and kettle.
static func _pack(canvas: CanvasItem, c: Vector2) -> void:
	var bag := [c + Vector2(-12, -38), c + Vector2(12, -38), c + Vector2(16, -14), c + Vector2(-16, -14)]
	var shadow := []
	for p in bag:
		shadow.append(p + Vector2(4, 5))
	_poly(canvas, shadow, SHADOW)
	_poly(canvas, bag, PACK)
	canvas.draw_rect(Rect2(c + Vector2(-14, -34), Vector2(28, 6)), RUG)
	canvas.draw_circle(c + Vector2(-6, -40), 5.0, Color("7D8389"))
	canvas.draw_circle(c + Vector2(-6, -40), 3.0, Color("5D6166"))
	canvas.draw_circle(c + Vector2(7, -41), 4.0, Color("2F6E8C"))
	var roll := PackedVector2Array()
	for k in range(20):
		var a := TAU * float(k) / 20.0
		roll.append(c + Vector2(cos(a) * 16.0, -26.0 + sin(a) * 4.0))
	canvas.draw_colored_polygon(roll, CANVAS)


static func _lantern(canvas: CanvasItem, at: Vector2, time: float) -> void:
	var flicker := 0.85 + 0.15 * sin(time * 11.0) * sin(time * 7.3)
	canvas.draw_circle(at, 11.0 * flicker, Color(LAMP, 0.16))
	canvas.draw_circle(at, 6.0, Color(LAMP, 0.3 * flicker))
	canvas.draw_rect(Rect2(at - Vector2(2.5, 3), Vector2(5, 6)), Color("FFE6A0"))
	canvas.draw_rect(Rect2(at - Vector2(3, 4), Vector2(6, 1.5)), WOOD_D)


## Hooded merchant seen from above, facing the rug (down the screen).
static func _merchant(canvas: CanvasItem, at: Vector2, time: float, glow: float) -> void:
	var f := Vector2.DOWN
	var s := Vector2.LEFT
	canvas.draw_circle(at + Vector2(3, 4), 13.0, SHADOW)
	_ellipse(canvas, at, 14.0, 12.0, CLOAK_D)
	_ellipse(canvas, at - f * 1.5, 12.0, 10.0, CLOAK)
	_ellipse(canvas, at - f * 3.0, 7.0, 6.0, CLOAK_L)
	canvas.draw_circle(at + f * 6.0, 5.5, Color("140E1A"))
	var blink := 0.15 if fposmod(time, 4.3) < 0.12 else 1.0
	for side in [1.0, -1.0]:
		var eye: Vector2 = at + f * 7.0 + s * 2.2 * side
		canvas.draw_circle(eye, 2.4 + glow, Color(EYE, 0.25 * blink))
		canvas.draw_circle(eye, 1.3 * blink + 0.1, EYE)
	# Pipe and drifting smoke puffs.
	var bowl := at + f * 13.0 + s * 5.0
	canvas.draw_line(at + f * 9.0, bowl, WOOD_D, 1.6)
	canvas.draw_circle(bowl, 1.6, Color("FF7A2A"))
	for k in range(4):
		var phase := fposmod(time * 0.45 + float(k) * 0.25, 1.0)
		var puff := bowl + Vector2(sin(phase * 5.0 + float(k)) * 3.0 - phase * 4.0, -phase * 26.0)
		canvas.draw_circle(puff, 1.2 + phase * 3.0, Color(1, 1, 1, 0.38 * (1.0 - phase)))
	# Scarf tail.
	_poly(canvas, [at - s * 10.0 + f * 2.0, at - s * 16.0 - f * 6.0, at - s * 12.0 - f * 8.0], Color("B8452F"))


static func _ellipse(canvas: CanvasItem, c: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for k in range(24):
		var a := TAU * float(k) / 24.0
		points.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	canvas.draw_colored_polygon(points, color)
