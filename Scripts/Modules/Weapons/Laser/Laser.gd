class_name Laser
extends WeaponModule

## A continuous piercing beam weapon with no damage falloff.

const AIM_EPSILON_RADIANS: float = 0.001

## Damage applied to each intersected enemy per beam tick.
@export var basic_damage: float = 1.0

## Seconds between beam damage ticks.
@export var attack_interval: float = 0.1

## Maximum beam and targeting distance in pixels.
@export var attack_range: float = 1000.0

## Maximum turret rotation speed in degrees per second.
@export var rotation_speed: float = 120.0

## Effective aiming tolerance. Zero uses a tiny internal epsilon.
@export var aim_tolerance: float = 0.0

## Width of the visible and damaging beam in pixels.
@export var beam_width: float = 6.0

## Number of beams emitted by this weapon.
@export_range(1, 1, 1) var projectile_count: int = 1

@onready var _turret: Node2D = $Turret
@onready var _muzzle: Marker2D = $Turret/Muzzle
@onready var _beam: Line2D = $Turret/Muzzle/Beam

## The enemy locked by the laser until it dies or leaves range.
var current_target: BasicEnemy = null
var _damage_cooldown: float = 0.0


func get_damage() -> float:
	return basic_damage


func get_fire_rate() -> float:
	if attack_interval <= 0.0:
		return 0.0

	return 1.0 / attack_interval


func _ready() -> void:
	_beam.width = beam_width
	_beam.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2(attack_range, 0.0)
	])
	_beam.hide()
	print("Laser targeting system initialized.")


func _physics_process(delta: float) -> void:
	if assembly_mode:
		_deactivate_beam()
		return

	current_target = keep_or_find_target(
		current_target,
		_muzzle.global_position,
		attack_range
	)

	if not is_instance_valid(current_target):
		_deactivate_beam()
		return

	rotate_turret_toward(
		_turret,
		current_target.global_position,
		rotation_speed,
		delta
	)

	var allowed_error := maxf(
		deg_to_rad(aim_tolerance),
		AIM_EPSILON_RADIANS
	)

	if get_aim_error(
		_turret,
		current_target.global_position
	) > allowed_error:
		_deactivate_beam()
		return

	_beam.show()

	if attack_interval <= 0.0:
		return

	_damage_cooldown -= delta
	while _damage_cooldown <= 0.0:
		fire()
		_damage_cooldown += attack_interval


## Applies one damage tick to every enemy intersecting the full beam shape.
func fire() -> void:
	var beam_shape := RectangleShape2D.new()
	beam_shape.size = Vector2(attack_range, beam_width)

	var beam_direction := Vector2.RIGHT.rotated(_muzzle.global_rotation)
	var beam_center := (
		_muzzle.global_position
		+ beam_direction * attack_range * 0.5
	)

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = beam_shape
	query.transform = Transform2D(_muzzle.global_rotation, beam_center)
	query.collision_mask = 1
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var results := get_world_2d().direct_space_state.intersect_shape(query, 256)
	var damaged_enemy_ids: Dictionary = {}

	for result in results:
		var collider: Object = result.get("collider")
		if not collider is BasicEnemy:
			continue

		var enemy := collider as BasicEnemy
		if not enemy.is_in_group("enemies"):
			continue

		var enemy_id := enemy.get_instance_id()
		if damaged_enemy_ids.has(enemy_id):
			continue

		damaged_enemy_ids[enemy_id] = true
		enemy.take_damage(basic_damage)


## Hides the beam and prevents stored cooldown from causing delayed damage.
func _deactivate_beam() -> void:
	current_target = null
	_damage_cooldown = 0.0
	_beam.hide()
