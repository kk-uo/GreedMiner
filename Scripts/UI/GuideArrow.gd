extends RefCounted

## The tutorials' pointer (user pick D "lock-on"): four cream corner
## brackets with a dark ink outline close in on the target and breathe, and
## a small orange triangle with an ink outline points at it. Flat, no glow.
## Callers (base TutorialGuide, battle MiningTutorial, ArtifactTutorialHint)
## draw draw_lock / draw_lock_circle round the target and draw() beside it.
## Also the "scroll down" pill.
## Load with preload(); no class_name on purpose.

const INK := Color("2B1F17")
const CREAM := Color("F2E3C6")
const LIGHT := Color("FFC27A")
const TRI_LENGTH := 15.0
const TRI_HALF := 10.0
const BRACKET := 14.0


static func _outlined(ci: CanvasItem, points: PackedVector2Array, fill: Color, ink: float) -> void:
	for poly in Geometry2D.offset_polygon(points, ink, Geometry2D.JOIN_ROUND):
		ci.draw_colored_polygon(poly, INK)
	ci.draw_colored_polygon(points, fill)


## Small orange triangle with its tip at `tip`, pointing along `direction`.
## `pulse` (0..1) is accepted for older callers and ignored (no glow).
static func draw(ci: CanvasItem, tip: Vector2, direction: Vector2, _pulse: float = 0.5) -> void:
	var d := direction.normalized()
	var s := d.orthogonal()
	var tri := PackedVector2Array([tip, tip - d * TRI_LENGTH + s * TRI_HALF, tip - d * TRI_LENGTH - s * TRI_HALF])
	ci.draw_colored_polygon(Palette.offset_points(tri, Vector2(1.5, 3.0)), Color(0, 0, 0, 0.3))
	_outlined(ci, tri, Palette.ACCENT, 2.5)


## Four corner brackets round `rect` that close in and breathe with `time`.
static func draw_lock(ci: CanvasItem, rect: Rect2, time: float) -> void:
	var pull := 5.0 * (0.5 + 0.5 * cos(time * TAU * 1.2))
	var r := rect.grow(4.0 + pull)
	var arm := minf(BRACKET, minf(r.size.x, r.size.y) * 0.4)
	var corners := [
		[r.position, Vector2.RIGHT, Vector2.DOWN],
		[Vector2(r.end.x, r.position.y), Vector2.LEFT, Vector2.DOWN],
		[r.end, Vector2.LEFT, Vector2.UP],
		[Vector2(r.position.x, r.end.y), Vector2.RIGHT, Vector2.UP],
	]
	for corner in corners:
		var at: Vector2 = corner[0]
		var bracket := PackedVector2Array([at + corner[1] * arm, at, at + corner[2] * arm])
		ci.draw_polyline(Palette.offset_points(bracket, Vector2(0.0, 2.0)), Color(0, 0, 0, 0.3), 5.0)
		ci.draw_polyline(bracket, INK, 6.0)
		ci.draw_polyline(bracket, CREAM, 3.0)
		for end in [bracket[0], bracket[2]]:
			ci.draw_circle(end, 3.0, INK)
			ci.draw_circle(end, 1.5, CREAM)
		ci.draw_circle(at, 3.0, INK)
		ci.draw_circle(at, 1.5, CREAM)


## The same lock-on round a circular target (its bounding square).
static func draw_lock_circle(ci: CanvasItem, center: Vector2, radius: float, time: float) -> void:
	draw_lock(ci, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), time)


## "Scroll down" hint: a pill with the text and a stack of bouncing chevrons,
## centred on `at`. `down` false points up.
static func draw_scroll_hint(ci: CanvasItem, at: Vector2, text: String, time: float, down: bool = true) -> void:
	var font: Font = ThemeDB.fallback_font if not (ci is Control) else (ci as Control).get_theme_default_font()
	var size := 14
	var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pill := Rect2(at - Vector2(text_w * 0.5 + 18.0, 15.0), Vector2(text_w + 36.0, 30.0))
	ci.draw_colored_polygon(Palette.rounded_rect_points(pill.grow(2.0), 17.0), Color(0, 0, 0, 0.25))
	ci.draw_colored_polygon(Palette.rounded_rect_points(pill, 15.0), Palette.ACCENT)
	ci.draw_string(font, Vector2(pill.position.x + 18.0, at.y + 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Palette.UI_PANEL)
	var dir := 1.0 if down else -1.0
	var base_y := at.y + dir * 30.0
	for k in range(3):
		var phase := fposmod(time * 1.6 - float(k) * 0.22, 1.0)
		var alpha := sin(PI * phase)
		var y := base_y + dir * (float(k) * 11.0 + phase * 6.0)
		var pts := PackedVector2Array([
			Vector2(at.x - 12.0, y - dir * 5.0), Vector2(at.x, y + dir * 5.0), Vector2(at.x + 12.0, y - dir * 5.0),
			Vector2(at.x + 12.0, y - dir * 1.0), Vector2(at.x, y + dir * 9.0), Vector2(at.x - 12.0, y - dir * 1.0),
		])
		ci.draw_colored_polygon(pts, Color(Palette.ACCENT, alpha))
