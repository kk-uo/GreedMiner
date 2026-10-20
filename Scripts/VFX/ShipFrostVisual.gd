extends Node2D

## The ship frozen solid by the Mega Monster's snowball: a sheet of ice grows
## over the hull, frost crystals spike out of the corners and edges, white
## cracks run across it and sparkles glint; a snowflake badge with a ring
## counts down above the ship. When the freeze ends the ice shatters outward.
##
## Added by BattleMain as a child of the Ship (ship-local coordinates; the
## hull spans 0..Ship.SHIP_SIZE). Reads the remaining time from the
## WeatherManager. Presentation only. Load with preload(); no class_name.

const ICE_SHEET := Color("BFE8FF")
const FROST := Color("F2FBFF")
const CRYSTAL_DARK := Color("2B8FB0")
const CRYSTAL := Color("9FE7FF")
const CRYSTAL_LIGHT := Color("E8FBFF")
const GROW_TIME: float = 0.35
const SHATTER_TIME: float = 0.55
const PAD: float = 8.0

var weather: Node
var _total: float = 3.0
var _age: float = 0.0
var _shatter_age: float = -1.0
var _crystals: Array = []  # {p, dir, length, width}
var _cracks: Array = []  # PackedVector2Array
var _sparkles: Array = []  # {p, phase}
var _rng := RandomNumberGenerator.new()
## QTE feedback: chips flying off each click, a short jolt, more cracks.
var _chips: Array = []  # {p, vel, age, r, rot}
var _jolt: float = 0.0
var _clicks: int = 0
const CHIP_LIFE: float = 0.45


func setup(weather_manager: Node) -> void:
	weather = weather_manager
	if weather != null and weather.has_method("get_freeze_remaining"):
		_total = maxf(float(weather.call("get_freeze_remaining")), 0.1)
	if weather != null and weather.has_signal("freeze_qte_clicked"):
		weather.connect("freeze_qte_clicked", _on_qte_click)


## A QTE click: chips burst off a random spot on the ice and it jolts.
func _on_qte_click(_remaining: float) -> void:
	_clicks += 1
	_jolt = 1.0
	var size: Vector2 = Ship.SHIP_SIZE
	var at := Vector2(_rng.randf_range(0.0, size.x), _rng.randf_range(0.0, size.y))
	for k in range(7):
		var dir := Vector2.RIGHT.rotated(_rng.randf() * TAU)
		_chips.append({"p": at, "vel": dir * _rng.randf_range(120.0, 260.0), "age": 0.0, "r": _rng.randf_range(3.0, 6.0), "rot": _rng.randf() * TAU})


func release() -> void:
	if _shatter_age < 0.0:
		_shatter_age = 0.0


func _ready() -> void:
	z_index = 4
	_rng.seed = 9137
	var size: Vector2 = Ship.SHIP_SIZE
	var corners := [Vector2(-PAD, -PAD), Vector2(size.x + PAD, -PAD), Vector2(size.x + PAD, size.y + PAD), Vector2(-PAD, size.y + PAD)]
	var center := size * 0.5
	for corner in corners:
		var out: Vector2 = ((corner as Vector2) - center).normalized()
		for k in range(3):
			_crystals.append({"p": corner, "dir": out.rotated((float(k) - 1.0) * 0.5), "length": _rng.randf_range(22.0, 34.0) * (1.25 if k == 1 else 1.0), "width": _rng.randf_range(6.0, 8.0)})
	var sides := [[Vector2(0, -PAD), Vector2(size.x, -PAD), Vector2.UP], [Vector2(size.x + PAD, 0), Vector2(size.x + PAD, size.y), Vector2.RIGHT],
			[Vector2(0, size.y + PAD), Vector2(size.x, size.y + PAD), Vector2.DOWN], [Vector2(-PAD, 0), Vector2(-PAD, size.y), Vector2.LEFT]]
	for edge in sides:
		for k in range(4):
			var t := (float(k) + 0.5 + _rng.randf_range(-0.2, 0.2)) / 4.0
			var p: Vector2 = (edge[0] as Vector2).lerp(edge[1], t)
			_crystals.append({"p": p, "dir": (edge[2] as Vector2).rotated(_rng.randf_range(-0.4, 0.4)), "length": _rng.randf_range(10.0, 18.0), "width": _rng.randf_range(4.0, 6.0)})
	for k in range(5):
		var start := Vector2(_rng.randf_range(0.1, 0.9) * size.x, _rng.randf_range(0.1, 0.9) * size.y)
		var line := PackedVector2Array([start])
		var dir := Vector2.RIGHT.rotated(_rng.randf() * TAU)
		for step in range(4):
			dir = dir.rotated(_rng.randf_range(-0.6, 0.6))
			line.append(line[line.size() - 1] + dir * _rng.randf_range(16.0, 30.0))
		_cracks.append(line)
	# Extra cracks revealed one per QTE click.
	for k in range(20):
		var start := Vector2(_rng.randf_range(0.05, 0.95) * size.x, _rng.randf_range(0.05, 0.95) * size.y)
		var line := PackedVector2Array([start])
		var dir := Vector2.RIGHT.rotated(_rng.randf() * TAU)
		for step in range(3):
			dir = dir.rotated(_rng.randf_range(-0.7, 0.7))
			line.append(line[line.size() - 1] + dir * _rng.randf_range(12.0, 24.0))
		_cracks.append(line)
	for k in range(9):
		_sparkles.append({"p": Vector2(_rng.randf() * size.x, _rng.randf() * size.y), "phase": _rng.randf() * TAU})


