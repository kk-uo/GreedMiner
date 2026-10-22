extends MagicArtifactEffect

## Provides an instance-local fire-rate modifier from artifact configuration.
var weapon: WeaponModule
## Presentation: particles under the equipped weapon.
const WeaponArtifactAura := preload("res://Scripts/VFX/WeaponArtifactAura.gd")
var _aura: Node2D


func configure_weapon(target_weapon: WeaponModule) -> void:
	weapon = target_weapon


func _ready() -> void:
	if is_instance_valid(weapon):
		weapon.add_artifact_fire_rate_bonus(Callable(self, "_get_fire_rate_bonus"))
		_aura = WeaponArtifactAura.new()
		_aura.set("kind", definition.artifact_id)
		_aura.set("bonus", _get_fire_rate_bonus)
		weapon.add_child(_aura)
		weapon.move_child(_aura, 0)


func _get_fire_rate_bonus() -> float:
	var parameters := definition.effect_parameters
	var bonus := maxf(float(parameters.get("base_bonus", 0.0)), 0.0)
	var threshold := float(parameters.get("activity_per_stack", 0.0))
	if threshold > 0.0:
		bonus += floorf(ArtifactManager.get_weapon_battle_activity(weapon) / threshold) * maxf(float(parameters.get("bonus_per_stack", 0.0)), 0.0)
	return bonus


func cleanup() -> void:
	if is_instance_valid(weapon):
		weapon.remove_artifact_fire_rate_bonus(Callable(self, "_get_fire_rate_bonus"))
	if is_instance_valid(_aura):
		_aura.queue_free()
	queue_free()
