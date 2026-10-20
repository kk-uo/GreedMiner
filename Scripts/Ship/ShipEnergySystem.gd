class_name ShipEnergySystem
extends RefCounted

## Calculates aggregate ship energy statistics from installed ShipModule data.
##
## The system has no scene or UI dependencies. Ship owns one instance and UI
## components consume the published totals through Ship.energy_changed.

signal totals_changed(
	total_power_capacity: int,
	total_power_consumption: int,
	available_power: int,
	total_expansion_capacity: int
)

var total_power_capacity: int = 0
var total_power_consumption: int = 0
var available_power: int = 0
var total_expansion_capacity: int = 0


## Recalculates and publishes every aggregate value from installed instances.
func recalculate(modules: Array[ShipModule]) -> void:
	var profile := calculate_profile(modules)
	total_power_capacity = profile.total_power_capacity
	total_power_consumption = profile.total_power_consumption
	available_power = profile.available_power
	total_expansion_capacity = profile.total_expansion_capacity

	totals_changed.emit(
		total_power_capacity,
		total_power_consumption,
		available_power,
		total_expansion_capacity
	)


## Returns totals for a proposed set without changing the current ship state.
func calculate_profile(modules: Array[ShipModule]) -> Dictionary:
	var profile := {
		"total_power_capacity": 0,
		"total_power_consumption": 0,
		"available_power": 0,
		"total_expansion_capacity": 0,
		"energy_module_count": 0,
	}

	for module in modules:
		if module == null or not is_instance_valid(module):
			continue

		profile.total_power_capacity += module.get_power_capacity()
		profile.total_power_consumption += module.get_power_consumption()
		profile.total_expansion_capacity += module.get_expansion_capacity()
		if module.get_module_category() == ShipModule.CATEGORY_ENERGY:
			profile.energy_module_count += 1

	# Research power built into the hull (no Energy Module needed).
	profile.total_power_capacity += ResearchManager.get_ship_base_power_bonus()

	profile.available_power = (
		profile.total_power_capacity
		- profile.total_power_consumption
	)
	return profile


## Returns a stable dictionary suitable for UI and debugging consumers.
func get_snapshot() -> Dictionary:
	return {
		"total_power_capacity": total_power_capacity,
		"total_power_consumption": total_power_consumption,
		"available_power": available_power,
		"total_expansion_capacity": total_expansion_capacity,
	}


## Calculates the energy profile represented by saved module scene paths.
## This keeps launch validation independent from a live Ship scene.
static func calculate_loadout_profile(installed_module_paths: Dictionary) -> Dictionary:
	var calculator := ShipEnergySystem.new()
	var modules: Array[ShipModule] = []
	for scene_path_value in installed_module_paths.values():
		var scene_path := String(scene_path_value)
		if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
			continue
		var scene := load(scene_path) as PackedScene
		if scene == null:
			continue
		var module := scene.instantiate() as ShipModule
		if module != null:
			modules.append(module)

	var profile := calculator.calculate_profile(modules)
	for module in modules:
		module.free()
	return profile


## Existing loadout validity shared by launch checks and Ship validation.
static func is_profile_operational(profile: Dictionary) -> bool:
	return (
		int(profile.get("energy_module_count", 0)) >= 1
		and int(profile.get("total_power_consumption", 0))
			<= int(profile.get("total_power_capacity", 0))
	)