func _process(delta: float) -> void:
	_age += delta
	_jolt = maxf(_jolt - delta * 6.0, 0.0)
	for chip in _chips.duplicate():
		chip["age"] += delta
		chip["p"] += chip["vel"] * delta
		chip["vel"] *= 0.9
		if chip["age"] > CHIP_LIFE:
			_chips.erase(chip)
	if _shatter_age >= 0.0:
		_shatter_age += delta
		if _shatter_age >= SHATTER_TIME:
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	if _shatter_age >= 0.0:
		_draw_shatter(_shatter_age / SHATTER_TIME)
		return
	var g := smoothstep(0.0, GROW_TIME, _age)
	var size: Vector2 = Ship.SHIP_SIZE
	# Jolt: the ice shudders on each QTE click.
	draw_set_transform(Vector2(sin(_age * 90.0), cos(_age * 77.0)) * 4.0 * _jolt, 0.0, Vector2.ONE)
	var rect := Rect2(Vector2(-PAD, -PAD), size + Vector2(PAD, PAD) * 2.0)
	# Ice sheet thickening from the rim inward.
	draw_rect(rect, Color(ICE_SHEET, 0.32 * g))
	for band in range(5):
		var inset := float(band) * 9.0 * g
		draw_rect(rect.grow(-inset - 4.5), Color(FROST, 0.22 * g * (1.0 - float(band) / 5.0)), false, 9.0)
	draw_rect(rect, Color(CRYSTAL_LIGHT, 0.9 * g), false, 3.0)
	for index in range(mini(_cracks.size(), 5 + _clicks)):
		draw_polyline(_cracks[index], Color(1, 1, 1, 0.55 * g), 2.0)
	for crystal in _crystals:
		_draw_crystal(crystal, g)
	for sparkle in _sparkles:
		var a := maxf(sin(_age * 3.0 + float(sparkle["phase"])), 0.0) * g
		if a > 0.05:
			var p: Vector2 = sparkle["p"]
			draw_line(p + Vector2(-6, 0) * a, p + Vector2(6, 0) * a, Color(1, 1, 1, a), 2.0)
			draw_line(p + Vector2(0, -6) * a, p + Vector2(0, 6) * a, Color(1, 1, 1, a), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for chip in _chips:
		var t: float = float(chip["age"]) / CHIP_LIFE
		var d := Vector2.RIGHT.rotated(float(chip["rot"]) + t * 8.0) * float(chip["r"])
		var q: Vector2 = chip["p"]
		draw_colored_polygon(PackedVector2Array([q - d, q + Vector2(-d.y, d.x) * 0.5, q + d, q - Vector2(-d.y, d.x) * 0.5]), Color(CRYSTAL_LIGHT, 1.0 - t))
	_draw_countdown(g)
	_draw_qte_prompt(g)


func _draw_crystal(crystal: Dictionary, g: float, offset: Vector2 = Vector2.ZERO, alpha: float = 1.0) -> void:
	var p: Vector2 = (crystal["p"] as Vector2) + offset
	var dir: Vector2 = crystal["dir"]
	var perp := Vector2(-dir.y, dir.x)
	var length: float = float(crystal["length"]) * g
	var width: float = crystal["width"]
	draw_colored_polygon(PackedVector2Array([p + perp * width, p + dir * length, p - perp * width]), Color(CRYSTAL_DARK, alpha))
	draw_colored_polygon(PackedVector2Array([p + perp * width * 0.5, p + dir * length * 0.9, p]), Color(CRYSTAL, alpha))
	draw_line(p, p + dir * length * 0.7, Color(CRYSTAL_LIGHT, alpha), 1.5)


## QTE prompt above the badge: "CLICK!" with a mouse icon and the seconds
## left, pulsing; it pops a little on each click.
func _draw_qte_prompt(g: float) -> void:
	var remaining := 0.0
	if is_instance_valid(weather) and weather.has_method("get_freeze_remaining"):
		remaining = float(weather.call("get_freeze_remaining"))
	var font := ThemeDB.fallback_font
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.default_font != null:
		font = theme.default_font
	var pulse := 0.5 + 0.5 * sin(_age * 9.0)
	var pop := 1.0 + 0.18 * _jolt
	var center := Vector2(Ship.SHIP_SIZE.x * 0.5, -100.0)
	draw_set_transform(center, 0.0, Vector2.ONE * pop)
	var text := "CLICK!  %.1fs" % remaining
	var font_size := 22
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x + 64.0
	var pill := Rect2(Vector2(-width * 0.5, -20.0), Vector2(width, 40.0))
	Palette.draw_rounded_rect(self, Rect2(pill.position + Vector2(3.0, 4.0), pill.size), 20.0, Color(Palette.SHADOW_COLOR, Palette.SHADOW_COLOR.a * g))
	Palette.draw_rounded_rect(self, pill, 20.0, Color(CRYSTAL_LIGHT.lerp(Color.WHITE, pulse * 0.5), 0.95 * g))
	# Mouse icon with the left button lit.
	var mouse := Vector2(pill.position.x + 24.0, 0.0)
	Palette.draw_rounded_rect(self, Rect2(mouse - Vector2(8.0, 12.0), Vector2(16.0, 24.0)), 8.0, Color(Palette.UI_PANEL, g))
	draw_rect(Rect2(mouse - Vector2(6.0, 10.0), Vector2(5.0, 8.0)), Color(CRYSTAL_DARK.lerp(Color("2BD4FF"), pulse), g))
	draw_string(font, Vector2(pill.position.x + 40.0, 8.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(Palette.UI_PANEL, g))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Snowflake badge with a ring that fills while the ship thaws.
func _draw_countdown(g: float) -> void:
	var remaining := 0.0
	if is_instance_valid(weather) and weather.has_method("get_freeze_remaining"):
		remaining = float(weather.call("get_freeze_remaining"))
	var progress := 1.0 - clampf(remaining / _total, 0.0, 1.0)
	var at := Vector2(Ship.SHIP_SIZE.x * 0.5, -48.0)
	draw_circle(at + Vector2(2.0, 3.0), 18.0, Color(Palette.SHADOW_COLOR, Palette.SHADOW_COLOR.a * g))
	draw_circle(at, 18.0, Color(Palette.UI_PANEL, 0.92 * g))
	draw_arc(at, 15.5, 0.0, TAU, 40, Color(CRYSTAL_DARK, g), 3.5)
	if progress > 0.0:
		draw_arc(at, 15.5, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, Color(CRYSTAL_LIGHT, g), 3.5)
	for k in range(3):
		var dir := Vector2.UP.rotated(PI / 3.0 * float(k))
		draw_line(at - dir * 9.0, at + dir * 9.0, Color(CRYSTAL, g), 2.2)
		for end in [-1.0, 1.0]:
			var tip: Vector2 = at + dir * 6.0 * float(end)
			draw_line(tip, tip + dir.rotated(0.8) * 3.0 * end, Color(CRYSTAL, g), 1.6)
			draw_line(tip, tip + dir.rotated(-0.8) * 3.0 * end, Color(CRYSTAL, g), 1.6)


## Ice bursting off: crystals fly outward and fade, a frost ring expands.
func _draw_shatter(t: float) -> void:
	var center := Ship.SHIP_SIZE * 0.5
	var out := 1.0 - pow(1.0 - t, 2.0)
	var fade := 1.0 - smoothstep(0.4, 1.0, t)
	draw_rect(Rect2(Vector2(-PAD, -PAD), Ship.SHIP_SIZE + Vector2(PAD, PAD) * 2.0), Color(1, 1, 1, 0.5 * (1.0 - t) * (1.0 - t)))
	for crystal in _crystals:
		var from_center: Vector2 = ((crystal["p"] as Vector2) - center).normalized()
		_draw_crystal(crystal, 1.0 - 0.4 * t, from_center * 60.0 * out, fade)
	var radius := lerpf(Ship.SHIP_SIZE.x * 0.6, Ship.SHIP_SIZE.x * 0.95, out)
	draw_arc(center, radius, 0.0, TAU, 64, Color(CRYSTAL_LIGHT, 0.85 * (1.0 - t)), 6.0 * (1.0 - t) + 1.0)
