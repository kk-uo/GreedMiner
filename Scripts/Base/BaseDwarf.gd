class_name BaseDwarf
extends Node2D

## A tiny top-down dwarf (style A): round helmet with a safety-orange lamp and
## a beard wedge pointing where it faces, little feet that step while walking.
## Entirely code-drawn, presentation only. Behaviours (`mode`):
## - &"route":   walk a fixed `route` back and forth, pausing at each end.
## - &"wander":  stroll to random floor points (`pick_point`), pause, look
##               around, then wander on; speed and pauses vary.
## - &"job":     loop through `steps` ({to, wait, face, carry, work}): haulers
##               pick up and drop crates, technicians repair (sparks fly).
## - &"station": stay near `route[0]` facing `facing`, glance around and now
##               and then shuffle a step or two (guards, the crane operator).
## Every walker steers around `obstacles` (circles / rects, parent space).
## `tool` draws a prop: &"axe", &"chart", &"wrench" or &"" (none).

## Points in the parent's space. One point = stand there, two or more = patrol.
var route: PackedVector2Array = PackedVector2Array()
var tunic: Color = Color("7A5A3A")
## Facing angle used while idle.
var facing: float = 0.0
## Multiplies the 1x mock dimensions (body radius 7) into world space.
var body_scale: float = 1.0
var walk_speed: float = 70.0
var pause_time: float = 1.6

var mode: StringName = &"route"
var tool: StringName = &""
var carrying: bool = false
## What `carrying` holds: &"crate" (ammo crate) or &"ore" (a glowing ore chunk).
var cargo: StringName = &"crate"
## job mode: [{to: Vector2, wait: float, face: Vector2 (optional), carry: bool (optional), work: bool (optional)}]
var steps: Array = []
## wander mode: returns a random free floor point (parent space).
var pick_point: Callable
## [{center: Vector2, radius: float}] or [{rect: Rect2}] in parent space.
var obstacles: Array = []
## station mode: when set, the hangar drives `facing` itself (crane operator).
var driven: bool = false

var _target_index: int = 1
var _pause_left: float = 0.0
var _time: float = 0.0
var _walking: bool = false
var _working: bool = false
var _target: Vector2
var _has_target: bool = false
var _walk_timeout: float = 0.0
var _look_left: float = 0.0
var _look_angle: float = 0.0
var _home_facing: float = 0.0
var _step_index: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_time = _rng.randf() * 10.0
	if not route.is_empty():
		position = route[0]
	_home_facing = facing
	_look_angle = facing
	_pause_left = _rng.randf() * pause_time
	if mode == &"wander":
		walk_speed *= _rng.randf_range(0.75, 1.15)


func _process(delta: float) -> void:
	_time += delta
	_walking = false
	_working = false
	match mode:
		&"wander":
			_process_wander(delta)
		&"job":
			_process_job(delta)
		&"station":
			_process_station(delta)
		_:
			_process_route(delta)
	queue_redraw()


# ==========================================
# Behaviours
# ==========================================

func _process_route(delta: float) -> void:
	if route.size() < 2:
		_idle_look(delta, 0.6)
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		_idle_look(delta, 0.8)
		return
	if _walk_to(route[_target_index], delta):
		_target_index = (_target_index + 1) % route.size()
		_pause_left = pause_time * _rng.randf_range(0.6, 1.5)


func _process_wander(delta: float) -> void:
	if _pause_left > 0.0:
		_pause_left -= delta
		_idle_look(delta, 1.6)
		return
	if not _has_target:
		if not pick_point.is_valid():
			return
		_target = pick_point.call()
		_has_target = true
		_walk_timeout = position.distance_to(_target) / walk_speed * 2.5 + 2.0
	_walk_timeout -= delta
	if _walk_to(_target, delta) or _walk_timeout <= 0.0:
		_has_target = false
		_pause_left = _rng.randf_range(1.2, 4.0)
		_look_left = _rng.randf_range(0.3, 0.9)


func _process_job(delta: float) -> void:
	if steps.is_empty():
		return
	var step: Dictionary = steps[_step_index]
	if _pause_left > 0.0:
		_pause_left -= delta
		_working = bool(step.get("work", false))
		if step.has("face"):
			facing = lerp_angle(facing, ((step["face"] as Vector2) - position).angle(), minf(delta * 6.0, 1.0))
		if _pause_left <= 0.0:
			if step.has("carry"):
				carrying = bool(step["carry"])
			_step_index = (_step_index + 1) % steps.size()
		return
	_walk_timeout += delta
	if _walk_to(step["to"], delta) or _walk_timeout > 14.0:
		_walk_timeout = 0.0
		_pause_left = float(step.get("wait", 0.8)) * _rng.randf_range(0.8, 1.3)


