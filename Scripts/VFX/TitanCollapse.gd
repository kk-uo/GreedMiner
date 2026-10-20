class_name TitanCollapse
extends Node2D

## Death effect for the Rock Titan (style A, code-drawn, frees itself).
##
## 1. A purple flash and shock ring where the crystal heart breaks.
## 2. Purple crystal shards spray outward.
## 3. Grey boulders are thrown into the air, land with a bounce, then fade.
## 4. A big rolling dust cloud (StoneDust) and a crater with cracks and glowing
##    purple fissures that linger on the ground (TitanCollapse.Scar).

const DURATION: float = 3.6
const GRAVITY: float = 900.0

## Size of the titan in world pixels; everything scales from it.
var radius: float = 165.0

var _age: float = 0.0
var _rng := RandomNumberGenerator.new()
var _shards: Array[Dictionary] = []
var _chunks: Array[Dictionary] = []


## Adds the collapse to parent at a global position. Safe during physics callbacks.
static func spawn(parent: Node, world_position: Vector2, titan_radius: float = 165.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var effect := TitanCollapse.new()
	effect.radius = titan_radius
	effect.z_index = 20
	parent.call_deferred("add_child", effect)
	effect.set_deferred("global_position", world_position)

	var scar := Scar.new()
	scar.radius = titan_radius
	scar.z_index = StoneDust.GROUND_Z - 1
	parent.call_deferred("add_child", scar)
	scar.set_deferred("global_position", world_position)

	StoneDust.spawn(parent, world_position, 36, titan_radius * 0.22, titan_radius * 1.2, 2.6)
	StoneDust.spawn(parent, world_position, 14, titan_radius * 0.24, titan_radius * 0.35, 2.8)


func _ready() -> void:
	_rng.randomize()
	for index in range(18):
		var angle: float = TAU * float(index) / 18.0 + _rng.randf_range(-0.2, 0.2)
		_shards.append({
			"pos": Vector2.RIGHT.rotated(angle) * radius * 0.15,
			"vel": Vector2.RIGHT.rotated(angle) * radius * _rng.randf_range(2.0, 3.4),
			"size": _rng.randf_range(5.0, 11.0),
			"rot": angle,
			"spin": _rng.randf_range(-9.0, 9.0),
			"life": _rng.randf_range(0.6, 1.0),
		})
	for index in range(14):
		var angle: float = _rng.randf_range(0.0, TAU)
		var size: float = _rng.randf_range(10.0, 26.0) * radius / 165.0
		var points := PackedVector2Array()
		var sides: int = _rng.randi_range(5, 7)
		for side in range(sides):
			var a: float = TAU * float(side) / float(sides) + _rng.randf_range(-0.2, 0.2)
			points.append(Vector2.RIGHT.rotated(a) * size * _rng.randf_range(0.8, 1.1))
		_chunks.append({
			"pos": Vector2.RIGHT.rotated(angle) * radius * _rng.randf_range(0.1, 0.5),
			"vel": Vector2.RIGHT.rotated(angle) * _rng.randf_range(90.0, 230.0) * radius / 165.0,
			"height": 0.0,
			"vz": _rng.randf_range(260.0, 460.0),
			"rot": _rng.randf_range(0.0, TAU),
			"spin": _rng.randf_range(-5.0, 5.0),
			"points": points,
			"bounced": false,
		})


func _process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		queue_free()
		return

	var drag: float = exp(-3.0 * delta)
	for shard in _shards:
		shard["pos"] += shard["vel"] * delta
		shard["vel"] *= drag
		shard["rot"] += shard["spin"] * delta

	for chunk in _chunks:
		var airborne: bool = chunk["height"] > 0.0 or chunk["vz"] > 0.0
		if airborne:
			chunk["vz"] -= GRAVITY * delta
			chunk["height"] = maxf(chunk["height"] + chunk["vz"] * delta, 0.0)
			chunk["pos"] += chunk["vel"] * delta
			chunk["rot"] += chunk["spin"] * delta
			if chunk["height"] <= 0.0 and chunk["vz"] < 0.0:
				if not chunk["bounced"]:
					# One small bounce, then it stays down.
					chunk["bounced"] = true
					chunk["vz"] = -chunk["vz"] * 0.3
					chunk["vel"] *= 0.45
					chunk["spin"] *= 0.4
				else:
					chunk["vz"] = 0.0
					chunk["vel"] = Vector2.ZERO
					chunk["spin"] = 0.0
	queue_redraw()


func _draw() -> void:
	# 1. Flash and shock ring.
	var flash_t: float = clampf(_age / 0.7, 0.0, 1.0)
	if flash_t < 1.0:
		if _age < 0.18:
			var core: float = 1.0 - _age / 0.18
			draw_circle(Vector2.ZERO, radius * 0.6 * core, Color(Palette.ENEMY_EYE_GLOW, 0.9 * core))
		var ring_radius: float = radius * (0.3 + 1.2 * (1.0 - pow(1.0 - flash_t, 3.0)))
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, Color(Palette.ENEMY_EYE, 1.0 - flash_t), 10.0 * (1.0 - flash_t) + 2.0)

	# 3. Boulders: shadow on the ground, rock lifted by its height.
	var chunk_alpha: float = 1.0 - clampf((_age - 2.6) / 1.0, 0.0, 1.0)
	for chunk in _chunks:
		var points: PackedVector2Array = chunk["points"]
		var lift: float = chunk["height"]
		var shadow_alpha: float = Palette.SHADOW_COLOR.a * chunk_alpha / (1.0 + lift * 0.01)
		draw_set_transform(chunk["pos"] + Palette.SHADOW_OFFSET + Vector2(lift * 0.15, lift * 0.2), chunk["rot"], Vector2.ONE)
		draw_colored_polygon(points, Color(0.0, 0.0, 0.0, shadow_alpha))
		var scale_up: float = 1.0 + lift / 400.0
		draw_set_transform(chunk["pos"] - Vector2(0.0, lift), chunk["rot"], Vector2.ONE * scale_up)
		draw_colored_polygon(points, Color(Palette.STONE_DARK, chunk_alpha))
		var inner := PackedVector2Array()
		for point in points:
			inner.append(point * 0.8 + Vector2(-0.8, -1.2))
		draw_colored_polygon(inner, Color(Palette.STONE_MID, chunk_alpha))
		var lit := PackedVector2Array([inner[0] * 0.4, inner[inner.size() - 1], inner[inner.size() - 2]])
		draw_colored_polygon(lit, Color(Palette.STONE_LIGHT, chunk_alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. Crystal shards on top.
	for shard in _shards:
		var t: float = _age / shard["life"]
		if t >= 1.0:
			continue
		var size: float = shard["size"]
		var diamond := PackedVector2Array([
			Vector2(size, 0.0), Vector2(0.0, size * 0.4), Vector2(-size * 0.6, 0.0), Vector2(0.0, -size * 0.4),
		])
		draw_set_transform(shard["pos"], shard["rot"], Vector2.ONE)
		draw_colored_polygon(diamond, Color(Palette.ENEMY_EYE_DEEP, 1.0 - t))
		draw_colored_polygon(PackedVector2Array([diamond[0], diamond[1], diamond[2]]), Color(Palette.ENEMY_EYE, 1.0 - t))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Crater, cracks and fading purple fissures left on the ground.
class Scar:
	extends Node2D

	const LIFE: float = 7.0
	const FADE: float = 1.8

	var radius: float = 165.0
	var _age: float = 0.0
	var _crater := PackedVector2Array()
	var _cracks: Array[PackedVector2Array] = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for index in range(11):
			var angle: float = TAU * float(index) / 11.0
			_crater.append(Vector2.RIGHT.rotated(angle) * radius * 0.42 * rng.randf_range(0.8, 1.15))
		for index in range(9):
			var angle: float = TAU * float(index) / 9.0 + rng.randf_range(-0.25, 0.25)
			var line := PackedVector2Array([Vector2.RIGHT.rotated(angle) * radius * 0.35])
			var reach: float = radius * 0.35
			for step in range(3):
				reach += radius * rng.randf_range(0.14, 0.24)
				angle += rng.randf_range(-0.3, 0.3)
				line.append(Vector2.RIGHT.rotated(angle) * reach)
			_cracks.append(line)

	func _process(delta: float) -> void:
		_age += delta
		if _age >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var alpha: float = clampf((LIFE - _age) / FADE, 0.0, 1.0)
		var grow: float = clampf(_age / 0.15, 0.0, 1.0)
		draw_colored_polygon(_scaled(_crater, grow), Color(0.0, 0.0, 0.0, 0.22 * alpha))
		draw_colored_polygon(_scaled(_crater, grow * 0.6), Color(0.0, 0.0, 0.0, 0.18 * alpha))
		var glow: float = clampf(1.0 - _age / 2.5, 0.0, 1.0)
		for crack in _cracks:
			var line := _scaled(crack, grow)
			draw_polyline(line, Color(0.0, 0.0, 0.0, 0.3 * alpha), 5.0)
			if glow > 0.0:
				draw_polyline(line, Color(Palette.ENEMY_EYE, 0.35 * glow), 6.0)
				draw_polyline(line, Color(Palette.ENEMY_EYE, 0.9 * glow), 2.0)

	func _scaled(points: PackedVector2Array, factor: float) -> PackedVector2Array:
		var result := PackedVector2Array()
		for point in points:
			result.append(point * factor)
		return result
