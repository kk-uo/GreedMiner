class_name WeaponModule
extends ShipModule

## Emitted only for a direct projectile impact, never for splash or beams.
signal projectile_hit(enemy: BasicEnemy, actual_damage: float)

## Base class for weapon modules installed on the ship.
##
## Derived weapon modules provide their own damage, attack timing,
## and firing behavior through these overridable methods.

## Keeps the weapon visible while disabling combat behavior in BaseMain.
@export var assembly_mode: bool = false

## Continuous power required by this weapon instance.
## Future weapon scenes can override this value independently.
@export var power_consumption: int = 1

## Stable ID used by global research and future chip effect providers.
@export var weapon_type_id: StringName

var damage: float:
	get:
		return get_damage()

## A battle artifact can provide an instance-local additive fire-rate ratio.
var artifact_fire_rate_bonus: Callable
var fire_rate: float:
	get:
		return get_fire_rate()


func get_module_category() -> StringName:
	return CATEGORY_WEAPON


func get_chip_module_kind() -> StringName:
	return &"weapon"


func get_power_consumption() -> int:
	return maxi(power_consumption, 0)


## Applies permanent research and configured chip modifiers to an untouched
## base damage value. Effective values never mutate the exported base stats.
func get_modified_damage(base_damage: float) -> float:
	var modifiers: Array[StatModifier] = ResearchManager.get_weapon_stat_modifiers(
		weapon_type_id,
		&"damage"
	)
	modifiers.append_array(ChipManager.get_stat_modifiers({
		"stat_id": &"damage",
		"weapon_type_id": weapon_type_id,
		"weapon_instance": self,
		"module_kind": get_chip_module_kind(),
	}))
	return StatModifierPipeline.calculate(&"damage", base_damage, modifiers)


## Applies chip attack-frequency modifiers without changing stored intervals.
func get_modified_fire_rate(base_fire_rate: float) -> float:
	var modifiers := ChipManager.get_stat_modifiers({
		"stat_id": &"fire_rate",
		"weapon_type_id": weapon_type_id,
		"weapon_instance": self,
		"module_kind": get_chip_module_kind(),
	})
	if artifact_fire_rate_bonus.is_valid():
		var modifier := StatModifier.new()
		modifier.source_id = &"equipped_magic_artifact"
		modifier.stat_id = &"fire_rate"
		modifier.base_additive_ratio = maxf(float(artifact_fire_rate_bonus.call()), 0.0)
		modifiers.append(modifier)
	return maxf(StatModifierPipeline.calculate(&"fire_rate", base_fire_rate, modifiers), 0.0)


## Applies a universal Range Chip without changing the exported base range.
func get_modified_attack_range(base_range: float) -> float:
	var modifiers := ChipManager.get_stat_modifiers({
		"stat_id": &"attack_range",
		"weapon_type_id": weapon_type_id,
		"weapon_instance": self,
		"module_kind": get_chip_module_kind(),
	})
	return maxf(StatModifierPipeline.calculate(&"attack_range", base_range, modifiers), 0.0)


## Interface for future active skills. Skill chips reduce cast time but never
## cooldown, and the result is clamped so a cast cannot become negative.
func get_modified_skill_cast_time(base_cast_time: float) -> float:
	var modifiers := ChipManager.get_stat_modifiers({
		"stat_id": &"skill_cast_time",
		"weapon_type_id": weapon_type_id,
		"weapon_instance": self,
		"module_kind": get_chip_module_kind(),
		"supports_active_skill": supports_active_skill(),
	})
	return maxf(StatModifierPipeline.calculate(&"skill_cast_time", base_cast_time, modifiers), 0.0)


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

		var distance := world_origin.distance_to(enemy.get_target_point(world_origin))

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
			and world_origin.distance_to(enemy.get_target_point(world_origin))
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
