class_name ShipDamageArea
extends Area2D

## Physics receiver used by hostile projectiles.
## Keeping this adapter separate prevents projectile logic from owning ship HP.


## Applies damage through the Ship's authoritative health method.
func apply_damage(amount: float) -> void:
	var ship := get_parent() as Ship
	if ship != null:
		ship.take_damage(amount)
