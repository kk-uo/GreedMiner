extends MagicArtifactEffect

## Per-equipped-turret volley counter. Only physical projectile volleys emit
## this event, so missed shots count but beams and persistent damage do not.
const ARM_SCENE := preload("res://Scenes/Modules/Weapons/Artifacts/zombie_arm_projectile.tscn")

var weapon: WeaponModule
var attack_count: int = 0


func configure_weapon(target_weapon: WeaponModule) -> void:
	weapon = target_weapon


func _ready() -> void:
	if is_instance_valid(weapon):
		weapon.projectile_volley_fired.connect(_on_volley_fired)


func _on_volley_fired(origin: Vector2, direction: Vector2, speed: float, maximum_distance: float) -> void:
	attack_count += 1
	var interval := maxi(int(definition.effect_parameters.get("attacks_per_arm", 3)), 1)
	if attack_count % interval != 0 or not is_instance_valid(weapon):
		return
	var battle := get_tree().current_scene
	if battle == null:
		return
	var arm := ARM_SCENE.instantiate() as ZombieArmProjectile
	arm.source_weapon = weapon
	arm.direction = direction.normalized()
	arm.speed = speed
	arm.damage = maxf(float(definition.effect_parameters.get("arm_damage", 50.0)), 0.0)
	arm.maximum_distance = maxf(maximum_distance, 1.0)
	battle.add_child(arm)
	arm.global_position = origin
	arm.arm_from_current_position()


func cleanup() -> void:
	if is_instance_valid(weapon) and weapon.projectile_volley_fired.is_connected(_on_volley_fired):
		weapon.projectile_volley_fired.disconnect(_on_volley_fired)
	attack_count = 0
	queue_free()


func _exit_tree() -> void:
	if is_instance_valid(weapon) and weapon.projectile_volley_fired.is_connected(_on_volley_fired):
		weapon.projectile_volley_fired.disconnect(_on_volley_fired)
