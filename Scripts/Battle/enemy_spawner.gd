class_name EnemySpawner
extends Node2D

## Stateless spawning service used by WaveManager.

## Extra distance beyond the current camera view used for enemy entry.
@export var spawn_margin: float = 64.0

## Keeps enemy collision shapes inside the finite battlefield boundary.
@export var map_edge_margin: float = 32.0

@onready var ship: Ship = $"../Ship"
@onready var battlefield: Battlefield = $"../Battlefield"
@onready var enemies: Node2D = $"../Enemies"

var _spawning_enabled: bool = true


func _ready() -> void:
	# The prototype timer remains as a harmless scene child for compatibility;
	# WaveManager now owns all spawn timing and quantities.
	var legacy_timer := get_node_or_null("SpawnTimer") as Timer
	if legacy_timer != null:
		legacy_timer.stop()


func set_spawning_enabled(enabled: bool) -> void:
	_spawning_enabled = enabled


## Creates one enemy using the wave's configured direction pattern.
func spawn_enemy(
	selected_scene: PackedScene,
	spawn_pattern: int = WaveDefinition.SpawnPattern.RANDOM,
	sequence_index: int = 0,
	requested_direction: Vector2 = Vector2.ZERO,
	formation_position: Vector2 = Vector2.INF
) -> BasicEnemy:
	if not _spawning_enabled or selected_scene == null:
		return null

	var enemy := selected_scene.instantiate() as BasicEnemy
	if enemy == null:
		push_error("EnemySpawner scenes must inherit BasicEnemy.gd.")
		return null

	var has_requested_direction := requested_direction != Vector2.ZERO
	var direction := (
		requested_direction.normalized()
		if has_requested_direction
		else _get_spawn_direction(spawn_pattern, sequence_index)
	)
	var collision_clearance := _get_enemy_collision_clearance(enemy)
	var spawn_position := _get_spawn_position(
		direction,
		sequence_index,
		collision_clearance,
		has_requested_direction
	)
	if formation_position.is_finite():
		spawn_position = formation_position
		enemy.set_meta("formation_spawn_side", direction)
	if battlefield.planet_theme == &"forest" and enemy.enemy_id in [&"treant", &"big_treant"]:
		if is_instance_valid(battlefield.forest_terrain) and battlefield.forest_terrain.rings_own_treants:
			# ForestRingRaise raises whole rings of trees instead.
			enemy.free()
			return null
		var tree := battlefield.take_forest_spawn_tree()
		if tree == null:
			enemy.free()
			return null
		spawn_position = tree.global_position
		tree.spawned_enemy_id = enemy.enemy_id
		enemy.set_meta("forest_tree_spawn", tree.get_instance_id())
	enemy.target_ship = ship
	enemies.add_child(enemy)
	enemy.global_position = spawn_position
	return enemy


## Spawns one quota-preserving cluster from one cardinal direction.
func spawn_cluster(
	selected_scene: PackedScene,
	count: int,
	direction: Vector2,
	cluster_radius: float,
	sequence_index: int = 0
) -> Array[BasicEnemy]:
	var spawned: Array[BasicEnemy] = []
	if not _spawning_enabled or selected_scene == null or count <= 0:
		return spawned
	var normalized_direction := direction.normalized()
	if normalized_direction == Vector2.ZERO:
		normalized_direction = Vector2.UP
	var anchor := _get_spawn_position(normalized_direction, sequence_index)
	var used_positions: Array[Vector2] = []
	for index in range(count):
		var spawn_position := _find_cluster_position(
			anchor,
			normalized_direction,
			index,
			count,
			cluster_radius,
			used_positions
		)
		var enemy := selected_scene.instantiate() as BasicEnemy
		if enemy == null:
			push_error("EnemySpawner cluster scenes must inherit BasicEnemy.gd.")
			continue
		enemy.target_ship = ship
		enemies.add_child(enemy)
		enemy.global_position = spawn_position
		used_positions.append(spawn_position)
		spawned.append(enemy)
	return spawned


