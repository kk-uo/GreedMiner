class_name DwarfCannon
extends WeaponModule

## A slow, precise cannon that launches circular AOE projectiles.

## Damage applied to every enemy caught by one explosion.
@export var basic_damage: float = 30.0

## Seconds between cannon shots.
@export var attack_interval: float = 2.0

## Maximum targeting distance in pixels.
@export var attack_range: float = 200.0

## Cannonball movement speed in pixels per second.
@export var projectile_speed: float = 800.0

## Radius of the no-falloff explosion.
@export var aoe_radius: float = 20.0

## Maximum turret rotation speed in degrees per second.
@export var rotation_speed: float = 200.0

## Maximum aiming error allowed before firing.
@export var aim_tolerance: float = 3.0

## Number of projectiles created by each attack.
@export_range(1, 1, 1) var projectile_count: int = 1

## Cannonball scene assigned through the Inspector.
@export var projectile_scene: PackedScene

@onready var _turret: Node2D = $Turret
@onready var _muzzle: Marker2D = $Turret/Muzzle

## The enemy locked by the cannon until it dies or leaves range.
var current_target: BasicEnemy = null
var _attack_cooldown: float = 0.0


func get_damage() -> float:
	return basic_damage


func get_fire_rate() -> float:
	if attack_interval <= 0.0:
		return 0.0

	return 1.0 / attack_interval


func _ready() -> void:
	print("DwarfCannon targeting system initialized.")


func _process(delta: float) -> void:
	if assembly_mode:
		current_target = null
		_attack_cooldown = 0.0
		return

	current_target = keep_or_find_target(
		current_target,
		global_position,
		attack_range
	)

	if not is_instance_valid(current_target):
		_attack_cooldown = 0.0
		return

	rotate_turret_toward(
		_turret,
		current_target.global_position,
		rotation_speed,
		delta
	)

	if attack_interval <= 0.0:
		return

	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)

	if get_aim_error(
		_turret,
		current_target.global_position
	) > deg_to_rad(aim_tolerance):
		return

	if _attack_cooldown <= 0.0:
		fire()
		_attack_cooldown = attack_interval


## Launches one physical cannonball along the turret's current direction.
func fire() -> void:
	if projectile_scene == null:
		push_error("DwarfCannon: Projectile scene is missing!")
		return

	var projectile := projectile_scene.instantiate() as DwarfCannonProjectile

	if projectile == null:
		push_error("DwarfCannon: Invalid projectile scene!")
		return

	get_tree().current_scene.add_child(projectile)
	projectile.global_position = _muzzle.global_position
	projectile.direction = Vector2.RIGHT.rotated(_muzzle.global_rotation)
	projectile.speed = projectile_speed
	projectile.damage = basic_damage
	projectile.explosion_radius = aoe_radius
