extends Node2D

## Snowball hitting the ship: a white ring, packed-snow chunks and glittering
## flakes bursting out. `big` is the boss's freezing snowball (a much larger
## burst with a cyan frost ring); `wood` is a sled's death animation
## (snow plus broken planks and a runner). Frees itself. Presentation only.
## Load with preload(); no class_name on purpose.

const SNOW := Color("F2FAFF")
const SHADE := Color("B5D3E6")
const ICE := Color("9FE7FF")

var big: bool = false
var wood: bool = false
const PLANK := Color("8A5A34")
const PLANK_DARK := Color("3B2A1E")
var _age: float = 0.0
var _life: float = 0.4
var _radius: float = 26.0
var _pieces: Array = []


func _ready() -> void:
	z_index = 6
	_life = 0.75 if big else (0.6 if wood else 0.4)
	_radius = 120.0 if big else (75.0 if wood else 26.0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count := 18 if big else (14 if wood else 8)
	for index in range(count):
		_pieces.append({
			"angle": TAU * float(index) / float(count) + rng.randf_range(-0.2, 0.2),
			"reach": rng.randf_range(0.6, 1.1),
			"size": rng.randf_range(0.7, 1.2) * (9.0 if big else (6.0 if wood else 3.5)),
			"spin": rng.randf_range(-5.0, 5.0),
			"ice": index % 3 == 0,
			"plank": wood and index % 2 == 0,
		})


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / _life
	var out := 1.0 - pow(1.0 - t, 3.0)
	var fade := 1.0 - smoothstep(0.4, 1.0, t)
	draw_circle(Vector2.ZERO, _radius * 0.45 * (1.0 - t), Color(SNOW, 0.8 * (1.0 - t)))
	draw_arc(Vector2.ZERO, _radius * lerpf(0.3, 1.0, out), 0.0, TAU, 48, Color(SNOW, 0.7 * fade), (10.0 if big else 3.0) * (1.0 - t) + 1.0)
	if big:
		draw_arc(Vector2.ZERO, _radius * lerpf(0.25, 0.85, out), 0.0, TAU, 48, Color(ICE, 0.8 * fade), 4.0 * (1.0 - t) + 1.0)
	for piece in _pieces:
		var dir := Vector2.RIGHT.rotated(float(piece["angle"]))
		var p: Vector2 = dir * _radius * float(piece["reach"]) * out
		var size: float = float(piece["size"]) * lerpf(1.0, 0.6, t)
		if bool(piece["plank"]):
			# Broken plank: a long thin board tumbling outward.
			var along := Vector2.RIGHT.rotated(float(piece["spin"]) * t * 2.0 + float(piece["angle"]))
			var across := Vector2(-along.y, along.x)
			var board := PackedVector2Array([p - along * size * 1.6 - across * size * 0.4, p + along * size * 1.6 - across * size * 0.4, p + along * size * 1.3 + across * size * 0.4, p - along * size * 1.6 + across * size * 0.4])
			draw_colored_polygon(board, Color(PLANK_DARK, fade))
			var top := PackedVector2Array([p - along * size * 1.45 - across * size * 0.22, p + along * size * 1.45 - across * size * 0.22, p + along * size * 1.2 + across * size * 0.12, p - along * size * 1.45 + across * size * 0.12])
			draw_colored_polygon(top, Color(PLANK, fade))
			continue
		var color: Color = ICE if bool(piece["ice"]) else (SNOW if int(float(piece["angle"]) * 10.0) % 2 == 0 else SHADE)
		draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(5, size, float(piece["spin"]) * t), p), Color(color, fade))
