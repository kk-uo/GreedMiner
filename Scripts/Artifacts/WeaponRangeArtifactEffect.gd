extends MagicArtifactEffect

## Provides an instance-local attack-range modifier from artifact configuration
## (effect_parameters.range_bonus, e.g. 1.0 = +100% of the base range).
const WeaponArtifactAura := preload("res://Scripts/VFX/WeaponArtifactAura.gd")
var weapon: WeaponModule
var _aura: Node2D


func configure_weapon(target_weapon: WeaponModule) -> void:
	weapon = target_weapon


func _ready() -> void:
	if is_instance_valid(weapon):
		weapon.add_artifact_range_bonus(Callable(self, "_get_range_bonus"))
		_aura = WeaponArtifactAura.new()
		_aura.set("kind", definition.artifact_id)
		weapon.add_child(_aura)
		weapon.move_child(_aura, 0)


func _get_range_bonus() -> float:
	return maxf(float(definition.effect_parameters.get("range_bonus", 0.0)), 0.0)


func cleanup() -> void:
	if is_instance_valid(weapon):
		weapon.remove_artifact_range_bonus(Callable(self, "_get_range_bonus"))
	if is_instance_valid(_aura):
		_aura.queue_free()
	queue_free()
