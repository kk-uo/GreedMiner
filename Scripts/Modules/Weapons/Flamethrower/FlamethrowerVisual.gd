extends Node2D

## Flamethrower turret (style A). Rendering only; Flamethrower.gd aims and
## fires. Points along local +X: a round red fuel tank with hazard stripes on
## the base, a hose, and a long nozzle with a flickering pilot flame that
## flares while it sprays.

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var shadow := Palette.local_shadow_offset(self)
	Palette.draw_turret_base(self, 20.0, shadow)
	var weapon := get_parent() as Flamethrower
	var spraying := weapon != null and weapon.is_spraying()
	# Nozzle barrel with a flared tip.
	var barrel := PackedVector2Array([Vector2(2, -5.5), Vector2(22, -5.5), Vector2(28, -8.5), Vector2(28, 8.5), Vector2(22, 5.5), Vector2(2, 5.5)])
	draw_colored_polygon(Palette.offset_points(barrel, shadow * 0.5), Palette.SHADOW_COLOR)
	draw_colored_polygon(barrel, Palette.MECH)
	draw_rect(Rect2(21.0, -6.5, 3.5, 13.0), Palette.ACCENT)
	draw_line(Vector2(4, -3), Vector2(21, -3), Palette.MECH_LIGHT, 2.0)
	# Fuel tank: red cylinder seen from above with hazard stripes and a cap.
	draw_circle(Vector2(-4.0, 0.0) + shadow * 0.5, 13.0, Palette.SHADOW_COLOR)
	draw_circle(Vector2(-4.0, 0.0), 13.0, Color("7A1A1C"))
	draw_circle(Vector2(-5.0, -1.0), 11.0, Color("C8352B"))
	for k in range(3):
		var a := -0.9 + float(k) * 0.9
		draw_line(Vector2(-3.0, 0.0) + Vector2.RIGHT.rotated(a + PI) * 4.0, Vector2(-3.0, 0.0) + Vector2.RIGHT.rotated(a + PI) * 9.0, Palette.UI_PANEL, 2.0)
	draw_circle(Vector2(-6.0, -3.0), 3.0, Palette.MECH_LIGHT)
	draw_circle(Vector2(-6.0, -3.0), 1.6, Palette.MECH)
	# Hose from tank to nozzle.
	draw_polyline(PackedVector2Array([Vector2(4, 6), Vector2(8, 9), Vector2(14, 5)]), Palette.MECH, 2.0)
	# Pilot flame at the tip.
	var flicker := 0.7 + 0.3 * sin(_time * 23.0) * sin(_time * 7.0)
	var size := (5.5 if spraying else 2.6) * flicker
	draw_circle(Vector2(30.0, 0.0), size * 1.7, Color(Color("F08A24"), 0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(28.0, -size * 0.6), Vector2(28.0 + size * 2.2, 0.0), Vector2(28.0, size * 0.6)]), Color("F08A24"))
	draw_colored_polygon(PackedVector2Array([Vector2(28.0, -size * 0.3), Vector2(28.0 + size * 1.3, 0.0), Vector2(28.0, size * 0.3)]), Color("FFE08A"))
