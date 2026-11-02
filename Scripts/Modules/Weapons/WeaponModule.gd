class_name WeaponModule
extends ShipModule

## Emitted only for a direct projectile impact, never for splash or beams.
signal projectile_hit(enemy: BasicEnemy, actual_damage: float)
## One event per physical bullet volley; beams, saws and waves do not emit it.
signal projectile_volley_fired(origin: Vector2, direction: Vector2, speed: float, maximum_distance: float)
## Emitted for a kill credited to this weapon, including its projectile splash
## and persistent fire. Artifact damage intentionally cannot emit it again.
signal enemy_defeated(death_position: Vector2, defeated_max_health: float)
## Brackets one firing action (including every pellet or beam hit in a volley).
signal artifact_attack_started
signal artifact_attack_finished
## Presentation hook (Claude sync 97): every bullet/shell this weapon spawns.
signal projectile_spawned(projectile: Node2D)
## Actual health removed from an enemy by this weapon (any hit that names it
## as source: projectiles, beams, splash, fire, artifact echoes). BattleStats
## sums it for the result board's turret damage report. Presentation only.
signal damage_dealt(amount: float)

## Base class for weapon modules installed on the ship.
##
## Derived weapon modules provide their own damage, attack timing,
## and firing behavior through these overridable methods.

## Keeps the weapon visible while disabling combat behavior in BaseMain.
@export var assembly_mode: bool = false

## Weapons are either ground-only or able to attack both movement layers.
## There is intentionally no air-only mode.
enum EnemyTargeting {
	GROUND_ONLY,
	GROUND_AND_AIR,
}

@export var enemy_targeting: EnemyTargeting = EnemyTargeting.GROUND_AND_AIR

## Continuous power required by this weapon instance.
## Future weapon scenes can override this value independently.
@export var power_consumption: int = 1

## Stable ID used by global research and magic-artifact compatibility.
@export var weapon_type_id: StringName

## Group scans are staggered; a valid locked target is still tracked each frame.
@export_range(0.0, 1.0, 0.01) var target_search_interval: float = 0.2
## Set by boss smoke: no target lock, nearest enemy re-picked every scan.
var target_lock_suppressed: bool = false
const TARGET_SEARCH_SCHEDULE := preload("res://Scripts/Modules/Weapons/TargetSearchSchedule.gd")
var _target_search_schedule := TARGET_SEARCH_SCHEDULE.new()

var damage: float:
	get:
		return get_damage()

## Multiple equipped artifacts may contribute to the same stat. Provider lists
## prevent one artifact from overwriting another when all three slots are used.
var artifact_fire_rate_bonuses: Array[Callable] = []
var artifact_damage_multipliers: Array[Callable] = []
## Added after research and percentage multipliers, unlike base-damage bonuses.
var artifact_final_damage_bonuses: Array[Callable] = []
## Flat additions to the untouched weapon base; research scales this value.
var artifact_base_damage_bonuses: Array[Callable] = []
var artifact_range_bonuses: Array[Callable] = []
var artifact_flat_range_bonuses: Array[Callable] = []
var artifact_projectile_range_bonuses: Array[Callable] = []
## Laser size overrides use max(), so two artifacts never turn 10x into 20x.
var artifact_beam_width_multipliers: Array[Callable] = []
## Projectile travel speed, unrelated to projectile collision/model size.
var artifact_projectile_speed_multipliers: Array[Callable] = []
var artifact_projectile_pierce_bonuses: Array[Callable] = []
var artifact_ghost_projectile_providers: Array[Callable] = []
var artifact_projectile_count_bonuses: Array[Callable] = []
var artifact_air_targeting_providers: Array[Callable] = []
var artifact_projectile_homing_providers: Array[Callable] = []
var artifact_flame_homing_providers: Array[Callable] = []
var artifact_homing_range_providers: Array[Callable] = []
var artifact_laser_deflection_providers: Array[Callable] = []
## Runtime-only manual aim state. Artifacts may opt a turret into this mode,
## while each weapon keeps ownership of its normal firing cadence and damage.
var _manual_control_active: bool = false
var _manual_aim_world_position: Vector2 = Vector2.ZERO
var fire_rate: float:
	get:
		return get_fire_rate()


