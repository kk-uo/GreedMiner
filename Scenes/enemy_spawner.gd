extends Node2D

## The enemy scene that will be instantiated.
@export var enemy_scene: PackedScene

## Minimum distance between the ship and spawned enemies.
@export var min_spawn_radius: float = 250.0

## Maximum distance between the ship and spawned enemies.
@export var max_spawn_radius: float = 350.0

## Reference to the child spawn timer.
@onready var spawn_timer: Timer = $SpawnTimer

## Reference to the ship.
@onready var ship: Node2D = $"../Ship"

## Container for all spawned enemies.
@onready var enemies: Node2D = $"../Enemies"


## Initialize the enemy spawner.
func _ready() -> void:
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	print("EnemySpawner initialized!")


## Spawn an enemy when the timer finishes.
func _on_spawn_timer_timeout() -> void:
	if enemy_scene == null:
		push_warning("Enemy scene has not been assigned!")
		return

	# Generate a random angle around the ship.
	var angle: float = randf_range(0.0, TAU)

	# Generate a random distance from the ship.
	var radius: float = randf_range(
		min_spawn_radius,
		max_spawn_radius
	)

	# Convert the angle and distance into a position offset.
	var offset: Vector2 = Vector2.RIGHT.rotated(angle) * radius

	# Create a new enemy instance.
	var enemy: BasicEnemy = enemy_scene.instantiate() as BasicEnemy

	# Stop if the assigned scene is not a BasicEnemy.
	if enemy == null:
		push_error("The assigned enemy scene must use BasicEnemy.gd.")
		return

	# Assign the ship as the enemy's movement target.
	enemy.target_ship = ship

	# Add the enemy to the enemy container.
	enemies.add_child(enemy)

	# Position the enemy around the ship.
	enemy.global_position = ship.global_position + offset

	# Print the spawned enemy's position for debugging.
	print("Enemy spawned at: ", enemy.global_position)
