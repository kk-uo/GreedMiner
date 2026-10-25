extends MagicArtifactEffect

## Applies a temporary slow only from real projectile impacts. Beams, contact
## damage, explosions and artifact splash never emit WeaponModule.projectile_hit.
var weapon: WeaponModule


func configure_weapon(target_weapon: WeaponModule) -> void:
	weapon = target_weapon


func _ready() -> void:
	if is_instance_valid(weapon):
		weapon.projectile_hit.connect(_on_projectile_hit)


func _on_projectile_hit(enemy: BasicEnemy, _actual_damage: float) -> void:
	if not is_instance_valid(enemy) or enemy.is_dying():
		return
	enemy.apply_artifact_projectile_slow(
		maxf(float(definition.effect_parameters.get("slow_fraction", 0.30)), 0.0),
		maxf(float(definition.effect_parameters.get("boss_slow_fraction", 0.15)), 0.0),
		maxf(float(definition.effect_parameters.get("duration", 2.0)), 0.0)
	)


func cleanup() -> void:
	if is_instance_valid(weapon) and weapon.projectile_hit.is_connected(_on_projectile_hit):
		weapon.projectile_hit.disconnect(_on_projectile_hit)
	queue_free()
