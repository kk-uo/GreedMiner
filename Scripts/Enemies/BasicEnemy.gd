
class_name BasicEnemy
extends Area2D

## Shared base class for enemies that approach and attack the ship.

## Distance slack (px) when deciding whether the ship is within attack range.
const ATTACK_RANGE_TOLERANCE: float = 0.5

## Emitted once when this enemy is killed by damage.
signal died(enemy_id: StringName, death_position: Vector2)

## Emitted after initialization and whenever this enemy loses health.
signal health_changed(current_health: float, maximum_health: float)


## Supported enemy attack categories.
enum AttackType {
	MELEE,
	RANGED,
}

## Broad enemy tiers used by future spawn systems.
enum EnemyTier {
	COMMON,
	LARGE,
	BOSS,
}

## Bit flags describing the formations in which a wave may place an enemy.
enum SpawnPattern {
	SOLO = 1,
	CLUSTER = 2,
}

## Stable identifier used by enemy catalogs and future spawn systems.
@export var enemy_id: StringName = &"little_rock"

## Human-readable name shown in tools and future UI.
@export var enemy_name: String = "Little Rock"
## Opt-in per-enemy logging; combat can generate thousands of events.
@export var debug_combat_logging: bool = false

## Maximum health of this enemy.
@export var max_health: float = 20.0

## Movement speed in pixels per second.
@export var move_speed: float = 75.0

## Damage dealt by each attack.
@export var attack_damage: float = 5.0

## Time between attacks in seconds.
@export var attack_interval: float = 1.0

## Maximum distance from the ship boundary to attack.
@export var attack_range: float = 10.0

## Ore added to the current mission when this enemy is killed (0 = none).
@export_range(0.0, 100000.0, 1.0) var reward_ore: float = 0.0

## Fraction of each incoming hit prevented before health is reduced.
## 0.2 means that the enemy receives 80% of the incoming damage.
@export_range(0.0, 1.0, 0.01) var damage_reduction: float = 0.0

## Attack behavior category for future enemy definitions.
@export var attack_type: AttackType = AttackType.MELEE

## Spawn and difficulty category for future enemy definitions.
@export var enemy_tier: EnemyTier = EnemyTier.COMMON

## Allows specific non-common enemies to use the normal click-to-pop mechanic.
@export var allow_click_pop: bool = false

## Data-only spawn metadata. Wave quotas are intentionally configured
## elsewhere; these fields document when and where this enemy becomes valid.
@export var spawn_map_id: StringName = &""
@export_range(1, 100, 1) var minimum_spawn_wave: int = 1
@export_flags("Solo:1", "Cluster:2") var spawn_patterns: int = SpawnPattern.SOLO


## Defines how the enemy chooses its movement destination.
enum TargetMode {
	SHIP_CENTER,
	SHIP_EDGE
}

## Determines which part of the ship the enemy moves toward.
@export var target_mode: TargetMode = TargetMode.SHIP_EDGE


## Current health of this enemy.
var _current_health: float

## Reference to the ship that this enemy attacks.
var target_ship: Node2D
## Working or ore-carrying workers attract nearby ordinary melee enemies.
var _mining_target: Node2D
@export_range(0.0, 1000.0, 1.0) var mining_target_range: float = 200.0
@export_range(0.0, 1.0, 0.01) var mining_target_search_interval: float = 0.2
const TARGET_SEARCH_SCHEDULE := preload("res://Scripts/Modules/Weapons/TargetSearchSchedule.gd")
var _dwarf_search_schedule := TARGET_SEARCH_SCHEDULE.new()

## Whether the enemy is currently attacking.
var _is_attacking: bool = false

## Prevents duplicate death effects from multiple hits in the same frame.
var _is_dying: bool = false

## Battle shutdown disables splitting so descendants cannot appear afterward.
var _death_effects_enabled: bool = true

## How long an enemy flashes white after being hit (style A hit feedback).
const HIT_FLASH_DURATION: float = 0.08

## Seconds remaining on the white hit flash.
var _hit_flash_time: float = 0.0

## Eligible enemies can be popped by clicking them this many times in battle.
const CLICKS_TO_POP: int = 8
## Clicks received so far (see register_click).
var click_count: int = 0
var _click_tween: Tween

