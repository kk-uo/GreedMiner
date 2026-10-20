class_name ResearchEffect
extends Resource

## Extension point for category-specific research effects.

func get_stat_modifiers(_research_id: StringName, _target_id: StringName, _level: int) -> Array[StatModifier]:
	return []