func begin_artifact_attack() -> void:
	artifact_attack_started.emit()


func end_artifact_attack() -> void:
	artifact_attack_finished.emit()


func get_module_category() -> StringName:
	return CATEGORY_WEAPON


func get_chip_module_kind() -> StringName:
	return &"weapon"


func get_power_consumption() -> int:
	return maxi(power_consumption, 0)


## Applies permanent research to an untouched base damage value. Artifact
## behavior is supplied by independent runtime effect nodes.
func get_modified_damage(base_damage: float) -> float:
	var effective_base := base_damage
	for provider in artifact_base_damage_bonuses.duplicate():
		if not provider.is_valid():
			artifact_base_damage_bonuses.erase(provider)
			continue
		effective_base += float(provider.call())
	var modifiers: Array[StatModifier] = ResearchManager.get_weapon_stat_modifiers(
		weapon_type_id,
		&"damage"
	)
	var provider_index := 0
	for provider in artifact_damage_multipliers.duplicate():
		if not provider.is_valid():
			artifact_damage_multipliers.erase(provider)
			continue
		var modifier := StatModifier.new()
		modifier.source_id = StringName("equipped_ship_artifact_damage_%d" % provider_index)
		modifier.stat_id = &"damage"
		modifier.final_multiplier = maxf(float(provider.call()), 0.0)
		modifiers.append(modifier)
		provider_index += 1
	var result := StatModifierPipeline.calculate(&"damage", effective_base, modifiers)
	for provider in artifact_final_damage_bonuses.duplicate():
		if not provider.is_valid():
			artifact_final_damage_bonuses.erase(provider)
			continue
		result += float(provider.call())
	return maxf(result, 0.0)


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
	for provider in artifact_flat_range_bonuses.duplicate():
		if not provider.is_valid():
			artifact_flat_range_bonuses.erase(provider)
			continue
		var modifier := StatModifier.new()
		modifier.source_id = StringName("equipped_magic_artifact_flat_range_%d" % provider_index)
		modifier.stat_id = &"attack_range"
		modifier.flat_bonus = maxf(float(provider.call()), 0.0)
		modifiers.append(modifier)
		provider_index += 1
	return maxf(StatModifierPipeline.calculate(&"attack_range", base_range, modifiers), 0.0)


## Applies projectile-size modifiers independently from targeting range.
## Projectile range is the projectile's visual and collision radius/width; it
## never controls how far a projectile travels through the world.
func get_modified_projectile_range(base_range: float) -> float:
	var modifiers: Array[StatModifier] = []
	var provider_index := 0
	for provider in artifact_projectile_range_bonuses.duplicate():
		if not provider.is_valid():
			artifact_projectile_range_bonuses.erase(provider)
			continue
		var modifier := StatModifier.new()
		modifier.source_id = StringName("equipped_magic_artifact_projectile_range_%d" % provider_index)
		modifier.stat_id = &"projectile_range"
		modifier.base_additive_ratio = maxf(float(provider.call()), 0.0)
		modifiers.append(modifier)
		provider_index += 1
	return maxf(StatModifierPipeline.calculate(&"projectile_range", base_range, modifiers), 0.0)


## Shared by beam visuals and hit shapes, separate from projectile radius.
func get_modified_beam_width(base_width: float) -> float:
	var minimum_multiplier := 1.0
	for provider in artifact_beam_width_multipliers.duplicate():
		if not provider.is_valid():
			artifact_beam_width_multipliers.erase(provider)
			continue
		minimum_multiplier = maxf(minimum_multiplier, float(provider.call()))
	return maxf(get_modified_projectile_range(base_width), base_width * minimum_multiplier)


## Each artifact multiplies the current travel speed: 0.5 * 1.5 = 0.75.
func get_modified_projectile_speed(base_speed: float) -> float:
	var result := base_speed
	for provider in artifact_projectile_speed_multipliers.duplicate():
		if not provider.is_valid():
			artifact_projectile_speed_multipliers.erase(provider)
			continue
		result *= maxf(float(provider.call()), 0.0)
	return maxf(result, 0.0)


## Reserved interface for future artifact-based active skills.
func get_modified_skill_cast_time(base_cast_time: float) -> float:
	return maxf(base_cast_time, 0.0)


