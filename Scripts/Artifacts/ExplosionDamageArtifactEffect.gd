extends MagicArtifactEffect
const WEAPON_ARTIFACT_AURA := preload("res://Scripts/VFX/WeaponArtifactAura.gd")
var _aura: Node2D

## Reusable, instance-local modifier for explosive module damage.
var module: ShipModule


func configure_module(target_module: ShipModule) -> void:
	module = target_module


func _ready() -> void:
	if is_instance_valid(module):
		module.add_artifact_explosion_damage_bonus(Callable(self, "_get_bonus"))
		# Presentation: particles under the equipped module.
		_aura = WEAPON_ARTIFACT_AURA.new()
		_aura.set("kind", definition.artifact_id)
		module.add_child(_aura)
		module.move_child(_aura, 0)


func _get_bonus() -> float:
	return maxf(float(definition.effect_parameters.get("explosion_damage_bonus", 0.0)), 0.0)


func cleanup() -> void:
	if is_instance_valid(module):
		module.remove_artifact_explosion_damage_bonus(Callable(self, "_get_bonus"))
	if is_instance_valid(_aura):
		_aura.queue_free()
	queue_free()
