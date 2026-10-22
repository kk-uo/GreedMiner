extends Control

## Small geometric combat HUD icons, using the existing ship/UI palette.
@export_enum("Ship", "Flag", "Skull") var icon: int = 0


func _draw() -> void:
	var s := minf(size.x, size.y) / 24.0
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE * s)
	match icon:
		0:
			# Top-down ship silhouette with the orange industrial accent.
			draw_colored_polygon(PackedVector2Array([Vector2(0, -10), Vector2(7, -5), Vector2(9, 7), Vector2(5, 10), Vector2(-5, 10), Vector2(-9, 7), Vector2(-7, -5)]), Palette.SHIP_BODY)
			draw_rect(Rect2(-4, -4, 8, 9), Palette.MECH)
			draw_rect(Rect2(-2, -2, 4, 5), Palette.ACCENT)
			draw_rect(Rect2(-7, 7, 4, 2), Palette.ACCENT)
			draw_rect(Rect2(3, 7, 4, 2), Palette.ACCENT)
		1:
			# Wave flag on a light pole, with the same warm orange as the ship.
			draw_rect(Rect2(-7, -10, 2, 20), Palette.SHIP_BODY)
			draw_colored_polygon(PackedVector2Array([Vector2(-5, -9), Vector2(8, -9), Vector2(5, -4), Vector2(8, 1), Vector2(-5, 1)]), Palette.ACCENT)
			draw_rect(Rect2(-9, 9, 6, 2), Palette.SHIP_SHADOW)
		2:
			# Cream skull, readable at the same size as the wave flag.
			draw_circle(Vector2(0, -2), 8.5, Palette.SHIP_BODY)
			draw_rect(Rect2(-5, 3, 10, 6), Palette.SHIP_BODY)
			draw_circle(Vector2(-3.5, -2), 2.0, Palette.MECH)
			draw_circle(Vector2(3.5, -2), 2.0, Palette.MECH)
			draw_rect(Rect2(-1, 2, 2, 2), Palette.MECH)
			for x in [-3.0, 0.0, 3.0]:
				draw_rect(Rect2(x - 0.5, 6, 1, 3), Palette.MECH)
