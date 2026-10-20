class_name ShieldModule
extends ShipModule

## Shared base for defensive ship modules.
## Ship owns health aggregation; shield modules only expose their contribution
## and battle-active state.

@export var max_hp_bonus: float = 50.0
@export_range(0, 8, 1) var chip_slot_count: int = 0
@export_range(1, 8, 1) var max_chip_slots: int = 3

var module_active: bool = true


func get_module_category() -> StringName:
	return CATEGORY_SHIELD


func get_max_hp_bonus() -> float:
	return maxf(max_hp_bonus, 0.0)


func set_module_active(active: bool) -> void:
	module_active = active


func get_chip_slot_count() -> int:
	return maxi(chip_slot_count, 0)


func get_chip_modifiers(stat_id: StringName) -> Array[StatModifier]:
	return ChipManager.get_stat_modifiers({
		"stat_id": stat_id,
		"module_instance": self,
		"module_kind": get_chip_module_kind(),
		"supports_active_skill": supports_active_skill(),
	})


func get_research_modifiers(stat_id: StringName) -> Array[StatModifier]:
	return ResearchManager.get_shield_stat_modifiers(get_research_target_id(), stat_id)


func get_research_target_id() -> StringName:
	return &""


func calculate_chip_stat(stat_id: StringName, base_value: float) -> float:
	var modifiers := get_research_modifiers(stat_id)
	modifiers.append_array(get_chip_modifiers(stat_id))
	return maxf(StatModifierPipeline.calculate(stat_id, base_value, modifiers), 0.0)
