extends MagicArtifactEffect

## Adds one projectile to every bullet/projectile volley. Compatible beam,
## wave, saw and continuous-flame attacks never consume this provider.
var weapon: WeaponModule


func configure_weapon(target_weapon: WeaponModule) -> void:
	weapon = target_weapon


func _ready() -> void:
	if is_instance_valid(weapon):
		weapon.add_artifact_projectile_count_bonus(Callable(self, "_get_extra_projectiles"))


func _get_extra_projectiles() -> int:
	return maxi(int(definition.effect_parameters.get("extra_projectiles", 1)), 0)


func cleanup() -> void:
	if is_instance_valid(weapon):
		weapon.remove_artifact_projectile_count_bonus(Callable(self, "_get_extra_projectiles"))
	queue_free()
