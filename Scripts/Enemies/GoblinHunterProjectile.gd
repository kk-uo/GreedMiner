class_name GoblinHunterProjectile
extends HostileProjectile

## Single-hit hostile projectile fired by a Goblin Hunter.

func _draw() -> void:
	GoblinVisual.draw_thrown_spear(self, direction.angle())


func _on_ship_hit() -> void:
	print("Goblin Hunter projectile hit! Damage: %s" % damage)