func _process_station(delta: float) -> void:
	if driven:
		return
	var home: Vector2 = route[0] if not route.is_empty() else position
	if _has_target:
		if _walk_to(_target, delta):
			_has_target = false
			_pause_left = _rng.randf_range(1.5, 3.5)
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		_idle_look(delta, 0.9)
		return
	# Shuffle a little: either a step or two aside, or back home.
	if position.distance_to(home) > 4.0:
		_target = home
	else:
		_target = home + Vector2.RIGHT.rotated(_rng.randf() * TAU) * 14.0 * body_scale
	_has_target = true
	_pause_left = _rng.randf_range(2.0, 4.5)


## Glance around: every so often turn the head to a new angle near home.
func _idle_look(delta: float, spread: float) -> void:
	_look_left -= delta
	if _look_left <= 0.0:
		_look_left = _rng.randf_range(0.8, 2.2)
		var base := _home_facing if mode != &"wander" else facing
		_look_angle = base + _rng.randf_range(-spread, spread)
		if mode == &"station" or mode == &"route":
			_look_angle = _home_facing + _rng.randf_range(-spread, spread)
	facing = lerp_angle(facing, _look_angle, minf(delta * 4.0, 1.0))


## Steps toward `target` around the obstacles; true once it has arrived.
func _walk_to(target: Vector2, delta: float) -> bool:
	var to_target := target - position
	var step := walk_speed * delta * (0.85 if carrying else 1.0)
	if to_target.length() <= step:
		position = target
		return true
	# Close to the goal: head straight in (steering there made dwarves circle
	# a target that sits next to an obstacle without ever arriving).
	var direction := to_target.normalized()
	if to_target.length() > 30.0 * body_scale:
		direction = _steer(direction, target)
	position += direction * step
	facing = lerp_angle(facing, direction.angle(), minf(delta * 10.0, 1.0))
	_walking = true
	return false


func _steer(direction: Vector2, target: Vector2) -> Vector2:
	var reach := 22.0 * body_scale
	for obstacle in obstacles:
		var nearest: Vector2
		if obstacle.has("rect"):
			var rect: Rect2 = obstacle["rect"]
			nearest = Vector2(clampf(position.x, rect.position.x, rect.end.x), clampf(position.y, rect.position.y, rect.end.y))
		else:
			var center: Vector2 = obstacle["center"]
			var offset := position - center
			if offset.length_squared() < 0.01:
				offset = Vector2.RIGHT
			nearest = center + offset.normalized() * float(obstacle["radius"])
		var away := position - nearest
		var distance := away.length()
		if distance >= reach or distance < 0.001:
			continue
		var toward := -away / distance
		if direction.dot(toward) <= 0.0:
			continue
		var tangent := Vector2(-toward.y, toward.x)
		if tangent.dot(target - position) < 0.0:
			tangent = -tangent
		var weight := 1.0 - distance / reach
		direction = (direction * (1.0 - weight) + tangent * weight * 1.3 + away / distance * weight * 0.25).normalized()
	return direction


# ==========================================
# Drawing
# ==========================================

## Everything below records into one shared batch and is submitted as a
## single draw command per frame.
static var _BATCH := MeshBatch2D.new()
var _pen: Object = self

func _draw() -> void:
	_pen = _BATCH
	_paint()
	_BATCH.flush_to(self)
	_pen = self


func _paint() -> void:
	# Walking dwarves bob quickly; idle ones breathe slowly.
	var bob := sin(_time * (14.0 if _walking else 2.0)) * (1.2 if _walking else 0.5)
	_pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * body_scale)
	_pen.draw_circle(Vector2(4.0, 5.0), 8.0, Palette.SHADOW_COLOR)

	_pen.draw_set_transform(Vector2(0.0, bob), facing, Vector2.ONE * body_scale)
	# Boots stepping under the body.
	var stride := sin(_time * 14.0) * 3.0 if _walking else 0.0
	for side in [-1.0, 1.0]:
		_pen.draw_circle(Vector2(1.5 + stride * side, 4.2 * side), 2.4, Color("2E2620"))
	_draw_tool_back()
	# Stocky shoulders, a beard tip poking out front, a big helmet on top.
	_pen.draw_colored_polygon(Palette.regular_polygon(7, 7.5, PI / 7.0), tunic)
	_pen.draw_colored_polygon(PackedVector2Array([Vector2(3, -4), Vector2(10, 0), Vector2(3, 4)]), Color("C98B52"))
	if carrying:
		_draw_crate()
	_pen.draw_circle(Vector2(-0.5, 0.0), 5.6, Palette.SHIP_PART)
	_pen.draw_circle(Vector2(-1.5, -1.0), 4.2, Palette.SHIP_BODY)
	_pen.draw_circle(Vector2(3.6, 0.0), 1.8, Palette.ACCENT)
	_draw_tool_front()
	_pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Ammo crate held out in front with both hands.
