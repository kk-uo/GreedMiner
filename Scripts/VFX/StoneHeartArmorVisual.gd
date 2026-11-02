extends Node2D

## Stone Heart's Rock Armor drawn on the ship (design A "stone shell"):
## twelve irregular rock chunks sit on the hull rim, three per side. They
## crack with glowing orange seams as the armor drops (two stages), flash and
## shed chips on every absorbed hit, and burst outward with a shockwave ring
## when the armor shatters. While it reforms, only faint dashed outlines are
## left and a small Stone Heart with a countdown ring floats above the top
## edge; when it is back the chunks snap in with a flash.
##
## Added by StoneHeartEffect as a child of the Ship (ship-local coordinates;
## the hull spans 0..Ship.SHIP_SIZE). Presentation only.
## Load with preload(); no class_name on purpose.

const ArtifactVisual := preload("res://Scripts/UI/Artifacts/ArtifactVisual.gd")

const STONE_DARK := Color("4A3B2F")
const STONE := Color("7E6C5C")
const STONE_LIGHT := Color("A08C76")
const STONE_HI := Color("C2AF96")
const CRACK := Color("F08A24")
const CRACK_HOT := Color("FFB347")
const FLASH := Color("FFF2C2")
const DUST := Color("B8A48C")

## How far outside the hull edge the chunks sit, and their size.
## Chunks float well outside the hull so its outline (the custom ship) stays
## visible between them.
const RIM_OFFSET: float = -38.0
const CHUNK_LENGTH: float = 46.0
const CHUNK_DEPTH: float = 20.0
const CHUNK_GAP: float = 22.0
const SHATTER_TIME: float = 0.7
const RESTORE_TIME: float = 0.35
const HIT_TIME: float = 0.28

var effect: Node
var _chunks: Array = []
var _armor_ratio: float = 1.0
var _broken: bool = false
var _time: float = 0.0
var _shatter_age: float = -1.0
var _restore_age: float = -1.0
var _hits: Array = []  # [{chunk, age}]
var _rng := RandomNumberGenerator.new()


func setup(stone_effect: Node) -> void:
	effect = stone_effect
	effect.connect("armor_changed", _on_armor_changed)
	effect.connect("armor_shattered", _on_shattered)
	effect.connect("armor_restored", _on_restored)


func _ready() -> void:
	z_index = 2
	_rng.seed = 4242
	_build_chunks()
	# Rebuild when the hull grows or changes shape (after the Ship has).
	ShipLoadout.expansion_changed.connect(_rebuild_chunks, CONNECT_DEFERRED)
	ShipLoadout.hull_changed.connect(func(_id: StringName) -> void: _rebuild_chunks(), CONNECT_DEFERRED)


## One chunk outside every exposed hull edge, so the armor follows the ship's
## real outline (expansion cells, plus shapes...). Each is a jagged polygon.
var _hull_center: Vector2 = Ship.SHIP_SIZE * 0.5
var _hull_radius: float = 160.0


func _hull_cells() -> Array[Vector2i]:
	var ship := get_parent() as Ship
	if ship != null:
		var cells := ship.get_hull_cells()
		if not cells.is_empty():
			return cells
	var square: Array[Vector2i] = []
	for row in range(Ship.GRID_SIZE):
		for column in range(Ship.GRID_SIZE):
			square.append(Vector2i(column, row))
	return square


func _rebuild_chunks() -> void:
	_build_chunks()
	queue_redraw()


