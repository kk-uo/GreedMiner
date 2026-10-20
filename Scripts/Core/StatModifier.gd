class_name StatModifier
extends Resource

## One uniquely keyed contribution to a gameplay stat.

@export var source_id: StringName
@export var stat_id: StringName
@export var flat_bonus: float = 0.0
@export var base_additive_ratio: float = 0.0
@export var final_multiplier: float = 1.0
