class_name MiningSkillCheck
extends Node2D

## Precision Mining arc skill check (v0.7, Identity V style), drawn in the
## battlefield right above its Mining Module — no separate panel.
##
## WARNING (precision_warning_duration s): the arc appears dimmed with
## "GET READY" + countdown. CHECK: a needle sweeps the arc once from its left
## end to its right end at needle_speed_degrees. One attempt: Space, or a click
## anywhere on the battlefield (the bar or empty ground), stops it. A green Success region (success_zone_degrees) sits at
## a random spot; a gold Perfect region (perfect_zone_degrees) is centred in
## it. Missing, or letting the needle reach the end, is a failure.
## RESULT: short coloured pulse; the owning event shows the reward text.
##
## Gameplay positions are measured along the track: 0 = left end,
## arc_sweep_degrees = right end (that length and needle_speed_degrees set the
## timing). The drawn bar is a gentle, wide curve (VISUAL_SWEEP_DEGREES of a
## large circle) above the module; text floats semi-transparent above it.
## Only Space and left clicks are consumed, and only while the needle moves.

signal check_started
signal finished(result: StringName)

enum Phase { WARNING, CHECK, RESULT }

## Drawn bar: a slice of a big circle, so it reads as a gently curved bar.
const ARC_RADIUS: float = 150.0
const VISUAL_SWEEP_DEGREES: float = 72.0
const TRACK_WIDTH: float = 13.0
const RESULT_TIME: float = 1.1
## Node origin = the bar's top-centre point, this far above the module.
const MODULE_OFFSET := Vector2(0.0, -86.0)
## Text floats this far above the bar.
const TEXT_OFFSET := Vector2(0.0, -34.0)
const TEXT_ALPHA: float = 0.78
## Keeps the bar this far inside the visible screen (screen pixels).
const SCREEN_MARGIN := Vector2(120.0, 80.0)
## Shared white QTE look: translucent white track, solid white success
## region, gold perfect region, white needle.
const SUCCESS_COLOR := Color(1.0, 1.0, 1.0)
const FAIL_COLOR := Color("8D857C")

var config: MiningQteConfig
## Success region start (degrees along the arc).
var zone_start: float = 90.0
## Needle position (degrees along the arc).
var needle: float = 0.0
var phase: int = Phase.WARNING
var result: StringName = &""
## Only the player's very first QTE shows "SPACE / CLICK".
var show_click_label: bool = false
## World node the arc follows (the Mining Module). May be null in tests.
var anchor: Node2D

var _timer: float = 0.0
var _age: float = 0.0
var _result_age: float = 0.0
## Result line set by the event, e.g. "PERFECT! +120".
var result_text: String = ""


func setup(qte_config: MiningQteConfig, zone_start_degrees: float, follow: Node2D = null) -> void:
	config = qte_config
	zone_start = zone_start_degrees
	anchor = follow


## Pure rule used by press(): perfect / success / failed for a needle angle.
## The Perfect region is centred inside the Success region.
static func evaluate(angle: float, start: float, success_size: float, perfect_size: float) -> StringName:
	var offset: float = angle - start
	if offset < 0.0 or offset > success_size:
		return MiningQteEvent.OUTCOME_FAILED
	if absf(offset - success_size * 0.5) <= perfect_size * 0.5:
		return MiningQteEvent.OUTCOME_PERFECT
	return MiningQteEvent.OUTCOME_SUCCESS


## Perfect region start (degrees along the arc) for a success region start.
static func perfect_start(start: float, success_size: float, perfect_size: float) -> float:
	return start + (success_size - perfect_size) * 0.5


## Random success-region start that always fits on the arc.
static func random_zone_start(qte_config: MiningQteConfig) -> float:
	var latest: float = minf(qte_config.zone_max_start_degrees, qte_config.arc_sweep_degrees - qte_config.success_zone_degrees - 5.0)
	var earliest: float = minf(qte_config.zone_min_start_degrees, latest)
	return randf_range(earliest, latest)


func _ready() -> void:
	if config == null:
		config = MiningQteManager.DEFAULT_CONFIG
	z_as_relative = false
	z_index = 40
	_follow()


func start_warning(duration: float) -> void:
	phase = Phase.WARNING
	_timer = maxf(duration, 0.0)
	needle = 0.0
	if _timer <= 0.0:
		_begin_check()


