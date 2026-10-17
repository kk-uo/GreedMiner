extends Node2D

## Optional scene override used for direct manual testing.
## When assigned, every enemy in the batch uses this scene.
@export var enemy_scene: PackedScene

## Enemy IDs spawned in a deterministic repeating order.
@export var spawn_enemy_ids: Array[StringName] = [
	&"little_rock",
	&"rock_golem",
]

## Number of enemies created per timer event.
## Two preserves the timer cadence while doubling the previous spawn count.
@export_range(1, 32, 1) var enemies_per_spawn_event: int = 2

## Extra distance beyond the current camera view used for enemy entry.
@export var spawn_margin: float = 64.0

## Keeps enemy collision shapes inside the finite battlefield boundary.
@export var map_edge_margin: float = 32.0

## Reference to the child spawn timer.
@onready var spawn_timer: Timer = $SpawnTimer

## Reference to the ship.
@onready var ship: Ship = $"../Ship"

## Reference to the finite world-space battlefield.
@onready var battlefield: Battlefield = $"../Battlefield"

## Container for all spawned enemies.
@onready var enemies: Node2D = $"../Enemies"

## Index of the next stable ID in the deterministic test sequence.
var _next_enemy_index: int = 0


## Initialize the enemy spawner.
func _ready() -> void:
	var callback := Callable(self, "_on_spawn_timer_timeout")
	if not spawn_timer.timeout.is_connected(callback):
		spawn_timer.timeout.connect(callback)

	# Spawn the first doubled batch immediately around the ship.
	_spawn_enemy_batch()
	print("EnemySpawner initialized!")


## Spawn an enemy when the timer finishes.
func _on_spawn_timer_timeout() -> void:
	_spawn_enemy_batch()


## Spawns the configured number of enemies for one timer event.
func _spawn_enemy_batch() -> void:
	for _spawn_index in range(enemies_per_spawn_event):
		var selected_scene := enemy_scene

		if selected_scene == null:
			if spawn_enemy_ids.is_empty():
				push_warning("EnemySpawner: No enemy IDs are configured.")
				return

			var selected_id := spawn_enemy_ids[
				_next_enemy_index % spawn_enemy_ids.size()
			]
			_next_enemy_index += 1
			selected_scene = EnemyCatalog.get_enemy_scene(selected_id)

			if selected_scene == null:
				push_warning(
					"EnemySpawner: No scene registered for ID: %s"
					% selected_id
				)
				continue

		_spawn_enemy(selected_scene)


## Creates one enemy scene at a random distance and direction around the ship.
func _spawn_enemy(selected_scene: PackedScene) -> BasicEnemy:
	# Generate a random approach direction around the ship.
	var angle: float = randf_range(0.0, TAU)
	var direction := Vector2.RIGHT.rotated(angle)
	var ship_center: Vector2 = ship.to_global(Ship.SHIP_SIZE * 0.5)

	# Convert the current viewport into world dimensions using the active
	# camera zoom, then find where this direction exits the visible rectangle.
	var camera_zoom := Vector2(
		maxf(ship.world_camera.zoom.x, 0.001),
		maxf(ship.world_camera.zoom.y, 0.001)
	)
	var visible_world_size := get_viewport_rect().size / camera_zoom
	var half_visible_size := visible_world_size * 0.5
	var distance_to_view_edge := INF

	if absf(direction.x) > 0.0001:
		distance_to_view_edge = minf(
			distance_to_view_edge,
			half_visible_size.x / absf(direction.x)
		)
	if absf(direction.y) > 0.0001:
		distance_to_view_edge = minf(
			distance_to_view_edge,
			half_visible_size.y / absf(direction.y)
		)

	var spawn_position := ship_center + direction * (
		distance_to_view_edge + spawn_margin
	)

	# Clamp the spawn point to the actual battlefield map, not to an old
	# viewport-sized rectangle. With the centered ship this still permits
	# approaches from every direction.
	var spawn_bounds := battlefield.get_world_bounds().grow(-map_edge_margin)
	spawn_position = Vector2(
		clampf(spawn_position.x, spawn_bounds.position.x, spawn_bounds.end.x),
		clampf(spawn_position.y, spawn_bounds.position.y, spawn_bounds.end.y)
	)

	# Create a new enemy instance.
	var enemy: BasicEnemy = selected_scene.instantiate() as BasicEnemy

	# Stop if the assigned scene is not a BasicEnemy.
	if enemy == null:
		push_error("EnemySpawner scenes must inherit BasicEnemy.gd.")
		return null

	# Assign the ship as the enemy's movement target.
	enemy.target_ship = ship

	# Add the enemy to the enemy container.
	enemies.add_child(enemy)

	# Position the enemy around the actual visual center of the ship grid.
	enemy.global_position = spawn_position

	# Print the spawned enemy's position for debugging.
	print("Enemy spawned at: ", enemy.global_position)
	return enemy


## Spawns one requested enemy ID immediately for testing or future systems.
func spawn_enemy_by_id(requested_enemy_id: StringName) -> BasicEnemy:
	var requested_scene := EnemyCatalog.get_enemy_scene(requested_enemy_id)
	if requested_scene == null:
		return null

	return _spawn_enemy(requested_scene)
