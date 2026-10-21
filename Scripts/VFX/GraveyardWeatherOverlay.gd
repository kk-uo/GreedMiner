extends Control

## Screen-space Graveyard Planet weather, drawn under the battle HUD.
## Presentation only - WeatherManager (or future wave logic) decides when.
##
## Lightning: two quick white flashes, then the battlefield goes completely
## black for ~2.45 s (nothing shows through), then a reveal flash and the
## light comes back. blackout_started / blackout_ended let gameplay spawn
## things out of the graves while it is dark.
##
## Blood moon (design v3 "blood grade"): the battlefield is regraded to a red
## monochrome, red ash falls, the screen edge throbs like a heartbeat and
## every enemy gets a pulsing red aura at its feet (empowered look).
## Load with preload(); no class_name on purpose.

signal blackout_started
signal blackout_ended

const DARK_START: float = 0.45
const DARK_END: float = 2.9
const LIGHTNING_TIME: float = 3.4
const NIGHT := Color("000000")
const NIGHT_ALPHA: float = 1.0
const ASH := Color("FF6A4A")
const AURA := Color("FF3B30")
const BLOOD_FADE_SPEED: float = 0.7

const GRADE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 0.0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 lo = vec3(0.04, 0.0, 0.015);
	vec3 mid = vec3(0.46, 0.04, 0.07);
	vec3 hi = vec3(1.0, 0.7, 0.58);
	vec3 ramp = l < 0.5 ? mix(lo, mid, l / 0.5) : mix(mid, hi, (l - 0.5) / 0.5);
	COLOR = vec4(mix(c, ramp, strength), 1.0);
}
"""

var blood_moon: bool = false

var _lightning_age: float = -1.0
var _blackout: bool = false
var _blood: float = 0.0
var _time: float = 0.0
var _grade: ColorRect
var _night: ColorRect
var _fx: Control
var _ash: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade = ColorRect.new()
	_grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = GRADE_SHADER
	material.shader = shader
	_grade.material = material
	_grade.hide()
	add_child(_grade)
	_night = ColorRect.new()
	_night.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_night.color = Color(NIGHT, 0.0)
	add_child(_night)
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in range(90):
		_ash.append({"x": rng.randf(), "y": rng.randf(), "speed": rng.randf_range(0.04, 0.11), "drift": rng.randf_range(-0.02, 0.02), "r": rng.randf_range(1.0, 2.6), "spin": rng.randf() * TAU})


## Starts one lightning strike (ignored while one is already playing).
func play_lightning() -> void:
	if is_lightning_playing():
		return
	_lightning_age = 0.0
	_blackout = false


func is_lightning_playing() -> bool:
	return _lightning_age >= 0.0


func is_blacked_out() -> bool:
	return _blackout


func _process(delta: float) -> void:
	_time += delta
	_blood = move_toward(_blood, 1.0 if blood_moon else 0.0, delta * BLOOD_FADE_SPEED)
	_grade.visible = _blood > 0.001
	(_grade.material as ShaderMaterial).set_shader_parameter("strength", 0.8 * _blood)
	if _lightning_age >= 0.0:
		_lightning_age += delta
		var dark := dark_at(_lightning_age)
		if not _blackout and dark >= 1.0:
			_blackout = true
			blackout_started.emit()
		elif _blackout and _lightning_age >= DARK_END:
			_blackout = false
			blackout_ended.emit()
		if _lightning_age > LIGHTNING_TIME:
			_lightning_age = -1.0
	_night.color = Color(NIGHT, NIGHT_ALPHA * dark_at(_lightning_age))
	_fx.queue_redraw()


## White flash strength at time t of a strike (two quick hits, then reveal).
static func flash_at(t: float) -> float:
	if t < 0.0:
		return 0.0
	return maxf(maxf(_pulse(t, 0.0, 0.05, 0.16), _pulse(t, 0.22, 0.03, 0.12) * 0.7), _pulse(t, DARK_END, 0.04, 0.35))


## Darkness (0..1) at time t of a strike.
static func dark_at(t: float) -> float:
	if t < DARK_START - 0.15 or t > DARK_END + 0.05:
		return 0.0
	return smoothstep(DARK_START - 0.15, DARK_START, t) * (1.0 - smoothstep(DARK_END - 0.02, DARK_END + 0.05, t))


static func _pulse(t: float, start: float, rise: float, fall: float) -> float:
	if t < start or t > start + rise + fall:
		return 0.0
	if t < start + rise:
		return (t - start) / rise
	return 1.0 - (t - start - rise) / fall


func _to_screen(world: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world


func _zoom() -> float:
	var camera := get_viewport().get_camera_2d()
	return camera.zoom.x if camera != null else 1.0


func _draw_fx() -> void:
	var screen := _fx.size
	if _blood > 0.001:
		_draw_blood_moon(screen)
	var flash := flash_at(_lightning_age)
	if flash > 0.0:
		_fx.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.92, 0.95, 1.0, 0.75 * flash))


func _draw_blood_moon(screen: Vector2) -> void:
	# Fully hidden while a lightning blackout covers the field.
	var k := _blood * (1.0 - dark_at(_lightning_age))
	if k <= 0.001:
		return
	# Empowered enemies: pulsing red aura at their feet.
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as BasicEnemy
		if enemy == null or enemy.is_dying():
			continue
		var at := _to_screen(enemy.global_position)
		if at.x < -60.0 or at.y < -60.0 or at.x > screen.x + 60.0 or at.y > screen.y + 60.0:
			continue
		var r := (enemy.get_collision_radius() + 8.0) * _zoom()
		_fx.draw_arc(at, r * (1.0 + 0.15 * pulse), 0.0, TAU, 24, Color(AURA, (0.55 + 0.3 * pulse) * k), 2.5)
		_fx.draw_circle(at, r, Color(AURA, (0.1 + 0.08 * pulse) * k))
	# Falling red ash.
	for ash in _ash:
		var p := Vector2(fposmod(float(ash["x"]) + float(ash["drift"]) * _time, 1.0) * screen.x, fposmod(float(ash["y"]) + float(ash["speed"]) * _time, 1.0) * screen.y)
		var r: float = ash["r"]
		var spin: float = float(ash["spin"]) + _time * 2.0
		_fx.draw_colored_polygon(PackedVector2Array([p + Vector2(r, 0).rotated(spin), p + Vector2(0, r * 0.6).rotated(spin), p + Vector2(-r, 0).rotated(spin), p + Vector2(0, -r * 0.6).rotated(spin)]), Color(ASH, 0.8 * k))
	# Heartbeat at the screen edge.
	var beat := fposmod(_time, 1.1)
	var heart := maxf(_pulse(beat, 0.0, 0.08, 0.25), _pulse(beat, 0.3, 0.08, 0.3) * 0.7)
	_vignette(screen, Color("5A0008"), (0.45 + 0.35 * heart) * k)


## Cheap vignette: translucent frames thickening toward the screen edge.
func _vignette(screen: Vector2, color: Color, strength: float) -> void:
	var steps := 14
	for index in range(steps):
		var u := float(index) / float(steps)
		var inset := u * minf(screen.x, screen.y) * 0.32
		var a := strength * pow(1.0 - u, 2.2) * 0.22
		var r := Rect2(Vector2(inset, inset), screen - Vector2(inset, inset) * 2.0)
		_fx.draw_rect(Rect2(Vector2.ZERO, Vector2(screen.x, r.position.y)), Color(color, a))
		_fx.draw_rect(Rect2(Vector2(0, r.end.y), Vector2(screen.x, screen.y - r.end.y)), Color(color, a))
		_fx.draw_rect(Rect2(Vector2(0, r.position.y), Vector2(r.position.x, r.size.y)), Color(color, a))
		_fx.draw_rect(Rect2(Vector2(r.end.x, r.position.y), Vector2(screen.x - r.end.x, r.size.y)), Color(color, a))
