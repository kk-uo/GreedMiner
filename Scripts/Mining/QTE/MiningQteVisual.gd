class_name MiningQteVisual
extends RefCounted

## Presentation-only drawing for mining QTEs (style A): the yellow "!" marker,
## the salvage crate and gold ore shards. No gameplay depends on this file.

const MARKER_RADIUS: float = 13.0
## Markers and crates are drawn larger than their base geometry so they stay
## readable at battle zoom.
const MARKER_SCALE: float = 1.35
const CHEST_SCALE: float = 1.3


## Yellow "!" badge. age drives pop-in and bob; remaining (1..0) the timer ring.
## round_badge: Precision Mining uses a round badge, Ore Burst a hexagon.
static func draw_marker(canvas: CanvasItem, center: Vector2, age: float, remaining: float, round_badge: bool, alpha: float = 1.0) -> void:
	var pop: float = _back_out(clampf(age / 0.25, 0.0, 1.0))
	var pulse: float = 1.0 + (0.08 * sin(age * 14.0) if remaining < 0.34 else 0.0)
	var size: float = pop * pulse
	if size <= 0.01 or alpha <= 0.01:
		return
	canvas.draw_set_transform(center * (1.0 - MARKER_SCALE), 0.0, Vector2.ONE * MARKER_SCALE)
	var bob := Vector2(0.0, sin(age * 5.0) * 2.5)
	var c: Vector2 = center + bob
	var radius: float = MARKER_RADIUS * size
	# Ground shadow and pointer down to the module.
	canvas.draw_circle(center + Vector2(4.0, 30.0), radius * 0.6, Color(0, 0, 0, 0.22 * alpha))
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-5.0, radius - 1.0), c + Vector2(5.0, radius - 1.0), c + Vector2(0.0, radius + 8.0 * size),
	]), Color(Palette.UI_PANEL, alpha))
	# Timer ring.
	canvas.draw_arc(c, radius + 6.0, 0.0, TAU, 32, Color(Palette.UI_PANEL, 0.45 * alpha), 3.0)
	if remaining > 0.0:
		canvas.draw_arc(c, radius + 6.0, -PI * 0.5, -PI * 0.5 + TAU * remaining, 32, Color(Palette.GOLD_LIGHT, alpha), 2.4)
	var badge: PackedVector2Array
	if round_badge:
		badge = Palette.regular_polygon(20, radius + 2.5)
	else:
		badge = Palette.regular_polygon(6, radius + 3.5, PI / 6.0)
	canvas.draw_colored_polygon(Palette.offset_points(badge, c), Color(Palette.UI_PANEL, alpha))
	var inner := PackedVector2Array()
	for point in badge:
		inner.append(c + point * 0.82)
	canvas.draw_colored_polygon(inner, Color(Palette.GOLD, alpha))
	# Lit top-left facet.
	canvas.draw_circle(c + Vector2(-3.5, -3.5) * size, radius * 0.38, Color(Palette.GOLD_LIGHT, 0.55 * alpha))
	if round_badge:
		# Tiny dial ticks mark the skill-check event.
		for index in range(4):
			var direction := Vector2.UP.rotated(index * TAU / 4.0)
			canvas.draw_line(c + direction * radius * 0.62, c + direction * radius * 0.78, Color(Palette.GOLD_SHADOW, alpha), 1.4)
	# The "!".
	var mark := Color(Palette.UI_PANEL, alpha)
	Palette.draw_rounded_rect(canvas, Rect2(c + Vector2(-2.2, -8.0) * size, Vector2(4.4, 10.5) * size), 2.0 * size, mark)
	canvas.draw_circle(c + Vector2(0.0, 6.4) * size, 2.3 * size, mark)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Salvage crate seen from above. open: 0..1 lid halves slide apart.
