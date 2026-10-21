extends RefCounted

## Mining dwarf art (user pick: style A "pickaxe"). The same little top-down
## dwarf as BaseDwarf (round helmet, orange lamp, beard pointing forward),
## drawn facing +x and rotated by `facing`. Swings a pickaxe while mining
## (lamp beam on the crystal), carries a glowing crystal chunk over its head
## on the way back. Presentation only.
## state: {at, time, facing, walking, working, carrying, chunk (Color)}
## Load with preload(); no class_name on purpose.

const SCALE: float = 1.3
const BOOT := Color("2E2620")
const TUNIC := Color("7A5A3A")
const SKIN := Color("C98B52")
const BEARD := Color("E8D7B8")
const STEEL: Array[Color] = [Color("5D6166"), Color("7D8389"), Color("AAB0B5")]
const WOOD: Array[Color] = [Color("3B2A1E"), Color("8A5A34"), Color("B07A46")]
## Swings per second while mining.
const SWING_RATE: float = 1.6


## 0..1 position in the current swing (strike lands at ~0.62).
static func swing_cycle(time: float) -> float:
	return fposmod(time * SWING_RATE, 1.0)


static func draw(c: Object, state: Dictionary) -> void:
	var origin: Vector2 = state.get("at", Vector2.ZERO)
	var time: float = state.get("time", 0.0)
	var facing: float = state.get("facing", 0.0)
	var walking: bool = state.get("walking", false)
	var working: bool = state.get("working", false)
	var carrying: bool = state.get("carrying", false)
	var bob := sin(time * (14.0 if walking else 2.0)) * (1.2 if walking else 0.5)
	c.draw_set_transform(origin, 0.0, Vector2.ONE * SCALE)
	c.draw_circle(Vector2(4.0, 5.0), 8.0, Palette.SHADOW_COLOR)
	c.draw_set_transform(origin + Vector2(0.0, bob) * SCALE, facing, Vector2.ONE * SCALE)
	var stride := sin(time * 14.0) * 3.0 if walking else 0.0
	for side in [-1.0, 1.0]:
		c.draw_circle(Vector2(1.5 + stride * side, 4.2 * side), 2.4, BOOT)
	c.draw_colored_polygon(Palette.regular_polygon(7, 7.5, PI / 7.0), TUNIC)
	c.draw_colored_polygon(PackedVector2Array([Vector2(3, -4), Vector2(10, 0), Vector2(3, 4)]), BEARD)
	_pick(c, working, carrying, time)
	c.draw_circle(Vector2(-0.5, 0.0), 5.6, Palette.SHIP_PART)
	c.draw_circle(Vector2(-1.5, -1.0), 4.2, Palette.SHIP_BODY)
	c.draw_circle(Vector2(3.6, 0.0), 1.8, Palette.ACCENT)
	if working:
		c.draw_colored_polygon(PackedVector2Array([Vector2(4, -1.2), Vector2(18, -6), Vector2(18, 6), Vector2(4, 1.2)]), Color(Palette.ACCENT_LIGHT, 0.18))
	if carrying:
		_held_crystal(c, time, state.get("chunk", Palette.COBALT))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _hand(c: Object, at: Vector2) -> void:
	c.draw_circle(at, 1.8, SKIN)


static func _pick(c: Object, working: bool, carrying: bool, time: float) -> void:
	if carrying:
		# Pick slung across the back.
		c.draw_line(Vector2(-8, -7), Vector2(-3, 8), WOOD[0], 1.8)
		c.draw_colored_polygon(PackedVector2Array([Vector2(-11, -6), Vector2(-8, -9), Vector2(-4, -8.5), Vector2(-8, -6.5)]), STEEL[1])
		return
	# Swing: wind up over the shoulder, strike forward fast, recover.
	var angle := -0.9
	if working:
		var cycle := swing_cycle(time)
		angle = lerpf(-0.2, -2.0, smoothstep(0.0, 0.55, cycle)) if cycle < 0.55 else lerpf(-2.0, 0.25, smoothstep(0.55, 0.68, cycle))
	var dir := Vector2.RIGHT.rotated(angle)
	var n := dir.orthogonal()
	var grip := Vector2(2.0, 4.0)
	var head := grip + dir * 15.0
	c.draw_line(grip + Vector2(0.8, 0.8), head + Vector2(0.8, 0.8), Color(0, 0, 0, 0.25), 2.8)
	c.draw_line(grip, head, WOOD[0], 2.8)
	c.draw_line(grip, head, WOOD[2], 1.4)
	var pick_head := PackedVector2Array([head + n * 7.0 - dir * 1.0, head + dir * 2.2, head - n * 6.5 - dir * 1.0, head - dir * 2.0])
	c.draw_colored_polygon(Palette.offset_points(pick_head, Vector2(0.8, 0.8)), Color(0, 0, 0, 0.25))
	c.draw_colored_polygon(pick_head, STEEL[0])
	c.draw_colored_polygon(PackedVector2Array([head + n * 7.0 - dir * 1.0, head + dir * 2.2, head - dir * 0.2]), STEEL[2])
	_hand(c, grip + dir * 3.5)
	_hand(c, grip + dir * 7.5)


## A big crystal chunk held up over the helmet, glowing in the crystal's colour.
static func _held_crystal(c: Object, time: float, color: Color) -> void:
	var glow := 0.7 + 0.3 * sin(time * 4.0)
	var at := Vector2(-1.0, -1.0)
	c.draw_circle(at, 9.0, Color(color, 0.18 * glow))
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -7), at + Vector2(5, -2), at + Vector2(4, 5), at + Vector2(-2, 6), at + Vector2(-5, 0)]), color.darkened(0.3))
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -7), at + Vector2(-5, 0), at + Vector2(-2, 6), at + Vector2(0.5, 0)]), color)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -7), at + Vector2(-3, -2), at + Vector2(0, -1.5)]), color.lightened(0.6))
	for side in [-1.0, 1.0]:
		_hand(c, at + Vector2(1.0, 6.0 * side))


## Chips flying off the struck crystal just after each blow. `at` is the
## crystal, `toward` points from the crystal back at the dwarf.
static func draw_chips(c: Object, at: Vector2, time: float, toward: Vector2, color: Color) -> void:
	var cycle := swing_cycle(time)
	if cycle < 0.62:
		return
	var ph := (cycle - 0.62) / 0.38
	for k in range(5):
		var dir := toward.rotated((float(k) - 2.0) * 0.45)
		var p := at + dir * ph * (14.0 + 3.0 * float(k % 2)) + Vector2(0, -sin(PI * ph) * 8.0)
		var r := 1.8 * (1.0 - ph) + 0.4
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), Color(color.lightened(0.5), 1.0 - ph))
	if ph < 0.25:
		c.draw_circle(at + toward * 6.0, 4.0 * (1.0 - ph * 4.0), Color(1, 1, 1, 0.8 * (1.0 - ph * 4.0)))
