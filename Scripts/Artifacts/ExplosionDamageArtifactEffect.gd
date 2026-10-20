extends MagicArtifactEffect

## Reusable, instance-local modifier for explosive module damage.
var module: ShipModule


func configure_module(target_module: ShipModule) -> void:
	module = target_module


func _ready() -> void:
	if is_instance_valid(module):
		module.artifact_explosion_damage_bonus = _get_bonus


func _get_bonus() -> float:
	return maxf(float(definition.effect_parameters.get("explosion_damage_bonus", 0.0)), 0.0)


func cleanup() -> void:
	if is_instance_valid(module) and module.artifact_explosion_damage_bonus == Callable(self, "_get_bonus"):
		module.artifact_explosion_damage_bonus = Callable()
	queue_free()
