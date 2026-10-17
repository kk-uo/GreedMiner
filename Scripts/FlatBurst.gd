class_name FlatBurst
extends Node2D

## Short style-A impact effect drawn from primitives: a hot core, an expanding
## ring and a few dark shards. No textures; frees itself when finished.

const DURATION: float = 0.32

var radius: float = 24.0
var ring_color: Color = Palette.SHOT
var shard_color: Color = Palette.ENEMY

var _age: float = 0.0
var _shard_angles: PackedFloat32Array = PackedFloat32Array()


## Adds a burst to parent at a global position. Safe to call during physics callbacks.
static func spawn(
	parent: Node,
	world_position: Vector2,
	burst_radius: float = 24.0,
	color: Color = Palette.SHOT,
	shards: Color = Palette.ENEMY
) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var burst := FlatBurst.new()
	burst.radius = burst_radius
	burst.ring_color = color
	burst.shard_color = shards
	burst.z_index = 20
	parent.call_deferred("add_child", burst)
	burst.set_deferred("global_position", world_position)


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for index in range(5):
		_shard_angles.append(TAU * float(index) / 5.0 + rng.randf_range(-0.4, 0.4))


func _process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / DURATION, 0.0, 1.0)
	var ease_out := 1.0 - pow(1.0 - t, 3.0)

	# Hot core collapses quickly.
	if t < 0.45:
		draw_circle(Vector2.ZERO, radius * 0.45 * (1.0 - t / 0.45), Palette.SHOT_CORE)

	# Expanding ring thins out as it fades.
	var ring := ring_color
	ring.a = 1.0 - t
	draw_arc(Vector2.ZERO, radius * (0.4 + 0.6 * ease_out), 0.0, TAU, 28, ring, 3.0 * (1.0 - t) + 1.0)

	# Dark triangular shards fly outward.
	var shard := shard_color
	shard.a = 1.0 - t * t
	for angle in _shard_angles:
		var center := Vector2.RIGHT.rotated(angle) * radius * (0.5 + 0.9 * ease_out)
		var tri := Palette.regular_polygon(3, 4.0, angle + t * 4.0)
		draw_colored_polygon(Palette.offset_points(tri, center), shard)
