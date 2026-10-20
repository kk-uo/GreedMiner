extends Node2D

## Goblin death: the goblin bursts. A hot flash and a red mist puff, then
## chunks fly out in arcs (green skin, red meat, bits of bone, an ear and an
## eyeball), bounce and lie on the ground; blood droplets rain down, leaving
## splats around a spreading puddle. Everything fades after a few seconds.
## One batched draw per frame. Presentation only.
## Load with preload(); no class_name on purpose.

const LIFE: float = 3.4
const GRAVITY: float = 620.0
const SKIN: Array[Color] = [Color("4E6B22"), Color("7FA83A"), Color("A9CF5C")]
const MEAT: Array[Color] = [Color("5E0F14"), Color("A3202A"), Color("E0505A")]
const BONE := Color("E9DFC6")
const BLOOD := Color("7A1218")
const BLOOD_LIGHT := Color("B3202A")
const FLASH := Color("FFF1C2")

static var _BATCH := MeshBatch2D.new()

## Colour theme: &"goblin" (green skin, red blood) or &"yeti" (white fur,
## blue skin, green blood, ice bits). Set before adding (spawn() does).
var theme: StringName = &"goblin"
var _skin: Array[Color] = SKIN
var _meat: Array[Color] = MEAT
var _blood: Color = BLOOD
var _blood_light: Color = BLOOD_LIGHT
const YETI_FUR: Array[Color] = [Color("7F9DB3"), Color("BCD3E2"), Color("E8F3FA")]
const YETI_SKIN: Array[Color] = [Color("2F4E6B"), Color("4A7393"), Color("6E98B8")]
const YETI_BLOOD := Color("2E6B1F")
const YETI_BLOOD_LIGHT := Color("6FBF3A")

var size: float = 1.0
var _age: float = 0.0
var _chunks: Array = []
var _drops: Array = []
var _splats: Array = []
var _puddle: PackedVector2Array
var _rng := RandomNumberGenerator.new()


## Spawns a gore burst at a global position; `scale_factor` ~1 for a goblin.
static func spawn(parent: Node, at: Vector2, scale_factor: float = 1.0, gore_theme: StringName = &"goblin") -> Node2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var gore: Node2D = load("res://Scripts/VFX/GoblinGore.gd").new()
	gore.set("size", scale_factor)
	gore.set("theme", gore_theme)
	parent.add_child(gore)
	gore.global_position = at
	return gore


## Death styles, picked at random so a crowd of deaths never looks the same.
enum Style { SPLAT, POP, SHRED, COLLAPSE }
var _style: int = Style.SPLAT
## Set before adding to force a style (tests); -1 = random.
var forced_style: int = -1
## SHRED: direction the bits spray (and the smear runs).
var _dir := Vector2.RIGHT
## COLLAPSE: goo bubbles popping in the puddle.
var _bubbles: Array = []


