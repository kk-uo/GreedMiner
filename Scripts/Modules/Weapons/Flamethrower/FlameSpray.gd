extends Node2D

## The flamethrower's visible flame (rendering only; FlamethrowerProjectile
## carries the damage). While the weapon sprays, many small hexagonal puffs
## shoot out of the nozzle in a narrow cone, like the ship's thruster fire:
## white-hot, swelling and cooling through yellow, orange and red into dark
## smoke at the end of the range. Each puff hangs at the end of its flight
## for LINGER seconds (matching FlamethrowerProjectile.LINGER_TIME), flickering
## as it cools from red into smoke. Lives in world space (top_level) so the
## flame does not swing with the turret.

const STAGES: Array = [
	[0.10, Color("FFF2C2")],
	[0.26, Color("FFD23F")],
	[0.48, Color("F08A24")],
	[0.66, Color("E2572A")],
	[0.80, Color("B8321F")],
]
const SMOKE := Color("2B2420")
const EMIT_RATE: float = 45.0
const LINGER: float = 0.5
## Share of the colour ramp used while flying; the rest is the linger fade.
const FLY_SHARE: float = 0.72

var weapon: Node
var muzzle: Node2D
var _particles: Array = []
var _debt: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true
	z_index = 3
	_rng.randomize()


func _process(delta: float) -> void:
	global_position = Vector2.ZERO
	var spraying: bool = is_instance_valid(weapon) and weapon.call("is_spraying")
	if spraying and is_instance_valid(muzzle):
		_debt += EMIT_RATE * delta
		var speed: float = float(weapon.get("projectile_speed"))
		var reach: float = float(weapon.call("get_modified_attack_range", weapon.get("attack_range")))
		var grow: float = float(weapon.call("get_flame_size_scale"))
		while _debt >= 1.0:
			_debt -= 1.0
			var dir := Vector2.RIGHT.rotated(muzzle.global_rotation + _rng.randf_range(-0.16, 0.16))
			var v := speed * _rng.randf_range(0.85, 1.1)
			_particles.append({"pos": muzzle.global_position + dir * _rng.randf_range(0.0, 6.0), "vel": dir * v,
					"age": 0.0, "fly": reach / v * _rng.randf_range(0.9, 1.15), "linger": LINGER * _rng.randf_range(0.85, 1.1), "rot": _rng.randf() * TAU,
					"spin": _rng.randf_range(-4.0, 4.0), "size": _rng.randf_range(0.8, 1.2) * grow})
	else:
		_debt = 0.0
	for index in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[index]
		p["age"] += delta
		if p["age"] >= float(p["fly"]) + float(p["linger"]):
			_particles.remove_at(index)
			continue
		if p["age"] < p["fly"]:
			p["pos"] += p["vel"] * delta
			p["rot"] += p["spin"] * delta
		else:
			p["rot"] += p["spin"] * delta * 0.3
	queue_redraw()


func _draw() -> void:
	# Oldest (smoke) first so the hot puffs near the nozzle sit on top.
	for index in range(_particles.size()):
		var p: Dictionary = _particles[index]
		var age: float = p["age"]
		var fly: float = p["fly"]
		var t: float
		var radius: float
		if age < fly:
			t = age / fly * FLY_SHARE
			radius = lerpf(3.0, 15.0, sqrt(age / fly))
		else:
			# Hanging in place: flickers, swells a little and cools to smoke.
			var k: float = (age - fly) / float(p["linger"])
			t = FLY_SHARE + (1.0 - FLY_SHARE) * k * k
			radius = (15.0 + 3.0 * k) * (1.0 + 0.08 * sin(age * 30.0 + float(p["spin"]) * 5.0))
		radius *= float(p["size"])
		draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(6, radius, p["rot"]), p["pos"]), _color_at(t))


func _color_at(t: float) -> Color:
	for stage in STAGES:
		if t < stage[0]:
			return stage[1]
	var last: float = STAGES[STAGES.size() - 1][0]
	return Color(SMOKE, 0.7 * (1.0 - (t - last) / (1.0 - last)))
