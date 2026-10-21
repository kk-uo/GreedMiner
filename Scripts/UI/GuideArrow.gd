extends RefCounted

## The tutorials' pointer arrow (base TutorialGuide, battle MiningTutorial):
## a notched arrowhead on a rounded shaft in the accent orange, lit on one
## side, with a soft glow and no outline. Also the "scroll down" pill.
## Load with preload(); no class_name on purpose.

const LIGHT := Color("FFC27A")


## Draws the arrow with its tip at `tip`, pointing along `direction`.
## `pulse` (0..1) breathes the glow.
static func draw(ci: CanvasItem, tip: Vector2, direction: Vector2, pulse: float = 0.5) -> void:
	var d := direction.normalized()
	var s := d.orthogonal()
	const HEAD := 26.0
	const HALF := 16.0
	const NOTCH := 9.0
	const SHAFT := 24.0
	const SHAFT_HALF := 5.5
	var neck := tip - d * (HEAD - NOTCH)
	var tail := tip - d * (HEAD + SHAFT)
	# Soft glow.
	var glow_at := tip - d * HEAD * 0.7
	for k in range(3):
		ci.draw_circle(glow_at, 22.0 + 9.0 * float(k), Color(Palette.ACCENT, (0.09 - 0.025 * float(k)) * (0.6 + 0.8 * pulse)))
	# Faint drop shadow (no outline).
	var off := Vector2(2.0, 4.0)
	var head := PackedVector2Array([tip, tip - d * HEAD + s * HALF, neck, tip - d * HEAD - s * HALF])
	var shaft := PackedVector2Array([neck + s * SHAFT_HALF, tail + s * SHAFT_HALF, tail - s * SHAFT_HALF, neck - s * SHAFT_HALF])
	ci.draw_colored_polygon(Palette.offset_points(shaft, off), Color(0, 0, 0, 0.16))
	ci.draw_circle(tail + off, SHAFT_HALF, Color(0, 0, 0, 0.16))
	ci.draw_colored_polygon(Palette.offset_points(head, off), Color(0, 0, 0, 0.16))
	# Shaft with a round tail, then the head; the +side half is lit.
	ci.draw_colored_polygon(shaft, Palette.ACCENT)
	ci.draw_circle(tail, SHAFT_HALF, Palette.ACCENT)
	ci.draw_colored_polygon(PackedVector2Array([neck + s * SHAFT_HALF, tail + s * SHAFT_HALF, tail, neck]), LIGHT)
	ci.draw_colored_polygon(head, Palette.ACCENT)
	ci.draw_colored_polygon(PackedVector2Array([tip, tip - d * HEAD + s * HALF, neck]), LIGHT)
	ci.draw_circle(tip - d * 6.0 + s * 2.0, 1.8, Color(1, 1, 1, 0.75))


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
