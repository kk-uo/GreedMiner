extends Node2D

## Graveyard undead death effects (style C "signature", one move per enemy):
## - zombie:   sinks into its grave - the earth opens, clods fly, a hand
##             reaches up and is pulled under (the zombie grave rises after)
## - skeleton: blows apart - a flash, bones and skull fly out spinning,
##             bounce once and clatter to rest
## - vampire:  bursts into a swarm of bats that scatter and fly off
## - werewolf: the body swells and twitches, then bursts - a spray of blood,
##             fur-and-meat chunks fly and bounce, splats and a pool stay
## The enemy's own art (UndeadVisual) stays for the first moments and is
## faded / sunk per kind. One batched draw per frame. Presentation only.
## Load with preload(); no class_name on purpose.

const LIFE: float = 2.6
const FADE: float = 0.8

const Z_SKIN: Array[Color] = [Color("3E4656"), Color("5D6779"), Color("8790A3")]
const BONE: Array[Color] = [Color("B9B5AC"), Color("F2F0EA"), Color("FFFFFF")]
const BONE_HOLE := Color("1A1620")
const SOUL_CORE := Color("EEE6FF")
const V_CAPE: Array[Color] = [Color("1A1024"), Color("2E1D40"), Color("4A3266")]
const V_RED := Color("FF4A7A")
const BLOOD_LIT := Color("8E1C36")
const W_FUR: Array[Color] = [Color("464A56"), Color("7A8090"), Color("B8BECB")]
const W_EYE := Color("7FD8FF")
const BLOOD_DARK := Color("4E0B16")
const BLOOD := Color("8E1626")
const BLOOD_RED := Color("C42A33")
const MEAT := Color("B8545A")
## Werewolf: when the swollen body bursts.
const BURST_AT: float = 0.22
const DIRT := Color("3A3128")
const DIRT_LIGHT := Color("5A4A38")
const HOLE := Color("15110E")

static var _BATCH := MeshBatch2D.new()


## The enemy's own art, kept for the first moments and faded / sunk / shrunk
## per kind (see _update_body).
class BodyArt extends Node2D:
	var kind: StringName = &"zombie"
	var face: float = 0.0

	func _draw() -> void:
		match kind:
			&"skeleton": UndeadVisual.draw_skeleton(self, face, 0.0, 0.0, false, 0.0)
			&"vampire": UndeadVisual.draw_vampire(self, face, 0.0, 0.0, false, 0.0)
			&"werewolf": UndeadVisual.draw_werewolf(self, face, 0.0, 0.0, false, 0.0)
			_: UndeadVisual.draw_zombie(self, face, 0.0, 0.0, false, 0.0)

var kind: StringName = &"zombie"
var size: float = 1.0
var facing: float = 0.0
## Screenshots / tests can freeze the effect at a given age.
var frozen_age: float = -1.0

var _age: float = 0.0
var _rng := RandomNumberGenerator.new()
var _bits: Array = []
var _body: BodyArt


static func spawn(parent: Node, at: Vector2, enemy_kind: StringName, scale_factor: float = 1.0, facing_angle: float = 0.0) -> Node2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var node: Node2D = load("res://Scripts/VFX/UndeadDeath.gd").new()
	node.set("kind", enemy_kind)
	node.set("size", scale_factor)
	node.set("facing", facing_angle)
	parent.add_child(node)
	node.global_position = at
	return node


func _ready() -> void:
	z_index = 1
	_rng.seed = hash(str(kind)) if frozen_age >= 0.0 else randi()
	var count := 10
	for index in range(count):
		var a := TAU * float(index) / float(count) + _rng.randf_range(-0.3, 0.3)
		_bits.append({
			"dir": Vector2.RIGHT.rotated(a), "dist": _rng.randf_range(0.7, 1.5), "spin": _rng.randf_range(-6.0, 6.0),
			"rot": _rng.randf() * TAU, "delay": _rng.randf_range(0.0, 0.25), "r": _rng.randf_range(0.7, 1.3),
			"phase": _rng.randf() * TAU, "kind": index % 5,
		})
	_body = BodyArt.new()
	_body.kind = kind
	_body.face = facing
	_body.z_index = 1
	add_child(_body)
	if frozen_age >= 0.0:
		_age = frozen_age
		set_process(false)
	_update_body()


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	_update_body()
	queue_redraw()


