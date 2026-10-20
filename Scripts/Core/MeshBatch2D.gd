class_name MeshBatch2D
extends RefCounted

## Records flat 2D draw calls (same names / arguments as CanvasItem) and bakes
## them into one vertex-coloured ArrayMesh. Draw order is preserved, so a
## static scene painted thousands of polygons at a time becomes a single
## draw_mesh() call — important for the GL Compatibility / Web renderer,
## which does not batch individual draw_colored_polygon() calls well.

## Vertices per mesh surface (multiple of 3).
const SURFACE_VERTEX_LIMIT: int = 60000

var _vertices := PackedVector2Array()
var _colors := PackedColorArray()
var _xf := Transform2D.IDENTITY
## Unit-circle triangle fans by segment count (built once, shared).
static var _FANS: Dictionary = {}


## Forgets everything recorded (reuse one batch per frame without allocating).
func clear() -> void:
	_vertices.clear()
	_colors.clear()
	_xf = Transform2D.IDENTITY


## Same as CanvasItem.draw_set_transform: applies to everything drawn after it.
func draw_set_transform(position: Vector2, rotation: float = 0.0, scale: Vector2 = Vector2.ONE) -> void:
	_xf = Transform2D(rotation, scale, 0.0, position)


func draw_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, point_count: int, color: Color, width: float = 1.0, _antialiased: bool = false) -> void:
	var points := PackedVector2Array()
	var count: int = maxi(point_count, 2)
	for index in range(count):
		points.append(center + Vector2.RIGHT.rotated(lerpf(start_angle, end_angle, float(index) / float(count - 1))) * radius)
	draw_polyline(points, color, width)


## Submits everything recorded as ONE triangle-array command on canvas, then
## clears the batch. Use instead of build() for shapes that change every frame.
func flush_to(canvas: CanvasItem) -> void:
	if not _vertices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), PackedInt32Array(), _vertices, _colors)
	clear()


func get_vertex_count() -> int:
	return _vertices.size()


func draw_colored_polygon(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3 or color.a <= 0.0:
		return
	if _xf != Transform2D.IDENTITY:
		points = _xf * points
	var indices := Geometry2D.triangulate_polygon(points)
	if indices.is_empty():
		for index in range(1, points.size() - 1):
			_raw_triangle(points[0], points[index], points[index + 1], color)
		return
	for index in indices:
		_vertices.append(points[index])
		_colors.append(color)


func draw_circle(center: Vector2, radius: float, color: Color, _filled: bool = true, _width: float = -1.0, _antialiased: bool = false) -> void:
	if radius <= 0.0 or color.a <= 0.0:
		return
	var segments: int = clampi(int(radius * 0.5) + 8, 10, 40)
	# A cached unit fan, scaled/moved in one transform: no per-triangle script work.
	var fan: PackedVector2Array = _FANS.get(segments, PackedVector2Array())
	if fan.is_empty():
		var previous := Vector2.RIGHT
		for index in range(1, segments + 1):
			var point := Vector2.RIGHT.rotated(TAU * float(index) / float(segments))
			fan.append(Vector2.ZERO)
			fan.append(previous)
			fan.append(point)
			previous = point
		_FANS[segments] = fan
	_vertices.append_array((_xf * Transform2D(0.0, Vector2(radius, radius), 0.0, center)) * fan)
	_append_color(color, fan.size())


func draw_line(from: Vector2, to: Vector2, color: Color, width: float = 1.0, _antialiased: bool = false) -> void:
	var direction := to - from
	if direction.length_squared() <= 0.0001 or color.a <= 0.0:
		return
	var side := Vector2(-direction.y, direction.x).normalized() * maxf(width, 1.0) * 0.5
	_triangle(from + side, to + side, to - side, color)
	_triangle(from + side, to - side, from - side, color)


func draw_polyline(points: PackedVector2Array, color: Color, width: float = 1.0, _antialiased: bool = false) -> void:
	for index in range(points.size() - 1):
		draw_line(points[index], points[index + 1], color, width)


func draw_rect(rect: Rect2, color: Color, filled: bool = true, width: float = 1.0, _antialiased: bool = false) -> void:
	if not filled:
		var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position])
		draw_polyline(corners, color, width)
		return
	var a := rect.position
	var b := Vector2(rect.end.x, rect.position.y)
	var c := rect.end
	var d := Vector2(rect.position.x, rect.end.y)
	_triangle(a, b, c, color)
	_triangle(a, c, d, color)


## Bakes everything recorded so far. Returns null when nothing was drawn.
func build() -> ArrayMesh:
	if _vertices.is_empty():
		return null
	var mesh := ArrayMesh.new()
	var start: int = 0
	while start < _vertices.size():
		var end: int = mini(start + SURFACE_VERTEX_LIMIT, _vertices.size())
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _vertices.slice(start, end)
		arrays[Mesh.ARRAY_COLOR] = _colors.slice(start, end)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
		start = end
	return mesh


func _append_color(color: Color, count: int) -> void:
	var colors := PackedColorArray()
	colors.resize(count)
	colors.fill(color)
	_colors.append_array(colors)


func _triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	if _xf != Transform2D.IDENTITY:
		_raw_triangle(_xf * a, _xf * b, _xf * c, color)
	else:
		_raw_triangle(a, b, c, color)


func _raw_triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	_vertices.append(a)
	_vertices.append(b)
	_vertices.append(c)
	_colors.append(color)
	_colors.append(color)
	_colors.append(color)
