extends Node2D

## Small particles around the base of a weapon that carries a module artifact,
## drawn under the weapon's own visuals (it is the weapon's first child):
## - &"goblin_flag": red banner scraps swirling up around the base over a faint
##   red ring.
## - &"goblin_horn": green-gold sound ripples pulsing out from the base with a
##   few motes; they pulse faster and brighter as the horn's stacks grow.
## - &"demon_prism": a slowly turning crimson triangle sigil with three
##   refracted light rays sweeping out from the base and rising embers.
## - &"red_crystal": a faint red ring with small red crystal shards and sparks
##   drifting up from the base (Dwarf Cannon / Knockback).
## - &"ghost_bullet": pale translucent wisps circling the base.
## `bonus` (optional) returns the weapon's current fire-rate bonus.
## Added by WeaponFireRateArtifactEffect. Presentation only.
## Load with preload(); no class_name on purpose.

const FLAG := Color("C0392B")
const FLAG_LIGHT := Color("E8604A")
const HORN := Color("5E8F22")
const HORN_LIGHT := Color("9CC44C")
const HORN_GOLD := Color("E0A12A")
const PRISM := Color("C0182E")
const PRISM_LIGHT := Color("FF4A3D")
const PRISM_HOT := Color("FFB347")
const RADIUS: float = 27.0

var kind: StringName = &""
var bonus: Callable
var _time: float = 0.0
var _seeds: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	for index in range(9):
		_seeds.append({"phase": rng.randf(), "angle": rng.randf() * TAU, "speed": rng.randf_range(0.7, 1.2), "size": rng.randf_range(0.8, 1.2)})


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	match kind:
		&"goblin_flag":
			_draw_flag()
		&"goblin_horn":
			_draw_horn()
		&"demon_prism":
			_draw_prism()
		&"red_crystal":
			_draw_red_crystal()
		&"ghost_bullet":
			_draw_ghost()


func _draw_flag() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	draw_circle(Vector2.ZERO, RADIUS + 2.0, Color(FLAG, 0.16 + 0.06 * pulse))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, Color(FLAG, 0.55 + 0.2 * pulse), 2.5)
	for mote in _seeds:
		var ph := fposmod(_time * 0.55 * float(mote["speed"]) + float(mote["phase"]), 1.0)
		var a := float(mote["angle"]) + ph * 2.2
		var p := Vector2(cos(a), sin(a)) * RADIUS * lerpf(0.75, 1.05, ph) + Vector2(0, -16.0 * ph)
		var size := 5.5 * float(mote["size"]) * (1.0 - 0.4 * ph)
		var spin := a * 2.0 + ph * 6.0
		var dir := Vector2.RIGHT.rotated(spin)
		var side := Vector2(-dir.y, dir.x)
		var alpha := sin(PI * ph)
		draw_colored_polygon(PackedVector2Array([p - dir * size, p + dir * size, p + side * size * 0.8]), Color(FLAG if int(float(mote["phase"]) * 10.0) % 2 == 0 else FLAG_LIGHT, alpha))


func _draw_horn() -> void:
	var stacks := 0.0
	if bonus.is_valid():
		stacks = clampf(float(bonus.call()) / 0.2, 0.0, 1.0)  # full glow at +20%
	var tempo := lerpf(0.6, 1.4, stacks)
	draw_circle(Vector2.ZERO, RADIUS + 2.0, Color(HORN_LIGHT, 0.18 + 0.12 * stacks))
	for ring in range(2):
		var ph := fposmod(_time * tempo + float(ring) * 0.5, 1.0)
		var r := lerpf(RADIUS * 0.55, RADIUS * 1.35, ph)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(HORN, (0.8 + 0.2 * stacks) * (1.0 - ph)), 3.2 * (1.0 - ph) + 1.0)
	for index in range(6):
		var mote: Dictionary = _seeds[index]
		var ph := fposmod(_time * 0.4 * float(mote["speed"]) * tempo + float(mote["phase"]), 1.0)
		var a := float(mote["angle"])
		var p := Vector2(cos(a), sin(a)) * RADIUS * lerpf(0.7, 1.15, ph)
		draw_circle(p, 3.0 * float(mote["size"]) * (1.0 - 0.4 * ph), Color(HORN_GOLD, (0.75 + 0.25 * stacks) * sin(PI * ph)))


