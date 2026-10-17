class_name ScaledUIRoot
extends Control

## Provides one consistent, configurable visual scale for CanvasLayer UI.

## Visual scale applied to all descendant controls.
@export_range(0.1, 4.0, 0.05) var ui_visual_scale: float = 1.25


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var resize_callback := Callable(self, "_apply_ui_scale")
	if not get_viewport().size_changed.is_connected(resize_callback):
		get_viewport().size_changed.connect(resize_callback)

	_apply_ui_scale()


## Converts a viewport screen position into this scaled UI's coordinates.
func screen_to_ui(screen_position: Vector2) -> Vector2:
	return screen_position / maxf(ui_visual_scale, 0.1)


## Updates the virtual UI canvas so anchors remain inside the viewport.
func _apply_ui_scale() -> void:
	var safe_scale := maxf(ui_visual_scale, 0.1)
	position = Vector2.ZERO
	scale = Vector2.ONE * safe_scale
	size = get_viewport_rect().size / safe_scale