func _build_chunks() -> void:
	_chunks.clear()
	var cells := _hull_cells()
	var lookup := {}
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for cell in cells:
		lookup[cell] = true
		lo = lo.min(Vector2(cell) * Ship.CELL_SIZE)
		hi = hi.max((Vector2(cell) + Vector2.ONE) * Ship.CELL_SIZE)
	_hull_center = (lo + hi) * 0.5
	_hull_radius = (hi - lo).length() * 0.5 + 25.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var half := Ship.CELL_SIZE * 0.5
	for cell in cells:
		for dir in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			if lookup.has(cell + dir):
				continue
			var normal := Vector2(dir)
			var tangent := normal.rotated(PI * 0.5)
			var anchor := (Vector2(cell) + Vector2(0.5, 0.5)) * Ship.CELL_SIZE + normal * (half - RIM_OFFSET)
			# Inner corners would put two chunks on top of each other.
			var crowded := false
			for other in _chunks:
				if (other["anchor"] as Vector2).distance_to(anchor) < 40.0:
					crowded = true
					break
			if crowded:
				continue
			var length := CHUNK_LENGTH * rng.randf_range(0.86, 1.0)
			var depth := CHUNK_DEPTH * rng.randf_range(0.85, 1.12)
			var points := PackedVector2Array()
			var corners := [
				Vector2(-0.5, -0.5), Vector2(-0.15, -0.62), Vector2(0.2, -0.55), Vector2(0.5, -0.42),
				Vector2(0.56, 0.05), Vector2(0.46, 0.5), Vector2(0.05, 0.6), Vector2(-0.35, 0.52), Vector2(-0.56, 0.12),
			]
			for corner in corners:
				var c: Vector2 = corner
				var bump := Vector2(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.1, 0.1))
				var local := Vector2((c.x + bump.x) * length, (c.y + bump.y) * depth)
				points.append(anchor + tangent * local.x + normal * local.y)
			var facet := PackedVector2Array()
			for k in [0, 1, 2, 8]:
				facet.append(points[k].lerp(anchor, 0.35) + Vector2(-1.0, -1.0))
			var crack := PackedVector2Array([
				anchor + tangent * (-length * 0.3) + normal * (-depth * 0.25),
				anchor + tangent * (rng.randf_range(-0.05, 0.05) * length) + normal * (depth * 0.05),
				anchor + tangent * (length * 0.18) + normal * (depth * 0.3),
			])
			_chunks.append({
				"points": points, "facet": facet, "crack": crack, "anchor": anchor, "normal": normal,
				"spin": rng.randf_range(-3.5, 3.5), "stage": _chunks.size() % 2,
			})


func _process(delta: float) -> void:
	_time += delta
	if _shatter_age >= 0.0:
		_shatter_age += delta
		if _shatter_age > SHATTER_TIME:
			_shatter_age = -1.0
	if _restore_age >= 0.0:
		_restore_age += delta
		if _restore_age > RESTORE_TIME:
			_restore_age = -1.0
	for hit in _hits.duplicate():
		hit["age"] += delta
		if hit["age"] > HIT_TIME:
			_hits.erase(hit)
	queue_redraw()


func _on_armor_changed(current: float, maximum: float) -> void:
	var ratio := current / maxf(maximum, 0.001)
	if ratio < _armor_ratio and current > 0.0:
		_hits.append({"chunk": _rng.randi_range(0, _chunks.size() - 1), "age": 0.0})
	_armor_ratio = ratio


func _on_shattered() -> void:
	_broken = true
	_shatter_age = 0.0
	_hits.clear()


func _on_restored() -> void:
	_broken = false
	_armor_ratio = 1.0
	_restore_age = 0.0


func _draw() -> void:
	if not _broken:
		_draw_armor()
	else:
		_draw_ghosts()
		_draw_countdown()
	if _shatter_age >= 0.0:
		_draw_shatter(_shatter_age / SHATTER_TIME)
	if _restore_age >= 0.0:
		var t := _restore_age / RESTORE_TIME
		draw_arc(_hull_center, lerpf(_hull_radius + 25.0, _hull_radius - 10.0, t), 0.0, TAU, 64, Color(CRACK_HOT, 0.9 * (1.0 - t)), 6.0 * (1.0 - t) + 1.0)


