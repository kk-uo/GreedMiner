class_name FireballProjectile
extends HostileProjectile

## Fireball thrown by an Imp: flickering flame in flight, bursts on the hull.

const FireballBurstScript := preload("res://Scripts/VFX/FireballBurst.gd")

var _age: float = 0.0


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	DemonVisual.draw_fireball(self, direction, _age)


func _on_ship_hit() -> void:
	var parent := get_parent()
	if parent != null:
		FireballBurstScript.spawn(parent, global_position)
	print("Imp fireball hit! Damage: %s" % damage)
