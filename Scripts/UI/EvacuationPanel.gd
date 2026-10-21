class_name EvacuationPanel
extends Control

## The Big Red Button: a single arcade-style button that must be slammed
## REQUIRED_CLICKS times to evacuate. The count and the label live on the
## button itself, and a ring of segments around it lights up per press.
## Drawn entirely in code (style A, see docs/ART_STYLE.md).

signal evacuation_completed

## Number of deliberate presses required to leave the battlefield.
const REQUIRED_CLICKS: int = 10

## How far the dome sinks when pressed, in pixels.
const PRESS_DEPTH: float = 4.0

## Sized to read as "a bit bigger than one ship cell" at the default UI scale.
const DOME_RADIUS: float = 34.0
const BEZEL_RADIUS: float = 41.0
const RING_RADIUS: float = 51.0
const RING_WIDTH: float = 7.0
const BIG_FONT_SIZE: int = 21
const SMALL_FONT_SIZE: int = 10

## Seconds without a press before progress starts draining.
@export var decay_delay: float = 1.0
## Seconds per segment lost while draining.
@export var decay_interval: float = 0.35

## Darker red used for the dome's side wall (its visible thickness).
const DOME_WALL := Color("B3203A")
## Lighter red used for the dome's lit top-left facet and hover state.
const DOME_LIGHT := Color("FF6078")

var _click_count: int = 0
var _completed: bool = false
var _battle_active: bool = true

## 1.0 right after a press, eases back to 0.0 as the dome springs up.
var _press_amount: float = 0.0
## Short screen-space shake applied to the whole button on each press.
var _shake: float = 0.0
## Index of the ring segment that just lit up, flashes white briefly.
var _flash_segment: int = -1
var _flash_time: float = 0.0
var _hovered: bool = false
var _held: bool = false
var _time: float = 0.0
## Time since the last press; drives the drain.
var _idle_time: float = 0.0
var _decay_timer: float = 0.0
## Segment that was just lost, flashes red briefly.
var _drain_segment: int = -1
var _drain_time: float = 0.0


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	tooltip_text = tr("Press %d times to evacuate") % REQUIRED_CLICKS
	mouse_entered.connect(func() -> void: _hovered = true)
	mouse_exited.connect(func() -> void:
		_hovered = false
		_held = false
	)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_press_amount = move_toward(_press_amount, 1.0 if _held else 0.0, delta * (30.0 if _held else 9.0))
	_shake = move_toward(_shake, 0.0, delta * 40.0)
	_flash_time = maxf(_flash_time - delta, 0.0)
	_drain_time = maxf(_drain_time - delta, 0.0)
	_update_decay(delta)
	queue_redraw()


## Stop pressing and the count slowly falls back, forcing one continuous burst.
func _update_decay(delta: float) -> void:
	if not _is_pressable() or _click_count == 0:
		_idle_time = 0.0
		_decay_timer = 0.0
		return

	_idle_time += delta
	if _idle_time < decay_delay:
		return

	_decay_timer += delta
	while _decay_timer >= decay_interval and _click_count > 0:
		_decay_timer -= decay_interval
		_click_count -= 1
		_drain_segment = _click_count
		_drain_time = 0.2


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mouse := event as InputEventMouseButton
		# Only the round button and its progress ring are clickable.
		if mouse.pressed and mouse.position.distance_to(size * 0.5) > RING_RADIUS + RING_WIDTH:
			return
		_held = mouse.pressed and _is_pressable()
		if mouse.pressed:
			_press()
		accept_event()
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		_press()
		accept_event()


## Counts one press and completes exactly once.
func _press() -> void:
	if not _is_pressable():
		return

	_click_count = mini(_click_count + 1, REQUIRED_CLICKS)
	_idle_time = 0.0
	_decay_timer = 0.0
	_press_amount = 1.0
	_shake = 2.5
	_flash_segment = _click_count - 1
	_flash_time = 0.18

	if _click_count == REQUIRED_CLICKS:
		_completed = true
		_held = false
		evacuation_completed.emit()


## Enables or disables evacuation without pausing any battle systems.
func set_battle_active(is_active: bool) -> void:
	_battle_active = is_active
	if not _battle_active:
		_held = false
	queue_redraw()


func get_click_count() -> int:
	return _click_count


func is_completed() -> bool:
	return _completed


func _is_pressable() -> bool:
	if is_inside_tree():
		var weather := get_tree().get_first_node_in_group("battle_weather_manager") as WeatherManager
		if weather != null and weather.is_input_frozen():
			return false
	return _battle_active and not _completed


