class_name PlanetVisual
extends Control

## Procedural, reusable planet presentation used by the selection carousel.

signal pressed(planet_index: int)

var planet_index: int = 0
var planet_id: StringName = &""
var display_name: String = ""
var visual_theme: StringName = &"rocky"
var unlocked: bool = false
## True while the destination still has to be pinpointed with ore.
var uncharted: bool = false
## 1 -> 0 after a successful locate: the reticle snaps shut and fades.
var lock_on: float = 0.0

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
		&"jungle":
			_draw_jungle_planet(center, radius)
		&"frozen":
			_draw_frozen_planet(center, radius)
		&"volcanic":
			_draw_volcanic_planet(center, radius)
		&"graveyard":
			_draw_graveyard_planet(center, radius)
		_:
			_draw_rocky_planet(center, radius)

	# Style A: one hard, flat shadow crescent (light from the top-left).
	_draw_shadow_crescent(center, radius)
	if visual_theme == &"graveyard":
		_draw_graveyard_wisps(center, radius)

	if not unlocked:
		_draw_lock(center, radius)
	elif uncharted or lock_on > 0.0:
		_draw_locate_reticle(center, radius)


## Targeting reticle over a planet whose coordinates are not known yet. After
## a locate it closes in on the planet in orange and fades (lock_on 1 -> 0).
func _draw_locate_reticle(center: Vector2, radius: float) -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	var closing := 1.0 - lock_on if lock_on > 0.0 else 0.0
	var r := radius * (1.18 - 0.18 * closing)
	var color := Palette.ACCENT if lock_on > 0.0 else Color(Palette.UI_TEXT, 0.75)
	var alpha := lock_on if lock_on > 0.0 else 1.0
	color.a *= alpha
	var spin := t * 0.6 * (1.0 if lock_on <= 0.0 else 4.0)
	for index in range(4):
		var start := spin + float(index) * TAU / 4.0
		draw_arc(center, r, start, start + TAU / 4.0 * 0.6, 18, color, 3.0)
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(center + direction * (r - 14.0), center + direction * (r + 12.0), color, 3.0)
	if lock_on <= 0.0:
		# Faint scanning sweep while uncharted.
		var sweep := fposmod(t * 0.9, 1.0)
		draw_arc(center, radius * (0.25 + 0.75 * sweep), 0.0, TAU, 48, Color(Palette.UI_TEXT, 0.25 * (1.0 - sweep)), 2.0)


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


## Lush green world... dotted with goblin campfires and huts.
func _draw_jungle_planet(center: Vector2, radius: float) -> void:
	var ground := Palette.planet(&"jungle")
	draw_circle(center, radius, ground["ground"])
	draw_circle(center + Vector2(-30.0, -24.0), 46.0, ground["ground_light"])
	# Dense forest blobs (clusters of octagons) over the disc.
	var clumps := [
		[Vector2(30.0, -52.0), 22.0], [Vector2(48.0, -30.0), 18.0], [Vector2(-56.0, 30.0), 24.0],
		[Vector2(-36.0, 52.0), 20.0], [Vector2(6.0, 60.0), 18.0], [Vector2(58.0, 26.0), 20.0],
		[Vector2(-62.0, -12.0), 16.0], [Vector2(-8.0, -70.0), 14.0],
	]
	for clump in clumps:
		var at: Vector2 = center + (clump[0] as Vector2)
		var r: float = clump[1]
		draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(8, r, 0.3), at), ground["rock"])
		draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(8, r * 0.72, 0.3), at + Vector2(-2.0, -3.0)), ground["canopy_mid"])
		draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(6, r * 0.34, 0.3), at + Vector2(-r * 0.3, -r * 0.34)), ground["rock_light"])
	# A river of mud and goblin camps: tiny huts with glowing campfires.
	draw_polyline(PackedVector2Array([
		center + Vector2(-70.0, -46.0), center + Vector2(-30.0, -6.0),
		center + Vector2(-4.0, 14.0), center + Vector2(40.0, 4.0), center + Vector2(72.0, 46.0),
	]), ground["crater"], 6.0)
	for camp in [Vector2(-14.0, -20.0), Vector2(20.0, 28.0), Vector2(-40.0, 6.0)]:
		var at: Vector2 = center + camp
		draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(10, 7.0, 0.0), at), ground["thatch_dark"])
		draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(10, 5.5, 0.0), at + Vector2(-0.6, -0.8)), ground["thatch"])
		draw_circle(at + Vector2(9.0, 6.0), 4.0, Color(Palette.ACCENT, 0.35))
		draw_circle(at + Vector2(9.0, 6.0), 2.0, Palette.GOLD)


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