## How the enemy's own art leaves the scene.
func _update_body() -> void:
	var gone := 1.0
	var tint := Color.WHITE
	var shift := Vector2.ZERO
	var grow := 1.0
	match kind:
		&"zombie":
			gone = smoothstep(0.05, 0.7, _age)
			tint = Color.WHITE.lerp(Color(0.25, 0.22, 0.2), gone)
			grow = 1.0 - 0.55 * gone
			shift = Vector2(0, 6.0 * gone)
		&"skeleton":
			gone = smoothstep(0.0, 0.08, _age)
		&"vampire":
			gone = smoothstep(0.0, 0.3, _age)
			grow = 1.0 + 0.3 * gone
		&"werewolf":
			# Swells, flushes red and twitches, then pops.
			var swell := smoothstep(0.0, BURST_AT, _age)
			gone = 1.0 if _age >= BURST_AT else 0.0
			grow = 1.0 + 0.3 * swell
			tint = Color.WHITE.lerp(Color(1.5, 0.55, 0.55), swell)
			shift = Vector2(sin(_age * 95.0), cos(_age * 77.0)) * 1.6 * swell
		_:
			gone = smoothstep(0.25, 1.0, _age)
			tint = Color.WHITE.lerp(Color(0.75, 0.95, 1.2), gone)
	_body.visible = gone < 1.0
	_body.modulate = Color(tint, 1.0 - gone)
	_body.scale = Vector2.ONE * grow
	_body.position = shift


func _draw() -> void:
	var c := _BATCH
	var r0 := 12.0 * size
	var fade := 1.0 - smoothstep(LIFE - FADE, LIFE, _age)
	match kind:
		&"skeleton": _bone_burst(c, r0, fade)
		&"vampire": _bat_swarm(c, r0, fade)
		&"werewolf": _blood_burst(c, r0, fade)
		_: _sink(c, r0, fade)
	c.flush_to(self)


# ------------------------------------------------------------------ helpers

func _out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)


## Where a flung bit is at this age: arcs out, lands, slides a little.
func _fling(bit: Dictionary, reach: float, time: float = 0.45) -> Vector2:
	var t := clampf((_age - float(bit["delay"])) / time, 0.0, 1.0)
	var flat: Vector2 = bit["dir"] * reach * float(bit["dist"]) * _out(t)
	return flat + Vector2(0, -sin(PI * t) * reach * 0.35)


func _blob(center: Vector2, radii: Vector2, seed: float, sides: int = 11) -> PackedVector2Array:
	var p := PackedVector2Array()
	for k in range(sides):
		var a := TAU * float(k) / float(sides)
		var wobble := 1.0 + 0.08 * sin(a * 2.0 + seed) + 0.05 * sin(a * 5.0 + seed * 2.0)
		p.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y) * wobble)
	return p


func _bone(c: Object, a: Vector2, b: Vector2, w: float, alpha: float) -> void:
	c.draw_line(a + Vector2(1.2, 1.4), b + Vector2(1.2, 1.4), Color(0, 0, 0, 0.25 * alpha), w)
	c.draw_line(a, b, Color(BONE[0], alpha), w + 1.0)
	c.draw_line(a, b, Color(BONE[1], alpha), w)
	for end in [a, b]:
		var n := (b - a).normalized().orthogonal() * w * 0.45
		c.draw_circle(end + n, w * 0.55, Color(BONE[1], alpha))
		c.draw_circle(end - n, w * 0.55, Color(BONE[1], alpha))


func _skull(c: Object, at: Vector2, r: float, rot: float, alpha: float) -> void:
	var fwd := Vector2.RIGHT.rotated(rot)
	var side := fwd.orthogonal()
	c.draw_circle(at + Vector2(1.2, 1.5), r, Color(0, 0, 0, 0.25 * alpha))
	c.draw_circle(at, r + 0.6, Color(BONE[0], alpha))
	c.draw_circle(at, r, Color(BONE[1], alpha))
	c.draw_circle(at - Vector2(0.3, 0.3) * r, r * 0.5, Color(BONE[2], alpha))
	c.draw_rect(Rect2(at + fwd * r * 0.55 - Vector2.ONE * r * 0.35, Vector2.ONE * r * 0.7), Color(BONE[1], alpha))
	for s in [-1.0, 1.0]:
		c.draw_circle(at + fwd * r * 0.35 + side * s * r * 0.38, r * 0.26, Color(BONE_HOLE, alpha))


