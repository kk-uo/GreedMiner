extends RefCounted

## Shared flat chip artwork and labels used by the Laboratory, the Hangar
## sockets and the Warehouse. Load with preload(); no class_name on purpose.
##
## Every chip is a dark package with pins, a coloured die and a glyph.
## Colours and short effect texts are presentation only; the gameplay numbers
## live in ChipConfiguration.

const PIN := Color("8D857C")
const PACKAGE := Color("3B3530")
const GLYPH := Color("1D1714")

const STYLES := {
	&"attack_chip": {"color": Color("F08A24"), "effect": "+1 POWER", "glyph": &"arrow"},
	&"attack_speed_chip": {"color": Color("4FC3D9"), "effect": "+20% FIRE RATE", "glyph": &"chevrons"},
	&"damage_chip": {"color": Color("FF5A4A"), "effect": "+20% DMG", "glyph": &"star"},
	&"range_chip": {"color": Color("72D990"), "effect": "+35% RANGE", "glyph": &"range"},
	&"skill_chip": {"color": Color("B07CFF"), "effect": "-1s CAST", "glyph": &"clock"},
}


static func get_color(chip_id: StringName) -> Color:
	return STYLES.get(chip_id, {}).get("color", Color("A89C88"))


static func get_effect_text(chip_id: StringName) -> String:
	return TranslationServer.translate(String(STYLES.get(chip_id, {}).get("effect", "")))


static func get_display_name(chip_id: StringName) -> String:
	var definition := ChipManager.configuration.get_chip(chip_id)
	return TranslationServer.translate(definition.chip_name.to_upper()) if definition != null else String(chip_id).to_upper()


## "R2·C3" label for a ship cell (1-based, as shown in the Hangar).
static func cell_label(cell: Vector2i) -> String:
	return "R%d·C%d" % [cell.x + 1, cell.y + 1]


## Draws a chip of `chip_id` filling a square of side `side` centred on `center`.
static func draw_chip(canvas: CanvasItem, chip_id: StringName, center: Vector2, side: float, alpha: float = 1.0, glow: bool = false) -> void:
	var s := side / 44.0
	var origin := center - Vector2(22.0, 22.0) * s
	var color := get_color(chip_id)
	if glow:
		canvas.draw_circle(center, 21.0 * s, Color(color, 0.22 * alpha))
	var pin_color := Color(PIN, alpha)
	for x in [12.0, 20.5, 29.0]:
		Palette.draw_rounded_rect(canvas, Rect2(origin + Vector2(x, 1.0) * s, Vector2(3.0, 6.0) * s), 1.0 * s, pin_color)
		Palette.draw_rounded_rect(canvas, Rect2(origin + Vector2(x, 37.0) * s, Vector2(3.0, 6.0) * s), 1.0 * s, pin_color)
		Palette.draw_rounded_rect(canvas, Rect2(origin + Vector2(1.0, x) * s, Vector2(6.0, 3.0) * s), 1.0 * s, pin_color)
		Palette.draw_rounded_rect(canvas, Rect2(origin + Vector2(37.0, x) * s, Vector2(6.0, 3.0) * s), 1.0 * s, pin_color)
	Palette.draw_rounded_rect(canvas, Rect2(origin + Vector2(6.0, 6.0) * s, Vector2(32.0, 32.0) * s), 6.0 * s, Color(PACKAGE, alpha))
	Palette.draw_rounded_rect(canvas, Rect2(origin + Vector2(9.0, 9.0) * s, Vector2(26.0, 26.0) * s), 4.0 * s, Color(color, alpha))
	# Soft highlight on the upper part of the die.
	canvas.draw_colored_polygon(PackedVector2Array([
		origin + Vector2(10.0, 10.0) * s, origin + Vector2(34.0, 10.0) * s,
		origin + Vector2(34.0, 16.0) * s, origin + Vector2(10.0, 22.0) * s,
	]), Color(1.0, 1.0, 1.0, 0.2 * alpha))
	_draw_glyph(canvas, StringName(STYLES.get(chip_id, {}).get("glyph", &"dot")), origin, s, Color(GLYPH, alpha))