func add_artifact_fire_rate_bonus(provider: Callable) -> void:
	if provider.is_valid() and not artifact_fire_rate_bonuses.has(provider):
		artifact_fire_rate_bonuses.append(provider)


func add_artifact_damage_multiplier(provider: Callable) -> void:
	if provider.is_valid() and not artifact_damage_multipliers.has(provider):
		artifact_damage_multipliers.append(provider)


func add_artifact_final_damage_bonus(provider: Callable) -> void:
	if provider.is_valid() and not artifact_final_damage_bonuses.has(provider):
		artifact_final_damage_bonuses.append(provider)


func remove_artifact_final_damage_bonus(provider: Callable) -> void:
	artifact_final_damage_bonuses.erase(provider)


func add_artifact_projectile_speed_multiplier(provider: Callable) -> void:
	if provider.is_valid() and not artifact_projectile_speed_multipliers.has(provider):
		artifact_projectile_speed_multipliers.append(provider)


func remove_artifact_projectile_speed_multiplier(provider: Callable) -> void:
	artifact_projectile_speed_multipliers.erase(provider)


func add_artifact_base_damage_bonus(provider: Callable) -> void:
	if provider.is_valid() and not artifact_base_damage_bonuses.has(provider):
		artifact_base_damage_bonuses.append(provider)


func remove_artifact_base_damage_bonus(provider: Callable) -> void:
	artifact_base_damage_bonuses.erase(provider)


func remove_artifact_damage_multiplier(provider: Callable) -> void:
	artifact_damage_multipliers.erase(provider)


func remove_artifact_fire_rate_bonus(provider: Callable) -> void:
	artifact_fire_rate_bonuses.erase(provider)


func add_artifact_range_bonus(provider: Callable) -> void:
	if provider.is_valid() and not artifact_range_bonuses.has(provider):
		artifact_range_bonuses.append(provider)


func remove_artifact_range_bonus(provider: Callable) -> void:
	artifact_range_bonuses.erase(provider)


func add_artifact_flat_range_bonus(provider: Callable) -> void:
	if provider.is_valid() and not artifact_flat_range_bonuses.has(provider):
		artifact_flat_range_bonuses.append(provider)


func remove_artifact_flat_range_bonus(provider: Callable) -> void:
	artifact_flat_range_bonuses.erase(provider)


func add_artifact_projectile_range_bonus(provider: Callable) -> void:
	if provider.is_valid() and not artifact_projectile_range_bonuses.has(provider):
		artifact_projectile_range_bonuses.append(provider)


func remove_artifact_projectile_range_bonus(provider: Callable) -> void:
	artifact_projectile_range_bonuses.erase(provider)


func add_artifact_beam_width_multiplier(provider: Callable) -> void:
	if provider.is_valid() and not artifact_beam_width_multipliers.has(provider):
		artifact_beam_width_multipliers.append(provider)


func remove_artifact_beam_width_multiplier(provider: Callable) -> void:
	artifact_beam_width_multipliers.erase(provider)


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


## Ghost Bullet is more than a pierce bonus: direct-target kills refund the
## penetration consumed by that impact and opt the shot into ghost visuals.
## Keeping this flag separate lets ordinary pierce bonuses stack cleanly.
func add_artifact_ghost_projectile(provider: Callable) -> void:
	_add_artifact_provider(artifact_ghost_projectile_providers, provider)


func remove_artifact_ghost_projectile(provider: Callable) -> void:
	artifact_ghost_projectile_providers.erase(provider)


func has_artifact_ghost_projectile() -> bool:
	for provider in artifact_ghost_projectile_providers.duplicate():
		if not provider.is_valid():
			artifact_ghost_projectile_providers.erase(provider)
		elif bool(provider.call()):
			return true
	return false


## Adds projectiles to attacks that actually instantiate bullet/projectile
## scenes. Beams, waves, saws and continuous flame never read this value.
func add_artifact_projectile_count_bonus(provider: Callable) -> void:
	_add_artifact_provider(artifact_projectile_count_bonuses, provider)


func remove_artifact_projectile_count_bonus(provider: Callable) -> void:
	artifact_projectile_count_bonuses.erase(provider)


