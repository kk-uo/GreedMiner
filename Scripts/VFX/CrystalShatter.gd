extends Node2D

## A mined crystal breaking: a white flash, a ring of light and crystal shards
## in the crystal's colours that fly out, tumble and fade. Presentation only.
## Load with preload(); no class_name on purpose.

const LIFE: float = 0.9

static var _BATCH := MeshBatch2D.new()

var color: Color = Palette.COBALT
var size: float = 1.0
var _age: float = 0.0
var _shards: Array = []


static func spawn(parent: Node, at: Vector2, crystal_color: Color, scale_factor: float = 1.0) -> Node2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var node: Node2D = load("res://Scripts/VFX/CrystalShatter.gd").new()
	node.set("color", crystal_color)
	node.set("size", scale_factor)
	parent.add_child(node)
	node.global_position = at
	return node


func _ready() -> void:
	z_index = 1
	for index in range(12):
		var a := TAU * float(index) / 12.0 + randf_range(-0.25, 0.25)
		_shards.append({"dir": Vector2.RIGHT.rotated(a), "dist": randf_range(18.0, 34.0), "r": randf_range(2.2, 4.2),
			"spin": randf_range(-9.0, 9.0), "rot": randf() * TAU})


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var c := _BATCH
	var k := _age / LIFE
	var s := size
	if k < 0.3:
		var f := k / 0.3
		c.draw_circle(Vector2(0, -4) * s, 16.0 * s * (1.0 - f * 0.5), Color(1, 1, 1, 0.85 * (1.0 - f)))
		c.draw_arc(Vector2(0, -4) * s, lerpf(10.0, 30.0, f) * s, 0.0, TAU, 24, Color(color.lightened(0.5), 0.8 * (1.0 - f)), 2.5)
	var out := 1.0 - pow(1.0 - minf(k / 0.55, 1.0), 2.0)
	var alpha := 1.0 - smoothstep(0.6, 1.0, k)
	for shard in _shards:
		var p: Vector2 = (shard["dir"] * float(shard["dist"]) * out + Vector2(0, -4.0 - sin(PI * minf(k / 0.55, 1.0)) * 10.0)) * s
		var r: float = float(shard["r"]) * s
		var rot: float = float(shard["rot"]) + float(shard["spin"]) * minf(_age, 0.5)
		var a := Vector2.RIGHT.rotated(rot) * r
		var b := a.orthogonal() * 0.55
		c.draw_colored_polygon(PackedVector2Array([p + a, p + b, p - a, p - b]), Color(color.darkened(0.25), alpha))
		c.draw_colored_polygon(PackedVector2Array([p + a, p + b, p]), Color(color.lightened(0.45), alpha))
	c.flush_to(self)