static func _draw_glyph(canvas: CanvasItem, glyph: StringName, o: Vector2, s: float, color: Color) -> void:
	var w := 3.2 * s
	match glyph:
		&"arrow":
			canvas.draw_line(o + Vector2(15.0, 29.0) * s, o + Vector2(28.0, 16.0) * s, color, w, true)
			canvas.draw_polyline(PackedVector2Array([o + Vector2(20.0, 15.0) * s, o + Vector2(29.0, 15.0) * s, o + Vector2(29.0, 24.0) * s]), color, w, true)
		&"chevrons":
			canvas.draw_polyline(PackedVector2Array([o + Vector2(14.0, 15.0) * s, o + Vector2(21.0, 22.0) * s, o + Vector2(14.0, 29.0) * s]), color, w, true)
			canvas.draw_polyline(PackedVector2Array([o + Vector2(22.0, 15.0) * s, o + Vector2(29.0, 22.0) * s, o + Vector2(22.0, 29.0) * s]), color, w, true)
		&"star":
			var points := PackedVector2Array()
			for index in range(10):
				var radius := 10.0 if index % 2 == 0 else 4.4
				var angle := -PI * 0.5 + float(index) * PI / 5.0
				points.append(o + (Vector2(22.0, 22.5) + Vector2.RIGHT.rotated(angle) * radius) * s)
			canvas.draw_colored_polygon(points, color)
		&"clock":
			canvas.draw_arc(o + Vector2(22.0, 22.0) * s, 8.5 * s, 0.0, TAU, 24, color, 3.0 * s, true)
			canvas.draw_polyline(PackedVector2Array([o + Vector2(22.0, 17.0) * s, o + Vector2(22.0, 22.0) * s, o + Vector2(26.0, 24.0) * s]), color, 2.6 * s, true)
		&"range":
			canvas.draw_arc(o + Vector2(22.0, 22.0) * s, 9.0 * s, 0.0, TAU, 24, color, 2.5 * s, true)
			canvas.draw_arc(o + Vector2(22.0, 22.0) * s, 4.5 * s, 0.0, TAU, 20, color, 2.0 * s, true)
			canvas.draw_circle(o + Vector2(22.0, 22.0) * s, 1.8 * s, color)
		_:
			canvas.draw_circle(o + Vector2(22.0, 22.0) * s, 4.0 * s, color)


## Wooden crate glyph used for the Warehouse button and header.
static func draw_crate(canvas: CanvasItem, center: Vector2, side: float) -> void:
	var s := side / 28.0
	var o := center - Vector2(14.0, 14.0) * s
	canvas.draw_colored_polygon(PackedVector2Array([o + Vector2(6.0, 8.0) * s, o + Vector2(9.0, 3.0) * s, o + Vector2(19.0, 3.0) * s, o + Vector2(22.0, 8.0) * s]), Palette.GOBLIN_WOOD_LIGHT)
	Palette.draw_rounded_rect(canvas, Rect2(o + Vector2(3.0, 8.0) * s, Vector2(22.0, 17.0) * s), 3.0 * s, Palette.GOBLIN_WOOD)
	Palette.draw_rounded_rect(canvas, Rect2(o + Vector2(3.0, 8.0) * s, Vector2(22.0, 5.0) * s), 2.0 * s, Palette.GOBLIN_WOOD_LIGHT)
	canvas.draw_rect(Rect2(o + Vector2(12.0, 8.0) * s, Vector2(4.0, 17.0) * s), Palette.GOBLIN_IRON_DARK)


## Small ore gem (pentagon) used next to prices.
static func draw_ore(canvas: CanvasItem, center: Vector2, side: float) -> void:
	var s := side / 16.0
	var o := center - Vector2(8.0, 8.0) * s
	canvas.draw_colored_polygon(PackedVector2Array([o + Vector2(8.0, 1.0) * s, o + Vector2(14.0, 5.0) * s, o + Vector2(12.0, 14.0) * s, o + Vector2(4.0, 14.0) * s, o + Vector2(2.0, 5.0) * s]), Palette.GOLD)
	canvas.draw_colored_polygon(PackedVector2Array([o + Vector2(8.0, 1.0) * s, o + Vector2(14.0, 5.0) * s, o + Vector2(8.0, 7.0) * s, o + Vector2(2.0, 5.0) * s]), Palette.GOLD_LIGHT)


## Lightning bolt glyph for Energy.
static func draw_bolt(canvas: CanvasItem, center: Vector2, side: float, color: Color = Palette.ACCENT) -> void:
	var s := side / 16.0
	var o := center - Vector2(8.0, 8.0) * s
	canvas.draw_colored_polygon(PackedVector2Array([
		o + Vector2(9.0, 1.0) * s, o + Vector2(3.0, 9.0) * s, o + Vector2(7.5, 9.0) * s,
		o + Vector2(6.0, 15.0) * s, o + Vector2(13.0, 6.0) * s, o + Vector2(8.5, 6.0) * s,
	]), color)


## Control that draws one chip; set chip_id and redraw.
class ChipIcon:
	extends Control

	const ChipVisual := preload("res://Scripts/UI/Chips/ChipVisual.gd")

	var chip_id: StringName
	var glow: bool = false
	var dim: bool = false

	func _init(id: StringName = &"", side: float = 40.0, with_glow: bool = false) -> void:
		chip_id = id
		glow = with_glow
		custom_minimum_size = Vector2(side, side)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_chip(id: StringName) -> void:
		chip_id = id
		queue_redraw()

	func _draw() -> void:
		if chip_id.is_empty():
			return
		ChipVisual.draw_chip(self, chip_id, size * 0.5, minf(size.x, size.y), 0.35 if dim else 1.0, glow)
