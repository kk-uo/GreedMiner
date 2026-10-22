class_name ForestRoot
extends ForestTree

## Boss escape lock. Dwarves cut it with the normal tree/grave dispatch tool.
func _draw() -> void:
	if chopped:
		return
	for index in range(5):
		var angle := TAU * float(index) / 5.0
		var tip := Vector2.RIGHT.rotated(angle) * 42.0
		draw_line(Vector2.ZERO, tip, Color("6A4936"), 11.0)
		draw_line(Vector2.ZERO, tip, Color("94704A"), 4.0)
	draw_circle(Vector2.ZERO, 16.0, Color("725138"))
	if dig_progress > 0.0:
		draw_arc(Vector2.ZERO, 48.0, -PI * 0.5, -PI * 0.5 + TAU * dig_progress, 32, Color("B5D879"), 4.0)
