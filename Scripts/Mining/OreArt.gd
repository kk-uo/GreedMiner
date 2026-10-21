extends RefCounted

## Planet ore deposits mined by the dwarves (user picks, 2026-10-20):
## Verdant amber; Frozen aurora frost + silver vein; Volcanic obsidian + fire
## crystal; Graveyard biomass + soul crystal. Drawn around the deposit origin
## (about 25 px radius before scaling), top-down 3/4, light from the upper
## left, shadow lower right. RockyCrystal draws these when `ore_kind` is set.
## Load with preload(); no class_name on purpose.

const SHADOW := Color(0, 0, 0, 0.28)


static func draw(c: Object, kind: StringName, time: float) -> void:
	match kind:
		&"amber": _amber(c, time)
		&"aurora": _aurora(c, time)
		&"silver": _silver(c, time)
		&"obsidian": _obsidian(c, time)
		&"fire": _fire(c, time)
		&"biomass": _biomass(c, time)
		&"soul": _soul(c, time)


## The colour of the chunk a dwarf carries home.
static func chunk_color(kind: StringName) -> Color:
	return {
		&"amber": Color("F2A93B"), &"aurora": Color("B8F0FF"), &"silver": Color("D8DEE6"),
		&"obsidian": Color("FF7A2A"), &"fire": Color("FF5A2A"),
		&"biomass": Color("6BE04A"), &"soul": Color("B49CFF"),
	}.get(kind, Palette.COBALT)


# ------------------------------------------------------------------ helpers

static func _prism(c: Object, base: Vector2, height: float, width: float, tilt: float, light: Color, dark: Color, shine: Color) -> void:
	var up := Vector2.UP.rotated(tilt)
	var side := up.orthogonal()
	var tip := base + up * height
	var shoulder := base + up * height * 0.62
	var pts_l := PackedVector2Array([tip, shoulder - side * width, base - side * width * 0.9, base])
	var pts_r := PackedVector2Array([tip, shoulder + side * width, base + side * width * 0.9, base])
	c.draw_colored_polygon(Palette.offset_points(PackedVector2Array([tip, shoulder + side * width, base + side * width, base - side * width, shoulder - side * width]), Vector2(3, 3)), SHADOW)
	c.draw_colored_polygon(pts_r, dark)
	c.draw_colored_polygon(pts_l, light)
	c.draw_colored_polygon(PackedVector2Array([tip, shoulder - side * width, tip.lerp(base, 0.45)]), shine)


static func _blob(center: Vector2, radii: Vector2, seed: float, sides: int = 10) -> PackedVector2Array:
	var p := PackedVector2Array()
	for k in range(sides):
		var a := TAU * float(k) / float(sides)
		var w := 1.0 + 0.1 * sin(a * 2.0 + seed) + 0.07 * sin(a * 5.0 + seed * 1.7)
		p.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y) * w)
	return p


