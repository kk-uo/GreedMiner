
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
const DAMAGE: float = 5.0

## Number of projectiles fired per second.
const FIRE_RATE: float = 10.0

## Maximum targeting distance in pixels.
@export var attack_range: float = 200.0

## Maximum rotation speed in degrees per second.
@export var rotation_speed: float = 360.0

## Maximum aiming error allowed before firing.
@export var aim_tolerance: float = 5.0

## Keeps the module visible but disables targeting and firing in BaseMain.
@export var assembly_mode: bool = false


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


# ==========================================
# Targeting State
# ==========================================

## The enemy currently selected by the machine gun.
var current_target: BasicEnemy = null

## Remaining time before the next shot.
var _fire_timer: float = 0.0


# ==========================================
# WeaponModule Properties
# ==========================================

func get_damage() -> float:
	return DAMAGE


func get_fire_rate() -> float:
	return FIRE_RATE


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
	var nearest_enemy: BasicEnemy = null
	var nearest_distance: float = attack_range

	# Search every enemy registered in the enemies group.
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is BasicEnemy:
			continue

		var enemy: BasicEnemy = node as BasicEnemy

		# Measure distance from the weapon to the enemy.
		var distance: float = global_position.distance_to(
			enemy.global_position
		)

		# Select the closest enemy inside the attack range.
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy

	return nearest_enemy


# ==========================================
# Turret Rotation
# ==========================================

## Smoothly rotates the turret toward the selected enemy.
func rotate_toward_target(delta: float) -> void:
	if not is_instance_valid(current_target):
		return

	# Calculate the direction from turret to enemy.
	var direction: Vector2 = (
		current_target.global_position - _turret.global_position
	)

	# Convert the direction vector into an angle.
	var target_angle: float = direction.angle()

	# Convert rotation speed to radians per second.
	var max_rotation: float = deg_to_rad(rotation_speed) * delta

	# Rotate toward the target without instantly snapping.
	_turret.global_rotation = rotate_toward(
		_turret.global_rotation,
		target_angle,
		max_rotation
	)


# ==========================================
# Aiming Validation
# ==========================================

## Checks whether the turret is aimed accurately enough.
func is_aimed_at_target() -> bool:
	if not is_instance_valid(current_target):
		return false

	# Calculate the desired firing direction.
	var direction: Vector2 = (
		current_target.global_position - _turret.global_position
	)

	var target_angle: float = direction.angle()

	# Measure the shortest angular difference.
	var angle_difference: float = abs(
		angle_difference(_turret.global_rotation, target_angle)
	)

	# Allow firing only when sufficiently aligned.
	return angle_difference <= deg_to_rad(aim_tolerance)


# ==========================================
# Automatic Targeting and Firing
# ==========================================

func _process(delta: float) -> void:
	# BaseMain is an assembly environment, so weapons remain visual only.
	if assembly_mode:
		current_target = null
		_fire_timer = 0.0
		return

	# Find the nearest enemy every frame.
	current_target = find_nearest_enemy()

	# Stop attacking when no enemy is in range.
	if not is_instance_valid(current_target):
		_fire_timer = 0.0
		return

	# Continuously track the moving enemy.
	rotate_toward_target(delta)

	# Validate the weapon's firing rate.
	if fire_rate <= 0.0:
		return

	# Count down the firing timer.
	_fire_timer = maxf(_fire_timer - delta, 0.0)

	# Do not fire while the turret is still turning.
	if not is_aimed_at_target():
		return

	# Fire when the weapon is ready and properly aimed.
	if _fire_timer <= 0.0:
		fire()
		_fire_timer = 1.0 / fire_rate


# ==========================================
# Projectile Firing
# ==========================================

func fire() -> void:
	# Verify that a projectile scene is assigned.
	if projectile_scene == null:
		push_error("MachineGun: Projectile scene is missing!")
		return

	# Create a projectile instance.
	var projectile := projectile_scene.instantiate() as MachineGunProjectile

	if projectile == null:
		push_error("MachineGun: Invalid projectile scene!")
		return

	# Add the projectile to the main game scene.
	# This prevents bullets from rotating with the turret.
	get_tree().current_scene.add_child(projectile)

	# Spawn the projectile at the muzzle.
	projectile.global_position = _muzzle.global_position

	# Fire in the direction the muzzle is facing.
	projectile.direction = Vector2.RIGHT.rotated(
		_muzzle.global_rotation
	)

	# Apply the machine gun's damage.
	projectile.damage = damage
