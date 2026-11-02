extends MagicArtifactEffect

## Mirrors only hull HP actually restored by the equipped Regeneration module.
## The pulse's effective (research-adjusted) radius is shared with the damage.
var module: RegenerationModule


func configure_module(target_module: ShipModule) -> void:
	module = target_module as RegenerationModule


func _ready() -> void:
	if is_instance_valid(module):
		module.ship_healed_by_pulse.connect(_on_ship_healed)


func _on_ship_healed(actual_amount: float, origin: Vector2, radius: float) -> void:
	if not is_instance_valid(module) or actual_amount <= 0.0 or radius <= 0.0:
		return
	var damage := actual_amount * maxf(float(definition.effect_parameters.get("healing_damage_ratio", 1.0)), 0.0)
	if damage <= 0.0:
		return
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, origin)
	query.collision_mask = 0xffffffff
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit_ids: Dictionary = {}
	for result in module.get_world_2d().direct_space_state.intersect_shape(query, 1024):
		var enemy := result.get("collider") as BasicEnemy
		if enemy == null or enemy.is_dying() or not enemy.is_in_group(&"enemies"):
			continue
		var enemy_id := enemy.get_instance_id()
		if hit_ids.has(enemy_id):
			continue
		hit_ids[enemy_id] = true
		# Artifact damage has no weapon attribution and cannot start kill chains.
		enemy.take_damage(damage, false, false, null)


func cleanup() -> void:
	if is_instance_valid(module) and module.ship_healed_by_pulse.is_connected(_on_ship_healed):
		module.ship_healed_by_pulse.disconnect(_on_ship_healed)
	queue_free()
