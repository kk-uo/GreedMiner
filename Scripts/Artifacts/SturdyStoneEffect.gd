extends MagicArtifactEffect

## Adds a fixed penetration to each compatible projectile. Unlike Ghost
## Bullet, kills do not replenish this penetration.
var weapon: WeaponModule


func configure_weapon(target_weapon: WeaponModule) -> void:
	weapon = target_weapon


func _ready() -> void:
	if is_instance_valid(weapon):
		weapon.add_artifact_projectile_pierces(Callable(self, "_get_extra_pierces"))


func _get_extra_pierces() -> int:
	return maxi(int(definition.effect_parameters.get("extra_pierces", 1)), 0)


func cleanup() -> void:
	if is_instance_valid(weapon):
		weapon.remove_artifact_projectile_pierces(Callable(self, "_get_extra_pierces"))
	queue_free()