## Graveyard world: ashen moss-grey ground packed with rows of tombstones,
## a crypt and dead trees, split by a chasm of glowing green biomass (the
## planet's riches), with violet grave-mist drifting over the surface.
func _draw_graveyard_planet(center: Vector2, radius: float) -> void:
	var t := _animation_time
	draw_circle(center, radius, Color("3B403A"))
	draw_circle(center - Vector2(20.0, 24.0), radius * 0.7, Color("4D5449"))
	# Darker burial plots.
	for plot in [[Vector2(-40.0, 38.0), 30.0], [Vector2(46.0, -18.0), 26.0], [Vector2(-18.0, -58.0), 20.0]]:
		draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(7, plot[1], 0.4), center + (plot[0] as Vector2)), Color("343A33"))
	# Glowing biomass: irregular pools seeping up between the graves.
	var glow := 0.5 + 0.5 * sin(t * 1.6)
	for pool in [[Vector2(-26.0, 20.0), 19.0, 0.3], [Vector2(36.0, 38.0), 14.0, 1.1], [Vector2(-56.0, -26.0), 9.0, 2.0], [Vector2(6.0, 40.0), 7.0, 0.7]]:
		var at: Vector2 = center + (pool[0] as Vector2)
		var r: float = pool[1]
		var blob := PackedVector2Array()
		for k in range(11):
			var a := TAU * float(k) / 11.0 + float(pool[2])
			blob.append(at + Vector2(cos(a) * r * (1.0 + 0.22 * sin(a * 3.0 + float(pool[2]))), sin(a) * r * 0.78))
		draw_circle(at, r + 6.0 + 2.0 * glow, Color("7CFF5A", 0.1 + 0.08 * glow))
		draw_colored_polygon(Palette.offset_points(blob, Vector2(0.0, 2.0)), Color("1E2A1C"))
		draw_colored_polygon(blob, Color("4FC23C"))
		var core := PackedVector2Array()
		for point in blob:
			core.append(at + (point - at) * 0.55 + Vector2(-r * 0.18, -r * 0.16))
		draw_colored_polygon(core, Color("9BEF6A"))
		draw_circle(at + Vector2(-r * 0.35, -r * 0.3), r * 0.16, Color("E6FFC8"))
		var ph := fposmod(t * 0.7 + r * 0.13, 1.0)
		draw_circle(at + Vector2(r * 0.35, r * 0.05 - ph * 6.0), 2.2 * (1.0 - ph), Color("E6FFC8", 1.0 - ph))
	# Dead trees.
	for tree in [[Vector2(70.0, 34.0), 1.3], [Vector2(-74.0, 10.0), 1.1]]:
		_draw_dead_tree(center + (tree[0] as Vector2), tree[1])
	# A small crypt.
	draw_set_transform(center + Vector2(6.0, -30.0), 0.0, Vector2.ONE * 1.4)
	_draw_crypt(Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Rows of tombstones following the curve of the world.
	var rows := [
		[Vector2(-60.0, -50.0), Vector2(21.0, -5.0), 3],
		[Vector2(-58.0, 56.0), Vector2(21.0, 6.0), 3],
		[Vector2(34.0, -62.0), Vector2(20.0, 8.0), 2],
		[Vector2(62.0, 4.0), Vector2(6.0, 20.0), 2],
		[Vector2(14.0, 70.0), Vector2(20.0, -6.0), 2],
	]
	var index := 0
	for row in rows:
		for k in range(int(row[2])):
			var at: Vector2 = center + (row[0] as Vector2) + (row[1] as Vector2) * float(k)
			_draw_tombstone(at, index % 3, 1.45 + 0.15 * float((index * 7) % 3), float((index * 5) % 7 - 3) * 0.06)
			index += 1


## One tombstone: rounded slab, cross or obelisk (kind 0/1/2), lit from the top-left.
func _draw_tombstone(at: Vector2, kind: int, scale_by: float, tilt: float) -> void:
	var s := scale_by
	var dark := Color("6E7268")
	var stone := Color("A3A79A")
	var lit := Color("CDD0C2")
	draw_set_transform(at, tilt, Vector2.ONE * s)
	draw_colored_polygon(PackedVector2Array([Vector2(-5.0, 1.0), Vector2(6.0, 1.0), Vector2(8.0, 3.5), Vector2(-3.0, 3.5)]), Color(0.0, 0.0, 0.0, 0.3))
	match kind:
		1:
			draw_rect(Rect2(Vector2(-1.6, -12.0), Vector2(3.2, 13.0)), dark)
			draw_rect(Rect2(Vector2(-5.0, -9.0), Vector2(10.0, 3.0)), dark)
			draw_rect(Rect2(Vector2(-1.6, -12.0), Vector2(2.0, 12.0)), stone)
			draw_rect(Rect2(Vector2(-5.0, -9.0), Vector2(9.0, 2.0)), lit)
		2:
			draw_colored_polygon(PackedVector2Array([Vector2(-3.5, 1.0), Vector2(-2.2, -11.0), Vector2(0.0, -14.0), Vector2(2.2, -11.0), Vector2(3.5, 1.0)]), dark)
			draw_colored_polygon(PackedVector2Array([Vector2(-3.0, 0.5), Vector2(-1.8, -10.5), Vector2(0.0, -13.2), Vector2(0.4, 0.5)]), stone)
		_:
			var slab := PackedVector2Array([Vector2(-4.5, 1.0), Vector2(-4.5, -6.0)])
			for k in range(7):
				slab.append(Vector2(-4.5 * cos(PI * float(k) / 6.0), -6.0 - 4.5 * sin(PI * float(k) / 6.0)))
			slab.append(Vector2(4.5, 1.0))
			draw_colored_polygon(slab, dark)
			var face := PackedVector2Array()
			for point in slab:
				face.append(point * Vector2(0.78, 0.9) + Vector2(-0.8, -0.2))
			draw_colored_polygon(face, stone)
			draw_line(Vector2(-2.6, -6.0), Vector2(1.0, -6.0), dark, 0.9)
			draw_line(Vector2(-2.6, -3.6), Vector2(0.4, -3.6), dark, 0.9)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_dead_tree(at: Vector2, s: float) -> void:
	var bark := Color("2A2622")
	draw_line(at, at + Vector2(1.0, -22.0) * s, bark, 3.0 * s)
	draw_line(at + Vector2(0.6, -12.0) * s, at + Vector2(-9.0, -20.0) * s, bark, 2.0 * s)
	draw_line(at + Vector2(-9.0, -20.0) * s, at + Vector2(-11.0, -26.0) * s, bark, 1.4 * s)
	draw_line(at + Vector2(0.8, -16.0) * s, at + Vector2(8.0, -25.0) * s, bark, 1.8 * s)
	draw_line(at + Vector2(1.0, -22.0) * s, at + Vector2(-2.0, -29.0) * s, bark, 1.4 * s)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-5.0, 1.0) * s, at + Vector2(6.0, 1.0) * s, at + Vector2(2.0, -2.0) * s]), bark)


