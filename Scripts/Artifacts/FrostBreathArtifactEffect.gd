extends MagicArtifactEffect

## Keeps a 50% movement slow on only this turret's current locked target.
## Switching, losing a target, unequipping, or ending battle releases the
## previous target immediately.
var weapon: WeaponModule
var _slowed_target: BasicEnemy


func configure_weapon(target_weapon: WeaponModule) -> void:
	weapon = target_weapon


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(weapon):
		_release_target()
		return
	# A weapon may still hold a reference to an enemy queued/freed this frame.
	# Validate the Variant before casting it; casting a freed Object throws.
	var target_value: Variant = weapon.get("current_target")
	var candidate: BasicEnemy = target_value as BasicEnemy if is_instance_valid(target_value) else null
	if is_instance_valid(candidate) and candidate.is_dying():
		candidate = null
	if candidate == _slowed_target:
		return
	_release_target()
	if is_instance_valid(candidate) and candidate.apply_artifact_target_slow(
		get_instance_id(),
		float(definition.effect_parameters.get("slow_fraction", 0.5))
	):
		_slowed_target = candidate


func _release_target() -> void:
	if is_instance_valid(_slowed_target):
		_slowed_target.remove_artifact_target_slow(get_instance_id())
	_slowed_target = null


func cleanup() -> void:
	_release_target()
	queue_free()


func _exit_tree() -> void:
	_release_target()
