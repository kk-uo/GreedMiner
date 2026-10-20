extends Node2D

## Angry Stone splash: a ring of grey stone grit bursting out from the struck
## enemy to the splash radius, then fading. Spawned by AngryStoneEffect on
## every triggering hit, in the battle scene at the target's position; frees
## itself. Presentation only. Load with preload(); no class_name on purpose.

const LIFETIME: float = 0.42
const COUNT: int = 18
const GREYS: Array[Color] = [Color("8E939A"), Color("A8A29A"), Color("6A6E75"), Color("C4BFB6")]

var radius: float = 30.0
var _age: float = 0.0
var _particles: Array = []


func _ready() -> void:
	z_index = 5
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for index in range(COUNT):
		var angle := TAU * float(index) / float(COUNT) + rng.randf_range(-0.15, 0.15)
		_particles.append({
			"angle": angle,
			"reach": rng.randf_range(0.85, 1.15),
			"size": rng.randf_range(3.4, 5.4),
			"spin": rng.randf_range(-6.0, 6.0),
			"color": GREYS[index % GREYS.size()],
		})


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var ease := 1.0 - pow(1.0 - t, 3.0)
	var fade := 1.0 - smoothstep(0.45, 1.0, t)
	# Faint dusty ring at the splash edge.
	draw_arc(Vector2.ZERO, radius * lerpf(0.35, 1.0, ease), 0.0, TAU, 32, Color(GREYS[1], 0.35 * fade), 3.0)
	for particle in _particles:
		var dir := Vector2.RIGHT.rotated(particle["angle"])
		var p: Vector2 = dir * radius * float(particle["reach"]) * lerpf(0.25, 1.0, ease)
		var size: float = float(particle["size"]) * lerpf(1.0, 0.7, t)
		var color: Color = particle["color"]
		draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(4, size, float(particle["spin"]) * t), p), Color(color, fade))
