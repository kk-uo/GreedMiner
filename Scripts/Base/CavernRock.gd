extends Node2D

## Solid rock that surrounds the dwarven hold (replaces the old starfield).
## A jittered grid of rock slabs separated by dark seams; slabs near the
## hold are a little lighter, the far ones fade into the dark. Static: drawn
## once. AsteroidHangar adds it as a child with show_behind_parent and scales
## it by LAYOUT_SCALE, so everything here is in mock (1280x720) coordinates.
## Load with preload(); no class_name on purpose.

## Area covered (mock coords); generous so wide screens never see past it.
const AREA := Rect2(-560.0, -360.0, 2400.0, 1440.0)
const CELL: float = 74.0
const JITTER: float = 26.0
const SEAM := Color("191310")
const TONES: Array[Color] = [Color("231B16"), Color("2B221C"), Color("33291F"), Color("3C3026"), Color("463829")]
const EDGE_LIGHT := Color("5A4733")

## Outline of the hold (ASTEROID polygon); slabs fully inside are skipped.
var hold: PackedVector2Array = PackedVector2Array()
var _slabs: Array = []


func _ready() -> void:
	show_behind_parent = true
	_build()
	queue_redraw()


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	var columns := int(ceil(AREA.size.x / CELL)) + 1
	var rows := int(ceil(AREA.size.y / CELL)) + 1
	var grid: Array = []
	for row in range(rows + 1):
		var line: Array = []
		for column in range(columns + 1):
			var base := AREA.position + Vector2(float(column) * CELL + (CELL * 0.5 if row % 2 == 1 else 0.0), float(row) * CELL)
			line.append(base + Vector2(rng.randf_range(-JITTER, JITTER), rng.randf_range(-JITTER, JITTER)))
		grid.append(line)
	var center := Vector2(640.0, 360.0)
	for row in range(rows):
		for column in range(columns):
			var quad := PackedVector2Array([grid[row][column], grid[row][column + 1], grid[row + 1][column + 1], grid[row + 1][column]])
			var inside := true
			for point in quad:
				if not Geometry2D.is_point_in_polygon(point, hold):
					inside = false
					break
			if inside:
				continue
			# Now and then split a slab into two triangles for variety.
			var pieces: Array = [quad]
			if rng.randf() < 0.35:
				pieces = [PackedVector2Array([quad[0], quad[1], quad[2]]), PackedVector2Array([quad[0], quad[2], quad[3]])]
			for piece in pieces:
				var mid := Vector2.ZERO
				for point in piece:
					mid += point
				mid /= float(piece.size())
				# Lighter near the hold, darker far away.
				var reach: float = (mid - center).length() / Vector2(700.0, 480.0).length()
				var tone_index := clampi(int(round(lerpf(4.2, 0.0, clampf((reach - 0.62) / 0.75, 0.0, 1.0)))) + rng.randi_range(-1, 0), 0, TONES.size() - 1)
				var inset := PackedVector2Array()
				for point in piece:
					inset.append(point + (mid - point).normalized() * 1.6)
				_slabs.append({"points": inset, "color": TONES[tone_index], "light": tone_index >= 2})


## Static: baked once into a single mesh (hundreds of slabs as one draw call).
var _mesh: ArrayMesh
var _pen: Object

func _draw() -> void:
	if _mesh == null:
		var batch := MeshBatch2D.new()
		_pen = batch
		_paint()
		_pen = null
		_mesh = batch.build()
	if _mesh != null:
		draw_mesh(_mesh, null)


func _paint() -> void:
	_pen.draw_rect(AREA, SEAM)
	for slab in _slabs:
		var points: PackedVector2Array = slab["points"]
		_pen.draw_colored_polygon(points, slab["color"])
		if slab["light"]:
			# Lit top-left edge: the two vertices closest to the top-left.
			var best := 0
			var second := 1
			for index in range(points.size()):
				if points[index].x + points[index].y < points[best].x + points[best].y:
					second = best
					best = index
				elif index != best and points[index].x + points[index].y < points[second].x + points[second].y:
					second = index
			var mid := Vector2.ZERO
			for point in points:
				mid += point
			mid /= float(points.size())
			var a := points[best].lerp(mid, 0.16)
			var b := points[second].lerp(mid, 0.16)
			_pen.draw_line(a, b, Color(EDGE_LIGHT, 0.6), 2.4)
