extends MagicArtifactEffect

## Every kill credited to the equipped turret releases one non-recursive
## necromantic burst based on the defeated enemy's maximum health.
const NECRO_BURST := preload("res://Scripts/VFX/NecroSpiritBurst.gd")
var weapon: WeaponModule


func configure_weapon(target_weapon: WeaponModule) -> void:
	weapon = target_weapon


func _ready() -> void:
	if is_instance_valid(weapon):
		weapon.enemy_defeated.connect(_on_enemy_defeated)


func _on_enemy_defeated(death_position: Vector2, defeated_max_health: float) -> void:
	if not is_instance_valid(weapon) or defeated_max_health <= 0.0:
		return
	var radius := maxf(float(definition.effect_parameters.get("radius", 80.0)), 0.001)
	var damage := defeated_max_health * maxf(float(definition.effect_parameters.get("health_damage_fraction", 0.33)), 0.0)
	NECRO_BURST.spawn(weapon.get_tree().current_scene, death_position, radius)
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, death_position)
	query.collision_mask = 0xffffffff
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit_ids: Dictionary = {}
	for result in weapon.get_world_2d().direct_space_state.intersect_shape(query, 1024):
		var enemy := result.get("collider") as BasicEnemy
		if enemy == null or enemy.is_dying() or not enemy.is_in_group(&"enemies"):
			continue
		var instance_id := enemy.get_instance_id()
		if hit_ids.has(instance_id):
			continue
		hit_ids[instance_id] = true
		# count_for_artifact=false prevents activity counting and kill-chain bursts.
		enemy.take_damage(damage, false, false, null)


func cleanup() -> void:
	if is_instance_valid(weapon) and weapon.enemy_defeated.is_connected(_on_enemy_defeated):
		weapon.enemy_defeated.disconnect(_on_enemy_defeated)
	queue_free()
