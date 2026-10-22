extends Node2D

## Graveyard Planet battlefield decoration (style C "biomass seep"): random
## tombstones and tombstone clusters - lone stones and 3 x 3 grave clusters -
## with glowing green biomass seeping out of the grave soil and pooling
## between the graves.
##
## Battlefield calls generate() while it builds the map (before rocks), so
## the clusters claim their ground. The static art is baked once into a mesh;
## only the biomass glow pulses (two baked glow meshes, alternating phase).
## Presentation only. Load with preload(); no class_name on purpose.

## Everything is drawn at this scale so the stones read at battle zoom.
const DRAW_SCALE: float = 1.2
const MAP_GRAVE := preload("res://Scripts/Battle/Graveyard/MapGrave.gd")

## Placement rules (world pixels, distances from the ship's hull edge):
## one 9-stone cluster 200-300 px from the ship, two more clusters elsewhere,
## at least NEAR_STONES single stones 100-200 px from the ship, and about
## EXTRA_STONES single stones over the rest of the map. Every stone is a
## monster spawn point (get_emerge_points()).
const CLUSTER_STONES: int = 9
const NEAR_CLUSTER_BAND := Vector2(200.0, 300.0)
const FAR_CLUSTERS: int = 2
const FAR_CLUSTER_MIN_HULL: float = 450.0
const FAR_CLUSTER_SPACING: float = 700.0
const NEAR_STONES: int = 5
const NEAR_STONE_BAND := Vector2(100.0, 200.0)
const EXTRA_STONES: int = 20
const EXTRA_MIN_HULL: float = 260.0
## Footprint used to keep things apart (world px).
const STONE_RADIUS: float = 20.0
const CLUSTER_RADIUS: float = 115.0

const DARK := Color("4A4F4A")
const STONE := Color("7F877C")
const LIT := Color("A9B1A3")
const ENGRAVE := Color("2A3328")
const DIRT := Color("3A3128")
const DIRT_LIGHT := Color("5A4A38")
const BIO_DEEP := Color("1E2A1C")
const BIO_BASE := Color("3E9C30")
const BIO := Color("4FC23C")
const BIO_HOT := Color("B8FF7A")

var stones: Array = []   # {pos, kind, size, tilt, broken, glow, phase}
var plots: Array = []    # {rect} 3 x 3 cluster areas (no fence drawn)
var crypts: Array = []   # {pos, size, phase}
var graves: Array = []   # {pos, tilt, phase}
var pools: Array = []    # {pos, r, seed, phase}

var _pen: Object = self
var _static_mesh: ArrayMesh
var _glow_meshes: Array = [null, null]
var _time: float = 0.0
var _diggable_stones: Array[Node2D] = []


