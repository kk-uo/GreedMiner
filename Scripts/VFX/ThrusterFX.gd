class_name ThrusterFX
extends Node2D

## Top-down rocket exhaust for the ship's thruster pods (style A, code-drawn).
##
## Small angular (hexagonal) puffs well up from the ground under each nozzle
## and roll outward in every direction. Each puff starts tiny and white-hot,
## grows, cools through yellow, orange and red, then turns into black smoke
## that fades. Emission follows Ship.thruster_power; no textures are used.

## Ship whose nozzles feed the effect.
var ship: Ship

## Puffs per second per nozzle at full power.
@export var emit_rate: float = 46.0
## Puff size range in world pixels (kept small on purpose).
@export var start_size: float = 3.0
@export var end_size: float = 12.0
@export var lifetime: Vector2 = Vector2(0.7, 1.15)
@export var spread_speed: Vector2 = Vector2(55.0, 125.0)

const SMOKE := Color("2B2420")
const SMOKE_LIGHT := Color("4A3F38")
const STAGES: Array = [
	[0.10, Color("FFF2C2")],
	[0.22, Color("FFD23F")],
	[0.40, Color("F08A24")],
	[0.55, Color("E2572A")],
	[0.68, Color("B8321F")],
]

var _particles: Array[Dictionary] = []
var _emit_debt: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Extra one-off puffs, e.g. at touchdown.
func burst(per_nozzle: int, speed_scale: float = 1.6) -> void:
	if ship == null:
		return
	for nozzle in ship.get_thruster_ground_positions():
		for index in range(per_nozzle):
			_spawn(nozzle, speed_scale)


func _process(delta: float) -> void:
	if ship != null and is_instance_valid(ship) and ship.thruster_power > 0.01:
		_emit_debt += emit_rate * ship.thruster_power * delta
		var nozzles := ship.get_thruster_ground_positions()
		while _emit_debt >= 1.0:
			_emit_debt -= 1.0
			for nozzle in nozzles:
				_spawn(nozzle, 0.6 + 0.4 * ship.thruster_power)

	for index in range(_particles.size() - 1, -1, -1):
		var puff := _particles[index]
		puff["age"] += delta
		if puff["age"] >= puff["life"]:
			_particles.remove_at(index)
			continue
		puff["pos"] += puff["vel"] * delta
		puff["vel"] *= maxf(0.0, 1.0 - 2.4 * delta)
		puff["rot"] += puff["spin"] * delta
	queue_redraw()


func _spawn(origin: Vector2, speed_scale: float) -> void:
	# Puffs roll outward away from the hull (the part under the hull is hidden).
	var outward := Vector2.RIGHT
	if ship != null:
		var center := ship.to_global(Ship.SHIP_SIZE * 0.5)
		if origin.distance_squared_to(center) > 1.0:
			outward = (origin - center).normalized()
	var direction := outward.rotated(_rng.randf_range(-1.9, 1.9))
	_particles.append({
		"pos": origin + direction * _rng.randf_range(0.0, 3.0),
		"vel": direction * _rng.randf_range(spread_speed.x, spread_speed.y) * speed_scale,
		"age": 0.0,
		"life": _rng.randf_range(lifetime.x, lifetime.y),
		"rot": _rng.randf() * TAU,
		"spin": _rng.randf_range(-2.0, 2.0),
		"size_jitter": _rng.randf_range(0.8, 1.2),
	})


func _draw() -> void:
	# Oldest (smoke) first so the hot new puffs sit on top at the nozzle.
	var ordered := _particles.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["age"] / a["life"] > b["age"] / b["life"]
	)
	for puff in ordered:
		var t: float = puff["age"] / puff["life"]
		var radius := lerpf(start_size, end_size, sqrt(t)) * float(puff["size_jitter"])
		var points := Palette.offset_points(Palette.regular_polygon(6, radius, puff["rot"]), to_local(puff["pos"]))
		var color := _color_at(t)
		draw_colored_polygon(points, color)
		if t > STAGES[STAGES.size() - 1][0]:
			var light := Color(SMOKE_LIGHT, color.a)
			var facet := Palette.offset_points(
				Palette.regular_polygon(6, radius * 0.5, puff["rot"]),
				to_local(puff["pos"]) + Vector2(-radius * 0.22, -radius * 0.28)
			)
			draw_colored_polygon(facet, light)


func _color_at(t: float) -> Color:
	for stage in STAGES:
		if t < stage[0]:
			return stage[1]
	var last: float = STAGES[STAGES.size() - 1][0]
	var fade := 1.0 - (t - last) / (1.0 - last)
	return Color(SMOKE, 0.82 * fade)
