extends Node2D

## Lava bulging, bubbling and splashing as an enemy climbs out of a rift
## (LavaEmergence). Presentation only. Load with preload(); no class_name.

const LIFE: float = 1.1
const LAVA := Color("E2541A")
const HOT := Color("FFB347")
const CORE := Color("FFE08A")

var radius: float = 14.0
var _age: float = 0.0


static func spawn(parent: Node, at: Vector2, size: float = 14.0) -> Node2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var node: Node2D = load("res://Scripts/VFX/LavaEmergeFx.gd").new()
	node.set("radius", size)
	parent.add_child(node)
	node.global_position = at
	return node


func _ready() -> void:
	z_index = 2


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var r := radius
	# Bulge before it breaks the surface.
	if _age < 0.35:
		var k := _age / 0.35
		draw_circle(Vector2.ZERO, r * (0.6 + 0.6 * k), LAVA)
		draw_circle(Vector2(-2, -2), r * (0.3 + 0.4 * k), HOT)
		for i in range(4):
			var ph := fposmod(k * 2.0 + float(i) * 0.25, 1.0)
			draw_arc(Vector2(cos(i * 1.7), sin(i * 1.7)) * r * 0.7, 2.0 + ph * 5.0, 0.0, TAU, 12, Color(CORE, 1.0 - ph), 1.5)
	# Splash ring and lava drops thrown out.
	if _age >= 0.3:
		var k := clampf((_age - 0.3) / 0.8, 0.0, 1.0)
		draw_arc(Vector2.ZERO, r * (1.0 + 1.6 * k), 0.0, TAU, 32, Color(HOT, 0.8 * (1.0 - k)), 3.0 * (1.0 - k) + 1.0)
		for i in range(8):
			var d := Vector2.RIGHT.rotated(float(i) * 0.8 + 0.3)
			var p := d * r * (0.8 + 2.0 * k) + Vector2(0, -sin(PI * k) * 14.0)
			draw_circle(p, 2.6 * (1.0 - k) + 0.6, Color("FF9A3A", 1.0 - k * 0.8))