func _ready() -> void:
	z_index = 1
	_rng.randomize()
	if theme == &"yeti":
		_skin = YETI_FUR
		_meat = YETI_SKIN
		_blood = YETI_BLOOD
		_blood_light = YETI_BLOOD_LIGHT
	_style = forced_style if forced_style >= 0 else _rng.randi_range(0, 3)
	_dir = Vector2.RIGHT.rotated(_rng.randf() * TAU)
	var reach := sqrt(size)
	match _style:
		Style.SPLAT:
			# Classic burst: meat and skin all round, extras only sometimes.
			var kinds := []
			for k in range(int(7.0 + 4.0 * size)):
				kinds.append("skin" if _rng.randf() < 0.45 else "meat")
			_maybe(kinds, "eye", 0.35)
			_maybe(kinds, "ear", 0.4)
			_maybe(kinds, "bone", 0.4)
			for kind in kinds:
				_add_chunk(kind, _rng.randf() * TAU, _rng.randf_range(35.0, 100.0) * reach, _rng.randf_range(110.0, 220.0))
			_add_drops(12, 0.0, PI, 40.0, 130.0, 50.0, 170.0)
		Style.POP:
			# The head pops off and flies up; blood fountains and rains back
			# down close by; a few teeth.
			_add_chunk("head", _rng.randf() * TAU, _rng.randf_range(15.0, 40.0) * reach, 330.0)
			for k in range(int(4.0 + 2.0 * size)):
				_add_chunk("meat", _rng.randf() * TAU, _rng.randf_range(20.0, 60.0) * reach, _rng.randf_range(120.0, 200.0))
			for k in range(_rng.randi_range(2, 4)):
				_add_chunk("tooth", _rng.randf() * TAU, _rng.randf_range(25.0, 70.0) * reach, _rng.randf_range(150.0, 240.0))
			_add_drops(18, 0.0, PI, 10.0, 60.0, 200.0, 330.0)
		Style.SHRED:
			# Torn apart one way: skin strips and a spray of blood in a cone,
			# leaving a long smear.
			var kinds := []
			for k in range(int(6.0 + 3.0 * size)):
				kinds.append("strip" if _rng.randf() < 0.55 else "meat")
			_maybe(kinds, "cloth", 0.7)
			_maybe(kinds, "ear", 0.3)
			var base := _dir.angle()
			for kind in kinds:
				_add_chunk(kind, base + _rng.randf_range(-0.6, 0.6), _rng.randf_range(50.0, 125.0) * reach, _rng.randf_range(60.0, 140.0))
			_add_drops(16, base, 0.5, 60.0, 160.0, 30.0, 110.0)
		_:
			# Collapses into a heap: bits barely leave the spot, a big puddle
			# with goo bubbles popping and a puff of stink.
			var kinds := []
			for k in range(int(6.0 + 3.0 * size)):
				kinds.append("skin" if _rng.randf() < 0.5 else "meat")
			_maybe(kinds, "bone", 0.5)
			_maybe(kinds, "eye", 0.25)
			for kind in kinds:
				_add_chunk(kind, _rng.randf() * TAU, _rng.randf_range(10.0, 40.0) * reach, _rng.randf_range(60.0, 120.0))
			_add_drops(8, 0.0, PI, 20.0, 70.0, 40.0, 110.0)
			for k in range(7):
				_bubbles.append({"pos": Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf() * 10.0 * size, "phase": _rng.randf(), "r": _rng.randf_range(1.2, 2.6) * size})
	if theme == &"yeti":
		# Bits of the ice crystals off its shoulders.
		for k in range(_rng.randi_range(5, 8)):
			_add_chunk("ice", _rng.randf() * TAU, _rng.randf_range(40.0, 110.0) * reach, _rng.randf_range(130.0, 240.0))
	for p in range(10):
		var a := TAU * float(p) / 10.0
		_puddle.append(Vector2(cos(a), sin(a)) * _rng.randf_range(0.7, 1.15))


func _maybe(kinds: Array, kind: String, chance: float) -> void:
	if _rng.randf() < chance:
		kinds.append(kind)


func _add_chunk(kind: String, angle: float, speed: float, up: float) -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	var points := PackedVector2Array()
	var r := _rng.randf_range(2.6, 4.6) * size
	if kind == "head":
		r = 6.0 * size
	for p in range(5):
		points.append(Vector2.RIGHT.rotated(TAU * float(p) / 5.0 + _rng.randf_range(-0.3, 0.3)) * r * _rng.randf_range(0.7, 1.15))
	_chunks.append({
		"kind": kind, "pos": dir * 2.0, "vel": dir * speed, "z": 4.0, "vz": up,
		"rot": _rng.randf() * TAU if kind != "strip" else angle, "spin": _rng.randf_range(-12.0, 12.0) * (0.3 if kind == "strip" else 1.0),
		"r": r, "points": points, "bounced": false, "landed": false,
	})


## count drops around `angle` (+/- spread), horizontal and upward speed ranges.
func _add_drops(count: int, angle: float, spread: float, speed_min: float, speed_max: float, up_min: float, up_max: float) -> void:
	for k in range(int(float(count) * size)):
		var dir := Vector2.RIGHT.rotated(angle + _rng.randf_range(-spread, spread))
		_drops.append({"pos": Vector2.ZERO, "vel": dir * _rng.randf_range(speed_min, speed_max) * sqrt(size), "z": 3.0,
				"vz": _rng.randf_range(up_min, up_max), "r": _rng.randf_range(1.0, 2.0) * size, "landed": false})


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	for chunk in _chunks:
		if chunk["landed"]:
			continue
		chunk["pos"] += chunk["vel"] * delta
		chunk["z"] += chunk["vz"] * delta
		chunk["vz"] -= GRAVITY * delta
		chunk["rot"] += chunk["spin"] * delta
		if chunk["z"] <= 0.0:
			chunk["z"] = 0.0
			if not chunk["bounced"] and chunk["vz"] < -120.0:
				chunk["vz"] = -chunk["vz"] * 0.3
				chunk["vel"] *= 0.45
				chunk["spin"] *= 0.5
				chunk["bounced"] = true
			else:
				chunk["landed"] = true
			if chunk["kind"] == "meat" or chunk["kind"] == "skin":
				_add_splat(chunk["pos"], chunk["r"] * 1.1)
	for drop in _drops:
		if drop["landed"]:
			continue
		drop["pos"] += drop["vel"] * delta
		drop["z"] += drop["vz"] * delta
		drop["vz"] -= GRAVITY * delta
		if drop["z"] <= 0.0:
			drop["landed"] = true
			_add_splat(drop["pos"], drop["r"] * 1.6)
	queue_redraw()