## Facing angle used by subclasses' _draw(); enemies always face the ship.
var _facing: float = 0.0


@onready var attack_timer: Timer = $AttackTimer


## Initializes enemy health and attack behavior.
func _ready() -> void:
	# Enemies are passive targets. Projectile and melee areas detect them;
	# enemy-vs-enemy overlap monitoring has no gameplay purpose.
	monitoring = false
	collision_mask = 0
	_current_health = max_health

	# Register this enemy for automatic weapon targeting.
	add_to_group("enemies")

	# Configure the attack timer.
	attack_timer.wait_time = attack_interval
	attack_timer.one_shot = false
	attack_timer.stop()
	health_changed.emit(_current_health, max_health)

	if debug_combat_logging:
		print("%s spawned! HP: %s" % [enemy_name, _current_health])


## Moves toward the ship and attacks when close enough.
func _physics_process(delta: float) -> void:
	if _is_dying:
		return

	if not is_instance_valid(target_ship):
		_stop_attacking()
		return

	if not target_ship is Ship:
		_stop_attacking()
		return

	var ship: Ship = target_ship as Ship

	# Stop attacking when the ship has been destroyed.
	if ship.current_hp <= 0.0:
		_stop_attacking()
		return

	var dwarf := _find_targetable_dwarf(delta)
	if dwarf != _mining_target:
		_stop_attacking()
		_mining_target = dwarf
	if is_instance_valid(dwarf):
		var dwarf_position: Vector2 = dwarf.call("get_enemy_target_position")
		var distance := global_position.distance_to(dwarf_position)
		_facing = (dwarf_position - global_position).angle()
		if distance <= _dwarf_attack_reach():
			_start_attacking()
		else:
			_stop_attacking()
			global_position = global_position.move_toward(dwarf_position, minf(get_effective_move_speed() * delta, maxf(distance - _dwarf_attack_reach(), 0.0)))
		return

	# Calculate the closest point on the transformed ship-grid boundary.
	var closest_point: Vector2 = _get_nearest_ship_boundary_world(
		ship,
		global_position
	)

	# Face the ship so silhouettes read as "approaching".
	var to_ship: Vector2 = closest_point - global_position
	if to_ship.length_squared() > 0.01:
		_facing = to_ship.angle()

	# Calculate distance from the enemy to the ship boundary.
	var distance_to_ship: float = global_position.distance_to(
		closest_point
	)

	# Start attacking when close enough to the ship. The small tolerance stops
	# an enemy approaching a hull corner diagonally from stalling forever a
	# floating-point hair outside attack_range (it never attacked).
	if distance_to_ship <= attack_range + ATTACK_RANGE_TOLERANCE:
		_start_attacking()
		return

	# Stop attacking while approaching the ship.
	_stop_attacking()

	# Choose a movement destination.
	var target_position: Vector2 = closest_point

	if target_mode == TargetMode.SHIP_CENTER:
		# The Ship origin is the grid's top-left, not its visual center.
		target_position = ship.to_global(
			Ship.SHIP_SIZE * 0.5
		)

	# Move toward the destination.
	var direction: Vector2 = global_position.direction_to(
		target_position
	)
	# Directional army batches initially march in parallel; near the ship they
	# resume normal targeting so units can reach the hull and attack.
	if has_meta("formation_spawn_side"):
		var side: Vector2 = get_meta("formation_spawn_side")
		var ship_center := ship.to_global(Ship.SHIP_SIZE * 0.5)
		if (global_position - ship_center).dot(side) > 250.0:
			direction = -side
			_facing = direction.angle()
		else:
			remove_meta("formation_spawn_side")

	# Never cross the attack boundary, even during a long frame.
	var remaining_approach_distance: float = maxf(
		distance_to_ship - attack_range,
		0.0
	)

	var movement: float = minf(
		get_effective_move_speed() * delta,
		remaining_approach_distance
	)

	global_position += direction * movement

## Weather is a transient additive modifier and never changes saved base stats.
func get_effective_move_speed() -> float:
	if enemy_tier == EnemyTier.BOSS:
		return move_speed
	var weather := get_node_or_null("../../WeatherManager")
	if weather != null and weather.has_method("blood_moon_speed_bonus"):
		return move_speed + float(weather.call("blood_moon_speed_bonus"))
	return move_speed