## Places the clusters and single stones (see the rules above), avoiding
## claimed areas, and claims the ground they use.
func generate(battlefield: Node, seed_value: int) -> void:
	for proxy in _diggable_stones:
		if is_instance_valid(proxy):
			proxy.queue_free()
	_diggable_stones.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	stones.clear(); plots.clear(); crypts.clear(); graves.clear(); pools.clear()
	scale = Vector2.ONE * DRAW_SCALE
	var bounds: Rect2 = battlefield.get_world_bounds().grow(-140.0)
	var center: Vector2 = bounds.get_center()
	var cluster_centers: Array[Vector2] = []
	# 1) The cluster close to the ship.
	var near_cluster_ok := func(at: Vector2) -> bool:
		var d: float = battlefield.get_ship_hull_distance(at)
		return d >= NEAR_CLUSTER_BAND.x and d <= NEAR_CLUSTER_BAND.y
	var near_cluster := _find_spot(battlefield, rng, bounds, CLUSTER_RADIUS, near_cluster_ok, true)
	if near_cluster != Vector2.INF:
		cluster_centers.append(near_cluster)
	# 2) Two clusters elsewhere on the map, apart from each other.
	var far_cluster_ok := func(at: Vector2) -> bool:
		if battlefield.get_ship_hull_distance(at) < FAR_CLUSTER_MIN_HULL:
			return false
		for other in cluster_centers:
			if at.distance_to(other) < FAR_CLUSTER_SPACING:
				return false
		return true
	for _index in range(FAR_CLUSTERS):
		var spot := _find_spot(battlefield, rng, bounds, CLUSTER_RADIUS, far_cluster_ok, false)
		if spot != Vector2.INF:
			cluster_centers.append(spot)
	for spot in cluster_centers:
		battlefield.claim_area(spot, CLUSTER_RADIUS)
		_add_cluster(rng, to_local(spot))
	# 3) Single stones around the ship, spread over sectors.
	var near_stone_ok := func(at: Vector2) -> bool:
		var d: float = battlefield.get_ship_hull_distance(at)
		return d >= NEAR_STONE_BAND.x and d <= NEAR_STONE_BAND.y
	var near_angle := rng.randf() * TAU
	for index in range(NEAR_STONES):
		var sector := near_angle + TAU * float(index) / float(NEAR_STONES)
		var spot := _find_spot(battlefield, rng, bounds, STONE_RADIUS, near_stone_ok, true, center, sector)
		if spot != Vector2.INF:
			battlefield.claim_area(spot, STONE_RADIUS)
			_add_single(rng, to_local(spot))
	# 4) Extra single stones over the rest of the map.
	var extra_ok := func(at: Vector2) -> bool:
		return battlefield.get_ship_hull_distance(at) >= EXTRA_MIN_HULL
	for _index in range(EXTRA_STONES):
		var spot := _find_spot(battlefield, rng, bounds, STONE_RADIUS, extra_ok, false)
		if spot != Vector2.INF:
			battlefield.claim_area(spot, STONE_RADIUS)
			_add_single(rng, to_local(spot))
	stones.sort_custom(func(a, b): return (a["pos"] as Vector2).y < (b["pos"] as Vector2).y)
	for stone in stones:
		var proxy: Node2D = MAP_GRAVE.new()
		proxy.set("stone", stone)
		proxy.position = stone["pos"]
		add_child(proxy)
		_diggable_stones.append(proxy)
	_static_mesh = null
	_glow_meshes = [null, null]
	queue_redraw()


## Random free world spot passing `accept` (Vector2.INF if none found).
## near_ship ignores the clearing around the ship. With a sector angle the
## first tries stay within that direction from `origin`.
func _find_spot(battlefield: Node, rng: RandomNumberGenerator, bounds: Rect2, radius: float, accept: Callable,
		near_ship: bool, origin: Vector2 = Vector2.ZERO, sector: float = NAN) -> Vector2:
	for attempt in range(1200):
		var at: Vector2
		if not is_nan(sector) and attempt < 400:
			var a := sector + rng.randf_range(-0.6, 0.6)
			at = origin + Vector2.RIGHT.rotated(a) * rng.randf_range(80.0, 360.0)
		else:
			at = Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		if not bounds.has_point(at) or not accept.call(at):
			continue
		var free: bool = battlefield.is_area_free_near_ship(at, radius) if near_ship else battlefield.is_area_free(at, radius)
		if free:
			return at
	return Vector2.INF


## A cluster: 3 x 3 stones in loose rows (no fence).
func _add_cluster(rng: RandomNumberGenerator, at: Vector2) -> void:
	var cols := 3
	var rows := 3
	var size := Vector2(cols * 34.0 + 26.0, rows * 40.0 + 24.0)
	plots.append({"rect": Rect2(at - size * 0.5, size)})
	for r in range(rows):
		for c in range(cols):
			var p := at - size * 0.5 + Vector2(30.0 + 34.0 * float(c), 34.0 + 40.0 * float(r)) + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
			_add_stone(rng, p, rng.randf_range(0.8, 1.0))
	if rng.randf() < 0.6:
		pools.append({"pos": at + Vector2(rng.randf_range(-30.0, 30.0), size.y * 0.5 + 18.0), "r": rng.randf_range(16.0, 24.0), "seed": rng.randf() * TAU, "phase": rng.randi_range(0, 1)})


func _add_single(rng: RandomNumberGenerator, at: Vector2) -> void:
	_add_stone(rng, at, rng.randf_range(0.9, 1.2))
	if rng.randf() < 0.25:
		pools.append({"pos": at + Vector2(rng.randf_range(-24.0, 24.0), rng.randf_range(22.0, 34.0)), "r": rng.randf_range(12.0, 20.0), "seed": rng.randf() * TAU, "phase": rng.randi_range(0, 1)})