func get_artifact_projectile_count_bonus() -> int:
	var total := 0
	for provider in artifact_projectile_count_bonuses.duplicate():
		if provider.is_valid():
			total += maxi(int(provider.call()), 0)
		else:
			artifact_projectile_count_bonuses.erase(provider)
	return total


## Optional symmetric spread helper. Twin Demon passes zero spread for base
## weapons so the parallel bonus shot cannot miss the locked target.
## Twin Demon (Claude sync 97): extra projectiles fly side by side with the
## original, a clear gap apart (about 3x the bullet's radius, at least 14 px).
func get_volley_lateral_spacing(projectile_radius: float) -> float:
	return maxf(projectile_radius * 3.0, 14.0)


func get_projectile_volley_direction(base_direction: Vector2, index: int, count: int, spread_degrees: float = 0.0) -> Vector2:
	if count <= 1:
		return base_direction.normalized()
	var weight := float(index) / float(count - 1)
	var offset := deg_to_rad(lerpf(-spread_degrees, spread_degrees, weight))
	return base_direction.normalized().rotated(offset)


func add_artifact_air_targeting(provider: Callable) -> void:
	_add_artifact_provider(artifact_air_targeting_providers, provider)


func remove_artifact_air_targeting(provider: Callable) -> void:
	artifact_air_targeting_providers.erase(provider)


func add_artifact_projectile_homing(provider: Callable) -> void:
	_add_artifact_provider(artifact_projectile_homing_providers, provider)


func remove_artifact_projectile_homing(provider: Callable) -> void:
	artifact_projectile_homing_providers.erase(provider)


func add_artifact_flame_homing(provider: Callable) -> void:
	_add_artifact_provider(artifact_flame_homing_providers, provider)


func remove_artifact_flame_homing(provider: Callable) -> void:
	artifact_flame_homing_providers.erase(provider)


func add_artifact_homing_range(provider: Callable) -> void:
	_add_artifact_provider(artifact_homing_range_providers, provider)


func remove_artifact_homing_range(provider: Callable) -> void:
	artifact_homing_range_providers.erase(provider)


func add_artifact_laser_deflection(provider: Callable) -> void:
	_add_artifact_provider(artifact_laser_deflection_providers, provider)


func remove_artifact_laser_deflection(provider: Callable) -> void:
	artifact_laser_deflection_providers.erase(provider)


func has_artifact_air_targeting() -> bool:
	for provider in artifact_air_targeting_providers.duplicate():
		if not provider.is_valid():
			artifact_air_targeting_providers.erase(provider)
		elif bool(provider.call()):
			return true
	return false


func get_artifact_projectile_homing_turn_rate() -> float:
	return _maximum_artifact_value(artifact_projectile_homing_providers)


func get_artifact_flame_homing_turn_rate() -> float:
	return _maximum_artifact_value(artifact_flame_homing_providers)


func get_artifact_homing_range() -> float:
	return _maximum_artifact_value(artifact_homing_range_providers)


func get_artifact_laser_deflection_degrees() -> float:
	return _maximum_artifact_value(artifact_laser_deflection_providers)


func _add_artifact_provider(providers: Array[Callable], provider: Callable) -> void:
	if provider.is_valid() and not providers.has(provider):
		providers.append(provider)


func _maximum_artifact_value(providers: Array[Callable]) -> float:
	var maximum := 0.0
	for provider in providers.duplicate():
		if provider.is_valid():
			maximum = maxf(maximum, float(provider.call()))
		else:
			providers.erase(provider)
	return maximum


## Enables or disables player-directed aiming for this weapon instance.
## This state is never saved and is cleared with battle artifact effects.
func set_manual_control_active(active: bool) -> void:
	_manual_control_active = active and not assembly_mode
	if _manual_control_active:
		_manual_aim_world_position = get_global_mouse_position()


func is_manual_control_active() -> bool:
	return _manual_control_active and not assembly_mode


func set_manual_aim_world_position(world_position: Vector2) -> void:
	_manual_aim_world_position = world_position


func get_manual_aim_world_position() -> Vector2:
	return _manual_aim_world_position


func has_valid_manual_aim(origin: Vector2) -> bool:
	return is_manual_control_active() and origin.distance_squared_to(_manual_aim_world_position) > 1.0


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


