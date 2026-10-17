extends Node2D

## Heavy cannon turret visual (style A): short thick barrel, hexagonal head.

var _drawn_rotation: float = INF


func _process(_delta: float) -> void:
	if not is_equal_approx(global_rotation, _drawn_rotation):
		queue_redraw()


func _draw() -> void:
	_drawn_rotation = global_rotation
	var shadow := Palette.local_shadow_offset(self)
	Palette.draw_turret_base(self, 20.0, shadow)

	var barrel := Rect2(2.0, -7.0, 22.0, 14.0)
	draw_rect(Rect2(barrel.position + shadow * 0.5, barrel.size), Palette.SHADOW_COLOR)
	draw_rect(barrel, Palette.MECH)
	draw_rect(Rect2(2.0, -7.0, 22.0, 4.0), Palette.MECH_LIGHT)
	draw_rect(Rect2(20.0, -8.5, 7.0, 17.0), Palette.ACCENT)

	var head := Palette.regular_polygon(6, 13.0, PI / 6.0)
	draw_colored_polygon(head, Palette.MECH)
	draw_colored_polygon(PackedVector2Array([head[3], head[4], head[5], Vector2.ZERO]), Palette.MECH_LIGHT)
	draw_circle(Vector2.ZERO, 4.0, Palette.ACCENT)
