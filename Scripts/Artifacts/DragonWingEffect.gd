extends MagicArtifactEffect

## Lets a ground-only turret acquire and damage flying enemies while equipped.
var weapon: WeaponModule


func configure_weapon(target_weapon: WeaponModule) -> void:
	weapon = target_weapon


func _ready() -> void:
	if is_instance_valid(weapon):
		weapon.add_artifact_air_targeting(Callable(self, "_allows_air_targets"))


func _allows_air_targets() -> bool:
	return true


func cleanup() -> void:
	if is_instance_valid(weapon):
		weapon.remove_artifact_air_targeting(Callable(self, "_allows_air_targets"))
	queue_free()