## Weather is read at the moment of damage so spawned enemies inherit it too.
func is_blood_moon_active() -> bool:
	var weather := get_node_or_null("../../WeatherManager") as WeatherManager
	return weather != null and weather.blood_moon_active


## A nonnegative override replaces the total reduction during a blood moon.
func get_blood_moon_total_damage_reduction() -> float:
	return -1.0


## Keeps the hit flash and facing up to date on screen.
func _process(delta: float) -> void:
	if _hit_flash_time > 0.0:
		_hit_flash_time = maxf(_hit_flash_time - delta, 0.0)
	queue_redraw()


## Returns the white flash color while hit, otherwise the given color.
func _flash(base_color: Color) -> Color:
	return Palette.HIT_FLASH if _hit_flash_time > 0.0 else base_color


## Whether the hit flash is currently showing.
func _is_flashing() -> bool:
	return _hit_flash_time > 0.0


## Approximate visual radius, used to size the death burst.
func _get_visual_radius() -> float:
	return 14.0


## Returns the nearest point on the ship grid's outer boundary in world space.
func _get_nearest_ship_boundary_world(
	ship: Ship,
	world_position: Vector2
) -> Vector2:
	var local_position: Vector2 = ship.to_local(world_position)
	var boundary_position: Vector2 = _get_nearest_ship_boundary_local(
		local_position
	)

	return ship.to_global(boundary_position)


## Finds the nearest outer-boundary point of the local 3x3 ship rectangle.
func _get_nearest_ship_boundary_local(local_position: Vector2) -> Vector2:
	var ship_rect := Rect2(Vector2.ZERO, Ship.SHIP_SIZE)
	var boundary_position := Vector2(
		clampf(local_position.x, ship_rect.position.x, ship_rect.end.x),
		clampf(local_position.y, ship_rect.position.y, ship_rect.end.y)
	)

	# Clamping an interior point returns the point itself, so snap it to the
	# nearest edge to guarantee that the result is always on the boundary.
	if ship_rect.has_point(local_position):
		var distance_left: float = local_position.x - ship_rect.position.x
		var distance_right: float = ship_rect.end.x - local_position.x
		var distance_top: float = local_position.y - ship_rect.position.y
		var distance_bottom: float = ship_rect.end.y - local_position.y
		var nearest_distance: float = minf(
			minf(distance_left, distance_right),
			minf(distance_top, distance_bottom)
		)

		if nearest_distance == distance_left:
			boundary_position.x = ship_rect.position.x
		elif nearest_distance == distance_right:
			boundary_position.x = ship_rect.end.x
		elif nearest_distance == distance_top:
			boundary_position.y = ship_rect.position.y
		else:
			boundary_position.y = ship_rect.end.y

	return boundary_position


## Starts the enemy's repeating attack timer.
func _start_attacking() -> void:
	if _is_attacking:
		return

	_is_attacking = true
	attack_timer.start()


## Stops the enemy's attack timer.
func _stop_attacking() -> void:
	if not _is_attacking:
		return

	_is_attacking = false
	attack_timer.stop()


## Deals damage whenever the attack timer finishes.
func _on_attack_timer_timeout() -> void:
	if not _is_attacking:
		return
	if is_instance_valid(_mining_target):
		if _mining_target.call("is_enemy_targetable") and global_position.distance_to(_mining_target.call("get_enemy_target_position")) <= _dwarf_attack_reach() + ATTACK_RANGE_TOLERANCE:
			_mining_target.call("take_damage", attack_damage)
		else:
			_stop_attacking()
		return

	if not is_instance_valid(target_ship):
		_stop_attacking()
		return

	if not target_ship is Ship:
		_stop_attacking()
		return

	var ship: Ship = target_ship as Ship

	if ship.current_hp <= 0.0:
		_stop_attacking()
		return

	# Shield reactions are queried only at this authoritative pre-attack point.
	# If one activates, stop this attack cycle before any damage/projectile is
	# produced. Physics processing may begin a fresh full interval afterward.
	if ship.try_interrupt_enemy_attack(self):
		_stop_attacking()
		return

	_perform_attack(ship)

