class_name ChipEffect
extends Resource

## Extension interface for future chip effects. Default implementations are
## intentionally inert until real chip gameplay rules are approved.

@export var effect_id: StringName


func get_stat_modifiers(_chip_id: StringName, _context: Dictionary) -> Array[StatModifier]:
	return []


func apply(_context: Dictionary) -> void:
	pass


func remove(_context: Dictionary) -> void:
	pass