## A squat stone mausoleum with a peaked roof and a faint green glow inside.
func _draw_crypt(at: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(-12.0, 4.0), at + Vector2(14.0, 4.0), at + Vector2(17.0, 8.0), at + Vector2(-9.0, 8.0)]), Color(0.0, 0.0, 0.0, 0.3))
	draw_rect(Rect2(at + Vector2(-12.0, -10.0), Vector2(24.0, 14.0)), Color("6E7268"))
	draw_rect(Rect2(at + Vector2(-12.0, -10.0), Vector2(18.0, 13.0)), Color("A3A79A"))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-15.0, -10.0), at + Vector2(0.0, -20.0), at + Vector2(15.0, -10.0)]), Color("595D54"))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-15.0, -10.0), at + Vector2(0.0, -20.0), at + Vector2(1.0, -13.0)]), Color("CDD0C2"))
	draw_rect(Rect2(at + Vector2(-3.5, -5.0), Vector2(7.0, 9.0)), Color("1E2A1C"))
	draw_rect(Rect2(at + Vector2(-2.5, -3.5), Vector2(5.0, 7.5)), Color("5FD94A", 0.45 + 0.25 * sin(_animation_time * 2.0)))
	draw_line(at + Vector2(0.0, -24.0), at + Vector2(0.0, -19.0), Color("A3A79A"), 1.4)
	draw_line(at + Vector2(-2.0, -22.5), at + Vector2(2.0, -22.5), Color("A3A79A"), 1.4)


## Violet grave-mist drifting across the face and a few ghost wisps
## circling just above the surface (drawn after the shadow so they glow).
func _draw_graveyard_wisps(center: Vector2, radius: float) -> void:
	var t := _animation_time
	for band in range(2):
		var y := -10.0 + 46.0 * float(band) + sin(t * 0.5 + float(band)) * 4.0
		var drift := fposmod(t * (6.0 + 3.0 * float(band)), 40.0) - 20.0
		var points := PackedVector2Array()
		var half_width := sqrt(maxf(radius * radius - y * y, 0.0)) - 6.0
		for k in range(13):
			var x := lerpf(-half_width, half_width, float(k) / 12.0)
			points.append(center + Vector2(x, y + sin(x * 0.06 + t + drift * 0.05) * 5.0))
		draw_polyline(points, Color("B49CFF", 0.07), 14.0)
		draw_polyline(points, Color("D9CCFF", 0.06), 5.0)
	for k in range(3):
		var a := t * (0.35 + 0.08 * float(k)) + TAU * float(k) / 3.0
		var at := center + Vector2(cos(a), sin(a) * 0.85) * (radius + 10.0)
		var trail := at - Vector2(-sin(a), cos(a) * 0.85) * 10.0
		draw_line(trail, at, Color("C8FFB0", 0.18), 6.0)
		draw_circle(at, 4.5, Color("C8FFB0", 0.35))
		draw_circle(at, 2.2, Color("F2FFE6", 0.9))


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
