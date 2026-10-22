extends HostileProjectile

## Minimal ranged attack placeholder. The existing hostile-projectile collision
## path applies its configured damage to the ship exactly once.
func _physics_process(delta: float) -> void:
	var battle := get_tree().current_scene
	if battle != null and battle.get("_battle_ended") == true:
		queue_free()
		return
	super(delta)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color("D8F0A3"))
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 16, Color("A7D889", 0.7), 1.5)