func is_checking() -> bool:
	return phase == Phase.CHECK


## The single input attempt. Ignored outside the CHECK phase.
func press() -> StringName:
	if phase != Phase.CHECK:
		return &""
	var outcome := evaluate(needle, zone_start, config.success_zone_degrees, config.perfect_zone_degrees)
	_finish(outcome)
	return outcome


## Advances the check by delta seconds (also used by tests).
func advance(delta: float) -> void:
	_age += delta
	match phase:
		Phase.WARNING:
			_timer -= delta
			if _timer <= 0.0:
				_begin_check()
		Phase.CHECK:
			needle += config.needle_speed_degrees * delta
			if needle >= config.arc_sweep_degrees:
				needle = config.arc_sweep_degrees
				_finish(MiningQteEvent.OUTCOME_FAILED)
		Phase.RESULT:
			_result_age += delta
			if _result_age >= RESULT_TIME:
				queue_free()
	queue_redraw()


func _process(delta: float) -> void:
	_follow()
	advance(delta)


## Sits above the module, nudged back inside the screen near the edges.
func _follow() -> void:
	if not is_inside_tree():
		return
	var base: Vector2 = (anchor.global_position if is_instance_valid(anchor) else global_position - MODULE_OFFSET) + MODULE_OFFSET
	var canvas := get_viewport().get_canvas_transform()
	var screen: Vector2 = canvas * base
	var rect := get_viewport().get_visible_rect()
	screen.x = clampf(screen.x, rect.position.x + SCREEN_MARGIN.x, rect.end.x - SCREEN_MARGIN.x)
	screen.y = clampf(screen.y, rect.position.y + SCREEN_MARGIN.y, rect.end.y - SCREEN_MARGIN.y)
	global_position = canvas.affine_inverse() * screen


func _input(event: InputEvent) -> void:
	var weather := get_tree().get_first_node_in_group("battle_weather_manager") as WeatherManager
	if weather != null and weather.is_input_frozen():
		return
	if phase != Phase.CHECK:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		press()


func _unhandled_input(event: InputEvent) -> void:
	var weather := get_tree().get_first_node_in_group("battle_weather_manager") as WeatherManager
	if weather != null and weather.is_input_frozen():
		return
	if phase != Phase.CHECK:
		return
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		# Any left click on the battlefield counts while the needle moves
		# (on the bar or on empty ground); HUD buttons still get theirs first.
		get_viewport().set_input_as_handled()
		press()


## True when a local point is on (or close to) the drawn bar.
func is_on_bar(local: Vector2) -> bool:
	var from_center: Vector2 = local - _circle_center()
	if absf(from_center.length() - ARC_RADIUS) > TRACK_WIDTH + 18.0:
		return false
	var angle: float = rad_to_deg(from_center.angle()) + 90.0
	return absf(angle) <= VISUAL_SWEEP_DEGREES * 0.5 + 6.0


func _begin_check() -> void:
	phase = Phase.CHECK
	needle = 0.0
	check_started.emit()


func _finish(outcome: StringName) -> void:
	if phase == Phase.RESULT:
		return
	result = outcome
	phase = Phase.RESULT
	_result_age = 0.0
	finished.emit(outcome)


## Centre of the big circle the bar is cut from (local; origin = bar top).
func _circle_center() -> Vector2:
	return Vector2(0.0, ARC_RADIUS)


## Track position (0..arc_sweep_degrees) → canvas radians on the drawn bar.
func _rad(along: float) -> float:
	var k: float = along / maxf(config.arc_sweep_degrees, 0.01)
	return deg_to_rad(-90.0 - VISUAL_SWEEP_DEGREES * 0.5 + VISUAL_SWEEP_DEGREES * k)


func _point(along: float, radius: float = ARC_RADIUS) -> Vector2:
	return _circle_center() + Vector2.RIGHT.rotated(_rad(along)) * radius


func _bar(from: float, to: float, color: Color, width: float, points: int = 24) -> void:
	draw_arc(_circle_center(), ARC_RADIUS, _rad(from), _rad(to), points, color, width)