func _draw_prism() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 2.4)
	draw_circle(Vector2.ZERO, RADIUS + 3.0, Color(PRISM, 0.14 + 0.06 * pulse))
	# Turning triangle sigil inside a thin ring.
	var turn := _time * 0.5
	var tri := PackedVector2Array()
	for k in range(4):
		tri.append(Vector2.RIGHT.rotated(turn + TAU * float(k) / 3.0) * RADIUS * 0.98)
	draw_polyline(tri, Color(PRISM_LIGHT, 0.55 + 0.25 * pulse), 2.0)
	var tri2 := PackedVector2Array()
	for k in range(4):
		tri2.append(Vector2.RIGHT.rotated(-turn * 0.7 + PI + TAU * float(k) / 3.0) * RADIUS * 0.8)
	draw_polyline(tri2, Color(PRISM, 0.4 + 0.2 * pulse), 1.5)
	draw_arc(Vector2.ZERO, RADIUS + 1.0, 0.0, TAU, 40, Color(PRISM, 0.5), 1.5)
	# Three refracted rays sweeping outward from the sigil corners.
	for k in range(3):
		var a := turn + TAU * float(k) / 3.0
		var dir := Vector2.RIGHT.rotated(a)
		var side := Vector2(-dir.y, dir.x)
		var ph := fposmod(_time * 0.8 + float(k) / 3.0, 1.0)
		var reach := RADIUS * lerpf(1.1, 1.9, ph)
		var alpha := sin(PI * ph) * 0.8
		var root := dir * RADIUS * 0.95
		draw_colored_polygon(PackedVector2Array([root, dir * reach + side * 7.0, dir * reach - side * 7.0]), Color(PRISM_LIGHT, alpha * 0.7))
		draw_line(root, dir * reach, Color(PRISM_HOT, alpha), 2.0)
	# Rising embers.
	for index in range(6):
		var mote: Dictionary = _seeds[index]
		var ph := fposmod(_time * 0.45 * float(mote["speed"]) + float(mote["phase"]), 1.0)
		var a := float(mote["angle"])
		var p := Vector2(cos(a), sin(a)) * RADIUS * 0.9 + Vector2(0, -18.0 * ph)
		draw_circle(p, 2.2 * float(mote["size"]) * (1.0 - 0.5 * ph), Color(PRISM_HOT if index % 2 == 0 else PRISM_LIGHT, sin(PI * ph)))


const RED := Color("D7263D")
const RED_LIGHT := Color("FF5A6E")
const RED_HOT := Color("FFB3BC")


func _draw_red_crystal() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 2.6)
	draw_circle(Vector2.ZERO, RADIUS + 2.0, Color(RED, 0.12 + 0.06 * pulse))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, Color(RED, 0.45 + 0.2 * pulse), 2.0)
	# Little crystal shards drifting up, turning, with a lit facet.
	for mote in _seeds:
		var ph := fposmod(_time * 0.42 * float(mote["speed"]) + float(mote["phase"]), 1.0)
		var a := float(mote["angle"])
		var p := Vector2(cos(a), sin(a)) * RADIUS * lerpf(0.8, 1.0, ph) + Vector2(0, -22.0 * ph)
		var alpha := sin(PI * ph)
		var size := 4.2 * float(mote["size"]) * (1.0 - 0.35 * ph)
		var spin := a + _time * 1.5 * float(mote["speed"])
		var up := Vector2.UP.rotated(spin * 0.3) * size * 1.4
		var across := Vector2.RIGHT.rotated(spin * 0.3) * size * 0.75
		draw_colored_polygon(PackedVector2Array([p + up, p + across, p - up, p - across]), Color(RED, alpha))
		draw_colored_polygon(PackedVector2Array([p + up, p - across, p]), Color(RED_LIGHT, alpha))
	# Bright sparks.
	for index in range(5):
		var mote: Dictionary = _seeds[index]
		var ph := fposmod(_time * 0.9 * float(mote["speed"]) + float(mote["phase"]) * 1.7, 1.0)
		var a := float(mote["angle"]) + 1.3
		var p := Vector2(cos(a), sin(a)) * RADIUS * 0.9 + Vector2(0, -14.0 * ph)
		draw_circle(p, 1.6 * (1.0 - ph), Color(RED_HOT, sin(PI * ph)))


const GHOST := Color("BDF1FF")


func _draw_ghost() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 2.0)
	draw_circle(Vector2.ZERO, RADIUS + 2.0, Color(GHOST, 0.07 + 0.05 * pulse))
	# Three wisps chasing each other around the base, each a fading tail.
	for w in range(3):
		var head := _time * 1.6 + TAU * float(w) / 3.0
		for k in range(8):
			var a := head - float(k) * 0.16
			var wobble := sin(_time * 5.0 + float(k) + float(w)) * 2.5
			var p := Vector2(cos(a), sin(a)) * (RADIUS + wobble)
			draw_circle(p, lerpf(3.6, 0.8, float(k) / 7.0), Color(GHOST, 0.5 * (1.0 - float(k) / 8.0)))
