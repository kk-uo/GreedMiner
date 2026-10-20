extends Node2D

## Battle-only overlay: the attack range of the weapon the player clicked,
## drawn as a soft disc with a slowly turning dashed ring around the turret.
## Follows the turret every frame (the ship can rotate) and hides when the
## turret goes away. Presentation only; BattleMain decides what is shown.

const RING_COLOR := Color("FFF4E0")
const DASH_COLOR := Color("F08A24")
const FILL_ALPHA: float = 0.07
const DASH_COUNT: int = 48
const OPEN_TIME: float = 0.16

var target: Node2D = null
var radius: float = 0.0
var _age: float = 0.0
## Hull mode (Knockback): a band hugging the ship outline instead of a circle.
var _hull_ship: Node2D = null
var _hull_size: Vector2 = Vector2.ZERO

const HULL_COLOR := Color("EEE6FF")
const HULL_DASH := Color("B69CFF")


func _ready() -> void:
	z_as_relative = false
	z_index = 30
	visible = false
	set_process(false)


## Shows the ring around module (range in world units). Same module again or
## null hides it.
func toggle(module: Node2D, range_radius: float) -> void:
	if module == null or (visible and module == target):
		hide_ring()
		return
	target = module
	radius = range_radius
	_hull_ship = null
	_age = 0.0
	visible = true
	set_process(true)
	_follow()
	queue_redraw()


## Knockback-style range: everything within margin of the ship hull
## (ship-local rect hull_size). Same module again hides it.
func toggle_hull(module: Node2D, ship_node: Node2D, hull_size: Vector2, margin: float) -> void:
	if module == null or (visible and module == target):
		hide_ring()
		return
	target = module
	radius = margin
	_hull_ship = ship_node
	_hull_size = hull_size
	_age = 0.0
	visible = true
	set_process(true)
	_follow()
	queue_redraw()


func hide_ring() -> void:
	target = null
	_hull_ship = null
	visible = false
	set_process(false)


func is_showing() -> bool:
	return visible and is_instance_valid(target)


func _process(delta: float) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		hide_ring()
		return
	_age += delta
	_follow()
	queue_redraw()


func _follow() -> void:
	if _hull_ship != null and is_instance_valid(_hull_ship):
		global_transform = _hull_ship.global_transform
	elif is_instance_valid(target):
		global_transform = Transform2D(0.0, target.global_position)


func _draw() -> void:
	if radius <= 0.0:
		return
	if _hull_ship != null:
		_draw_hull_band()
		return
	var k: float = clampf(_age / OPEN_TIME, 0.0, 1.0)
	var r: float = radius * (0.7 + 0.3 * (1.0 - pow(1.0 - k, 3.0)))
	var alpha: float = k
	draw_circle(Vector2.ZERO, r, Color(RING_COLOR, FILL_ALPHA * alpha))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(RING_COLOR, 0.55 * alpha), 2.0)
	# Turning dashes just inside the ring.
	var spin: float = _age * 0.35
	var step: float = TAU / float(DASH_COUNT)
	for index in range(DASH_COUNT):
		var start: float = spin + float(index) * step
		draw_arc(Vector2.ZERO, r - 5.0, start, start + step * 0.5, 4, Color(DASH_COLOR, 0.8 * alpha), 2.4)
	draw_circle(Vector2.ZERO, 3.0, Color(DASH_COLOR, 0.9 * alpha))


func _draw_hull_band() -> void:
	var k: float = clampf(_age / OPEN_TIME, 0.0, 1.0)
	var margin: float = radius * (0.7 + 0.3 * (1.0 - pow(1.0 - k, 3.0)))
	var rect := Rect2(Vector2.ZERO, _hull_size).grow(margin)
	var outline := Palette.rounded_rect_points(rect, margin, 8)
	draw_colored_polygon(outline, Color(HULL_DASH, 0.08 * k))
	outline.append(outline[0])
	draw_polyline(outline, Color(HULL_COLOR, 0.6 * k), 2.0)
	# Marching dashes just inside the band.
	var inner := Palette.rounded_rect_points(rect.grow(-5.0), maxf(margin - 5.0, 1.0), 8)
	inner.append(inner[0])
	var travelled := 0.0
	var offset := fposmod(_age * 30.0, 18.0)
	for index in range(inner.size() - 1):
		var a := inner[index]
		var b := inner[index + 1]
		var length := a.distance_to(b)
		var t := 0.0
		while t < length:
			var phase := fposmod(travelled + t + offset, 18.0)
			if phase < 9.0:
				var end := minf(t + 9.0 - phase, length)
				draw_line(a.lerp(b, t / length), a.lerp(b, end / length), Color(HULL_DASH, 0.85 * k), 2.4)
				t = end
			else:
				t += 18.0 - phase
		travelled += length
