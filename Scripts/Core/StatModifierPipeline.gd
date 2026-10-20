class_name StatModifierPipeline
extends RefCounted

## Combines modifiers without mutating the original base value. Duplicate
## source IDs replace each other instead of applying the same bonus twice.

static func calculate(
	stat_id: StringName,
	base_value: float,
	modifiers: Array[StatModifier]
) -> float:
	var unique: Dictionary = {}
	for modifier in modifiers:
		if modifier == null or modifier.stat_id != stat_id or modifier.source_id.is_empty():
			continue
		unique[modifier.source_id] = modifier

	var flat_total: float = 0.0
	var base_ratio_total: float = 0.0
	var multiplier_total: float = 1.0
	for value in unique.values():
		var modifier := value as StatModifier
		flat_total += modifier.flat_bonus
		base_ratio_total += modifier.base_additive_ratio
		multiplier_total *= maxf(modifier.final_multiplier, 0.0)
	return (base_value + flat_total + base_value * base_ratio_total) * multiplier_total
