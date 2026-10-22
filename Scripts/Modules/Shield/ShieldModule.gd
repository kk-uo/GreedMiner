class_name ShieldModule
extends ShipModule

## Shared base for defensive ship modules.
## Ship owns health aggregation; shield modules only expose their contribution
## and battle-active state.

@export var max_hp_bonus: float = 50.0
## Continuous power required by this shield module.
@export_range(0, 100, 1) var power_consumption: int = 0

var module_active: bool = true


func get_module_category() -> StringName:
	return CATEGORY_SHIELD


func get_power_consumption() -> int:
	return maxi(power_consumption, 0)


func get_max_hp_bonus() -> float:
	return maxf(max_hp_bonus, 0.0)


func set_module_active(active: bool) -> void:
	module_active = active


func get_research_modifiers(stat_id: StringName) -> Array[StatModifier]:
	return ResearchManager.get_shield_stat_modifiers(get_research_target_id(), stat_id)


func get_research_target_id() -> StringName:
	return &""


func calculate_researched_stat(stat_id: StringName, base_value: float) -> float:
	var modifiers := get_research_modifiers(stat_id)
	return maxf(StatModifierPipeline.calculate(stat_id, base_value, modifiers), 0.0)


## Compatibility alias for existing shield scripts; chips no longer contribute.
func calculate_chip_stat(stat_id: StringName, base_value: float) -> float:
	return calculate_researched_stat(stat_id, base_value)