func _scaled(points: PackedVector2Array, pivot: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(pivot + (p - pivot) * k)
	return out


func _bat(c: Object, at: Vector2, r: float, flap: float, heading: float, color: Color, alpha: float) -> void:
	var f := Vector2.RIGHT.rotated(heading)
	var s := f.orthogonal()
	var lift := 0.35 + 0.65 * absf(sin(flap))
	for side in [-1.0, 1.0]:
		var wing := PackedVector2Array([
			at + s * side * r * 0.2,
			at + s * side * r * 1.4 * lift - f * r * 0.1,
			at + s * side * r * 1.1 * lift - f * r * 0.55,
			at + s * side * r * 0.7 * lift - f * r * 0.3,
			at + s * side * r * 0.4 - f * r * 0.5,
		])
		c.draw_colored_polygon(wing, Color(color, alpha))
	c.draw_circle(at, r * 0.38, Color(color, alpha))
	c.draw_circle(at + f * r * 0.35, r * 0.25, Color(color, alpha))
	for e in [-1.0, 1.0]:
		c.draw_circle(at + f * r * 0.42 + s * e * r * 0.11, r * 0.07, Color(V_RED, alpha))


# ------------------------------------------------------------------ per enemy

## Zombie: sinks into its own grave - the earth opens, clods fly, a hand goes
## last; the hole closes as the zombie grave rises (ZombieGrave.RISE_DELAY).
func _sink(c: Object, r0: float, _fade: float) -> void:
	# The hole and clods hand over to the rising grave (which has its own clods).
	var fade := 1.0 - smoothstep(0.85, 1.2, _age)
	if fade <= 0.0:
		return
	var open := smoothstep(0.0, 0.3, _age) * (1.0 - smoothstep(0.8, 1.3, _age))
	c.draw_colored_polygon(_blob(Vector2.ZERO, Vector2(r0 * 1.6, r0 * 1.2), 0.4, 13), Color(DIRT, 0.9 * fade))
	c.draw_colored_polygon(_blob(Vector2.ZERO, Vector2(r0 * 1.1, r0 * 0.8) * open, 1.4, 11), Color(HOLE, fade))
	# The last hand reaching up, then pulled under.
	var hand := clampf((_age - 0.3) / 0.7, 0.0, 1.0)
	if hand > 0.0 and hand < 1.0:
		var up := sin(PI * hand)
		var base := Vector2(r0 * 0.1, 0)
		var tip := base + Vector2(0, -r0 * 1.2 * up)
		c.draw_line(base, tip, Z_SKIN[0], r0 * 0.3)
		c.draw_line(base, tip, Z_SKIN[1], r0 * 0.22)
		for f in [-1.0, 0.0, 1.0]:
			c.draw_line(tip, tip + Vector2(f * r0 * 0.18, -r0 * 0.25 * up), Z_SKIN[2], r0 * 0.08)
	# Dirt clods thrown out and settled around the rim.
	for bit in _bits:
		var p := _fling(bit, r0 * 1.7, 0.4)
		c.draw_circle(p + Vector2(0.8, 1.0), r0 * 0.16 * float(bit["r"]), Color(0, 0, 0, 0.25 * fade))
		c.draw_circle(p, r0 * 0.16 * float(bit["r"]), Color(DIRT_LIGHT, fade))
	c.draw_colored_polygon(_blob(Vector2(-r0 * 0.3, -r0 * 0.4), Vector2(r0 * 0.9, r0 * 0.35), 3.0, 9), Color(DIRT_LIGHT, 0.7 * fade))


## Skeleton: blows apart - a white crack of light, bones and the skull fly
## out spinning, bounce once and clatter to rest, a puff of bone dust.
func _bone_burst(c: Object, r0: float, fade: float) -> void:
	# Flash and shock ring.
	if _age < 0.25:
		var t := _age / 0.25
		c.draw_circle(Vector2.ZERO, r0 * lerpf(0.6, 1.3, t), Color(1, 1, 1, 0.7 * (1.0 - t)))
		c.draw_arc(Vector2.ZERO, r0 * lerpf(0.8, 2.8, _out(t)), 0.0, TAU, 28, Color(BONE[1], 0.8 * (1.0 - t)), 2.5 * (1.0 - t) + 0.6)
	# Bone dust puff.
	if _age < 0.7:
		var t := _age / 0.7
		for k in range(10):
			var a := TAU * float(k) / 10.0 + 0.3
			c.draw_circle(Vector2.RIGHT.rotated(a) * r0 * 1.9 * _out(t), r0 * 0.32 * (1.0 - t), Color(BONE[0], 0.55 * (1.0 - t)))
	# Tiny shards.
	if _age < 0.35:
		var t := _age / 0.35
		for bit in _bits:
			var p: Vector2 = Vector2(bit["dir"]).rotated(0.3) * r0 * 3.6 * _out(t)
			var d := Vector2.RIGHT.rotated(float(bit["rot"]) + _age * 20.0) * r0 * 0.12
			c.draw_line(p - d, p + d, Color(BONE[2], 1.0 - t), 1.4)
	for index in range(_bits.size()):
		var bit: Dictionary = _bits[index]
		var dir: Vector2 = bit["dir"]
		var reach: float = r0 * (3.4 if index == 0 else 2.8) * float(bit["dist"])
		var fly := 0.32 if index > 0 else 0.42
		var t := clampf((_age - float(bit["delay"]) * 0.2) / fly, 0.0, 1.0)
		var hop := clampf((_age - float(bit["delay"]) * 0.2 - fly) / 0.22, 0.0, 1.0)
		var p := dir * (reach * _out(t) + r0 * 0.5 * _out(hop))
		p.y -= sin(PI * t) * reach * (0.55 if index == 0 else 0.35) + sin(PI * hop) * r0 * 0.4
		var spin: float = float(bit["spin"]) * 2.2 * (minf(_age, fly) + 0.4 * minf(maxf(_age - fly, 0.0), 0.22))
		var rot: float = float(bit["rot"]) + spin
		if index == 0:
			_skull(c, p, r0 * 0.45, rot, fade)
		elif index <= 3:
			# Rib: a curved bone.
			var d := Vector2.RIGHT.rotated(rot) * r0 * 0.5
			var mid := p + d.orthogonal() * 0.35
			_bone(c, p - d, mid, r0 * 0.12, fade)
			_bone(c, mid, p + d, r0 * 0.12, fade)
		else:
			var d := Vector2.RIGHT.rotated(rot) * r0 * (0.5 if index < 7 else 0.32)
			_bone(c, p - d, p + d, r0 * 0.14, fade)


## Vampire: bursts into a swarm of bats that scatter and fly off.
func _bat_swarm(c: Object, r0: float, fade: float) -> void:
	if _age < 0.4:
		var t := _age / 0.4
		c.draw_circle(Vector2.ZERO, r0 * lerpf(0.8, 1.4, t), Color(BLOOD_LIT, 0.3 * (1.0 - t)))
	for bit in _bits:
		var t := clampf((_age - float(bit["delay"]) * 0.6) / 1.8, 0.0, 1.0)
		if t <= 0.0 or t >= 1.0:
			continue
		var dir: Vector2 = Vector2(bit["dir"]).rotated(sin(t * 4.0 + float(bit["phase"])) * 0.35)
		var p := dir * r0 * 3.4 * t * float(bit["dist"]) + Vector2(0, -r0 * 1.5 * t)
		var alpha := 1.0 - smoothstep(0.6, 1.0, t)
		_bat(c, p + Vector2(2.0, 3.0) * (1.0 + t), r0 * 0.4 * float(bit["r"]), _age * 22.0 + float(bit["phase"]), dir.angle(), Color(0, 0, 0, 1), 0.2 * alpha)
		_bat(c, p, r0 * 0.4 * float(bit["r"]), _age * 22.0 + float(bit["phase"]), dir.angle(), V_CAPE[1], alpha)


## Werewolf: the swollen body bursts - a red flash and mist, blood drops
## arc out and land as splats, fur-and-meat chunks spin out and bounce, and a
## pool spreads where it stood. Everything lies there, then fades.
func _blood_burst(c: Object, r0: float, fade: float) -> void:
	var t0 := _age - BURST_AT
	if t0 < 0.0:
		return
	# Pool spreading under the body.
	var pool := _out(t0 / 0.6)
	c.draw_colored_polygon(_blob(Vector2.ZERO, Vector2(r0 * 1.5, r0 * 1.15) * pool, 1.7, 13), Color(BLOOD_DARK, 0.92 * fade))
	c.draw_colored_polygon(_blob(Vector2(-r0 * 0.15, -r0 * 0.12), Vector2(r0 * 1.05, r0 * 0.75) * pool, 3.1, 11), Color(BLOOD, fade))
	c.draw_colored_polygon(_blob(Vector2(-r0 * 0.4, -r0 * 0.3), Vector2(r0 * 0.35, r0 * 0.2) * pool, 0.6, 8), Color(BLOOD_RED, 0.8 * fade))
	# Splats where the drops landed (under the flying bits).
	for bit in _bits:
		var dir: Vector2 = bit["dir"]
		var land: Vector2 = dir * r0 * 2.9 * float(bit["dist"])
		var t := (t0 - float(bit["delay"]) * 0.3) / 0.32
		if t < 1.0:
			continue
		var spread := _out((t - 1.0) * 3.0)
		var long := Vector2(r0 * 0.5, r0 * 0.28) * float(bit["r"]) * spread
		var splat := _blob(Vector2.ZERO, long, float(bit["phase"]), 9)
		var placed := PackedVector2Array()
		for q in splat:
			placed.append(land + q.rotated(dir.angle()))
		c.draw_colored_polygon(placed, Color(BLOOD, fade))
		c.draw_circle(land + dir * r0 * 0.75 * spread, r0 * 0.12 * float(bit["r"]), Color(BLOOD, fade))
		c.draw_circle(land - dir * r0 * 0.1 + dir.orthogonal() * r0 * 0.08, r0 * 0.12 * spread, Color(BLOOD_RED, 0.7 * fade))
	# Flash and red mist.
	if t0 < 0.16:
		var t := t0 / 0.16
		c.draw_circle(Vector2.ZERO, r0 * lerpf(0.9, 1.6, t), Color(BLOOD_RED, 0.75 * (1.0 - t)))
		c.draw_circle(Vector2.ZERO, r0 * lerpf(0.5, 0.9, t), Color(1.0, 0.8, 0.75, 0.6 * (1.0 - t)))
	if t0 < 0.6:
		var t := t0 / 0.6
		for k in range(9):
			var a := TAU * float(k) / 9.0 + 0.4
			c.draw_circle(Vector2.RIGHT.rotated(a) * r0 * 2.0 * _out(t), r0 * (0.5 - 0.3 * t), Color(BLOOD_RED, 0.4 * (1.0 - t)))
	# Drops in flight with a short streak behind them.
	for bit in _bits:
		for k in range(2):
			var dir: Vector2 = Vector2(bit["dir"]).rotated(0.3 * float(k))
			var reach := r0 * 2.9 * float(bit["dist"]) * (1.0 if k == 0 else 0.65)
			var t := (t0 - float(bit["delay"]) * 0.3) / 0.32
			if t <= 0.0 or t >= 1.0:
				continue
			var p := dir * reach * _out(t) + Vector2(0, -sin(PI * t) * reach * 0.3)
			var back := dir * reach * _out(maxf(t - 0.12, 0.0)) + Vector2(0, -sin(PI * maxf(t - 0.12, 0.0)) * reach * 0.3)
			c.draw_line(back, p, Color(BLOOD, 0.9), r0 * 0.16)
			c.draw_circle(p, r0 * 0.11 * float(bit["r"]), BLOOD_RED)
	# Fur-and-meat chunks: spin out, bounce once, lie there.
	for index in range(0, _bits.size(), 2):
		var bit: Dictionary = _bits[index]
		var dir: Vector2 = Vector2(bit["dir"]).rotated(0.5)
		var reach := r0 * 2.3 * float(bit["dist"])
		var fly := 0.38
		var t := clampf((t0 - float(bit["delay"]) * 0.2) / fly, 0.0, 1.0)
		var hop := clampf((t0 - float(bit["delay"]) * 0.2 - fly) / 0.2, 0.0, 1.0)
		var p := dir * (reach * _out(t) + r0 * 0.45 * _out(hop))
		p.y -= sin(PI * t) * reach * 0.45 + sin(PI * hop) * r0 * 0.35
		var rot: float = float(bit["rot"]) + float(bit["spin"]) * 2.0 * (minf(t0, fly) + 0.3 * minf(maxf(t0 - fly, 0.0), 0.2))
		var sz := r0 * 0.4 * float(bit["r"])
		var chunk := PackedVector2Array()
		for q in [Vector2(-1.0, -0.7), Vector2(0.4, -1.0), Vector2(1.1, -0.1), Vector2(0.6, 0.9), Vector2(-0.8, 0.7)]:
			chunk.append(p + (q as Vector2).rotated(rot) * sz)
		var shadow := PackedVector2Array()
		for q in chunk:
			shadow.append(q + Vector2(1.2, 1.6))
		c.draw_colored_polygon(shadow, Color(0, 0, 0, 0.25 * fade))
		var fur: Color = W_FUR[1] if index % 4 == 0 else W_FUR[0]
		c.draw_colored_polygon(chunk, Color(fur, fade))
		c.draw_circle(p + Vector2(0.45, 0.25).rotated(rot) * sz, sz * 0.55, Color(MEAT, fade))
		c.draw_circle(p + Vector2(0.55, 0.3).rotated(rot) * sz, sz * 0.28, Color(BLOOD_RED, fade))
