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

## Stable ID used by global research and magic-artifact compatibility.
@export var weapon_type_id: StringName

## Group scans are staggered; a valid locked target is still tracked each frame.
@export_range(0.0, 1.0, 0.01) var target_search_interval: float = 0.2
const TARGET_SEARCH_SCHEDULE := preload("res://Scripts/Modules/Weapons/TargetSearchSchedule.gd")
var _target_search_schedule := TARGET_SEARCH_SCHEDULE.new()

var damage: float:
	get:
		return get_damage()

## Multiple equipped artifacts may contribute to the same stat. Provider lists
## prevent one artifact from overwriting another when all three slots are used.
var artifact_fire_rate_bonuses: Array[Callable] = []
var artifact_range_bonuses: Array[Callable] = []
var artifact_projectile_pierce_bonuses: Array[Callable] = []
var fire_rate: float:
	get:
		return get_fire_rate()


func get_module_category() -> StringName:
	return CATEGORY_WEAPON


func get_chip_module_kind() -> StringName:
	return &"weapon"


func get_power_consumption() -> int:
	return maxi(power_consumption, 0)


## Applies permanent research to an untouched base damage value. Artifact
## behavior is supplied by independent runtime effect nodes.
func get_modified_damage(base_damage: float) -> float:
	var modifiers: Array[StatModifier] = ResearchManager.get_weapon_stat_modifiers(
		weapon_type_id,
		&"damage"
	)
	return StatModifierPipeline.calculate(&"damage", base_damage, modifiers)


## Applies equipped artifact attack-frequency modifiers.
func get_modified_fire_rate(base_fire_rate: float) -> float:
	var modifiers: Array[StatModifier] = []
	var provider_index := 0
	for provider in artifact_fire_rate_bonuses.duplicate():
		if not provider.is_valid():
			artifact_fire_rate_bonuses.erase(provider)
			continue
		var modifier := StatModifier.new()
		# Each equipped artifact is an independent source. Reusing one source ID
		# would make StatModifierPipeline intentionally replace the earlier slot.
		modifier.source_id = StringName("equipped_magic_artifact_%d" % provider_index)
		modifier.stat_id = &"fire_rate"
		modifier.base_additive_ratio = maxf(float(provider.call()), 0.0)
		modifiers.append(modifier)
		provider_index += 1
	return maxf(StatModifierPipeline.calculate(&"fire_rate", base_fire_rate, modifiers), 0.0)


## Applies equipped artifact range modifiers without mutating the base range.
func get_modified_attack_range(base_range: float) -> float:
	var modifiers: Array[StatModifier] = []
	var provider_index := 0
	for provider in artifact_range_bonuses.duplicate():
		if not provider.is_valid():
			artifact_range_bonuses.erase(provider)
			continue
		var modifier := StatModifier.new()
		modifier.source_id = StringName("equipped_magic_artifact_range_%d" % provider_index)
		modifier.stat_id = &"attack_range"
		modifier.base_additive_ratio = maxf(float(provider.call()), 0.0)
		modifiers.append(modifier)
		provider_index += 1
	return maxf(StatModifierPipeline.calculate(&"attack_range", base_range, modifiers), 0.0)


## Reserved interface for future artifact-based active skills.
func get_modified_skill_cast_time(base_cast_time: float) -> float:
	return maxf(base_cast_time, 0.0)


func add_artifact_fire_rate_bonus(provider: Callable) -> void:
	if provider.is_valid() and not artifact_fire_rate_bonuses.has(provider):
		artifact_fire_rate_bonuses.append(provider)


func remove_artifact_fire_rate_bonus(provider: Callable) -> void:
	artifact_fire_rate_bonuses.erase(provider)


func add_artifact_range_bonus(provider: Callable) -> void:
	if provider.is_valid() and not artifact_range_bonuses.has(provider):
		artifact_range_bonuses.append(provider)


func remove_artifact_range_bonus(provider: Callable) -> void:
	artifact_range_bonuses.erase(provider)


func add_artifact_projectile_pierces(provider: Callable) -> void:
	if provider.is_valid() and not artifact_projectile_pierce_bonuses.has(provider):
		artifact_projectile_pierce_bonuses.append(provider)


func remove_artifact_projectile_pierces(provider: Callable) -> void:
	artifact_projectile_pierce_bonuses.erase(provider)


func get_artifact_projectile_pierces() -> int:
	var total := 0
	for provider in artifact_projectile_pierce_bonuses.duplicate():
		if provider.is_valid():
			total += maxi(int(provider.call()), 0)
		else:
			artifact_projectile_pierce_bonuses.erase(provider)
	return total


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
	maximum_range: float,
	delta: float = -1.0
) -> BasicEnemy:
	# Explicit three-argument queries remain immediate for tools and tests.
	var search_due := delta < 0.0 or _target_search_schedule.is_due(delta, target_search_interval)
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

	if search_due:
		return find_nearest_enemy_in_range(world_origin, maximum_range)
	return null


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
