extends MagicArtifactEffect
const WEAPON_ARTIFACT_AURA := preload("res://Scripts/VFX/WeaponArtifactAura.gd")
var _aura: Node2D

## Supplies the number of initial penetrations to this weapon only.
var weapon: WeaponModule

func configure_weapon(target_weapon: WeaponModule) -> void:
	weapon = target_weapon

func _ready() -> void:
	if is_instance_valid(weapon):
		weapon.artifact_projectile_pierces = _get_pierces
		# Presentation: particles under the equipped module.
		_aura = WEAPON_ARTIFACT_AURA.new()
		_aura.set("kind", definition.artifact_id)
		weapon.add_child(_aura)
		weapon.move_child(_aura, 0)

func _get_pierces() -> int:
	return maxi(int(definition.effect_parameters.get("initial_pierces", 1)), 0)

func cleanup() -> void:
	if is_instance_valid(weapon) and weapon.artifact_projectile_pierces == Callable(self, "_get_pierces"):
		weapon.artifact_projectile_pierces = Callable()
	if is_instance_valid(_aura):
		_aura.queue_free()
	queue_free()
