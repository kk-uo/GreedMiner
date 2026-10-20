extends Node2D

## Short burst of green healing particles over a healed friendly: small
## crosses and sparks that drift up and fade. Spawned by healing sources
## (RegenerationModule) at the target's healing position; frees itself.
## Load with preload(); no class_name on purpose.

const HEAL := Color("7CF0A8")
const HEAL_DARK := Color("2FA86A")
const HEAL_LIGHT := Color("D8FFE6")
const LIFETIME: float = 0.9

## Half-size of the area the particles spread over (ship ~ 60, small units ~ 16).
var spread: float = 60.0
var count: int = 7

var _age: float = 0.0
var _particles: Array[Dictionary] = []


static func spawn(parent: Node, at: Vector2, area: float = 60.0, amount: int = 7) -> Node2D:
	var burst: Node2D = load("res://Scripts/VFX/HealParticles.gd").new()
	burst.spread = area
	burst.count = amount
	burst.z_index = 40
	parent.add_child(burst)
	burst.global_position = at
	return burst


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for index in range(count):
		_particles.append({
			"pos": Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread * 0.6, spread * 0.6)),
			"rise": rng.randf_range(30.0, 52.0),
			"size": rng.randf_range(4.6, 7.0),
			"delay": rng.randf_range(0.0, 0.25),
			"cross": index % 3 != 2,
			"sway": rng.randf_range(-6.0, 6.0),
		})


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME + 0.25:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	# Particles always rise in screen space even if a parent is rotated.
	draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE)
	for particle in _particles:
		var k := clampf((_age - float(particle["delay"])) / LIFETIME, 0.0, 1.0)
		if k <= 0.0 or k >= 1.0:
			continue
		var ease_out := 1.0 - (1.0 - k) * (1.0 - k)
		var at: Vector2 = particle["pos"] + Vector2(float(particle["sway"]) * ease_out, -float(particle["rise"]) * ease_out)
		var alpha := sin(PI * k)
		var s: float = particle["size"] * (0.7 + 0.5 * sin(PI * minf(k * 2.0, 1.0)))
		if particle["cross"]:
			draw_rect(Rect2(at + Vector2(-s * 0.32, -s) + Vector2(1.0, 1.0), Vector2(s * 0.64, s * 2.0)), Color(HEAL_DARK, alpha * 0.6))
			draw_rect(Rect2(at + Vector2(-s, -s * 0.32) + Vector2(1.0, 1.0), Vector2(s * 2.0, s * 0.64)), Color(HEAL_DARK, alpha * 0.6))
			draw_rect(Rect2(at + Vector2(-s * 0.32, -s), Vector2(s * 0.64, s * 2.0)), Color(HEAL, alpha))
			draw_rect(Rect2(at + Vector2(-s, -s * 0.32), Vector2(s * 2.0, s * 0.64)), Color(HEAL, alpha))
		else:
			draw_circle(at, s * 0.9, Color(HEAL, alpha * 0.35))
			draw_circle(at, s * 0.45, Color(HEAL_LIGHT, alpha))
