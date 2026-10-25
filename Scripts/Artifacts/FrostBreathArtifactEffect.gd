extends MagicArtifactEffect

## Keeps only this turret's current lock frozen. Switching, losing a target,
## unequipping, or ending battle releases the previous target immediately.
var weapon: WeaponModule
var _frozen_target: BasicEnemy


func configure_weapon(target_weapon: WeaponModule) -> void:
	weapon = target_weapon


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(weapon):
		_release_target()
		return
	var candidate := weapon.get("current_target") as BasicEnemy
	if is_instance_valid(candidate) and candidate.is_dying():
		candidate = null
	if candidate == _frozen_target:
		return
	_release_target()
	if is_instance_valid(candidate) and candidate.apply_artifact_freeze(
		get_instance_id(),
		bool(definition.effect_parameters.get("affects_bosses", false))
	):
		_frozen_target = candidate


func _release_target() -> void:
	if is_instance_valid(_frozen_target):
		_frozen_target.remove_artifact_freeze(get_instance_id())
	_frozen_target = null


func cleanup() -> void:
	_release_target()
	queue_free()


func _exit_tree() -> void:
	_release_target()