func _find_targetable_dwarf(delta: float = -1.0) -> Node2D:
	if attack_type != AttackType.MELEE or enemy_tier == EnemyTier.BOSS:
		return null
	var search_due := delta < 0.0 or _dwarf_search_schedule.is_due(delta, mining_target_search_interval)
	var closest: Node2D
	# Detection and melee reach are measured from the edge of this enemy's body.
	var best := maxf(ResearchManager.get_dwarf_detection_range(mining_target_range), 0.0) + get_collision_radius()
	if is_instance_valid(_mining_target) and _mining_target.call("is_enemy_targetable") and global_position.distance_to(_mining_target.call("get_enemy_target_position")) < best:
		return _mining_target
	if not search_due:
		return null
	for node in get_tree().get_nodes_in_group("mining_dwarves"):
		var dwarf := node as Node2D
		if not is_instance_valid(dwarf) or not dwarf.has_method("is_enemy_targetable") or not dwarf.call("is_enemy_targetable"):
			continue
		var distance := global_position.distance_to(dwarf.call("get_enemy_target_position"))
		if distance < best:
			best = distance
			closest = dwarf
	return closest


## Distance between body centres at which a melee strike can reach the dwarf.
func _dwarf_attack_reach() -> float:
	return attack_range + get_collision_radius() + 10.0


## Performs one attack. Ranged enemies override this to create a projectile.
func _perform_attack(ship: Ship) -> void:
	ship.take_damage(attack_damage)
	if debug_combat_logging:
		print("%s attacks! Damage: %s" % [enemy_name, attack_damage])


## Point on this enemy's body nearest to from_world. Weapons measure their
## range to it and aim at it. Default: the centre; long enemies override it.
func get_target_point(_from_world: Vector2) -> Vector2:
	return global_position


## Conservative radius of the active collision shape, used for hull-distance
## and map-boundary calculations without relying on visual sprite dimensions.
func get_collision_radius() -> float:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return _get_visual_radius()
	var shape := collision.shape
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		return maxf(capsule.radius, capsule.height * 0.5)
	if shape is RectangleShape2D:
		return (shape as RectangleShape2D).size.length() * 0.5
	return _get_visual_radius()


## Instantly displaces this enemy away from an origin while respecting solid
## PhysicsBody2D obstacles and optional battlefield bounds. Artifact and shield
## effects decide tier immunity before calling this shared movement interface.
func apply_radial_knockback(origin: Vector2, distance: float, bounds: Rect2 = Rect2()) -> void:
	if distance <= 0.0 or _is_dying:
		return
	var direction := origin.direction_to(global_position)
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	var destination := global_position + direction * distance
	if bounds.size.x > 0.0 and bounds.size.y > 0.0:
		var radius := get_collision_radius()
		destination.x = clampf(destination.x, bounds.position.x + radius, bounds.end.x - radius)
		destination.y = clampf(destination.y, bounds.position.y + radius, bounds.end.y - radius)
	global_position = _collision_safe_knockback_destination(destination)


func _collision_safe_knockback_destination(destination: Vector2) -> Vector2:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null or not is_inside_tree():
		return destination
	var start := global_position
	var steps := maxi(1, ceili(start.distance_to(destination) / 10.0))
	var last_clear := start
	for index in range(1, steps + 1):
		var candidate := start.lerp(destination, float(index) / float(steps))
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = collision.shape
		query.transform = Transform2D(global_rotation, candidate)
		query.collision_mask = 0xFFFFFFFF
		query.collide_with_areas = false
		query.collide_with_bodies = true
		if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			break
		last_clear = candidate
	return last_clear


## Whether the player can pop this enemy by clicking it.
func is_clickable() -> bool:
	return (enemy_tier == EnemyTier.COMMON or allow_click_pop) and not _is_dying


## Radius used for click hit tests (a little larger than the body).
func get_click_radius() -> float:
	return _get_visual_radius() + 6.0