func _draw_armor() -> void:
	# Two crack stages: below 2/3 armor half the chunks crack, below 1/3 all.
	var cracked_stage := 2 if _armor_ratio <= 0.34 else (1 if _armor_ratio <= 0.67 else 0)
	var pop := 1.0
	if _restore_age >= 0.0:
		pop = lerpf(1.25, 1.0, clampf(_restore_age / RESTORE_TIME, 0.0, 1.0))
	for index in range(_chunks.size()):
		var chunk: Dictionary = _chunks[index]
		var anchor: Vector2 = chunk["anchor"]
		var points := _scaled(chunk["points"], anchor, pop)
		draw_colored_polygon(Palette.offset_points(points, Vector2(3.0, 4.0)), Palette.SHADOW_COLOR)
		draw_colored_polygon(points, STONE_DARK)
		draw_colored_polygon(_scaled(points, anchor, 0.86), STONE)
		draw_colored_polygon(_scaled(chunk["facet"], anchor, pop), STONE_LIGHT)
		if int(chunk["stage"]) < cracked_stage:
			var crack: PackedVector2Array = chunk["crack"]
			var glow := 0.75 + 0.25 * sin(_time * 5.0 + float(index))
			draw_polyline(crack, Color(CRACK, glow), 2.4)
			draw_polyline(crack, Color(CRACK_HOT, 0.6 * glow), 1.0)
	# Hit: white flash on the struck chunk and a few chips flying off.
	for hit in _hits:
		var chunk: Dictionary = _chunks[int(hit["chunk"])]
		var t: float = float(hit["age"]) / HIT_TIME
		draw_colored_polygon(chunk["points"], Color(FLASH, 0.8 * (1.0 - t)))
		var anchor: Vector2 = chunk["anchor"]
		var normal: Vector2 = chunk["normal"]
		for k in range(4):
			var spread := normal.rotated((float(k) - 1.5) * 0.45)
			var p := anchor + spread * (6.0 + 22.0 * t)
			draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(4, 3.0 * (1.0 - t * 0.5), float(k)), p), Color(STONE_HI, 1.0 - t))


func _draw_ghosts() -> void:
	var alpha := 0.45 + 0.1 * sin(_time * 2.5)
	for chunk in _chunks:
		var points: PackedVector2Array = chunk["points"]
		for index in range(points.size()):
			var a := points[index]
			var b := points[(index + 1) % points.size()]
			draw_dashed_line(a, b, Color(STONE_HI, alpha), 1.4, 4.0)


## Small Stone Heart with a ring that fills while the armor reforms.
func _draw_countdown() -> void:
	if effect == null or not effect.has_method("get_regeneration_remaining"):
		return
	var total: float = maxf(float(effect.get("regeneration_delay")), 0.001)
	var progress := 1.0 - clampf(float(effect.call("get_regeneration_remaining")) / total, 0.0, 1.0)
	var at := Vector2(_hull_center.x, _hull_center.y - _hull_radius + 60.0)
	draw_circle(at + Vector2(2.0, 3.0), 17.0, Palette.SHADOW_COLOR)
	draw_circle(at, 17.0, Color(Palette.UI_PANEL, 0.9))
	draw_arc(at, 15.0, 0.0, TAU, 40, STONE_DARK, 3.5)
	if progress > 0.0:
		draw_arc(at, 15.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, CRACK, 3.5)
	ArtifactVisual.draw_icon(self, at + Vector2(0.0, 1.0), 22.0, &"stone_heart", 2)


func _draw_shatter(t: float) -> void:
	var center := _hull_center
	var ease := 1.0 - pow(1.0 - t, 2.0)
	# Chunks fly outward, spinning and fading.
	for chunk in _chunks:
		var anchor: Vector2 = chunk["anchor"]
		var normal: Vector2 = chunk["normal"]
		var tangent := (anchor - center).normalized()
		var offset := (normal * 0.6 + tangent * 0.4).normalized() * 70.0 * ease
		var spin: float = float(chunk["spin"]) * ease
		var moved := PackedVector2Array()
		for point in chunk["points"]:
			moved.append(anchor + offset + ((point as Vector2) - anchor).rotated(spin) * (1.0 - 0.4 * t))
		var alpha := 1.0 - smoothstep(0.55, 1.0, t)
		draw_colored_polygon(moved, Color(STONE, alpha))
	# Shockwave ring (orange core + dusty outer band) and dust puffs.
	var radius := lerpf(_hull_radius, _hull_radius + 65.0, ease)
	draw_arc(center, radius, 0.0, TAU, 72, Color(STONE_LIGHT, 0.45 * (1.0 - t)), 14.0 * (1.0 - t) + 2.0)
	draw_arc(center, radius, 0.0, TAU, 72, Color(CRACK_HOT, 0.95 * (1.0 - t)), 5.0 * (1.0 - t) + 1.0)
	for index in range(16):
		var a := TAU * float(index) / 16.0 + 0.2
		var p := center + Vector2(cos(a), sin(a)) * lerpf(_hull_radius - 2.0, _hull_radius + 50.0, ease)
		draw_circle(p, lerpf(4.0, 11.0, ease), Color(DUST, 0.55 * (1.0 - t)))


static func _scaled(points: PackedVector2Array, pivot: Vector2, factor: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(pivot + (point - pivot) * factor)
	return result