func _draw() -> void:
	var sweep: float = config.arc_sweep_degrees
	var warning: bool = phase == Phase.WARNING
	var fade: float = 1.0
	if phase == Phase.RESULT:
		fade = clampf((RESULT_TIME - _result_age) / 0.3, 0.0, 1.0)
	var dim: float = 0.45 if warning else 1.0
	var c := _circle_center()
	# Backing + track.
	draw_arc(c + Vector2(2.0, 3.0), ARC_RADIUS, _rad(0.0), _rad(sweep), 40, Color(0, 0, 0, 0.25 * fade), TRACK_WIDTH + 7.0)
	_bar(0.0, sweep, Color(1, 1, 1, 0.16 * fade), TRACK_WIDTH + 7.0, 40)
	_bar(0.0, sweep, Color(1, 1, 1, 0.22 * fade), TRACK_WIDTH, 40)
	# Regions.
	var success_color := SUCCESS_COLOR
	var perfect_color := Palette.GOLD
	if phase == Phase.RESULT and result == MiningQteEvent.OUTCOME_FAILED:
		success_color = FAIL_COLOR
		perfect_color = FAIL_COLOR
	_bar(zone_start, zone_start + config.success_zone_degrees, Color(success_color, dim * fade), TRACK_WIDTH, 10)
	var p_start: float = perfect_start(zone_start, config.success_zone_degrees, config.perfect_zone_degrees)
	_bar(p_start, p_start + config.perfect_zone_degrees, Color(perfect_color, dim * fade), TRACK_WIDTH + 3.0, 4)
	# End caps and ticks.
	for along in [0.0, sweep]:
		draw_line(_point(along, ARC_RADIUS - TRACK_WIDTH * 0.7), _point(along, ARC_RADIUS + TRACK_WIDTH * 0.7), Color(Palette.UI_MUTED, fade), 2.5)
	for index in range(1, 8):
		var along: float = sweep * float(index) / 8.0
		draw_line(_point(along, ARC_RADIUS - TRACK_WIDTH * 0.5), _point(along, ARC_RADIUS - TRACK_WIDTH * 0.15), Color(Palette.UI_MUTED, 0.55 * fade), 1.4)
	# Needle riding the bar.
	if not warning:
		var tip_in: Vector2 = _point(needle, ARC_RADIUS - TRACK_WIDTH * 0.95)
		var tip_out: Vector2 = _point(needle, ARC_RADIUS + TRACK_WIDTH * 1.15)
		draw_line(tip_in, tip_out, Color(0.08, 0.06, 0.05, 0.6 * fade), 6.5)
		draw_line(tip_in, tip_out, Color(1, 1, 1, fade), 3.4)
		draw_circle(tip_out, 4.4, Color(1, 1, 1, fade))
	# Text: no backing, large, semi-transparent, above the bar.
	if warning:
		var pulse: float = 0.5 + 0.5 * sin(_age * 10.0)
		MiningQteVisual.draw_text(self, TEXT_OFFSET, "GET READY  %d" % ceili(maxf(_timer, 0.0)), 20, Palette.UI_TEXT, TEXT_ALPHA * (0.75 + 0.25 * pulse))
	elif phase == Phase.CHECK:
		if show_click_label:
			MiningQteVisual.draw_text(self, TEXT_OFFSET, "SPACE / CLICK", 18, Palette.UI_TEXT, TEXT_ALPHA * 0.85)
	else:
		var k: float = clampf(_result_age / 0.45, 0.0, 1.0)
		var pulse_color: Color = FAIL_COLOR
		if result == MiningQteEvent.OUTCOME_PERFECT:
			pulse_color = Palette.GOLD
		elif result == MiningQteEvent.OUTCOME_SUCCESS:
			pulse_color = SUCCESS_COLOR
		var strength: float = 0.5 if result == MiningQteEvent.OUTCOME_FAILED else 1.0
		draw_arc(c, ARC_RADIUS - 2.0 - 18.0 * k, _rad(0.0), _rad(sweep), 40, Color(pulse_color, (1.0 - k) * 0.9 * strength), 4.0 * (1.0 - k) + 0.6)
		var pop: float = 1.0 + 0.25 * maxf(1.0 - _result_age / 0.18, 0.0)
		draw_set_transform(TEXT_OFFSET + Vector2(0.0, -10.0 * minf(_result_age / 0.4, 1.0)), 0.0, Vector2.ONE * pop)
		MiningQteVisual.draw_text(self, Vector2.ZERO, result_text, 24, pulse_color, TEXT_ALPHA * fade)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
