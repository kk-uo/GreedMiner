class_name WeaponModule
extends Node2D

## Base class for weapon modules installed on the ship.
##
## Derived weapon modules provide their own damage, attack timing,
## and firing behavior through these overridable methods.

## Keeps the weapon visible while disabling combat behavior in BaseMain.
@export var assembly_mode: bool = false

var damage: float:
	get:
		return get_damage()

var fire_rate: float:
	get:
		return get_fire_rate()


## Returns the damage dealt by one attack.
func get_damage() -> float:
	push_error("WeaponModule.get_damage() must be overridden.")
	return 0.0


## Returns the number of attacks fired per second.
func get_fire_rate() -> float:
	push_error("WeaponModule.get_fire_rate() must be overridden.")
	return 0.0


## Performs one weapon attack.
func fire() -> void:
	push_error("WeaponModule.fire() must be overridden.")


## Finds the nearest valid enemy to a world-space origin.
func find_nearest_enemy_in_range(
	world_origin: Vector2,
	maximum_range: float
) -> BasicEnemy:
	var nearest_enemy: BasicEnemy = null
	var nearest_distance: float = maximum_range

	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is BasicEnemy:
			continue

		var enemy := node as BasicEnemy
		if enemy.is_dying():
			continue

		var distance := world_origin.distance_to(enemy.global_position)

		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy

	return nearest_enemy


## Keeps a living target locked until it dies or leaves the weapon's range.
## Only then does the turret acquire the nearest currently valid enemy.
func keep_or_find_target(
	current_target: Variant,
	world_origin: Vector2,
	maximum_range: float
) -> BasicEnemy:
	# A typed enemy variable can temporarily contain a previously freed object.
	# Accept the reference as Variant so validity is checked before conversion.
	if is_instance_valid(current_target) and current_target is BasicEnemy:
		var enemy := current_target as BasicEnemy
		if (
			enemy.is_in_group("enemies")
			and not enemy.is_dying()
			and world_origin.distance_to(enemy.global_position)
				<= maximum_range
		):
			return enemy

	return find_nearest_enemy_in_range(world_origin, maximum_range)


## Rotates a turret toward a world-space point at a limited angular speed.
func rotate_turret_toward(
	turret: Node2D,
	world_target: Vector2,
	rotation_speed_degrees: float,
	delta: float
) -> void:
	var target_angle := turret.global_position.direction_to(world_target).angle()
	var maximum_rotation := deg_to_rad(rotation_speed_degrees) * delta
	turret.global_rotation = rotate_toward(
		turret.global_rotation,
		target_angle,
		maximum_rotation
	)


## Returns the absolute aiming error between a turret and a world-space point.
func get_aim_error(turret: Node2D, world_target: Vector2) -> float:
	var target_angle := turret.global_position.direction_to(world_target).angle()
	return abs(angle_difference(turret.global_rotation, target_angle))