func _draw() -> void:
	var center := size * 0.5
	if _shake > 0.0:
		center += Vector2(sin(_time * 90.0), cos(_time * 77.0)) * _shake

	var disabled := not _battle_active and not _completed

	# No housing plate: the button sits directly on the battlefield,
	# grounded by the standard hard shadow.
	draw_circle(center + Palette.SHADOW_OFFSET * 0.6, RING_RADIUS + RING_WIDTH * 0.5, Palette.SHADOW_COLOR)

	_draw_progress_ring(center)

	# Gunmetal bezel the dome sits in.
	draw_circle(center, BEZEL_RADIUS, Palette.MECH)
	draw_circle(center + Vector2(-1.0, -1.0), BEZEL_RADIUS - 3.0, Palette.MECH_LIGHT)
	draw_circle(center + Vector2(0.5, 1.0), BEZEL_RADIUS - 5.0, Color("241D19"))

	# The dome: a visible red side wall that shrinks as the button sinks.
	var sink := PRESS_DEPTH * _press_amount
	var dome_top := center + Vector2(0.0, -PRESS_DEPTH + sink)
	var face := Palette.THREAT
	var wall := DOME_WALL
	var shine := DOME_LIGHT
	if _completed:
		face = Palette.ACCENT
		wall = Color("B8641A")
		shine = Color("FFB060")
	elif disabled:
		face = Palette.MECH_LIGHT
		wall = Palette.MECH
		shine = Color("6E655C")
	elif _hovered and not _held:
		face = face.lerp(DOME_LIGHT, 0.25)

	draw_circle(center, DOME_RADIUS, wall)
	draw_circle(dome_top, DOME_RADIUS, face)
	_draw_dome_shine(dome_top, shine)

	_draw_labels(dome_top, disabled)


## Ten segments around the dome; each press lights one more.
func _draw_progress_ring(center: Vector2) -> void:
	var gap := 0.07
	var step := TAU / float(REQUIRED_CLICKS)
	for index in range(REQUIRED_CLICKS):
		var start := -PI * 0.5 + step * float(index) + gap * 0.5
		var color := Palette.MECH
		var draining := _idle_time >= decay_delay
		if index < _click_count:
			color = Palette.ACCENT if _completed else Palette.UI_TEXT
			if draining:
				# Warn that progress is slipping away.
				color = Palette.UI_TEXT.lerp(DOME_LIGHT, 0.5 + 0.5 * sin(_time * 18.0))
			if index == _flash_segment and _flash_time > 0.0:
				color = Palette.HIT_FLASH
		elif index == _drain_segment and _drain_time > 0.0:
			color = Palette.THREAT
		elif index == _click_count and _is_pressable() and _click_count > 0:
			# The next segment to fill breathes gently to invite another press.
			color = Palette.MECH.lerp(Palette.UI_MUTED, 0.35 + 0.25 * sin(_time * 6.0))
		draw_arc(center, RING_RADIUS, start, start + step - gap, 12, color, RING_WIDTH)


## Flat lit facet in the top-left of the dome (no gradients).
func _draw_dome_shine(dome_center: Vector2, shine: Color) -> void:
	var dome := Palette.offset_points(Palette.regular_polygon(48, DOME_RADIUS - 3.0), dome_center)
	var cutter := Palette.offset_points(Palette.regular_polygon(48, DOME_RADIUS), dome_center + Vector2(5.0, 6.0))
	for part in Geometry2D.clip_polygons(dome, cutter):
		draw_colored_polygon(part, shine)


func _draw_labels(dome_center: Vector2, disabled: bool) -> void:
	var font := get_theme_default_font()
	var ink := Palette.UI_PANEL if not disabled else Color("2A231E")

	var big: String
	var small: String
	if _completed:
		big = "GO"
		small = "LIFT OFF"
	elif disabled:
		big = "--"
		small = "OFFLINE"
	else:
		big = "%d/%d" % [_click_count, REQUIRED_CLICKS]
		small = "EVACUATE"

	var width := DOME_RADIUS * 2.0
	small = tr(small)
	draw_string(font, dome_center + Vector2(-DOME_RADIUS, 4.0), big, HORIZONTAL_ALIGNMENT_CENTER, width, BIG_FONT_SIZE, ink)
	draw_string(font, dome_center + Vector2(-DOME_RADIUS, 17.0), small, HORIZONTAL_ALIGNMENT_CENTER, width, SMALL_FONT_SIZE, ink)
