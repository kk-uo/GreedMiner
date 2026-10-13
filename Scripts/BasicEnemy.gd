class_name BasicEnemy
extends Area2D

## A basic enemy that can receive damage and die.

# Maximum health of this enemy.
@export var max_health: float = 20.0

# Current health of this enemy.
var _current_health: float


# Initialize enemy health when spawned.
func _ready() -> void:
	_current_health = max_health
	print("Enemy spawned! HP: %s" % _current_health)
	# Register this enemy for automatic weapon targeting.
	add_to_group("enemies")

# Draw a temporary green square.
func _draw() -> void:
	draw_rect(
		Rect2(-16.0, -16.0, 32.0, 32.0),
		Color.GREEN
	)


# Called when the enemy receives damage.
func take_damage(damage: float) -> void:
	_current_health -= damage
	print("Enemy HP: %s" % _current_health)

	# Destroy the enemy when health reaches zero.
	if _current_health <= 0.0:
		_die()


# Remove the enemy from the scene.
func _die() -> void:
	print("Enemy destroyed!")
	queue_free()

## Defines how the enemy chooses its movement destination.
enum TargetMode {
	SHIP_CENTER,
	SHIP_EDGE
}

## Movement speed in pixels per second.
@export var move_speed: float = 60.0

## Determines which part of the ship the enemy moves toward.
@export var target_mode: TargetMode = TargetMode.SHIP_CENTER

## Reference to the ship that the enemy will approach.
var target_ship: Node2D

## Moves the enemy toward its assigned target.
func _physics_process(delta: float) -> void:
	if not is_instance_valid(target_ship):
		return

	# Currently, all movement modes use the ship center.
	# Ship-edge targeting will be implemented in a future update.
	var target_position: Vector2 = target_ship.global_position

	# Calculate the direction toward the destination.
	var direction: Vector2 = global_position.direction_to(
		target_position
	)

	# Move the enemy toward its destination.
	global_position += direction * move_speed * delta