func _add_splat(at: Vector2, radius: float) -> void:
	if _splats.size() < 40:
		_splats.append({"pos": at, "r": radius, "turn": _rng.randf() * TAU})


func _draw() -> void:
	var c := _BATCH
	var fade := 1.0 - smoothstep(LIFE - 1.0, LIFE, _age)
	var r0 := 10.0 * size
	# Spreading puddle and splats on the ground.
	var grow := smoothstep(0.03, 0.35, _age)
	if grow > 0.0:
		var puddle_size := {Style.SPLAT: 1.15, Style.POP: 1.3, Style.SHRED: 0.9, Style.COLLAPSE: 1.6}[_style] as float
		if _style == Style.SHRED:
			# Long smear in the spray direction.
			var smear := Transform2D(_dir.angle(), Vector2(r0 * 2.6, r0 * 0.55) * grow, 0.0, _dir * r0 * 1.6 * grow)
			c.draw_colored_polygon(smear * _puddle, Color(_blood, 0.6 * fade))
		var xf := Transform2D(0.0, Vector2.ONE * r0 * puddle_size * grow, 0.0, Vector2.ZERO)
		c.draw_colored_polygon(xf * _puddle, Color(_blood, 0.7 * fade))
		c.draw_colored_polygon(Transform2D(0.0, Vector2.ONE * r0 * 0.6 * grow, 0.0, Vector2(-r0 * 0.2, -r0 * 0.2)) * _puddle, Color(_blood_light, 0.45 * fade))
	for splat in _splats:
		var xf := Transform2D(float(splat["turn"]), Vector2(1.3, 0.85) * float(splat["r"]), 0.0, splat["pos"])
		c.draw_colored_polygon(xf * _puddle, Color(_blood, 0.75 * fade))
	# Goo bubbles swelling and popping in the heap's puddle.
	for bubble in _bubbles:
		var ph := fposmod(_age * 1.3 + float(bubble["phase"]), 1.0)
		var br: float = float(bubble["r"]) * ph
		if ph < 0.85:
			c.draw_circle(bubble["pos"], br, Color(_blood_light, 0.85 * fade))
			c.draw_circle(bubble["pos"] + Vector2(-br * 0.3, -br * 0.3), br * 0.3, Color(1, 1, 1, 0.5 * fade))
		else:
			c.draw_arc(bubble["pos"], float(bubble["r"]) * 1.2, 0.0, TAU, 10, Color(_blood_light, 0.7 * fade), 0.8)
	# Flash and red mist in the first moments.
	if _age < 0.14:
		var t := _age / 0.14
		c.draw_circle(Vector2.ZERO, r0 * lerpf(1.0, 2.0, t), Color(FLASH, 0.9 * (1.0 - t)))
	if _age < 0.45:
		var t := _age / 0.45
		var out := 1.0 - pow(1.0 - t, 3.0)
		var mist := _blood_light if _style != Style.COLLAPSE else Color("8FA35A")
		for p in range(7):
			var a := TAU * float(p) / 7.0 + 0.4
			c.draw_circle(Vector2(cos(a), sin(a)) * r0 * 1.2 * out, r0 * lerpf(0.5, 1.0, t), Color(mist, 0.45 * (1.0 - t)))
		c.draw_arc(Vector2.ZERO, r0 * lerpf(0.8, 2.4, out), 0.0, TAU, 28, Color(_meat[2], 0.7 * (1.0 - t)), 3.0 * (1.0 - t) + 0.5)
	# Droplets in flight.
	for drop in _drops:
		if drop["landed"]:
			continue
		var p: Vector2 = drop["pos"] + Vector2(0.0, -float(drop["z"]))
		c.draw_circle(p, float(drop["r"]), Color(_blood_light, fade))
	# Chunks: shadow on the ground, then the piece raised by its height.
	for chunk in _chunks:
		var z: float = chunk["z"]
		var ground: Vector2 = chunk["pos"]
		var r: float = chunk["r"]
		if z > 0.5:
			c.draw_circle(ground + Vector2(2.0, 3.0), r * 0.8, Color(0, 0, 0, 0.25 * fade))
		var at := ground + Vector2(0.0, -z)
		var lift := 1.0 + z / 220.0
		var xf := Transform2D(float(chunk["rot"]), Vector2.ONE * lift, 0.0, at)
		match String(chunk["kind"]):
			"skin":
				c.draw_colored_polygon(xf * chunk["points"], Color(_skin[0], fade))
				c.draw_colored_polygon(xf * (Transform2D(0.0, Vector2.ONE * 0.7, 0.0, Vector2(-0.6, -0.6)) * chunk["points"]), Color(_skin[1], fade))
				c.draw_circle(xf * Vector2(r * 0.4, r * 0.3), r * 0.35, Color(_meat[1], fade))
			"meat":
				c.draw_colored_polygon(xf * chunk["points"], Color(_meat[0], fade))
				c.draw_colored_polygon(xf * (Transform2D(0.0, Vector2.ONE * 0.68, 0.0, Vector2(-0.5, -0.5)) * chunk["points"]), Color(_meat[1], fade))
				c.draw_circle(xf * Vector2(-r * 0.3, -r * 0.3), r * 0.22, Color(_meat[2], fade))
			"bone":
				c.draw_line(xf * Vector2(-r, 0.0), xf * Vector2(r, 0.0), Color(BONE, fade), r * 0.55)
				for end in [-1.0, 1.0]:
					c.draw_circle(xf * Vector2(r * end, 0.0), r * 0.45, Color(BONE, fade))
			"ear":
				var ear := PackedVector2Array([Vector2(-r, -r * 0.6), Vector2(r * 1.6, 0.0), Vector2(-r, r * 0.6)])
				c.draw_colored_polygon(xf * ear, Color(_skin[1], fade))
				c.draw_colored_polygon(xf * PackedVector2Array([Vector2(-r * 0.5, -r * 0.25), Vector2(r * 0.9, 0.0), Vector2(-r * 0.5, r * 0.25)]), Color(Color("D98C8C"), fade))
			"head" when theme == &"yeti":
				# Popped yeti head: shaggy fur, blue face, curled horns, X eyes.
				for side in [-1.0, 1.0]:
					var horn := PackedVector2Array([xf * Vector2(-r * 0.2, side * r * 0.7), xf * Vector2(-r * 0.9, side * r * 1.5), xf * Vector2(-r * 1.6, side * r * 1.2), xf * Vector2(-r * 1.4, side * r * 0.8)])
					c.draw_polyline(horn, Color(Color("B9AE98"), fade), r * 0.35)
				var fur := PackedVector2Array()
				for k in range(16):
					var a := TAU * float(k) / 16.0
					fur.append(Vector2(cos(a), sin(a)) * r * (1.0 if k % 2 == 0 else 0.82))
				c.draw_colored_polygon(xf * fur, Color(_skin[1], fade))
				c.draw_circle(xf * Vector2(-r * 0.3, -r * 0.3), r * 0.5, Color(_skin[2], fade))
				c.draw_circle(xf * Vector2(r * 0.35, 0.0), r * 0.62, Color(_meat[1], fade))
				for side in [-1.0, 1.0]:
					var eye := xf * Vector2(r * 0.5, side * r * 0.28)
					c.draw_line(eye + Vector2(-1.3, -1.3) * lift, eye + Vector2(1.3, 1.3) * lift, Color(Color("7FF3FF"), fade), 1.0)
					c.draw_line(eye + Vector2(-1.3, 1.3) * lift, eye + Vector2(1.3, -1.3) * lift, Color(Color("7FF3FF"), fade), 1.0)
				c.draw_circle(xf * Vector2(r * 0.85, 0.0), r * 0.18, Color(Color("1A2633"), fade))
			"head":
				# The popped head: ears, crossed-out eyes and a lolling tongue.
				for side in [-1.0, 1.0]:
					c.draw_colored_polygon(xf * PackedVector2Array([Vector2(-r * 0.2, side * r * 0.6), Vector2(-r * 0.4, side * r * 2.0), Vector2(r * 0.4, side * r * 0.8)]), Color(_skin[1], fade))
				c.draw_circle(at, r * lift, Color(_skin[0], fade))
				c.draw_circle(at + Vector2(-0.8, -0.8), r * 0.82 * lift, Color(_skin[1], fade))
				for side in [-1.0, 1.0]:
					var eye := xf * Vector2(r * 0.35, side * r * 0.38)
					c.draw_line(eye + Vector2(-1.4, -1.4) * lift, eye + Vector2(1.4, 1.4) * lift, Color(Color("1A1410"), fade), 1.0)
					c.draw_line(eye + Vector2(-1.4, 1.4) * lift, eye + Vector2(1.4, -1.4) * lift, Color(Color("1A1410"), fade), 1.0)
				c.draw_circle(xf * Vector2(r * 0.85, r * 0.1), r * 0.28, Color(Color("D96A7A"), fade))
				c.draw_circle(xf * Vector2(-r * 0.2, 0.0), r * 0.3, Color(_meat[1], fade))
			"ice":
				# A long ice spike snapped off its shoulders.
				var spike := PackedVector2Array([Vector2(-r * 0.9, -r * 0.45), Vector2(r * 2.2, 0.0), Vector2(-r * 0.9, r * 0.45), Vector2(-r * 1.2, 0.0)])
				c.draw_colored_polygon(xf * spike, Color(Color("2B8FB0"), fade))
				c.draw_colored_polygon(xf * PackedVector2Array([Vector2(-r * 0.8, -r * 0.35), Vector2(r * 2.0, 0.0), Vector2(-r * 0.8, 0.0)]), Color(Color("9FE7FF"), fade))
				c.draw_line(xf * Vector2(-r * 0.5, -r * 0.1), xf * Vector2(r * 1.4, -r * 0.05), Color(1, 1, 1, 0.8 * fade), 0.8)
			"tooth":
				c.draw_colored_polygon(xf * PackedVector2Array([Vector2(-r * 0.4, -r * 0.35), Vector2(r * 0.4, -r * 0.35), Vector2(0.0, r * 0.6)]), Color(BONE, fade))
			"strip":
				var strip := PackedVector2Array([Vector2(-r * 1.8, -r * 0.35), Vector2(r * 1.6, -r * 0.5), Vector2(r * 1.9, r * 0.2), Vector2(-r * 1.5, r * 0.45)])
				c.draw_colored_polygon(xf * strip, Color(_skin[0], fade))
				c.draw_colored_polygon(xf * PackedVector2Array([Vector2(-r * 1.5, -r * 0.15), Vector2(r * 1.4, -r * 0.3), Vector2(r * 1.5, 0.0), Vector2(-r * 1.3, r * 0.15)]), Color(_skin[1], fade))
				c.draw_line(xf * Vector2(-r * 1.6, r * 0.35), xf * Vector2(r * 1.7, r * 0.1), Color(_meat[1], fade), 0.9)
			"cloth":
				var rag := PackedVector2Array([Vector2(-r, -r * 0.8), Vector2(r * 1.2, -r * 0.6), Vector2(r * 0.8, r * 0.2), Vector2(r * 1.1, r * 0.9), Vector2(-r * 0.9, r * 0.7)])
				c.draw_colored_polygon(xf * rag, Color(Color("6B4A32"), fade))
				c.draw_colored_polygon(xf * PackedVector2Array([Vector2(-r * 0.7, -r * 0.5), Vector2(r * 0.8, -r * 0.4), Vector2(-r * 0.6, r * 0.3)]), Color(Color("8A6446"), fade))
			"eye":
				c.draw_circle(at, r * 0.95 * lift, Color(Color("F4EEDC"), fade))
				c.draw_circle(xf * Vector2(r * 0.35, 0.0), r * 0.45 * lift, Color(Color("7FF3FF") if theme == &"yeti" else Color("FF4A3A"), fade))
				c.draw_circle(xf * Vector2(r * 0.45, 0.0), r * 0.2 * lift, Color(Color("1A1410"), fade))
	c.flush_to(self)
