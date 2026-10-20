extends Control

## Compact base resource pill (top-right): ◆ stored ore.
## Expedition energy and its purchase button were removed; ore is now spent on
## research, chips and locating planets. Presentation only (ResourceManager
## owns the value). Load with preload(); no class_name on purpose.

const HEIGHT: float = 30.0
const FONT_SIZE: int = 16
const PAD: float = 12.0

var _pulse: float = 0.0
var _shown: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ResourceManager.stored_ore_changed.connect(_on_ore_changed)
	_refresh()


func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(_pulse - delta * 3.0, 0.0)
		queue_redraw()


func _on_ore_changed(_amount: float) -> void:
	_refresh()


func _refresh() -> void:
	var value := floori(ResourceManager.stored_ore)
	if _shown >= 0 and value != _shown:
		_pulse = 1.0
	_shown = value
	var font := get_theme_default_font()
	var width := PAD * 2.0 + 18.0 + font.get_string_size(_ore_string(), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	# Grow leftward from the right anchor so the pill hugs the screen edge.
	offset_left = offset_right - width
	offset_bottom = offset_top + HEIGHT
	queue_redraw()


func _ore_string() -> String:
	var digits := str(maxi(_shown, 0))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return digits + out


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	Palette.draw_rounded_rect(self, Rect2(rect.position + Vector2(2.0, 3.0), rect.size), 8.0, Color(0, 0, 0, 0.3))
	Palette.draw_rounded_rect(self, rect, 8.0, Color(Palette.UI_PANEL, 0.94))
	var center := Vector2(PAD + 6.0, HEIGHT * 0.5)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -7), center + Vector2(5.5, 0), center + Vector2(0, 7), center + Vector2(-5.5, 0)]), Palette.GOLD_SHADOW)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -7), center + Vector2(5.5, 0), center + Vector2(0, 1.5), center + Vector2(-5.5, 0)]), Palette.GOLD)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -7), center + Vector2(-2, -2), center + Vector2(-5.5, 0)]), Palette.GOLD_LIGHT)
	var font := get_theme_default_font()
	var baseline: float = HEIGHT * 0.5 + FONT_SIZE * 0.36
	draw_string(font, Vector2(PAD + 18.0, baseline), _ore_string(), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE,
			Palette.UI_TEXT.lerp(Palette.GOLD, _pulse))
