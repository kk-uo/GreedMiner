extends Node2D

## Lightweight placeholder for the spirit released by Necronomicon. Claude
## Code can replace this presentation without changing the gameplay effect.
var radius: float = 80.0
var age: float = 0.0
const LIFE: float = 0.65


static func spawn(parent: Node, at: Vector2, burst_radius: float) -> void:
	if parent == null:
		return
	var burst := load("res://Scripts/VFX/NecroSpiritBurst.gd").new() as Node2D
	burst.radius = burst_radius
	parent.add_child(burst)
	burst.global_position = at


func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= LIFE:
		queue_free()


func _draw() -> void:
	var t := clampf(age / LIFE, 0.0, 1.0)
	var alpha := 1.0 - t
	draw_arc(Vector2.ZERO, lerpf(10.0, radius, t), 0.0, TAU, 48, Color(0.45, 0.95, 0.72, alpha * 0.75), 3.0)
	var rise := Vector2(0.0, -18.0 * t)
	draw_circle(rise, lerpf(12.0, 5.0, t), Color(0.72, 1.0, 0.86, alpha * 0.8))
	draw_circle(rise + Vector2(-4.0, -1.0), 1.5, Color(0.08, 0.16, 0.12, alpha))
	draw_circle(rise + Vector2(4.0, -1.0), 1.5, Color(0.08, 0.16, 0.12, alpha))