static func _scaled(points: PackedVector2Array, pivot: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(pivot + (p - pivot) * k)
	return out


static func _rock(c: Object, center: Vector2, radii: Vector2, seed: float, tones: Array) -> void:
	var b := _blob(center, radii, seed)
	c.draw_colored_polygon(Palette.offset_points(b, Vector2(3, 3)), SHADOW)
	c.draw_colored_polygon(b, tones[0])
	c.draw_colored_polygon(_scaled(b, center + Vector2(-radii.x, -radii.y) * 0.2, 0.75), tones[1])
	c.draw_colored_polygon(_scaled(b, center + Vector2(-radii.x, -radii.y) * 0.55, 0.35), tones[2])


static func _glow(c: Object, at: Vector2, r: float, color: Color, alpha: float) -> void:
	c.draw_circle(at, r * 0.85, Color(color, alpha * 0.55))


# ------------------------------------------------------------------ verdant (jungle)

## Amber: honey-gold resin blobs oozing from a mossy root, a bug caught inside.
static func _amber(c: Object, time: float) -> void:
	_rock(c, Vector2(0, 6), Vector2(22, 11), 0.6, [Color("4A3524"), Color("6B4E34"), Color("8A6A48")])
	for k in range(3):
		c.draw_circle(Vector2(-16 + k * 13, 9 + (k % 2) * 3), 3.4, Color("5E8F3A"))
	var drops := [[Vector2(-7, -6), 9.0], [Vector2(8, -2), 7.0], [Vector2(-1, -17), 6.0]]
	for d in drops:
		var at: Vector2 = d[0]
		var r: float = d[1]
		# Teardrop of resin: rounded bottom, drawn-out top.
		var drop := PackedVector2Array()
		for k in range(14):
			var a := TAU * float(k) / 14.0
			var stretch := 1.0 + 0.55 * maxf(-sin(a), 0.0)
			drop.append(at + Vector2(cos(a) * r * 0.85 * (1.0 - 0.35 * maxf(-sin(a), 0.0)), sin(a) * r * stretch))
		c.draw_colored_polygon(Palette.offset_points(drop, Vector2(2.5, 2.5)), SHADOW)
		c.draw_colored_polygon(drop, Color("A8561A"))
		c.draw_colored_polygon(_scaled(drop, at + Vector2(-r * 0.2, -r * 0.2), 0.82), Color("F2A93B", 0.95))
		c.draw_colored_polygon(_scaled(drop, at + Vector2(r * 0.3, r * 0.5), 0.45), Color("C8701E", 0.6))
		c.draw_circle(at + Vector2(-r * 0.32, -r * 0.45), r * 0.22, Color("FFF0C8"))
	# Trapped bug.
	c.draw_circle(Vector2(-6, -5), 2.0, Color("4A2A10", 0.8))
	for s in [-1.0, 1.0]:
		c.draw_line(Vector2(-6, -5), Vector2(-6 + 3.0 * s, -8), Color("4A2A10", 0.7), 0.8)
	_glow(c, Vector2(-2, -6), 22.0, Color("F2A93B"), 0.06 + 0.02 * sin(time * 2.0))


# ------------------------------------------------------------------ frozen

## Aurora frost: tall thin pale spikes with a shifting cyan-violet sheen.
static func _aurora(c: Object, time: float) -> void:
	var spikes := [[Vector2(-10, 8), 30.0, -0.3], [Vector2(0, 10), 40.0, 0.05], [Vector2(10, 8), 26.0, 0.35], [Vector2(-3, 12), 18.0, -0.1]]
	for index in range(spikes.size()):
		var s: Array = spikes[index]
		var hue := fposmod(time * 0.08 + float(index) * 0.12, 1.0)
		var sheen := Color.from_hsv(lerpf(0.5, 0.82, 0.5 + 0.5 * sin(hue * TAU)), 0.35, 1.0)
		_prism(c, s[0], s[1], 4.5, s[2], Color("DDF6FF"), Color("8FB8D8"), sheen)
	_glow(c, Vector2(0, -14), 28.0, Color.from_hsv(fposmod(0.55 + 0.1 * sin(time * 0.6), 1.0), 0.4, 1.0), 0.07)


## Silver vein: a snow-capped boulder threaded with bright silver ore.
static func _silver(c: Object, time: float) -> void:
	_rock(c, Vector2(0, 0), Vector2(22, 16), 1.2, [Color("3F4A52"), Color("56636D"), Color("6E7C86")])
	c.draw_colored_polygon(_blob(Vector2(-4, -9), Vector2(16, 7), 3.0), Color("F2F7FA"))
	c.draw_colored_polygon(_blob(Vector2(-7, -11), Vector2(9, 4), 1.0), Color("FFFFFF"))
	var veins := [[Vector2(-16, 2), Vector2(-6, 6), Vector2(4, 2), Vector2(14, 6)], [Vector2(-8, 10), Vector2(2, 9), Vector2(10, 12)]]
	for v in veins:
		var pts := PackedVector2Array(v)
		c.draw_polyline(pts, Color("8A96A2"), 3.4)
		c.draw_polyline(pts, Color("D8DEE6"), 2.0)
	for k in range(3):
		var ph := fposmod(time * 0.7 + float(k) * 0.33, 1.0)
		var p: Vector2 = [Vector2(-6, 5), Vector2(8, 4), Vector2(2, 10)][k]
		var a := 3.0 * sin(PI * ph)
		c.draw_line(p - Vector2(a, 0), p + Vector2(a, 0), Color.WHITE, 1.0)
		c.draw_line(p - Vector2(0, a), p + Vector2(0, a), Color.WHITE, 1.0)


# ------------------------------------------------------------------ volcanic

## Obsidian: glassy black shards split by glowing magma cracks.
static func _obsidian(c: Object, time: float) -> void:
	var glow := 0.7 + 0.3 * sin(time * 2.0)
	_glow(c, Vector2(0, 0), 24.0, Color("FF7A2A"), 0.08 * glow)
	_prism(c, Vector2(-8, 8), 22.0, 8.0, -0.4, Color("3A3040"), Color("17121A"), Color("8A80A0"))
	_prism(c, Vector2(8, 9), 26.0, 8.0, 0.3, Color("3A3040"), Color("17121A"), Color("8A80A0"))
	for line in [[Vector2(-10, 4), Vector2(-7, -4), Vector2(-9, -10)], [Vector2(9, 6), Vector2(6, -3), Vector2(10, -12)]]:
		var pts := PackedVector2Array(line)
		c.draw_polyline(pts, Color("FF7A2A", 0.5 * glow), 3.0)
		c.draw_polyline(pts, Color("FFD08A", glow), 1.2)
	c.draw_colored_polygon(_blob(Vector2(0, 11), Vector2(14, 4), 0.5), Color("C2410C", 0.8))
	c.draw_colored_polygon(_blob(Vector2(-1, 10), Vector2(8, 2), 0.5), Color("FFB347", glow))


## Fire crystal: orange-red crystals whose tips flicker with little flames.
static func _fire(c: Object, time: float) -> void:
	_glow(c, Vector2(0, -6), 26.0, Color("FF5A2A"), 0.1)
	var tips := [[Vector2(-8, 8), 22.0, -0.35], [Vector2(6, 9), 28.0, 0.25], [Vector2(0, 11), 14.0, 0.0]]
	for index in range(tips.size()):
		var t: Array = tips[index]
		_prism(c, t[0], t[1], 6.0, t[2], Color("FF7A3A"), Color("B8261A"), Color("FFE08A"))
		var tip: Vector2 = Vector2(t[0]) + Vector2.UP.rotated(float(t[2])) * float(t[1])
		var f := 0.75 + 0.25 * sin(time * 11.0 + float(index) * 2.0)
		c.draw_colored_polygon(PackedVector2Array([tip + Vector2(-3, 1), tip + Vector2(0, -9 * f), tip + Vector2(3, 1)]), Color("FFB347", 0.9))
		c.draw_colored_polygon(PackedVector2Array([tip + Vector2(-1.5, 1), tip + Vector2(0, -5 * f), tip + Vector2(1.5, 1)]), Color("FFF2B0"))


# ------------------------------------------------------------------ graveyard

## Biomass: glowing green crystals dripping into a pool of living biomass.
static func _biomass(c: Object, time: float) -> void:
	var pulse := 0.6 + 0.4 * sin(time * 1.7)
	c.draw_colored_polygon(_blob(Vector2(0, 10), Vector2(22, 8), 0.4), Color("1E2A1C"))
	c.draw_colored_polygon(_blob(Vector2(-1, 9), Vector2(19, 6), 0.4), Color("3E9C30"))
	c.draw_colored_polygon(_blob(Vector2(-4, 8), Vector2(9, 3), 1.4), Color("B8FF7A", pulse))
	_glow(c, Vector2(0, -6), 26.0, Color("4FC23C"), 0.1 * pulse)
	_prism(c, Vector2(-7, 8), 24.0, 6.0, -0.3, Color("6BE04A"), Color("2E7A22"), Color("D8FFB8"))
	_prism(c, Vector2(7, 9), 18.0, 5.0, 0.35, Color("6BE04A"), Color("2E7A22"), Color("D8FFB8"))
	var ph := fposmod(time * 0.8, 1.0)
	c.draw_circle(Vector2(-4, -4 + ph * 12), 1.6 * (1.0 - ph * 0.5), Color("B8FF7A", 1.0 - ph))


## Soul crystal: a lilac crystal with tiny wisps orbiting it.
static func _soul(c: Object, time: float) -> void:
	_rock(c, Vector2(0, 8), Vector2(16, 7), 2.4, [Color("2A2E2A"), Color("4A4F4A"), Color("7F877C")])
	_glow(c, Vector2(0, -10), 26.0, Color("B49CFF"), 0.1)
	_prism(c, Vector2(0, 8), 32.0, 8.0, 0.0, Color("B49CFF"), Color("5E3FA8"), Color("EEE6FF"))
	for k in range(3):
		var a := time * 1.6 + TAU * float(k) / 3.0
		var p := Vector2(cos(a) * 16.0, -12.0 + sin(a) * 6.0)
		c.draw_circle(p, 3.4, Color("B49CFF", 0.3))
		c.draw_circle(p, 1.8, Color("EEE6FF"))
		c.draw_line(p, p - Vector2(-sin(a), cos(a) * 0.4) * 6.0, Color("B49CFF", 0.5), 1.4)
