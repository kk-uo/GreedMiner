class_name PlanetVisual
extends Control

## Procedural, reusable planet presentation used by the selection carousel.

signal pressed(planet_index: int)

var planet_index: int = 0
var planet_id: StringName = &""
var display_name: String = ""
var visual_theme: StringName = &"rocky"
var unlocked: bool = false

var selection_amount: float = 0.0:
	set(value):
		selection_amount = value
		queue_redraw()

var hover_amount: float = 0.0:
	set(value):
		hover_amount = value
		queue_redraw()

var _animation_time: float = 0.0
var _hover_tween: Tween


## Applies one entry from PlanetSelect's data-driven planet list.
func configure(data: Dictionary, index: int) -> void:
	planet_index = index
	planet_id = data.get("id", &"") as StringName
	display_name = String(data.get("name", "UNKNOWN PLANET"))
	visual_theme = data.get("theme", &"rocky") as StringName
	unlocked = bool(data.get("unlocked", false))
	tooltip_text = display_name
	queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(320.0, 320.0)
	size = Vector2(320.0, 320.0)
	pivot_offset = size * 0.5
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	queue_redraw()


func _process(delta: float) -> void:
	_animation_time = fmod(_animation_time + delta, TAU * 20.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if (
		mouse_event.button_index == MOUSE_BUTTON_LEFT
		and mouse_event.pressed
	):
		pressed.emit(planet_index)
		accept_event()


func _on_mouse_entered() -> void:
	_animate_hover(1.0)


func _on_mouse_exited() -> void:
	_animate_hover(0.0)


func _animate_hover(target: float) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "hover_amount", target, 0.16)


func _draw() -> void:
	var center := size * 0.5
	var radius := 102.0 * (1.0 + hover_amount * 0.035)
	var pulse := (sin(_animation_time * 2.0) + 1.0) * 0.5

	# Selected planets receive layered atmospheric glow and a scanner ring.
	if selection_amount > 0.01:
		var glow_strength := selection_amount * (0.12 + pulse * 0.04)
		for ring_index in range(4, 0, -1):
			draw_circle(
				center,
				radius + float(ring_index) * 9.0,
				Color(Palette.ACCENT, glow_strength * 0.7 / float(ring_index))
			)
		draw_arc(
			center,
			radius + 18.0,
			0.18,
			TAU - 0.18,
			96,
			Color(Palette.ACCENT, 0.9 * selection_amount),
			3.0
		)

	match visual_theme:
		&"frozen":
			_draw_frozen_planet(center, radius)
		&"volcanic":
			_draw_volcanic_planet(center, radius)
		_:
			_draw_rocky_planet(center, radius)

	# Style A: one hard, flat shadow crescent (light from the top-left).
	_draw_shadow_crescent(center, radius)

	if not unlocked:
		_draw_lock(center, radius)


func _draw_rocky_planet(center: Vector2, radius: float) -> void:
	var ground := Palette.planet(&"rocky")
	draw_circle(center, radius, ground["ground"])
	draw_circle(center - Vector2(22.0, 28.0), 49.0, ground["ground_light"])
	draw_circle(center + Vector2(25.0, 45.0), 28.0, ground["ground_dark"])
	for crater in [[Vector2(-48.0, 25.0), 21.0], [Vector2(43.0, -36.0), 17.0]]:
		draw_circle(center + (crater[0] as Vector2), crater[1], ground["rock"])
		draw_circle(center + (crater[0] as Vector2) + Vector2(2.0, 2.0), (crater[1] as float) * 0.72, ground["crater_inner"])

	# Mineral seams and cracked plates identify the current rocky world.
	draw_polyline(PackedVector2Array([
		center + Vector2(-8.0, -64.0),
		center + Vector2(2.0, -38.0),
		center + Vector2(-10.0, -14.0),
		center + Vector2(8.0, 12.0),
		center + Vector2(3.0, 40.0),
	]), ground["rock"], 3.0)
	draw_polyline(PackedVector2Array([
		center + Vector2(3.0, -38.0),
		center + Vector2(24.0, -51.0),
		center + Vector2(38.0, -48.0),
	]), ground["rock"], 2.0)
	# Gold ore glints: the only saturated color on the planet.
	Palette.draw_crystal(self, center + Vector2(-20.0, -6.0), 0.55)
	Palette.draw_crystal(self, center + Vector2(-6.0, 6.0), 0.4, 0.3)
	Palette.draw_crystal(self, center + Vector2(13.0, -2.0), 0.32, -0.3)