func can_target_enemy(enemy: BasicEnemy) -> bool:
	if not is_instance_valid(enemy) or enemy.is_dying():
		return false
	return enemy_targeting == EnemyTargeting.GROUND_AND_AIR or not enemy.is_flying_enemy() or has_artifact_air_targeting()


## Artifact-only steering shared by bullets, shells, fusion shots, and flame
## puffs. The returned target persists between frames to avoid repeated scans.
func get_homing_steering(
	world_origin: Vector2,
	direction: Vector2,
	current_target: Variant,
	ignored_enemy_ids: Dictionary,
	delta: float,
	turn_rate_degrees: float
) -> Dictionary:
	var maximum_range := get_artifact_homing_range()
	var target := current_target as BasicEnemy if is_instance_valid(current_target) and current_target is BasicEnemy else null
	if (
		target == null
		or not target.is_in_group(&"enemies")
		or not can_target_enemy(target)
		or ignored_enemy_ids.has(target.get_instance_id())
		or world_origin.distance_to(target.get_target_point(world_origin)) > maximum_range
	):
		target = null
		var nearest_distance := maximum_range
		for node in get_tree().get_nodes_in_group(&"enemies"):
			var enemy := node as BasicEnemy
			if enemy == null or not can_target_enemy(enemy) or ignored_enemy_ids.has(enemy.get_instance_id()):
				continue
			var distance := world_origin.distance_to(enemy.get_target_point(world_origin))
			if distance <= nearest_distance:
				nearest_distance = distance
				target = enemy
	var steered := direction.normalized()
	if target != null and turn_rate_degrees > 0.0:
		var desired := world_origin.direction_to(target.get_target_point(world_origin))
		if desired.length_squared() > 0.0001:
			var maximum_turn := deg_to_rad(turn_rate_degrees) * maxf(delta, 0.0)
			var turn := clampf(angle_difference(steered.angle(), desired.angle()), -maximum_turn, maximum_turn)
			steered = steered.rotated(turn).normalized()
	return {"target": target, "direction": steered}


## A Bat Eyeball laser stays straight through its first target, then may bend
## by a small capped angle toward one additional valid target.
func get_artifact_laser_path(
	world_origin: Vector2,
	direction: Vector2,
	maximum_range: float,
	preferred_first_target: BasicEnemy
) -> PackedVector2Array:
	var straight := direction.normalized()
	var result := PackedVector2Array([world_origin, world_origin + straight * maximum_range])
	var maximum_deflection := deg_to_rad(get_artifact_laser_deflection_degrees())
	if maximum_deflection <= 0.0 or not can_target_enemy(preferred_first_target):
		return result
	var bend := preferred_first_target.get_target_point(world_origin)
	var bend_distance := world_origin.distance_to(bend)
	if bend_distance <= 1.0 or bend_distance >= maximum_range:
		return result
	var remaining := maximum_range - bend_distance
	var secondary: BasicEnemy
	var best_angle := INF
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as BasicEnemy
		if enemy == null or enemy == preferred_first_target or not can_target_enemy(enemy):
			continue
		var relative := enemy.get_target_point(bend) - bend
		var distance := relative.length()
		if distance <= 1.0 or distance > remaining:
			continue
		var angle := absf(angle_difference(straight.angle(), relative.angle()))
		if angle <= maximum_deflection and (angle < best_angle or (is_equal_approx(angle, best_angle) and distance < best_distance)):
			secondary = enemy
			best_angle = angle
			best_distance = distance
	if secondary == null:
		return result
	var desired := bend.direction_to(secondary.get_target_point(bend))
	var turn := clampf(angle_difference(straight.angle(), desired.angle()), -maximum_deflection, maximum_deflection)
	var deflected := straight.rotated(turn)
	return PackedVector2Array([world_origin, bend, bend + deflected * remaining])


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
		if not can_target_enemy(enemy):
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
	# Ancient Dragon smoke (Claude sync 93): while blinded the turret cannot
	# hold a lock; every scan it re-picks the nearest enemy but keeps firing.
	var lock_blocked := target_lock_suppressed and search_due
	if not lock_blocked and is_instance_valid(current_target) and current_target is BasicEnemy:
		var enemy := current_target as BasicEnemy
		if (
			enemy.is_in_group("enemies")
			and can_target_enemy(enemy)
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
