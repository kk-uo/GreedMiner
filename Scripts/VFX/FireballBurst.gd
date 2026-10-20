extends Node2D

## Short orange burst where an Imp fireball hits the ship: a flash, an
## expanding ring and a few embers. World-space, frees itself.
## Load with preload(); no class_name on purpose.

const LIFETIME: float = 0.35
const FIRE := Color("FF8A2A")
const FIRE_LIGHT := Color("FFE08A")

var _age: float = 0.0
var _embers: Array[Vector2] = []


static func spawn(parent: Node, at: Vector2) -> Node2D:
	var burst: Node2D = load("res://Scripts/VFX/FireballBurst.gd").new()
	burst.z_index = 40
	parent.add_child(burst)
	burst.global_position = at
	return burst


func _ready() -> void:
	for index in range(6):
		_embers.append(Vector2.RIGHT.rotated(TAU * float(index) / 6.0 + randf_range(-0.3, 0.3)) * randf_range(14.0, 22.0))


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = _age / LIFETIME
	var fade: float = 1.0 - k
	var eased: float = 1.0 - pow(1.0 - k, 3.0)
	draw_circle(Vector2.ZERO, lerpf(6.0, 20.0, eased), Color(FIRE, 0.45 * fade))
	draw_arc(Vector2.ZERO, lerpf(6.0, 26.0, eased), 0.0, TAU, 28, Color(FIRE_LIGHT, fade), 3.0 * fade + 0.5)
	if k < 0.3:
		draw_circle(Vector2.ZERO, 7.0 * (1.0 - k / 0.3), Color(1, 1, 1, 0.9))
	for ember in _embers:
		draw_circle(ember * eased, 2.2 * fade + 0.4, FIRE_LIGHT)
