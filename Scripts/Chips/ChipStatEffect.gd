class_name ChipStatEffect
extends ChipEffect

## Data-only stat effect used by chip quality tiers.

@export var stat_id: StringName
## Optional semantic effect shared by different module categories. When set,
## the requested stat is adapted through ADAPTED_STATS instead of stat_id.
@export var adaptation_id: StringName
@export var flat_bonus: float = 0.0
@export var base_additive_ratio: float = 0.0
@export var final_multiplier: float = 1.0


func get_stat_modifiers(chip_instance_id: StringName, context: Dictionary) -> Array[StatModifier]:
	var requested_stat := StringName(context.get("stat_id", &""))
	var resolved_stat := get_adapted_stat(requested_stat, context)
	if resolved_stat.is_empty():
		return []
	var modifier := StatModifier.new()
	modifier.source_id = StringName("chip.%s.%s" % [String(chip_instance_id), String(effect_id)])
	modifier.stat_id = resolved_stat
	modifier.flat_bonus = flat_bonus
	modifier.base_additive_ratio = base_additive_ratio
	modifier.final_multiplier = final_multiplier
	return [modifier]


## Resolves a universal chip effect to the stat exposed by its host module.
func get_adapted_stat(requested_stat: StringName, context: Dictionary) -> StringName:
	if adaptation_id.is_empty():
		return stat_id if requested_stat.is_empty() or requested_stat == stat_id else &""
	var module_kind := StringName(context.get("module_kind", &"weapon"))
	var candidates: Array = []
	match adaptation_id:
		&"flat_attack", &"damage_percent":
			candidates = [&"damage"] if module_kind == &"weapon" else ([&"shockwave_damage"] if module_kind == &"knockback" else [&"healing_amount"])
		&"action_frequency":
			candidates = [&"fire_rate"] if module_kind == &"weapon" else ([&"knockback_frequency"] if module_kind == &"knockback" else [&"healing_frequency"])
		&"range_percent":
			candidates = [&"attack_range"] if module_kind == &"weapon" else ([&"trigger_range", &"splash_radius"] if module_kind == &"knockback" else [&"healing_radius"])
		&"skill_cast_time":
			if bool(context.get("supports_active_skill", false)):
				candidates = [&"skill_cast_time"]
	return requested_stat if candidates.has(requested_stat) else &""


func supports_context(context: Dictionary) -> bool:
	return not get_adapted_stat(StringName(context.get("stat_id", &"")), context).is_empty()
