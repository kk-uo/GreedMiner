extends Node2D

## Rock enemy death: the stone cracks with a bright flash and bursts into
## angular shards that clatter out, bounce and lie on the ground, with a
## dust cloud and a sprinkle of pebbles; a small rubble heap stays behind.
## Two styles at random: BURST (shards fly out) and CRUMBLE (it caves in on
## itself: short hops, more dust, a bigger heap). `red` uses the Red Rock's
## magma-veined tones. One batched draw per frame. Presentation only.
## Load with preload(); no class_name on purpose.

const LIFE: float = 3.2
const GRAVITY: float = 640.0
const GREY: Array[Color] = [Color("2F3135"), Color("44474C"), Color("686C72"), Color("8E9298")]
const REDS: Array[Color] = [Color("4A140C"), Color("7A2416"), Color("B23C24"), Color("D9623A")]
const DUST := Color("B8A68E")
const CRACK := Color("FFF4D6")
const MAGMA := Color("FFB23A")

static var _BATCH := MeshBatch2D.new()

var size: float = 1.0
var red: bool = false
## -1 random, 0 BURST, 1 CRUMBLE.
var forced_style: int = -1
var _style: int = 0
var _age: float = 0.0
var _tones: Array[Color] = GREY
var _shards: Array = []
var _pebbles: Array = []
var _heap: Array = []
var _cracks: Array = []
var _rng := RandomNumberGenerator.new()


static func spawn(parent: Node, at: Vector2, scale_factor: float = 1.0, is_red: bool = false) -> Node2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var node: Node2D = load("res://Scripts/VFX/StoneShatter.gd").new()
	node.set("size", scale_factor)
	node.set("red", is_red)
	parent.add_child(node)
	node.global_position = at
	return node


func _ready() -> void:
	z_index = 1
	_rng.randomize()
	_style = forced_style if forced_style >= 0 else _rng.randi_range(0, 1)
	_tones = REDS if red else GREY
	var reach := sqrt(size)
	var crumble := _style == 1
	for k in range(int(7.0 + 4.0 * size)):
		var dir := Vector2.RIGHT.rotated(_rng.randf() * TAU)
		var r := _rng.randf_range(3.0, 5.5) * size
		var points := PackedVector2Array()
		var sides := _rng.randi_range(3, 5)
		for p in range(sides):
			points.append(Vector2.RIGHT.rotated(TAU * float(p) / float(sides) + _rng.randf_range(-0.35, 0.35)) * r * _rng.randf_range(0.6, 1.2))
		var speed := _rng.randf_range(15.0, 45.0) if crumble else _rng.randf_range(45.0, 120.0)
		_shards.append({"pos": dir * 2.0, "vel": dir * speed * reach, "z": 3.0,
				"vz": _rng.randf_range(60.0, 130.0) if crumble else _rng.randf_range(110.0, 220.0),
				"rot": _rng.randf() * TAU, "spin": _rng.randf_range(-10.0, 10.0), "points": points, "r": r,
				"tone": _rng.randi_range(1, 3), "bounces": 0, "landed": false})
	for k in range(int(10.0 * size)):
		var dir := Vector2.RIGHT.rotated(_rng.randf() * TAU)
		_pebbles.append({"pos": Vector2.ZERO, "vel": dir * _rng.randf_range(40.0, 110.0) * reach, "z": 2.0,
				"vz": _rng.randf_range(60.0, 180.0), "r": _rng.randf_range(0.9, 1.7) * size, "landed": false})
	for k in range(4 if crumble else 3):
		var dir := Vector2.RIGHT.rotated(_rng.randf() * TAU)
		var r := _rng.randf_range(3.5, 6.0) * size * (1.2 if crumble else 1.0)
		var points := PackedVector2Array()
		for p in range(5):
			points.append(Vector2.RIGHT.rotated(TAU * float(p) / 5.0 + _rng.randf_range(-0.3, 0.3)) * r * _rng.randf_range(0.7, 1.1))
		_heap.append({"pos": dir * _rng.randf() * 4.0 * size, "points": points, "tone": _rng.randi_range(1, 2)})
	for k in range(5):
		var a := TAU * float(k) / 5.0 + _rng.randf_range(-0.3, 0.3)
		var dir := Vector2.RIGHT.rotated(a)
		var side := Vector2(-dir.y, dir.x)
		_cracks.append(PackedVector2Array([Vector2.ZERO, dir * 5.0 * size + side * 1.5 * size, dir * 10.0 * size - side * size]))


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	for shard in _shards:
		if shard["landed"]:
			continue
		shard["pos"] += shard["vel"] * delta
		shard["z"] += shard["vz"] * delta
		shard["vz"] -= GRAVITY * delta
		shard["rot"] += shard["spin"] * delta
		if shard["z"] <= 0.0:
			shard["z"] = 0.0
			if shard["bounces"] < 1 and shard["vz"] < -100.0:
				shard["vz"] = -shard["vz"] * 0.35
				shard["vel"] *= 0.5
				shard["spin"] *= 0.4
				shard["bounces"] += 1
			else:
				shard["landed"] = true
	for pebble in _pebbles:
		if pebble["landed"]:
			continue
		pebble["pos"] += pebble["vel"] * delta
		pebble["z"] += pebble["vz"] * delta
		pebble["vz"] -= GRAVITY * delta
		if pebble["z"] <= 0.0:
			pebble["landed"] = true
	queue_redraw()


