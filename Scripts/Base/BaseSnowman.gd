extends Node2D

## Trophy snowman in the hold, earned by defeating the Frozen Planet boss
## (BaseTrophies &"snowman"). Same build as the battlefield snowmen - two
## snowballs, stick arms, carrot nose - plus a top hat, a fluttering scarf,
## a little snow drift and a few twinkles. Drawn in mock units (scaled by
## AsteroidHangar). Presentation only.

const SNOW := Color("EEF6FB")
const SNOW_SHADE := Color("BCD0DD")
const SCARF := Color("D9534F")
const SCARF_DARK := Color("A33A37")
const HAT := Color("2B2D31")
const HAT_BAND := Color("3E8ED0")

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var r := 16.0
	var body := Vector2.ZERO
	var head := Vector2(0.0, -r * 0.95)
	var hr := r * 0.64
	# Snow drift and shadows.
	var drift := PackedVector2Array()
	for k in range(14):
		var a := TAU * float(k) / 14.0
		drift.append(Vector2(cos(a) * r * 1.6, r * 0.55 + sin(a) * r * 0.5) * (1.0 + 0.08 * sin(a * 3.0)))
	draw_colored_polygon(Palette.offset_points(drift, Vector2(2, 2)), Color(0, 0, 0, 0.15))
	draw_colored_polygon(drift, SNOW_SHADE)
	draw_colored_polygon(Palette.offset_points(drift, Vector2(-1.5, -1.5)), Color(SNOW, 0.9))
	draw_circle(body + Vector2(4, 5), r, Palette.SHADOW_COLOR)
	draw_circle(head + Vector2(4, 5), hr, Palette.SHADOW_COLOR)
	# Stick arms, one waving.
	var wave := sin(_time * 2.2) * 0.25
	for side in [-1.0, 1.0]:
		var root := body + Vector2(side * r * 0.75, -r * 0.35)
		var tilt := wave if side > 0.0 else 0.0
		var tip: Vector2 = root + Vector2(side * r * 0.95, -r * 0.55).rotated(side * tilt)
		draw_line(root, tip, Palette.GOBLIN_WOOD_DARK, 2.2)
		var twig := tip.lerp(root, 0.35)
		draw_line(twig, twig + Vector2(side * r * 0.22, -r * 0.3), Palette.GOBLIN_WOOD_DARK, 1.6)
	# Body with coal buttons.
	draw_circle(body, r, SNOW_SHADE)
	draw_circle(body + Vector2(-r * 0.12, -r * 0.12), r * 0.86, SNOW)
	for k in range(3):
		draw_circle(body + Vector2(0.0, -r * 0.35 + float(k) * r * 0.35), r * 0.09, HAT)
	# Scarf with a fluttering tail.
	var flutter := sin(_time * 3.0) * 0.12
	draw_colored_polygon(_ellipse(head + Vector2(0.0, hr * 0.78), hr * 1.02, 0.42), SCARF)
	var tail_root := head + Vector2(hr * 0.45, hr * 0.85)
	draw_colored_polygon(PackedVector2Array([tail_root, tail_root + Vector2(hr * 0.75, hr * 0.9).rotated(flutter), tail_root + Vector2(hr * 0.2, hr * 1.05).rotated(flutter)]), SCARF_DARK)
	# Head.
	draw_circle(head, hr, SNOW_SHADE)
	draw_circle(head + Vector2(-hr * 0.12, -hr * 0.12), hr * 0.86, SNOW)
	for side in [-1.0, 1.0]:
		draw_circle(head + Vector2(side * hr * 0.32, -hr * 0.05), hr * 0.11, HAT)
	var nose := head + Vector2(0.0, hr * 0.18)
	draw_colored_polygon(PackedVector2Array([nose + Vector2(0.0, -hr * 0.12), nose + Vector2(hr * 0.8, hr * 0.08), nose + Vector2(0.0, hr * 0.14)]), Color("F08A24"))
	# Top hat.
	var brim := head + Vector2(0.0, -hr * 0.78)
	draw_colored_polygon(_ellipse(brim, hr * 0.95, 0.35), HAT)
	draw_rect(Rect2(brim + Vector2(-hr * 0.55, -hr * 1.05), Vector2(hr * 1.1, hr * 1.05)), HAT)
	draw_rect(Rect2(brim + Vector2(-hr * 0.55, -hr * 0.32), Vector2(hr * 1.1, hr * 0.22)), HAT_BAND)
	draw_rect(Rect2(brim + Vector2(-hr * 0.5, -hr * 1.02), Vector2(hr * 0.25, hr * 0.95)), Color(1, 1, 1, 0.12))
	# Twinkles around it.
	for k in range(3):
		var ph := fposmod(_time * 0.6 + float(k) * 0.33, 1.0)
		var at: Vector2 = [Vector2(-r * 1.4, -r * 1.6), Vector2(r * 1.5, -r * 0.9), Vector2(-r * 1.1, r * 0.2)][k]
		var s := 3.0 * sin(PI * ph)
		draw_line(at - Vector2(s, 0), at + Vector2(s, 0), Color(1, 1, 1, 0.9), 1.0)
		draw_line(at - Vector2(0, s), at + Vector2(0, s), Color(1, 1, 1, 0.9), 1.0)


func _ellipse(center: Vector2, radius: float, squash: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in range(14):
		var a := TAU * float(k) / 14.0
		points.append(center + Vector2(cos(a) * radius, sin(a) * radius * squash))
	return points