## glow: 0..1 seam pulse. scale / alpha for pop-in and expiry.
static func draw_chest(canvas: CanvasItem, center: Vector2, open: float, glow: float, scale: float = 1.0, alpha: float = 1.0) -> void:
	if alpha <= 0.01 or scale <= 0.01:
		return
	scale *= CHEST_SCALE
	var half := Vector2(16.0, 12.0) * scale
	var body := Rect2(center - half, half * 2.0)
	Palette.draw_rounded_rect(canvas, Rect2(body.position + Vector2(4.0, 5.0), body.size), 4.0 * scale, Color(0, 0, 0, 0.28 * alpha))
	Palette.draw_rounded_rect(canvas, body, 4.0 * scale, Color(Palette.MECH, alpha))
	var inner := body.grow(-2.5 * scale)
	# Interior (visible once open): gold glow.
	Palette.draw_rounded_rect(canvas, inner, 3.0 * scale, Color("120F0D", alpha))
	if open > 0.0:
		canvas.draw_circle(center, 9.0 * scale * (0.6 + open), Color(Palette.GOLD, 0.35 * open * alpha))
		canvas.draw_circle(center, 5.0 * scale, Color(Palette.GOLD_LIGHT, open * alpha))
	# Two lid halves, sliding left / right.
	var slide: float = open * 9.0 * scale
	var lid_w: float = inner.size.x * 0.5
	for side in [-1.0, 1.0]:
		var x: float = center.x + (side * slide) + (0.0 if side > 0 else -lid_w)
		var lid := Rect2(Vector2(x, inner.position.y), Vector2(lid_w, inner.size.y))
		Palette.draw_rounded_rect(canvas, lid, 2.5 * scale, Color(Palette.SHIP_PART_EDGE, alpha))
		Palette.draw_rounded_rect(canvas, Rect2(lid.position, lid.size - Vector2(1.5, 1.5) * scale), 2.5 * scale, Color(Palette.SHIP_BODY, alpha))
		# Hazard band across the lid.
		var band := Rect2(Vector2(lid.position.x, center.y - 3.0 * scale), Vector2(lid.size.x, 6.0 * scale))
		canvas.draw_rect(band, Color(Palette.MECH, alpha))
		var stripe_x: float = band.position.x + 1.0 * scale
		while stripe_x < band.end.x - 2.0 * scale:
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(stripe_x, band.end.y), Vector2(stripe_x + 2.5 * scale, band.position.y),
				Vector2(stripe_x + 5.0 * scale, band.position.y), Vector2(stripe_x + 2.5 * scale, band.end.y),
			]), Color(Palette.ACCENT, alpha))
			stripe_x += 5.5 * scale
	# Glowing seam while closed.
	if open < 0.2 and glow > 0.0:
		canvas.draw_line(center + Vector2(0.0, -half.y + 2.0), center + Vector2(0.0, half.y - 2.0), Color(Palette.GOLD, (0.4 + 0.6 * glow) * alpha), 2.0 * scale)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		canvas.draw_circle(center + corner * (half - Vector2(2.5, 2.5) * scale), 1.3 * scale, Color(Palette.MECH_LIGHT, alpha))


## Small gold ore shard (diamond, lit facet).
static func draw_shard(canvas: CanvasItem, center: Vector2, size: float, angle: float, alpha: float = 1.0) -> void:
	if alpha <= 0.01 or size <= 0.05:
		return
	var points := PackedVector2Array([Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)])
	var lit := PackedVector2Array([Vector2(0, -5), Vector2(4, 0), Vector2(0, 1), Vector2(-4, 0)])
	var shine := PackedVector2Array([Vector2(0, -5), Vector2(-1.5, -1.5), Vector2(-4, 0)])
	canvas.draw_colored_polygon(_xf(points, center, size, angle), Color(Palette.GOLD_SHADOW, alpha))
	canvas.draw_colored_polygon(_xf(lit, center, size, angle), Color(Palette.GOLD, alpha))
	canvas.draw_colored_polygon(_xf(shine, center, size, angle), Color(Palette.GOLD_LIGHT, alpha))


static func _xf(points: PackedVector2Array, center: Vector2, size: float, angle: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(center + (point * size).rotated(angle))
	return result


static func _back_out(x: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


# ==========================================
# Compact world-space text (QTE counters, results, "+X Ore")
# ==========================================

const THEME_PATH: String = "res://Resources/UI/greedminer_theme.tres"
static var _font: Font


## The game's UI font (Chakra Petch from the project theme), cached.
static func ui_font() -> Font:
	if _font == null:
		var theme := load(THEME_PATH) as Theme
		if theme != null and theme.default_font != null:
			_font = theme.default_font
		else:
			_font = ThemeDB.fallback_font
	return _font


## Centred outlined text at center (baseline-adjusted), for Node2D canvases.
static func draw_text(canvas: CanvasItem, center: Vector2, text: String, font_size: int, color: Color, alpha: float = 1.0) -> void:
	if alpha <= 0.01 or text.is_empty():
		return
	var font := ui_font()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := Vector2(center.x - width * 0.5, center.y + font_size * 0.36)
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(Palette.UI_PANEL, 0.9 * alpha))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, color.a * alpha))


## Small dark rounded backing plate behind a counter.
static func draw_plate(canvas: CanvasItem, rect: Rect2, alpha: float = 1.0, border: Color = Color(0, 0, 0, 0)) -> void:
	Palette.draw_rounded_rect(canvas, Rect2(rect.position + Vector2(2.0, 3.0), rect.size), 6.0, Color(0, 0, 0, 0.25 * alpha))
	Palette.draw_rounded_rect(canvas, rect, 6.0, Color(Palette.UI_PANEL, 0.88 * alpha))
	if border.a > 0.0:
		var pts := Palette.rounded_rect_points(rect, 6.0)
		pts.append(pts[0])
		canvas.draw_polyline(pts, Color(border, border.a * alpha), 1.5)


## Ore Burst click particle: a little gold nugget chip.
static func draw_ore_chip(canvas: CanvasItem, center: Vector2, size: float, angle: float, alpha: float) -> void:
	draw_shard(canvas, center, size, angle, alpha)
