
class_name BasicEnemy
extends Area2D

## Shared base class for enemies that approach and attack the ship.

## Emitted once when this enemy is killed by damage.
signal died(enemy_id: StringName, death_position: Vector2)


## Supported enemy attack categories.
enum AttackType {
	MELEE,
}

## Broad enemy tiers used by future spawn systems.
enum EnemyTier {
	COMMON,
	LARGE,
}

## Stable identifier used by enemy catalogs and future spawn systems.
@export var enemy_id: StringName = &"little_rock"

## Human-readable name shown in tools and future UI.
@export var enemy_name: String = "Little Rock"

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

## Flat damage removed from each incoming hit before health is reduced.
@export_range(0.0, 1000.0, 0.1) var damage_reduction: float = 0.0

## Attack behavior category for future enemy definitions.
@export var attack_type: AttackType = AttackType.MELEE

## Spawn and difficulty category for future enemy definitions.
@export var enemy_tier: EnemyTier = EnemyTier.COMMON


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

## Whether the enemy is currently attacking.
var _is_attacking: bool = false

## Prevents duplicate death effects from multiple hits in the same frame.
var _is_dying: bool = false

## How long an enemy flashes white after being hit (style A hit feedback).
const HIT_FLASH_DURATION: float = 0.08

## Seconds remaining on the white hit flash.
var _hit_flash_time: float = 0.0

## Facing angle used by subclasses' _draw(); enemies always face the ship.
var _facing: float = 0.0


@onready var attack_timer: Timer = $AttackTimer


## Initializes enemy health and attack behavior.
func _ready() -> void:
	_current_health = max_health

	# Register this enemy for automatic weapon targeting.
	add_to_group("enemies")

	# Configure the attack timer.
	attack_timer.wait_time = attack_interval
	attack_timer.one_shot = false
	attack_timer.stop()

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

	# Start attacking when close enough to the ship.
	if distance_to_ship <= attack_range:
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

	# Never cross the attack boundary, even during a long frame.
	var remaining_approach_distance: float = maxf(
		distance_to_ship - attack_range,
		0.0
	)

	var movement: float = minf(
		move_speed * delta,
		remaining_approach_distance
	)

	global_position += direction * movement


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

	# Damage the ship.
	ship.take_damage(attack_damage)

	print("Enemy attacks! Damage: ", attack_damage)


## Called when the enemy receives damage.
func take_damage(damage: float) -> void:
	if damage <= 0.0 or _current_health <= 0.0 or _is_dying:
		return

	# Damage reduction is applied exactly once per incoming hit.
	var final_damage := maxf(1.0, damage - damage_reduction)
	_current_health = maxf(_current_health - final_damage, 0.0)
	_hit_flash_time = HIT_FLASH_DURATION

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
	FlatBurst.spawn(get_parent(), death_position, _get_visual_radius() * 1.6, Palette.SHOT, Palette.ENEMY)
	_perform_death_effect()
	died.emit(enemy_id, death_position)
	print("%s destroyed!" % enemy_name)

	queue_free()


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