## Spawns an organized block (Goblin Pack) just outside the view on one
## cardinal side, front row facing the ship, with one flag bearer.
## Layouts come from SpawnFormation (data-driven); units never overlap.
func spawn_formation(
	selected_scene: PackedScene,
	count: int,
	direction: Vector2,
	spacing: float = 30.0,
	with_flag_bearer: bool = true,
	march_in_formation: bool = false
) -> Array[BasicEnemy]:
	var spawned: Array[BasicEnemy] = []
	if not _spawning_enabled or selected_scene == null or count <= 0:
		return spawned
	var side := direction.normalized()
	if side == Vector2.ZERO:
		side = Vector2.UP
	var rows := SpawnFormation.get_rows(count, with_flag_bearer).size()
	# Centre lane (no lane offset), pushed out so the whole block starts off-screen.
	var anchor := _get_spawn_position(side, 3) + side * float(rows - 1) * spacing * 0.5
	var bounds := battlefield.get_world_bounds().grow(-map_edge_margin)
	for slot in SpawnFormation.place(anchor, -side, count, spacing, with_flag_bearer):
		var enemy := selected_scene.instantiate() as BasicEnemy
		if enemy == null:
			push_error("EnemySpawner formation scenes must inherit BasicEnemy.gd.")
			continue
		if bool(slot["flag"]) and "is_flag_bearer" in enemy:
			enemy.set("is_flag_bearer", true)
		if march_in_formation:
			enemy.set_meta("formation_spawn_side", side)
		enemy.target_ship = ship
		enemies.add_child(enemy)
		var position: Vector2 = slot["position"]
		enemy.global_position = Vector2(
			clampf(position.x, bounds.position.x, bounds.end.x),
			clampf(position.y, bounds.position.y, bounds.end.y)
		)
		spawned.append(enemy)
	return spawned


## Compact centered blocks use one spacing grid even with mixed enemy types.
func get_directional_formation_positions(direction: Vector2, count: int, spacing: float, lane_offset: float = 0.0) -> Array[Vector2]:
	var side := direction.normalized()
	if side == Vector2.ZERO:
		side = Vector2.UP
	var rows := SpawnFormation.get_rows(count, false).size()
	var bounds := battlefield.get_world_bounds().grow(-map_edge_margin - 20.0)
	var anchor := _get_spawn_position(side, 3, 20.0) + side * float(rows - 1) * spacing * 0.5
	anchor += Vector2(-side.y, side.x) * lane_offset
	# Shift the whole block inside the bounds rather than clamping each slot.
	var slots := SpawnFormation.place(anchor, -side, count, spacing, false)
	var result: Array[Vector2] = []
	var block := Rect2(anchor, Vector2.ZERO)
	for slot in slots:
		block = block.expand(slot["position"])
	var shift := Vector2.ZERO
	if block.position.x < bounds.position.x: shift.x = bounds.position.x - block.position.x
	if block.end.x + shift.x > bounds.end.x: shift.x += bounds.end.x - (block.end.x + shift.x)
	if block.position.y < bounds.position.y: shift.y = bounds.position.y - block.position.y
	if block.end.y + shift.y > bounds.end.y: shift.y += bounds.end.y - (block.end.y + shift.y)
	for slot in slots:
		result.append((slot["position"] as Vector2) + shift)
	return result


func _find_cluster_position(
	anchor: Vector2,
	direction: Vector2,
	index: int,
	count: int,
	radius: float,
	used_positions: Array[Vector2]
) -> Vector2:
	var bounds := battlefield.get_world_bounds().grow(-map_edge_margin)
	var tangent := Vector2(-direction.y, direction.x)
	var safe_radius := maxf(radius, 1.0)
	# Dense decoration can invalidate many candidates, so sample the full disc
	# thoroughly before considering a bounded fallback.
	const CLUSTER_POSITION_ATTEMPTS: int = 128
	for attempt in range(CLUSTER_POSITION_ATTEMPTS):
		var sample_index := index + attempt * count
		var fraction := sqrt(float(sample_index + 1) / float(maxi(count * CLUSTER_POSITION_ATTEMPTS, 1)))
		var angle := float(sample_index) * 2.399963
		var offset := tangent * cos(angle) * safe_radius * fraction
		offset += direction * sin(angle) * safe_radius * fraction * 0.35
		var candidate := Vector2(
			clampf(anchor.x + offset.x, bounds.position.x, bounds.end.x),
			clampf(anchor.y + offset.y, bounds.position.y, bounds.end.y)
		)
		if not battlefield.is_area_free(candidate, 12.0):
			continue
		var distinct := true
		for used in used_positions:
			if candidate.distance_to(used) < 24.0:
				distinct = false
				break
		if distinct:
			return candidate
	push_warning("EnemySpawner: Could not find a fully clear cluster position; using bounded fallback.")
	return Vector2(
		clampf(anchor.x + tangent.x * float(index - count / 2) * 24.0, bounds.position.x, bounds.end.x),
		clampf(anchor.y + tangent.y * float(index - count / 2) * 24.0, bounds.position.y, bounds.end.y)
	)


