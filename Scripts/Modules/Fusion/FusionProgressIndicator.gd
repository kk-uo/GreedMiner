class_name FusionProgressIndicator
extends Node2D

var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var label_text: String = "FUSING"


func _ready() -> void:
	z_index = 40
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-36.0, -47.0, 72.0, 12.0)
	Palette.draw_rounded_rect(self, rect, 5.0, Color(Palette.UI_PANEL, 0.94))
	if progress > 0.001:
		var fill_width := maxf((rect.size.x - 4.0) * progress, 2.0)
		draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), Vector2(fill_width, rect.size.y - 4.0)), Palette.ACCENT)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-36.0, -52.0), label_text, HORIZONTAL_ALIGNMENT_CENTER, 72.0, 9, Palette.UI_TEXT)
