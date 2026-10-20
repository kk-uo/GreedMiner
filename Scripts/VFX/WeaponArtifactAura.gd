extends Node2D

## Small particles around the base of a weapon that carries a module artifact,
## drawn under the weapon's own visuals (it is the weapon's first child):
## - &"goblin_flag": red banner scraps swirling up around the base over a faint
##   red ring.
## - &"goblin_horn": green-gold sound ripples pulsing out from the base with a
##   few motes; they pulse faster and brighter as the horn's stacks grow.
## `bonus` (optional) returns the weapon's current fire-rate bonus.
## Added by WeaponFireRateArtifactEffect. Presentation only.
## Load with preload(); no class_name on purpose.

const FLAG := Color("C0392B")
const FLAG_LIGHT := Color("E8604A")
const HORN := Color("5E8F22")
const HORN_LIGHT := Color("9CC44C")
const HORN_GOLD := Color("E0A12A")
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
