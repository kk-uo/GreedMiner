class_name ModuleStatResearchEffect
extends ResearchEffect

## Additive improvement relative to a module's untouched base stat.

@export var stat_id: StringName
@export_range(0.0, 10.0, 0.01) var bonus_per_level: float = 0.2


func get_value_for_level(base_value: float, level: int) -> float:
	return base_value * (1.0 + bonus_per_level * float(maxi(level - 1, 0)))


func get_stat_modifiers(research_id: StringName, _target_id: StringName, level: int) -> Array[StatModifier]:
	var modifier := StatModifier.new()
	modifier.source_id = research_id
	modifier.stat_id = stat_id
	modifier.base_additive_ratio = bonus_per_level * float(maxi(level - 1, 0))
	return [modifier]
