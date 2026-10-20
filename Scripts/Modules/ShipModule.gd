class_name ShipModule
extends Node2D

## Shared gameplay-data interface for every module installed on the ship.
##
## Ship energy calculations depend only on this interface. Presentation scripts
## may read these values, but must not own or recalculate them.

const CATEGORY_GENERIC: StringName = &"generic"
const CATEGORY_WEAPON: StringName = &"weapon"
const CATEGORY_MINING: StringName = &"mining"
const CATEGORY_ENERGY: StringName = &"energy"
const CATEGORY_SHIELD: StringName = &"shield"

## Instance-local artifact modifier shared by compatible explosive modules.
var artifact_explosion_damage_bonus: Callable


func get_modified_explosion_damage(base_damage: float) -> float:
	if artifact_explosion_damage_bonus.is_valid():
		return base_damage * (1.0 + maxf(float(artifact_explosion_damage_bonus.call()), 0.0))
	return base_damage


## Returns the module category used by Ship for grid classification.
func get_module_category() -> StringName:
	return CATEGORY_GENERIC


## Returns continuous power required by this installed module.
func get_power_consumption() -> int:
	return 0


## Returns power capacity contributed by this installed module.
func get_power_capacity() -> int:
	return 0


## Returns future grid-expansion support contributed by this module.
func get_expansion_capacity() -> int:
	return 0


## Maximum hull health contributed while this module is installed.
func get_max_hp_bonus() -> float:
	return 0.0


## Hull health restored per second while combat modules are active.
func get_regeneration_per_second() -> float:
	return 0.0


## Chip adaptation category. Only explicitly supported modules return a value.
func get_chip_module_kind() -> StringName:
	return &""


## Number of instance-local chip sockets exposed after the Chip Lab unlock.
func get_chip_slot_count() -> int:
	return 0


## Active-skill chips are rejected unless a concrete module opts in here.
func supports_active_skill() -> bool:
	return false