## Spawns one stable enemy ID for tests and future planet integrations.
func spawn_enemy_by_id(
	requested_enemy_id: StringName,
	spawn_pattern: int = WaveDefinition.SpawnPattern.RANDOM,
	sequence_index: int = 0
) -> BasicEnemy:
	return spawn_enemy(
		EnemyCatalog.get_enemy_scene(requested_enemy_id),
		spawn_pattern,
		sequence_index
	)


func _get_spawn_direction(spawn_pattern: int, sequence_index: int) -> Vector2:
	match spawn_pattern:
		WaveDefinition.SpawnPattern.ALTERNATING_SIDES:
			var alternating := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
			return alternating[sequence_index % alternating.size()]
		WaveDefinition.SpawnPattern.CARDINAL_CYCLE:
			return Vector2.RIGHT.rotated(TAU * float(sequence_index % 8) / 8.0)
		_:
			return Vector2.RIGHT.rotated(randf_range(0.0, TAU))


func _get_spawn_position(
	direction: Vector2,
	sequence_index: int,
	collision_clearance: float = 0.0,
	spread_across_edge: bool = false
) -> Vector2:
	var ship_center: Vector2 = ship.to_global(Ship.SHIP_SIZE * 0.5)
	var camera_zoom := Vector2(
		maxf(ship.world_camera.zoom.x, 0.001),
		maxf(ship.world_camera.zoom.y, 0.001)
	)
	var half_visible_size := (get_viewport_rect().size / camera_zoom) * 0.5
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

	# Explicit directional waves distribute requests across most of the edge.
	# Legacy random waves retain their existing seven-lane behavior.
	var tangent := Vector2(-direction.y, direction.x)
	var lane_offset := float((sequence_index % 7) - 3) * 28.0
	if spread_across_edge:
		var tangent_half_extent := (
			half_visible_size.y if absf(tangent.y) > absf(tangent.x) else half_visible_size.x
		)
		var usable_half_extent := maxf(tangent_half_extent - collision_clearance - 24.0, 0.0)
		var edge_fraction := fmod(float(sequence_index) * 0.61803398875, 1.0)
		lane_offset = lerpf(-usable_half_extent, usable_half_extent, edge_fraction)
	var spawn_position := (
		ship_center
		+ direction * (distance_to_view_edge + spawn_margin)
		+ tangent * lane_offset
	)

	# Keep the complete collision body inside the map, including the Chariot's
	# 100px radius, rather than clamping only the enemy's origin.
	var boundary_inset := map_edge_margin + maxf(collision_clearance, 0.0)
	var spawn_bounds := battlefield.get_world_bounds().grow(-boundary_inset)
	return Vector2(
		clampf(spawn_position.x, spawn_bounds.position.x, spawn_bounds.end.x),
		clampf(spawn_position.y, spawn_bounds.position.y, spawn_bounds.end.y)
	)


func _get_enemy_collision_clearance(enemy: BasicEnemy) -> float:
	var collision := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return 0.0
	var extent := 0.0
	if collision.shape is CircleShape2D:
		extent = (collision.shape as CircleShape2D).radius
	elif collision.shape is RectangleShape2D:
		var rectangle := collision.shape as RectangleShape2D
		extent = maxf(rectangle.size.x, rectangle.size.y) * 0.5
	elif collision.shape is CapsuleShape2D:
		var capsule := collision.shape as CapsuleShape2D
		extent = maxf(capsule.radius, capsule.height * 0.5)
	return collision.position.length() + extent * maxf(absf(collision.scale.x), absf(collision.scale.y))
