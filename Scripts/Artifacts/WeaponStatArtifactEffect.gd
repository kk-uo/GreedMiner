extends MagicArtifactEffect

## Applies data-driven targeting-range and final-damage modifiers to the one
## weapon module that owns this artifact slot.

var weapon: WeaponModule


func configure_weapon(target_weapon: WeaponModule) -> void:
	weapon = target_weapon


func _ready() -> void:
	if not is_instance_valid(weapon):
		return
	weapon.add_artifact_range_bonus(Callable(self, "_get_range_bonus"))
	weapon.add_artifact_damage_multiplier(Callable(self, "_get_damage_multiplier"))
	if definition.effect_parameters.has("base_damage_bonus"):
		weapon.add_artifact_base_damage_bonus(Callable(self, "_get_base_damage_bonus"))


func _get_range_bonus() -> float:
	return maxf(float(definition.effect_parameters.get("range_bonus", 0.0)), 0.0)


func _get_damage_multiplier() -> float:
	return maxf(float(definition.effect_parameters.get("damage_multiplier", 1.0)), 0.0)


func _get_base_damage_bonus() -> float:
	return float(definition.effect_parameters.get("base_damage_bonus", 0.0))


func cleanup() -> void:
	if is_instance_valid(weapon):
		weapon.remove_artifact_range_bonus(Callable(self, "_get_range_bonus"))
		weapon.remove_artifact_damage_multiplier(Callable(self, "_get_damage_multiplier"))
		weapon.remove_artifact_base_damage_bonus(Callable(self, "_get_base_damage_bonus"))
	queue_free()
