class_name AngryStoneEffect
extends MagicArtifactEffect

## Per-equipped-weapon hit counter. Splash damage does not emit projectile_hit.
## Every triggering hit also bursts a ring of grey grit at the target.
const Burst := preload("res://Scripts/VFX/AngryStoneBurst.gd")
var weapon: WeaponModule
var hit_count: int = 0

func configure_weapon(target_weapon: WeaponModule) -> void:
	weapon = target_weapon

func _ready() -> void:
	if is_instance_valid(weapon):
		weapon.projectile_hit.connect(_on_projectile_hit)

func cleanup() -> void:
	if is_instance_valid(weapon) and weapon.projectile_hit.is_connected(_on_projectile_hit):
		weapon.projectile_hit.disconnect(_on_projectile_hit)
	queue_free()

func _on_projectile_hit(target: BasicEnemy, actual_damage: float) -> void:
	if not is_instance_valid(weapon) or weapon.is_queued_for_deletion() or weapon.assembly_mode or not is_instance_valid(ship) or ship.get_module_cell(weapon).x < 0 or not is_instance_valid(target):
		return
	hit_count += 1
	var every := maxi(int(definition.effect_parameters.get("hits_per_trigger", 3)), 1)
	if hit_count % every != 0:
		return
	var circle := CircleShape2D.new()
	circle.radius = maxf(float(definition.effect_parameters.get("radius", 30.0)), 0.001)
	_spawn_burst(target.global_position, circle.radius)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, target.global_position)
	query.collision_mask = 0xffffffff
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var seen := {}
	for result in get_world_2d().direct_space_state.intersect_shape(query, 1024):
		var enemy := result.get("collider") as BasicEnemy
		if enemy == null or enemy == target or enemy.is_dying() or not enemy.is_in_group("enemies"):
			continue
		var id := enemy.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		enemy.take_damage(actual_damage * maxf(float(definition.effect_parameters.get("damage_fraction", 0.5)), 0.0), false, true, weapon)


func _spawn_burst(at: Vector2, radius: float) -> void:
	var scene_root := ship.get_parent() if is_instance_valid(ship) else null
	if scene_root == null:
		return
	var burst: Node2D = Burst.new()
	burst.radius = radius
	scene_root.add_child(burst)
	burst.global_position = at
