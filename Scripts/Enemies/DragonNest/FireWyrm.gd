extends BasicEnemy

## Ancient Dragon phase two summon (Claude sync 90): a serpent of living fire
## that crawls slowly at the ship, always breathing a short cone of flame
## ahead. Once it touches the hull it burns it continuously (fast melee ticks,
## BasicEnemy attack timer). Ground unit, so every weapon can shoot it.
## Load via its scene; no class_name on purpose (see sync 81).

const SEGMENTS: int = 9
const SEGMENT_GAP: float = 13.0
const FLAME_DARK := Color("A8261C")
const FLAME := Color("F06A24")
const FLAME_LIGHT := Color("FFC861")
const CORE := Color("FFF2C2")

var _trail: Array[Vector2] = []
var _t: float = 0.0


func _ready() -> void:
	super()
	_t = randf() * 10.0
	_trail.clear()


func _process(delta: float) -> void:
	_t += delta
	_update_hit_feedback(delta)
	# Body segments follow the head's path.
	var head := global_position
	if _trail.is_empty() or _trail[0].distance_to(head) >= 3.0:
		_trail.push_front(head)
		if _trail.size() > SEGMENTS * 6:
			_trail.pop_back()
	queue_redraw()


func _get_visual_radius() -> float:
	return 26.0


func _body_points() -> Array[Vector2]:
	# Resample the trail every SEGMENT_GAP pixels (local space).
	var points: Array[Vector2] = [Vector2.ZERO]
	var dir := Vector2.from_angle(_facing + PI)
	var last := global_position
	var walked := 0.0
	var next := SEGMENT_GAP
	for p in _trail:
		var step := last.distance_to(p)
		while walked + step >= next and points.size() < SEGMENTS:
			var k := (next - walked) / maxf(step, 0.001)
			points.append(to_local(last.lerp(p, k)))
			next += SEGMENT_GAP
		walked += step
		last = p
	while points.size() < SEGMENTS:
		points.append(points[points.size() - 1] + dir.rotated(-global_rotation) * SEGMENT_GAP)
	return points


func _draw() -> void:
	var body := _body_points()
	var forward := Vector2.from_angle(_facing - global_rotation)
	# Breath cone ahead, always on.
	var cone_len := 58.0 + 10.0 * sin(_t * 17.0)
	var side := forward.orthogonal()
	draw_colored_polygon(PackedVector2Array([forward * 16.0 + side * 6.0, forward * (16.0 + cone_len) + side * 26.0, forward * (16.0 + cone_len * 1.1), forward * (16.0 + cone_len) - side * 26.0, forward * 16.0 - side * 6.0]), Color(FLAME, 0.45))
	draw_colored_polygon(PackedVector2Array([forward * 16.0 + side * 3.0, forward * (16.0 + cone_len * 0.7) + side * 12.0, forward * (16.0 + cone_len * 0.8), forward * (16.0 + cone_len * 0.7) - side * 12.0, forward * 16.0 - side * 3.0]), Color(FLAME_LIGHT, 0.7))
	# Body: tail to head, each segment a flickering flame disc.
	for index in range(body.size() - 1, -1, -1):
		var k := 1.0 - float(index) / float(SEGMENTS)
		var r := 6.0 + 12.0 * k
		var flick := 1.0 + 0.12 * sin(_t * 14.0 + float(index) * 1.3)
		var p: Vector2 = body[index] + side * sin(_t * 6.0 + float(index) * 0.8) * 3.0 * (1.0 - k)
		draw_circle(p, r * 1.5 * flick, Color(FLAME_DARK, 0.28))
		draw_circle(p, r * flick, Color(FLAME, 0.85))
		draw_circle(p + Vector2(-r * 0.2, -r * 0.2), r * 0.55 * flick, Color(FLAME_LIGHT, 0.9))
		# Flame licks rising off the back.
		if index % 2 == 0:
			var lick := p - side * r * 0.2 + Vector2(0, -r * (1.2 + 0.4 * sin(_t * 11.0 + index)))
			draw_colored_polygon(PackedVector2Array([p + side * r * 0.4, lick, p - side * r * 0.4]), Color(FLAME_LIGHT, 0.6))
	# Head: horn flames and two white-hot eyes.
	var head: Vector2 = body[0]
	for sd in [1.0, -1.0]:
		draw_colored_polygon(PackedVector2Array([head + side * 8.0 * sd, head - forward * 22.0 + side * 16.0 * sd, head - forward * 6.0 + side * 4.0 * sd]), Color(FLAME_DARK, 0.9))
		draw_circle(head + forward * 7.0 + side * 6.0 * sd, 3.6, CORE)
		draw_circle(head + forward * 7.0 + side * 6.0 * sd, 6.0, Color(FLAME_LIGHT, 0.35))
