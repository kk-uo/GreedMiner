extends RefCounted

## Magic Stall art (design B "runestone circle"): a round stone dais with a
## slowly turning ring of dwarven runes, four standing runestones that beam
## cyan light to the artifact floating in the middle. Same rune set and cyan
## as the Warehouse vault. Drawn by AsteroidHangar in mock coordinates (the
## canvas transform already applies LAYOUT_SCALE).
## Load with preload(); no class_name on purpose.
##
## Dormant (no artifact yet): dull runes, no beams, no artifact. The first
## artifact wakes it: runes light up one after another (wake 0..1).

## Mock-canvas centre of the dais and the size of its clickable area.
const CENTER := Vector2(282.0, 505.0)
const HIT_RECT := Rect2(CENTER - Vector2(62.0, 50.0), Vector2(124.0, 100.0))
## Design units to mock units.
const K: float = 0.62
## Seconds the wake-up sequence takes.
const WAKE_TIME: float = 1.4

const STONE_DARK := Color("3E3128")
const STONE := Color("6E5D4F")
const STONE_LIGHT := Color("8C7866")
const RUNE := Color("5FE6EE")
const RUNE_DORMANT := Color("4A4440")
const ARTIFACT_DARK := Color("5B3FD0")
const ARTIFACT := Color("B69CFF")
const ARTIFACT_LIGHT := Color("EEE6FF")

## Angular rune strokes (unit size ±5), shared with the vault style.
const GLYPHS := [
	[Vector2(-4, -5), Vector2(0, 5), Vector2(4, -5)],
	[Vector2(-3, 5), Vector2(-3, -5), Vector2(3, -1), Vector2(-3, 2)],
	[Vector2(0, -5), Vector2(0, 5), Vector2(-4, -1), Vector2(0, 1), Vector2(4, -1)],
	[Vector2(-4, 5), Vector2(0, -5), Vector2(4, 5)],
	[Vector2(-3, -5), Vector2(3, 5), Vector2(0, 0), Vector2(3, -5), Vector2(-3, 5)],
	[Vector2(-4, 0), Vector2(4, 0), Vector2(0, -5), Vector2(0, 5)],
]
const STONES := [Vector2(-56, -46), Vector2(56, -46), Vector2(-60, 40), Vector2(60, 40)]
const ARTIFACT_AT := Vector2(0, -22)


static func contains(mock_point: Vector2) -> bool:
	return HIT_RECT.grow(8.0).has_point(mock_point)


## wake: 0..1 how far the runes have lit up (1 = fully awake; 0 = dormant).
## hovered: brighter runes and a faster ring. guide: pulsing orange outline.
static func draw(canvas: CanvasItem, time: float, wake: float, hovered: bool, guide: bool) -> void:
	var awake: bool = wake > 0.0
	var boost: float = 1.0 if hovered else 0.0

	# Shadow and dais.
	_ellipse(canvas, Vector2(6, 8), 96.0, 80.0, Palette.SHADOW_COLOR)
	_ellipse(canvas, Vector2.ZERO, 96.0, 80.0, STONE_DARK)
	_ellipse(canvas, Vector2(-2, -2), 92.0, 76.0, STONE)
	_ellipse(canvas, Vector2.ZERO, 70.0, 57.0, Color(STONE_DARK, 0.55))
	_ellipse(canvas, Vector2(-1, -1), 66.0, 53.0, Color(STONE_LIGHT, 0.35))

	# Turning rune ring on the dais rim (each rune lights in turn on waking).
	var spin: float = time * (0.26 + 0.5 * boost) if awake else 0.0
	for index in range(12):
		var angle: float = TAU * float(index) / 12.0 + spin
		var at := Vector2(cos(angle) * 80.0, sin(angle) * 80.0 * 0.8)
		var lit: float = clampf(wake * 12.0 - float(index), 0.0, 1.0)
		_glyph(canvas, at, index, 0.9, _rune_color(lit, time + float(index) * 0.3, boost), 2.2)

	# Standing runestones and their beams to the artifact.
	var orb := ARTIFACT_AT + Vector2(0.0, sin(time * 2.8) * 3.0)
	for index in range(STONES.size()):
		var stone: Vector2 = STONES[index]
		var lit: float = clampf(wake * 4.0 - float(index), 0.0, 1.0)
		if lit >= 1.0:
			_beam(canvas, stone + Vector2(0, -2), orb, time + float(index) * 0.2, 0.7 + 0.3 * boost)
	for index in range(STONES.size()):
		var stone: Vector2 = STONES[index]
		var lit: float = clampf(wake * 4.0 - float(index), 0.0, 1.0)
		_poly(canvas, [stone + Vector2(-4, -7), stone + Vector2(14, -7), stone + Vector2(16, 19), stone + Vector2(-6, 19)], Palette.SHADOW_COLOR)
		_poly(canvas, [stone + Vector2(-9, -14), stone + Vector2(9, -14), stone + Vector2(11, 12), stone + Vector2(-11, 12)], STONE_DARK)
		_poly(canvas, [stone + Vector2(-8, -13), stone + Vector2(7, -13), stone + Vector2(8, 9), stone + Vector2(-9, 9)], STONE_LIGHT)
		_glyph(canvas, stone + Vector2(0, -2), index + 2, 0.85, _rune_color(lit, time * 1.3 + float(index), boost), 1.8)

	# Centre socket, glow and the floating artifact.
	_ellipse(canvas, Vector2.ZERO, 18.0, 15.0, STONE_DARK)
	if awake:
		var glow: float = wake * (0.8 + 0.2 * sin(time * 3.0)) * (1.0 + 0.4 * boost)
		_ellipse(canvas, Vector2.ZERO, 30.0, 25.0, Color(RUNE, 0.12 * glow))
		_ellipse(canvas, Vector2.ZERO, 16.0, 13.0, Color(RUNE, 0.3 * glow))
		_artifact(canvas, orb, wake, boost)

	if hovered or guide:
		var width: float = 2.0 + (1.0 + sin(time * 4.0) if guide else 0.0)
		var outline := _ellipse_points(Vector2.ZERO, 104.0, 88.0)
		outline.append(outline[0])
		# Hover: soft cream outline; the first-artifact guide alone pulses orange.
		if hovered and not guide:
			Palette.draw_hover_outline(canvas, outline, 2.4)
		else:
			canvas.draw_polyline(outline, Palette.ACCENT if awake else Palette.UI_MUTED, width)


