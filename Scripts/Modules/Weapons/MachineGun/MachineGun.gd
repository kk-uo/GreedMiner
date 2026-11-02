class_name MachineGun
extends WeaponModule

## Represents an automatic machine gun module.
##
## The machine gun searches for nearby enemies,
## rotates its turret toward the nearest target,
## and fires projectiles when properly aligned.


# ==========================================
# Weapon Statistics
# ==========================================

## Damage dealt by each projectile.
@export var basic_damage: float = 5.0

## Seconds between shots. A value of 0.2 gives 5 attacks per second.
@export var attack_interval: float = 0.2

## Maximum targeting distance in pixels.
@export var attack_range: float = 200.0

## Bullet visual and collision radius in pixels. This does not affect travel.
@export var projectile_range: float = 4.0

## Maximum rotation speed in degrees per second.
@export var rotation_speed: float = 360.0

## Maximum aiming error allowed before firing.
@export var aim_tolerance: float = 12.0

## Projectile movement speed in pixels per second.
@export var projectile_speed: float = 450.0

## Number of projectiles created by each attack.
@export_range(1, 1, 1) var projectile_count: int = 1


# ==========================================
# Projectile Configuration
# ==========================================

## Projectile scene assigned through the Inspector.
@export var projectile_scene: PackedScene


# ==========================================
# Node References
# ==========================================

## Rotating turret body.
@onready var _turret: Node2D = $Turret

## Projectile spawn point.
@onready var _muzzle: Marker2D = $Turret/Muzzle
@onready var _sound: WeaponSound = $Sound


# ==========================================
# Targeting State
# ==========================================

## The enemy locked by the machine gun until it dies or leaves range.
var current_target: BasicEnemy = null

## Remaining time before the next shot.
var _fire_timer: float = 0.0


# ==========================================
# WeaponModule Properties
# ==========================================

func get_damage() -> float:
	return get_modified_damage(basic_damage)


func get_fire_rate() -> float:
	if attack_interval <= 0.0:
		return 0.0
	return get_modified_fire_rate(1.0 / attack_interval)


# ==========================================
# Initialization
# ==========================================

func _ready() -> void:
	print("MachineGun targeting system initialized.")


# ==========================================
# Target Detection
# ==========================================

## Finds the nearest enemy inside the attack range.
func find_nearest_enemy() -> BasicEnemy:
	return find_nearest_enemy_in_range(global_position, get_modified_attack_range(attack_range))


# ==========================================
# Turret Rotation
# ==========================================

## Smoothly rotates the turret toward the selected enemy.
func rotate_toward_target(delta: float) -> void:
	if not is_instance_valid(current_target):
		return

	rotate_turret_toward(
		_turret,
		current_target.get_target_point(global_position),
		rotation_speed,
		delta
	)


# ==========================================
# Aiming Validation
# ==========================================

## Checks whether the turret is aimed accurately enough.
func is_aimed_at_target() -> bool:
	if not is_instance_valid(current_target):
		return false

	# Allow firing only when sufficiently aligned.
	return get_aim_error(
		_turret,
		current_target.get_target_point(global_position)
	) <= deg_to_rad(aim_tolerance)


# ==========================================
# Automatic Targeting and Firing
# ==========================================

func _process(delta: float) -> void:
	# BaseMain is an assembly environment, so weapons remain visual only.
	if assembly_mode:
		current_target = null
		_fire_timer = 0.0
		return

	if is_manual_control_active():
		current_target = null
		_process_manual_control(delta)
		return

	# Keep firing at the current enemy before selecting the next nearest one.
	current_target = keep_or_find_target(
		current_target,
		global_position,
		get_modified_attack_range(attack_range),
		delta
	)

	# Stop attacking when no enemy is in range.
	if not is_instance_valid(current_target):
		_fire_timer = 0.0
		return

	# Continuously track the moving enemy.
	rotate_toward_target(delta)

	# Validate the weapon's firing rate.
	var effective_fire_rate := get_fire_rate()
	if effective_fire_rate <= 0.0:
		return

	# Count down the firing timer.
	_fire_timer = maxf(_fire_timer - delta, 0.0)

	# Do not fire while the turret is still turning.
	if not is_aimed_at_target():
		return

	# Fire when the weapon is ready and properly aimed.
	if _fire_timer <= 0.0:
		fire()
		_fire_timer = 1.0 / effective_fire_rate


func _process_manual_control(delta: float) -> void:
	var aim_position := get_manual_aim_world_position()
	if not has_valid_manual_aim(_turret.global_position):
		_fire_timer = 0.0
		return
	rotate_turret_toward(_turret, aim_position, rotation_speed, delta)
	var effective_fire_rate := get_fire_rate()
	if effective_fire_rate <= 0.0:
		return
	_fire_timer = maxf(_fire_timer - delta, 0.0)
	if get_aim_error(_turret, aim_position) > deg_to_rad(aim_tolerance):
		return
	if _fire_timer <= 0.0:
		fire()
		_fire_timer = 1.0 / effective_fire_rate


# ==========================================
# Projectile Firing
# ==========================================

func fire() -> void:
	# Verify that a projectile scene is assigned.
	if projectile_scene == null:
		push_error("MachineGun: Projectile scene is missing!")
		return
	begin_artifact_attack()

	var volley_count := maxi(projectile_count + get_artifact_projectile_count_bonus(), 1)
	var base_direction := Vector2.RIGHT.rotated(_muzzle.global_rotation)
	var artifact_pierces := get_artifact_projectile_pierces()
	var is_ghost_projectile := has_artifact_ghost_projectile()
	for index in range(volley_count):
		var projectile := projectile_scene.instantiate() as MachineGunProjectile
		if projectile == null:
			push_error("MachineGun: Invalid projectile scene!")
			end_artifact_attack()
			return
		# World-space children do not inherit the turret's rotation.
		get_tree().current_scene.add_child(projectile)
		var lateral_spacing := get_volley_lateral_spacing(get_modified_projectile_range(projectile_range))
		var lateral_weight := float(index) - float(volley_count - 1) * 0.5
		projectile.global_position = _muzzle.global_position + base_direction.orthogonal() * lateral_spacing * lateral_weight
		projectile.direction = get_projectile_volley_direction(base_direction, index, volley_count)
		projectile.damage = damage
		projectile.source_weapon = self
		if artifact_pierces > 0:
			projectile.enable_ghost_piercing(artifact_pierces, is_ghost_projectile, is_ghost_projectile)
		projectile.speed = get_modified_projectile_speed(projectile_speed)
		projectile.projectile_range = get_modified_projectile_range(projectile_range)
		projectile_spawned.emit(projectile)
	projectile_volley_fired.emit(_muzzle.global_position, base_direction, get_modified_projectile_speed(projectile_speed), get_modified_attack_range(attack_range))
	_sound.play_shot()
	end_artifact_attack()
