extends Node2D

## Takeoff-only placeholder: workers outside the ship remain visible on the
## planet. It never alters dwarf ownership, cooldowns, save data or rewards.
func _draw() -> void:
	draw_circle(Vector2(2.0, 3.0), 9.0, Color(0.0, 0.0, 0.0, 0.25))
	draw_circle(Vector2.ZERO, 8.0, Color("D7C79E"))
	draw_rect(Rect2(-8.0, -8.0, 16.0, 5.0), Color("D69A4C"))
