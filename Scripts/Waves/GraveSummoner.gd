class_name GraveSummoner
extends RefCounted

## Shared world-space grave interface for lightning and boss resurrection.
static func points(provider: Node) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if provider != null and provider.has_method("get_grave_emerge_points"):
		for point in provider.call("get_grave_emerge_points"):
			if point is Vector2 and point.is_finite() and not result.has(point):
				result.append(point)
	if result.is_empty():
		push_warning("GraveSummoner: no valid graves; event continues without summons.")
	return result

static func spawn(provider: Node, container: Node2D, ship: Ship, scene: PackedScene, grave_points: Array[Vector2], origin: StringName) -> int:
	var bounds := Rect2()
	if provider != null and provider.has_method("get_world_bounds"):
		bounds = provider.call("get_world_bounds")
	var reserved: Array[Vector2] = []
	for point in grave_points:
		var candidate := _safe_position(container, ship, point, bounds, reserved)
		if not candidate.is_finite():
			push_warning("GraveSummoner: no safe position near grave %s" % point)
			continue
		var enemy := scene.instantiate() as BasicEnemy
		if enemy == null:
			push_error("GraveSummoner: scene must inherit BasicEnemy")
			continue
		enemy.target_ship = ship
		enemy.set_meta("spawn_origin", origin)
		enemy.position = container.to_local(candidate)
		container.add_child(enemy)
		reserved.append(candidate)
	return reserved.size()

static func _safe_position(container: Node2D, ship: Ship, point: Vector2, bounds: Rect2, reserved: Array[Vector2]) -> Vector2:
	const RADIUS := 12.0
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	for radius: float in [0.0, 24.0, 48.0, 72.0]:
		for index in range(1 if radius == 0.0 else 8):
			var candidate: Vector2 = point + Vector2.RIGHT.rotated(TAU * index / 8.0) * radius
			if bounds.has_area() and not bounds.grow(-RADIUS).has_point(candidate):
				continue
			var occupied := false
			for other in reserved:
				if other.distance_to(candidate) < RADIUS * 2.0:
					occupied = true
					break
			if occupied:
				continue
			if is_instance_valid(ship) and Rect2(Vector2.ZERO, Ship.SHIP_SIZE).grow(RADIUS).has_point(ship.to_local(candidate)):
				continue
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = shape
			query.transform = Transform2D(0.0, candidate)
			query.collision_mask = 0xffffffff
			query.collide_with_areas = true
			query.collide_with_bodies = true
			if container.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
				return candidate
	return Vector2(INF, INF)