static func _rune_color(lit: float, phase: float, boost: float) -> Color:
	if lit <= 0.0:
		return RUNE_DORMANT
	var pulse: float = 0.6 + 0.4 * sin(phase * 2.6)
	var bright: Color = RUNE.lerp(Color(1, 1, 1), 0.25 * boost)
	return RUNE_DORMANT.lerp(Color(bright, clampf(pulse + 0.3 * boost, 0.0, 1.0)), lit)


static func _beam(canvas: CanvasItem, from: Vector2, to: Vector2, time: float, alpha: float) -> void:
	# Dashed line whose dashes flow toward the artifact.
	var a := _at(from)
	var b := _at(to)
	var length := a.distance_to(b)
	var direction := (b - a) / maxf(length, 0.001)
	var dash: float = 2.2
	var gap: float = 2.8
	var offset: float = fposmod(time * 9.0, dash + gap)
	var s: float = offset - (dash + gap)
	while s < length:
		var s0 := maxf(s, 0.0)
		var s1 := minf(s + dash, length)
		if s1 > s0:
			canvas.draw_line(a + direction * s0, a + direction * s1, Color(RUNE, 0.9 * alpha), 1.2)
		s += dash + gap


static func _artifact(canvas: CanvasItem, at: Vector2, wake: float, boost: float) -> void:
	var s: float = clampf(wake * 1.4 - 0.4, 0.0, 1.0) * 1.1
	if s <= 0.0:
		return
	_ellipse(canvas, Vector2(3, 3), 8.0 * s, 3.0 * s, Color(0, 0, 0, 0.25))
	_ellipse(canvas, at, 18.0 * s * (1.0 + 0.3 * boost), 18.0 * s * (1.0 + 0.3 * boost), Color(ARTIFACT, 0.16))
	_ellipse(canvas, at, 11.0 * s, 11.0 * s, Color(ARTIFACT, 0.3))
	_poly(canvas, [at + Vector2(0, -10) * s, at + Vector2(8, -2) * s, at + Vector2(5, 8) * s, at + Vector2(-5, 8) * s, at + Vector2(-8, -2) * s], ARTIFACT_DARK)
	_poly(canvas, [at + Vector2(0, -10) * s, at + Vector2(8, -2) * s, at + Vector2(0, 1) * s, at + Vector2(-8, -2) * s], ARTIFACT)
	_poly(canvas, [at + Vector2(0, -10) * s, at + Vector2(-8, -2) * s, at + Vector2(-1, -3) * s], ARTIFACT_LIGHT)


# ------------------------------------------------------------------ helpers
## Design units (relative to the dais centre) to mock coordinates.
static func _at(point: Vector2) -> Vector2:
	return CENTER + point * K


static func _poly(canvas: CanvasItem, points: Array, color: Color) -> void:
	var mapped := PackedVector2Array()
	for point in points:
		mapped.append(_at(point))
	canvas.draw_colored_polygon(mapped, color)


static func _ellipse_points(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(32):
		var angle: float = TAU * float(index) / 32.0
		points.append(_at(center + Vector2(cos(angle) * rx, sin(angle) * ry)))
	return points


static func _ellipse(canvas: CanvasItem, center: Vector2, rx: float, ry: float, color: Color) -> void:
	canvas.draw_colored_polygon(_ellipse_points(center, rx, ry), color)


static func _glyph(canvas: CanvasItem, at: Vector2, index: int, size: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for point in GLYPHS[index % GLYPHS.size()]:
		points.append(_at(at + (point as Vector2) * size))
	canvas.draw_polyline(points, color, width * K)