func _draw_frozen_planet(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, Color("75B9D2"))
	draw_circle(center - Vector2(20.0, 24.0), radius * 0.66, Color("A5DAE8"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-88.0, -30.0),
		center + Vector2(-50.0, -63.0),
		center + Vector2(-9.0, -48.0),
		center + Vector2(23.0, -78.0),
		center + Vector2(73.0, -47.0),
		center + Vector2(91.0, -16.0),
		center + Vector2(52.0, -27.0),
		center + Vector2(4.0, -12.0),
		center + Vector2(-42.0, -22.0),
	]), Color("E9FAFF"))
	draw_polyline(PackedVector2Array([
		center + Vector2(-58.0, 19.0),
		center + Vector2(-25.0, 8.0),
		center + Vector2(-4.0, 28.0),
		center + Vector2(31.0, 14.0),
		center + Vector2(62.0, 32.0),
	]), Color("D9F8FF"), 8.0)
	draw_polyline(PackedVector2Array([
		center + Vector2(9.0, -6.0),
		center + Vector2(17.0, 19.0),
		center + Vector2(7.0, 45.0),
		center + Vector2(25.0, 68.0),
	]), Color("3E8FAE"), 3.0)


func _draw_volcanic_planet(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, Color("332D30"))
	draw_circle(center - Vector2(19.0, 24.0), radius * 0.72, Color("4B3A37"))
	var lava_color := Color("FF6A24")
	var hot_color := Color("FFC24A")
	draw_polyline(PackedVector2Array([
		center + Vector2(-80.0, -34.0),
		center + Vector2(-47.0, -25.0),
		center + Vector2(-28.0, -2.0),
		center + Vector2(3.0, 5.0),
		center + Vector2(22.0, 32.0),
		center + Vector2(63.0, 43.0),
	]), lava_color, 8.0)
	draw_polyline(PackedVector2Array([
		center + Vector2(-25.0, -75.0),
		center + Vector2(-15.0, -48.0),
		center + Vector2(10.0, -31.0),
		center + Vector2(3.0, 5.0),
	]), hot_color, 4.0)
	draw_polyline(PackedVector2Array([
		center + Vector2(20.0, 32.0),
		center + Vector2(8.0, 62.0),
		center + Vector2(20.0, 83.0),
	]), hot_color, 4.0)
	draw_circle(center + Vector2(43.0, -39.0), 17.0, Color("211D20"))
	draw_arc(center + Vector2(43.0, -39.0), 12.0, 0.0, TAU, 24, Color("7C4B36"), 3.0)


func _draw_lock(center: Vector2, radius: float) -> void:
	draw_circle(center, radius - 2.0, Color(Palette.UI_PANEL, 0.6))
	var lock_center := center + Vector2(0.0, 9.0)
	draw_arc(
		lock_center + Vector2(0.0, -16.0),
		22.0,
		PI,
		TAU,
		32,
		Palette.UI_MUTED,
		7.0
	)
	draw_rect(
		Rect2(lock_center - Vector2(28.0, 14.0), Vector2(56.0, 48.0)),
		Palette.UI_PANEL,
		true
	)
	draw_rect(
		Rect2(lock_center - Vector2(28.0, 14.0), Vector2(56.0, 48.0)),
		Palette.MECH,
		false,
		2.0
	)
	draw_circle(lock_center + Vector2(0.0, 6.0), 5.0, Palette.UI_MUTED)
	draw_rect(Rect2(lock_center + Vector2(-2.0, 8.0), Vector2(4.0, 13.0)), Palette.UI_MUTED)


## Flat shadow crescent: the planet disc minus a lit disc shifted toward the
## top-left, so the shadow stays one hard tone (no gradients).
func _draw_shadow_crescent(center: Vector2, radius: float) -> void:
	var planet_disc := Palette.offset_points(Palette.regular_polygon(64, radius), center)
	var lit_disc := Palette.offset_points(
		Palette.regular_polygon(64, radius * 1.02), center + Vector2(-radius * 0.3, -radius * 0.24)
	)
	for part in Geometry2D.clip_polygons(planet_disc, lit_disc):
		draw_colored_polygon(part, Color(0.0, 0.0, 0.0, 0.22))