## One player click: a quick swell + flash; the CLICKS_TO_POP-th click pops it
## (normal death: burst, reward and death effects). Returns true if counted.
func register_click() -> bool:
	if not is_clickable():
		return false
	click_count += 1
	_hit_flash_time = HIT_FLASH_DURATION
	if click_count >= CLICKS_TO_POP:
		if _click_tween != null:
			_click_tween.kill()
		scale = Vector2.ONE
		_current_health = 0.0
		health_changed.emit(_current_health, max_health)
		_die()
		return true
	# Each click swells a bit more, so the player can feel it filling up.
	var swell: float = 1.22 + 0.03 * float(click_count)
	if _click_tween != null:
		_click_tween.kill()
	scale = Vector2.ONE
	_click_tween = create_tween()
	_click_tween.tween_property(self, "scale", Vector2.ONE * swell, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_click_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return true


## Called when the enemy receives damage. Exact-effect damage may explicitly
## bypass armor; normal weapons retain the existing reduction behavior.
func take_damage(damage: float, ignore_damage_reduction: bool = false, count_for_artifact: bool = true, source_weapon: WeaponModule = null) -> void:
	if damage <= 0.0 or _current_health <= 0.0 or _is_dying:
		return

	# Damage reduction is applied exactly once per incoming hit.
	var final_damage := damage if ignore_damage_reduction else damage * (1.0 - clampf(damage_reduction, 0.0, 1.0))
	var weather := get_node_or_null("../../WeatherManager") as WeatherManager
	if weather != null and weather.blood_moon_active and enemy_tier != EnemyTier.BOSS:
		var total_reduction := get_blood_moon_total_damage_reduction()
		if total_reduction >= 0.0:
			final_damage = damage * (1.0 - clampf(total_reduction, 0.0, 1.0))
		else:
			final_damage *= 1.0 - clampf(weather.blood_moon_damage_reduction, 0.0, 1.0)
	var previous_health := _current_health
	_current_health = maxf(_current_health - final_damage, 0.0)
	if count_for_artifact:
		ArtifactManager.record_battle_activity(source_weapon, previous_health - _current_health)
	_hit_flash_time = HIT_FLASH_DURATION
	health_changed.emit(_current_health, max_health)

	if debug_combat_logging:
		print("%s HP: %s (-%s)" % [
			enemy_name,
			_current_health,
			final_damage,
		])

	# Destroy the enemy when health reaches zero.
	if _current_health <= 0.0:
		_die()


## Removes the enemy from the scene.
func _die() -> void:
	if _is_dying:
		return

	_is_dying = true
	_stop_attacking()
	set_physics_process(false)
	remove_from_group("enemies")
	set_deferred("monitoring", false)

	var death_position := global_position
	_spawn_death_visual(death_position)
	if _death_effects_enabled:
		# Presentation: every boss's killing blow gets the cinema finisher
		# (hit-stop, bullet time, letterbox, grey world, camera punch).
		if enemy_tier == EnemyTier.BOSS:
			BOSS_FINISHER.play(self, death_position, _finisher_keeps_camera())
		_grant_reward(death_position)
		_perform_death_effect()
	died.emit(enemy_id, death_position)
	if debug_combat_logging:
		print("%s destroyed!" % enemy_name)

	queue_free()


const BOSS_FINISHER := preload("res://Scripts/VFX/BossFinisher.gd")


## Overridden by a boss whose death starts a cinematic that owns the camera.
func _finisher_keeps_camera() -> bool:
	return false


## Adds reward_ore to the mission; bosses also show a floating "+N" pickup.
## Skipped after battle shutdown, together with the other death effects.
func _grant_reward(death_position: Vector2) -> void:
	if reward_ore <= 0.0:
		return
	ResourceManager.add_mission_ore(reward_ore)
	# Only bosses show a floating "+N" pickup; ordinary kills add ore silently.
	if enemy_tier == EnemyTier.BOSS:
		RewardPopup.spawn(get_parent(), death_position, reward_ore)


## Presentation hook: the burst shown when this enemy dies. Enemy families
## override it (goblins burst into gore). Never affects gameplay.
func _spawn_death_visual(death_position: Vector2) -> void:
	FlatBurst.spawn(get_parent(), death_position, _get_visual_radius() * 1.6, Palette.SHOT, Palette.ENEMY)


## Overridable hook for enemy-specific death effects.
## It is called exactly once only when damage kills this enemy.
func _perform_death_effect() -> void:
	pass


## Returns current health for HUD, tests, and future enemy inspection UI.
func get_current_health() -> float:
	return _current_health


## Returns whether death handling has already started.
func is_dying() -> bool:
	return _is_dying


## Enables or disables enemy-specific death spawning without changing damage.
func set_death_effects_enabled(enabled: bool) -> void:
	_death_effects_enabled = enabled
