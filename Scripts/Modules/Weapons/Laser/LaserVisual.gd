extends Node2D

## Laser emitter visual (style A): slim lens housing with a hot core.

var _drawn_rotation: float = INF


func _process(_delta: float) -> void:
	if not is_equal_approx(global_rotation, _drawn_rotation):
		queue_redraw()


func _draw() -> void:
	_drawn_rotation = global_rotation
	var shadow := Palette.local_shadow_offset(self)
	Palette.draw_turret_base(self, 17.0, shadow)

	var emitter := Rect2(0.0, -5.0, 22.0, 10.0)
	draw_rect(Rect2(emitter.position + shadow * 0.5, emitter.size), Palette.SHADOW_COLOR)
	draw_rect(emitter, Palette.MECH)
	draw_rect(Rect2(18.0, -6.0, 6.0, 12.0), Palette.ACCENT)

	draw_circle(Vector2.ZERO, 11.0, Palette.MECH)
	draw_circle(Vector2(-3.0, -3.0), 4.0, Palette.MECH_LIGHT)
	draw_circle(Vector2(2.0, 0.0), 4.0, Palette.SHOT_CORE)
