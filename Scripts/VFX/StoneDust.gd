class_name StoneDust
extends Node2D

## Ground dust kicked up by stone enemies (style A, code-drawn).
##
## Hexagonal puffs roll outward from a point, grow, slow down and fade. Drawn
## on the ground layer: above the battlefield, below the ship and enemies.
## Each spawn() call makes one short-lived node that frees itself.

## Above Battlefield (-100), below ship / enemies (0).
const GROUND_Z: int = -50

var _puffs: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


## Adds count puffs at a global position. direction = Vector2.ZERO spreads them
## all around; otherwise they fan out within +-spread radians of it.
## Safe to call during physics callbacks.
static func spawn(
	parent: Node,
	world_position: Vector2,
	count: int,
	size: float = 10.0,
	speed: float = 40.0,
	life: float = 1.1,
	direction: Vector2 = Vector2.ZERO,
	spread: float = PI
) -> void:
	if parent == null or not parent.is_inside_tree() or count <= 0:
		return
	var dust := StoneDust.new()
	dust.z_index = GROUND_Z
	dust._rng.randomize()
	for index in range(count):
		dust._add_puff(size, speed, life, direction, spread)
	parent.call_deferred("add_child", dust)
	dust.set_deferred("global_position", world_position)


func _add_puff(size: float, speed: float, life: float, direction: Vector2, spread: float) -> void:
	var angle: float
	if direction == Vector2.ZERO:
		angle = _rng.randf_range(0.0, TAU)
	else:
		angle = direction.angle() + _rng.randf_range(-spread, spread)
	var heading := Vector2.RIGHT.rotated(angle)
	var tones: Array[Color] = [Palette.STONE_DUST, Palette.STONE_DUST.lightened(0.18), Palette.STONE_DUST.darkened(0.14)]
	_puffs.append({
		"pos": heading * _rng.randf_range(0.0, size * 0.6),
		"vel": heading * speed * _rng.randf_range(0.5, 1.0),
		"from": size * _rng.randf_range(0.3, 0.5),
		"to": size * _rng.randf_range(0.9, 1.3),
		"life": life * _rng.randf_range(0.7, 1.15),
		"age": 0.0,
		"rot": _rng.randf_range(0.0, TAU),
		"color": tones[_rng.randi() % tones.size()],
	})


func _process(delta: float) -> void:
	var damping: float = exp(-2.6 * delta)
	for index in range(_puffs.size() - 1, -1, -1):
		var puff := _puffs[index]
		puff["age"] += delta
		if puff["age"] >= puff["life"]:
			_puffs.remove_at(index)
			continue
		puff["pos"] += puff["vel"] * delta
		puff["vel"] *= damping
	if _puffs.is_empty():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for puff in _puffs:
		var t: float = puff["age"] / puff["life"]
		var size: float = lerpf(puff["from"], puff["to"], 1.0 - pow(1.0 - t, 3.0))
		var color: Color = puff["color"]
		color.a = 0.75 * pow(1.0 - t, 1.4)
		var hexagon := Palette.regular_polygon(6, size, puff["rot"] + t * 0.6)
		draw_colored_polygon(Palette.offset_points(hexagon, puff["pos"]), color)