func _draw() -> void:
	var c := _BATCH
	var fade := 1.0 - smoothstep(LIFE - 1.0, LIFE, _age)
	var r0 := 10.0 * size
	var crumble := _style == 1
	# Dust stain and the rubble heap left behind.
	var settle := smoothstep(0.05, 0.4, _age)
	c.draw_circle(Vector2.ZERO, r0 * (1.3 if crumble else 1.0) * settle, Color(DUST, 0.28 * fade))
	for piece in _heap:
		var xf := Transform2D(0.0, Vector2.ONE * settle, 0.0, piece["pos"])
		c.draw_colored_polygon(xf * Palette.offset_points(piece["points"], Vector2(1.5, 2.0)), Color(0, 0, 0, 0.25 * fade))
		c.draw_colored_polygon(xf * piece["points"], Color(_tones[0], fade))
		c.draw_colored_polygon(xf * (Transform2D(0.0, Vector2.ONE * 0.75, 0.0, Vector2(-0.8, -0.8)) * piece["points"]), Color(_tones[int(piece["tone"])], fade))
	# Crack flash.
	if _age < 0.12:
		var t := _age / 0.12
		c.draw_circle(Vector2.ZERO, r0 * lerpf(0.9, 1.5, t), Color(CRACK, 0.85 * (1.0 - t)))
		for crack in _cracks:
			c.draw_polyline(crack, Color(MAGMA if red else CRACK, 1.0 - t), 1.6)
	# Dust cloud billowing out.
	if _age < 0.9:
		var t := _age / (1.4 if crumble else 0.9)
		var out := 1.0 - pow(1.0 - t, 3.0)
		for p in range(8):
			var a := TAU * float(p) / 8.0 + 0.3
			c.draw_circle(Vector2(cos(a), sin(a)) * r0 * (1.0 if crumble else 1.4) * out, r0 * lerpf(0.5, 1.1, t), Color(DUST, (0.5 if crumble else 0.4) * (1.0 - t)))
		c.draw_arc(Vector2.ZERO, r0 * lerpf(0.8, 2.3, out), 0.0, TAU, 28, Color(DUST, 0.6 * (1.0 - t)), 2.5 * (1.0 - t) + 0.5)
	for pebble in _pebbles:
		var p: Vector2 = pebble["pos"] + Vector2(0.0, -float(pebble["z"]))
		c.draw_circle(p, float(pebble["r"]), Color(_tones[2], fade))
	for shard in _shards:
		var z: float = shard["z"]
		var ground: Vector2 = shard["pos"]
		if z > 0.5:
			c.draw_circle(ground + Vector2(2.0, 3.0), float(shard["r"]) * 0.7, Color(0, 0, 0, 0.25 * fade))
		var xf := Transform2D(float(shard["rot"]), Vector2.ONE * (1.0 + z / 220.0), 0.0, ground + Vector2(0.0, -z))
		var points: PackedVector2Array = shard["points"]
		c.draw_colored_polygon(xf * points, Color(_tones[0], fade))
		c.draw_colored_polygon(xf * (Transform2D(0.0, Vector2.ONE * 0.72, 0.0, Vector2(-0.6, -0.6)) * points), Color(_tones[int(shard["tone"])], fade))
		if red:
			c.draw_line(xf * points[0], xf * Vector2.ZERO, Color(MAGMA, 0.8 * fade * (1.0 - smoothstep(0.5, 2.0, _age))), 0.9)
	c.flush_to(self)
