extends Control

## Screen-space blizzard drawn under the battle HUD.
##
## Level 1 (a Snow Monster Wizard's blizzard, design 2 "gusts + fog"): soft
## fog banks drift across the screen, now and then a curved white gust sweeps
## by, snowflakes blow sideways, and a light frost haze sits on the edges.
## Level 2 (the boss's entrance blizzard, designs 3 + 2): everything above
## plus three depths of heavier snow, a thicker frost haze and a whiteout
## flash every few seconds.
## WeatherManager sets `level`; the effect fades in and out smoothly.
## Load with preload(); no class_name on purpose.

const SNOW := Color("FFFFFF")
const FOG := Color("F2FAFF")
const FROST := Color("EAF6FF")
## Wind direction (screen space, normalised) and how fast intensity eases.
const WIND := Vector2(1.0, 0.22)
const FADE_SPEED: float = 0.8
const WHITEOUT_PERIOD: float = 5.5

var level: int = 0

var _intensity: float = 0.0  # eases toward `level` (0..2)
var _time: float = 0.0
var _flakes: Array = []  # {p (0..1 coords), depth, speed, size, wobble}
var _fog: Array = []
var _gusts: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 707
	# Depth 0 = far (small, slow), 1 = mid, 2 = near (big, fast). Level 1 only
	# shows the mid layer; level 2 shows all three.
	for index in range(260):
		var depth := 1 if index < 140 else (0 if index < 210 else 2)
		_flakes.append({
			"p": Vector2(_rng.randf(), _rng.randf()),
			"depth": depth,
			"speed": [0.10, 0.22, 0.42][depth] * _rng.randf_range(0.8, 1.2),
			"size": [1.0, 1.8, 3.4][depth] * _rng.randf_range(0.75, 1.25),
			"wobble": _rng.randf() * TAU,
		})
	for index in range(4):
		_fog.append({"p": Vector2(_rng.randf(), 0.15 + 0.23 * float(index)), "speed": _rng.randf_range(0.025, 0.045), "size": _rng.randf_range(0.22, 0.32)})
	for index in range(3):
		_gusts.append({"age": _rng.randf() * 3.0, "y": _rng.randf_range(0.15, 0.85), "life": _rng.randf_range(2.2, 3.2)})


func _process(delta: float) -> void:
	_intensity = move_toward(_intensity, float(level), delta * FADE_SPEED)
	visible = _intensity > 0.001
	if not visible:
		return
	_time += delta
	for flake in _flakes:
		var p: Vector2 = flake["p"]
		p += WIND * float(flake["speed"]) * delta * (1.0 + 0.35 * _intensity)
		p.y += sin(_time * 2.0 + float(flake["wobble"])) * 0.02 * delta
		flake["p"] = Vector2(fposmod(p.x, 1.1), fposmod(p.y, 1.1))
	for bank in _fog:
		var p: Vector2 = bank["p"]
		bank["p"] = Vector2(fposmod(p.x + float(bank["speed"]) * delta + 0.3, 1.6) - 0.3, p.y)
	for gust in _gusts:
		gust["age"] = float(gust["age"]) + delta
		if float(gust["age"]) > float(gust["life"]):
			gust["age"] = 0.0
			gust["y"] = _rng.randf_range(0.12, 0.88)
			gust["life"] = _rng.randf_range(2.2, 3.4)
	queue_redraw()


func _draw() -> void:
	var view := size
	var strength := clampf(_intensity, 0.0, 1.0)  # level-1 layers
	var heavy := clampf(_intensity - 1.0, 0.0, 1.0)  # extra level-2 layers
	# Cold tint over the whole field.
	draw_rect(Rect2(Vector2.ZERO, view), Color("BFE3FF", 0.07 * strength + 0.05 * heavy))
	# Fog banks drifting across (soft: stacked translucent ellipses).
	for bank in _fog:
		var center := Vector2((bank["p"] as Vector2).x * view.x, (bank["p"] as Vector2).y * view.y)
		var radius: float = float(bank["size"]) * view.x
		for ring in range(4):
			var k := 1.0 - float(ring) * 0.22
			_ellipse(center, Vector2(radius * k, radius * 0.28 * k), Color(FOG, (0.05 + 0.03 * heavy) * strength))
	# Gusts: a curved white stroke that sweeps across and fades.
	for gust in _gusts:
		var t: float = float(gust["age"]) / float(gust["life"])
		var alpha := sin(PI * clampf(t, 0.0, 1.0)) * 0.55 * strength
		if alpha <= 0.01:
			continue
		var start := Vector2(lerpf(-0.3, 1.1, t) * view.x, float(gust["y"]) * view.y)
		var points := PackedVector2Array()
		for k in range(14):
			var u := float(k) / 13.0
			points.append(start + Vector2(u * view.x * 0.22, sin(u * PI * 1.6) * -18.0 + u * 22.0))
		draw_polyline(points, Color(SNOW, alpha), 2.4, true)
	# Snowflakes.
	for flake in _flakes:
		var depth: int = flake["depth"]
		var alpha := strength if depth == 1 else heavy
		if alpha <= 0.0:
			continue
		var p: Vector2 = flake["p"]
		var at := Vector2((p.x - 0.05) * view.x, (p.y - 0.05) * view.y)
		var radius: float = flake["size"]
		var opacity: float = [0.45, 0.8, 0.95][depth]
		if depth == 2:
			draw_line(at - WIND * radius * 2.4, at, Color(SNOW, 0.35 * alpha), radius * 0.8)
		draw_circle(at, radius, Color(SNOW, opacity * alpha))
	# Frost haze on the edges (thicker in the boss blizzard).
	var haze := 0.16 * strength + 0.14 * heavy
	for band in range(8):
		var inset := float(band) * view.y * 0.022
		var a := haze * (1.0 - float(band) / 8.0)
		var w := view.y * 0.022
		draw_rect(Rect2(inset, inset, view.x - inset * 2.0, w), Color(FROST, a))
		draw_rect(Rect2(inset, view.y - inset - w, view.x - inset * 2.0, w), Color(FROST, a))
		draw_rect(Rect2(inset, inset + w, w, view.y - inset * 2.0 - w * 2.0), Color(FROST, a))
		draw_rect(Rect2(view.x - inset - w, inset + w, w, view.y - inset * 2.0 - w * 2.0), Color(FROST, a))
	# Boss blizzard: the whole screen goes white for a moment every few seconds.
	if heavy > 0.0:
		var k := fposmod(_time, WHITEOUT_PERIOD) / WHITEOUT_PERIOD
		var flash := 0.0
		if k > 0.6 and k < 0.85:
			flash = sin((k - 0.6) / 0.25 * PI)
		draw_rect(Rect2(Vector2.ZERO, view), Color(SNOW, 0.28 * flash * heavy))


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var a := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(points, color)
