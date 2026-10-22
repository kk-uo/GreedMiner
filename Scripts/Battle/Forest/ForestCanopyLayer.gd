extends Node2D

## Static forest floor: the dark floor beyond the clearing, bushes and fallen
## logs on the clearing's rim, and decorative crowns only OUTSIDE the
## gameplay bounds (map border). Every tree inside the bounds is a ForestTree
## drawn by ForestTreeChunks on top of this. Baked once into one mesh.
## Load with preload(); no class_name on purpose.

const ART := preload("res://Scripts/Battle/Forest/ForestArt.gd")

var _mesh: ArrayMesh


## `bounds` is where the gameplay trees grow; only the border outside it gets
## decorative crowns.
func build(world_size: Vector2, center: Vector2, clearing_radius: float, seed_value: int, bounds: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x43414E4F
	var pen := MeshBatch2D.new()
	var edge_phase := rng.randf() * TAU
	var edge := func(point: Vector2) -> float:
		var a := (point - center).angle()
		return clearing_radius * (1.0 + 0.10 * sin(a * 3.0 + edge_phase) + 0.06 * sin(a * 7.0 + edge_phase * 2.0))
	# Shady forest floor beyond the clearing so gaps between crowns read dark.
	var far := world_size.length() + 400.0
	for k in range(64):
		var a0 := TAU * float(k) / 64.0
		var a1 := TAU * float(k + 1) / 64.0
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		var r0: float = float(edge.call(center + d0)) - 10.0
		var r1: float = float(edge.call(center + d1)) - 10.0
		pen.draw_colored_polygon(PackedVector2Array([center + d0 * r0, center + d1 * r1, center + d1 * far, center + d0 * far]), ART.FLOOR)
	# Crowns on a jittered grid; small first, big ones on top.
	var spacing := 44.0
	var smalls: Array = []
	var bigs: Array = []
	var y := -60.0
	while y < world_size.y + 60.0:
		var x := -60.0
		while x < world_size.x + 60.0:
			var p := Vector2(x, y) + Vector2(rng.randf_range(-16, 16), rng.randf_range(-16, 16))
			var d := p.distance_to(center)
			var limit: float = edge.call(p)
			if d >= limit:
				if not bounds.grow(-20.0).has_point(p):
					smalls.append([p, rng.randf_range(32.0, 46.0), "oak", rng.randi()])
			elif d > limit - 70.0 and rng.randf() < 0.18:
				# The clearing's rim: bushes, stumps and fallen logs.
				var roll := rng.randf()
				smalls.push_front([p, rng.randf_range(16.0, 24.0), "bushes" if roll < 0.65 else "log", rng.randi()])
			x += spacing
		y += spacing
	for item in smalls + bigs:
		var p: Vector2 = item[0]
		var r: float = item[1]
		var s: int = item[3]
		match item[2]:
			"giant": ART.giant_oak(pen, p, r, s)
			"willow": ART.willow(pen, p, r, s)
			"bushes": ART.bushes(pen, p, r * 1.6, s)
			"stump": ART.stump(pen, p, r * 0.8, s)
			"log": ART.log(pen, p, r * 1.6, s)
			_: ART.canopy(pen, p, r, s, ART.OAK if s % 3 != 0 else ART.OAK_DEEP)
	_mesh = pen.build() if pen.get_vertex_count() > 0 else null
	queue_redraw()


func _draw() -> void:
	if _mesh != null:
		draw_mesh(_mesh, null)
