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

## Instance-local artifact modifiers shared by compatible explosive modules.
## A list lets multiple equipped artifacts coexist without the last one
## overwriting an earlier provider.
var artifact_explosion_damage_bonuses: Array[Callable] = []


func get_modified_explosion_damage(base_damage: float) -> float:
	var total_bonus := 0.0
	for provider in artifact_explosion_damage_bonuses.duplicate():
		if provider.is_valid():
			total_bonus += maxf(float(provider.call()), 0.0)
		else:
			artifact_explosion_damage_bonuses.erase(provider)
	return base_damage * (1.0 + total_bonus)


func add_artifact_explosion_damage_bonus(provider: Callable) -> void:
	if provider.is_valid() and not artifact_explosion_damage_bonuses.has(provider):
		artifact_explosion_damage_bonuses.append(provider)


func remove_artifact_explosion_damage_bonus(provider: Callable) -> void:
	artifact_explosion_damage_bonuses.erase(provider)


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


## Legacy module-category interface retained only for old save migration.
func get_chip_module_kind() -> StringName:
	return &""


## Legacy compatibility interface. Active equipment uses ArtifactManager.
func get_chip_slot_count() -> int:
	return 0


## Legacy compatibility interface for retired active-skill chip data.
func supports_active_skill() -> bool:
	return false
