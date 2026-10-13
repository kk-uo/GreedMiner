class_name WeaponModule
extends Node2D

## Base class for weapon modules installed on the ship.
##
## Derived weapon modules provide their own damage, fire rate,
## and firing behavior through these overridable methods.

var damage: float:
	get:
		return get_damage()

var fire_rate: float:
	get:
		return get_fire_rate()


## Returns the damage dealt by one attack.
func get_damage() -> float:
	push_error("WeaponModule.get_damage() must be overridden.")
	return 0.0


## Returns the number of attacks fired per second.
func get_fire_rate() -> float:
	push_error("WeaponModule.get_fire_rate() must be overridden.")
	return 0.0


## Performs one weapon attack.
func fire() -> void:
	push_error("WeaponModule.fire() must be overridden.")
