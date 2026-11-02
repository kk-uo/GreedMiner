class_name DragonFireProjectile
extends HostileProjectile

## Painted size multiplier (the Ancient Dragon spits much bigger fireballs).
var visual_scale: float = 1.0
var _age: float = 0.0


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	var k := visual_scale
	var pulse := 1.0 + sin(_age * 18.0) * 0.12
	var back := -direction.normalized()
	# flame trail
	for i in range(4):
		var f := float(i + 1) / 4.0
		draw_circle(back * (6.0 + f * 16.0) * k, (6.0 - f * 3.5) * k * pulse, Color(0.85, 0.22, 0.12, 0.55 * (1.0 - f * 0.7)))
	draw_circle(Vector2.ZERO, 11.0 * k * pulse, Color(1.0, 0.45, 0.12, 0.25))
	draw_circle(Vector2.ZERO, 7.0 * k * pulse, Color("f05a28"))
	draw_circle(Vector2(-1.5, -1.5) * k, 4.0 * k * pulse, Color("ffd35a"))
	draw_circle(Vector2(-2.0, -2.0) * k, 1.8 * k, Color("fff6cf"))
