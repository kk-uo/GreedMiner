extends MagicArtifactEffect

## Adds gentle steering to projectiles, stronger steering to flame puffs, and
## one small post-target bend to piercing laser beams.
var weapon: WeaponModule


func configure_weapon(target_weapon: WeaponModule) -> void:
	weapon = target_weapon


func _ready() -> void:
	if not is_instance_valid(weapon):
		return
	weapon.add_artifact_projectile_homing(Callable(self, "_projectile_turn_rate"))
	weapon.add_artifact_flame_homing(Callable(self, "_flame_turn_rate"))
	weapon.add_artifact_homing_range(Callable(self, "_acquisition_range"))
	weapon.add_artifact_laser_deflection(Callable(self, "_laser_deflection"))


func _projectile_turn_rate() -> float:
	return maxf(float(definition.effect_parameters.get("projectile_turn_rate_degrees", 30.0)), 0.0)


func _flame_turn_rate() -> float:
	return maxf(float(definition.effect_parameters.get("flame_turn_rate_degrees", 120.0)), 0.0)


func _acquisition_range() -> float:
	return maxf(float(definition.effect_parameters.get("acquisition_range", 600.0)), 0.0)


func _laser_deflection() -> float:
	return maxf(float(definition.effect_parameters.get("laser_deflection_degrees", 8.0)), 0.0)


func cleanup() -> void:
	if is_instance_valid(weapon):
		weapon.remove_artifact_projectile_homing(Callable(self, "_projectile_turn_rate"))
		weapon.remove_artifact_flame_homing(Callable(self, "_flame_turn_rate"))
		weapon.remove_artifact_homing_range(Callable(self, "_acquisition_range"))
		weapon.remove_artifact_laser_deflection(Callable(self, "_laser_deflection"))
	queue_free()