## Monster spawn points: in front of every tombstone (world positions).
func get_emerge_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for stone in stones:
		points.append(to_global(stone["pos"] + Vector2(0.0, 16.0 * float(stone["size"]))))
	for grave in graves:
		points.append(to_global(grave["pos"]))
	return points


## Expose the original map stones to the same digging system as zombie graves.
func get_diggable_stones_in(world_position: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for proxy in _diggable_stones:
		if not is_instance_valid(proxy) or proxy.is_queued_for_deletion():
			continue
		if is_instance_valid(proxy.get("dig_site")):
			continue
		if proxy.global_position.distance_to(world_position) <= radius:
			result.append(proxy)
	return result


## Removing a stone also removes its spawn point and refreshes the baked art.
func remove_stone(stone: Dictionary) -> void:
	if not stones.has(stone):
		return
	stones.erase(stone)
	_static_mesh = null
	_glow_meshes = [null, null]
	queue_redraw()


func _add_stone(rng: RandomNumberGenerator, at: Vector2, s: float) -> void:
	stones.append({"pos": at, "kind": rng.randi_range(0, 3), "size": s, "tilt": rng.randf_range(-0.14, 0.14),
		"broken": rng.randf() < 0.12, "glow": rng.randf() < 0.45, "seed": rng.randf() * TAU, "phase": rng.randi_range(0, 1)})


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _static_mesh == null:
		_static_mesh = _bake(func(): _paint_static())
		for phase in range(2):
			_glow_meshes[phase] = _bake(func(): _paint_glow(phase))
	if _static_mesh != null:
		draw_mesh(_static_mesh, null)
	for phase in range(2):
		if _glow_meshes[phase] != null:
			var pulse := 0.5 + 0.5 * sin(_time * 1.7 + PI * float(phase))
			draw_mesh(_glow_meshes[phase], null, Transform2D.IDENTITY, Color(1, 1, 1, 0.55 + 0.45 * pulse))


func _bake(paint: Callable) -> ArrayMesh:
	var batch := MeshBatch2D.new()
	_pen = batch
	paint.call()
	_pen = self
	return batch.build() if batch.get_vertex_count() > 0 else null


func _paint_static() -> void:
	for pool in pools:
		_pool_base(pool)
	for grave in graves:
		_open_grave(grave)
	for crypt in crypts:
		_crypt(crypt)
	for stone in stones:
		_stone(stone)


## Glow parts of one phase group (pulsed together through the mesh modulate).
func _paint_glow(phase: int) -> void:
	for pool in pools:
		if int(pool["phase"]) == phase:
			var at: Vector2 = pool["pos"]
			var r: float = pool["r"]
			_pen.draw_circle(at, r * 1.5, Color(BIO, 0.12))
			_pen.draw_colored_polygon(_scaled(_blob(pool), at + Vector2(-r * 0.15, -r * 0.08), 0.55), Color(BIO_HOT, 0.85))
	for stone in stones:
		if bool(stone["glow"]) and int(stone["phase"]) == phase:
			var s: float = stone["size"]
			_pen.draw_set_transform(stone["pos"], float(stone["tilt"]), Vector2.ONE * s)
			_pen.draw_circle(Vector2(0, 13), 14.0, Color(BIO, 0.16))
			_pen.draw_colored_polygon(Palette.offset_points(_scaled(_seep(stone), Vector2(0, 13), 0.55), Vector2(-1.5, -0.8)), Color(BIO_HOT, 0.95))
			_pen.draw_rect(Rect2(-6, -4, 10, 5), Color(BIO, 0.26))
			_pen.draw_set_transform(Vector2.ZERO)
	for grave in graves:
		if int(grave["phase"]) == phase:
			_pen.draw_set_transform(grave["pos"], float(grave["tilt"]))
			_pen.draw_rect(Rect2(-8, 12, 16, 8), Color(BIO, 0.75))
			_pen.draw_set_transform(Vector2.ZERO)
	for crypt in crypts:
		if int(crypt["phase"]) == phase:
			_pen.draw_set_transform(crypt["pos"], 0.0, Vector2.ONE * float(crypt["size"]))
			_pen.draw_rect(Rect2(-8, -8, 16, 24), Color(BIO, 0.6))
			_pen.draw_circle(Vector2(0, 22), 14.0, Color(BIO, 0.2))
			_pen.draw_set_transform(Vector2.ZERO)


func _blob(pool: Dictionary) -> PackedVector2Array:
	var at: Vector2 = pool["pos"]
	var r: float = pool["r"]
	var points := PackedVector2Array()
	for k in range(11):
		var a := TAU * float(k) / 11.0 + float(pool["seed"])
		points.append(at + Vector2(cos(a) * r * (1.0 + 0.25 * sin(a * 3.0 + float(pool["seed"]))), sin(a) * r * 0.6))
	return points


func _seep(stone: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in range(12):
		var a := TAU * float(k) / 12.0
		points.append(Vector2(cos(a) * 8.5 * (1.0 + 0.2 * sin(a * 3.0 + float(stone["seed"]))), 13.0 + sin(a) * 4.5))
	return points


func _pool_base(pool: Dictionary) -> void:
	var blob := _blob(pool)
	_pen.draw_colored_polygon(Palette.offset_points(blob, Vector2(0, 1.5)), BIO_DEEP)
	_pen.draw_colored_polygon(blob, BIO_BASE)


## A standing slab seen from the 3/4 top-down camera, face to the bottom of
## the screen, shadow to the lower right, a grave mound in front.
func _stone(stone: Dictionary) -> void:
	var s: float = stone["size"]
	_pen.draw_set_transform(stone["pos"], float(stone["tilt"]), Vector2.ONE * s)
	_pen.draw_colored_polygon(PackedVector2Array([Vector2(-8, 2), Vector2(10, 2), Vector2(16, 8), Vector2(-2, 8)]), Color(0, 0, 0, 0.28))
	var mound := PackedVector2Array()
	for k in range(12):
		var a := TAU * float(k) / 12.0
		mound.append(Vector2(cos(a) * 9.5, 13.0 + sin(a) * 6.0))
	_pen.draw_colored_polygon(mound, Color(DIRT, 0.55))
	if bool(stone["glow"]):
		_pen.draw_colored_polygon(_seep(stone), BIO_BASE)
	match int(stone["kind"]):
		1:  # Cross
			_pen.draw_rect(Rect2(-2.6, -22, 5.2, 24), DARK)
			_pen.draw_rect(Rect2(-8.5, -16, 17, 5), DARK)
			_pen.draw_rect(Rect2(-2.6, -22, 3.4, 23), STONE)
			_pen.draw_rect(Rect2(-8.5, -16, 15.5, 3.4), LIT)
		2:  # Obelisk
			_pen.draw_colored_polygon(PackedVector2Array([Vector2(-6, 2), Vector2(-4, -20), Vector2(0, -27), Vector2(4, -20), Vector2(6, 2)]), DARK)
			_pen.draw_colored_polygon(PackedVector2Array([Vector2(-5, 1.5), Vector2(-3.2, -19.5), Vector2(0, -25.5), Vector2(0.5, 1.5)]), STONE)
			_pen.draw_rect(Rect2(-8, -1, 16, 4), DARK)
			_pen.draw_rect(Rect2(-8, -1, 13, 2), LIT)
		3:  # Wide flat-top slab
			_pen.draw_rect(Rect2(-10, -15, 20, 17), DARK)
			_pen.draw_rect(Rect2(-10, -15, 17, 15.5), STONE)
			_pen.draw_rect(Rect2(-11, -17, 22, 3), LIT)
			_pen.draw_line(Vector2(-6, -9), Vector2(3, -9), ENGRAVE, 1.4)
			_pen.draw_line(Vector2(-6, -5), Vector2(1, -5), ENGRAVE, 1.4)
		_:  # Rounded slab
			var slab := PackedVector2Array([Vector2(-8, 2), Vector2(-8, -12)])
			for k in range(9):
				slab.append(Vector2(-8.0 * cos(PI * float(k) / 8.0), -12.0 - 8.0 * sin(PI * float(k) / 8.0)))
			slab.append(Vector2(8, 2))
			_pen.draw_colored_polygon(slab, DARK)
			var front := PackedVector2Array()
			for p in slab:
				front.append(p * Vector2(0.8, 0.92) + Vector2(-1.2, 0.0))
			_pen.draw_colored_polygon(front, STONE)
			_pen.draw_arc(Vector2(-1.2, -12), 5.4, PI * 1.1, PI * 1.6, 6, LIT, 1.6)
			_pen.draw_line(Vector2(-5, -9), Vector2(2.5, -9), ENGRAVE, 1.3)
			_pen.draw_line(Vector2(-4.5, -5.5), Vector2(1.5, -5.5), ENGRAVE, 1.3)
			_pen.draw_line(Vector2(-4, -2), Vector2(0.5, -2), ENGRAVE, 1.3)
	if bool(stone["broken"]):
		_pen.draw_polyline(PackedVector2Array([Vector2(1, -21), Vector2(-2, -15), Vector2(2, -11), Vector2(-1, -6)]), ENGRAVE, 1.6)
		_pen.draw_colored_polygon(PackedVector2Array([Vector2(8, 4), Vector2(14, 2), Vector2(15, 7), Vector2(9, 8)]), STONE)
	_pen.draw_set_transform(Vector2.ZERO)


func _open_grave(grave: Dictionary) -> void:
	_pen.draw_set_transform(grave["pos"], float(grave["tilt"]))
	_pen.draw_colored_polygon(PackedVector2Array([Vector2(-18, -12), Vector2(-4, -20), Vector2(8, -18), Vector2(14, -10), Vector2(0, -6)]), DIRT_LIGHT)
	_pen.draw_rect(Rect2(-12, -8, 24, 30), DIRT)
	_pen.draw_rect(Rect2(-10, -6, 20, 26), Color("15110E"))
	_pen.draw_rect(Rect2(-10, -6, 20, 4), Color("2A221B"))
	for k in range(5):
		_pen.draw_circle(Vector2(-14.0 + 7.0 * float(k), -14.0 + float((k * 3) % 4)), 3.0, DIRT_LIGHT)
	# Shovel stuck in the dirt pile.
	_pen.draw_line(Vector2(10, -16), Vector2(18, -34), Color("6B4A2A"), 2.4)
	_pen.draw_colored_polygon(PackedVector2Array([Vector2(7, -12), Vector2(13, -12), Vector2(12, -19), Vector2(8, -19)]), Color("8A8F96"))
	_pen.draw_set_transform(Vector2.ZERO)


func _crypt(crypt: Dictionary) -> void:
	_pen.draw_set_transform(crypt["pos"], 0.0, Vector2.ONE * float(crypt["size"]))
	_pen.draw_colored_polygon(PackedVector2Array([Vector2(-34, 18), Vector2(40, 18), Vector2(52, 30), Vector2(-22, 30)]), Color(0, 0, 0, 0.3))
	_pen.draw_colored_polygon(PackedVector2Array([Vector2(-38, -40), Vector2(38, -40), Vector2(42, -24), Vector2(-42, -24)]), DARK)
	_pen.draw_colored_polygon(PackedVector2Array([Vector2(-38, -40), Vector2(30, -40), Vector2(0, -32)]), LIT)
	_pen.draw_rect(Rect2(-34, -24, 68, 42), DARK)
	_pen.draw_rect(Rect2(-34, -24, 58, 40), STONE)
	for x in [-26.0, 18.0]:
		_pen.draw_rect(Rect2(x, -22, 7, 38), LIT)
	_pen.draw_rect(Rect2(-10, -12, 20, 30), Color("161416"))
	_pen.draw_arc(Vector2(0, -12), 10.0, PI, TAU, 12, Color("161416"), 4.0)
	_pen.draw_rect(Rect2(-2, -54, 4, 16), LIT)
	_pen.draw_rect(Rect2(-7, -49, 14, 4), LIT)
	_pen.draw_set_transform(Vector2.ZERO)


func _scaled(points: PackedVector2Array, pivot: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(pivot + (p - pivot) * k)
	return out
