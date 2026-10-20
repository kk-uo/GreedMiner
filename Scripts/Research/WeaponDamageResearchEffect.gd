class_name WeaponDamageResearchEffect
extends ResearchEffect

## Additive damage increase relative to the weapon's untouched base damage.

@export_range(0.0, 10.0, 0.01) var damage_bonus_per_level: float = 0.2


func get_damage_for_level(base_damage: float, level: int) -> float:
	return base_damage * (
		1.0 + damage_bonus_per_level * float(maxi(level - 1, 0))
	)


func get_stat_modifiers(research_id: StringName, _target_id: StringName, level: int) -> Array[StatModifier]:
	var modifier := StatModifier.new()
	modifier.source_id = research_id
	modifier.stat_id = &"damage"
	modifier.base_additive_ratio = damage_bonus_per_level * float(maxi(level - 1, 0))
	return [modifier]
