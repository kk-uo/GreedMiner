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
	return get_modified_damage(basic_damage)


func get_fire_rate() -> float:
	if attack_interval <= 0.0:
		return 0.0
	return get_modified_fire_rate(1.0 / attack_interval)


## Range bonuses (Range Chip, Demon Prism) also widen the beam, both visually
## and for hits, at BEAM_WIDTH_RANGE_FACTOR times the range bonus
## (+35% range -> +350% width).
const BEAM_WIDTH_RANGE_FACTOR: float = 10.0


func get_effective_beam_width() -> float:
	if attack_range <= 0.0:
		return beam_width
	var range_bonus := get_modified_attack_range(attack_range) / attack_range - 1.0
	return beam_width * maxf(1.0 + range_bonus * BEAM_WIDTH_RANGE_FACTOR, 0.1)


func _ready() -> void:
	_beam.width = beam_width
	_update_beam_length()
	_beam.hide()
	print("Laser targeting system initialized.")


func _physics_process(delta: float) -> void:
	if assembly_mode:
		_deactivate_beam()
		return

	_update_beam_length()
	current_target = keep_or_find_target(
		current_target,
		_muzzle.global_position,
		get_modified_attack_range(attack_range)
	)

	if not is_instance_valid(current_target):
		_deactivate_beam()
		return

	rotate_turret_toward(
		_turret,
		current_target.get_target_point(global_position),
		rotation_speed,
		delta
	)

	var allowed_error := maxf(
		deg_to_rad(aim_tolerance),
		AIM_EPSILON_RADIANS
	)

	if get_aim_error(
		_turret,
		current_target.get_target_point(global_position)
	) > allowed_error:
		_deactivate_beam()
		return

	_beam.show()

	var effective_fire_rate := get_fire_rate()
	if effective_fire_rate <= 0.0:
		return
	var effective_interval := 1.0 / effective_fire_rate

	_damage_cooldown -= delta
	while _damage_cooldown <= 0.0:
		fire()
		_damage_cooldown += effective_interval


## Applies one damage tick to every enemy intersecting the full beam shape.
func fire() -> void:
	var effective_range := get_modified_attack_range(attack_range)
	var beam_shape := RectangleShape2D.new()
	beam_shape.size = Vector2(effective_range, get_effective_beam_width())

	var beam_direction := Vector2.RIGHT.rotated(_muzzle.global_rotation)
	var beam_center := (
		_muzzle.global_position
		+ beam_direction * effective_range * 0.5
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
		# Trees standing in the beam get burned too.
		if collider is Node and (collider as Node).is_in_group(&"destructible_props"):
			if not damaged_enemy_ids.has(collider.get_instance_id()):
				damaged_enemy_ids[collider.get_instance_id()] = true
				collider.call("take_damage", get_damage())
			continue
		if not collider is BasicEnemy:
			continue

		var enemy := collider as BasicEnemy
		if not enemy.is_in_group("enemies"):
			continue

		var enemy_id := enemy.get_instance_id()
		if damaged_enemy_ids.has(enemy_id):
			continue

		damaged_enemy_ids[enemy_id] = true
		enemy.take_damage(get_damage(), false, true, self)


func _update_beam_length() -> void:
	_beam.width = get_effective_beam_width()
	_beam.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2(get_modified_attack_range(attack_range), 0.0),
	])


## Hides the beam and prevents stored cooldown from causing delayed damage.
func _deactivate_beam() -> void:
	current_target = null
	_damage_cooldown = 0.0
	_beam.hide()