func _draw_crate() -> void:
	if cargo == &"ore":
		_draw_ore_chunk()
		return
	var box := Rect2(Vector2(5.0, -5.5), Vector2(9.0, 11.0))
	_pen.draw_rect(box, Palette.GOBLIN_WOOD_DARK)
	_pen.draw_rect(box.grow(-1.2), Palette.GOBLIN_WOOD)
	_pen.draw_line(Vector2(5.6, -4.8), Vector2(13.4, 4.8), Palette.GOBLIN_WOOD_DARK, 0.8)
	# Three brass shell tips on top.
	for y in [-2.8, 0.0, 2.8]:
		_pen.draw_circle(Vector2(9.5, y), 1.0, Palette.GOLD)
	for side in [-1.0, 1.0]:
		_pen.draw_circle(Vector2(5.5, 5.8 * side), 1.7, Color("C98B52"))


## A big gold ore chunk held out in front, glinting.
func _draw_ore_chunk() -> void:
	var glow := 0.7 + 0.3 * sin(_time * 4.0)
	_pen.draw_circle(Vector2(10.0, 0.0), 8.0, Color(Palette.GOLD, 0.18 * glow))
	_pen.draw_colored_polygon(PackedVector2Array([Vector2(5, -4), Vector2(10, -6.5), Vector2(15, -3), Vector2(14.5, 3.5), Vector2(9.5, 6), Vector2(5, 3)]), Color("B8862B"))
	_pen.draw_colored_polygon(PackedVector2Array([Vector2(5, -4), Vector2(10, -6.5), Vector2(15, -3), Vector2(10, -0.5)]), Palette.GOLD)
	_pen.draw_colored_polygon(PackedVector2Array([Vector2(10, -6.5), Vector2(12.5, -4.8), Vector2(10.5, -3.2)]), Color("FFF2C2"))
	for side in [-1.0, 1.0]:
		_pen.draw_circle(Vector2(5.5, 5.8 * side), 1.7, Color("C98B52"))


func _draw_tool_back() -> void:
	match tool:
		&"axe":
			# Long-hafted axe held upright at the right shoulder.
			_pen.draw_line(Vector2(-7.0, 7.0), Vector2(9.0, 7.5), Palette.GOBLIN_WOOD_DARK, 1.8)
			_pen.draw_colored_polygon(PackedVector2Array([Vector2(6.0, 7.5), Vector2(9.5, 3.5), Vector2(12.0, 7.5), Vector2(9.5, 11.5)]), Palette.GOBLIN_IRON_LIGHT)
			_pen.draw_line(Vector2(9.5, 3.8), Vector2(12.0, 7.5), Color.WHITE, 0.7)


func _draw_tool_front() -> void:
	match tool:
		&"chart":
			# Unrolled star chart held in front; dots and a route line.
			var tilt := sin(_time * 0.9) * 0.15
			var xf := Transform2D(tilt, Vector2(10.0, 0.0))
			var sheet := PackedVector2Array([xf * Vector2(-2.5, -6.0), xf * Vector2(3.0, -6.0), xf * Vector2(3.0, 6.0), xf * Vector2(-2.5, 6.0)])
			_pen.draw_colored_polygon(sheet, Color("1F2A3A"))
			_pen.draw_line(xf * Vector2(-2.5, -6.5), xf * Vector2(-2.5, 6.5), Palette.GOBLIN_BONE, 1.4)
			_pen.draw_line(xf * Vector2(3.0, -6.5), xf * Vector2(3.0, 6.5), Palette.GOBLIN_BONE, 1.4)
			_pen.draw_circle(xf * Vector2(0.5, -3.0), 0.8, Palette.GOLD)
			_pen.draw_circle(xf * Vector2(-0.5, 2.5), 0.7, Color("9FE7FF"))
			_pen.draw_line(xf * Vector2(0.5, -3.0), xf * Vector2(-0.5, 2.5), Color(Palette.GOLD, 0.6), 0.5)
		&"wrench":
			var swing := sin(_time * 12.0) * 0.5 if _working else 0.0
			var xf := Transform2D(swing - 0.4, Vector2(6.0, 5.0))
			_pen.draw_line(xf * Vector2(0.0, 0.0), xf * Vector2(8.0, 0.0), Palette.GOBLIN_IRON, 1.8)
			_pen.draw_arc(xf * Vector2(9.0, 0.0), 1.8, 0.8, TAU - 0.8, 8, Palette.GOBLIN_IRON_LIGHT, 1.4)
			if _working:
				# Sparks off the repair.
				for k in range(4):
					var ph := fposmod(_time * 3.0 + float(k) * 0.25, 1.0)
					var dir := Vector2.RIGHT.rotated(float(k) * 1.7 + _time)
					var p := Vector2(14.0, 4.0) + dir * ph * 7.0
					_pen.draw_circle(p, 0.9 * (1.0 - ph), Color(Palette.ACCENT_LIGHT, 1.0 - ph))
