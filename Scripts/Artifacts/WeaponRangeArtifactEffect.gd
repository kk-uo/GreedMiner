extends MagicArtifactEffect

## Provides independently configured targeting-range and projectile-size
## modifiers. Keeping both values in artifact data prevents either stat from
## silently inheriting the other one's value.
const WeaponArtifactAura := preload("res://Scripts/VFX/WeaponArtifactAura.gd")
var weapon: WeaponModule
var _aura: Node2D


func configure_weapon(target_weapon: WeaponModule) -> void:
	weapon = target_weapon


func _ready() -> void:
	if is_instance_valid(weapon):
		weapon.add_artifact_range_bonus(Callable(self, "_get_range_bonus"))
		weapon.add_artifact_flat_range_bonus(Callable(self, "_get_flat_range_bonus"))
		weapon.add_artifact_projectile_range_bonus(Callable(self, "_get_projectile_range_bonus"))
		_aura = WeaponArtifactAura.new()
		_aura.set("kind", definition.artifact_id)
		weapon.add_child(_aura)
		weapon.move_child(_aura, 0)


func _get_range_bonus() -> float:
	return maxf(float(definition.effect_parameters.get("range_bonus", 0.0)), 0.0)


func _get_flat_range_bonus() -> float:
	return maxf(float(definition.effect_parameters.get("range_flat_bonus", 0.0)), 0.0)


func _get_projectile_range_bonus() -> float:
	return maxf(float(definition.effect_parameters.get("projectile_range_bonus", 0.0)), 0.0)


func cleanup() -> void:
	if is_instance_valid(weapon):
		weapon.remove_artifact_range_bonus(Callable(self, "_get_range_bonus"))
		weapon.remove_artifact_flat_range_bonus(Callable(self, "_get_flat_range_bonus"))
		weapon.remove_artifact_projectile_range_bonus(Callable(self, "_get_projectile_range_bonus"))
	if is_instance_valid(_aura):
		_aura.queue_free()
	queue_free()
